// Driver Selector module
// TreeView Version by HyperYagami
#include "burner.h"
#include "png.h"
#include <shellapi.h>
//#include "menugui.h"
//#include "imagebutton.h"

// externs -------------------------------------------------------------------------------------------------------------------------------------------------
extern HWND		hTabControl3;					// GameList & Favorite games list tabs control
extern HWND		listView;						// Favorite games 'list view' control
extern int		nFavorites;
extern TCHAR	szFavoritesDat[MAX_PATH];
extern bool		bFavSelected;
extern int		columnIndex;
extern BOOL		isAscendingOrder;

void			InsertTabs();
void			InitFavGameList();
void			DisplayControls(int TabSelected, int TabControl);
int	CALLBACK	ListView_CompareFunc(LPARAM index1, LPARAM index2, LPARAM param);
BOOL			IsCommCtrlVersion6();
void			ListView_SetHeaderSortImage(HWND lView, int colIndex, BOOL isAscending);
void			UpdateFavListTitles(int nFavCount);
int				ParseFavListDat();
void			InitFavGameList();
int				SaveFavList(HWND hwndListView, FILE *f, TCHAR *sFileName, long lLines, long lCols);
void			RefreshFavGameList();

#if defined (_UNICODE)
void			SetFavListRow(int nRow, TCHAR* pszCol1, TCHAR* pszUnicodeTitle	, TCHAR* pszCol3, TCHAR* pszCol4, TCHAR* pszCol5, TCHAR* pszCol6/*, TCHAR* pszCol7*/);
#else
void			SetFavListRow(int nRow, TCHAR* pszCol1, TCHAR* pszCol2			, TCHAR* pszCol3, TCHAR* pszCol4, TCHAR* pszCol5, TCHAR* pszCol6/*, TCHAR* pszCol7*/);
#endif

// ----------------------------------------------------------------------------------------------------------------------------------------------------------

UINT_PTR nTimer					= 0;
int nDialogSelect				= -1;										// The driver which this dialog selected
int nOldDlgSelected				= -1;
bool bDialogCancel				= false;

static int nShowMVSCartsOnly	= 0;

bool bMVSMultiSlot				= false;

bool bGameInfoOpen				= false;
bool bDrvSelected				= false;

HBITMAP hPrevBmp				= NULL;
static HBITMAP hPreview			= NULL;

HWND hSelDlg					= NULL;
static HWND hSelList			= NULL;
static HWND hParent				= NULL;
static HWND hInfoLabel[6]		= { NULL, NULL, NULL, NULL, NULL };			// 4 things in our Info-box
static HWND hInfoText[6]		= { NULL, NULL, NULL, NULL, NULL };			// 4 things in our Info-box

static HBRUSH hWhiteBGBrush;
static HICON hExpand, hCollapse;
static HICON hNotWorking, hNotFoundEss, hNotFoundNonEss;

static char TreeBuilding		= 0;										// if 1, ignore TVN_SELCHANGED messages

// Filter TreeView
HWND hFilterList				= NULL;
HTREEITEM hFilterCave			= NULL;
HTREEITEM hFilterCps1			= NULL;
HTREEITEM hFilterCps2			= NULL;
HTREEITEM hFilterCps3			= NULL;
HTREEITEM hFilterKaneko16		= NULL;
HTREEITEM hFilterKonami			= NULL;
HTREEITEM hFilterNeogeo			= NULL;
HTREEITEM hFilterPacman			= NULL;
HTREEITEM hFilterPgm			= NULL;
HTREEITEM hFilterPsikyo			= NULL;
HTREEITEM hFilterSega			= NULL;
HTREEITEM hFilterTaito			= NULL;
HTREEITEM hFilterToaplan		= NULL;
HTREEITEM hFilterMegadrive		= NULL;
HTREEITEM hFilterMiscPre90s		= NULL;
HTREEITEM hFilterMiscPost90s	= NULL;
HTREEITEM hFilterBootleg		= NULL;
HTREEITEM hFilterDemo			= NULL;
HTREEITEM hFilterHack			= NULL;
HTREEITEM hFilterHomebrew		= NULL;
HTREEITEM hFilterPrototype		= NULL;
HTREEITEM hFilterGenuine		= NULL;
HTREEITEM hFilterHorshoot		= NULL;
HTREEITEM hFilterVershoot		= NULL;
HTREEITEM hFilterScrfight		= NULL;
HTREEITEM hFilterVsfight		= NULL;
HTREEITEM hFilterBios			= NULL;
HTREEITEM hFilterBreakout		= NULL;
HTREEITEM hFilterCasino			= NULL;
HTREEITEM hFilterBallpaddle		= NULL;
HTREEITEM hFilterMaze			= NULL;
HTREEITEM hFilterMinigames		= NULL;
HTREEITEM hFilterPinball		= NULL;
HTREEITEM hFilterPlatform		= NULL;
HTREEITEM hFilterPuzzle			= NULL;
HTREEITEM hFilterQuiz			= NULL;
HTREEITEM hFilterSportsmisc		= NULL;
HTREEITEM hFilterSportsfootball = NULL;
HTREEITEM hFilterMisc			= NULL;
HTREEITEM hFilterMahjong		= NULL;
HTREEITEM hFilterRacing			= NULL;
HTREEITEM hFilterShoot			= NULL;
HTREEITEM hFilterOtherFamily	= NULL;
HTREEITEM hFilterMslug			= NULL;
HTREEITEM hFilterSf				= NULL;
HTREEITEM hFilterKof			= NULL;
HTREEITEM hFilterDstlk			= NULL;
HTREEITEM hFilterFatfury		= NULL;
HTREEITEM hFilterSamsho			= NULL;
HTREEITEM hFilter19xx			= NULL;
HTREEITEM hFilterSonicwi		= NULL;
HTREEITEM hFilterPwrinst		= NULL;

HTREEITEM hRoot					= NULL;
HTREEITEM hBoardType			= NULL;
HTREEITEM hFamily				= NULL;
HTREEITEM hGenre				= NULL;
HTREEITEM hHardware				= NULL;

// GCC doesn't seem to define these correctly.....
#define _TreeView_SetItemState(hwndTV, hti, data, _mask) \
{ TVITEM _ms_TVi;\
  _ms_TVi.mask = TVIF_STATE; \
  _ms_TVi.hItem = hti; \
  _ms_TVi.stateMask = _mask;\
  _ms_TVi.state = data;\
  SNDMSG((hwndTV), TVM_SETITEM, 0, (LPARAM)(TV_ITEM *)&_ms_TVi);\
}

#define _TreeView_SetCheckState(hwndTV, hti, fCheck) \
  _TreeView_SetItemState(hwndTV, hti, INDEXTOSTATEIMAGEMASK((fCheck)?2:1), TVIS_STATEIMAGEMASK)

// -----------------------------------------------------------------------------------------------------------------

#define DISABLE_NON_AVAILABLE_SELECT	0						// Disable selecting non-available sets
#define NON_WORKING_PROMPT_ON_LOAD		1						// Prompt user on loading non-working sets

#define MASKCPS			(1 << (HARDWARE_PREFIX_CAPCOM			>> 24))
#define MASKCPS2		(1 << (HARDWARE_PREFIX_CPS2				>> 24))
#define MASKCPS3		(1 << (HARDWARE_PREFIX_CPS3				>> 24))
#define MASKNEOGEO		(1 << (HARDWARE_PREFIX_SNK				>> 24))
#define MASKSEGA		(1 << (HARDWARE_PREFIX_SEGA				>> 24))
#define MASKTOAPLAN 	(1 << (HARDWARE_PREFIX_TOAPLAN			>> 24))
#define MASKCAVE		(1 << (HARDWARE_PREFIX_CAVE				>> 24))
#define MASKPGM			(1 << (HARDWARE_PREFIX_IGS_PGM			>> 24))
#define MASKMEGADRIVE	(1 << (HARDWARE_PREFIX_SEGA_MEGADRIVE   >> 24))
#define MASKTAITO		(1 << (HARDWARE_PREFIX_TAITO			>> 24))
#define MASKPSIKYO		(1 << (HARDWARE_PREFIX_PSIKYO			>> 24))
#define MASKKANEKO16	(1 << (HARDWARE_PREFIX_KANEKO16			>> 24))
#define MASKKONAMI		(1 << (HARDWARE_PREFIX_KONAMI			>> 24))
#define MASKPACMAN		(1 << (HARDWARE_PREFIX_PACMAN			>> 24))
#define MASKMISCPRE90S	(1 << (HARDWARE_PREFIX_MISC_PRE90S		>> 24))
#define MASKMISCPOST90S	(1 << (HARDWARE_PREFIX_MISC_POST90S		>> 24))
#define MASKALL			(MASKCPS | MASKCPS2 | MASKCPS3 | MASKNEOGEO | MASKSEGA | MASKTOAPLAN | MASKCAVE | MASKPGM | MASKTAITO | MASKPSIKYO | MASKKANEKO16 | MASKKONAMI | MASKPACMAN | MASKMEGADRIVE | MASKMISCPRE90S | MASKMISCPOST90S)

#define AVAILONLY		(1 << 16)
#define AUTOEXPAND		(1 << 17)
#define SHOWSHORT		(1 << 18)
#define ASCIIONLY		(1 << 19)

#define MASKBOARDTYPEGENUINE	(1)
#define MASKFAMILYOTHER		0x10000000

int nLoadMenuShowX				= 0;
int nLoadMenuBoardTypeFilter	= 0;
int nLoadMenuGenreFilter		= 0;
int nLoadMenuFamilyFilter		= 0;

struct NODEINFO {
	int nBurnDrvNo;
	bool bIsParent;
	char* pszROMName;
	HTREEITEM hTreeHandle;
};

static NODEINFO* nBurnDrv;
static unsigned int nTmpDrvCount;

// Check if a specified driver is working
static bool CheckWorkingStatus(int nDriver)
{
	int nOldnBurnDrvSelect = nBurnDrvSelect;
	nBurnDrvSelect = nDriver;
	bool bStatus = BurnDrvIsWorking();
	nBurnDrvSelect = nOldnBurnDrvSelect;

	return bStatus;
}

static TCHAR* MangleGamename(const TCHAR* szOldName, bool bRemoveArticle)
{
	static TCHAR szNewName[256] = _T("");

#if 0
	TCHAR* pszName = szNewName;

	if (_tcsnicmp(szOldName, _T("the "), 4) == 0) {
		int x = 0, y = 0;
		while (szOldName[x] && szOldName[x] != _T('(') && szOldName[x] != _T('-')) {
			x++;
		}
		y = x;
		while (y && szOldName[y - 1] == _T(' ')) {
			y--;
		}
		_tcsncpy(pszName, szOldName + 4, y - 4);
		pszName[y - 4] = _T('\0');
		pszName += y - 4;

		if (!bRemoveArticle) {
			pszName += _stprintf(pszName, _T(", the"));
		}
		if (szOldName[x]) {
			_stprintf(pszName, _T(" %s"), szOldName + x);
		}
	} else {
		_tcscpy(pszName, szOldName);
	}
#endif

#if 1
	_tcscpy(szNewName, szOldName);
#endif

	return szNewName;
}

