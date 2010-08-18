// State dialog module
#include "burner.h"
#include "replay.h"
#include "../../utils/xstring.h"
#include <string>
#include <fstream>

using namespace std;

//Backup savestate/loadstate values
TCHAR lastSavestateMade[2048]; //Stores the filename of the last savestate made (needed for UndoSavestate)
bool undoSS = false;		  //This will be true if there is lastSavestateMade, it was made since ROM was loaded, a backup state for lastSavestateMade exists
bool redoSS = false;		  //This will be true if UndoSaveState is run, will turn false when a new savestate is made

TCHAR lastLoadstateMade[2048]; //Stores the filename of the last state loaded (needed for Undo/Redo loadstate)
bool undoLS = false;		  //This will be true if a backupstate was made and it was made since ROM was loaded
bool redoLS = false;		  //This will be true if a backupstate was loaded, meaning redoLoadState can be run

void BackupLoadState();
void LoadBackup(bool user);

extern bool bReplayDontClose;
int bDrvSaveAll = 0;

static void MakeOfn(TCHAR* pszFilter)
{
	_stprintf(pszFilter, FBALoadStringEx(hAppInst, IDS_DISK_FILE_STATE, true), _T(APP_TITLE));
	memcpy(pszFilter + _tcslen(pszFilter), _T(" (*.fs, *.fbm)\0*.fs;*.fbm\0\0"), 25 * sizeof(TCHAR));

	memset(&ofn, 0, sizeof(ofn));
	ofn.lStructSize = sizeof(ofn);
	ofn.hwndOwner = hScrnWnd;
	ofn.lpstrFilter = pszFilter;
	ofn.lpstrFile = szChoice;
	ofn.nMaxFile = sizeof(szChoice) / sizeof(TCHAR);
	ofn.lpstrInitialDir = _T(".\\savestates");
	ofn.Flags = OFN_NOCHANGEDIR | OFN_HIDEREADONLY;
	ofn.lpstrDefExt = _T("fs");
	return;
}

// The automatic save
int StatedAuto(int bSave)
{
	static TCHAR szName[32] = _T("");
	int nRet;

	_stprintf(szName, _T("%sconfig\\games\\%s.fs"), szCurrentPath, BurnDrvGetText(DRV_NAME));

	if (bSave == 0) {
		nRet = BurnStateLoad(szName, bDrvSaveAll, NULL);		// Load ram
		if (nRet && bDrvSaveAll)	{
			nRet = BurnStateLoad(szName, 0, NULL);				// Couldn't get all - okay just try the nvram
		}
	} else {
		nRet = BurnStateSave(szName, bDrvSaveAll);				// Save ram
	}

	return nRet;
}

static void CreateStateName(int nSlot)
{
	if (MovieIsActive() && BindedSavestates())	//If movie is active and bind savestates flag active, bind movie to savestaes by including movie name in the filename
	{
		_stprintf(szChoice, _T("%ssavestates\\%s %s slot %02x.fs"), szCurrentPath, BurnDrvGetText(DRV_NAME), StripExtension(StripPath(GetCurrentMovie())).c_str(), nSlot);
	}
	else
	{
		_stprintf(szChoice, _T("%ssavestates\\%s slot %02x.fs"), szCurrentPath, BurnDrvGetText(DRV_NAME), nSlot);
	}
}

//Retunrs a generic non numbered savestate name based on rom & movie
std::wstring ReturnStateName()
{
	TCHAR choice[260];
	if (MovieIsActive() && BindedSavestates())	//If movie is active and bind savestates flag active, bind movie to savestaes by including movie name in the filename
	{
		_stprintf(choice, _T("%ssavestates\\%s %s.fs"), szCurrentPath, BurnDrvGetText(DRV_NAME), StripExtension(StripPath(GetCurrentMovie())).c_str());
	}
	else
	{
		_stprintf(choice, _T("%ssavestates\\%s.fs"), szCurrentPath, BurnDrvGetText(DRV_NAME));
	}
	return choice;
}

