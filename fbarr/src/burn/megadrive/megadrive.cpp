/********************************************************************************
 SEGA Genesis / Mega Drive Driver for FBA 
 ********************************************************************************
 This is part of Pico Library v0936

 (c) Copyright 2004 Dave, All rights reserved.
 (c) Copyright 2006 notaz, All rights reserved.
 Free for non-commercial use.

 For commercial use, separate licencing terms must be obtained. 
 ********************************************************************************

 PicoOpt bits LSb->MSb:
 enable_ym2612&dac, enable_sn76496, enable_z80, stereo_sound,
 alt_renderer, 6button_gamepad, accurate_timing, accurate_sprites,
 draw_no_32col_border, external_ym2612

 ********************************************************************************
 Port by OopsWare
 ********************************************************************************/

#include "burnint.h"
#include "burn_ym2612.h"
#include "sn76496.h"

#define OSC_NTSC 53693175
#define OSC_PAL  53203424

#define MAX_CARTRIDGE_SIZE	0xc00000
#define MAX_SRAM_SIZE		0x010000

static int cycles_68k, cycles_z80;

typedef void (*MegadriveCb)();
static MegadriveCb MegadriveCallback;

struct PicoVideo {
	unsigned char reg[0x20];
	unsigned int command;		// 32-bit Command
	unsigned char pending;		// 1 if waiting for second half of 32-bit command
	unsigned char type;			// Command type (v/c/vsram read/write)
	unsigned short addr;		// Read/Write address
	int status;					// Status bits
	unsigned char pending_ints;	// pending interrupts: ??VH????
	unsigned char pad[0x13];	//
};

struct PicoMisc {
	unsigned int Z80Run;
	unsigned int Bank68k;
	unsigned char Rotate;

	unsigned char Pad[3];
	
	unsigned int SRamReg;
	unsigned int SRamStart;
	unsigned int SRamEnd;
};

struct TileStrip
{
	int nametab; // Position in VRAM of name table (for this tile line)
	int line;    // Line number in pixels 0x000-0x3ff within the virtual tilemap 
	int hscroll; // Horizontal scroll value in pixels for the line
	int xmask;   // X-Mask (0x1f - 0x7f) for horizontal wraparound in the tilemap
	int *hc;     // cache for high tile codes and their positions
	int cells;   // cells (tiles) to draw (32 col mode doesn't need to update whole 320)
};

struct MegadriveJoyPad {
	unsigned short pad[2];
	unsigned char  padTHPhase[2];
	unsigned char  padDelay[2];
};

static unsigned char *Mem = NULL, *MemEnd = NULL;
static unsigned char *RamStart, *RamEnd;

static unsigned char *RomMain;
static unsigned char *Ssf2Rom;

static unsigned char *Ram68K;
static unsigned char *RamZ80;

static unsigned char *SRam;
static unsigned char *RamIO;

static unsigned short *RamPal;
static unsigned short *RamVid;
static unsigned short *RamSVid;
static struct PicoVideo *RamVReg;
static struct PicoMisc *RamMisc;
static struct MegadriveJoyPad *JoyPad;

unsigned short *MegadriveCurPal;

static unsigned char *HighCol;
static unsigned char *HighColFull;

static int *HighCacheA;
static int *HighCacheB;
static int *HighCacheS;
static int *HighPreSpr;
static char *HighSprZ;

unsigned char MegadriveReset = 0;
unsigned char bMegadriveRecalcPalette = 0;

unsigned char MegadriveJoy1[12] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
unsigned char MegadriveJoy2[12] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
unsigned char MegadriveDIP[2] = {0, 0};

static unsigned int RomSize = 0;
static unsigned int SRamSize = 0;

static int SpriteBlocks;

static int Scanline = 0;

static int Z80HasBus = 0;
static int MegadriveZ80Reset = 0;
static int RomNoByteswap;

static unsigned char Hardware;
static unsigned char DrvSECAM = 0;	// NTSC 

// .bin format
static void Byteswap(unsigned char *data, int len)
{
	for(int i=0;i<len;i+=2) {
		unsigned char c = data[i];
		data[i] = data[i+1];
		data[i+1] = c;
	}
}

void MegadriveCheckHardware()
{
	Hardware = MegadriveDIP[0] & 0xe0;
	if (MegadriveDIP[0] & 0x01) {
		// Auto Detect Region and SECAM
		unsigned int support = 0;
		for (int i = 0; i < 4; i++) {
			unsigned int v = RomMain[0x1f0 + i];
			if (v <= 0x20) continue;

			switch (v) {
				case 0x30:
				case 0x31:
				case 0x32:
				case 0x33:
				case 0x34:
				case 0x35:
				case 0x36:
				case 0x37:
				case 0x38:
				case 0x39: {
					support |= v - 0x30;
					break;
				}
				
				case 0x41:
				case 0x42:
				case 0x43:
				case 0x44:
				case 0x46: {
					support |= v - 0x41;
					break;
				}
				
				case 0x45: {
					// Japan
					support |= 0x08;
					break;
				}
				
				case 0x4a: {
					// Europe
					support |= 0x01;
					break;
				}
				
				case 0x55: {
					// USA
					support |= 0x04;
					break;
				}
				
				case 0x61:
				case 0x62:
				case 0x63:
				case 0x64:
				case 0x65:
				case 0x66: {
					support |= v - 0x61;
					break;
				}
			}
		}

		bprintf(PRINT_IMPORTANT, _T("Autodetecting Cartridge (Hardware Code: %02x%02x%02x%02x):\n"), RomMain[0x1f0], RomMain[0x1f1], RomMain[0x1f2], RomMain[0x1f3]);
		Hardware = 0x80;
		
		if (support & 0x02) {
			Hardware = 0x40; // Japan PAL
			bprintf(PRINT_IMPORTANT, _T("Japan PAL supported ???\n"));
		}
		
		if (support & 0x01) {
			Hardware = 0x00; // Japan NTSC
			bprintf(PRINT_IMPORTANT, _T("Japan NTSC supported\n"));
		}		
		
		if (support & 0x08) {
			Hardware = 0xc0; // Europe PAL
			bprintf(PRINT_IMPORTANT, _T("Europe PAL supported\n"));
		}
		
		if (support & 0x04) {
			Hardware = 0x80; // USA NTSC
			bprintf(PRINT_IMPORTANT, _T("USA NTSC supported\n"));
		}
		
		if ((Hardware & 0xc0) == 0xc0) {
			bprintf(PRINT_IMPORTANT, _T("Emulating Europe PAL Machine\n"));
		} else {
			if ((Hardware & 0x80) == 0x80) {
				bprintf(PRINT_IMPORTANT, _T("Emulating USA NTSC Machine\n"));
			} else {
				if ((Hardware & 0x40) == 0x40) {
					bprintf(PRINT_IMPORTANT, _T("Emulating Japan PAL Machine ???\n"));
				} else {
					if ((Hardware & 0x00) == 0x00) {
						bprintf(PRINT_IMPORTANT, _T("Emulating Japan NTSC Machine\n"));
					}
				}
			}
		}
		
		// CD-ROM
		Hardware |= MegadriveDIP[0] & 0x20;
	}
	
	if ((Hardware & 0x20) != 0x20) bprintf(PRINT_IMPORTANT, _T("Emulating Mega-CD Add-on\n"));

	SRamSize = 0;
	RamMisc->SRamReg = 0;
	RamMisc->SRamStart = 0;
	RamMisc->SRamEnd = 0;
	
	if (RomMain[0x1b0] == 0x41 && RomMain[0x1b1] == 0x52) {
		SekOpen(0);
		if (RomMain[0x1b2] & 0x40) {
			// EEPROM
			RamMisc->SRamStart = SekReadLong(0x1b4) & ~0x01;
			RamMisc->SRamEnd = SekReadLong(0x1b8);
			SRamSize = 0x2000;
			RamMisc->SRamReg = 0x04;
		} else {
			RamMisc->SRamStart = SekReadLong(0x1B4) & 0xFFFF00;
			RamMisc->SRamEnd = SekReadLong(0x1B8);
			SRamSize = RamMisc->SRamEnd - RamMisc->SRamStart + 1;
		}
		SekClose();
		RamMisc->SRamReg |= 0x10;
		bprintf(PRINT_IMPORTANT, _T("SRAM Detected: Start %06x, End %06x\n"), RamMisc->SRamStart, RamMisc->SRamEnd);
	}
	
//	if (SRamSize <= 0 || SRamSize > MAX_SRAM_SIZE) {
//		RamMisc->SRamStart = 0x200000;
//		RamMisc->SRamEnd   = 0x203fff;
//		SRamSize  = 0x4000;
//	}
	
	// If SRAM region doesn't overlap ROM then enable it
//	if (RomSize <= RamMisc->SRamStart) {
//		RamMisc->SRamReg |= 0x01;
//		bprintf(PRINT_IMPORTANT, _T("Enabling SRAM Region: Start %06x, End %06x\n"), RamMisc->SRamStart, RamMisc->SRamEnd);
//		SekOpen(0);
//		SekMapMemory(SRam, RamMisc->SRamStart, RamMisc->SRamEnd, SM_RAM);
//		SekClose();
//	}	
}

//-----------------------------------------------------------------

inline static void CalcCol(int index, unsigned short nColour)
{
	int r, g, b;

	r = (nColour & 0x000f) << 4;	// Red
	g = (nColour & 0x00f0) << 0; 	// Green
	b = (nColour & 0x0f00) >> 4;	// Blue

	r |= r >> 4;
	g |= g >> 4;
	b |= b >> 4;
	
	RamPal[index] = nColour;
	
	// Normal Color
	MegadriveCurPal[index + 0x00] = BurnHighCol(r, g, b, 0);
	
	// Shadow Color
	MegadriveCurPal[index + 0x40] = MegadriveCurPal[index + 0xc0] = BurnHighCol(r>>1, g>>1, b>>1, 0);
	
	// Highlight Color
	r += 0x80; if (r > 0xFF) r = 0xFF;
	g += 0x80; if (g > 0xFF) g = 0xFF;
	b += 0x80; if (b > 0xFF) b = 0xFF;
	MegadriveCurPal[index + 0x80] = BurnHighCol(r, g, b, 0);
}

static int MemIndex()
{
	unsigned char *Next; Next = Mem;
	RomMain 	= Next; Next += MAX_CARTRIDGE_SIZE + sizeof(long);	// 68000 ROM, Max enough 
	
	RamStart	= Next;
	
	Ram68K		= Next; Next += 0x010000;
	RamZ80		= Next; Next += 0x002000;
	SRam		= Next; Next += MAX_SRAM_SIZE;		// SRam
	RamIO		= Next; Next += 0x000010;			// I/O
	
	RamPal		= (unsigned short *) Next; Next += 0x000040 * sizeof(unsigned short);
	RamSVid		= (unsigned short *) Next; Next += 0x000080;	// VSRam
	RamVid		= (unsigned short *) Next; Next += 0x010000;	// Video Ram
	
	RamVReg		= (struct PicoVideo *)Next; Next += sizeof(struct PicoVideo);
	RamMisc		= (struct PicoMisc *)Next; Next += sizeof(struct PicoMisc);
	
	RamEnd		= Next;

	MegadriveCurPal		= (unsigned short *) Next; Next += 0x000040 * sizeof(unsigned short) * 4;
	
	HighColFull	= Next; Next += (8 + 320 + 8) * 240;
	
	HighCacheA	= (int *) Next; Next += (41+1) * sizeof(int);	// caches for high layers
	HighCacheB	= (int *) Next; Next += (41+1) * sizeof(int);
	HighCacheS	= (int *) Next; Next += (80+1) * sizeof(int);	// and sprites
	HighPreSpr	= (int *) Next; Next += (80*2+1) * sizeof(int);	// slightly preprocessed sprites
	HighSprZ	= (char*) Next; Next += (320+8+8);				// Z-buffer for accurate sprites and shadow/hilight mode
	
	JoyPad		= (struct MegadriveJoyPad *) Next; Next += sizeof(struct MegadriveJoyPad);

	MemEnd		= Next;
	return 0;
}

unsigned short __fastcall MegadriveReadWord(unsigned int sekAddress)
{
	switch (sekAddress) {
		case 0xa11100: {
			unsigned short retVal = rand() & 0xffff;
			if (Z80HasBus || MegadriveZ80Reset) {
				retVal |= 0x100;
			} else {
				retVal &= 0xfeff;
			}
			return retVal;
		}
		
		default: {
			bprintf(PRINT_NORMAL, _T("Attempt to read word value of location %x\n"), sekAddress);
		}
	}
	return 0;
}

unsigned char __fastcall MegadriveReadByte(unsigned int sekAddress)
{
	switch (sekAddress) {
		case 0xa04000:
		case 0xa04001:
		case 0xa04002:
		case 0xa04003: {
			if (!Z80HasBus && !MegadriveZ80Reset) {
				return BurnYM2612Read(0, 0);
			} else {
				return 0;
			}
		}
				
		case 0xa11100: {
			unsigned char retVal = rand() & 0xff;
			if (Z80HasBus || MegadriveZ80Reset) {
				retVal |= 0x01;
			} else {
				retVal &= 0xfe;
			}
			return retVal;
		}

		default: {
			bprintf(PRINT_NORMAL, _T("Attempt to read byte value of location %x\n"), sekAddress);
		}
	}
	return 0;
}

void __fastcall MegadriveWriteByte(unsigned int sekAddress, unsigned char byteValue)
{
	if(sekAddress >= 0xA13004 && sekAddress < 0xA13040) {
		// dumb 12-in-1 or 4-in-1 banking support
		sekAddress &= 0x3f; 
		sekAddress <<= 16;
		int len = RomSize - sekAddress;
		if (len <= 0) return; // invalid/missing bank
		if (len > 0x200000) len = 0x200000; // 2 megs
		// code which does this is in RAM so this is safe.
		memcpy(RomMain, RomMain + sekAddress, len); 
		return;
	}

	switch (sekAddress) {
		case 0xa04000: {
			if (!Z80HasBus && !MegadriveZ80Reset) BurnYM2612Write(0, 0, byteValue);
			return;
		}
	
		case 0xa04001: {
			if (!Z80HasBus && !MegadriveZ80Reset) BurnYM2612Write(0, 1, byteValue);
			return;
		}
	
		case 0xa04002: {
			if (!Z80HasBus && !MegadriveZ80Reset) BurnYM2612Write(0, 2, byteValue);
			return;
		}
	
		case 0xa04003: {
			if (!Z80HasBus && !MegadriveZ80Reset) BurnYM2612Write(0, 3, byteValue);
			return;
		}
		
		case 0xA11100: {
			if (byteValue & 1) {
				RamMisc->Z80Run = 0;
				Z80HasBus = 0;
			} else {
				RamMisc->Z80Run = 1;
				Z80HasBus = 1;
			}
			return;
		}

		case 0xA11200: {
			if (!(byteValue & 1)) {
				ZetOpen(0);
				ZetReset();
				ZetClose();

				BurnYM2612Reset();
				MegadriveZ80Reset = 1;	
			} else {
				MegadriveZ80Reset = 0;
			}
			return;
		}
	
		case 0xA130F1: {
			// sram access register
			RamMisc->SRamReg = byteValue & 0x03;
			return;
		}
			
		default: {
			bprintf(PRINT_NORMAL, _T("Attempt to write byte value %x to location %x\n"), byteValue, sekAddress);
		}		
	}
}

