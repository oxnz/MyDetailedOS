;======================================================================
;                     kliba.asm
;		功能：放置一些杂项函数，作用不定
;======================================================================

;导入全局变量
extern disp_pos
[SECTION .text]

; 导出函数
global	disp_str
global	disp_color_str
global	out_byte
global	in_byte

; ========================================================================
;                  void disp_str(char * info);
;	功能：将以info指针为首开始的字符串打印，主要处理的是换行符
;	，另外结束字符是0x0.
; ========================================================================
disp_str:
	push	ebp
	mov	ebp, esp

	mov	esi, [ebp + 8]	; pszInfo
	mov	edi, [disp_pos]
	mov	ah, 0Fh
.1:
	lodsb
	test	al, al
	jz	.2
	cmp	al, 0Ah	; 是回车吗?
	jnz	.3
	push	eax
	mov	eax, edi
	mov	bl, 160
	div	bl
	and	eax, 0FFh
	inc	eax
	mov	bl, 160
	mul	bl
	mov	edi, eax
	pop	eax
	jmp	.1
.3:
	mov	[gs:edi], ax
	add	edi, 2
	jmp	.1

.2:
	mov	[disp_pos], edi

	pop	ebp
	ret

; ========================================================================
;      void disp_color_str(char * info, int color);
; 	功能：比disp_str多了一个功能，就是颜色的设置，而disp_str
;		对于颜色的设置是定死的 。(ah = 0Fh,黑地白字)
; ========================================================================
disp_color_str:
	push	ebp
	mov	ebp, esp

	mov	esi, [ebp + 8]	; pszInfo
	mov	edi, [disp_pos]
	mov	ah, [ebp + 12]	; color
.1:
	lodsb
	test	al, al
	jz	.2
	cmp	al, 0Ah	; 是回车吗?
	jnz	.3
	push	eax
	mov	eax, edi
	mov	bl, 160
	div	bl
	and	eax, 0FFh
	inc	eax
	mov	bl, 160
	mul	bl
	mov	edi, eax
	pop	eax
	jmp	.1
.3:
	mov	[gs:edi], ax
	add	edi, 2
	jmp	.1

.2:
	mov	[disp_pos], edi

	pop	ebp
	ret

; ========================================================================
;                void out_byte(u16 port, u8 value);
;			功能：向端口port发送数据value
; ========================================================================
out_byte:
	mov	dx, [esp + 4]		; port
	mov	al, [esp + 4 + 4]	; value
	out	dx, al
	nop	; 一点延迟
	nop
	ret

; ========================================================================
;                  u8 in_byte(u16 port);
;		功能：从端口port接受数据，放入al中，由于调用约定，
;		返回值在eax中，所以函数返回al中的值。
; ========================================================================
in_byte:
	mov	dx, [esp + 4]		; port
	xor	ax, ax
	in	al, dx
	nop	; 一点延迟
	nop
	ret

