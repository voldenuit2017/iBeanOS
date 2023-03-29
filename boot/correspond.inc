;--------------------------------------------------------------------------------
;	boot/correspond.inc
;Descriptor:
;	This file is just for const values corresponding between Boot-part,
;Kernel-part and Makefile. The most thing are about the memory layout.
;--------------------------------------------------------------------------------

;This Value is corresponding with Makefile ld paramenter -Ttext
KERNEL_PHY_ENTER	equ	0x30400
