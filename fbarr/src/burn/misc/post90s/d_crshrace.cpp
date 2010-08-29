// FB Alpha Lethal Crash Race driver module
// Based on MAME driver by Nicola Salmoria

#include "tiles_generic.h"
#include "burn_ym2610.h"

static unsigned char DrvJoy1[16];
static unsigned char DrvJoy2[16];
static unsigned char DrvJoy3[16];
static unsigned char DrvDips[4];
static unsigned short DrvInputs[6];
static unsigned char DrvReset;

static unsigned char *AllMem;
static unsigned char *MemEnd;
static unsigned char *AllRam;
static unsigned char *RamEnd;
static unsigned char *Drv68KROM;
static unsigned char *DrvZ80ROM;
static unsigned char *DrvGfxROM0;
static unsigned char *DrvGfxROM1;
static unsigned char *DrvGfxROM2;
static unsigned char *DrvSndROM;
static unsigned char *Drv68KRAM;
static unsigned char *DrvPalRAM;
static unsigned char *DrvVidRAM1;
static unsigned char *DrvVidRAM2;
static unsigned char *DrvSprRAM1;
static unsigned char *DrvSprRAM2;
static unsigned char *DrvSprBuf1a;
static unsigned char *DrvSprBuf2a;
static unsigned char *DrvSprBuf1b;
static unsigned char *DrvSprBuf2b;
static unsigned char *DrvZ80RAM;
static unsigned short *DrvGfxCtrl;
static unsigned short *DrvBgTmp;
static unsigned int *DrvPalette;

static unsigned char DrvRecalc;

static unsigned char *nSoundBank;
static unsigned char *pending_command;
static unsigned char *roz_bank;
static unsigned char *gfx_priority;
static unsigned char *soundlatch;
static unsigned char *flipscreen;

static struct BurnInputInfo CrshraceInputList[] = {
	{"P1 Coin",		BIT_DIGITAL,	DrvJoy1 + 8,	"p1 coin"	},
	{"P1 Start",		BIT_DIGITAL,	DrvJoy1 + 11,	"p1 start"	},
	{"P1 Up",		BIT_DIGITAL,	DrvJoy1 + 0,	"p1 up"		},
	{"P1 Down",		BIT_DIGITAL,	DrvJoy1 + 1,	"p1 down"	},
	{"P1 Left",		BIT_DIGITAL,	DrvJoy1 + 2,	"p1 left"	},
	{"P1 Right",		BIT_DIGITAL,	DrvJoy1 + 3,	"p1 right"	},
	{"P1 Button 1",		BIT_DIGITAL,	DrvJoy1 + 4,	"p1 fire 1"	},
	{"P1 Button 2",		BIT_DIGITAL,	DrvJoy1 + 5,	"p1 fire 2"	},
	{"P1 Button 3",		BIT_DIGITAL,	DrvJoy1 + 6,	"p1 fire 3"	},

	{"P2 Coin",		BIT_DIGITAL,	DrvJoy1 + 9,	"p2 coin"	},
	{"P2 Start",		BIT_DIGITAL,	DrvJoy1 + 12,	"p2 start"	},
	{"P2 Up",		BIT_DIGITAL,	DrvJoy2 + 0,	"p2 up"		},
	{"P2 Down",		BIT_DIGITAL,	DrvJoy2 + 1,	"p2 down"	},
	{"P2 Left",		BIT_DIGITAL,	DrvJoy2 + 2,	"p2 left"	},
	{"P2 Right",		BIT_DIGITAL,	DrvJoy2 + 3,	"p2 right"	},
	{"P2 Button 1",		BIT_DIGITAL,	DrvJoy2 + 4,	"p2 fire 1"	},
	{"P2 Button 2",		BIT_DIGITAL,	DrvJoy2 + 5,	"p2 fire 2"	},
	{"P2 Button 3",		BIT_DIGITAL,	DrvJoy2 + 6,	"p2 fire 3"	},

