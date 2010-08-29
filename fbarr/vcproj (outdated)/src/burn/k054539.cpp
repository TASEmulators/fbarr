/*********************************************************

    Konami 054539 PCM Sound Chip

    A lot of information comes from Amuse.
    Big thanks to them.

*********************************************************/

// IRQ handling is disabled for now...

#include "burnint.h"
#include "math.h"
#include "k054539.h"

static unsigned int nUpdateStep;

typedef struct _k054539_interface k054539_interface;
struct _k054539_interface
{
	const char *rgnoverride;
	void (*apan)(double, double);
//	void (*irq)(running_machine *);
};

struct k054539_channel {
	UINT32 pos;
	UINT32 pfrac;
	INT32 val;
	INT32 pval;
};

struct k054539_info {
	const k054539_interface *intf;
	double voltab[256];
	double pantab[0xf];

	double k054539_gain[8];
	UINT8 k054539_posreg_latch[8][3];
	int k054539_flags;

	unsigned char regs[0x230];
	unsigned char *ram;
	int reverb_pos;

	INT32 cur_ptr;
	int cur_limit;
	unsigned char *cur_zone;
	unsigned char *rom;
	UINT32 rom_size;
	UINT32 rom_mask;

	int clock;

	k054539_channel channels[8];
};

static k054539_info Chips[2];
static k054539_info *info;

static int *soundbuf[2];

void K054539_init_flags(int chip, int flags)
{
	info = &Chips[chip];
	info->k054539_flags = flags;
}

void K054539_set_gain(int chip, int channel, double gain)
{
	info = &Chips[chip];
	if (gain >= 0) info->k054539_gain[channel] = gain;
}

static int k054539_regupdate()
{
	return !(info->regs[0x22f] & 0x80);
}

static void k054539_keyon(int channel)
{
	if(k054539_regupdate())
		info->regs[0x22c] |= 1 << channel;
}

static void k054539_keyoff(int channel)
{
	if(k054539_regupdate())
		info->regs[0x22c] &= ~(1 << channel);
}

void K054539Write(int chip, int offset, unsigned char data)
{
	info = &Chips[chip];

	int latch, offs, ch, pan;
	unsigned char *regbase, *regptr, *posptr;

	regbase = info->regs;
	latch = (info->k054539_flags & K054539_UPDATE_AT_KEYON) && (regbase[0x22f] & 1);

	if (latch && offset < 0x100)
	{
		offs = (offset & 0x1f) - 0xc;
		ch = offset >> 5;

		if (offs >= 0 && offs <= 2)
		{
			// latch writes to the position index registers
			info->k054539_posreg_latch[ch][offs] = data;
			return;
		}
	}

	else switch(offset)
	{
		case 0x13f:
			pan = data >= 0x11 && data <= 0x1f ? data - 0x11 : 0x18 - 0x11;
			if(info->intf->apan)
				info->intf->apan(info->pantab[pan], info->pantab[0xe - pan]);
		break;

		case 0x214:
			if (latch)
			{
				for(ch=0; ch<8; ch++)
				{
					if(data & (1<<ch))
					{
						posptr = &info->k054539_posreg_latch[ch][0];
						regptr = regbase + (ch<<5) + 0xc;

						// update the chip at key-on
						regptr[0] = posptr[0];
						regptr[1] = posptr[1];
						regptr[2] = posptr[2];

						k054539_keyon(ch);
					}
				}
			}
			else
			{
				for(ch=0; ch<8; ch++)
					if(data & (1<<ch))
						k054539_keyon(ch);
			}
		break;

		case 0x215:
			for(ch=0; ch<8; ch++)
				if(data & (1<<ch))
					k054539_keyoff(ch);
		break;

		case 0x22d:
			if(regbase[0x22e] == 0x80)
				info->cur_zone[info->cur_ptr] = data;
			info->cur_ptr++;
			if(info->cur_ptr == info->cur_limit)
				info->cur_ptr = 0;
		break;

		case 0x22e:
			info->cur_zone =
				data == 0x80 ? info->ram :
				info->rom + 0x20000*data;
			info->cur_limit = data == 0x80 ? 0x4000 : 0x20000;
			info->cur_ptr = 0;
		break;

		default:
		break;
	}

	regbase[offset] = data;
}

