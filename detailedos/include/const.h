/*======================================================================
                           const.h
			功能：放置系统中大部分的常量
========================================================================*/
#ifndef	_MYDETAOS_CONST_H_
#define	_MYDETAOS_CONST_H_

/* 函数类型 */
#define	PUBLIC			/* PUBLIC is the opposite of PRIVATE */
#define	PRIVATE	static	/* PRIVATE x limits the scope of x */

/* GDT 和 IDT 中描述符的个数 */
#define	GDT_SIZE	128
#define 	IDT_SIZE	256


/*Color Set , 为函数disp_color_str 的第二个参数准备，详情请参考于渊老师的书pdf第286页 */
#define BLACK 	 	0X0 	/* 0000 */
#define WHITE		0x7 	/* 0111 */
#define RED			0x4 	/* 0100 */
#define GREEN 		0x2 	/* 0010 */
#define BLUE		0x1 	/* 0001 */
#define FLASH		0x80 	/* 1000 0000 */
#define BRIGHT		0x08 	/* 0000 1000 */
#define MAKE_COLOR(x,y) ((x<<4)|y) /* MAKE_COLOR(Background,Foreground) */

/* 权限 */
#define	PRIVILEGE_KRNL	0
#define	PRIVILEGE_TASK	1
#define	PRIVILEGE_USER	3

/* RPL */
#define	RPL_KRNL	SA_RPL0
#define	RPL_TASK	SA_RPL1
#define	RPL_USER	SA_RPL3

/* 8259A interrupt controller ports */
#define INT_M_CTL	0x20
#define INT_S_CTL	0xA0
#define INT_M_CTLMASK	0x21
#define INT_S_CTLMASK	0xA1

#endif
