#include "burner.h"
//#include "imagebutton.h"

static HWND hNgslotDlg	= NULL;
static HWND hParent		= NULL;
static HBITMAP hPreview = NULL;
static HBITMAP hBmp[6]		= { NULL, NULL, NULL, NULL, NULL, NULL};
static HBRUSH hWhiteBGBrush;
int nMultiSlotRet = 0;


void SetMVSCartPreview(int nStaticControl, TCHAR* szDrvName, TCHAR* szDrvParent, TCHAR* szDrvBoard, int nBmpSlot)
{
	FILE *fp;
	HBITMAP hNewImage = NULL;
	TCHAR szImageFile[256] = _T("");
	TCHAR szFileName[MAX_PATH];

	switch(nStaticControl) {
		case 0: nStaticControl = IDC_NGSLOT1_IMAGE; break;
		case 1: nStaticControl = IDC_NGSLOT2_IMAGE; break;
		case 2: nStaticControl = IDC_NGSLOT3_IMAGE; break;
		case 3: nStaticControl = IDC_NGSLOT4_IMAGE; break;
		case 4: nStaticControl = IDC_NGSLOT5_IMAGE; break;
		case 5: nStaticControl = IDC_NGSLOT6_IMAGE; break;
	}

	if (hBmp[nBmpSlot]) {
		DeleteObject((HGDIOBJ)hBmp[nBmpSlot]);
		hBmp[nBmpSlot] = NULL;
	}

	_stprintf(szFileName, _T("%s%s.png"), szAppTitlesPath, szDrvName);
	fp = _tfopen(szFileName, _T("rb"));

	if (!fp && szDrvParent) {
		_stprintf(szFileName, _T("%s%s.png"), szAppTitlesPath, szDrvParent);
		fp = _tfopen(szFileName, _T("rb"));
	}

	if (!fp && szDrvBoard) {
		_stprintf(szFileName, _T("%s%s.png"), szAppTitlesPath, szDrvBoard);
		fp = _tfopen(szFileName, _T("rb"));
	}

	// -----------------------------------------------------------------------------
	// Download title if not present locally

	if (!fp) {
		_stprintf(szFileName, _T("%s%s.png"), szAppTitlesPath, szDrvName);
		_stprintf(szImageFile, _T("%s.png"), szDrvName);
		if(FileDownload(szAppTitlesPath, szFileName, szImageFile, _T("titles/"))) {
			fp = _tfopen(szFileName, _T("rb"));
		}
	}

	if(!fp) {
		_stprintf(szFileName, _T("%s%s.png"), szAppTitlesPath, szDrvParent);
		_stprintf(szImageFile, _T("%s.png"), szDrvParent);
		if(FileDownload(szAppTitlesPath, szFileName, szImageFile, _T("titles/"))) {
			fp = _tfopen(szFileName, _T("rb"));
		}
	}

	if(!fp) {
		_stprintf(szFileName, _T("%s%s.png"), szAppTitlesPath, szDrvBoard);
		_stprintf(szImageFile, _T("%s.png"), szDrvBoard);
		if(FileDownload(szAppTitlesPath, szFileName, szImageFile, _T("titles/"))) {
			fp = _tfopen(szFileName, _T("rb"));
		}
	}

	// -----------------------------------------------------------------------------

	if (fp) {
		hNewImage = LoadPNG(hNgslotDlg, fp, 75, 56, 1);
		fclose(fp);
	}

	if (hNewImage) {
		DeleteObject((HGDIOBJ)hBmp[nBmpSlot]);
		hBmp[nBmpSlot] = hNewImage;
		SendDlgItemMessage(hNgslotDlg, nStaticControl, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)hBmp[nBmpSlot]);

	} else {
		if (!hBmp[nBmpSlot]) {
			SendDlgItemMessage(hNgslotDlg, nStaticControl, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)hPreview);
		}
	}
}

