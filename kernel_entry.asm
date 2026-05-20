[BITS 64]

extern kernel_main
global k_start

k_start:
	mov rsp, 0x90000
	mov rdi, 0x7000	 ; in x86-64, the first int arg goes in rdi
	call kernel_main

hang:
	hlt
	jmp hang
