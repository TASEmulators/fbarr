// FB Alpha Face "LINDA" hardware driver module
// Based on MAME driver by Paul Priest and David Haywood

// To do:
// Fix sprite priorities
//   the game itself is setting them incorrectly?

#include "tiles_generic.h"
#include "burn_ym2610.h"

static unsigned char *AllMem;
static unsigned char *MemEnd;
static unsigned char *AllRam;
static unsigned char *RamEnd;
static unsigned char *Drv68KROM;
static unsigned char *Drv68KRAM;
static unsigned char *DrvZ80ROM;
static unsigned char *DrvZ80RAM;
static unsigned char *DrvGfxROM0;
static unsigned char *DrvGfxROM1;
static unsigned char *DrvGfxROM2;
static unsigned char *DrvSndROM;
static unsigned char *DrvVidRAM0;
static unsigned char *DrvVidRAM1;
static unsigned char *DrvSprRAM;
static unsigned char *DrvSprBuf;
static unsigned char *DrvPalRAM;
static unsigned int  *DrvPalette;

static unsigned char DrvRecalc;

static unsigned char DrvJoy1[16];
static unsigned char DrvJoy2[16];
static unsigned char DrvDips[ 2];
static unsigned short DrvInputs[2];
static unsigned char DrvReset;

static unsigned short *DrvScrollRAM0;
static unsigned short *DrvScrollRAM1;
static unsigned short *DrvVidRegs;
static unsigned short *DrvVidRegBuf;

static unsigned char *nDrvZ80Bank;
static unsigned char *soundlatch;
static unsigned char *soundlatch2;

static int nCyclesTotal[2];
static int nCyclesDone[2];
static int watchdog;

static int nGame;

static struct BurnInputInfo McatadvInputList[] = {
	{"P1 Coin",		BIT_DIGITAL,	DrvJoy1 + 8,	"p1 coin"	},
	{"P1 Start",		BIT_DIGITAL,	DrvJoy1 + 7,	"p1 start"	},
	{"P1 Up",		BIT_DIGITAL,	DrvJoy1 + 0,	"p1 up"		},
	{"P1 Down",		BIT_DIGITAL,	DrvJoy1 + 1,	"p1 down"	},
	{"P1 Left",		BIT_DIGITAL,	DrvJoy1 + 2,	"p1 left"	},
	{"P1 Right",		BIT_DIGITAL,	DrvJoy1 + 3,	"p1 right"	},
	{"P1 Button 1",		BIT_DIGITAL,	DrvJoy1 + 4,	"p1 fire 1"	},
	{"P1 Button 2",		BIT_DIGITAL,	DrvJoy1 + 5,	"p1 fire 2"	},
	{"P1 Button 3",		BIT_DIGITAL,	DrvJoy1 + 6,	"p1 fire 3"	},

	{"P2 Coin",		BIT_DIGITAL,	DrvJoy2 + 8,	"p2 coin"	},
	{"P2 Start",		BIT_DIGITAL,	DrvJoy2 + 7,	"p2 start"	},
	{"P2 Up",		BIT_DIGITAL,	DrvJoy2 + 0,	"p2 up"		},
	{"P2 Down",		BIT_DIGITAL,	DrvJoy2 + 1,	"p2 down"	},
	{"P2 Left",		BIT_DIGITAL,	DrvJoy2 + 2,	"p2 left"	},
	{"P2 Right",		BIT_DIGITAL,	DrvJoy2 + 3,	"p2 right"	},
	{"P2 Button 1",		BIT_DIGITAL,	DrvJoy2 + 4,	"p2 fire 1"	},
	{"P2 Button 2",		BIT_DIGITAL,	DrvJoy2 + 5,	"p2 fire 2"	},

	{"Reset",		BIT_DIGITAL,	&DrvReset,	"reset"		},
	{"Service",		BIT_DIGITAL,	DrvJoy2 + 9,	"service"	},
	{"Dip A",		BIT_DIPSWITCH,	DrvDips + 0,	"dip"		},
	{"Dip B",		BIT_DIPSWITCH,	DrvDips + 1,	"dip"		},
};

STDINPUTINFO(Mcatadv)

static struct BurnDIPInfo McatadvDIPList[]=
{
	{0x13, 0xff, 0xff, 0xff, NULL				},
	{0x14, 0xff, 0xff, 0xff, NULL				},

	{0   , 0xfe, 0   ,    2, "Demo Sounds"			},
	{0x13, 0x01, 0x01, 0x00, "Off"				},
	{0x13, 0x01, 0x01, 0x01, "On"				},

//	{0   , 0xfe, 0   ,    2, "Flip Screen"			},
//	{0x13, 0x01, 0x02, 0x02, "Off"				},
//	{0x13, 0x01, 0x02, 0x00, "On"				},

	{0   , 0xfe, 0   ,    2, "Coin Mode"			},
	{0x13, 0x01, 0x08, 0x08, "Mode 1"			},
	{0x13, 0x01, 0x08, 0x00, "Mode 2"			},

	{0   , 0xfe, 0   ,    7, "Coin A"			},
	{0x13, 0x01, 0x30, 0x00, "4 Coins 1 Credits "		},
	{0x13, 0x01, 0x30, 0x10, "3 Coins 1 Credits "		},
	{0x13, 0x01, 0x30, 0x10, "2 Coins 1 Credits "		},
	{0x13, 0x01, 0x30, 0x30, "1 Coin  1 Credits "		},
	{0x13, 0x01, 0x30, 0x00, "2 Coins 3 Credits "		},
	{0x13, 0x01, 0x30, 0x20, "1 Coin  2 Credits "		},
	{0x13, 0x01, 0x30, 0x20, "1 Coin  4 Credits "		},

	{0   , 0xfe, 0   ,    7, "Coin B"			},
	{0x13, 0x01, 0xc0, 0x00, "4 Coins 1 Credits "		},
	{0x13, 0x01, 0xc0, 0x40, "3 Coins 1 Credits "		},
	{0x13, 0x01, 0xc0, 0x40, "2 Coins 1 Credits "		},
	{0x13, 0x01, 0xc0, 0xc0, "1 Coin  1 Credits "		},
	{0x13, 0x01, 0xc0, 0x00, "2 Coins 3 Credits "		},
	{0x13, 0x01, 0xc0, 0x80, "1 Coin  2 Credits "		},
	{0x13, 0x01, 0xc0, 0x80, "1 Coin  4 Credits "		},

