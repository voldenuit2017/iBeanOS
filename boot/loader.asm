;-----------------------------------------------------------------------
;	iBean OS loader
;		Study by Yang Tingguang @ 2012.12
;Setup:
;Stage A : real mode
;	1: Get memory layout and size
;	2: Load kernel.bin
;	3: Load GDT pointer to GDTR
;	4: Enable A20
;	5: Set CR0.PE bit
;	6: Jump into protect mode segment
;Stage B : protect mode
;	1: Display memory layout
;	2: Setup Page ( Build PDT and PET, enable CR0.PG etc )
;	3: Init kernel, i.e. load kerel.bin but in ELF-format
;	4: Jump into kenel start address. 
;-----------------------------------------------------------------------


;====================================== Stage A : Real Mode =========================================
org 0x100
jmp stage_a_start

%include "fat12.inc"
%include "loader.inc"
%include "x86arch.inc"
%include "correspond.inc"

;-------------------------------------- GDT -------------------------------------------------------
;				Base	Limit   Attribute
GDT_NULL:	Descriptor	0,	0,	0				
GDTD_FLAT_C:	Descriptor	0x0,	0xfffff,DAC_ER | DA_32s | DA_LIMIT_4K	; 0 ~ 4G
GDTD_FLAT_RW:	Descriptor	0x0,	0xfffff,DAD_RW | DA_32s | DA_LIMIT_4K	; 0 ~ 4G
GDTD_VIDEO:	Descriptor	0xB8000,0xffff,	DAD_RW | DA_DPL3		; Grapic RAM

GDT_len		equ	$ - GDT_NULL
GDT_ptr		dw	GDT_len - 1	
		dd	LOAD_PHY_ADDR + GDT_NULL	

; GDT Selector	----------------------------------------------------------------------------------
sel_faltc	equ	GDTD_FLAT_C	- GDT_NULL
sel_faltrw	equ	GDTD_FLAT_RW	- GDT_NULL
sel_video	equ	GDTD_VIDEO	- GDT_NULL + SA_RPL3

stack_base	equ	LOAD_OFFSET

stage_a_start:
	mov	ax, cs
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
	mov	sp, stack_base



	mov	si, msg_loading
	call	puts
	call	get_mem_info
	call	load_kernel_file
	call	kill_motor	
	mov	si, msg_ready
	call	puts
	
	lgdt	[GDT_ptr]
	cli
	; Open the A20 line
	in	al, 0x92
	or	al, 00000010b
	out	0x92, al
	;SET CR0:PE bit, after that, Protect Mode enabled.
	mov	eax, cr0
	or	eax, 1
	mov	cr0, eax

	jmp	dword sel_faltc:(LOAD_PHY_ADDR+label_pm_start)


;------------------------------------------------------------------------------
; Variables and	string in real mode
sector_cnt	dw	ROOT_DIR_SECTORS	
setcor_idx	dw	0		
is_odd		db	0		
kernel_size	dd	0		

kfile_name	db	"KERNEL  BIN", 0	
msg_loading	db	0xd, "Loading", 0
msg_failed	db	"Failed! There is no kernel.bin in disk.", 0xa, 0
msg_ready	db	" DONE!", 0xa, 0
msg_point	db	".", 0


;----------------------------- get_mem_info --------------------------------
get_mem_info:
	mov	ebx, 0			
	mov	di, _MemChkBuf		; es:di point to Address Range Descriptor Structure
.MemChkLoop:
	mov	eax, 0xE820		; eax = 0000E820h
	mov	ecx, 20			; ecx = size of structure ARDS 
	mov	edx, 0x534D4150		; edx = 'SMAP'
	int	0x15			; int 15h
	jc	.MemChkFail
	add	di, 20
	inc	dword [_MCRNumber]	; MCRNumber = number of ARDS
	cmp	ebx, 0
	jne	.MemChkLoop
	jmp	.MemChkOK
.MemChkFail:
	mov	dword [_MCRNumber], 0
.MemChkOK:
	ret


;------------------------- load the file of kernel.bin -------------------------------
load_kernel_file:
	mov	word [setcor_idx], ROOT_DIR_START	
	xor	ah, ah	
	xor	dl, dl	
	int	0x13
.begin:
	cmp	word [sector_cnt], 0	
	jz	.miss
	dec	word [sector_cnt]	
	mov	ax, KFILE_SEG
	mov	es, ax				; es <- KFILE_SEG
	mov	bx, KFILE_OFFSET		; bx <- KFILE_OFFSET
	mov	ax, [setcor_idx]	
	mov	cl, 1
	call	read_sector

	mov	si, kfile_name			; ds:si -> "KERNEL  BIN"
	mov	di, KFILE_OFFSET	
	cld
	mov	dx, 0x10
