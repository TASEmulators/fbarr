// Screen Window
#include "burner.h"
#include "tracklst.h"
#include "maphkeys.h"
#include "ramwatch.h"
#include <string>

#include "../../utils/xstring.h"


using namespace std;

#define		HORIZONTAL_ORIENTED_RES		0
#define		VERTICAL_ORIENTED_RES		1

extern HWND hJukeboxDlg;
extern void UpdateLuaConsole(const char* fname);

int nActiveGame;

bool bLoading = 0;

int nSkipNvram = 0;

int OnMenuSelect(HWND, HMENU, int, HMENU, UINT);
int OnInitMenuPopup(HWND, HMENU, UINT, BOOL);
int OnUnInitMenuPopup(HWND, HMENU, UINT, BOOL);
void DisplayPopupMenu(int nMenu);

RECT SystemWorkArea = { 0, 0, 640, 480 };				// Work area on the desktop
int nWindowPosX = -1, nWindowPosY = -1;					// Window position

int bAutoPause = 1;

bool bMenuEnabled = true;

int nSavestateSlot = 1;

static TCHAR* szClass = _T("FB Alpha");					// Window class name
HWND hScrnWnd = NULL;									// Handle to the screen window
HWND hRebar = NULL;										// Handle to the Rebar control containing the menu

static bool bMaximised;
static int nPrevWidth, nPrevHeight;

#define ID_NETCHAT 999
HWND hwndChat = NULL;
WNDPROC pOldWndProc = NULL;

bool bRescanRoms = false;

static bool bDrag = false;
static int nDragX, nDragY;
static int nOldWindowX, nOldWindowY;
static int nLeftButtonX, nLeftButtonY;

static int OnCreate(HWND, LPCREATESTRUCT);
static void OnActivateApp(HWND, BOOL, DWORD);
static void OnPaint(HWND);
static void OnClose(HWND);
static void OnDestroy(HWND);
static void OnCommand(HWND, int, HWND, UINT);
static int OnSysCommand(HWND, UINT, int, int);
static void OnSize(HWND, UINT, int, int);
static void OnEnterSizeMove(HWND);
static void OnExitSizeMove(HWND);
static void OnEnterIdle(HWND, UINT, HWND);
static void OnEnterMenuLoop(HWND, BOOL);
static void OnExitMenuLoop(HWND, BOOL);
static int OnMouseMove(HWND, int, int, UINT);
static int OnLButtonUp(HWND, int, int, UINT);
static int OnLButtonDown(HWND, BOOL, int, int, UINT);
static int OnLButtonDblClk(HWND, BOOL, int, int, UINT);
static int OnRButtonUp(HWND, int, int, UINT);
static int OnRButtonDown(HWND, BOOL, int, int, UINT);

static int OnDisplayChange(HWND, UINT, UINT, UINT);

static int OnDropFiles(HWND, HDROP);

int OnNotify(HWND, int, NMHDR* lpnmhdr);

UINT32 mousex,mousey;

bool UseDialogs()
{
	if (/*!bDrvOkay ||*/ !nVidFullscreen) {
		return true;
	}

	return false;
}

void SetPauseMode(bool bPause)
{
	bRunPause = bPause;
	bAltPause = bPause;

	if (bPause) {
		AudBlankSound();
		if (UseDialogs()) {
			InputSetCooperativeLevel(false, bAlwaysProcessKeyboardInput);
		}
	} else {
		GameInpCheckMouse();
	}
}

static char* CreateKailleraList()
{
	unsigned int nOldDrvSelect = nBurnDrvSelect;
	int nSize = 256 * 1024;
	char* pList = (char*)malloc(nSize);
	char* pName = pList;

	if (pList == NULL) {
		return NULL;
	}

	// Add chat option to the gamelist
	pName += sprintf(pName, "* Chat only");
	pName++;

	if (avOk) {
		// Add all the driver names to the list
		for (nBurnDrvSelect = 0; nBurnDrvSelect < nBurnDrvCount; nBurnDrvSelect++) {

			if(BurnDrvGetFlags() & BDF_GAME_WORKING && gameAv[nBurnDrvSelect]) {
				char* szDecoratedName = DecorateGameName(nBurnDrvSelect);

				if (pName + strlen(szDecoratedName) >= pList + nSize) {
					char* pNewList;
					nSize <<= 1;
					pNewList = (char*)realloc(pList, nSize);
					if (pNewList == NULL) {
						return NULL;
					}
					pName -= (unsigned int)pList;
					pList = pNewList;
					pName += (unsigned int)pList;
				}
				pName += sprintf(pName, "%s", szDecoratedName);
				pName++;
			}
		}
	}

	*pName = '\0';
	pName++;

	nBurnDrvSelect = nOldDrvSelect;

	return pList;
}

void DeActivateChat()
{
	bEditActive = false;
	DestroyWindow(hwndChat);
	hwndChat = NULL;
}

int ActivateChat()
{
	RECT rect;
	GetClientRect(hScrnWnd, &rect);

	DeActivateChat();

	// Create an invisible edit control
	hwndChat = CreateWindow(
		_T("EDIT"), NULL,
		WS_CHILD | ES_LEFT,
		0, rect.bottom - 32, rect.right, 32,
		hScrnWnd, (HMENU)ID_NETCHAT, (HINSTANCE)GetWindowLong(hScrnWnd, GWL_HINSTANCE), NULL);                // pointer not needed

	EditText[0] = 0;
	bEditTextChanged = true;
	bEditActive = true;

	SendMessage(hwndChat, EM_LIMITTEXT, MAX_CHAT_SIZE, 0);			// Limit the amount of text

	SetFocus(hwndChat);

	return 0;
}

static int WINAPI gameCallback(char* game, int player, int numplayers)
{
	bool bFound = false;
	HWND hActive;

	for (nBurnDrvSelect = 0; nBurnDrvSelect < nBurnDrvCount; nBurnDrvSelect++) {

		char* szDecoratedName = DecorateGameName(nBurnDrvSelect);

		if (!strcmp(szDecoratedName, game)) {
			bFound = true;
			break;
		}
	}

	if (!bFound) {
//		kailleraEndGame();
		Kaillera_End_Game();
		return 1;
	}

	kNetGame = 1;
	hActive = GetActiveWindow();

	bCheatsAllowed = false;								// Disable cheats during netplay
	AudSoundStop();										// Stop while we load roms
	DrvInit(nBurnDrvSelect, false);						// Init the game driver
	ScrnInit();
	AudSoundPlay();										// Restart sound
	VidInit();
	SetFocus(hScrnWnd);

//	dprintf(_T(" ** OSD startnet text sent.\n"));

	TCHAR szTemp1[256];
	TCHAR szTemp2[256];
	VidSAddChatMsg(FBALoadStringEx(hAppInst, IDS_NETPLAY_START, true), 0xFFFFFF, BurnDrvGetText(DRV_FULLNAME), 0xFFBFBF);
	_sntprintf(szTemp1, 256, FBALoadStringEx(hAppInst, IDS_NETPLAY_START_YOU, true), player);
	_sntprintf(szTemp2, 256, FBALoadStringEx(hAppInst, IDS_NETPLAY_START_TOTAL, true), numplayers);
	VidSAddChatMsg(szTemp1, 0xFFFFFF, szTemp2, 0xFFBFBF);

	RunMessageLoop();

	DrvExit();
	if (kNetGame) {
		kNetGame = 0;
//		kailleraEndGame();
		Kaillera_End_Game();
	}
	DeActivateChat();

	bCheatsAllowed = true;								// reenable cheats netplay has ended

	SetFocus(hActive);
	return 0;
}

static void WINAPI kChatCallback(char* nick, char* text)
{
	TCHAR szTemp[128];
	_sntprintf(szTemp, 128, _T("%.32hs "), nick);
	VidSAddChatMsg(szTemp, 0xBFBFFF, ANSIToTCHAR(text, NULL, 0), 0x7F7FFF);
}

static void WINAPI kDropCallback(char *nick, int playernb)
{
	TCHAR szTemp[128];
	_sntprintf(szTemp, 128, FBALoadStringEx(hAppInst, IDS_NETPLAY_DROP, true), playernb, nick);
	VidSAddChatMsg(szTemp, 0xFFFFFF, NULL, 0);
}

static void DoNetGame()
{
	kailleraInfos ki;
	char tmpver[128];
	char* gameList;

	if(bDrvOkay) {
		DrvExit();
		ScrnTitle();
	}
	MenuEnableItems();

#ifdef _UNICODE
	_snprintf(tmpver, 128, APP_TITLE " v%.20ls", szAppBurnVer);
#else
	_snprintf(tmpver, 128, APP_TITLE " v%.20s", szAppBurnVer);
#endif

	gameList = CreateKailleraList();

	ki.appName = tmpver;
	ki.gameList = gameList;
	ki.gameCallback = &gameCallback;
	ki.chatReceivedCallback = &kChatCallback;
	ki.clientDroppedCallback = &kDropCallback;
	ki.moreInfosCallback = NULL;

	Kaillera_Set_Infos(&ki);
	//kailleraSetInfos(&ki);

	Kaillera_Select_Server_Dialog(NULL);
	//kailleraSelectServerDialog(NULL);

	free(gameList);
	
	End_Network();

	POST_INITIALISE_MESSAGE;
}

int CreateDatfileWindows(int nDatType, int bIncMegadrive)
{
	TCHAR szTitle[1024];
	TCHAR szFilter[1024];
	
	TCHAR szMegadriveString[25];
	_sntprintf(szMegadriveString, 25, _T(""));
	if (bIncMegadrive == 1) _sntprintf(szMegadriveString, 25, _T(", including Megadrive"));
	if (bIncMegadrive == 2) _sntprintf(szMegadriveString, 25, _T(", Megadrive only"));
	
	TCHAR szProgramString[25];	
	if (nDatType == 0) _sntprintf(szProgramString, 25, _T("ClrMame Pro old"));
	if (nDatType == 1) _sntprintf(szProgramString, 25, _T("RomCenter old"));
	if (nDatType == 2) _sntprintf(szProgramString, 25, _T("ClrMame Pro XML"));
	
	_sntprintf(szChoice, MAX_PATH, _T(APP_TITLE) _T(" v%.20s (%s%s).dat"), szAppBurnVer, szProgramString, szMegadriveString);
	_sntprintf(szTitle, 256, FBALoadStringEx(hAppInst, IDS_DAT_GENERATE, true), szProgramString);

	_stprintf(szFilter, FBALoadStringEx(hAppInst, IDS_DISK_ALL_DAT, true), _T(APP_TITLE));
	memcpy(szFilter + _tcslen(szFilter), _T(" (*.dat)\0*.dat\0\0"), 16 * sizeof(TCHAR));

	memset(&ofn, 0, sizeof(ofn));
	ofn.lStructSize = sizeof(ofn);
	ofn.hwndOwner = hScrnWnd;
	ofn.lpstrFilter = szFilter;
	ofn.lpstrFile = szChoice;
	ofn.nMaxFile = sizeof(szChoice) / sizeof(TCHAR);
	ofn.lpstrInitialDir = _T(".");
	ofn.Flags = OFN_NOCHANGEDIR | OFN_HIDEREADONLY;
	ofn.lpstrDefExt = _T("dat");
	ofn.lpstrTitle = szTitle;
	ofn.Flags |= OFN_OVERWRITEPROMPT;

	if (GetSaveFileName(&ofn) == 0)
		return -1;

	return create_datfile(szChoice, nDatType, bIncMegadrive);
}

// Returns true if a VidInit is needed when the window is resized
static bool VidInitNeeded()
{
	// D3D blitter needs to re-initialise only when auto-size RGB effects are enabled
	if (nVidSelect == 1 && (nVidBlitterOpt[nVidSelect] & 0x00030000) == 0x00030000) {
		return true;
	}
	if (nVidSelect == 3) {
		return true;
	}

	return false;
}

// Refresh the contents of the window when re-sizing it
static void RefreshWindow(bool bInitialise)
{
	if (nVidFullscreen) {
		return;
	}

	if (bInitialise && VidInitNeeded()) {
		VidInit();
		if (bVidOkay && (bRunPause || !bDrvOkay)) {
			VidRedraw();
			VidPaint(0);
		}
	}
}