void __fastcall MegadriveWriteWord(unsigned int sekAddress, unsigned short wordValue)
{
	switch (sekAddress) {
		case 0xa11100: {
			if (wordValue & 0x100) {
				RamMisc->Z80Run = 0;
				Z80HasBus = 0;
			} else {
				RamMisc->Z80Run = 1;
				Z80HasBus = 1;
			}
			return;
		}
		
		case 0xa11200: {
			if (!(wordValue & 0x100)) {
				ZetOpen(0);
				ZetReset();
				ZetClose();

				BurnYM2612Reset();
				MegadriveZ80Reset = 1;
			} else {
				MegadriveZ80Reset = 0;
			}
			return;
		}
		
		default: {
			bprintf(PRINT_NORMAL, _T("Attempt to write word value %x to location %x\n"), wordValue, sekAddress);
		}
	}
}

//---------------------------------------------------------------
// Megadrive Video Port Read Write
//---------------------------------------------------------------

static int rendstatus = 0;

// calculate the number of cycles 68k->VDP dma operation would take
static int DmaSlowBurn(int len)
{
	// test: Legend of Galahad, Time Killers
	int burn,maxlen,line=Scanline;
	//if(line == -1) line=vcounts[SekCyclesDone()>>8];
	maxlen = (224-line) * 18;
	if(len <= maxlen)
		burn = len*(((cycles_68k<<8)/18))>>8;
	else {
		burn  = maxlen*(((cycles_68k<<8)/18))>>8;
		burn += (len-maxlen)*(((cycles_68k<<8)/180))>>8;
	}
	return burn;
}

static int GetDmaLength()
{
  int len = 0;
  // 16-bit words to transfer:
  len  = RamVReg->reg[0x13];
  len |= RamVReg->reg[0x14]<<8;
  // Charles MacDonald:
  if(!len) len = 0xffff;
  return len;
}

static void DmaSlow(int len)
{
	unsigned short *pd=0, *pdend, *r;
	unsigned int a = RamVReg->addr, a2, d;
	unsigned char inc = RamVReg->reg[0xf];
	unsigned int source, burn;

	source  = RamVReg->reg[0x15] <<  1;
	source |= RamVReg->reg[0x16] <<  9;
	source |= RamVReg->reg[0x17] << 17;

  //dprintf("DmaSlow[%i] %06x->%04x len %i inc=%i blank %i [%i|%i]", Pico.video.type, source, a, len, inc,
  //         (Pico.video.status&8)||!(Pico.video.reg[1]&0x40), Pico.m.scanline, SekCyclesDone());

	if ((source & 0xe00000) == 0xe00000) { // RAM
		pd    = (unsigned short *)(Ram68K + (source & 0xfffe));
		pdend = (unsigned short *)(Ram68K + 0x10000); 
	} else if( source < RomSize) {	// ROM
		pd    = (unsigned short *)(RomMain + (source & ~1)); 
		pdend = (unsigned short *)(RomMain + RomSize); 
	} else return; // Invalid source address

	// CPU is stopped during DMA, so we burn some cycles to compensate that
	if((RamVReg->status & 8) || !(RamVReg->reg[1] & 0x40)) { 	// vblank?
		burn = (len*(((cycles_68k<<8)/167))>>8); 						// very approximate
		if(!(RamVReg->status & 8)) burn += burn>>1;				// a hack for Legend of Galahad
	} else burn = DmaSlowBurn(len);
	
	//SekCyclesBurn(burn);
	SekRunAdjust( 0 - burn );
	
	if(!(RamVReg->status & 8))
		SekRunEnd();
	//dprintf("DmaSlow burn: %i @ %06x", burn, SekPc);

	switch ( RamVReg->type ) {
	case 1: // vram
		r = RamVid;
		for(; len; len--) {
			d = *pd++;
			if(a&1) d=(d<<8)|(d>>8);
			r[a>>1] = (unsigned short)d; // will drop the upper bits
			// AutoIncrement
			a = (unsigned short)(a+inc);
			// didn't src overlap?
			if(pd >= pdend) pd -= 0x8000; // should be good for RAM, bad for ROM
		}
		rendstatus |= 0x10;
		break;
    
	case 3: // cram
		//dprintf("DmaSlow[%i] %06x->%04x len %i inc=%i blank %i [%i|%i]", Pico.video.type, source, a, len, inc,
		//         (Pico.video.status&8)||!(Pico.video.reg[1]&0x40), Pico.m.scanline, SekCyclesDone());
		for(a2 = a&0x7f; len; len--) {
			CalcCol( a2>>1, *pd );
			pd++;
			// AutoIncrement
			a2+=inc;
			// didn't src overlap?
			if(pd >= pdend) pd-=0x8000;
			// good dest?
			if(a2 >= 0x80) break; // Todds Adventures in Slime World / Andre Agassi tennis
		}
		a = (a&0xff00) | a2;
		break;

	case 5: // vsram[a&0x003f]=d;
		r = RamSVid;
		for(a2=a&0x7f; len; len--) {
			r[a2>>1] = (unsigned short)*pd++;
			// AutoIncrement
			a2+=inc;
			// didn't src overlap?
			if(pd >= pdend) pd-=0x8000;
			// good dest?
			if(a2 >= 0x80) break;
		}
		a=(a&0xff00)|a2;
		break;
	}
	// remember addr
	RamVReg->addr = (unsigned short)a;
}

static void DmaCopy(int len)
{
	unsigned char * vr = (unsigned char *) RamVid;
	unsigned char * vrs;
	//unsigned short a = Pico.video.addr;
	//unsigned char inc = RamVReg->reg[0xf];
	int source;
	
	//dprintf("DmaCopy len %i [%i|%i]", len, Pico.m.scanline, SekCyclesDone());

	source  = RamVReg->reg[0x15];
	source |= RamVReg->reg[0x16]<<8;
	vrs = vr + source;
	
	if (source+len > 0x10000) 
		len = 0x10000 - source; // clip??
	
	for(;len;len--) {
		vr[RamVReg->addr] = *vrs++;
		// AutoIncrement
		//a = (u16)(a + inc);
		RamVReg->addr += RamVReg->reg[0xf];
	}
	rendstatus |= 0x10;
}

static void DmaFill(int data)
{
	int len = GetDmaLength();
	unsigned char *vr = (unsigned char *) RamVid;
	unsigned char high = (unsigned char) (data >> 8);
	unsigned short a = RamVReg->addr;
	unsigned char inc = RamVReg->reg[0xf];
  
	//dprintf("DmaFill len %i inc %i [%i|%i]", len, inc, Pico.m.scanline, SekCyclesDone());

	// from Charles MacDonald's genvdp.txt:
	// Write lower byte to address specified
	vr[a] = (unsigned char) data;
	a = (unsigned short)(a+inc);

	if(!inc) len=1;

	for(;len;len--) {
		// Write upper byte to adjacent address
		// (here we are byteswapped, so address is already 'adjacent')
		vr[a] = high;
		// Increment address register
		a = (unsigned short)(a+inc);
	}
	// remember addr
	RamVReg->addr = a;
	// update length
	RamVReg->reg[0x13] = RamVReg->reg[0x14] = 0; // Dino Dini's Soccer (E) (by Haze)

	rendstatus |= 0x10;
}

static void CommandChange()
{
	//struct PicoVideo *pvid=&Pico.video;
	unsigned int cmd = RamVReg->command;
	unsigned int addr = 0;

	// Get type of transfer 0xc0000030 (v/c/vsram read/write)
	RamVReg->type = (unsigned char)(((cmd >> 2) & 0xc) | (cmd >> 30));

	// Get address 0x3fff0003
	addr  = (cmd >> 16) & 0x3fff;
	addr |= (cmd << 14) & 0xc000;
	RamVReg->addr = (unsigned short)addr;
	//dprintf("addr set: %04x", addr);

	// Check for dma:
	if (cmd & 0x80) {
		// Command DMA
		if ((RamVReg->reg[1] & 0x10) == 0) return; // DMA not enabled
		int len = GetDmaLength();
		switch ( RamVReg->reg[0x17]>>6 ) {
		case 0x00:
		case 0x01:
			DmaSlow(len);	// 68000 to VDP
			break;
		case 0x03:
			DmaCopy(len);	// VRAM Copy
			break;
		case 0x02:			// DMA Fill Flag ???
		default:
			;//bprintf(PRINT_NORMAL, _T("Video Command DMA Unknown %02x len %d\n"), RamVReg->reg[0x17]>>6, len);
		}
	}
}

// H-counter table for hvcounter reads in 40col mode
// based on Gens code
const unsigned char hcounts_40[] = {
	0x07,0x07,0x08,0x08,0x08,0x09,0x09,0x0a,0x0a,0x0b,0x0b,0x0b,0x0c,0x0c,0x0d,0x0d,
	0x0e,0x0e,0x0e,0x0f,0x0f,0x10,0x10,0x10,0x11,0x11,0x12,0x12,0x13,0x13,0x13,0x14,
	0x14,0x15,0x15,0x15,0x16,0x16,0x17,0x17,0x18,0x18,0x18,0x19,0x19,0x1a,0x1a,0x1b,
	0x1b,0x1b,0x1c,0x1c,0x1d,0x1d,0x1d,0x1e,0x1e,0x1f,0x1f,0x20,0x20,0x20,0x21,0x21,
	0x22,0x22,0x23,0x23,0x23,0x24,0x24,0x25,0x25,0x25,0x26,0x26,0x27,0x27,0x28,0x28,
	0x28,0x29,0x29,0x2a,0x2a,0x2a,0x2b,0x2b,0x2c,0x2c,0x2d,0x2d,0x2d,0x2e,0x2e,0x2f,
	0x2f,0x30,0x30,0x30,0x31,0x31,0x32,0x32,0x32,0x33,0x33,0x34,0x34,0x35,0x35,0x35,
	0x36,0x36,0x37,0x37,0x38,0x38,0x38,0x39,0x39,0x3a,0x3a,0x3a,0x3b,0x3b,0x3c,0x3c,
	0x3d,0x3d,0x3d,0x3e,0x3e,0x3f,0x3f,0x3f,0x40,0x40,0x41,0x41,0x42,0x42,0x42,0x43,
	0x43,0x44,0x44,0x45,0x45,0x45,0x46,0x46,0x47,0x47,0x47,0x48,0x48,0x49,0x49,0x4a,
	0x4a,0x4a,0x4b,0x4b,0x4c,0x4c,0x4d,0x4d,0x4d,0x4e,0x4e,0x4f,0x4f,0x4f,0x50,0x50,
	0x51,0x51,0x52,0x52,0x52,0x53,0x53,0x54,0x54,0x55,0x55,0x55,0x56,0x56,0x57,0x57,
	0x57,0x58,0x58,0x59,0x59,0x5a,0x5a,0x5a,0x5b,0x5b,0x5c,0x5c,0x5c,0x5d,0x5d,0x5e,
	0x5e,0x5f,0x5f,0x5f,0x60,0x60,0x61,0x61,0x62,0x62,0x62,0x63,0x63,0x64,0x64,0x64,
	0x65,0x65,0x66,0x66,0x67,0x67,0x67,0x68,0x68,0x69,0x69,0x6a,0x6a,0x6a,0x6b,0x6b,
	0x6c,0x6c,0x6c,0x6d,0x6d,0x6e,0x6e,0x6f,0x6f,0x6f,0x70,0x70,0x71,0x71,0x71,0x72,
	0x72,0x73,0x73,0x74,0x74,0x74,0x75,0x75,0x76,0x76,0x77,0x77,0x77,0x78,0x78,0x79,
	0x79,0x79,0x7a,0x7a,0x7b,0x7b,0x7c,0x7c,0x7c,0x7d,0x7d,0x7e,0x7e,0x7f,0x7f,0x7f,
	0x80,0x80,0x81,0x81,0x81,0x82,0x82,0x83,0x83,0x84,0x84,0x84,0x85,0x85,0x86,0x86,
	0x86,0x87,0x87,0x88,0x88,0x89,0x89,0x89,0x8a,0x8a,0x8b,0x8b,0x8c,0x8c,0x8c,0x8d,
	0x8d,0x8e,0x8e,0x8e,0x8f,0x8f,0x90,0x90,0x91,0x91,0x91,0x92,0x92,0x93,0x93,0x94,
	0x94,0x94,0x95,0x95,0x96,0x96,0x96,0x97,0x97,0x98,0x98,0x99,0x99,0x99,0x9a,0x9a,
	0x9b,0x9b,0x9b,0x9c,0x9c,0x9d,0x9d,0x9e,0x9e,0x9e,0x9f,0x9f,0xa0,0xa0,0xa1,0xa1,
	0xa1,0xa2,0xa2,0xa3,0xa3,0xa3,0xa4,0xa4,0xa5,0xa5,0xa6,0xa6,0xa6,0xa7,0xa7,0xa8,
	0xa8,0xa9,0xa9,0xa9,0xaa,0xaa,0xab,0xab,0xab,0xac,0xac,0xad,0xad,0xae,0xae,0xae,
	0xaf,0xaf,0xb0,0xb0,0xe4,0xe4,0xe4,0xe5,0xe5,0xe6,0xe6,0xe6,0xe7,0xe7,0xe8,0xe8,
	0xe9,0xe9,0xe9,0xea,0xea,0xeb,0xeb,0xeb,0xec,0xec,0xed,0xed,0xee,0xee,0xee,0xef,
	0xef,0xf0,0xf0,0xf1,0xf1,0xf1,0xf2,0xf2,0xf3,0xf3,0xf3,0xf4,0xf4,0xf5,0xf5,0xf6,
	0xf6,0xf6,0xf7,0xf7,0xf8,0xf8,0xf9,0xf9,0xf9,0xfa,0xfa,0xfb,0xfb,0xfb,0xfc,0xfc,
	0xfd,0xfd,0xfe,0xfe,0xfe,0xff,0xff,0x00,0x00,0x00,0x01,0x01,0x02,0x02,0x03,0x03,
	0x03,0x04,0x04,0x05,0x05,0x06,0x06,0x06,0x07,0x07,0x08,0x08,0x08,0x09,0x09,0x0a,
	0x0a,0x0b,0x0b,0x0b,0x0c,0x0c,0x0d,0x0d,0x0e,0x0e,0x0e,0x0f,0x0f,0x10,0x10,0x10,
};

