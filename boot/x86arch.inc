;--------------------------------------------------------------------
;	boot/x86arch.inc 
;Descriptor:
;	This file containt x86-architecture constants.
;--------------------------------------------------------------------

DA_32s		equ	0x4000
DA_LIMIT_4K	equ	0x8000

;SA : Selector Atrribute
SA_RPL_MASK	equ	0xfffc
SA_RPL0		equ	0
SA_RPL1		equ	1
SA_RPL2		equ	2
SA_RPL3		equ	3

SA_TI_MASK	equ	0xfffb
SA_TIG		equ	0
SA_TIL		equ	4

;DPL :	Descriptor Privilege level at Byte 4 Bit 5 and 6
DA_DPL0		equ	0x00
DA_DPL1		equ	0x20
DA_DPL2		equ	0x40
DA_DPL3		equ	0x60


;****************************************************************************
;TYPE: S=1 Code Segment Type and Data Segment Type; S=0 System Segment Type
; D : Data   C : Code   S : System   
; R : Read   W : Write  A : Access  D : Extension Down
; E : Exectues  C : Consistent
; CG : Call Gate  TG : Trap Gate  IG : Interrupt Gate
;****************************************************************************
DAD_R		equ	0x90
DAD_RA		equ	0x91
DAD_RW		equ	0x92
DAD_RWA		equ	0x93
DAD_RD		equ	0x94
DAD_RDA		equ	0x95
DAD_RWD		equ	0x96
DAD_RWDA	equ	0x97

DAC_E		equ	0x98
DAC_EA		equ	0x99
DAC_ER		equ	0x9a
DAC_ERA		equ	0x9b
DAC_EC		equ	0x9c
DAC_ECA		equ	0x9d
DAC_ERC		equ	0x9e
DAC_ERCA 	equ	0x9f

DAS_A286TSS	equ	0x81	;Avaliable 286TSS
DAS_LDT		equ	0x82
DAS_B286TSS	equ	0x83	;Busy 286TSS
DAS_286CG	equ	0x84
DAS_TaskGate	equ	0x85
DAS_286IG	equ	0x86
DAS_286TG	equ	0x87
DAS_A386TSS	equ	0x89
DAS_B386TSS 	equ	0x8b
DAS_386CG 	equ	0x8c
DAS_386IG 	equ	0x8e
DAS_386TG	equ	0x8f


;----------------------------------------------------------------------------
; Paging Variables
; P: Present	R: Read		W: Write	U: User		S: System
;----------------------------------------------------------------------------
PG_P		equ	1
PG_RWR		equ	0
PG_RWW		equ	2
PG_USS		equ	0
PG_USU		equ	4
;----------------------------------------------------------------------------

; usage: Descriptor Base, Limit, Attr
;        Base:  dd
;        Limit: dd (low 20 bits available)
;        Attr:  dw (lower 4 bits of higher byte are always 0)
%macro Descriptor 3
	dw	%2 & 0xFFFF
	dw	%1 & 0xFFFF
	db	(%1 >> 16) & 0xFF			
	dw	((%2 >> 8) & 0x0F00) | (%3 & 0xF0FF)	
	db	(%1 >> 24) & 0xFF			
%endmacro


; usage: Gate Selector, Offset, DCount, Attr
;        Selector:  dw
;        Offset:    dd
;        DCount:    db
;        Attr:      db
%macro Gate 4
	dw	(%2 & 0xFFFF)				
	dw	%1					
	dw	(%3 & 0x1F) | ((%4 << 8) & 0xFF00)	
	dw	((%2 >> 16) & 0xFFFF)			
%endmacro

