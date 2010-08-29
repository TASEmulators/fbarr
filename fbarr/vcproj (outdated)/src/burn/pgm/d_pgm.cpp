// FB Alpha IGS PolyGameMaster driver module
// Based on MAME (0.115) driver by ElSemi
// Original port by OopsWare (2007)

#include "pgm.h"

static struct BurnRomInfo emptyRomDesc[] = {
	{ "",                    0,          0, 0 },
};

static struct BurnInputInfo pgmInputList[] = {
	{"P1 Coin",		BIT_DIGITAL,	PgmBtn1 + 0,	"p1 coin"	},
	{"P1 Start",		BIT_DIGITAL,	PgmJoy1 + 0,	"p1 start"	},
	{"P1 Up",		BIT_DIGITAL,	PgmJoy1 + 1,	"p1 up"		},
	{"P1 Down",		BIT_DIGITAL,	PgmJoy1 + 2,	"p1 down"	},
	{"P1 Left",		BIT_DIGITAL,	PgmJoy1 + 3,	"p1 left"	},
	{"P1 Right",		BIT_DIGITAL,	PgmJoy1 + 4,	"p1 right"	},
	{"P1 Button 1",		BIT_DIGITAL,	PgmJoy1 + 5,	"p1 fire 1"	},
	{"P1 Button 2",		BIT_DIGITAL,	PgmJoy1 + 6,	"p1 fire 2"	},
	{"P1 Button 3",		BIT_DIGITAL,	PgmJoy1 + 7,	"p1 fire 3"	},
	{"P1 Button 4",		BIT_DIGITAL,	PgmBtn2 + 0,	"p1 fire 4"	},

	{"P2 Coin",		BIT_DIGITAL,	PgmBtn1 + 1,	"p2 coin"	},
	{"P2 Start",		BIT_DIGITAL,	PgmJoy2 + 0,	"p2 start"	},
	{"P2 Up",		BIT_DIGITAL,	PgmJoy2 + 1,	"p2 up"		},
	{"P2 Down",		BIT_DIGITAL,	PgmJoy2 + 2,	"p2 down"	},
	{"P2 Left",		BIT_DIGITAL,	PgmJoy2 + 3,	"p2 left"	},
	{"P2 Right",		BIT_DIGITAL,	PgmJoy2 + 4,	"p2 right"	},
	{"P2 Button 1",		BIT_DIGITAL,	PgmJoy2 + 5,	"p2 fire 1"	},
	{"P2 Button 2",		BIT_DIGITAL,	PgmJoy2 + 6,	"p2 fire 2"	},
	{"P2 Button 3",		BIT_DIGITAL,	PgmJoy2 + 7,	"p2 fire 3"	},
	{"P2 Button 4",		BIT_DIGITAL,	PgmBtn2 + 1,	"p2 fire 4"	},

	{"P3 Coin",		BIT_DIGITAL,	PgmBtn1 + 2,	"p3 coin"	},
	{"P3 Start",		BIT_DIGITAL,	PgmJoy3 + 0,	"p3 start"	},
	{"P3 Up",		BIT_DIGITAL,	PgmJoy3 + 1,	"p3 up"		},
	{"P3 Down",		BIT_DIGITAL,	PgmJoy3 + 2,	"p3 down"	},
	{"P3 Left",		BIT_DIGITAL,	PgmJoy3 + 3,	"p3 left"	},
	{"P3 Right",		BIT_DIGITAL,	PgmJoy3 + 4,	"p3 right"	},
	{"P3 Button 1",		BIT_DIGITAL,	PgmJoy3 + 5,	"p3 fire 1"	},
	{"P3 Button 2",		BIT_DIGITAL,	PgmJoy3 + 6,	"p3 fire 2"	},
	{"P3 Button 3",		BIT_DIGITAL,	PgmJoy3 + 7,	"p3 fire 3"	},
	{"P3 Button 4",		BIT_DIGITAL,	PgmBtn2 + 2,	"p3 fire 4"	},

	{"P4 Coin",		BIT_DIGITAL,	PgmBtn1 + 3,	"p4 coin"	},
	{"P4 Start",		BIT_DIGITAL,	PgmJoy4 + 0,	"p4 start"	},
	{"P4 Up",		BIT_DIGITAL,	PgmJoy4 + 1,	"p4 up"		},
	{"P4 Down",		BIT_DIGITAL,	PgmJoy4 + 2,	"p4 down"	},
	{"P4 Left",		BIT_DIGITAL,	PgmJoy4 + 3,	"p4 left"	},
	{"P4 Right",		BIT_DIGITAL,	PgmJoy4 + 4,	"p4 right"	},
	{"P4 Button 1",		BIT_DIGITAL,	PgmJoy4 + 5,	"p4 fire 1"	},
	{"P4 Button 2",		BIT_DIGITAL,	PgmJoy4 + 6,	"p4 fire 2"	},
	{"P4 Button 3",		BIT_DIGITAL,	PgmJoy4 + 7,	"p4 fire 3"	},
	{"P4 Button 4",		BIT_DIGITAL,	PgmBtn2 + 3,	"p4 fire 4"	},

	{"Reset",		BIT_DIGITAL,	&PgmReset,	"reset"		},
	{"Diagnostics 1",	BIT_DIGITAL,	PgmBtn1 + 4,	"diag"		},
	{"Diagnostics 2",	BIT_DIGITAL,	PgmBtn1 + 6,	""		},
	{"Service 1",		BIT_DIGITAL,	PgmBtn1 + 5,	"service"	},
	{"Service 2",		BIT_DIGITAL,	PgmBtn1 + 7,	"service2"	},

	{"Dip A",		BIT_DIPSWITCH,	PgmInput + 6,	"dip"		},
	{"Dip B",		BIT_DIPSWITCH,	PgmInput + 7,	"dip"		},
};

STDINPUTINFO(pgm)

static struct BurnDIPInfo pgmDIPList[] = {
	{0x2D,	0xFF, 0xFF,	0x00, NULL			},

	{0,	0xFE, 0,	2,    "Test mode"		},
	{0x2D,	0x01, 0x01,	0x00, "No"			},
	{0x2D,	0x01, 0x01,	0x01, "Yes"			},

	{0,	0xFE, 0,	2,    "Music"			},
	{0x2D,	0x01, 0x02,	0x02, "No"			},
	{0x2D,	0x01, 0x02,	0x00, "Yes"			},

	{0,	0xFE, 0,	2,    "Voice"			},
	{0x2D,	0x01, 0x04,	0x04, "No"			},
	{0x2D,	0x01, 0x04,	0x00, "Yes"			},

	{0,	0xFE, 0,	2,    "Free play"		},
	{0x2D,	0x01, 0x08,	0x00, "No"			},
	{0x2D,	0x01, 0x08,	0x08, "Yes"			},

	{0,	0xFE, 0,	2,    "Stop mode"		},
	{0x2D,	0x01, 0x10,	0x00, "No"			},
	{0x2D,	0x01, 0x10,	0x10, "Yes"			},
};

STDDIPINFO(pgm)

static struct BurnDIPInfo orlegendDIPList[] = {
	{0x2E,	0xFF, 0xFF,	0x00, NULL			},

	{0,	0xFE, 0,	2,    "Disable Ba-Chieh"	},
	{0x2E,	0x02, 0x01,	0x00, "No"			},
	{0x2E,	0x02, 0x01,	0x01, "Yes"			},

	{0,	0xFE, 0,	3,    "Region"			},
	{0x2E,	0x01, 0x03,	0x00, "World"			},
	{0x2E,	0x01, 0x03,	0x02, "Korea"			},
	{0x2E,	0x01, 0x03,	0x03, "China"			},
};

static struct BurnDIPInfo orlegndcDIPList[] = {
	{0x2E,	0xFF, 0xFF,	0x03, NULL			},

	{0,	0xFE, 0,	2,    "Disable Ba-Chieh"	},
	{0x2E,	0x02, 0x01,	0x00, "No"			},
	{0x2E,	0x02, 0x01,	0x01, "Yes"			},

	{0,	0xFE, 0,	3,    "Region"			},
	{0x2E,	0x01, 0x03,	0x00, "World"			},
	{0x2E,	0x01, 0x03,	0x02, "Korea"			},
	{0x2E,	0x01, 0x03,	0x03, "China"			},
};

static struct BurnDIPInfo orld111cDIPList[] = {
	{0x2E,	0xFF, 0xFF,	0x02, NULL			},

	{0,	0xFE, 0,	2,    "Region"			},
	{0x2E,	0x01, 0x03,	0x00, "Hong Kong"		},
	{0x2E,	0x01, 0x03,	0x02, "China"			},
};

static struct BurnDIPInfo orld105kDIPList[] = {
	{0x2E,	0xFF, 0xFF,	0x02, NULL			},
};

static struct BurnDIPInfo sangoDIPList[] = {
	{0x2E,	0xFF, 0xFF,	0x05, NULL			},

	{0,	0xFE, 0,	6,    "Region"			},
	{0x2E,	0x01, 0x0F,	0x00, "China"			},
	{0x2E,	0x01, 0x0F,	0x01, "Taiwan"			},
	{0x2E,	0x01, 0x0F,	0x02, "Japan"			},
	{0x2E,	0x01, 0x0F,	0x03, "Korea"			},
	{0x2E,	0x01, 0x0F,	0x04, "Hong Kong"		},
	{0x2E,	0x01, 0x0F,	0x05, "World"			},
};

static struct BurnDIPInfo oldsDIPList[] = {
	{0x2E,	0xFF, 0xFF,	0x04, NULL			},

	{0,	0xFE, 0,	6,    "Region"			},
	{0x2E,	0x01, 0x0F,	0x01, "Taiwan"			},
	{0x2E,	0x01, 0x0F,	0x02, "China"			},
	{0x2E,	0x01, 0x0F,	0x03, "Japan"			},
	{0x2E,	0x01, 0x0F,	0x04, "Korea"			},
	{0x2E,	0x01, 0x0F,	0x05, "Hong Kong"		},
	{0x2E,	0x01, 0x0F,	0x06, "World"			},
};

static struct BurnDIPInfo olds100DIPList[] = {
	{0x2E,	0xFF, 0xFF,	0x05, NULL			},

	{0,	0xFE, 0,	6,    "Region"			},
	{0x2E,	0x01, 0x0F,	0x01, "Taiwan"			},
	{0x2E,	0x01, 0x0F,	0x02, "China"			},
	{0x2E,	0x01, 0x0F,	0x03, "Japan"			},
	{0x2E,	0x01, 0x0F,	0x04, "Korea"			},
	{0x2E,	0x01, 0x0F,	0x05, "Hong Kong"		},
	{0x2E,	0x01, 0x0F,	0x06, "World"			},
};

static struct BurnDIPInfo kovjDIPList[] = {
	{0x2E,	0xFF, 0xFF,	0x02, NULL			},

	{0,	0xFE, 0,	6,    "Region"			},
	{0x2E,	0x01, 0x0F,	0x00, "China"			},
	{0x2E,	0x01, 0x0F,	0x01, "Taiwan"			},
	{0x2E,	0x01, 0x0F,	0x02, "Japan"			},
	{0x2E,	0x01, 0x0F,	0x03, "Korea"			},
	{0x2E,	0x01, 0x0F,	0x04, "Hong Kong"		},
	{0x2E,	0x01, 0x0F,	0x05, "World"			},
};

static struct BurnDIPInfo killbldtDIPList[] = {
	{0x2E,	0xFF, 0xFF,	0x21, NULL			},

	{0,	0xFE, 0,	6,    "Region"			},
	{0x2E,	0x01, 0xFF,	0x16, "Taiwan"			},
	{0x2E,	0x01, 0xFF,	0x17, "China"			},
	{0x2E,	0x01, 0xFF,	0x18, "Hong Kong"		},
	{0x2E,	0x01, 0xFF,	0x19, "Japan"			},
	{0x2E,	0x01, 0xFF,	0x20, "Korea"			},
	{0x2E,	0x01, 0xFF,	0x21, "World"			},
};

static struct BurnDIPInfo photoy2kDIPList[] = {
	{0x2E,	0xFF, 0xFF,	0x03, NULL			},

	{0,	0xFE, 0,	7,    "Region"			},
	{0x2E,	0x01, 0x0F,	0x00, "Taiwan"			},
	{0x2E,	0x01, 0x0F,	0x01, "China"			},
	{0x2E,	0x01, 0x0F,	0x02, "Japan"			},
	{0x2E,	0x01, 0x0F,	0x03, "World"			},
	{0x2E,	0x01, 0x0F,	0x04, "Korea"			},
	{0x2E,	0x01, 0x0F,	0x05, "Hong Kong"		},
	{0x2E,	0x01, 0x0F,	0x06, "Singapore / Malaysia"	},
};

static struct BurnDIPInfo raf102jDIPList[] = {
	{0x2E,	0xFF, 0xFF,	0x02, NULL			},

	{0,	0xFE, 0,	7,    "Region"			},
	{0x2E,	0x01, 0x0F,	0x00, "Taiwan"			},
	{0x2E,	0x01, 0x0F,	0x01, "China"			},
	{0x2E,	0x01, 0x0F,	0x02, "Japan"			},
	{0x2E,	0x01, 0x0F,	0x03, "World"			},
	{0x2E,	0x01, 0x0F,	0x04, "Korea"			},
	{0x2E,	0x01, 0x0F,	0x05, "Hong Kong"		},
	{0x2E,	0x01, 0x0F,	0x06, "Singapore / Malaysia"	},
};

static struct BurnDIPInfo puzzli2DIPList[] = {
	{0x2E,	0xFF, 0xFF,	0x05, NULL			},

	{0,	0xFE, 0,	6,    "Region"			},
	{0x2E,	0x01, 0x0F,	0x00, "Taiwan"			},
	{0x2E,	0x01, 0x0F,	0x01, "China"			},
	{0x2E,	0x01, 0x0F,	0x02, "Japan"			},
	{0x2E,	0x01, 0x0F,	0x03, "Korea"			},
	{0x2E,	0x01, 0x0F,	0x04, "Hong Kong"		},
	{0x2E,	0x01, 0x0F,	0x05, "World"			},
};

static struct BurnDIPInfo kov2DIPList[] = {
	{0x2E,	0xFF, 0xFF,	0x04, NULL			},

	{0,	0xFE, 0,	6,    "Region"			},
	{0x2E,	0x01, 0x07,	0x00, "China"			},
	{0x2E,	0x01, 0x07,	0x01, "Taiwan"			},
	{0x2E,	0x01, 0x07,	0x02, "Japan"			},
	{0x2E,	0x01, 0x07,	0x03, "Korea"			},
	{0x2E,	0x01, 0x07,	0x04, "Hong Kong"		},
	{0x2E,	0x01, 0x07,	0x05, "World"			},
};

static struct BurnDIPInfo martmastDIPList[] = {
	{0x2E,	0xFF, 0xFF,	0x05, NULL			},

	{0,	0xFE, 0,	7,    "Region"			},
	{0x2E,	0x01, 0x07,	0x00, "China"			},
	{0x2E,	0x01, 0x07,	0x01, "Taiwan"			},
	{0x2E,	0x01, 0x07,	0x02, "China"			},
	{0x2E,	0x01, 0x07,	0x03, "Korea"			},
	{0x2E,	0x01, 0x07,	0x04, "Hong Kong"		},
	{0x2E,	0x01, 0x07,	0x05, "World"			},
	{0x2E,	0x01, 0x07,	0x06, "USA"			},
};

