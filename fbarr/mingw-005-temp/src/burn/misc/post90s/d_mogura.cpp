// FB Alpha Mogura Desse driver module
// Based on MAME driver by David Haywood

#include "tiles_generic.h"
#include "dac.h"

static unsigned char *AllMem;
static unsigned char *MemEnd;
static unsigned char *AllRam;
static unsigned char *RamEnd;
static unsigned char *DrvZ80ROM;
static unsigned char *DrvColPROM;
static unsigned char *DrvZ80RAM;
static unsigned char *DrvGfxRAM;
static unsigned char *DrvVidRAM;
static unsigned char *DrvGfxROM;

static unsigned int  *DrvPalette;
static unsigned char DrvRecalc;

static unsigned char DrvJoy1[8];
static unsigned char DrvJoy2[8];
static unsigned char DrvJoy3[8];
static unsigned char DrvJoy4[8];
static unsigned char DrvJoy5[8];
static unsigned char DrvReset;
static unsigned short DrvInputs[5];

static struct BurnInputInfo MoguraInputList[] = {
	{"P1 Coin",		BIT_DIGITAL,	DrvJoy1 + 0,	"p1 coin"	},
	{"P1 Start",		BIT_DIGITAL,	DrvJoy2 + 7,	"p1 start"	},
	{"P1 Up",		BIT_DIGITAL,	DrvJoy2 + 2,	"p1 up"		},
	{"P1 Down",		BIT_DIGITAL,	DrvJoy2 + 3,	"p1 down"	},
	{"P1 Left",		BIT_DIGITAL,	DrvJoy2 + 0,	"p1 left"	},
	{"P1 Right",		BIT_DIGITAL,	DrvJoy2 + 1,	"p1 right"	},
	{"P1 Button 1",		BIT_DIGITAL,	DrvJoy2 + 4,	"p1 fire 1"	},
	{"P1 Button 2",		BIT_DIGITAL,	DrvJoy2 + 5,	"p1 fire 2"	},
	{"P1 Button 3",		BIT_DIGITAL,	DrvJoy2 + 6,	"p1 fire 3"	},

	{"P2 Coin",		BIT_DIGITAL,	DrvJoy1 + 1,	"p2 coin"	},
	{"P2 Start",		BIT_DIGITAL,	DrvJoy3 + 7,	"p2 start"	},
	{"P2 Up",		BIT_DIGITAL,	DrvJoy3 + 2,	"p2 up"		},
	{"P2 Down",		BIT_DIGITAL,	DrvJoy3 + 3,	"p2 down"	},
	{"P2 Left",		BIT_DIGITAL,	DrvJoy3 + 0,	"p2 left"	},
	{"P2 Right",		BIT_DIGITAL,	DrvJoy3 + 1,	"p2 right"	},
	{"P2 Button 1",		BIT_DIGITAL,	DrvJoy3 + 4,	"p2 fire 1"	},
	{"P2 Button 2",		BIT_DIGITAL,	DrvJoy3 + 5,	"p2 fire 2"	},
	{"P2 Button 3",		BIT_DIGITAL,	DrvJoy3 + 6,	"p2 fire 3"	},

	{"P3 Coin",		BIT_DIGITAL,	DrvJoy1 + 2,	"p3 coin"	},
	{"P3 Start",		BIT_DIGITAL,	DrvJoy4 + 7,	"p3 start"	},
	{"P3 Up",		BIT_DIGITAL,	DrvJoy4 + 2,	"p3 up"		},
	{"P3 Down",		BIT_DIGITAL,	DrvJoy4 + 3,	"p3 down"	},
	{"P3 Left",		BIT_DIGITAL,	DrvJoy4 + 0,	"p3 left"	},
	{"P3 Right",		BIT_DIGITAL,	DrvJoy4 + 1,	"p3 right"	},
	{"P3 Button 1",		BIT_DIGITAL,	DrvJoy4 + 4,	"p3 fire 1"	},
	{"P3 Button 2",		BIT_DIGITAL,	DrvJoy4 + 5,	"p3 fire 2"	},
	{"P3 Button 3",		BIT_DIGITAL,	DrvJoy4 + 6,	"p3 fire 3"	},

	{"P4 Coin",		BIT_DIGITAL,	DrvJoy1 + 3,	"p4 coin"	},
	{"P4 Start",		BIT_DIGITAL,	DrvJoy5 + 7,	"p4 start"	},
	{"P4 Up",		BIT_DIGITAL,	DrvJoy5 + 2,	"p4 up"		},
	{"P4 Down",		BIT_DIGITAL,	DrvJoy5 + 3,	"p4 down"	},
	{"P4 Left",		BIT_DIGITAL,	DrvJoy5 + 0,	"p4 left"	},
	{"P4 Right",		BIT_DIGITAL,	DrvJoy5 + 1,	"p4 right"	},
	{"P4 Button 1",		BIT_DIGITAL,	DrvJoy5 + 4,	"p4 fire 1"	},
	{"P4 Button 2",		BIT_DIGITAL,	DrvJoy5 + 5,	"p4 fire 2"	},
	{"P4 Button 3",		BIT_DIGITAL,	DrvJoy5 + 6,	"p4 fire 3"	},