// H-counter table for hvcounter reads in 32col mode
const unsigned char hcounts_32[] = {
	0x05,0x05,0x05,0x06,0x06,0x07,0x07,0x07,0x08,0x08,0x08,0x09,0x09,0x09,0x0a,0x0a,
	0x0a,0x0b,0x0b,0x0b,0x0c,0x0c,0x0c,0x0d,0x0d,0x0d,0x0e,0x0e,0x0f,0x0f,0x0f,0x10,
	0x10,0x10,0x11,0x11,0x11,0x12,0x12,0x12,0x13,0x13,0x13,0x14,0x14,0x14,0x15,0x15,
	0x15,0x16,0x16,0x17,0x17,0x17,0x18,0x18,0x18,0x19,0x19,0x19,0x1a,0x1a,0x1a,0x1b,
	0x1b,0x1b,0x1c,0x1c,0x1c,0x1d,0x1d,0x1d,0x1e,0x1e,0x1f,0x1f,0x1f,0x20,0x20,0x20,
	0x21,0x21,0x21,0x22,0x22,0x22,0x23,0x23,0x23,0x24,0x24,0x24,0x25,0x25,0x26,0x26,
	0x26,0x27,0x27,0x27,0x28,0x28,0x28,0x29,0x29,0x29,0x2a,0x2a,0x2a,0x2b,0x2b,0x2b,
	0x2c,0x2c,0x2c,0x2d,0x2d,0x2e,0x2e,0x2e,0x2f,0x2f,0x2f,0x30,0x30,0x30,0x31,0x31,
	0x31,0x32,0x32,0x32,0x33,0x33,0x33,0x34,0x34,0x34,0x35,0x35,0x36,0x36,0x36,0x37,
	0x37,0x37,0x38,0x38,0x38,0x39,0x39,0x39,0x3a,0x3a,0x3a,0x3b,0x3b,0x3b,0x3c,0x3c,
	0x3d,0x3d,0x3d,0x3e,0x3e,0x3e,0x3f,0x3f,0x3f,0x40,0x40,0x40,0x41,0x41,0x41,0x42,
	0x42,0x42,0x43,0x43,0x43,0x44,0x44,0x45,0x45,0x45,0x46,0x46,0x46,0x47,0x47,0x47,
	0x48,0x48,0x48,0x49,0x49,0x49,0x4a,0x4a,0x4a,0x4b,0x4b,0x4b,0x4c,0x4c,0x4d,0x4d,
	0x4d,0x4e,0x4e,0x4e,0x4f,0x4f,0x4f,0x50,0x50,0x50,0x51,0x51,0x51,0x52,0x52,0x52,
	0x53,0x53,0x53,0x54,0x54,0x55,0x55,0x55,0x56,0x56,0x56,0x57,0x57,0x57,0x58,0x58,
	0x58,0x59,0x59,0x59,0x5a,0x5a,0x5a,0x5b,0x5b,0x5c,0x5c,0x5c,0x5d,0x5d,0x5d,0x5e,
	0x5e,0x5e,0x5f,0x5f,0x5f,0x60,0x60,0x60,0x61,0x61,0x61,0x62,0x62,0x62,0x63,0x63,
	0x64,0x64,0x64,0x65,0x65,0x65,0x66,0x66,0x66,0x67,0x67,0x67,0x68,0x68,0x68,0x69,
	0x69,0x69,0x6a,0x6a,0x6a,0x6b,0x6b,0x6c,0x6c,0x6c,0x6d,0x6d,0x6d,0x6e,0x6e,0x6e,
	0x6f,0x6f,0x6f,0x70,0x70,0x70,0x71,0x71,0x71,0x72,0x72,0x72,0x73,0x73,0x74,0x74,
	0x74,0x75,0x75,0x75,0x76,0x76,0x76,0x77,0x77,0x77,0x78,0x78,0x78,0x79,0x79,0x79,
	0x7a,0x7a,0x7b,0x7b,0x7b,0x7c,0x7c,0x7c,0x7d,0x7d,0x7d,0x7e,0x7e,0x7e,0x7f,0x7f,
	0x7f,0x80,0x80,0x80,0x81,0x81,0x81,0x82,0x82,0x83,0x83,0x83,0x84,0x84,0x84,0x85,
	0x85,0x85,0x86,0x86,0x86,0x87,0x87,0x87,0x88,0x88,0x88,0x89,0x89,0x89,0x8a,0x8a,
	0x8b,0x8b,0x8b,0x8c,0x8c,0x8c,0x8d,0x8d,0x8d,0x8e,0x8e,0x8e,0x8f,0x8f,0x8f,0x90,
	0x90,0x90,0x91,0x91,0xe8,0xe8,0xe8,0xe9,0xe9,0xe9,0xea,0xea,0xea,0xeb,0xeb,0xeb,
	0xec,0xec,0xec,0xed,0xed,0xed,0xee,0xee,0xee,0xef,0xef,0xf0,0xf0,0xf0,0xf1,0xf1,
	0xf1,0xf2,0xf2,0xf2,0xf3,0xf3,0xf3,0xf4,0xf4,0xf4,0xf5,0xf5,0xf5,0xf6,0xf6,0xf6,
	0xf7,0xf7,0xf8,0xf8,0xf8,0xf9,0xf9,0xf9,0xfa,0xfa,0xfa,0xfb,0xfb,0xfb,0xfc,0xfc,
	0xfc,0xfd,0xfd,0xfd,0xfe,0xfe,0xfe,0xff,0xff,0x00,0x00,0x00,0x01,0x01,0x01,0x02,
	0x02,0x02,0x03,0x03,0x03,0x04,0x04,0x04,0x05,0x05,0x05,0x06,0x06,0x07,0x07,0x07,
	0x08,0x08,0x08,0x09,0x09,0x09,0x0a,0x0a,0x0a,0x0b,0x0b,0x0b,0x0c,0x0c,0x0c,0x0d,
};

unsigned short __fastcall MegadriveVideoReadWord(unsigned int sekAddress)
{
	//bprintf(PRINT_NORMAL, _T("Video Attempt to read word value of location %x\n"), sekAddress);
	//return MegadriveVDPRead((sekAddress - 0xc00000) >> 1);
	
	if (sekAddress > 0xC0001F)
		bprintf(PRINT_NORMAL, _T("Video Attempt to read word value of location %x\n"), sekAddress);
	
	unsigned short res = 0;
	
	switch (sekAddress & 0x1c) {
	case 0x00:	// data
		switch (RamVReg->type) {
			case 0: res = RamVid [(RamVReg->addr >> 1) & 0x7fff]; break;
			case 4: res = RamSVid[(RamVReg->addr >> 1) & 0x003f]; break;
			case 8: res = RamPal [(RamVReg->addr >> 1) & 0x003f]; break;
		}
		RamVReg->addr += RamVReg->reg[0xf];
		break;

	case 0x04:	// command
		res = RamVReg->status;
		//if(PicoOpt&0x10) d|=0x0020; 							// sprite collision (Shadow of the Beast)
		if(RamMisc->Rotate++&8) res |= 0x0100; else res |= 0x0200;	// Toggle fifo full empty (who uses that stuff?)
		if(!(RamVReg->reg[1] & 0x40)) res |= 0x0008;			// set V-Blank if display is disabled
		if(m68k_ICount < 84+4) res |= 0x0004;					// H-Blank (Sonic3 vs)
		RamVReg->pending = 0;		// ctrl port reads clear write-pending flag (Charles MacDonald)		
		break;
	
	case 0x08: 	// H-counter info
		{
			unsigned int hc = 50;
	
			int lineCycles = (cycles_68k - m68k_ICount) & 0x1ff;
			res = Scanline; // V-Counter
	
			if(RamVReg->reg[12]&1) 
				hc = hcounts_40[lineCycles];
			else hc = hcounts_32[lineCycles];
	
			if(lineCycles > cycles_68k-12) res++; // Wheel of Fortune

			if( Hardware & 0x40 ) {
				if(res >= 0x103) res -= 56; // based on Gens
			} else {
				if(res >= 0x0EB) res -= 6;
			}
		
			if((RamVReg->reg[12]&6) == 6) {
				// interlace mode 2 (Combat Cars (UE) [!])
				res <<= 1;
				if (res & 0xf00) res |= 1;
			}
			
			//dprintf("hv: %02x %02x (%i) @ %06x", hc, d, SekCyclesDone(), SekPc);
			res &= 0xff; 
			res <<= 8;
			res |= hc;
		}
		break;
		
	default:	
		bprintf(PRINT_NORMAL, _T("Video Attempt to read word value of location %x, %x\n"), sekAddress, sekAddress & 0x1c);
		break;
	}	
	
	return res;
}

unsigned char __fastcall MegadriveVideoReadByte(unsigned int sekAddress)
{
	//bprintf(PRINT_NORMAL, _T("Video Attempt to read byte value of location %x\n"), sekAddress);
	unsigned short res = MegadriveVideoReadWord(sekAddress & ~1);
	if ((sekAddress&1)==0) res >>= 8;
	return res & 0xff;
}

void __fastcall MegadriveVideoWriteWord(unsigned int sekAddress, unsigned short wordValue)
{
	if (sekAddress > 0xC0001F)
		bprintf(PRINT_NORMAL, _T("Video Attempt to write word value %x to location %x\n"), wordValue, sekAddress);

	switch (sekAddress & 0x1c) {
	case 0x00:	// data
		if (RamVReg->pending)
			CommandChange();
    	RamVReg->pending = 0;
		if ((RamVReg->command & 0x80) && (RamVReg->reg[1]&0x10) && (RamVReg->reg[0x17]>>6)==2) {

			DmaFill(wordValue);

		} else {
			//unsigned int a=Pico.video.addr;
			switch (RamVReg->type) {
			case 1: 
				// If address is odd, bytes are swapped (which game needs this?)
				if (RamVReg->addr & 1) {
					bprintf(PRINT_NORMAL, _T("Video address is odd, bytes are swapped!!!\n"));
					wordValue = (wordValue<<8)|(wordValue>>8);
				}
				RamVid[(RamVReg->addr >> 1) & 0x7fff] = wordValue;
            	rendstatus |= 0x10; 
            	break;
			case 3: 
				//Pico.m.dirtyPal = 1;
				//dprintf("w[%i] @ %04x, inc=%i [%i|%i]", Pico.video.type, a, Pico.video.reg[0xf], Pico.m.scanline, SekCyclesDone());
				CalcCol((RamVReg->addr >> 1) & 0x003f, wordValue);
				break;
			case 5:
				RamSVid[(RamVReg->addr >> 1) & 0x003f] = wordValue; 
				break;
			}
			//dprintf("w[%i] @ %04x, inc=%i [%i|%i]", Pico.video.type, a, Pico.video.reg[0xf], Pico.m.scanline, SekCyclesDone());
			//AutoIncrement();
			RamVReg->addr += RamVReg->reg[0xf];
		}
    	return;
		
	case 0x04:	// command
		if(RamVReg->pending) {
			// Low word of command:
			RamVReg->command &= 0xffff0000;
			RamVReg->command |= wordValue;
			RamVReg->pending = 0;
			CommandChange();
		} else {
			if((wordValue & 0xc000) == 0x8000) {
				int num = (wordValue >> 8) & 0x1f;
				RamVReg->reg[num] = wordValue & 0xff;
				
				// update IRQ level (Lemmings, Wiz 'n' Liz intro, ... )
				// may break if done improperly:
				// International Superstar Soccer Deluxe (crash), Street Racer (logos), Burning Force (gfx), Fatal Rewind (hang), Sesame Street Counting Cafe
				if(num < 2) {
					
					int lines = (RamVReg->reg[1] & 0x20) | (RamVReg->reg[0] & 0x10);
					int pints = (RamVReg->pending_ints & lines);
					if(pints & 0x20) SekSetIRQLine(6, SEK_IRQSTATUS_AUTO);
					else if(pints & 0x10) SekSetIRQLine(4, SEK_IRQSTATUS_AUTO);
					else SekSetIRQLine(0, SEK_IRQSTATUS_NONE);

				}

				if (num == 5) rendstatus |= 1;
//				else if(num == 0xc) Pico.m.dirtyPal = 2; // renderers should update their palettes if sh/hi mode is changed
				RamVReg->type = 0; // register writes clear command (else no Sega logo in Golden Axe II)
			} else {
				// High word of command:
				RamVReg->command &= 0x0000ffff;
				RamVReg->command |= wordValue << 16;
				RamVReg->pending = 1;
			}
		}
    	return;
	
	case 0x10:
	case 0x14:
		// PSG Sound
		//bprintf(PRINT_NORMAL, _T("PSG Attempt to write word value %04x to location %08x\n"), wordValue, sekAddress);
		SN76496Write(0, wordValue & 0xFF);
		return;
	
	}
}

void __fastcall MegadriveVideoWriteByte(unsigned int sekAddress, unsigned char byteValue)
{
	//bprintf(PRINT_NORMAL, _T("Video Attempt to write byte value %x to location %x\n"), byteValue, sekAddress);
	MegadriveVideoWriteWord(sekAddress, (byteValue << 8) | byteValue);
}

// -- Z80 Ram Read Write ------------------------------------------

unsigned char __fastcall MegadriveZ80RamReadByte(unsigned int sekAddress)
{
	if (!Z80HasBus && !MegadriveZ80Reset) {
		return RamZ80[sekAddress & 0x1fff];
	}
		
	return 0;
}

unsigned short __fastcall MegadriveZ80RamReadWord(unsigned int sekAddress)
{
	bprintf(PRINT_NORMAL, _T("Z80Ram Attempt to read word value of location %x\n"), sekAddress);
	return 0;
}

void __fastcall MegadriveZ80RamWriteByte(unsigned int sekAddress, unsigned char byteValue)
{
	if (!Z80HasBus && !MegadriveZ80Reset) {
		RamZ80[sekAddress & 0x1fff] = byteValue;
		return;
	}
	bprintf(PRINT_NORMAL, _T("Z80Ram Attempt to write byte value %x to location %x and didn't have the Bus!\n"), byteValue, sekAddress);
}

void __fastcall MegadriveZ80RamWriteWord(unsigned int sekAddress, unsigned short wordValue)
{
	if (!Z80HasBus && !MegadriveZ80Reset) {
		RamZ80[sekAddress & 0x1fff] = wordValue >> 8;
		return;
	}
	
	bprintf(PRINT_NORMAL, _T("Z80Ram Attempt to write word value %x to location %x and didn't have the Bus!\n"), wordValue, sekAddress);
//	MegadriveZ80RamWriteByte(sekAddress, wordValue >> 0x08);
}

// -- I/O Read Write ------------------------------------------