	{0   , 0xfe, 0   ,    4, "Difficulty"			},
	{0x14, 0x01, 0x03, 0x02, "Easy"				},
	{0x14, 0x01, 0x03, 0x03, "Normal"			},
	{0x14, 0x01, 0x03, 0x01, "Hard"				},
	{0x14, 0x01, 0x03, 0x00, "Hardest"			},

	{0   , 0xfe, 0   ,    4, "Lives"			},
	{0x14, 0x01, 0x0c, 0x04, "2"				},
	{0x14, 0x01, 0x0c, 0x0c, "3"				},
	{0x14, 0x01, 0x0c, 0x08, "4"				},
	{0x14, 0x01, 0x0c, 0x00, "5"				},

	{0   , 0xfe, 0   ,    4, "Energy"			},
	{0x14, 0x01, 0x30, 0x30, "3"				},
	{0x14, 0x01, 0x30, 0x20, "4"				},
	{0x14, 0x01, 0x30, 0x10, "5"				},
	{0x14, 0x01, 0x30, 0x00, "8"				},

	{0   , 0xfe, 0   ,    3, "Cabinet"			},
	{0x14, 0x01, 0xc0, 0x40, "Upright 1 Player"		},
	{0x14, 0x01, 0xc0, 0xc0, "Upright 2 Players"		},
	{0x14, 0x01, 0xc0, 0x80, "Cocktail"			},
};

STDDIPINFO(Mcatadv)

static struct BurnInputInfo NostInputList[] = {
	{"P1 Coin",		BIT_DIGITAL,	DrvJoy1 + 8,	"p1 coin"	},
	{"P1 Start",		BIT_DIGITAL,	DrvJoy1 + 7,	"p1 start"	},
	{"P1 Up",		BIT_DIGITAL,	DrvJoy1 + 0,	"p1 up"		},
	{"P1 Down",		BIT_DIGITAL,	DrvJoy1 + 1,	"p1 down"	},
	{"P1 Left",		BIT_DIGITAL,	DrvJoy1 + 2,	"p1 left"	},
	{"P1 Right",		BIT_DIGITAL,	DrvJoy1 + 3,	"p1 right"	},
	{"P1 Button 1",		BIT_DIGITAL,	DrvJoy1 + 4,	"p1 fire 1"	},

	{"P2 Coin",		BIT_DIGITAL,	DrvJoy2 + 8,	"p2 coin"	},
	{"P2 Start",		BIT_DIGITAL,	DrvJoy2 + 7,	"p2 start"	},
	{"P2 Up",		BIT_DIGITAL,	DrvJoy2 + 0,	"p2 up"		},
	{"P2 Down",		BIT_DIGITAL,	DrvJoy2 + 1,	"p2 down"	},
	{"P2 Left",		BIT_DIGITAL,	DrvJoy2 + 2,	"p2 left"	},
	{"P2 Right",		BIT_DIGITAL,	DrvJoy2 + 3,	"p2 right"	},
	{"P2 Button 1",		BIT_DIGITAL,	DrvJoy2 + 4,	"p2 fire 1"	},

	{"Reset",		BIT_DIGITAL,	&DrvReset,	"reset"		},
	{"Service",		BIT_DIGITAL,	DrvJoy2 + 9,	"service"	},
	{"Dip A",		BIT_DIPSWITCH,	DrvDips + 0,	"dip"		},
	{"Dip B",		BIT_DIPSWITCH,	DrvDips + 1,	"dip"		},
};

STDINPUTINFO(Nost)

static struct BurnDIPInfo NostDIPList[]=
{
	{0x10, 0xff, 0xff, 0xff, NULL			},
	{0x11, 0xff, 0xff, 0xff, NULL			},

	{0   , 0xfe, 0   ,    4, "Lives"		},
	{0x10, 0x01, 0x03, 0x02, "2"			},
	{0x10, 0x01, 0x03, 0x03, "3"			},
	{0x10, 0x01, 0x03, 0x01, "4"			},
	{0x10, 0x01, 0x03, 0x00, "5"			},

	{0   , 0xfe, 0   ,    4, "Difficulty"		},
	{0x10, 0x01, 0x0c, 0x08, "Easy"			},
	{0x10, 0x01, 0x0c, 0x0c, "Normal"		},
	{0x10, 0x01, 0x0c, 0x04, "Hard"			},
	{0x10, 0x01, 0x0c, 0x00, "Hardest"		},

//	{0   , 0xfe, 0   ,    2, "Flip Screen"		},
//	{0x10, 0x01, 0x10, 0x10, "Off"			},
//	{0x10, 0x01, 0x10, 0x00, "On"			},

	{0   , 0xfe, 0   ,    2, "Demo Sounds"		},
	{0x10, 0x01, 0x20, 0x00, "Off"			},
	{0x10, 0x01, 0x20, 0x20, "On"			},

	{0   , 0xfe, 0   ,    4, "Bonus Life"		},
	{0x10, 0x01, 0xc0, 0x80, "500k 1000k"		},
	{0x10, 0x01, 0xc0, 0xc0, "800k 1500k"		},
	{0x10, 0x01, 0xc0, 0x40, "1000k 2000k"		},
	{0x10, 0x01, 0xc0, 0x00, "None"			},

	{0   , 0xfe, 0   ,    8, "Coin A"		},
	{0x11, 0x01, 0x07, 0x02, "3 Coins 1 Credits "	},
	{0x11, 0x01, 0x07, 0x04, "2 Coins 1 Credits "	},
	{0x11, 0x01, 0x07, 0x01, "3 Coins 2 Credits "	},
	{0x11, 0x01, 0x07, 0x07, "1 Coin  1 Credits "	},
	{0x11, 0x01, 0x07, 0x03, "2 Coins 3 Credits "	},
	{0x11, 0x01, 0x07, 0x06, "1 Coin  2 Credits "	},
	{0x11, 0x01, 0x07, 0x05, "1 Coin  3 Credits "	},
	{0x11, 0x01, 0x07, 0x00, "Free Play"		},

