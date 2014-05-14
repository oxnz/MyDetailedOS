org  0100h
;它告诉编译器，程序被载入内存的初始偏移地址为0x0100h，
;因此编译产生的代码中，涉及MOV等指令的标号的偏移量都加上了0x0100h,
;常量并不会发生变化

;关于PBP以及软盘文件系统FAT12的详细信息，请看以下参考资料
;让操作系统走进保护模式(知识个人总结精华版)
;软盘结构，FAT文件系统，FAT文件系统白皮书
;======================================================================================================
BaseOfStack			equ	  0100h
BaseOfKernel		equ	 08000h	; KERNEL.ELF 被加载到的位置 ---- 段地址
OffsetOfKernel		equ	     0h	; KERNEL.ELF 被加载到的位置 ---- 偏移地址
;======================================================================================================	
	jmp LABEL_START

; 下面是 FAT12 磁盘的头, 独立出来的原因是这两个文件都要使用这些参数。
%include "fat12hdr.inc"

LABEL_START:
	mov	ax, cs
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
	mov	sp, BaseOfStack			;初始化各个寄存器，特别是sp
	
	mov	dh, 0			; "Loading  "
	call	DispStr			; 显示字符串

	xor	ah, ah	
	xor	dl, dl	
	int	13h					; 磁盘系统复位，详情参考资料库
	
; 以下代码片段是在软盘的根目录寻找 KERNEL.ELF.
; 这个代码是一个简单的三重循环,用C+伪代码来书写就如下面所示
; for (i=RootDirSectors;i>0;i--)
;  {
;	读取从wSectorNo开始一个扇区内容到es：bx所指向的位置;
; 	使ds:si指向"KERNEL  BIN";
;	使es:di指向BaseOfKernel:OffsetOfKernel;
;	for(j=10h;j>0;j--)
;	{
;		for(k=11;k>0;k--)
;		{
;			if(某一个字符不相同)
;			{
;				di &= 0FFE0h;		
;				di += 20h;
;				si = KernelFileName;
;				break;
;			}
;		}
;		if(k==0)for(;)		
;	}
;	wSectorNo++;
;  }
	mov	word [wSectorNo], SectorNoOfRootDirectory
LABEL_SEARCH_IN_ROOT_DIR_BEGIN:
	cmp	word [wRootDirSizeForLoop], 0	; 判断根目录区是不是已经读完
	jz	LABEL_NO_KERNELELF		; 如果读完表示没有找到 KERNEL.ELF
	dec	word [wRootDirSizeForLoop]
	mov	ax, BaseOfKernel
	mov	es, ax				; es <- BaseOfKernel
	mov	bx, OffsetOfKernel		; bx <- OffsetOfKernel
	mov	ax, [wSectorNo]			; ax <- Root Directory 中的某 Sector 号
	mov	cl, 1
	call	ReadSector

	mov	si, KernelFileName		; ds:si -> "KERNEL  ELF"
	mov	di, OffsetOfKernel		; es:di -> BaseOfKernel:0100
	cld
	mov	dx, 10h				;10h=200h(单个扇区字节数)/20h（目录项字节数）
LABEL_SEARCH_FOR_KERNELELF:
	cmp	dx, 0				   	; 循环次数控制
	jz	LABEL_GOTO_NEXT_SECTOR_IN_ROOT_DIR
	dec	dx				   	; 就进入下一个 Sector
	mov	cx, 11
LABEL_CMP_FILENAME:
	cmp	cx, 0
	jz	LABEL_FILENAME_FOUND		; 如果比较了 11 个字符都相等, 表示找到
	dec	cx
	lodsb						
	cmp	al, byte [es:di]
	jz	LABEL_GO_ON
	jmp	LABEL_DIFFERENT			
	; 只要发现不一样的字符就表明本 DirectoryEntry不是我们要找的 KERNEL.ELF,跳出循环
LABEL_GO_ON:
	inc	di
	jmp	LABEL_CMP_FILENAME		; 继续循环

LABEL_DIFFERENT:
	and	di, 0FFE0h				
	; di &= FFE0 为了让它指向本条目开头,因为无法确定di的大小	
	add	di, 20h				;di += 20h  指向下一个目录条目
	mov	si, KernelFileName		
	jmp	LABEL_SEARCH_FOR_KERNELELF

LABEL_GOTO_NEXT_SECTOR_IN_ROOT_DIR:
	add	word [wSectorNo], 1
	jmp	LABEL_SEARCH_IN_ROOT_DIR_BEGIN

LABEL_NO_KERNELELF:
	mov	dh, 2			; "No KERNEL."
	call	DispStr		; 打印字符串
	jmp	$			; 没有找到 KERNEL.ELF, 死循环在这里
