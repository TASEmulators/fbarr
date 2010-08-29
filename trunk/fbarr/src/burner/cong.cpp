// Burner Config for Game file module
#include "burner.h"

const int nConfigMinVersion = 0x000000;

bool bSaveInputs = true;

static TCHAR* GameConfigName()
{
	// Return the path of the config file for this game
	static TCHAR szName[MAX_PATH];
	_stprintf(szName, _T("%sconfig\\games\\%s.ini"), szCurrentPath, BurnDrvGetText(DRV_NAME));
	return szName;
}

// Read in the config file for the game-specific inputs
int ConfigGameLoad(bool bOverWrite)
{
	TCHAR szLine[256];
	int nFileVersion = 0;

	FILE* h = _tfopen(GameConfigName(), _T("rt"));
	if (h == NULL) {
		return 1;
	}

	if (bOverWrite) {
		nAnalogSpeed = 0x0100;
		nBurnCPUSpeedAdjust = 0x0100;
	}

	// Go through each line of the config file and process inputs
	while (_fgetts(szLine, sizeof(szLine), h)) {
		TCHAR *szValue;
		int nLen = _tcslen(szLine);

		// Get rid of the linefeed at the end
		if (szLine[nLen - 1] == 10) {
			szLine[nLen - 1] = 0;
			nLen--;
		}

		szValue = LabelCheck(szLine, _T("version"));
		if (szValue) {
			nFileVersion = _tcstol(szValue, NULL, 0);
		}

		if (bOverWrite) {
			szValue = LabelCheck(szLine, _T("analog"));
			if (szValue) {
				nAnalogSpeed = _tcstol(szValue, NULL, 0);
			}
			szValue = LabelCheck(szLine, _T("cpu"));
			if (szValue) {
				nBurnCPUSpeedAdjust = _tcstol(szValue, NULL, 0);
			}
		}

		if (nConfigMinVersion <= nFileVersion && nFileVersion <= nBurnVer) {
			szValue = LabelCheck(szLine, _T("input"));
			if (szValue) {
				GameInpRead(szValue, bOverWrite);
				continue;
			}

			szValue = LabelCheck(szLine, _T("macro"));
			if (szValue) {
				GameInpMacroRead(szValue, bOverWrite);
				continue;
			}

			szValue = LabelCheck(szLine, _T("custom"));
			if (szValue) {
				GameInpCustomRead(szValue, bOverWrite);
				continue;
			}
		}
	}

	fclose(h);
	return 0;
}

// Write out the config file for the game-specific inputs
int ConfigGameSave(bool bSave)
{
	FILE* h;

	if (!bSave) {
		GameInpBlank(0);
		ConfigGameLoad(false);
	}

	h = _tfopen(GameConfigName(), _T("wt"));
	if (h == NULL) {
		return 1;
	}

	// Write title
	_ftprintf(h, _T("// ") _T(APP_TITLE) _T(" v%s --- Config File for %s (%s)\n\n"), szAppBurnVer, BurnDrvGetText(DRV_NAME), ANSIToTCHAR(BurnDrvGetTextA(DRV_FULLNAME), NULL, 0));

	_ftprintf(h, _T("// --- Miscellaneous ----------------------------------------------------------\n\n"));
	// Write version number
	_ftprintf(h, _T("version 0x%06X\n\n"), nBurnVer);
	// Write speed for relative analog controls
	_ftprintf(h, _T("analog  0x%04X\n"), nAnalogSpeed);
	// Write CPU speed adjustment
	_ftprintf(h, _T("cpu     0x%04X\n"), nBurnCPUSpeedAdjust);

	_ftprintf(h, _T("\n\n\n"));
	_ftprintf(h, _T("// --- Inputs -----------------------------------------------------------------\n\n"));

	GameInpWrite(h);

	fclose(h);
	return 0;
}

