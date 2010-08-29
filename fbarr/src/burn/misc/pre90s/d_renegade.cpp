#include "tiles_generic.h"
#include "m6502.h"
#include "m6809_intf.h"
#include "burn_ym3526.h"

static unsigned char DrvInputPort0[8] = {0, 0, 0, 0, 0, 0, 0, 0};
static unsigned char DrvInputPort1[8] = {0, 0, 0, 0, 0, 0, 0, 0};
static unsigned char DrvInputPort2[8] = {0, 0, 0, 0, 0, 0, 0, 0};
static unsigned char DrvDip[2]        = {0, 0};
static unsigned char DrvInput[3]      = {0x00, 0x00, 0x00};
static unsigned char DrvReset         = 0;

static unsigned char *Mem                 = NULL;
static unsigned char *MemEnd              = NULL;
static unsigned char *RamStart            = NULL;
static unsigned char *RamEnd              = NULL;
static unsigned char *DrvM6502Rom         = NULL;
static unsigned char *DrvM6809Rom         = NULL;
static unsigned char *DrvADPCMRom         = NULL;
static unsigned char *DrvM6502Ram         = NULL;
static unsigned char *DrvM6809Ram         = NULL;
static unsigned char *DrvVideoRam1        = NULL;
static unsigned char *DrvVideoRam2        = NULL;
static unsigned char *DrvSpriteRam        = NULL;
static unsigned char *DrvPaletteRam1      = NULL;
static unsigned char *DrvPaletteRam2      = NULL;
static unsigned char *DrvChars            = NULL;
static unsigned char *DrvTiles            = NULL;
static unsigned char *DrvSprites          = NULL;
static unsigned char *DrvTempRom          = NULL;
static unsigned int  *DrvPalette          = NULL;

static unsigned char DrvRomBank;
static unsigned char DrvVBlank;
static unsigned char DrvScrollX[2];
static unsigned char DrvSoundLatch;

static int nCyclesTotal[2];



struct adpcm_state
{
	INT32	signal;
	INT32	step;
};

static struct renegade_adpcm_state
{
	struct adpcm_state adpcm;
//	sound_stream *stream;
	UINT32 current, end;
	UINT8 nibble;
	UINT8 playing;
	UINT8 *base;
} renegade_adpcm;

static int diff_lookup[49*16];
static int tables_computed = 0;

static unsigned int nUpdateStep;

static void compute_tables(void)
{
	/* nibble to bit map */
	static const int nbl2bit[16][4] =
	{
		{ 1, 0, 0, 0}, { 1, 0, 0, 1}, { 1, 0, 1, 0}, { 1, 0, 1, 1},
		{ 1, 1, 0, 0}, { 1, 1, 0, 1}, { 1, 1, 1, 0}, { 1, 1, 1, 1},
		{-1, 0, 0, 0}, {-1, 0, 0, 1}, {-1, 0, 1, 0}, {-1, 0, 1, 1},
		{-1, 1, 0, 0}, {-1, 1, 0, 1}, {-1, 1, 1, 0}, {-1, 1, 1, 1}
	};

	int step, nib;

	/* loop over all possible steps */
	for (step = 0; step <= 48; step++)
	{
		/* compute the step value */
		int stepval = (int)floor(16.0 * pow(11.0 / 10.0, (double)step));
		
		/* loop over all nibbles and compute the difference */
		for (nib = 0; nib < 16; nib++)
		{
			diff_lookup[step*16 + nib] = nbl2bit[nib][0] *
				(stepval   * nbl2bit[nib][1] +
				 stepval/2 * nbl2bit[nib][2] +
				 stepval/4 * nbl2bit[nib][3] +
				 stepval/8);
		}
	}

	tables_computed = 1;
}

static void reset_adpcm(struct adpcm_state *state)
{
	/* make sure we have our tables */
	if (!tables_computed)
		compute_tables();

	/* reset the signal/step */
	state->signal = -2;
	state->step = 0;
}

static void RenegadeADPCMInit(int clock)
{
	struct renegade_adpcm_state *state = &renegade_adpcm;
	state->playing = 0;
	state->base = DrvADPCMRom;
	reset_adpcm(&state->adpcm);
	
	nUpdateStep = (int)(((float)clock / nBurnSoundRate) * 4096);
}









#define MCU_TYPE_NONE		0
#define MCU_TYPE_RENEGADE	1
#define MCU_TYPE_KUNIOKUN	2

#define MCU_BUFFER_MAX 6
static UINT8 mcu_buffer[MCU_BUFFER_MAX];
static UINT8 mcu_input_size;
static UINT8 mcu_output_byte;
static INT8 mcu_key;

static int mcu_type;
static const UINT8 *mcu_encrypt_table;
static int mcu_encrypt_table_len;

static struct BurnInputInfo DrvInputList[] =
{
	{"Coin 1"            , BIT_DIGITAL  , DrvInputPort1 + 6, "p1 coin"   },
	{"Start 1"           , BIT_DIGITAL  , DrvInputPort0 + 6, "p1 start"  },
	{"Coin 2"            , BIT_DIGITAL  , DrvInputPort1 + 7, "p2 coin"   },
	{"Start 2"           , BIT_DIGITAL  , DrvInputPort0 + 7, "p2 start"  },

	{"P1 Up"             , BIT_DIGITAL  , DrvInputPort0 + 2, "p1 up"     },
	{"P1 Down"           , BIT_DIGITAL  , DrvInputPort0 + 3, "p1 down"   },
	{"P1 Left"           , BIT_DIGITAL  , DrvInputPort0 + 1, "p1 left"   },
	{"P1 Right"          , BIT_DIGITAL  , DrvInputPort0 + 0, "p1 right"  },
	{"P1 Fire 1"         , BIT_DIGITAL  , DrvInputPort0 + 4, "p1 fire 1" },
	{"P1 Fire 2"         , BIT_DIGITAL  , DrvInputPort0 + 5, "p1 fire 2" },
	{"P1 Fire 3"         , BIT_DIGITAL  , DrvInputPort2 + 2, "p1 fire 3" },
	
	{"P2 Up"             , BIT_DIGITAL  , DrvInputPort1 + 2, "p2 up"     },
	{"P2 Down"           , BIT_DIGITAL  , DrvInputPort1 + 3, "p2 down"   },
	{"P2 Left"           , BIT_DIGITAL  , DrvInputPort1 + 1, "p2 left"   },
	{"P2 Right"          , BIT_DIGITAL  , DrvInputPort1 + 0, "p2 right"  },
	{"P2 Fire 1"         , BIT_DIGITAL  , DrvInputPort1 + 4, "p2 fire 1" },
	{"P2 Fire 2"         , BIT_DIGITAL  , DrvInputPort1 + 5, "p2 fire 2" },
	{"P2 Fire 3"         , BIT_DIGITAL  , DrvInputPort2 + 3, "p2 fire 3" },

	{"Reset"             , BIT_DIGITAL  , &DrvReset        , "reset"     },
	{"Service"           , BIT_DIGITAL  , DrvInputPort2 + 7, "service"   },
	{"Dip 1"             , BIT_DIPSWITCH, DrvDip + 0       , "dip"       },
	{"Dip 2"             , BIT_DIPSWITCH, DrvDip + 1       , "dip"       },
};