void ScanTitlePreviews()
{
	unsigned int nOldSelection = nBurnDrvSelect;

	for (int i = 0; i < MAX_NEO_SLOTS; i++) {
		if (nNeoSlotDrvNum[i] != (unsigned int)-1){
			nBurnDrvSelect = nNeoSlotDrvNum[i];
			SetMVSCartPreview(i, BurnDrvGetText(DRV_NAME), BurnDrvGetText(DRV_PARENT), BurnDrvGetText(DRV_BOARDROM), i);
		}
	}

	nBurnDrvSelect = nOldSelection;
}

void InitContent(HWND hDlg)
{
	hNgslotDlg = hDlg;

	hPreview = LoadBitmap(hAppInst, MAKEINTRESOURCE(BMP_SMALLPREVIEW));
	SendDlgItemMessage(hDlg, IDC_NGSLOT1_IMAGE, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)hPreview);
	SendDlgItemMessage(hDlg, IDC_NGSLOT2_IMAGE, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)hPreview);
	SendDlgItemMessage(hDlg, IDC_NGSLOT3_IMAGE, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)hPreview);
	SendDlgItemMessage(hDlg, IDC_NGSLOT4_IMAGE, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)hPreview);
	SendDlgItemMessage(hDlg, IDC_NGSLOT5_IMAGE, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)hPreview);
	SendDlgItemMessage(hDlg, IDC_NGSLOT6_IMAGE, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)hPreview);

	SendMessage(GetDlgItem(hDlg, IDC_NGSLOT1_TEXT), WM_SETTEXT, (WPARAM)0, (LPARAM)_T("Slot 1"));
	SendMessage(GetDlgItem(hDlg, IDC_NGSLOT1_ROMNAME), WM_SETTEXT, (WPARAM)0, (LPARAM)_T("Empty"));
	SendMessage(GetDlgItem(hDlg, IDC_NGSLOT2_TEXT), WM_SETTEXT, (WPARAM)0, (LPARAM)_T("Slot 2"));
	SendMessage(GetDlgItem(hDlg, IDC_NGSLOT2_ROMNAME), WM_SETTEXT, (WPARAM)0, (LPARAM)_T("Empty"));
	SendMessage(GetDlgItem(hDlg, IDC_NGSLOT3_TEXT), WM_SETTEXT, (WPARAM)0, (LPARAM)_T("Slot 3"));
	SendMessage(GetDlgItem(hDlg, IDC_NGSLOT3_ROMNAME), WM_SETTEXT, (WPARAM)0, (LPARAM)_T("Empty"));
	SendMessage(GetDlgItem(hDlg, IDC_NGSLOT4_TEXT), WM_SETTEXT, (WPARAM)0, (LPARAM)_T("Slot 4"));
	SendMessage(GetDlgItem(hDlg, IDC_NGSLOT4_ROMNAME), WM_SETTEXT, (WPARAM)0, (LPARAM)_T("Empty"));
	SendMessage(GetDlgItem(hDlg, IDC_NGSLOT5_TEXT), WM_SETTEXT, (WPARAM)0, (LPARAM)_T("Slot 5"));
	SendMessage(GetDlgItem(hDlg, IDC_NGSLOT5_ROMNAME), WM_SETTEXT, (WPARAM)0, (LPARAM)_T("Empty"));
	SendMessage(GetDlgItem(hDlg, IDC_NGSLOT6_TEXT), WM_SETTEXT, (WPARAM)0, (LPARAM)_T("Slot 6"));
	SendMessage(GetDlgItem(hDlg, IDC_NGSLOT6_ROMNAME), WM_SETTEXT, (WPARAM)0, (LPARAM)_T("Empty"));

	for (int i = 0; i < MAX_NEO_SLOTS; i++) {
		nNeoSlotDrvNum[i] = (unsigned int)-1;
	}

	// Make a white brush
	hWhiteBGBrush = CreateSolidBrush(RGB(0xFF,0xFF,0xFF));

	WndInMid(hDlg, hParent);

	/*ImageButton_EnableXPThemes();

	ImageButton_Create(hDlg, IDCANCEL);
	ImageButton_Create(hDlg, IDOK);
	ImageButton_SetIcon(GetDlgItem(hDlg, IDCANCEL), IDI_CANCEL, 0,0,16,16);
	ImageButton_SetIcon(GetDlgItem(hDlg, IDOK), IDI_PLAY, 0,0,16,16);

	ImageButton_Create(hDlg, IDC_NGSLOT1_SELECT);
	ImageButton_Create(hDlg, IDC_NGSLOT2_SELECT);
	ImageButton_Create(hDlg, IDC_NGSLOT3_SELECT);
	ImageButton_Create(hDlg, IDC_NGSLOT4_SELECT);
	ImageButton_Create(hDlg, IDC_NGSLOT5_SELECT);
	ImageButton_Create(hDlg, IDC_NGSLOT6_SELECT);
	ImageButton_SetIcon(GetDlgItem(hDlg, IDC_NGSLOT1_SELECT), IDI_NGSLOTSELECT, 0,0,32,32);
	ImageButton_SetIcon(GetDlgItem(hDlg, IDC_NGSLOT2_SELECT), IDI_NGSLOTSELECT, 0,0,32,32);
	ImageButton_SetIcon(GetDlgItem(hDlg, IDC_NGSLOT3_SELECT), IDI_NGSLOTSELECT, 0,0,32,32);
	ImageButton_SetIcon(GetDlgItem(hDlg, IDC_NGSLOT4_SELECT), IDI_NGSLOTSELECT, 0,0,32,32);
	ImageButton_SetIcon(GetDlgItem(hDlg, IDC_NGSLOT5_SELECT), IDI_NGSLOTSELECT, 0,0,32,32);
	ImageButton_SetIcon(GetDlgItem(hDlg, IDC_NGSLOT6_SELECT), IDI_NGSLOTSELECT, 0,0,32,32);
	*/
	HICON hIcon = LoadIcon(hAppInst, MAKEINTRESOURCE(IDI_APP));
	SendMessage(hDlg, WM_SETICON, ICON_SMALL, (LPARAM)hIcon);	// Set the dialog icon.

	WndInMid(hDlg, hScrnWnd);
	SetFocus(hDlg);	 // Enable Esc=close

}

