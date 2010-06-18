// based on FBA shuffle, which was based on FBA-RR, which was based on PCSX-RR
#include "burner.h"
#include "maphkeys.h"
#include "tracklst.h"
#include "vid_directx_support.h"

enum { MODKEY_NONE = 0x00, MODKEY_CTRL = 0x01, MODKEY_ALT = 0x02, MODKEY_SHIFT = 0x04 };

// init keys
CustomKey customKeys[] = {
	{ VK_ESCAPE,     MODKEY_NONE,  0,                      "Call Menu",                 "call-menu",     HK_callMenu,          0, 0 },
	{ VK_PAUSE,      MODKEY_NONE,  MENU_PAUSE,             "Pause",                     "pause",         HK_pause,             0, 0 },
	{ VK_TAB,        MODKEY_NONE,  0,                      "Fast Forward",              "fast-foward",   HK_fastFowardKeyDown, HK_fastFowardKeyUp, 0 },
	{ VK_OEM_5,      MODKEY_NONE,  0,                      "Frame Advance",             "frame-advance", HK_frameAdvance,      0, 0 },
	{ '8',           MODKEY_SHIFT, 0,                      "Read-Only Toggle",          "readonly",      HK_toggleReadOnly,    0, 0 },
	{ VK_OEM_MINUS,  MODKEY_NONE,  0,                      "Decrease Speed",            "dec-speed",     HK_speedDec,          0, 0 },
	{ VK_OEM_PLUS,   MODKEY_NONE,  0,                      "Increase Speed",            "inc-speed",     HK_speedInc,          0, 0 },
	{ VK_NUMPAD0,    MODKEY_NONE,  0,                      "Normal Speed",              "normal-speed",  HK_speedNormal,       0, 0 },
	{ VK_DECIMAL,    MODKEY_NONE,  0,                      "Turbo Speed",               "turbo-speed",   HK_speedTurbo,        0, 0 },
	{ VK_OEM_PERIOD, MODKEY_NONE,  0,                      "Frame Counter",             "frame-counter", HK_frameCounter,      0, 0 },
	{ VK_F12,        MODKEY_NONE,  MENU_SAVESNAP,          "Take Screenshot",           "screenshot",    HK_screenShot,        0, 0 },

	{ VK_F1,         MODKEY_NONE,  0,                      "Load State 1",              "loadstate1",    HK_loadState,         0, 1 },
	{ VK_F2,         MODKEY_NONE,  0,                      "Load State 2",              "loadstate2",    HK_loadState,         0, 2 },
	{ VK_F3,         MODKEY_NONE,  0,                      "Load State 3",              "loadstate3",    HK_loadState,         0, 3 },
	{ VK_F4,         MODKEY_NONE,  0,                      "Load State 4",              "loadstate4",    HK_loadState,         0, 4 },
	{ VK_F5,         MODKEY_NONE,  0,                      "Load State 5",              "loadstate5",    HK_loadState,         0, 5 },
	{ VK_F6,         MODKEY_NONE,  0,                      "Load State 6",              "loadstate6",    HK_loadState,         0, 6 },
	{ VK_F7,         MODKEY_NONE,  0,                      "Load State 7",              "loadstate7",    HK_loadState,         0, 7 },
	{ VK_F8,         MODKEY_NONE,  0,                      "Load State 8",              "loadstate8",    HK_loadState,         0, 8 },
	{ VK_F9,         MODKEY_NONE,  0,                      "Load State 9",              "loadstate9",    HK_loadState,         0, 9 },
	{ VK_F1,         MODKEY_SHIFT, 0,                      "Save State 1",              "savestate1",    HK_saveState,         0, 1 },
	{ VK_F2,         MODKEY_SHIFT, 0,                      "Save State 2",              "savestate2",    HK_saveState,         0, 2 },
	{ VK_F3,         MODKEY_SHIFT, 0,                      "Save State 3",              "savestate3",    HK_saveState,         0, 3 },
	{ VK_F4,         MODKEY_SHIFT, 0,                      "Save State 4",              "savestate4",    HK_saveState,         0, 4 },
	{ VK_F5,         MODKEY_SHIFT, 0,                      "Save State 5",              "savestate5",    HK_saveState,         0, 5 },
	{ VK_F6,         MODKEY_SHIFT, 0,                      "Save State 6",              "savestate6",    HK_saveState,         0, 6 },
	{ VK_F7,         MODKEY_SHIFT, 0,                      "Save State 7",              "savestate7",    HK_saveState,         0, 7 },
	{ VK_F8,         MODKEY_SHIFT, 0,                      "Save State 8",              "savestate8",    HK_saveState,         0, 8 },
	{ VK_F9,         MODKEY_SHIFT, 0,                      "Save State 9",              "savestate9",    HK_selectState,       0, 9 },
	{ 0,             MODKEY_NONE,  0,                      "Select State 1",            "sel-state1",    HK_selectState,       0, 1 },
	{ 0,             MODKEY_NONE,  0,                      "Select State 2",            "sel-state2",    HK_selectState,       0, 2 },
	{ 0,             MODKEY_NONE,  0,                      "Select State 3",            "sel-state3",    HK_selectState,       0, 3 },
	{ 0,             MODKEY_NONE,  0,                      "Select State 4",            "sel-state4",    HK_selectState,       0, 4 },
	{ 0,             MODKEY_NONE,  0,                      "Select State 5",            "sel-state5",    HK_selectState,       0, 5 },
	{ 0,             MODKEY_NONE,  0,                      "Select State 6",            "sel-state6",    HK_selectState,       0, 6 },
	{ 0,             MODKEY_NONE,  0,                      "Select State 7",            "sel-state7",    HK_selectState,       0, 7 },
	{ 0,             MODKEY_NONE,  0,                      "Select State 8",            "sel-state8",    HK_selectState,       0, 8 },
	{ 0,             MODKEY_NONE,  0,                      "Select State 9",            "sel-state9",    HK_selectState,       0, 9 },
	{ 0,             MODKEY_NONE,  MENU_STATE_PREVSLOT,    "Select Previous Slot",      "sel-prevstate", HK_prevState,         0, 0 },
	{ 0,             MODKEY_NONE,  MENU_STATE_NEXTSLOT,    "Select Next Slot",          "sel-nextstate", HK_nextState,         0, 0 },
	{ 0,             MODKEY_NONE,  MENU_STATE_LOAD_SLOT,   "Load Current State",        "load-curstate", HK_loadCurState,      0, 0 },
	{ 0,             MODKEY_NONE,  MENU_STATE_SAVE_SLOT,   "Save Current State",        "save-curstate", HK_saveCurState,      0, 0 },
	{ 0,             MODKEY_NONE,  MENU_STATE_LOAD_DIALOG, "Load State Dialog",         "load-dialog",   HK_loadStateDialog,   0, 0 },
	{ 0,             MODKEY_NONE,  MENU_STATE_SAVE_DIALOG, "Save State Dialog",         "save-dialog",   HK_saveStateDialog,   0, 0 },

	{ 'N',           MODKEY_CTRL,  MENU_STARTRECORD,       "Start Recording",           "start-rec",     HK_startRec,          0, 0 },
	{ 'R',           MODKEY_CTRL,  MENU_STARTREPLAY,       "Start Playback",            "play-rec",      HK_playRec,           0, 0 },
	{ 'R',           MODKEY_SHIFT, 0,                      "Play Movie From Beginning", "play-begin",    HK_playFromBeginning, 0, 0 },
	{ 'T',           MODKEY_CTRL,  MENU_STOPREPLAY,        "Stop Movie",                "end-rec",       HK_stopRec,           0, 0 },
	{ 0,             MODKEY_NONE,  MENU_AVI_BEGIN,         "Start AVI Capture",         "start-avi",     HK_startAvi,          0, 0 },
	{ 0,             MODKEY_NONE,  MENU_AVI_END,           "Stop AVI Capture",          "end-avi",       HK_stopAvi,           0, 0 },
	{ 'C',           MODKEY_CTRL,  MENU_ENABLECHEAT,       "Cheat Editor",              "cheat",         HK_cheatEditor,       0, 0 },
//	{ 'F',           MODKEY_CTRL,  ID_RAM_SEARCH,          "RAM Search",                "ram-search",    HK_ramSearch,         0, 0 },
	{ 'F',           MODKEY_CTRL,  ID_RAM_SEARCH,          "RAM Search",                "ram-search",    HK_ramSearchOld,      0, 0 },
//	{ 'W',           MODKEY_CTRL,  ID_RAM_WATCH,           "RAM Watch",                 "ram-watch",     HK_ramWatch,          0, 0 },
	{ 'W',           MODKEY_CTRL,  ID_RAM_WATCH,           "RAM Watch",                 "ram-watch",     HK_ramWatchOld,       0, 0 },
	{ 0,             0,            ID_LUA_OPEN,            "New Lua Script Window",     "lua-open",      HK_luaOpen,           0, 0 },
	{ 0,             0,            ID_LUA_CLOSE_ALL,       "Close All Script Windows",  "lua-close-all", HK_luaCloseAll,       0, 0 },
	{ 0,             0,            0,                      "Reload Lua Script",         "lua-reload",    HK_luaReload,         0, 0 },
	{ 0,             0,            0,                      "Stop Lua Script",           "lua-stop",      HK_luaStop,           0, 0 },

	{ VK_OEM_MINUS,  MODKEY_CTRL,  0,                      "Volume Down",               "volume-down",   HK_volumeDec,         0, 0 },
	{ VK_OEM_PLUS,   MODKEY_CTRL,  0,                      "Volume Up",                 "volume-up",     HK_volumeInc,         0, 0 },
	{ VK_BACK,       MODKEY_NONE,  0,                      "Show FPS",                  "show-fps",      HK_showFps,           0, 0 },
	{ 0,             MODKEY_NONE,  MENU_LOAD,              "Open Game",                 "open-game",     HK_openGame,          0, 0 },
	{ 0,             MODKEY_NONE,  MENU_VIEWGAMEINFO,      "Game Info",                 "game-info",     HK_gameInfo,          0, 0 },
	{ 0,             MODKEY_NONE,  MENU_QUIT,              "Exit Game",                 "exit-game",     HK_exitGame,          0, 0 },
	{ 0,             MODKEY_NONE,  MENU_INPUT,             "Configure Controllers",     "config-pad",    HK_configPad,         0, 0 },
	{ 0,             MODKEY_NONE,  MENU_DIPSW,             "DIP Switches",              "dips",          HK_setDips,           0, 0 },
	{ VK_F12,        MODKEY_CTRL,  MENU_SNAPFACT,          "Shot Factory",              "shot-factory",  HK_shotFactory,       0, 0 },
	{ '1',           MODKEY_ALT,   MENU_SINGLESIZEWINDOW,  "Window size 1x",            "win-size1",     HK_windowSize,        0, 1 },
	{ '2',           MODKEY_ALT,   MENU_DOUBLESIZEWINDOW,  "Window size 2x",            "win-size2",     HK_windowSize,        0, 2 },
	{ '3',           MODKEY_ALT,   MENU_TRIPLESIZEWINDOW,  "Window size 3x",            "win-size3",     HK_windowSize,        0, 3 },
	{ '4',           MODKEY_ALT,   MENU_QUADSIZEWINDOW,    "Window size 4x",            "win-size4",     HK_windowSize,        0, 4 },
	{ 'S',           MODKEY_ALT,   MENU_MAXIMUMSIZEWINDOW, "Window size max",           "win-sizemax",   HK_windowSizeMax,     0, 0 },
	{ VK_RETURN,     MODKEY_ALT,   MENU_FULL,              "Toggle fullscreen",         "fullscreen",    HK_fullscreen,        0, 0 },

	{ 0xffff, 0xffff, 0, "unknown error", "", 0, 0, 0 }, // last key
};