static LRESULT CALLBACK ScrnProc(HWND hWnd, UINT Msg, WPARAM wParam, LPARAM lParam)
{
	switch (Msg) {
		HANDLE_MSG(hWnd, WM_CREATE,			OnCreate);
		HANDLE_MSG(hWnd, WM_ACTIVATEAPP,	OnActivateApp);
		HANDLE_MSGB(hWnd,WM_PAINT,			OnPaint);
		HANDLE_MSG(hWnd, WM_CLOSE,			OnClose);
		HANDLE_MSG(hWnd, WM_DESTROY,		OnDestroy);
		HANDLE_MSG(hWnd, WM_COMMAND,		OnCommand);

		// We can't use the macro from windowsx.h macro for this one
		case WM_SYSCOMMAND: {
			if (OnSysCommand(hWnd,(UINT)wParam,(int)(short)LOWORD(lParam),(int)(short)HIWORD(lParam))) {
				return 0;
			}
			break;
		}

		HANDLE_MSG(hWnd, WM_SIZE,			OnSize);
		HANDLE_MSG(hWnd, WM_ENTERSIZEMOVE,	OnEnterSizeMove);
		HANDLE_MSG(hWnd, WM_EXITSIZEMOVE,	OnExitSizeMove);
		HANDLE_MSG(hWnd, WM_ENTERIDLE,		OnEnterIdle);
		HANDLE_MSG(hWnd, WM_MOUSEMOVE,		OnMouseMove);
		HANDLE_MSG(hWnd, WM_LBUTTONUP,		OnLButtonUp);
		HANDLE_MSG(hWnd, WM_LBUTTONDOWN,	OnLButtonDown);
		HANDLE_MSG(hWnd, WM_LBUTTONDBLCLK,	OnLButtonDblClk);
		HANDLE_MSG(hWnd, WM_RBUTTONUP,		OnRButtonUp);
		HANDLE_MSG(hWnd, WM_RBUTTONDBLCLK,	OnRButtonDown);
		HANDLE_MSG(hWnd, WM_RBUTTONDOWN,	OnRButtonDown);

		HANDLE_MSG(hWnd, WM_NOTIFY,			OnNotify);
		HANDLE_MSG(hWnd, WM_MENUSELECT,		OnMenuSelect);
		HANDLE_MSG(hWnd, WM_ENTERMENULOOP,	OnEnterMenuLoop);
		HANDLE_MSGB(hWnd,WM_EXITMENULOOP,	OnExitMenuLoop);
		HANDLE_MSGB(hWnd,WM_INITMENUPOPUP,	OnInitMenuPopup);
		HANDLE_MSG(hWnd, WM_UNINITMENUPOPUP,OnUnInitMenuPopup);

		HANDLE_MSG(hWnd, WM_DISPLAYCHANGE,	OnDisplayChange);

		HANDLE_MSG(hWnd, WM_DROPFILES,		OnDropFiles);
	}

	return DefWindowProc(hWnd, Msg, wParam, lParam);
}

void SimpleReinitScrn(const bool& reinitVid)
{
	ScrnSize();

	// need for dx9 blitter
	if (reinitVid || VidInitNeeded()) {
		VidReInitialise();
	}
}

static int OnDropFiles(HWND, HDROP hdrop)
{
	UINT len;
	char *ftmp;

	len=DragQueryFileA(hdrop,0,0,0)+1; 
	if((ftmp=(char*)malloc(len))) 
	{
		DragQueryFileA(hdrop,0,ftmp,len); 
		string fileDropped = ftmp;
		wstring fileDroppedW = mbstowcs(fileDropped);
		
		//adelikat:  Drag and Drop only checks file extension, the internal functions are responsible for file error checking
		
		//-------------------------------------------------------
		//Check if Movie file
		//-------------------------------------------------------
		if (!(fileDropped.find(".fbm") == string::npos) && (fileDropped.find(".fbm") == fileDropped.length()-4))	 //ROM is already loaded and .fbm in filename
		{
			
			//if (!GameInfo)				//If no game is loaded, load the Open Game dialog
			//	LoadNewGamey(hWnd, 0);
			//if (GameInfo && !(fileDropped.find(".fbm") == string::npos)) { //.fbm is at the end of the filename so that must be the extension		
			
			StartReplay(fileDroppedW.c_str());		 //We are convinced it is a movie file, attempt to load it
			//}
		}
		//-------------------------------------------------------
		//Check if Lua file
		//-------------------------------------------------------
		else if (!(fileDropped.find(".lua") == string::npos) && (fileDropped.find(".lua") == fileDropped.length()-4))	
		{
			FBA_LoadLuaCode(ftmp);
			UpdateLuaConsole(fileDropped.c_str());
		}
		//-------------------------------------------------------
		//If not a movie, Load it as a ROM file
		//-------------------------------------------------------
		else
		{
			//ALoad(ftmp);
			//free(ftmp);
		}			
	}

	return 0;
}

static int OnDisplayChange(HWND, UINT, UINT, UINT)
{
	if (nVidFullscreen == 0) {
		POST_INITIALISE_MESSAGE;
	}

	return 0;
}

/******************************************************************************/
/*	Fixed right click mouse events, now they work properly without interfering 
	with other applications in the background [CaptainCPS-X]				  */
//----------------------------------------------------------------------------//
bool bRDblClick = false;

static int OnRButtonDown(HWND hwnd, BOOL bDouble, int, int, UINT)
{
	if (hwnd != hScrnWnd) return 1;

	// "double-click" event
	if (bDouble) 
	{
		// game running
		if (bDrvOkay) {
			
			// toggle fullscreen
			nVidFullscreen = !nVidFullscreen;

			// Right double-click at fullcreen happened, turn this flag 'true' so 
			// when right double-click ends (OnRButtonUp) it doesn't do anything else.  
			bRDblClick = true;
			
			POST_INITIALISE_MESSAGE;
			return 0;
		}
	}

	return 1;
}

static int OnRButtonUp(HWND hwnd, int, int, UINT)
{
	if (hwnd != hScrnWnd) return 1;

	// If not fullscreen and this event is not related to 'toggle fullscreen' right double-click event
	if (!nVidFullscreen && !bRDblClick) {
		bMenuEnabled = !bMenuEnabled;
		POST_INITIALISE_MESSAGE;
		return 0;
	} else {
		bRDblClick = false; // 'toggle fullcreen' right double-click event ended, so now we can handle other 'OnRButtonUp' events in windowed mode
	}

	return 1;
}
/*************************************************************************/

static int OnLButtonDown(HWND hwnd, BOOL, int x, int y, UINT)
{
	if (hwnd == hScrnWnd && !nVidFullscreen && !bMenuEnabled) {
		RECT clientRect;

		GetWindowRect(hScrnWnd, &clientRect);

		nOldWindowX = clientRect.left;
		nOldWindowY = clientRect.top;

		nLeftButtonX = clientRect.left + x;
		nLeftButtonY = clientRect.top + y;

		bDrag = true;

		return 0;
	}

	return 1;
}

static int OnLButtonDblClk(HWND hwnd, BOOL, int, int, UINT)
{
	if (hwnd == hScrnWnd && bDrvOkay) {
		nVidFullscreen = !nVidFullscreen;
		POST_INITIALISE_MESSAGE;
		return 0;
	}

	return 1;
}

static int OnMouseMove(HWND hwnd, int x, int y, UINT keyIndicators)
{

	mousex=x;
	mousey=y;

	if (bDrag && hwnd == hScrnWnd && keyIndicators == MK_LBUTTON && !nVidFullscreen && !bMenuEnabled) {
		RECT clientRect;

		GetWindowRect(hScrnWnd, &clientRect);

		if ((nLeftButtonX - (clientRect.left + x)) < nDragX && (nLeftButtonX - (clientRect.left + x)) > -nDragX && (nLeftButtonY - (clientRect.top + y)) < nDragY && (nLeftButtonY - (clientRect.top + y)) > -nDragY) {
			SetWindowPos(hScrnWnd, NULL, nOldWindowX, nOldWindowY, 0, 0, SWP_NOREPOSITION | SWP_NOSIZE);
		} else {
			nWindowPosX = nOldWindowX - (nLeftButtonX - (clientRect.left + x));
			nWindowPosY = nOldWindowY - (nLeftButtonY - (clientRect.top + y));

			SetWindowPos(hScrnWnd, NULL, nWindowPosX, nWindowPosY, 0, 0, SWP_NOREPOSITION | SWP_NOSIZE);
		}

		return 0;
	}

	return 1;
}

static int OnLButtonUp(HWND hwnd, int x, int y, UINT)
{
	bDrag = false;

	if (nVidFullscreen) {

		if (hwnd != hScrnWnd) {
			return 1;
		}

		if (UseDialogs()) {
			RECT clientRect;
			GetWindowRect(hScrnWnd, &clientRect);

			TrackPopupMenuEx(hMenuPopup, TPM_LEFTALIGN | TPM_TOPALIGN, clientRect.left + x, clientRect.top + y, hScrnWnd, NULL);
			return 0;
		}
	} else {
		if (!bMenuEnabled) {
			RECT clientRect;
			GetWindowRect(hScrnWnd, &clientRect);

			if ((nLeftButtonX - (clientRect.left + x)) < nDragX && (nLeftButtonX - (clientRect.left + x)) > -nDragX && (nLeftButtonY - (clientRect.top + y)) < nDragY && (nLeftButtonY - (clientRect.top + y)) > -nDragY) {
				TrackPopupMenuEx(hMenuPopup, TPM_LEFTALIGN | TPM_TOPALIGN, clientRect.left + x, clientRect.top + y, hScrnWnd, NULL);
				return 0;
			}
		}
	}

	return 1;
}

static int OnCreate(HWND, LPCREATESTRUCT)	// HWND hwnd, LPCREATESTRUCT lpCreateStruct
{
	return 1;
}

static void OnActivateApp(HWND hwnd, BOOL fActivate, DWORD /* dwThreadId */)
{
//	if (!kNetGame && bAutoPause && !bAltPause && hInpdDlg == NULL && hInpCheatDlg == NULL && hInpDIPSWDlg == NULL) {
//		bRunPause = fActivate? 0 : 1;
//	}
	if (fActivate == false && hwnd == hScrnWnd) {
		EndMenu();
	}
	if (fActivate == false && bRunPause) {
		AudBlankSound();
	}

	if (fActivate) {
		if (hInpdDlg || hInpCheatDlg || hInpDIPSWDlg || hDbgDlg || hwndMemWatch || cheatSearchDlg || LuaConsoleHWnd) {
			InputSetCooperativeLevel(false, bAlwaysProcessKeyboardInput);
		} else {
			GameInpCheckMouse();
		}
	}
}

static void OnPaint(HWND hWnd)
{
	if (hWnd == hScrnWnd) {

		// paint and validate client area
		VidPaint(1);

		// draw menu
		if (!nVidFullscreen) {
			RedrawWindow(hRebar, NULL, NULL, RDW_FRAME | RDW_UPDATENOW | RDW_ALLCHILDREN);
		}
	}
}

static void OnClose(HWND)
{
    PostQuitMessage(0);					// Quit the program if the window is closed
}

static void OnDestroy(HWND)
{
    VidExit();							// Stop using video with the Window
    hScrnWnd = NULL;					// Make sure handle is not used again
}

