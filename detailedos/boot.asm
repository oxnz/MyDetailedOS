org	07c00h
;;它告诉编译器，程序被载入内存的初始偏移地址为0x7c00h，
;;因此编译产生的代码中，涉及MOV等指令的标号的偏移量都加上了0x7c00h,
;;常量并不会发生变化
	
;;关于PBP的详情，请看以下参考资料
;;让操作系统走进保护模式(知识个人总结精华版)
;;软盘结构，FAT文件系统，FAT文件系统白皮书
	jmp short LABEL_START		; Start to boot.
	nop				; 这个 nop 不可少

	; 下面是 FAT12 磁盘的头
	BS_OEMName		DB 'MSWIN4.1'	; OEM String, 必须 8 个字节
	BPB_BytsPerSec	DW 512		; 每扇区字节数
	BPB_SecPerClus	DB 1		; 每簇多少扇区
	BPB_RsvdSecCnt	DW 1		; Boot 记录占用多少扇区
	BPB_NumFATs		DB 2		; 共有多少 FAT 表
	BPB_RootEntCnt	DW 224		; 根目录文件数最大值
	BPB_TotSec16	DW 2880		; 逻辑扇区总数
	BPB_Media		DB 0xF0		; 媒体描述符
	BPB_FATSz16		DW 9		; 每FAT扇区数
	BPB_SecPerTrk	DW 18		; 每磁道扇区数
	BPB_NumHeads	DW 2		; 磁头数(面数)
	BPB_HiddSec		DD 0		; 隐藏扇区数
	BPB_TotSec32	DD 0		; wTotalSectorCount为0时这个值记录扇区数
	BS_DrvNum		DB 0		; 中断 13 的驱动器号
	BS_Reserved1	DB 0		; 未使用
	BS_BootSig		DB 29h		; 扩展引导标记 (29h)
	BS_VolID		DD 0		; 卷序列号
	BS_VolLab		DB 'MyDetaOS001'; 卷标, 必须 11 个字节
	BS_FileSysType	DB 'FAT12   '	; 文件系统类型, 必须 8个字节  

LABEL_START:
	mov 	ax, cs
	mov 	ds, ax
	mov 	es, ax
	;;初始化各个段寄存器
	call	DispStr
	jmp 	$
DispStr:
;;这是一个简单地函数，功能是利用BIOS的10h号中断调用在屏幕打印字符串
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
	mov 	ax, BootMessage
	mov 	bp, ax
   	mov  	cx, LengthOfBootMessage	;;这样比硬编码要有健壮性
	mov 	ax, 01301h
 	mov 	bx, 000ch
	mov 	dl, 0
	int 	10h
	ret
BootMessage: 		db  	"Hello, OS World!"
LengthOfBootMessage 	equ	$ - BootMessage
times		510-($-$$)	db	0
;;NASM 在表达式中支持两个特殊的记号，即'$'和'$$',它们允许引用当前指令的地址。
;;'$'计算得到它本身所在源代码行的开始处的地址；所以你可以简单地写这样的代码'jmp $'来表示无限循环。
;;'$$'计算当前段开始处的地址，所以你可以通过($-$$)找出你当前在段内的偏移
dw 	0xaa55
;;引导扇区的结束标志