static int nFpsScale = 100;

HWND hMHkeysDlg = NULL;
static HWND hMHkeysList = NULL;

static HHOOK hook = 0;
static int receivingKmap;

const TCHAR* GetKeyName(int c)
{
	static TCHAR out[MAX_PATH] = _T("");
	_stprintf(out, _T("#%d"), c);

	if ((c >= '0' && c <= '9') || (c >= 'A' && c <= 'Z'))
	{
		_stprintf(out, _T("%c"), c);
		return out;
	}
	if (c >= VK_NUMPAD0 && c <= VK_NUMPAD9)
	{
		_stprintf(out, _T("Numpad-%c"), '0' + (c - VK_NUMPAD0));
		return out;
	}

	switch (c)
	{
		case VK_TAB:        _stprintf(out, _T("Tab")); break;
		case VK_BACK:       _stprintf(out, _T("Backspace")); break;
		case VK_CLEAR:      _stprintf(out, _T("Delete")); break;
		case VK_RETURN:     _stprintf(out, _T("Enter")); break;
		case VK_LSHIFT:     _stprintf(out, _T("LShift")); break;
		case VK_RSHIFT:     _stprintf(out, _T("RShift")); break;
		case VK_LCONTROL:   _stprintf(out, _T("LCtrl")); break;
		case VK_RCONTROL:   _stprintf(out, _T("RCtrl")); break;
		case VK_LMENU:      _stprintf(out, _T("LAlt")); break;
		case VK_RMENU:      _stprintf(out, _T("RAlt")); break;
		case VK_PAUSE:      _stprintf(out, _T("Pause")); break;
		case VK_CAPITAL:    _stprintf(out, _T("CapsLock")); break;
		case VK_ESCAPE:     _stprintf(out, _T("Escape")); break;
		case VK_SPACE:      _stprintf(out, _T("Space")); break;
		case VK_PRIOR:      _stprintf(out, _T("PgUp")); break;
		case VK_NEXT:       _stprintf(out, _T("PgDn")); break;
		case VK_HOME:       _stprintf(out, _T("Home")); break;
		case VK_END:        _stprintf(out, _T("End")); break;
		case VK_LEFT:       _stprintf(out, _T("Left") ); break;
		case VK_RIGHT:      _stprintf(out, _T("Right")); break;
		case VK_UP:         _stprintf(out, _T("Up")); break;
		case VK_DOWN:       _stprintf(out, _T("Down")); break;
		case VK_SELECT:     _stprintf(out, _T("Select")); break;
		case VK_PRINT:      _stprintf(out, _T("Print")); break;
		case VK_EXECUTE:    _stprintf(out, _T("Execute")); break;
		case VK_SNAPSHOT:   _stprintf(out, _T("SnapShot")); break;
		case VK_INSERT:     _stprintf(out, _T("Insert")); break;
		case VK_DELETE:     _stprintf(out, _T("Delete")); break;
		case VK_HELP:       _stprintf(out, _T("Help")); break;
		case VK_LWIN:       _stprintf(out, _T("LWin")); break;
		case VK_RWIN:       _stprintf(out, _T("RWin")); break;
		case VK_APPS:       _stprintf(out, _T("App")); break;
		case VK_MULTIPLY:   _stprintf(out, _T("Numpad *")); break;
		case VK_ADD:        _stprintf(out, _T("Numpad +")); break;
		case VK_SEPARATOR:  _stprintf(out, _T("\\")); break;
		case VK_OEM_7:      _stprintf(out, _T("Apostrophe")); break;
		case VK_OEM_COMMA:  _stprintf(out, _T("Comma") );break;
		case VK_OEM_PERIOD: _stprintf(out, _T("Period"));break;
		case VK_SUBTRACT:   _stprintf(out, _T("Numpad -")); break;
		case VK_DECIMAL:    _stprintf(out, _T("Numpad .")); break;
		case VK_DIVIDE:     _stprintf(out, _T("Numpad /")); break;
		case VK_NUMLOCK:    _stprintf(out, _T("NumLock")); break;
		case VK_SCROLL:     _stprintf(out, _T("ScrollLock")); break;
		case VK_OEM_MINUS:  _stprintf(out, _T("-")); break;
		case VK_OEM_PLUS:   _stprintf(out, _T("=")); break;
		case VK_SHIFT:      _stprintf(out, _T("Shift")); break;
		case VK_CONTROL:    _stprintf(out, _T("Control")); break;
		case VK_MENU:       _stprintf(out, _T("Alt")); break;
		case VK_OEM_1:      _stprintf(out, _T(";")); break;
		case VK_OEM_4:      _stprintf(out, _T("[")); break;
		case VK_OEM_6:      _stprintf(out, _T("]")); break;
		case VK_OEM_5:      _stprintf(out, _T("\\")); break;
		case VK_OEM_2:      _stprintf(out, _T("/")); break;
		case VK_OEM_3:      _stprintf(out, _T("`")); break;
		case VK_F1:         _stprintf(out, _T("F1")); break;
		case VK_F2:         _stprintf(out, _T("F2")); break;
		case VK_F3:         _stprintf(out, _T("F3")); break;
		case VK_F4:         _stprintf(out, _T("F4")); break;
		case VK_F5:         _stprintf(out, _T("F5")); break;
		case VK_F6:         _stprintf(out, _T("F6")); break;
		case VK_F7:         _stprintf(out, _T("F7")); break;
		case VK_F8:         _stprintf(out, _T("F8")); break;
		case VK_F9:         _stprintf(out, _T("F9")); break;
		case VK_F10:        _stprintf(out, _T("F10")); break;
		case VK_F11:        _stprintf(out, _T("F11")); break;
		case VK_F12:        _stprintf(out, _T("F12")); break;
		case VK_F13:        _stprintf(out, _T("F13")); break;
		case VK_F14:        _stprintf(out, _T("F14")); break;
		case VK_F15:        _stprintf(out, _T("F15")); break;
		case VK_F16:        _stprintf(out, _T("F16")); break;
	}

	return out;
}