void UpdatePreviousGameList()
{
	if (bJukeboxInUse) return;

	int nRecentIdenticalTo = -1;

	// check if this game is identical to any of the listed in the recent menu 
	for(int x = 0; x < SHOW_PREV_GAMES; x++) { 
		if(!_tcscmp(BurnDrvGetText(DRV_NAME), szPrevGames[x])) {
			nRecentIdenticalTo = x;
		}
	}

	// Declare temporary array
	TCHAR szTmp[SHOW_PREV_GAMES][32];

	// Backup info for later use
	for(int x = 0; x < SHOW_PREV_GAMES; x++) {
		_tcscpy(szTmp[x], szPrevGames[x]);
	}

	switch(nRecentIdenticalTo) 
	{
		case -1:
			// Normal rotation when recent game is not identical to any of the ones listed
			// - - -
			_tcscpy(szPrevGames[9], szPrevGames[8]);			// Recent 10 = 9
			_tcscpy(szPrevGames[8], szPrevGames[7]);			// Recent 9 = 8
			_tcscpy(szPrevGames[7], szPrevGames[6]);			// Recent 8 = 7
			_tcscpy(szPrevGames[6], szPrevGames[5]);			// Recent 7 = 6
			_tcscpy(szPrevGames[5], szPrevGames[4]);			// Recent 6 = 5
			_tcscpy(szPrevGames[4], szPrevGames[3]);			// Recent 5 = 4
			_tcscpy(szPrevGames[3], szPrevGames[2]);			// Recent 4 = 3
			_tcscpy(szPrevGames[2], szPrevGames[1]);			// Recent 3 = 2
			_tcscpy(szPrevGames[1], szPrevGames[0]);			// Recent 2 = 1
			_tcscpy(szPrevGames[0], BurnDrvGetText(DRV_NAME));	// Update most recent game played (Recent 1)
			break;
		case 0:	
			break;												// Nothing Change
		case 1:
			_tcscpy(szPrevGames[0], szTmp[1]);					// Update most recent game played (Recent 1 = 2)
			_tcscpy(szPrevGames[1], szTmp[0]);					// Recent 2 = 1
			break;
		case 2:
			_tcscpy(szPrevGames[0], szTmp[2]);					// Update most recent game played (Recent 1 = 3)
			_tcscpy(szPrevGames[1], szTmp[0]);					// Recent 2 = 1
			_tcscpy(szPrevGames[2], szTmp[1]);					// Recent 3 = 2
			break;
		case 3:
			_tcscpy(szPrevGames[0], szTmp[3]);					// Update most recent game played (Recent 1 = 4)
			_tcscpy(szPrevGames[1], szTmp[0]);					// Recent 2 = 1
			_tcscpy(szPrevGames[2], szTmp[1]);					// Recent 3 = 2
			_tcscpy(szPrevGames[3], szTmp[2]);					// Recent 4 = 3
			break;
		case 4:
			_tcscpy(szPrevGames[0], szTmp[4]);					// Update most recent game played (Recent 1 = 5)
			_tcscpy(szPrevGames[1], szTmp[0]);					// Recent 2 = 1
			_tcscpy(szPrevGames[2], szTmp[1]);					// Recent 3 = 2
			_tcscpy(szPrevGames[3], szTmp[2]);					// Recent 4 = 3
			_tcscpy(szPrevGames[4], szTmp[3]);					// Recent 5 = 4
			break;
		case 5:
			_tcscpy(szPrevGames[0], szTmp[5]);					// Update most recent game played (Recent 1 = 6)
			_tcscpy(szPrevGames[1], szTmp[0]);					// Recent 2 = 1
			_tcscpy(szPrevGames[2], szTmp[1]);					// Recent 3 = 2
			_tcscpy(szPrevGames[3], szTmp[2]);					// Recent 4 = 3
			_tcscpy(szPrevGames[4], szTmp[3]);					// Recent 5 = 4
			_tcscpy(szPrevGames[5], szTmp[4]);					// Recent 6 = 5
			break;
		case 6:
			_tcscpy(szPrevGames[0], szTmp[6]);					// Update most recent game played (Recent 1 = 7)
			_tcscpy(szPrevGames[1], szTmp[0]);					// Recent 2 = 1
			_tcscpy(szPrevGames[2], szTmp[1]);					// Recent 3 = 2
			_tcscpy(szPrevGames[3], szTmp[2]);					// Recent 4 = 3
			_tcscpy(szPrevGames[4], szTmp[3]);					// Recent 5 = 4
			_tcscpy(szPrevGames[5], szTmp[4]);					// Recent 6 = 5
			_tcscpy(szPrevGames[6], szTmp[5]);					// Recent 7 = 6
			break;
		case 7:
			_tcscpy(szPrevGames[0], szTmp[7]);					// Update most recent game played (Recent 1 = 8)
			_tcscpy(szPrevGames[1], szTmp[0]);					// Recent 2 = 1
			_tcscpy(szPrevGames[2], szTmp[1]);					// Recent 3 = 2
			_tcscpy(szPrevGames[3], szTmp[2]);					// Recent 4 = 3
			_tcscpy(szPrevGames[4], szTmp[3]);					// Recent 5 = 4
			_tcscpy(szPrevGames[5], szTmp[4]);					// Recent 6 = 5
			_tcscpy(szPrevGames[6], szTmp[5]);					// Recent 7 = 6
			_tcscpy(szPrevGames[7], szTmp[6]);					// Recent 8 = 7
			break;
		case 8:
			_tcscpy(szPrevGames[0], szTmp[8]);					// Update most recent game played (Recent 1 = 9)
			_tcscpy(szPrevGames[1], szTmp[0]);					// Recent 2 = 1
			_tcscpy(szPrevGames[2], szTmp[1]);					// Recent 3 = 2
			_tcscpy(szPrevGames[3], szTmp[2]);					// Recent 4 = 3
			_tcscpy(szPrevGames[4], szTmp[3]);					// Recent 5 = 4
			_tcscpy(szPrevGames[5], szTmp[4]);					// Recent 6 = 5
			_tcscpy(szPrevGames[6], szTmp[5]);					// Recent 7 = 6
			_tcscpy(szPrevGames[7], szTmp[6]);					// Recent 8 = 7
			_tcscpy(szPrevGames[8], szTmp[7]);					// Recent 9 = 8
			break;
		case 9:
			_tcscpy(szPrevGames[0], szTmp[9]);					// Update most recent game played (Recent 1 = 10)
			_tcscpy(szPrevGames[1], szTmp[0]);					// Recent 2 = 1
			_tcscpy(szPrevGames[2], szTmp[1]);					// Recent 3 = 2
			_tcscpy(szPrevGames[3], szTmp[2]);					// Recent 4 = 3
			_tcscpy(szPrevGames[4], szTmp[3]);					// Recent 5 = 4
			_tcscpy(szPrevGames[5], szTmp[4]);					// Recent 6 = 5
			_tcscpy(szPrevGames[6], szTmp[5]);					// Recent 7 = 6
			_tcscpy(szPrevGames[7], szTmp[6]);					// Recent 8 = 7
			_tcscpy(szPrevGames[8], szTmp[7]);					// Recent 9 = 8
			_tcscpy(szPrevGames[9], szTmp[8]);					// Recent 10 = 9
			break;
	}
}

// Compact driver loading module
int BurnLoadDriver(TCHAR *szDriverName)
{

	// This is needed in case NeoGeo slot loading is canceled
	if(bDrvOkay) {
		nActiveGame = nBurnDrvSelect;
	}

	for (unsigned int i = 0; i < nBurnDrvCount; i++)
	{
		nBurnDrvSelect = i;
		if (!_tcscmp(BurnDrvGetText(DRV_NAME), szDriverName)) {
			break;
		}
	}

	// If not in range, return error
	if(nBurnDrvSelect >= nBurnDrvCount) return 1;

	if (!_tcscmp(BurnDrvGetText(DRV_NAME), _T("neogeo"))) {
		bMVSMultiSlot = true;
	} else {
		bMVSMultiSlot = false;
	}

#if defined (INCLUDE_NEOGEO_MULTISLOT)
	//DrvExit();
	if (!bMVSMultiSlot) {
		DrvInit(nBurnDrvSelect, true);			// Init the game driver
	} else {
		if(!NeogeoSlotSelectCreate(hScrnWnd)) 
		{
			// [CANCEL button was pressed] get previous emulation state
			if(bDrvOkay) {
				nBurnDrvSelect = nActiveGame;
			}						
			GameInpCheckMouse();
			AudSoundPlay();					// Restart sound
			bLoading = 0;
			return 1;
		} else {
			// [OK button was pressed]
			// NEOGEO MVS SLOT STUFF GOES HERE
		}
	}
	MenuEnableItems();
	bAltPause = 0;
	AudSoundPlay();					// Restart sound
	bLoading = 0;
	if (!bMVSMultiSlot) {
		UpdatePreviousGameList();
		if (bVidAutoSwitchFull) {
			nVidFullscreen = 1;
			POST_INITIALISE_MESSAGE;
		}
	}
#else
	DrvExit();
	DrvInit(nBurnDrvSelect, true);      // Init the game driver
	MenuEnableItems();
	bAltPause = 0;
	AudSoundPlay();                  // Restart sound
	bLoading = 0;
	UpdatePreviousGameList();
	if (bVidAutoSwitchFull) {
		nVidFullscreen = 1;
		POST_INITIALISE_MESSAGE;
	}
#endif   
	POST_INITIALISE_MESSAGE;
   return 0;
}