	{0   , 0xfe, 0   ,    8, "Coin_B"		},
	{0x11, 0x01, 0x38, 0x00, "4 Coins 1 Credits "	},
	{0x11, 0x01, 0x38, 0x10, "3 Coins 1 Credits "	},
	{0x11, 0x01, 0x38, 0x20, "2 Coins 1 Credits "	},
	{0x11, 0x01, 0x38, 0x08, "3 Coins 2 Credits "	},
	{0x11, 0x01, 0x38, 0x38, "1 Coin  1 Credits "	},
	{0x11, 0x01, 0x38, 0x18, "2 Coins 3 Credits "	},
	{0x11, 0x01, 0x38, 0x30, "1 Coin  2 Credits "	},
	{0x11, 0x01, 0x38, 0x28, "1 Coin  3 Credits "	},
};

STDDIPINFO(Nost)

static inline void mcatadv_z80_sync()
{
#if 0
	float nCycles = SekTotalCycles() * 1.0000;
	nCycles /= nCyclesTotal[0];
	nCycles *= nCyclesTotal[1];
	nCycles -= nCyclesDone[1];
	if (nCycles > 0) {
		nCyclesDone[1] += ZetRun((int)nCycles);
	}
#endif
}

static inline void palette_write(int offset)
{
	unsigned char r,g,b;
	unsigned short data = *((unsigned short*)(DrvPalRAM + offset));

	r = (data >>  5) & 0x1f;
	r = (r << 3) | (r >> 2);

	g = (data >> 10) & 0x1f;
	g = (g << 3) | (g >> 2);

	b = (data >>  0) & 0x1f;
	b = (b << 3) | (b >> 2);

	DrvPalette[offset/2] = BurnHighCol(r, g, b, 0);
}

void __fastcall mcatadv_write_byte(unsigned int /*address*/, unsigned char /*data*/)
{

}

void __fastcall mcatadv_write_word(unsigned int address, unsigned short data)
{
	switch (address)
	{
		case 0x200000:
		case 0x200002:
		case 0x200004:
			DrvScrollRAM0[(address & 6) >> 1] = data;
		return;

		case 0x300000:
		case 0x300002:
		case 0x300004:
			DrvScrollRAM1[(address & 6) >> 1] = data;
		return;

		case 0xb00000:
		case 0xb00002:
		case 0xb00004:
		case 0xb00006:
		case 0xb00008:
		case 0xb0000a:
		case 0xb0000c:
		case 0xb0000e:
			DrvVidRegs[(address & 0x0e) >> 1] = data;
		return;

		case 0xb00018:
			watchdog = 0;
		return;

		case 0xc00000:
		{
			mcatadv_z80_sync();

			*soundlatch = data;
			ZetNmi();
		}
		return;
	}
}

unsigned char __fastcall mcatadv_read_byte(unsigned int address)
{
	switch (address)
	{
		case 0x800000:
			return DrvInputs[0] >> 8;

		case 0x800001:
			return DrvInputs[0] & 0xff;

		case 0x800002:
			return DrvInputs[1] >> 8;

		case 0x800003:
			return DrvInputs[1] & 0xff;
	}

	return 0;
}

unsigned short __fastcall mcatadv_read_word(unsigned int address)
{
	switch (address)
	{
		case 0x800000:
			return DrvInputs[0];

		case 0x800002:
			return DrvInputs[1];

		case 0xa00000:
			return (DrvDips[0] << 8) | 0x00ff;

		case 0xa00002:
			return (DrvDips[1] << 8) | 0x00ff;

		case 0xb0001e:
			watchdog = 0;
			return 0x0c00;

		case 0xc00000:
			mcatadv_z80_sync();
			return *soundlatch2;
	}

	return 0;
}

static void sound_bankswitch(int data)
{
	*nDrvZ80Bank = data;

	ZetMapArea(0x4000 << nGame, 0xbfff, 0, DrvZ80ROM + (data * 0x4000));
	ZetMapArea(0x4000 << nGame, 0xbfff, 2, DrvZ80ROM + (data * 0x4000));
}	

void __fastcall mcatadv_sound_write(unsigned short address, unsigned char data)
{
	switch (address)
	{
		case 0xe000:
		case 0xe001:
		case 0xe002:
		case 0xe003:
			BurnYM2610Write(address & 3, data);
		return;

		case 0xf000:
			sound_bankswitch(data);
		return;
	}
}

unsigned char __fastcall mcatadv_sound_read(unsigned short address)
{
	switch (address)
	{
		case 0xe000:
		case 0xe002:
			return BurnYM2610Read(address & 2);
	}

	return 0;
}

void __fastcall mcatadv_sound_out(unsigned short port, unsigned char data)
{
	switch (port & 0xff)
	{
		case 0x00:
		case 0x01:
		case 0x02:
		case 0x03:
			BurnYM2610Write(port & 3, data);
		return;

		case 0x40:
			sound_bankswitch(data);
		return;

		case 0x80:
			*soundlatch2 = data;
		return;
	}
}

unsigned char __fastcall mcatadv_sound_in(unsigned short port)
{
	switch (port & 0xff)
	{
		case 0x04:
		case 0x05:
		case 0x06:
		case 0x07:
			return BurnYM2610Read(port & 3); 

		case 0x80:
			return *soundlatch;
	}

	return 0;
}

static void DrvFMIRQHandler(int, int nStatus)
{
	if (nStatus) {
		ZetSetIRQLine(0xff, ZET_IRQSTATUS_ACK);
	} else {
		ZetSetIRQLine(0,    ZET_IRQSTATUS_NONE);
	}
}

static int DrvSynchroniseStream(int nSoundRate)
{
	return (long long)ZetTotalCycles() * nSoundRate / 4000000;
}

static double DrvGetTime()
{
	return (double)ZetTotalCycles() / 4000000.0;
}