// Update which command is using which key
static int MHkeysUseUpdate()
{
	TCHAR tempTxt[MAX_PATH];
	unsigned int i;

	if (hMHkeysList == NULL) {
		return 1;
	}

	// Update the values of all the inputs
	for (i = 0; !lastCustomKey(customKeys[i]); i++) {
		CustomKey& key = customKeys[i];

		LVITEM LvItem;
		tempTxt[0] = '\0';

		if (key.keymod & MODKEY_CTRL)
			_tcscat(tempTxt, _T("Ctrl + "));
		if (key.keymod & MODKEY_ALT)
			_tcscat(tempTxt, _T("Alt + "));
		if (key.keymod & MODKEY_SHIFT)
			_tcscat(tempTxt, _T("Shift + "));

		_stprintf(tempTxt, _T("%s%s"), tempTxt, GetKeyName(key.key));

		if (!key.key)
			tempTxt[0] = '\0';

		memset(&LvItem, 0, sizeof(LvItem));
		LvItem.mask = LVIF_TEXT;
		LvItem.iItem = i;
		LvItem.iSubItem = 1;
		LvItem.pszText = tempTxt;

		SendMessage(hMHkeysList, LVM_SETITEM, 0, (LPARAM)&LvItem);
	}

	return 0;
}

static int MHkeysListBegin()
{
	LVCOLUMN LvCol;
	if (hMHkeysList == NULL) {
		return 1;
	}

	// Full row select style:
	SendMessage(hMHkeysList, LVM_SETEXTENDEDLISTVIEWSTYLE, 0, LVS_EX_FULLROWSELECT);

	// Make column headers
	memset(&LvCol, 0, sizeof(LvCol));
	LvCol.mask = LVCF_TEXT | LVCF_WIDTH | LVCF_SUBITEM;

	LvCol.cx = 164;
	LvCol.pszText = _T("Command");
	SendMessage(hMHkeysList, LVM_INSERTCOLUMN, 0, (LPARAM)&LvCol);

	LvCol.cx = 160;
	LvCol.pszText = _T("Mapped to");
	SendMessage(hMHkeysList, LVM_INSERTCOLUMN, 1, (LPARAM)&LvCol);

	return 0;
}