static int PadRead(int i)
{
	int pad=0,value=0,TH;
	pad = ~(JoyPad->pad[i]);					// Get inverse of pad MXYZ SACB RLDU
	TH = RamIO[i+1] & 0x40;

	/*if(PicoOpt & 0x20)*/ {					// 6 button gamepad enabled
		int phase = JoyPad->padTHPhase[i];

		if(phase == 2 && !TH) {
			value = (pad&0xc0)>>2;				// ?0SA 0000
			goto end;
		} else if(phase == 3 && TH) {
			value=(pad&0x30)|((pad>>8)&0xf);	// ?1CB MXYZ
			goto end;
		} else if(phase == 3 && !TH) {
			value=((pad&0xc0)>>2)|0x0f;			// ?0SA 1111
		goto end;
		}
	}

	if(TH) value=(pad&0x3f);              // ?1CB RLDU
	else   value=((pad&0xc0)>>2)|(pad&3); // ?0SA 00DU

end:

	// orr the bits, which are set as output
	value |= RamIO[i+1] & RamIO[i+4];

	return value; // will mirror later
}

unsigned char __fastcall MegadriveIOReadByte(unsigned int sekAddress)
{
	if (sekAddress > 0xA1001F)
		bprintf(PRINT_NORMAL, _T("IO Attempt to read byte value of location %x\n"), sekAddress);

	int offset = (sekAddress >> 1) & 0xf;
	switch (offset) {
	case 0:	// Get Hardware 
		return Hardware;
	case 1: // Pad 1
		return (RamIO[1] & 0x80) | PadRead(0);
	case 2: // Pad 2
		return (RamIO[2] & 0x80) | PadRead(1);
	default:
		//bprintf(PRINT_NORMAL, _T("IO Attempt to read byte value of location %x\n"), sekAddress);
		return RamIO[offset];
	}
	return 0;
}

unsigned short __fastcall MegadriveIOReadWord(unsigned int sekAddress)
{
	//if (sekAddress > 0xA1001F)
	//	bprintf(PRINT_NORMAL, _T("IO Attempt to read word value of location %x\n"), sekAddress);

	unsigned char res = MegadriveIOReadByte(sekAddress);
	return res | (res << 8);
}

void __fastcall MegadriveIOWriteByte(unsigned int sekAddress, unsigned char byteValue)
{
	if (sekAddress > 0xA1001F)
		bprintf(PRINT_NORMAL, _T("IO Attempt to byte byte value %x to location %x\n"), byteValue, sekAddress);

	int offset = (sekAddress >> 1) & 0xf;
	// 6-Button Support
	switch( offset ) {
	case 1:
		JoyPad->padDelay[0] = 0;
		if(!(RamIO[1] & 0x40) && (byteValue&0x40)) 
			JoyPad->padTHPhase[0] ++;
		break;
	case 2:
		JoyPad->padDelay[1] = 0;
		if(!(RamIO[2] & 0x40) && (byteValue&0x40)) 
			JoyPad->padTHPhase[1] ++;
		break;
	}
	RamIO[offset] = byteValue;
}

void __fastcall MegadriveIOWriteWord(unsigned int sekAddress, unsigned short wordValue)
{
	//if (sekAddress > 0xA1001F)	
	//	bprintf(PRINT_NORMAL, _T("IO Attempt to write word value %x to location %x\n"), wordValue, sekAddress);
		
	MegadriveIOWriteByte(sekAddress, wordValue & 0xff);
}

// -- YM2612/YM2612 FM Chip ----------------------------------------------------------

inline static int MegadriveSynchroniseStream(int nSoundRate)
{
	return (long long)SekTotalCycles() * nSoundRate / (OSC_NTSC / 7);
}

inline static double MegadriveGetTime()
{
	return (double)SekTotalCycles() / (OSC_NTSC / 7);
}

inline static int MegadriveSynchroniseStreamPAL(int nSoundRate)
{
	return (long long)SekTotalCycles() * nSoundRate / (OSC_PAL / 7);
}

inline static double MegadriveGetTimePAL()
{
	return (double)SekTotalCycles() / (OSC_PAL / 7);
}

// -- SRam / EEPROM ----------------------------------------------------------

unsigned char __fastcall MegadriveSRamReadByte(unsigned int sekAddress)
{
	unsigned int sreg = RamMisc->SRamReg;
	if(!(sreg & 0x10) && (sreg & 1) && sekAddress > 0x200001) { 
		// not yet detected SRAM
		RamMisc->SRamReg |= 0x10; // should be normal SRAM
	}
	
	if(sreg & 0x04) { // EEPROM read
		//d = SRAMReadEEPROM();
		bprintf(PRINT_NORMAL, _T("EEPROM Attempt to read byte value of location   %02x\n"), sekAddress);
		return 0;
    } else if(sreg & 0x01) {
		return SRam[ sekAddress - RamMisc->SRamStart ];
    } else {
		//bprintf(PRINT_NORMAL, _T("SRam Attempt to read byte value of location   %02x\n"), sekAddress);
    	if (sekAddress < RomSize) {
    		return RomMain[ sekAddress ^ 1];
    	}
    }
	
	return 0;
}

unsigned short __fastcall MegadriveSRamReadWord(unsigned int sekAddress)
{
	//bprintf(PRINT_NORMAL, _T("SRam Attempt to read word value of location %04x\n"), sekAddress);
	unsigned short res;
	res  = MegadriveSRamReadByte(sekAddress) << 8;
	res |= MegadriveSRamReadByte(sekAddress + 1);
	return res;
}

void __fastcall MegadriveSRamWriteByte(unsigned int sekAddress, unsigned char byteValue)
{
	unsigned int sreg = RamMisc->SRamReg;

	if(!(sreg & 0x10)) {
		// not detected SRAM
		if((sekAddress&~1)==0x200000) {
			//bprintf(2, _T("SRam Not Detected and Now Enable it!!!\n"));
			RamMisc->SRamReg |= 4; // this should be a game with EEPROM (like NBA Jam)
			RamMisc->SRamStart=0x200000; 
			RamMisc->SRamEnd = RamMisc->SRamStart + 1;
			
		}
		RamMisc->SRamReg |= 0x10;
	}
	
	if (sreg * 0x04) {

//		bprintf(PRINT_NORMAL, _T("EEPROM Attempt to write byte value   %02x to location %08x\n"), byteValue, sekAddress);
		
	} else if(!(sreg & 0x02)) {
		SRam[ sekAddress - RamMisc->SRamStart ] = byteValue;
	} else
		bprintf(PRINT_NORMAL, _T("SRam Attempt to write byte value   %02x to location %08x\n"), byteValue, sekAddress);
}

void __fastcall MegadriveSRamWriteWord(unsigned int sekAddress, unsigned short wordValue)
{
	//bprintf(PRINT_NORMAL, _T("SRam Attempt to write word value %04x to location %08x\n"), wordValue, sekAddress);
	MegadriveSRamWriteByte( sekAddress + 0, wordValue >> 0x08 );
	MegadriveSRamWriteByte( sekAddress + 1, wordValue  & 0xff );
}

// ---------------------------------------------------------------

static int MegadriveResetDo()
{
	SekOpen(0);
	SekReset();
	SekClose();
	
	ZetOpen(0);
	ZetReset();
	ZetClose();

	BurnYM2612Reset();
	
	MegadriveZ80Reset = 1;
	Z80HasBus = 1;
	
#if 0
	FILE * f = fopen("Megadrive.bin", "wb+");
	fwrite(RomMain, 1, 0x200000, f);
	fclose(f);
#endif
	
	MegadriveCheckHardware();
	
	if (Hardware & 0x40) {
		BurnSetRefreshRate(50.0);
		Reinitialise();
		
		BurnYM2612Exit();
		BurnYM2612Init(1, OSC_PAL / 7, NULL, MegadriveSynchroniseStreamPAL, MegadriveGetTimePAL, 0);
		BurnTimerAttachSek(OSC_PAL / 7);
		
		BurnYM2612Reset();
		
		SN76496Exit();
		SN76496Init(0, OSC_PAL / 15, 1);
	} else {
		BurnSetRefreshRate(60.0);
		Reinitialise();
		
		BurnYM2612Exit();
		BurnYM2612Init(1, OSC_NTSC / 7, NULL, MegadriveSynchroniseStream, MegadriveGetTime, 0);
		BurnTimerAttachSek(OSC_NTSC / 7);
		
		BurnYM2612Reset();
		
		SN76496Exit();
		SN76496Init(0, OSC_NTSC / 15, 1);
	}

	// other reset
	memset(RamMisc, 0, sizeof(struct PicoMisc));
	memset(JoyPad, 0, sizeof(struct MegadriveJoyPad));
	
	// default VDP register values (based on Fusion)
	memset(RamVReg, 0, sizeof(struct PicoVideo));
	RamVReg->reg[0x00] = 0x04;
	RamVReg->reg[0x01] = 0x04;
	RamVReg->reg[0x0c] = 0x81;
	RamVReg->reg[0x0f] = 0x02;
	
	RamVReg->status = 0x3408 | ((MegadriveDIP[0] & 0x40) >> 6);
	
	return 0;
}

int __fastcall MegadriveIrqCallback(int irq)
{
	switch ( irq ) {
	case 4:	RamVReg->pending_ints  =  0x00; break;
	case 6:	RamVReg->pending_ints &= ~0x20; break;
	}
	return -1;
}

// ----------------------------------------------------------------
// Z80 Read/Write
// ----------------------------------------------------------------

unsigned char __fastcall MegadriveZ80PortRead(unsigned short a)
{
	a &= 0xff;
	
	switch (a) {
		default: {
			bprintf(PRINT_NORMAL, _T("Z80 Port Read 02%x\n"), a);
		}
	}	

	return 0;
}

void __fastcall MegadriveZ80PortWrite(unsigned short a, unsigned char d)
{
	a &= 0xff;
	
	switch (a) {
		default: {
			bprintf(PRINT_NORMAL, _T("Z80 Port Write %02x, %02%x\n"), a, d);
		}
	}
}

unsigned char __fastcall MegadriveZ80ProgRead(unsigned short a)
{
	if (a >= 0x6100 && a <= 0x7eff) {
		return 0xff;
	}
	
	if (a >= 0x8000) {
		unsigned int addr68k = RamMisc->Bank68k;
		addr68k += a & 0x7fff;
		if (addr68k <= 0x3fffff) return RomMain[addr68k ^ 1];
		
		bprintf(PRINT_NORMAL, _T("%Z80 trying to read 68k address %06X\n"), addr68k);
		return 0;
	}
	
	switch (a) {
		case 0x4000:
		case 0x4001:
		case 0x4002: {
			return BurnYM2612Read(0, 0);
		}
		
		default: {
			bprintf(PRINT_NORMAL, _T("Z80 Read %04x\n"), a);
		}
	}
	
	return 0;
}

UINT32 Z80BankPartial = 0;
UINT32 Z80BankPos = 0;

void __fastcall MegadriveZ80ProgWrite(unsigned short a, unsigned char d)
{
	if (a == 0x6000 || a == 0x6001) {
		Z80BankPartial |= (d & 0x01) << 23;
		Z80BankPos++;

		if (Z80BankPos < 9) {
			Z80BankPartial >>= 1;
		} else {
			Z80BankPos = 0;
			RamMisc->Bank68k = Z80BankPartial;
			Z80BankPartial = 0;
		}
		return;
	}
	
	if (a >= 0x8000) {
		unsigned int addr68k = RamMisc->Bank68k;
		addr68k += a & 0x7fff;
		
		if (addr68k <= 0x3fffff) return;
		
		if (addr68k == 0xc00011) {
			SN76496Write(0, d);
			return;
		}
		
		if ((addr68k >= 0xe00000) && (addr68k <= 0xffffff)) {
			addr68k &=0xffff;
			unsigned short *Ram = (unsigned short*)Ram68K;
			if (addr68k & 0x01) {
				Ram[addr68k >> 1] = (Ram[addr68k >> 1] & 0xff00) | d;
			} else {
				Ram[addr68k >> 1] = (Ram[addr68k >> 1] & 0x00ff) | (d << 8);
			}
			return;
		}
		
		bprintf(PRINT_NORMAL, _T("Z80-Bank68K Attempt to write byte value %02x to location %06x\n"), d, addr68k);
		return;
	}
	
	switch (a) {
		case 0x4000: {
			BurnYM2612Write(0, 0, d);
			return;
		}
		
		case 0x4001: {
			BurnYM2612Write(0, 1, d);
			return;
		}
		
		case 0x4002: {
			BurnYM2612Write(0, 2, d);
			return;
		}
		
		case 0x4003: {
			BurnYM2612Write(0, 3, d);
			return;
		}
		
		case 0x7f11:
		case 0x7f13:
		case 0x7f15:
		case 0x7f17: {
			SN76496Write(0, d);
			return;
		}
		
		default: {
			bprintf(PRINT_NORMAL, _T("Z80 Write %04x, %02x\n"), a, d);
		}
	}
}

int MegadriveInit()
{
	Mem = NULL;
	MemIndex();
	int nLen = MemEnd - (unsigned char *)0;
	if ((Mem = (unsigned char *)malloc(nLen)) == NULL) return 1;
	memset(Mem, 0, nLen);
	MemIndex();	

	int res = BurnLoadRom(RomMain, 0, 1);
	if ( res == 0 ) {
		struct BurnRomInfo ri;
		BurnDrvGetRomInfo(&ri, 0);
		RomSize = ri.nLen;		
		if (!RomNoByteswap) Byteswap(RomMain, RomSize);
	}

	// preset sram to 0xff ???
	memset(SRam, 0xFF, MAX_SRAM_SIZE);
	
	{
		SekInit(0, 0x68000);										// Allocate 68000
	        SekOpen(0);

		// Map 68000 memory:
		SekMapMemory(RomMain,		0x000000, 0x3FFFFF, SM_ROM);	// 68000 ROM
		SekMapMemory(Ram68K,		0xFF0000, 0xFFFFFF, SM_RAM);	// 68000 RAM
		
		SekMapHandler(1,			0xC00000, 0xC0001F, SM_RAM);	// Video Port
		SekMapHandler(2,			0xA00000, 0xA01FFF, SM_RAM);	// Z80 Ram
		SekMapHandler(3,			0xA02000, 0xA03FFF, SM_RAM);	// Z80 Ram
		SekMapHandler(4,			0xA10000, 0xA1001F, SM_RAM);	// I/O
		
		SekSetReadByteHandler (0, MegadriveReadByte);
		SekSetReadWordHandler (0, MegadriveReadWord);
		SekSetWriteByteHandler(0, MegadriveWriteByte);
		SekSetWriteWordHandler(0, MegadriveWriteWord);
		
		SekSetReadByteHandler (1, MegadriveVideoReadByte);
		SekSetReadWordHandler (1, MegadriveVideoReadWord);
		SekSetWriteByteHandler(1, MegadriveVideoWriteByte);
		SekSetWriteWordHandler(1, MegadriveVideoWriteWord);

		SekSetReadByteHandler (2, MegadriveZ80RamReadByte);
		SekSetReadWordHandler (2, MegadriveZ80RamReadWord);
		SekSetWriteByteHandler(2, MegadriveZ80RamWriteByte);
		SekSetWriteWordHandler(2, MegadriveZ80RamWriteWord);
		
		SekSetReadByteHandler (3, MegadriveZ80RamReadByte);
		SekSetReadWordHandler (3, MegadriveZ80RamReadWord);
		SekSetWriteByteHandler(3, MegadriveZ80RamWriteByte);
		SekSetWriteWordHandler(3, MegadriveZ80RamWriteWord);

		SekSetReadByteHandler (4, MegadriveIOReadByte);
		SekSetReadWordHandler (4, MegadriveIOReadWord);
		SekSetWriteByteHandler(4, MegadriveIOWriteByte);
		SekSetWriteWordHandler(4, MegadriveIOWriteWord);

		SekSetIrqCallback( MegadriveIrqCallback );
	}
	
	{
		ZetInit(1);
		ZetOpen(0);
		
		ZetMapArea(0x0000, 0x1FFF, 0, RamZ80);
		ZetMapArea(0x0000, 0x1FFF, 1, RamZ80);
		ZetMapArea(0x0000, 0x1FFF, 2, RamZ80);

		ZetMapArea(0x2000, 0x3FFF, 0, RamZ80);
		ZetMapArea(0x2000, 0x3FFF, 1, RamZ80);
		ZetMapArea(0x2000, 0x3FFF, 2, RamZ80);
		
		ZetMemEnd();
		
		ZetSetReadHandler(MegadriveZ80ProgRead);
		ZetSetWriteHandler(MegadriveZ80ProgWrite);
		ZetSetInHandler(MegadriveZ80PortRead);
		ZetSetOutHandler(MegadriveZ80PortWrite);
		ZetClose();
	}
	
	// OSC_NTSC / 7
	BurnSetRefreshRate(60.0);

	DrvSECAM = 0;
	BurnYM2612Init(1, OSC_NTSC / 7, NULL, MegadriveSynchroniseStream, MegadriveGetTime, 0);
	BurnTimerAttachSek(OSC_NTSC / 7);
	
	SN76496Init(0, OSC_NTSC / 15, 1);
	
	if (MegadriveCallback) MegadriveCallback();
	
	pBurnDrvPalette = (unsigned int*)MegadriveCurPal;
	
	MegadriveResetDo();	

	return 0;
}

