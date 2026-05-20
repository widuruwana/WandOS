ENTRY(k_start)
/* tells the linker the entry point symbol is start, which is whats
   in the kernel_entry.asm
 */

SECTIONS {
	. = 0x100000;
	/* The dot is the current address counter. this tells the linker
	   that everything that follows lives at base address 0x100000.
	 */
	
	.text : {
		*kernel_entry.o(.text)
		*(.text)
		/* .text is the code section, *kernel_entry.o(.text) forces the
		   kernel_entry.o to come first. Then *(.text) pulls in code from
		   all the other object files.
		 */
	}

	.data : {
		*(.data) /* .data -> Initialized global variables */
	}

	.bss : {
		*(.bss) /* .bss -> uninitialized global variables */
	 }
}
