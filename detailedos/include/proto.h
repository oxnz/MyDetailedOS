/*======================================================================
                           const.h
			功能：放置系统中全局的函数声明
========================================================================*/
#ifndef	_MYDETAOS_PROTO_H_
#define	_MYDETAOS_PROTO_H_

/* 引用其他头文件，保证头文件可以单独可以使用 */
#include "const.h"
#include "type.h"

/* klib.asm */
PUBLIC void	out_byte(u16 port, u8 value);
PUBLIC u8	in_byte(u16 port);
PUBLIC void	disp_str(char * info);
PUBLIC void	disp_color_str(char * info, int color);
/* protect.c */
PUBLIC void	init_prot();
/* i8259.c */
PUBLIC void	init_8259A();
/* klib.c */
PUBLIC void disp_int(int input);

#endif