static void OnCommand(HWND /*hDlg*/, int id, HWND /*hwndCtl*/, UINT codeNotify)
{
	if (bLoading) {
		return;
	}
	
	switch (id) {

		case MENU_MVS_LOAD:	{
			EndDialog(hJukeboxDlg, 0);
			BurnLoadDriver(_T("neogeo"));
			break;
		}

		case MENU_LOAD:
			HK_openGame(0);
			break;

		case MENU_TRACKLIST:
		{
			if (UseDialogs()) {
				if (bDrvOkay) TracklistDialog();
			}
			break;
		}
		
		case MENU_PREVIOUSGAMES1:
		case MENU_PREVIOUSGAMES2:
		case MENU_PREVIOUSGAMES3:
		case MENU_PREVIOUSGAMES4:
		case MENU_PREVIOUSGAMES5:
		case MENU_PREVIOUSGAMES6:
		case MENU_PREVIOUSGAMES7:
		case MENU_PREVIOUSGAMES8:
		case MENU_PREVIOUSGAMES9:
		case MENU_PREVIOUSGAMES10: {
			unsigned int j;
			
			bDoPatch = FALSE;
			PatchExit();
			
			int nOldDrvSelect = nBurnDrvSelect;
			EndDialog(hJukeboxDlg, 0);
			DrvExit();
			bLoading = 1;
			
			for (j = 0; j < nBurnDrvCount; j++) {
				nBurnDrvSelect = j;
				if (!_tcscmp(szPrevGames[id - MENU_PREVIOUSGAMES1], BurnDrvGetText(DRV_NAME))) {
					nBurnDrvSelect = nOldDrvSelect;
					nDialogSelect = j;
					SplashDestroy(1);
					StopReplay();
					
					DrvExit();
					DrvInit(j, true);	// Init the game driver
					if (AutoRWLoad)
					{
						HK_ramWatch(0);
					}
					MenuEnableItems();
					bAltPause = 0;
					AudSoundPlay();			// Restart sound
					bLoading = 0;
					UpdatePreviousGameList();
					if (bVidAutoSwitchFull) {
						nVidFullscreen = 1;
						POST_INITIALISE_MESSAGE;
					}
					break;
				}
			}
			
			break;
		}

		case MENU_STARTNET:
			if (Init_Network()) {
				MessageBox(hScrnWnd, FBALoadStringEx(hAppInst, IDS_ERR_NO_NETPLAYDLL, true), FBALoadStringEx(hAppInst, IDS_ERR_ERROR, true), MB_OK);
				break;
			}
			if (!kNetGame) {
				InputSetCooperativeLevel(false, bAlwaysProcessKeyboardInput);
				AudBlankSound();
				SplashDestroy(1);
				StopReplay();
				DrvExit();
				DoNetGame();
				MenuEnableItems();
				InputSetCooperativeLevel(false, bAlwaysProcessKeyboardInput);
			}
			break;

		case MENU_STARTREPLAY:
			HK_playRec(0);
			break;
		case MENU_STARTRECORD:
			HK_startRec(0);
			break;
		case MENU_STOPREPLAY:
			HK_stopRec(0);
			break;

		case ID_LUA_OPEN:
			HK_luaOpen(0);
			break;
		case ID_LUA_CLOSE_ALL:
			HK_luaCloseAll(0);
			break;
			
		case MENU_HOTKEYS:
			MHkeysCreate();
			break;
			
		case MENU_VIEWGAMEINFO:
			void HK_gameInfo(int);
			break;
			
		case MENU_QUIT:
			HK_exitGame(0);
			break;

		case MENU_EXIT:
			if (AskSave())
			{
				StopReplay();
				if (kNetGame) {
					kNetGame = 0;
	//				kailleraEndGame();
					Kaillera_End_Game();
					DeActivateChat();
				}
				PostQuitMessage(0);
				return;
				}
			break;

		case MENU_PAUSE:
			HK_pause(0);
			break;

		case MENU_INPUT:
			HK_configPad(0);
			break;

		case MENU_DIPSW:
			HK_setDips(0);
			break;

		case MENU_SETCPUCLOCK:
			AudBlankSound();
			CPUClockDialog();
			MenuEnableItems();
			GameInpCheckMouse();
			break;
		case MENU_RESETCPUCLOCK:
			nBurnCPUSpeedAdjust = 0x0100;
			MenuEnableItems();
			break;

		case MENU_MEMCARD_CREATE:
			if (bDrvOkay && UseDialogs() && !kNetGame && (BurnDrvGetHardwareCode() & HARDWARE_PUBLIC_MASK) == HARDWARE_SNK_NEOGEO) {
				InputSetCooperativeLevel(false, bAlwaysProcessKeyboardInput);
				AudBlankSound();
				MemCardEject();
				MemCardCreate();
				MemCardInsert();
				GameInpCheckMouse();
			}
			break;
		case MENU_MEMCARD_SELECT:
			if (bDrvOkay && UseDialogs() && !kNetGame && (BurnDrvGetHardwareCode() & HARDWARE_PUBLIC_MASK) == HARDWARE_SNK_NEOGEO) {
				InputSetCooperativeLevel(false, bAlwaysProcessKeyboardInput);
				AudBlankSound();
				MemCardEject();
				MemCardSelect();
				MemCardInsert();
				GameInpCheckMouse();
			}
			break;
		case MENU_MEMCARD_INSERT:
			if (!kNetGame && (BurnDrvGetHardwareCode() & HARDWARE_PUBLIC_MASK) == HARDWARE_SNK_NEOGEO) {
				MemCardInsert();
			}
			break;
		case MENU_MEMCARD_EJECT:
			if (!kNetGame && (BurnDrvGetHardwareCode() & HARDWARE_PUBLIC_MASK) == HARDWARE_SNK_NEOGEO) {
				MemCardEject();
			}
			break;

		case MENU_MEMCARD_TOGGLE:
			if (bDrvOkay && !kNetGame && (BurnDrvGetHardwareCode() & HARDWARE_PUBLIC_MASK) == HARDWARE_SNK_NEOGEO) {
				MemCardToggle();
			}
			break;

		case MENU_STATE_LOAD_DIALOG:
			HK_loadStateDialog(0);
			break;
		case MENU_STATE_SAVE_DIALOG:
			HK_saveStateDialog(0);
			return;
		case MENU_STATE_PREVSLOT:
			HK_prevState(0);
			break;
		case MENU_STATE_NEXTSLOT:
			HK_nextState(0);
			break;
		case MENU_STATE_LOAD_SLOT:
			HK_loadCurState(0);
			break;
		case MENU_STATE_SAVE_SLOT:
			HK_saveCurState(0);
			break;

		case MENU_ALLRAM:
			bDrvSaveAll = !bDrvSaveAll;
			break;

		case MENU_NOSTRETCH:
			bVidCorrectAspect = 0;
			bVidFullStretch = 0;
			POST_INITIALISE_MESSAGE;
			break;

		case MENU_STRETCH:
			bVidFullStretch = true;
			if (bVidFullStretch) {
				bVidCorrectAspect = 0;
			}
			POST_INITIALISE_MESSAGE;
			break;

		case MENU_ASPECT:
			bVidCorrectAspect = true;
			if (bVidCorrectAspect) {
				bVidFullStretch = 0;
			}
			POST_INITIALISE_MESSAGE;
			break;

		case MENU_TRIPLE:
			bVidTripleBuffer = !bVidTripleBuffer;
			break;

		case MENU_BLITTER_1:
			VidSelect(0);
			POST_INITIALISE_MESSAGE;
			break;
		case MENU_BLITTER_2:
			VidSelect(1);
			POST_INITIALISE_MESSAGE;
			break;
		case MENU_BLITTER_3:
			VidSelect(2);
			POST_INITIALISE_MESSAGE;
			break;
		case MENU_BLITTER_4:
			VidSelect(3);
			POST_INITIALISE_MESSAGE;
			break;
#if 0
		case MENU_BLITTER_5:
			VidSelect(4);
			POST_INITIALISE_MESSAGE;
			break;
		case MENU_BLITTER_6:
			VidSelect(5);
			POST_INITIALISE_MESSAGE;
			break;
		case MENU_BLITTER_7:
			VidSelect(6);
			POST_INITIALISE_MESSAGE;
			break;
		case MENU_BLITTER_8:
			VidSelect(7);
			POST_INITIALISE_MESSAGE;
			break;
#endif

		case MENU_RES_ARCADE:
			bVidArcaderesHor = !bVidArcaderesHor;
			nScreenSizeHor = 0;
			if ((bDrvOkay) && !(BurnDrvGetFlags() & BDF_ORIENTATION_VERTICAL)) {
				nScreenSize = nScreenSizeHor;
				bVidArcaderes = bVidArcaderesHor;				
			}
			break;

		case MENU_SINGLESIZESCREEN:
			nScreenSizeHor = 1;
			bVidArcaderesHor = false;
			if ((bDrvOkay) && !(BurnDrvGetFlags() & BDF_ORIENTATION_VERTICAL)) {
				nScreenSize = nScreenSizeHor;
				bVidArcaderes = bVidArcaderesHor;				
			}
			break;
		case MENU_DOUBLESIZESCREEN:
			nScreenSizeHor = 2;
			bVidArcaderesHor = false;
			if ((bDrvOkay) && !(BurnDrvGetFlags() & BDF_ORIENTATION_VERTICAL)) {
				nScreenSize = nScreenSizeHor;
				bVidArcaderes = bVidArcaderesHor;				
			}
			break;
		case MENU_TRIPLESIZESCREEN:
			nScreenSizeHor = 3;
			bVidArcaderesHor = false;
			if ((bDrvOkay) && !(BurnDrvGetFlags() & BDF_ORIENTATION_VERTICAL)) {
				nScreenSize = nScreenSizeHor;
				bVidArcaderes = bVidArcaderesHor;				
			}
			break;
		case MENU_QUADSIZESCREEN:
			nScreenSizeHor = 4;
			bVidArcaderesHor = false;
			if ((bDrvOkay) && !(BurnDrvGetFlags() & BDF_ORIENTATION_VERTICAL)) {
				nScreenSize = nScreenSizeHor;
				bVidArcaderes = bVidArcaderesHor;				
			}
			break;

		case MENU_RES_1:
			nVidHorWidth = VidPreset[0].nWidth;
			nVidHorHeight = VidPreset[0].nHeight;
			bVidArcaderesHor = false;
			nScreenSizeHor = 0;
			if ((bDrvOkay) && !(BurnDrvGetFlags() & BDF_ORIENTATION_VERTICAL)) {
				nScreenSize = nScreenSizeHor;
				bVidArcaderes = bVidArcaderesHor;
				nVidWidth	= nVidHorWidth;
				nVidHeight	= nVidHorHeight;			
			}
			break;
		case MENU_RES_2:
			nVidHorWidth = VidPreset[1].nWidth;
			nVidHorHeight = VidPreset[1].nHeight;
			bVidArcaderesHor = false;
			nScreenSizeHor = 0;
			if ((bDrvOkay) && !(BurnDrvGetFlags() & BDF_ORIENTATION_VERTICAL)) {
				nScreenSize = nScreenSizeHor;
				bVidArcaderes = bVidArcaderesHor;
				nVidWidth	= nVidHorWidth;
				nVidHeight	= nVidHorHeight;			
			}
			break;
		case MENU_RES_3:
			nVidHorWidth = VidPreset[2].nWidth;
			nVidHorHeight = VidPreset[2].nHeight;
			bVidArcaderesHor = false;
			nScreenSizeHor = 0;
			if ((bDrvOkay) && !(BurnDrvGetFlags() & BDF_ORIENTATION_VERTICAL)) {
				nScreenSize = nScreenSizeHor;
				bVidArcaderes = bVidArcaderesHor;
				nVidWidth	= nVidHorWidth;
				nVidHeight	= nVidHorHeight;			
			}
			break;
		case MENU_RES_4:
			nVidHorWidth = VidPreset[3].nWidth;
			nVidHorHeight = VidPreset[3].nHeight;
			bVidArcaderesHor = false;
			nScreenSizeHor = 0;
			if ((bDrvOkay) && !(BurnDrvGetFlags() & BDF_ORIENTATION_VERTICAL)) {
				nScreenSize = nScreenSizeHor;
				bVidArcaderes = bVidArcaderesHor;
				nVidWidth	= nVidHorWidth;
				nVidHeight	= nVidHorHeight;			
			}
			break;


		case MENU_RES_OTHER:
			bVidArcaderesHor = false;
			nScreenSizeHor = 0;
			if ((bDrvOkay) && !(BurnDrvGetFlags() & BDF_ORIENTATION_VERTICAL)) {
				nScreenSize = nScreenSizeHor;
				bVidArcaderes = bVidArcaderesHor;			
			}
			AudBlankSound();
			InputSetCooperativeLevel(false, bAlwaysProcessKeyboardInput);
			ResCreate(HORIZONTAL_ORIENTED_RES);
			GameInpCheckMouse();
			break;

		// Vertical 
		case MENU_RES_ARCADE_VERTICAL:
			bVidArcaderesVer = !bVidArcaderesVer;
			nScreenSizeVer = 0;
			if ((bDrvOkay) && (BurnDrvGetFlags() & BDF_ORIENTATION_VERTICAL)) {
				nScreenSize = nScreenSizeVer;
				bVidArcaderes = bVidArcaderesVer;		
			}
			break;

		case MENU_SINGLESIZESCREEN_VERTICAL:
			nScreenSizeVer = 1;
			bVidArcaderesVer = false;
			if ((bDrvOkay) && (BurnDrvGetFlags() & BDF_ORIENTATION_VERTICAL)) {
				nScreenSize = nScreenSizeVer;
				bVidArcaderes = bVidArcaderesVer;		
			}
			break;
		case MENU_DOUBLESIZESCREEN_VERTICAL:
			nScreenSizeVer = 2;
			bVidArcaderesVer = false;
			if ((bDrvOkay) && (BurnDrvGetFlags() & BDF_ORIENTATION_VERTICAL)) {
				nScreenSize = nScreenSizeVer;
				bVidArcaderes = bVidArcaderesVer;		
			}
			break;
		case MENU_TRIPLESIZESCREEN_VERTICAL:
			nScreenSizeVer = 3;
			bVidArcaderesVer = false;
			if ((bDrvOkay) && (BurnDrvGetFlags() & BDF_ORIENTATION_VERTICAL)) {
				nScreenSize = nScreenSizeVer;
				bVidArcaderes = bVidArcaderesVer;		
			}
			break;
		case MENU_QUADSIZESCREEN_VERTICAL:
			nScreenSizeVer = 4;
			bVidArcaderesVer = false;
			if ((bDrvOkay) && (BurnDrvGetFlags() & BDF_ORIENTATION_VERTICAL)) {
				nScreenSize = nScreenSizeVer;
				bVidArcaderes = bVidArcaderesVer;		
			}
			break;

		case MENU_RES_1_VERTICAL:
			nVidVerWidth = VidPresetVer[0].nWidth;
			nVidVerHeight = VidPresetVer[0].nHeight;
			bVidArcaderesVer = false;
			nScreenSizeVer = 0;
			if ((bDrvOkay) && (BurnDrvGetFlags() & BDF_ORIENTATION_VERTICAL)) {
				nScreenSize = nScreenSizeVer;
				bVidArcaderes = bVidArcaderesVer;
				nVidWidth	= nVidVerWidth;
				nVidHeight	= nVidVerHeight;	
			}
			break;
		case MENU_RES_2_VERTICAL:
			nVidVerWidth = VidPresetVer[1].nWidth;
			nVidVerHeight = VidPresetVer[1].nHeight;
			bVidArcaderesVer = false;
			nScreenSizeVer = 0;
			if ((bDrvOkay) && (BurnDrvGetFlags() & BDF_ORIENTATION_VERTICAL)) {
				nScreenSize = nScreenSizeVer;
				bVidArcaderes = bVidArcaderesVer;
				nVidWidth	= nVidVerWidth;
				nVidHeight	= nVidVerHeight;	
			}
			break;
		case MENU_RES_3_VERTICAL:
			nVidVerWidth = VidPresetVer[2].nWidth;
			nVidVerHeight = VidPresetVer[2].nHeight;
			bVidArcaderesVer = false;
			nScreenSizeVer = 0;
			if ((bDrvOkay) && (BurnDrvGetFlags() & BDF_ORIENTATION_VERTICAL)) {
				nScreenSize = nScreenSizeVer;
				bVidArcaderes = bVidArcaderesVer;
				nVidWidth	= nVidVerWidth;
				nVidHeight	= nVidVerHeight;	
			}
			break;
		case MENU_RES_4_VERTICAL:
			nVidVerWidth = VidPresetVer[3].nWidth;
			nVidVerHeight = VidPresetVer[3].nHeight;
			bVidArcaderesVer = false;
			nScreenSizeVer = 0;
			if ((bDrvOkay) && (BurnDrvGetFlags() & BDF_ORIENTATION_VERTICAL)) {
				nScreenSize = nScreenSizeVer;
				bVidArcaderes = bVidArcaderesVer;
				nVidWidth	= nVidVerWidth;
				nVidHeight	= nVidVerHeight;	
			}
			break;

		case MENU_RES_OTHER_VERTICAL:
			bVidArcaderesVer = false;
			nScreenSizeVer = 0;
			if ((bDrvOkay) && (BurnDrvGetFlags() & BDF_ORIENTATION_VERTICAL)) {
				nScreenSize = nScreenSizeVer;
				bVidArcaderes = bVidArcaderesVer;
			}
			AudBlankSound();
			InputSetCooperativeLevel(false, bAlwaysProcessKeyboardInput);
			ResCreate(VERTICAL_ORIENTED_RES);
			GameInpCheckMouse();
			break;

		case MENU_16:
			nVidDepth = 16;
			break;

		case MENU_24:
			nVidDepth = 24;
			break;

		case MENU_32:
			nVidDepth = 32;
			break;

		case MENU_GAMMA_DO:
			bDoGamma = !bDoGamma;
			if (bDrvOkay) {
				if (nVidSelect == 1) {
					VidInit();
				}
				SetBurnHighCol(nVidImageDepth);
				if (bRunPause) {
					VidRedraw();
				}
			}
			break;

		case MENU_GAMMA_DARKER:
			nGamma = 1.25;
			ComputeGammaLUT();
			bDoGamma = 1;
			if (bDrvOkay) {
				if (nVidSelect == 1) {
					VidInit();
				}
				SetBurnHighCol(nVidImageDepth);
				if (bRunPause) {
					VidRedraw();
				}
			}
			break;

		case MENU_GAMMA_LIGHTER:
			nGamma = 0.80;
			ComputeGammaLUT();
			bDoGamma = 1;
			if (bDrvOkay) {
				if (nVidSelect == 1) {
					VidInit();
				}
				SetBurnHighCol(nVidImageDepth);
				if (bRunPause) {
					VidRedraw();
				}
			}
			break;

		case MENU_GAMMA_OTHER: {
			if (UseDialogs()) {
				double nOldGamma = nGamma;
				bDoGamma = 1;
				if (bDrvOkay) {
					if (nVidSelect == 1) {
						VidInit();
					}
					SetBurnHighCol(nVidImageDepth);
				}
				InputSetCooperativeLevel(false, bAlwaysProcessKeyboardInput);
				AudBlankSound();
				GammaDialog();
				if (nGamma > 0.999 && nGamma < 1.001) {
					nGamma = nOldGamma;
					bDoGamma = 0;
					if (nVidSelect == 1) {
						VidInit();
					}
					SetBurnHighCol(nVidImageDepth);
				} else {
					bDoGamma = 1;
					ComputeGammaLUT();
				}
				if (bDrvOkay) {
					VidRecalcPal();
				}
				GameInpCheckMouse();
			}
			break;
		}

		case MENU_GAMMA_USE_HARDWARE:
			bVidUseHardwareGamma = 1;
			bHardwareGammaOnly = 0;
			if (bDrvOkay) {
				if (nVidSelect == 1) {
					VidInit();
				}
				SetBurnHighCol(nVidImageDepth);
				VidRecalcPal();
				if (bRunPause) {
					VidRedraw();
				}
			}
			break;
		case MENU_GAMMA_HARDWARE_ONLY:
			bVidUseHardwareGamma = 1;
			bHardwareGammaOnly = 1;
			if (bDrvOkay) {
				if (nVidSelect == 1) {
					VidInit();
				}
				SetBurnHighCol(nVidImageDepth);
				VidRecalcPal();
				if (bRunPause) {
					VidRedraw();
				}
			}
			break;
		case MENU_GAMMA_SOFTWARE_ONLY:
			bVidUseHardwareGamma = 0;
			bHardwareGammaOnly = 0;
			if (bDrvOkay) {
				if (nVidSelect == 1) {
					VidInit();
				}
				SetBurnHighCol(nVidImageDepth);
				VidRecalcPal();
				if (bRunPause) {
					VidRedraw();
				}
			}
			break;

		case MENU_FULL:
			HK_fullscreen(0);
			return;
		
		case MENU_AUTOSWITCHFULL:
			bVidAutoSwitchFull = !bVidAutoSwitchFull;
			break;

		case MENU_MEMAUTO:
			nVidTransferMethod = -1;
			POST_INITIALISE_MESSAGE;
			break;

		case MENU_VIDEOMEM:
			nVidTransferMethod = 0;
			POST_INITIALISE_MESSAGE;
			break;

		case MENU_SYSMEM:
			nVidTransferMethod = 1;
			POST_INITIALISE_MESSAGE;
			break;

		case MENU_AUTOSIZE:
			if (nWindowSize != 0) {
				nWindowSize = 0;
				POST_INITIALISE_MESSAGE;
			}
			break;
		case MENU_SINGLESIZEWINDOW:
			HK_windowSize(1);
			break;
		case MENU_DOUBLESIZEWINDOW:
			HK_windowSize(2);
			break;
		case MENU_TRIPLESIZEWINDOW:
			HK_windowSize(3);
			break;
		case MENU_QUADSIZEWINDOW:
			HK_windowSize(4);
			break;
		case MENU_MAXIMUMSIZEWINDOW:
			HK_windowSizeMax(0);
			break;
			
		case MENU_MONITORAUTOCHECK:
			bMonitorAutoCheck = !bMonitorAutoCheck;
			if (bMonitorAutoCheck) MonitorAutoCheck();
			POST_INITIALISE_MESSAGE;
			break;

		case MENU_ASPECTNORMAL:
			bMonitorAutoCheck = false; nVidScrnAspectX = 4; nVidScrnAspectY = 3;
			POST_INITIALISE_MESSAGE;
			break;
		case MENU_ASPECTLCD:
			bMonitorAutoCheck = false; nVidScrnAspectX = 5; nVidScrnAspectY = 4;
			POST_INITIALISE_MESSAGE;
			break;
		case MENU_ASPECTWIDE:
			bMonitorAutoCheck = false; nVidScrnAspectX = 16; nVidScrnAspectY = 9;
			POST_INITIALISE_MESSAGE;
			break;
		case MENU_ASPECTWIDELCD:
			bMonitorAutoCheck = false; nVidScrnAspectX = 16; nVidScrnAspectY = 10;
			POST_INITIALISE_MESSAGE;
			break;
		case MENU_MONITORMIRRORVERT:
			nVidRotationAdjust ^= 2;
			POST_INITIALISE_MESSAGE;
			break;

		case MENU_ROTATEVERTICAL:
			nVidRotationAdjust ^= 1;
			POST_INITIALISE_MESSAGE;
			break;

		case MENU_FORCE60HZ:
			bForce60Hz = !bForce60Hz;
			break;
			
		case MENU_VIDEOVSYNC:
			bVidVSync = !bVidVSync;
			break;

		case MENU_AUTOFRAMESKIP:
			bAlwaysDrawFrames = !bAlwaysDrawFrames;
			break;

		case MENU_BLITTERPREVIEW:
			bVidUsePlaceholder = !bVidUsePlaceholder;
			if (!bDrvOkay) {
				POST_INITIALISE_MESSAGE;
			}
			break;
			
		case MENU_AUD_PLUGIN_1:
			AudSelect(0);
			POST_INITIALISE_MESSAGE;
			break;
			
		case MENU_AUD_PLUGIN_2:
			AudSelect(1);
			POST_INITIALISE_MESSAGE;
			break;
		
		case MENU_DSOUND_NOSOUND:
			if (!bDrvOkay) {
				nAudSampleRate[0] = 0;
				POST_INITIALISE_MESSAGE;
			}
			break;
		case MENU_DSOUND_11025:
			if (!bDrvOkay) {
				nAudSampleRate[0] = 11025;
				POST_INITIALISE_MESSAGE;
			}
			break;
		case MENU_DSOUND_22050:
			if (!bDrvOkay) {
				nAudSampleRate[0] = 22050;
				POST_INITIALISE_MESSAGE;
			}
			break;
		case MENU_DSOUND_44100:
			if (!bDrvOkay) {
				nAudSampleRate[0] = 44100;
				POST_INITIALISE_MESSAGE;
			}
			break;
		case MENU_DSOUND_48000:
			if (!bDrvOkay) {
				nAudSampleRate[0] = 48000;
				POST_INITIALISE_MESSAGE;
			}
			break;
			
		case MENU_XAUDIO_NOSOUND:
			if (!bDrvOkay) {
				nAudSampleRate[1] = 0;
				POST_INITIALISE_MESSAGE;
			}
			break;
		case MENU_XAUDIO_11025:
			if (!bDrvOkay) {
				nAudSampleRate[1] = 11025;
				POST_INITIALISE_MESSAGE;
			}
			break;
		case MENU_XAUDIO_22050:
			if (!bDrvOkay) {
				nAudSampleRate[1] = 22050;
				POST_INITIALISE_MESSAGE;
			}
			break;
		case MENU_XAUDIO_44100:
			if (!bDrvOkay) {
				nAudSampleRate[1] = 44100;
				POST_INITIALISE_MESSAGE;
			}
			break;
		case MENU_XAUDIO_48000:
			if (!bDrvOkay) {
				nAudSampleRate[1] = 48000;
				POST_INITIALISE_MESSAGE;
			}
			break;

		case MENU_FRAMES:
			if (UseDialogs()) {
				if (!bDrvOkay) {
//					AudBlankSound();
					NumDialCreate(0);
					POST_INITIALISE_MESSAGE;
				}
			}
			break;

		case MENU_INTERPOLATE_0:
			nInterpolation = 0;
			break;
		case MENU_INTERPOLATE_1:
			nInterpolation = 1;
			break;
		case MENU_INTERPOLATE_3:
			nInterpolation = 3;
			break;

		case MENU_INTERPOLATE_FM_0:
			nFMInterpolation = 0;
			break;
		case MENU_INTERPOLATE_FM_1:
			nFMInterpolation = 1;
			break;
		case MENU_INTERPOLATE_FM_3:
			nFMInterpolation = 3;
			break;

		case MENU_DSOUND_BASS:
			nAudDSPModule[0] = !nAudDSPModule[0];
			break;
			
		case MENU_XAUDIO_BASS:
			nAudDSPModule[1] ^= 1;
			break;
			
		case MENU_XAUDIO_REVERB:
			nAudDSPModule[1] ^= 2;
			break;

		case MENU_WLOGSTART:
			AudBlankSound();
			WaveLogStart();
			break;

		case MENU_WLOGEND:
			AudBlankSound();
			WaveLogStop();
			break;

		case MENU_AUTOPAUSE:
			bAutoPause = !bAutoPause;
			break;

		case MENU_PROCESSINPUT:
			bAlwaysProcessKeyboardInput = !bAlwaysProcessKeyboardInput;
			break;

		case MENU_DISPLAYINDICATOR:
			nVidSDisplayStatus = !nVidSDisplayStatus;
//			VidRedraw();
			VidPaint(2);
			break;

		case MENU_MODELESS:
			bModelessMenu = !bModelessMenu;
			POST_INITIALISE_MESSAGE;
			break;
			
		case MENU_NOCHANGENUMLOCK:
			bNoChangeNumLock = !bNoChangeNumLock;
			break;
			
		case MENU_SAVEHISCORES:
			EnableHiscores = !EnableHiscores;
			break;
			
		case MENU_ROMDIRS:
			RomsDirCreate(hScrnWnd);
			break;
			
		case MENU_SUPPORTDIRS:
			SupportDirCreate();
			break;
			
		case MENU_DISABLETHEMES:
			nMenuUITheme = 0;
			POST_INITIALISE_MESSAGE;
			break;
			
		case MENU_DEFAULTTHEME:
			nMenuUITheme = 1;
			bModelessMenu = false;
			ImageMenu_SetStyle(nMenuUITheme - 1);
			POST_INITIALISE_MESSAGE;
			break;
			
		case MENU_GRAYTHEME:
			nMenuUITheme = 2;
			bModelessMenu = false;
			ImageMenu_SetStyle(nMenuUITheme - 1);
			POST_INITIALISE_MESSAGE;
			break;
			
		case MENU_OFFICETHEME:
			nMenuUITheme = 3;
			bModelessMenu = false;
			ImageMenu_SetStyle(nMenuUITheme - 1);
			POST_INITIALISE_MESSAGE;
			break;
			
		case MENU_OFFICE2003THEME:
			nMenuUITheme = 4;
			bModelessMenu = false;
			ImageMenu_SetStyle(nMenuUITheme - 1);
			POST_INITIALISE_MESSAGE;
			break;
		
		case MENU_OFFICE2007THEME:
			nMenuUITheme = 5;
			bModelessMenu = false;
			ImageMenu_SetStyle(nMenuUITheme - 1);
			POST_INITIALISE_MESSAGE;
			break;
			
		case MENU_VISSTUDIOEXTHEME:
			nMenuUITheme = 6;
			bModelessMenu = false;
			ImageMenu_SetStyle(nMenuUITheme - 1);
			POST_INITIALISE_MESSAGE;
			break;
			
		case MENU_SELECTPLACEHOLDER: 
			if (UseDialogs()) {
				SelectPlaceHolder();
				POST_INITIALISE_MESSAGE;
			}
			break;
			
		case MENU_DISABLEPLACEHOLDER:
			ResetPlaceHolder();
			POST_INITIALISE_MESSAGE;
			break;

		case MENU_LANGUAGE_SELECT:
			if (UseDialogs()) {
				FBALocaliseLoadTemplate();
				POST_INITIALISE_MESSAGE;
			}
			break;
		case MENU_LANGUAGE_EXPORT:
			if (UseDialogs()) {
				FBALocaliseCreateTemplate();
			}
			break;
		case MENU_LANGUAGE_RESET:
			szLocalisationTemplate[0] = _T('\0');
			FBALocaliseInit(szLocalisationTemplate);
			POST_INITIALISE_MESSAGE;
			break;
			
		case MENU_GAMELANG_SELECT:
			if (UseDialogs()) {
				SelectGameListLocalisationTemplate();
				POST_INITIALISE_MESSAGE;
			}
			break;
			
		case MENU_GAMELANG_EXPORT:
			if (UseDialogs()) {
				ExportGameListLocalisationTemplate();
			}
			break;
			
		case MENU_GAMELANG_RESET:
			szGamelistLocalisationTemplate[0] = _T('\0');
			POST_INITIALISE_MESSAGE;
			break;

		case MENU_ENABLEICONS:
			bEnableIcons = !bEnableIcons;
			if(!bEnableIcons && bIconsLoaded) {
				// unload icons
				UnloadDrvIcons();
				bIconsLoaded = 0;
			} 
			if(bEnableIcons && !bIconsLoaded) {
				// load icons
				LoadDrvIcons();
				bIconsLoaded = 1;
			}
			break;

		case MENU_ICONS_SIZE_16:
			nIconsSize = ICON_16x16;
			if(bEnableIcons && bIconsLoaded) {
				// unload icons
				UnloadDrvIcons();
				bIconsLoaded = 0;
				// load icons
				LoadDrvIcons();
				bIconsLoaded = 1;
			}
			if(bEnableIcons && !bIconsLoaded) {
				// load icons
				LoadDrvIcons();
				bIconsLoaded = 1;
			}
			break;

		case MENU_ICONS_SIZE_24:
			nIconsSize = ICON_24x24;
			if(bEnableIcons && bIconsLoaded) {
				// unload icons
				UnloadDrvIcons();
				bIconsLoaded = 0;
				// load icons
				LoadDrvIcons();
				bIconsLoaded = 1;
			}
			if(bEnableIcons && !bIconsLoaded) {
				// load icons
				LoadDrvIcons();
				bIconsLoaded = 1;
			}
			break;

		case MENU_ICONS_SIZE_32:
			nIconsSize = ICON_32x32;
			if(bEnableIcons && bIconsLoaded) {
				// unload icons
				UnloadDrvIcons();
				bIconsLoaded = 0;
				// load icons
				LoadDrvIcons();
				bIconsLoaded = 1;
			}
			if(bEnableIcons && !bIconsLoaded) {
				// load icons
				LoadDrvIcons();
				bIconsLoaded = 1;
			}
			break;

		case MENU_PRIORITY_REALTIME:
			nAppThreadPriority = THREAD_PRIORITY_TIME_CRITICAL;
			SetThreadPriority(GetCurrentThread(), nAppThreadPriority);
			break;
		case MENU_PRIORITY_HIGH:
			nAppThreadPriority = THREAD_PRIORITY_HIGHEST;
			SetThreadPriority(GetCurrentThread(), nAppThreadPriority);
			break;
		case MENU_PRIORITY_ABOVE_NORMAL:
			nAppThreadPriority = THREAD_PRIORITY_ABOVE_NORMAL;
			SetThreadPriority(GetCurrentThread(), nAppThreadPriority);
			break;
		case MENU_PRIORITY_NORMAL:
			nAppThreadPriority = THREAD_PRIORITY_NORMAL;
			SetThreadPriority(GetCurrentThread(), nAppThreadPriority);
			break;
		case MENU_PRIORITY_BELOW_NORMAL:
			nAppThreadPriority = THREAD_PRIORITY_BELOW_NORMAL;
			SetThreadPriority(GetCurrentThread(), nAppThreadPriority);
			break;
		case MENU_PRIORITY_LOW:
			nAppThreadPriority = THREAD_PRIORITY_LOWEST;
			SetThreadPriority(GetCurrentThread(), nAppThreadPriority);
			break;
			
		case MENU_SAVECROMS:
			bSaveCRoms = !bSaveCRoms;
			break;

		case MENU_CLRMAME_PRO:
			if (UseDialogs()) {
				CreateDatfileWindows(0, 0);
			}
			break;

		case MENU_ROMCENTER:
			if (UseDialogs()) {
				CreateDatfileWindows(1, 0);
			}
			break;
			
		case MENU_CLRMAME_PRO_XML:
			if (UseDialogs()) {
				CreateDatfileWindows(2, 0);
			}
			break;
		
		case MENU_CLRMAME_PRO_INC_MD:
			if (UseDialogs()) {
				CreateDatfileWindows(0, 1);
			}
			break;

		case MENU_ROMCENTER_INC_MD:
			if (UseDialogs()) {
				CreateDatfileWindows(1, 1);
			}
			break;
		
		case MENU_CLRMAME_PRO_XML_INC_MD:
			if (UseDialogs()) {
				CreateDatfileWindows(2, 1);
			}
			break;
			
		case MENU_CLRMAME_PRO_MD_ONLY:
			if (UseDialogs()) {
				CreateDatfileWindows(0, 2);
			}
			break;

		case MENU_ROMCENTER_MD_ONLY:
			if (UseDialogs()) {
				CreateDatfileWindows(1, 2);
			}
			break;
		
		case MENU_CLRMAME_PRO_XML_MD_ONLY:
			if (UseDialogs()) {
				CreateDatfileWindows(2, 2);
			}
			break;

		case MENU_ENABLECHEAT:
			HK_cheatEditor(0);
			break;

		case MENU_DEBUG:
			if (UseDialogs()) {
				InputSetCooperativeLevel(false, bAlwaysProcessKeyboardInput);
				DebugCreate();
			}
			break;

		case ID_RAM_WATCH:
			HK_ramWatch(0);
//			HK_ramWatchOld(0);
			break;

		case ID_RAM_SEARCH:
			HK_ramSearch(0);
//			HK_ramSearchOld(0);
			break;

		case MENU_PALETTEVIEWER: {
			AudBlankSound();
			InputSetCooperativeLevel(false, bAlwaysProcessKeyboardInput);
			PaletteViewerDialogCreate(hScrnWnd);
			break;
		}

		case MENU_ASSEMBLYCORE:
			bBurnUseASMCPUEmulation = !bBurnUseASMCPUEmulation;
			break;

		case MENU_SAVESNAP: {
			HK_screenShot(0);
			break;
		}

		case MENU_SNAPFACT:
			HK_shotFactory(0);
			break;

		case MENU_ASSOCIATE:
			RegisterExtensions(true);
			break;
        case MENU_DISASSOCIATE:
			RegisterExtensions(false);
			break;

		case MENU_SAVEGAMEINPUTNOW:
			ConfigGameSave(true);
			break;

		case MENU_SAVEGAMEINPUT:
			bSaveInputs = !bSaveInputs;
			break;

		case MENU_SAVESET:
			ConfigAppSave();
			break;

		case MENU_LOADSET:
			ConfigAppLoad();
			POST_INITIALISE_MESSAGE;
			break;

		case MENU_AVI_BEGIN:
			HK_startAvi(0);
			break;

		case MENU_AVI_END:
			HK_stopAvi(0);
			break;

		case MENU_ABOUT:
			if (UseDialogs()) {
				InputSetCooperativeLevel(false, bAlwaysProcessKeyboardInput);
				AudBlankSound();
				AboutCreate();
				GameInpCheckMouse();
			}
			break;
		case MENU_SYSINFO:
			if (UseDialogs()) {
				InputSetCooperativeLevel(false, bAlwaysProcessKeyboardInput);
				AudBlankSound();
				SystemInfoCreate();
				GameInpCheckMouse();
			}
			break;

		case MENU_CONTENTS: {
			if (!nVidFullscreen) {
				FILE* fp = _tfopen(_T("fba.chm"), _T("r"));
				if (fp) {
					fclose(fp);
					ShellExecute(NULL, _T("open"), _T("fba.chm"), NULL, NULL, SW_SHOWNORMAL);
				}
			}
			break;
		}
		
		case MENU_WHATSNEW: {
			if (!nVidFullscreen) {
				FILE* fp = _tfopen(_T("whatsnew.html"), _T("r"));
				if (fp) {
					fclose(fp);
					ShellExecute(NULL, _T("open"), _T("whatsnew.html"), NULL, NULL, SW_SHOWNORMAL);
				}
			}
			break;
		}

		case MENU_WWW_HOME:
			if (!nVidFullscreen) {
				ShellExecute(NULL, _T("open"), _T("http://www.barryharris.me.uk/"), NULL, NULL, SW_SHOWNORMAL);
			}
			break;

		case MENU_WWW_FORUM:
			if (!nVidFullscreen) {
				ShellExecute(NULL, _T("open"), _T("http://www.ojko.com/phpbb/viewforum.php?f=27"), NULL, NULL, SW_SHOWNORMAL);
			}
			break;
			
		case MENU_WWW_NSFORUM:
			if (!nVidFullscreen) {
				ShellExecute(NULL, _T("open"), _T("http://neosource.1emu.net/forums/"), NULL, NULL, SW_SHOWNORMAL);
			}
			break;

//		default:
//			printf("  * Command %i sent.\n");

	}

	switch (nVidSelect) {
		case 0: {
			switch (id) {
				// Options for the Default DirectDraw blitter
				case MENU_NORMAL:
					bVidScanlines = 0;
					POST_INITIALISE_MESSAGE;
					break;
				case MENU_SCAN:
					bVidScanlines = 1;
					bVidScanHalf = 0;
					POST_INITIALISE_MESSAGE;
					break;
				case MENU_SCAN50:
					bVidScanlines = 1;
					bVidScanHalf = 1;
					POST_INITIALISE_MESSAGE;
					break;

				case MENU_ROTSCAN:
					bVidScanRotate = !bVidScanRotate;
					POST_INITIALISE_MESSAGE;
					break;
			}
			break;
		}
		case 1: {
			switch (id) {
				//	Options for the Direct3D blitter
				case MENU_DISABLEFX:
					bVidBilinear = 0;
					bVidScanlines = 0;
					nVidBlitterOpt[nVidSelect] &= 0xF40200FF;
					POST_INITIALISE_MESSAGE;
					break;

				case MENU_BILINEAR:
					bVidBilinear = !bVidBilinear;
					if (bVidOkay && (bRunPause || !bDrvOkay)) {
						VidRedraw();
					}
					break;

				case MENU_PHOSPHOR:
					bVidScanDelay = !bVidScanDelay;
					break;

				case MENU_NORMAL:
					nVidBlitterOpt[nVidSelect] &= ~0x00110000;
					POST_INITIALISE_MESSAGE;
					break;
				case MENU_SCAN:
					bVidScanlines = !bVidScanlines;
					nVidBlitterOpt[nVidSelect] &= ~0x00010000;
					POST_INITIALISE_MESSAGE;
					break;
				case MENU_RGBEFFECTS:
					nVidBlitterOpt[nVidSelect] &= ~0x00100000;
					nVidBlitterOpt[nVidSelect] |= 0x00010000;
					bVidScanlines = 0;
					ScrnSize();
					VidInit();
					if (bVidScanlines) {
						ScrnSize();
						VidInit();
					}
					if (bVidOkay && (bRunPause || !bDrvOkay)) {
						VidRedraw();
					}
					break;
				case MENU_3DPROJECTION:
					nVidBlitterOpt[nVidSelect] &= ~0x00010000;
					nVidBlitterOpt[nVidSelect] |= 0x00100000;
					POST_INITIALISE_MESSAGE;
					break;

				case MENU_EFFECT_AUTO:
					nVidBlitterOpt[nVidSelect] &= ~0x001000000;
					nVidBlitterOpt[nVidSelect] |= 0x00030000;
					POST_INITIALISE_MESSAGE;
					if (bVidOkay && (bRunPause || !bDrvOkay)) {
						VidRedraw();
					}
					break;
				case MENU_EFFECT_01:
				case MENU_EFFECT_02:
				case MENU_EFFECT_03:
				case MENU_EFFECT_04:
				case MENU_EFFECT_05:
				case MENU_EFFECT_06:
				case MENU_EFFECT_07:
				case MENU_EFFECT_08:
				case MENU_EFFECT_09:
				case MENU_EFFECT_0A:
				case MENU_EFFECT_0B:
				case MENU_EFFECT_0C:
				case MENU_EFFECT_0D:
				case MENU_EFFECT_0E:
				case MENU_EFFECT_0F:
				case MENU_EFFECT_10:
					nVidBlitterOpt[nVidSelect] &= ~0x001300FF;
					nVidBlitterOpt[nVidSelect] |= 0x00010008 + id - MENU_EFFECT_01;
					POST_INITIALISE_MESSAGE;
					if (bVidOkay && (bRunPause || !bDrvOkay)) {
						VidRedraw();
					}
					break;

				case MENU_ROTSCAN:
					bVidScanRotate = !bVidScanRotate;
					POST_INITIALISE_MESSAGE;
					break;

				case MENU_PRESCALE:
					nVidBlitterOpt[nVidSelect] ^= 0x01000000;
					POST_INITIALISE_MESSAGE;
					break;
				case MENU_SOFTFX:
					nVidBlitterOpt[nVidSelect] ^= 0x02000000;
					nVidBlitterOpt[nVidSelect] |= 0x01000000;
					POST_INITIALISE_MESSAGE;
					break;

				case MENU_SOFT_STRETCH:
				case MENU_SOFT_SCALE2X:
				case MENU_SOFT_SCALE3X:
				case MENU_SOFT_2XPM_LQ:
				case MENU_SOFT_2XPM_HQ:
				case MENU_SOFT_EAGLE:
				case MENU_SOFT_SUPEREAGLE:
				case MENU_SOFT_2XSAI:
				case MENU_SOFT_SUPER2XSAI:
				case MENU_SOFT_SUPEREAGLE_VBA:
				case MENU_SOFT_2XSAI_VBA:
				case MENU_SOFT_SUPER2XSAI_VBA:
				case MENU_SOFT_SUPERSCALE:
				case MENU_SOFT_SUPERSCALE75:
				case MENU_SOFT_HQ2X:
				case MENU_SOFT_HQ3X:
				case MENU_SOFT_HQ4X:
				case MENU_SOFT_HQ2XS_VBA:
				case MENU_SOFT_HQ3XS_VBA:
				case MENU_SOFT_HQ2XS_SNES9X:
				case MENU_SOFT_HQ3XS_SNES9X:
				case MENU_SOFT_HQ2XBOLD:
				case MENU_SOFT_HQ3XBOLD:
				case MENU_SOFT_EPXB:
				case MENU_SOFT_EPXC: {
					nVidBlitterOpt[nVidSelect] &= 0x0FFFFFFF;
					nVidBlitterOpt[nVidSelect] |= 0x03000000 + ((long long)(id - MENU_SOFT_STRETCH) << 32);
					POST_INITIALISE_MESSAGE;
					break;
				}
				case MENU_SOFT_AUTOSIZE:
					nVidBlitterOpt[nVidSelect] ^= 0x04000000;
					POST_INITIALISE_MESSAGE;
					break;

				case MENU_SCANINTENSITY:
					if (UseDialogs()) {
						InputSetCooperativeLevel(false, bAlwaysProcessKeyboardInput);
						AudBlankSound();
						if (!bVidScanlines) {
							bVidScanlines = 1;
							ScrnSize();
							VidInit();
							VidRedraw();
						}
						if (nVidBlitterOpt[nVidSelect] & 0x00010000) {
							nVidBlitterOpt[nVidSelect] &= ~0x00010000;
							ScrnSize();
							VidInit();
							VidRedraw();
						}
						ScanlineDialog();
						GameInpCheckMouse();
					}
					break;

				case MENU_PHOSPHORINTENSITY:
					if (UseDialogs()) {
						InputSetCooperativeLevel(false, bAlwaysProcessKeyboardInput);
						AudBlankSound();
						PhosphorDialog();
						bVidScanDelay = 1;
					}
					break;

				case MENU_3DSCREENANGLE:
					if (UseDialogs()) {
						InputSetCooperativeLevel(false, bAlwaysProcessKeyboardInput);
						AudBlankSound();
						if ((nVidBlitterOpt[nVidSelect] & 0x00100000) == 0) {
							nVidBlitterOpt[nVidSelect] &= ~0x00010000;
							nVidBlitterOpt[nVidSelect] |= 0x00100000;
							ScrnSize();
							VidInit();
							VidRedraw();
						}
						ScreenAngleDialog();
						if (!bRunPause) {
							GameInpCheckMouse();
						}
					}
					break;

				case MENU_FORCE_16BIT:
					bVidForce16bit = !bVidForce16bit;
					VidInit();
					if (bVidOkay && (bRunPause || !bDrvOkay)) {
						VidRedraw();
					}
					break;
				case MENU_TEXTUREMANAGE:
					if (nVidTransferMethod != 0) {
						nVidTransferMethod = 0;
					} else {
						nVidTransferMethod = 1;
					}
					VidInit();
					if (bVidOkay && (bRunPause || !bDrvOkay)) {
						VidRedraw();
					}
					break;
			}
			break;
		}
		case 2: {
			switch (id) {
				// Options for the DirectDraw Software Effects blitter
				case MENU_SOFT_STRETCH:
				case MENU_SOFT_SCALE2X:
				case MENU_SOFT_SCALE3X:
				case MENU_SOFT_2XPM_LQ:
				case MENU_SOFT_2XPM_HQ:
				case MENU_SOFT_EAGLE:
				case MENU_SOFT_SUPEREAGLE:
				case MENU_SOFT_2XSAI:
				case MENU_SOFT_SUPER2XSAI:
				case MENU_SOFT_SUPEREAGLE_VBA:
				case MENU_SOFT_2XSAI_VBA:
				case MENU_SOFT_SUPER2XSAI_VBA:
				case MENU_SOFT_SUPERSCALE:
				case MENU_SOFT_SUPERSCALE75:
				case MENU_SOFT_HQ2X:
				case MENU_SOFT_HQ3X:
				case MENU_SOFT_HQ4X:
				case MENU_SOFT_HQ2XS_VBA:
				case MENU_SOFT_HQ3XS_VBA:
				case MENU_SOFT_HQ2XS_SNES9X:
				case MENU_SOFT_HQ3XS_SNES9X:
				case MENU_SOFT_HQ2XBOLD:
				case MENU_SOFT_HQ3XBOLD:
				case MENU_SOFT_EPXB:
				case MENU_SOFT_EPXC:
					nVidBlitterOpt[nVidSelect] &= ~0xFF;
					nVidBlitterOpt[nVidSelect] |= id - MENU_SOFT_STRETCH;
					POST_INITIALISE_MESSAGE;
					break;

				case MENU_SOFT_AUTOSIZE:
					nVidBlitterOpt[nVidSelect] ^= 0x0100;
					POST_INITIALISE_MESSAGE;
					break;
				case MENU_SOFT_DIRECTACCESS:
					nVidBlitterOpt[nVidSelect] ^= 0x0200;
					POST_INITIALISE_MESSAGE;
					break;
			}
			break;
		}
		case 3:
			switch (id) {
				// Options for the DirectX Graphics 9 blitter
				case MENU_DX9_POINT:
					nVidBlitterOpt[nVidSelect] &= ~(3 << 24);
					nVidBlitterOpt[nVidSelect] |=  (0 << 24);
					POST_INITIALISE_MESSAGE;
					break;
				case MENU_DX9_LINEAR:
					nVidBlitterOpt[nVidSelect] &= ~(3 << 24);
					nVidBlitterOpt[nVidSelect] |=  (1 << 24);
					POST_INITIALISE_MESSAGE;
					break;
				case MENU_DX9_CUBIC:
					nVidBlitterOpt[nVidSelect] &= ~(3 << 24);
					nVidBlitterOpt[nVidSelect] |=  (2 << 24);
					POST_INITIALISE_MESSAGE;
					break;

				case MENU_DX9_CUBIC_LIGHT:
					dVidCubicB = 0.0;
					dVidCubicC = 0.0;
					VidRedraw();
					break;
				case MENU_DX9_CUBIC_BSPLINE:
					dVidCubicB = 1.0;
					dVidCubicC = 0.0;
					VidRedraw();
					break;
				case MENU_DX9_CUBIC_NOTCH:
					dVidCubicB =  3.0 / 2.0;
					dVidCubicC = -0.25;
					VidRedraw();
					break;
				case MENU_DX9_CUBIC_OPTIMAL:
					dVidCubicB = 1.0 / 3.0;
					dVidCubicC = 1.0 / 3.0;
					VidRedraw();
					break;
				case MENU_DX9_CUBIC_CATMULL:
					dVidCubicB = 0.0;
					dVidCubicC = 0.5;
					VidRedraw();
					break;
				case MENU_DX9_CUBIC_SHARP:
					dVidCubicB = 0.0;
					dVidCubicC = 1.0;
					VidRedraw();
					break;

/*
					if (UseDialogs()) {
						InputSetCooperativeLevel(false, bAlwaysProcessKeyboardInput);
						AudBlankSound();
						if ((nVidBlitterOpt[nVidSelect] & (3 << 24)) !=  (2 << 24)) {
							nVidBlitterOpt[nVidSelect] &= ~(3 << 24);
							nVidBlitterOpt[nVidSelect] |=  (2 << 24);
							ScrnSize();
							VidInit();
							VidRedraw();
						}
						CubicSharpnessDialog();
						GameInpCheckMouse();
					}
					break;
*/

				case MENU_SCAN:
					bVidScanlines = !bVidScanlines;
					POST_INITIALISE_MESSAGE;
					break;
				case MENU_SCANINTENSITY:
					if (UseDialogs()) {
						InputSetCooperativeLevel(false, bAlwaysProcessKeyboardInput);
						AudBlankSound();
						if (!bVidScanlines) {
							bVidScanlines = 1;
							ScrnSize();
							VidInit();
							VidRedraw();
						}
						ScanlineDialog();
						GameInpCheckMouse();
					}
					break;

				case MENU_DX9_FPTERXTURES:
					POST_INITIALISE_MESSAGE;
					break;

				case MENU_DX9_FORCE_PS14:
					nVidBlitterOpt[nVidSelect] ^=  (1 <<  9);
					POST_INITIALISE_MESSAGE;
					break;

				case MENU_DX9_CUBIC0:
					nVidBlitterOpt[nVidSelect] &= ~(7 << 28);
					nVidBlitterOpt[nVidSelect] |=  (0 << 28);

					nVidBlitterOpt[nVidSelect] |=  (1 <<  8);
					nVidBlitterOpt[nVidSelect] |=  (1 <<  9);
					POST_INITIALISE_MESSAGE;
					break;
				case MENU_DX9_CUBIC1:
					nVidBlitterOpt[nVidSelect] &= ~(7 << 28);
					nVidBlitterOpt[nVidSelect] |=  (1 << 28);

					nVidBlitterOpt[nVidSelect] |=  (1 <<  8);
					nVidBlitterOpt[nVidSelect] |=  (1 <<  9);
					POST_INITIALISE_MESSAGE;
					break;
				case MENU_DX9_CUBIC2:
					nVidBlitterOpt[nVidSelect] &= ~(7 << 28);
					nVidBlitterOpt[nVidSelect] |=  (2 << 28);

					nVidBlitterOpt[nVidSelect] |=  (1 <<  8);
					nVidBlitterOpt[nVidSelect] |=  (1 <<  9);
					POST_INITIALISE_MESSAGE;
					break;
				case MENU_DX9_CUBIC3:
					nVidBlitterOpt[nVidSelect] &= ~(7 << 28);
					nVidBlitterOpt[nVidSelect] |=  (3 << 28);

					nVidBlitterOpt[nVidSelect] |=  (1 <<  8);
					nVidBlitterOpt[nVidSelect] |=  (1 <<  9);
					POST_INITIALISE_MESSAGE;
					break;
				case MENU_DX9_CUBIC4:
					nVidBlitterOpt[nVidSelect] &= ~(7 << 28);
					nVidBlitterOpt[nVidSelect] |=  (4 << 28);

					nVidBlitterOpt[nVidSelect] &= ~(1 <<  8);
					nVidBlitterOpt[nVidSelect] &= ~(1 <<  9);
					POST_INITIALISE_MESSAGE;
					break;

			}
			break;
	}

	if (hwndChat) {
		switch (codeNotify) {
			case EN_CHANGE: {
				bEditTextChanged = true;
				SendMessage(hwndChat, WM_GETTEXT, (WPARAM)MAX_CHAT_SIZE + 1, (LPARAM)EditText);
				break;
			}
			case EN_KILLFOCUS: {
				SetFocus(hwndChat);
				break;
			}
			case EN_MAXTEXT: {
				VidSNewShortMsg(FBALoadStringEx(hAppInst, IDS_NETPLAY_TOOMUCH, true), 0xFF3F3F);
				break;
			}
		}
	}

	MenuUpdate();
}

