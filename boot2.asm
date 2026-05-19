[BITS 16]
[ORG 0x7E00]

start:
	; Enable A20 to use 0x100000 for loading ther Kernel
	mov ax, 0x2401
	int 0x15

	; VESA BIOS Extension (VBE)
	; VESA function: Set video mode
	mov ax, 0x4F02
	; ah = 0x4F : this specific high byte tells the BIOS to
	;-not use legacy VGA, and its sending a VESA VBE command
	; al = 0x02 : specific low byte is the VBE command for
	;-"Set Video Mode"
	; al = 0x00 : for quering card info
	mov bx, 0x4114 ; bx means base register ( BL | BH )
	; 0x0114 is the VESA Mode ID, 0x114 is the standard ID for
	;-800x600 resolution with 32 bits per pixel, means 4 bytes per pixel. 
	; 0x4000 sets Bit 14. Linear Framebuffer (LFB) flag.
	int 0x10 ; call bios video services

	mov si, kernel_dap
	mov ah, 0x42
	mov dl, [0x500]
	int 0x13

	jmp setup_gdt

; Loading the Kernal
kernel_dap:
	db 0x10
	db 0x00
	dw 64
	dw 0x0010 ; offset
	dw 0xFFFF ; destination
	dq 5	; Kernel lives at sector 5

; gdt ( Global Descripter Table )
gdt_start:
	; the null descriptor,
	; CPU requires the very first card in the list to be invalid.
	gdt_null:
		dq 0x0000000000000000

	gdt_code:
		dw 0xFFFF	; limit low
		dw 0x0000	; base low
		db 0x00		; base middle
		db 10011010b	; access byte
		db 11001111b	; flags + limit high
		db 0x00		; base high

	; Access byte for code,
	;	1 -> segment is present in memory
	;	00 -> ring 0 privilege level
	;	1 -> this is code/data segment (not a system segment)
	;	1 -> this is a code segment (executable)
	;	0 -> not conforming (only runs at its privilege level)
	;	1 -> readable ( code can be read as data )
	;	0 -> accessed bit, CPU sets this, we leave it at 0

	; Base (where memory starts)
	; 0x00 + 0x00 + 0x0000 = 0x00000000
	; The Limit (How big the memory is)
	; 0xFFFF(limit low) + last 4 bits of db 11001111b(limit high)
	; 0xFFFF + 0x0000F = 0xFFFFF ( around 1 MB )
	
	; in db 11001111b, the very first 1 in 1100 is the
	;-Granularity Flag. It tells the CPU to treat the limit not
	;-as single bytes, but as 4KB blocks.
	; Now 1MB limit expands to 4GB.

	gdt_data:
		dw 0xFFFF	; limit low
		dw 0x0000	; base low
		db 0x00		; base middle
		db 10010010b	; access byte
		db 11001111b	; flags + limit high
		db 0x00		; base high

	; Access byte for data,
	;	1 -> present
	;	00 -> ring 0
	;	1 -> code/data segment
	;	0 -> data segment ( not executable )
	;	0 -> expand up ( stack direction )
	;	1 -> writable
	;	0 -> accessed bit

	; The flags byte
	;	1 -> granularity: limit is in 4KB pages and not bytes
	;	1 -> 32-bit protected mode segment
	;	0 -> not 64-bit ( for now ig )
	;	0 -> reserved
	;	1111 -> upper 4 bits of the limit
	
	; Both Code and Data say they start at address 0 and spans
	;-the entire 4 GB of memory. This is a perfect overlap that
	;-creates two difference sets of rules (one for executing and
	;-one for writing.). This is called the 'Flat Memory Model'.

	gdt_code64:
		dw 0xFFFF	; limit low
		dw 0x0000	; base low
		db 0x00		; base middle
		db 10011010b	; access byte (same as 32-bit code)
		db 10101111b	; flags: 64-bit flag set ( bit 5 )
		db 0x00		; base high

	gdt_end:

		gdt_descriptor:
			dw gdt_end - gdt_start - 1 ; size of GDT - 1
			dd gdt_start	; address of GDT
	
	; lgdt is a special CPU instruction (Load GDT).
	; It reads the gdt_descriptor structure and stores the GDT
	;-location and size into a special internal CPU register
	;-called the GDTR. The CPU will reference this register
	;-every single time it needs to look up a segment descriptor.
	setup_gdt:
		lgdt [gdt_descriptor]
	
	; cr0 is a control register.You cannot mov a value directly
	;-in to it. You have to read it, modify it, and write it back.
	mov eax, cr0
	or eax, 1
	mov cr0, eax

	; Bit 0 of cr0 is called the PE bit ( Protection Enable ).
	; Flipping it to 1 switch the CPU from real mode to protected.

	; ---> <---
	; CPU has an internal pipeline that was already fetching &
	;-decoding instructions assuming real mode. Flipping the PE
	;-bit doesnt automatically flush that pipeline. Have to
	;-perform a far jump immediately after setting the PE bit.
	; far jump force the CPU to flush its pipeline and reload the
	;-CS register from GDT, where then GDT takes effect.
	jmp 0x08:protected_mode

[BITS 32]
protected_mode:
	; reloading segment registers with data segment selectors
	; 0x10 -> 0000000000010000
	; bits 15-3 -> 0000000000010 -> index 2 -> third entry in GDT -> gdt_data
	; bits 2 -> 0 -> use GDT ( if 1 use Local Descripter Table [LDT] -> we dont use this)
	; bits 1-0 -> 00 -> ring 0
	mov ax, 0x10
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax
	mov ss, ax
	mov esp, 0x90000 ; new stack is set up in a safe location

	; CR3 Register - PML4 (Page Mape Level 4)
	;	-> PDPT (Page Directory Pointer Table)
	;		-> PD (Page Directory)
	;			-> PT (Page Table)
	;				-> Physical Page

	; clear pages by zero out 12KB starting at 0x1000
	mov edi, 0x1000		; edi -> destination index
	mov cr3, edi		; CR3(control register 3) points at PML4
	xor eax, eax		; eax -> accumulator register, ecx -> counter register
	mov ecx, 3072		; 3072 * 4 bytes = 12KB
	rep stosd		; repeat: store EAX into [EDI], advance EDI
	mov edi, cr3		; resets EDI back to 0x1000

	; PML4[0] points to PDPT at 0x2000
	; flags: present (bit 0) + writable (bit 1) = 0x3
	mov dword [0x1000], 0x2003

	; PDPT[0] points at PD at 0x3000
	mov dword [0x2000], 0x3003

	; PD[0] points at first 2MB Using a huge page
	; flags: present + writable + huge page (bit 7) = 0x83 (10000011)
	mov dword [0x3000], 0x83

	; Enable PAE (Physical address extension) - bit 5 of CR4
	mov eax, cr4
	or eax, 1 << 5
	mov cr4, eax

	; Enable long mode in EFER(Extended Feature Enable Register) MSR (0xC0000080)
	mov ecx, 0xC0000080
	rdmsr
	or eax, 1 << 8
	wrmsr

	; Enable Paging
	mov eax, cr0
	or eax, 1 << 31
	mov cr0, eax

	jmp 0x18:long_mode

[BITS 64]
long_mode:
	mov ax, 0x10
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax
	mov ss, ax
	mov rsp, 0x90000 ; rsp instead of esp

