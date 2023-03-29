;----------------------------------------------------------------
;	kernel.asm
;Descriptor:
;	Kernel header, prepare paramenter for kernel.c
;----------------------------------------------------------------

;Extern functions, in kernel.c
extern kinit

[bits 32]
[section .bss]
stack_space	resb	2048	;2K stack
kstack_top:

[section .text]
global	_start
_start:
	call	kinit

;never return here
	hlt