int StatedLoad(int nSlot)
{
	TCHAR szFilter[1024];
	int nRet;
	int bOldPause;

	if(!bDrvOkay) return 1; //don't load unless there's a ROM open...

	BackupLoadState();		//Make backup savestate first

	// if rewinding during playback, and readonly is not set,
	// then transition from decoding to encoding
	if(!bReplayReadOnly && nReplayStatus == 2)
	{
		nReplayStatus = 1;
	}
	if(bReplayReadOnly && nReplayStatus == 1)
	{
		bReplayDontClose = 1;
		StopReplay();
		nReplayStatus = 2;
	}

	if (nSlot) {
		CreateStateName(nSlot);
	} else {
		/*if (bDrvOkay) {
			_stprintf(szChoice, _T("%.8s*.fs"), BurnDrvGetText(DRV_NAME));
		} else {
			_stprintf(szChoice, _T("savestate"));
		}*/
		_stprintf(szChoice, _T("%.8s*.fs"), BurnDrvGetText(DRV_NAME));
		MakeOfn(szFilter);
		ofn.lpstrTitle = FBALoadStringEx(hAppInst, IDS_STATE_LOAD, true);

		bOldPause = bRunPause;
		bRunPause = 1;
		nRet = GetOpenFileName(&ofn);
		bRunPause = bOldPause;

		if (nRet == 0) {		// Error
			return 1;
		}
	}

	nRet = BurnStateLoad(szChoice, 1, &DrvInitCallback);
	
	//adelikat: Replace with a dynamic message that includes the slot number
	if (nSlot)
	{
	TCHAR message[16];
	swprintf(message, L"state %d loaded", nSlot);
	std::wstring messageStr = message;
	VidSNewShortMsg(messageStr.c_str());
	}
	else
		VidSNewShortMsg(L"state loaded");
	
	
	UpdateMemWatch();

	if (nSlot) {
		return nRet;
	}

	// Describe any possible errors:
	if (nRet == 3) {
		FBAPopupAddText(PUF_TEXT_DEFAULT, MAKEINTRESOURCE(IDS_DISK_THIS_STATE));
		FBAPopupAddText(PUF_TEXT_DEFAULT, MAKEINTRESOURCE(IDS_ERR_DISK_UNAVAIL));
	} else {
		if (nRet == 4) {
			FBAPopupAddText(PUF_TEXT_DEFAULT, MAKEINTRESOURCE(IDS_DISK_THIS_STATE));
			FBAPopupAddText(PUF_TEXT_DEFAULT, MAKEINTRESOURCE(IDS_ERR_DISK_TOOOLD), _T(APP_TITLE));
		} else {
			if (nRet == 5) {
				FBAPopupAddText(PUF_TEXT_DEFAULT, MAKEINTRESOURCE(IDS_DISK_THIS_STATE));
				FBAPopupAddText(PUF_TEXT_DEFAULT, MAKEINTRESOURCE(IDS_ERR_DISK_TOONEW), _T(APP_TITLE));
			} else {
				if (nRet && !nSlot) {
					FBAPopupAddText(PUF_TEXT_DEFAULT, MAKEINTRESOURCE(IDS_ERR_DISK_LOAD));
					FBAPopupAddText(PUF_TEXT_DEFAULT, MAKEINTRESOURCE(IDS_DISK_STATE));
				}
			}
		}
	}

	if (nRet) 
	{
		LoadBackup(0);						//Restore previous state
		FBAPopupDisplay(PUF_TYPE_ERROR);
	}

	return nRet;
}