// Make a list view of the game inputs
int MHkeysListMake(int bBuild)
{
	unsigned int i;

	if (hMHkeysList == NULL) {
		return 1;
	}

	if (bBuild)	{
		SendMessage(hMHkeysList, LVM_DELETEALLITEMS, 0, 0);
	}

	// Add all the input names to the list
	for (i = 0; !lastCustomKey(customKeys[i]); i++) {
		CustomKey& key = customKeys[i];

		LVITEM LvItem;
		memset(&LvItem, 0, sizeof(LvItem));
		LvItem.mask = LVIF_TEXT | LVIF_PARAM;
		LvItem.iItem = i;
		LvItem.iSubItem = 0;
		LvItem.pszText = _AtoT(key.name);
		LvItem.lParam = (LPARAM)i;

		SendMessage(hMHkeysList, bBuild ? LVM_INSERTITEM : LVM_SETITEM, 0, (LPARAM)&LvItem);
	}

	MHkeysUseUpdate();

	return 0;
}

static int MHkeysInit()
{
	hMHkeysList = GetDlgItem(hMHkeysDlg, IDC_MHKEYS_LIST);

	MHkeysListBegin();
	MHkeysListMake(1);

	return 0;
}

static int MHkeysExit()
{
	hMHkeysList = NULL;
	hMHkeysDlg = NULL;

	UnhookWindowsHookEx(hook);
	hook = 0;

	return 0;
}