unsigned char K054539Read(int chip, int offset)
{
	info = &Chips[chip];

	switch(offset) {
	case 0x22d:
		if(info->regs[0x22f] & 0x10) {
			UINT8 res = info->cur_zone[info->cur_ptr];
			info->cur_ptr++;
			if(info->cur_ptr == info->cur_limit)
				info->cur_ptr = 0;
			return res;
		} else
			return 0;

	case 0x22c:
		break;

	default:
		break;
	}

	return info->regs[offset];
}

void K054539Reset(int chip)
{
	info = &Chips[chip];
	int data = info->regs[0x22e];
	info->cur_zone =
		data == 0x80 ? info->ram :
		info->rom + 0x20000*data;
	info->cur_limit = data == 0x80 ? 0x4000 : 0x20000;
}

static void k054539_init_chip(int clock, unsigned char *rom, int nLen)
{
	int i;

	memset(info->regs, 0, sizeof(info->regs));
	memset(info->k054539_posreg_latch, 0, sizeof(info->k054539_posreg_latch));
	info->k054539_flags |= K054539_UPDATE_AT_KEYON; // make it default until proven otherwise

	// Real size of 0x4000, the addon is to simplify the reverb buffer computations
	info->ram = (unsigned char*)malloc(0x4000*2+clock/50*2);
	info->reverb_pos = 0;
	info->cur_ptr = 0;
	memset(info->ram, 0, 0x4000*2+clock/50*2);

	info->rom = rom;
	info->rom_size = nLen;
	info->rom_mask = 0xffffffffU;
	for(i=0; i<32; i++)
		if((1U<<i) >= info->rom_size) {
			info->rom_mask = (1U<<i) - 1;
			break;
		}

//	if(info->intf->irq)
//		timer_pulse(ATTOTIME_IN_HZ(480), info, 0, k054539_irq); // 10% of usual clock...
}

void K054539Init(int chip, int clock, unsigned char *rom, int nLen)
{
	static const k054539_interface defintrf = { 0, 0 };
	int i;

	info = &Chips[chip];

	info->intf = &defintrf;
	info->clock = clock;

	nUpdateStep = (int)(((float)clock / nBurnSoundRate) * 32768);

	for (i = 0; i < 8; i++)
		info->k054539_gain[i] = 1.0;

	info->k054539_flags = K054539_RESET_FLAGS;

	for(i=0; i<256; i++)
		info->voltab[i] = pow(10.0, (-36.0 * (double)i / (double)0x40) / 20.0) / 4.0;

	for(i=0; i<0xf; i++)
		info->pantab[i] = sqrt((double)i)  / sqrt((double)0xe);

	k054539_init_chip(clock, rom, nLen);

	if (soundbuf[0] == NULL) soundbuf[0] = (int*)malloc(nBurnSoundLen * sizeof(int));
	if (soundbuf[1] == NULL) soundbuf[1] = (int*)malloc(nBurnSoundLen * sizeof(int));
}

void K054539Exit()
{
	if (soundbuf[0] != NULL) {
		free (soundbuf[0]);
		soundbuf[0] = NULL;
	}

	if (soundbuf[1] != NULL) {
		free (soundbuf[1]);
		soundbuf[1] = NULL;
	}

	for (int i = 0; i < 2; i++) {
		info = &Chips[i];
		if (info->ram) {
			free (info->ram);
			info->ram = NULL;
		}
	}
}

