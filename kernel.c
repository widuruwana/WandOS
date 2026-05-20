void kernel_main(unsigned int *vbe_info){
	__asm__("cli");

	unsigned int fb_addr = vbe_info[10]; // offset 40 -> 4 bytes x 10(th index of uint32 arr)
	unsigned char *fb = (unsigned char *)(unsigned long)fb_addr;
	
	int tot_bytes = 800 * 600 * 4;

	for(int i = 0; i < tot_bytes; i++){
		fb[i] = 0xFF; // Blue
		//fb[i+1] = 0xFF; // Green
		//fb[i+2] = 0xFF; // Red
		//fb[i+3] = 0x00; // Alpha
	}

	//unsigned int *debug = (unsigned int *)0x150000;
    	//debug[0] = 0xDEADBEEF;
    	//debug[1] = vbe_info[10];
    	
	while(1) {}
}