STDINPUTINFO(Drv)

static inline void DrvMakeInputs()
{
	// Reset Inputs
	DrvInput[0] = DrvInput[1] = 0xff;
	DrvInput[2] = 0x9c;

	// Compile Digital Inputs
	for (int i = 0; i < 8; i++) {
		DrvInput[0] -= (DrvInputPort0[i] & 1) << i;
		DrvInput[1] -= (DrvInputPort1[i] & 1) << i;
		DrvInput[2] -= (DrvInputPort2[i] & 1) << i;
	}
}

static struct BurnDIPInfo DrvDIPList[]=
{
	// Default Values
	{0x14, 0xff, 0xff, 0xbf, NULL                     },
	{0x15, 0xff, 0xff, 0x03, NULL                     },
	
	// Dip 1
	{0   , 0xfe, 0   , 4   , "Coin A"                 },
	{0x14, 0x01, 0x03, 0x00, "2 Coins 1 Play"         },
	{0x14, 0x01, 0x03, 0x03, "1 Coin  1 Play"         },
	{0x14, 0x01, 0x03, 0x02, "1 Coin  2 Plays"        },
	{0x14, 0x01, 0x03, 0x01, "1 Coin  3 Plays"        },
	
	{0   , 0xfe, 0   , 4   , "Coin B"                 },
	{0x14, 0x01, 0x0c, 0x00, "2 Coins 1 Play"         },
	{0x14, 0x01, 0x0c, 0x0c, "1 Coin  1 Play"         },
	{0x14, 0x01, 0x0c, 0x08, "1 Coin  2 Plays"        },
	{0x14, 0x01, 0x0c, 0x04, "1 Coin  3 Plays"        },
	
	{0   , 0xfe, 0   , 2   , "Lives"                  },
	{0x14, 0x01, 0x10, 0x10, "1"                      },
	{0x14, 0x01, 0x10, 0x00, "2"                      },
	
	{0   , 0xfe, 0   , 4   , "Bonus"                  },
	{0x14, 0x01, 0x20, 0x20, "30k"                    },
	{0x14, 0x01, 0x20, 0x00, "None"                   },
	
	{0   , 0xfe, 0   , 2   , "Cabinet"                },
	{0x14, 0x01, 0x40, 0x00, "Upright"                },
	{0x14, 0x01, 0x40, 0x40, "Cocktail"               },
	
	{0   , 0xfe, 0   , 2   , "Flip Screen"            },
	{0x14, 0x01, 0x80, 0x80, "Off"                    },
	{0x14, 0x01, 0x80, 0x00, "On"                     },
	
	// Dip 2	
	{0   , 0xfe, 0   , 4   , "Difficulty"             },
	{0x15, 0x01, 0x03, 0x02, "Easy"                   },
	{0x15, 0x01, 0x03, 0x03, "Normal"                 },
	{0x15, 0x01, 0x03, 0x01, "Hard"                   },
	{0x15, 0x01, 0x03, 0x00, "Very Hard"              },
};

STDDIPINFO(Drv)

static struct BurnRomInfo DrvRomDesc[] = {
	{ "nb-5.bin",      0x08000, 0xba683ddf, BRF_ESS | BRF_PRG }, //  0	M6502 Program Code
	{ "na-5.bin",      0x08000, 0xde7e7df4, BRF_ESS | BRF_PRG }, //	 1
	
	{ "n0-5.bin",      0x08000, 0x3587de3b, BRF_ESS | BRF_PRG }, //  2	M6809 Program Code
	
	{ "nc-5.bin",      0x08000, 0x9adfaa5d, BRF_GRA },	     //  3	Characters
	
	{ "n1-5.bin",      0x08000, 0x4a9f47f3, BRF_GRA },	     //  4	Tiles
	{ "n6-5.bin",      0x08000, 0xd62a0aa8, BRF_GRA },	     //  5
	{ "n7-5.bin",      0x08000, 0x7ca5a532, BRF_GRA },	     //  6
	{ "n2-5.bin",      0x08000, 0x8d2e7982, BRF_GRA },	     //  7
	{ "n8-5.bin",      0x08000, 0x0dba31d3, BRF_GRA },	     //  8
	{ "n9-5.bin",      0x08000, 0x5b621b6a, BRF_GRA },	     //  9
	
	{ "nh-5.bin",      0x08000, 0xdcd7857c, BRF_GRA },	     //  10	Sprites
	{ "nd-5.bin",      0x08000, 0x2de1717c, BRF_GRA },	     //  11
	{ "nj-5.bin",      0x08000, 0x0f96a18e, BRF_GRA },	     //  12
	{ "nn-5.bin",      0x08000, 0x1bf15787, BRF_GRA },	     //  13
	{ "ne-5.bin",      0x08000, 0x924c7388, BRF_GRA },	     //  14
	{ "nk-5.bin",      0x08000, 0x69499a94, BRF_GRA },	     //  15
	{ "ni-5.bin",      0x08000, 0x6f597ed2, BRF_GRA },	     //  16
	{ "nf-5.bin",      0x08000, 0x0efc8d45, BRF_GRA },	     //  17
	{ "nl-5.bin",      0x08000, 0x14778336, BRF_GRA },	     //  18
	{ "no-5.bin",      0x08000, 0x147dd23b, BRF_GRA },	     //  19
	{ "ng-5.bin",      0x08000, 0xa8ee3720, BRF_GRA },	     //  20
	{ "nm-5.bin",      0x08000, 0xc100258e, BRF_GRA },	     //  21
	
	{ "n5-5.bin",      0x08000, 0x7ee43a3c, BRF_GRA },	     //  22	ADPCM
	{ "n4-5.bin",      0x08000, 0x6557564c, BRF_GRA },	     //  23
	{ "n3-5.bin",      0x08000, 0x78fd6190, BRF_GRA },	     //  24
	
	{ "mcu",           0x08000, 0x00000000, BRF_PRG | BRF_NODUMP },	// 25 MCU
};

STD_ROM_PICK(Drv)
STD_ROM_FN(Drv)

static struct BurnRomInfo DrvjRomDesc[] = {
	{ "nb-01.bin",     0x08000, 0x93fcfdf5, BRF_ESS | BRF_PRG }, //  0	M6502 Program Code
	{ "ta18-11.bin",   0x08000, 0xf240f5cd, BRF_ESS | BRF_PRG }, //	 1
	
	{ "n0-5.bin",      0x08000, 0x3587de3b, BRF_ESS | BRF_PRG }, //  2	M6809 Program Code
	
	{ "ta18-25.bin",   0x08000, 0x9bd2bea3, BRF_GRA },	     //  3	Characters
	
	{ "ta18-01.bin",   0x08000, 0xdaf15024, BRF_GRA },	     //  4	Tiles
	{ "ta18-06.bin",   0x08000, 0x1f59a248, BRF_GRA },	     //  5
	{ "n7-5.bin",      0x08000, 0x7ca5a532, BRF_GRA },	     //  6
	{ "ta18-02.bin",   0x08000, 0x994c0021, BRF_GRA },	     //  7
	{ "ta18-04.bin",   0x08000, 0x55b9e8aa, BRF_GRA },	     //  8
	{ "ta18-03.bin",   0x08000, 0x0475c99a, BRF_GRA },	     //  9
	
