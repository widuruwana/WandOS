#!/bin/bash

# Assemble bootloader stages
nasm -f bin boot/boot1.asm -o boot1.bin
nasm -f bin boot/boot2.asm -o boot2.bin

# compile kernel
nasm -f elf64 kernel/kernel_entry.asm -o kernel_entry.o
gcc -ffreestanding -mno-red-zone -m64 -c kernel/kernel.c -o kernel.o
ld -T kernel/kernel.ld -o kernel.bin --oformat binary kernel_entry.o kernel.o

# -f elf64 -> unlike the bootloader which used -f bin, the kernel entry
#-is assembled into ELF format, which is the standard object file format that
#-the linker understands. The linker combined ELF files and produces the final
#-binary.

# -ffreestanding tell the GCC that this C code doesn't use any standard libraries
#-underneath it. Like there is no printf or malloc or C runtime. Just bare metal.

# -mno-red-zone is a 128 byte area below the stack pointer that the System V ABI
# reserves for optimizations. Hardware interrupts can fire anytime and corrupt
# that area so for a kernel its dangerous so this flag disables that red zone.

# --oformat binary tell the linker to output a flat raw binary, same as -f bin
#-in NASM.

# Create a blank 1MB disk image
dd if=/dev/zero of=wand.img bs=512 count=2048 2>/dev/null

# 512 bytes x 2048 = 1,048,576 bytes = 1 MB
# 2>/dev/null hides standard error text

# Write stage 1 to sector 0
dd if=boot1.bin of=wand.img bs=512 seek=0 conv=notrunc 2>/dev/null

# seek=0 means skip 0 blocks (in here write directly to first sector)
# conv=notrunc means Do Not Truncate, prevents dd from cutting off or
#-deleting the rest of 1MB file after writing

# Write stage 2 to sector 1
dd if=boot2.bin of=wand.img bs=512 seek=1 conv=notrunc 2>/dev/null

# Write Kernel to sector 5
dd if=kernel.bin of=wand.img bs=512 seek=5 conv=notrunc 2>/dev/null

echo "Build Complete. Running QEMU..."
# qemu-system-x86_64 -drive format=raw,file=wand.img -monitor stdio
# qemu-system-x86_64 -drive format=raw,file=wand.img
qemu-system-x86_64 -drive format=raw,file=wand.img -monitor stdio -S
