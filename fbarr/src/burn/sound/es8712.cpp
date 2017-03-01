/**********************************************************************************************
 *
 *  Streaming singe channel ADPCM core for the ES8712 chip
 *  Chip is branded by Excellent Systems, probably OEM'd.
 *
 *  Samples are currently looped, but whether they should and how, is unknown.
 *  Interface to the chip is also not 100% clear.
 *  Should there be any status signals signifying busy, end of sample - etc?
 *
 *  Heavily borrowed from the OKI M6295 source
 *
 *  Excellent Systems ADPCM Emulation
 *  Copyright Nicola Salmoria and the MAME Team
 *
 *  From MAME 0.139u1. Modified for use in FBA Aug 23, 2010.
 *
 **********************************************************************************************/

#include "burnint.h"
#include "math.h"
#include "es8712.h"

#define MAX_ES8712_CHIPS	1

#define MAX_SAMPLE_CHUNK	10000

/* struct describing a playing ADPCM chip */
typedef struct _es8712_state es8712_state;
struct _es8712_state
{
	UINT8 playing;			/* 1 if we're actively playing */

	UINT32 base_offset;		/* pointer to the base memory location */
	UINT32 sample;			/* current sample number */
	UINT32 count;			/* total samples to play */

	UINT32 signal;			/* current ADPCM signal */
	UINT32 step;			/* current ADPCM step */

	UINT32 start;			/* starting address for the next loop */
	UINT32 end;				/* ending address for the next loop */
	UINT8  repeat;			/* Repeat current sample when 1 */

	INT32 bank_offset;

// non volatile
	UINT8 *region_base;		/* pointer to the base of the region */

	int sample_rate;		/* samples per frame */
	int volume;			/* set gain */
	int addSignal;			/* add signal to stream? */
};

static short *tbuf[MAX_ES8712_CHIPS] = { NULL };

static _es8712_state chips[MAX_ES8712_CHIPS];
static _es8712_state *chip;

static const int index_shift[8] = { -1, -1, -1, -1, 2, 4, 6, 8 };
static int diff_lookup[49*16];

/**********************************************************************************************

     compute_tables -- compute the difference tables

***********************************************************************************************/

static void compute_tables()
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
		int stepval = (int)(floor(16.0 * pow(11.0 / 10.0, (double)step)));

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
}


/**********************************************************************************************

    generate_adpcm -- general ADPCM decoding routine

***********************************************************************************************/

static void generate_adpcm(short *buffer, int samples)
{
	/* if this chip is active */
	if (chip->playing)
	{
		UINT8 *base = chip->region_base + chip->bank_offset + chip->base_offset;
		int sample = chip->sample;
		int signal = chip->signal;
		int count = chip->count;
		int step = chip->step;
		int volume = chip->volume;
		int val;

		/* loop while we still have samples to generate */
		while (samples)
		{
			/* compute the new amplitude and update the current step */
			val = base[sample / 2] >> (((sample & 1) << 2) ^ 4);
			signal += diff_lookup[step * 16 + (val & 15)];

			/* clamp to the maximum */
			if (signal > 2047)
				signal = 2047;
			else if (signal < -2048)
				signal = -2048;

			/* adjust the step size and clamp */
			step += index_shift[val & 7];
			if (step > 48)
				step = 48;
			else if (step < 0)
				step = 0;

			/* output to the buffer */
			*buffer++ = (signal * 16 * volume) / 100;
			samples--;

			/* next! */
			if (++sample >= count)
			{
				if (chip->repeat)
				{
					sample = 0;
					signal = -2;
					step = 0;
				}
				else
				{
					chip->playing = 0;
					break;
				}
			}
		}

		/* update the parameters */
		chip->sample = sample;
		chip->signal = signal;
		chip->step = step;
	}

	/* fill the rest with silence */
	while (samples--)
		*buffer++ = 0;
}


/**********************************************************************************************

    es8712Update -- update the sound chip so that it is in sync with CPU execution

***********************************************************************************************/

void es8712Update(int device, short *buffer, int samples)
{
	if (device >= MAX_ES8712_CHIPS) return;

	chip = &chips[device];

	int sample_num = (int)((float)(((samples / nBurnSoundLen) * 1.0000) * chip->sample_rate));

	float step = ((chip->sample_rate * 1.00000) / nBurnSoundLen);

	short *buf = tbuf[device];

	generate_adpcm(buf, sample_num);

	float r = 0;
	if (chip->addSignal) {
		for (int i = 0; i < samples; i++, r += step, buffer+=2) {
			buffer[0] += buf[(int)r];
			buffer[1] += buf[(int)r];
		}
	} else {
		for (int i = 0; i < samples; i++, r += step, buffer+=2) {
			buffer[0] = buffer[1] = buf[(int)r];
		}
	}
}


/**********************************************************************************************

    es8712Init -- start emulation of an ES8712 chip

***********************************************************************************************/