	{"Reset",		BIT_DIGITAL,	&DrvReset,	"reset"		},
	{"Service",		BIT_DIGITAL,	DrvJoy1 + 4,	"service"	},
};

STDINPUTINFO(Mogura)

static inline void DrvTileDecode(int offset, int data)
{
	unsigned char *tile = DrvGfxROM + (offset << 2);

	tile[0] = (data >> 6) & 3;
	tile[1] = (data >> 4) & 3;
	tile[2] = (data >> 2) & 3;
	tile[3] = (data >> 0) & 3;
}

void __fastcall mogura_write(unsigned short address, unsigned char data)
{
	if ((address & 0xf000) == 0xe000) {
		DrvGfxRAM[address & 0xfff] = data;
		DrvTileDecode(address & 0xfff, data);
		return;
	}
}

void __fastcall mogura_write_port(unsigned short port, unsigned char data)
{
	switch (port & 0xff)
	{
		case 0x14:
			DACWrite((data & 0xf0) | ((data & 0x0f) << 4));
		return;
	}
}

unsigned char __fastcall mogura_read_port(unsigned short port)
{
	switch (port & 0xff)
	{
		case 0x08:
			return DrvInputs[0];

		case 0x0c:
			return DrvInputs[1];

		case 0x0d:
			return DrvInputs[2];

		case 0x0e:
			return DrvInputs[3];

		case 0x0f:
			return DrvInputs[5];

		case 0x10:
			return 0xff;
	}

	return 0;
}

static void DrvPaletteInit()
{
	for (int i = 0; i < 0x20; i++)
	{
		int bit0,bit1,bit2,r,g,b;

		bit0 = (DrvColPROM[i] >> 0) & 0x01;
		bit1 = (DrvColPROM[i] >> 1) & 0x01;
		bit2 = (DrvColPROM[i] >> 2) & 0x01;
		r = 0x21 * bit0 + 0x47 * bit1 + 0x97 * bit2;

		bit0 = (DrvColPROM[i] >> 3) & 0x01;
		bit1 = (DrvColPROM[i] >> 4) & 0x01;
		bit2 = (DrvColPROM[i] >> 5) & 0x01;
		g = 0x21 * bit0 + 0x47 * bit1 + 0x97 * bit2;

		bit0 = 0;
		bit1 = (DrvColPROM[i] >> 6) & 0x01;
		bit2 = (DrvColPROM[i] >> 7) & 0x01;
		b = 0x21 * bit0 + 0x47 * bit1 + 0x97 * bit2;

		DrvPalette[((i & 7) << 2) | ((i >> 3) & 3)] = BurnHighCol(r, g, b, 0);
	}
}

static int DrvDoReset()
{
	memset (AllRam, 0, RamEnd - AllRam);

	ZetOpen(0);
	ZetReset();
	ZetClose();

	DACReset();

	return 0;
}

static int MemIndex()
{
	unsigned char *Next; Next = AllMem;

	DrvZ80ROM	= Next; Next += 0x008000;
	DrvColPROM	= Next; Next += 0x000020;

	DrvPalette	= (unsigned int*)Next; Next += 0x0020 * sizeof(int);

	AllRam		= Next;

	DrvGfxROM	= Next; Next += 0x004000;
	DrvGfxRAM	= Next; Next += 0x001000;

	DrvVidRAM	= Next; Next += 0x001000;

	DrvZ80RAM	= Next; Next += 0x002000;

	RamEnd		= Next;

	MemEnd		= Next;

	return 0;
}

static int DrvInit()
{
	AllMem = NULL;
	MemIndex();
	int nLen = MemEnd - (unsigned char *)0;
	if ((AllMem = (unsigned char *)malloc(nLen)) == NULL) return 1;
	memset(AllMem, 0, nLen);
	MemIndex();

	{
		if (BurnLoadRom(DrvZ80ROM,		0, 1)) return 1;

		if (BurnLoadRom(DrvColPROM,		1, 1)) return 1;
	}

	ZetInit(1);
	ZetOpen(0);
	ZetMapArea(0x0000, 0x7fff, 0, DrvZ80ROM);
	ZetMapArea(0x0000, 0x7fff, 2, DrvZ80ROM);
	ZetMapArea(0xc000, 0xdfff, 0, DrvZ80RAM);
	ZetMapArea(0xc000, 0xdfff, 1, DrvZ80RAM);
	ZetMapArea(0xc000, 0xdfff, 2, DrvZ80RAM);
	ZetMapArea(0xe000, 0xefff, 0, DrvGfxRAM);
//	ZetMapArea(0xe000, 0xefff, 1, DrvGfxRAM);
	ZetMapArea(0xe000, 0xefff, 2, DrvGfxRAM);
	ZetMapArea(0xf000, 0xffff, 0, DrvVidRAM);
	ZetMapArea(0xf000, 0xffff, 1, DrvVidRAM);
	ZetMapArea(0xf000, 0xffff, 2, DrvVidRAM);
	ZetSetWriteHandler(mogura_write);
	ZetSetOutHandler(mogura_write_port);
	ZetSetInHandler(mogura_read_port);
	ZetMemEnd();
	ZetClose();

	DACInit(0, 0);

	GenericTilesInit();

	DrvDoReset();

	return 0;
}

