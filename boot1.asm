[BITS 16]
[ORG 0x7C00]

start:
	; clear the Direction Flag (DF = 0) so memory ops go forward
	cld
	; when writing a function to print text to the screen or copy sectors of memory around,
	; we rely on loadsb (Load String Byte) or movsb (Move String Byte) instructions.
	; When Direction Flag = 0 (cld), loadsb reads a byte at si register and automatically
	;-adds 1 to it point to next character.
	; If DF is left at 1 (std), loadsb would read the byte and subsctract 1 from si, reading
	;-string backwards.

	; clearing segment registers as the BIOS state is undefined
	xor ax, ax ; accumulator Reg. ( AX, EAX in 32-bit and RAX in 64-bit)
	mov ds, ax ; Segment Reg.
	mov es, ax ; Extra segment reg.
	mov ss, ax ; Stack segment reg.
	mov sp, 0x7C00 ; stack grows downwards

	mov [boot_drive], dl ; save the driver number gave by BIOS
	; Alse [something] functions as deferencing like the * in C.

	mov si, dap		; source index points at the DAP (Disk Address Packet)
	mov dl, [boot_drive] 	; restore drive number into dl (Data low)
	mov ah, 0x42		; function 0x42 = extended read
	int 0x13		; does the disk read

	jc disk_error		; jump to an error handler if the read failed

	jmp 0x7E00		; jump to stage 2

disk_error:
	mov ah, 0x0E	; BIOS teletype output function
	mov al, 'E'	; Character 'E' for error
	int 0x10	; Print char to screen

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