	{ "ta18-20.bin",   0x08000, 0xc7d54139, BRF_GRA },	     //  10	Sprites
	{ "ta18-24.bin",   0x08000, 0x84677d45, BRF_GRA },	     //  11
	{ "ta18-18.bin",   0x08000, 0x1c770853, BRF_GRA },	     //  12
	{ "ta18-14.bin",   0x08000, 0xaf656017, BRF_GRA },	     //  13
	{ "ta18-23.bin",   0x08000, 0x3fd19cf7, BRF_GRA },	     //  14
	{ "ta18-17.bin",   0x08000, 0x74c64c6e, BRF_GRA },	     //  15
	{ "ta18-19.bin",   0x08000, 0xc8795fd7, BRF_GRA },	     //  16
	{ "ta18-22.bin",   0x08000, 0xdf3a2ff5, BRF_GRA },	     //  17
	{ "ta18-16.bin",   0x08000, 0x7244bad0, BRF_GRA },	     //  18
	{ "ta18-13.bin",   0x08000, 0xb6b14d46, BRF_GRA },	     //  19
	{ "ta18-21.bin",   0x08000, 0xc95e009b, BRF_GRA },	     //  20
	{ "ta18-15.bin",   0x08000, 0xa5d61d01, BRF_GRA },	     //  21
	
	{ "ta18-07.bin",   0x08000, 0x02e3f3ed, BRF_GRA },	     //  22	ADPCM
	{ "ta18-08.bin",   0x08000, 0xc9312613, BRF_GRA },	     //  23
	{ "ta18-09.bin",   0x08000, 0x07ed4705, BRF_GRA },	     //  24
	
	{ "mcu",           0x08000, 0x00000000, BRF_PRG | BRF_NODUMP },	// 25 MCU
};

STD_ROM_PICK(Drvj)
STD_ROM_FN(Drvj)

static struct BurnRomInfo DrvbRomDesc[] = {
	{ "ta18-10.bin",   0x08000, 0xa90cf44a, BRF_ESS | BRF_PRG }, //  0	M6502 Program Code
	{ "ta18-11.bin",   0x08000, 0xf240f5cd, BRF_ESS | BRF_PRG }, //	 1
	
	{ "n0-5.bin",      0x08000, 0x3587de3b, BRF_ESS | BRF_PRG }, //  2	M6809 Program Code
	
	{ "ta18-25.bin",   0x08000, 0x9bd2bea3, BRF_GRA },	     //  3	Characters
	
	{ "ta18-01.bin",   0x08000, 0xdaf15024, BRF_GRA },	     //  4	Tiles
	{ "ta18-06.bin",   0x08000, 0x1f59a248, BRF_GRA },	     //  5
	{ "n7-5.bin",      0x08000, 0x7ca5a532, BRF_GRA },	     //  6
	{ "ta18-02.bin",   0x08000, 0x994c0021, BRF_GRA },	     //  7
	{ "ta18-04.bin",   0x08000, 0x55b9e8aa, BRF_GRA },	     //  8
	{ "ta18-03.bin",   0x08000, 0x0475c99a, BRF_GRA },	     //  9
	
	{ "ta18-20.bin",   0x08000, 0xc7d54139, BRF_GRA },	     //  10	Sprites
	{ "ta18-24.bin",   0x08000, 0x84677d45, BRF_GRA },	     //  11
	{ "ta18-18.bin",   0x08000, 0x1c770853, BRF_GRA },	     //  12
	{ "ta18-14.bin",   0x08000, 0xaf656017, BRF_GRA },	     //  13
	{ "ta18-23.bin",   0x08000, 0x3fd19cf7, BRF_GRA },	     //  14
	{ "ta18-17.bin",   0x08000, 0x74c64c6e, BRF_GRA },	     //  15
	{ "ta18-19.bin",   0x08000, 0xc8795fd7, BRF_GRA },	     //  16
	{ "ta18-22.bin",   0x08000, 0xdf3a2ff5, BRF_GRA },	     //  17
	{ "ta18-16.bin",   0x08000, 0x7244bad0, BRF_GRA },	     //  18
	{ "ta18-13.bin",   0x08000, 0xb6b14d46, BRF_GRA },	     //  19
	{ "ta18-21.bin",   0x08000, 0xc95e009b, BRF_GRA },	     //  20
	{ "ta18-15.bin",   0x08000, 0xa5d61d01, BRF_GRA },	     //  21
	
	{ "ta18-07.bin",   0x08000, 0x02e3f3ed, BRF_GRA },	     //  22	ADPCM
	{ "ta18-08.bin",   0x08000, 0xc9312613, BRF_GRA },	     //  23
	{ "ta18-09.bin",   0x08000, 0x07ed4705, BRF_GRA },	     //  24
};

STD_ROM_PICK(Drvb)
STD_ROM_FN(Drvb)

static int MemIndex()
{
	unsigned char *Next; Next = Mem;

	DrvM6502Rom            = Next; Next += 0x10000;
	DrvM6809Rom            = Next; Next += 0x08000;
	DrvADPCMRom            = Next; Next += 0x20000;

	RamStart               = Next;

	DrvM6502Ram            = Next; Next += 0x01800;
	DrvM6809Ram            = Next; Next += 0x01000;
	DrvSpriteRam           = Next; Next += 0x00800;
	DrvVideoRam1           = Next; Next += 0x00800;
	DrvVideoRam2           = Next; Next += 0x00800;
	DrvPaletteRam1         = Next; Next += 0x00100;
	DrvPaletteRam2         = Next; Next += 0x00100;

	RamEnd                 = Next;

	DrvChars               = Next; Next += 0x0400 * 8 * 8;
	DrvTiles               = Next; Next += 0x0800 * 16 * 16;
	DrvSprites             = Next; Next += 0x1000 * 16 * 16;
	DrvPalette             = (unsigned int*)Next; Next += 0x00100 * sizeof(unsigned int);

	MemEnd                 = Next;

	return 0;
}

static const UINT8 renegade_xor_table[0x37] =
{
	0x8A, 0x48, 0x98, 0x48, 0xA9, 0x00, 0x85, 0x14,
	0x85, 0x15, 0xA5, 0x11, 0x05, 0x10, 0xF0, 0x21,
	0x46, 0x11, 0x66, 0x10, 0x90, 0x0F, 0x18, 0xA5,
	0x14, 0x65, 0x12, 0x85, 0x14, 0xA5, 0x15, 0x65,
	0x13, 0x85, 0x15, 0xB0, 0x06, 0x06, 0x12, 0x26,
	0x13, 0x90, 0xDF, 0x68, 0xA8, 0x68, 0xAA, 0x38,
	0x60, 0x68, 0xA8, 0x68, 0xAA, 0x18, 0x60
};

static const UINT8 kuniokun_xor_table[0x2a] =
{
	0x48, 0x8a, 0x48, 0xa5, 0x01, 0x48, 0xa9, 0x00,
	0x85, 0x01, 0xa2, 0x10, 0x26, 0x10, 0x26, 0x11,
	0x26, 0x01, 0xa5, 0x01, 0xc5, 0x00, 0x90, 0x04,
	0xe5, 0x00, 0x85, 0x01, 0x26, 0x10, 0x26, 0x11,
	0xca, 0xd0, 0xed, 0x68, 0x85, 0x01, 0x68, 0xaa,
	0x68, 0x60
};

