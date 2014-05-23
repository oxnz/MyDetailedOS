BaseOfLoader		equ	09000h	; LOADER.BIN 被加载到的位置 ----  段地址
OffsetOfLoader		equ	0100h		; LOADER.BIN 被加载到的位置 ---- 偏移地址

BaseOfLoaderPhyAddr equ	BaseOfLoader*10h ; LOADER.BIN 被加载到的位置 ---- 物理地址

BaseOfKernel		equ	 08000h	; KERNEL.ELF 被加载到的位置 ---- 段地址
OffsetOfKernel		equ	     0h	; KERNEL.ELF 被加载到的位置 ---- 偏移地址

BaseOfKernelPhyAddr	equ	BaseOfKernel * 10h
KernelEntryPointPhyAddr	equ	030400h	
; 注意：1、必须与 MAKEFILE 中参数 -Ttext 的值相等!!
;        2、这是个地址而非仅仅是个偏移，如果 -Ttext 的值为 0x400400，则它的值也应该是 0x400400。

PageDirBase			equ	100000h	; 页目录开始地址: 1M
PageTblBase			equ	101000h	; 页表开始地址:   1M + 4K

