;======================================================================
;                     string.asm
;		功能：放置系统中使用到的所有有关字符串的函数
;======================================================================

[SECTION .text]

; 导出函数
global	memcpy
global	memset

; =========================================================================
; void* memcpy(void* es:pDest, void* ds:pSrc, int iSize);
; =========================================================================
memcpy:
	push ebp
	mov ebp,esp
	
	push esi
	push edi
	push ecx 
	mov edi,[ebp+8]
	mov esi,[ebp+12]
	mov ecx,[ebp+16]

	cld
	rep movsb
	
	mov eax,[ebp+8]
	
	pop ecx
	pop edi
	pop esi
	
	pop ebp

	ret 	; 函数结束，返回
; memcpy 结束

; =========================================================================
; void memset(void* p_dst, char ch, int size);
; =========================================================================
memset:
	push ebp
	mov ebp,esp

	push edi
	push ecx
	mov edi,[ebp+8]		; Destination
	mov eax,[ebp+12]		; Char to be put
	mov ecx,[ebp+16]		; Counter
	
	cld
	rep stosb
	
	pop ecx
	pop edi
	pop ebp
	ret				; 函数结束，返回
; memset 结束