static int DoExtraFilters()
{
	if (nShowMVSCartsOnly && ((BurnDrvGetHardwareCode() & HARDWARE_SNK_MVSCARTRIDGE) != HARDWARE_SNK_MVSCARTRIDGE)) return 1;

	if ((nLoadMenuBoardTypeFilter & BDF_BOOTLEG)	&& (BurnDrvGetFlags() & BDF_BOOTLEG))				return 1;
	if ((nLoadMenuBoardTypeFilter & BDF_DEMO)		&& (BurnDrvGetFlags() & BDF_DEMO))					return 1;
	if ((nLoadMenuBoardTypeFilter & BDF_HACK)		&& (BurnDrvGetFlags() & BDF_HACK))					return 1;
	if ((nLoadMenuBoardTypeFilter & BDF_HOMEBREW)	&& (BurnDrvGetFlags() & BDF_HOMEBREW))				return 1;
	if ((nLoadMenuBoardTypeFilter & BDF_PROTOTYPE)	&& (BurnDrvGetFlags() & BDF_PROTOTYPE))				return 1;

	if ((nLoadMenuBoardTypeFilter & MASKBOARDTYPEGENUINE)	&& (!(BurnDrvGetFlags() & BDF_BOOTLEG))
															&& (!(BurnDrvGetFlags() & BDF_DEMO))
															&& (!(BurnDrvGetFlags() & BDF_HACK))
															&& (!(BurnDrvGetFlags() & BDF_HOMEBREW))
															&& (!(BurnDrvGetFlags() & BDF_PROTOTYPE)))	return 1;

	if ((nLoadMenuFamilyFilter & FBF_MSLUG)			&& (BurnDrvGetFamilyFlags() & FBF_MSLUG))			return 1;
	if ((nLoadMenuFamilyFilter & FBF_SF)			&& (BurnDrvGetFamilyFlags() & FBF_SF))				return 1;
	if ((nLoadMenuFamilyFilter & FBF_KOF)			&& (BurnDrvGetFamilyFlags() & FBF_KOF))				return 1;
	if ((nLoadMenuFamilyFilter & FBF_DSTLK)			&& (BurnDrvGetFamilyFlags() & FBF_DSTLK))			return 1;
	if ((nLoadMenuFamilyFilter & FBF_FATFURY)		&& (BurnDrvGetFamilyFlags() & FBF_FATFURY))			return 1;
	if ((nLoadMenuFamilyFilter & FBF_SAMSHO)		&& (BurnDrvGetFamilyFlags() & FBF_SAMSHO))			return 1;
	if ((nLoadMenuFamilyFilter & FBF_19XX)			&& (BurnDrvGetFamilyFlags() & FBF_19XX))			return 1;
	if ((nLoadMenuFamilyFilter & FBF_SONICWI)		&& (BurnDrvGetFamilyFlags() & FBF_SONICWI))			return 1;
	if ((nLoadMenuFamilyFilter & FBF_PWRINST)		&& (BurnDrvGetFamilyFlags() & FBF_PWRINST))			return 1;

	if ((nLoadMenuFamilyFilter & MASKFAMILYOTHER)	&& (!(BurnDrvGetFamilyFlags() & FBF_MSLUG))
													&& (!(BurnDrvGetFamilyFlags() & FBF_SF))
													&& (!(BurnDrvGetFamilyFlags() & FBF_KOF))
													&& (!(BurnDrvGetFamilyFlags() & FBF_DSTLK))
													&& (!(BurnDrvGetFamilyFlags() & FBF_FATFURY))
													&& (!(BurnDrvGetFamilyFlags() & FBF_SAMSHO))
													&& (!(BurnDrvGetFamilyFlags() & FBF_19XX))
													&& (!(BurnDrvGetFamilyFlags() & FBF_SONICWI))
													&& (!(BurnDrvGetFamilyFlags() & FBF_PWRINST)))		return 1;

	if ((nLoadMenuGenreFilter & GBF_HORSHOOT)		&& (BurnDrvGetGenreFlags() & GBF_HORSHOOT))			return 1;
	if ((nLoadMenuGenreFilter & GBF_VERSHOOT)		&& (BurnDrvGetGenreFlags() & GBF_VERSHOOT))			return 1;
	if ((nLoadMenuGenreFilter & GBF_SCRFIGHT)		&& (BurnDrvGetGenreFlags() & GBF_SCRFIGHT))			return 1;
	if ((nLoadMenuGenreFilter & GBF_VSFIGHT)		&& (BurnDrvGetGenreFlags() & GBF_VSFIGHT))			return 1;
	if ((nLoadMenuGenreFilter & GBF_BIOS)			&& (BurnDrvGetGenreFlags() & GBF_BIOS))				return 1;
	if ((nLoadMenuGenreFilter & GBF_BREAKOUT)		&& (BurnDrvGetGenreFlags() & GBF_BREAKOUT))			return 1;
	if ((nLoadMenuGenreFilter & GBF_CASINO)			&& (BurnDrvGetGenreFlags() & GBF_CASINO))			return 1;
	if ((nLoadMenuGenreFilter & GBF_BALLPADDLE)		&& (BurnDrvGetGenreFlags() & GBF_BALLPADDLE))		return 1;
	if ((nLoadMenuGenreFilter & GBF_MAZE)			&& (BurnDrvGetGenreFlags() & GBF_MAZE))				return 1;
	if ((nLoadMenuGenreFilter & GBF_MINIGAMES)		&& (BurnDrvGetGenreFlags() & GBF_MINIGAMES))		return 1;
	if ((nLoadMenuGenreFilter & GBF_PINBALL)		&& (BurnDrvGetGenreFlags() & GBF_PINBALL))			return 1;
	if ((nLoadMenuGenreFilter & GBF_PLATFORM)		&& (BurnDrvGetGenreFlags() & GBF_PLATFORM))			return 1;
	if ((nLoadMenuGenreFilter & GBF_PUZZLE)			&& (BurnDrvGetGenreFlags() & GBF_PUZZLE))			return 1;
	if ((nLoadMenuGenreFilter & GBF_QUIZ)			&& (BurnDrvGetGenreFlags() & GBF_QUIZ))				return 1;
	if ((nLoadMenuGenreFilter & GBF_SPORTSMISC)		&& (BurnDrvGetGenreFlags() & GBF_SPORTSMISC))		return 1;
	if ((nLoadMenuGenreFilter & GBF_SPORTSFOOTBALL) && (BurnDrvGetGenreFlags() & GBF_SPORTSFOOTBALL))	return 1;
	if ((nLoadMenuGenreFilter & GBF_MISC)			&& (BurnDrvGetGenreFlags() & GBF_MISC))				return 1;
	if ((nLoadMenuGenreFilter & GBF_MAHJONG)		&& (BurnDrvGetGenreFlags() & GBF_MAHJONG))			return 1;
	if ((nLoadMenuGenreFilter & GBF_RACING)			&& (BurnDrvGetGenreFlags() & GBF_RACING))			return 1;
	if ((nLoadMenuGenreFilter & GBF_SHOOT)			&& (BurnDrvGetGenreFlags() & GBF_SHOOT))			return 1;

	return 0;
}

// Make a tree-view control with all drivers
static int SelListMake()
{
	unsigned int i, j;

	free(nBurnDrv);
	nBurnDrv = (NODEINFO*)malloc(nBurnDrvCount * sizeof(NODEINFO));
	memset(nBurnDrv, 0, nBurnDrvCount * sizeof(NODEINFO));

	nTmpDrvCount = 0;

	if (hSelList == NULL) {
		return 1;
	}

	// Add all the driver names to the list

	// 1st: parents
	for (i = 0; i < nBurnDrvCount; i++) {
		TV_INSERTSTRUCT TvItem;

		nBurnDrvSelect = i;																// Switch to driver i

		if (BurnDrvGetFlags() & BDF_BOARDROM) {
#if defined (INCLUDE_NEOGEO_MULTISLOT)
			if (_stricmp(BurnDrvGetTextA(DRV_NAME), "neogeo")) continue;
			if (nShowMVSCartsOnly) continue;
#else
			continue;
#endif
		}
		if (BurnDrvGetText(DRV_PARENT) != NULL && (BurnDrvGetFlags() & BDF_CLONE)) {	// Skip clones
			continue;
		}
		if (avOk && (nLoadMenuShowX & AVAILONLY) && !gameAv[i])	{						// Skip non-available games if needed
			continue;
		}

		int nHardware = 1 << (BurnDrvGetHardwareCode() >> 24);
		if ((nHardware & MASKALL) && (nHardware & nLoadMenuShowX) || (nHardware & MASKALL) == 0) {
			continue;
		}

		if (DoExtraFilters()) continue;

		memset(&TvItem, 0, sizeof(TvItem));
		TvItem.item.mask = TVIF_TEXT | TVIF_PARAM;
		TvItem.hInsertAfter = TVI_SORT;
		TvItem.item.pszText = (nLoadMenuShowX & SHOWSHORT) ? BurnDrvGetText(DRV_NAME) : MangleGamename(BurnDrvGetText(DRV_ASCIIONLY | DRV_FULLNAME), true);
		TvItem.item.lParam = (LPARAM)&nBurnDrv[nTmpDrvCount];
		nBurnDrv[nTmpDrvCount].hTreeHandle = (HTREEITEM)SendMessage(hSelList, TVM_INSERTITEM, 0, (LPARAM)&TvItem);
		nBurnDrv[nTmpDrvCount].nBurnDrvNo = i;
		nBurnDrv[nTmpDrvCount].pszROMName = BurnDrvGetTextA(DRV_NAME);
		nBurnDrv[nTmpDrvCount].bIsParent = true;
		nTmpDrvCount++;
	}

	// 2nd: clones
	for (i = 0; i < nBurnDrvCount; i++) {
		TV_INSERTSTRUCT TvItem;

		nBurnDrvSelect = i;																// Switch to driver i

		if (BurnDrvGetFlags() & BDF_BOARDROM) {
			continue;
		}

		if (BurnDrvGetTextA(DRV_PARENT) == NULL || !(BurnDrvGetFlags() & BDF_CLONE)) {	// Skip parents
			continue;
		}
		if (avOk && (nLoadMenuShowX & AVAILONLY) && !gameAv[i])	{						// Skip non-available games if needed
			continue;
		}

		int nHardware = 1 << (BurnDrvGetHardwareCode() >> 24);
		if ((nHardware & MASKALL) && (nHardware & nLoadMenuShowX) || ((nHardware & MASKALL) == 0)) {
			continue;
		}

		if (DoExtraFilters()) continue;

		memset(&TvItem, 0, sizeof(TvItem));
		TvItem.item.mask = TVIF_TEXT | TVIF_PARAM;
		TvItem.hInsertAfter = TVI_SORT;
		TvItem.item.pszText = (nLoadMenuShowX & SHOWSHORT) ? BurnDrvGetText(DRV_NAME) : MangleGamename(BurnDrvGetText(DRV_ASCIIONLY | DRV_FULLNAME), true);

		// Find the parent's handle
		for (j = 0; j < nTmpDrvCount; j++) {
			if (nBurnDrv[j].bIsParent) {
				if (!_stricmp(BurnDrvGetTextA(DRV_PARENT), nBurnDrv[j].pszROMName)) {
					TvItem.hParent = nBurnDrv[j].hTreeHandle;
					break;
				}
			}
		}

		// Find the parent and add a branch to the tree
		if (!TvItem.hParent) {
			char szTempName[9];
			strcpy(szTempName, BurnDrvGetTextA(DRV_PARENT));
			int nTempBurnDrvSelect = nBurnDrvSelect;
			for (j = 0; j < nBurnDrvCount; j++) {
				nBurnDrvSelect = j;
				if (!strcmp(szTempName, BurnDrvGetTextA(DRV_NAME))) {
					TV_INSERTSTRUCT TempTvItem;
					memset(&TempTvItem, 0, sizeof(TempTvItem));
					TempTvItem.item.mask = TVIF_TEXT | TVIF_PARAM;
					TempTvItem.hInsertAfter = TVI_SORT;
					TempTvItem.item.pszText = (nLoadMenuShowX & SHOWSHORT) ? BurnDrvGetText(DRV_NAME) : MangleGamename(BurnDrvGetText(DRV_ASCIIONLY | DRV_FULLNAME), true);
					TempTvItem.item.lParam = (LPARAM)&nBurnDrv[nTmpDrvCount];
					nBurnDrv[nTmpDrvCount].hTreeHandle = (HTREEITEM)SendMessage(hSelList, TVM_INSERTITEM, 0, (LPARAM)&TempTvItem);
					nBurnDrv[nTmpDrvCount].nBurnDrvNo = j;
					nBurnDrv[nTmpDrvCount].bIsParent = true;
					nBurnDrv[nTmpDrvCount].pszROMName = BurnDrvGetTextA(DRV_NAME);
					TvItem.item.lParam = (LPARAM)&nBurnDrv[nTmpDrvCount];
					TvItem.hParent = nBurnDrv[nTmpDrvCount].hTreeHandle;
					nTmpDrvCount++;
					break;
				}
			}
			nBurnDrvSelect = nTempBurnDrvSelect;
		}

		TvItem.item.lParam = (LPARAM)&nBurnDrv[nTmpDrvCount];
		nBurnDrv[nTmpDrvCount].hTreeHandle = (HTREEITEM)SendMessage(hSelList, TVM_INSERTITEM, 0, (LPARAM)&TvItem);
		nBurnDrv[nTmpDrvCount].pszROMName = BurnDrvGetTextA(DRV_NAME);
		nBurnDrv[nTmpDrvCount].nBurnDrvNo = i;
		nTmpDrvCount++;
	}

	for (i = 0; i < nTmpDrvCount; i++) {

		// See if we need to expand the branch of an unavailable or non-working parent
		if (nBurnDrv[i].bIsParent && ((nLoadMenuShowX & AUTOEXPAND) || !gameAv[nBurnDrv[i].nBurnDrvNo] || !CheckWorkingStatus(nBurnDrv[i].nBurnDrvNo))) {
			for (j = 0; j < nTmpDrvCount; j++) {

				// Expand the branch only if a working clone is available
				if (gameAv[nBurnDrv[j].nBurnDrvNo]) {
					nBurnDrvSelect = nBurnDrv[j].nBurnDrvNo;
					if (BurnDrvGetTextA(DRV_PARENT)) {
						if (strcmp(nBurnDrv[i].pszROMName, BurnDrvGetTextA(DRV_PARENT)) == 0) {
							SendMessage(hSelList, TVM_EXPAND,TVE_EXPAND, (LPARAM)nBurnDrv[i].hTreeHandle);
							break;
						}
					}
				}
			}
		}
	}

	// Update the status info
	TCHAR szRomsAvailableInfo[50] = _T("");

	_stprintf(szRomsAvailableInfo, _T("Showing %i of %i sets"), nTmpDrvCount, nBurnDrvCount - 2);
	SendDlgItemMessage(hSelDlg, IDC_DRVCOUNT, WM_SETTEXT, 0, (LPARAM)(LPCTSTR)szRomsAvailableInfo);

	return 0;
}

