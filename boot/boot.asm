;------------------------------------------------------------------
;	iBean OS Boot
;		Study by Yang Tingguang @ 2012.12 
;Setup:
;	1: Search the file in root sector( 19th sector )
;	2: Read the loader.bin in disk to RAM space 0x9000:0x100
;	3: Far jump to Loader
;
;Modify 2013.2 first time.
;--------------------------------------------------------------------

;BIOS read the first Sector data ( 512 bytes ) to RAM at 0x7c00,
;so set the offset as 0x7c00 with pesudo instruct org. And the 
;stack base address is set in 0x7c00 too.
org		0x7c00
stack_base	equ		0x7c00

%include "loader.inc"

;Without Debug information can man reduce the size of BootSector.
;By some version of NASM, for example 1.9.10, with debug information
;will the final code size bigger than 512 bytes, then cause compilate
;to fail.
%define	BOOT_DEBUG

;jmp	short in Intel Opcode is eb xx ( xx is jump addr, here is
;0x3c, 0x3c + 2 = 0x3e, 0x3e is the start of boot code, you can
;see the FAT12 Specific as reference ), with the opcode nop 
;complement 3 bytes
jmp	short boot_start
nop

;Header of the FAT12
%include "fat12.inc"

;Here start the OS boot code
boot_start:
	mov	ax, cs
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
	mov	sp, stack_base

%ifdef BOOT_DEBUG	
;Clear srceen and	show prompt
	call	clrsrc
	mov	si, msg_booting
	call	puts
%endif

;Reset floppy
	xor	ah, ah
	xor	dl, dl
	int	0x13

;Search and load load.bin
	call	search_file
	call 	load_file

;Show something about boot finishing
%ifdef	BOOT_DEBUG
	mov	si, msg_ready
	call	puts
%endif

	jmp	LOAD_SEG:LOAD_OFFSET


;--------------------------------------------------------------------
;	Variables and string
;--------------------------------------------------------------------
rds_idx		dw	ROOT_DIR_SECTORS	
sect_cnt	dw	0			;Sector number
is_odd		db	0			;odd or even , odd : 1 even : 0
file_name	db	"LOADER  BIN", 0	;file name

;Some prompt information
%ifdef	BOOT_DEBUG
msg_point	db	".", 0
msg_booting	db	"Booting", 0
msg_ready	db	" DONE!", 0xa, 0
msg_failed	db	" FAILED!", 0xa, 0
%endif



;--------------------------------------------------------------------
;	Support functions
;--------------------------------------------------------------------

;----------------------------- search_file --------------------------
;Searching loader.bin in root directory	
search_file:
	mov	word [sect_cnt], ROOT_DIR_SECTORS	 ; = 19
.begin:
;Check the root directory sector is finished
	cmp	word [rds_idx], 0	
	jz	.miss
	dec	word [rds_idx]

;Set the paramenter for function read_sector in space es:bx
	mov	ax, LOAD_SEG
	mov	es, ax			
	mov	bx, LOAD_OFFSET
	mov	ax, [sect_cnt]
	mov	cl, 1
	call	read_sector
; ds:si -> "LOADER  BIN"
	mov	si, file_name
	mov	di, LOAD_OFFSET
	cld

;loop for a sector 32 bytes * 16 items = 512 bytes
	mov	dx, 0x10
.loop_search:
	cmp	dx, 0				
	jz	.next_root	
	dec	dx
	mov	cx, 11
.compare:
	cmp	cx, 0
;If 11 bytes equal, the jump out
	jz	.found
	dec	cx
	lodsb			; ds:si -> al
	cmp	al, byte [es:di]
	jz	.continue
	jmp	.diff
.continue:
	inc	di
	jmp	.compare

;Set the new es:di to next item start addr
.diff:
	and	di, 0xFFE0
	add	di, 0x20
	mov	si, file_name
	jmp	.loop_search

.next_root:
	add	word [sect_cnt], 1
	jmp	.begin
