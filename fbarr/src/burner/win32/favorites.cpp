#include "burner.h"
#include <shellapi.h>
#include <shlwapi.h>

#define ASCIIONLY		(1 << 19)

extern HWND hSelDlg;

HWND	listView					= NULL;		// Favorite Gamelist Control Handle
HWND	hTabControl3				= NULL;		// [IDC_TAB3] GameList & Favorites Gamelist tabs control
int		nFavorites					= 0;
TCHAR	szFavoritesDat[MAX_PATH]	= _T("");
bool	bFavSelected				= false;
int columnIndex						= 0;
BOOL isAscendingOrder				= TRUE;

#ifndef HDF_SORTUP
#define HDF_SORTUP              0x0400
#endif

#ifndef HDF_SORTDOWN
#define HDF_SORTDOWN            0x0200
#endif

void InsertTabs() 
{
	// Insert Tabs
	TC_ITEM TCI; 
	TCI.mask = TCIF_TEXT;

	// GAME LIST
	TCI.pszText = _T("Games List");
	SendMessage(hTabControl3, TCM_INSERTITEM, (WPARAM) 0, (LPARAM) &TCI); 

	// FAVORITE GAMELIST
	TCI.pszText = _T("Favorite Games List");
	SendMessage(hTabControl3, TCM_INSERTITEM, (WPARAM) 1, (LPARAM) &TCI);
}

void DisplayControls(int TabSelected, int TabControl) 
{
	TabControl = 0; // Not used in this implementation

	switch(TabSelected) 
	{
		// Game selection list
		case 0:
			// Hide the following controls in this Tab:
			ShowWindow(GetDlgItem(hSelDlg, IDC_FAVLIST), SW_HIDE);							// Favorites Gamelist

			// Show this ones:
			EnableWindow(GetDlgItem(hSelDlg, IDC_TREE1), TRUE);								// Enable the Gamelist
			AnimateWindow(GetDlgItem(hSelDlg, IDC_TREE1), 400, AW_HOR_POSITIVE | SW_SHOW);
			nFavorites = 0;
			break;

		// Favorite games selection list
		case 1:
			// Hide the following controls in this Tab:
			ShowWindow(GetDlgItem(hSelDlg, IDC_TREE1), SW_HIDE);							// Gamelist
			EnableWindow(GetDlgItem(hSelDlg, IDC_TREE1), FALSE);							// Disable the Gamelist

			// Show this ones:
			AnimateWindow(GetDlgItem(hSelDlg, IDC_FAVLIST), 400, AW_HOR_POSITIVE | SW_SHOW); // Favorites Gamelist
			nFavorites = 1;				
			break;
	}	
}

// Favorites Games List Compare function
int CALLBACK ListView_CompareFunc(LPARAM index1, LPARAM index2, LPARAM param)
{
	HWND listview = (HWND)param;
	TCHAR itemText1[256] = _T(""), itemText2[256] = _T("");	
	LVITEM lvi;

	// FIRST ROW
	//------------------------------------------------------
	lvi.pszText = itemText1;
	lvi.cchTextMax = 256;
	lvi.iSubItem = columnIndex;
	SendMessage(
		listview,			// Favorite Games List
		LVM_GETITEMTEXT,	// Get item text
		(WPARAM)index1,		// iItem / Row from list
		(LPARAM)&lvi		// ListView Item struct
	);

	// SECOND ROW
	//------------------------------------------------------
	lvi.pszText = itemText2;
	lvi.cchTextMax = 256;
	lvi.iSubItem = columnIndex;
	SendMessage(
		listview,			// Favorite Games List
		LVM_GETITEMTEXT,	// Get item text
		(WPARAM)index2,		// iItem / Row from list
		(LPARAM)&lvi		// ListView Item struct
	);

   return isAscendingOrder ?
		_tcscmp(_tcslwr(itemText1), _tcslwr(itemText2)):
		_tcscmp(_tcslwr(itemText2), _tcslwr(itemText1));
}

// Check the version of 'comctl32.dll' to see if is the v6
BOOL IsCommCtrlVersion6()
{
    static BOOL isCommCtrlVersion6 = -1;

	if (isCommCtrlVersion6 != -1) {
		return isCommCtrlVersion6;
	}
    
    //The default value
    isCommCtrlVersion6 = FALSE;

#if defined (_UNICODE)
    HINSTANCE commCtrlDll = LoadLibrary(_T("comctl32.dll"));
#else
	HINSTANCE commCtrlDll = LoadLibrary("comctl32.dll");
#endif

	if(commCtrlDll) {
        DLLGETVERSIONPROC pDllGetVersion;
        pDllGetVersion = (DLLGETVERSIONPROC)GetProcAddress(commCtrlDll, "DllGetVersion");
        
        if (pDllGetVersion) {
            DLLVERSIONINFO dvi;
            dvi.cbSize = sizeof(DLLVERSIONINFO);
            (*pDllGetVersion)(&dvi);
            
            isCommCtrlVersion6 = (dvi.dwMajorVersion == 6);
        }        
        FreeLibrary(commCtrlDll);
    }    
    return isCommCtrlVersion6;
}

