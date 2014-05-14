org	07c00h
;;它告诉编译器，程序被载入内存的初始偏移地址为0x7c00h，
;;因此编译产生的代码中，涉及MOV等指令的标号的偏移量都加上了0x7c00h,
;;常量并不会发生变化

;;关于PBP以及软盘文件系统FAT12的详细信息，请看以下参考资料
;;让操作系统走进保护模式(知识个人总结精华版)
;;软盘结构，FAT文件系统，FAT文件系统白皮书
;;================================================================================================
BaseOfStack			equ	07c00h	;; 堆栈基地址(栈底, 从这个位置向低地址生长)
BaseOfLoader		equ	09000h	;; LOADER.BIN 被加载到的位置 ----  段地址
OffsetOfLoader		equ	0100h		;; LOADER.BIN 被加载到的位置 ---- 偏移地址
RootDirSectors		equ	14		;; 根目录占用空间
SectorNoOfRootDirectory	equ	19		;; Root Directory 的第一个扇区号	
	jmp short LABEL_START			;; Start to boot.
	nop						;; 这个指令确实少不得，否则加载会出问题

	;; 下面是 FAT12 磁盘的头
	BS_OEMName		DB 'MSWIN4.1'	;; OEM String, 必须 8 个字节
	BPB_BytsPerSec	DW 512		;; 每扇区字节数
	BPB_SecPerClus	DB 1			;; 每簇多少扇区
	BPB_RsvdSecCnt	DW 1			;; Boot 记录占用多少扇区
	BPB_NumFATs		DB 2			;; 共有多少 FAT 表
	BPB_RootEntCnt	DW 224		;; 根目录文件数最大值
	BPB_TotSec16	DW 2880		;; 逻辑扇区总数
	BPB_Media		DB 0xF0		;; 媒体描述符
	BPB_FATSz16		DW 9			;; 每FAT扇区数
	BPB_SecPerTrk	DW 18			;; 每磁道扇区数
	BPB_NumHeads	DW 2			;; 磁头数(面数)
	BPB_HiddSec		DD 0			;; 隐藏扇区数
	BPB_TotSec32	DD 0			;; wTotalSectorCount为0时这个值记录扇区数
	BS_DrvNum		DB 0			;; 中断 13 的驱动器号
	BS_Reserved1	DB 0			;; 未使用
	BS_BootSig		DB 29h		;; 扩展引导标记 (29h)
	BS_VolID		DD 0			;; 卷序列号
	BS_VolLab		DB 'MyDetaOS0.1'	;; 卷标, 必须 11 个字节
	BS_FileSysType	DB 'FAT12   '	;; 文件系统类型, 必须 8个字节  

LABEL_START:
	mov	ax, cs
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
	mov	sp, BaseOfStack			;;初始化各个寄存器，特别是sp
	
	;; 清屏,详情参考资料库
	mov	ax, 0600h		; AH = 6,  AL = 0h
	mov	bx, 0700h		; 黑底白字(BL = 07h)
	mov	cx, 0			; 左上角: (0, 0)
	mov	dx, 0184fh		; 右下角: (80, 50)
	int	10h			; int 10h
	
	mov	dh, 0			; "Booting  "
	call	DispStr			; 显示字符串

	xor	ah, ah	
	xor	dl, dl	
	int	13h					;; 磁盘系统复位，详情参考资料库
	
;; 以下代码片段是在软盘的根目录寻找 LOADER.BIN.
;; 这个代码是一个简单的三重循环,用C+伪代码来书写就如下面所示
;; for (i=RootDirSectors;i>0;i--)
;;  {
;;	读取从wSectorNo开始一个扇区内容到es：bx所指向的位置;
;; 	使ds:si指向"LOADER  BIN";
;;	使es:di指向BaseOfLoader:OffsetOfLoader;
;;	for(j=10h;j>0;j--)
;;	{
;;		for(k=11;k>0;k--)
;;		{
;;			if(某一个字符不相同)
;;			{
;;				di &= 0FFE0h;		
;;				di += 20h;
;;				si = LoaderFileName;
;;				break;
;;			}
;;		}
;;		if(k==0)for(;;)		
;;	}
;;	wSectorNo++;
;;  }
	mov	word [wSectorNo], SectorNoOfRootDirectory