.loop_search:
	cmp	dx, 0					
	jz	.next_sector	
	dec	dx					
	mov	cx, 11
.compare:
	cmp	cx, 0			
	jz	.found	
	dec	cx		
	lodsb				; ds:si -> al
	cmp	al, byte [es:di]	; if al == es:di
	jz	.continue
	jmp	.diff
.continue:
	inc	di
	jmp	.compare

.diff:
	and	di, 0xFFE0
	add	di, 0x20		
	mov	si, kfile_name	
	jmp	.loop_search

.next_sector:
	add	word [setcor_idx], 1
	jmp	.begin

.miss:
	mov	si, msg_failed
	call	puts
	jmp	$

.found:
	mov	ax, ROOT_DIR_SECTORS
	and	di, 0xFFF0

	push	eax
	mov	eax, [es:di+0x1c]
	mov	dword [kernel_size], eax
	pop	eax

	add	di, 0x1a	
	mov	cx, word [es:di]
	push	cx			
	add	cx, ax
	add	cx, DELTA_SECTOR_NO	
	mov	ax, KFILE_SEG
	mov	es, ax			
	mov	bx, KFILE_OFFSET	
	mov	ax, cx	

.loop_load:
	mov	si, msg_point
	call	puts
		
	mov	cl, 1
	call	read_sector
	pop	ax		
	call	get_fat_entry
	cmp	ax, 0xFFF
	jz	.done
	push	ax	
	mov	dx, ROOT_DIR_SECTORS
	add	ax, dx
	add	ax, DELTA_SECTOR_NO
	add	bx, [BPB_BytsPerSec]
	jmp	.loop_load
.done:

ret


;------------------------- read_sector --------------------------
;#c=#lba/(S*H)
;#h=(#lba/S)%H
;#s=(#lba%S)+1
;ax sctors   cl sctor number   es:bx space
read_sector:	
	push	bp
	mov	[sectors_st], ax
	mov	[sectors_rd], cl
	push	bx

	mov	bl, 36 ;18*2	
	div	bl
	mov	[cylind_ch], al

	mov	ax, [sectors_st]
	mov	bl, 18
	div	bl
	and	ax, 0x1
	mov	[header_dh], al

	mov	ax, [sectors_st]
	mov	bl, 18
	div	bl
	inc	ah
	mov	[sector_cl], ah

	mov	dh, [header_dh]
	mov	ch, [cylind_ch]
	mov	cl, [sector_cl]
	mov	dl, 0	;A disk
	pop	bx
.loop:
	mov	ah, 2	;int 0x13 funtion 2
	mov	al, [sectors_rd]
	int	0x13
	jc	.loop
	pop	bp
	ret
sector_cl	db	0
cylind_ch	db	0
header_dh	db	0
sectors_rd	db	0
sectors_st	dw	0	;start sector number


;--------------------------- get_fat_entry --------------------------------
;find the setor in FAT by index = ax, 
;read the temp data in es:bx [0x8ff0:0x00], behind Baseofloader , 4k
get_fat_entry:
	push	es
	push	bx
	push	ax
;4K space for buffer
	mov	ax, LOAD_SEG	
	sub	ax, 0x100
	mov	es, ax			
	pop	ax
;Odd or even
	mov	byte [is_odd], 0
	mov	bx, 3
	mul	bx			; dx:ax = ax * 3
	mov	bx, 2
	div	bx			
	cmp	dx, 0
	jz	.even
	mov	byte [is_odd], 1
.even:
	xor	dx, dx			
	mov	bx, [BPB_BytsPerSec]
	div	bx			
					
	push	dx
	mov	bx, 0			
	inc	ax
	mov	cl, 2
	call	read_sector	
	pop	dx
	add	bx, dx
	mov	ax, [es:bx]
	cmp	byte [is_odd], 1
	jnz	.even2
	shr	ax, 4
.even2:
	and	ax, 0xFFF

	pop	bx
	pop	es
	ret
;----------------------------------------------------------------------------

;---------------------------- puts -----------------------------
;put string in srceen, si as input
puts:
	pusha
	mov	ah, 0x0e
	mov	bh, 0x00
	mov	bl, 0x01	
.loop:	
	lodsb
	test	al,al
	jz	.done
	int	0x10
	jmp	.loop
.done:	
	popa
	ret
;---------------------------- kill_motor ------------------------------
;Kill motor, stop the Floppy LED and motor
kill_motor:
	push	dx
	mov	dx, 0x3F2
	mov	al, 0
	out	dx, al
	pop	dx
	ret



