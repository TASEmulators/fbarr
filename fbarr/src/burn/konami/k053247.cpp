#include "tiles_generic.h"
#include "konamiic.h"

#define K053247_CUSTOMSHADOW	0x20000000
#define K053247_SHDSHIFT		20

static unsigned char  K053246Regs[8];
static unsigned char  K053246_OBJCHA_line;
static unsigned char *K053247Ram;
static unsigned short K053247Regs[16];

static unsigned char *K053246Gfx;
static unsigned int   K053246Mask;

static int K053247_dx;
static int K053247_dy;
static int K053247_wraparound;

static void (*K053247Callback)(int *code, int *color, int *priority);

void K053247Reset()
{
	memset (K053247Ram,  0, 0x1000);
	memset (K053247Regs, 0, 16 * sizeof (short));
	memset (K053246Regs, 0, 8);

	K053246_OBJCHA_line = 0; // clear
}

void K053247Scan(int nAction)
{
	struct BurnArea ba;
	
	if (nAction & ACB_MEMORY_RAM) {
		memset(&ba, 0, sizeof(ba));
		ba.Data	  = K053247Ram;
		ba.nLen	  = 0x1000;
		ba.szName = "K053247 Ram";
		BurnAcb(&ba);

		ba.Data	  = K053247Regs;
		ba.nLen	  = 0x0010 * sizeof(short);
		ba.szName = "K053247 Regs";
		BurnAcb(&ba);

		ba.Data	  = K053246Regs;
		ba.nLen	  = 0x0008;
		ba.szName = "K053246 Regs";
		BurnAcb(&ba);

		SCAN_VAR(K053246_OBJCHA_line);
		SCAN_VAR(K053247_wraparound);
	}
}

void K053247Init(unsigned char *gfxrom, int gfxlen, void (*Callback)(int *code, int *color, int *priority))
{
	K053247Ram = (unsigned char*)malloc(0x1000);

	K053246Gfx = gfxrom;
	K053246Mask = gfxlen;

	K053247Callback = Callback;

	K053247_dx = 0;
	K053247_dy = 0;
	K053247_wraparound = 1;

	KonamiIC_K053247InUse = 1;
}

void K053247Exit()
{
	if (K053247Ram) {
		free (K053247Ram);
		K053247Ram = NULL;
	}

	memset (K053247Regs, 0, 16 * sizeof(short));
}

void K053247Export(unsigned char **ram, unsigned char **gfx, void (**callback)(int *, int *, int *), int *dx, int *dy)
{
	if (ram) *ram = K053247Ram;
	if (gfx) *gfx = K053246Gfx;

	if (dx)	*dx = K053247_dx;
	if (dy)	*dy = K053247_dy;

	if(callback) *callback = K053247Callback;
}

void K053247GfxDecode(unsigned char *src, unsigned char *dst, int len) // 16x16
{
	for (int i = 0; i < len; i++)
	{
		int t = src[i^1];
		dst[(i << 1) + 0] = t >> 4;
		dst[(i << 1) + 1] = t & 0x0f;
	}
}

void K053247SetSpriteOffset(int offsx, int offsy)
{
	K053247_dx = offsx;
	K053247_dy = offsy;
}

void K053247WrapEnable(int status)
{
	K053247_wraparound = status;
}

unsigned char K053247Read(int offset)
{
	return K053247Ram[offset & 0xfff];
}

void K053247Write(int offset, int data)
{
	if (data & 0x10000) { // use word
		*((unsigned short*)(K053247Ram + (offset & 0xffe))) = data;
	} else {
		K053247Ram[offset & 0xfff] = data;
	}
}

unsigned char K053246Read(int offset)
{
	if (K053246_OBJCHA_line) // assert_line
	{
		int addr;

		addr = (K053246Regs[6] << 17) | (K053246Regs[7] << 9) | (K053246Regs[4] << 1) | ((offset & 1) ^ 1);
		addr &= K053246Mask;

		return K053246Gfx[addr];
	}
	else
	{
		return 0;
	}
}

