org  0100h
;它告诉编译器，程序被载入内存的初始偏移地址为0x0100h，
;因此编译产生的代码中，涉及MOV等指令的标号的偏移量都加上了0x0100h,
;常量并不会发生变化

;关于PBP以及软盘文件系统FAT12的详细信息，请看以下参考资料
;让操作系统走进保护模式(知识个人总结精华版)
;软盘结构，FAT文件系统，FAT文件系统白皮书

	jmp LABEL_START

; 下面是 FAT12 磁盘的头, 独立出来的原因是这两个文件都要使用这些参数。
%include "fat12hdr.inc"
%include "load.inc"
%include "pm.inc"

;关于gdt,selector,descriptor等名词的具体含义，请去资料库中寻找赵炯老师和于渊老师的书，
;书中有详细的解释，方便大家学习
; GDT
;                            段基址     段界限, 属性
LABEL_GDT:	    Descriptor 0,            0, 0              ; 空描述符
LABEL_DESC_FLAT_C:  Descriptor 0,      0fffffh, DA_CR|DA_32|DA_LIMIT_4K ;0-4G
LABEL_DESC_FLAT_RW: Descriptor 0,      0fffffh, DA_DRW|DA_32|DA_LIMIT_4K;0-4G
LABEL_DESC_VIDEO:   Descriptor 0B8000h, 0ffffh, DA_DRW|DA_DPL3 ; 显存首地址

GdtLen		equ	$ - LABEL_GDT
GdtPtr		dw	GdtLen - 1				; 段界限
		dd	BaseOfLoaderPhyAddr + LABEL_GDT		; 基地址

; GDT 选择子
SelectorFlatC		equ	LABEL_DESC_FLAT_C	- LABEL_GDT
SelectorFlatRW		equ	LABEL_DESC_FLAT_RW	- LABEL_GDT
SelectorVideo		equ	LABEL_DESC_VIDEO	- LABEL_GDT + SA_RPL3

;======================================================================================================
BaseOfStack			equ	  0100h
PageDirBase			equ	100000h	; 页目录开始地址: 1M
PageTblBase			equ	101000h	; 页表开始地址:   1M + 4K
;======================================================================================================	

LABEL_START:
	mov	ax, cs
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
	mov	sp, BaseOfStack			;初始化各个寄存器，特别是sp
	
	mov	dh, 0			; "Loading  "
	call	DispStrRealMode	; 显示字符串

	; 得到内存数
	mov	ebx, 0			; ebx = 后续值, 开始时需为 0
	mov	di, _MemChkBuf		; es:di 指向一个地址范围描述符结构(ARDS)
.MemChkLoop:
	mov	eax, 0E820h			; eax = 0000E820h
	mov	ecx, 20			; ecx = 地址范围描述符结构的大小
	mov	edx, 0534D4150h		; edx = 'SMAP'
	int	15h				; int 15h
	jc	.MemChkFail
	add	di, 20
	inc	dword [_dwMCRNumber]	; dwMCRNumber = ARDS 的个数
	cmp	ebx, 0
	jne	.MemChkLoop
	jmp	.MemChkOK
.MemChkFail:
	mov	dword [_dwMCRNumber], 0
.MemChkOK:

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
	call	DispStrRealMode	; 显示字符串

	; 下面准备跳入保护模式

	; 加载 GDTR
	lgdt	[GdtPtr]

	; 关中断
	cli

	; 打开地址线A20
	in	al, 92h
	or	al, 00000010b
	out	92h, al

	; 准备切换到保护模式
	mov	eax, cr0
	or	eax, 1
	mov	cr0, eax

	; 真正进入保护模式
	jmp	dword SelectorFlatC:(BaseOfLoaderPhyAddr+LABEL_PM_START)

	jmp $

; *****************************************************************************************************
	;jmp	BaseOfKernel:OffsetOfKernel	
	; 这一句正式跳转到已加载到内存中的 KERNEL.ELF 的开始处，
	; 开始执行 KERNEL.ELF 的代码。