static unsigned char mcu_reset_r()
{
	mcu_key = -1;
	mcu_input_size = 0;
	mcu_output_byte = 0;
	
	return 0;
}

static void mcu_w(unsigned char data)
{
	mcu_output_byte = 0;

	if (mcu_key < 0) {
		mcu_key = 0;
		mcu_input_size = 1;
		mcu_buffer[0] = data;
	} else {
		data ^= mcu_encrypt_table[mcu_key++];
		if (mcu_key == mcu_encrypt_table_len)
			mcu_key = 0;
		if (mcu_input_size < MCU_BUFFER_MAX)
			mcu_buffer[mcu_input_size++] = data;
	}
}

static void mcu_process_command(void)
{
	mcu_input_size = 0;
	mcu_output_byte = 0;

	switch (mcu_buffer[0]) {
		case 0x10:
			mcu_buffer[0] = mcu_type;
			break;

		case 0x26: {
			int sound_code = mcu_buffer[1];
			static const UINT8 sound_command_table[256] = {
				0xa0, 0xa1, 0xa2, 0x80, 0x81, 0x82, 0x83, 0x84,
				0x85, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x8b, 0x8c,
				0x8d, 0x8e, 0x8f, 0x97, 0x96, 0x9b, 0x9a, 0x95,
				0x9e, 0x98, 0x90, 0x93, 0x9d, 0x9c, 0xa3, 0x91,
				0x9f, 0x99, 0xa6, 0xae, 0x94, 0xa5, 0xa4, 0xa7,
				0x92, 0xab, 0xac, 0xb0, 0xb1, 0xb2, 0xb3, 0xb4,
				0xb5, 0xb6, 0xb7, 0xb8, 0xb9, 0xba, 0xbb, 0x00,
				0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
				0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
				0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
				0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
				0x00, 0x00, 0x00, 0x00, 0x00, 0x20, 0x20, 0x20,
				0x50, 0x50, 0x90, 0x30, 0x30, 0x00, 0x00, 0x00,
				0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
				0x00, 0x00, 0x00, 0x80, 0xa0, 0x00, 0x00, 0x00,
				0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
				0x00, 0x40, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00,
				0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
				0x20, 0x00, 0x00, 0x10, 0x10, 0x00, 0x00, 0x90,
				0x30, 0x30, 0x30, 0xb0, 0xb0, 0xb0, 0xb0, 0xf0,
				0xf0, 0xf0, 0xf0, 0xd0, 0xf0, 0x00, 0x00, 0x00,
				0x00, 0x10, 0x10, 0x50, 0x30, 0xb0, 0xb0, 0xf0,
				0xf0, 0xf0, 0xf0, 0xf0, 0xf0, 0x00, 0x00, 0x00,
				0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10,
				0x10, 0x10, 0x30, 0x30, 0x20, 0x00, 0x00, 0x00,
				0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
				0x00, 0x00, 0x00, 0x00, 0x00, 0x0f, 0x0f, 0x0f,
				0x0f, 0x0f, 0x0f, 0x0f, 0x0f, 0x0f, 0x0f, 0x0f,
				0x0f, 0x0f, 0x0f, 0x0f, 0x0f, 0x8f, 0x8f, 0x0f,
				0x0f, 0x0f, 0x0f, 0x0f, 0x0f, 0x0f, 0x0f, 0x0f,
				0x0f, 0x0f, 0x0f, 0x0f, 0x0f, 0xff, 0xff, 0xff,
				0xef, 0xef, 0xcf, 0x8f, 0x8f, 0x0f, 0x0f, 0x0f
			};
			mcu_buffer[0] = 1;
			mcu_buffer[1] = sound_command_table[sound_code];
			break;
		}
		

		case 0x33: {
			int joy_bits = mcu_buffer[2];
			static const UINT8 joy_table[0x10] = {
				0, 3, 7, 0, 1, 2, 8, 0, 5, 4, 6, 0, 0, 0, 0, 0
			};
			mcu_buffer[0] = 1;
			mcu_buffer[1] = joy_table[joy_bits & 0xf];
			break;
		}
		

		case 0x44: {
			int difficulty = mcu_buffer[2] & 0x3;
			int stage = mcu_buffer[3];
			static const UINT8 difficulty_table[4] = { 5, 3, 1, 2 };
			int result = difficulty_table[difficulty];

			if (stage == 0)
				result--;
			result += stage / 4;
			if (result > 0x21)
				result += 0xc0;

			mcu_buffer[0] = 1;
			mcu_buffer[1] = result;
			break;
		}
		
		case 0x55: {
			int difficulty = mcu_buffer[4] & 0x3;
			static const UINT16 table[4] = {
				0x4001, 0x5001, 0x1502, 0x0002
			};

			mcu_buffer[0] = 3;
			mcu_buffer[2] = table[difficulty] >> 8;
			mcu_buffer[3] = table[difficulty] & 0xff;
			break;
		}
		

		case 0x41: {
			mcu_buffer[0] = 2;
			mcu_buffer[1] = 0x20;
			mcu_buffer[2] = 0x78;
			break;
		}
		

		case 0x40: {
			int difficulty = mcu_buffer[2];
			int enemy_type = mcu_buffer[3];
			int health;

			if (enemy_type <= 4) {
				health = 0x18 + difficulty * 2;
				if (health > 0x40)
					health = 0x40;	/* max 0x40 */
			} else {
				health = 0x06 + difficulty * 2;
				if (health > 0x20)
					health = 0x20;	/* max 0x20 */
			}
			mcu_buffer[0] = 1;
			mcu_buffer[1] = health;
			break;
		}
		

		case 0x42: {
			int stage = mcu_buffer[2] & 0x3;
			int indx = mcu_buffer[3];
			int enemy_type=0;

			static const int table[] = {
				0x01, 0x06, 0x06, 0x05, 0x05, 0x05, 0x05, 0x05,	/* for stage#: 0 */
				0x02, 0x0a, 0x0a, 0x09, 0x09, 0x09, 0x09,	/* for stage#: 1 */
				0x03, 0x0e, 0x0e, 0x0e, 0x0d, 0x0d, 0x0d, 0x0d,	/* for stage#: 2 */
				0x04, 0x12, 0x12, 0x12, 0x12, 0x12, 0x12, 0x12,	/* for stage#: 3 */
				0x3d, 0x23, 0x26, 0x0a, 0xb6, 0x11, 0xa4, 0x0f,	/* strange data (maybe out of table) */
			};
			int offset = stage * 8 + indx;

			if (stage >= 2)
				offset--;

			enemy_type = table[offset];

			mcu_buffer[0] = 1;
			mcu_buffer[1] = enemy_type;
			break;
		}
	}
}

static unsigned char mcu_r()
{
	int result = 1;

	if (mcu_input_size)
		mcu_process_command();

	if (mcu_output_byte < MCU_BUFFER_MAX)
		result = mcu_buffer[mcu_output_byte++];

	return result;
}

