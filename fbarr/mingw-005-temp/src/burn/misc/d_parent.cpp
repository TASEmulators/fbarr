// A module for keeping parents who have no driver in FBA

#include "burnint.h"

static unsigned char ParentReset         = 0;

static struct BurnInputInfo ParentInputList[] = {
	{"Reset"             , BIT_DIGITAL  , &ParentReset        , "reset"     },
};

STDINPUTINFO(Parent)

static int ParentInit()
{
	return 1;
}

static int ParentExit()
{
	return 0;
}

static struct BurnRomInfo BagmanRomDesc[] = {
	{ "e9_b05.bin",         0x01000, 0xe0156191, BRF_ESS | BRF_PRG },
	{ "f9_b06.bin",         0x01000, 0x7b758982, BRF_ESS | BRF_PRG },
	{ "f9_b07.bin",         0x01000, 0x302a077b, BRF_ESS | BRF_PRG },
	{ "k9_b08.bin",         0x01000, 0xf04293cb, BRF_ESS | BRF_PRG },
	{ "m9_b09s.bin",        0x01000, 0x68e83e4f, BRF_ESS | BRF_PRG },
	{ "n9_b10.bin",         0x01000, 0x1d6579f7, BRF_ESS | BRF_PRG },
	
	{ "e1_b02.bin",         0x01000, 0x4a0a6b55, BRF_ESS | BRF_PRG },
	{ "j1_b04.bin",         0x01000, 0xc680ef04, BRF_ESS | BRF_PRG },
	
	{ "c1_b01.bin",         0x01000, 0x705193b2, BRF_ESS | BRF_PRG },
	{ "f1_b03s.bin",        0x01000, 0xdba1eda7, BRF_ESS | BRF_PRG },

	{ "p3.bin",             0x00020, 0x2a855523, BRF_GRA },
	{ "r3.bin",             0x00020, 0xae6f1019, BRF_GRA },
	{ "r6.bin",             0x00020, 0xc58a4f6a, BRF_GRA },
	
	{ "r9_b11.bin",         0x01000, 0x2e0057ff, BRF_SND },
	{ "t9_b12.bin",         0x01000, 0xb2120edd, BRF_SND },
};

STD_ROM_PICK(Bagman)
STD_ROM_FN(Bagman)

struct BurnDriver BurnDrvBagman = {
	"bagman", NULL, NULL, "1982",
	"Bagman\0", NULL, "Valadon Automation", "Miscellaneous",
	NULL, NULL, NULL, NULL,
	0, 2, HARDWARE_MISC_PRE90S, GBF_MAZE, 0,
	NULL, BagmanRomInfo, BagmanRomName, ParentInputInfo, NULL,
	ParentInit, ParentExit, NULL, NULL, NULL,
	0, NULL, NULL, NULL, NULL, 0, 224, 256, 3, 4
};

static struct BurnRomInfo CkongRomDesc[] = {
	{ "d05-07.bin",         0x01000, 0xb27df032, BRF_ESS | BRF_PRG },
	{ "f05-08.bin",         0x01000, 0x5dc1aaba, BRF_ESS | BRF_PRG },
	{ "h05-09.bin",         0x01000, 0xc9054c94, BRF_ESS | BRF_PRG },
	{ "k05-10.bin",         0x01000, 0x069c4797, BRF_ESS | BRF_PRG },
	{ "l05-11.bin",         0x01000, 0xae159192, BRF_ESS | BRF_PRG },
	{ "n05-12.bin",         0x01000, 0x966bc9ab, BRF_ESS | BRF_PRG },
	
	{ "n11-06.bin",         0x01000, 0x2dcedd12, BRF_ESS | BRF_PRG },
	{ "l11-05.bin",         0x01000, 0xfa7cbd91, BRF_ESS | BRF_PRG },
	{ "k11-04.bin",         0x01000, 0x3375b3bd, BRF_ESS | BRF_PRG },
	{ "h11-03.bin",         0x01000, 0x5655cc11, BRF_ESS | BRF_PRG },
	
	{ "c11-02.bin",         0x00800, 0xd1352c31, BRF_ESS | BRF_PRG },
	{ "a11-01.bin",         0x00800, 0xa7a2fdbd, BRF_ESS | BRF_PRG },