static int DrvGfxDecode()
{
	static int Planes[4] = { 0, 1, 2, 3 };
	static int XOffs[16] = { 0, 4, 8, 12, 16, 20, 24, 28, 256, 260, 264, 268, 272, 276, 280, 284 };
	static int YOffs[16] = { 0, 32, 64, 96, 128, 160, 192, 224, 512, 544, 576, 608, 640, 672, 704, 736 };

	unsigned char *tmp = (unsigned char*)malloc(0x280000);
	if (tmp == NULL) {
		return 1;
	}

	memcpy (tmp, DrvGfxROM1, 0x180000);

	GfxDecode(0x3000, 4, 16, 16, Planes, XOffs, YOffs, 0x400, tmp, DrvGfxROM1);

	memcpy (tmp, DrvGfxROM2, 0x280000);

	GfxDecode(0x5000, 4, 16, 16, Planes, XOffs, YOffs, 0x400, tmp, DrvGfxROM2);

	free (tmp);

	return 0;
}

static int MemIndex()
{
	unsigned char *Next; Next = AllMem;

	Drv68KROM		= Next; Next += 0x100000;
	DrvZ80ROM		= Next; Next += 0x040000;

	DrvGfxROM0		= Next; Next += 0x600000;
	DrvGfxROM1		= Next; Next += 0x300000;
	DrvGfxROM2		= Next; Next += 0x500000;

	DrvSndROM		= Next; Next += 0x100000;

	DrvPalette		= (unsigned int*)Next; Next += 0x1001 * sizeof(int);

	AllRam			= Next;

	Drv68KRAM		= Next; Next += 0x010000;
	DrvZ80RAM		= Next; Next += 0x002000;

	DrvVidRAM0		= Next; Next += 0x002000;
	DrvVidRAM1		= Next; Next += 0x002000;
	DrvPalRAM		= Next; Next += 0x003000;
	DrvSprRAM		= Next; Next += 0x010000;
	DrvSprBuf		= Next; Next += 0x008000;

	DrvScrollRAM0		= (unsigned short*)Next; Next += 0x000004 * sizeof(short);
	DrvScrollRAM1		= (unsigned short*)Next; Next += 0x000004 * sizeof(short);
	DrvVidRegs		= (unsigned short*)Next; Next += 0x000008 * sizeof(short);
	DrvVidRegBuf		= (unsigned short*)Next; Next += 0x000008 * sizeof(short);

	nDrvZ80Bank		= Next; Next += 0x000001;
	soundlatch		= Next; Next += 0x000001;
	soundlatch2		= Next; Next += 0x000001;

	RamEnd			= Next;

	MemEnd			= Next;

	return 0;
}

static int DrvDoReset()
{
	DrvReset = 0;

	memset (AllRam, 0, RamEnd - AllRam);

	SekOpen(0);
	SekReset();
	SekClose();

	ZetOpen(0);
	ZetReset();
	sound_bankswitch(1);
	ZetClose();

	BurnYM2610Reset();

	watchdog = 0;

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
		if (BurnLoadRom(Drv68KROM  + 0x000001,	0, 2)) return 1;
		if (BurnLoadRom(Drv68KROM  + 0x000000,	1, 2)) return 1;

		if (BurnLoadRom(DrvZ80ROM,		2, 1)) return 1;

		if (BurnLoadRom(DrvGfxROM0 + 0x000000,	3, 2)) return 1;
		if (BurnLoadRom(DrvGfxROM0 + 0x000001,	4, 2)) return 1;
		if (BurnLoadRom(DrvGfxROM0 + 0x200000,	5, 2)) return 1;
		if (BurnLoadRom(DrvGfxROM0 + 0x200001,	6, 2)) return 1;
		if (BurnLoadRom(DrvGfxROM0 + 0x400000,	7, 2)) return 1;
		if (BurnLoadRom(DrvGfxROM0 + 0x400001,	8, 2)) return 1;

		if (BurnLoadRom(DrvSndROM  + 0x000000, 13, 1)) return 1;

		if (DrvZ80ROM[0x20000])
		{
			if (BurnLoadRom(DrvGfxROM1 + 0x000000,	9, 1)) return 1;
			if (BurnLoadRom(DrvGfxROM1 + 0x100000, 10, 1)) return 1;
	
			if (BurnLoadRom(DrvGfxROM2 + 0x000000, 11, 1)) return 1;
			if (BurnLoadRom(DrvGfxROM2 + 0x100000, 12, 1)) return 1;

			nGame = 1;
		}
		else
		{
			if (BurnLoadRom(DrvGfxROM1 + 0x000000,	9, 1)) return 1;
	
			if (BurnLoadRom(DrvGfxROM2 + 0x000000, 10, 1)) return 1;
			if (BurnLoadRom(DrvGfxROM2 + 0x100000, 11, 1)) return 1;
			if (BurnLoadRom(DrvGfxROM2 + 0x200000, 12, 1)) return 1;

			nGame = 0;
		}
	}

	DrvGfxDecode();

	SekInit(0, 0x68000);
	SekOpen(0);
	SekMapMemory(Drv68KROM,			0x000000, 0x0fffff, SM_ROM);
	SekMapMemory(Drv68KRAM,			0x100000, 0x10ffff, SM_RAM);
	SekMapMemory(DrvVidRAM0,		0x400000, 0x401fff, SM_RAM);
	SekMapMemory(DrvVidRAM1,		0x500000, 0x501fff, SM_RAM);
	SekMapMemory(DrvPalRAM,			0x600000, 0x602fff, SM_RAM);
	SekMapMemory(DrvSprRAM,			0x700000, 0x70ffff, SM_RAM);
	SekSetWriteByteHandler(0,		mcatadv_write_byte);
	SekSetWriteWordHandler(0,		mcatadv_write_word);
	SekSetReadByteHandler(0,		mcatadv_read_byte);
	SekSetReadWordHandler(0,		mcatadv_read_word);
	SekClose();

	ZetInit(1);
	ZetOpen(0);
	ZetMapArea(0x0000, 0x7fff, 0, DrvZ80ROM);
	ZetMapArea(0x0000, 0x7fff, 2, DrvZ80ROM);
	ZetMapArea(0xc000, 0xdfff, 0, DrvZ80RAM);
	ZetMapArea(0xc000, 0xdfff, 1, DrvZ80RAM);
	ZetMapArea(0xc000, 0xdfff, 2, DrvZ80RAM);
	ZetSetWriteHandler(mcatadv_sound_write);
	ZetSetReadHandler(mcatadv_sound_read);
	ZetSetInHandler(mcatadv_sound_in);
	ZetSetOutHandler(mcatadv_sound_out);
	ZetMemEnd();
	ZetClose();

	int DrvSndROMLen = nGame ? 0x100000 : 0x80000;
	BurnYM2610Init(8000000, DrvSndROM, &DrvSndROMLen, DrvSndROM, &DrvSndROMLen, &DrvFMIRQHandler, DrvSynchroniseStream, DrvGetTime, 0);
	BurnTimerAttachZet(4000000);

	GenericTilesInit();

	DrvDoReset();

	return 0;
}