	{"P3 Coin",		BIT_DIGITAL,	DrvJoy1 + 10,	"p3 coin"	},
	{"P3 Start",		BIT_DIGITAL,	DrvJoy3 + 7,	"p3 start"	},
	{"P3 Up",		BIT_DIGITAL,	DrvJoy3 + 0,	"p3 up"		},
	{"P3 Down",		BIT_DIGITAL,	DrvJoy3 + 1,	"p3 down"	},
	{"P3 Left",		BIT_DIGITAL,	DrvJoy3 + 2,	"p3 left"	},
	{"P3 Right",		BIT_DIGITAL,	DrvJoy3 + 3,	"p3 right"	},
	{"P3 Button 1",		BIT_DIGITAL,	DrvJoy3 + 4,	"p3 fire 1"	},
	{"P3 Button 2",		BIT_DIGITAL,	DrvJoy3 + 5,	"p3 fire 2"	},
	{"P3 Button 3",		BIT_DIGITAL,	DrvJoy3 + 6,	"p3 fire 3"	},

	{"Reset",		BIT_DIGITAL,	&DrvReset,	"reset"		},
	{"Service",		BIT_DIGITAL,	DrvJoy1 + 15,	"service"	},
	{"Tilt",		BIT_DIGITAL,	DrvJoy1 + 14,	"tilt"		},
	{"Dip A",		BIT_DIPSWITCH,	DrvDips + 0,	"dip"		},
	{"Dip B",		BIT_DIPSWITCH,	DrvDips + 1,	"dip"		},
	{"Dip C",		BIT_DIPSWITCH,	DrvDips + 2,	"dip"		},
	{"Dip D",		BIT_DIPSWITCH,	DrvDips + 3,	"dip"		},
};

STDINPUTINFO(Crshrace)

static struct BurnDIPInfo CrshraceDIPList[]=
{
	{0x1e, 0xff, 0xff, 0xff, NULL				},
	{0x1f, 0xff, 0xff, 0xff, NULL				},
	{0x20, 0xff, 0xff, 0xff, NULL				},
	{0x21, 0xff, 0xff, 0x01, NULL				},

//	{0   , 0xfe, 0   ,    2, "Flip Screen"			},
//	{0x1e, 0x01, 0x01, 0x01, "Off"				},
//	{0x1e, 0x01, 0x01, 0x00, "On"				},

	{0   , 0xfe, 0   ,    2, "Demo Sounds"			},
	{0x1e, 0x01, 0x02, 0x00, "Off"				},
	{0x1e, 0x01, 0x02, 0x02, "On"				},

	{0   , 0xfe, 0   ,    2, "Free Play"			},
	{0x1e, 0x01, 0x04, 0x04, "Off"				},
	{0x1e, 0x01, 0x04, 0x00, "On"				},

	{0   , 0xfe, 0   ,    2, "Service Mode"			},
	{0x1e, 0x01, 0x08, 0x08, "Off"				},
	{0x1e, 0x01, 0x08, 0x00, "On"				},

	{0   , 0xfe, 0   ,    4, "Difficulty"			},
	{0x1e, 0x01, 0xc0, 0x80, "Easy"				},
	{0x1e, 0x01, 0xc0, 0xc0, "Normal"			},
	{0x1e, 0x01, 0xc0, 0x40, "Hard"				},
	{0x1e, 0x01, 0xc0, 0x00, "Hardest"			},

	{0   , 0xfe, 0   ,    2, "Coin Slot"			},
	{0x1f, 0x01, 0x01, 0x01, "Same"				},
	{0x1f, 0x01, 0x01, 0x00, "Individual"			},

	{0   , 0xfe, 0   ,    8, "Coin A"			},
	{0x1f, 0x01, 0x0e, 0x0a, "3 Coins 1 Credits"		},
	{0x1f, 0x01, 0x0e, 0x0c, "2 Coins 1 Credits"		},
	{0x1f, 0x01, 0x0e, 0x0e, "1 Coin  1 Credits"		},
	{0x1f, 0x01, 0x0e, 0x08, "1 Coin  2 Credits"		},
	{0x1f, 0x01, 0x0e, 0x06, "1 Coin  3 Credits"		},
	{0x1f, 0x01, 0x0e, 0x04, "1 Coin  4 Credits"		},
	{0x1f, 0x01, 0x0e, 0x02, "1 Coin  5 Credits"		},
	{0x1f, 0x01, 0x0e, 0x00, "1 Coin  6 Credits"		},

