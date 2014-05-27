/*======================================================================
                        main.c
========================================================================*/
#include "const.h"
#include "proto.h"
#include "proc.h"
#include "global.h"
#include "string.h"
#include "protect.h"

/*======================================================================*
                            kernel_main
			功能：内核正式开始运行进程。
 *======================================================================*/
//引导判断中断重入的标志，因为这个变量在此处初始化。
extern int k_reenter;

PUBLIC int kernel_main()
{
	disp_str("----------kernel start----------\n");

	TASK *p_task = task_table;
	PROCESS *p_proc = proc_table;
	char *p_stack_size = task_stack + STACK_SIZE_TOTAL;
	u16  selector_ldt = SELECTOR_LDT_FIRST;
	int  i; 
	for(i=0;i<NR_TASKS;i++)
	{
		strcpy(p_proc->p_name , p_task->name);
		p_proc->pid = i;
		p_proc->ldt_sel = selector_ldt;
		memcpy(&p_proc->ldts[0],&gdt[SELECTOR_KERNEL_CS >> 3],sizeof(DESCRIPTOR));
		p_proc->ldts[0].attr1 = DA_C | PRIVILEGE_TASK << 5;
		memcpy(&p_proc->ldts[1],&gdt[SELECTOR_KERNEL_DS >> 3],sizeof(DESCRIPTOR));
		p_proc->ldts[1].attr1 = DA_DRW | PRIVILEGE_TASK << 5;
	
		p_proc->regs.cs = ((8*0)& SA_RPL_MASK & SA_TI_MASK) | SA_TIL |RPL_TASK;
		p_proc->regs.ds = ((8*1) & SA_RPL_MASK & SA_TI_MASK) | SA_TIL |RPL_TASK;
		p_proc->regs.es = ((8*1) & SA_RPL_MASK & SA_TI_MASK) | SA_TIL |RPL_TASK;
		p_proc->regs.fs = ((8*1) & SA_RPL_MASK & SA_TI_MASK) | SA_TIL |RPL_TASK;
		p_proc->regs.ss = ((8*1) & SA_RPL_MASK & SA_TI_MASK) | SA_TIL |RPL_TASK;
		p_proc->regs.gs = (SELECTOR_KERNEL_GS & SA_RPL_MASK) |RPL_TASK;
	
		p_proc->regs.eip = (u32)p_task->initial_eip;
		p_proc->regs.esp = (u32)p_stack_size;

		p_proc->regs.eflags = 0x1202;
		
		selector_ldt +=1 << 3;
		p_proc++;
		p_task++;
		p_stack_size -=p_task->stacksize;
			
	}
	k_reenter 		= -1;
	p_proc_ready	= proc_table;
	restart();

	while(1){}
}

/*======================================================================*
                        TestA
		功能：一个测试使用的用户级程序代码
 *======================================================================*/
void TestA()
{
	int i = 0;
	while(1){
		disp_str("A");
		disp_int(i++);
		disp_str(".");
		delay(2);
	}
}
/*======================================================================*
                        TestB
 功能：一个和TestB类似，但是显示稍有区别的测试使用的用户级程序代码
 *======================================================================*/
PUBLIC void TestB()
{
	int i=0x1000;
	while(1)
	{
	   disp_str("B");
	   disp_int(i++);
	   disp_str(".");
	   delay(1);
	}
}
