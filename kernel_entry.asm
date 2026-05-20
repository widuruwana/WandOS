[BITS 64]

extern kernel_main
global k_start

k_start:
	mov rsp, 0x90000
	call kernel_main

hang:
	hlt
	jmp hang