static int DrvExit()
{
	GenericTilesExit();

	SekExit();
	ZetExit();
	BurnYM2610Exit();

	free (AllMem);
	AllMem = NULL;

	return 0;
}

static void draw_sprites(int priority)
{
	unsigned short *source = (unsigned short*)DrvSprBuf;
	unsigned short *vidregram = DrvVidRegs;
	unsigned short *vidregbuf = DrvVidRegBuf;
	unsigned short *finish = source + 0x2000-4;
	int global_x = vidregram[0]-0x184;
	int global_y = vidregram[1]-0x1f1;

	unsigned short *destline;

	int xstart, xend, xinc;
	int ystart, yend, yinc;

	if (vidregbuf[2] == 0x0001)
	{
		source += 0x2000;
		finish += 0x2000;
	}

	while (source < finish)
	{
		int attr = source[0];
		int prio = attr >> 14;
		if (prio < priority) { // good?
			source += 4;
			continue;
		}

		int pen    = (attr & 0x3f00) >> 4;
		int tileno =  source[1];
		int x      =  source[2] & 0x03ff;
		int y      =  source[3] & 0x03ff;
		int flipy  =  attr & 0x0040;
		int flipx  =  attr & 0x0080;

		int height = (source[3] & 0xf000) >> 8;
		int width  = (source[2] & 0xf000) >> 8;
		int offset = tileno << 8;

		unsigned char *sprdata = DrvGfxROM0;

		int drawxpos, drawypos;
		int xcnt,ycnt;
		int pix;

		if (x & 0x200) x-=0x400;
		if (y & 0x200) y-=0x400;

		if (source[3] != source[0])
		{
			if(!flipx) { xstart = 0;        xend = width;  xinc =  1; }
			else       { xstart = width-1;  xend = -1;     xinc = -1; }
			if(!flipy) { ystart = 0;        yend = height; yinc =  1; }
			else       { ystart = height-1; yend = -1;     yinc = -1; }

			for (ycnt = ystart; ycnt != yend; ycnt += yinc) {
				drawypos = y+ycnt-global_y;

				if ((drawypos >= 0) && (drawypos < 224)) {
					destline = pTransDraw + drawypos * 320;

					for (xcnt = xstart; xcnt != xend; xcnt += xinc) {
						drawxpos = x+xcnt-global_x;

						if (offset >= 0xa00000) offset = 0;
						pix = sprdata[offset >> 1];

						if (offset & 1)  pix >>= 4;
						pix &= 0x0f;

						if ((drawxpos >= 0) && (drawxpos < 320) && pix)
							destline[drawxpos] = pix | pen;

						offset++;
					}
				} else  {
					offset += width;
				}
			}
		}
		source+=4;
	}

	return;
}

static void draw_background(unsigned char *vidramsrc, unsigned char *gfxbase, unsigned short *scroll, int priority, int max_tile)
{
	unsigned short *vidram = (unsigned short*)vidramsrc;
	unsigned short *dest   = pTransDraw;

	int yscroll = ((scroll[1] & 0x1ff) - 0x1df) & 0x1ff;
	int xscroll = ((scroll[0] & 0x1ff) - 0x194) & 0x1ff;

	if (~scroll[1] & 0x4000 && ~scroll[0] & 0x4000) { // row by row
		yscroll &= 0x1ff;
		xscroll &= 0x1ff;

		for (int y = 0; y < 239; y+=16)
		{
			for (int x = 0; x < 335; x+=16)
			{
				int sy = y - (yscroll & 0x0f);
				int sx = x - (xscroll & 0x0f);
				if (sy < -15 || sx < -15 || sy >= nScreenHeight || sx >= nScreenWidth) continue;

				int offs = (((yscroll+y)&0x1f0) << 2) | (((xscroll+x)&0x1f0)>>3);

				if ((vidram[offs] >> 14) != priority) continue;

				int code  = vidram[offs | 1];
				if (!code || code >= max_tile) continue;
				int color = ((vidram[offs] >> 8) & 0x3f) | ((scroll[2] & 3) << 6); 

				Render16x16Tile_Mask_Clip(pTransDraw, code, sx, sy, color, 4, 0, 0, gfxbase);
			}
		}

		return;
	}

	for (int y = 0; y < 224; y++, dest += 320) // line by line
	{
		int scrollx = xscroll;
		int scrolly = (yscroll + y) & 0x1ff;

		if (scroll[1] & 0x4000) scrolly  = vidram[0x0800 + (scrolly * 2) + 1] & 0x1ff;
		if (scroll[0] & 0x4000)	scrollx += vidram[0x0800 + (scrolly * 2) + 0];

		int srcy = (scrolly & 0x1ff) >> 4;
		int srcx = (scrollx & 0x1ff) >> 4;	

		for (int x = 0; x < 336; x+=16)
		{
			int offs = ((srcy << 5) | ((srcx + (x >> 4)) & 0x1f)) << 1;

			if ((vidram[offs] >> 14) != priority) continue;

			int code  = vidram[offs | 1];
			if (!code || code >= max_tile) continue;

			int color = ((vidram[offs] >> 4) & 0x3f0) | ((scroll[2] & 3) << 10);

			unsigned char *gfxsrc = gfxbase + (code << 8) + ((scrolly & 0x0f) << 4);

			for (int dx = 0; dx < 16; dx++)
			{
				int dst = (x + dx) - (scrollx & 0x0f);
				if (dst < 0 || dst >= nScreenWidth) continue;

				if (gfxsrc[dx])
					dest[dst] = color | gfxsrc[dx];
			}
		}
	}
}

