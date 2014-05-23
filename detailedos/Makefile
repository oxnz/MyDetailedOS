#######################################
# Makefile for MyDetailedOS #
######################################
# It must have the same value with 'KRNL_ENT_PT_PHY_ADDR' in load.inc!
ENTRYPOINT	= 0x30400
# Programs, flags, etc.
ASM		= nasm
#DASM		= ndisasm
#CC		= gcc
LD		= ld
ASMKFLAGS	= -f elf
LDFLAGS		= -s -Ttext $(ENTRYPOINT)

# This Program
ORANGESBOOT		= boot.bin loader.bin
ORANGESKERNEL	= kernel.elf
OBJS			= kernel.o
# All Phony Targets
.PHONY : everything final image clean realclean disasm all buildimg

# Default starting position
everything : $(ORANGESBOOT) $(ORANGESKERNEL)

image: everything buildimg clean

clean :
	rm -f $(OBJS)
realclean :
	rm -f $(ORANGESBOOT) $(ORANGESKERNEL) *.o
# We assume that "a.img" exists in current folder
buildimg :
	dd if=boot.bin of=a.img bs=512 count=1 conv=notrunc
	sudo mount -o loop a.img /mnt/floppy/
	sudo cp -fv loader.bin /mnt/floppy/
	sudo cp -fv kernel.elf /mnt/floppy
	sudo umount /mnt/floppy
boot.bin : boot.asm
	$(ASM) -o $@ $<
loader.bin : loader.asm
	$(ASM) -o $@ $<
kernel.o : kernel.asm
	$(ASM) $(ASMKFLAGS) -o $@ $<
$(ORANGESKERNEL) : $(OBJS)
	$(LD) $(LDFLAGS) -o $(ORANGESKERNEL) $^

