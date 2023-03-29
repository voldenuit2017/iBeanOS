;---------------------------------------------------------------------
;	lib/klib.asm
;---------------------------------------------------------------------

[section .data]
extern	disp_pos

[section .text]

;------------------- void disp_str( char *buf ) -------------------
global	disp_str
disp_str:
	push	ebp
	mov	ebp, esp
	
	mov	esi, [ebp+8]	; get char *buf
	mov	edi, [disp_pos]
	mov	ah, 0xf

.loop:
	lodsb
;if the value is zero, then the function terminated
	test	al, al
	jz	.done
	cmp	edi, ( 80 * 25 * 2 )
	jz	.done
;if the char is enter, then just newline
	cmp	al, 0xa
	jnz	.show
	push	eax
	mov	eax, edi
	mov	bl, 160
	div	bl
	and	eax, 0xff
	inc	eax
	mov	bl, 160
	mul	bl
	mov	edi, eax
	pop	eax
	jmp	.loop

.show:
	mov	[gs:edi], ax
	add	edi, 2
	jmp	.loop

.done:
	mov	[disp_pos], edi
	pop	ebp
	ret

;---------- void memset( void *dst, char ch, int size );
global memset
memset:
	push	ebp
	mov	ebp, esp
	push	esi
	push	edi
	push	ecx

	mov	edi, [ebp+8]	;Destination
	mov	edx, [ebp+12]	;Char to be setted
	mov	ecx, [ebp+16]	;Counter

.loop:
	mov	byte [edi], dl
	inc	edi
	loop	.loop

	pop	ecx
	pop	edi
	pop	esi
	mov	esp, ebp
	pop	ebp
	ret

;-------------------- char *strcpy( char *dst, char *src );
global strcpy
strcpy:
	push	ebp
	mov	ebp, esp
	
	mov	esi, [ebp+12]	;Source
	mov	edi, [ebp+8]	;Destination

.loop:
	mov	al, [esi]
	inc	esi
	mov	byte [edi], al
	inc	edi
	cmp	al, 0
	jnz	.loop
	mov	eax, [ebp+8]

	pop	ebp
	ret

;-------------- int strlen( char *str )
global strlen
strlen:
	push	ebp
	mov	ebp, esp
	mov	eax, 0
	mov	esi, [ebp+8]
.loop:
	cmp	byte [esi], 0
	jz	.done
	inc	esi
	inc	eax
	jmp	.loop
.done:
	pop	ebp
	ret

;-------------void* memcpy( void *dest, void *src, int size )
global memcpy
memcpy:
	push	ebp
	mov	ebp, esp
	push	esi
	push	edi
	push	ecx
	
;get the paramter from stack, ebp+4 is ebp, ebp+0 is function return address
	mov	edi, [ebp+8]	; *dest
	mov	esi, [ebp+12]	; *src
	mov	ecx, [ebp+16]	; size

.loop:
	cmp	ecx, 0
	jz	.done
	
	mov	al, [ds:esi]
	inc	esi
	mov	byte [es:edi], al
	inc	edi
	dec	ecx
	jmp	.loop	

.done:
	mov	eax, [ebp+8]
	pop	ecx
	pop	edi
	pop	esi
	mov	esp, ebp
	pop	ebp
	ret
