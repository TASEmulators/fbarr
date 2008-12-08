#include "burner.h"
#include <shlobj.h>

TCHAR szAppPreviewsPath[MAX_PATH] = _T("previews\\");
TCHAR szAppTitlesPath[MAX_PATH] = _T("titles\\");
TCHAR szAppFlyersPath[MAX_PATH] = _T("flyers\\");
TCHAR szAppMarqueesPath[MAX_PATH] = _T("marquees\\");
TCHAR szAppControlsPath[MAX_PATH] = _T("controls\\");
TCHAR szAppCabinetsPath[MAX_PATH] = _T("cabinets\\");
TCHAR szAppPCBsPath[MAX_PATH] = _T("pcbs\\");
TCHAR szAppCheatsPath[MAX_PATH] = _T("cheats\\");
TCHAR szAppHistoryPath[MAX_PATH] = _T("");
TCHAR szAppListsPath[MAX_PATH] = _T("lists\\");
TCHAR szAppIpsPath[MAX_PATH] = _T("ips\\");

static BOOL CALLBACK DefInpProc(HWND hDlg, UINT Msg, WPARAM wParam, LPARAM)
{
	int var;

	switch (Msg) {
		case WM_INITDIALOG: {
			SetDlgItemText(hDlg, IDC_SUPPORTDIR_EDIT1, szAppPreviewsPath);
			SetDlgItemText(hDlg, IDC_SUPPORTDIR_EDIT2, szAppTitlesPath);
			SetDlgItemText(hDlg, IDC_SUPPORTDIR_EDIT3, szAppFlyersPath);
			SetDlgItemText(hDlg, IDC_SUPPORTDIR_EDIT4, szAppMarqueesPath);
			SetDlgItemText(hDlg, IDC_SUPPORTDIR_EDIT5, szAppControlsPath);
			SetDlgItemText(hDlg, IDC_SUPPORTDIR_EDIT6, szAppCabinetsPath);
			SetDlgItemText(hDlg, IDC_SUPPORTDIR_EDIT7, szAppPCBsPath);
			SetDlgItemText(hDlg, IDC_SUPPORTDIR_EDIT8, szAppCheatsPath);
			SetDlgItemText(hDlg, IDC_SUPPORTDIR_EDIT9, szAppHistoryPath);
			SetDlgItemText(hDlg, IDC_SUPPORTDIR_EDIT10, szAppListsPath);
			SetDlgItemText(hDlg, IDC_SUPPORTDIR_EDIT11, szAppIpsPath);

			WndInMid(hDlg, hScrnWnd);
			SetFocus(hDlg);											// Enable Esc=close
			break;
		}
		
		case WM_COMMAND: {
			LPMALLOC pMalloc = NULL;
			BROWSEINFO bInfo;
			ITEMIDLIST* pItemIDList = NULL;
			TCHAR buffer[MAX_PATH];
			
			if (LOWORD(wParam) == IDOK) {
				GetDlgItemText(hDlg, IDC_SUPPORTDIR_EDIT1, szAppPreviewsPath, sizeof(szAppPreviewsPath));
				GetDlgItemText(hDlg, IDC_SUPPORTDIR_EDIT2, szAppTitlesPath, sizeof(szAppTitlesPath));
				GetDlgItemText(hDlg, IDC_SUPPORTDIR_EDIT3, szAppFlyersPath, sizeof(szAppFlyersPath));
				GetDlgItemText(hDlg, IDC_SUPPORTDIR_EDIT4, szAppMarqueesPath, sizeof(szAppMarqueesPath));
				GetDlgItemText(hDlg, IDC_SUPPORTDIR_EDIT5, szAppControlsPath, sizeof(szAppControlsPath));
				GetDlgItemText(hDlg, IDC_SUPPORTDIR_EDIT6, szAppCabinetsPath, sizeof(szAppCabinetsPath));
				GetDlgItemText(hDlg, IDC_SUPPORTDIR_EDIT7, szAppPCBsPath, sizeof(szAppPCBsPath));
				GetDlgItemText(hDlg, IDC_SUPPORTDIR_EDIT8, szAppCheatsPath, sizeof(szAppCheatsPath));
				GetDlgItemText(hDlg, IDC_SUPPORTDIR_EDIT9, szAppHistoryPath, sizeof(szAppHistoryPath));
				GetDlgItemText(hDlg, IDC_SUPPORTDIR_EDIT10, szAppListsPath, sizeof(szAppListsPath));
				GetDlgItemText(hDlg, IDC_SUPPORTDIR_EDIT11, szAppIpsPath, sizeof(szAppIpsPath));
			
				SendMessage(hDlg, WM_CLOSE, 0, 0);
				break;
			} else {
				if (LOWORD(wParam) >= IDC_SUPPORTDIR_BR1 && LOWORD(wParam) <= IDC_SUPPORTDIR_BR11) {
					var = IDC_SUPPORTDIR_EDIT1 + LOWORD(wParam) - IDC_SUPPORTDIR_BR1;
				} else {
					if (HIWORD(wParam) == BN_CLICKED && LOWORD(wParam) == IDCANCEL) {
						SendMessage(hDlg, WM_CLOSE, 0, 0);
					}
					break;
				}
			}
			
			SHGetMalloc(&pMalloc);

			memset(&bInfo, 0, sizeof(bInfo));
			bInfo.hwndOwner = hDlg;
			bInfo.pszDisplayName = buffer;
			bInfo.lpszTitle = FBALoadStringEx(hAppInst, IDS_ROMS_SELECT_DIR, true);
			bInfo.ulFlags = BIF_EDITBOX | BIF_RETURNONLYFSDIRS;

			pItemIDList = SHBrowseForFolder(&bInfo);

			if (pItemIDList) {
				if (SHGetPathFromIDList(pItemIDList, buffer)) {
					int strLen = _tcslen(buffer);
					if (strLen) {
						if (buffer[strLen - 1] != _T('\\')) {
							buffer[strLen] = _T('\\');
							buffer[strLen + 1] = _T('\0');
						}
						SetDlgItemText(hDlg, var, buffer);
					}
				}
				pMalloc->Free(pItemIDList);
			}
			pMalloc->Release();
			
			break;
		}
		
		case WM_CLOSE: {
			EndDialog(hDlg, 0);
			break;
		}
	}

	return 0;
}

int SupportDirCreate()
{
	FBADialogBox(hAppInst, MAKEINTRESOURCE(IDD_SUPPORTDIR), hScrnWnd, DefInpProc);
	return 1;
}
