/*======================================================================
                      protect.h
功能：放置一些保护模式需要的数据类型定义或者跟保护模式有关的宏之类的
========================================================================*/
#ifndef	_MYDETAOS_PROTECT_H_
#define	_MYDETAOS_PROTECT_H_

#include "type.h"

/* 存储段描述符/系统段描述符,详情参考pm.inc或者资料库中于渊和赵炯老师的书 */
typedef struct s_descriptor		 /* 共 8 个字节 */
{
	u16	limit_low;			/* Limit */
	u16	base_low;			/* Base */
	u8	base_mid;			/* Base */
	u8	attr1;			/* P(1) DPL(2) DT(1) TYPE(4) */
	u8	limit_high_attr2;		/* G(1) D(1) 0(1) AVL(1) LimitHigh(4) */
	u8	base_high;			/* Base */
}DESCRIPTOR;

#endif 