void es8712Init(int device, unsigned char *rom, int sample_rate, float volume, int addSignal)
{
	if (device >= MAX_ES8712_CHIPS) return;

	chip = &chips[device];

	compute_tables();

	chip->start = 0;
	chip->end = 0;
	chip->repeat = 0;

	chip->bank_offset = 0;
	chip->region_base = (UINT8*)rom;

	/* initialize the rest of the structure */
	chip->signal = (UINT32)-2;

	chip->sample_rate = sample_rate;

	chip->volume = (int)(volume+0.5);
	chip->addSignal = addSignal;

	if (tbuf[device] == NULL) {
		tbuf[device] = (short*)malloc(sample_rate * sizeof(short));
	}
}

/**********************************************************************************************

    es8712Exit -- stop emulation of an ES8712 chip

***********************************************************************************************/

void es8712Exit(int device)
{
	if (device >= MAX_ES8712_CHIPS) return;

	chip = &chips[device];

	memset (chip, 0, sizeof(_es8712_state));

	if (tbuf[device] != NULL) {
		free (tbuf[device]);
		tbuf[device] = NULL;
	}
}

/*************************************************************************************

     es8712Reset -- stop emulation of an ES8712-compatible chip

**************************************************************************************/

void es8712Reset(int device)
{
	if (device >= MAX_ES8712_CHIPS) return;

	chip = &chips[device];

	if (chip->playing)
	{
		/* update the stream, then turn it off */
		chip->playing = 0;
		chip->repeat = 0;
	}
}


/****************************************************************************

    es8712_set_bank_base -- set the base of the bank on a given chip

*****************************************************************************/

void es8712SetBankBase(int device, int base)
{
	if (device >= MAX_ES8712_CHIPS) return;

	chip = &chips[device];

	chip->bank_offset = base;
}


/**********************************************************************************************

    es8712Play -- Begin playing the addressed sample

***********************************************************************************************/

void es8712Play(int device)
{
	if (device >= MAX_ES8712_CHIPS) return;

	chip = &chips[device];

	if (chip->start < chip->end)
	{
		if (!chip->playing)
		{
			chip->playing = 1;
			chip->base_offset = chip->start;
			chip->sample = 0;
			chip->count = 2 * (chip->end - chip->start + 1);
			chip->repeat = 0;//1;

			/* also reset the ADPCM parameters */
			chip->signal = (UINT32)-2;
			chip->step = 0;
		}
	}
	/* invalid samples go here */
	else
	{
		if (chip->playing)
		{
			/* update the stream */
			chip->playing = 0;
		}
	}
}


/**********************************************************************************************

     es8712Write -- generic data write function

***********************************************************************************************/

/**********************************************************************************************
 *
 *  offset  Start       End
 *          0hmmll  -  0HMMLL
 *    00    ----ll
 *    01    --mm--
 *    02    0h----
 *    03               ----LL
 *    04               --MM--
 *    05               0H----
 *    06           Go!
 *
 * Offsets are written in the order -> 00, 02, 01, 03, 05, 04, 06
 * Offset 06 is written with the same value as offset 04.
 *
***********************************************************************************************/

void es8712Write(int device, int offset, unsigned char data)
{
	if (device >= MAX_ES8712_CHIPS) return;

	chip = &chips[device];

	switch (offset)
	{
		case 00:	chip->start &= 0x000fff00;
					chip->start |= ((data & 0xff) <<  0); break;
		case 01:	chip->start &= 0x000f00ff;
					chip->start |= ((data & 0xff) <<  8); break;
		case 02:	chip->start &= 0x0000ffff;
					chip->start |= ((data & 0x0f) << 16); break;
		case 03:	chip->end   &= 0x000fff00;
					chip->end   |= ((data & 0xff) <<  0); break;
		case 04:	chip->end   &= 0x000f00ff;
					chip->end   |= ((data & 0xff) <<  8); break;
		case 05:	chip->end   &= 0x0000ffff;
					chip->end   |= ((data & 0x0f) << 16); break;
		case 06:
				es8712Play(device);
				break;
		default:	break;
	}

	chip->start &= 0xfffff;
	chip->end &= 0xfffff;
}


/**********************************************************************************************

     es8712Scan -- save state function

***********************************************************************************************/

int es8712Scan(int device, int nAction)
{
	if (device >= MAX_ES8712_CHIPS) return 1;

	if (nAction & ACB_DRIVER_DATA) {
		chip = &chips[device];

		SCAN_VAR(chip->playing);
		SCAN_VAR(chip->base_offset);
		SCAN_VAR(chip->sample);
		SCAN_VAR(chip->count);
		SCAN_VAR(chip->signal);
		SCAN_VAR(chip->step);
		SCAN_VAR(chip->start);
		SCAN_VAR(chip->end);
		SCAN_VAR(chip->repeat);
		SCAN_VAR(chip->bank_offset);
	}

	return 0;
}