static struct BurnDIPInfo martmascDIPList[] = {
	{0x2E,	0xFF, 0xFF,	0x00, NULL			},

	{0,	0xFE, 0,	7,    "Region"			},
	{0x2E,	0x01, 0x07,	0x00, "China"			},
	{0x2E,	0x01, 0x07,	0x01, "Taiwan"			},
	{0x2E,	0x01, 0x07,	0x02, "China"			},
	{0x2E,	0x01, 0x07,	0x03, "Korea"			},
	{0x2E,	0x01, 0x07,	0x04, "Hong Kong"		},
	{0x2E,	0x01, 0x07,	0x05, "World"			},
	{0x2E,	0x01, 0x07,	0x06, "USA"			},
};

STDDIPINFOEXT(orlegend, pgm, orlegend )
STDDIPINFOEXT(orlegndc, pgm, orlegndc )
STDDIPINFOEXT(orld111c, pgm, orld111c )
STDDIPINFOEXT(orld105k, pgm, orld105k )
STDDIPINFOEXT(sango,    pgm, sango    )
STDDIPINFOEXT(kovj,     pgm, kovj     )
STDDIPINFOEXT(killbldt, pgm, killbldt )
STDDIPINFOEXT(photoy2k, pgm, photoy2k )
STDDIPINFOEXT(raf102j,  pgm, raf102j  )
STDDIPINFOEXT(puzzli2,  pgm, puzzli2  )
STDDIPINFOEXT(kov2,     pgm, kov2     )
STDDIPINFOEXT(martmast, pgm, martmast )
STDDIPINFOEXT(martmasc, pgm, martmasc )
STDDIPINFOEXT(olds,     pgm, olds     )
STDDIPINFOEXT(olds100,  pgm, olds100  )

// -----------------------------------------------------------------------------
// BIOS


// PGM (Polygame Master) System BIOS

static struct BurnRomInfo pgmRomDesc[] = {
	{ "pgm_p01s.rom", 0x020000, 0xe42b166e, BRF_PRG | BRF_BIOS },	// 68K BIOS (V0001)
	{ "pgm_t01s.rom", 0x200000, 0x1a7123a0, BRF_GRA | BRF_BIOS }, 	// 8x8 Text Layer Tiles
	{ "pgm_m01s.rom", 0x200000, 0x45ae7159, BRF_SND | BRF_BIOS },	// Samples
};

STD_ROM_PICK(pgm)
STD_ROM_FN(pgm)

struct BurnDriver BurnDrvPgm = {
	"pgm", NULL, NULL, "1997",
	"PGM (Polygame Master) System BIOS\0", "BIOS only", "IGS", "PolyGameMaster",
	NULL, NULL, NULL, NULL,
	BDF_BOARDROM, 0, HARDWARE_IGS_PGM, GBF_BIOS, 0,
	NULL, pgmRomInfo, pgmRomName, pgmInputInfo, pgmDIPInfo,
	pgmInit, pgmExit, pgmFrame, pgmDraw, pgmScan,  0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// -----------------------------------------------------------------------------
// Normal Games


// Oriental Legend / Xi Yo Gi Shi Re Zuang (V126)

static struct BurnRomInfo orlegendRomDesc[] = {
	{ "p0103.rom",     0x200000, 0xd5e93543, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code

	{ "t0100.rom",     0x400000, 0x61425e1e, 2 | BRF_GRA },		  //  1 Tile data

	{ "a0100.rom",     0x400000, 0x8b3bd88a, 3 | BRF_GRA },		  //  2 Sprite Color Data
	{ "a0101.rom",     0x400000, 0x3b9e9644, 3 | BRF_GRA },		  //  3	  
	{ "a0102.rom",     0x400000, 0x069e2c38, 3 | BRF_GRA },		  //  4
	{ "a0103.rom",     0x400000, 0x4460a3fd, 3 | BRF_GRA },		  //  5
	{ "a0104.rom",     0x400000, 0x5f8abb56, 3 | BRF_GRA },		  //  6
	{ "a0105.rom",     0x400000, 0xa17a7147, 3 | BRF_GRA },		  //  7

	{ "b0100.rom",     0x400000, 0x69d2e48c, 4 | BRF_GRA },		  //  8 Sprite Masks & Color Indexes
	{ "b0101.rom",     0x400000, 0x0d587bf3, 4 | BRF_GRA },		  //  9
	{ "b0102.rom",     0x400000, 0x43823c1e, 4 | BRF_GRA },		  // 10

	{ "m0100.rom",     0x200000, 0xe5c36c83, 5 | BRF_SND },		  // 11 Samples
};

STDROMPICKEXT(orlegend, orlegend, pgm)
STD_ROM_FN(orlegend)

static int orlegendInit()
{
	pPgmResetCallback = reset_asic3;

	int nRet = pgmInit();

	if (nRet == 0) {
		install_protection_asic3();
	}

	return nRet;
}

struct BurnDriver BurnDrvOrlegend = {
	"orlegend", NULL, "pgm", "1997",
	"Oriental Legend - Xi Yo Gi Shi Re Zuang (V126)\0", NULL, "IGS", "PolyGameMaster",
	L"Oriental Legend\0\u897F\u6E38\u91CA\u5384\u4F20 (V126)\0", NULL, NULL, NULL,
	BDF_GAME_WORKING, 4, HARDWARE_IGS_PGM, GBF_SCRFIGHT, 0,
	NULL, orlegendRomInfo, orlegendRomName, pgmInputInfo, orlegendDIPInfo,
	orlegendInit, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// Oriental Legend / Xi Yo Gi Shi Re Zuang (V112)

static struct BurnRomInfo orlegndeRomDesc[] = {
	{ "p0102.rom",     0x200000, 0x4d0f6cc5, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code

	{ "t0100.rom",     0x400000, 0x61425e1e, 2 | BRF_GRA },		  //  1 Tile data

	{ "a0100.rom",     0x400000, 0x8b3bd88a, 3 | BRF_GRA },		  //  2 Sprite Color Data
	{ "a0101.rom",     0x400000, 0x3b9e9644, 3 | BRF_GRA },		  //  3
	{ "a0102.rom",     0x400000, 0x069e2c38, 3 | BRF_GRA },		  //  4
	{ "a0103.rom",     0x400000, 0x4460a3fd, 3 | BRF_GRA },		  //  5
	{ "a0104.rom",     0x400000, 0x5f8abb56, 3 | BRF_GRA },		  //  6
	{ "a0105.rom",     0x400000, 0xa17a7147, 3 | BRF_GRA },		  //  7

	{ "b0100.rom",     0x400000, 0x69d2e48c, 4 | BRF_GRA },		  //  8 Sprite Masks & Color Indexes
	{ "b0101.rom",     0x400000, 0x0d587bf3, 4 | BRF_GRA },		  //  9
	{ "b0102.rom",     0x400000, 0x43823c1e, 4 | BRF_GRA },		  // 10

	{ "m0100.rom",     0x200000, 0xe5c36c83, 5 | BRF_SND },		  // 11 Samples	
};

STDROMPICKEXT(orlegnde, orlegnde, pgm)
STD_ROM_FN(orlegnde)

struct BurnDriver BurnDrvOrlegnde = {
	"orlegende", "orlegend", "pgm", "1997",
	"Oriental Legend - Xi Yo Gi Shi Re Zuang (V112)\0", NULL, "IGS", "PolyGameMaster",
	L"Oriental Legend\0\u897F\u6E38\u91CA\u5384\u4F20 (V112)\0", NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_CLONE, 4, HARDWARE_IGS_PGM, GBF_SCRFIGHT, 0,
	NULL, orlegndeRomInfo, orlegndeRomName, pgmInputInfo, orlegendDIPInfo,
	orlegendInit, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// Oriental Legend / Xi Yo Gi Shi Re Zuang (V112, China)

static struct BurnRomInfo orlegndcRomDesc[] = {
	{ "p0101.160",     0x200000, 0xb24f0c1e, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code

	{ "t0100.rom",     0x400000, 0x61425e1e, 2 | BRF_GRA },		  //  1 Tile data

	{ "a0100.rom",     0x400000, 0x8b3bd88a, 3 | BRF_GRA },		  //  2 Sprite Color Data
	{ "a0101.rom",     0x400000, 0x3b9e9644, 3 | BRF_GRA },		  //  3
	{ "a0102.rom",     0x400000, 0x069e2c38, 3 | BRF_GRA },		  //  4
	{ "a0103.rom",     0x400000, 0x4460a3fd, 3 | BRF_GRA },		  //  5
	{ "a0104.rom",     0x400000, 0x5f8abb56, 3 | BRF_GRA },		  //  6
	{ "a0105.rom",     0x400000, 0xa17a7147, 3 | BRF_GRA },		  //  7

	{ "b0100.rom",     0x400000, 0x69d2e48c, 4 | BRF_GRA },		  //  8 Sprite Masks & Color Indexes
	{ "b0101.rom",     0x400000, 0x0d587bf3, 4 | BRF_GRA },		  //  9
	{ "b0102.rom",     0x400000, 0x43823c1e, 4 | BRF_GRA },		  // 10

	{ "m0100.rom",     0x200000, 0xe5c36c83, 5 | BRF_SND },		  // 11 Samples	
};

STDROMPICKEXT(orlegndc, orlegndc, pgm)
STD_ROM_FN(orlegndc)

struct BurnDriver BurnDrvOrlegndc = {
	"orlegendc", "orlegend", "pgm", "1997",
	"Oriental Legend - Xi Yo Gi Shi Re Zuang (V112, China)\0", NULL, "IGS", "PolyGameMaster",
	L"Oriental Legend\0\u897F\u6E38\u91CA\u5384\u4F20 (V112, China)\0", NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_CLONE, 4, HARDWARE_IGS_PGM, GBF_SCRFIGHT, 0,
	NULL, orlegndcRomInfo, orlegndcRomName, pgmInputInfo, orlegndcDIPInfo,
	orlegendInit, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// Oriental Legend / Xi Yo Gi Shi Re Zuang (V111, China)

static struct BurnRomInfo orld111cRomDesc[] = {
	{ "olv111ch.u6",   0x080000, 0x5fb86373, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code
	{ "olv111ch.u9",   0x080000, 0x83cf09c8, 1 | BRF_PRG | BRF_ESS }, //  1
	{ "olv111ch.u7",   0x080000, 0x6ee79faf, 1 | BRF_PRG | BRF_ESS }, //  2
	{ "olv111ch.u11",  0x080000, 0xb80ddd3c, 1 | BRF_PRG | BRF_ESS }, //  3

	{ "t0100.rom",     0x400000, 0x61425e1e, 2 | BRF_GRA },		  //  4 Tile data

	{ "a0100.rom",     0x400000, 0x8b3bd88a, 3 | BRF_GRA },		  //  5 Sprite Color Data
	{ "a0101.rom",     0x400000, 0x3b9e9644, 3 | BRF_GRA },		  //  6
	{ "a0102.rom",     0x400000, 0x069e2c38, 3 | BRF_GRA },		  //  7
	{ "a0103.rom",     0x400000, 0x4460a3fd, 3 | BRF_GRA },		  //  8
	{ "a0104.rom",     0x400000, 0x5f8abb56, 3 | BRF_GRA },		  //  9
	{ "a0105.rom",     0x400000, 0xa17a7147, 3 | BRF_GRA },		  // 10

	{ "b0100.rom",     0x400000, 0x69d2e48c, 4 | BRF_GRA },		  // 11 Sprite Masks & Color Indexes
	{ "b0101.rom",     0x400000, 0x0d587bf3, 4 | BRF_GRA },		  // 12
	{ "b0102.rom",     0x400000, 0x43823c1e, 4 | BRF_GRA },		  // 13

	{ "m0100.rom",     0x200000, 0xe5c36c83, 5 | BRF_SND },		  // 14 Samples	
};

STDROMPICKEXT(orld111c, orld111c, pgm)
STD_ROM_FN(orld111c)

struct BurnDriver BurnDrvOrld111c = {
	"orlegend111c", "orlegend", "pgm", "1997",
	"Oriental Legend - Xi Yo Gi Shi Re Zuang (V111, China)\0", NULL, "IGS", "PolyGameMaster",
	L"Oriental Legend\0\u897F\u6E38\u91CA\u5384\u4F20 (V111, China)\0", NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_CLONE, 4, HARDWARE_IGS_PGM, GBF_SCRFIGHT, 0,
	NULL, orld111cRomInfo, orld111cRomName, pgmInputInfo, orld111cDIPInfo,
	orlegendInit, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// Oriental Legend (V105, Korea)

static struct BurnRomInfo orld105kRomDesc[] = {
	{ "olv105ko.u6",   0x080000, 0xb86703fe, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code
	{ "olv105ko.u9",   0x080000, 0x5a108e39, 1 | BRF_PRG | BRF_ESS }, //  1
	{ "olv105ko.u7",   0x080000, 0x5712facc, 1 | BRF_PRG | BRF_ESS }, //  2
	{ "olv105ko.u11",  0x080000, 0x40ae4d9e, 1 | BRF_PRG | BRF_ESS }, //  3

	{ "t0100.rom",     0x400000, 0x61425e1e, 2 | BRF_GRA },		  //  4 Tile data

	{ "a0100.rom",     0x400000, 0x8b3bd88a, 3 | BRF_GRA },		  //  5 Sprite Color Data
	{ "a0101.rom",     0x400000, 0x3b9e9644, 3 | BRF_GRA },		  //  6
	{ "a0102.rom",     0x400000, 0x069e2c38, 3 | BRF_GRA },		  //  7
	{ "a0103.rom",     0x400000, 0x4460a3fd, 3 | BRF_GRA },		  //  8
	{ "a0104.rom",     0x400000, 0x5f8abb56, 3 | BRF_GRA },		  //  9
	{ "a0105.rom",     0x400000, 0xa17a7147, 3 | BRF_GRA },		  // 10

	{ "b0100.rom",     0x400000, 0x69d2e48c, 4 | BRF_GRA },		  // 11 Sprite Masks & Color Indexes
	{ "b0101.rom",     0x400000, 0x0d587bf3, 4 | BRF_GRA },		  // 12
	{ "b0102.rom",     0x400000, 0x43823c1e, 4 | BRF_GRA },		  // 13

	{ "m0100.rom",     0x200000, 0xe5c36c83, 5 | BRF_SND },		  // 14 Samples	
};

STDROMPICKEXT(orld105k, orld105k, pgm)
STD_ROM_FN(orld105k)

struct BurnDriver BurnDrvOrld105k = {
	"orlegend105k", "orlegend", "pgm", "1997",
	"Oriental Legend (V105, Korea)\0", NULL, "IGS", "PolyGameMaster",
	NULL, NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_CLONE, 4, HARDWARE_IGS_PGM, GBF_SCRFIGHT, 0,
	NULL, orld105kRomInfo, orld105kRomName, pgmInputInfo, orld105kDIPInfo,
	orlegendInit, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// Dragon World II (V110X, World)

static struct BurnRomInfo drgw2RomDesc[] = {
	{ "v-110x.u2",     0x080000, 0x1978106b, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code

	{ "pgmt0200.u7",   0x400000, 0xb0f6534d, 2 | BRF_GRA },		  //  1 Tile data

