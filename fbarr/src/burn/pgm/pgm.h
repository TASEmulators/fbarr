#include "tiles_generic.h"
#include "arm7_intf.h"
#include "ics2115.h"

// pgm_run
extern int nPGM68KROMLen;
extern int nPGMSPRColMaskLen;
extern int nPGMSPRMaskMaskLen;
extern int nPGMTileROMLen;

extern unsigned char *Ram68K;
extern unsigned char *PGM68KROM;
extern unsigned char *PGMTileROM;
extern unsigned char *PGMTileROMExp;
extern unsigned char *PGMSPRColROM;
extern unsigned char *PGMSPRMaskROM;
extern unsigned char *PGMARMROM;
extern unsigned char *PGMUSER0;
extern unsigned char *PGMARMRAM0;
extern unsigned char *PGMARMRAM1;
extern unsigned char *PGMARMRAM2;
extern unsigned char *PGMARMShareRAM;
extern unsigned char *PGMARMShareRAM2;
extern unsigned short *RamRs;
extern unsigned short *PgmRamPal;
extern unsigned short *RamVReg;
extern unsigned short *RamSpr;
extern unsigned short *RamSprBuf;
extern unsigned int *RamBg;
extern unsigned int *RamTx;
extern unsigned int *RamCurPal;
extern unsigned char nPgmPalRecalc;

extern unsigned char PgmJoy1[];
extern unsigned char PgmJoy2[];
extern unsigned char PgmJoy3[];
extern unsigned char PgmJoy4[];
extern unsigned char PgmBtn1[];
extern unsigned char PgmBtn2[];
extern unsigned char PgmInput[];
extern unsigned char PgmReset;

extern void (*pPgmInitCallback)();
extern void (*pPgmResetCallback)();
extern int (*pPgmScanCallback)(int, int*);

int pgmInit();
int pgmExit();
int pgmFrame();
int pgmScan(int nAction, int *pnMin);

// pgm_draw
void pgmInitDraw();
void pgmExitDraw();
int pgmDraw();

// pgm_prot
void install_protection_asic3();
void install_protection_asic27A();
void install_protection_asic28();
void install_protection_dw2();
void install_protection_puzlstar();
void install_protection_killbldt();
void install_protection_olds();
void install_protection_kovsh();
void install_protection_svg();

void reset_puzlstar();
void reset_killbldt();
void reset_asic28();
void reset_asic3();
void reset_olds();

// pgm_crypt
void pgm_decrypt_kov();
void pgm_decrypt_kovsh();
void pgm_decrypt_kovshp();
void pgm_decrypt_puzzli2();
void pgm_decrypt_dw2();
void pgm_decrypt_photoy2k();
void pgm_decrypt_puzlstar();
void pgm_decrypt_dw3();
void pgm_decrypt_killbld();
void pgm_decrypt_dfront();
void pgm_decrypt_ddp2();
void pgm_decrypt_martmast();
void pgm_decrypt_kov2();
void pgm_decrypt_kov2p();
void pgm_decrypt_theglad();
void pgm_decrypt_killbldp();
void pgm_decrypt_oldsplus();
void pgm_decrypt_svg();
