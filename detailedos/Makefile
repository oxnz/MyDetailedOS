#######################################
# Makefile for MyDetailedOS #
######################################

# Programs, flags, etc.
ASM		= nasm
#DASM		= ndisasm
#CC		= gcc
#LD		= ld

# This Program
ORANGESBOOT	= boot.bin

# All Phony Targets
.PHONY : everything final image clean realclean disasm all buildimg

# Default starting position
everything : $(ORANGESBOOT) $(ORANGESKERNEL)

all : everything

final : clean all

image: final buildimg

clean :
	rm -f $(ORANGESBOOT)

# We assume that "a.img" exists in current folder
buildimg :
	dd if=boot.bin of=a.img bs=512 count=1 conv=notrunc

boot.bin : boot.asm
	$(ASM) -o $@ $<
