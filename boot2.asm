[BITS 16]
[ORG 0x7E00]

start:
	; VESA BIOS Extension (VBE)
	; VESA function: Set video mode
	mov ax, 0x4F02
	; ah = 0x4F : this specific high byte tells the BIOS to
	;-not use legacy VGA, and its sending a VESA VBE command
	; al = 0x02 : specific low byte is the VBE command for
	;-"Set Video Mode"
	; al = 0x00 : for quering card info
	mov bx, 0x4114 ; bx means base register ( BL | BH )
	; 0x0114 is the VESA Mode ID, 0x114 is the standard ID for 800x600 resolution with 16-bit color (RGB565)
	; 0x4000 sets Bit 14. Linear Framebuffer (LFB) flag.