static void MyEndDialog()
{
	if (nTimer) {
		KillTimer(hSelDlg, nTimer);
		nTimer = 0;
	}

	SendDlgItemMessage(hSelDlg, IDC_SCREENSHOT_H, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)NULL);
	SendDlgItemMessage(hSelDlg, IDC_SCREENSHOT_V, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)NULL);

	if (hPrevBmp) {
		DeleteObject((HGDIOBJ)hPrevBmp);
		hPrevBmp = NULL;
	}
	if (hPreview) {
		DeleteObject((HGDIOBJ)hPreview);
		hPreview = NULL;
	}

	if (hExpand) {
		DestroyIcon(hExpand);
		hExpand = NULL;
	}
	if (hCollapse) {
		DestroyIcon(hCollapse);
		hCollapse = NULL;
	}
	if (hNotWorking) {
		DestroyIcon(hNotWorking);
		hNotWorking = NULL;
	}
	if (hNotFoundEss) {
		DestroyIcon(hNotFoundEss);
		hNotFoundEss = NULL;
	}
	if (hNotFoundNonEss) {
		DestroyIcon(hNotFoundNonEss);
		hNotFoundNonEss = NULL;
	}

	EndDialog(hSelDlg, 0);
}

// User clicked ok for a driver in the list
static void SelOkay()
{
	if(!bFavSelected)
	{
		TV_ITEM TvItem;
		unsigned int nSelect = 0;
		HTREEITEM hSelectHandle = (HTREEITEM)SendMessage(hSelList, TVM_GETNEXTITEM, TVGN_CARET, ~0U);

		if (!hSelectHandle)	{			// Nothing is selected, return without closing the window
			return;
		}

		TvItem.hItem = hSelectHandle;
		TvItem.mask = TVIF_PARAM;
		SendMessage(hSelList, TVM_GETITEM, 0, (LPARAM)&TvItem);
		nSelect = ((NODEINFO*)TvItem.lParam)->nBurnDrvNo;

	#if DISABLE_NON_AVAILABLE_SELECT
		if (!gameAv[nSelect]) {			// Game not available, return without closing the window
			return;
		}
	#endif

	#if NON_WORKING_PROMPT_ON_LOAD
		if (!CheckWorkingStatus(nSelect)) {
			if (MessageBox(hSelDlg, _T("This game isn't working. Load it anyway?"), _T("Warning!"), MB_YESNO | MB_DEFBUTTON2 | MB_ICONWARNING) == IDNO) {
				return;
			}
		}
	#endif
		nDialogSelect = nSelect;
	}

	bDialogCancel = false;
	MyEndDialog();
}

static void RefreshPanel()
{
	// clear preview shot
	if (hPrevBmp) {
		DeleteObject((HGDIOBJ)hPrevBmp);
		hPrevBmp = NULL;
	}
	if (nTimer) {
		KillTimer(hSelDlg, nTimer);
		nTimer = 0;
	}

	SendDlgItemMessage(hSelDlg, IDC_SCREENSHOT_H, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)hPreview);
	SendDlgItemMessage(hSelDlg, IDC_SCREENSHOT_V, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)NULL);

	// Clear the things in our Info-box
	for (int i = 0; i < 6; i++) {
		SendMessage(hInfoText[i], WM_SETTEXT, (WPARAM)0, (LPARAM)_T(""));
		EnableWindow(hInfoLabel[i], FALSE);
	}

	CheckDlgButton(hSelDlg, IDC_CHECKAUTOEXPAND, (nLoadMenuShowX & AUTOEXPAND) ? BST_CHECKED : BST_UNCHECKED);
	CheckDlgButton(hSelDlg, IDC_CHECKAVAILABLEONLY, (nLoadMenuShowX & AVAILONLY) ? BST_CHECKED : BST_UNCHECKED);

	CheckDlgButton(hSelDlg, IDC_SEL_SHORTNAME, nLoadMenuShowX & SHOWSHORT ? BST_CHECKED : BST_UNCHECKED);
	CheckDlgButton(hSelDlg, IDC_SEL_ASCIIONLY, nLoadMenuShowX & ASCIIONLY ? BST_CHECKED : BST_UNCHECKED);
}

static void RebuildEverything()
{
	RefreshPanel();

	bDrvSelected = false;

	TreeBuilding = 1;
	SendMessage(hSelList, WM_SETREDRAW, (WPARAM)FALSE,(LPARAM)TVI_ROOT);	// disable redraw
	SendMessage(hSelList, TVM_DELETEITEM, 0, (LPARAM)TVI_ROOT);				// Destory all nodes
	SelListMake();
	SendMessage(hSelList, WM_SETREDRAW, (WPARAM)TRUE, (LPARAM)TVI_ROOT);	// enable redraw

	// Clear the things in our Info-box
	for (int i = 0; i < 6; i++) {
		SendMessage(hInfoText[i], WM_SETTEXT, (WPARAM)0, (LPARAM)_T(""));
		EnableWindow(hInfoLabel[i], FALSE);
	}

	TreeBuilding = 0;
}

#define _TVCreateFiltersA(a, b, c, d, e)											\
{																					\
	TvItem.hParent = a;																\
	TvItem.item.pszText = FBALoadStringEx(hAppInst, b, true);						\
	c = (HTREEITEM)SendMessage(hFilterList, TVM_INSERTITEM, 0, (LPARAM)&TvItem);	\
	_TreeView_SetCheckState(hFilterList, d, (e) ? FALSE : TRUE);					\
}

#define _TVCreateFiltersB(a, b, c)													\
{																					\
	TvItem.hParent = a;																\
	TvItem.item.pszText = FBALoadStringEx(hAppInst, b, true);						\
	c = (HTREEITEM)SendMessage(hFilterList, TVM_INSERTITEM, 0, (LPARAM)&TvItem);	\
}