int MegadriveNoByteswapInit()
{
	RomNoByteswap = 1;
	return MegadriveInit();
}

void __fastcall Ssf2BankingWriteByte(unsigned int sekAddress, unsigned char byteValue)
{
	switch (sekAddress) {
		case 0xa130f1: {
			return;
		}
		
		case 0xa130f3: {
			memcpy(RomMain + 0x080000, Ssf2Rom + ((byteValue & 0x0f) * 0x80000), 0x80000);
			return;
		}
		
		case 0xa130f5: {
			memcpy(RomMain + 0x100000, Ssf2Rom + ((byteValue & 0x0f) * 0x80000), 0x80000);
			return;
		}
		
		case 0xa130f7: {
			memcpy(RomMain + 0x180000, Ssf2Rom + ((byteValue & 0x0f) * 0x80000), 0x80000);
			return;
		}
		
		case 0xa130f9: {
			memcpy(RomMain + 0x200000, Ssf2Rom + ((byteValue & 0x0f) * 0x80000), 0x80000);
			return;
		}
		
		case 0xa130fb: {
			memcpy(RomMain + 0x280000, Ssf2Rom + ((byteValue & 0x0f) * 0x80000), 0x80000);
			return;
		}
		
		case 0xa130fd: {
			memcpy(RomMain + 0x300000, Ssf2Rom + ((byteValue & 0x0f) * 0x80000), 0x80000);
			return;
		}
		
		case 0xa130ff: {
			memcpy(RomMain + 0x380000, Ssf2Rom + ((byteValue & 0x0f) * 0x80000), 0x80000);
			return;
		}
		
		default: {
			bprintf(PRINT_NORMAL, _T("Attempt to write byte value %x to location %x\n"), byteValue, sekAddress);
		}		
	}
}

static void Ssf2MapBanking()
{
	memcpy(Ssf2Rom, RomMain, 0x500000);
	
	SekOpen(0);
	SekMapHandler(5, 0xa13000, 0xa13fff, SM_WRITE);
	SekSetWriteByteHandler(5, Ssf2BankingWriteByte);
	SekClose();
}

int MegadriveSsf2Init()
{
	Ssf2Rom = (unsigned char*)malloc(0x500000);
		
	MegadriveCallback = Ssf2MapBanking;
	return MegadriveInit();
}

static void RiseRealDumpLoad()
{
	BurnLoadRom(RomMain + 0x200000, 1, 1);
}

int MegadriveRiseRealDumpInit()
{
	MegadriveCallback = RiseRealDumpLoad;
	
	RomNoByteswap = 1;
	return MegadriveInit();
}

static void F22RealDumpLoad()
{
	BurnLoadRom(RomMain + 0x080000, 1, 2);
}

int MegadriveF22RealDumpInit()
{
	MegadriveCallback = F22RealDumpLoad;
	
	RomNoByteswap = 1;
	return MegadriveInit();
}

static void MegadriveMapSRAM_0x200000_0x800()
{
	SekOpen(0);
	SekMapMemory(SRam, 0x200000, 0x2007ff, SM_RAM);
	SekClose();
}

int MegadriveBackup_0x200000_0x800_Init()
{
	MegadriveCallback = MegadriveMapSRAM_0x200000_0x800;
	
	return MegadriveInit();
}

static void MegadriveMapSRAM_0x200000_0x2000()
{
	SekOpen(0);
	SekMapMemory(SRam, 0x200000, 0x201fff, SM_RAM);
	SekClose();
}

int MegadriveBackup_0x200000_0x2000_Init()
{
	MegadriveCallback = MegadriveMapSRAM_0x200000_0x2000;
	
	return MegadriveInit();
}

static void MegadriveMapSRAM_0x200000_0x4000()
{
	SekOpen(0);
	SekMapMemory(SRam, 0x200000, 0x203fff, SM_RAM);
	SekClose();
}

int MegadriveBackup_0x200000_0x4000_Init()
{
	MegadriveCallback = MegadriveMapSRAM_0x200000_0x4000;
	
	return MegadriveInit();
}

int MegadriveNoByteswapBackup_0x200000_0x4000_Init()
{
	RomNoByteswap = 1;
	MegadriveCallback = MegadriveMapSRAM_0x200000_0x4000;
	
	return MegadriveInit();
}

static void MegadriveMapSRAM_0x200000_0x10000()
{
	SekOpen(0);
	SekMapMemory(SRam, 0x200000, 0x20ffff, SM_RAM);
	SekClose();
}

int MegadriveBackup_0x200000_0x10000_Init()
{
	MegadriveCallback = MegadriveMapSRAM_0x200000_0x10000;
	
	return MegadriveInit();
}

int MegadriveNoByteswapBackup_0x200000_0x10000_Init()
{
	RomNoByteswap = 1;
	MegadriveCallback = MegadriveMapSRAM_0x200000_0x10000;
	
	return MegadriveInit();
}

static void MegadriveMapSRAM_0x300000_0x10000()
{
	SekOpen(0);
	SekMapMemory(SRam, 0x300000, 0x30ffff, SM_RAM);
	SekClose();
}

int MegadriveBackup_0x300000_0x10000_Init()
{
	MegadriveCallback = MegadriveMapSRAM_0x300000_0x10000;
	
	return MegadriveInit();
}

void __fastcall Sks3BackupWriteByte(unsigned int sekAddress, unsigned char byteValue)
{
	switch (sekAddress) {
		case 0xA130F1: {
			// sram access register
			RamMisc->SRamReg = byteValue & 0x03;
			
			if (byteValue & 0x01) {
				SekMapMemory(SRam, 0x200000, 0x2003ff, SM_RAM);
			} else {
				SekMapMemory(RomMain + 0x200000, 0x200000, 0x2003ff, SM_ROM);
			}
			return;
		}
			
		default: {
			bprintf(PRINT_NORMAL, _T("Attempt to write byte value %x to location %x\n"), byteValue, sekAddress);
		}		
	}
}

void __fastcall Sks3Backup_0x4000_WriteByte(unsigned int sekAddress, unsigned char byteValue)
{
	switch (sekAddress) {
		case 0xA130F1: {
			// sram access register
			RamMisc->SRamReg = byteValue & 0x03;
			
			if (byteValue & 0x01) {
				SekMapMemory(SRam, 0x200000, 0x203fff, SM_RAM);
			} else {
				SekMapMemory(RomMain + 0x200000, 0x200000, 0x203fff, SM_ROM);
			}
			return;
		}
			
		default: {
			bprintf(PRINT_NORMAL, _T("Attempt to write byte value %x to location %x\n"), byteValue, sekAddress);
		}		
	}
}

static void Sks3MapSRAM()
{
	SekOpen(0);
	SekMapHandler(5, 0xa13000, 0xa13fff, SM_WRITE);
	SekSetWriteByteHandler(5, Sks3BackupWriteByte);
	SekClose();
}

int MegadriveBackup_Sks3_Init()
{
	MegadriveCallback = Sks3MapSRAM;
	
	return MegadriveInit();
}

static void Sks3_0x4000_MapSRAM()
{
	SekOpen(0);
	SekMapHandler(5, 0xa13000, 0xa13fff, SM_WRITE);
	SekSetWriteByteHandler(5, Sks3Backup_0x4000_WriteByte);
	SekClose();
}

int MegadriveBackup_Sks3_0x4000_Init()
{
	MegadriveCallback = Sks3_0x4000_MapSRAM;
	
	return MegadriveInit();
}

unsigned char __fastcall RadicaBankSelectByte(unsigned int sekAddress)
{
	bprintf(PRINT_IMPORTANT, _T("Radica Bank Read Byte %06x\n"), sekAddress);
	
	return 0;
}

unsigned short __fastcall RadicaBankSelectWord(unsigned int sekAddress)
{
	int Bank = ((sekAddress - 0xa13000) >> 1) & 0x3f;
	memcpy(RomMain, RomMain + (Bank * 0x10000) + 0x400000, 0x400000);
	
	return 0;
}

static void MapRadicaBanks()
{
	memcpy(RomMain + 0x400000, RomMain + 0x000000, 0x400000);
	memcpy(RomMain + 0x800000, RomMain + 0x000000, 0x400000);
	
	SekOpen(0);
	SekMapHandler(6, 0xa13000, 0xa1307f, SM_READ);
	SekSetReadByteHandler(6, RadicaBankSelectByte);
	SekSetReadWordHandler(6, RadicaBankSelectWord);
	SekClose();
}

int RadicaInit()
{
	RomNoByteswap = 1;
	
	MegadriveCallback = MapRadicaBanks;
	
	return MegadriveInit();
}

int MegadriveExit()
{
	SekExit();
	ZetExit();

	BurnYM2612Exit();
	SN76496Exit();
	
	if (Mem) {
		free(Mem);
		Mem = NULL;
	}
	
	if (Ssf2Rom) {
		free(Ssf2Rom);
		Ssf2Rom = NULL;
	}
	
	MegadriveCallback = NULL;
	cycles_68k = 0;
	cycles_z80 = 0;
	RomNoByteswap = 0;
	MegadriveReset = 0;
	RomSize = 0;
	SRamSize = 0;
	Scanline = 0;
	Z80HasBus = 0;
	MegadriveZ80Reset = 0;
	Hardware = 0;
	DrvSECAM = 0;
	HighCol = NULL;
	
	return 0;
}

//---------------------------------------------------------------
// Megadrive Draw
//---------------------------------------------------------------

static int TileNorm(int sx,int addr,int pal)
{
	unsigned char *pd = HighCol+sx;
	unsigned int pack=0; 
	unsigned int t=0;

	pack = *(unsigned int *)(RamVid + addr); // Get 8 pixels
	if (pack) {
		t=pack&0x0000f000; if (t) pd[0]=(unsigned char)(pal|(t>>12));
		t=pack&0x00000f00; if (t) pd[1]=(unsigned char)(pal|(t>> 8));
		t=pack&0x000000f0; if (t) pd[2]=(unsigned char)(pal|(t>> 4));
		t=pack&0x0000000f; if (t) pd[3]=(unsigned char)(pal|(t    ));
		t=pack&0xf0000000; if (t) pd[4]=(unsigned char)(pal|(t>>28));
		t=pack&0x0f000000; if (t) pd[5]=(unsigned char)(pal|(t>>24));
		t=pack&0x00f00000; if (t) pd[6]=(unsigned char)(pal|(t>>20));
		t=pack&0x000f0000; if (t) pd[7]=(unsigned char)(pal|(t>>16));
		return 0;
	}
	return 1; // Tile blank
}

static int TileFlip(int sx,int addr,int pal)
{
	unsigned char *pd = HighCol+sx;
	unsigned int pack=0; 
	unsigned int t=0;

	pack = *(unsigned int *)(RamVid + addr); // Get 8 pixels
	if (pack) {
		t=pack&0x000f0000; if (t) pd[0]=(unsigned char)(pal|(t>>16));
		t=pack&0x00f00000; if (t) pd[1]=(unsigned char)(pal|(t>>20));
		t=pack&0x0f000000; if (t) pd[2]=(unsigned char)(pal|(t>>24));
		t=pack&0xf0000000; if (t) pd[3]=(unsigned char)(pal|(t>>28));
		t=pack&0x0000000f; if (t) pd[4]=(unsigned char)(pal|(t    ));
		t=pack&0x000000f0; if (t) pd[5]=(unsigned char)(pal|(t>> 4));
		t=pack&0x00000f00; if (t) pd[6]=(unsigned char)(pal|(t>> 8));
		t=pack&0x0000f000; if (t) pd[7]=(unsigned char)(pal|(t>>12));
		return 0;
	}
	return 1; // Tile blank
}

// tile renderers for hacky operator sprite support
#define sh_pix(x) \
  if(!t); \
  else if(t==0xe) pd[x]=(unsigned char)((pd[x]&0x3f)|0x80); /* hilight */ \
  else if(t==0xf) pd[x]=(unsigned char)((pd[x]&0x3f)|0xc0); /* shadow  */ \
  else pd[x]=(unsigned char)(pal|t);

static int TileNormSH(int sx,int addr,int pal)
{
	unsigned int pack=0; unsigned int t=0;
	unsigned char *pd = HighCol+sx;

	pack=*(unsigned int *)(RamVid+addr); // Get 8 pixels
	if (pack) {
		t=(pack&0x0000f000)>>12; sh_pix(0);
		t=(pack&0x00000f00)>> 8; sh_pix(1);
		t=(pack&0x000000f0)>> 4; sh_pix(2);
		t=(pack&0x0000000f)    ; sh_pix(3);
		t=(pack&0xf0000000)>>28; sh_pix(4);
		t=(pack&0x0f000000)>>24; sh_pix(5);
		t=(pack&0x00f00000)>>20; sh_pix(6);
		t=(pack&0x000f0000)>>16; sh_pix(7);
		return 0;
	}
	return 1; // Tile blank
}