; *****************************************************************************************************

;============================================================================
;变量
wRootDirSizeForLoop	dw	RootDirSectors	; Root Directory 占用的扇区数, 在循环中会递减至零.
wSectorNo			dw	0	; 要读取的扇区号
bOdd				db	0		; 奇数还是偶数
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
; 函数名: DispStrRealMode
;----------------------------------------------------------------------------
; 功能: 利用BIOS的10h号中断调用在屏幕打印字符串, 函数开始时 dh 中应该是字符串序号(0-based)
DispStrRealMode:
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

; 从此以后的代码在保护模式下执行 ----------------------------------------------------
; 32 位代码段. 由实模式跳入 ---------------------------------------------------------
[SECTION .s32]

ALIGN	32

[BITS	32]

LABEL_PM_START:
	mov	ax, SelectorVideo
	mov	gs, ax

	mov	ax, SelectorFlatRW
	mov	ds, ax
	mov	es, ax
	mov	fs, ax
	mov	ss, ax
	mov	esp, TopOfStack

	push	szMemChkTitle
	call	DispStr
	add	esp, 4

	call	DispMemInfo
	call	SetupPaging

	mov	ah, 0Fh				; 0000: 黑底    1111: 白字
	mov	al, 'P'
	mov	[gs:((80 * 0 + 39) * 2)], ax	; 屏幕第 0 行, 第 39 列。
	jmp	$

; ------------------------------------------------------------------------
; 显示 AL 中的数字
; ------------------------------------------------------------------------
DispAL:
	push	ecx
	push	edx
	push	edi

	mov	edi, [dwDispPos]

	mov	ah, 0Fh			; 0000b: 黑底    1111b: 白字
	mov	dl, al
	shr	al, 4
	mov	ecx, 2
.begin:
	and	al, 01111b
	cmp	al, 9
	ja	.1
	add	al, '0'
	jmp	.2
.1:
	sub	al, 0Ah
	add	al, 'A'
.2:
	mov	[gs:edi], ax
	add	edi, 2

	mov	al, dl
	loop	.begin
	;add	edi, 2

	mov	[dwDispPos], edi

	pop	edi
	pop	edx
	pop	ecx

	ret
; DispAL 结束-------------------------------------------------------------


; ------------------------------------------------------------------------
; 显示一个整形数
; ------------------------------------------------------------------------
DispInt:
	mov	eax, [esp + 4]
	shr	eax, 24
	call	DispAL

	mov	eax, [esp + 4]
	shr	eax, 16
	call	DispAL

	mov	eax, [esp + 4]
	shr	eax, 8
	call	DispAL

	mov	eax, [esp + 4]
	call	DispAL

	mov	ah, 07h			; 0000b: 黑底    0111b: 灰字
	mov	al, 'h'
	push	edi
	mov	edi, [dwDispPos]
	mov	[gs:edi], ax
	add	edi, 4
	mov	[dwDispPos], edi
	pop	edi

	ret
; DispInt 结束------------------------------------------------------------

; ------------------------------------------------------------------------
; 显示一个字符串
; ------------------------------------------------------------------------
DispStr:
	push	ebp
	mov	ebp, esp
	push	ebx
	push	esi
	push	edi

	mov	esi, [ebp + 8]	; pszInfo
	mov	edi, [dwDispPos]
	mov	ah, 0Fh
.1:
	lodsb
	test	al, al
	jz	.2
	cmp	al, 0Ah	; 是回车吗?
	jnz	.3
	push	eax
	mov	eax, edi
	mov	bl, 160
	div	bl
	and	eax, 0FFh
	inc	eax
	mov	bl, 160
	mul	bl
	mov	edi, eax
	pop	eax
	jmp	.1
.3:
	mov	[gs:edi], ax
	add	edi, 2
	jmp	.1