static int DrvDoReset()
{
	m6502Open(0);
	m6502Reset();
	m6502Close();
	
	M6809Open(0);
	M6809Reset();
	M6809Close();
	
	BurnYM3526Reset();
	
	DrvRomBank = 0;
	DrvVBlank = 0;
	memset(DrvScrollX, 0, 2);
	DrvSoundLatch = 0;
	
	return 0;
}

unsigned char RenegadeReadByte(unsigned short Address)
{
	switch (Address) {
		case 0x3800: {
			return DrvInput[0];
		}
		
		case 0x3801: {
			return DrvInput[1];
		}
		
		case 0x3802: {
			return DrvInput[2] | DrvDip[1] | ((DrvVBlank) ? 0x40 : 0);
		}
		
		case 0x3803: {
			return DrvDip[0];
		}
		
		case 0x3804: {
			return mcu_r();
		}
		
		case 0x3805: {
			return mcu_reset_r();
		}
		
		default: {
			bprintf(PRINT_NORMAL, _T("M6502 Read Byte %04X\n"), Address);
		}
	}

	return 0;
}

void RenegadeWriteByte(unsigned short Address, unsigned char Data)
{
	switch (Address) {
		case 0x3800: {
			DrvScrollX[0] = Data;
			return;
		}
		
		case 0x3801: {
			DrvScrollX[1] = Data;
			return;
		}
		
		case 0x3802: {
			DrvSoundLatch = Data;
			M6809Open(0);
			M6809SetIRQ(M6809_IRQ_LINE, M6809_IRQSTATUS_AUTO);
			M6809Close();
			return;
		}
		
		case 0x3803: {
			// flipscreen
			return;
		}
		
		case 0x3804: {
			mcu_w(Data);
			return;
		}
		
		case 0x3805: {
			DrvRomBank = Data & 1;
			m6502MapMemory(DrvM6502Rom + 0x8000 + (DrvRomBank * 0x4000), 0x4000, 0x7fff, M6502_ROM);
			return;
		}
		
		case 0x3806: {
			// nop
			return;
		}
		
		case 0x3807: {
			// coin counter
			return;
		}
		
		default: {
			bprintf(PRINT_NORMAL, _T("M6502 Write Byte %04X, %02X\n"), Address, Data);
		}
	}
}

unsigned char RenegadeM6809ReadByte(unsigned short Address)
{
	switch (Address) {
		case 0x1000: {
			return DrvSoundLatch;
		}
		
		default: {
			bprintf(PRINT_NORMAL, _T("M6809 Read Byte %04X\n"), Address);
		}
	}

	return 0;
}

#if 0
static WRITE8_HANDLER( adpcm_play_w )
{
	int offs;
	int len;

	offs = (data - 0x2c) * 0x2000;
	len = 0x2000 * 2;

	/* kludge to avoid reading past end of ROM */
	if (offs + len > 0x20000)
		len = 0x1000;

	if (offs >= 0 && offs+len <= 0x20000)
	{
		renegade_adpcm.current = offs;
		renegade_adpcm.end = offs + len/2;
		renegade_adpcm.nibble = 4;
		renegade_adpcm.playing = 1;
	}
	else
		logerror("out of range adpcm command: 0x%02x\n", data);
}
#endif

void RenegadeM6809WriteByte(unsigned short Address, unsigned char Data)
{
	switch (Address) {
		case 0x1800: {
			// nop???
			return;
		}
		
		case 0x2000: {
			int Offset, Length;
			
			Offset = (Data - 0x2c) * 0x2000;
			Length = 0x2000 * 2;
			
			if ((Offset + Length) > 0x20000) Length = 0x1000;
			
			if (Offset >= 0 && (Offset + Length) < 0x20000) {
				renegade_adpcm.current = Offset << 12;
				renegade_adpcm.end = Offset + (Length / 2);
				renegade_adpcm.nibble = 4;
				renegade_adpcm.playing = 1;
			}
			return;
		}
		
		case 0x2800: {
			BurnYM3526Write(0, Data);
			return;
		}
		
		case 0x2801: {
			BurnYM3526Write(1, Data);
			return;
		}
		
		case 0x3000: {
			// nop???
			return;
		}
		
		default: {
			bprintf(PRINT_NORMAL, _T("M6809 Write Byte %04X, %02X\n"), Address, Data);
		}
	}
}

static int CharPlaneOffsets[3]   = { 2, 4, 6 };
static int CharXOffsets[8]       = { 1, 0, 65, 64, 129, 128, 193, 192 };
static int CharYOffsets[8]       = { 0, 8, 16, 24, 32, 40, 48, 56 };
static int Tile1PlaneOffsets[3]  = { 0x00004, 0x40000, 0x40004 };
static int Tile2PlaneOffsets[3]  = { 0x00000, 0x60000, 0x60004 };
static int Tile3PlaneOffsets[3]  = { 0x20004, 0x80000, 0x80004 };
static int Tile4PlaneOffsets[3]  = { 0x20000, 0xa0000, 0xa0004 };
static int TileXOffsets[16]      = { 3, 2, 1, 0, 131, 130, 129, 128, 259, 258, 257, 256, 387, 386, 385, 384 };
static int TileYOffsets[16]      = { 0, 8, 16, 24, 32, 40, 48, 56, 64, 72, 80, 88, 96, 104, 112, 120 };

static void DrvFMIRQHandler(int, int nStatus)
{
	if (nStatus) {
		M6809SetIRQ(M6809_FIRQ_LINE, M6809_IRQSTATUS_ACK);
	} else {
		M6809SetIRQ(M6809_FIRQ_LINE, M6809_IRQSTATUS_NONE);
	}
}

static int DrvSynchroniseStream(int nSoundRate)
{
	return (long long)M6809TotalCycles() * nSoundRate / 1500000;
}