// Set the UP / DOWN arrow image when a column header is clicked in the Favorite Games List
void ListView_SetHeaderSortImage(HWND lView, int colIndex, BOOL isAscending)
{
    HWND header = ListView_GetHeader(lView);
    BOOL isCommonControlVersion6 = IsCommCtrlVersion6();
    
    int columnCount = Header_GetItemCount(header);

    for (int i=0; i < columnCount; i++)
    {
        HDITEM hi;
        
        // I only need to retrieve the format if i'm on
        // windows xp. If not, then i need to retrieve
        // the bitmap also.
        hi.mask = HDI_FORMAT | (isCommonControlVersion6 ? 0 : HDI_BITMAP);
        
        Header_GetItem(header, i, &hi);
        
        // Set sort image to this column
        if(i == colIndex)
        {
            // Windows xp has a easier way to show the sort order
            // in the header: i just have to set a flag and windows
            // will do the drawing. No windows xp, no easy way.
            if (isCommonControlVersion6) {
                hi.fmt &= ~(HDF_SORTDOWN|HDF_SORTUP);
                hi.fmt |= isAscending ? HDF_SORTUP : HDF_SORTDOWN;
            } else {
                UINT bitmapID = isAscending ? IDB_UPARROW : IDB_DOWNARROW;
                
                // If there's a bitmap, let's delete it.
                if (hi.hbm) DeleteObject(hi.hbm);

                hi.fmt |= HDF_BITMAP|HDF_BITMAP_ON_RIGHT;
                hi.hbm = (HBITMAP)LoadImage(GetModuleHandle(NULL), MAKEINTRESOURCE(bitmapID), IMAGE_BITMAP, 0,0, LR_LOADMAP3DCOLORS);
            }
        }
        // Remove sort image (if exists)
        // from other columns.
        else
        {
            if (isCommonControlVersion6)
                hi.fmt &= ~(HDF_SORTDOWN|HDF_SORTUP);
            else
            {
                // If there's a bitmap, let's delete it.
                if (hi.hbm)
                    DeleteObject(hi.hbm);
                
                // Remove flags that tell windows to look for
                // a bitmap.
                hi.mask &= ~HDI_BITMAP;
                hi.fmt &= ~(HDF_BITMAP|HDF_BITMAP_ON_RIGHT);
            }
        }        
        Header_SetItem(header, i, &hi);
    }
}

