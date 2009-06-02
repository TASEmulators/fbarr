#include "burner.h"

extern int bImageOrientation;

static HWND hGameInfoDlg	= NULL;
static HWND hParent			= NULL;
static HWND hTabControl		= NULL;
static HMODULE hRiched		= NULL;
static HBITMAP hPreview		= NULL;
HBITMAP hGiBmp				= NULL;
static TCHAR szFullName[1024];
static int nGiDriverSelected;
static HBRUSH hWhiteBGBrush;

static void SetPreview(TCHAR* szPreviewDir) {

	HWND hDlg = hGameInfoDlg;

	HBITMAP hNewImage	= NULL;
	TCHAR	szFDriver[MAX_PATH] = _T(""), szDrvName[MAX_PATH] = _T(""), szDrvParent[MAX_PATH] = _T(""), szDrvBoard[MAX_PATH] = _T("") ;
	bool	bLoadPNG	= false;
	bool	bLoadZipPNG = false;
	bool	bParent		= false;
	bool	bBoard		= false;

	// Check if we can get the values and proceed (FBA will crash if used incorrecly)
	if(BurnDrvGetText(DRV_NAME)) _stprintf(szDrvName, BurnDrvGetText(DRV_NAME));
	if(BurnDrvGetText(DRV_PARENT)) bParent = true;
	if(BurnDrvGetText(DRV_BOARDROM)) bBoard = true;
	if(bParent) _stprintf(szDrvParent, BurnDrvGetText(DRV_PARENT));
	if(bBoard) _stprintf(szDrvBoard, BurnDrvGetText(DRV_BOARDROM));

	if (hGiBmp) {
		DeleteObject((HGDIOBJ)hGiBmp);
		hGiBmp = NULL;
	}
	
	do {

		// ============================================================
		// Load PNG from directory

		if(!CheckFile(szDrvName, szPreviewDir, _T(".png"))) 
		{	
			_stprintf(szFDriver, szDrvName);
			bLoadPNG = true;
			break;
		}

		if(bParent) {
			if(!CheckFile(szDrvParent, szPreviewDir, _T(".png"))) 
			{	
				_stprintf(szFDriver, szDrvParent);
				bLoadPNG = true;
				break;
			}
		}

		if(bBoard) {
			if(!CheckFile(szDrvBoard, szPreviewDir, _T(".png"))) 
			{ 
				_stprintf(szFDriver, szDrvBoard);
				bLoadPNG = true;
				break;
			}
		}

		// ============================================================
		// Load PNG from ZIP

		if(!CheckZipFile(szDrvName,	szPreviewDir, _T(".png"))) 
		{	
			_stprintf(szFDriver, szDrvName);
			bLoadPNG = true; 
			bLoadZipPNG = true;
			break;
		}

		if(bParent) {
			if(!CheckZipFile(szDrvParent, szPreviewDir, _T(".png"))) 
			{	
				_stprintf(szFDriver, szDrvParent);
				bLoadPNG = true; 
				bLoadZipPNG = true;
				break;
			}
		}

		if(bBoard) {
			if(!CheckZipFile(szDrvBoard, szPreviewDir, _T(".png"))) 
			{ 
				_stprintf(szFDriver, szDrvBoard);
				bLoadPNG = true; 
				bLoadZipPNG = true;
				break;
			}
		}

		if(!bLoadPNG) break;

	} while (!bLoadPNG);

	if (bLoadPNG) {

		char szTemp[2][MAX_PATH];		
		sprintf(szTemp[0], _TtoA(szPreviewDir));
		sprintf(szTemp[1], _TtoA(szFDriver));			

		// Load PNG from ZIP if we can't get a handle from the directory file
		if(bLoadZipPNG) {
			hNewImage = PNGtoBMP(hDlg, szTemp[0], szTemp[1], FBA_LM_ZIP_BUFF, 400, 500);
		} else {
			hNewImage = PNGtoBMP(hDlg, szTemp[0], szTemp[1], FBA_LM_FILE, 400, 500);
		}
	}

	if (hNewImage) {

		if(hGiBmp) DeleteObject((HGDIOBJ)hGiBmp);

		hGiBmp = hNewImage;

		if (bImageOrientation == 0) {
			SendDlgItemMessage(hDlg, IDC_SCREENSHOT_H, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)hGiBmp);
			SendDlgItemMessage(hDlg, IDC_SCREENSHOT_V, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)NULL);
			ShowWindow(GetDlgItem(hDlg, IDC_SCREENSHOT_V), SW_HIDE);
		} else {
			SendDlgItemMessage(hDlg, IDC_SCREENSHOT_H, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)NULL);
			ShowWindow(GetDlgItem(hDlg, IDC_SCREENSHOT_V), SW_SHOW);
			SendDlgItemMessage(hDlg, IDC_SCREENSHOT_V, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)hGiBmp);
		}

	} else {
		SendDlgItemMessage(hDlg, IDC_SCREENSHOT_H, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)LoadBitmap(hAppInst, MAKEINTRESOURCE(BMP_PREVIEW_ALT)));
		SendDlgItemMessage(hDlg, IDC_SCREENSHOT_V, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)NULL);
		ShowWindow(GetDlgItem(hDlg, IDC_SCREENSHOT_V), SW_HIDE);
	}
}