static int DrvInit(int nMcuType)
{
	int nRet = 0, nLen;

	// Allocate and Blank all required memory
	Mem = NULL;
	MemIndex();
	nLen = MemEnd - (unsigned char *)0;
	if ((Mem = (unsigned char *)malloc(nLen)) == NULL) return 1;
	memset(Mem, 0, nLen);
	MemIndex();

	DrvTempRom = (unsigned char *)malloc(0x60000);

	// Load M6502 Program Roms
	nRet = BurnLoadRom(DrvM6502Rom + 0x00000, 0, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvM6502Rom + 0x08000, 1, 1); if (nRet != 0) return 1;
	
	// Load M6809 Program Roms
	nRet = BurnLoadRom(DrvM6809Rom + 0x00000, 2, 1); if (nRet != 0) return 1;
	
	// Load and decode the chars
	nRet = BurnLoadRom(DrvTempRom, 3, 1); if (nRet != 0) return 1;
	GfxDecode(0x400, 3, 8, 8, CharPlaneOffsets, CharXOffsets, CharYOffsets, 0x100, DrvTempRom, DrvChars);
	
	// Load and decode the tiles
	memset(DrvTempRom, 0, 0x60000);
	nRet = BurnLoadRom(DrvTempRom + 0x00000, 4, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x08000, 5, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x10000, 6, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x18000, 7, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x20000, 8, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x28000, 9, 1); if (nRet != 0) return 1;
	GfxDecode(0x100, 3, 16, 16, Tile1PlaneOffsets, TileXOffsets, TileYOffsets, 0x200, DrvTempRom + 0x00000, DrvTiles + (0x000 * 16 * 16));
	GfxDecode(0x100, 3, 16, 16, Tile2PlaneOffsets, TileXOffsets, TileYOffsets, 0x200, DrvTempRom + 0x00000, DrvTiles + (0x100 * 16 * 16));
	GfxDecode(0x100, 3, 16, 16, Tile3PlaneOffsets, TileXOffsets, TileYOffsets, 0x200, DrvTempRom + 0x00000, DrvTiles + (0x200 * 16 * 16));
	GfxDecode(0x100, 3, 16, 16, Tile4PlaneOffsets, TileXOffsets, TileYOffsets, 0x200, DrvTempRom + 0x00000, DrvTiles + (0x300 * 16 * 16));
	GfxDecode(0x100, 3, 16, 16, Tile1PlaneOffsets, TileXOffsets, TileYOffsets, 0x200, DrvTempRom + 0x18000, DrvTiles + (0x400 * 16 * 16));
	GfxDecode(0x100, 3, 16, 16, Tile2PlaneOffsets, TileXOffsets, TileYOffsets, 0x200, DrvTempRom + 0x18000, DrvTiles + (0x500 * 16 * 16));
	GfxDecode(0x100, 3, 16, 16, Tile3PlaneOffsets, TileXOffsets, TileYOffsets, 0x200, DrvTempRom + 0x18000, DrvTiles + (0x600 * 16 * 16));
	GfxDecode(0x100, 3, 16, 16, Tile4PlaneOffsets, TileXOffsets, TileYOffsets, 0x200, DrvTempRom + 0x18000, DrvTiles + (0x700 * 16 * 16));
	
	// Load and decode the sprites
	memset(DrvTempRom, 0, 0x60000);
	nRet = BurnLoadRom(DrvTempRom + 0x00000, 10, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x08000, 11, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x10000, 12, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x18000, 13, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x20000, 14, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x28000, 15, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x30000, 16, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x38000, 17, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x40000, 18, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x48000, 19, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x50000, 20, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x58000, 21, 1); if (nRet != 0) return 1;
	GfxDecode(0x100, 3, 16, 16, Tile1PlaneOffsets, TileXOffsets, TileYOffsets, 0x200, DrvTempRom + 0x00000, DrvSprites + (0x000 * 16 * 16));
	GfxDecode(0x100, 3, 16, 16, Tile2PlaneOffsets, TileXOffsets, TileYOffsets, 0x200, DrvTempRom + 0x00000, DrvSprites + (0x100 * 16 * 16));
	GfxDecode(0x100, 3, 16, 16, Tile3PlaneOffsets, TileXOffsets, TileYOffsets, 0x200, DrvTempRom + 0x00000, DrvSprites + (0x200 * 16 * 16));
	GfxDecode(0x100, 3, 16, 16, Tile4PlaneOffsets, TileXOffsets, TileYOffsets, 0x200, DrvTempRom + 0x00000, DrvSprites + (0x300 * 16 * 16));
	GfxDecode(0x100, 3, 16, 16, Tile1PlaneOffsets, TileXOffsets, TileYOffsets, 0x200, DrvTempRom + 0x18000, DrvSprites + (0x400 * 16 * 16));
	GfxDecode(0x100, 3, 16, 16, Tile2PlaneOffsets, TileXOffsets, TileYOffsets, 0x200, DrvTempRom + 0x18000, DrvSprites + (0x500 * 16 * 16));
	GfxDecode(0x100, 3, 16, 16, Tile3PlaneOffsets, TileXOffsets, TileYOffsets, 0x200, DrvTempRom + 0x18000, DrvSprites + (0x600 * 16 * 16));
	GfxDecode(0x100, 3, 16, 16, Tile4PlaneOffsets, TileXOffsets, TileYOffsets, 0x200, DrvTempRom + 0x18000, DrvSprites + (0x700 * 16 * 16));
	GfxDecode(0x100, 3, 16, 16, Tile1PlaneOffsets, TileXOffsets, TileYOffsets, 0x200, DrvTempRom + 0x30000, DrvSprites + (0x800 * 16 * 16));
	GfxDecode(0x100, 3, 16, 16, Tile2PlaneOffsets, TileXOffsets, TileYOffsets, 0x200, DrvTempRom + 0x30000, DrvSprites + (0x900 * 16 * 16));
	GfxDecode(0x100, 3, 16, 16, Tile3PlaneOffsets, TileXOffsets, TileYOffsets, 0x200, DrvTempRom + 0x30000, DrvSprites + (0xa00 * 16 * 16));
	GfxDecode(0x100, 3, 16, 16, Tile4PlaneOffsets, TileXOffsets, TileYOffsets, 0x200, DrvTempRom + 0x30000, DrvSprites + (0xb00 * 16 * 16));
	GfxDecode(0x100, 3, 16, 16, Tile1PlaneOffsets, TileXOffsets, TileYOffsets, 0x200, DrvTempRom + 0x48000, DrvSprites + (0xc00 * 16 * 16));
	GfxDecode(0x100, 3, 16, 16, Tile2PlaneOffsets, TileXOffsets, TileYOffsets, 0x200, DrvTempRom + 0x48000, DrvSprites + (0xd00 * 16 * 16));
	GfxDecode(0x100, 3, 16, 16, Tile3PlaneOffsets, TileXOffsets, TileYOffsets, 0x200, DrvTempRom + 0x48000, DrvSprites + (0xe00 * 16 * 16));
	GfxDecode(0x100, 3, 16, 16, Tile4PlaneOffsets, TileXOffsets, TileYOffsets, 0x200, DrvTempRom + 0x48000, DrvSprites + (0xf00 * 16 * 16));
	
	// Load ADPCM Roms
	nRet = BurnLoadRom(DrvADPCMRom + 0x00000, 22, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvADPCMRom + 0x10000, 23, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvADPCMRom + 0x18000, 24, 1); if (nRet != 0) return 1;
		
	free(DrvTempRom);
	
	// Setup the M6502 emulation
	m6502Init(1);
	m6502Open(0);
	m6502MapMemory(DrvM6502Ram            , 0x0000, 0x17ff, M6502_RAM);
	m6502MapMemory(DrvVideoRam2           , 0x1800, 0x1fff, M6502_RAM);
	m6502MapMemory(DrvSpriteRam           , 0x2000, 0x27ff, M6502_RAM);
	m6502MapMemory(DrvVideoRam1           , 0x2800, 0x2fff, M6502_RAM);
	m6502MapMemory(DrvPaletteRam1         , 0x3000, 0x30ff, M6502_RAM);
	m6502MapMemory(DrvPaletteRam2         , 0x3100, 0x31ff, M6502_RAM);
	m6502MapMemory(DrvM6502Rom + 0x8000   , 0x4000, 0x7fff, M6502_ROM);
	m6502MapMemory(DrvM6502Rom            , 0x8000, 0xffff, M6502_ROM);
	m6502SetReadHandler(RenegadeReadByte);
	m6502SetWriteHandler(RenegadeWriteByte);
	m6502Close();
	
	// Setup the M6809 emulation
	M6809Init(1);
	M6809Open(0);
	M6809MapMemory(DrvM6809Ram          , 0x0000, 0x0fff, M6809_RAM);
	M6809MapMemory(DrvM6809Rom          , 0x8000, 0xffff, M6809_ROM);
	M6809SetReadByteHandler(RenegadeM6809ReadByte);
	M6809SetWriteByteHandler(RenegadeM6809WriteByte);
	M6809Close();
	
	if (nMcuType == MCU_TYPE_RENEGADE) {
		mcu_type = 0xda;
		mcu_encrypt_table = renegade_xor_table;
		mcu_encrypt_table_len = 0x37;
	}
	
	if (nMcuType == MCU_TYPE_KUNIOKUN) {
		mcu_type = 0x85;
		mcu_encrypt_table = kuniokun_xor_table;
		mcu_encrypt_table_len = 0x2a;
	}
	
	BurnYM3526Init(3000000, &DrvFMIRQHandler, &DrvSynchroniseStream, 1);
	BurnTimerAttachM6809YM3526(1500000);
	
	RenegadeADPCMInit(8000);
	
	GenericTilesInit();
	
	// Reset the driver
	DrvDoReset();

	return 0;
}