.2:
	mov	[dwDispPos], edi

	pop	edi
	pop	esi
	pop	ebx
	pop	ebp
	ret
; DispStr 结束------------------------------------------------------------

; ------------------------------------------------------------------------
; 换行
; ------------------------------------------------------------------------
DispReturn:
	push	szReturn
	call	DispStr			;printf("\n");
	add	esp, 4

	ret
; DispReturn 结束---------------------------------------------------------


; ------------------------------------------------------------------------
; 内存拷贝，仿 memcpy
; ------------------------------------------------------------------------
; void* MemCpy(void* es:pDest, void* ds:pSrc, int iSize);
; ------------------------------------------------------------------------
MemCpy:
	push	ebp
	mov	ebp, esp

	push	esi
	push	edi
	push	ecx

	mov	edi, [ebp + 8]	; Destination
	mov	esi, [ebp + 12]	; Source
	mov	ecx, [ebp + 16]	; Counter
.1:
	cmp	ecx, 0		; 判断计数器
	jz	.2		; 计数器为零时跳出

	mov	al, [ds:esi]		; ┓
	inc	esi			; ┃
					; ┣ 逐字节移动
	mov	byte [es:edi], al	; ┃
	inc	edi			; ┛

	dec	ecx		; 计数器减一
	jmp	.1		; 循环
.2:
	mov	eax, [ebp + 8]	; 返回值

	pop	ecx
	pop	edi
	pop	esi
	mov	esp, ebp
	pop	ebp

	ret			; 函数结束，返回
; MemCpy 结束-------------------------------------------------------------

; 显示内存信息 --------------------------------------------------------------
DispMemInfo:
	push	esi
	push	edi
	push	ecx

	mov	esi, MemChkBuf
	mov	ecx, [dwMCRNumber];for(int i=0;i<[MCRNumber];i++)//每次得到一个ARDS
.loop:				  ;{
	mov	edx, 5		  ;  for(int j=0;j<5;j++)//每次得到一个ARDS中的成员
	mov	edi, ARDStruct	  ;  {//依次显示:BaseAddrLow,BaseAddrHigh,LengthLow
.1:				  ;               LengthHigh,Type
	push	dword [esi]	  ;
	call	DispInt		  ;    DispInt(MemChkBuf[j*4]); // 显示一个成员
	pop	eax		  ;
	stosd			  ;    ARDStruct[j*4] = MemChkBuf[j*4];
	add	esi, 4		  ;
	dec	edx		  ;
	cmp	edx, 0		  ;
	jnz	.1		  ;  }
	call	DispReturn	  ;  printf("\n");
	cmp	dword [dwType], 1 ;  if(Type == AddressRangeMemory)
	jne	.2		  ;  {
	mov	eax, [dwBaseAddrLow];
	add	eax, [dwLengthLow];
	cmp	eax, [dwMemSize]  ;    if(BaseAddrLow + LengthLow > MemSize)
	jb	.2		  ;
	mov	[dwMemSize], eax  ;    MemSize = BaseAddrLow + LengthLow;
.2:				  ;  }
	loop	.loop		  ;}
				  ;
	call	DispReturn	  ;printf("\n");
	push	szRAMSize	  ;
	call	DispStr		  ;printf("RAM size:");
	add	esp, 4		  ;
				  ;
	push	dword [dwMemSize] ;
	call	DispInt		  ;DispInt(MemSize);
	add	esp, 4		  ;

	pop	ecx
	pop	edi
	pop	esi
	ret
; ---------------------------------------------------------------------------

; 启动分页机制 --------------------------------------------------------------
SetupPaging:
	; 根据内存大小计算应初始化多少PDE以及多少页表
	xor	edx, edx
	mov	eax, [dwMemSize]
	mov	ebx, 400000h	; 400000h = 4M = 4096 * 1024, 一个页表对应的内存大小
	div	ebx
	mov	ecx, eax	; 此时 ecx 为页表的个数，也即 PDE 应该的个数
	test	edx, edx
	jz	.no_remainder
	inc	ecx		; 如果余数不为 0 就需增加一个页表