static int DrvDraw()
{
	if (DrvRecalc) {
		for (int i = 0; i < 0x2000; i+=2) {
			palette_write(i);
		}
		DrvPalette[0x1000] = 0;
	}
		
	for (int i = 0; i < nScreenWidth * nScreenHeight; i++) {
		pTransDraw[i] = 0x1000;
	}

	for (int i = 0; i < 4; i++)
	{
		draw_sprites(3-i); // correct?

		draw_background(DrvVidRAM0, DrvGfxROM1, DrvScrollRAM0, i, 0x3000);
		draw_background(DrvVidRAM1, DrvGfxROM2, DrvScrollRAM1, i, 0x5000);
	}

	memcpy (DrvSprBuf, DrvSprRAM, 0x08000);
	memcpy (DrvVidRegBuf, DrvVidRegs, 0x10);

	BurnTransferCopy(DrvPalette);

	return 0;
}

static int DrvFrame()
{
	if (DrvReset) {
		DrvDoReset();
	}

	{
		DrvInputs[0] = DrvInputs[1] = 0xffff;
		for (int i = 0; i < 16; i++) {
			DrvInputs[0] ^= (DrvJoy1[i] & 1) << i;
			DrvInputs[1] ^= (DrvJoy2[i] & 1) << i;
		}

		DrvInputs[0] ^= (nGame << 11);
	}


	nCyclesTotal[0] = 16000000 / 60;
	nCyclesTotal[1] = 4000000 / 60;
	nCyclesDone[1 ] = 0;

	SekOpen(0);
	ZetOpen(0);

	SekNewFrame();
	ZetNewFrame();

	watchdog++;
	if (watchdog == 180) {
		SekReset();
		ZetReset();
		watchdog = 0;
	}

	SekRun(nCyclesTotal[0]);
	SekSetIRQLine(1, SEK_IRQSTATUS_AUTO);

	if (nCyclesTotal[1] - nCyclesDone[1] > 0)
		BurnTimerEndFrame(nCyclesTotal[1] - nCyclesDone[1]);

	if (pBurnSoundOut) {
		BurnYM2610Update(pBurnSoundOut, nBurnSoundLen);
	}

	ZetClose();
	SekClose();

	if (pBurnDraw) {
		DrvDraw();
	}

	return 0;
}

static int DrvScan(int nAction, int *pnMin)
{
	struct BurnArea ba;
	
	if (pnMin != NULL) {
		*pnMin = 0x029702;
	}

	if (nAction & ACB_MEMORY_RAM) {
		memset(&ba, 0, sizeof(ba));
		ba.Data	  = AllRam;
		ba.nLen	  = RamEnd-AllRam;
		ba.szName = "All Ram";
		BurnAcb(&ba);
	}

	if (nAction & ACB_DRIVER_DATA) {
		SekScan(nAction);
		ZetScan(nAction);

		BurnYM2610Scan(nAction, pnMin);

		SCAN_VAR(nCyclesDone[1]);
		SCAN_VAR(watchdog);
	}

	if (nAction & ACB_WRITE) {
		ZetOpen(0);
		sound_bankswitch(*nDrvZ80Bank);
		ZetClose();
	}

	return 0;
}


// Magical Cat Adventure

static struct BurnRomInfo mcatadvRomDesc[] = {
	{ "mca-u30e",		0x080000, 0xc62fbb65, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code
	{ "mca-u29e",		0x080000, 0xcf21227c, 1 | BRF_PRG | BRF_ESS }, //  1

	{ "u9.bin",		0x020000, 0xfda05171, 2 | BRF_PRG | BRF_ESS }, //  2 Z80 code

	{ "mca-u82.bin",	0x100000, 0x5f01d746, 3 | BRF_GRA },           //  3 Sprites
	{ "mca-u83.bin",	0x100000, 0x4e1be5a6, 3 | BRF_GRA },           //  4
	{ "mca-u84.bin",	0x080000, 0xdf202790, 3 | BRF_GRA },           //  5
	{ "mca-u85.bin",	0x080000, 0xa85771d2, 3 | BRF_GRA },           //  6
	{ "mca-u86e",		0x080000, 0x017bf1da, 3 | BRF_GRA },           //  7
	{ "mca-u87e",		0x080000, 0xbc9dc9b9, 3 | BRF_GRA },           //  8

	{ "mca-u58.bin",	0x080000, 0x3a8186e2, 4 | BRF_GRA },           //  9 Background Tiles

	{ "mca-u60.bin",	0x100000, 0xc8942614, 5 | BRF_GRA },           // 10 Foreground Tiles
	{ "mca-u61.bin",	0x100000, 0x51af66c9, 5 | BRF_GRA },           // 11
	{ "mca-u100",		0x080000, 0xb273f1b0, 5 | BRF_GRA },           // 12

	{ "mca-u53.bin",	0x080000, 0x64c76e05, 6 | BRF_SND },           // 13 YM2610 Samples
};

STD_ROM_PICK(mcatadv)
STD_ROM_FN(mcatadv)

struct BurnDriver BurnDrvMcatadv = {
	"mcatadv", NULL, NULL, "1993",
	"Magical Cat Adventure\0", NULL, "Wintechno", "LINDA",
	NULL, NULL, NULL, NULL,
	BDF_GAME_WORKING, 2, HARDWARE_MISC_POST90S, GBF_PLATFORM, 0,
	NULL, mcatadvRomInfo, mcatadvRomName, McatadvInputInfo, McatadvDIPInfo,
	DrvInit, DrvExit, DrvFrame, DrvDraw, DrvScan, 0, NULL, NULL, NULL, &DrvRecalc, 0x1001,
	320, 224, 4, 3
};


// Magical Cat Adventure (Japan)

static struct BurnRomInfo mcatadvjRomDesc[] = {
	{ "u30.bin",		0x080000, 0x05762f42, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code
	{ "u29.bin",		0x080000, 0x4c59d648, 1 | BRF_PRG | BRF_ESS }, //  1

	{ "u9.bin",		0x020000, 0xfda05171, 2 | BRF_PRG | BRF_ESS }, //  2 Z80 code