	{ "prom.v6",            0x00020, 0xb3fc1505, BRF_GRA },
	{ "prom.u6",            0x00020, 0x26aada9e, BRF_GRA },
	{ "prom.t6",            0x00020, 0x676b3166, BRF_GRA },
	
	{ "cc13j.bin",          0x01000, 0x5f0bcdfb, BRF_SND },
	{ "cc12j.bin",          0x01000, 0x9003ffbd, BRF_SND },
};

STD_ROM_PICK(Ckong)
STD_ROM_FN(Ckong)

struct BurnDriver BurnDrvCkong = {
	"ckong", NULL, NULL, "1981",
	"Crazy Kong Part II (set 1)\0", NULL, "Falcon", "Miscellaneous",
	NULL, NULL, NULL, NULL,
	0, 2, HARDWARE_MISC_PRE90S, GBF_PLATFORM, 0,
	NULL, CkongRomInfo, CkongRomName, ParentInputInfo, NULL,
	ParentInit, ParentExit, NULL, NULL, NULL,
	0, NULL, NULL, NULL, NULL, 0, 224, 256, 3, 4
};

static struct BurnRomInfo DkongjrRomDesc[] = {
	{ "dkj.5b",             0x02000, 0xdea28158, BRF_ESS | BRF_PRG },
	{ "dkj.5c",             0x02000, 0x6fb5faf6, BRF_ESS | BRF_PRG },
	{ "dkj.5e",             0x02000, 0xd042b6a8, BRF_ESS | BRF_PRG },
	
	{ "c_3h.bin",           0x01000, 0x715da5f8, BRF_ESS | BRF_PRG },
	
	{ "dkj.3n",             0x01000, 0x8d51aca9, BRF_ESS | BRF_PRG },
	{ "dkj.3p",             0x01000, 0x4ef64ba5, BRF_ESS | BRF_PRG },
	
	{ "v_7c.bin",           0x00800, 0xdc7f4164, BRF_ESS | BRF_PRG },
	{ "v_7d.bin",           0x00800, 0x0ce7dcf6, BRF_ESS | BRF_PRG },
	{ "v_7e.bin",           0x00800, 0x24d1ff17, BRF_ESS | BRF_PRG },
	{ "v_7f.bin",           0x00800, 0x0f8c083f, BRF_ESS | BRF_PRG },

	{ "c-2e.bpr",           0x00100, 0x463dc7ad, BRF_GRA },
	{ "c-2f.bpr",           0x00100, 0x47ba0042, BRF_GRA },
	{ "v-2n.bpr",           0x00100, 0xdbf185bf, BRF_GRA },
};

STD_ROM_PICK(Dkongjr)
STD_ROM_FN(Dkongjr)

struct BurnDriver BurnDrvDkongjr = {
	"dkongjr", NULL, NULL, "1982",
	"Donkey Kong Junior (US)\0", NULL, "Nintendo of America", "Miscellaneous",
	NULL, NULL, NULL, NULL,
	0, 2, HARDWARE_MISC_PRE90S, GBF_PLATFORM, 0,
	NULL, DkongjrRomInfo, DkongjrRomName, ParentInputInfo, NULL,
	ParentInit, ParentExit, NULL, NULL, NULL,
	0, NULL, NULL, NULL, NULL, 0, 224, 256, 3, 4
};

static struct BurnRomInfo DockmanRomDesc[] = {
	{ "pe1.19",             0x01000, 0xeef2ec54, BRF_ESS | BRF_PRG },
	{ "pe2.18",             0x01000, 0xbc48d16b, BRF_ESS | BRF_PRG },
	{ "pe3.17",             0x01000, 0x1c923057, BRF_ESS | BRF_PRG },
	{ "pe4.16",             0x01000, 0x23af1cba, BRF_ESS | BRF_PRG },
	{ "pe5.15",             0x01000, 0x39dbe429, BRF_ESS | BRF_PRG },
	
	{ "pe7.22",             0x00800, 0xd2094e4a, BRF_ESS | BRF_PRG },
	{ "pe6.23",             0x00800, 0x1cf447f4, BRF_ESS | BRF_PRG },

