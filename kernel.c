void kernel_main(){
	unsigned char *fb = (unsigned char*)0xFD000000;
	int tot_bytes = 800 * 600 * 4;

	for(int i = 0; i < tot_bytes; i += 4){
		fb[i] = 0xFF; // Blue
		fb[i+1] = 0xFF; // Green
		fb[i+2] = 0xFF; // Red
		fb[i+3] = 0x00; // Alpha
	}
}
