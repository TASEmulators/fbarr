// FB Alpha - Emulator for MC68000/Z80 based arcade games
//            Refer to the "license.txt" file for more info

#include <limits.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <assert.h>
#include <ctype.h>

#include "tchar.h"

// Macro to make quoted strings
#define MAKE_STRING_2(s) #s
#define MAKE_STRING(s) MAKE_STRING_2(s)

#define BZIP_MAX (8)								// Maximum zip files to search through
#define DIRS_MAX (8)								// Maximum number of directories to search

#include "title.h"
#include "burn.h"

#define sizearray(a) (sizeof(a) / sizeof((a)[0]))

// ---------------------------------------------------------------------------
// OS dependent functionality

#if defined (BUILD_WIN32)
 #include "burner_win32.h"
#elif defined (BUILD_SDL)
 #include "burner_sdl.h"
#endif

#include <shellapi.h>
#include <shlwapi.h>
#include "net.h"
#include "png.h"
#include "dwmapi_core.h"

// ---------------------------------------------------------------------------
// OS independent functionality

#include "interface.h"
#include "luaengine.h"

#define IMG_FREE		(1 << 0)

// Macros for parsing text
#define SKIP_WS(s) while (_istspace(*s)) { s++; }			// Skip whitespace
#define FIND_WS(s) while (*s && !_istspace(*s)) { s++; }	// Find whitespace
#define FIND_QT(s) while (*s && *s != _T('\"')) { s++; }	// Find quote

// image.cpp
void img_free(IMAGE* img);
int img_alloc(IMAGE* img);

bool PNGIsImage(FILE* fp);
int PNGLoad(IMAGE* img, FILE* fp, int nPreset);

// gami.cpp
extern struct GameInp* GameInp;
extern unsigned int nGameInpCount;
extern unsigned int nMacroCount;
extern unsigned int nMaxMacro;

extern int nAnalogSpeed;

extern int nFireButtons;

extern bool bStreetFighterLayout;
extern bool bLeftAltkeyMapped;

int GameInpInit();
int GameInpExit();
TCHAR* InputCodeDesc(int c);
TCHAR* InpToDesc(struct GameInp* pgi);
TCHAR* InpMacroToDesc(struct GameInp* pgi);
void GameInpCheckLeftAlt();
void GameInpCheckMouse();
int GameInpBlank(int bDipSwitch);
int GameInputAutoIni(int nPlayer, TCHAR* lpszFile, bool bOverWrite);
int ConfigGameLoadHardwareDefaults();
int GameInpDefault();
int GameInpWrite(FILE* h);
int GameInpRead(TCHAR* szVal, bool bOverWrite);
int GameInpMacroRead(TCHAR* szVal, bool bOverWrite);
int GameInpCustomRead(TCHAR* szVal, bool bOverWrite);

// Player Default Controls
extern int nPlayerDefaultControls[4];
extern TCHAR szPlayerDefaultIni[4][MAX_PATH];

// cong.cpp
extern const int nConfigMinVersion;					// Minimum version of application for which input files are valid
extern bool bSaveInputs;
int ConfigGameLoad(bool bOverWrite);				// char* lpszName = NULL
int ConfigGameSave(bool bSave);

// conc.cpp
int ConfigCheatLoad();

// gamc.cpp
int GamcMisc(struct GameInp* pgi, char* szi, int nPlayer);
int GamcAnalogKey(struct GameInp* pgi, char* szi, int nPlayer, int nSlide);
int GamcAnalogJoy(struct GameInp* pgi, char* szi, int nPlayer, int nJoy, int nSlide);
int GamcPlayer(struct GameInp* pgi, char* szi, int nPlayer, int nDevice);
int GamcPlayerHotRod(struct GameInp* pgi, char* szi, int nPlayer, int nFlags, int nSlide);

// misc.cpp
#define QUOTE_MAX (128)															// Maximum length of "quoted strings"
int QuoteRead(TCHAR** ppszQuote, TCHAR** ppszEnd, TCHAR* pszSrc);					// Read a quoted string from szSrc and point to the end
TCHAR* LabelCheck(TCHAR* s, TCHAR* pszLabel);

extern int bDoGamma;
extern int bHardwareGammaOnly;
extern double nGamma;

int SetBurnHighCol(int nDepth);
char* DecorateGameName(unsigned int nBurnDrv);
TCHAR* DecorateGenreInfo();
void ComputeGammaLUT();

// dat.cpp
int write_datfile(int bIncMegadrive, FILE* fDat);
int create_datfile(TCHAR* szFilename, int bIncMegadrive);

// sshot.cpp
unsigned char* ConvertVidImage(int bFlipVertical);	// returns either pImage or a dynamically allocated buffer which should be freed by the caller
int MakeScreenShot();
extern bool bLuaDrawingsInCaptures;

// state.cpp
int BurnStateLoadEmbed(FILE* fp, int nOffset, int bAll, int (*pLoadGame)());
int BurnStateLoad(TCHAR* szName, int bAll, int (*pLoadGame)());
int BurnStateSaveEmbed(FILE* fp, int nOffset, int bAll);
int BurnStateSave(TCHAR* szName, int bAll);

// statec.cpp
int BurnStateCompress(unsigned char** pDef, int* pnDefLen, int bAll);
int BurnStateDecompress(unsigned char* Def, int nDefLen, int bAll);

// zipfn.cpp
struct ZipEntry { char* szName;	unsigned int nLen; unsigned int nCrc; };

int ZipOpen(const char* szZip);
int ZipClose();
int ZipGetList(struct ZipEntry** pList, int* pnListCount);
int ZipLoadFile(unsigned char* Dest, int nLen, int* pnWrote, int nEntry);

// bzip.cpp

#define BZIP_STATUS_OK		(0)
#define BZIP_STATUS_BADDATA	(1)
#define BZIP_STATUS_ERROR	(2)

int BzipOpen(bool);
int BzipClose();
int BzipInit();
int BzipExit();
int BzipStatus();