void K054539Update(int chip, short *pBuf, int length)
{
	info = &Chips[chip];
#define VOL_CAP 1.80

	static const INT16 dpcm[16] = {
		0<<8, 1<<8, 4<<8, 9<<8, 16<<8, 25<<8, 36<<8, 49<<8,
		-64<<8, -49<<8, -36<<8, -25<<8, -16<<8, -9<<8, -4<<8, -1<<8
	};

	int ch, reverb_pos;
	short *rbase;
	unsigned char *samples;
	UINT32 rom_mask;

	unsigned char *base1, *base2;
	struct k054539_channel *chan;
	int *bufl, *bufr;
	int cur_pos, cur_pfrac, cur_val, cur_pval;
	int delta, rdelta, fdelta, pdelta;
	int vol, bval, pan, i;

	double gain, lvol, rvol, rbvol;

	reverb_pos = info->reverb_pos;
	rbase = (short *)(info->ram);

	int **buffer = soundbuf;

	memset(buffer[0], 0, length*sizeof(*buffer[0]));
	memset(buffer[1], 0, length*sizeof(*buffer[1]));

	samples = info->rom;
	rom_mask = info->rom_mask;

	if(!(info->regs[0x22f] & 1)) return;

	info->reverb_pos = (reverb_pos + length) & 0x3fff;

	for(ch=0; ch<8; ch++)
		if(info->regs[0x22c] & (1<<ch)) {
			base1 = info->regs + 0x20*ch;
			base2 = info->regs + 0x200 + 0x2*ch;
			chan = info->channels + ch;
			delta = base1[0x00] | (base1[0x01] << 8) | (base1[0x02] << 16);

			vol = base1[0x03];

			bval = vol + base1[0x04];
			if (bval > 255) bval = 255;

			pan = base1[0x05];
// DJ Main: 81-87 right, 88 middle, 89-8f left
if (pan >= 0x81 && pan <= 0x8f)
pan -= 0x81;
else
			if (pan >= 0x11 && pan <= 0x1f) pan -= 0x11; else pan = 0x18 - 0x11;

			gain = info->k054539_gain[ch];

			lvol = info->voltab[vol] * info->pantab[pan] * gain;
			if (lvol > VOL_CAP) lvol = VOL_CAP;

			rvol = info->voltab[vol] * info->pantab[0xe - pan] * gain;
			if (rvol > VOL_CAP) rvol = VOL_CAP;

			rbvol= info->voltab[bval] * gain / 2;
			if (rbvol > VOL_CAP) rbvol = VOL_CAP;

			rdelta = (base1[6] | (base1[7] << 8)) >> 3;
//          rdelta = (reverb_pos + (int)((rdelta - 0x2000) * info->freq_ratio)) & 0x3fff;
			rdelta = (int)(rdelta + reverb_pos) & 0x3fff;

			cur_pos = (base1[0x0c] | (base1[0x0d] << 8) | (base1[0x0e] << 16)) & rom_mask;

			bufl = buffer[0];
			bufr = buffer[1];
//*

			if(base2[0] & 0x20) {
				delta = -delta;
				fdelta = +0x10000;
				pdelta = -1;
			} else {
				fdelta = -0x10000;
				pdelta = +1;
			}

			if(cur_pos != (int)chan->pos) {
				chan->pos = cur_pos;
				cur_pfrac = 0;
				cur_val = 0;
				cur_pval = 0;
			} else {
				cur_pfrac = chan->pfrac;
				cur_val = chan->val;
				cur_pval = chan->pval;
			}

#define UPDATE_CHANNELS																	\
			do {																		\
				*bufl++ += (INT16)(cur_val*lvol);										\
				*bufr++ += (INT16)(cur_val*rvol);										\
				rbase[rdelta++] += (INT16)(cur_val*rbvol);										\
				rdelta &= 0x3fff;										\
			} while(0)

			switch(base2[0] & 0xc) {
			case 0x0: { // 8bit pcm
				for(i=0; i<length; i++) {
					cur_pfrac += delta;
					while(cur_pfrac & ~0xffff) {
						cur_pfrac += fdelta;
						cur_pos += (pdelta * nUpdateStep) >> 15;

						cur_pval = cur_val;
						cur_val = (INT16)(samples[cur_pos] << 8);
						if(cur_val == (INT16)0x8000) {
							if(base2[1] & 1) {
								cur_pos = (base1[0x08] | (base1[0x09] << 8) | (base1[0x0a] << 16)) & rom_mask;
								cur_val = (INT16)(samples[cur_pos] << 8);
								if(cur_val != (INT16)0x8000)
									continue;
							}
							k054539_keyoff(ch);
							goto end_channel_0;
						}
					}

					UPDATE_CHANNELS;
				}
			end_channel_0:
				break;
			}
			case 0x4: { // 16bit pcm lsb first
				pdelta <<= 1;

				for(i=0; i<length; i++) {
					cur_pfrac += delta;
					while(cur_pfrac & ~0xffff) {
						cur_pfrac += fdelta;
						cur_pos += (pdelta * nUpdateStep) >> 15;

						cur_pval = cur_val;
						cur_val = (INT16)(samples[cur_pos] | samples[cur_pos+1]<<8);
						if(cur_val == (INT16)0x8000) {
							if(base2[1] & 1) {
								cur_pos = (base1[0x08] | (base1[0x09] << 8) | (base1[0x0a] << 16)) & rom_mask;
								cur_val = (INT16)(samples[cur_pos] | samples[cur_pos+1]<<8);
								if(cur_val != (INT16)0x8000)
									continue;
							}
							k054539_keyoff(ch);
							goto end_channel_4;
						}
					}

					UPDATE_CHANNELS;
				}
			end_channel_4:
				break;
			}
			case 0x8: { // 4bit dpcm
				cur_pos <<= 1;
				cur_pfrac <<= 1;
				if(cur_pfrac & 0x10000) {
					cur_pfrac &= 0xffff;
					cur_pos |= 1;
				}

				for(i=0; i<length; i++) {
					cur_pfrac += delta;
					while(cur_pfrac & ~0xffff) {
						cur_pfrac += fdelta;
						cur_pos += (pdelta * nUpdateStep) >> 15;

						cur_pval = cur_val;
						cur_val = samples[cur_pos>>1];
						if(cur_val == 0x88) {
							if(base2[1] & 1) {
								cur_pos = ((base1[0x08] | (base1[0x09] << 8) | (base1[0x0a] << 16)) & rom_mask) << 1;
								cur_val = samples[cur_pos>>1];
								if(cur_val != 0x88)
									goto next_iter;
							}
							k054539_keyoff(ch);
							goto end_channel_8;
						}
					next_iter:
						if(cur_pos & 1)
							cur_val >>= 4;
						else
							cur_val &= 15;
						cur_val = cur_pval + dpcm[cur_val];
						if(cur_val < -32768)
							cur_val = -32768;
						else if(cur_val > 32767)
							cur_val = 32767;
					}

					UPDATE_CHANNELS;
				}
			end_channel_8:
				cur_pfrac >>= 1;
				if(cur_pos & 1)
					cur_pfrac |= 0x8000;
				cur_pos >>= 1;
				break;
			}
			default:
				break;
			}
			chan->pos = cur_pos;
			chan->pfrac = cur_pfrac;
			chan->pval = cur_pval;
			chan->val = cur_val;
			if(k054539_regupdate()) {
				base1[0x0c] = cur_pos     & 0xff;
				base1[0x0d] = cur_pos>> 8 & 0xff;
				base1[0x0e] = cur_pos>>16 & 0xff;
			}
		}

	//* drivers should be given the option to disable reverb when things go terribly wrong
	if(!(info->k054539_flags & K054539_DISABLE_REVERB))
	{
		for(i=0; i<length; i++) {
			short val = rbase[(i+reverb_pos) & 0x3fff];
			buffer[0][i] += val;
			buffer[1][i] += val;
		}
	}

	for (int f = 0; f < length; f++) {
		if (buffer[0][f] >  32767) buffer[0][f] =  32767;
		if (buffer[0][f] < -32768) buffer[0][f] = -32768;
		
		if (buffer[1][f] >  32767) buffer[1][f] =  32767;
		if (buffer[1][f] < -32768) buffer[1][f] = -32768;

		pBuf[0] += buffer[0][f];
		pBuf[1] += buffer[1][f];
		pBuf += 2;
	}

	if(reverb_pos + length > 0x4000) {
		i = 0x4000 - reverb_pos;
		memset(rbase + reverb_pos, 0, i*2);
		memset(rbase, 0, (length-i)*2);
	} else
		memset(rbase + reverb_pos, 0, length*2);
}