.no_remainder:
	push	ecx		; 暂存页表个数

	; 为简化处理, 所有线性地址对应相等的物理地址. 并且不考虑内存空洞.

	; 首先初始化页目录
	mov	ax, SelectorFlatRW
	mov	es, ax
	mov	edi, PageDirBase	; 此段首地址为 PageDirBase
	xor	eax, eax
	mov	eax, PageTblBase | PG_P  | PG_USU | PG_RWW
.1:
	stosd
	add	eax, 4096		; 为了简化, 所有页表在内存中是连续的.
	loop	.1

	; 再初始化所有页表
	pop	eax			; 页表个数
	mov	ebx, 1024		; 每个页表 1024 个 PTE
	mul	ebx
	mov	ecx, eax		; PTE个数 = 页表个数 * 1024
	mov	edi, PageTblBase	; 此段首地址为 PageTblBase
	xor	eax, eax
	mov	eax, PG_P  | PG_USU | PG_RWW
.2:
	stosd
	add	eax, 4096		; 每一页指向 4K 的空间
	loop	.2

	mov	eax, PageDirBase
	mov	cr3, eax
	mov	eax, cr0
	or	eax, 80000000h
	mov	cr0, eax
	jmp	short .3
.3:
	nop

	ret
; 分页机制启动完毕 ----------------------------------------------------------


; SECTION .data1 之开始 ---------------------------------------------------------------------------------------------
[SECTION .data1]

ALIGN	32

LABEL_DATA:
; 实模式下使用这些符号
; 字符串
_szMemChkTitle:	db "BaseAddrL BaseAddrH LengthLow LengthHigh   Type", 0Ah, 0
_szRAMSize:	db "RAM size:", 0
_szReturn:	db 0Ah, 0
;; 变量
_dwMCRNumber:	dd 0	; Memory Check Result
_dwDispPos:	dd (80 * 6 + 0) * 2	; 屏幕第 6 行, 第 0 列。
_dwMemSize:	dd 0
_ARDStruct:	; Address Range Descriptor Structure
  _dwBaseAddrLow:		dd	0
  _dwBaseAddrHigh:		dd	0
  _dwLengthLow:			dd	0
  _dwLengthHigh:		dd	0
  _dwType:			dd	0
_MemChkBuf:	times	256	db	0
;
;; 保护模式下使用这些符号
szMemChkTitle		equ	BaseOfLoaderPhyAddr + _szMemChkTitle
szRAMSize		equ	BaseOfLoaderPhyAddr + _szRAMSize
szReturn		equ	BaseOfLoaderPhyAddr + _szReturn
dwDispPos		equ	BaseOfLoaderPhyAddr + _dwDispPos
dwMemSize		equ	BaseOfLoaderPhyAddr + _dwMemSize
dwMCRNumber		equ	BaseOfLoaderPhyAddr + _dwMCRNumber
ARDStruct		equ	BaseOfLoaderPhyAddr + _ARDStruct
	dwBaseAddrLow	equ	BaseOfLoaderPhyAddr + _dwBaseAddrLow
	dwBaseAddrHigh	equ	BaseOfLoaderPhyAddr + _dwBaseAddrHigh
	dwLengthLow	equ	BaseOfLoaderPhyAddr + _dwLengthLow
	dwLengthHigh	equ	BaseOfLoaderPhyAddr + _dwLengthHigh
	dwType		equ	BaseOfLoaderPhyAddr + _dwType
MemChkBuf		equ	BaseOfLoaderPhyAddr + _MemChkBuf


; 堆栈就在数据段的末尾
StackSpace:	times	1024	db	0
TopOfStack	equ	BaseOfLoaderPhyAddr + $	; 栈顶
; SECTION .data1 之结束 ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