// Block screensaver and windows menu if needed
static int OnSysCommand(HWND, UINT sysCommand, int, int)
{
	switch (sysCommand) {
		case SC_MONITORPOWER:
		case SC_SCREENSAVE: {
			if (!bRunPause && bDrvOkay) {
				return 1;
			}
			break;
		}
		case SC_KEYMENU:
		case SC_MOUSEMENU: {
			if (kNetGame && !bModelessMenu) {
				return 1;
			}
			break;
		}
	}

	return 0;
}

static void OnSize(HWND, UINT state, int cx, int cy)
{
	if (state == SIZE_MINIMIZED) {
		bMaximised = false;
	} else {
		bool bSizeChanged = false;

		MoveWindow(hRebar, 0, 0, cx, nMenuHeight, TRUE);

		if (hwndChat) {
			MoveWindow(hwndChat, 0, cy - 32, cx, 32, FALSE);
		}

		if (state == SIZE_MAXIMIZED) {
			if (!bMaximised) {
				bSizeChanged = true;
			}
			bMaximised = true;
		}
		if (state == SIZE_RESTORED) {
			if (bMaximised) {
				bSizeChanged = true;
			}
			bMaximised = false;
		}
		
		if (bSizeChanged) {
			RefreshWindow(true);
		} else {
			RefreshWindow(false);
		}
	}
}