static int DisplayRomInfo()
{
	ShowWindow(GetDlgItem(hGameInfoDlg, IDC_SCREENSHOT_H), SW_HIDE);
	ShowWindow(GetDlgItem(hGameInfoDlg, IDC_MESSAGE_EDIT_ENG), SW_HIDE);
	ShowWindow(GetDlgItem(hGameInfoDlg, IDC_LIST1), SW_SHOW);
	UpdateWindow(hGameInfoDlg);
	
	return 0;
}

static int DisplayHistory()
{
	ShowWindow(GetDlgItem(hGameInfoDlg, IDC_SCREENSHOT_H), SW_HIDE);
	ShowWindow(GetDlgItem(hGameInfoDlg, IDC_LIST1), SW_HIDE);
	ShowWindow(GetDlgItem(hGameInfoDlg, IDC_MESSAGE_EDIT_ENG), SW_SHOW);
	UpdateWindow(hGameInfoDlg);
	
	return 0;
}

static int GameInfoInit()
{
	// Get the games full name
	TCHAR szText[1024] = _T("");
	TCHAR* pszPosition = szText;
	TCHAR* pszName = BurnDrvGetText(DRV_FULLNAME);

	pszPosition += _sntprintf(szText, 1024, pszName);
	
	pszName = BurnDrvGetText(DRV_FULLNAME);
	while ((pszName = BurnDrvGetText(DRV_NEXTNAME | DRV_FULLNAME)) != NULL) {
		if (pszPosition + _tcslen(pszName) - 1024 > szText) {
			break;
		}
		pszPosition += _stprintf(pszPosition, _T(SEPERATOR_2) _T("%s"), pszName);
	}
	
	_tcscpy(szFullName, szText);
	
	_stprintf(szText, _T("%s") _T(SEPERATOR_1) _T("%s"), FBALoadStringEx(hAppInst, IDS_GAMEINFO_DIALOGTITLE, true), szFullName);
	
	// Set the window caption
	SetWindowText(hGameInfoDlg, szText);
	
	// Setup the tabs
	hTabControl = GetDlgItem(hGameInfoDlg, IDC_TAB1);
    TC_ITEM TCI; 
    TCI.mask = TCIF_TEXT; 

	UINT idsString[15] = {IDS_GAMEINFO_INGAME, IDS_GAMEINFO_TITLE, IDS_GAMEINFO_SELECT, IDS_GAMEINFO_VERSUS, IDS_GAMEINFO_HOWTO, IDS_GAMEINFO_SCORES, IDS_GAMEINFO_BOSSES, IDS_GAMEINFO_GAMEOVER, IDS_GAMEINFO_FLYER, IDS_GAMEINFO_CABINET, IDS_GAMEINFO_MARQUEE, IDS_GAMEINFO_CONTROLS, IDS_GAMEINFO_PCB , IDS_GAMEINFO_ROMINFO, IDS_GAMEINFO_HISTORY };
	
	for(int i = 0; i < 15; i++) {
		TCI.pszText = FBALoadStringEx(hAppInst, idsString[i], true);
		SendMessage(hTabControl, TCM_INSERTITEM, (WPARAM) i, (LPARAM) &TCI);
	}

	// Load the preview image
	hPreview = LoadBitmap(hAppInst, MAKEINTRESOURCE(BMP_PREVIEW_ALT));
	
	// Display preview image
	SendDlgItemMessage(hGameInfoDlg, IDC_SCREENSHOT_H, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)NULL);
	SendDlgItemMessage(hGameInfoDlg, IDC_SCREENSHOT_V, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)NULL);

	ShowWindow(GetDlgItem(hGameInfoDlg, IDC_LIST1), SW_HIDE);
	ShowWindow(GetDlgItem(hGameInfoDlg, IDC_MESSAGE_EDIT_ENG), SW_HIDE);
	ShowWindow(GetDlgItem(hGameInfoDlg, IDC_SCREENSHOT_H), SW_SHOW);
	ShowWindow(GetDlgItem(hGameInfoDlg, IDC_SCREENSHOT_V), SW_SHOW);
	UpdateWindow(hGameInfoDlg);

	nBurnDrvSelect = nGiDriverSelected;
	SetPreview(szAppPreviewsPath);
	
	// Display the game title
	TCHAR szItemText[1024];
	HWND hInfoControl = GetDlgItem(hGameInfoDlg, IDC_TEXTCOMMENT);
	SendMessage(hInfoControl, WM_SETTEXT, (WPARAM)0, (LPARAM)szFullName);
	
	// Display the romname
	bool bBracket = false;
	hInfoControl = GetDlgItem(hGameInfoDlg, IDC_TEXTROMNAME);
	_stprintf(szItemText, _T("%s"), BurnDrvGetText(DRV_NAME));
	if ((BurnDrvGetFlags() & BDF_CLONE) && BurnDrvGetTextA(DRV_PARENT)) {
		int nOldDrvSelect = nBurnDrvSelect;
		pszName = BurnDrvGetText(DRV_PARENT);

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
	SendMessage(hInfoControl, WM_SETTEXT, (WPARAM)0, (LPARAM)szItemText);
	
	//Display the rom info
	bool bUseInfo = false;
	szItemText[0] = _T('\0');
	hInfoControl = GetDlgItem(hGameInfoDlg, IDC_TEXTROMINFO);
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
		SendMessage(hInfoControl, WM_SETTEXT, (WPARAM)0, (LPARAM)szItemText);
		bUseInfo = true;
	}
	SendMessage(hInfoControl, WM_SETTEXT, (WPARAM)0, (LPARAM)szItemText);
	
	// Display the release info
	szItemText[0] = _T('\0');
	hInfoControl = GetDlgItem(hGameInfoDlg, IDC_TEXTSYSTEM);
	_stprintf(szItemText, _T("%s (%s, %s hardware)"), BurnDrvGetTextA(DRV_MANUFACTURER) ? BurnDrvGetText(DRV_MANUFACTURER) : _T("unknown"), BurnDrvGetText(DRV_DATE), ((BurnDrvGetHardwareCode() & HARDWARE_SNK_MVSCARTRIDGE) == HARDWARE_SNK_MVSCARTRIDGE) ? _T("Neo Geo MVS Cartidge") : BurnDrvGetText(DRV_SYSTEM));
	SendMessage(hInfoControl, WM_SETTEXT, (WPARAM)0, (LPARAM)szItemText);
	
	// Display any comments
	szItemText[0] = _T('\0');
	hInfoControl = GetDlgItem(hGameInfoDlg, IDC_TEXTNOTES);
	_stprintf(szItemText, _T("%s"), BurnDrvGetTextA(DRV_COMMENT) ? BurnDrvGetText(DRV_COMMENT) : _T(""));
	if (BurnDrvGetFlags() & BDF_HISCORE_SUPPORTED) {
		_stprintf(szItemText + _tcslen(szItemText), _T("%shigh scores supported"), _tcslen(szItemText) ? _T(", ") : _T(""));
	}
	SendMessage(hInfoControl, WM_SETTEXT, (WPARAM)0, (LPARAM)szItemText);
	
	// Display the genre
	szItemText[0] = _T('\0');
	hInfoControl = GetDlgItem(hGameInfoDlg, IDC_TEXTGENRE);
	_stprintf(szItemText, _T("%s"), DecorateGenreInfo());
	SendMessage(hInfoControl, WM_SETTEXT, (WPARAM)0, (LPARAM)szItemText);
	
	// Set up the rom info list
	HWND hList = GetDlgItem(hGameInfoDlg, IDC_LIST1);
	LV_COLUMN LvCol;
	LV_ITEM LvItem;
	
	ListView_SetExtendedListViewStyle(hList, LVS_EX_FULLROWSELECT);
	
	memset(&LvCol, 0, sizeof(LvCol));
	LvCol.mask = LVCF_TEXT | LVCF_WIDTH | LVCF_SUBITEM;
	LvCol.cx = 200;
	LvCol.pszText = _T("Name");	
	SendMessage(hList, LVM_INSERTCOLUMN , 0, (LPARAM)&LvCol);
	LvCol.cx = 100;
	LvCol.pszText = _T("Size (bytes)");	
	SendMessage(hList, LVM_INSERTCOLUMN , 1, (LPARAM)&LvCol);
	LvCol.cx = 100;
	LvCol.pszText = _T("CRC32");	
	SendMessage(hList, LVM_INSERTCOLUMN , 2, (LPARAM)&LvCol);
	LvCol.cx = 200;
	LvCol.pszText = _T("Type");	
	SendMessage(hList, LVM_INSERTCOLUMN , 3, (LPARAM)&LvCol);
	LvCol.cx = 100;
	LvCol.pszText = _T("Flags");	
	SendMessage(hList, LVM_INSERTCOLUMN , 4, (LPARAM)&LvCol);
	LvCol.cx = 100;
	
	memset(&LvItem, 0, sizeof(LvItem));
	LvItem.mask=  LVIF_TEXT;
	LvItem.cchTextMax = 256;
	int RomPos = 0;
	for (int i = 0; i < 0x100; i++) { // assume max 0x100 roms per game
		int nRet;
		struct BurnRomInfo ri;
		char nLen[10] = "";
		char nCrc[8] = "";
		char *szRomName = NULL;
		char Type[100] = "";
		char FormatType[100] = "";

		memset(&ri, 0, sizeof(ri));

		nRet = BurnDrvGetRomInfo(&ri, i);
		nRet += BurnDrvGetRomName(&szRomName, i, 0);
		
		if (ri.nLen == 0) continue;		
		if (ri.nType & BRF_BIOS) continue;
		
		LvItem.iItem = RomPos;
		LvItem.iSubItem = 0;
		LvItem.pszText = ANSIToTCHAR(szRomName, NULL, 0);
		SendMessage(hList, LVM_INSERTITEM, 0, (LPARAM)&LvItem);
		
		sprintf(nLen, "%d", ri.nLen);
		LvItem.iSubItem = 1;
		LvItem.pszText = ANSIToTCHAR(nLen, NULL, 0);
		SendMessage(hList, LVM_SETITEM, 0, (LPARAM)&LvItem);
		
		sprintf(nCrc, "%08X", ri.nCrc);
		if (!(ri.nType & BRF_NODUMP)) {
			LvItem.iSubItem = 2;
			LvItem.pszText = ANSIToTCHAR(nCrc, NULL, 0);
			SendMessage(hList, LVM_SETITEM, 0, (LPARAM)&LvItem);
		}
		
		if (ri.nType & BRF_ESS) sprintf(Type, "%s, Essential", Type);
		if (ri.nType & BRF_OPT) sprintf(Type, "%s, Optional", Type);
		if (ri.nType & BRF_PRG)	sprintf(Type, "%s, Program", Type);
		if (ri.nType & BRF_GRA) sprintf(Type, "%s, Graphics", Type);
		if (ri.nType & BRF_SND) sprintf(Type, "%s, Sound", Type);
		if (ri.nType & BRF_BIOS) sprintf(Type, "%s, BIOS", Type);
		
		for (int j = 0; j < 98; j++) {
			FormatType[j] = Type[j + 2];
		}
		
		LvItem.iSubItem = 3;
		LvItem.pszText = ANSIToTCHAR(FormatType, NULL, 0);
		SendMessage(hList, LVM_SETITEM, 0, (LPARAM)&LvItem);
		
		LvItem.iSubItem = 4;
		LvItem.pszText = _T("");
		if (ri.nType & BRF_NODUMP) LvItem.pszText = _T("No Dump");
		SendMessage(hList, LVM_SETITEM, 0, (LPARAM)&LvItem);
		
		RomPos++;
	}
	
	// Check for board roms
	if (BurnDrvGetTextA(DRV_BOARDROM)) {
		char szBoardName[8] = "";
		unsigned int nOldDrvSelect = nBurnDrvSelect;
		strcpy(szBoardName, BurnDrvGetTextA(DRV_BOARDROM));
			
		for (unsigned int i = 0; i < nBurnDrvCount; i++) {
			nBurnDrvSelect = i;
			if (!strcmp(szBoardName, BurnDrvGetTextA(DRV_NAME))) break;
		}
			
		for (int j = 0; j < 0x100; j++) {
			int nRetBoard;
			struct BurnRomInfo riBoard;
			char nLenBoard[10] = "";
			char nCrcBoard[8] = "";
			char *szBoardRomName = NULL;
			char BoardType[100] = "";
			char BoardFormatType[100] = "";

			memset(&riBoard, 0, sizeof(riBoard));

			nRetBoard = BurnDrvGetRomInfo(&riBoard, j);
			nRetBoard += BurnDrvGetRomName(&szBoardRomName, j, 0);
		
			if (riBoard.nLen == 0) continue;
				
			LvItem.iItem = RomPos;
			LvItem.iSubItem = 0;
			LvItem.pszText = ANSIToTCHAR(szBoardRomName, NULL, 0);
			SendMessage(hList, LVM_INSERTITEM, 0, (LPARAM)&LvItem);
		
			sprintf(nLenBoard, "%d", riBoard.nLen);
			LvItem.iSubItem = 1;
			LvItem.pszText = ANSIToTCHAR(nLenBoard, NULL, 0);
			SendMessage(hList, LVM_SETITEM, 0, (LPARAM)&LvItem);
		
			sprintf(nCrcBoard, "%08X", riBoard.nCrc);
			if (!(riBoard.nType & BRF_NODUMP)) {
				LvItem.iSubItem = 2;
				LvItem.pszText = ANSIToTCHAR(nCrcBoard, NULL, 0);
				SendMessage(hList, LVM_SETITEM, 0, (LPARAM)&LvItem);
			}
			
			if (riBoard.nType & BRF_ESS) sprintf(BoardType, "%s, Essential", BoardType);
			if (riBoard.nType & BRF_OPT) sprintf(BoardType, "%s, Optional", BoardType);
			if (riBoard.nType & BRF_PRG) sprintf(BoardType, "%s, Program", BoardType);
			if (riBoard.nType & BRF_GRA) sprintf(BoardType, "%s, Graphics", BoardType);
			if (riBoard.nType & BRF_SND) sprintf(BoardType, "%s, Sound", BoardType);
			if (riBoard.nType & BRF_BIOS) sprintf(BoardType, "%s, BIOS", BoardType);
		
			for (int k = 0; k < 98; k++) {
				BoardFormatType[k] = BoardType[k + 2];
			}
		
			LvItem.iSubItem = 3;
			LvItem.pszText = ANSIToTCHAR(BoardFormatType, NULL, 0);
			SendMessage(hList, LVM_SETITEM, 0, (LPARAM)&LvItem);
		
			LvItem.iSubItem = 4;
			LvItem.pszText = _T("");
			if (riBoard.nType & BRF_NODUMP) LvItem.pszText = _T("No Dump");
			SendMessage(hList, LVM_SETITEM, 0, (LPARAM)&LvItem);
			
			RomPos++;
		}
		
		nBurnDrvSelect = nOldDrvSelect;
	}
	
	// Get the history info
	CHAR szFileName[MAX_PATH] = "";
	sprintf(szFileName, "%shistory.dat", TCHARToANSI(szAppHistoryPath, NULL, 0));
	
	FILE *fp = fopen(szFileName, "rt");	
	char Temp[1000];
	int inGame = 0;
	TCHAR szBuffer[50000] = _T("{\\rtf1\\ansi{\\fonttbl(\\f0\\fswiss\\fprq2 Tahoma;)}{\\colortbl;\\red0\\green0\\blue0;\\red110\\green107\\blue106;}");
	
	if (fp) {		
		while (!feof(fp)) {
			char *Tokens;
			
			fgets(Temp, 1000, fp);
			if (!strncmp("$info=", Temp, 6)) {
				Tokens = strtok(Temp, "=,");
				while (Tokens != NULL) {
					if (!strcmp(Tokens, BurnDrvGetTextA(DRV_NAME))) {
						inGame = 1;
						break;
					}

					Tokens = strtok(NULL, "=,");
				}
			}
			
			if (inGame) {
				int nTitleWrote = 0;
				while (strncmp("$end", Temp, 4)) {
					fgets(Temp, 1000, fp);

					if (!strncmp("$", Temp, 1)) continue;
					if (!strncmp("\n", Temp, 1)) _stprintf(szBuffer, _T("%s\\par"), szBuffer);
						
					if (!nTitleWrote) {
						_stprintf(szBuffer, _T("%s{\\b\\f0\\fs28\\cf1 %s}"), szBuffer, ANSIToTCHAR(Temp, NULL, 0));
					} else {
						if (!strncmp("- ", Temp, 2)) {
							_stprintf(szBuffer, _T("%s{\\b\\f0\\fs16\\cf1 %s}"), szBuffer, ANSIToTCHAR(Temp, NULL, 0));
						} else {
							_stprintf(szBuffer, _T("%s{\\f0\\fs16\\cf2 %s}"), szBuffer, ANSIToTCHAR(Temp, NULL, 0));
						}
					}
						
					if (strcmp("\n", Temp)) nTitleWrote = 1;
				}
				break;
			}
		}
		fclose(fp);
	}
	
	_stprintf(szBuffer, _T("%s}"), szBuffer);
	SendMessage(GetDlgItem(hGameInfoDlg, IDC_MESSAGE_EDIT_ENG), WM_SETTEXT, (WPARAM)0, (LPARAM)szBuffer);
	
	// Make a white brush
	hWhiteBGBrush = CreateSolidBrush(RGB(0xFF,0xFF,0xFF));
	
	return 0;
}