int K054539Scan(int nAction)
{
	struct BurnArea ba;
	char szName[32];

	if ((nAction & ACB_DRIVER_DATA) == 0) {
		return 1;
	}

	for (int i = 0; i < 2; i++) {
		info = &Chips[i];

		sprintf(szName, "K054539 Latch %d", 0);
		ba.Data		= info->k054539_posreg_latch;
		ba.nLen		= 8*3;
		ba.nAddress = 0;
		ba.szName	= szName;
		BurnAcb(&ba);

		sprintf(szName, "K054539 Regs # %d", 0);
		ba.Data		= info->regs;
		ba.nLen		= 0x230;
		ba.nAddress = 0;
		ba.szName	= szName;
		BurnAcb(&ba);

		sprintf(szName, "K054539 Ram # %d", 0);
		ba.Data		= info->ram;
		ba.nLen		= 0x4000*2+info->clock/50*2;
		ba.nAddress = 0;
		ba.szName	= szName;
		BurnAcb(&ba);

		ba.Data		= &info->channels;
		ba.nLen		= sizeof(k054539_channel) * 8;
		ba.nAddress = 0;
		ba.szName	= szName;
		BurnAcb(&ba);

		SCAN_VAR(info->k054539_flags);
		SCAN_VAR(info->reverb_pos);
		SCAN_VAR(info->cur_ptr);
		SCAN_VAR(info->cur_limit);

		K054539Write(i, 0x22e, K054539Read(0, 0x22e));
	}

	return 0;
}
