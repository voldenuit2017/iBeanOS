;--------------------------------------------------------------------------
;	boot/fat12.inc
;Descriptor:
;	FAT12 standar header information, and some other loader const.
;--------------------------------------------------------------------------

;FAT12 header
BS_OEMName		DB	'MaodouFS'	
BPB_BytsPerSec		DW	512		
BPB_SecPerClus		DB	1		
BPB_RsvdSecCnt		DW	1		
BPB_NumFATs		DB	2		
BPB_RootEntCnt		DW	224		
BPB_TotSec16		DW	2880		
BPB_Media		DB	0xF0		
BPB_FATSz16		DW	9		
BPB_SecPerTrk		DW	18		
BPB_NumHeads		DW	2		
BPB_HiddSec		DD	0		
BPB_TotSec32		DD	0		
BS_DrvNum		DB	0		
BS_Reserved1		DB	0		
BS_BootSig		DB	29h		
BS_VolID		DD	0		
BS_VolLab		DB	'iBeanOS Vol'
BS_FileSysType		DB	'FAT12   '

;Customs enviroment value
ROOT_DIR_SECTORS	equ	14	;Space of root directory
ROOT_DIR_START		equ	19	;The first sector of root directory
DELTA_SECTOR_NO		equ	17
