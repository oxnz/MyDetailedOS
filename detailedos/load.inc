BaseOfLoader		equ	09000h	; LOADER.BIN 被加载到的位置 ----  段地址
OffsetOfLoader		equ	0100h		; LOADER.BIN 被加载到的位置 ---- 偏移地址

BaseOfLoaderPhyAddr equ	BaseOfLoader*10h ; LOADER.BIN 被加载到的位置 ---- 物理地址

BaseOfKernel		equ	 08000h	; KERNEL.ELF 被加载到的位置 ---- 段地址
OffsetOfKernel		equ	     0h	; KERNEL.ELF 被加载到的位置 ---- 偏移地址
