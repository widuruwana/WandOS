[BITS 16]
[ORG 0x7E00]

start:
	; Enable A20 to use 0x100000 for loading ther Kernel
	mov ax, 0x2401
	int 0x15

	; Query VBE mode info
	mov ax, 0x4F01		; VBE function: get mode info
	mov cx, 0x114		; Mode number
	mov di, 0x7000		; Where to write the 256 byte structure
	int 0x10
	; The Physical framebuffer sits at 0x7000 + 40(offset) into the structure.

	; VESA BIOS Extension (VBE)
	; VESA function: Set video mode
	mov ax, 0x4F02
	; ah = 0x4F : this specific high byte tells the BIOS to not use legacy VGA,
	;-and its sending a VESA VBE command
	; al = 0x02 : specific low byte is the VBE command for "Set Video Mode"
	; al = 0x00 : for quering card info
	mov bx, 0x4114 ; bx means base register ( BL | BH )
	; 0x0114 is the VESA Mode ID, 0x114 is the standard ID for
	;-800x600 resolution with 32 bits per pixel, means 4 bytes per pixel. 
	; 0x4000 sets Bit 14. Linear Framebuffer (LFB) flag.
	int 0x10 ; call bios video services

	; Loading the kernel
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
	dw 0x0000 ; offset
	dw 0x1000 ; destination
	dq 5	; Kernel lives at sector 5

	; 0x1000 * 16 + 0x0000 = 0x10000
	; loads the kernel to 0x10000 in this real mode

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

	; copy kernel from 0x10000 to 0x100000
	; exc must match DAP sector count: 64 sectors * 512 / 4 = 8192 dwords
	mov esi, 0x10000	; source -> where we loaded the kernel
	mov edi, 0x100000	; destination -> where kernel should live
	mov ecx, 8192		; 8192 * 4 bytes = 32 KB.
	rep movsd

	; rep movsd copy 4 bytes from [ESI] to [EDI], advance both by 4, decrements ECX
	;-and repeats until EXC is 0.
	; ex: If exc is only 3, then it will copy 4*3 = 12 bytes starting
	;-from esi address and then paste that starting from edi address.

	; CR3 Register:
	; -> PML4 (Page Map Level 4)
	;	-> PDPT (Page Directory Pointer Table)
	;		-> PD (Page Directory)
	;			-> PT (Page Table)
	;				-> Physical Page

	; clear pages by zero out 24KB starting at 0x1000
	mov edi, 0x1000		; edi -> destination index
	mov cr3, edi		; CR3(control register 3) points at PML4
	xor eax, eax		; eax -> accumulator register, ecx -> counter register
	mov ecx, 6144		; 6144 * 4 bytes = 24KB, have 6 tables
	rep stosd		; repeat: store EAX into [EDI], advance EDI
	mov edi, cr3		; resets EDI back to 0x1000

	; PML4[0] points to PDPT at 0x2000
	; flags: present (bit 0) + writable (bit 1) = 0x3
	mov dword [0x1000], 0x2003

	; PDPT has 4 entries, one per GB
	; PDPT[0] points at PD at 0x3000
	mov dword [0x2000], 0x3003 ; 0GB - 1GB
	mov dword [0x2008], 0x4003 ; 1GB - 2GB
	mov dword [0x2010], 0x5003 ; 2GB - 3GB
	mov dword [0x2018], 0x6003 ; 3GB - 4GB

	; fill each PD with 512 huge page entries
	; PDO at 0x3000 -> covers 0x00000000 to 0x3FFFFFFF ( 1GB mem )
	mov edi, 0x3000		; point EDI at the start of PD0.
	mov ebx, 0x00000083	; 0x00000000 is the physical address this entry maps to
				; 0x83 is the flag ( present + writable + hugepage )
	; meaning "Virtual address in this range maps to physical address 0x00000000, and
	;-its a 2MB huge page"
	mov ecx, 512		; ECX is the loop counter 512 ( 2MB x 512 = 1GB )
	.pd0:
		mov dword [edi], ebx	; write current entry val to PD at address on EDI
		add edi, 8		; advance the pointer by 8 bytes
		add ebx, 0x200000	; advance physical address of EDI by 2MB
		loop .pd0

	; PD1 at 0x4000 -> covers 0x40000000 to 0x7FFFFFFF
	mov edi, 0x4000		
	mov ebx, 0x40000083	; 1GB more than 0x00000000 (+ 0x40000000)
	mov ecx, 512
	.pd1:
		mov dword [edi], ebx
		add edi, 8
		add ebx, 0x200000
		loop .pd1

	; PD2 at 0x5000 -> covers 0x80000000 to 0xBFFFFFFF
	mov edi, 0x5000
	mov ebx, 0x80000083
	mov ecx, 512
	.pd2:
		mov dword [edi], ebx
		add edi, 8
		add ebx, 0x200000
		loop .pd2

	; PD3 at 0x6000 -> covers 0xC0000000 to 0xFFFFFFFF
	mov edi, 0x6000
	mov ebx, 0xC0000083
	mov ecx, 512
	.pd3:
		mov dword [edi], ebx
		add edi, 8
		add ebx, 0x200000
		loop .pd3

	; Additional fact -> 2MB size is not something you specify as a number anywhere,
	;-its a fixed property of the paging structure level. Each page table hierchy has a
	;-fixed coverage size:
	;	PML4 entry -> covers 512GB each
	;	PDPT entry -> covers 1GB each
	;	PD entry   -> covers 2MB each (when huge page bit is set)
	;	PT entry   -> covers 4KB each


	; PD[0] points at first 2MB Using a huge page
	; flags: present + writable + huge page (bit 7) = 0x83 (10000011)
	; mov dword [0x3000], 0x83 -- [REMOVED for expanding the page table]
	
	; ------> <------

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

	jmp 0x100000