	{ "pgma0200.u5",   0x400000, 0x13b95069, 3 | BRF_GRA },		  //  2 Sprite Color Data

	{ "pgmb0200.u9",   0x400000, 0x932d0f13, 4 | BRF_GRA },		  //  3 Sprite Masks & Color Indexes
};

STDROMPICKEXT(drgw2, drgw2, pgm)
STD_ROM_FN(drgw2)

void drgw2_patch()
{
	pgm_decrypt_dw2();

	// protection-related patches
	if (strcmp(BurnDrvGetTextA(DRV_NAME), "drgw2") == 0) {
		*((unsigned short*)(PGM68KROM + 0x031098)) = 0x4e93;
		*((unsigned short*)(PGM68KROM + 0x03113e)) = 0x4e93;
		*((unsigned short*)(PGM68KROM + 0x0311ce)) = 0x4e93;
	}

	if (strcmp(BurnDrvGetTextA(DRV_NAME), "drgw2c") == 0) {
		*((unsigned short*)(PGM68KROM + 0x0303bc)) = 0x4e93;
		*((unsigned short*)(PGM68KROM + 0x030462)) = 0x4e93;
		*((unsigned short*)(PGM68KROM + 0x0304F2)) = 0x4e93;
	}

	if (strcmp(BurnDrvGetTextA(DRV_NAME), "drgw2j") == 0) {
		*((unsigned short*)(PGM68KROM + 0x0302C0)) = 0x4e93;
		*((unsigned short*)(PGM68KROM + 0x030366)) = 0x4e93;
		*((unsigned short*)(PGM68KROM + 0x0303F6)) = 0x4e93;
	}
}

int drgw2Init()
{
	pPgmInitCallback = drgw2_patch;

	int nRet = pgmInit();

	if (nRet == 0) {
		install_protection_dw2();
	}

	return nRet;
}

struct BurnDriver BurnDrvDrgw2 = {
	"drgw2", NULL, "pgm", "1997",
	"Dragon World II (V110X, World)\0", NULL, "IGS", "PolyGameMaster",
	NULL, NULL, NULL, NULL,
	BDF_GAME_WORKING, 4, HARDWARE_IGS_PGM, GBF_PUZZLE, 0,
	NULL, drgw2RomInfo, drgw2RomName, pgmInputInfo, pgmDIPInfo,
	drgw2Init, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// Zhong Guo Long II (V100C, China)

static struct BurnRomInfo drgw2cRomDesc[] = {
	{ "v-100c.u2",     0x080000, 0x67467981, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code

	{ "pgmt0200.u7",   0x400000, 0xb0f6534d, 2 | BRF_GRA },		  //  1 Tile data

	{ "pgma0200.u5",   0x400000, 0x13b95069, 3 | BRF_GRA },		  //  2 Sprite Color Data

	{ "pgmb0200.u9",   0x400000, 0x932d0f13, 4 | BRF_GRA },		  //  3 Sprite Masks & Color Indexes
};

STDROMPICKEXT(drgw2c, drgw2c, pgm)
STD_ROM_FN(drgw2c)

struct BurnDriver BurnDrvDrgw2c = {
	"drgw2c", "drgw2", "pgm", "1997",
	"Zhong Guo Long II (V100C, China)\0", NULL, "IGS", "PolyGameMaster",
	L"\u4E2D\u570B\u9F8D II (V100C, China)\0", NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_CLONE, 4, HARDWARE_IGS_PGM, GBF_PUZZLE, 0,
	NULL, drgw2cRomInfo, drgw2cRomName, pgmInputInfo, pgmDIPInfo,
	drgw2Init, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// Chuugokuryuu II (V100J, Japan)

static struct BurnRomInfo drgw2jRomDesc[] = {
	{ "v-100j.u2",     0x080000, 0xf8f8393e, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code

	{ "pgmt0200.u7",   0x400000, 0xb0f6534d, 2 | BRF_GRA },		  //  1 Tile data

	{ "pgma0200.u5",   0x400000, 0x13b95069, 3 | BRF_GRA },		  //  2 Sprite Color Data

	{ "pgmb0200.u9",   0x400000, 0x932d0f13, 4 | BRF_GRA },		  //  3 Sprite Masks & Color Indexes
};

STDROMPICKEXT(drgw2j, drgw2j, pgm)
STD_ROM_FN(drgw2j)

struct BurnDriver BurnDrvDrgw2j = {
	"drgw2j", "drgw2", "pgm", "1997",
	"Chuugokuryuu II (V100J, Japan)\0", NULL, "IGS", "PolyGameMaster",
	L"\u4E2D\u570B\u9F8D II (V100J, Japan)\0", NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_CLONE, 4, HARDWARE_IGS_PGM, GBF_PUZZLE, 0,
	NULL, drgw2jRomInfo, drgw2jRomName, pgmInputInfo, pgmDIPInfo,
	drgw2Init, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// The Killing Blade (V104)

static struct BurnRomInfo killbldRomDesc[] = {
	{ "kb_u3_v104.u3", 0x080000, 0x6db1d719, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code
	{ "kb_u6_v104.u6", 0x080000, 0x31ecc978, 1 | BRF_PRG | BRF_ESS }, //  1
	{ "kb_u4_v104.u4", 0x080000, 0x1ed8b2e7, 1 | BRF_PRG | BRF_ESS }, //  2
	{ "kb_u5_v104.u5", 0x080000, 0xa0bafc29, 1 | BRF_PRG | BRF_ESS }, //  3

	{ "t0300.u14",	   0x400000, 0x0922f7d9, 2 | BRF_GRA },		  //  4 Tile data

	{ "a0300.u9",      0x400000, 0x3f9455d3, 3 | BRF_GRA },		  //  5 Sprite Color Data
	{ "a0301.u10",	   0x400000, 0x92776889, 3 | BRF_GRA },		  //  6
	{ "a0303.u11",	   0x400000, 0x33f5cc69, 3 | BRF_GRA },		  //  7
	{ "a0306.u12",	   0x400000, 0xcc018a8e, 3 | BRF_GRA },		  //  8
	{ "a0307.u2",	   0x400000, 0xbc772e39, 3 | BRF_GRA },		  //  9

	{ "b0300.u13",	   0x400000, 0x7f876981, 4 | BRF_GRA },		  // 10 Sprite Masks & Color Indexes
	{ "b0302.u14",	   0x400000, 0xeea9c502, 4 | BRF_GRA },		  // 11
	{ "b0303.u15",	   0x200000, 0x77a9652e, 4 | BRF_GRA },		  // 12

	{ "m0300.u1",      0x400000, 0x93159695, 5 | BRF_SND },		  // 13 Samples

	{ "kb_u2_v104.u2", 0x010000, 0xc970f6d5, 0 | BRF_PRG | BRF_ESS }, // 14 Protection Data
};

STDROMPICKEXT(killbld, killbld, pgm)
STD_ROM_FN(killbld)

struct BurnDriver BurnDrvKillbld = {
	"killbld", NULL, "pgm", "1998",
	"The Killing Blade (V104)\0", "Not working", "IGS", "PolyGameMaster",
	L"The Killing Blade\0\u50B2\u5251\u72C2\u5200\0\u50B2\u528D\u72C2\u5200 (V104)\0", NULL, NULL, NULL,
	0, 4, HARDWARE_IGS_PGM, GBF_VSFIGHT, 0,
	NULL, killbldRomInfo, killbldRomName, pgmInputInfo, pgmDIPInfo,
	pgmInit, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// The Killing Blade (V109, China)

static struct BurnRomInfo killbldtRomDesc[] = {
	{ "kb.u9",         0x200000, 0x43da77d7, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code

	{ "t0300.u14",     0x400000, 0x0922f7d9, 2 | BRF_GRA },		  //  1 Tile data

	{ "a0300.u9",      0x400000, 0x3f9455d3, 3 | BRF_GRA },		  //  2 Sprite Color Data
	{ "a0301.u10",     0x400000, 0x92776889, 3 | BRF_GRA },		  //  3
	{ "a0303.u11",     0x400000, 0x33f5cc69, 3 | BRF_GRA },		  //  4
	{ "a0306.u12",     0x400000, 0xcc018a8e, 3 | BRF_GRA },		  //  5
	{ "a0307.u2",      0x400000, 0xbc772e39, 3 | BRF_GRA },		  //  6

	{ "b0300.u13",     0x400000, 0x7f876981, 4 | BRF_GRA },		  //  7 Sprite Masks & Color Indexes
	{ "b0302.u14",     0x400000, 0xeea9c502, 4 | BRF_GRA },		  //  8
	{ "b0303.u15",     0x200000, 0x77a9652e, 4 | BRF_GRA },		  //  9

	{ "m0300.u1",      0x400000, 0x93159695, 5 | BRF_SND },		  // 10 Samples

	{ "kb_u2.rom",     0x010000, 0xde3eae63, 0 | BRF_PRG | BRF_ESS }, // 11 Protection Data

	{ "kb.ram",        0x004000, 0x6994c507, 0 | BRF_ESS }, 	  // 12 Ram Dump
};

STDROMPICKEXT(killbldt, killbldt, pgm)
STD_ROM_FN(killbldt)

void killbldt_patch()
{
	pgm_decrypt_killbld();

	// Protection-related patches
	*((unsigned short *)(PGM68KROM + 0x008a2c)) = 0xB6AA;
	*((unsigned short *)(PGM68KROM + 0x008a30)) = 0x6610;
	*((unsigned short *)(PGM68KROM + 0x008a32)) = 0x13c2;
	*((unsigned short *)(PGM68KROM + 0x008a34)) = 0x0080;
	*((unsigned short *)(PGM68KROM + 0x008a36)) = 0x9c76;
	*((unsigned short *)(PGM68KROM + 0x008a38)) = 0x23c3;
	*((unsigned short *)(PGM68KROM + 0x008a3a)) = 0x0080;
	*((unsigned short *)(PGM68KROM + 0x008a3c)) = 0x9c78;
	*((unsigned short *)(PGM68KROM + 0x008a3e)) = 0x1002;
	*((unsigned short *)(PGM68KROM + 0x008a40)) = 0x6054;
	*((unsigned short *)(PGM68KROM + 0x008a42)) = 0x5202;
	*((unsigned short *)(PGM68KROM + 0x008a44)) = 0x0c02;
}

static int killbldtInit()
{
	pPgmInitCallback = killbldt_patch;
	pPgmResetCallback = reset_killbldt;

	int nRet = pgmInit();

	if (nRet == 0) {
		install_protection_killbldt();
	}

	return nRet;
}

struct BurnDriver BurnDrvKillbldt = {
	"killbldt", "killbld", "pgm", "1998",
	"The Killing Blade (V109, China)\0", "Imperfect Protection Emulation", "IGS", "PolyGameMaster",
	L"The Killing Blade\0\u50B2\u5251\u72C2\u5200\0\u50B2\u528D\u72C2\u5200 (V109, China)\0", NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_CLONE, 4, HARDWARE_IGS_PGM, GBF_VSFIGHT, 0,
	NULL, killbldtRomInfo, killbldtRomName, pgmInputInfo, killbldtDIPInfo,
	killbldtInit, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// Dragon World 3 (V100J, Japan)

static struct BurnRomInfo drgw3RomDesc[] = {
	{ "dw3_v100.u12",  0x080000, 0x47243906, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code
	{ "dw3_v100.u13",  0x080000, 0xb7cded21, 1 | BRF_PRG | BRF_ESS }, //  1

	{ "dw3t0400.u18",  0x400000, 0xb70f3357, 2 | BRF_GRA },		  //  2 Tile data

	{ "dw3a0400.u9",   0x400000, 0xdd7bfd40, 3 | BRF_GRA },		  //  3 Sprite Color Data
	{ "dw3a0401.u10",  0x400000, 0xcab6557f, 3 | BRF_GRA },		  //  4

	{ "dw3b0400.u13",  0x400000, 0x4bb87cc0, 4 | BRF_GRA },		  //  5 Sprite Masks & Color Indexes

	{ "dw3m0400.u1",   0x400000, 0x031eb9ce, 5 | BRF_SND },		  //  6 Samples

	{ "dw3_v100.u15",  0x010000, 0x03dc4fdf, 0 | BRF_PRG | BRF_ESS }, //  7 Protection data
};

STDROMPICKEXT(drgw3, drgw3, pgm)
STD_ROM_FN(drgw3)

int drgw3Init()
{
	pPgmInitCallback = pgm_decrypt_dw3;

	return pgmInit();
}

struct BurnDriverD BurnDrvDrgw3 = {
	"drgw3", NULL, "pgm", "1998",
	"Dragon World 3 (V100J, Japan)\0", NULL, "IGS", "PolyGameMaster",
	L"Dragon World 3\0\u4E2D\u56FD\u9F99 3 (V100J, Japan)\0", NULL, NULL, NULL,
	0, 4, HARDWARE_IGS_PGM, GBF_PUZZLE, 0,
	NULL, drgw3RomInfo, drgw3RomName, pgmInputInfo, pgmDIPInfo,
	drgw3Init, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// Dragon World 3 (V106, Korea)

static struct BurnRomInfo drgw3kRomDesc[] = {
	{ "dw3_v106.u12",  0x080000, 0xc3f6838b, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code
	{ "dw3_v106.u13",  0x080000, 0x28284e22, 1 | BRF_PRG | BRF_ESS }, //  1

	{ "dw3t0400.u18",  0x400000, 0xb70f3357, 2 | BRF_GRA },		  //  2 Tile data

	{ "dw3a0400.u9",   0x400000, 0xdd7bfd40, 3 | BRF_GRA },		  //  3 Sprite Color Data
	{ "dw3a0401.u10",  0x400000, 0xcab6557f, 3 | BRF_GRA },		  //  4

	{ "dw3b0400.u13",  0x400000, 0x4bb87cc0, 4 | BRF_GRA },		  //  5 Sprite Masks & Color Indexes

	{ "dw3m0400.u1",   0x400000, 0x031eb9ce, 5 | BRF_SND },		  //  6 Samples

	{ "dw3_v100.u15",  0x010000, 0x03dc4fdf, 0 | BRF_PRG | BRF_ESS }, //  7 Protection data
};

STDROMPICKEXT(drgw3k, drgw3k, pgm)
STD_ROM_FN(drgw3k)

struct BurnDriverD BurnDrvDrgw3k = {
	"drgw3k", "drgw3", "pgm", "1998",
	"Dragon World 3 (V106, Korea)\0", NULL, "IGS", "PolyGameMaster",
	NULL, NULL, NULL, NULL,
	BDF_CLONE, 4, HARDWARE_IGS_PGM, GBF_PUZZLE, 0,
	NULL, drgw3kRomInfo, drgw3kRomName, pgmInputInfo, pgmDIPInfo,
	drgw3Init, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// Oriental Legend Super (V101, Korea)

static struct BurnRomInfo oldsRomDesc[] = {
	{ "sp_v101.u2",	   0x080000, 0x08eb9661, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code
	{ "sp_v101.u3",	   0x080000, 0x0a358c1e, 1 | BRF_PRG | BRF_ESS }, //  1
	{ "sp_v101.u4",	   0x080000, 0x766570e0, 1 | BRF_PRG | BRF_ESS }, //  2
	{ "sp_v101.u5",	   0x080000, 0x58662e12, 1 | BRF_PRG | BRF_ESS }, //  3
	{ "sp_v101.u1",	   0x080000, 0x2b2f4f1e, 1 | BRF_PRG | BRF_ESS }, //  4