static int RenegadeInit()
{
	return DrvInit(MCU_TYPE_RENEGADE);
}

static int KuniokunInit()
{
	return DrvInit(MCU_TYPE_KUNIOKUN);
}

static int KuniokunbInit()
{
	return DrvInit(MCU_TYPE_NONE);
}

static int DrvExit()
{
	m6502Exit();
	M6809Exit();
	
	BurnYM3526Exit();
	
	GenericTilesExit();
	
	free(Mem);
	Mem = NULL;
	
	mcu_type = 0;
	mcu_encrypt_table = NULL;
	mcu_encrypt_table_len = 0;
	
	memset(mcu_buffer, 0, MCU_BUFFER_MAX);
	mcu_input_size = 0;
	mcu_output_byte = 0;
	mcu_key = 0;
	
	DrvRomBank = 0;
	DrvVBlank = 0;
	memset(DrvScrollX, 0, 2);
	DrvSoundLatch = 0;

	return 0;
}

static inline unsigned char pal4bit(unsigned char bits)
{
	bits &= 0x0f;
	return (bits << 4) | bits;
}

inline static unsigned int CalcCol(unsigned short nColour)
{
	int r, g, b;

	r = pal4bit(nColour >> 0);
	g = pal4bit(nColour >> 4);
	b = pal4bit(nColour >> 8);

	return BurnHighCol(r, g, b, 0);
}

static void DrvCalcPalette()
{
	for (int i = 0; i < 0x100; i++) {
		int Val = DrvPaletteRam1[i] + (DrvPaletteRam2[i] << 8);
		
		DrvPalette[i] = CalcCol(Val);
	}
}

static void DrvRenderBgLayer()
{
	int mx, my, Attr, Code, Colour, x, y, TileIndex = 0, xScroll;
	
	xScroll = DrvScrollX[0] + (DrvScrollX[1] << 8);
	xScroll &= 0x3ff;
	xScroll -= 256;

	for (my = 0; my < 16; my++) {
		for (mx = 0; mx < 64; mx++) {
			Attr = DrvVideoRam1[TileIndex + 0x400];
			Code = DrvVideoRam1[TileIndex + 0x000];
			Colour = Attr >> 5;
			
			x = 16 * mx;
			y = 16 * my;
			
			x -= xScroll;
			if (x < -16) x += 1024;
			
			x -= 8;

			if (x > 0 && x < 224 && y > 0 && y < 224) {
				Render16x16Tile(pTransDraw, Code, x, y, Colour, 3, 192, DrvTiles + ((Attr & 0x07) * 0x100 * 16 * 16));
			} else {
				Render16x16Tile_Clip(pTransDraw, Code, x, y, Colour, 3, 192, DrvTiles + ((Attr & 0x07) * 0x100 * 16 * 16));
			}

			TileIndex++;
		}
	}
}

static void DrvRenderSprites()
{
	UINT8 *Source = DrvSpriteRam;
	UINT8 *Finish = Source + 96 * 4;

	while (Source < Finish) {
		int sy = 240 - Source[0];

		if (sy >= 16) {
			int Attr = Source[1];
			int sx = Source[3];
			int Code = Source[2];
			int SpriteBank = Attr & 0xf;
			int Colour = (Attr >> 4) & 0x3;
			int xFlip = Attr & 0x40;

			if (sx > 248) sx -= 256;
			
			sx -= 8;

			if (Attr & 0x80) {
				Code &= ~1;
				if (sx > 16 && sx < 224 && (sy + 16) > 0 && (sy + 16) < 224) {
					if (xFlip) {
						Render16x16Tile_Mask_FlipX(pTransDraw, Code + 1, sx, sy + 16, Colour, 3, 0, 128, DrvSprites + (SpriteBank * 0x100 * 16 * 16));
					} else {
						Render16x16Tile_Mask(pTransDraw, Code + 1, sx, sy + 16, Colour, 3, 0, 128, DrvSprites + (SpriteBank * 0x100 * 16 * 16));
					}
				} else {
					if (xFlip) {
						Render16x16Tile_Mask_FlipX_Clip(pTransDraw, Code + 1, sx, sy + 16, Colour, 3, 0, 128, DrvSprites + (SpriteBank * 0x100 * 16 * 16));
					} else {
						Render16x16Tile_Mask_Clip(pTransDraw, Code + 1, sx, sy + 16, Colour, 3, 0, 128, DrvSprites + (SpriteBank * 0x100 * 16 * 16));
					}
				}
			} else {
				sy += 16;
			}
			
			if (sx > 16 && sx < 224 && sy > 0 && sy < 224) {
				if (xFlip) {
					Render16x16Tile_Mask_FlipX(pTransDraw, Code, sx, sy, Colour, 3, 0, 128, DrvSprites + (SpriteBank * 0x100 * 16 * 16));
				} else {
					Render16x16Tile_Mask(pTransDraw, Code, sx, sy, Colour, 3, 0, 128, DrvSprites + (SpriteBank * 0x100 * 16 * 16));
				}
			} else {
				if (xFlip) {
					Render16x16Tile_Mask_FlipX_Clip(pTransDraw, Code, sx, sy, Colour, 3, 0, 128, DrvSprites + (SpriteBank * 0x100 * 16 * 16));
				} else {
					Render16x16Tile_Mask_Clip(pTransDraw, Code, sx, sy, Colour, 3, 0, 128, DrvSprites + (SpriteBank * 0x100 * 16 * 16));
				}
			}
		}
		Source += 4;
	}
}

static void DrvRenderCharLayer()
{
	int mx, my, Attr, Code, Colour, x, y, TileIndex = 0;

	for (my = 0; my < 32; my++) {
		for (mx = 0; mx < 32; mx++) {
			Attr = DrvVideoRam2[TileIndex + 0x400];
			Code = ((Attr & 3) << 8) + DrvVideoRam2[TileIndex + 0x000];
			Colour = Attr >> 6;
			
			x = 8 * mx;
			y = 8 * my;
			
			x -= 8;

			if (x > 0 && x < 232 && y > 0 && y < 232) {
				Render8x8Tile_Mask(pTransDraw, Code, x, y, Colour, 3, 0, 0, DrvChars);
			} else {
				Render8x8Tile_Mask_Clip(pTransDraw, Code, x, y, Colour, 3, 0, 0, DrvChars);
			}

			TileIndex++;
		}
	}
}