static void MyEndDialog()
{
	SendDlgItemMessage(hGameInfoDlg, IDC_SCREENSHOT_H, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)NULL);
	SendDlgItemMessage(hGameInfoDlg, IDC_SCREENSHOT_V, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)NULL);
	
	if (hGiBmp) {
		DeleteObject((HGDIOBJ)hGiBmp);
		hGiBmp = NULL;
	}
	if (hPreview) {
		DeleteObject((HGDIOBJ)hPreview);
		hPreview = NULL;
	}
	
	hTabControl = NULL;
	memset(szFullName, 0, 1024);
	
	EndDialog(hGameInfoDlg, 0);
}

static BOOL CALLBACK DialogProc(HWND hDlg, UINT Msg, WPARAM wParam, LPARAM lParam)
{
	if (Msg == WM_INITDIALOG) {
		hGameInfoDlg = hDlg;

		if (bDrvOkay) {
			if (!kNetGame && bAutoPause) bRunPause = 1;
			AudSoundStop();
		}
		
		GameInfoInit();

		WndInMid(hDlg, hParent);
		SetFocus(hDlg);											// Enable Esc=close

		return TRUE;
	}
	
	if (Msg == WM_CLOSE) {
		MyEndDialog();
		DeleteObject(hWhiteBGBrush);
		
		EnableWindow(hScrnWnd, TRUE);
		DestroyWindow(hGameInfoDlg);
		
		FreeLibrary(hRiched);
		hRiched = NULL;
		
		if (bDrvOkay) {
			if(!bAltPause && bRunPause) bRunPause = 0;
			AudSoundPlay();
		}
		
		return 0;
	}

	if (Msg == WM_COMMAND) {
		int Id = LOWORD(wParam);
		int Notify = HIWORD(wParam);
		
		if (Id == IDCANCEL && Notify == BN_CLICKED) {
			SendMessage(hGameInfoDlg, WM_CLOSE, 0, 0);
			return 0;
		}
	}
	
	if (Msg == WM_NOTIFY) {
		NMHDR* pNmHdr = (NMHDR*)lParam;

		if (pNmHdr->code == TCN_SELCHANGE) {
			int TabPage = TabCtrl_GetCurSel(hTabControl);
			
			ShowWindow(GetDlgItem(hGameInfoDlg, IDC_LIST1), SW_HIDE);
			ShowWindow(GetDlgItem(hGameInfoDlg, IDC_MESSAGE_EDIT_ENG), SW_HIDE);
			ShowWindow(GetDlgItem(hGameInfoDlg, IDC_SCREENSHOT_H), SW_SHOW);
			ShowWindow(GetDlgItem(hGameInfoDlg, IDC_SCREENSHOT_V), SW_SHOW);
			UpdateWindow(hGameInfoDlg);
			
			nBurnDrvSelect = nGiDriverSelected;

			if (TabPage == 0)  { SetPreview(szAppPreviewsPath);	}
			if (TabPage == 1)  { SetPreview(szAppTitlesPath);	}
			if (TabPage == 2)  { SetPreview(szAppSelectPath);	}
			if (TabPage == 3)  { SetPreview(szAppVersusPath);	}
			if (TabPage == 4)  { SetPreview(szAppHowtoPath);	}
			if (TabPage == 5)  { SetPreview(szAppScoresPath);	}
			if (TabPage == 6)  { SetPreview(szAppBossesPath);	}
			if (TabPage == 7)  { SetPreview(szAppGameoverPath);	}
			if (TabPage == 8)  { SetPreview(szAppFlyersPath);	}
			if (TabPage == 9)  { SetPreview(szAppCabinetsPath);	}
			if (TabPage == 10) { SetPreview(szAppMarqueesPath);	}
			if (TabPage == 11) { SetPreview(szAppControlsPath);	}
			if (TabPage == 12) { SetPreview(szAppPCBsPath);		}
			if (TabPage == 13) DisplayRomInfo();
			if (TabPage == 14) DisplayHistory();

			return FALSE;
		}
	}
	
	if (Msg == WM_CTLCOLORSTATIC) {
		if ((HWND)lParam == GetDlgItem(hGameInfoDlg, IDC_LABELCOMMENT) || (HWND)lParam == GetDlgItem(hGameInfoDlg, IDC_LABELROMNAME) || (HWND)lParam == GetDlgItem(hGameInfoDlg, IDC_LABELROMINFO) || (HWND)lParam == GetDlgItem(hGameInfoDlg, IDC_LABELSYSTEM) || (HWND)lParam == GetDlgItem(hGameInfoDlg, IDC_LABELNOTES) || (HWND)lParam == GetDlgItem(hGameInfoDlg, IDC_LABELGENRE) || (HWND)lParam == GetDlgItem(hGameInfoDlg, IDC_TEXTCOMMENT) || (HWND)lParam == GetDlgItem(hGameInfoDlg, IDC_TEXTROMNAME) || (HWND)lParam == GetDlgItem(hGameInfoDlg, IDC_TEXTROMINFO) || (HWND)lParam == GetDlgItem(hGameInfoDlg, IDC_TEXTSYSTEM) || (HWND)lParam == GetDlgItem(hGameInfoDlg, IDC_TEXTNOTES) || (HWND)lParam == GetDlgItem(hGameInfoDlg, IDC_TEXTGENRE)) {
			return (BOOL)hWhiteBGBrush;
		}
	}

	return 0;
}

int GameInfoDialogCreate(HWND hParentWND, int nDrvSel)
{
	bGameInfoOpen = true;
	nGiDriverSelected = nDrvSel;

#if defined (_UNICODE)
	hRiched = LoadLibrary(L"RICHED20.DLL");
#else
	hRiched = LoadLibrary("RICHED20.DLL");
#endif

	if (hRiched) {
		hParent = hParentWND;
		FBADialogBox(hAppInst, MAKEINTRESOURCE(IDD_GAMEINFO), hParent, DialogProc);
	}

	bGameInfoOpen = false;
	return 0;
}