	{ "t0500.rom",	   0x400000, 0xd881726c, 2 | BRF_GRA },		  //  5 Tile data
	{ "t0501.rom",	   0x200000, 0xd2106864, 2 | BRF_GRA },		  //  6

	{ "a0500.rom",	   0x400000, 0x80a59197, 3 | BRF_GRA },		  //  7 Sprite Color Data
	{ "a0501.rom",	   0x400000, 0x98c931b1, 3 | BRF_GRA },		  //  8
	{ "a0502.rom",	   0x400000, 0xc3fcdf1d, 3 | BRF_GRA },		  //  9
	{ "a0503.rom",	   0x400000, 0x066dffec, 3 | BRF_GRA },		  // 10
	{ "a0504.rom",	   0x400000, 0x45337583, 3 | BRF_GRA },		  // 11
	{ "a0505.rom",	   0x400000, 0x5b8cf3a5, 3 | BRF_GRA },		  // 12
	{ "a0506.rom",	   0x400000, 0x087ac60c, 3 | BRF_GRA },		  // 13

	{ "b0500.rom",	   0x400000, 0xcde07f74, 4 | BRF_GRA },		  // 14 Sprite Masks & Color Indexes
	{ "b0501.rom",	   0x400000, 0x1546c2e9, 4 | BRF_GRA },		  // 15
	{ "b0502.rom",	   0x400000, 0xe97b31c3, 4 | BRF_GRA },		  // 16
	{ "b0503.u16",	   0x400000, 0xe41d98e4, 4 | BRF_GRA },		  // 17

	{ "m0500.rom",	   0x200000, 0x37928cdd, 5 | BRF_SND },		  // 18 Samples

	{ "sp_v101.u6",	   0x010000, 0x097046bc, 0 | BRF_PRG | BRF_ESS }, // 19 Protection Rom

	{ "ram_dump", 	   0x040000, 0x619cc52d, 0 | BRF_ESS },		  // 20 ram dump
};

STDROMPICKEXT(olds, olds, pgm)
STD_ROM_FN(olds)

static int oldsInit()
{
	pPgmResetCallback = reset_olds;

	int nRet = pgmInit();

	if (nRet == 0) {
		install_protection_olds();
	}

	return nRet;
}

struct BurnDriver BurnDrvOlds = {
	"olds", NULL, "pgm", "1999",
	"Oriental Legend Super (V101, Korea)\0", "Imperfect Protection Emulation", "IGS", "PolyGameMaster",
	NULL, NULL, NULL, NULL,
	BDF_GAME_WORKING, 4, HARDWARE_IGS_PGM, GBF_SCRFIGHT, 0,
	NULL, oldsRomInfo, oldsRomName, pgmInputInfo, oldsDIPInfo,
	oldsInit, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// Oriental Legend Special / Xi Yo Gi Shi Re Zuang Super (V100)

static struct BurnRomInfo olds100RomDesc[] = {
	{ "v100-u2.040",   0x080000, 0x517c2a06, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code
	{ "v100-u3.040",   0x080000, 0xd0e2b741, 1 | BRF_PRG | BRF_ESS }, //  1
	{ "v100-u4.040",   0x080000, 0x32a6bdbd, 1 | BRF_PRG | BRF_ESS }, //  2
	{ "v100-u5.040",   0x080000, 0xb4a1cafb, 1 | BRF_PRG | BRF_ESS }, //  3
	{ "v100-u1.040",   0x080000, 0x37ea4e75, 1 | BRF_PRG | BRF_ESS }, //  4

	{ "t0500.rom",	   0x400000, 0xd881726c, 2 | BRF_GRA },		  //  5 Tile data
	{ "t0501.rom",	   0x200000, 0xd2106864, 2 | BRF_GRA },		  //  6

	{ "a0500.rom",	   0x400000, 0x80a59197, 3 | BRF_GRA },		  //  7 Sprite Color Data
	{ "a0501.rom",	   0x400000, 0x98c931b1, 3 | BRF_GRA },		  //  8
	{ "a0502.rom",	   0x400000, 0xc3fcdf1d, 3 | BRF_GRA },		  //  9
	{ "a0503.rom",	   0x400000, 0x066dffec, 3 | BRF_GRA },		  // 10
	{ "a0504.rom",	   0x400000, 0x45337583, 3 | BRF_GRA },		  // 11
	{ "a0505.rom",	   0x400000, 0x5b8cf3a5, 3 | BRF_GRA },		  // 12
	{ "a0506.rom",	   0x400000, 0x087ac60c, 3 | BRF_GRA },		  // 13

	{ "b0500.rom",	   0x400000, 0xcde07f74, 4 | BRF_GRA },		  // 14 Sprite Masks & Color Indexes
	{ "b0501.rom",	   0x400000, 0x1546c2e9, 4 | BRF_GRA },		  // 15
	{ "b0502.rom",	   0x400000, 0xe97b31c3, 4 | BRF_GRA },		  // 16
	{ "b0503.u16",	   0x400000, 0xe41d98e4, 4 | BRF_GRA },		  // 17

	{ "m0500.rom",	   0x200000, 0x37928cdd, 5 | BRF_SND },		  // 18 Samples

	{ "kd-u6.512",	   0x010000, 0xe7613dda, 0 | BRF_PRG | BRF_ESS }, // 19 Protection Rom

	{ "ram_dump", 	   0x040000, 0x619cc52d, 0 | BRF_ESS },		  // 20 ram dump
};

STDROMPICKEXT(olds100, olds100, pgm)
STD_ROM_FN(olds100)

struct BurnDriver BurnDrvOlds100 = {
	"olds100", "olds", "pgm", "1998",
	"Oriental Legend Special - Xi Yo Gi Shi Re Zuang Super (V100)\0", "Imperfect Protection Emulation", "IGS", "PolyGameMaster",
	L"Oriental Legend Super\0\u897F\u6E38\u91CA\u5384\u4F20 Super (V100)\0", NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_CLONE, 4, HARDWARE_IGS_PGM, GBF_SCRFIGHT, 0,
	NULL, olds100RomInfo, olds100RomName, pgmInputInfo, olds100DIPInfo,
	oldsInit, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// Oriental Legend Special / Xi Yo Gi Shi Re Zuang Super (V100 alt)

static struct BurnRomInfo olds100aRomDesc[] = {
	{ "p0500.v10",	   0x400000, 0x8981fc87, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code

	{ "t0500.rom",	   0x400000, 0xd881726c, 2 | BRF_GRA },		  //  1 Tile data
	{ "t0501.rom",	   0x200000, 0xd2106864, 2 | BRF_GRA },		  //  2

	{ "a0500.rom",	   0x400000, 0x80a59197, 3 | BRF_GRA },		  //  3 Sprite Color Data
	{ "a0501.rom",	   0x400000, 0x98c931b1, 3 | BRF_GRA },		  //  4
	{ "a0502.rom",	   0x400000, 0xc3fcdf1d, 3 | BRF_GRA },		  //  5
	{ "a0503.rom",	   0x400000, 0x066dffec, 3 | BRF_GRA },		  //  6
	{ "a0504.rom",	   0x400000, 0x45337583, 3 | BRF_GRA },		  //  7
	{ "a0505.rom",	   0x400000, 0x5b8cf3a5, 3 | BRF_GRA },		  //  8
	{ "a0506.rom",	   0x400000, 0x087ac60c, 3 | BRF_GRA },		  //  9

	{ "b0500.rom",	   0x400000, 0xcde07f74, 4 | BRF_GRA },		  // 10 Sprite Masks & Color Indexes
	{ "b0501.rom",	   0x400000, 0x1546c2e9, 4 | BRF_GRA },		  // 11
	{ "b0502.rom",	   0x400000, 0xe97b31c3, 4 | BRF_GRA },		  // 12
	{ "b0503.u16",	   0x400000, 0xe41d98e4, 4 | BRF_GRA },		  // 13

	{ "m0500.rom",	   0x200000, 0x37928cdd, 5 | BRF_SND },		  // 14 Samples
	
	{ "protection_data.u6",	  0x010000, 0, 	 0 | BRF_PRG | BRF_NODUMP }, // 15 Protection Rom

	{ "ram_dump", 	   0x040000, 0x619cc52d, 0 | BRF_ESS },		  // 16 ram dump
};

STDROMPICKEXT(olds100a, olds100a, pgm)
STD_ROM_FN(olds100a)

struct BurnDriver BurnDrvOlds100a = {
	"olds100a", "olds", "pgm", "1998",
	"Oriental Legend Special - Xi Yo Gi Shi Re Zuang Super (V100 alt)\0", "Imperfect Protection Emulation", "IGS", "PolyGameMaster",
	L"Oriental Legend Super\0\u897F\u6E38\u91CA\u5384\u4F20 Super (V100 alt)\0", NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_CLONE, 4, HARDWARE_IGS_PGM, GBF_SCRFIGHT, 0,
	NULL, olds100aRomInfo, olds100aRomName, pgmInputInfo, olds100DIPInfo,
	oldsInit, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// Photo Y2K / Real and Fake (V104)

static struct BurnRomInfo photoy2kRomDesc[] = {
	{ "v104.16m",      0x200000, 0xe051070f, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code

	{ "t0700.rom",     0x080000, 0x93943b4d, 2 | BRF_GRA },		  //  1 Tile data

	{ "a0700.l",       0x400000, 0x26a9ae9c, 3 | BRF_GRA },		  //  2 Sprite Color Data
	{ "a0700.h",       0x400000, 0x79bc1fc1, 3 | BRF_GRA },		  //  3
	{ "a0701.l",       0x400000, 0x23607f81, 3 | BRF_GRA },		  //  4
	{ "a0701.h",       0x400000, 0x5f2efd37, 3 | BRF_GRA },		  //  5
	{ "a0702.rom",     0x080000, 0x42239e1b, 3 | BRF_GRA },		  //  6

	{ "b0700.l",       0x400000, 0xaf096904, 4 | BRF_GRA },		  //  7 Sprite Masks & Color Indexes
	{ "b0700.h",       0x400000, 0x6d53de26, 4 | BRF_GRA },		  //  8
	{ "cgv101.rom",    0x020000, 0xda02ec3e, 4 | BRF_GRA },		  //  9

	{ "m0700.rom",     0x080000, 0xacc7afce, 5 | BRF_SND },		  // 10 Samples

	{ "photoy2k_v100_china.asic", 0x004000,  0x6dd7f257, 7 | BRF_PRG | BRF_ESS }, // 11 Internal ARM7 Rom
};

STDROMPICKEXT(photoy2k, photoy2k, pgm)
STD_ROM_FN(photoy2k)

int photoy2kInit()
{
	pPgmInitCallback = pgm_decrypt_photoy2k;

	Arm7SetIdleLoopAddress(0x000001f4);

	int nRet = pgmInit();

	if (nRet == 0) {
		install_protection_kovsh();
	}

	return nRet;
}

struct BurnDriver BurnDrvPhotoy2k = {
	"photoy2k", NULL, "pgm", "1999",
	"Photo Y2K\0Real and Fake (V104)\0", NULL, "IGS", "PolyGameMaster",
	L"Photo Y2K\0\u30EA\u30A2\u30EB\u30A2\u30F3\u30C9 \u30D5\u30A7\u30A4\u30AF\0\u5927\u5BB6\u6765 \u627E\u78B4\0\u8D85\u7EA7 \u6BD4\u4E00\u6BD4 (V104)\0", NULL, NULL, NULL,
	BDF_GAME_WORKING, 4, HARDWARE_IGS_PGM | HARDWARE_IGS_USE_ARM_CPU, GBF_PUZZLE, 0,
	NULL, photoy2kRomInfo, photoy2kRomName, pgmInputInfo, photoy2kDIPInfo,
	photoy2kInit, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// Real and Fake / Photo Y2K (V102, Japan)

static struct BurnRomInfo raf102jRomDesc[] = {
	{ "v102.u4",       0x080000, 0xa65eda9f, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code
	{ "v102.u6",       0x080000, 0xb9ca5504, 1 | BRF_PRG | BRF_ESS }, //  1
	{ "v102.u5",       0x080000, 0x9201621b, 1 | BRF_PRG | BRF_ESS }, //  2
	{ "v102.u8",       0x080000, 0x3be22b8f, 1 | BRF_PRG | BRF_ESS }, //  3

	{ "t0700.rom",     0x080000, 0x93943b4d, 2 | BRF_GRA },		  //  4 Tile data

	{ "a0700.l",       0x400000, 0x26a9ae9c, 3 | BRF_GRA },		  //  5 Sprite Color Data
	{ "a0700.h",       0x400000, 0x79bc1fc1, 3 | BRF_GRA },		  //  6
	{ "a0701.l",       0x400000, 0x23607f81, 3 | BRF_GRA },		  //  7
	{ "a0701.h",       0x400000, 0x5f2efd37, 3 | BRF_GRA },		  //  8
	{ "a0702.rom",     0x080000, 0x42239e1b, 3 | BRF_GRA },		  //  9

	{ "b0700.l",       0x400000, 0xaf096904, 4 | BRF_GRA },		  // 10 Sprite Masks & Color Indexes
	{ "b0700.h",       0x400000, 0x6d53de26, 4 | BRF_GRA },		  // 11
	{ "cgv101.rom",    0x020000, 0xda02ec3e, 4 | BRF_GRA },		  // 12

	{ "m0700.rom",     0x080000, 0xacc7afce, 5 | BRF_SND },		  // 13 Samples

	{ "photoy2k_v100_china.asic", 0x0004000,  0x6dd7f257, 7 | BRF_PRG | BRF_ESS }, // 14 Internal ARM7? Rom
};

STDROMPICKEXT(raf102j, raf102j, pgm)
STD_ROM_FN(raf102j)

struct BurnDriver BurnDrvRaf102j = {
	"raf102j", "photoy2k", "pgm", "1999",
	"Real and Fake\0Photo Y2K (V102, Japan)\0", NULL, "IGS", "PolyGameMaster",
	L"\u30EA\u30A2\u30EB\u30A2\u30F3\u30C9 \u30D5\u30A7\u30A4\u30AF\0Photo Y2K\0\u5927\u5BB6\u6765 \u627E\u78B4\0\u8D85\u7EA7 \u6BD4\u4E00\u6BD4 (V102, Japan)\0", NULL, NULL, NULL,
	BDF_GAME_WORKING  | BDF_CLONE, 4, HARDWARE_IGS_PGM | HARDWARE_IGS_USE_ARM_CPU, GBF_PUZZLE, 0,
	NULL, raf102jRomInfo, raf102jRomName, pgmInputInfo, raf102jDIPInfo,
	photoy2kInit, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// Knights of Valour / Sangoku Senki (V117)

static struct BurnRomInfo kovRomDesc[] = {
	{ "p0600.117",     0x400000, 0xc4d19fe6, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code

	{ "t0600.rom",     0x800000, 0x4acc1ad6, 2 | BRF_GRA },		  //  1 Tile data
	