static int TileFlipSH(int sx,int addr,int pal)
{
	unsigned int pack=0; unsigned int t=0;
	unsigned char *pd = HighCol+sx;

	pack=*(unsigned int *)(RamVid+addr); // Get 8 pixels
	if (pack) {
		t=(pack&0x000f0000)>>16; sh_pix(0);
		t=(pack&0x00f00000)>>20; sh_pix(1);
		t=(pack&0x0f000000)>>24; sh_pix(2);
		t=(pack&0xf0000000)>>28; sh_pix(3);
		t=(pack&0x0000000f)    ; sh_pix(4);
		t=(pack&0x000000f0)>> 4; sh_pix(5);
		t=(pack&0x00000f00)>> 8; sh_pix(6);
		t=(pack&0x0000f000)>>12; sh_pix(7);
		return 0;
	}
	return 1; // Tile blank
}

static int TileNormZ(int sx,int addr,int pal,int zval)
{
	unsigned int pack=0; 
	unsigned int t=0;
	unsigned char *pd = HighCol+sx;
	char *zb = HighSprZ+sx;
	int collision = 0, zb_s;

	pack=*(unsigned int *)(RamVid+addr); // Get 8 pixels
	if (pack) {
		t=pack&0x0000f000; if(t) { zb_s=zb[0]; if(zb_s) collision=1; if(zval>zb_s) { pd[0]=(unsigned char)(pal|(t>>12)); zb[0]=(char)zval; } }
		t=pack&0x00000f00; if(t) { zb_s=zb[1]; if(zb_s) collision=1; if(zval>zb_s) { pd[1]=(unsigned char)(pal|(t>> 8)); zb[1]=(char)zval; } }
		t=pack&0x000000f0; if(t) { zb_s=zb[2]; if(zb_s) collision=1; if(zval>zb_s) { pd[2]=(unsigned char)(pal|(t>> 4)); zb[2]=(char)zval; } }
		t=pack&0x0000000f; if(t) { zb_s=zb[3]; if(zb_s) collision=1; if(zval>zb_s) { pd[3]=(unsigned char)(pal|(t    )); zb[3]=(char)zval; } }
		t=pack&0xf0000000; if(t) { zb_s=zb[4]; if(zb_s) collision=1; if(zval>zb_s) { pd[4]=(unsigned char)(pal|(t>>28)); zb[4]=(char)zval; } }
		t=pack&0x0f000000; if(t) { zb_s=zb[5]; if(zb_s) collision=1; if(zval>zb_s) { pd[5]=(unsigned char)(pal|(t>>24)); zb[5]=(char)zval; } }
		t=pack&0x00f00000; if(t) { zb_s=zb[6]; if(zb_s) collision=1; if(zval>zb_s) { pd[6]=(unsigned char)(pal|(t>>20)); zb[6]=(char)zval; } }
		t=pack&0x000f0000; if(t) { zb_s=zb[7]; if(zb_s) collision=1; if(zval>zb_s) { pd[7]=(unsigned char)(pal|(t>>16)); zb[7]=(char)zval; } }
		if(collision) RamVReg->status |= 0x20;
		return 0;
	}
	return 1; // Tile blank
}

static int TileFlipZ(int sx,int addr,int pal,int zval)
{
	unsigned int pack=0; 
	unsigned int t=0;
	unsigned char *pd = HighCol+sx;
	char *zb = HighSprZ+sx;
	int collision = 0, zb_s;
	
	pack=*(unsigned int *)(RamVid+addr); // Get 8 pixels
	if (pack) {
		t=pack&0x000f0000; if(t) { zb_s=zb[0]&0x1f; if(zb_s) collision=1; if(zval>zb_s) { pd[0]=(unsigned char)(pal|(t>>16)); zb[0]=(char)zval; } }
		t=pack&0x00f00000; if(t) { zb_s=zb[1]&0x1f; if(zb_s) collision=1; if(zval>zb_s) { pd[1]=(unsigned char)(pal|(t>>20)); zb[1]=(char)zval; } }
		t=pack&0x0f000000; if(t) { zb_s=zb[2]&0x1f; if(zb_s) collision=1; if(zval>zb_s) { pd[2]=(unsigned char)(pal|(t>>24)); zb[2]=(char)zval; } }
		t=pack&0xf0000000; if(t) { zb_s=zb[3]&0x1f; if(zb_s) collision=1; if(zval>zb_s) { pd[3]=(unsigned char)(pal|(t>>28)); zb[3]=(char)zval; } }
		t=pack&0x0000000f; if(t) { zb_s=zb[4]&0x1f; if(zb_s) collision=1; if(zval>zb_s) { pd[4]=(unsigned char)(pal|(t    )); zb[4]=(char)zval; } }
		t=pack&0x000000f0; if(t) { zb_s=zb[5]&0x1f; if(zb_s) collision=1; if(zval>zb_s) { pd[5]=(unsigned char)(pal|(t>> 4)); zb[5]=(char)zval; } }
		t=pack&0x00000f00; if(t) { zb_s=zb[6]&0x1f; if(zb_s) collision=1; if(zval>zb_s) { pd[6]=(unsigned char)(pal|(t>> 8)); zb[6]=(char)zval; } }
		t=pack&0x0000f000; if(t) { zb_s=zb[7]&0x1f; if(zb_s) collision=1; if(zval>zb_s) { pd[7]=(unsigned char)(pal|(t>>12)); zb[7]=(char)zval; } }
		if(collision) RamVReg->status |= 0x20;
		return 0;
 	}
	return 1; // Tile blank
}


#define sh_pixZ(x) \
  if(t) { \
    if(zb[x]) collision=1; \
    if(zval>zb[x]) { \
      if     (t==0xe) { pd[x]=(unsigned char)((pd[x]&0x3f)|0x80); /* hilight */ } \
      else if(t==0xf) { pd[x]=(unsigned char)((pd[x]&0x3f)|0xc0); /* shadow  */ } \
      else            { zb[x]=(char)zval; pd[x]=(unsigned char)(pal|t); } \
    } \
  }

static int TileNormZSH(int sx,int addr,int pal,int zval)
{
	unsigned int pack=0; 
	unsigned int t=0;
	unsigned char *pd = HighCol+sx;
	char *zb = HighSprZ+sx;
	int collision = 0;

	pack=*(unsigned int *)(RamVid+addr); // Get 8 pixels
	if (pack) {
		t=(pack&0x0000f000)>>12; sh_pixZ(0);
		t=(pack&0x00000f00)>> 8; sh_pixZ(1);
		t=(pack&0x000000f0)>> 4; sh_pixZ(2);
		t=(pack&0x0000000f)    ; sh_pixZ(3);
		t=(pack&0xf0000000)>>28; sh_pixZ(4);
		t=(pack&0x0f000000)>>24; sh_pixZ(5);
		t=(pack&0x00f00000)>>20; sh_pixZ(6);
		t=(pack&0x000f0000)>>16; sh_pixZ(7);
		if(collision) RamVReg->status |= 0x20;
		return 0;
	}
	return 1; // Tile blank
}

static int TileFlipZSH(int sx,int addr,int pal,int zval)
{
	unsigned int pack=0; 
	unsigned int t=0;
	unsigned char *pd = HighCol+sx;
	char *zb = HighSprZ+sx;
	int collision = 0;
	
	pack=*(unsigned int *)(RamVid+addr); // Get 8 pixels
	if (pack) {
		t=(pack&0x000f0000)>>16; sh_pixZ(0);
		t=(pack&0x00f00000)>>20; sh_pixZ(1);
		t=(pack&0x0f000000)>>24; sh_pixZ(2);
		t=(pack&0xf0000000)>>28; sh_pixZ(3);
		t=(pack&0x0000000f)    ; sh_pixZ(4);
		t=(pack&0x000000f0)>> 4; sh_pixZ(5);
		t=(pack&0x00000f00)>> 8; sh_pixZ(6);
		t=(pack&0x0000f000)>>12; sh_pixZ(7);
		if(collision) RamVReg->status |= 0x20;
		return 0;
	}
	return 1; // Tile blank
}

static void DrawStrip(struct TileStrip *ts, int sh)
{
	int tilex=0,dx=0,ty=0,code=0,addr=0,cells;
	int oldcode=-1,blank=-1; // The tile we know is blank
	int pal=0;

	// Draw tiles across screen:
	tilex = (-ts->hscroll)>>3;
	ty = (ts->line&7)<<1; // Y-Offset into tile
	dx = ((ts->hscroll-1)&7)+1;
	cells = ts->cells;
	if(dx != 8) cells++; // have hscroll, need to draw 1 cell more

	for (; cells; dx+=8,tilex++,cells--) {
		int zero=0;

		code=RamVid[ts->nametab + (tilex&ts->xmask)];
		if (code==blank) continue;
		if (code>>15) { // high priority tile
			int cval = code | (dx<<16) | (ty<<25);
			if(code&0x1000) cval^=7<<26;
			*ts->hc++ = cval; // cache it
			continue;
		}

		if (code!=oldcode) {
			oldcode = code;
			// Get tile address/2:
			addr=(code&0x7ff)<<4;
			addr+=ty;
			if (code&0x1000) addr^=0xe; // Y-flip
			pal=((code>>9)&0x30)|(sh<<6);
		}

		if (code&0x0800) zero=TileFlip(dx,addr,pal);
		else             zero=TileNorm(dx,addr,pal);

		if (zero) blank=code; // We know this tile is blank now
	}

	// terminate the cache list
	*ts->hc = 0;
}

static void DrawStripVSRam(struct TileStrip *ts, int plane)
{
	int tilex=0,dx=0,ty=0,code=0,addr=0,cell=0,nametabadd=0;
	int oldcode=-1,blank=-1; // The tile we know is blank
	int pal=0,scan=Scanline;

	// Draw tiles across screen:
	tilex=(-ts->hscroll)>>3;
	dx=((ts->hscroll-1)&7)+1;
	if(dx != 8) {
		int vscroll, line;
		cell--; // have hscroll, start with negative cell
		// also calculate intial VS stuff
		vscroll = RamSVid[plane];

		// Find the line in the name table
		line = (vscroll+scan)&ts->line&0xffff;		// ts->line is really ymask ..
		nametabadd = (line>>3)<<(ts->line>>24);		// .. and shift[width]
		ty = (line&7)<<1;							// Y-Offset into tile
	}

	for (; cell < ts->cells; dx+=8,tilex++,cell++) {
		int zero=0;

		if((cell&1)==0) {
			int line,vscroll;
			vscroll = RamSVid[plane+(cell&~1)];

			// Find the line in the name table
			line = (vscroll+scan)&ts->line&0xffff;	// ts->line is really ymask ..
			nametabadd = (line>>3)<<(ts->line>>24);	// .. and shift[width]
			ty = (line&7)<<1; 						// Y-Offset into tile
		}

		code = RamVid[ts->nametab + nametabadd + (tilex&ts->xmask)];
		if (code==blank) continue;
		if (code>>15) { // high priority tile
			int cval = code | (dx<<16) | (ty<<25);
			if(code&0x1000) cval^=7<<26;
			*ts->hc++ = cval; // cache it
			continue;
		}

		if (code!=oldcode) {
			oldcode = code;
			// Get tile address/2:
			addr=(code&0x7ff)<<4;
			if (code&0x1000) addr+=14-ty; else addr+=ty; // Y-flip
			pal=((code>>9)&0x30);
		}

		if (code&0x0800) zero=TileFlip(dx,addr,pal);
		else             zero=TileNorm(dx,addr,pal);

		if (zero) blank=code; // We know this tile is blank now
	}

	// terminate the cache list
	*ts->hc = 0;
}

static void DrawStripInterlace(struct TileStrip *ts)
{
	int tilex=0,dx=0,ty=0,code=0,addr=0,cells;
	int oldcode=-1,blank=-1; // The tile we know is blank
	int pal=0;

	// Draw tiles across screen:
	tilex=(-ts->hscroll)>>3;
	ty=(ts->line&15)<<1; // Y-Offset into tile
	dx=((ts->hscroll-1)&7)+1;
	cells = ts->cells;
	if(dx != 8) cells++; // have hscroll, need to draw 1 cell more

	for (; cells; dx+=8,tilex++,cells--) {
		int zero=0;

		code=RamVid[ts->nametab+(tilex&ts->xmask)];
		if (code==blank) continue;
		if (code>>15) { // high priority tile
			int cval = (code&0xfc00) | (dx<<16) | (ty<<25);
			cval |= (code&0x3ff)<<1;
			if(code&0x1000) cval^=0xf<<26;
			*ts->hc++ = cval; // cache it
			continue;
		}

		if (code!=oldcode) {
			oldcode = code;
			// Get tile address/2:
			addr=(code&0x7ff)<<5;
			if (code&0x1000) addr+=30-ty; else addr+=ty; // Y-flip
			pal=((code>>9)&0x30);
		}

		if (code&0x0800) zero=TileFlip(dx,addr,pal);
		else             zero=TileNorm(dx,addr,pal);

		if (zero) blank=code; // We know this tile is blank now
	}

	// terminate the cache list
	*ts->hc = 0;
}

static void DrawLayer(int plane, int *hcache, int maxcells, int sh)
{
	const char shift[4]={5,6,5,7}; // 32,64 or 128 sized tilemaps (2 is invalid)
	struct TileStrip ts;
	int width, height, ymask;
	int vscroll, htab;

	ts.hc = hcache;
	ts.cells = maxcells;

	// Work out the TileStrip to draw

	// Work out the name table size: 32 64 or 128 tiles (0-3)
	width  = RamVReg->reg[16];
	height = (width>>4)&3; 
	width &= 3;

	ts.xmask=(1<<shift[width])-1; // X Mask in tiles (0x1f-0x7f)
	ymask=(height<<8)|0xff;       // Y Mask in pixels
	if(width == 1)   ymask&=0x1ff;
	else if(width>1) ymask =0x0ff;

	// Find name table:
	if (plane==0) ts.nametab=(RamVReg->reg[2] & 0x38)<< 9; // A
	else          ts.nametab=(RamVReg->reg[4] & 0x07)<<12; // B

	htab = RamVReg->reg[13] << 9; // Horizontal scroll table address
	if ( RamVReg->reg[11] & 2)     htab += Scanline<<1; // Offset by line
	if ((RamVReg->reg[11] & 1)==0) htab &= ~0xf; // Offset by tile
	htab += plane; // A or B

	// Get horizontal scroll value, will be masked later
	ts.hscroll = RamVid[htab & 0x7fff];

	if((RamVReg->reg[12]&6) == 6) {
		// interlace mode 2
		vscroll = RamSVid[plane]; // Get vertical scroll value

		// Find the line in the name table
		ts.line=(vscroll+(Scanline<<1))&((ymask<<1)|1);
		ts.nametab+=(ts.line>>4)<<shift[width];

		DrawStripInterlace(&ts);
	} else if( RamVReg->reg[11]&4) {
		// shit, we have 2-cell column based vscroll
		// luckily this doesn't happen too often
		ts.line = ymask | (shift[width]<<24); // save some stuff instead of line
		DrawStripVSRam(&ts, plane);
	} else {
		vscroll = RamSVid[plane]; // Get vertical scroll value

		// Find the line in the name table
		ts.line = (vscroll+Scanline)&ymask;
		ts.nametab += (ts.line>>3)<<shift[width];

		DrawStrip(&ts, sh);
	}
}