;=============================== Stage B : Protect Mode ===================================
;---------------------------- 32-Bit Codes ----------------------------------
[SECTION .s32]
ALIGN	32
[BITS	32]
label_pm_start:

;Set enviroment
mov	ax, sel_video
mov	gs, ax
mov	ax, sel_faltrw
mov	ds, ax
mov	es, ax
mov	fs, ax
mov	ss, ax
mov	esp, TopOfStack

;Clear srceen and set color
call	clrsrc
mov	ah, COLOR_BLACK
mov	al, COLOR_YELLOW
call	setcolor 
mov	esi, pm_msg_setpage
call	pm_puts

;Display memory layout
mov	esi, pm_msg_meminfo
call	pm_puts
mov	ah, COLOR_BLACK
mov	al, COLOR_GREEN
call	setcolor
mov	esi, MemChkTitle
call	pm_puts
call	DispMemInfo
call	newline

;jmp $
;Setup paging
mov	esi, pm_msg_setpage
call	pm_puts
call	setup_paging

;Init kernel file by ELF-format
mov	esi, pm_msg_initk
call	pm_puts
call	init_kernel


call	clrsrc
mov	ah, COLOR_BLACK
mov	al, COLOR_GREEN
call	setcolor
mov	esi, pm_msg_welcome
call	pm_puts
mov	ah, COLOR_BLACK
mov	al, COLOR_YELLOW
call	setcolor
mov	esi, pm_msg_author
call	pm_puts
;Jump into kernel

;Prepare communication paraments
;Fill in BootParm[]
mov	dword [BOOT_PARAM_ADDR], BOOT_PARAM_MAGIC
mov	eax, [MemSize]
mov	[BOOT_PARAM_ADDR+4], eax	;memory size
mov	eax, KFILE_SEG
shl	eax, 4
add	eax, KFILE_OFFSET
mov	[BOOT_PARAM_ADDR+8], eax	;phy-addr of kernel.bin

mov eax, dword [MCRNumber]
mov dword [0x920], eax

mov eax, 256
push eax
mov eax, MemChkBuf
push eax
mov eax, 0x930
push eax
call memcpy


jmp	sel_faltc:KERNEL_PHY_ENTER


;-------------------------------------- Support Functions -----------------------------
;---------------------------esi as input
pm_putchar:
	push	ebx
	mov	ebx, vrampos
	
	and	esi, 0xff
	cmp	si, 0x0a
	jnz	.do_putchar		;If the char is 0x0a, set newline
	call	get_cur_col
	neg	eax
	add	eax, 160
	add	eax, [ebx]
	jmp	.done
.do_putchar:
	mov	eax, [ebx]
	cmp	eax, VRAM_END	
	ja	.done	
	or	si, [ccolor]		;Set the color
	mov	[gs:eax], si
	add	eax, 2
.done:
	mov	[ebx], eax		;Write the current RAM position back
	pop	ebx
	ret

;--------------------------- get_cur_col
;eax as current colume
get_cur_col:
	push	ebx
	mov	eax, [vrampos]
	mov	bl, 160
	div	bl
	movzx	eax, ah
	pop	ebx
	ret

;---------------- clrsrc ----------------
;inputs:	none
;outputs:	none
clrsrc:
	push	ecx
	mov	ecx, VRAM_END
	mov	[ccolor], word 0x0f00
	mov	[vrampos], dword 0
.loop:
	mov	esi, 0x20
	call	pm_putchar	
	loop	.loop
	mov	[ccolor], word 0x0f00
	mov	[vrampos], dword 0x0
	pop	ecx
	ret

;---------------- puts ----------------
;inputs:	esi: string pointer
;outputs:	none
pm_puts:
	push	ebx
	mov	ebx, esi
	test	ebx, ebx
	jz	.done
.loop:
	mov	al, [ebx]
	test	al, al
	jz	.done
	mov	esi, eax
	call	pm_putchar
	inc	ebx
	jmp	.loop
.done:
	pop	ebx
	ret


;---------------- setcolor ----------------
;inputs:	ah : Background color
;		al : Frontground color
;outputs:	none
setcolor:
	push	ebx
	and	ax, 0xffff
	mov	bx, ax
	shr	bx, 4 
	or	ax, bx
	shl	ax, 8 
	mov	[ccolor], ax
	pop	ebx
	ret

;---------------- newline ----------------
;inputs:	none
;outputs:	none
newline:
	push	esi
	mov	esi, 0x0a
	call	pm_putchar
	pop	esi
	ret