	{ "a0600.rom",     0x800000, 0xd8167834, 3 | BRF_GRA },		  //  2 Sprite Color Data
	{ "a0601.rom",     0x800000, 0xff7a4373, 3 | BRF_GRA },		  //  3
	{ "a0602.rom",     0x800000, 0xe7a32959, 3 | BRF_GRA },		  //  4
	{ "a0603.rom",     0x400000, 0xec31abda, 3 | BRF_GRA },		  //  5
	
	{ "b0600.rom",     0x800000, 0x7d3cd059, 4 | BRF_GRA },		  //  6 Sprite Masks & Color Indexes
	{ "b0601.rom",     0x400000, 0xa0bb1c2f, 4 | BRF_GRA },		  //  7
	
	{ "m0600.rom",     0x400000, 0x3ada4fd6, 5 | BRF_SND },		  //  8 Samples
	
	{ "kov_igs027a.bin", 0x004000, 0x00000000, 0 | BRF_PRG | BRF_NODUMP },
};

STDROMPICKEXT(kov, kov, pgm)
STD_ROM_FN(kov)

static int kovInit()
{
	pPgmInitCallback = pgm_decrypt_kov;
	pPgmResetCallback = reset_asic28;

	int nRet = pgmInit();

	if (nRet == 0) {
		install_protection_asic28();
	}

	return nRet;
}

struct BurnDriver BurnDrvKov = {
	"kov", NULL, "pgm", "1999",
	"Knights of Valour - Sangoku Senki (V117)\0", NULL, "IGS", "PolyGameMaster",
	L"Knights of Valour\0\u4E09\u56FD\u6226\u7D00\0\u4E09\u56FD\u6218\u7EAA (V117)\0", NULL, NULL, NULL,
	BDF_GAME_WORKING, 4, HARDWARE_IGS_PGM, GBF_SCRFIGHT, 0,
	NULL, kovRomInfo, kovRomName, pgmInputInfo, sangoDIPInfo,
	kovInit, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// Knights of Valour / Sangoku Senki (V115)

static struct BurnRomInfo kov115RomDesc[] = {
	{ "p0600.115",     0x400000, 0x527a2924, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code

	{ "t0600.rom",     0x800000, 0x4acc1ad6, 2 | BRF_GRA },		  //  1 Tile data
	
	{ "a0600.rom",     0x800000, 0xd8167834, 3 | BRF_GRA },		  //  2 Sprite Color Data
	{ "a0601.rom",     0x800000, 0xff7a4373, 3 | BRF_GRA },		  //  3
	{ "a0602.rom",     0x800000, 0xe7a32959, 3 | BRF_GRA },		  //  4
	{ "a0603.rom",     0x400000, 0xec31abda, 3 | BRF_GRA },		  //  5
	
	{ "b0600.rom",     0x800000, 0x7d3cd059, 4 | BRF_GRA },		  //  6 Sprite Masks & Color Indexes
	{ "b0601.rom",     0x400000, 0xa0bb1c2f, 4 | BRF_GRA },		  //  7
	
	{ "m0600.rom",     0x400000, 0x3ada4fd6, 5 | BRF_SND },		  //  8 Samples
	
	{ "kov_igs027a.bin", 0x004000, 0x00000000, 0 | BRF_PRG | BRF_NODUMP },
};

STDROMPICKEXT(kov115, kov115, pgm)
STD_ROM_FN(kov115)

struct BurnDriver BurnDrvKov115 = {
	"kov115", "kov", "pgm", "1999",
	"Knights of Valour - Sangoku Senki (V115)\0", NULL, "IGS", "PolyGameMaster",
	L"Knights of Valour\0\u4E09\u56FD\u6226\u7D00\0\u4E09\u56FD\u6218\u7EAA (V115)\0", NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_CLONE, 4, HARDWARE_IGS_PGM, GBF_SCRFIGHT, 0,
	NULL, kov115RomInfo, kov115RomName, pgmInputInfo, sangoDIPInfo,
	kovInit, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// Knights of Valour Plus / Sangoku Senki (V100, Japan)

static struct BurnRomInfo kovjRomDesc[] = {
	{ "sav111.u4",     0x080000, 0xae2f1b4e, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code
	{ "sav111.u7",     0x080000, 0x95eedf0e, 1 | BRF_PRG | BRF_ESS }, //  1
	{ "sav111.u5",     0x080000, 0x5fdd4aa8, 1 | BRF_PRG | BRF_ESS }, //  2
	{ "sav111.u8",     0x080000, 0x003cbf49, 1 | BRF_PRG | BRF_ESS }, //  3
	{ "sav111.u10",    0x080000, 0xd5536107, 1 | BRF_PRG | BRF_ESS }, //  4

	{ "t0600.rom",     0x800000, 0x4acc1ad6, 2 | BRF_GRA },		  //  5 Tile data
	
	{ "a0600.rom",     0x800000, 0xd8167834, 3 | BRF_GRA },		  //  6 Sprite Color Data
	{ "a0601.rom",     0x800000, 0xff7a4373, 3 | BRF_GRA },		  //  7
	{ "a0602.rom",     0x800000, 0xe7a32959, 3 | BRF_GRA },		  //  8
	{ "a0603.rom",     0x400000, 0xec31abda, 3 | BRF_GRA },		  //  9
	
	{ "b0600.rom",     0x800000, 0x7d3cd059, 4 | BRF_GRA },		  // 10 Sprite Masks & Color Indexes
	{ "b0601.rom",     0x400000, 0xa0bb1c2f, 4 | BRF_GRA },		  // 11
	
	{ "m0600.rom",     0x400000, 0x3ada4fd6, 5 | BRF_SND },		  // 12 Samples	
	
	{ "kov_igs027a.bin", 0x004000, 0x00000000, 0 | BRF_PRG | BRF_NODUMP },
};

STDROMPICKEXT(kovj, kovj, pgm)
STD_ROM_FN(kovj)

struct BurnDriver BurnDrvKovj = {
	"kovj", "kov", "pgm", "1999",
	"Knights of Valour - Sangoku Senki (V100, Japan)\0", NULL, "IGS (Alta Co., LTD License)", "PolyGameMaster",
	L"Knights of Valour\0\u4E09\u56FD\u6226\u7D00\0\u4E09\u56FD\u6218\u7EAA (V100, Japan)\0", NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_CLONE, 4, HARDWARE_IGS_PGM, GBF_SCRFIGHT, 0,
	NULL, kovjRomInfo, kovjRomName, pgmInputInfo, kovjDIPInfo,
	kovInit, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// Knights of Valour Plus / Sangoku Senki Plus (V119)

static struct BurnRomInfo kovplusRomDesc[] = {
	{ "p0600.119",     0x400000, 0xe4b0875d, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code

	{ "t0600.rom",     0x800000, 0x4acc1ad6, 2 | BRF_GRA },		  //  1 Tile data
	
	{ "a0600.rom",     0x800000, 0xd8167834, 3 | BRF_GRA },		  //  2 Sprite Color Data
	{ "a0601.rom",     0x800000, 0xff7a4373, 3 | BRF_GRA },		  //  3
	{ "a0602.rom",     0x800000, 0xe7a32959, 3 | BRF_GRA },		  //  4
	{ "a0603.rom",     0x400000, 0xec31abda, 3 | BRF_GRA },		  //  5
	
	{ "b0600.rom",     0x800000, 0x7d3cd059, 4 | BRF_GRA },		  //  6 Sprite Masks & Color Indexes
	{ "b0601.rom",     0x400000, 0xa0bb1c2f, 4 | BRF_GRA },		  //  7
	
	{ "m0600.rom",     0x400000, 0x3ada4fd6, 5 | BRF_SND },		  //  8 Samples	
	
	{ "kov_igs027a.bin", 0x004000, 0x00000000, 0 | BRF_PRG | BRF_NODUMP },
};

STDROMPICKEXT(kovplus, kovplus, pgm)
STD_ROM_FN(kovplus)

struct BurnDriver BurnDrvKovplus = {
	"kovplus", "kov", "pgm", "1999",
	"Knights of Valour Plus - Sangoku Senki Plus (V119)\0", NULL, "IGS", "PolyGameMaster",
	L"Knights of Valour Plus\0\u4E09\u56FD\u6226\u7D00 Plus\0\u4E09\u56FD\u6218\u7EAA Plus (V119)\0", NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_CLONE, 4, HARDWARE_IGS_PGM, GBF_SCRFIGHT, 0,
	NULL, kovplusRomInfo, kovplusRomName, pgmInputInfo, sangoDIPInfo,
	kovInit, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// Knights of Valour Plus / Sangoku Senki Plus (V119 alt)

static struct BurnRomInfo kovplusaRomDesc[] = {
	{ "v119.u3",       0x080000, 0x6750388f, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code
	{ "v119.u5",       0x080000, 0xd4101ffd, 1 | BRF_PRG | BRF_ESS }, //  1
	{ "v119.u4",       0x080000, 0x8200ece6, 1 | BRF_PRG | BRF_ESS }, //  2
	{ "v119.u6",       0x080000, 0x71e28f27, 1 | BRF_PRG | BRF_ESS }, //  3
	{ "v119.u2",	   0x080000, 0x29588ef2, 1 | BRF_PRG | BRF_ESS }, //  4

	{ "t0600.rom",     0x800000, 0x4acc1ad6, 2 | BRF_GRA },		  //  5 Tile data
	
	{ "a0600.rom",     0x800000, 0xd8167834, 3 | BRF_GRA },		  //  6 Sprite Color Data
	{ "a0601.rom",     0x800000, 0xff7a4373, 3 | BRF_GRA },		  //  7
	{ "a0602.rom",     0x800000, 0xe7a32959, 3 | BRF_GRA },		  //  8
	{ "a0603.rom",     0x400000, 0xec31abda, 3 | BRF_GRA },		  //  9
	
	{ "b0600.rom",     0x800000, 0x7d3cd059, 4 | BRF_GRA },		  // 10 Sprite Masks & Color Indexes
	{ "b0601.rom",     0x400000, 0xa0bb1c2f, 4 | BRF_GRA },		  // 11
	
	{ "m0600.rom",     0x400000, 0x3ada4fd6, 5 | BRF_SND },		  // 12 Samples	
	
	{ "kov_igs027a.bin", 0x004000, 0x00000000, 0 | BRF_PRG | BRF_NODUMP },
};

STDROMPICKEXT(kovplusa, kovplusa, pgm)
STD_ROM_FN(kovplusa)

struct BurnDriver BurnDrvKovplusa = {
	"kovplusa", "kov", "pgm", "1999",
	"Knights of Valour Plus - Sangoku Senki Plus (V119 alt)\0", NULL, "IGS", "PolyGameMaster",
	L"Knights of Valour Plus\0\u4E09\u56FD\u6226\u7D00 Plus\0\u4E09\u56FD\u6218\u7EAA Plus (V119 alt)\0", NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_CLONE, 4, HARDWARE_IGS_PGM, GBF_SCRFIGHT, 0,
	NULL, kovplusaRomInfo, kovplusaRomName, pgmInputInfo, sangoDIPInfo,
	kovInit, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// Knights of Valour Superheroes / Sangoku Senki Superheroes (V104)

static struct BurnRomInfo kovshRomDesc[] = {
	{ "p0600.322",	   0x400000, 0x7c78e5f3, 1 | BRF_ESS | BRF_PRG }, //  0 68K Code

	{ "t0600.rom",     0x800000, 0x4acc1ad6, 2 | BRF_GRA },		  //  1 Tile data

	{ "a0600.rom",	   0x800000, 0xd8167834, 3 | BRF_GRA },		  //  2 Sprite Color Data
	{ "a0601.rom",	   0x800000, 0xff7a4373, 3 | BRF_GRA },		  //  3
	{ "a0602.rom",	   0x800000, 0xe7a32959, 3 | BRF_GRA },		  //  4
	{ "a0603.rom",	   0x400000, 0xec31abda, 3 | BRF_GRA },		  //  5
	{ "a0604.rom",	   0x400000, 0x26b59fd3, 3 | BRF_GRA },		  //  6

	{ "b0600.rom",	   0x800000, 0x7d3cd059, 4 | BRF_GRA },		  //  7 Sprite Masks & Color Indexes
	{ "b0601.rom",	   0x400000, 0xa0bb1c2f, 4 | BRF_GRA },		  //  8
	{ "b0602.rom",	   0x400000, 0xc3e0b454, 4 | BRF_GRA },		  //  9

	{ "m0600.rom",	   0x400000, 0x3ada4fd6, 5 | BRF_SND },		  // 10 Samples

	{ "kovsh_v100_china.asic", 0x04000, 0x0f09a5c1, 7 | BRF_ESS | BRF_PRG }, // 11 Internal ARM7 Rom
};

STDROMPICKEXT(kovsh, kovsh, pgm)
STD_ROM_FN(kovsh)

int kovshInit()
{
	pPgmInitCallback = pgm_decrypt_kovsh;

	Arm7SetIdleLoopAddress(0x00000260);

	int nRet = pgmInit();

	if (nRet == 0) {
		install_protection_kovsh();
	}

	return nRet;
}

struct BurnDriver BurnDrvKovsh = {
	"kovsh", "kov", "pgm", "1999",
	"Knights of Valour Superheroes\0Sangoku Senki Superheroes (V104)\0", NULL, "IGS", "PolyGameMaster",
	NULL, NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_CLONE, 4, HARDWARE_IGS_PGM | HARDWARE_IGS_USE_ARM_CPU, GBF_SCRFIGHT, 0,
	NULL, kovshRomInfo, kovshRomName, pgmInputInfo, sangoDIPInfo,
	kovshInit, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// Puzzle Star (V100MG)

static struct BurnRomInfo puzlstarRomDesc[] = {
	{ "v100mg.u2",	   0x080000, 0x4c79d979, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code
	{ "v100mg.u1",	   0x080000, 0x5788b77d, 1 | BRF_PRG | BRF_ESS }, //  1

	{ "t0800.u5",	   0x200000, 0xf9d84e59, 2 | BRF_GRA }, 	  //  2 Tile data

	{ "a0800.u1",	   0x400000, 0xe1e6ec40, 3 | BRF_GRA },		  //  3 Sprite Color Data

	{ "b0800.u3",	   0x200000, 0x52e7bef5, 4 | BRF_GRA }, 	  //  4 Sprite Masks & Color Indexes

	{ "m0800.u2",	   0x400000, 0xe1a46541, 5 | BRF_SND },		  //  5 Samples

	{ "puzlstar_igs027a.bin", 0x004000,   0, 0 | BRF_PRG | BRF_NODUMP }, //  6 Internal ARM7 Rom
};

STDROMPICKEXT(puzlstar, puzlstar, pgm)
STD_ROM_FN(puzlstar)

int puzlstarInit()
{
	pPgmInitCallback = pgm_decrypt_puzlstar;
	pPgmResetCallback = reset_puzlstar;

	int nRet = pgmInit();

	if (nRet == 0) {
		install_protection_puzlstar();
	}

	return nRet;
}

struct BurnDriver BurnDrvPuzlstar = {
	"puzlstar", NULL, "pgm", "1999",
	"Puzzle Star (V100MG)\0", "Incomplete Protection Emulation", "IGS", "PolyGameMaster",
	L"Puzzle Star\0\u30D1\u30BA\u30EB\u30B9\u30BF\u30FC\0\u9B54\u5E7B\u661F\u5EA7 (V100MG)\0", NULL, NULL, NULL,
	BDF_GAME_WORKING, 4, HARDWARE_IGS_PGM, GBF_PUZZLE, 0,
	NULL, puzlstarRomInfo, puzlstarRomName, pgmInputInfo, sangoDIPInfo,
	puzlstarInit, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// Puzzli 2 Super (V200)

static struct BurnRomInfo puzzli2RomDesc[] = {
	{ "2sp_v200.u4",   0x080000, 0xfa5c86c1, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code
	{ "2sp_v200.u3",   0x080000, 0x2a5ba8a6, 1 | BRF_PRG | BRF_ESS }, //  1