	{ "pe8.9",              0x01000, 0x4d8c2974, BRF_GRA },
	{ "pe9.8",              0x01000, 0x4e4ea162, BRF_GRA },
	
	{ "mb7051.3",           0x00020, 0x6440dc61, BRF_GRA },
};

STD_ROM_PICK(Dockman)
STD_ROM_FN(Dockman)

struct BurnDriver BurnDrvDockman = {
	"dockman", NULL, NULL, "1982",
	"Dock Man\0", NULL, "Taito Corporation", "Miscellaneous",
	NULL, NULL, NULL, NULL,
	0, 2, HARDWARE_MISC_PRE90S, GBF_PLATFORM, 0,
	NULL, DockmanRomInfo, DockmanRomName, ParentInputInfo, NULL,
	ParentInit, ParentExit, NULL, NULL, NULL,
	0, NULL, NULL, NULL, NULL, 0, 224, 256, 3, 4
};

static struct BurnRomInfo EightballactRomDesc[] = {
	{ "8b-dk.5e",           0x01000, 0x166c1c9b, BRF_ESS | BRF_PRG },
	{ "8b-dk.5c",           0x01000, 0x9ec87baa, BRF_ESS | BRF_PRG },
	{ "8b-dk.5b",           0x01000, 0xf836a962, BRF_ESS | BRF_PRG },
	{ "8b-dk.5a",           0x01000, 0xd45866d4, BRF_ESS | BRF_PRG },
	
	{ "8b-dk.3h",           0x00800, 0xa8752c60, BRF_ESS | BRF_PRG },

	{ "8b-dk.3n",           0x00800, 0x44830867, BRF_GRA },
	{ "8b-dk.3p",           0x00800, 0x6148c6f2, BRF_GRA },
	
	{ "8b-dk.7c",           0x00800, 0xe34409f5, BRF_GRA },
	{ "8b-dk.7d",           0x00800, 0xb4dc37ca, BRF_GRA },
	{ "8b-dk.7e",           0x00800, 0x655af8a8, BRF_GRA },
	{ "8b-dk.7f",           0x00800, 0xa29b2763, BRF_GRA },
	
	{ "8b.2e",              0x00100, 0xc7379a12, BRF_GRA },
	{ "8b.2f",              0x00100, 0x116612b4, BRF_GRA },
	{ "8b.2n",              0x00100, 0x30586988, BRF_GRA },
	
	{ "82s147.prm",         0x00200, 0x46e5bc92, BRF_GRA },
	
	{ "pls153h.bin",        0x000eb, 0x00000000, BRF_NODUMP },
};

STD_ROM_PICK(Eightballact)
STD_ROM_FN(Eightballact)

struct BurnDriverD BurnDrvEightballact = {
	"8ballact", NULL, NULL, "1984",
	"Eight Ball Action (DK conversion)\0", NULL, "Seatongrove Ltd (Magic Eletronics USA licence)", "Miscellaneous",
	NULL, NULL, NULL, NULL,
	0, 2, HARDWARE_MISC_PRE90S, GBF_SPORTSMISC, 0,
	NULL, EightballactRomInfo, EightballactRomName, ParentInputInfo, NULL,
	ParentInit, ParentExit, NULL, NULL, NULL,
	0, NULL, NULL, NULL, NULL, 0, 256, 224, 4, 3
};

static struct BurnRomInfo HunchbakRomDesc[] = {
	{ "hb-gp1.bin",         0x01000, 0xaf801d54, BRF_ESS | BRF_PRG },
	{ "hb-gp2.bin",         0x01000, 0xb448cc8e, BRF_ESS | BRF_PRG },
	{ "hb-gp3.bin",         0x01000, 0x57c6ea7b, BRF_ESS | BRF_PRG },
	{ "hb-gp4.bin",         0x01000, 0x7f91287b, BRF_ESS | BRF_PRG },
	{ "hb-gp5.bin",         0x01000, 0x1dd5755c, BRF_ESS | BRF_PRG },
	
	{ "6c.sdp1",            0x01000, 0xf9ba2854, BRF_ESS | BRF_PRG },
	
	{ "8a.sp1",             0x00800, 0xed1cd201, BRF_SND },