;-----------------------------
;input		esi : hex number
;output		eax : char
hex2char:
	push	esi
	and	esi, 0x0f
	movzx	eax, byte [charidx+esi]
	pop	esi
	ret

;----------------- hex2str4 ----------------
;input esi,hex;  edi: buffer 9
hex2str4:
        push	ecx
        push	esi
	push	edi

        mov	ecx, 8
.loop:
        rol	esi, 4
        call	hex2char
        mov	byte [edi], al
        inc	edi
        dec	ecx
        jnz	.loop
        mov	byte [edi], 0

	pop	edi
        pop	esi
        pop	ecx
        ret



;---------------- print_hex4 -------------
;input :	esi hexval
print_hex4:
	push	edi
	
	mov	edi, hexbuf4
	call	hex2str4
	mov	esi, hexbuf4
	call	pm_puts

	pop	edi
	ret

; ------------------------------------------------------------------------
; void* memcpy(void* es:pDest, void* ds:pSrc, int iSize);
memcpy:
	push	ebp
	mov	ebp, esp

	push	esi
	push	edi
	push	ecx

	mov	edi, [ebp + 8]	; Destination
	mov	esi, [ebp + 12]	; Source
	mov	ecx, [ebp + 16]	; Counter
.loop:
	cmp	ecx, 0		; Counter controller
	jz	.done

;move byte by byte
	mov	al, [ds:esi]		
	inc	esi
	mov	byte [es:edi], al	
	inc	edi			

	dec	ecx		
	jmp	.loop
.done:
	mov	eax, [ebp + 8]	; return value

	pop	ecx
	pop	edi
	pop	esi
	mov	esp, ebp
	pop	ebp

	ret	


;---------------------Dump memory information ( by ARDS )
DispMemInfo:
	push	esi
	push	edi
	push	ecx

	mov	esi, MemChkBuf
	mov	ecx, [MCRNumber]
.loop:					
	mov	edx, 5			
	mov	edi, ARDStruct		
.1:	
	push	esi
	mov	esi, [esi]
	call	print_hex4
	mov	esi, endspace
	call	pm_puts
	pop	esi

	mov	eax, [esi]
	stosd				
	add	esi, 4			
	dec	edx			
	cmp	edx, 0			
	jnz	.1			
	call	newline

	cmp	dword [Type], 1	
	jne	.2			
	mov	eax, [BaseAddrLow]	
	add	eax, [LengthLow]	
	cmp	eax, [MemSize]	
	jb	.2			
	mov	[MemSize], eax	
.2:					
	loop	.loop			
					
	call	newline
	mov	esi, RAMSize
	call	pm_puts
	mov	esi, [MemSize]
	call	print_hex4

	pop	ecx
	pop	edi
	pop	esi
	ret

; ---------------------------------------------------------------------------
; ------------------------ setup_paging
setup_paging:
	;Calculate the memory size, howmay PDT we need
	xor	edx, edx
	mov	eax, [MemSize]
	mov	ebx, 400000h	; 400000h = 4M = 4096 * 1024, PDT
	div	ebx
	mov	ecx, eax	
	test	edx, edx
	jz	.no_remainder
	inc	ecx		
.no_remainder:
	push	ecx	


	; Init PDT
	mov	ax, sel_faltrw
	mov	es, ax
	mov	edi, PAGE_DIR_BASE	; PAGE_DIR_BASE 0x200000 2M
	xor	eax, eax
	mov	eax, PAGE_TBL_BASE | PG_P  | PG_USU | PG_RWW ; PagetblBase 0x201000 2M+4K
.loopPDT:
	stosd
	add	eax, 4096		; For simple, all of the memory is consecutive
	loop	.loopPDT

	; Init PTE
	pop	eax			; Number of PDT
	mov	ebx, 1024		; every PDT has 1024 PTE
	mul	ebx
	mov	ecx, eax		
	mov	edi, PAGE_TBL_BASE	; Base address is PAGE_TBL_BASE
	xor	eax, eax
	mov	eax, PG_P  | PG_USU | PG_RWW
.loopPTE:
	stosd
	add	eax, 4096		; every PTE pointer to 4K space
	loop	.loopPTE

	mov	eax, PAGE_DIR_BASE
	mov	cr3, eax
	mov	eax, cr0
	or	eax, 80000000h
	mov	cr0, eax
	jmp	short .flashTLB
.flashTLB:
	nop

	ret
;----------------------  END OF PAGING --------------------------



