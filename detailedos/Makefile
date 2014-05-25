#######################################
# Makefile for MyDetailedOS #
######################################
# It must have the same value with 'KRNL_ENT_PT_PHY_ADDR' in load.inc!
ENTRYPOINT	= 0x30400

# Programs, flags, etc.
ASM		= nasm
#DASM		= ndisasm
CC		= gcc
LD		= ld
ASMBFLAGS	= -I boot/include/
ASMKFLAGS	= -f elf -I include/
CFLAGS	= -c -Wall -I include/
LDFLAGS	= -s -Ttext $(ENTRYPOINT) -Map kernel.map

# This Program
ORANGESBOOT		= boot/boot.bin boot/loader.bin
ORANGESKERNEL	= kernel/kernel.elf
OBJS			= kernel/kernel.o kernel/start.o kernel/i8259.o kernel/global.o kernel/protect.o \
			  lib/string.o lib/kliba.o lib/klib.o
# All Phony Targets
.PHONY : everything final image clean realclean disasm all buildimg

# Default starting position
everything : $(ORANGESBOOT) $(ORANGESKERNEL)

image: everything buildimg clean

clean :
	rm -f $(OBJS)
realclean :
	rm -f $(ORANGESBOOT) $(ORANGESKERNEL) $(OBJS)
# We assume that "a.img" exists in current folder
buildimg :
	dd if=boot/boot.bin of=a.img bs=512 count=1 conv=notrunc
	sudo mount -o loop a.img /mnt/floppy/
	sudo cp -fv boot/loader.bin /mnt/floppy/
	sudo cp -fv kernel/kernel.elf /mnt/floppy
	sudo umount /mnt/floppy
boot/boot.bin : boot/boot.asm
	$(ASM) $(ASMBFLAGS) -o $@ $<
boot/loader.bin : boot/loader.asm
	$(ASM) $(ASMBFLAGS) -o $@ $<
kernel/kernel.o : kernel/kernel.asm
	$(ASM) $(ASMKFLAGS) -o $@ $<
$(ORANGESKERNEL) : $(OBJS)
	$(LD) $(LDFLAGS) -o $(ORANGESKERNEL) $^
kernel/start.o : kernel/start.c
	$(CC) $(CFLAGS) -o $@ $<
kernel/i8259.o : kernel/i8259.c
	$(CC) $(CFLAGS) -o $@ $<
kernel/global.o : kernel/global.c
	$(CC) $(CFLAGS) -o $@ $<
kernel/protect.o : kernel/protect.c
	$(CC) $(CFLAGS) -o $@ $<
lib/string.o : lib/string.asm
	$(ASM) $(ASMKFLAGS) -o $@ $<
lib/kliba.o : lib/kliba.asm
	$(ASM) $(ASMKFLAGS) -o $@ $<
lib/klib.o : lib/klib.c
	$(CC) $(CFLAGS) -o $@ $<