static LRESULT CALLBACK KeyMappingHook(int code, WPARAM wParam, LPARAM lParam)
{
	if (code < 0) {
		return CallNextHookEx(hook, code, wParam, lParam);
	}
	if (wParam == VK_SHIFT || wParam == VK_MENU || wParam == VK_CONTROL) {
		return CallNextHookEx(hook, code, wParam, lParam);
	}

	CustomKey& key = customKeys[receivingKmap];

	key.key = wParam;
	key.keymod = 0;
	if (KEY_DOWN(VK_CONTROL))
		key.keymod |= MODKEY_CTRL;
	if (KEY_DOWN(VK_MENU))
		key.keymod |= MODKEY_ALT;
	if (KEY_DOWN(VK_SHIFT))
		key.keymod |= MODKEY_SHIFT;

	MHkeysUseUpdate();

	UnhookWindowsHookEx(hook);
	hook = 0;

	SetWindowText(GetDlgItem(hMHkeysDlg, IDC_HKEYSS_STATIC), _T("Double-click a command to change its mapping"));
	return 1;
}

// List item(s) deleted; find out which one(s)
static int MHkeysItemDelete()
{
	int nStart = -1;
	LVITEM LvItem;
	int nRet;

	while ((nRet = SendMessage(hMHkeysList, LVM_GETNEXTITEM, (WPARAM)nStart, LVNI_SELECTED)) != -1) {
		nStart = nRet;

		// Get the corresponding input
		LvItem.mask = LVIF_PARAM;
		LvItem.iItem = nRet;
		LvItem.iSubItem = 0;
		SendMessage(hMHkeysList, LVM_GETITEM, 0, (LPARAM)&LvItem);
		nRet = LvItem.lParam;

		customKeys[nRet].key = 0;
		customKeys[nRet].keymod = 0;
	}

	MHkeysListMake(0);
	return 0;
}

// List item activated; find out which one
static int MHkeysItemActivate()
{
	char str [256];
	int nSel = SendMessage(hMHkeysList, LVM_GETNEXTITEM, (WPARAM)-1, LVNI_SELECTED);
	static HWND statusText;
	statusText = GetDlgItem(hMHkeysDlg, IDC_HKEYSS_STATIC);

	sprintf(str, "SETTING KEY: %s", customKeys[nSel].name);
	SetWindowText(statusText, _AtoT(str));
	receivingKmap = nSel;
	hook = SetWindowsHookEx(WH_KEYBOARD, KeyMappingHook, 0, GetCurrentThreadId());

	return 0;
}

static INT_PTR CALLBACK MHkeysDialogProc(HWND hDlg, UINT Msg, WPARAM wParam, LPARAM lParam)
{
	if (Msg == WM_INITDIALOG) {
		hMHkeysDlg = hDlg;
		MHkeysInit();
		WndInMid(hDlg, hScrnWnd);
		return TRUE;
	}

	if (Msg == WM_CLOSE) {
		EnableWindow(hScrnWnd, TRUE);
		DestroyWindow(hMHkeysDlg);
		return 0;
	}

	if (Msg == WM_DESTROY) {
		MHkeysExit();
		return 0;
	}

	if (Msg == WM_COMMAND) {
		int Id = LOWORD(wParam);
		int Notify = HIWORD(wParam);

		if (Id == IDOK && Notify == BN_CLICKED) {
			return 0;
		}
		else if (Id == IDCANCEL && Notify == BN_CLICKED) {
			SendMessage(hDlg, WM_CLOSE, 0, 0);
			return 0;
		}
	}

	if (Msg == WM_NOTIFY && lParam != 0) {
		int Id = LOWORD(wParam);
		NMHDR* pnm = (NMHDR*)lParam;

		if (Id == IDC_MHKEYS_LIST && pnm->code == LVN_ITEMACTIVATE) {
			MHkeysItemActivate();
		}
		else if (Id == IDC_MHKEYS_LIST && pnm->code == LVN_KEYDOWN) {
			NMLVKEYDOWN *pnmkd = (NMLVKEYDOWN*)lParam;
			if (pnmkd->wVKey == VK_DELETE) {
				MHkeysItemDelete();
			}
		}

		return 0;
	}

	return 0;
}

int MHkeysCreate()
{
	DestroyWindow(hMHkeysDlg); // Make sure exitted

	FBADialogBox(hAppInst, MAKEINTRESOURCE(IDD_MHKEYS), hScrnWnd, (DLGPROC)MHkeysDialogProc);
	if (hMHkeysDlg == NULL) {
		return 1;
	}

	ShowWindow(hMHkeysDlg, SW_NORMAL);

	return 0;
}

// ----------------------------------------------------------------------------

// key functions
extern bool UseDialogs();
extern void SimpleReinitScrn(const bool&);

void HK_callMenu(int)
{
	if (nVidFullscreen) {
		nVidFullscreen = 0;
		bMenuEnabled = true;
		POST_INITIALISE_MESSAGE;
	}
	else {
		bMenuEnabled = !bMenuEnabled;
		POST_INITIALISE_MESSAGE;
	}
}

void HK_pause(int)
{
	bRunPause^=1;
}

void HK_fastFowardKeyDown(int)
{
	bAppDoFast = 1;
}
void HK_fastFowardKeyUp(int)
{
	bAppDoFast = 0;
}

void HK_loadState(int param)
{
	StatedLoad(param);
}
void HK_saveState(int param)
{
	StatedSave(param);
}

void HK_prevState(int)
{
	nSavestateSlot--;
	if (nSavestateSlot < 1) {
		nSavestateSlot = 1;
	}

	TCHAR szString[MAX_PATH];
	_sntprintf(szString, sizearray(szString), FBALoadStringEx(hAppInst, IDS_STATE_ACTIVESLOT, true), nSavestateSlot);
	VidSNewShortMsg(szString);
	MenuEnableItems();
}
void HK_nextState(int)
{
	nSavestateSlot++;
	if (nSavestateSlot > 8) {
		nSavestateSlot = 8;
	}

	TCHAR szString[MAX_PATH];
	_sntprintf(szString, sizearray(szString), FBALoadStringEx(hAppInst, IDS_STATE_ACTIVESLOT, true), nSavestateSlot);
	VidSNewShortMsg(szString);
	MenuEnableItems();
}

