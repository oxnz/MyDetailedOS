org	07c00h
;;它告诉编译器，程序被载入内存的初始偏移地址为0x7c00h，
;;因此编译产生的代码中，涉及MOV等指令的标号的偏移量都加上了0x7c00h,
;;常量并不会发生变化
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
   	mov  	cx, 16
	mov 	ax, 01301h
 	mov 	bx, 000ch
	mov 	dl, 0
	int 	10h
	ret
BootMessage: 	db  	"Hello, OS World!"
times	510-($-$$)	db	0
;;NASM 在表达式中支持两个特殊的记号，即'$'和'$$',它们允许引用当前指令的地址。
;;'$'计算得到它本身所在源代码行的开始处的地址；所以你可以简单地写这样的代码'jmp $'来表示无限循环。
;;'$$'计算当前段开始处的地址，所以你可以通过($-$$)找出你当前在段内的偏移
dw 	0xaa55
;;引导扇区的结束标志
