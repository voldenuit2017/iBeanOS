;**************************************************************
;	boot/load.inc
;Descriptor:
;	Const value which are shared by boot.asm and load.asm.
;**************************************************************

;Paging start physic address in RAM.
PAGE_DIR_BASE		equ		0x200000	; 1M
PAGE_TBL_BASE		equ		0x201000	; 1M + 4K

;Load address
LOAD_SEG		equ		0x9000
LOAD_OFFSET		equ		0x100
LOAD_PHY_ADDR		equ		LOAD_SEG * 0x10

;Some const about kernel file load.
KFILE_SEG		equ		0x8000
KFILE_OFFSET		equ		0
KFILE_PHY_ADDR		equ		KFILE_SEG * 0x10

;Const for boot parament, which means for memory size
BOOT_PARAM_ADDR		equ		0x900
BOOT_PARAM_MAGIC	equ		0xB007

ARDS_SEG		equ		0x7000
ARDS_OFFSET		equ		20
ARDS_PHY_ADDR		equ		0x7000 * 0x10

;------------ tmp value 
;define Color
COLOR_BLACK		equ	0
COLOR_BLUE		equ	1
COLOR_GREEN		equ	2
COLOR_CYAN		equ	3
COLOR_RED		equ	4
COLOR_MAGENTA		equ	5
COLOR_BROWN		equ	6
COLOR_LIGHTGRAY		equ	7
COLOR_GRAY		equ	8
COLOR_LIGHTBLUE		equ	9
COLOR_LIGHTGREEN	equ	10
COLOR_LIGHTCYAN		equ	11
COLOR_LIGHTRED		equ	12
COLOR_LIGHTMAGENTA	equ	13
COLOR_YELLOW		equ	14
COLOR_WHITE		equ	15
COLOR_DEFAULT		equ	0x000f