void HK_selectState(int param)
{
	nSavestateSlot = param;
	TCHAR szString[MAX_PATH];
	_sntprintf(szString, sizearray(szString), FBALoadStringEx(hAppInst, IDS_STATE_ACTIVESLOT, true), nSavestateSlot);
	VidSNewShortMsg(szString);
	MenuEnableItems();
}

void HK_loadCurState(int)
{
	if (bDrvOkay && !kNetGame) {
		if (StatedLoad(nSavestateSlot) == 0) {
			VidSNewShortMsg(FBALoadStringEx(hAppInst, IDS_STATE_LOADED, true));
		} else {
			VidSNewShortMsg(FBALoadStringEx(hAppInst, IDS_STATE_LOAD_ERROR, true), 0xFF3F3F);
		}
	}
}
void HK_saveCurState(int)
{
	if (bDrvOkay) {
		if (StatedSave(nSavestateSlot) == 0) {
			VidSNewShortMsg(FBALoadStringEx(hAppInst, IDS_STATE_SAVED, true));
		} else {
			VidSNewShortMsg(FBALoadStringEx(hAppInst, IDS_STATE_SAVE_ERROR, true), 0xFF3F3F);
			SetPauseMode(1);
		}
	}
}

void HK_loadStateDialog(int)
{
	if (UseDialogs() && !kNetGame) {
		InputSetCooperativeLevel(false, bAlwaysProcessKeyboardInput);
		AudSoundStop();
		SplashDestroy(1);
		StatedLoad(0);
		GameInpCheckMouse();
		AudSoundPlay();
	}
}
void HK_saveStateDialog(int)
{
	if (UseDialogs()) {
		InputSetCooperativeLevel(false, bAlwaysProcessKeyboardInput);
		AudBlankSound();
		StatedSave(0);
		GameInpCheckMouse();
	}
}

void HK_playRec(int)
{
	if (UseDialogs()) {
		InputSetCooperativeLevel(false, bAlwaysProcessKeyboardInput);
		AudSoundStop();
		SplashDestroy(1);
		StopReplay();
		StartReplay();
		GameInpCheckMouse();
		AudSoundPlay();

		MenuEnableItems();
	}
}
void HK_startRec(int)
{
	if (UseDialogs() && nReplayStatus != 1) {
		InputSetCooperativeLevel(false, bAlwaysProcessKeyboardInput);
		AudBlankSound();
		StopReplay();
		StartRecord();
		GameInpCheckMouse();

		MenuEnableItems();
	}
}
void HK_stopRec(int)
{
	StopReplay();

	MenuEnableItems();
}
void HK_playFromBeginning(int)
{
	// TO-DO
}

void HK_startAvi(int)
{
	if (UseDialogs()) {
		AviBegin();
		MenuEnableItems();
	}
}
void HK_stopAvi(int)
{
	AviEnd();
	MenuEnableItems();
}

void HK_frameAdvance(int)
{
	if (!bRunPause)
		bRunPause = 1;
	bAppDoStep = 1;
}

void HK_toggleReadOnly(int)
{
	bReplayReadOnly^=1;
	if (bReplayReadOnly)
		VidSNewShortMsg(_T("read-only"));
	else
		VidSNewShortMsg(_T("read+write"));
}

void HK_frameCounter(int)
{
	bReplayFrameCounterDisplay = !bReplayFrameCounterDisplay;
	if (!bReplayFrameCounterDisplay)
		VidSKillTinyMsg();
}

void HK_speedInc(int)
{
	// TO-DO: fix this
	VidSNewTinyMsg(_T("disabled function"));
	return;

	if (kNetGame) {
		return;
	}

	if (nFpsScale < 10) {
		nFpsScale = 10;
	} else {
		if (nFpsScale >= 100) {
			nFpsScale += 50;
		} else {
			nFpsScale += 10;
		}
	}
	if (nFpsScale > 800) {
		nFpsScale = 800;
	}

	TCHAR buffer[15];
	_stprintf(buffer, _T("speed %02i %%"), nFpsScale);
	VidSNewShortMsg(buffer);

	MediaChangeFps(nFpsScale);
}
void HK_speedDec(int)
{
	// TO-DO: fix this
	VidSNewTinyMsg(_T("disabled function"));
	return;

	if (kNetGame) {
		return;
	}

	if (nFpsScale <= 10) {
		nFpsScale = 10;
	} else {
		if (nFpsScale > 100) {
			nFpsScale -= 50;
		} else {
			nFpsScale -= 10;
		}
	}
	if (nFpsScale < 10) {
		nFpsScale = 10;
	}

	TCHAR buffer[15];
	_stprintf(buffer, _T("speed %02i %%"), nFpsScale);
	VidSNewShortMsg(buffer);

	MediaChangeFps(nFpsScale);
}

void HK_speedNormal(int)
{
	nFpsScale = 100;
	bAppDoFast = 0;
	VidSNewShortMsg(_T("normal speed"));
	MediaChangeFps(nFpsScale);
}

void HK_speedTurbo(int)
{
	nFpsScale = 100;
	bAppDoFast = 1;
	VidSNewShortMsg(_T("turbo speed"));
	MediaChangeFps(nFpsScale);
}