static void OnEnterSizeMove(HWND)
{
	RECT rect;

	AudBlankSound();

	GetClientRect(hScrnWnd, &rect);
	nPrevWidth = rect.right;
	nPrevHeight = rect.bottom;
}

static void OnExitSizeMove(HWND)
{
	RECT rect;

	GetClientRect(hScrnWnd, &rect);
	if (rect.right != nPrevWidth || rect.bottom != nPrevHeight) {
		RefreshWindow(true);
	}
	
	GetWindowRect(hScrnWnd, &rect);
	nWindowPosX = rect.left;
	nWindowPosY = rect.top;
}

static void OnEnterIdle(HWND /*hwnd*/, UINT /*source*/, HWND /*hwndSource*/)
{
	MSG Message;

    // Modeless dialog is idle
    while (kNetGame && !PeekMessage(&Message, NULL, 0, 0, PM_NOREMOVE)) {
		RunIdle();
	}
}

static void OnEnterMenuLoop(HWND, BOOL)
{
	if (!bModelessMenu) {
		InputSetCooperativeLevel(false, bAlwaysProcessKeyboardInput);
		AudBlankSound();
	} else {
		if (!kNetGame && bAutoPause) {
			bRunPause = 1;
		}
	}
}

static void OnExitMenuLoop(HWND, BOOL)
{
	if (!bModelessMenu) {
		GameInpCheckMouse();
	}
}

