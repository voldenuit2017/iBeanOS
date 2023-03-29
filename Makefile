#------------------------------------------------------------
#	Makfie for iBeanOS 2012 
#------------------------------------------------------------
KENTER_ADDR	= 0x30400
ASM		= nasm
CC		= gcc
LD		= ld
ASM_BFLAGS	= -I boot/
ASM_KFLAGS	= -I include/ -f elf
C_FLAGS		= -I include/ -c -fno-builtin -Wall
AR_FLAGS	= rcs
LD_FLAGS	= -s -Ttext $(KENTER_ADDR) -Map kmap

IBEAN_BOOT	= boot/boot.bin boot/loader.bin
IBEAN_KERNEL	= kernel.bin


KOBJS		= kernel/kernel_asm.o kernel/kernel_c.o \
		lib/klib_asm.o lib/klib_c.o

#--------------------- Compile ops --------------------------
.PHONY : build clean all tags install tags cleandisk cleantags

all: clean tags build install

clean :
	rm -f $(IBEAN_BOOT)
	rm -f $(IBEAN_KERNEL)

build :	$(IBEAN_BOOT) $(IBEAN_KERNEL) $(KOBJS)

install :
	dd if=boot/boot.bin of=/dev/fd0
	mount -o loop /dev/fd0 /mnt/floppy/
	cp -f boot/loader.bin /mnt/floppy/
	cp -f kernel.bin /mnt/floppy/
	umount /mnt/floppy
	sync
tags :
	ctags -R

cleandisk :
	dd if=/dev/zero of=/dev/fd0 count=2880
cleantags :
	rm -f tags

#-------------------- Depend relationship -------------------

$(IBEAN_KERNEL) : $(KOBJS)
	$(LD) $(LD_FLAGS) -o $@ $(KOBJS)

#folder boot:
boot/boot.bin : boot/boot.asm
	$(ASM) $(ASM_BFLAGS) -o $@ $<
boot/loader.bin : boot/loader.asm
	$(ASM) $(ASM_BFLAGS) -o $@ $<

#folder kernel:
kernel/kernel_asm.o : kernel/kernel.asm
	$(ASM) $(ASM_KFLAGS) -o $@ $<
kernel/kernel_c.o : kernel/kernel.c
	$(CC) $(C_FLAGS) -o $@ $<

#folder lib:
lib/klib_c.o : lib/klib.c
	$(CC) $(C_FLAGS) -o $@ $<
lib/klib_asm.o : lib/klib.asm
	$(ASM) $(ASM_KFLAGS) -o $@ $<