static void DrvDraw()
{
	BurnTransferClear();
	DrvCalcPalette();
	DrvRenderBgLayer();
	DrvRenderSprites();
	DrvRenderCharLayer();	
	BurnTransferCopy(DrvPalette);
}

static void DrvInterrupt()
{
	static int Count;
	Count = !Count;
	if (Count) {
		m6502SetIRQ(M6502_NMI);
	} else {
		m6502SetIRQ(M6502_IRQ);
	}
}

static const int index_shift[8] = { -1, -1, -1, -1, 2, 4, 6, 8 };

INT16 clock_adpcm(struct adpcm_state *state, UINT8 nibble)
{
	state->signal += diff_lookup[state->step * 16 + (nibble & 15)];

	/* clamp to the maximum */
	if (state->signal > 2047)
		state->signal = 2047;
	else if (state->signal < -2048)
		state->signal = -2048;

	/* adjust the step size and clamp */
	state->step += index_shift[nibble & 7];
	if (state->step > 48)
		state->step = 48;
	else if (state->step < 0)
		state->step = 0;

	/* return the signal */
	return state->signal;
}

static void RenderADPCMSample(short *pSoundBuf, int nLength)
{
/*	while (renegade_adpcm.playing && nLength > 0) {
		int val = (renegade_adpcm.base[renegade_adpcm.current >> 12] >> renegade_adpcm.nibble) & 15;
		
		renegade_adpcm.nibble ^= 4;
		if (renegade_adpcm.nibble == 4) {
			renegade_adpcm.current += nUpdateStep;//++;
			if ((renegade_adpcm.current >> 12) >= renegade_adpcm.end) renegade_adpcm.playing = 0;
		}
		
		pSoundBuf[0] = clock_adpcm(&renegade_adpcm.adpcm, val) << 4;
		pSoundBuf[1] = clock_adpcm(&renegade_adpcm.adpcm, val) << 4;
		pSoundBuf += 2;
		nLength--;
	}*/
	while (nLength > 0) {
		pSoundBuf[0] = 0;
		pSoundBuf[1] = 0;
		pSoundBuf += 2;
		nLength--;
	}
}

static int DrvFrame()
{
	int nInterleave = nBurnSoundLen;
	int nSoundBufferPos = 0;
	
	if (DrvReset) DrvDoReset();

	DrvMakeInputs();

	nCyclesTotal[0] = (12000000 / 8) / 60;
	nCyclesTotal[1] = (12000000 / 8) / 60;
	
	int nCyclesDone[2] = { 0, 0 };
	int nCyclesSegment;
	
	DrvVBlank = 0;
	
	M6809NewFrame();

	for (int i = 0; i < nInterleave; i++) {
		int nCurrentCPU, nNext;
		
		m6502Open(0);
		nCurrentCPU = 0;
		nNext = (i + 1) * nCyclesTotal[nCurrentCPU] / nInterleave;
		nCyclesSegment = nNext - nCyclesDone[nCurrentCPU];
		nCyclesDone[nCurrentCPU] += m6502Run(nCyclesSegment);
		if (i == ((nInterleave / 10) * 7)) DrvVBlank = 1;
		if (i == (nInterleave / 2) || i == ((nInterleave / 10) * 9)) DrvInterrupt();
		m6502Close();
		
		M6809Open(0);
		BurnTimerUpdateYM3526(i * (nCyclesTotal[1] / nInterleave));
		M6809Close();
		
		if (pBurnSoundOut) {
			int nSegmentLength = nBurnSoundLen / nInterleave;
			short* pSoundBuf = pBurnSoundOut + (nSoundBufferPos << 1);
			RenderADPCMSample(pSoundBuf, nSegmentLength);
			nSoundBufferPos += nSegmentLength;
		}
	}
	
	M6809Open(0);
	BurnTimerEndFrameYM3526(nCyclesTotal[1]);
	M6809Close();
	
	if (pBurnSoundOut) {
		int nSegmentLength = nBurnSoundLen - nSoundBufferPos;
		short* pSoundBuf = pBurnSoundOut + (nSoundBufferPos << 1);

		if (nSegmentLength) {
			RenderADPCMSample(pSoundBuf, nSegmentLength);
		}
	}
	
	M6809Open(0);
	BurnYM3526Update(pBurnSoundOut, nBurnSoundLen);
	M6809Close();
	
	if (pBurnDraw) DrvDraw();

	return 0;
}


static int DrvScan(int nAction, int *pnMin)
{
	struct BurnArea ba;
	
	if (pnMin != NULL) {			// Return minimum compatible version
		*pnMin = 0x029696;
	}

	if (nAction & ACB_MEMORY_RAM) {
		memset(&ba, 0, sizeof(ba));
		ba.Data	  = RamStart;
		ba.nLen	  = RamEnd-RamStart;
		ba.szName = "All Ram";
		BurnAcb(&ba);
	}

	return 0;
}

struct BurnDriver BurnDrvRenegade = {
	"renegade", NULL, NULL, "1986",
	"Renegade (US)\0", NULL, "Technos (Taito America license)", "Miscellaneous",
	NULL, NULL, NULL, NULL,
	BDF_GAME_WORKING, 2, HARDWARE_MISC_PRE90S, GBF_SCRFIGHT, 0,
	NULL, DrvRomInfo, DrvRomName, DrvInputInfo, DrvDIPInfo,
	RenegadeInit, DrvExit, DrvFrame, NULL, DrvScan,
	0, NULL, NULL, NULL, NULL, 0x100, 240, 240, 4, 3
};

struct BurnDriver BurnDrvKuniokun = {
	"kuniokun", "renegade", NULL, "1986",
	"Nekketsu Kouha Kunio-kun (Japan)\0", NULL, "Technos", "Miscellaneous",
	NULL, NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_CLONE, 2, HARDWARE_MISC_PRE90S, GBF_SCRFIGHT, 0,
	NULL, DrvjRomInfo, DrvjRomName, DrvInputInfo, DrvDIPInfo,
	KuniokunInit, DrvExit, DrvFrame, NULL, DrvScan,
	0, NULL, NULL, NULL, NULL, 0x100, 240, 240, 4, 3
};

struct BurnDriver BurnDrvKuniokunb = {
	"kuniokunb", "renegade", NULL, "1986",
	"Nekketsu Kouha Kunio-kun (Japan bootleg)\0", NULL, "bootleg", "Miscellaneous",
	NULL, NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_CLONE | BDF_BOOTLEG, 2, HARDWARE_MISC_PRE90S, GBF_SCRFIGHT, 0,
	NULL, DrvbRomInfo, DrvbRomName, DrvInputInfo, DrvDIPInfo,
	KuniokunbInit, DrvExit, DrvFrame, NULL, DrvScan,
	0, NULL, NULL, NULL, NULL, 0x100, 240, 240, 4, 3
};