	{ "t0900.u9",	   0x200000, 0x70615611, 2 | BRF_GRA },		  //  2 Tile data

	{ "a0900.u3",	   0x400000, 0x14911251, 3 | BRF_GRA },		  //  3 Sprite Color Data

	{ "b0900.u4",	   0x200000, 0x6f0638b6, 4 | BRF_GRA },		  //  4 Sprite Masks & Color Indexes

	{ "m0900.u2",	   0x400000, 0x9ea7af2e, 5 | BRF_SND },		  //  5 Samples

	{ "puzzli2_igs027a.bin", 0x004000, 0,    7 | BRF_PRG | BRF_NODUMP }, //  6 Internal ARM7 Rom
};

STDROMPICKEXT(puzzli2, puzzli2, pgm)
STD_ROM_FN(puzzli2)

void puzzli2_decrypt()
{
 	pgm_decrypt_puzzli2();

	// Protection-related patches
	*((unsigned short*)(PGM68KROM + 0x0268c0)) = 0x4e71;
	*((unsigned short*)(PGM68KROM + 0x0268c2)) = 0x4e71;
	*((unsigned short*)(PGM68KROM + 0x0268c4)) = 0x4e71;
	*((unsigned short*)(PGM68KROM + 0x03877a)) = 0x4e71;
	*((unsigned short*)(PGM68KROM + 0x04cee0)) = 0x4e71;
	*((unsigned short*)(PGM68KROM + 0x0548ec)) = 0x4e71;
	*((unsigned short*)(PGM68KROM + 0x0548fc)) = 0x4e71;
	*((unsigned short*)(PGM68KROM + 0x054948)) = 0x4e71;
	*((unsigned short*)(PGM68KROM + 0x05496A)) = 0x4e71;
	*((unsigned short*)(PGM68KROM + 0x0549FA)) = 0x4e71;
	*((unsigned short*)(PGM68KROM + 0x054A0A)) = 0x4e71;
}

int puzzli2Init()
{
	pPgmInitCallback = puzzli2_decrypt;

	return pgmInit();
}

struct BurnDriverD BurnDrvPuzzli2 = {
	"puzzli2", NULL, "pgm", "2001",
	"Puzzli 2 Super (V200)\0", NULL, "IGS", "PolyGameMaster",
	NULL, NULL, NULL, NULL,
	0, 4, HARDWARE_IGS_PGM | HARDWARE_IGS_USE_ARM_CPU, GBF_PUZZLE, 0,
	NULL, puzzli2RomInfo, puzzli2RomName, pgmInputInfo, puzzli2DIPInfo,
	puzzli2Init, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// Martial Masters / Xing Yi (V104, USA)

static struct BurnRomInfo martmastRomDesc[] = {
	{ "v104_32m.u9",   0x400000, 0xcfd9dff4, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code

	{ "t1000.u3",	   0x800000, 0xbbf879b5, 2 | BRF_GRA },	          //  1 Tile data

	{ "a1000.u3",      0x800000, 0x43577ac8, 3 | BRF_GRA },		  //  2 Sprite Color Data
	{ "a1001.u4",      0x800000, 0xfe7a476f, 3 | BRF_GRA },		  //  3
	{ "a1002.u6",      0x800000, 0x62e33d38, 3 | BRF_GRA },		  //  4
	{ "a1003.u8",      0x800000, 0xb2c4945a, 3 | BRF_GRA },		  //  5
	{ "a1004.u10",     0x400000, 0x9fd3f5fd, 3 | BRF_GRA },		  //  6

	{ "b1000.u9",	   0x800000, 0xc5961f6f, 4 | BRF_GRA },	          //  7 Sprite Masks & Color Indexes
	{ "b1001.u11",	   0x800000, 0x0b7e1c06, 4 | BRF_GRA },		  //  8

	{ "m1000.u5",      0x800000, 0xed407ae8, 5 | BRF_SND },	          //  9 Samples
	{ "m1001.u7",      0x400000, 0x662d2d48, 5 | BRF_SND },		  // 10 

	{ "martial_masters_v102_usa.asic", 0x4000,  0xa6c0828c, 7 | BRF_PRG | BRF_ESS }, // 11 Internal ARM7 Rom

	{ "v102_16m.u10",  0x200000, 0x18b745e6, 8 | BRF_PRG | BRF_ESS }, // 12 External ARM7 Rom
};

STDROMPICKEXT(martmast, martmast, pgm)
STD_ROM_FN(martmast)

int martmastInit()
{
	pPgmInitCallback = pgm_decrypt_martmast;

	Arm7SetIdleLoopAddress(0x800039e);

	int nRet = pgmInit();

	if (nRet == 0) {
		install_protection_asic27A();
	}

	return nRet;
}

struct BurnDriver BurnDrvMartmast = {
	"martmast", NULL, "pgm", "2001",
	"Martial Masters (V104, USA)\0", NULL, "IGS", "PolyGameMaster",
	L"Martial Masters\0\u5f62\u610f\u62f3 (V104, USA)\0", NULL, NULL, NULL,
	BDF_GAME_WORKING, 4, HARDWARE_IGS_PGM | HARDWARE_IGS_USE_ARM_CPU, GBF_VSFIGHT, 0,
	NULL, martmastRomInfo, martmastRomName, pgmInputInfo, martmastDIPInfo,
	martmastInit, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// Martial Masters / Xing Yi (V101, China)

static struct BurnRomInfo martmascRomDesc[] = {
	{ "v104_32m.u9",   0x400000, 0xcfd9dff4, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code

	{ "t1000.u3",	   0x800000, 0xbbf879b5, 2 | BRF_GRA },		  //  1 Tile data

	{ "a1000.u3",      0x800000, 0x43577ac8, 3 | BRF_GRA },		  //  2 Sprite Color Data
	{ "a1001.u4",      0x800000, 0xfe7a476f, 3 | BRF_GRA },		  //  3
	{ "a1002.u6",      0x800000, 0x62e33d38, 3 | BRF_GRA },		  //  4
	{ "a1003.u8",      0x800000, 0xb2c4945a, 3 | BRF_GRA },		  //  5
	{ "a1004.u10",     0x400000, 0x9fd3f5fd, 3 | BRF_GRA },		  //  6

	{ "b1000.u9",	   0x800000, 0xc5961f6f, 4 | BRF_GRA },		  //  7 Sprite Masks & Color Indexes
	{ "b1001.u11",	   0x800000, 0x0b7e1c06, 4 | BRF_GRA },		  //  8

	{ "m1000.u5",      0x800000, 0xed407ae8, 5 | BRF_SND },		  //  9 Samples
	{ "m1001.u7",      0x400000, 0x662d2d48, 5 | BRF_SND },		  // 10

	{ "martial_masters_v101_cn.asic", 0x4000, 0xb3e25b7d, 7 | BRF_PRG | BRF_ESS }, // 11 Internal ARM7 Rom

	{ "v102_16m.u10",  0x200000, 0x18b745e6, 8 | BRF_PRG | BRF_ESS },  // 12 External ARM7 Rom
};

STDROMPICKEXT(martmasc, martmasc, pgm)
STD_ROM_FN(martmasc)

struct BurnDriver BurnDrvMartmasc = {
	"martmastc", "martmast", "pgm", "2001",
	"Martial Masters (V101, China)\0", NULL, "IGS", "PolyGameMaster",
	L"Martial Masters\0\u5f62\u610f\u62f3 (V101, China)\0", NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_CLONE, 4, HARDWARE_IGS_PGM | HARDWARE_IGS_USE_ARM_CPU, GBF_VSFIGHT, 0,
	NULL, martmascRomInfo, martmascRomName, pgmInputInfo, martmascDIPInfo,
	martmastInit, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// Knights of Valour 2 (V100)

static struct BurnRomInfo kov2RomDesc[] = {
	{ "igs_u18.rom",   0x400000, 0x86205879, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code

	{ "t1200.rom",	   0x800000, 0xd7e26609, 2 | BRF_GRA },		  //  1 Tile data

	{ "a1200.rom",	   0x800000, 0xceeb81d8, 3 | BRF_GRA },		  //  2 Sprite Color Data
	{ "a1201.rom",	   0x800000, 0x82f0a878, 3 | BRF_GRA },		  //  3
	{ "a1202.rom",	   0x800000, 0x4bb92fae, 3 | BRF_GRA },		  //  4
	{ "a1203.rom",	   0x800000, 0xe73cb627, 3 | BRF_GRA },		  //  5
	{ "a1204.rom",	   0x800000, 0x27527099, 3 | BRF_GRA },		  //  6

	{ "b1200.rom",	   0x800000, 0xbed7d994, 4 | BRF_GRA },		  //  7 Sprite Masks & Color Indexes
	{ "b1201.rom",	   0x800000, 0xf251eb57, 4 | BRF_GRA },		  //  8

	{ "m1200.rom",	   0x800000, 0xb0d88720, 5 | BRF_SND },		  //  9 Samples

	{ "kov2_v100_hongkong.asic", 0x4000, 0xe0d7679f, 7 | BRF_PRG | BRF_ESS }, // 10 Internal ARM7 Rom

	{ "igs_u19.rom",  0x200000, 0xedd59922, 8 | BRF_PRG | BRF_ESS },  // 11 External ARM7 Rom
};

STDROMPICKEXT(kov2, kov2, pgm)
STD_ROM_FN(kov2)

int kov2Init()
{
	pPgmInitCallback = pgm_decrypt_kov2;

	Arm7SetIdleLoopAddress(0x80000ae);

	int nRet = pgmInit();

	if (nRet == 0) {
		install_protection_asic27A();
	}

	return nRet;
}

struct BurnDriver BurnDrvKov2 = {
	"kov2", NULL, "pgm", "2000",
	"Knights of Valour 2 (V100)\0", NULL, "IGS", "PolyGameMaster",
	L"Knights of Valour 2\0\u4e09\u56fd\u6218\u7eaa 2 (V100)\0", NULL, NULL, NULL,
	BDF_GAME_WORKING, 4, HARDWARE_IGS_PGM | HARDWARE_IGS_USE_ARM_CPU, GBF_SCRFIGHT, 0,
	NULL, kov2RomInfo, kov2RomName, pgmInputInfo, kov2DIPInfo,
	kov2Init, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// Knights of Valour 2 (V106)

static struct BurnRomInfo kov2106RomDesc[] = {
	{ "u18.106",	   0x400000, 0x40051ad9, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code

	{ "t1200.rom",	   0x800000, 0xd7e26609, 2 | BRF_GRA },		  //  1 Tile data

	{ "a1200.rom",	   0x800000, 0xceeb81d8, 3 | BRF_GRA },		  //  2 Sprite Color Data
	{ "a1201.rom",	   0x800000, 0x82f0a878, 3 | BRF_GRA },		  //  3
	{ "a1202.rom",	   0x800000, 0x4bb92fae, 3 | BRF_GRA },		  //  4
	{ "a1203.rom",	   0x800000, 0xe73cb627, 3 | BRF_GRA },		  //  5
	{ "a1204.rom",	   0x800000, 0x27527099, 3 | BRF_GRA },		  //  6

	{ "b1200.rom",	   0x800000, 0xbed7d994, 4 | BRF_GRA },		  //  7 Sprite Masks & Color Indexes
	{ "b1201.rom",	   0x800000, 0xf251eb57, 4 | BRF_GRA },		  //  8

	{ "m1200.rom",	   0x800000, 0xb0d88720, 5 | BRF_SND },		  //  9 Samples

	{ "kov2_v100_hongkong.asic", 0x4000, 0xe0d7679f, 7 | BRF_PRG | BRF_ESS }, // 10 Internal ARM7 Rom

	{ "u19.102",	   0x200000, 0x462e2980, 8 | BRF_PRG | BRF_ESS }, // 11 External ARM7 Rom
};

STDROMPICKEXT(kov2106, kov2106, pgm)
STD_ROM_FN(kov2106)

struct BurnDriver BurnDrvKov2106 = {
	"kov2106", "kov2", "pgm", "2000",
	"Knights of Valour 2 (V106)\0", "Protection Emulation Issues", "IGS", "PolyGameMaster",
	L"Knights of Valour 2\0\u4e09\u56fd\u6218\u7eaa 2 (V106)\0", NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_CLONE, 4, HARDWARE_IGS_PGM | HARDWARE_IGS_USE_ARM_CPU, GBF_SCRFIGHT, 0,
	NULL, kov2106RomInfo, kov2106RomName, pgmInputInfo, pgmDIPInfo,
	kov2Init, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// Knights of Valour 2 Plus - Nine Dragons (VM204XX)

static struct BurnRomInfo kov2pRomDesc[] = {
	{ "v204-32m.rom",  0x400000, 0x583e0650, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code

	{ "t1200.rom",	   0x800000, 0xd7e26609, 2 | BRF_GRA },		  //  1 Tile data

	{ "a1200.rom",	   0x800000, 0xceeb81d8, 3 | BRF_GRA },		  //  2 Sprite Color Data
	{ "a1201.rom_p",   0x800000, 0x21063ca7, 3 | BRF_GRA },		  //  3
	{ "a1202.rom",	   0x800000, 0x4bb92fae, 3 | BRF_GRA },		  //  4
	{ "a1203.rom",	   0x800000, 0xe73cb627, 3 | BRF_GRA },		  //  5
	{ "a1204.rom_p",   0x200000, 0x14b4b5bb, 3 | BRF_GRA },		  //  6

	{ "b1200.rom",	   0x800000, 0xbed7d994, 4 | BRF_GRA },		  //  7 Sprite Masks & Color Indexes
	{ "b1201.rom",	   0x800000, 0xf251eb57, 4 | BRF_GRA },		  //  8

	{ "m1200.rom",	   0x800000, 0xb0d88720, 5 | BRF_SND },		  //  9 Samples

	{ "kov2p_igs027a.bin",	   0x004000, 0xe0d7679f, 7 | BRF_PRG | BRF_ESS | BRF_NODUMP },  // 10 Internal ARM7 Rom