LABEL_SEARCH_IN_ROOT_DIR_BEGIN:
	cmp	word [wRootDirSizeForLoop], 0	;; 判断根目录区是不是已经读完
	jz	LABEL_NO_LOADERBIN		;; 如果读完表示没有找到 LOADER.BIN
	dec	word [wRootDirSizeForLoop]
	mov	ax, BaseOfLoader
	mov	es, ax				;; es <- BaseOfLoader
	mov	bx, OffsetOfLoader		;; bx <- OffsetOfLoader
	mov	ax, [wSectorNo]			;; ax <- Root Directory 中的某 Sector 号
	mov	cl, 1
	call	ReadSector

	mov	si, LoaderFileName		;; ds:si -> "LOADER  BIN"
	mov	di, OffsetOfLoader		;; es:di -> BaseOfLoader:0100
	cld
	mov	dx, 10h				;;10h=200h(单个扇区字节数)/20h（目录项字节数）
LABEL_SEARCH_FOR_LOADERBIN:
	cmp	dx, 0				   	;; 循环次数控制
	jz	LABEL_GOTO_NEXT_SECTOR_IN_ROOT_DIR
	dec	dx				   	;; 就进入下一个 Sector
	mov	cx, 11
LABEL_CMP_FILENAME:
	cmp	cx, 0
	jz	LABEL_FILENAME_FOUND		;; 如果比较了 11 个字符都相等, 表示找到
	dec	cx
	lodsb						
	cmp	al, byte [es:di]
	jz	LABEL_GO_ON
	jmp	LABEL_DIFFERENT			
	;; 只要发现不一样的字符就表明本 DirectoryEntry不是我们要找的 LOADER.BIN,跳出循环
LABEL_GO_ON:
	inc	di
	jmp	LABEL_CMP_FILENAME		;; 继续循环

LABEL_DIFFERENT:
	and	di, 0FFE0h				
	;; di &= FFE0 为了让它指向本条目开头,因为无法确定di的大小	
	add	di, 20h				;;di += 20h  指向下一个目录条目
	mov	si, LoaderFileName		
	jmp	LABEL_SEARCH_FOR_LOADERBIN

LABEL_GOTO_NEXT_SECTOR_IN_ROOT_DIR:
	add	word [wSectorNo], 1
	jmp	LABEL_SEARCH_IN_ROOT_DIR_BEGIN

LABEL_NO_LOADERBIN:
	mov	dh, 2			;; "No LOADER."
	call	DispStr		;; 打印字符串
	jmp	$			;; 没有找到 LOADER.BIN, 死循环在这里
LABEL_FILENAME_FOUND:		;; 找到 LOADER.BIN 后便来到这里继续
	mov	dh, 1			
	call	DispStr		;; 打印字符串
	jmp	$			;; 代码暂时停在这里
;============================================================================
;变量
wRootDirSizeForLoop	dw	RootDirSectors	;; Root Directory 占用的扇区数, 在循环中会递减至零.
wSectorNo		dw	0	;; 要读取的扇区号

;字符串
LoaderFileName		db	"LOADER  BIN", 0  ;; LOADER.BIN 之文件名
; 为简化代码, 下面每个字符串的长度均为 MessageLength
MessageLength		equ	9
BootMessage:		db	"Booting  " 	;; 9字节, 不够则用空格补齐. 序号 0
Message1			db	"Ready.   " 	;; 9字节, 不够则用空格补齐. 序号 1
Message2			db	"No LOADER" 	;; 9字节, 不够则用空格补齐. 序号 2
;============================================================================