LABEL_FILENAME_FOUND:		; 找到 KERNEL.ELF 后便来到这里继续
	mov	ax, RootDirSectors
	and	di, 0FFE0h		; di -> 当前条目的开始

	push	eax
	mov	eax, [es : di + 01Ch]		
	mov	dword [dwKernelSize], eax	; 保存 KERNEL.BIN 文件大小
	pop	eax

	add	di, 01Ah		; di -> 首 Sector
	mov	cx, word [es:di]
	push	cx			; 保存此 Sector 在 FAT 中的序号
	add	cx, ax
	add	cx, DeltaSectorNo	; cl <- KERNEL.ELF的起始扇区号(0-based)
	mov	ax, BaseOfKernel
	mov	es, ax			; es <- BaseOfKernel
	mov	bx, OffsetOfKernel	; bx <- OffsetOfKernel
	mov	ax, cx			; ax <- Sector 号

LABEL_GOON_LOADING_FILE:
	push	ax			; 
	push	bx			;  |
	mov	ah, 0Eh		;  | 每读一个扇区就在 "Booting  " 后面
	mov	al, '.'		;  | 打一个点, 形成这样的效果:
	mov	bl, 0Fh		;  | Booting ......
	int	10h			;  |
	pop	bx			;  |
	pop	ax			; 

	mov	cl, 1
	call	ReadSector
	pop	ax			; 取出此 Sector 在 FAT 中的序号
	call	GetFATEntry
	cmp	ax, 0FFFh
	jz	LABEL_FILE_LOADED
	push	ax			; 保存 Sector 在 FAT 中的序号
	mov	dx, RootDirSectors
	add	ax, dx
	add	ax, DeltaSectorNo
	add	bx, [BPB_BytsPerSec]
	jmp	LABEL_GOON_LOADING_FILE
LABEL_FILE_LOADED:
	call	KillMotor		; 关闭软驱马达

	mov	dh, 1			; "Ready."
	call	DispStr			; 显示字符串

	jmp $

; *****************************************************************************************************
	;jmp	BaseOfKernel:OffsetOfKernel	
	; 这一句正式跳转到已加载到内存中的 KERNEL.ELF 的开始处，
	; 开始执行 KERNEL.ELF 的代码。
; *****************************************************************************************************

;============================================================================
;变量
wRootDirSizeForLoop	dw	RootDirSectors	; Root Directory 占用的扇区数, 在循环中会递减至零.
wSectorNo		dw	0	; 要读取的扇区号
bOdd			db	0		; 奇数还是偶数
dwKernelSize		dd	0		; KERNEL.ELF 文件大小

;字符串
KernelFileName		db	"KERNEL  BIN", 0  ; KERNEL.ELF 之文件名
; 为简化代码, 下面每个字符串的长度均为 MessageLength
MessageLength		equ	9
BootMessage:		db	"Loading  " 	; 9字节, 不够则用空格补齐. 序号 0
Message1			db	"Ready.   " 	; 9字节, 不够则用空格补齐. 序号 1
Message2			db	"No KERNEL" 	; 9字节, 不够则用空格补齐. 序号 2
;============================================================================

;----------------------------------------------------------------------------
; 函数名: DispStr
;----------------------------------------------------------------------------
; 功能: 利用BIOS的10h号中断调用在屏幕打印字符串, 函数开始时 dh 中应该是字符串序号(0-based)
DispStr:
;10h中断调用 ah=13h
;功能：显示字符串
;参数：ES:BP = 串地址 
;参数：CX = 串长度 
;参数：DH，DL = 起始行列 
;参数：BH = 页号
;AL = 0，BL = 属性 						光标返回起始位置
;串：Char，char，……，char
;AL = 1，BL = 属性 						光标跟随移动
;串：Char，char，……，char 
;AL = 2 									光标返回起始位置
;串：Char，attr，……，char，attr 
;AL = 3 									光标跟随串移动
;串：Char，attr，……，char，attr
	mov	ax, MessageLength
	mul	dh
	add	ax, BootMessage
	mov	bp, ax			; 
	mov	ax, ds			; | ES:BP = 串地址
	mov	es, ax			; 
	mov	cx, MessageLength	; CX = 串长度
	mov	ax, 01301h		; AH = 13,  AL = 01h
	mov	bx, 0007h		; 页号为0(BH = 0) 黑底白字(BL = 07h)
	mov	dl, 0
	add	dh, 3			; 从第 3 行往下显示,和boot提示信息有空行
	int	10h			; int 10h
	ret
