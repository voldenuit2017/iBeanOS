/****************************************************************************
*		kernel/kernel.c
*Descriptor:
*	Kernel file, init all device.
*****************************************************************************/

#include "type.h"
#include "kernel.h"
#include "klib.h"

int disp_pos;

void kinit( void )
{
	int *ards_nr = ( int* )0x920;
	u32 *ards_buf = ( u32* )0x930;
	struct ards ards[ 30 ];
	int idx;
	
	disp_pos = 80 * 4;
	memcpy( ards, ards_buf, 256 );
	printf( "\n\nIn Kernel ARDS Nr = %x\n", *ards_nr );
	printf( "Base Low   Base High   Len Low    Len High    Type\n" );
	for( idx = 0; idx < *ards_nr; idx++ )
		printf( "%x    %x  %x   %x   %d\n", ards[idx].base_addr_low,
			ards[idx].base_addr_high, ards[idx].length_low,
			ards[idx].length_high, ards[idx].type );
	for( ; ; );
}
