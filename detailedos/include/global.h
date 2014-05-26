/*======================================================================
                      global.h
		功能：放置一些系统的全局变量声明
========================================================================*/
#ifndef	_MYDETAOS_GLOBAL_H_
#define	_MYDETAOS_GLOBAL_H_

/* 引用其他头文件，保证头文件可以单独可以使用 */
#include "type.h"
#include "protect.h"
#include "proc.h"

extern	int		disp_pos;
extern	u8		gdt_ptr[];	/* 0~15:Limit  16~47:Base */
extern	DESCRIPTOR	gdt[];
extern	u8		idt_ptr[];	/* 0~15:Limit  16~47:Base */
extern	GATE		idt[];
extern PROCESS	proc_table[];
extern char		task_stack[];
extern TSS		tss;
extern PROCESS*	p_proc_ready;

#endif