	{ "v200-16.rom",   0x200000, 0x16a0c11f, 8 | BRF_PRG | BRF_ESS }, // 11 External ARM7 Rom
};

STDROMPICKEXT(kov2p, kov2p, pgm)
STD_ROM_FN(kov2p)

static void kov2pHack()
{
	unsigned char *src = PGMUSER0;

	src[0x0000de] = 0xc0;
	src[0x0000df] = 0x46;
	src[0x004ed8] = 0xa8;
	src[0x004edc] = 0x9c;
	src[0x004ee0] = 0x5c;
	src[0x004ee4] = 0x94;
	src[0x004ee8] = 0xe8;
	src[0x004eec] = 0x6c;
	src[0x004ef0] = 0xd4;
	src[0x004ef4] = 0x50;
	src[0x004ef8] = 0x80;
	src[0x004efc] = 0x9c;
	src[0x004f00] = 0x28;
	src[0x004f04] = 0x30;
	src[0x004f08] = 0x34;
	src[0x004f0c] = 0x1c;
	src[0x1ffffc] = 0x33;
	src[0x1ffffd] = 0x99;
}

static int kov2pInit()
{
	pPgmInitCallback = pgm_decrypt_kov2p;

	Arm7SetIdleLoopAddress(0x80000a6);

	int nRet = pgmInit();

	if (nRet == 0) {
		kov2pHack();

		install_protection_asic27A();
	}

	return nRet;
}

struct BurnDriver BurnDrvKov2p = {
	"kov2p", "kov2", "pgm", "2000",
	"Knights of Valour 2 Plus - Nine Dragons (VM204XX)\0", NULL, "IGS", "PolyGameMaster",
	L"Knights of Valour 2 Plus\0\u4e09\u56fd\u6218\u7eaa 2 - \u7fa4\u96c4\u4e89\u9738 (VM204XX)\0", NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_CLONE, 4, HARDWARE_IGS_PGM | HARDWARE_IGS_USE_ARM_CPU, GBF_SCRFIGHT, 0,
	NULL, kov2pRomInfo, kov2pRomName, pgmInputInfo, kov2DIPInfo,
	kov2pInit, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// Knights of Valour 2 Plus - Nine Dragons (VM205XX, China)

static struct BurnRomInfo kov2p205RomDesc[] = {
	{ "u8-27322.rom",  0x400000, 0x3a2cc0de, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code

	{ "t1200.rom",	   0x800000, 0xd7e26609, 2 | BRF_GRA },		  //  1 Tile data

	{ "a1200.rom",	   0x800000, 0xceeb81d8, 3 | BRF_GRA },		  //  2 Sprite Color Data
	{ "a1201.rom_p",   0x800000, 0x21063ca7, 3 | BRF_GRA },		  //  3
	{ "a1202.rom",	   0x800000, 0x4bb92fae, 3 | BRF_GRA },		  //  4
	{ "a1203.rom",	   0x800000, 0xe73cb627, 3 | BRF_GRA },		  //  5
	{ "a1204.rom_p",   0x200000, 0x14b4b5bb, 3 | BRF_GRA },		  //  6

	{ "b1200.rom",	   0x800000, 0xbed7d994, 4 | BRF_GRA },		  //  7 Sprite Masks & Color Indexes
	{ "b1201.rom",	   0x800000, 0xf251eb57, 4 | BRF_GRA },		  //  8

	{ "m1200.rom",	   0x800000, 0xb0d88720, 5 | BRF_SND },		  //  9 Samples

	{ "kov2p_igs027a.bin",	   0x004000, 0xe0d7679f, 7 | BRF_PRG | BRF_ESS | BRF_NODUMP },  // 10 Internal ARM7 Rom

	{ "v200-16.rom",   0x200000, 0x16a0c11f, 8 | BRF_PRG | BRF_ESS }, // 11 External ARM7 Rom
};

STDROMPICKEXT(kov2p205, kov2p205, pgm)
STD_ROM_FN(kov2p205)

struct BurnDriver BurnDrvKov2p205 = {
	"kov2p205", "kov2", "pgm", "2002",
	"Knights of Valour 2 Plus - Nine Dragons (VM205XX, China)\0", NULL, "IGS", "PolyGameMaster",
	L"Knights of Valour 2 Plus\0\u4e09\u56fd\u6218\u7eaa 2 - \u7fa4\u96c4\u4e89\u9738 (VM205XX, China)\0", NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_CLONE, 4, HARDWARE_IGS_PGM | HARDWARE_IGS_USE_ARM_CPU, GBF_SCRFIGHT, 0,
	NULL, kov2p205RomInfo, kov2p205RomName, pgmInputInfo, kov2DIPInfo,
	kov2pInit, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// Bee Storm - DoDonPachi II (V102)

static struct BurnRomInfo ddp2RomDesc[] = {
	{ "ddp2_v102.u8",  0x200000, 0x5a9ea040, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code

	{ "t1300.u21",	   0x800000, 0xe748f0cb, 2 | BRF_GRA },		  //  1 Tile data

	{ "a1300.u1",	   0x800000, 0xfc87a405, 3 | BRF_GRA },		  //  2 Sprite Color Data
	{ "a1301.u2",	   0x800000, 0x0c8520da, 3 | BRF_GRA },		  //  3

	{ "b1300.u7",	   0x800000, 0xef646604, 4 | BRF_GRA },		  //  4 Sprite Masks & Color Indexes

	{ "m1300.u5",	   0x400000, 0x82d4015d, 5 | BRF_SND },		  //  5 Samples

	{ "ddp2_igs027a.bin", 0x004000, 0,	 7 | BRF_PRG | BRF_NODUMP },//  6 Internal ARM7 Rom

	{ "v100.u23", 	   0x020000, 0x06c3dd29, 8 | BRF_PRG | BRF_ESS }, //  7 External ARM7 Rom
};

STDROMPICKEXT(ddp2, ddp2, pgm)
STD_ROM_FN(ddp2)

int ddp2Init()
{
	pPgmInitCallback = pgm_decrypt_ddp2;
	
	return pgmInit();
}

struct BurnDriverD BurnDrvDdp2 = {
	"ddp2", NULL, "pgm", "2001",
	"Bee Storm - DoDonPachi II (V102)\0", "Incomplete Dump", "IGS", "PolyGameMaster",
	L"Bee Storm - DoDonPatchi II\0\u6012\u9996\u9886\u8702\uff0d\u8702\u66b4 (V102)\0", NULL, NULL, NULL,
	BDF_ORIENTATION_VERTICAL , 4, HARDWARE_IGS_PGM | HARDWARE_IGS_USE_ARM_CPU, GBF_VERSHOOT, 0,
	NULL, ddp2RomInfo, ddp2RomName, pgmInputInfo, pgmDIPInfo,
	ddp2Init, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	224,448,3,4
};


// Bee Storm - DoDonPachi II (V100)

static struct BurnRomInfo ddp2aRomDesc[] = {
	{ "v100.u8",	   0x200000, 0x0c8aa8ea, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code

	{ "t1300.u21",	   0x800000, 0xe748f0cb, 2 | BRF_GRA },		  //  1 Tile data

	{ "a1300.u1",	   0x800000, 0xfc87a405, 3 | BRF_GRA },		  //  2 Sprite Color Data
	{ "a1301.u2",	   0x800000, 0x0c8520da, 3 | BRF_GRA },		  //  3

	{ "b1300.u7",	   0x800000, 0xef646604, 4 | BRF_GRA },		  //  4 Sprite Masks & Color Indexes

	{ "m1300.u5",	   0x400000, 0x82d4015d, 5 | BRF_SND },		  //  5 Samples

	{ "ddp2_igs027a.bin", 0x004000, 0,	 7 | BRF_PRG | BRF_NODUMP },//  6 Internal ARM7 Rom

	{ "v100.u23", 	   0x020000, 0x06c3dd29, 8 | BRF_PRG | BRF_ESS }, //  7 External ARM7 Rom
};

STDROMPICKEXT(ddp2a, ddp2a, pgm)
STD_ROM_FN(ddp2a)

struct BurnDriverD BurnDrvDdp2a = {
	"ddp2a", "ddp2", "pgm", "2001",
	"Bee Storm - DoDonPachi II (V100)\0", "Incomplete Dump", "IGS", "PolyGameMaster",
	L"Bee Storm - DoDonPatchi II\0\u6012\u9996\u9886\u8702\uff0d\u8702\u66b4 (V100)\0", NULL, NULL, NULL,
	BDF_ORIENTATION_VERTICAL | BDF_CLONE, 4, HARDWARE_IGS_PGM | HARDWARE_IGS_USE_ARM_CPU, GBF_VERSHOOT, 0,
	NULL, ddp2aRomInfo, ddp2aRomName, pgmInputInfo, pgmDIPInfo,
	ddp2Init, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	224,448,3,4
};


// Demon Front (V102)

static struct BurnRomInfo dmnfrntRomDesc[] = {
	{ "v102_16m.u5",   0x200000, 0x3d4d481a, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code

	{ "t04501.u29",	   0x800000, 0x900eaaac, 2 | BRF_GRA },		  //  1 Tile data

	{ "a04501.u3",     0x800000, 0x9741bea6, 3 | BRF_GRA },		  //  2 Sprite Color Data
	{ "a04502.u4",     0x800000, 0xe104f405, 3 | BRF_GRA },		  //  3
	{ "a04503.u6",     0x800000, 0xbfd5cfe3, 3 | BRF_GRA },		  //  4

	{ "b04501.u9",	   0x800000, 0x29320b7d, 4 | BRF_GRA },		  //  5 Sprite Masks & Color Indexes
	{ "b04502.u11",	   0x200000, 0x578c00e9, 4 | BRF_GRA },		  //  6

	{ "w04501.u5",     0x800000, 0x3ab58137, 5 | BRF_SND },		  //  7 Samples

	{ "dmnfrnt_igs027a.bin", 0x004000, 0,    7 | BRF_PRG | BRF_NODUMP }, //  8 Internal ARM7 Rom

	{ "v101_32m.u26",  0x400000, 0x93965281, 8 | BRF_PRG | BRF_ESS }, //  9 External ARM7 Rom
};

STDROMPICKEXT(dmnfrnt, dmnfrnt, pgm)
STD_ROM_FN(dmnfrnt)

static int dmnfrntInit()
{
	pPgmInitCallback = pgm_decrypt_dfront;

	return pgmInit();
}

struct BurnDriverD BurnDrvDmnfrnt = {
	"dmnfrnt", NULL, "pgm", "2002",
	"Demon Front (V102)\0", "Incomplete Dump", "IGS", "PolyGameMaster",
	L"Demon Front\0\u9B54\u57DF\u6218\u7EBF\0\u9B54\u57DF\u6230\u7DDA (V102)\0", NULL, NULL, NULL,
	0, 4, HARDWARE_IGS_PGM | HARDWARE_IGS_USE_ARM_CPU, GBF_PLATFORM, 0,
	NULL, dmnfrntRomInfo, dmnfrntRomName, pgmInputInfo, pgmDIPInfo,
	dmnfrntInit, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// Demon Front (V105, China)

static struct BurnRomInfo dmnfrntaRomDesc[] = {
	{ "v105_16m.u5",   0x200000, 0xbda083bd, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code

	{ "t04501.u29",	   0x800000, 0x900eaaac, 2 | BRF_GRA },		  //  1 Tile data

	{ "a04501.u3",     0x800000, 0x9741bea6, 3 | BRF_GRA },		  //  2 Sprite Color Data
	{ "a04502.u4",     0x800000, 0xe104f405, 3 | BRF_GRA },		  //  3
	{ "a04503.u6",     0x800000, 0xbfd5cfe3, 3 | BRF_GRA },		  //  4

	{ "b04501.u9",	   0x800000, 0x29320b7d, 4 | BRF_GRA },		  //  5 Sprite Masks & Color Indexes
	{ "b04502.u11",	   0x200000, 0x578c00e9, 4 | BRF_GRA },		  //  6

	{ "w04501.u5",     0x800000, 0x3ab58137, 5 | BRF_SND },		  //  7 Samples

	{ "dmnfrnt_igs027a.bin", 0x004000, 0,    7 | BRF_PRG | BRF_NODUMP }, //  8 Internal ARM7 Rom

	{ "v105_32m.u26",  0x400000, 0xd200ee63, 8 | BRF_PRG | BRF_ESS }, //  9 External ARM7 Rom
};

STDROMPICKEXT(dmnfrnta, dmnfrnta, pgm)
STD_ROM_FN(dmnfrnta)

struct BurnDriverD BurnDrvDmnfrnta = {
	"dmnfrnta", "dmnfrnt", "pgm", "2002",
	"Demon Front (V105, China)\0", "Incomplete Dump", "IGS", "PolyGameMaster",
	L"Demon Front\0\u9B54\u57DF\u6218\u7EBF\0\u9B54\u57DF\u6230\u7DDA (V105, China)\0", NULL, NULL, NULL,
	BDF_CLONE, 4, HARDWARE_IGS_PGM | HARDWARE_IGS_USE_ARM_CPU, GBF_PLATFORM, 0,
	NULL, dmnfrntaRomInfo, dmnfrntaRomName, pgmInputInfo, pgmDIPInfo,
	dmnfrntInit, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// The Gladiator / Shen Jian (V100)

static struct BurnRomInfo thegladRomDesc[] = {
	{ "u6.rom",	   0x080000, 0x14c85212, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code

	{ "t04601.u33",	   0x800000, 0xe5dab371, 2 | BRF_GRA },		  //  1 Tile data

	{ "a04601.u2",     0x800000, 0xd9b2e004, 3 | BRF_GRA },		  //  2 Sprite Color Data
	{ "a04602.u4",     0x800000, 0x14f22308, 3 | BRF_GRA },		  //  3
	{ "a04603.u6",     0x800000, 0x8f621e17, 3 | BRF_GRA },		  //  4

	{ "b04601.u11",	   0x800000, 0xee72bccf, 4 | BRF_GRA },		  //  5 Sprite Masks & Color Indexes
	{ "b04602.u12",	   0x400000, 0x7dba9c38, 4 | BRF_GRA },		  //  6

	{ "w04601.u1",     0x800000, 0x5f15ddb3, 5 | BRF_SND },		  //  7 Samples

	{ "theglad_igs027a.bin", 0x004000, 0x00000000, 7 | BRF_PRG | BRF_NODUMP },  //  8 Internal ARM7 Rom

	{ "u2.rom",  	   0x200000, 0xc7bcf2ae, 8 | BRF_PRG | BRF_ESS }, //  9 External ARM7 Rom
};

STDROMPICKEXT(theglad, theglad, pgm)
STD_ROM_FN(theglad)

static int thegladInit()
{
	pPgmInitCallback = pgm_decrypt_theglad;

	return pgmInit();
}

struct BurnDriverD BurnDrvTheglad = {
	"theglad", NULL, "pgm", "2003",
	"The Gladiator\0Shen Jian (V100)\0", "Incomplete Dump", "IGS", "PolyGameMaster",
	L"The Gladiator\0\u795E\u5251\u98CE\u4E91\0\u795E\u528D\u98A8\u96F2 (V100)\0", NULL, NULL, NULL,
	0, 4, HARDWARE_IGS_PGM | HARDWARE_IGS_USE_ARM_CPU, GBF_SCRFIGHT, 0,
	NULL, thegladRomInfo, thegladRomName, pgmInputInfo, pgmDIPInfo,
	thegladInit, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// The Gladiator / Shen Jian (V101, Taiwan)

static struct BurnRomInfo thegladaRomDesc[] = {
	{ "v101.u6",	   0x080000, 0xf799e866, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code

	{ "t04601.u33",	   0x800000, 0xe5dab371, 2 | BRF_GRA },		  //  1 Tile data

	{ "a04601.u2",     0x800000, 0xd9b2e004, 3 | BRF_GRA },		  //  2 Sprite Color Data
	{ "a04602.u4",     0x800000, 0x14f22308, 3 | BRF_GRA },		  //  3
	{ "a04603.u6",     0x800000, 0x8f621e17, 3 | BRF_GRA },		  //  4

	{ "b04601.u11",	   0x800000, 0xee72bccf, 4 | BRF_GRA },		  //  5 Sprite Masks & Color Indexes
	{ "b04602.u12",	   0x400000, 0x7dba9c38, 4 | BRF_GRA },		  //  6