; init_kernel ---------------------------------------------------------------------------------
; Load the kernel code by program header (loop)
; --------------------------------------------------------------------------------------------
init_kernel:
	xor	esi, esi
	mov	cx, word [KFILE_PHY_ADDR + 0x2c]	;┓ ecx <- pELFHdr->e_phnum
	movzx	ecx, cx		 	;┛
	mov	esi, [KFILE_PHY_ADDR + 0x1c]	; esi <- pELFHdr->e_phoff
	add	esi, KFILE_PHY_ADDR		; esi <- OffsetOfKernel + pELFHdr->e_phoff
.Begin:
	mov	eax, [esi + 0]
	cmp	eax, 0			; PT_NULL
	jz	.NoAction
	push	dword [esi + 0x10]	; size	┓
	mov	eax, [esi + 0x4]	;	┃
	add	eax, KFILE_PHY_ADDR		;	┣ ::memcpy((void*)(pPHdr->p_vaddr),
	push	eax			; src	┃	uchCode + pPHdr->p_offset,
	push	dword [esi + 0x8]	; dst	┃	pPHdr->p_filesz;
	call	memcpy			;	┃
	add	esp, 12			;	┛
.NoAction:
	add	esi, 0x20		; esi += pELFHdr->e_phentsize
	dec	ecx
	jnz	.Begin

	ret


; SECTION .data1--------------------------------------------
[SECTION .data1]

ALIGN	32

LABEL_DATA:
_MemChkTitle:			db	"BaseAddrL  BaseAddrH  LengthLow  LengthHigh Type", 0xa, 0
_RAMSize:			db	"RAM size:", 0
_Return:			db	0xa, 0
_MCRNumber:			dd	0	; Memory Check Result
_MemSize:			dd	0

_ARDStruct:					; Address Range Descriptor Structure
	_BaseAddrLow:		dd	0
	_BaseAddrHigh:		dd	0
	_LengthLow:		dd	0
	_LengthHigh:		dd	0
	_Type:			dd	0
_MemChkBuf:	times	256	db	0

MemChkTitle		equ	LOAD_PHY_ADDR + _MemChkTitle
RAMSize			equ	LOAD_PHY_ADDR + _RAMSize
Return			equ	LOAD_PHY_ADDR + _Return
MemSize			equ	LOAD_PHY_ADDR + _MemSize
MCRNumber		equ	LOAD_PHY_ADDR + _MCRNumber
ARDStruct		equ	LOAD_PHY_ADDR + _ARDStruct
	BaseAddrLow	equ	LOAD_PHY_ADDR + _BaseAddrLow
	BaseAddrHigh	equ	LOAD_PHY_ADDR + _BaseAddrHigh
	LengthLow	equ	LOAD_PHY_ADDR + _LengthLow
	LengthHigh	equ	LOAD_PHY_ADDR + _LengthHigh
	Type		equ	LOAD_PHY_ADDR + _Type
MemChkBuf		equ	LOAD_PHY_ADDR + _MemChkBuf


_pm_msg_title	db	"123Now in Protected mode.", 0xa, 0
_pm_msg_setpage	db	"Setup the Paging.....", 0xa, 0
_pm_msg_meminfo	db	"Display the memory layout.", 0xa, 0
_pm_msg_initk	db	"Init the Kernel......", 0xa, 0
_pm_msg_welcome	db	"                      Welcome to iBean OS Kernel!", 0xa, 0
_pm_msg_author	db	"                              design by T.G. Yang [ 2012 - 2013 ]", 0xa, 0
_hexbuf4	dq	0, 0
_charidx	db	"0123456789ABCDEF", 0
_endspace	db	"h  ", 0x0

_ccolor		dw	0x0f00
_vrampos	dd	0
VRAM_END	equ	0x1ff0

pm_msg_title	equ	LOAD_PHY_ADDR + _pm_msg_title
pm_msg_setpage	equ	LOAD_PHY_ADDR + _pm_msg_setpage
pm_msg_meminfo	equ	LOAD_PHY_ADDR + _pm_msg_meminfo
pm_msg_initk	equ	LOAD_PHY_ADDR + _pm_msg_initk
pm_msg_welcome	equ	LOAD_PHY_ADDR + _pm_msg_welcome
pm_msg_author	equ	LOAD_PHY_ADDR + _pm_msg_author

ccolor		equ	LOAD_PHY_ADDR + _ccolor
vrampos		equ	LOAD_PHY_ADDR + _vrampos
hexbuf4		equ	LOAD_PHY_ADDR + _hexbuf4
charidx		equ	LOAD_PHY_ADDR + _charidx
endspace	equ	LOAD_PHY_ADDR + _endspace


;Stack at the end of Data
StackSpace:	times	1000h	db	0
TopOfStack	equ	LOAD_PHY_ADDR + $	; Top of the Stack
; SECTION .data1