int StatedSave(int nSlot)
{
	TCHAR szFilter[1024];
	int nRet;
	int bOldPause;

	if (bDrvOkay == 0) {
		return 1;
	}

	if (nSlot) {
		CreateStateName(nSlot);
	} else {
		_stprintf(szChoice, _T("%s"), BurnDrvGetText(DRV_NAME));
		MakeOfn(szFilter);
		ofn.lpstrTitle = FBALoadStringEx(hAppInst, IDS_STATE_SAVE, true);
		ofn.Flags |= OFN_OVERWRITEPROMPT;

		bOldPause = bRunPause;
		bRunPause = 1;
		nRet = GetSaveFileName(&ofn);
		bRunPause = bOldPause;

		if (nRet == 0) {		// Error
			return 1;
		}
	}

	nRet = BurnStateSave(szChoice, 1);

	if (nRet && !nSlot) {
		FBAPopupAddText(PUF_TEXT_DEFAULT, MAKEINTRESOURCE(IDS_ERR_DISK_CREATE));
		FBAPopupAddText(PUF_TEXT_DEFAULT, MAKEINTRESOURCE(IDS_DISK_STATE));
		FBAPopupDisplay(PUF_TYPE_ERROR);
	}

	//adelikat: Replace the call to IDS_STATE_SAVED with a dynamic message that includes the slot number
	if (nSlot)
	{
	TCHAR message[16];
	swprintf(message, L"state %d saved", nSlot);
	std::wstring messageStr = message;
	VidSNewShortMsg(messageStr.c_str());
	}
	else
		VidSNewShortMsg(FBALoadStringEx(hAppInst, IDS_STATE_SAVED, true));

	return nRet;
}

//Save state based on a file name
int StatedSave(std::wstring filename)
{
	TCHAR choice[260];
	int nRet;

	if (bDrvOkay == 0) 
	{
		return 1;
	}

	wcscpy(choice, filename.c_str());
	nRet = BurnStateSave(choice, 1);

	if (nRet) 
	{
		FBAPopupAddText(PUF_TEXT_DEFAULT, MAKEINTRESOURCE(IDS_ERR_DISK_CREATE));
		FBAPopupAddText(PUF_TEXT_DEFAULT, MAKEINTRESOURCE(IDS_DISK_STATE));
		FBAPopupDisplay(PUF_TYPE_ERROR);
	}

	VidSNewShortMsg(L"Error creating backup state");
	return nRet;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------
//*************************************************************************
//Loadstate backup functions
//(Used when Loading savestates)
//*************************************************************************

wstring GetBackupFileName()
{
	//This backup savestate is a special one specifically made whenever a loadstate occurs so that the user's place in a movie/game is never lost
	//particularly from unintentional loadstating
	
	std::wstring filename = StripExtension(ReturnStateName());//Generate normal savestate filename then remove file extension
	filename.append(L".bak");								  //add .bak extension
	return filename;
}

//This function simply checks to see if the backup loadstate exists, the backup loadstate is a special savestate
//That is made before loading any state, so that the user never loses data, it has the .bak file extension
bool CheckBackupSaveStateExist()
{
	wstring filename = GetBackupFileName(); //Get backup savestate filename
		
	//Check if this filename exists
	fstream test;
	test.open(filename.c_str(),fstream::in);
		
	if (test.fail())
	{
		test.close();
		return false;
	}
	else
	{
		test.close();
		return true;
	}
}

//Creates a .bak file, to be used before loading any state
void BackupLoadState()
{
	wstring filename = GetBackupFileName();
	StatedSave(filename.c_str());
	undoLS = true;
}

//Loads the backup (.bak) savestate that's created whenever a loadstate is executed
//user is to signal whether it is the users choice or FBA (in the event of loadstate error)
void LoadBackup(bool user)
{
	if (!undoLS && user) return;			//If this is a user choice and backups are turned off
	TCHAR choice[260];
	wcscpy(choice, GetBackupFileName().c_str());
	if (CheckBackupSaveStateExist())
	{
		int nRet = BurnStateLoad(choice, 1, &DrvInitCallback);
		redoLS = true;						//Flag redoLoadState
		undoLS = false;						//Flag that LoadBackup cannot be run again
	}
	else
		VidSNewShortMsg(L"Error loading backup state"); //TODO: put backup filename in error message
														//TODO: use nret for a more informative message
}