;----------------------------------------------------------------------------
; 函数名: DispStr
;----------------------------------------------------------------------------
; 功能: 利用BIOS的10h号中断调用在屏幕打印字符串, 函数开始时 dh 中应该是字符串序号(0-based)
DispStr:
;;10h中断调用 ah=13h
;;功能：显示字符串
;;参数：ES:BP = 串地址 
;;参数：CX = 串长度 
;;参数：DH，DL = 起始行列 
;;参数：BH = 页号
;;AL = 0，BL = 属性 						光标返回起始位置
;;串：Char，char，……，char
;;AL = 1，BL = 属性 						光标跟随移动
;;串：Char，char，……，char 
;;AL = 2 									光标返回起始位置
;;串：Char，attr，……，char，attr 
;;AL = 3 									光标跟随串移动
;;串：Char，attr，……，char，attr
	mov	ax, MessageLength
	mul	dh
	add	ax, BootMessage
	mov	bp, ax			; `.
	mov	ax, ds			;  | ES:BP = 串地址
	mov	es, ax			; /
	mov	cx, MessageLength	; CX = 串长度
	mov	ax, 01301h		; AH = 13,  AL = 01h
	mov	bx, 0007h		; 页号为0(BH = 0) 黑底白字(BL = 07h)
	mov	dl, 0
	int	10h			; int 10h
	ret
;----------------------------------------------------------------------------
; 函数名: ReadSector
;----------------------------------------------------------------------------
; 作用:
;;	从第 ax 个 Sector 开始, 将 cl 个 Sector 读入 es:bx 中
ReadSector:
;;13h中断调用 ah=02h
;;功能：从软盘中按照扇区号读取相应扇区数的数据
;;参数：ES:BX 为数据缓冲区 
;;参数：AL = 要读扇区数
;;参数：CH = 柱面（磁道）号 ,CL = 起始扇区号 
;;参数：DH = 磁头号 ,DL = 驱动器号 
	
;; 怎样由扇区号求扇区在磁盘中的位置 (扇区号 -> 柱面号, 起始扇区, 磁头号)
;; 设扇区号为 x
;;                                    | 柱面号 = y >> 1
;;       x        | 商   y =>|
;; ----------------  =  ┤            | 磁头号 = y & 1
;;  每磁道扇区数       │ 余数 z =>  起始扇区号 = z + 1
	push	bp
	mov	bp, sp
	sub	esp, 2 		;; 辟出两个字节的堆栈区域保存要读的扇区数: byte [bp-2]

	mov	byte [bp-2], cl
	push	bx			;; 保存 bx
	mov	bl, [BPB_SecPerTrk]	;; bl: 除数
	div	bl			;; y 在 al 中, z 在 ah 中
	inc	ah			;; z ++
	mov	cl, ah		;; cl <- 起始扇区号
	mov	dh, al		;; dh <- y
	shr	al, 1			;; y >> 1 (y/BPB_NumHeads)
	mov	ch, al		;; ch <- 柱面号
	and	dh, 1			;; dh & 1 = 磁头号
	pop	bx			;; 恢复 bx
	;; 至此, "柱面号, 起始扇区, 磁头号" 全部得到
	mov	dl, [BS_DrvNum]	;; 驱动器号 (0 表示 A 盘)
.GoOnReading:
	mov	ah, 2			;; 读
	mov	al, byte [bp-2]	;; 读 al 个扇区
	int	13h
	jc	.GoOnReading	;; 如果读取错误 CF 会被置为 1, 
					;; 这时就不停地读, 直到正确为止
	add	esp, 2
	pop	bp
	ret
times		510-($-$$)	db	0
;;NASM 在表达式中支持两个特殊的记号，即'$'和'$$',它们允许引用当前指令的地址。
;;'$'计算得到它本身所在源代码行的开始处的地址；所以你可以简单地写这样的代码'jmp $'来表示无限循环。
;;'$$'计算当前段开始处的地址，所以你可以通过($-$$)找出你当前在段内的偏移
dw 	0xaa55
;;引导扇区的结束标志