	{ "mca-u82.bin",	0x100000, 0x5f01d746, 3 | BRF_GRA },           //  3 Sprites
	{ "mca-u83.bin",	0x100000, 0x4e1be5a6, 3 | BRF_GRA },           //  4
	{ "mca-u84.bin",	0x080000, 0xdf202790, 3 | BRF_GRA },           //  5
	{ "mca-u85.bin",	0x080000, 0xa85771d2, 3 | BRF_GRA },           //  6
	{ "u86.bin",		0x080000, 0x2d3725ed, 3 | BRF_GRA },           //  7
	{ "u87.bin",		0x080000, 0x4ddefe08, 3 | BRF_GRA },           //  8

	{ "mca-u58.bin",	0x080000, 0x3a8186e2, 4 | BRF_GRA },           //  9 Background Tiles

	{ "mca-u60.bin",	0x100000, 0xc8942614, 5 | BRF_GRA },           // 10 Foreground Tiles
	{ "mca-u61.bin",	0x100000, 0x51af66c9, 5 | BRF_GRA },           // 11
	{ "u100.bin",		0x080000, 0xe2c311da, 5 | BRF_GRA },           // 12

	{ "mca-u53.bin",	0x080000, 0x64c76e05, 6 | BRF_SND },           // 13 YM2610 Samples
};

STD_ROM_PICK(mcatadvj)
STD_ROM_FN(mcatadvj)

struct BurnDriver BurnDrvMcatadvj = {
	"mcatadvj", "mcatadv", NULL, "1993",
	"Magical Cat Adventure (Japan)\0", NULL, "Wintechno", "LINDA",
	NULL, NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_CLONE, 2, HARDWARE_MISC_POST90S, GBF_PLATFORM, 0,
	NULL, mcatadvjRomInfo, mcatadvjRomName, McatadvInputInfo, McatadvDIPInfo,
	DrvInit, DrvExit, DrvFrame, DrvDraw, DrvScan, 0, NULL, NULL, NULL, &DrvRecalc, 0x1001,
	320, 224, 4, 3
};


// Catt (Japan)

static struct BurnRomInfo cattRomDesc[] = {
	{ "catt-u30.bin",	0x080000, 0x8c921e1e, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code
	{ "catt-u29.bin",	0x080000, 0xe725af6d, 1 | BRF_PRG | BRF_ESS }, //  1

	{ "u9.bin",		0x020000, 0xfda05171, 2 | BRF_PRG | BRF_ESS }, //  2 Z80 code

	{ "mca-u82.bin",	0x100000, 0x5f01d746, 3 | BRF_GRA },           //  3 Sprites
	{ "mca-u83.bin",	0x100000, 0x4e1be5a6, 3 | BRF_GRA },           //  4
	{ "u84.bin",		0x100000, 0x843fd624, 3 | BRF_GRA },           //  5
	{ "u85.bin",		0x100000, 0x5ee7b628, 3 | BRF_GRA },           //  6
	{ "mca-u86e",		0x080000, 0x017bf1da, 3 | BRF_GRA },           //  7
	{ "mca-u87e",		0x080000, 0xbc9dc9b9, 3 | BRF_GRA },           //  8

	{ "u58.bin",		0x100000, 0x73c9343a, 4 | BRF_GRA },           //  9 Background Tiles

	{ "mca-u60.bin",	0x100000, 0xc8942614, 5 | BRF_GRA },           // 10 Foreground Tiles
	{ "mca-u61.bin",	0x100000, 0x51af66c9, 5 | BRF_GRA },           // 11
	{ "mca-u100",		0x080000, 0xb273f1b0, 5 | BRF_GRA },           // 12

	{ "u53.bin",		0x100000, 0x99f2a624, 6 | BRF_SND },           // 13 YM2610 Samples

	{ "peel18cv8.u1",	0x000155, 0x00000000, 7 | BRF_NODUMP | BRF_OPT }, // 14 plds
	{ "gal16v8a.u10",	0x000117, 0x00000000, 7 | BRF_NODUMP | BRF_OPT }, // 15
};

STD_ROM_PICK(catt)
STD_ROM_FN(catt)

struct BurnDriver BurnDrvCatt = {
	"catt", "mcatadv", NULL, "1993",
	"Catt (Japan)\0", NULL, "Wintechno", "LINDA",
	NULL, NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_CLONE, 2, HARDWARE_MISC_POST90S, GBF_PLATFORM, 0,
	NULL, cattRomInfo, cattRomName, McatadvInputInfo, McatadvDIPInfo,
	DrvInit, DrvExit, DrvFrame, DrvDraw, DrvScan, 0, NULL, NULL, NULL, &DrvRecalc, 0x1001,
	320, 224, 4, 3
};


// Nostradamus

static struct BurnRomInfo nostRomDesc[] = {
	{ "nos-pe-u.bin",	0x080000, 0x4b080149, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code
	{ "nos-po-u.bin",	0x080000, 0x9e3cd6d9, 1 | BRF_PRG | BRF_ESS }, //  1

	{ "nos-ps.u9",		0x040000, 0x832551e9, 3 | BRF_PRG | BRF_ESS }, //  2 Z80 code

	{ "nos-se-0.u82",	0x100000, 0x9d99108d, 3 | BRF_GRA },           //  3 Sprites
	{ "nos-so-0.u83",	0x100000, 0x7df0fc7e, 3 | BRF_GRA },           //  4
	{ "nos-se-1.u84",	0x100000, 0xaad07607, 3 | BRF_GRA },           //  5
	{ "nos-so-1.u85",	0x100000, 0x83d0012c, 3 | BRF_GRA },           //  6
	{ "nos-se-2.u86",	0x080000, 0xd99e6005, 3 | BRF_GRA },           //  7
	{ "nos-so-2.u87",	0x080000, 0xf60e8ef3, 3 | BRF_GRA },           //  8

	{ "nos-b0-0.u58",	0x100000, 0x0214b0f2, 4 | BRF_GRA },           //  9 Background Tiles
	{ "nos-b0-1.u59",	0x080000, 0x3f8b6b34, 4 | BRF_GRA },           // 10

	{ "nos-b1-0.u60",	0x100000, 0xba6fd0c7, 5 | BRF_GRA },           // 11 Foreground Tiles
	{ "nos-b1-1.u61",	0x080000, 0xdabd8009, 5 | BRF_GRA },           // 12