	{ "w04601.u1",     0x800000, 0x5f15ddb3, 5 | BRF_SND },		  //  7 Samples

	{ "theglad_igs027a.bin", 0x004000, 0x00000000, 7 | BRF_PRG | BRF_NODUMP },  //  8 Internal ARM7 Rom

	{ "v107.u26",	   0x200000, 0xf7c61357, 8 | BRF_PRG | BRF_ESS }, //  9 External ARM7 Rom
};

STDROMPICKEXT(theglada, theglada, pgm)
STD_ROM_FN(theglada)

struct BurnDriverD BurnDrvTheglada = {
	"theglada", "theglad", "pgm", "2003",
	"The Gladiator\0Shen Jian (V101, Taiwan)\0", "Incomplete Dump", "IGS", "PolyGameMaster",
	L"The Gladiator\0\u795E\u5251\u98CE\u4E91\0\u795E\u528D\u98A8\u96F2 (V101, Taiwan)\0", NULL, NULL, NULL,
	BDF_CLONE, 4, HARDWARE_IGS_PGM | HARDWARE_IGS_USE_ARM_CPU, GBF_SCRFIGHT, 0,
	NULL, thegladaRomInfo, thegladaRomName, pgmInputInfo, pgmDIPInfo,
	thegladInit, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// Knights of Valour Super Heroes Plus / Sangoku Senki Super Heroes Plus (ver. 100)

static struct BurnRomInfo kovshpRomDesc[] = {
	{ "p0600h.rom",	   0x400000, 0xe251e8e4, 1 | BRF_ESS | BRF_PRG }, //  0 68K Code

	{ "t0600.rom",     0x800000, 0x4acc1ad6, 2 | BRF_GRA },		  //  1 Tile data

	{ "a0600.rom",	   0x800000, 0xd8167834, 3 | BRF_GRA },		  //  2 Sprite Color Data
	{ "a0601.rom",	   0x800000, 0xff7a4373, 3 | BRF_GRA }, 	  //  3 
	{ "a0602.rom",	   0x800000, 0xe7a32959, 3 | BRF_GRA }, 	  //  4
	{ "a0540.rom",	   0x800000, 0x4fd3413e, 3 | BRF_GRA }, 	  //  5

	{ "b0600.rom",	   0x800000, 0x7d3cd059, 4 | BRF_GRA },		  //  6 Sprite Masks & Color Indexes
	{ "b0540.rom",	   0x800000, 0x60999757, 4 | BRF_GRA },		  //  7

	{ "m0600.rom",	   0x400000, 0x3ada4fd6, 5 | BRF_SND },		  //  8 Samples

	{ "kovshp_igs027a.bin", 0x004000, 0x00000000, 0 | BRF_ESS | BRF_PRG | BRF_NODUMP }, //  9 Internal ARM7 Rom
};

STDROMPICKEXT(kovshp, kovshp, pgm)
STD_ROM_FN(kovshp)

int kovshpInit()
{
	pPgmInitCallback = pgm_decrypt_kovshp;

	int nRet = pgmInit();

	if (nRet == 0) {
		install_protection_asic28(); // gets it to the title screen...
	}

	return nRet;
}

struct BurnDriverD BurnDrvkovshp = {
	"kovshp", "kov", "pgm", "2004",
	"Knights of Valour Super Heroes Plus / Sangoku Senki Super Heroes Plus (ver. 100)\0", "Incomplete dump", "IGS", "PolyGameMaster",
	NULL, NULL, NULL, NULL,
	BDF_CLONE, 4, HARDWARE_IGS_PGM | HARDWARE_IGS_USE_ARM_CPU, GBF_SCRFIGHT, 0,
	NULL, kovshpRomInfo, kovshpRomName, pgmInputInfo, sangoDIPInfo,
	kovshpInit, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// Oriental Legend Special Plus / Xi You Shi E Zhuan Super Plus

static struct BurnRomInfo oldsplusRomDesc[] = {
	{ "p05301.rom",	   0x400000, 0x923f7246, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code

	{ "t05301.rom",	   0x800000, 0x8257bbb0, 2 | BRF_GRA },		  //  1 Tile data

	{ "a05301.rom",	   0x800000, 0x57946fd2, 3 | BRF_GRA },	 	  //  2 Sprite Color Data
	{ "a05302.rom",	   0x800000, 0x3459a0b8, 3 | BRF_GRA },		  //  3
	{ "a05303.rom",	   0x800000, 0x13475d85, 3 | BRF_GRA },		  //  4
	{ "a05304.rom",	   0x800000, 0xf03ef7a6, 3 | BRF_GRA },		  //  5

	{ "b05301.rom",	   0x800000, 0xfd98f503, 4 | BRF_GRA },		  //  6 Sprite Masks & Color Indexes
	{ "b05302.rom",	   0x800000, 0x9f6094a8, 4 | BRF_GRA },		  //  7

	{ "m05301.rom",	   0x400000, 0x86ec83bc, 5 | BRF_SND },		  //  8 Samples

	{ "oldsplus_igs027a.bin",	0x004000, 0,  0 | BRF_PRG | BRF_NODUMP }, //  9 Internal ARM7 Rom
};

STDROMPICKEXT(oldsplus, oldsplus, pgm)
STD_ROM_FN(oldsplus)

static int oldsplusInit()
{
	pPgmInitCallback = pgm_decrypt_oldsplus;

	return pgmInit();
}

struct BurnDriverD BurnDrvoldsplus = {
	"oldsplus", NULL, "pgm", "2004",
	"Oriental Legend Ex - Xi Yo Gi Shi Re Zuang Ex\0", "Incomplete Dump", "IGS", "PolyGameMaster",
	L"Oriental Legend Special Plus\0\u897F\u6E38\u91CA\u5384\u4F20 Plus\0", NULL, NULL, NULL,
	0, 4, HARDWARE_IGS_PGM | HARDWARE_IGS_USE_ARM_CPU, GBF_SCRFIGHT, 0,
	NULL, oldsplusRomInfo, oldsplusRomName, pgmInputInfo, pgmDIPInfo,
	oldsplusInit, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// The Killing Blade Plus (V300)

static struct BurnRomInfo killbldpRomDesc[] = {
	{ "v300x.u6",       0x080000, 0xb7fb8ec9, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code
	
	{ "t05701w032.bin", 0x400000, 0x567c714f, 2 | BRF_GRA },	   //  1 Tile data

	{ "a05701w064.bin", 0x800000, 0x8c0c992c, 3 | BRF_GRA },	   //  3 Sprite Color Data
	{ "a05702w064.bin", 0x800000, 0x7e5b0f27, 3 | BRF_GRA },	   //  4
	{ "a05703w064.bin", 0x800000, 0xaccbdb44, 3 | BRF_GRA },	   //  5
	
	{ "b05701w064.bin", 0x800000, 0xa20cdcef, 4 | BRF_GRA },	   //  6 Sprite Masks & Color Indexes
	{ "b05702w016.bin", 0x200000, 0xfe7457df, 4 | BRF_GRA },	   //  7
	
	{ "w05701b032.bin", 0x400000, 0x2d3ae593, 5 | BRF_SND },	   //  8 Samples

	{ "killbldp_igs027a.bin", 0x004000, 0x9a73bf7d, 7 | BRF_PRG | BRF_ESS }, //  9 Internal ARM7 Rom
	
	{ "v300x.u26",      0x200000, 0x144388c8, 8 | BRF_PRG | BRF_ESS }, // 10 External ARM7 Rom
};

STDROMPICKEXT(killbldp, killbldp, pgm)
STD_ROM_FN(killbldp)

int killbldpInit()
{
	pPgmInitCallback = pgm_decrypt_killbldp;

	int nRet = pgmInit();

	if (nRet == 0) {
		install_protection_svg();
	}

	return nRet;
}

struct BurnDriverD BurnDrvKillbldp = {
	"killbldp", NULL, "pgm", "2005",
	"The Killing Blade Plus (V300)\0", NULL, "IGS", "PolyGameMaster",
	L"The Killing Blade Plus \0\u50B2\u5251\u72C2\u5200\0\u50B2\u528D\u72C2\u5200 (V300)\0", NULL, NULL, NULL,
	0, 4, HARDWARE_IGS_PGM | HARDWARE_IGS_USE_ARM_CPU, GBF_VSFIGHT, 0,
	NULL, killbldpRomInfo, killbldpRomName, pgmInputInfo, pgmDIPInfo,
	killbldpInit, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// S.V.G. - Spectral vs Generation (V200, China)

static struct BurnRomInfo svgRomDesc[] = {
	{ "u30.bin",		0x080000, 0x34c18f3f, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code

	{ "t05601w016.bin",	0x200000, 0x03e110dc, 2 | BRF_GRA },	       //  1 Tile data

	{ "a05601w064.bin",	0x800000, 0xea6453e4, 3 | BRF_GRA },	       //  2 Sprite Color Data
	{ "a05602w064.bin",	0x800000, 0x6d00621b, 3 | BRF_GRA },	       //  3
	{ "a05603w064.bin",	0x800000, 0x7b71c64f, 3 | BRF_GRA },	       //  4
	{ "a05604w032.bin",	0x400000, 0x9452a567, 3 | BRF_GRA },	       //  5

	{ "b05601w064.bin",	0x800000, 0x35c0a489, 4 | BRF_GRA },	       //  6 Sprite Masks & Color Indexes
	{ "b05602w064.bin",	0x800000, 0x8aad3f85, 4 | BRF_GRA },	       //  7

	{ "w05601b064.bin",	0x800000, 0xbfe61a71, 5 | BRF_SND },	       //  8 Samples
	{ "w05602b032.bin",	0x400000, 0x0685166d, 5 | BRF_SND },	       //  9

	{ "svg_igs027a.bin",	0x004000, 0x00000000, 7 | BRF_PRG | BRF_NODUMP }, // 10 Internal ARM7 Rom

	{ "u26.bin",		0x400000, 0x46826ec8, 8 | BRF_PRG | BRF_ESS }, // 11 External ARM7 Rom
	{ "u29.bin",		0x400000, 0xfa5f3901, 8 | BRF_PRG | BRF_ESS }, // 12
};

STDROMPICKEXT(svg, svg, pgm)
STD_ROM_FN(svg)

static int svgInit()
{
	pPgmInitCallback = pgm_decrypt_svg;

	return pgmInit();
}

struct BurnDriverD BurnDrvSvg = {
	"svg", NULL, "pgm", "2005",
	"S.V.G. - Spectral vs Generation (V200, China)\0", "Incomplete Dump", "IGS", "PolyGameMaster",
	NULL, NULL, NULL, NULL,
	BDF_CLONE, 4, HARDWARE_IGS_PGM | HARDWARE_IGS_USE_ARM_CPU, GBF_SCRFIGHT, 0,
	NULL, svgRomInfo, svgRomName, pgmInputInfo, pgmDIPInfo,
	svgInit, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// -----------------------------------------------------------------------------
// Homebrew


// Chaos (PGM Demo)

static struct BurnRomInfo pgmdemoRomDesc[] = {
	{ "p0103.rom",     0x200000, 0xd3f6ec45, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code

	{ "t0100.rom",     0x400000, 0x0596a59a, 2 | BRF_GRA },		  //  1 Tile data

	{ "a0100.rom",     0x400000, 0x5d0e8fa1, 3 | BRF_GRA },		  //  2 Sprite Color Data

	{ "b0100.rom",     0x400000, 0x15dd191f, 4 | BRF_GRA },		  //  3 Sprite Masks & Color Indexes

	{ "m0100.rom",     0x200000, 0x8d89877e, 5 | BRF_SND },		  //  4 Samples
};

STDROMPICKEXT(pgmdemo, pgmdemo, pgm)
STD_ROM_FN(pgmdemo)

struct BurnDriver BurnDrvPgmdemo = {
	"pgmdemo", NULL, "pgm", "2005",
	"Chaos (PGM Demo)\0", "Demo Game", "Raster", "PolyGameMaster",
	NULL, NULL, NULL, NULL,
	BDF_GAME_WORKING  | BDF_DEMO, 4, HARDWARE_IGS_PGM, GBF_MISC, 0,
	NULL, pgmdemoRomInfo, pgmdemoRomName, pgmInputInfo, pgmDIPInfo,
	pgmInit,pgmExit,pgmFrame,pgmDraw,NULL, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// Frog Feast (PGM)

static struct BurnRomInfo pgmfrogRomDesc[] = {
	{ "p0103.rom",     0x200000, 0xcdec9e8d, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code

	{ "t0100.rom",     0x400000, 0x8f58b6d8, 2 | BRF_GRA },		  //  1 Tile data

	{ "a0100.rom",     0x400000, 0xdc1eafe6, 3 | BRF_GRA },		  //  2 Sprite Color Data

	{ "b0100.rom",     0x400000, 0x3d44b66f, 4 | BRF_GRA },		  //  3 Sprite Masks & Color Indexes

	{ "m0100.rom",     0x200000, 0x05e2f761, 5 | BRF_SND },		  //  4 Samples
};

STDROMPICKEXT(pgmfrog, pgmfrog, pgm)
STD_ROM_FN(pgmfrog)

struct BurnDriver BurnDrvPgmfrog = {
	"pgmfrog", NULL, "pgm", "2006",
	"Frog Feast (PGM)\0", NULL, "RasterSoft", "PolyGameMaster",
	NULL, NULL, NULL, NULL,
	BDF_GAME_WORKING  | BDF_HOMEBREW, 4, HARDWARE_IGS_PGM, GBF_MISC, 0,
	NULL, pgmfrogRomInfo, pgmfrogRomName, pgmInputInfo, pgmDIPInfo,
	pgmInit, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


// P-GeMeni (060123)

static struct BurnRomInfo pgemeniRomDesc[] = {
	{ "p0103.rom",     0x200000, 0x6cafa56b, 1 | BRF_PRG | BRF_ESS }, //  0 68K Code

	{ "t0100.rom",     0x400000, 0x42b979dd, 2 | BRF_GRA },		  //  1 Tile data

	{ "a0100.rom",     0x400000, 0x105d7cee, 3 | BRF_GRA },		  //  2 Sprite Color Data

	{ "b0100.rom",     0x400000, 0xb4127373, 4 | BRF_GRA },		  //  3 Sprite Masks & Color Indexes

	{ "m0100.rom",     0x200000, 0x8d89877e, 5 | BRF_SND },		  //  4 Samples
};

STDROMPICKEXT(pgemeni, pgemeni, pgm)
STD_ROM_FN(pgemeni)

struct BurnDriver BurnDrvPgemeni = {
	"pgemeni", NULL, "pgm", "2006",
	"P-GeMeni (060123)\0", NULL, "blastar@gmx.net", "PolyGameMaster",
	NULL, NULL, NULL, NULL,
	BDF_GAME_WORKING  | BDF_HOMEBREW, 4, HARDWARE_IGS_PGM, GBF_PUZZLE, 0,
	NULL, pgemeniRomInfo, pgemeniRomName, pgmInputInfo, pgmDIPInfo,
	pgmInit, pgmExit, pgmFrame, pgmDraw, pgmScan, 0, NULL, NULL, NULL, &nPgmPalRecalc, 0x1200,
	448, 224, 4, 3
};