	{ "11a.cp1",            0x00800, 0xf256b047, BRF_GRA },
	{ "10a.cp2",            0x00800, 0xb870c64f, BRF_GRA },
	{ "9a.cp3",             0x00800, 0x9a7dab88, BRF_GRA },
	
	{ "5b.bin",             0x00800, 0xf055a624, BRF_SND },
	
	{ "82s185.10h",         0x00800, 0xc205bca6, BRF_GRA },
	{ "82s123.10k",         0x00020, 0xb5221cec, BRF_GRA },
};

STD_ROM_PICK(Hunchbak)
STD_ROM_FN(Hunchbak)

struct BurnDriver BurnDrvHunchbak = {
	"hunchbak", NULL, NULL, "1983",
	"Hunchback (set 1)\0", NULL, "Century Electronics", "Miscellaneous",
	NULL, NULL, NULL, NULL,
	0, 2, HARDWARE_MISC_PRE90S, GBF_PLATFORM, 0,
	NULL, HunchbakRomInfo, HunchbakRomName, ParentInputInfo, NULL,
	ParentInit, ParentExit, NULL, NULL, NULL,
	0, NULL, NULL, NULL, NULL, 0, 224, 256, 3, 4
};

static struct BurnRomInfo HuncholyRomDesc[] = {
	{ "ho-gp1.bin",         0x01000, 0x4f17cda7, BRF_ESS | BRF_PRG },
	{ "ho-gp2.bin",         0x01000, 0x70fa52c7, BRF_ESS | BRF_PRG },
	{ "ho-gp3.bin",         0x01000, 0x931934b1, BRF_ESS | BRF_PRG },
	{ "ho-gp4.bin",         0x01000, 0xaf5cd501, BRF_ESS | BRF_PRG },
	{ "ho-gp5.bin",         0x01000, 0x658e8974, BRF_ESS | BRF_PRG },
	
	{ "ho-sdp1.bin",        0x01000, 0x3efb3ffd, BRF_ESS | BRF_PRG },
	
	{ "ho-sp1.bin",         0x01000, 0x3fd39b1e, BRF_SND },

	{ "ho-cp1.bin",         0x00800, 0xc6c73d46, BRF_GRA },
	{ "ho-cp2.bin",         0x00800, 0xe596371c, BRF_GRA },
	{ "ho-cp3.bin",         0x00800, 0x11fae1cf, BRF_GRA },
	
	{ "5b.bin",             0x00800, 0xf055a624, BRF_SND },
	
	{ "82s185.10h",         0x00800, 0xc205bca6, BRF_GRA },
	{ "82s123.10k",         0x00020, 0xb5221cec, BRF_GRA },
};

STD_ROM_PICK(Huncholy)
STD_ROM_FN(Huncholy)

struct BurnDriver BurnDrvHuncholy = {
	"huncholy", NULL, NULL, "1984",
	"Hunchback Olympic\0", NULL, "Seatongrove Ltd", "Miscellaneous",
	NULL, NULL, NULL, NULL,
	0, 2, HARDWARE_MISC_PRE90S, GBF_SPORTSMISC, 0,
	NULL, HuncholyRomInfo, HuncholyRomName, ParentInputInfo, NULL,
	ParentInit, ParentExit, NULL, NULL, NULL,
	0, NULL, NULL, NULL, NULL, 0, 224, 256, 3, 4
};

static struct BurnRomInfo ManiacsqRomDesc[] = {
	{ "d8-d15.1m",          0x20000, 0x9121d1b6, BRF_ESS | BRF_PRG },
	{ "d0-d7.1m",           0x20000, 0xa95cfd2a, BRF_ESS | BRF_PRG },
	
	{ "d0-d7.4m",           0x80000, 0xd8551b2f, BRF_GRA },
	{ "d8-d15.4m",          0x80000, 0xb269c427, BRF_GRA },
	{ "d16-d23.1m",         0x20000, 0xaf4ea5e7, BRF_GRA },
	{ "d24-d31.1m",         0x20000, 0x578c3588, BRF_GRA },
};

STD_ROM_PICK(Maniacsq)
STD_ROM_FN(Maniacsq)

