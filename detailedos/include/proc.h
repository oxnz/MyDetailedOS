/*======================================================================
                           proc.h
			功能：放置系统中进程的一些数据结构和宏
========================================================================*/
#ifndef	_MYDETAOS_PROC_H_
#define	_MYDETAOS_PROC_H_

/* 引用其他头文件，保证头文件可以单独可以使用 */
#include "protect.h"
#include "type.h"
typedef struct s_stackframe {
	u32	gs;		/*                                     */
	u32	fs;		/*                                     */
	u32	es;		/*                                     */
	u32	ds;		/*                                     */
	u32	edi;		/*                                     */
	u32	esi;		/*  pushed by save()                   */
	u32	ebp;		/*                                     */
	u32	kernel_esp;	/*  'popad' will ignore it             */
	u32	ebx;		/*                                     */
	u32	edx;		/*                                     */
	u32	ecx;		/*                                     */
	u32	eax;		/*                                     */
	u32	retaddr;	/* return addr for kernel.asm::save()  */
	u32	eip;		/*                                     */
	u32	cs;		/*                                     */
	u32	eflags;	/*  pushed by CPU during interrupt     */
	u32	esp;		/*                                     */
	u32	ss;		/*                                     */
}STACK_FRAME;


typedef struct s_proc {
	STACK_FRAME regs;          /* process registers saved in stack frame */
	u16 ldt_sel;               /* gdt selector giving ldt base and limit */
	DESCRIPTOR ldts[LDT_SIZE]; /* local descriptors for code and data */
	u32 pid;                   /* process id passed in from MM */
	char p_name[16];           /* name of the process */
}PROCESS;


/* Number of tasks */
#define NR_TASKS	1

/* stacks of tasks */
#define STACK_SIZE_TESTA	0x8000

#define STACK_SIZE_TOTAL	STACK_SIZE_TESTA

#endif