static int ScrnRegister()
{
	WNDCLASSEX WndClassEx;
	ATOM Atom = 0;

	// Register the window class
	memset(&WndClassEx, 0, sizeof(WndClassEx)); 		// Init structure to all zeros
	WndClassEx.cbSize = sizeof(WndClassEx);
	WndClassEx.style = CS_HREDRAW | CS_VREDRAW | CS_DBLCLKS | CS_CLASSDC;// These cause flicker in the toolbar
	WndClassEx.lpfnWndProc = ScrnProc;
	WndClassEx.hInstance = hAppInst;
	WndClassEx.hIcon = LoadIcon(hAppInst, MAKEINTRESOURCE(IDI_APP));
	WndClassEx.hCursor = LoadCursor(NULL, IDC_ARROW);
	WndClassEx.hbrBackground = CreateSolidBrush(0);
	WndClassEx.lpszClassName = szClass;

	// Register the window class with the above information:
	Atom = RegisterClassEx(&WndClassEx);
	if (Atom) {
		return 0;
	} else {
		return 1;
	}
}

int ScrnSize()
{
	int x, y, w, h, ew, eh;
	int nScrnWidth, nScrnHeight;
	int nBmapWidth = nVidImageWidth, nBmapHeight = nVidImageHeight;
	int nGameAspectX = 4, nGameAspectY = 3;
	int nMaxSize;

	SystemParametersInfo(SPI_GETWORKAREA, 0, &SystemWorkArea, 0);	// Find the size of the visible WorkArea

	if (hScrnWnd == NULL || nVidFullscreen) {
		return 1;
	}

	if (bDrvOkay) {
		if ((BurnDrvGetFlags() & BDF_ORIENTATION_VERTICAL) && (nVidRotationAdjust & 1)) {
			BurnDrvGetVisibleSize(&nBmapHeight, &nBmapWidth);
			BurnDrvGetAspect(&nGameAspectY, &nGameAspectX);
		} else {
			BurnDrvGetVisibleSize(&nBmapWidth, &nBmapHeight);
			BurnDrvGetAspect(&nGameAspectX, &nGameAspectY);
		}

		if (nBmapWidth <= 0 || nBmapHeight <= 0) {
			return 1;
		}
	}

	nDragX = GetSystemMetrics(SM_CXDRAG) / 2;
	nDragY = GetSystemMetrics(SM_CYDRAG) / 2;

	nScrnWidth = SystemWorkArea.right - SystemWorkArea.left;
	nScrnHeight = SystemWorkArea.bottom - SystemWorkArea.top;

	if (nVidSelect == 2 && nVidBlitterOpt[2] & 0x0100) {								// The Software effects blitter uses a fixed size
		nMaxSize = 9;
	} else {
		if (nWindowSize) {
			nMaxSize = nWindowSize;
		} else {
			if (nBmapWidth < nBmapHeight) {
				if (SystemWorkArea.bottom - SystemWorkArea.top <= 600) {
					nMaxSize = 1;
				} else {
					if (SystemWorkArea.bottom - SystemWorkArea.top <= 960) {
						nMaxSize = 2;
					} else {
						if (SystemWorkArea.bottom - SystemWorkArea.top <= 1280) {
							nMaxSize = 3;
						} else {
							nMaxSize = 4;
						}
					}
				}
			} else {
				if (SystemWorkArea.right - SystemWorkArea.left <= 640) {
					nMaxSize = 1;
				} else {
					if (SystemWorkArea.right - SystemWorkArea.left <= 1152) {
						nMaxSize = 2;
					} else {
						if (SystemWorkArea.right - SystemWorkArea.left <= 1600) {
							nMaxSize = 3;
						} else {
							nMaxSize = 4;
						}
					}
				}
			}
		}
	}

	// Find the width and height
	w = nScrnWidth;
	h = nScrnHeight;

	// Find out how much space is taken up by the borders
	ew = GetSystemMetrics(SM_CXSIZEFRAME) << 1;
	eh = GetSystemMetrics(SM_CYSIZEFRAME) << 1;

	if (bMenuEnabled) {
		eh += GetSystemMetrics(SM_CYCAPTION);
		eh += nMenuHeight;
	} else {
		eh += 1 << 1;
		ew += 1 << 1;
	}

	if (bMenuEnabled || !bVidScanlines || nVidSelect == 2) {
		// Subtract the border space
		w -= ew;
		h -= eh;
	}
	
	if ((bVidCorrectAspect || bVidFullStretch) && !(nVidSelect == 2 && (nVidBlitterOpt[2] & 0x0100) == 0)) {
		int ww = w;
		int hh = h;

		do {
			if (nBmapWidth < nBmapHeight && bVidScanRotate) {
				if (ww > nBmapWidth * nMaxSize) {
					ww = nBmapWidth * nMaxSize;
				}
				if (hh > ww * nVidScrnAspectX * nGameAspectY * nScrnHeight / (nScrnWidth * nVidScrnAspectY * nGameAspectX)) {
					hh = ww * nVidScrnAspectX * nGameAspectY * nScrnHeight / (nScrnWidth * nVidScrnAspectY * nGameAspectX);
				}
			} else {
				if (hh > nBmapHeight * nMaxSize) {
					hh = nBmapHeight * nMaxSize;
				}
				if (ww > hh * nVidScrnAspectY * nGameAspectX * nScrnWidth / (nScrnHeight * nVidScrnAspectX * nGameAspectY)) {
					ww = hh * nVidScrnAspectY * nGameAspectX * nScrnWidth / (nScrnHeight * nVidScrnAspectX * nGameAspectY);
				}
			}
		} while ((ww > w || hh > h) && nMaxSize-- > 1);
		w =	ww;
		h = hh;
	} else {
		while ((nBmapWidth * nMaxSize > w || nBmapHeight * nMaxSize > h) && nMaxSize > 1) {
			nMaxSize--;
		}

		if (w > nBmapWidth * nMaxSize || h > nBmapHeight * nMaxSize) {
			w = nBmapWidth * nMaxSize;
			h = nBmapHeight * nMaxSize;
		}
	}
	
	if (!bDrvOkay) {
		if (w < 304) w = 304;
		if (h < 224) h = 224;
	}

	RECT rect = { 0, 0, w, h };
	VidImageSize(&rect, nBmapWidth, nBmapHeight);
	w = rect.right - rect.left + ew;
	h = rect.bottom - rect.top + eh;

	x = nWindowPosX; y = nWindowPosY;
	if (x + w > SystemWorkArea.right || y + h > SystemWorkArea.bottom) {
		// Find the midpoint for the window
		x = SystemWorkArea.left + SystemWorkArea.right;
		x /= 2;
		y = SystemWorkArea.bottom + SystemWorkArea.top;
		y /= 2;

		x -= w / 2;
		y -= h / 2;
	}

	MenuUpdate();

	bMaximised = false;

	MoveWindow(hScrnWnd, x, y, w, h, true);
//	SetWindowPos(hScrnWnd, NULL, x, y, w, h, SWP_NOREDRAW | SWP_NOACTIVATE | SWP_NOSENDCHANGING | SWP_NOZORDER);

	nWindowPosX = x; nWindowPosY = y;

  	return 0;
}