static void CreateFilters()
{
	TV_INSERTSTRUCT TvItem;
	memset(&TvItem, 0, sizeof(TvItem));

	hFilterList			= GetDlgItem(hSelDlg, IDC_TREE2);

	TvItem.item.mask	= TVIF_TEXT | TVIF_PARAM;
	TvItem.hInsertAfter = TVI_LAST;

	_TVCreateFiltersB(TVI_ROOT		, IDS_SEL_FILTERS		, hRoot			);
	_TVCreateFiltersB(hRoot			, IDS_SEL_BOARDTYPE		, hBoardType	);

	_TVCreateFiltersA(hBoardType	, IDS_SEL_GENUINE		, hFilterGenuine		, hFilterGenuine	, nLoadMenuBoardTypeFilter & MASKBOARDTYPEGENUINE	);
	_TVCreateFiltersA(hBoardType	, IDS_SEL_BOOTLEG		, hFilterBootleg		, hFilterBootleg	, nLoadMenuBoardTypeFilter & BDF_BOOTLEG			);
	_TVCreateFiltersA(hBoardType	, IDS_SEL_DEMO			, hFilterDemo			, hFilterDemo		, nLoadMenuBoardTypeFilter & BDF_DEMO				);
	_TVCreateFiltersA(hBoardType	, IDS_SEL_HACK			, hFilterHack			, hFilterHack		, nLoadMenuBoardTypeFilter & BDF_HACK				);
	_TVCreateFiltersA(hBoardType	, IDS_SEL_HOMEBREW		, hFilterHomebrew		, hFilterHomebrew	, nLoadMenuBoardTypeFilter & BDF_HOMEBREW			);
	_TVCreateFiltersA(hBoardType	, IDS_SEL_PROTOTYPE		, hFilterPrototype		, hFilterPrototype	, nLoadMenuBoardTypeFilter & BDF_PROTOTYPE			);

	_TVCreateFiltersB(hRoot			, IDS_FAMILY			, hFamily);

	_TVCreateFiltersA(hFamily		, IDS_FAMILY_OTHER		, hFilterOtherFamily	, hFilterOtherFamily, nLoadMenuFamilyFilter & MASKFAMILYOTHER			);
	_TVCreateFiltersA(hFamily		, IDS_FAMILY_19XX		, hFilter19xx			, hFilter19xx		, nLoadMenuFamilyFilter & FBF_19XX					);
	_TVCreateFiltersA(hFamily		, IDS_FAMILY_SONICWI	, hFilterSonicwi		, hFilterSonicwi	, nLoadMenuFamilyFilter & FBF_SONICWI				);
	_TVCreateFiltersA(hFamily		, IDS_FAMILY_DSTLK		, hFilterDstlk			, hFilterDstlk		, nLoadMenuFamilyFilter & FBF_DSTLK					);
	_TVCreateFiltersA(hFamily		, IDS_FAMILY_FATFURY	, hFilterFatfury		, hFilterFatfury	, nLoadMenuFamilyFilter & FBF_FATFURY				);
	_TVCreateFiltersA(hFamily		, IDS_FAMILY_KOF		, hFilterKof			, hFilterKof		, nLoadMenuFamilyFilter & FBF_KOF					);
	_TVCreateFiltersA(hFamily		, IDS_FAMILY_MSLUG		, hFilterMslug			, hFilterMslug		, nLoadMenuFamilyFilter & FBF_MSLUG					);
	_TVCreateFiltersA(hFamily		, IDS_FAMILY_PWRINST	, hFilterPwrinst		, hFilterPwrinst	, nLoadMenuFamilyFilter & FBF_PWRINST				);
	_TVCreateFiltersA(hFamily		, IDS_FAMILY_SAMSHO		, hFilterSamsho			, hFilterSamsho		, nLoadMenuFamilyFilter & FBF_SAMSHO				);
	_TVCreateFiltersA(hFamily		, IDS_FAMILY_SF			, hFilterSf				, hFilterSf			, nLoadMenuFamilyFilter & FBF_SF					);

	_TVCreateFiltersB(hRoot			, IDS_GENRE				, hGenre		);

	_TVCreateFiltersA(hGenre		, IDS_GENRE_BALLPADDLE	, hFilterBallpaddle		, hFilterBallpaddle	, nLoadMenuGenreFilter & GBF_BALLPADDLE				);
	_TVCreateFiltersA(hGenre		, IDS_GENRE_BIOS		, hFilterBios			, hFilterBios		, nLoadMenuGenreFilter & GBF_BIOS					);
	_TVCreateFiltersA(hGenre		, IDS_GENRE_BREAKOUT	, hFilterBreakout		, hFilterBreakout	, nLoadMenuGenreFilter & GBF_BREAKOUT				);
	_TVCreateFiltersA(hGenre		, IDS_GENRE_CASINO		, hFilterCasino			, hFilterCasino		, nLoadMenuGenreFilter & GBF_CASINO					);
	_TVCreateFiltersA(hGenre		, IDS_GENRE_SCRFIGHT	, hFilterScrfight		, hFilterScrfight	, nLoadMenuGenreFilter & GBF_SCRFIGHT				);
	_TVCreateFiltersA(hGenre		, IDS_GENRE_VSFIGHT		, hFilterVsfight		, hFilterVsfight	, nLoadMenuGenreFilter & GBF_VSFIGHT				);
	_TVCreateFiltersA(hGenre		, IDS_GENRE_MAHJONG		, hFilterMahjong		, hFilterMahjong	, nLoadMenuGenreFilter & GBF_MAHJONG				);
	_TVCreateFiltersA(hGenre		, IDS_GENRE_MAZE		, hFilterMaze			, hFilterMaze		, nLoadMenuGenreFilter & GBF_MAZE					);
	_TVCreateFiltersA(hGenre		, IDS_GENRE_MINIGAMES	, hFilterMinigames		, hFilterMinigames	, nLoadMenuGenreFilter & GBF_MINIGAMES				);
	_TVCreateFiltersA(hGenre		, IDS_GENRE_MISC		, hFilterMisc			, hFilterMisc		, nLoadMenuGenreFilter & GBF_MISC					);
	_TVCreateFiltersA(hGenre		, IDS_GENRE_PINBALL		, hFilterPinball		, hFilterPinball	, nLoadMenuGenreFilter & GBF_PINBALL				);
	_TVCreateFiltersA(hGenre		, IDS_GENRE_PLATFORM	, hFilterPlatform		, hFilterPlatform	, nLoadMenuGenreFilter & GBF_PLATFORM				);
	_TVCreateFiltersA(hGenre		, IDS_GENRE_PUZZLE		, hFilterPuzzle			, hFilterPuzzle		, nLoadMenuGenreFilter & GBF_PUZZLE					);
	_TVCreateFiltersA(hGenre		, IDS_GENRE_QUIZ		, hFilterQuiz			, hFilterQuiz		, nLoadMenuGenreFilter & GBF_QUIZ					);
	_TVCreateFiltersA(hGenre		, IDS_GENRE_RACING		, hFilterRacing			, hFilterRacing		, nLoadMenuGenreFilter & GBF_RACING					);
	_TVCreateFiltersA(hGenre		, IDS_GENRE_HORSHOOT	, hFilterHorshoot		, hFilterHorshoot	, nLoadMenuGenreFilter & GBF_HORSHOOT				);
	_TVCreateFiltersA(hGenre		, IDS_GENRE_SHOOT		, hFilterShoot			, hFilterShoot		, nLoadMenuGenreFilter & GBF_SHOOT					);
	_TVCreateFiltersA(hGenre		, IDS_GENRE_VERSHOOT	, hFilterVershoot		, hFilterVershoot	, nLoadMenuGenreFilter & GBF_VERSHOOT				);
	_TVCreateFiltersA(hGenre		, IDS_GENRE_SPORTSMISC	, hFilterSportsmisc		, hFilterSportsmisc	, nLoadMenuGenreFilter & GBF_SPORTSMISC				);
	_TVCreateFiltersA(hGenre		, IDS_GENRE_SPORTSFOOTBALL, hFilterSportsfootball, hFilterSportsfootball, nLoadMenuGenreFilter & GBF_SPORTSFOOTBALL		);

	_TVCreateFiltersB(hRoot			, IDS_SEL_HARDWARE, hHardware			);

	_TVCreateFiltersA(hHardware		, IDS_SEL_CAVE			, hFilterCave			, hFilterCave		, nLoadMenuShowX & MASKCAVE							);
	_TVCreateFiltersA(hHardware		, IDS_SEL_CPS1			, hFilterCps1			, hFilterCps1		, nLoadMenuShowX & MASKCPS							);
	_TVCreateFiltersA(hHardware		, IDS_SEL_CPS2			, hFilterCps2			, hFilterCps2		, nLoadMenuShowX & MASKCPS2							);
	_TVCreateFiltersA(hHardware		, IDS_SEL_CPS3			, hFilterCps3			, hFilterCps3		, nLoadMenuShowX & MASKCPS3							);
	_TVCreateFiltersA(hHardware		, IDS_SEL_KANEKO16		, hFilterKaneko16		, hFilterKaneko16	, nLoadMenuShowX & MASKKANEKO16						);
	_TVCreateFiltersA(hHardware		, IDS_SEL_KONAMI		, hFilterKonami			, hFilterKonami		, nLoadMenuShowX & MASKKONAMI						);
	_TVCreateFiltersA(hHardware		, IDS_SEL_NEOGEO		, hFilterNeogeo			, hFilterNeogeo		, nLoadMenuShowX & MASKNEOGEO						);
	_TVCreateFiltersA(hHardware		, IDS_SEL_PACMAN		, hFilterPacman			, hFilterPacman		, nLoadMenuShowX & MASKPACMAN						);
	_TVCreateFiltersA(hHardware		, IDS_SEL_PGM			, hFilterPgm			, hFilterPgm		, nLoadMenuShowX & MASKPGM							);
	_TVCreateFiltersA(hHardware		, IDS_SEL_PSIKYO		, hFilterPsikyo			, hFilterPsikyo		, nLoadMenuShowX & MASKPSIKYO						);
	_TVCreateFiltersA(hHardware		, IDS_SEL_SEGA			, hFilterSega			, hFilterSega		, nLoadMenuShowX & MASKSEGA							);
	_TVCreateFiltersA(hHardware		, IDS_SEL_TAITO			, hFilterTaito			, hFilterTaito		, nLoadMenuShowX & MASKTAITO						);
	_TVCreateFiltersA(hHardware		, IDS_SEL_TOAPLAN		, hFilterToaplan		, hFilterToaplan	, nLoadMenuShowX & MASKTOAPLAN						);
	_TVCreateFiltersA(hHardware		, IDS_SEL_MISCPRE90S	, hFilterMiscPre90s		, hFilterMiscPre90s	, nLoadMenuShowX & MASKMISCPRE90S					);
	_TVCreateFiltersA(hHardware		, IDS_SEL_MISCPOST90S	, hFilterMiscPost90s	, hFilterMiscPost90s, nLoadMenuShowX & MASKMISCPOST90S					);
	_TVCreateFiltersA(hHardware		, IDS_SEL_MEGADRIVE		, hFilterMegadrive		, hFilterMegadrive	, nLoadMenuShowX & MASKMEGADRIVE					);

	SendMessage(hFilterList	, TVM_EXPAND,TVE_EXPAND, (LPARAM)hRoot);
	SendMessage(hFilterList	, TVM_EXPAND,TVE_EXPAND, (LPARAM)hHardware);
}

static BOOL CALLBACK DialogProc(HWND hDlg, UINT Msg, WPARAM wParam, LPARAM lParam)
{
	InitCommonControls();

	if (Msg == WM_INITDIALOG) {

		hSelDlg = hDlg;

		SendDlgItemMessage(hDlg, IDC_SCREENSHOT_H, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)NULL);
		SendDlgItemMessage(hDlg, IDC_SCREENSHOT_V, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)NULL);

		hWhiteBGBrush	= CreateSolidBrush(RGB(0xFF,0xFF,0xFF));
		hPreview		= LoadBitmap(hAppInst, MAKEINTRESOURCE(BMP_PREVIEW));

		hExpand			= (HICON)LoadImage(hAppInst, MAKEINTRESOURCE(IDI_TV_PLUS), IMAGE_ICON, 16, 16, LR_DEFAULTCOLOR);
		hCollapse		= (HICON)LoadImage(hAppInst, MAKEINTRESOURCE(IDI_TV_MINUS), IMAGE_ICON, 16, 16, LR_DEFAULTCOLOR);
		hNotWorking		= (HICON)LoadImage(hAppInst, MAKEINTRESOURCE(IDI_TV_NOTWORKING), IMAGE_ICON, 16, 16, LR_DEFAULTCOLOR);
		hNotFoundEss	= (HICON)LoadImage(hAppInst, MAKEINTRESOURCE(IDI_TV_NOTFOUND_ESS), IMAGE_ICON, 16, 16, LR_DEFAULTCOLOR);
		hNotFoundNonEss = (HICON)LoadImage(hAppInst, MAKEINTRESOURCE(IDI_TV_NOTFOUND_NON), IMAGE_ICON, 16, 16, LR_DEFAULTCOLOR);

		TCHAR szOldTitle[1024] = _T(""), szNewTitle[1024] = _T("");
		GetWindowText(hSelDlg, szOldTitle, 1024);
		_sntprintf(szNewTitle, 1024, _T(APP_TITLE) _T(SEPERATOR_1) _T("%s"), szOldTitle);
		SetWindowText(hSelDlg, szNewTitle);

		hSelList		= GetDlgItem(hSelDlg, IDC_TREE1);
		hInfoLabel[0]	= GetDlgItem(hSelDlg, IDC_LABELROMNAME);
		hInfoLabel[1]	= GetDlgItem(hSelDlg, IDC_LABELROMINFO);
		hInfoLabel[2]	= GetDlgItem(hSelDlg, IDC_LABELSYSTEM);
		hInfoLabel[3]	= GetDlgItem(hSelDlg, IDC_LABELCOMMENT);
		hInfoLabel[4]	= GetDlgItem(hSelDlg, IDC_LABELNOTES);
		hInfoLabel[5]	= GetDlgItem(hSelDlg, IDC_LABELGENRE);
		hInfoText[0]	= GetDlgItem(hSelDlg, IDC_TEXTROMNAME);
		hInfoText[1]	= GetDlgItem(hSelDlg, IDC_TEXTROMINFO);
		hInfoText[2]	= GetDlgItem(hSelDlg, IDC_TEXTSYSTEM);
		hInfoText[3]	= GetDlgItem(hSelDlg, IDC_TEXTCOMMENT);
		hInfoText[4]	= GetDlgItem(hSelDlg, IDC_TEXTNOTES);
		hInfoText[5]	= GetDlgItem(hSelDlg, IDC_TEXTGENRE);

#if !defined _UNICODE
		EnableWindow(GetDlgItem(hDlg, IDC_SEL_ASCIIONLY), FALSE);
