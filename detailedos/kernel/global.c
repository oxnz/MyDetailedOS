/*======================================================================
                        global.c
			功能：声明各种全局变量
========================================================================*/

#include "type.h"
#include "const.h"
#include "protect.h"


int		disp_pos;
u8		  gdt_ptr[6];	/* 0~15:Limit  16~47:Base */
DESCRIPTOR	  gdt[GDT_SIZE];
u8		  idt_ptr[6];	/* 0~15:Limit  16~47:Base */
GATE		  idt[IDT_SIZE];