static void DrawWindow(int tstart, int tend, int prio, int sh)
{
	int tilex=0, ty=0, nametab, code=0;
	int blank = -1; // The tile we know is blank

	// Find name table line:
	nametab  = (RamVReg->reg[3] & 0x3c)<<9;
	if (RamVReg->reg[12] & 1) nametab += (Scanline>>3)<<6;	// 40-cell mode
	else					  nametab += (Scanline>>3)<<5;	// 32-cell mode

	tilex = tstart<<1;
	tend <<= 1;

	ty = (Scanline & 7)<<1; // Y-Offset into tile

	if(!(rendstatus & 2)) {
		// check the first tile code
		code = RamVid[nametab + tilex];
		// if the whole window uses same priority (what is often the case), we may be able to skip this field
		if((code>>15) != prio) return;
	}

	// Draw tiles across screen:
	for (; tilex < tend; tilex++) {
		int addr=0, zero=0, pal;

		code = RamVid[nametab + tilex];
		if(code==blank) continue;
		if((code>>15) != prio) {
			rendstatus |= 2;
			continue;
		}

		pal=((code>>9)&0x30);

		if(sh) {
			int tmp, *zb = (int *)(HighCol+8+(tilex<<3));
			if(prio) {
				tmp = *zb;
				if(!(tmp&0x00000080)) tmp&=~0x000000c0; if(!(tmp&0x00008000)) tmp&=~0x0000c000;
				if(!(tmp&0x00800000)) tmp&=~0x00c00000; if(!(tmp&0x80000000)) tmp&=~0xc0000000;
				*zb++=tmp; tmp = *zb;
				if(!(tmp&0x00000080)) tmp&=~0x000000c0; if(!(tmp&0x00008000)) tmp&=~0x0000c000;
				if(!(tmp&0x00800000)) tmp&=~0x00c00000; if(!(tmp&0x80000000)) tmp&=~0xc0000000;
				*zb++=tmp;
			} else {
				pal |= 0x40;
			}
		}

		// Get tile address/2:
		addr = (code&0x7ff)<<4;
		if (code&0x1000) addr += 14-ty; else addr += ty; // Y-flip

		if (code&0x0800) zero = TileFlip(8+(tilex<<3),addr,pal);
		else             zero = TileNorm(8+(tilex<<3),addr,pal);

		if (zero) blank = code; // We know this tile is blank now
	}
	// terminate the cache list
	//*hcache = 0;
}

static void DrawTilesFromCache(int *hc, int sh)
{
	int code, addr, zero, dx;
	int pal;
	short blank=-1; // The tile we know is blank

	// *ts->hc++ = code | (dx<<16) | (ty<<25); // cache it

	while((code = *hc++)) {
		if(!sh && (short)code == blank) continue;

		// Get tile address/2:
		addr=(code&0x7ff)<<4;
		addr+=(unsigned int)code>>25; // y offset into tile
		dx=(code>>16)&0x1ff;
		if(sh) {
			unsigned char *zb = HighCol+dx;
			if(!(*zb&0x80)) *zb&=0x3f; zb++; if(!(*zb&0x80)) *zb&=0x3f; zb++;
			if(!(*zb&0x80)) *zb&=0x3f; zb++; if(!(*zb&0x80)) *zb&=0x3f; zb++;
			if(!(*zb&0x80)) *zb&=0x3f; zb++; if(!(*zb&0x80)) *zb&=0x3f; zb++;
			if(!(*zb&0x80)) *zb&=0x3f; zb++; if(!(*zb&0x80)) *zb&=0x3f; zb++;
		}

		pal=((code>>9)&0x30);

		if (code&0x0800) zero=TileFlip(dx,addr,pal);
		else             zero=TileNorm(dx,addr,pal);

		if(zero) blank=(short)code;
	}
}

// Index + 0  :    hhhhvvvv ab--hhvv yyyyyyyy yyyyyyyy // a: offscreen h, b: offs. v, h: horiz. size
// Index + 4  :    xxxxxxxx xxxxxxxx pccvhnnn nnnnnnnn // x: x coord + 8

static void DrawSprite(int *sprite, int **hc, int sh)
{
	int width=0,height=0;
	int row=0,code=0;
	int pal;
	int tile=0,delta=0;
	int sx, sy;
	int (*fTileFunc)(int sx,int addr,int pal);

	// parse the sprite data
	sy=sprite[0];
	code=sprite[1];
	sx=code>>16;		// X
	width=sy>>28;
	height=(sy>>24)&7;	// Width and height in tiles
	sy=(sy<<16)>>16;	// Y

	row=Scanline-sy;	// Row of the sprite we are on

	if (code&0x1000) row=(height<<3)-1-row; // Flip Y

	tile=code&0x7ff;	// Tile number
	tile+=row>>3;		// Tile number increases going down
	delta=height;		// Delta to increase tile by going right
	if (code&0x0800) { tile+=delta*(width-1); delta=-delta; } // Flip X

	tile<<=4; tile+=(row&7)<<1; // Tile address

	if(code&0x8000) { // high priority - cache it
		*(*hc)++ = (tile<<16)|((code&0x0800)<<5)|((sx<<6)&0x0000ffc0)|((code>>9)&0x30)|((sprite[0]>>16)&0xf);
	} else {
		delta<<=4; // Delta of address
		pal=((code>>9)&0x30)|(sh<<6);

		if(sh && (code&0x6000) == 0x6000) {
			if(code&0x0800) fTileFunc=TileFlipSH;
			else            fTileFunc=TileNormSH;
		} else {
			if(code&0x0800) fTileFunc=TileFlip;
			else            fTileFunc=TileNorm;
		}

		for (; width; width--,sx+=8,tile+=delta) {
			if(sx<=0)   continue;
			if(sx>=328) break; // Offscreen

			tile&=0x7fff; // Clip tile address
			fTileFunc(sx,tile,pal);
		}
	}
}

// Index + 0  :    hhhhvvvv s---hhvv yyyyyyyy yyyyyyyy // s: skip flag, h: horiz. size
// Index + 4  :    xxxxxxxx xxxxxxxx pccvhnnn nnnnnnnn // x: x coord + 8

static void DrawSpriteZ(int pack, int pack2, int shpri, int sprio)
{
	int width=0,height=0;
	int row=0;
	int pal;
	int tile=0,delta=0;
	int sx, sy;
	int (*fTileFunc)(int sx,int addr,int pal,int zval);

	// parse the sprite data
	sx    =  pack2>>16;			// X
	sy    = (pack <<16)>>16;	// Y
	width =  pack >>28;
	height= (pack >>24)&7;		// Width and height in tiles

	row = Scanline-sy; 			// Row of the sprite we are on

	if (pack2&0x1000) row=(height<<3)-1-row; // Flip Y

	tile = pack2&0x7ff; 		// Tile number
	tile+= row>>3;				// Tile number increases going down
	delta=height;				// Delta to increase tile by going right
	if (pack2&0x0800) { 		// Flip X
		tile += delta*(width-1); 
		delta = -delta; 
	} 

	tile<<=4; 
	tile+=(row&7)<<1; // Tile address
	delta<<=4; // Delta of address
	pal=((pack2>>9)&0x30);
	if((shpri&1)&&!(shpri&2)) pal|=0x40;

	shpri&=1;
	if((pack2&0x6000) != 0x6000) shpri = 0;
	shpri |= (pack2&0x0800)>>10;
	switch(shpri) {
	default:
	case 0: fTileFunc=TileNormZ;   break;
	case 1: fTileFunc=TileNormZSH; break;
	case 2: fTileFunc=TileFlipZ;   break;
	case 3: fTileFunc=TileFlipZSH; break;
	}

	for (; width; width--,sx+=8,tile+=delta) {
		if(sx<=0)   continue;
		if(sx>=328) break; // Offscreen

		tile&=0x7fff; // Clip tile address
		fTileFunc(sx,tile,pal,sprio);
	}
}


static void DrawSpriteInterlace(unsigned int *sprite)
{
	int width=0,height=0;
	int row=0,code=0;
	int pal;
	int tile=0,delta=0;
	int sx, sy;
	
	// parse the sprite data
	sy=sprite[0];
	height=sy>>24;
	sy=(sy&0x3ff)-0x100; // Y
	width=(height>>2)&3; height&=3;
	width++; height++; // Width and height in tiles
	
	row=(Scanline<<1)-sy; // Row of the sprite we are on
	
	code=sprite[1];
	sx=((code>>16)&0x1ff)-0x78; // X
	
	if (code&0x1000) row^=(16<<height)-1; // Flip Y
	
	tile=code&0x3ff; // Tile number
	tile+=row>>4; // Tile number increases going down
	delta=height; // Delta to increase tile by going right
	if (code&0x0800) { tile+=delta*(width-1); delta=-delta; } // Flip X
	
	tile<<=5; tile+=(row&15)<<1; // Tile address
	
	delta<<=5; // Delta of address
	pal=((code>>9)&0x30); // Get palette pointer

	for (; width; width--,sx+=8,tile+=delta) {
		if(sx<=0)   continue;
		if(sx>=328) break; // Offscreen

		tile&=0x7fff; // Clip tile address
		if (code&0x0800) TileFlip(sx,tile,pal);
		else             TileNorm(sx,tile,pal);
	}
}


static void DrawAllSpritesInterlace(int pri, int maxwidth)
{
	int i,u,table,link=0,sline=Scanline<<1;
	unsigned int *sprites[80]; // Sprite index
	
	table = RamVReg->reg[5]&0x7f;
	if (RamVReg->reg[12]&1) table&=0x7e; // Lowest bit 0 in 40-cell mode
	table<<=8; // Get sprite table address/2
	
	for (i=u=0; u < 80 && i < 21; u++) {
		unsigned int *sprite;
		int code, sx, sy, height;

		sprite=(unsigned int *)(RamVid+((table+(link<<2))&0x7ffc)); // Find sprite

		// get sprite info
		code = sprite[0];
		sx = sprite[1];
		if(((sx>>15)&1) != pri) goto nextsprite; // wrong priority sprite
		
		// check if it is on this line
		sy = (code&0x3ff)-0x100;
		height = (((code>>24)&3)+1)<<4;
		if(sline < sy || sline >= sy+height) goto nextsprite; // no
		
		// check if sprite is not hidden offscreen
		sx = (sx>>16)&0x1ff;
		sx -= 0x78; // Get X coordinate + 8
		if(sx <= -8*3 || sx >= maxwidth) goto nextsprite;
		
		// sprite is good, save it's pointer
		sprites[i++]=sprite;
		
		nextsprite:
		// Find next sprite
		link=(code>>16)&0x7f;
		if(!link) break; // End of sprites
	}

	// Go through sprites backwards:
	for (i-- ;i>=0; i--)
		DrawSpriteInterlace(sprites[i]);
}

static void DrawSpritesFromCache(int *hc, int sh)
{
	int code, tile, sx, delta, width;
	int pal;
	int (*fTileFunc)(int sx,int addr,int pal);
	
	// *(*hc)++ = (tile<<16)|((code&0x0800)<<5)|((sx<<6)&0x0000ffc0)|((code>>9)&0x30)|((sprite[0]>>24)&0xf);
	
	while((code=*hc++)) {
		pal=(code&0x30);
		delta=code&0xf;
		width=delta>>2; delta&=3;
		width++; delta++; // Width and height in tiles
		if (code&0x10000) delta=-delta; // Flip X
		delta<<=4;
		tile=((unsigned int)code>>17)<<1;
		sx=(code<<16)>>22; // sx can be negative (start offscreen), so sign extend
		
		if(sh && pal == 0x30) { //
			if(code&0x10000) fTileFunc=TileFlipSH;
			else             fTileFunc=TileNormSH;
		} else {
			if(code&0x10000) fTileFunc=TileFlip;
			else             fTileFunc=TileNorm;
		}

		for (; width; width--,sx+=8,tile+=delta) {
			if(sx<=0)   continue;
			if(sx>=328) break; // Offscreen

			tile&=0x7fff; // Clip tile address
			fTileFunc(sx,tile,pal);
		}
	}
}

// Index + 0  :    ----hhvv -lllllll -------y yyyyyyyy
// Index + 4  :    -------x xxxxxxxx pccvhnnn nnnnnnnn
// v
// Index + 0  :    hhhhvvvv ab--hhvv yyyyyyyy yyyyyyyy // a: offscreen h, b: offs. v, h: horiz. size
// Index + 4  :    xxxxxxxx xxxxxxxx pccvhnnn nnnnnnnn // x: x coord + 8

static void PrepareSprites(int full)
{
	int u=0,link=0,sblocks=0;
	int table=0;
	int *pd = HighPreSpr;
	
	table=RamVReg->reg[5]&0x7f;
	if (RamVReg->reg[12]&1) table&=0x7e; // Lowest bit 0 in 40-cell mode
	table<<=8; // Get sprite table address/2
	
	if (!full) {
		int pack;
		// updates: tilecode, sx
		for (u=0; u < 80 && (pack = *pd); u++, pd+=2) {
			unsigned int *sprite;
			int code, code2, sx, sy, skip=0;
			
			sprite=(unsigned int *)(RamVid+((table+(link<<2))&0x7ffc)); // Find sprite
			
			// parse sprite info
			code  = sprite[0];
			code2 = sprite[1];
			code2 &= ~0xfe000000;
			code2 -=  0x00780000; // Get X coordinate + 8 in upper 16 bits
			sx = code2>>16;

			if((sx <= 8-((pack>>28)<<3) && sx >= -0x76) || sx >= 328) skip=1<<23;
			else if ((sy = (pack<<16)>>16) < 240 && sy > -32) {
				int sbl = (2<<(pack>>28))-1;
				sblocks |= sbl<<(sy>>3);
			}

			*pd = (pack&~(1<<23))|skip;
			*(pd+1) = code2;
			
			// Find next sprite
			link=(code>>16)&0x7f;
			if(!link) break; // End of sprites
		}
		SpriteBlocks |= sblocks;
	} else {
		for (; u < 80; u++) {
			unsigned int *sprite;
			int code, code2, sx, sy, hv, height, width, skip=0, sx_min;
			
			sprite=(unsigned int *)(RamVid+((table+(link<<2))&0x7ffc)); // Find sprite
			
			// parse sprite info
			code = sprite[0];
			sy = (code&0x1ff)-0x80;
			hv = (code>>24)&0xf;
			height = (hv&3)+1;
			
			if(sy > 240 || sy + (height<<3) <= 0) skip|=1<<22;
			
			width  = (hv>>2)+1;
			code2 = sprite[1];
			sx = (code2>>16)&0x1ff;
			sx -= 0x78; // Get X coordinate + 8
			sx_min = 8-(width<<3);
    
			if((sx <= sx_min && sx >= -0x76) || sx >= 328) skip|=1<<23;
			else if (sx > sx_min && !skip) {
				int sbl = (2<<height)-1;
				int shi = sy>>3;
				if(shi < 0) shi=0; // negative sy
				sblocks |= sbl<<shi;
			}
    
			*pd++ = (width<<28)|(height<<24)|skip|(hv<<16)|((unsigned short)sy);
			*pd++ = (sx<<16)|((unsigned short)code2);
			
			// Find next sprite
			link=(code>>16)&0x7f;
			if(!link) break; // End of sprites
		}
		SpriteBlocks = sblocks;
		*pd = 0; // terminate
	}
}