	{0   , 0xfe, 0   ,    8, "Coin B"			},
	{0x1f, 0x01, 0x70, 0x50, "3 Coins 1 Credits"		},
	{0x1f, 0x01, 0x70, 0x60, "2 Coins 1 Credits"		},
	{0x1f, 0x01, 0x70, 0x70, "1 Coin  1 Credits"		},
	{0x1f, 0x01, 0x70, 0x40, "1 Coin  2 Credits"		},
	{0x1f, 0x01, 0x70, 0x30, "1 Coin  3 Credits"		},
	{0x1f, 0x01, 0x70, 0x20, "1 Coin  4 Credits"		},
	{0x1f, 0x01, 0x70, 0x10, "1 Coin  5 Credits"		},
	{0x1f, 0x01, 0x70, 0x00, "1 Coin  6 Credits"		},

	{0   , 0xfe, 0   ,    2, "2 to Start, 1 to Cont."	},
	{0x1f, 0x01, 0x80, 0x80, "Off"				},
	{0x1f, 0x01, 0x80, 0x00, "On"				},

	{0   , 0xfe, 0   ,    2, "Reset on P.O.S.T. Error"	},
	{0x20, 0x01, 0x80, 0x00, "No"				},
	{0x20, 0x01, 0x80, 0x80, "Yes"				},

	{0   , 0xfe, 0   ,    5, "Country"			},
	{0x21, 0x01, 0x0f, 0x01, "World"			},
	{0x21, 0x01, 0x0f, 0x08, "USA & Canada"			},
	{0x21, 0x01, 0x0f, 0x00, "Japan"			},
	{0x21, 0x01, 0x0f, 0x02, "Korea"			},
	{0x21, 0x01, 0x0f, 0x04, "Hong Kong & Taiwan"		},
};

STDDIPINFO(Crshrace)

static void crshrace_drawtile(int offset)
{
	int sx = (offset & 0x3f) << 4;
	int sy = (offset >> 6) << 4;

	int code  = *((unsigned short*)(DrvVidRAM1 + (offset << 1)));
	int color = code >> 12;
	    code  = (code & 0xfff) | (*roz_bank << 12);
	    color = (color << 4) | 0x100;

	unsigned char *src = DrvGfxROM1 + (code << 8);
	unsigned short *dst = DrvBgTmp + (sy << 10) + sx;

	for (int y = 0; y < 16; y++) {
		for (int x = 0; x < 16; x++) {
			int pxl = *src++;
			if (pxl == 0x0f) pxl = ~0;

			dst[x] = pxl | color;
		}
		dst += 1024;
	}
}

void __fastcall crshrace_write_word(unsigned int address, unsigned short data)
{
	if (address >= 0xfff020 && address <= 0xfff03f) { // K053936_0_ctrl
		DrvGfxCtrl[(address & 0x1f)/2] = data;
		return;
	}

	if ((address & 0xfffe000) == 0xd00000) {
		*((unsigned short*)(DrvVidRAM1 + (address & 0x1ffe))) = data;
		crshrace_drawtile((address & 0x1ffe)/2);
		return;
	}
}

void __fastcall crshrace_write_byte(unsigned int address, unsigned char data)
{
	if ((address & 0xfffe000) == 0xd00000) {
		DrvVidRAM1[(address & 0x1fff) ^ 1] = data;
		crshrace_drawtile((address & 0x1ffe)/2);
		return;
	}

	switch (address)
	{
		case 0xffc001:
			*roz_bank = data;
		return;

		case 0xfff001:
			*gfx_priority = data & 0xdf;
			*flipscreen = data & 0x20;
		return;

		case 0xfff009:
			*pending_command = 1;
			*soundlatch = data;
			ZetNmi();
		return;
	}
}

unsigned short __fastcall crshrace_read_word(unsigned int)
{
	return 0;
}

unsigned char __fastcall crshrace_read_byte(unsigned int address)
{
	switch (address)
	{
		case 0xfff000:
			return DrvInputs[0] >> 8;

		case 0xfff001:
			return DrvInputs[0];

		case 0xfff002:
			return DrvInputs[1] >> 8;

		case 0xfff003:
			return DrvInputs[1];

		case 0xfff004:
			return DrvDips[1];

		case 0xfff005:
			return DrvDips[0];

		case 0xfff00b:
			return DrvDips[2];

		case 0xfff00f:
			return DrvInputs[2];

		case 0xfff006:
			return DrvDips[3] | (*pending_command << 7);
	}

	return 0;
}