void K053246Write(int offset, int data)
{
	if (data & 0x10000) { // handle it as a word
		*((unsigned short*)(K053246Regs + (offset & 6))) = data;
	} else {
		K053246Regs[offset & 7] = data;
	}
}

void K053246_set_OBJCHA_line(int state)
{
	K053246_OBJCHA_line = state;
}

int K053246_is_IRQ_enabled()
{
	return K053246Regs[5] & 0x10;
}

void K053247SpritesRender(unsigned char *gfxbase, int priority)
{
#define NUM_SPRITES 256

	static const int xoffset[8] = { 0, 1, 4, 5, 16, 17, 20, 21 };
	static const int yoffset[8] = { 0, 2, 8, 10, 32, 34, 40, 42 };

	int sortedlist[NUM_SPRITES];
	int offs,zcode;
	int ox,oy,color,code,size,w,h,x,y,xa,ya,flipx,flipy,mirrorx,mirrory,shadow,zoomx,zoomy,primask;
	int nozoom,count,temp;//shdmask,

	int flipscreenx = K053246Regs[5] & 0x01;
	int flipscreeny = K053246Regs[5] & 0x02;
	int offx = (short)((K053246Regs[0] << 8) | K053246Regs[1]);
	int offy = (short)((K053246Regs[2] << 8) | K053246Regs[3]);

	unsigned short *SprRam = (unsigned short*)K053247Ram;

	int screen_width = nScreenWidth-1; //video_screen_get_width(machine->primary_screen);
//	UINT8 drawmode_table[256];
//	UINT8 shadowmode_table[256];
//	UINT8 *whichtable;

//	memset(drawmode_table, DRAWMODE_SOURCE, sizeof(drawmode_table));
//	drawmode_table[0] = DRAWMODE_NONE;
//	memset(shadowmode_table, DRAWMODE_SHADOW, sizeof(shadowmode_table));
//	shadowmode_table[0] = DRAWMODE_NONE;

//	if (machine->config->video_attributes & VIDEO_HAS_SHADOWS)
//	{
//		if (bitmap->bpp == 32 && (machine->config->video_attributes & VIDEO_HAS_HIGHLIGHTS))
//			shdmask = 3; // enable all shadows and highlights
//		else
//			shdmask = 0; // enable default shadows
//	}
//	else
//		shdmask = -1; // disable everything

	// Prebuild a sorted table by descending Z-order.
	zcode = -1; //K05324x_z_rejection;
	offs = count = 0;

	if (zcode == -1)
	{
		for (; offs<0x800; offs+=8)
			if (SprRam[offs] & 0x8000) sortedlist[count++] = offs;
	}
	else
	{
		for (; offs<0x800; offs+=8)
			if ((SprRam[offs] & 0x8000) && ((SprRam[offs] & 0xff) != zcode)) sortedlist[count++] = offs;
	}

	w = count;
	count--;
	h = count;

	if (!(K053247Regs[0xc/2] & 0x10))
	{
		// sort objects in decending order(smaller z closer) when OPSET PRI is clear
		for (y=0; y<h; y++)
		{
			offs = sortedlist[y];
			zcode = SprRam[offs] & 0xff;
			for (x=y+1; x<w; x++)
			{
				temp = sortedlist[x];
				code = SprRam[temp] & 0xff;
				if (zcode <= code) { zcode = code; sortedlist[x] = offs; sortedlist[y] = offs = temp; }
			}
		}
	}
	else
	{
		// sort objects in ascending order(bigger z closer) when OPSET PRI is set
		for (y=0; y<h; y++)
		{
			offs = sortedlist[y];
			zcode = SprRam[offs] & 0xff;
			for (x=y+1; x<w; x++)
			{
				temp = sortedlist[x];
				code = SprRam[temp] & 0xff;
				if (zcode >= code) { zcode = code; sortedlist[x] = offs; sortedlist[y] = offs = temp; }
			}
		}
	}

	for (int i = 0; i <= count; i++)
	{
		offs = sortedlist[i]; //count];

		code = SprRam[offs+1];
		shadow = color = SprRam[offs+6];
		primask = 0;

		(*K053247Callback)(&code,&color,&primask);

		if (primask != priority) continue;	//--------------------------------------- fix me!

		temp = SprRam[offs];

		size = (temp & 0x0f00) >> 8;
		w = 1 << (size & 0x03);
		h = 1 << ((size >> 2) & 0x03);

		/* the sprite can start at any point in the 8x8 grid. We have to */
		/* adjust the offsets to draw it correctly. Simpsons does this all the time. */
		xa = 0;
		ya = 0;
		if (code & 0x01) xa += 1;
		if (code & 0x02) ya += 1;
		if (code & 0x04) xa += 2;
		if (code & 0x08) ya += 2;
		if (code & 0x10) xa += 4;
		if (code & 0x20) ya += 4;
		code &= ~0x3f;

		oy = (short)SprRam[offs+2];
		ox = (short)SprRam[offs+3];

		if (K053247_wraparound)
		{
			offx &= 0x3ff;
			offy &= 0x3ff;
			oy &= 0x3ff;
			ox &= 0x3ff;
		}

		y = zoomy = SprRam[offs+4] & 0x3ff;
		if (zoomy) zoomy = (0x400000+(zoomy>>1)) / zoomy; else zoomy = 0x800000;
		if (!(temp & 0x4000))
		{
			x = zoomx = SprRam[offs+5] & 0x3ff;
			if (zoomx) zoomx = (0x400000+(zoomx>>1)) / zoomx;
			else zoomx = 0x800000;
		}
		else { zoomx = zoomy; x = y; }

		if ( K053246Regs[5] & 0x08 ) // Check only "Bit #3 is '1'?" (NOTE: good guess)
		{
			zoomx >>= 1;		// Fix sprite width to HALF size
			ox = (ox >> 1) + 1;	// Fix sprite draw position
			if (flipscreenx) ox += screen_width;
			nozoom = 0;
		}
		else
			nozoom = (x == 0x40 && y == 0x40);

		flipx = temp & 0x1000;
		flipy = temp & 0x2000;
		mirrorx = shadow & 0x4000;
		if (mirrorx) flipx = 0; // documented and confirmed
		mirrory = shadow & 0x8000;

	//	whichtable = drawmode_table;
	//	if (color == -1)
	//	{
	//		// drop the entire sprite to shadow unconditionally
	//		if (shdmask < 0) continue;
	//		color = 0;
	//		shadow = -1;
	//		whichtable = shadowmode_table;
	//		palette_set_shadow_mode(machine, 0);
	//	}
	//	else
	//	{
	//		if (shdmask >= 0)
	//		{
	//			shadow = (color & K053247_CUSTOMSHADOW) ? (color>>K053247_SHDSHIFT) : (shadow>>10);
	//			if (shadow &= 3) palette_set_shadow_mode(machine, (shadow-1) & shdmask);
	//		}
	//		else
	//			shadow = 0;
	//	}

		color &= 0xffff; // strip attribute flags

		if (flipscreenx)
		{
			ox = -ox;
			if (!mirrorx) flipx = !flipx;
		}
		if (flipscreeny)
		{
			oy = -oy;
			if (!mirrory) flipy = !flipy;
		}

		// apply wrapping and global offsets
		if (K053247_wraparound)
		{
			ox = ( ox - offx) & 0x3ff;
			oy = (-oy - offy) & 0x3ff;
			if (ox >= 0x300) ox -= 0x400;
			if (oy >= 0x280) oy -= 0x400;
		}
		else
		{
			ox =  ox - offx;
			oy = -oy - offy;
		}
		ox += K053247_dx;
		oy -= K053247_dy;

		ox = ((ox+16) & 0x3ff) - 16;
		oy = ((oy+16) & 0x3ff) - 16;

		// apply global and display window offsets

		/* the coordinates given are for the *center* of the sprite */
		ox -= (zoomx * w) >> 13;
		oy -= (zoomy * h) >> 13;

	//	drawmode_table[K053247_gfx->color_granularity-1] = shadow ? DRAWMODE_SHADOW : DRAWMODE_SOURCE;

		for (y = 0;y < h;y++)
		{
			int sx,sy,zw,zh;

			sy = oy + ((zoomy * y + (1<<11)) >> 12);
			zh = (oy + ((zoomy * (y+1) + (1<<11)) >> 12)) - sy;

			for (x = 0;x < w;x++)
			{
				int c,fx,fy;

				sx = ox + ((zoomx * x + (1<<11)) >> 12);
				zw = (ox + ((zoomx * (x+1) + (1<<11)) >> 12)) - sx;
				c = code;
				if (mirrorx)
				{
					if ((flipx == 0) ^ ((x<<1) < w))
					{
						/* mirror left/right */
						c += xoffset[(w-1-x+xa)&7];
						fx = 1;
					}
					else
					{
						c += xoffset[(x+xa)&7];
						fx = 0;
					}
				}
				else
				{
					if (flipx) c += xoffset[(w-1-x+xa)&7];
					else c += xoffset[(x+xa)&7];
					fx = flipx;
				}
				if (mirrory)
				{
					if ((flipy == 0) ^ ((y<<1) >= h))
					{
						/* mirror top/bottom */
						c += yoffset[(h-1-y+ya)&7];
						fy = 1;
					}
					else
					{
						c += yoffset[(y+ya)&7];
						fy = 0;
					}
				}
				else
				{
					if (flipy) c += yoffset[(h-1-y+ya)&7];
					else c += yoffset[(y+ya)&7];
					fy = flipy;
				}

				if (mirrory && h == 1)  /* Simpsons shadows */
				{
					if (nozoom)
					{
						if (!flipy) {
							if (flipx) {
								Render16x16Tile_Mask_FlipXY_Clip(pTransDraw, c, sx, sy, color, 4, 0 /* fix */, 0, gfxbase);
							} else {
								Render16x16Tile_Mask_FlipY_Clip(pTransDraw, c, sx, sy, color, 4, 0 /* fix */, 0, gfxbase);
							}
						} else {
							if (flipx) {
								Render16x16Tile_Mask_FlipX_Clip(pTransDraw, c, sx, sy, color, 4, 0 /* fix */, 0, gfxbase);
							} else {
								Render16x16Tile_Mask_Clip(pTransDraw, c, sx, sy, color, 4, 0 /* fix */, 0, gfxbase);
							}
						}
					}
					else
					{
						RenderZoomedTile(pTransDraw, gfxbase, c, color << 4, 0 /* fix */, sx, sy, fx, !fy, 16, 16, (zw << 16) >> 4, (zh << 16) >> 4);
					}
				}

				if (nozoom)
				{
					if (flipy) {
						if (flipx) {
							Render16x16Tile_Mask_FlipXY_Clip(pTransDraw, c, sx, sy, color, 4, 0 /* fix */, 0, gfxbase);
						} else {
							Render16x16Tile_Mask_FlipY_Clip(pTransDraw, c, sx, sy, color, 4, 0 /* fix */, 0, gfxbase);
						}
					} else {
						if (flipx) {
							Render16x16Tile_Mask_FlipX_Clip(pTransDraw, c, sx, sy, color, 4, 0 /* fix */, 0, gfxbase);
						} else {
							Render16x16Tile_Mask_Clip(pTransDraw, c, sx, sy, color, 4, 0 /* fix */, 0, gfxbase);
						}
					}
				}
				else
				{
					RenderZoomedTile(pTransDraw, gfxbase, c, color << 4, 0 /* fix */, sx, sy, fx, fy, 16, 16, (zw << 16) >> 4, (zh << 16) >> 4);
				}


			} // end of X loop
		} // end of Y loop

	} // end of sprite-list loop
#undef NUM_SPRITES
}