// Set / Insert items for each row of the Favorite Games List
#if defined (_UNICODE)
void SetFavListRow(int nRow, TCHAR* pszCol1, TCHAR* pszUnicodeTitle	, TCHAR* pszCol3, TCHAR* pszCol4, TCHAR* pszCol5, TCHAR* pszCol6/*, TCHAR* pszCol7*/) {
#else
void SetFavListRow(int nRow, TCHAR* pszCol1, TCHAR* pszCol2			, TCHAR* pszCol3, TCHAR* pszCol4, TCHAR* pszCol5, TCHAR* pszCol6/*, TCHAR* pszCol7*/) {
#endif

	LVITEM LvItem;
	memset(&LvItem,0,sizeof(LvItem));	// Zero struct's Members
	LvItem.mask = LVIF_TEXT;			// Text Style
	LvItem.cchTextMax = 256;			// Max size of text

	for(int i = 0; i < 5; i++) 
	{		
		LvItem.iSubItem = i;
		switch(i) {

			// ROMNAME
			case 0:
				LvItem.iItem		= nRow;			// This is the first and main Row item
				LvItem.iSubItem		= 0;			// Zero to indicate first and main Column
				LvItem.pszText		= pszCol1;		// Text to be added in the first Column
				SendMessage(listView, LVM_INSERTITEM, 0, (LPARAM)&LvItem);	// Insert the item to the List
				break;

			// TITLE
#if defined (_UNICODE)
			case 1:	
				LvItem.pszText = pszUnicodeTitle;	
				break;
#else
			case 1: 
				LvItem.pszText = pszCol2;	
				break;
#endif
			// HARDWARE / SYSTEM
			case 2:	
				LvItem.pszText = pszCol3;	
				break;

			// YEAR
			case 3:	
				LvItem.pszText = pszCol4;	
				break;

			// MANUFACTURER / COMPANY
			case 4:	
				LvItem.pszText = pszCol5;	
				break;

			// MAX PLAYERS
			case 5:	
				LvItem.pszText = pszCol6;	
				break;

			// PLAY COUNTER
			//case 6: 
				//LvItem.pszText = pszCol7;	
				//break;
			
		}
		// Make sure this message is not sent to the first column
		if(i != 0) SendMessage(listView, LVM_SETITEM, 0, (LPARAM)&LvItem);
	}
}

// Update Favorite Games List titles
void UpdateFavListTitles(int nFavCount) 
{
	unsigned int x = 0;
	int nGetTextFlags = nLoadMenuShowX & ASCIIONLY ? DRV_ASCIIONLY : 0;
	int nBurnDrvSelectTmp = nBurnDrvSelect; // Remember what driver we had selected
	TCHAR pszRomset[256] = _T("");

	for(int i = 0; i < nFavCount; i++) 
	{
		ListView_SetItemState( listView, i, LVIS_FOCUSED | LVIS_SELECTED, LVIS_OVERLAYMASK);
		ListView_GetItemText( listView, i, 0, pszRomset, 256 ); // Get romset name

		for (x = 0; x < nBurnDrvCount; x++) 
		{
			nBurnDrvSelect = x;
			if (_tcscmp(BurnDrvGetText(0), pszRomset) == 0) {
				break;
			}
		}

		TCHAR szText[1024] = _T("");
		TCHAR* pszPosition = szText;
		TCHAR* pszTitle = BurnDrvGetText(nGetTextFlags | DRV_FULLNAME);

		pszPosition += _sntprintf(szText, 1024, pszTitle);

		pszTitle = BurnDrvGetText(nGetTextFlags | DRV_FULLNAME);
		while ((pszTitle = BurnDrvGetText(nGetTextFlags | DRV_NEXTNAME | DRV_FULLNAME)) != NULL) {
			if (pszPosition + _tcslen(pszTitle) - 1024 > szText) {
				break;
			}
			pszPosition += _stprintf(pszPosition, _T(SEPERATOR_2) _T("%s"), pszTitle);
		}

		ListView_SetItemText( listView, i, 1, szText );
	}
	nBurnDrvSelect = nBurnDrvSelectTmp; // Select the driver we had before this module
}

// Favorite Game List parsing module
int ParseFavListDat() 
{
	FILE *f = _tfopen(szFavoritesDat, _T("rb"));
	if (f == NULL) return 1; // failed to open file

	int x					= 0;
	int nLineNum			= 0;
	TCHAR  pszLine[512]		= _T("");
	TCHAR* pch				= NULL;
	TCHAR* str				= NULL;
	TCHAR* pszRomname		= NULL;
#if defined (_UNICODE)
	TCHAR* pszUnicodeTitle	= NULL;
#else
	TCHAR* pszTitle			= NULL;
#endif
	TCHAR* pszHardware		= NULL;
	TCHAR* pszYear			= NULL;
	TCHAR* pszCompany		= NULL;
	TCHAR* pszMaxPlayers	= NULL;
	//TCHAR* pszPlayCounter	= NULL;

	while (1)
	{	
		// If there are no more lines, break
		// ------------------------------------------------------------------------------
		if (_fgetts(pszLine, 512, f) == NULL) break;

		// Not parsing '[Favorites]' line, so continue with the other lines
		// ------------------------------------------------------------------------------
		if (_tcsncmp (_T("[Favorites]"), pszLine, _tcslen(_T("[Favorites]"))) == 0) continue;

		// Split the current line to send each value to the proper string variables
		// ------------------------------------------------------------------------------
		str = pszLine;
		pch = _tcstok(str, _T(";"));
		while(pch != NULL)
		{
			if(x == 0) pszRomname		= pch;	// Romset name
#if defined (_UNICODE)
			if(x == 1) pszUnicodeTitle	= pch;	// Game Title (Unicode)
#else
			if(x == 1) pszTitle			= pch;	// Game Title (ASCII)
#endif
			if(x == 2) pszHardware		= pch;	// Hardware / System
			if(x == 3) pszYear			= pch;	// Year
			if(x == 4) pszCompany		= pch;	// Manufacturer / Company
			if(x == 5) pszMaxPlayers	= pch;	// Max. Num. of Players
			pch							= _tcstok(NULL, _T(";"));
			x++;
		}
		x = 0; // reset this to zero for next line

#if defined (_UNICODE)
		// Insert values to the Favorite Games List (Unicode Title)
		SetFavListRow(nLineNum, pszRomname, pszUnicodeTitle	, pszHardware, pszYear, pszCompany, pszMaxPlayers);
#else
		// Insert values to the Favorite Games List (ASCII Title)
		SetFavListRow(nLineNum, pszRomname, pszTitle		, pszHardware, pszYear, pszCompany, pszMaxPlayers);
#endif
		nLineNum++; // forward to the next line...
	}
	fclose(f); // close file
	
	// Update the Favorite Games List titles
	UpdateFavListTitles(nLineNum); // Sent the final line number to know the number of games

	return 1;
}

// Refresh the Favorite Games List
void RefreshFavGameList() {

	// Clean the Favorite Games List
	ListView_DeleteAllItems(GetDlgItem(hSelDlg, IDC_FAVLIST));

	// Parse the 'favorites.dat'
	ParseFavListDat();	

	// Sort Favorite Games List (macro)
	ListView_SortItemsEx(listView, ListView_CompareFunc, (LPARAM)listView);
}

// Initiate Favorite Games List  and add columns
void InitFavGameList() 
{
    ListView_SetExtendedListViewStyle(listView, LVS_EX_FULLROWSELECT);
    
	UINT columnMask = LVCF_TEXT | LVCF_FMT | LVCF_SUBITEM | LVCF_WIDTH;
    LVCOLUMN lc[] = {
        { columnMask, 0,	 80,	_T("Romset"),		0, 0,0,0 },		// 0
		{ columnMask, 0,	350,	_T("Game Title"),	0, 1,0,0 },		// 1
        { columnMask, 0,	130,	_T("Hardware"),		0, 2,0,0 },		// 2
		{ columnMask, 0,	 80,	_T("Year"),			0, 3,0,0 },		// 3
		{ columnMask, 0,	130,	_T("Manufacturer"),	0, 4,0,0 },		// 4
		{ columnMask, 0,	100,	_T("Max Players"),	0, 5,0,0 },		// 5
		//{ columnMask, 0,	110,	_T("Play Counter"),	0, 6,0,0 },		// 6
    };

	// Insert all columns to the Favorite Games List (macro)
	for(int i = 0; i < 5; i++) {
		ListView_InsertColumn(listView, i, &lc[i]);
	}

	// Parse the 'favorites.dat' 
	ParseFavListDat();
}

// Save the favorites.dat by getting the values from the Favorite Games List
int SaveFavList(HWND hwndListView, FILE *f, TCHAR *sFileName, long lLines, long lCols) 
{
	LVITEM lvi;					// ListView Structure
	TCHAR LVText[5000]	= _T("");
	long lMAX			= 5000;
	long nNumFavs		= 0;
	long j				= 0;
	
	// If the handler of the Favorite Games List control is empty return
	if (hwndListView == NULL) return(0);
	
	// Checking number of lines against parameter value :
	nNumFavs = SendMessage((HWND) hwndListView, (UINT) LVM_GETITEMCOUNT, (WPARAM) 0, (LPARAM) 0);

	// Open the favorites.dat to update it
#if defined (_UNICODE)
	f = _tfopen(sFileName, _T("wb"));
#else
	f = fopen(TCHARToANSI(sFileName, NULL, 0), "wt");
#endif
	if (f == NULL) return(0);	// failed

	// If the Favorite Games List is empty then write the first line and close the file
	if (nNumFavs == 0)
	{
#if defined (_UNICODE)
		_ftprintf(f, _T("[Favorites]\n"));
#else
		fprintf(f, "[Favorites]\n");
#endif
		fclose(f);

		return(0);
	}	
	
	// Get text from the Favorite Games List
	// ----------------------------------------------------------------------------------------
#if defined (_UNICODE)
	_ftprintf(f, _T("[Favorites]\n"));
#else
	fprintf(f, "[Favorites]\n");
#endif

	for (nNumFavs = 0; nNumFavs < lLines; nNumFavs++)
	{
		memset(&lvi, 0, sizeof(lvi));  // Clean up before action
		lvi.mask = LVIF_TEXT;
		lvi.state = 0;
		lvi.stateMask = 0;
		lvi.cchTextMax = lMAX - 1;  
		lvi.pszText = LVText;  // String buffer for pszText member

		for (j = 0; j <= lCols; j++)
		{
			lvi.iSubItem = j;
			SendMessage(hwndListView, LVM_GETITEMTEXT, (WPARAM) nNumFavs, (LPARAM) &lvi);

			if (f != NULL)
			{
#if defined (_UNICODE)
				_ftprintf(f, _T("%s%c"), LVText, _T(';')); 
#else
				fprintf(f, "%s%c", TCHARToANSI(LVText, NULL, 0), ';'); 
#endif
			}
		}
		// End of line...
#if defined (_UNICODE)
		if (f != NULL) _ftprintf(f, _T("\n"));
#else
		if (f != NULL) fprintf(f, "\n");
#endif
	}

	// Close the file
	if (f != NULL) fclose(f);

	return 1;
}
