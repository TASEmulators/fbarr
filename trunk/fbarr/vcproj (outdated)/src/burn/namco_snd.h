extern unsigned char* NamcoSoundProm;
void NamcoSoundUpdate(short* buffer, int length);
void NamcoSoundWrite(unsigned int offset, unsigned char data);
void NamcoSoundInit(int clock);
void NamcoSoundExit();
void NamcoSoundScan(int nAction,int *pnMin);