;loader.bin is not founded
.miss:
%ifdef BOOT_DEBUG
	mov	si, msg_failed
	call	puts
%endif
	jmp	$
.found:
	ret

;------------------------ load_file --------------------------
load_file:		
;Searching the first sectorNo
	mov	ax, ROOT_DIR_SECTORS
	and	di, 0xFFE0
	add	di, 0x1A		
	mov	cx, word [es:di]
	push	cx			; save the first Sector index in cx
	add	cx, ax
	add	cx, DELTA_SECTOR_NO	; cx =  Loader.bin start sector
	mov	ax, LOAD_SEG
	mov	es, ax			; es <- LOAD_SEG
	mov	bx, LOAD_OFFSET		; bx <- LOAD_OFFSET es:bx 0x9000:x0x100
	mov	ax, cx			; ax <- Sector Number

.loop:
%ifdef	BOOT_DEBUG
	mov	si, msg_point
	call	puts
%endif
	mov	cl, 1
	call	read_sector
	pop	ax			;Get the Sector index in FAT
	call	get_fat_entry
	cmp	ax, 0FFFh
	jz	.done
	push	ax			;Save the sector index in FAT
	mov	dx, ROOT_DIR_SECTORS
	add	ax, dx
	add	ax, DELTA_SECTOR_NO
	add	bx, [BPB_BytsPerSec]
	jmp	.loop
.done:
	ret

%ifdef BOOT_DEBUG
;------------------------------- puts -----------------------------
;put string in srceen, si as input
puts:
	pusha
	mov	ah, 0x0e
	mov	bh, 0x00
	mov	bl, 0x01	

do_puts_loop:	
	lodsb
	test	al,al
	jz	do_puts_done
	int	0x10
	jmp	do_puts_loop

do_puts_done:	
	popa
	ret

;-------------------------------- clrsrc ------------------------------
;clear the srceen
clrsrc:
	pusha
	mov	ax, 0x0600
	mov	cx, 0
	xor	bh, 0x0e
	mov	dh,	24
	mov	dl, 79
	int	0x10
	
;set the cursor position
	mov	ah, 0x02
	mov	bh, 0x00
	mov	dx, 0x00
	int	0x10
	popa
	ret
%endif

;----------------------------- read_sector ----------------------------
;#c=#lba/(S*H)
;#h=(#lba/S)%H
;#s=(#lba%S)+1
;ax sctors   cl sctor number   es:bx space
read_sector:	
	;save data
	push	bp
	mov	[sectors_st], ax
	mov	[sectors_rd], cl
	push	bx
;Calculate cylind
	mov	bl, 36 ;18*2	
	div	bl
	mov	[cylind_ch], al

;Calculate header
	mov	ax, [sectors_st]
	mov	bl, 18
	div	bl
	and	ax, 0x1
	mov	[header_dh], al

;Calculate sector
	mov	ax, [sectors_st]
	mov	bl, 18
	div	bl
	inc	ah
	mov	[sector_cl], ah

	mov	dh, [header_dh]
	mov	ch, [cylind_ch]
	mov	cl, [sector_cl]
	mov	dl, 0	;disk A ( Floppy A )
	pop	bx
.goon_read:
	mov	ah, 2	;int	0x13 funtion 2
	mov	al, [sectors_rd]
	int	0x13
	jc	.goon_read
	pop	bp
	ret
sector_cl	db	0
cylind_ch	db	0
header_dh	db	0
sectors_rd	db	0
sectors_st	dw	0	;start sector number


;---------------------------- get_fat_entry ------------------------
;find the setor in FAT by index = ax, 
;read the temp data in es:bx [0x8ff0:0x00], behind Baseofloader , 4k
get_fat_entry:
	push	es
	push	bx
	push	ax
;4K space for buffer
	mov	ax, LOAD_SEG	
	sub	ax, 0100h		
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

;=====================================================================
;End of bootsector
times 	510-($-$$)	db	0	
dw 	0xaa55			; End sign, littel end