int ScrnTitle()
{
	TCHAR szText[1024] = _T("");

	// Create window title
	if (bDrvOkay) {
		TCHAR* pszPosition = szText;
		TCHAR* pszName = BurnDrvGetText(DRV_FULLNAME);

		pszPosition += _sntprintf(szText, 1024, _T(APP_TITLE) _T( " v%.20s") _T(SEPERATOR_1) _T("%s"), szAppBurnVer, pszName);
		while ((pszName = BurnDrvGetText(DRV_NEXTNAME | DRV_FULLNAME)) != NULL) {
			if (pszPosition + _tcslen(pszName) - 1024 > szText) {
				break;
			}
			pszPosition += _stprintf(pszPosition, _T(SEPERATOR_2) _T("%s"), pszName);
		}
	} else {
		_stprintf(szText, _T(APP_TITLE) _T( " v%.20s") _T(SEPERATOR_1) _T("[%s]"), szAppBurnVer, FBALoadStringEx(hAppInst, IDS_SCRN_NOGAME, true));
	}

	SetWindowText(hScrnWnd, szText);
	return 0;
}

// Init the screen window (create it)
int ScrnInit()
{
	REBARINFO rebarInfo;
	REBARBANDINFO rebarBandInfo;
	RECT rect;
	int nWindowStyles, nWindowExStyles;

	ScrnExit();
	
	if (ScrnRegister() != 0) {
		return 1;
	}

	if (nVidFullscreen) {
		nWindowStyles = WS_POPUP;
		nWindowExStyles = 0;
	} else {
		if (bMenuEnabled) {
			nWindowStyles = WS_OVERLAPPEDWINDOW;
			nWindowExStyles = 0;
		} else {
			nWindowStyles = WS_MINIMIZEBOX | WS_POPUP | WS_SYSMENU | WS_THICKFRAME;
			nWindowExStyles = WS_EX_CLIENTEDGE;
		}
	}

	hScrnWnd = CreateWindowEx(nWindowExStyles, szClass, _T(APP_TITLE), nWindowStyles,
		0, 0, 0, 0,									   			// size of window
		NULL, NULL, hAppInst, NULL);

	if (hScrnWnd == NULL) {
		ScrnExit();
		return 1;
	}

	nMenuHeight = 0;
	if (!nVidFullscreen) {

		// Create the menu toolbar itself
		MenuCreate();

		// Create the toolbar
		if (bMenuEnabled) {
			// Create the Rebar control that will contain the menu toolbar
			hRebar = CreateWindowEx(WS_EX_TOOLWINDOW,
				REBARCLASSNAME, NULL,
				RBS_BANDBORDERS | CCS_NOPARENTALIGN | CCS_NODIVIDER | WS_BORDER | WS_CHILD | WS_CLIPCHILDREN | WS_CLIPSIBLINGS | WS_VISIBLE,
				0, 0, 0, 0,
				hScrnWnd, NULL, hAppInst, NULL);

			rebarInfo.cbSize = sizeof(REBARINFO);
			rebarInfo.fMask = 0;
			rebarInfo.himl = NULL;

			SendMessage(hRebar, RB_SETBARINFO, 0, (LPARAM)&rebarInfo);

			// Add the menu toolbar to the rebar
			GetWindowRect(hMenubar, &rect);

			rebarBandInfo.cbSize = sizeof(REBARBANDINFO);
			rebarBandInfo.fMask = RBBIM_CHILD | RBBIM_CHILDSIZE | RBBIM_SIZE | RBBIM_STYLE;
			rebarBandInfo.fStyle = RBBS_GRIPPERALWAYS;
			rebarBandInfo.hwndChild = hMenubar;
			rebarBandInfo.cxMinChild = 100;
			rebarBandInfo.cyMinChild = ((SendMessage(hMenubar, TB_GETBUTTONSIZE, 0, 0)) >> 16) + 1;
			rebarBandInfo.cx = rect.right - rect.left;

			SendMessage(hRebar, RB_INSERTBAND, (WPARAM)-1, (LPARAM)&rebarBandInfo);

			GetWindowRect(hRebar, &rect);
			nMenuHeight = rect.bottom - rect.top;

		}
		
		DragAcceptFiles(hScrnWnd, 1);
		
		ScrnTitle();
		ScrnSize();
	}

	return 0;
}

// Exit the screen window (destroy it)
int ScrnExit()
{
	// Ensure the window is destroyed
	DeActivateChat();

	if (hRebar) {
		DestroyWindow(hRebar);
		hRebar = NULL;
	}

	if (hScrnWnd) {
		DestroyWindow(hScrnWnd);
		hScrnWnd = NULL;
	}

	UnregisterClass(szClass, hAppInst);		// Unregister the scrn class

	MenuDestroy();

	return 0;
}

void Reinitialise()
{
	POST_INITIALISE_MESSAGE;
	VidReInitialise();
}

int StartFromReset()
{
	bDoPatch = FALSE;
	PatchExit();
	if(nBurnDrvSelect < 1) return 0;
	
	int nOldDrvSelect = nBurnDrvSelect;

	DrvExit();
	bLoading = 1;
	
	nBurnDrvSelect = nOldDrvSelect;
	nDialogSelect = nOldDrvSelect;
	SplashDestroy(1);
	StopReplay();
	
	nSkipNvram = 1;
	DrvInit(nOldDrvSelect, false);	// Init the game driver, without loading SRAM
	nSkipNvram = 0;
	MenuEnableItems();
	bAltPause = 0;
	AudSoundPlay();			// Restart sound
	bLoading = 0;
	UpdatePreviousGameList();
	if (bVidAutoSwitchFull) {
		nVidFullscreen = 1;
		POST_INITIALISE_MESSAGE;
	}
	return 1;
}