	{ "nossn-00.u53",	0x100000, 0x3bd1bcbc, 6 | BRF_SND },           // 13 YM2610 Samples
};

STD_ROM_PICK(nost)
STD_ROM_FN(nost)

static void NostPatch()
{
	// Can also be fixed overclocking the z80 to 4250000 and enabling
	// z80 sync, but is slow and breaks sound in Mcatadv.
	*((unsigned short*)(Drv68KROM + 0x000122)) = 0x0146; // Skip ROM Check
}

static int NostInit()
{
	int nRet = DrvInit();

	if (nRet == 0) {
		NostPatch();
	}

	return nRet;
}

struct BurnDriver BurnDrvNost = {
	"nost", NULL, NULL, "1993",
	"Nostradamus\0", NULL, "Face", "LINDA",
	NULL, NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_ORIENTATION_VERTICAL, 2, HARDWARE_MISC_POST90S, GBF_VERSHOOT, 0,
	NULL, nostRomInfo, nostRomName, NostInputInfo, NostDIPInfo,
	NostInit, DrvExit, DrvFrame, DrvDraw, DrvScan, 0, NULL, NULL, NULL, &DrvRecalc, 0x1001,
	224, 320, 3, 4
};


// Nostradamus (Japan)

static struct BurnRomInfo nostjRomDesc[] = {
	{ "nos-pe-j.u30",	0x080000, 0x4b080149, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code
	{ "nos-po-j.u29",	0x080000, 0x7fe241de, 1 | BRF_PRG | BRF_ESS }, //  1

	{ "nos-ps.u9",		0x040000, 0x832551e9, 2 | BRF_PRG | BRF_ESS }, //  2 Z80 code

	{ "nos-se-0.u82",	0x100000, 0x9d99108d, 3 | BRF_GRA },           //  3 Sprites
	{ "nos-so-0.u83",	0x100000, 0x7df0fc7e, 3 | BRF_GRA },           //  4
	{ "nos-se-1.u84",	0x100000, 0xaad07607, 3 | BRF_GRA },           //  5
	{ "nos-so-1.u85",	0x100000, 0x83d0012c, 3 | BRF_GRA },           //  6
	{ "nos-se-2.u86",	0x080000, 0xd99e6005, 3 | BRF_GRA },           //  7
	{ "nos-so-2.u87",	0x080000, 0xf60e8ef3, 3 | BRF_GRA },           //  8

	{ "nos-b0-0.u58",	0x100000, 0x0214b0f2, 4 | BRF_GRA },           //  9 Background Tiles
	{ "nos-b0-1.u59",	0x080000, 0x3f8b6b34, 4 | BRF_GRA },           // 10

	{ "nos-b1-0.u60",	0x100000, 0xba6fd0c7, 5 | BRF_GRA },           // 11 Foreground Tiles
	{ "nos-b1-1.u61",	0x080000, 0xdabd8009, 5 | BRF_GRA },           // 12

	{ "nossn-00.u53",	0x100000, 0x3bd1bcbc, 6 | BRF_SND },           // 13 YM2610 Samples
};

STD_ROM_PICK(nostj)
STD_ROM_FN(nostj)

struct BurnDriver BurnDrvNostj = {
	"nostj", "nost", NULL, "1993",
	"Nostradamus (Japan)\0", NULL, "Face", "LINDA",
	NULL, NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_CLONE | BDF_ORIENTATION_VERTICAL, 2, HARDWARE_MISC_POST90S, GBF_VERSHOOT, 0,
	NULL, nostjRomInfo, nostjRomName, NostInputInfo, NostDIPInfo,
	NostInit, DrvExit, DrvFrame, DrvDraw, DrvScan, 0, NULL, NULL, NULL, &DrvRecalc, 0x1001,
	224, 320, 3, 4
};


// Nostradamus (Korea)

static struct BurnRomInfo nostkRomDesc[] = {
	{ "nos-pe-t.u30",	0x080000, 0xbee5fbc8, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code
	{ "nos-po-t.u29",	0x080000, 0xf4736331, 1 | BRF_PRG | BRF_ESS }, //  1

	{ "nos-ps.u9",		0x040000, 0x832551e9, 2 | BRF_PRG | BRF_ESS }, //  2 Z80 code

	{ "nos-se-0.u82",	0x100000, 0x9d99108d, 3 | BRF_GRA },           //  3 Sprites
	{ "nos-so-0.u83",	0x100000, 0x7df0fc7e, 3 | BRF_GRA },           //  4
	{ "nos-se-1.u84",	0x100000, 0xaad07607, 3 | BRF_GRA },           //  5
	{ "nos-so-1.u85",	0x100000, 0x83d0012c, 3 | BRF_GRA },           //  6
	{ "nos-se-2.u86",	0x080000, 0xd99e6005, 3 | BRF_GRA },           //  7
	{ "nos-so-2.u87",	0x080000, 0xf60e8ef3, 3 | BRF_GRA },           //  8

	{ "nos-b0-0.u58",	0x100000, 0x0214b0f2, 4 | BRF_GRA },           //  9 Background Tiles
	{ "nos-b0-1.u59",	0x080000, 0x3f8b6b34, 4 | BRF_GRA },           // 10

	{ "nos-b1-0.u60",	0x100000, 0xba6fd0c7, 5 | BRF_GRA },           // 11 Foreground Tiles
	{ "nos-b1-1.u61",	0x080000, 0xdabd8009, 5 | BRF_GRA },           // 12

	{ "nossn-00.u53",	0x100000, 0x3bd1bcbc, 6 | BRF_SND },           // 13 YM2610 Samples
};

STD_ROM_PICK(nostk)
STD_ROM_FN(nostk)

struct BurnDriver BurnDrvNostk = {
	"nostk", "nost", NULL, "1993",
	"Nostradamus (Korea)\0", NULL, "Face", "LINDA",
	NULL, NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_CLONE | BDF_ORIENTATION_VERTICAL, 2, HARDWARE_MISC_POST90S, GBF_VERSHOOT, 0,
	NULL, nostkRomInfo, nostkRomName, NostInputInfo, NostDIPInfo,
	NostInit, DrvExit, DrvFrame, DrvDraw, DrvScan, 0, NULL, NULL, NULL, &DrvRecalc, 0x1001,
	224, 320, 3, 4
};