#endif

		bool bFoundROMs = false;
		for (unsigned int i = 0; i < nBurnDrvCount; i++) {
			if (gameAv[i]) {
				bFoundROMs = true;
				break;
			}
		}
		if (!bFoundROMs) {
			RomsDirCreate(hSelDlg);
		}

		RebuildEverything();

		if (nDialogSelect > -1) {
			for (unsigned int i = 0; i < nTmpDrvCount; i++) {
				if (nBurnDrv[i].nBurnDrvNo == nDialogSelect) {
					SendMessage(hSelList, TVM_SELECTITEM, (WPARAM)TVGN_CARET, (LPARAM)nBurnDrv[i].hTreeHandle);
					break;
				}
			}

			SendMessage(hDlg, WM_NEXTDLGCTL, (WPARAM)hSelList, TRUE);
		}

		DWORD dwStyle;
		dwStyle = (DWORD) GetWindowLongPtr (GetDlgItem(hSelDlg, IDC_TREE2), GWL_STYLE);
		dwStyle |= TVS_CHECKBOXES;
		SetWindowLongPtr (GetDlgItem(hSelDlg, IDC_TREE2), GWL_STYLE, (LONG_PTR) dwStyle);

		CreateFilters();

		bDoPatch = FALSE;
		PatchExit();

		WndInMid(hDlg, hParent);

		/*ImageButton_EnableXPThemes();
		ImageButton_Create(hSelDlg, IDCANCEL);
		ImageButton_Create(hSelDlg, IDOK);
		ImageButton_Create(hSelDlg, IDROM);
		ImageButton_Create(hSelDlg, IDRESCAN);
		ImageButton_SetIcon(GetDlgItem(hSelDlg, IDCANCEL), IDI_CANCEL, 0,0,16,16);
		ImageButton_SetIcon(GetDlgItem(hSelDlg, IDOK), IDI_PLAY, 0,0,16,16);
		ImageButton_SetIcon(GetDlgItem(hSelDlg, IDROM), IDI_SCAN, 0,0,16,16);
		ImageButton_SetIcon(GetDlgItem(hSelDlg, IDRESCAN), IDI_ROMDIRS, 0,0,16,16);*/

		HICON hIcon = LoadIcon(hAppInst, MAKEINTRESOURCE(IDI_APP));
		SendMessage(hSelDlg, WM_SETICON, ICON_SMALL, (LPARAM)hIcon);		// Set the Game Selection dialog icon.

		/* commented icon loading is a test for future possible feature (CaptainCPS-X)  ----------------------------*/

		//HICON hIcon = (HICON)LoadImage(hAppInst, _T("icons\\fba.ico"), IMAGE_ICON, 16, 16, LR_LOADFROMFILE);
		//SendMessage(hSelDlg, WM_SETICON, ICON_SMALL, (LPARAM)hIcon);		// Set the Game Selection dialog icon.

		/* ---------------------------------------------------------------------------------------------------------*/

		hTabControl3	= GetDlgItem(hDlg, IDC_TAB3);			// GameList & Favorite games list tabs control
		listView		= GetDlgItem(hSelDlg, IDC_FAVLIST);		// Favorite games 'list view' control
		InsertTabs();											// Insert Game list & Favorites tabs
		InitFavGameList();										// Initiate Favorites Module
		ShowWindow(GetDlgItem(hSelDlg, IDC_FAVLIST), SW_HIDE);	// Hide Favorites Gamelist

		return TRUE;
	}

	if (Msg == WM_COMMAND) {
		if (HIWORD(wParam) == BN_CLICKED) {
			int wID = LOWORD(wParam);
			switch (wID) {
				case IDOK:
					SelOkay();
					break;
				case IDROM:
					RomsDirCreate(hSelDlg);
					RebuildEverything();
					break;
				case IDRESCAN:
					bRescanRoms = true;
					CreateROMInfo(hSelDlg);
					RebuildEverything();
					break;
				case IDCANCEL:
					bDialogCancel = true;
					SendMessage(hDlg, WM_CLOSE, 0, 0);
					return 0;

				case IDC_CHECKAVAILABLEONLY:
					nLoadMenuShowX ^= AVAILONLY;
					RebuildEverything();
					break;
				case IDC_CHECKAUTOEXPAND:
					nLoadMenuShowX ^= AUTOEXPAND;
					RebuildEverything();
					break;
				case IDC_SEL_SHORTNAME:
					nLoadMenuShowX ^= SHOWSHORT;
					RebuildEverything();
					break;
				case IDC_SEL_ASCIIONLY:
					nLoadMenuShowX ^= ASCIIONLY;
					RebuildEverything();
					break;
			}
		}

		int id = LOWORD(wParam);

		switch (id) {

			// ADD TO FAVORITES
			//---------------------------------------------------------------------------------------------
			case ID_ADDFAV:
			{
				//bRClick = true; // right buttom is clicked
				int iItem;

				TCHAR* ItemRomname				= NULL;
#if defined (_UNICODE)
				TCHAR* ItemUnicodeTitle			= NULL;
#else
				TCHAR* ItemTitle				= NULL;
#endif
				TCHAR* ItemHardware				= NULL;
				TCHAR* ItemYear					= NULL;
				TCHAR* ItemCompany				= NULL;
				char ItemMaxPlayers[64]			= "";
				TCHAR pszItemMaxPlayers[64]		= _T("");

				iItem = SendMessage(GetDlgItem(hSelDlg, IDC_FAVLIST), LVM_GETITEMCOUNT,0,0); // num. of items in the listview

				// Get the text from the drivers via BurnDrvGetText()
				ItemRomname		= BurnDrvGetText(DRV_NAME);						// Romset Name
#if defined (_UNICODE)
				ItemUnicodeTitle= BurnDrvGetText(DRV_FULLNAME);					// Unicode Game Title
#else
				ItemTitle		= BurnDrvGetText(DRV_ASCIIONLY | DRV_FULLNAME);	// ASCII Game Title
#endif
				ItemHardware	= BurnDrvGetText(DRV_SYSTEM);					// Game Hardware / System
				ItemYear		= BurnDrvGetText(DRV_DATE);						// Year
				ItemCompany		= BurnDrvGetText(DRV_MANUFACTURER);				// Manufacturer / Company

				// Max Players
				sprintf(ItemMaxPlayers, "%i", BurnDrvGetMaxPlayers());
				ANSIToTCHAR(ItemMaxPlayers, pszItemMaxPlayers, 64);

				LVITEM LvItem;						// LVITEM structure
				memset(&LvItem, 0, sizeof(LvItem));	// Zero struct's Members
				LvItem.mask = LVIF_TEXT;			// Text Style
				LvItem.cchTextMax = 256;			// Max size of text

				// Add Romname, Title and Hardware of the selected game to the Favorites List
				for (int i = 0; i < 5; i++)
				{
					switch (i)
					{
						// ROMNAME
						case 0: {
							//-------------------------------------------------------
							LvItem.iItem = iItem;
							LvItem.iSubItem = i;
							LvItem.pszText = ItemRomname;
							SendMessage(listView,LVM_INSERTITEM,0,(LPARAM)&LvItem);
						}
						break;

						// TITLE
						case 1: {
							//-------------------------------------------------------
							LvItem.iSubItem = i;
#if defined (_UNICODE)
							LvItem.pszText = ItemUnicodeTitle;
#else
							LvItem.pszText = ItemTitle;
#endif
							SendMessage(listView, LVM_SETITEM, 0, (LPARAM)&LvItem);
						}
						break;

						// HARDWARE
						case 2: {
							//-------------------------------------------------------
							LvItem.iSubItem = i;
							LvItem.pszText = ItemHardware;
							SendMessage(listView,LVM_SETITEM,0,(LPARAM)&LvItem);
						}
						break;

						// YEAR
						case 3: {
							//-------------------------------------------------------
							LvItem.iSubItem = i;
							LvItem.pszText = ItemYear;
							SendMessage(listView,LVM_SETITEM,0,(LPARAM)&LvItem);
						}
						break;

						// MANUFACTURER / COMPANY
						case 4: {
							//-------------------------------------------------------
							LvItem.iSubItem = i;
							LvItem.pszText = ItemCompany;
							SendMessage(listView,LVM_SETITEM,0,(LPARAM)&LvItem);
						}
						break;

						// MAX PLAYERS
						case 5: {
							//-------------------------------------------------------
							LvItem.iSubItem = i;
							LvItem.pszText = pszItemMaxPlayers;
							SendMessage(listView,LVM_SETITEM,0,(LPARAM)&LvItem);
						}
						break;
					}
				}

				FILE *f = NULL;
				HWND hwndLV = GetDlgItem(hSelDlg, IDC_FAVLIST);
				long Lines = SendMessage((HWND) hwndLV, (UINT) LVM_GETITEMCOUNT, (WPARAM) 0, (LPARAM) 0);

				// Save the Favorite Games List
				SaveFavList(hwndLV, f, szFavoritesDat, Lines, 4);

			}
			break;

			// REMOVE FROM FAVORITES
			//---------------------------------------------------------------------------------------------
			case ID_REMOVEFAV:
			{
				//bRClick = true; // right buttom is clicked

				unsigned int iSel;

				iSel = SendMessage(GetDlgItem(hSelDlg, IDC_FAVLIST), LVM_GETNEXTITEM, ~0U, LVNI_FOCUSED);

				ListView_DeleteItem(GetDlgItem(hSelDlg, IDC_FAVLIST), iSel);

				FILE *f = NULL;
				HWND hwndLV = GetDlgItem(hSelDlg, IDC_FAVLIST);
				long Lines = SendMessage((HWND) hwndLV, (UINT) LVM_GETITEMCOUNT, (WPARAM) 0, (LPARAM) 0);

				// Save the Favorite Games List
				SaveFavList(hwndLV, f, szFavoritesDat, Lines, 4);

				// Refresh Favorite Games List
				RefreshFavGameList();

			}
			break;

			case GAMESEL_MENU_PLAY: {
				SelOkay();
				break;
			}

			case GAMESEL_MENU_GAMEINFO: {
				UpdatePreview(true, hSelDlg, szAppPreviewsPath);
				if (nTimer) {
					KillTimer(hSelDlg, nTimer);
					nTimer = 0;
				}
				GameInfoDialogCreate(hSelDlg, nBurnDrvSelect);
				break;
			}

			case GAMESEL_MENU_IPSMANAGER: {
				IpsManagerCreate(hSelDlg);
				break;
			}

			case GAMESEL_MENU_IPSPLAY: {
				bDoPatch = TRUE;
				SelOkay();
				break;
			}

			case GAMESEL_MENU_JUKEBOX: {
				bJukeboxInUse = true;
				SelOkay();
				break;
			}

			case GAMESEL_MENU_VIEWMAWS: {
				if (!nVidFullscreen) {
					TCHAR szURL[MAX_PATH];
					_stprintf(szURL, _T("http://www.mameworld.net/maws/romset/%s/"), BurnDrvGetText(DRV_NAME));
					ShellExecute(NULL, _T("open"), szURL, NULL, NULL, SW_SHOWNORMAL);
				}
				break;
			}

			case GAMESEL_MENU_VIEWCAESAR: {
				if (!nVidFullscreen) {
					TCHAR szURL[MAX_PATH];
					_stprintf(szURL, _T("http://caesar.logiqx.com/php/emulator_game.php?id=finalburnalpha&game=%s"), BurnDrvGetText(DRV_NAME));
					ShellExecute(NULL, _T("open"), szURL, NULL, NULL, SW_SHOWNORMAL);
				}
				break;
			}

			case GAMESEL_MENU_VIEWEMMA: {
				if (!nVidFullscreen) {
					TCHAR szURL[MAX_PATH];
					_stprintf(szURL, _T("http://www.progettoemma.net/gioco.php?&game=%s"), BurnDrvGetText(DRV_NAME));
					ShellExecute(NULL, _T("open"), szURL, NULL, NULL, SW_SHOWNORMAL);
				}
				break;
			}
		}
	}

	if (Msg == WM_CLOSE) {

		nDialogSelect = nOldDlgSelected;

		MyEndDialog();
		DeleteObject(hWhiteBGBrush);
		return 0;
	}

	if (Msg == WM_TIMER) {
		UpdatePreview(false, hSelDlg, szAppPreviewsPath);
		return 0;
	}

	if (Msg == WM_CTLCOLORSTATIC) {
		for (int i = 0; i < 6; i++) {
			if ((HWND)lParam == hInfoLabel[i]) {
				return (BOOL)hWhiteBGBrush;
			}
			if ((HWND)lParam == hInfoText[i]) {
				return (BOOL)hWhiteBGBrush;
			}
		}
	}

	NMHDR* pNmHdr = (NMHDR*)lParam;
	if (Msg == WM_NOTIFY)
	{
		static int lastColumnIndex = -1;

		// SORT FAV GAME LIST
		if (pNmHdr->code == LVN_COLUMNCLICK && LOWORD(wParam) == IDC_FAVLIST)
		{
			NMLISTVIEW *nmlv = (NMLISTVIEW*)lParam;

			listView = nmlv->hdr.hwndFrom;
			columnIndex = nmlv->iSubItem;

			if (lastColumnIndex == columnIndex) {
				isAscendingOrder = !isAscendingOrder;
			} else {
				isAscendingOrder = FALSE;
			}

			ListView_SetHeaderSortImage(listView, columnIndex, isAscendingOrder);
			lastColumnIndex = columnIndex;

			// Sort Favorite Games List (macro)
			ListView_SortItemsEx(listView, ListView_CompareFunc, (LPARAM)listView);

			return 1;
		}

		// GAME SELECTED IN FAVORITES
		if (pNmHdr->code == NM_CLICK && LOWORD(wParam) == IDC_FAVLIST)
		{
			int iCount		= SendMessage(GetDlgItem(hSelDlg, IDC_FAVLIST), LVM_GETITEMCOUNT, 0, 0);
			int iSelCount	= SendMessage(GetDlgItem(hSelDlg, IDC_FAVLIST), LVM_GETSELECTEDCOUNT, 0, 0);

			if(iCount == 0 || iSelCount == 0) return 1;

			TCHAR szRomSet[9] = _T("");

			int iSel = SendMessage(GetDlgItem(hSelDlg, IDC_FAVLIST), LVM_GETNEXTITEM, (WPARAM)-1, LVNI_FOCUSED);

			LVITEM LvItem;
			memset(&LvItem, 0, sizeof(LvItem));
			LvItem.iItem		= iSel;
			LvItem.mask			= LVIF_TEXT;
			LvItem.iSubItem		= 0;
			LvItem.pszText		= szRomSet;
			LvItem.cchTextMax	= 9;

			SendMessage(GetDlgItem(hSelDlg, IDC_FAVLIST), LVM_GETITEMTEXT, (WPARAM)iSel, (LPARAM)&LvItem);

			for (unsigned int i = 0; i < nBurnDrvCount; i++)
			{
				nBurnDrvSelect = i;
				if (!(_tcscmp(BurnDrvGetText(DRV_NAME), szRomSet))) {
					break;
				}
			}

			nDialogSelect	= nBurnDrvSelect;
			bDrvSelected	= true;
			bFavSelected	= true;
			UpdatePreview(true, hSelDlg, szAppPreviewsPath);

			// Get the text from the drivers via BurnDrvGetText()
			for (unsigned int i = 0; i < 5; i++) {
				int nGetTextFlags = nLoadMenuShowX & ASCIIONLY ? DRV_ASCIIONLY : 0;
				TCHAR szItemText[256];
				szItemText[0] = _T('\0');

				switch (i) {
					case 0: {
						bool bBracket = false;

						_stprintf(szItemText, _T("%s"), BurnDrvGetText(DRV_NAME));

						if ((BurnDrvGetFlags() & BDF_CLONE) && BurnDrvGetTextA(DRV_PARENT)) {
							int nOldDrvSelect = nBurnDrvSelect;
							TCHAR* pszName = BurnDrvGetText(DRV_PARENT);

							_stprintf(szItemText + _tcslen(szItemText), _T(" (clone of %s"), BurnDrvGetText(DRV_PARENT));

							for (nBurnDrvSelect = 0; nBurnDrvSelect < nBurnDrvCount; nBurnDrvSelect++) {
								if (!_tcsicmp(pszName, BurnDrvGetText(DRV_NAME))) {
									break;
								}
							}
							if (nBurnDrvSelect < nBurnDrvCount) {
								if (BurnDrvGetText(DRV_PARENT)) {
									_stprintf(szItemText + _tcslen(szItemText), _T(", uses ROMs from %s"), BurnDrvGetText(DRV_PARENT));
								}
							}
							nBurnDrvSelect = nOldDrvSelect;
							bBracket = true;
						} else {
							if (BurnDrvGetTextA(DRV_PARENT)) {
								_stprintf(szItemText + _tcslen(szItemText), _T("%suses ROMs from %s"), bBracket ? _T(", ") : _T(" ("), BurnDrvGetText(DRV_PARENT));
								bBracket = true;
							}
						}
						if (bBracket) {
							_stprintf(szItemText + _tcslen(szItemText), _T(")"));
						}
						SendMessage(hInfoText[i], WM_SETTEXT, (WPARAM)0, (LPARAM)szItemText);
						EnableWindow(hInfoLabel[i], TRUE);
						break;
					}

					case 1: {
						bool bUseInfo = false;
						if (BurnDrvGetFlags() & BDF_PROTOTYPE) {
							_stprintf(szItemText + _tcslen(szItemText), _T("prototype"));
							bUseInfo = true;
						}
						if (BurnDrvGetFlags() & BDF_BOOTLEG) {
							_stprintf(szItemText + _tcslen(szItemText), _T("%sbootleg / hack"), bUseInfo ? _T(", ") : _T(""));
							bUseInfo = true;
						}
						_stprintf(szItemText + _tcslen(szItemText), _T("%s%i player%s"), bUseInfo ? _T(", ") : _T(""), BurnDrvGetMaxPlayers(), (BurnDrvGetMaxPlayers() != 1) ? _T("s max") : _T(""));
						bUseInfo = true;
						if (BurnDrvGetText(DRV_BOARDROM)) {
							_stprintf(szItemText + _tcslen(szItemText), _T("%suses board-ROMs from %s"), bUseInfo ? _T(", ") : _T(""), BurnDrvGetText(DRV_BOARDROM));
							SendMessage(hInfoText[i], WM_SETTEXT, (WPARAM)0, (LPARAM)szItemText);
							EnableWindow(hInfoLabel[i], TRUE);
							bUseInfo = true;
						}
						SendMessage(hInfoText[i], WM_SETTEXT, (WPARAM)0, (LPARAM)szItemText);
						EnableWindow(hInfoLabel[i], bUseInfo);
						break;
					}
					case 2: {
						_stprintf(szItemText, _T("%s (%s, %s hardware)"), BurnDrvGetTextA(DRV_MANUFACTURER) ? BurnDrvGetText(nGetTextFlags | DRV_MANUFACTURER) : _T("unknown"), BurnDrvGetText(DRV_DATE), BurnDrvGetText(nGetTextFlags | DRV_SYSTEM));
						SendMessage(hInfoText[i], WM_SETTEXT, (WPARAM)0, (LPARAM)szItemText);
						EnableWindow(hInfoLabel[i], TRUE);
						break;
					}
					case 3: {
						TCHAR szText[1024] = _T("");
						TCHAR* pszPosition = szText;
						TCHAR* pszName = BurnDrvGetText(nGetTextFlags | DRV_FULLNAME);

						pszPosition += _sntprintf(szText, 1024, pszName);

						pszName = BurnDrvGetText(nGetTextFlags | DRV_FULLNAME);
						while ((pszName = BurnDrvGetText(nGetTextFlags | DRV_NEXTNAME | DRV_FULLNAME)) != NULL) {
							if (pszPosition + _tcslen(pszName) - 1024 > szText) {
								break;
							}
							pszPosition += _stprintf(pszPosition, _T(SEPERATOR_2) _T("%s"), pszName);
						}
						SendMessage(hInfoText[i], WM_SETTEXT, (WPARAM)0, (LPARAM)szText);
						if (szText[0]) {
							EnableWindow(hInfoLabel[i], TRUE);
						} else {
							EnableWindow(hInfoLabel[i], FALSE);
						}
						break;
					}
					case 4: {
						_stprintf(szItemText, _T("%s"), BurnDrvGetTextA(DRV_COMMENT) ? BurnDrvGetText(nGetTextFlags | DRV_COMMENT) : _T(""));
						SendMessage(hInfoText[i], WM_SETTEXT, (WPARAM)0, (LPARAM)szItemText);
						EnableWindow(hInfoLabel[i], TRUE);
						break;
					}
				}
			}

			//return 1;
		}

		// Tabs changed
		if (pNmHdr->code == TCN_SELCHANGE)
		{
			int nTab = SendMessage(hTabControl3, TCM_GETCURSEL, 0, 0);

			switch(nTab)
			{
				// Games list tab
				case 0:
					RebuildEverything();
					DisplayControls(0,1);
					break;
				// Favorite games list tab
				case 1:
					RebuildEverything();
					RefreshFavGameList();
					DisplayControls(1,1);
					break;
			}
			return FALSE;
		}

		// Favorites context menu
		if (pNmHdr->code == NM_RCLICK && LOWORD(wParam) == IDC_FAVLIST)
		{
			HMENU hMenuLoad,hMenuX; // Context Menu handlers
			POINT oPoint,pt;

			int iCount		= SendMessage(GetDlgItem(hSelDlg, IDC_FAVLIST), LVM_GETITEMCOUNT, 0, 0);
			int iSelCount	= SendMessage(GetDlgItem(hSelDlg, IDC_FAVLIST), LVM_GETSELECTEDCOUNT, 0, 0);

			if(iCount == 0 || iSelCount == 0) return 1;

			GetCursorPos( &pt);
			ScreenToClient(hSelList,&pt);
			GetCursorPos( &oPoint);

			// Load Favorite Games List context menu
			hMenuLoad = FBALoadMenu(hAppInst, MAKEINTRESOURCE(IDR_MENU_FAVLIST));
			hMenuX = GetSubMenu(hMenuLoad, 0);

			TCHAR RomSet[9]	= _T("");
			unsigned int iSel	= 0;
			unsigned int i		= 0;

			iSel = SendMessage(GetDlgItem(hSelDlg, IDC_FAVLIST), LVM_GETNEXTITEM, (WPARAM)-1, LVNI_FOCUSED);

			LVITEM LvItem;
			memset(&LvItem,0,sizeof(LvItem));
			LvItem.mask			= LVIF_TEXT;
			LvItem.iSubItem		= 0;
			LvItem.pszText		= RomSet;
			LvItem.cchTextMax	= 9;
			LvItem.iItem		= iSel;

			SendMessage(GetDlgItem(hSelDlg, IDC_FAVLIST), LVM_GETITEMTEXT, iSel, (LPARAM)&LvItem);

			for (i = 0; i < nBurnDrvCount; i++) {
				nBurnDrvSelect = i;
				if (_tcscmp(BurnDrvGetText(0), RomSet) == 0) break;
			}

			nDialogSelect	= nBurnDrvSelect;
			bDrvSelected	= true;
			bFavSelected	= true;
			UpdatePreview(true, hSelDlg, szAppPreviewsPath);

			if (BurnJukeboxGetFlags() & JBF_GAME_WORKING) {
				EnableMenuItem(hMenuX, GAMESEL_MENU_JUKEBOX,	MF_ENABLED	| MF_BYCOMMAND);
			} else {
				EnableMenuItem(hMenuX, GAMESEL_MENU_JUKEBOX,	MF_GRAYED	| MF_BYCOMMAND);
			}

			if (GetNumPatches()) {
				EnableMenuItem(hMenuX, GAMESEL_MENU_IPSMANAGER, MF_ENABLED	| MF_BYCOMMAND);
			} else {
				EnableMenuItem(hMenuX, GAMESEL_MENU_IPSMANAGER, MF_GRAYED	| MF_BYCOMMAND);
			}

			LoadActivePatches();
			if (GetNumActivePatches()) {
				EnableMenuItem(hMenuX, GAMESEL_MENU_IPSPLAY,	MF_ENABLED	| MF_BYCOMMAND);
			} else {
				EnableMenuItem(hMenuX, GAMESEL_MENU_IPSPLAY,	MF_GRAYED	| MF_BYCOMMAND);
			}

			TrackPopupMenu(hMenuX, TPM_LEFTALIGN | TPM_RIGHTBUTTON, oPoint.x, oPoint.y, 0, hSelDlg, NULL);
			DestroyMenu(hMenuLoad);

			//return FALSE;
		}

		// Favorites game list Double-Click event
		if (pNmHdr->code == NM_DBLCLK && LOWORD(wParam) == IDC_FAVLIST)
		{
			SelOkay();
			//return 1;
		}

		if (pNmHdr->code == NM_CLICK && LOWORD(wParam) == IDC_TREE2)
		{
			POINT cursorPos;
			GetCursorPos(&cursorPos);
			ScreenToClient(hFilterList, &cursorPos);

			TVHITTESTINFO thi;
			thi.pt = cursorPos;
			TreeView_HitTest(hFilterList, &thi);

			if (thi.flags == TVHT_ONITEMSTATEICON) {
				if (thi.hItem == hFilterCave)			nLoadMenuShowX				^= MASKCAVE;
				if (thi.hItem == hFilterCps1)			nLoadMenuShowX				^= MASKCPS;
				if (thi.hItem == hFilterCps2)			nLoadMenuShowX				^= MASKCPS2;
				if (thi.hItem == hFilterCps3)			nLoadMenuShowX				^= MASKCPS3;
				if (thi.hItem == hFilterKaneko16)		nLoadMenuShowX				^= MASKKANEKO16;
				if (thi.hItem == hFilterKonami)			nLoadMenuShowX				^= MASKKONAMI;
				if (thi.hItem == hFilterNeogeo)			nLoadMenuShowX				^= MASKNEOGEO;
				if (thi.hItem == hFilterPacman)			nLoadMenuShowX				^= MASKPACMAN;
				if (thi.hItem == hFilterPgm)			nLoadMenuShowX				^= MASKPGM;
				if (thi.hItem == hFilterPsikyo)			nLoadMenuShowX				^= MASKPSIKYO;
				if (thi.hItem == hFilterSega)			nLoadMenuShowX				^= MASKSEGA;
				if (thi.hItem == hFilterToaplan)		nLoadMenuShowX				^= MASKTOAPLAN;
				if (thi.hItem == hFilterTaito)			nLoadMenuShowX				^= MASKTAITO;
				if (thi.hItem == hFilterMiscPre90s)		nLoadMenuShowX				^= MASKMISCPRE90S;
				if (thi.hItem == hFilterMiscPost90s)	nLoadMenuShowX				^= MASKMISCPOST90S;
				if (thi.hItem == hFilterMegadrive)		nLoadMenuShowX				^= MASKMEGADRIVE;

				if (thi.hItem == hFilterBootleg)		nLoadMenuBoardTypeFilter	^= BDF_BOOTLEG;
				if (thi.hItem == hFilterDemo)			nLoadMenuBoardTypeFilter	^= BDF_DEMO;
				if (thi.hItem == hFilterHack)			nLoadMenuBoardTypeFilter	^= BDF_HACK;
				if (thi.hItem == hFilterHomebrew)		nLoadMenuBoardTypeFilter	^= BDF_HOMEBREW;
				if (thi.hItem == hFilterPrototype)		nLoadMenuBoardTypeFilter	^= BDF_PROTOTYPE;
				if (thi.hItem == hFilterGenuine)		nLoadMenuBoardTypeFilter	^= MASKBOARDTYPEGENUINE;

				if (thi.hItem == hFilterOtherFamily)	nLoadMenuFamilyFilter		^= MASKFAMILYOTHER;
				if (thi.hItem == hFilterMslug)			nLoadMenuFamilyFilter		^= FBF_MSLUG;
				if (thi.hItem == hFilterSf)				nLoadMenuFamilyFilter		^= FBF_SF;
				if (thi.hItem == hFilterKof)			nLoadMenuFamilyFilter		^= FBF_KOF;
				if (thi.hItem == hFilterDstlk)			nLoadMenuFamilyFilter		^= FBF_DSTLK;
				if (thi.hItem == hFilterFatfury)		nLoadMenuFamilyFilter		^= FBF_FATFURY;
				if (thi.hItem == hFilterSamsho)			nLoadMenuFamilyFilter		^= FBF_SAMSHO;
				if (thi.hItem == hFilter19xx)			nLoadMenuFamilyFilter		^= FBF_19XX;
				if (thi.hItem == hFilterSonicwi)		nLoadMenuFamilyFilter		^= FBF_SONICWI;
				if (thi.hItem == hFilterPwrinst)		nLoadMenuFamilyFilter		^= FBF_PWRINST;

				if (thi.hItem == hFilterHorshoot)		nLoadMenuGenreFilter		^= GBF_HORSHOOT;
				if (thi.hItem == hFilterVershoot)		nLoadMenuGenreFilter		^= GBF_VERSHOOT;
				if (thi.hItem == hFilterScrfight)		nLoadMenuGenreFilter		^= GBF_SCRFIGHT;
				if (thi.hItem == hFilterVsfight)		nLoadMenuGenreFilter		^= GBF_VSFIGHT;
				if (thi.hItem == hFilterBios)			nLoadMenuGenreFilter		^= GBF_BIOS;
				if (thi.hItem == hFilterBreakout)		nLoadMenuGenreFilter		^= GBF_BREAKOUT;
				if (thi.hItem == hFilterCasino)			nLoadMenuGenreFilter		^= GBF_CASINO;
				if (thi.hItem == hFilterBallpaddle)		nLoadMenuGenreFilter		^= GBF_BALLPADDLE;
				if (thi.hItem == hFilterMaze)			nLoadMenuGenreFilter		^= GBF_MAZE;
				if (thi.hItem == hFilterMinigames)		nLoadMenuGenreFilter		^= GBF_MINIGAMES;
				if (thi.hItem == hFilterPinball)		nLoadMenuGenreFilter		^= GBF_PINBALL;
				if (thi.hItem == hFilterPlatform)		nLoadMenuGenreFilter		^= GBF_PLATFORM;
				if (thi.hItem == hFilterPuzzle)			nLoadMenuGenreFilter		^= GBF_PUZZLE;
				if (thi.hItem == hFilterQuiz)			nLoadMenuGenreFilter		^= GBF_QUIZ;
				if (thi.hItem == hFilterSportsmisc)		nLoadMenuGenreFilter		^= GBF_SPORTSMISC;
				if (thi.hItem == hFilterSportsfootball) nLoadMenuGenreFilter		^= GBF_SPORTSFOOTBALL;
				if (thi.hItem == hFilterMisc)			nLoadMenuGenreFilter		^= GBF_MISC;
				if (thi.hItem == hFilterMahjong)		nLoadMenuGenreFilter		^= GBF_MAHJONG;
				if (thi.hItem == hFilterRacing)			nLoadMenuGenreFilter		^= GBF_RACING;
				if (thi.hItem == hFilterShoot)			nLoadMenuGenreFilter		^= GBF_SHOOT;

				RebuildEverything();
			}

			return 1;
		}

		if (pNmHdr->code == NM_DBLCLK && LOWORD(wParam) == IDC_TREE1)
		{
			SelOkay();

			// disable double-click node-expand
			SetWindowLong(hSelDlg, DWL_MSGRESULT, 1);

			return 1;
		}

		if (pNmHdr->code == NM_RCLICK && LOWORD(wParam) == IDC_TREE1) {

			HMENU hMenuLoad = FBALoadMenu(hAppInst, MAKEINTRESOURCE(IDR_MENU_GAMESEL));
			HMENU hMenuX = GetSubMenu(hMenuLoad, 0);

			POINT cursorPos, oPoint;
			GetCursorPos(&cursorPos);
			ScreenToClient(hSelList, &cursorPos);
			GetCursorPos(&oPoint);

			TVHITTESTINFO lpht;
			lpht.pt = cursorPos;
			HTREEITEM hSelectHandle = TreeView_HitTest(hSelList, &lpht);

			TreeView_SelectItem(hSelList,lpht.hItem);

			// Search through nBurnDrv[] for the nBurnDrvNo according to the returned hSelectHandle
			for (unsigned int i = 0; i < nTmpDrvCount; i++) {
				if (hSelectHandle == nBurnDrv[i].hTreeHandle) {
					nBurnDrvSelect = nBurnDrv[i].nBurnDrvNo;
					break;
				}
			}

			if (BurnJukeboxGetFlags() & JBF_GAME_WORKING) {
				EnableMenuItem(hMenuX, GAMESEL_MENU_JUKEBOX,	MF_ENABLED	| MF_BYCOMMAND);
			} else {
				EnableMenuItem(hMenuX, GAMESEL_MENU_JUKEBOX,	MF_GRAYED	| MF_BYCOMMAND);
			}

			if (GetNumPatches()) {
				EnableMenuItem(hMenuX, GAMESEL_MENU_IPSMANAGER, MF_ENABLED	| MF_BYCOMMAND);
			} else {
				EnableMenuItem(hMenuX, GAMESEL_MENU_IPSMANAGER, MF_GRAYED	| MF_BYCOMMAND);
			}

			LoadActivePatches();
			if (GetNumActivePatches()) {
				EnableMenuItem(hMenuX, GAMESEL_MENU_IPSPLAY,	MF_ENABLED	| MF_BYCOMMAND);
			} else {
				EnableMenuItem(hMenuX, GAMESEL_MENU_IPSPLAY,	MF_GRAYED	| MF_BYCOMMAND);
			}

			TrackPopupMenu(hMenuX, TPM_LEFTALIGN | TPM_RIGHTBUTTON, oPoint.x, oPoint.y, 0, hSelDlg, NULL);

			DestroyMenu(hMenuLoad);

			return 1;
		}

		if (pNmHdr->code == NM_CUSTOMDRAW && LOWORD(wParam) == IDC_TREE1) {
			LPNMLVCUSTOMDRAW lplvcd = (LPNMLVCUSTOMDRAW)lParam;
			int nGetTextFlags = nLoadMenuShowX & ASCIIONLY ? DRV_ASCIIONLY : 0;
			HTREEITEM hSelectHandle;

			switch (lplvcd->nmcd.dwDrawStage) {
				case CDDS_PREPAINT: {
					SetWindowLong(hSelDlg, DWL_MSGRESULT, CDRF_NOTIFYITEMDRAW);
					return 1;
				}

				case CDDS_ITEMPREPAINT:	{
					hSelectHandle = (HTREEITEM)(lplvcd->nmcd.dwItemSpec);
					HBRUSH hBackBrush;
					RECT rect;

					TV_ITEM TvItem;
					TvItem.hItem = hSelectHandle;
					TvItem.mask = TVIF_PARAM | TVIF_STATE | TVIF_CHILDREN;
					SendMessage(hSelList, TVM_GETITEM, 0, (LPARAM)&TvItem);

//					dprintf(_T("  - Item (%i×%i) - (%i×%i) %hs\n"), lplvcd->nmcd.rc.left, lplvcd->nmcd.rc.top, lplvcd->nmcd.rc.right, lplvcd->nmcd.rc.bottom, ((NODEINFO*)TvItem.lParam)->pszROMName);

					// Set the foreground and background colours unless the item is highlighted
					if (!(TvItem.state & (TVIS_SELECTED | TVIS_DROPHILITED))) {

						// Set less contrasting colours for clones
						if (!((NODEINFO*)TvItem.lParam)->bIsParent) {
							lplvcd->clrTextBk = RGB(0xF7, 0xF7, 0xF7);
							lplvcd->clrText = RGB(0x3F, 0x3F, 0x3F);
						}

						// For parents, change the colour of the background, for clones, change only the text colour
						if (!CheckWorkingStatus(((NODEINFO*)TvItem.lParam)->nBurnDrvNo)) {
							lplvcd->clrText = RGB(0x7F, 0x7F, 0x7F);
						}
					}

					rect.left = lplvcd->nmcd.rc.left;
					rect.right = lplvcd->nmcd.rc.right;
					rect.top = lplvcd->nmcd.rc.top;
					rect.bottom = lplvcd->nmcd.rc.bottom;

					hBackBrush = CreateSolidBrush(lplvcd->clrTextBk);

					nBurnDrvSelect = ((NODEINFO*)TvItem.lParam)->nBurnDrvNo;

					{
						// Fill background
						FillRect(lplvcd->nmcd.hdc, &lplvcd->nmcd.rc, hBackBrush);
					}

					{
						// Draw plus and minus buttons
						if (((NODEINFO*)TvItem.lParam)->bIsParent) {
							if (TvItem.state & TVIS_EXPANDED) {
								DrawIconEx(lplvcd->nmcd.hdc, rect.left + 4, rect.top, hCollapse, 16, 16, 0, NULL, DI_NORMAL);
							} else {
								if (TvItem.cChildren) {
									DrawIconEx(lplvcd->nmcd.hdc, rect.left + 4, rect.top, hExpand, 16, 16, 0, NULL, DI_NORMAL);
								}
							}
						}

						rect.left += 24;
					}

					{
						// Draw text

						TCHAR szText[1024] = _T("");
						TCHAR* pszPosition = szText;
						TCHAR* pszName;
						SIZE size = { 0, 0 };

						SetTextColor(lplvcd->nmcd.hdc, lplvcd->clrText);
						SetBkMode(lplvcd->nmcd.hdc, TRANSPARENT);

						// Display the short name if needed
						if (nLoadMenuShowX & SHOWSHORT) {
							DrawText(lplvcd->nmcd.hdc, BurnDrvGetText(DRV_NAME), -1, &rect, DT_LEFT);
							rect.left += 56;
						}


						{
							// Draw icons if needed
							if (!CheckWorkingStatus(((NODEINFO*)TvItem.lParam)->nBurnDrvNo)) {
								DrawIconEx(lplvcd->nmcd.hdc, rect.left, rect.top, hNotWorking, 16, 16, 0, NULL, DI_NORMAL);
								rect.left += 20;
							} else {
								if (!(gameAv[((NODEINFO*)TvItem.lParam)->nBurnDrvNo])) {
									DrawIconEx(lplvcd->nmcd.hdc, rect.left, rect.top, hNotFoundEss, 16, 16, 0, NULL, DI_NORMAL);
									rect.left += 20;
								} else {
									if (!(nLoadMenuShowX & AVAILONLY) && !(gameAv[((NODEINFO*)TvItem.lParam)->nBurnDrvNo] & 2)) {
										DrawIconEx(lplvcd->nmcd.hdc, rect.left, rect.top, hNotFoundNonEss, 16, 16, 0, NULL, DI_NORMAL);
										rect.left += 20;
									}
								}
							}
						}

						_tcsncpy(szText, MangleGamename(BurnDrvGetText(nGetTextFlags | DRV_FULLNAME), false), 1024);
						szText[1023] = _T('\0');

						GetTextExtentPoint32(lplvcd->nmcd.hdc, szText, _tcslen(szText), &size);

						DrawText(lplvcd->nmcd.hdc, szText, -1, &rect, DT_NOPREFIX | DT_SINGLELINE | DT_LEFT | DT_VCENTER);

						// Display extra info if needed
						szText[0] = _T('\0');

						pszName = BurnDrvGetText(nGetTextFlags | DRV_FULLNAME);
						while ((pszName = BurnDrvGetText(nGetTextFlags | DRV_NEXTNAME | DRV_FULLNAME)) != NULL) {
							if (pszPosition + _tcslen(pszName) - 1024 > szText) {
								break;
							}
							pszPosition += _stprintf(pszPosition, _T(SEPERATOR_2) _T("%s"), pszName);
						}
						if (szText[0]) {
							szText[255] = _T('\0');

							unsigned int r = ((lplvcd->clrText >> 16 & 255) * 2 + (lplvcd->clrTextBk >> 16 & 255)) / 3;
							unsigned int g = ((lplvcd->clrText >>  8 & 255) * 2 + (lplvcd->clrTextBk >>  8 & 255)) / 3;
							unsigned int b = ((lplvcd->clrText >>  0 & 255) * 2 + (lplvcd->clrTextBk >>  0 & 255)) / 3;

							rect.left += size.cx;
							SetTextColor(lplvcd->nmcd.hdc, (r << 16) | (g <<  8) | (b <<  0));
							DrawText(lplvcd->nmcd.hdc, szText, -1, &rect, DT_NOPREFIX | DT_SINGLELINE | DT_LEFT | DT_VCENTER);
						}
					}

					DeleteObject(hBackBrush);

					SetWindowLong(hSelDlg, DWL_MSGRESULT, CDRF_SKIPDEFAULT);
					return 1;
				}

				default: {
					SetWindowLong(hSelDlg, DWL_MSGRESULT, CDRF_DODEFAULT);
					return 1;
				}
			}
		}

		if (pNmHdr->code == TVN_ITEMEXPANDING && !TreeBuilding && LOWORD(wParam) == IDC_TREE1) {
			SendMessage(hSelList, TVM_SELECTITEM, TVGN_CARET, (LPARAM)((LPNMTREEVIEW)lParam)->itemNew.hItem);
			return FALSE;
		}

		if (pNmHdr->code == TVN_SELCHANGED && !TreeBuilding && LOWORD(wParam) == IDC_TREE1) {
			HTREEITEM hSelectHandle = (HTREEITEM)SendMessage(hSelList, TVM_GETNEXTITEM, TVGN_CARET, ~0U);

			// Search through nBurnDrv[] for the nBurnDrvNo according to the returned hSelectHandle
			for (unsigned int i = 0; i < nTmpDrvCount; i++) {
				if (hSelectHandle == nBurnDrv[i].hTreeHandle)
				{
					nBurnDrvSelect	= nBurnDrv[i].nBurnDrvNo;
					nDialogSelect	= nBurnDrvSelect;
					bDrvSelected	= true;
					UpdatePreview(true, hSelDlg, szAppPreviewsPath);
					break;
				}
			}

			// Get the text from the drivers via BurnDrvGetText()
			for (int i = 0; i < 6; i++) {
				int nGetTextFlags = nLoadMenuShowX & ASCIIONLY ? DRV_ASCIIONLY : 0;
				TCHAR szItemText[256];
				szItemText[0] = _T('\0');

				switch (i) {
					case 0: {
						bool bBracket = false;

						_stprintf(szItemText, _T("%s"), BurnDrvGetText(DRV_NAME));
						if ((BurnDrvGetFlags() & BDF_CLONE) && BurnDrvGetTextA(DRV_PARENT)) {
							int nOldDrvSelect = nBurnDrvSelect;
							TCHAR* pszName = BurnDrvGetText(DRV_PARENT);

							_stprintf(szItemText + _tcslen(szItemText), _T(" (clone of %s"), BurnDrvGetText(DRV_PARENT));

							for (nBurnDrvSelect = 0; nBurnDrvSelect < nBurnDrvCount; nBurnDrvSelect++) {
								if (!_tcsicmp(pszName, BurnDrvGetText(DRV_NAME))) {
									break;
								}
							}
							if (nBurnDrvSelect < nBurnDrvCount) {
								if (BurnDrvGetText(DRV_PARENT)) {
									_stprintf(szItemText + _tcslen(szItemText), _T(", uses ROMs from %s"), BurnDrvGetText(DRV_PARENT));
								}
							}
							nBurnDrvSelect = nOldDrvSelect;
							bBracket = true;
						} else {
							if (BurnDrvGetTextA(DRV_PARENT)) {
								_stprintf(szItemText + _tcslen(szItemText), _T("%suses ROMs from %s"), bBracket ? _T(", ") : _T(" ("), BurnDrvGetText(DRV_PARENT));
								bBracket = true;
							}
						}
						if (bBracket) {
							_stprintf(szItemText + _tcslen(szItemText), _T(")"));
						}
						SendMessage(hInfoText[i], WM_SETTEXT, (WPARAM)0, (LPARAM)szItemText);
						EnableWindow(hInfoLabel[i], TRUE);
						break;
					}
					case 1: {
						bool bUseInfo = false;

						if (BurnDrvGetFlags() & BDF_PROTOTYPE) {
							_stprintf(szItemText + _tcslen(szItemText), _T("prototype"));
							bUseInfo = true;
						}
						if (BurnDrvGetFlags() & BDF_BOOTLEG) {
							_stprintf(szItemText + _tcslen(szItemText), _T("%sbootleg"), bUseInfo ? _T(", ") : _T(""));
							bUseInfo = true;
						}
						if (BurnDrvGetFlags() & BDF_HACK) {
							_stprintf(szItemText + _tcslen(szItemText), _T("%shack"), bUseInfo ? _T(", ") : _T(""));
							bUseInfo = true;
						}
						if (BurnDrvGetFlags() & BDF_HOMEBREW) {
							_stprintf(szItemText + _tcslen(szItemText), _T("%shomebrew"), bUseInfo ? _T(", ") : _T(""));
							bUseInfo = true;
						}
						if (BurnDrvGetFlags() & BDF_DEMO) {
							_stprintf(szItemText + _tcslen(szItemText), _T("%sdemo"), bUseInfo ? _T(", ") : _T(""));
							bUseInfo = true;
						}
						_stprintf(szItemText + _tcslen(szItemText), _T("%s%i player%s"), bUseInfo ? _T(", ") : _T(""), BurnDrvGetMaxPlayers(), (BurnDrvGetMaxPlayers() != 1) ? _T("s max") : _T(""));
						bUseInfo = true;
						if (BurnDrvGetText(DRV_BOARDROM)) {
							_stprintf(szItemText + _tcslen(szItemText), _T("%suses board-ROMs from %s"), bUseInfo ? _T(", ") : _T(""), BurnDrvGetText(DRV_BOARDROM));
							SendMessage(hInfoText[i], WM_SETTEXT, (WPARAM)0, (LPARAM)szItemText);
							EnableWindow(hInfoLabel[i], TRUE);
							bUseInfo = true;
						}
						SendMessage(hInfoText[i], WM_SETTEXT, (WPARAM)0, (LPARAM)szItemText);
						EnableWindow(hInfoLabel[i], bUseInfo);
						break;
					}
					case 2: {
						_stprintf(szItemText, _T("%s (%s, %s hardware)"), BurnDrvGetTextA(DRV_MANUFACTURER) ? BurnDrvGetText(nGetTextFlags | DRV_MANUFACTURER) : _T("unknown"), BurnDrvGetText(DRV_DATE), ((BurnDrvGetHardwareCode() & HARDWARE_SNK_MVSCARTRIDGE) == HARDWARE_SNK_MVSCARTRIDGE) ? _T("Neo Geo MVS Cartidge") : BurnDrvGetText(nGetTextFlags | DRV_SYSTEM));
						SendMessage(hInfoText[i], WM_SETTEXT, (WPARAM)0, (LPARAM)szItemText);
						EnableWindow(hInfoLabel[i], TRUE);
						break;
					}
					case 3: {
						TCHAR szText[1024] = _T("");
						TCHAR* pszPosition = szText;
						TCHAR* pszName = BurnDrvGetText(nGetTextFlags | DRV_FULLNAME);

						pszPosition += _sntprintf(szText, 1024, pszName);

						pszName = BurnDrvGetText(nGetTextFlags | DRV_FULLNAME);
						while ((pszName = BurnDrvGetText(nGetTextFlags | DRV_NEXTNAME | DRV_FULLNAME)) != NULL) {
							if (pszPosition + _tcslen(pszName) - 1024 > szText) {
								break;
							}
							pszPosition += _stprintf(pszPosition, _T(SEPERATOR_2) _T("%s"), pszName);
						}
						SendMessage(hInfoText[i], WM_SETTEXT, (WPARAM)0, (LPARAM)szText);
						if (szText[0]) {
							EnableWindow(hInfoLabel[i], TRUE);
						} else {
							EnableWindow(hInfoLabel[i], FALSE);
						}
						break;
					}
					case 4: {
						_stprintf(szItemText, _T("%s"), BurnDrvGetTextA(DRV_COMMENT) ? BurnDrvGetText(nGetTextFlags | DRV_COMMENT) : _T(""));
						SendMessage(hInfoText[i], WM_SETTEXT, (WPARAM)0, (LPARAM)szItemText);
						EnableWindow(hInfoLabel[i], TRUE);
						break;
					}

					case 5: {
						_stprintf(szItemText, _T("%s"), DecorateGenreInfo());
						SendMessage(hInfoText[i], WM_SETTEXT, (WPARAM)0, (LPARAM)szItemText);
						EnableWindow(hInfoLabel[i], TRUE);
						break;
					}
				}
			}
		}
	}
	return 0;
}

int SelDialog(int nMVSCartsOnly, HWND hParentWND)
{
	_stprintf(szFavoritesDat, _T("config\\favorites.dat"));

	int nOldSelect = nBurnDrvSelect;

	if(bDrvOkay) {
		nOldDlgSelected = nBurnDrvSelect;
	}

	hParent = hParentWND;
	nShowMVSCartsOnly = nMVSCartsOnly;

	InitCommonControls();

	FBADialogBox(hAppInst, MAKEINTRESOURCE(IDD_SELNEW), hParent, DialogProc);

	if (!_tcscmp(BurnDrvGetText(DRV_NAME), _T("neogeo"))) {
		bMVSMultiSlot = true;
	} else {
		if(!nShowMVSCartsOnly) {
			bMVSMultiSlot = false;
		}
	}

	hSelDlg = NULL;
	hSelList = NULL;

	free(nBurnDrv);
	nBurnDrv = NULL;

	nBurnDrvSelect = nOldSelect;

	return nDialogSelect;
}