struct BurnDriverD BurnDrvManiacsq = {
	"maniacsq", NULL, NULL, "1996",
	"Maniac Square (unprotected)\0", NULL, "Gaelco", "Miscellaneous",
	NULL, NULL, NULL, NULL,
	0, 2, HARDWARE_MISC_POST90S, GBF_PUZZLE, 0,
	NULL, ManiacsqRomInfo, ManiacsqRomName, ParentInputInfo, NULL,
	ParentInit, ParentExit, NULL, NULL, NULL,
	0, NULL, NULL, NULL, NULL, 0, 256, 224, 4, 3
};

static struct BurnRomInfo PhoenixRomDesc[] = {
	{ "ic45",               0x00800, 0x9f68086b, BRF_ESS | BRF_PRG },
	{ "ic46",               0x00800, 0x273a4a82, BRF_ESS | BRF_PRG },
	{ "ic47",               0x00800, 0x3d4284b9, BRF_ESS | BRF_PRG },
	{ "ic48",               0x00800, 0xcb5d9915, BRF_ESS | BRF_PRG },
	{ "h5-ic49.5a",         0x00800, 0xa105e4e7, BRF_ESS | BRF_PRG },
	{ "h6-ic50.6a",         0x00800, 0xac5e9ec1, BRF_ESS | BRF_PRG },
	{ "h7-ic51.7a",         0x00800, 0x2eab35b4, BRF_ESS | BRF_PRG },
	{ "h8-ic52.8a",         0x00800, 0xaff8e9c5, BRF_ESS | BRF_PRG },
	
	{ "ic23.3d",            0x00800, 0x3c7e623f, BRF_GRA },
	{ "ic24.4d",            0x00800, 0x59916d3b, BRF_GRA },
	{ "b1-ic39.3b",         0x00800, 0x53413e8f, BRF_GRA },
	{ "b2-ic40.4b",         0x00800, 0x0be2ba91, BRF_GRA },
	
	{ "mmi6301.ic40",       0x00100, 0x79350b25, BRF_GRA },
	{ "mmi6301.ic41",       0x00100, 0xe176b768, BRF_GRA },
};

STD_ROM_PICK(Phoenix)
STD_ROM_FN(Phoenix)

struct BurnDriver BurnDrvPhoenix = {
	"phoenix", NULL, NULL, "1980",
	"Phoenix (Amstar)\0", NULL, "Amstar", "Miscellaneous",
	NULL, NULL, NULL, NULL,
	0, 2, HARDWARE_MISC_PRE90S, GBF_VERSHOOT, 0,
	NULL, PhoenixRomInfo, PhoenixRomName, ParentInputInfo, NULL,
	ParentInit, ParentExit, NULL, NULL, NULL,
	0, NULL, NULL, NULL, NULL, 0, 208, 256, 3, 4
};

static struct BurnRomInfo TumblepRomDesc[] = {
	{ "hl00-1.f12",         0x40000, 0xfd697c1b, BRF_ESS | BRF_PRG },
	{ "hl01-1.f13",         0x40000, 0xd5a62a3f, BRF_ESS | BRF_PRG },
	
	{ "hl02-.f16",          0x10000, 0xa5cab888, BRF_ESS | BRF_PRG },

	{ "map-02.rom",         0x80000, 0xdfceaa26, BRF_GRA },
	
	{ "map-01.rom",         0x80000, 0xe81ffa09, BRF_GRA },
	{ "map-00.rom",         0x80000, 0x8c879cfe, BRF_GRA },
	
	{ "hl03-.j15",          0x20000, 0x01b81da0, BRF_SND },
};

STD_ROM_PICK(Tumblep)
STD_ROM_FN(Tumblep)

struct BurnDriver BurnDrvTumblep = {
	"tumblep", NULL, NULL, "1991",
	"Tumble Pop (World)\0", NULL, "Data East Corporation", "Miscellaneous",
	NULL, NULL, NULL, NULL,
	0, 2, HARDWARE_MISC_POST90S, GBF_PLATFORM, 0,
	NULL, TumblepRomInfo, TumblepRomName, ParentInputInfo, NULL,
	ParentInit, ParentExit, NULL, NULL, NULL,
	0, NULL, NULL, NULL, NULL, 0, 256, 224, 4, 3
};