void HK_volumeDec(int)
{
	nAudVolume -= 100;
	if (nAudVolume < 0) {
		nAudVolume = 0;
	}
	if (AudSoundSetVolume() != 0) {
		VidSNewShortMsg(FBALoadStringEx(hAppInst, IDS_SOUND_NOVOLUME, true));
	} else {
		TCHAR buffer[15];
		_stprintf(buffer, FBALoadStringEx(hAppInst, IDS_SOUND_VOLUMESET, true), nAudVolume / 100);
		VidSNewShortMsg(buffer);
	}
}
void HK_volumeInc(int)
{
	nAudVolume += 100;
	if (nAudVolume > 10000) {
		nAudVolume = 10000;
	}
	if (AudSoundSetVolume() != 0) {
		VidSNewShortMsg(FBALoadStringEx(hAppInst, IDS_SOUND_NOVOLUME, true));
	} else {
		TCHAR buffer[15];
		_stprintf(buffer, FBALoadStringEx(hAppInst, IDS_SOUND_VOLUMESET, true), nAudVolume / 100);
		VidSNewShortMsg(buffer);
	}
}

void HK_showFps(int)
{
	bShowFPS = !bShowFPS;
	if (bShowFPS)
		DisplayFPS();
	else {
		VidSKillShortMsg();
		VidSKillOSDMsg();
	}
}

void HK_configPad(int)
{
	if (UseDialogs()) {
		AudBlankSound();
		InputSetCooperativeLevel(false, false);
		InpdCreate();
	}
}

void HK_setDips(int)
{
	if (UseDialogs()) {
		AudBlankSound();
		InputSetCooperativeLevel(false, bAlwaysProcessKeyboardInput);
		InpDIPSWCreate();
	}
}

void HK_cheatEditor(int)
{
	if (UseDialogs()) {
		AudBlankSound();
		InputSetCooperativeLevel(false, bAlwaysProcessKeyboardInput);
		InpCheatCreate();
	}
}

void HK_ramSearch(int)
{
	if(!RamSearchHWnd)
	{
		reset_address_info();
		RamSearchHWnd = CreateDialog(hAppInst, MAKEINTRESOURCE(IDD_RAMSEARCH), NULL, (DLGPROC) RamSearchProc);
	}
	else
		SetForegroundWindow(RamSearchHWnd);
}

void HK_ramSearchOld(int)
{
	if (UseDialogs()) {
		AudBlankSound();
		InputSetCooperativeLevel(false, bAlwaysProcessKeyboardInput);
		CheatSearchCreate();
	}
}

void HK_ramWatch(int)
{
	if(!RamWatchHWnd)
	{
		RamWatchHWnd = CreateDialog(hAppInst, MAKEINTRESOURCE(IDD_RAMWATCH), NULL, (DLGPROC) RamWatchProc);
	}
	else
		SetForegroundWindow(RamWatchHWnd);
}

void HK_ramWatchOld(int)
{
	if (UseDialogs()) {
		InputSetCooperativeLevel(false, bAlwaysProcessKeyboardInput);
		CreateMemWatch();
	}
}



void HK_windowSize(int param)
{
	if (nWindowSize != param) {
		nWindowSize = param;
		SimpleReinitScrn(false);
		MenuEnableItems();
		POST_INITIALISE_MESSAGE;
	}
}
void HK_windowSizeMax(int)
{
	if (nWindowSize <= 4) {
		nWindowSize = 30;
		SimpleReinitScrn(false);
		MenuEnableItems();
		POST_INITIALISE_MESSAGE;
	}
}

void HK_fullscreen(int)
{
	if (bDrvOkay || nVidFullscreen) {
		nVidFullscreen = !nVidFullscreen;
		POST_INITIALISE_MESSAGE;
	}
}

void HK_screenShot(int)
{
	if (bDrvOkay) {
		int status = MakeScreenShot();
		if (!status) {
			VidSNewShortMsg(FBALoadStringEx(hAppInst, IDS_SSHOT_SAVED, true));
		} else {
			TCHAR tmpmsg[MAX_PATH];
			_sntprintf(tmpmsg, sizearray(tmpmsg), FBALoadStringEx(hAppInst, IDS_SSHOT_ERROR, true), status);
			VidSNewShortMsg(tmpmsg, 0xFF3F3F);
		}
	}
}
void HK_shotFactory(int)
{
	if (UseDialogs()) {
		AudBlankSound();
		InputSetCooperativeLevel(false, bAlwaysProcessKeyboardInput);
		SFactdCreate();
	}
}

extern bool bLoading;
extern int nActiveGame;
extern HWND hJukeboxDlg;
extern void UpdatePreviousGameList();

