#include "burnint.h"
#include "konamiic.h"

unsigned int KonamiIC_K051960InUse = 0;
unsigned int KonamiIC_K052109InUse = 0;
unsigned int KonamiIC_K051316InUse = 0;
unsigned int KonamiIC_K053245InUse = 0;
unsigned int KonamiIC_K053247InUse = 0;

unsigned char K052109_051960_r(int offset)
{
	if (K052109RMRDLine == 0)
	{
		if (offset >= 0x3800 && offset < 0x3808)
			return K051937Read(offset - 0x3800);
		else if (offset < 0x3c00)
			return K052109Read(offset);
		else
			return K051960Read(offset - 0x3c00);
	}
	else return K052109Read(offset);
}

void K052109_051960_w(int offset, int data)
{
	if (offset >= 0x3800 && offset < 0x3808)
		K051937Write(offset - 0x3800,data);
	else if (offset < 0x3c00)
		K052109Write(offset,         data);
	else
		K051960Write(offset - 0x3c00,data);
}

static void shuffle(unsigned short *buf, int len)
{
	if (len == 2 || len & 3) return;

	len >>= 1;

	for (int i = 0; i < len/2; i++)
	{
		int t = buf[len/2 + i];
		buf[len/2 + i] = buf[len + i];
		buf[len + i] = t;
	}

	shuffle(buf,       len);
	shuffle(buf + len, len);
}

void konami_rom_deinterleave_2(unsigned char *src, int len)
{
	shuffle((unsigned short*)src,len/2);
}

void konami_rom_deinterleave_4(unsigned char *src, int len)
{
	konami_rom_deinterleave_2(src, len);
	konami_rom_deinterleave_2(src, len);
}

// xbbbbbgggggrrrrr (used mostly by Konami-custom cpu games)
void KonamiRecalcPal(unsigned char *src, unsigned int *dst, int len)
{
	unsigned char r,g,b;
	unsigned short *p = (unsigned short*)src;
	for (int i = 0; i < len / 2; i++) {
		unsigned short d = (p[i] << 8) | (p[i] >> 8);

		b = (d >> 10) & 0x1f;
		g = (d >>  5) & 0x1f;
		r = (d >>  0) & 0x1f;

		r = (r << 3) | (r >> 2);
		g = (g << 3) | (g >> 2);
		b = (b << 3) | (b >> 2);

		dst[i] = BurnHighCol(r, g, b, 0);
	}
}

void KonamiICReset()
{
	if (KonamiIC_K051960InUse) K051960Reset();
	if (KonamiIC_K052109InUse) K052109Reset();
	if (KonamiIC_K051316InUse) K051316Reset();
	if (KonamiIC_K053245InUse) K053245Reset();
	if (KonamiIC_K053247InUse) K053247Reset();

	// No init's, so always reset these
	K053251Reset();
	K054000Reset();
	K051733Reset();
}

void KonamiICExit()
{
	if (KonamiIC_K051960InUse) K051960Exit();
	if (KonamiIC_K052109InUse) K052109Exit();
	if (KonamiIC_K051316InUse) K051316Exit();
	if (KonamiIC_K053245InUse) K053245Exit();
	if (KonamiIC_K053247InUse) K053247Exit();

	KonamiIC_K051960InUse = 0;
	KonamiIC_K052109InUse = 0;
	KonamiIC_K051316InUse = 0;
	KonamiIC_K053245InUse = 0;
	KonamiIC_K053247InUse = 0;
}

void KonamiICScan(int nAction)
{
	if (KonamiIC_K051960InUse) K051960Scan(nAction);
	if (KonamiIC_K052109InUse) K052109Scan(nAction);
	if (KonamiIC_K051316InUse) K051316Scan(nAction);
	if (KonamiIC_K053245InUse) K053245Scan(nAction);
	if (KonamiIC_K053247InUse) K053247Scan(nAction);

	K053251Scan(nAction);
	K054000Scan(nAction);
	K051733Scan(nAction);
}