static BOOL CALLBACK DefInpProc(HWND hDlg, UINT Msg, WPARAM wParam, LPARAM lParam)
{
	switch (Msg) {
		case WM_INITDIALOG: {
			InitContent(hDlg);
//			IpsManagerInit();
			break;
		}

		case WM_COMMAND: {
			int wID = LOWORD(wParam);
			int Notify = HIWORD(wParam);

			if (Notify == BN_CLICKED) {
				switch (wID) {
					case IDOK: {
//						IpsOkay();
						nMultiSlotRet = 1; // Selection OK
						break;
					}

					case IDCANCEL: {
						nMultiSlotRet = 0; // Cancel
						SendMessage(hDlg, WM_CLOSE, 0, 0);
						return 0;
					}

					case IDC_NGSLOT1_SELECT:
					case IDC_NGSLOT2_SELECT:
					case IDC_NGSLOT3_SELECT:
					case IDC_NGSLOT4_SELECT:
					case IDC_NGSLOT5_SELECT:
					case IDC_NGSLOT6_SELECT: {
						int nActiveSlot = wID - IDC_NGSLOT1_SELECT;

						nNeoSlotDrvNum[nActiveSlot] = SelDialog(1, hDlg);

						extern bool bDialogCancel;

						if ((nNeoSlotDrvNum[nActiveSlot] != (unsigned int)-1) && (!bDialogCancel))
						{
							unsigned int nOldDrvSelect = nBurnDrvSelect;
							nBurnDrvSelect = nNeoSlotDrvNum[nActiveSlot];
							TCHAR szText[1024] = _T("");
							_stprintf(szText, _T("%s%s%s%s"), BurnDrvGetText(DRV_NAME), (BurnDrvGetText(DRV_PARENT)) ? _T(" (clone of ") : _T(""), (BurnDrvGetText(DRV_PARENT)) ? BurnDrvGetText(DRV_PARENT) : _T(""), (BurnDrvGetText(DRV_PARENT)) ? _T(")") : _T(""));
							SendMessage(GetDlgItem(hDlg, IDC_NGSLOT1_ROMNAME + nActiveSlot), WM_SETTEXT, (WPARAM)0, (LPARAM)szText);
							SendMessage(GetDlgItem(hDlg, IDC_NGSLOT1_ROMTITLE + nActiveSlot), WM_SETTEXT, (WPARAM)0, (LPARAM)BurnDrvGetText(DRV_FULLNAME));
							szText[0] = _T('\0');
							_stprintf(szText, _T("%s, %s"), BurnDrvGetText(DRV_MANUFACTURER), BurnDrvGetText(DRV_DATE));
							SendMessage(GetDlgItem(hDlg, IDC_NGSLOT1_ROMINFO + nActiveSlot), WM_SETTEXT, (WPARAM)0, (LPARAM)szText);
							nBurnDrvSelect = nOldDrvSelect;
						} else {
							SendMessage(GetDlgItem(hDlg, IDC_NGSLOT1_ROMNAME + nActiveSlot), WM_SETTEXT, (WPARAM)0, (LPARAM)_T("Empty"));
							SendDlgItemMessage(hDlg, IDC_NGSLOT1_IMAGE + nActiveSlot, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)hPreview);
						}
						ScanTitlePreviews();
						break;
					}
				}
			}
			break;
		}

		case WM_CTLCOLORSTATIC:
		{
			int idcText[6]		= { IDC_NGSLOT1_TEXT, IDC_NGSLOT2_TEXT, IDC_NGSLOT3_TEXT, IDC_NGSLOT4_TEXT, IDC_NGSLOT5_TEXT, IDC_NGSLOT6_TEXT };
			int idcRomname[6]	= { IDC_NGSLOT1_ROMNAME, IDC_NGSLOT2_ROMNAME, IDC_NGSLOT3_ROMNAME, IDC_NGSLOT4_ROMNAME, IDC_NGSLOT5_ROMNAME, IDC_NGSLOT6_ROMNAME };
			int idcRomtitle[6]	= { IDC_NGSLOT1_ROMTITLE, IDC_NGSLOT2_ROMTITLE, IDC_NGSLOT3_ROMTITLE, IDC_NGSLOT4_ROMTITLE, IDC_NGSLOT5_ROMTITLE, IDC_NGSLOT6_ROMTITLE };
			int idcRominfo[6]	= { IDC_NGSLOT1_ROMINFO, IDC_NGSLOT2_ROMINFO, IDC_NGSLOT3_ROMINFO, IDC_NGSLOT4_ROMINFO, IDC_NGSLOT5_ROMINFO, IDC_NGSLOT6_ROMINFO };

			for(int i = 0; i < 6; i++) {
				if ((HWND)lParam == GetDlgItem(hDlg, idcText[i]))		return (BOOL)hWhiteBGBrush;
				if ((HWND)lParam == GetDlgItem(hDlg, idcRomname[i]))	return (BOOL)hWhiteBGBrush;
				if ((HWND)lParam == GetDlgItem(hDlg, idcRomtitle[i]))	return (BOOL)hWhiteBGBrush;
				if ((HWND)lParam == GetDlgItem(hDlg, idcRominfo[i]))	return (BOOL)hWhiteBGBrush;
			}
			return 0;
		}

		case WM_CLOSE: {

			for(int i = 0; i < 6; i++) {
				if (hBmp[i]) {
					DeleteObject((HGDIOBJ)hBmp[i]);
					hBmp[i] = NULL;
				}
			}

			if(hWhiteBGBrush) {
				DeleteObject(hWhiteBGBrush);
			}

			EndDialog(hDlg, 0);
			break;
		}
	}

	return 0;
}

int NeogeoSlotSelectCreate(HWND hParentWND)
{
	hParent = hParentWND;
	InitCommonControls();
	FBADialogBox(hAppInst, MAKEINTRESOURCE(IDD_NGSLOTSELECT), hParent, DefInpProc);
	return nMultiSlotRet;
}