void HK_openGame(int)
{
	int nGame;

	if(kNetGame || !UseDialogs() || bLoading) {
		return;
	}

	SplashDestroy(1);
	StopReplay();

	InputSetCooperativeLevel(false, bAlwaysProcessKeyboardInput);

	bLoading = 1;
	AudSoundStop(); // Stop while the dialog is active or we're loading ROMs

	// This is needed in case NeoGeo slot loading is canceled
	if(bDrvOkay) {
		nActiveGame = nBurnDrvSelect;
	}

	nGame = SelDialog(0, hScrnWnd); // Bring up select dialog to pick a driver
	
	extern bool bDialogCancel;

	if (nGame >= 0 && bDialogCancel == false) {

		if(bJukeboxInUse == true) {
			DrvExit();
			bJukeboxInUse = true;
		}

		EndDialog(hJukeboxDlg, 0);

#if defined (INCLUDE_NEOGEO_MULTISLOT)
		//DrvExit();
		if (!bMVSMultiSlot) {
			DrvInit(nGame, true); // Init the game driver
		} else {
			if(!NeogeoSlotSelectCreate(hScrnWnd)) 
			{
				// [CANCEL button was pressed] get previous emulation state
				if(bDrvOkay) {
					nBurnDrvSelect = nActiveGame;
				}						
				GameInpCheckMouse();
				AudSoundPlay(); // Restart sound
				bLoading = 0;
				return;
			} else {
				// [OK button was pressed]
				// NEOGEO MVS SLOT STUFF GOES HERE
			}
		}
		MenuEnableItems();
		bAltPause = 0;
		AudSoundPlay(); // Restart sound
		bLoading = 0;
		if (!bMVSMultiSlot) {
			UpdatePreviousGameList();
			if (bVidAutoSwitchFull) {
				nVidFullscreen = 1;
				POST_INITIALISE_MESSAGE;
			}
		}
#else
		EndDialog(hJukeboxDlg, 0);
		DrvExit();
		DrvInit(nGame, true); // Init the game driver
		MenuEnableItems();
		bAltPause = 0;
		AudSoundPlay(); // Restart sound
		bLoading = 0;
		UpdatePreviousGameList();
		if (bVidAutoSwitchFull) {
			nVidFullscreen = 1;
			POST_INITIALISE_MESSAGE;
		}
#endif
		POST_INITIALISE_MESSAGE;
		return;
	} else {
		GameInpCheckMouse();
		AudSoundPlay(); // Restart sound
		bLoading = 0;
		return;
	}
}
void HK_gameInfo(int)
{
	if (bDrvOkay && UseDialogs()) {
		InputSetCooperativeLevel(false, bAlwaysProcessKeyboardInput);
		GameInfoDialogCreate(hScrnWnd, nBurnDrvSelect);
	}
}
void HK_exitGame(int)
{
	AudBlankSound();
	if (nVidFullscreen) {
		nVidFullscreen = 0;
		VidExit();
	}
	if (bDrvOkay) {
		bMVSMultiSlot = false;
		StopReplay();
		AviEnd();
		DrvExit();
		if (kNetGame) {
			kNetGame = 0;
			Kaillera_End_Game();
			DeActivateChat();
			PostQuitMessage(0);
		}
		bCheatsAllowed = true; // reenable cheats netplay has ended

		ScrnSize();
		ScrnTitle();
		MenuEnableItems();
		nDialogSelect = -1;
		nBurnDrvSelect = ~0U;

		POST_INITIALISE_MESSAGE;
	}
}

extern INT_PTR CALLBACK DlgLuaScriptDialog(HWND hDlg, UINT msg, WPARAM wParam, LPARAM lParam);

void HK_luaOpen(int)
{
	if (UseDialogs()) {
		if(!LuaConsoleHWnd) {
			InputSetCooperativeLevel(false, bAlwaysProcessKeyboardInput);
			LuaConsoleHWnd = CreateDialog(hAppInst, MAKEINTRESOURCE(IDD_LUA), NULL, (DLGPROC) DlgLuaScriptDialog);
		}
		else
			SetForegroundWindow(LuaConsoleHWnd);
	}
}
void HK_luaCloseAll(int)
{
	if(LuaConsoleHWnd)
		PostMessage(LuaConsoleHWnd, WM_CLOSE, 0, 0);
}
void HK_luaReload(int)
{
	FBA_ReloadLuaCode();
}
void HK_luaStop(int)
{
	FBA_LuaStop();
}

// key handle
static inline bool MHkeysCheckMenuState(const CustomKey* key)
{
	if (!key || (key->menuid > 0 && GetMenuState(hMenu, key->menuid, MF_BYCOMMAND) == MF_GRAYED)) {
		return false;
	}
	return true;
}

int MHkeysDownHandle(const MSG& Msg)
{
	static int key = 0;
	static int modifiers = 0;
	static int processed = 0;

	key = Msg.wParam;
	modifiers = 0;
	if (KEY_DOWN(VK_CONTROL)) {
		modifiers |= MODKEY_CTRL;
	}
	if (KEY_DOWN(VK_MENU)) {
		modifiers |= MODKEY_ALT;
	}
	if (KEY_DOWN(VK_SHIFT)) {
		modifiers |= MODKEY_SHIFT;
	}

	processed = 0;

	CustomKey* customkey = &customKeys[0];
	while (!lastCustomKey(*customkey)) {
		if (key == customkey->key && modifiers == customkey->keymod && customkey->handleKeyDown) {
			if (MHkeysCheckMenuState(customkey)) {
				customkey->handleKeyDown(customkey->param);
				processed = 1;
			}
		}
		customkey++;
	}

	return processed;
}

int MHkeysUpHandle(const MSG& Msg)
{
	static int key = 0;
	static int modifiers = 0;
	static int processed = 0;

	key = Msg.wParam;
	modifiers = 0;
	if (KEY_DOWN(VK_CONTROL)) {
		modifiers |= MODKEY_CTRL;
	}
	if (KEY_DOWN(VK_MENU)) {
		modifiers |= MODKEY_ALT;
	}
	if (KEY_DOWN(VK_SHIFT)) {
		modifiers |= MODKEY_SHIFT;
	}

	processed = 0;

	CustomKey* customkey = &customKeys[0];
	while (!lastCustomKey(*customkey)) {
		if (customkey->handleKeyUp && key == customkey->key && modifiers == customkey->keymod) {
			customkey->handleKeyUp(customkey->param);
			processed = 1;
		}
		customkey++;
	}

	return processed;
}
