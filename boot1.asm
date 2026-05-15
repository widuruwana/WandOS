[BITS 16]
[ORG 0x7C00]

start:
	; clearing segment registers as the BIOS state is undefined
	xor ax, ax
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, 0x7C00 ; stack grows downwards

	mov [boot_drive], dl ; save the driver number gave by BIOS
	; Alse [something] functions as deferencing like the * in C.

	mov si, dap		; source index points at the DAP (Disk Address Packet)
	mov dl, [boot_drive] 	; restore drive number into dl (Data low)
	mov ah, 0x42		; function 0x42 = extended read
	int 0x13		; does the disk read

	jmp 0x7E00		; jump to stage 2
hang:
	hlt
	jmp hang

boot_drive:
	db 0	; is just a byte initialized to 0. Thinks it just acts the same as a normal variable you initialize to store something.

dap:
	db 0x10		; packet size is 16 bytes, doesnt change
	db 0x00		; reserved 0
	dw 0x3		; (define word) read 3 sectors
	dw 0x7E00	; destination offset
	dw 0x0000	; destination segment
	dq 0x1		; (define quad - 8 bytes) start from sector 1 

times 510 - ($ - $$) db 0
dw 0xAA55