static void sound_bankswitch(int bank)
{
	*nSoundBank = bank & 0x03;
	int nBank = (*nSoundBank & 0x03) << 15;

	ZetMapArea(0x8000, 0xffff, 0, DrvZ80ROM + nBank);
	ZetMapArea(0x8000, 0xffff, 2, DrvZ80ROM + nBank);
}

void __fastcall crshrace_sound_out(unsigned short port, unsigned char data)
{
	switch (port & 0xff)
	{
		case 0x00:
			sound_bankswitch(data);
		return;

		case 0x04:
			*pending_command = 0;
		return;

		case 0x08:
		case 0x09:
		case 0x0a:
		case 0x0b:
			BurnYM2610Write(port & 3, data);
		return;
	}
}

unsigned char __fastcall crshrace_sound_in(unsigned short port)
{
	switch (port & 0xff)
	{
		case 0x04:
			return *soundlatch;

		case 0x08:
		case 0x09:
		case 0x0a:
		case 0x0b:
			return BurnYM2610Read(port & 3);
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

static int MemIndex()
{
	unsigned char *Next; Next = AllMem;

	Drv68KROM	= Next; Next += 0x300000;
	DrvZ80ROM	= Next; Next += 0x020000;

	DrvGfxROM0	= Next; Next += 0x100000;
	DrvGfxROM1	= Next; Next += 0x800000;
	DrvGfxROM2	= Next; Next += 0x800000;

	DrvSndROM	= Next; Next += 0x200000;

	DrvPalette	= (unsigned int  *)Next; Next += 0x000401 * sizeof(int);
	DrvBgTmp	= (unsigned short*)Next; Next += 0x100000 * sizeof(short);

	AllRam		= Next;

	Drv68KRAM	= Next; Next += 0x010000;
	DrvPalRAM	= Next; Next += 0x001000;
	DrvVidRAM1	= Next; Next += 0x002000;
	DrvVidRAM2	= Next; Next += 0x001000;

	DrvSprRAM1	= Next; Next += 0x002000;
	DrvSprRAM2	= Next; Next += 0x010000;

	DrvSprBuf1a	= Next; Next += 0x002000;
	DrvSprBuf2a	= Next; Next += 0x010000;
	DrvSprBuf1b	= Next; Next += 0x002000;
	DrvSprBuf2b	= Next; Next += 0x010000;

	DrvZ80RAM	= Next; Next += 0x000800;

	nSoundBank	= Next; Next += 0x000001;
	roz_bank	= Next; Next += 0x000001;
	soundlatch	= Next; Next += 0x000001;
	flipscreen	= Next; Next += 0x000001;
	gfx_priority	= Next; Next += 0x000001;
	pending_command	= Next; Next += 0x000001;

	DrvGfxCtrl	= (unsigned short*)Next; Next += 0x000010 * sizeof(short);

	RamEnd		= Next;

	MemEnd		= Next;

	return 0;
}

static int DrvDoReset()
{
	DrvReset = 0;

	memset (AllRam, 0, RamEnd - AllRam);
	memset (DrvBgTmp, 0xff, 0x200000);

	SekOpen(0);
	SekReset();
	SekClose();

	ZetOpen(0);
	ZetReset();
	ZetClose();

	BurnYM2610Reset();

	return 0;
}

static int DrvGfxDecode()
{
	int Plane[8]  = { 0x000, 0x001, 0x002, 0x003 };
	int XOffs[16] = { 0x004, 0x000, 0x00c, 0x008, 0x014, 0x010, 0x01c, 0x018,
			  0x024, 0x020, 0x02c, 0x028, 0x034, 0x030, 0x03c, 0x038 };
	int YOffs[16] = { 0x000, 0x040, 0x080, 0x0c0, 0x100, 0x140, 0x180, 0x1c0,
			  0x200, 0x240, 0x280, 0x2c0, 0x300, 0x340, 0x380, 0x3c0 };

	unsigned char *tmp = (unsigned char*)malloc(0x400000);
	if (tmp == NULL) {
		return 1;
	}

	for (int i = 0; i < 0x300000; i++) {
		tmp[i^1] = (DrvGfxROM1[i] << 4) | (DrvGfxROM1[i] >> 4);
	}

	GfxDecode(0x6000, 4, 16, 16, Plane, XOffs, YOffs, 0x400, tmp, DrvGfxROM1);

	memcpy (tmp, DrvGfxROM2, 0x400000);

	GfxDecode(0x8000, 4, 16, 16, Plane, XOffs, YOffs, 0x400, tmp, DrvGfxROM2);

	free (tmp);

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
		if (BurnLoadRom(Drv68KROM + 0x0000000,	 0, 1)) return 1;
		if (BurnLoadRom(Drv68KROM + 0x0100000,	 1, 1)) return 1;
		if (BurnLoadRom(Drv68KROM + 0x0200000,	 2, 1)) return 1;

		if (BurnLoadRom(DrvZ80ROM,		 3, 1)) return 1;

		if (BurnLoadRom(DrvGfxROM0 + 0x000000,	 4, 1)) return 1;

		if (BurnLoadRom(DrvGfxROM1 + 0x000000,	 5, 1)) return 1;
		if (BurnLoadRom(DrvGfxROM1 + 0x100000,	 6, 1)) return 1;
		if (BurnLoadRom(DrvGfxROM1 + 0x200000,	 7, 1)) return 1;

		if (BurnLoadRom(DrvGfxROM2 + 0x000000,	 8, 1)) return 1;
		if (BurnLoadRom(DrvGfxROM2 + 0x200000,	 9, 1)) return 1;

		if (BurnLoadRom(DrvSndROM + 0x0000000,	10, 1)) return 1;
		if (BurnLoadRom(DrvSndROM + 0x0100000,  11, 1)) return 1;

		DrvGfxDecode();
	}

	SekInit(0, 0x68000);
	SekOpen(0);
	SekMapMemory(Drv68KROM,			0x000000, 0x07ffff, SM_ROM);
	SekMapMemory(Drv68KROM + 0x100000,	0x300000, 0x3fffff, SM_ROM);
	SekMapMemory(Drv68KROM + 0x200000,	0x400000, 0x4fffff, SM_ROM);
	SekMapMemory(Drv68KROM + 0x200000,	0x500000, 0x5fffff, SM_ROM);
	SekMapMemory(DrvSprRAM2,		0xa00000, 0xa0ffff, SM_RAM);
	SekMapMemory(DrvVidRAM1,		0xd00000, 0xd01fff, SM_ROM);
	SekMapMemory(DrvSprRAM1,		0xe00000, 0xe01fff, SM_RAM);
	SekMapMemory(Drv68KRAM,			0xfe0000, 0xfeffff, SM_RAM);
	SekMapMemory(DrvVidRAM2,		0xffd000, 0xffdfff, SM_RAM);
	SekMapMemory(DrvPalRAM,			0xffe000, 0xffefff, SM_RAM);
	SekSetWriteWordHandler(0,		crshrace_write_word);
	SekSetWriteByteHandler(0,		crshrace_write_byte);
	SekSetReadWordHandler(0,		crshrace_read_word);
	SekSetReadByteHandler(0,		crshrace_read_byte);
	SekClose();

	ZetInit(1);
	ZetOpen(0);
	ZetMapArea(0x0000, 0x77ff, 0, DrvZ80ROM);
	ZetMapArea(0x0000, 0x77ff, 2, DrvZ80ROM);
	ZetMapArea(0x7800, 0x7fff, 0, DrvZ80RAM);
	ZetMapArea(0x7800, 0x7fff, 1, DrvZ80RAM);
	ZetMapArea(0x7800, 0x7fff, 2, DrvZ80RAM);
	ZetMapArea(0x8000, 0xffff, 0, DrvZ80ROM + 0x10000);
	ZetMapArea(0x8000, 0xffff, 1, DrvZ80ROM + 0x10000);
	ZetMapArea(0x8000, 0xffff, 2, DrvZ80ROM + 0x10000);
	ZetSetOutHandler(crshrace_sound_out);
	ZetSetInHandler(crshrace_sound_in);
	ZetMemEnd();
	ZetClose();

	int DrvSndROMLen = 0x100000;
	BurnYM2610Init(8000000, DrvSndROM + 0x100000, &DrvSndROMLen, DrvSndROM, &DrvSndROMLen, &DrvFMIRQHandler, DrvSynchroniseStream, DrvGetTime, 0);
	BurnTimerAttachZet(4000000);

	GenericTilesInit();

	DrvDoReset();

	return 0;
}

static int DrvExit()
{
	GenericTilesExit();

	BurnYM2610Exit();
	SekExit();
	ZetExit();

	free (AllMem);
	AllMem = NULL;

	return 0;
}

static void draw_sprites()
{
	int offs = 0;
	unsigned short *sprbuf1 = (unsigned short*)DrvSprBuf1a;
	unsigned short *sprbuf2 = (unsigned short*)DrvSprBuf2a;

	static const int zoomtable[16] = { 0,7,14,20,25,30,34,38,42,46,49,52,54,57,59,61 };

	while (offs < 0x0400 && (sprbuf1[offs] & 0x4000) == 0)
	{
		int attr_start = 4 * (sprbuf1[offs++] & 0x03ff);

		int ox        =  sprbuf1[attr_start + 1] & 0x01ff;
		int xsize     = (sprbuf1[attr_start + 1] & 0x0e00) >> 9;
		int zoomx     = (sprbuf1[attr_start + 1] & 0xf000) >> 12;
		int oy        =  sprbuf1[attr_start + 0] & 0x01ff;
		int ysize     = (sprbuf1[attr_start + 0] & 0x0e00) >> 9;
		int zoomy     = (sprbuf1[attr_start + 0] & 0xf000) >> 12;
		int flipx     =  sprbuf1[attr_start + 2] & 0x4000;
		int flipy     =  sprbuf1[attr_start + 2] & 0x8000;
		int color     = (sprbuf1[attr_start + 2] & 0x1f00) >> 8;
		int map_start =  sprbuf1[attr_start + 3] & 0x7fff;

		zoomx = 16 - zoomtable[zoomx]/8;
		zoomy = 16 - zoomtable[zoomy]/8;

		if (sprbuf1[attr_start + 2] & 0x20ff) color = 1; // what?? mame_rand? why?

		for (int y = 0;y <= ysize;y++)
		{
			int sx,sy;

			if (flipy) sy = ((oy + zoomy * (ysize - y) + 16) & 0x1ff) - 16;
			else sy = ((oy + zoomy * y + 16) & 0x1ff) - 16;

			for (int x = 0;x <= xsize;x++)
			{
				if (flipx)
					sx = ((ox + zoomx * (xsize - x) + 16) & 0x1ff) - 16;
				else
					sx = ((ox + zoomx * x + 16) & 0x1ff) - 16;

				int code = sprbuf2[map_start & 0x7fff] & 0x7fff;
				map_start++;

				RenderZoomedTile(pTransDraw, DrvGfxROM2, code, (color << 4) | 0x200, 0x0f, sx, sy, flipx, flipy, 16, 16, zoomx << 12, zoomy << 12);
			}
		}
	}
}

static void draw_background()
{
	unsigned short *vram = (unsigned short*)DrvVidRAM2;

	for (int offs = 0; offs < 64*28; offs++)
	{
		int sx = (offs & 0x3f) << 3;
		if (sx >= 320) continue;

		int sy = (offs >> 6) << 3;

		int code = vram[offs] & 0x3fff;
		if (code == 0) continue;

		Render8x8Tile_Mask(pTransDraw, code, sx, sy, 0, 4, 0xff, 0, DrvGfxROM0);
	}
}

static inline void copy_roz(unsigned int startx, unsigned int starty, int incxx, int incxy, int incyx, int incyy)
{
	unsigned short *dst = pTransDraw;
	unsigned short *src = DrvBgTmp;

	for (int sy = 0; sy < nScreenHeight; sy++, startx+=incyx, starty+=incyy)
	{
		unsigned int cx = startx;
		unsigned int cy = starty;

		for (int x = 0; x < nScreenWidth; x++, cx+=incxx, cy+=incxy, dst++)
		{
			int p = src[(((cy >> 16) & 0x3ff) * 1024) + ((cx >> 16) & 0x3ff)];

			if (p != 0xffff) {
				*dst = p;
			}
		}
	}
}

static void draw_foreground()
{
	unsigned short *ctrl = DrvGfxCtrl;

	unsigned int startx,starty;
	int incxx,incxy,incyx,incyy;

	startx = 256 * (short)(ctrl[0x00]);
	starty = 256 * (short)(ctrl[0x01]);
	incyx  =       (short)(ctrl[0x02]);
	incyy  =       (short)(ctrl[0x03]);
	incxx  =       (short)(ctrl[0x04]);
	incxy  =       (short)(ctrl[0x05]);

	if (ctrl[0x06] & 0x4000) { incyx *= 256; incyy *= 256; }
	if (ctrl[0x06] & 0x0040) { incxx *= 256; incxy *= 256; }

	startx -= -21 * incyx;
	starty -= -21 * incyy;

	startx -= -48 * incxx;
	starty -= -48 * incxy;

	copy_roz(startx << 5, starty << 5, incxx << 5, incxy << 5, incyx << 5, incyy << 5);
}

static int DrvDraw()
{
	if (DrvRecalc) {
		unsigned char r,g,b;
		unsigned short *p = (unsigned short*)DrvPalRAM;
		for (int i = 0; i < 0x400; i++) {
			r = (p[i] >>  0) & 0x1f;
			g = (p[i] >> 10) & 0x1f;
			b = (p[i] >>  5) & 0x1f;

			r = (r << 3) | (r >> 2);
			g = (g << 3) | (g >> 2);
			b = (b << 3) | (b >> 2);

			DrvPalette[i] = BurnHighCol(r, g, b, 0);
		}
		DrvPalette[0x400] = 0;
	}

	if (*gfx_priority & 0x04)
	{
		for (int i = 0; i < nScreenWidth * nScreenHeight; i++) {
			pTransDraw[i] = 0x400;
		}

		BurnTransferCopy(DrvPalette);

		return 0;
	}

	for (int i = 0; i < nScreenWidth * nScreenHeight; i++) {
		pTransDraw[i] = 0x01ff;
	}

	switch (*gfx_priority & 0xfb)
	{
		case 0x00:
			draw_sprites();
			draw_background();
			draw_foreground();
			break;

		case 0x01:
		case 0x02:
			draw_background();
			draw_foreground();
			draw_sprites();
			break;

		default:
			break;
	}

	BurnTransferCopy(DrvPalette);

	return 0;
}

static int DrvFrame()
{
	if (DrvReset) {
		DrvDoReset();
	}

	SekNewFrame();
	ZetNewFrame();

	{
		memset (DrvInputs, 0xff, 6);
		for (int i = 0; i < 16; i++) {
			DrvInputs[0] ^= (DrvJoy1[i] & 1) << i;
			DrvInputs[1] ^= (DrvJoy2[i] & 1) << i;
			DrvInputs[2] ^= (DrvJoy3[i] & 1) << i;
		}

		DrvInputs[3] = (DrvDips[0]) | (DrvDips[1] << 8);
		DrvInputs[4] = DrvDips[2];
		DrvInputs[5] = (DrvDips[3] << 8);
	}

	int nCyclesTotal[2] = { 16000000 / 60, 4000000 / 60 };

	SekOpen(0);
	ZetOpen(0);

	SekRun(nCyclesTotal[0]);
	SekSetIRQLine(1, SEK_IRQSTATUS_AUTO);

	BurnTimerEndFrame(nCyclesTotal[1]);

	if (pBurnSoundOut) {
		BurnYM2610Update(pBurnSoundOut, nBurnSoundLen);
	}

	ZetClose();
	SekClose();

	if (pBurnDraw) {
		DrvDraw();
	}

	// double buffer sprites
	memcpy (DrvSprBuf1b, DrvSprBuf1a, 0x002000);
	memcpy (DrvSprBuf1a, DrvSprRAM1,  0x002000);
	memcpy (DrvSprBuf2b, DrvSprBuf2a, 0x010000);
	memcpy (DrvSprBuf2a, DrvSprRAM2,  0x010000);

	return 0;
}

static int DrvScan(int nAction, int *pnMin)
{
	struct BurnArea ba;
	
	if (pnMin != NULL) {
		*pnMin =  0x029702;
	}

	if (nAction & ACB_MEMORY_RAM) {
		memset(&ba, 0, sizeof(ba));
		ba.Data	  = AllRam;
		ba.nLen	  = RamEnd - AllRam;
		ba.szName = "All Ram";
		BurnAcb(&ba);
	}

	if (nAction & ACB_DRIVER_DATA) {
		SekScan(nAction);
		ZetScan(nAction);

		BurnYM2610Scan(nAction, pnMin);
	}

	if (nAction & ACB_WRITE) {
		for (int i = 0; i < 0x1000; i++) {
			crshrace_drawtile(i);
		}

		ZetOpen(0);
		sound_bankswitch(*nSoundBank);
		ZetClose();
	}

	return 0;
}


// Lethal Crash Race (set 1)

static struct BurnRomInfo crshraceRomDesc[] = {
	{ "1",			0x080000, 0x21e34fb7, 1 | BRF_PRG | BRF_ESS }, //  0 68k Code
	{ "w21",		0x100000, 0xa5df7325, 1 | BRF_PRG | BRF_ESS }, //  1
	{ "w22",		0x100000, 0xfc9d666d, 1 | BRF_PRG | BRF_ESS }, //  2

	{ "2",			0x020000, 0xe70a900f, 2 | BRF_PRG | BRF_ESS }, //  3 Z80 Code

	{ "h895",		0x100000, 0x36ad93c3, 3 | BRF_GRA },           //  4 Background Tiles

	{ "w18",		0x100000, 0xb15df90d, 4 | BRF_GRA },           //  5 Foreground Tiles
	{ "w19",		0x100000, 0x28326b93, 4 | BRF_GRA },           //  6
	{ "w20",		0x100000, 0xd4056ad1, 4 | BRF_GRA },           //  7

	{ "h897",		0x200000, 0xe3230128, 5 | BRF_GRA },           //  8 Sprites
	{ "h896",		0x200000, 0xfff60233, 5 | BRF_GRA },           //  9

	{ "h894",		0x100000, 0xd53300c1, 6 | BRF_SND },           // 10 YM2610 Samples
	{ "h893",		0x100000, 0x32513b63, 6 | BRF_SND },           // 11
};

STD_ROM_PICK(crshrace)
STD_ROM_FN(crshrace)

struct BurnDriver BurnDrvCrshrace = {
	"crshrace", NULL, NULL, "1993",
	"Lethal Crash Race (set 1)\0", NULL, "Video System Co.", "Miscellaneous",
	NULL, NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_ORIENTATION_VERTICAL, 2, HARDWARE_MISC_POST90S, GBF_RACING, 0,
	NULL, crshraceRomInfo, crshraceRomName, CrshraceInputInfo, CrshraceDIPInfo,
	DrvInit, DrvExit, DrvFrame, DrvDraw, DrvScan, 0, NULL, NULL, NULL, &DrvRecalc, 0x401,
	224, 320, 3, 4
};


// Lethal Crash Race (set 2)

static struct BurnRomInfo crshrac2RomDesc[] = {
	{ "01-ic10.bin",	0x080000, 0xb284aacd, 1 | BRF_PRG | BRF_ESS }, //  0 68k Code
	{ "w21",		0x100000, 0xa5df7325, 1 | BRF_PRG | BRF_ESS }, //  1
	{ "w22",		0x100000, 0xfc9d666d, 1 | BRF_PRG | BRF_ESS }, //  2

	{ "2",			0x020000, 0xe70a900f, 2 | BRF_PRG | BRF_ESS }, //  3 Z80 Code

	{ "h895",		0x100000, 0x36ad93c3, 3 | BRF_GRA },           //  4 Background Tiles

	{ "w18",		0x100000, 0xb15df90d, 4 | BRF_GRA },           //  5 Foreground Tiles
	{ "w19",		0x100000, 0x28326b93, 4 | BRF_GRA },           //  6
	{ "w20",		0x100000, 0xd4056ad1, 4 | BRF_GRA },           //  7

	{ "h897",		0x200000, 0xe3230128, 5 | BRF_GRA },           //  8 Sprites
	{ "h896",		0x200000, 0xfff60233, 5 | BRF_GRA },           //  9

	{ "h894",		0x100000, 0xd53300c1, 6 | BRF_SND },           // 10 YM2610 Samples
	{ "h893",		0x100000, 0x32513b63, 6 | BRF_SND },           // 11
};

STD_ROM_PICK(crshrac2)
STD_ROM_FN(crshrac2)

struct BurnDriver BurnDrvCrshrac2 = {
	"crshrace2", "crshrace", NULL, "1993",
	"Lethal Crash Race (set 2)\0", NULL, "Video System Co.", "Miscellaneous",
	NULL, NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_CLONE | BDF_ORIENTATION_VERTICAL, 2, HARDWARE_MISC_POST90S, GBF_RACING, 0,
	NULL, crshrac2RomInfo, crshrac2RomName,  CrshraceInputInfo,  CrshraceDIPInfo,
	DrvInit, DrvExit, DrvFrame, DrvDraw, DrvScan, 0, NULL, NULL, NULL, &DrvRecalc, 0x401,
	224, 320, 3, 4
};