static void DrawAllSprites(int *hcache, int maxwidth, int prio, int sh)
{
	int i,u,n;
	int sx1seen=0; // sprite with x coord 1 or 0 seen
	int ntiles = 0; // tile counter for sprite limit emulation
	int *sprites[40]; // Sprites to draw in fast mode
	int *ps, pack, rs = rendstatus, scan=Scanline;

	if(rs&8) {
		DrawAllSpritesInterlace(prio, maxwidth);
		return;
	}
	if(rs&0x11) {
		//dprintf("PrepareSprites(%i) [%i]", (rs>>4)&1, scan);
		PrepareSprites(rs&0x10);
		rendstatus=rs&~0x11;
	}
	if (!(SpriteBlocks & (1<<(scan>>3)))) return;

	if(((rs&4)||sh)&&prio==0)
		memset(HighSprZ, 0, 328);
	if(!(rs&4)&&prio) {
		if(hcache[0]) DrawSpritesFromCache(hcache, sh);
		return;
	}

	ps = HighPreSpr;

	// Index + 0  :    hhhhvvvv ab--hhvv yyyyyyyy yyyyyyyy // a: offscreen h, b: offs. v, h: horiz. size
	// Index + 4  :    xxxxxxxx xxxxxxxx pccvhnnn nnnnnnnn // x: x coord + 8

	for(i=u=n=0; (pack = *ps) && n < 20; ps+=2, u++) {
		int sx, sy, row, pack2;

		if(pack & 0x00400000) continue;

		// get sprite info
		pack2 = *(ps+1);
		sx =  pack2>>16;
		sy = (pack <<16)>>16;
		row = scan-sy;

		//dprintf("x: %i y: %i %ix%i", sx, sy, (pack>>28)<<3, (pack>>21)&0x38);

		if(sx == -0x77) sx1seen |= 1; // for masking mode 2

		// check if it is on this line
		if(row < 0 || row >= ((pack>>21)&0x38)) continue; // no
		n++; // number of sprites on this line (both visible and hidden, max is 20) [broken]

		// sprite limit
		ntiles += pack>>28;
		if(ntiles > 40) break;

		if(pack & 0x00800000) continue;

		// masking sprite?
		if(sx == -0x78) {
			if(!(sx1seen&1) || sx1seen==3) {
				break; // this sprite is not drawn and remaining sprites are masked
			}
			if((sx1seen>>8) == 0) sx1seen=(i+1)<<8;
			continue;
		}
		else if(sx == -0x77) {
			// masking mode2 (Outrun, Galaxy Force II, Shadow of the beast)
			if(sx1seen>>8) { 
				i=(sx1seen>>8)-1; 
				break; 
			} // seen both 0 and 1
			sx1seen |= 2;
			continue;
		}

		// accurate sprites
		//dprintf("P:%i",((sx>>15)&1));
		if(rs&4) {
			// might need to skip this sprite
			if((pack2&0x8000) ^ (prio<<15)) continue;
			DrawSpriteZ(pack,pack2,sh|(prio<<1),(char)(0x1f-n));
			continue;
		}

		// sprite is good, save it's pointer
		sprites[i++]=ps;
	}

	// Go through sprites backwards:
	if(!(rs&4)) {
		for (i--; i>=0; i--)
			DrawSprite(sprites[i],&hcache,sh);

		// terminate cache list
		*hcache = 0;
	}
}


static void BackFill(int reg7, int sh)
{
	// Start with a blank scanline (background colour):
	unsigned int *pd = (unsigned int *)(HighCol+8);
	unsigned int *end= (unsigned int *)(HighCol+8+320);
	unsigned int back = reg7 & 0x3f;
	back |= sh<<6;
	back |= back<<8;
	back |= back<<16;
	do { pd[0]=pd[1]=pd[2]=pd[3]=back; pd+=4; } while (pd < end);
}


static int DrawDisplay(int sh)
{
	int maxw, maxcells;
	int win=0, edge=0, hvwind=0;
	
	if(RamVReg->reg[12] & 1) {
		maxw = 328; maxcells = 40;
	} else {
		maxw = 264; maxcells = 32;
	}
	
	// Find out if the window is on this line:
	win = RamVReg->reg[0x12];
	edge = (win & 0x1f)<<3;
  	
  	if (win&0x80) { if (Scanline>=edge) hvwind=1; }
	else          { if (Scanline< edge) hvwind=1; }
	
	if(!hvwind) { // we might have a vertical window here 
		win = RamVReg->reg[0x11];
		edge = win&0x1f;
		if(win&0x80) {
			if(!edge) hvwind=1;
			else if(edge < (maxcells>>1)) hvwind=2;
		} else {
			if(!edge);
			else if(edge < (maxcells>>1)) hvwind=2;
			else hvwind=1;
		}
	}	
	
	DrawLayer(1, HighCacheB, maxcells, sh);
	if(hvwind == 1)
		DrawWindow(0, maxcells>>1, 0, sh); // HighCacheAW
	else if(hvwind == 2) {
		// ahh, we have vertical window
		DrawLayer(0, HighCacheA, (win&0x80) ? edge<<1 : maxcells, sh);
		DrawWindow((win&0x80) ? edge : 0, (win&0x80) ? maxcells>>1 : edge, 0, sh); // HighCacheW
	} else
		DrawLayer(0, HighCacheA, maxcells, sh);
	DrawAllSprites(HighCacheS, maxw, 0, sh);
	
	if(HighCacheB[0]) 
		DrawTilesFromCache(HighCacheB, sh);
	if(hvwind == 1)
		DrawWindow(0, maxcells>>1, 1, sh);
	else if(hvwind == 2) {
		if(HighCacheA[0]) DrawTilesFromCache(HighCacheA, sh);
		DrawWindow((win&0x80) ? edge : 0, (win&0x80) ? maxcells>>1 : edge, 1, sh);
	} else
		if(HighCacheA[0]) DrawTilesFromCache(HighCacheA, sh);
	DrawAllSprites(HighCacheS, maxw, 1, sh);

	return 0;
}

static void PicoFrameStart()
{
	// prepare to do this frame
	rendstatus = 0x80 >> 5;							// accurate sprites
	RamVReg->status &= ~0x0020;
	if((RamVReg->reg[12]&6) == 6) rendstatus |= 8;	// interlace mode
	//if(Pico.m.dirtyPal) Pico.m.dirtyPal = 2; 		// reset dirty if needed
	PrepareSprites(1);
}

static int PicoLine(int /*scan*/)
{
	int sh = (RamVReg->reg[0xC] & 8)>>3; // shadow/hilight?

	BackFill(RamVReg->reg[7], sh);
	if (RamVReg->reg[1] & 0x40)
		DrawDisplay(sh);
	
	{
		int num = Scanline + 1;
		if (!(RamVReg->reg[1] & 8)) num += 8;
		HighCol = HighColFull + ( num * (8 + 320 + 8) );
	};

	return 0;
}

static void MegadriveDraw()
{
	unsigned short * pDest = (unsigned short *)pBurnDraw;

	if ((RamVReg->reg[12]&1) || !(MegadriveDIP[1] & 0x03)) {
	
		for (int j=0; j<224; j++) {
			unsigned char * pSrc = HighColFull + (j+9)*(8+320+8) + 8;
			for (int i=0;i<320;i++)
				pDest[i] = MegadriveCurPal[ pSrc[i] ];
			pDest += 320;
		}
	
	} else {  
		
		if (( MegadriveDIP[1] & 0x03 ) == 0x01 ) {
			// Center 
			pDest += 32;
			for (int j=0; j<224; j++) {
				unsigned char * pSrc = HighColFull + (j+9)*(8+320+8) + 8;

				memset((unsigned char *)pDest -  32*2, 0, 64);
				
				for (int i=0;i<256;i++)
					pDest[i] = MegadriveCurPal[ pSrc[i] ];
				
				memset((unsigned char *)pDest + 256*2, 0, 64);
				
				pDest += 320;
			}
		} else {
			// Zoom
			for (int j=0; j<224; j++) {
				unsigned char * pSrc = HighColFull + (j+9)*(8+320+8) + 8;
				unsigned int delta = 0;
				for (int i=0;i<320;i++) {
					pDest[i] = MegadriveCurPal[ pSrc[ delta >> 16 ] ];
					delta += 0xCCCC;
				}
				pDest += 320;
			}
		}
		
	}
}

#define TOTAL_68K_CYCLES	((double)OSC_NTSC / 7) / 60
#define TOTAL_Z80_CYCLES	((double)OSC_NTSC / 15) / 60
#define TOTAL_68K_CYCLES_PAL	((double)OSC_PAL / 7) / 50
#define TOTAL_Z80_CYCLES_PAL	((double)OSC_PAL / 15) / 50

int MegadriveFrame()
{
	int nSoundBufferPos = 0;
	
	if (MegadriveReset) {
		MegadriveResetDo();
		MegadriveReset = 0;
	}

	if (bMegadriveRecalcPalette) {
		for (int i=0;i<0x40;i++)
			CalcCol(i, RamPal[i]);
		bMegadriveRecalcPalette = 0;	
	}
	
	JoyPad->pad[0] = JoyPad->pad[1] = 0;
	for (int i = 0; i < 12; i++) {
		JoyPad->pad[0] |= (MegadriveJoy1[i] & 1) << i;
		JoyPad->pad[1] |= (MegadriveJoy2[i] & 1) << i;
	}
	
	
	SekNewFrame();
	ZetNewFrame();
	
	HighCol = HighColFull;
	PicoFrameStart();

	int lines,lines_vis = 224,line_sample;
	int done_z80 = 0;
	int hint = RamVReg->reg[10]; // Hint counter
	int total_68k_cycles, total_z80_cycles;
	
	if( Hardware & 0x40 ) {
		lines  = 313;
		line_sample = 68;
		if( RamVReg->reg[1]&8 ) lines_vis = 240;
		total_68k_cycles = (int)TOTAL_68K_CYCLES_PAL;
		total_z80_cycles = (int)TOTAL_Z80_CYCLES_PAL;
	} else {
		lines  = 262;
		line_sample = 93;
		total_68k_cycles = (int)TOTAL_68K_CYCLES;
		total_z80_cycles = (int)TOTAL_Z80_CYCLES;
	}
	
	cycles_68k = total_68k_cycles / lines;
	cycles_z80 = total_z80_cycles / lines;
  
	RamVReg->status &= ~0x88; // clear V-Int, come out of vblank
	
	for (int y=0; y<lines; y++) {

		Scanline = y;

		/*if(PicoOpt&0x20)*/ {
			// pad delay (for 6 button pads)
			if(JoyPad->padDelay[0]++ > 25) JoyPad->padTHPhase[0] = 0;
			if(JoyPad->padDelay[1]++ > 25) JoyPad->padTHPhase[1] = 0;
		}

		// H-Interrupts:
		if((y <= lines_vis) && (--hint < 0)) { // y <= lines_vis: Comix Zone, Golden Axe
			//dprintf("rhint:old @ %06x", SekPc);
			hint = RamVReg->reg[10]; // Reload H-Int counter
			RamVReg->pending_ints |= 0x10;
			if (RamVReg->reg[0] & 0x10) {
				SekOpen(0);
				SekSetIRQLine(4, SEK_IRQSTATUS_AUTO);
				SekClose();
			}
		}

		// V-Interrupt:
		if (y == lines_vis) {
			//dprintf("vint: @ %06x [%i|%i]", SekPc, y, SekCycleCnt);
			RamVReg->status |= 0x88; // V-Int happened, go into vblank
			
			// there must be a gap between H and V ints, also after vblank bit set (Mazin Saga, Bram Stoker's Dracula)
			SekOpen(0);
//			done_68k+=SekRun(128); 
			BurnTimerUpdate((y * cycles_68k) + 128 - cycles_68k);
			SekClose();

			RamVReg->pending_ints |= 0x20;
			if(RamVReg->reg[1] & 0x20) {
				SekOpen(0);
				SekSetIRQLine(6, SEK_IRQSTATUS_AUTO);
				SekClose();
			}
		}

		// decide if we draw this line
		if ((!(RamVReg->reg[1]&8) && y<=224) || ((RamVReg->reg[1]&8) && y<240))
			PicoLine(y);

		// Run scanline
		SekOpen(0);
		BurnTimerUpdate(y * cycles_68k);
		SekClose();
		
		if (Z80HasBus && !MegadriveZ80Reset) {
			ZetOpen(0);
			done_z80 += ZetRun(cycles_z80);
			if (y == line_sample) ZetSetIRQLine(0, ZET_IRQSTATUS_ACK);
			if (y == line_sample + 1) ZetSetIRQLine(0, ZET_IRQSTATUS_NONE);
			ZetClose();
		}
		
		if (pBurnSoundOut) {
			int nSegmentLength = nBurnSoundLen - nSoundBufferPos;
			short* pSoundBuf = pBurnSoundOut + (nSoundBufferPos << 1);
			SekOpen(0);
			BurnYM2612Update(pSoundBuf, nSegmentLength);
			SekClose();
			SN76496Update(0, pSoundBuf, nSegmentLength);
			nSoundBufferPos += nSegmentLength;
		}
	}
	
	if (pBurnDraw) MegadriveDraw();

	SekOpen(0);
	BurnTimerEndFrame(total_68k_cycles);
	SekClose();
	
	if (Z80HasBus && !MegadriveZ80Reset) {
		if (done_z80 < total_z80_cycles) {
			ZetOpen(0);
			ZetRun(total_z80_cycles - done_z80);
			ZetClose();
		}
	}
	
	if (pBurnSoundOut) {
		int nSegmentLength = nBurnSoundLen - nSoundBufferPos;
		short* pSoundBuf = pBurnSoundOut + (nSoundBufferPos << 1);
		if (nSegmentLength) {
			SekOpen(0);
			BurnYM2612Update(pSoundBuf, nSegmentLength);
			SekClose();
			SN76496Update(0, pSoundBuf, nSegmentLength);
		}
	}
	
	return 0;
}

int MegadriveScan(int /*nAction*/, int * /*pnMin*/)
{
	//BurnYM2612Scan(nAction, pnMin);	
	
	return 1;
}