static int DrvExit()
{
	GenericTilesExit();

	ZetExit();
	DACExit();

	free (AllMem);
	AllMem = NULL;

	return 0;
}

static void draw_background()
{
	for (int offs = 0; offs < 64 * 32; offs++)
	{
		int sx = ((offs ^ 0x20) & 0x3f) << 3;
		int sy = (offs >> 6) << 3;

		if (sx >= 256) sx ^= 128;
		if (sx >= 320) continue;

		int code  = DrvVidRAM[offs];
		int color = (DrvVidRAM[offs + 0x800] >> 1) & 7;

		Render8x8Tile(pTransDraw, code, sx, sy, color, 2, 0, DrvGfxROM);
	}
}

static int DrvDraw()
{
	if (DrvRecalc) {
		DrvPaletteInit();
		DrvRecalc = 0;
	}

	draw_background();

	BurnTransferCopy(DrvPalette);

	return 0;
}

static int DrvFrame()
{
	if (DrvReset) {
		DrvDoReset();
	}

	{
		memset (DrvInputs, 0xff, 5);
		for (int i = 0; i < 8; i++) {
			DrvInputs[0] ^= (DrvJoy1[i] & 1) << i;
			DrvInputs[1] ^= (DrvJoy2[i] & 1) << i;
			DrvInputs[2] ^= (DrvJoy3[i] & 1) << i;
			DrvInputs[3] ^= (DrvJoy4[i] & 1) << i;
			DrvInputs[4] ^= (DrvJoy5[i] & 1) << i;
		}
	}

	int nInterleave = nBurnSoundLen ? nBurnSoundLen : 1;
	int nSoundBufferPos = 0;
	int nTotalCycles = 3000000 / 60;

	ZetOpen(0);

	for (int i = 0; i < nInterleave; i++)
	{
		ZetRun(nTotalCycles / nInterleave);

		if (pBurnSoundOut) {
			int nSegmentLength = nBurnSoundLen / nInterleave;
			short* pSoundBuf = pBurnSoundOut + (nSoundBufferPos << 1);
			DACUpdate(pSoundBuf, nSegmentLength);
			nSoundBufferPos += nSegmentLength;
		}
	}

	if (pBurnSoundOut) {
		int nSegmentLength = nBurnSoundLen - nSoundBufferPos;
		short* pSoundBuf = pBurnSoundOut + (nSoundBufferPos << 1);

		if (nSegmentLength) {
			DACUpdate(pSoundBuf, nSegmentLength);
		}
	}

	ZetRaiseIrq(0);

	ZetClose();

	if (pBurnDraw) {
		DrvDraw();
	}

	return 0;
}

static int DrvScan(int nAction, int *pnMin)
{
	struct BurnArea ba;
	
	if (pnMin != NULL) {
		*pnMin = 0x029698;
	}

	if (nAction & ACB_MEMORY_RAM) {
		memset(&ba, 0, sizeof(ba));
		ba.Data	  = AllRam;
		ba.nLen	  = RamEnd-AllRam;
		ba.szName = "All Ram";
		BurnAcb(&ba);
	}

	if (nAction & ACB_DRIVER_DATA) {
		ZetScan(nAction);

		DACScan(nAction, pnMin);
	}

	return 0;
}


// Mogura Desse

static struct BurnRomInfo moguraRomDesc[] = {
	{ "gx141.5n",	0x8000, 0x98e6120d, 1 | BRF_PRG | BRF_ESS }, //  0 Z80 Code

	{ "gx141.7j",	0x0020, 0xb21c5d5f, 2 | BRF_GRA },           //  1 Color Prom
};

STD_ROM_PICK(mogura)
STD_ROM_FN(mogura)

struct BurnDriver BurnDrvMogura = {
	"mogura", NULL, NULL, "1991",
	"Mogura Desse\0", "Konami test board", "Konami", "Miscellaneous",
	NULL, NULL, NULL, NULL,
	BDF_GAME_WORKING, 4, HARDWARE_MISC_POST90S, GBF_MISC, 0,
	NULL, moguraRomInfo, moguraRomName, MoguraInputInfo, NULL,
	DrvInit, DrvExit, DrvFrame, DrvDraw, DrvScan, 0, NULL, NULL, NULL, &DrvRecalc, 0x20,
	320, 256, 4, 3
};