;----------------------------------------------------------------------------
; 函数名: ReadSector
;----------------------------------------------------------------------------
; 作用:
;	从第 ax 个 Sector 开始, 将 cl 个 Sector 读入 es:bx 中
ReadSector:
;13h中断调用 ah=02h
;功能：从软盘中按照扇区号读取相应扇区数的数据
;参数：ES:BX 为数据缓冲区 
;参数：AL = 要读扇区数
;参数：CH = 柱面（磁道）号 ,CL = 起始扇区号 
;参数：DH = 磁头号 ,DL = 驱动器号 
	
; 怎样由扇区号求扇区在磁盘中的位置 (扇区号 -> 柱面号, 起始扇区, 磁头号)
; 设扇区号为 x
;                                    | 柱面号 = y >> 1
;       x        | 商   y =>|
; ----------------  =  ┤            | 磁头号 = y & 1
;  每磁道扇区数       │ 余数 z =>  起始扇区号 = z + 1
	push	bp
	mov	bp, sp
	sub	esp, 2 		; 辟出两个字节的堆栈区域保存要读的扇区数: byte [bp-2]

	mov	byte [bp-2], cl
	push	bx			; 保存 bx
	mov	bl, [BPB_SecPerTrk]	; bl: 除数
	div	bl			; y 在 al 中, z 在 ah 中
	inc	ah			; z ++
	mov	cl, ah		; cl <- 起始扇区号
	mov	dh, al		; dh <- y
	shr	al, 1			; y >> 1 (y/BPB_NumHeads)
	mov	ch, al		; ch <- 柱面号
	and	dh, 1			; dh & 1 = 磁头号
	pop	bx			; 恢复 bx
	; 至此, "柱面号, 起始扇区, 磁头号" 全部得到
	mov	dl, [BS_DrvNum]	; 驱动器号 (0 表示 A 盘)
.GoOnReading:
	mov	ah, 2			; 读
	mov	al, byte [bp-2]	; 读 al 个扇区
	int	13h
	jc	.GoOnReading	; 如果读取错误 CF 会被置为 1, 
					; 这时就不停地读, 直到正确为止
	add	esp, 2
	pop	bp
	ret
;----------------------------------------------------------------------------
; 函数名: GetFATEntry
;----------------------------------------------------------------------------
; 作用:
;	找到序号为 ax 的 Sector 在 FAT 中的条目, 结果放在 ax 中
;	需要注意的是, 中间需要读 FAT 的扇区到 es:bx 处, 所以函数一开始保存了 es 和 bx
GetFATEntry:
	push	es
	push	bx
	push	ax
	mov	ax, BaseOfKernel	; 
	sub	ax, 0100h		;  | 在 BaseOfKernel 后面留出 4K 空间用于存放 FAT
	mov	es, ax		; 
	pop	ax
	mov	byte [bOdd], 0
	mov	bx, 3
	mul	bx			; dx:ax = ax * 3
	mov	bx, 2
	div	bx			; dx:ax / 2  ==>  ax <- 商, dx <- 余数
	cmp	dx, 0
	jz	LABEL_EVEN
	mov	byte [bOdd], 1
LABEL_EVEN:;偶数
	; 现在 ax 中是 FATEntry 在 FAT 中的偏移量,下面来
	; 计算 FATEntry 在哪个扇区中(FAT占用不止一个扇区)
	xor	dx, dx			
	mov	bx, [BPB_BytsPerSec]
	div	bx ; dx:ax / BPB_BytsPerSec
		   ;  ax <- 商 (FATEntry 所在的扇区相对于 FAT 的扇区号)
		   ;  dx <- 余数 (FATEntry 在扇区内的偏移)。
	push	dx
	mov	bx, 0 ; bx <- 0 于是, es:bx = (BaseOfKernel - 100):00
	add	ax, SectorNoOfFAT1 ; 此句之后的 ax 就是 FATEntry 所在的扇区号
	mov	cl, 2
	call	ReadSector ; 读取 FATEntry 所在的扇区, 一次读两个, 避免在边界
			   ; 发生错误, 因为一个 FATEntry 可能跨越两个扇区
	pop	dx
	add	bx, dx
	mov	ax, [es:bx]
	cmp	byte [bOdd], 1
	jnz	LABEL_EVEN_2
	shr	ax, 4
LABEL_EVEN_2:
	and	ax, 0FFFh

LABEL_GET_FAT_ENRY_OK:

	pop	bx
	pop	es
	ret
;----------------------------------------------------------------------------

;----------------------------------------------------------------------------
; 函数名: KillMotor
;----------------------------------------------------------------------------
; 作用: 关闭软驱马达
KillMotor:
	push	dx
	mov	dx, 03F2h
	mov	al, 0
	out	dx, al
	pop	dx
	ret
;----------------------------------------------------------------------------
