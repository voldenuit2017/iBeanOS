/*********************************************************************
*	include/kernel.h
*********************************************************************/

#ifndef _KERNEL_H_
#define _KERNEL_H_

//Structure for "Address Range Descriptor Structure"
struct ards{
	u32 base_addr_low;	//base address low 32 bits
	u32 base_addr_high;	//base address high 32 bits
	u32 length_low;		//length ( bytes ) low 32 bits
	u32 length_high;	//length ( bytes ) high 32 bits
	u32 type;		//Memory types :
	// 1 , Address Range Memory : this memory can be used by OS.	
	// 2 , Address Range Reserved : this memory CAN'T be used by OS.
	// 3 , Undefine	: Reserved, like as type 2.
};

#endif
