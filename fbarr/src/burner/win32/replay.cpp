// Functions for recording & replaying input
#include "burner.h"
#include "dynhuff.h"
#include <commdlg.h>

#include <io.h>

#ifndef W_OK
#define W_OK 4
#endif

#define MAX_METADATA 1024
wchar_t wszMetadata[MAX_METADATA];

int nReplayStatus = 0;
bool bReplayReadOnly = false;
bool bReplayDontClose = false;
int nReplayUndoCount = 0;
bool bReplayFrameCounterDisplay = 1;
TCHAR szFilter[1024];
int movieFlags = 0;
bool bStartFromReset = true;
TCHAR szCurrentMovieFilename[MAX_PATH] = _T("");
unsigned int nTotalFrames = 0;
unsigned int nReplayCurrentFrame;

#define MOVIE_FLAG_FROM_POWERON (1<<1)


const unsigned char nMovieVersion = 0x01;
unsigned int nStartFrame;
static unsigned int nEndFrame;

static FILE* fp = NULL;
static int nSizeOffset;

static short nPrevInputs[0x0100];

static int ReplayDialog();
static int RecordDialog();

int RecordInput()
{
	struct BurnInputInfo bii;
	memset(&bii, 0, sizeof(bii));

	for (unsigned int i = 0; i < nGameInpCount; i++) {
		BurnDrvGetInputInfo(&bii, i);
		if (bii.pVal) {
			if (bii.nType & BIT_GROUP_ANALOG) {
				if (*bii.pShortVal != nPrevInputs[i]) {
					EncodeBuffer(i);
					EncodeBuffer(*bii.pShortVal >> 8);
					EncodeBuffer(*bii.pShortVal & 0xFF);
					nPrevInputs[i] = *bii.pShortVal;
				}
			} else {
				if (*bii.pVal != nPrevInputs[i]) {
					EncodeBuffer(i);
					EncodeBuffer(*bii.pVal);
					nPrevInputs[i] = *bii.pVal;
				}
			}
		}
	}

	EncodeBuffer(0xFF);

	if (bReplayFrameCounterDisplay) {
		wchar_t framestring[15];
		swprintf(framestring, L"%d", GetCurrentFrame() - nStartFrame);
		VidSNewTinyMsg(framestring);
	}

	return 0;
}

int ReplayInput()
{
	unsigned char n;
	struct BurnInputInfo bii;
	memset(&bii, 0, sizeof(bii));

	// Just to be safe, restore the inputs to the known correct settings
	for (unsigned int i = 0; i < nGameInpCount; i++) {
		BurnDrvGetInputInfo(&bii, i);
		if (bii.pVal) {
			if (bii.nType & BIT_GROUP_ANALOG) {
				*bii.pShortVal = nPrevInputs[i];
			} else {
				*bii.pVal = nPrevInputs[i];
			}
		}
	}

	// Now read all inputs that need to change from the .fbm file
	while ((n = DecodeBuffer()) != 0xFF) {
		BurnDrvGetInputInfo(&bii, n);
		if (bii.pVal) {
			if (bii.nType & BIT_GROUP_ANALOG) {
				*bii.pShortVal = nPrevInputs[n] = (DecodeBuffer() << 8) | DecodeBuffer();
			} else {
				*bii.pVal = nPrevInputs[n] = DecodeBuffer();
			}
		} else {
			DecodeBuffer();
		}
	}

	if (bReplayFrameCounterDisplay) {
		wchar_t framestring[15];
		swprintf(framestring, L"%d / %d", GetCurrentFrame() - nStartFrame,nTotalFrames);
		VidSNewTinyMsg(framestring);
	}
	if ( (GetCurrentFrame()-nStartFrame) == (nTotalFrames-1) )
		bRunPause=1;

	if (end_of_buffer) {
		StopReplay();
		return 1;
	} else {
		return 0;
	}
}

static void MakeOfn(TCHAR* pszFilter)
{
	_stprintf(pszFilter, FBALoadStringEx(hAppInst, IDS_DISK_FILE_REPLAY, true), _T(APP_TITLE));
	memcpy(pszFilter + _tcslen(pszFilter), _T(" (*.fbm)\0*.fbm\0\0"), 14 * sizeof(TCHAR));

	memset(&ofn, 0, sizeof(ofn));
	ofn.lStructSize = sizeof(ofn);
	ofn.hwndOwner = hScrnWnd;
	ofn.lpstrFilter = pszFilter;
	ofn.lpstrFile = szChoice;
	ofn.nMaxFile = sizeof(szChoice) / sizeof(TCHAR);
	ofn.lpstrInitialDir = _T(".\\recordings");
	ofn.Flags = OFN_NOCHANGEDIR | OFN_HIDEREADONLY;
	ofn.lpstrDefExt = _T("fr");

	return;
}

int StartRecord()
{

	int nRet;
	int bOldPause;

	movieFlags = 0;

	bOldPause = bRunPause;
	bRunPause = 1;
	if(!bDrvOkay) {
		nBurnDrvSelect = SelDialog(0, hScrnWnd);
		if((signed int)nBurnDrvSelect == -1) {
			dprintf(_T("%d\n"),nBurnDrvSelect);
			nReplayStatus = 0;
			StopReplay();
			return 1;
		}
	}

	nRet = RecordDialog();
	bRunPause = bOldPause;
	if (nRet == 0) {
		return 1;
	}

	StopReplay();

	bReplayReadOnly = false;
	if (bStartFromReset) {
		if(!StartFromReset()) return 1; //todo: checking the driver again is useless, here.
		movieFlags |= MOVIE_FLAG_FROM_POWERON;
	}
	{
		const char szFileHeader[] = "FB1 ";				// File identifier
		fp = _tfopen(szChoice, _T("w+b"));
		_tcscpy(szCurrentMovieFilename, szChoice);

		nRet = 0;
		if (fp == NULL) {
			nRet = 1;
		} else {
			fwrite(&szFileHeader, 1, 4, fp);
			fwrite(&movieFlags, 1, 1, fp);

			if (bStartFromReset)
				nRet = 1;
			else
				nRet = BurnStateSaveEmbed(fp, -1, 1);

			if (nRet >= 0) {
				const char szChunkHeader[] = "FR1 ";	// Chunk identifier
				int nZero = 0;

				fwrite(&szChunkHeader, 1, 4, fp);		// Write chunk identifier

				nSizeOffset = ftell(fp);

				fwrite(&nZero, 1, 4, fp);				// reserve space for chunk size
				fwrite(&nZero, 1, 4, fp);				// reserve space for number of frames
				fwrite(&nZero, 1, 4, fp);				// undo count
				fwrite(&nZero, 1, 4, fp);				// reserved
				fwrite(&nZero, 1, 4, fp);				//

				nRet = EmbedCompressedFile(fp, -1);
			}
		}
	}

	if (nRet) {
		if (fp) {
			fclose(fp);
			fp = NULL;
		}

		FBAPopupAddText(PUF_TEXT_DEFAULT, MAKEINTRESOURCE(IDS_ERR_DISK_CREATE));
		FBAPopupAddText(PUF_TEXT_DEFAULT, MAKEINTRESOURCE(IDS_DISK_REPLAY));
		FBAPopupDisplay(PUF_TYPE_ERROR);
		return 1;
	} else {
		struct BurnInputInfo bii;
		memset(&bii, 0, sizeof(bii));

		nReplayStatus = 1;								// Set record status
		MenuEnableItems();

		nStartFrame = GetCurrentFrame();
		nReplayUndoCount = 0;

		// Create a baseline so we can just record the deltas afterwards
		for (unsigned int i = 0; i < nGameInpCount; i++) {
			BurnDrvGetInputInfo(&bii, i);
			if (bii.pVal) {
				if (bii.nType & BIT_GROUP_ANALOG) {
					EncodeBuffer(*bii.pShortVal >> 8);
					EncodeBuffer(*bii.pShortVal & 0xFF);
					nPrevInputs[i] = *bii.pShortVal;
				} else {
					EncodeBuffer(*bii.pVal);
					nPrevInputs[i] = *bii.pVal;
				}
			} else {
				EncodeBuffer(0);
			}
		}

#ifdef FBA_DEBUG
		dprintf(_T("*** Recording of file %s started.\n"), szChoice);
#endif

		return 0;
	}
}

int StartReplay(const TCHAR* szFileName)					// const char* szFileName = NULL
{
	if(!bDrvOkay) {
		nBurnDrvSelect = SelDialog(0, hScrnWnd);
		if(nBurnDrvSelect < 1) {
			StopReplay();
			return 1;
		}
	}

	int nRet;
	int bOldPause;

	if (szFileName) {
		_tcscpy(szChoice, szFileName);
	} else {
		if(fp && nReplayStatus == 0) {
			fclose(fp);
			fp = NULL;
		}
		bOldPause = bRunPause;
		bRunPause = 1;
		nRet = ReplayDialog();
		bRunPause = bOldPause;

		if (nRet == 0) {
			return 1;
		}

	}
	//dprintf(_T("Readonly: %d\nnReplayStatus: %d\n"),bReplayReadOnly, nReplayStatus);
	if(!bReplayReadOnly)// && nReplayStatus != 2)
		StopReplay();

	_tcscpy(szCurrentMovieFilename, szChoice);

	// init metadata
	wszMetadata[0] = L'\0';
	{
		const char szFileHeader[] = "FB1 ";					// File identifier
		char ReadHeader[] = "    ";
		fp = _tfopen(szChoice, _T("r+b"));
		memset(ReadHeader, 0, 4);
		fread(ReadHeader, 1, 4, fp);						// Read identifier
		if (memcmp(ReadHeader, szFileHeader, 4)) {			// Not the right file type
			fclose(fp);
			fp = NULL;
			nRet = 2;
		} else {
			memset(ReadHeader, 0, 4);
			fread(&movieFlags, 1, 1, fp); // Read movie flags
			if (movieFlags&MOVIE_FLAG_FROM_POWERON) { // Starts from reset
				bStartFromReset = 1;
				if (!bReplayDontClose)
					if(!StartFromReset()) return 0;
				nRet = 0;
			}
			else {// Load the savestate associated with the recording
				bStartFromReset = 0;
				nRet = BurnStateLoadEmbed(fp, -1, 1, &DrvInitCallback);
			}
			if (nRet == 0) {
				const char szChunkHeader[] = "FR1 ";		// Chunk identifier
				fread(ReadHeader, 1, 4, fp);				// Read identifier
				if (memcmp(ReadHeader, szChunkHeader, 4)) {	// Not the right file type
					fclose(fp);
					fp = NULL;
					nRet = 2;
				} else {
					int nChunkSize = 0;
					// Open the recording itself
					nSizeOffset = ftell(fp);				// Save chunk size offset in case the file is re-recorded
					fread(&nChunkSize, 1, 0x04, fp);		// Read chunk size
					int nChunkPosition = ftell(fp);			// For seeking to the metadata
					fread(&nEndFrame, 1, 4, fp);			// Read framecount
					nTotalFrames = nEndFrame;
//					if (bStartFromReset)
//						nCurrentFrame = 0;
					nStartFrame = GetCurrentFrame();
					bReplayDontClose = 0; // we don't need it anymore from this point
					nEndFrame += nStartFrame;
					fread(&nReplayUndoCount, 1, 4, fp);
					fseek(fp, 0x08, SEEK_CUR);				// Skip rest of header
					int nEmbedPosition = ftell(fp);

					// Read metadata
					const char szMetadataHeader[] = "FRM1";
					fseek(fp, nChunkPosition + nChunkSize, SEEK_SET);
					memset(ReadHeader, 0, 4);
					fread(ReadHeader, 1, 4, fp);
					if(memcmp(ReadHeader, szMetadataHeader, 4) == 0) {
						int nMetaSize;
						fread(&nMetaSize, 1, 4, fp);
						int nMetaLen = nMetaSize >> 1;
						if(nMetaLen >= MAX_METADATA) {
							nMetaLen = MAX_METADATA-1;
						}
						int i;
						for(i=0; i<nMetaLen; ++i) {
							wchar_t c = 0;
							c |= fgetc(fp) & 0xff;
							c |= (fgetc(fp) & 0xff) << 8;
							wszMetadata[i] = c;
						}
						wszMetadata[i] = L'\0';
					}

					// Seek back to the beginning of compressed data
					fseek(fp, nEmbedPosition, SEEK_SET);
					nRet = EmbedCompressedFile(fp, -1);

				}
			}
		}

		// Describe any possible errors:
		if (nRet == 3) {
			FBAPopupAddText(PUF_TEXT_DEFAULT, MAKEINTRESOURCE(IDS_DISK_THIS_REPLAY));
			FBAPopupAddText(PUF_TEXT_DEFAULT, MAKEINTRESOURCE(IDS_ERR_DISK_UNAVAIL));
		} else {
			if (nRet == 4) {
				FBAPopupAddText(PUF_TEXT_DEFAULT, MAKEINTRESOURCE(IDS_DISK_THIS_REPLAY));
				FBAPopupAddText(PUF_TEXT_DEFAULT, MAKEINTRESOURCE(IDS_ERR_DISK_TOOOLD), _T(APP_TITLE));
			} else {
				if (nRet == 5) {
					FBAPopupAddText(PUF_TEXT_DEFAULT, MAKEINTRESOURCE(IDS_DISK_THIS_REPLAY));
					FBAPopupAddText(PUF_TEXT_DEFAULT, MAKEINTRESOURCE(IDS_ERR_DISK_TOONEW), _T(APP_TITLE));
				} else {
					if (nRet) {
						FBAPopupAddText(PUF_TEXT_DEFAULT, MAKEINTRESOURCE(IDS_ERR_DISK_LOAD));
						FBAPopupAddText(PUF_TEXT_DEFAULT, MAKEINTRESOURCE(IDS_DISK_REPLAY));
					}
				}
			}
		}

		if (nRet) {
			if (fp) {
				fclose(fp);
				fp = NULL;
			}

			FBAPopupDisplay(PUF_TYPE_ERROR);

			return 1;
		}
	}

	nReplayStatus = 2;							// Set replay status
	MenuEnableItems();

	{
		struct BurnInputInfo bii;
		memset(&bii, 0, sizeof(bii));

		LoadCompressedFile();

		// Get the baseline
		for (unsigned int i = 0; i < nGameInpCount; i++) {
			BurnDrvGetInputInfo(&bii, i);
			if (bii.pVal) {
				if (bii.nType & BIT_GROUP_ANALOG) {
					*bii.pShortVal = nPrevInputs[i] = (DecodeBuffer() << 8) | DecodeBuffer();

				} else {
					*bii.pVal = nPrevInputs[i] = DecodeBuffer();
				}
			} else {
				DecodeBuffer();
			}
		}
	}

#ifdef FBA_DEBUG
	dprintf(_T("*** Replay of file %s started.\n"), szChoice);
#endif

	return 0;
}

static void CloseRecord()
{
	int nFrames = GetCurrentFrame() - nStartFrame;

	WriteCompressedFile();
	fseek(fp, 0, SEEK_END);
	int nMetadataOffset = ftell(fp);
	int nChunkSize = ftell(fp) - 4 - nSizeOffset;		// Fill in chunk size and no of recorded frames
	fseek(fp, nSizeOffset, SEEK_SET);
	fwrite(&nChunkSize, 1, 4, fp);
	fwrite(&nFrames, 1, 4, fp);
	fwrite(&nReplayUndoCount, 1, 4, fp);

	// NOTE: chunk should be aligned here, since the compressed
	// file code writes 4 bytes at a time

	// write metadata
	int nMetaLen = wcslen(wszMetadata);
	if(nMetaLen > 0) {
		fseek(fp, nMetadataOffset, SEEK_SET);
		const char szChunkHeader[] = "FRM1";
		fwrite(szChunkHeader, 1, 4, fp);
		int nMetaSize = nMetaLen * 2;
		fwrite(&nMetaSize, 1, 4, fp);
		unsigned char* metabuf = (unsigned char*)malloc(nMetaSize);
		int i;
		for(i=0; i<nMetaLen; ++i) {
			metabuf[i*2 + 0] = wszMetadata[i] & 0xff;
			metabuf[i*2 + 1] = (wszMetadata[i] >> 8) & 0xff;
		}
		fwrite(metabuf, 1, nMetaSize, fp);
		free(metabuf);
	}

	fclose(fp);
	fp = NULL;
	if (bReplayDontClose) {
		if(!StartReplay(szCurrentMovieFilename)) return;
	}
}

static void CloseReplay()
{
	CloseCompressedFile();

	if(fp) {
		fclose(fp);
		fp = NULL;
	}
}

void StopReplay()
{
	if (nReplayStatus) {
		if (nReplayStatus == 1) {

#ifdef FBA_DEBUG
			dprintf(_T(" ** Recording stopped, recorded %d frames.\n"), GetCurrentFrame() - nStartFrame);
#endif
			CloseRecord();
#ifdef FBA_DEBUG
			PrintResult();
#endif
		} else {
#ifdef FBA_DEBUG
			dprintf(_T(" ** Replay stopped, replayed %d frames.\n"), GetCurrentFrame() - nStartFrame);
#endif

			CloseReplay();
		}
		nReplayStatus = 0;
		MenuEnableItems();
	}
}


//#
//#             Input Status Freezing
//#
//##############################################################################

static inline void Write32(unsigned char*& ptr, const unsigned long v)
{
	*ptr++ = (unsigned char)(v&0xff);
	*ptr++ = (unsigned char)((v>>8)&0xff);
	*ptr++ = (unsigned char)((v>>16)&0xff);
	*ptr++ = (unsigned char)((v>>24)&0xff);
}

static inline unsigned long Read32(const unsigned char*& ptr)
{
	unsigned long v;
	v = (unsigned long)(*ptr++);
	v |= (unsigned long)((*ptr++)<<8);
	v |= (unsigned long)((*ptr++)<<16);
	v |= (unsigned long)((*ptr++)<<24);
	return v;
}

static inline void Write16(unsigned char*& ptr, const unsigned short v)
{
	*ptr++ = (unsigned char)(v&0xff);
	*ptr++ = (unsigned char)((v>>8)&0xff);
}

static inline unsigned short Read16(const unsigned char*& ptr)
{
	unsigned short v;
	v = (unsigned short)(*ptr++);
	v |= (unsigned short)((*ptr++)<<8);
	return v;
}

int FreezeInput(unsigned char** buf, int* size)
{
	*size = 4 + 2*nGameInpCount;
	*buf = (unsigned char*)malloc(*size);
	if(!*buf)
	{
		return -1;
	}

	unsigned char* ptr=*buf;
	Write32(ptr, nGameInpCount);

	for (unsigned int i = 0; i < nGameInpCount; i++)
	{
		Write16(ptr, nPrevInputs[i]);
	}

	return 0;
}

int UnfreezeInput(const unsigned char* buf, int size)
{
	unsigned int n=Read32(buf);
	if(n>0x100 || (unsigned)size < (4 + 2*n))
	{
		return -1;
	}

	for (unsigned int i = 0; i < n; i++)
	{
		nPrevInputs[i]=Read16(buf);
	}

	return 0;
}

//------------------------------------------------------

static void GetRecordingPath(wchar_t* szPath)
{
	wchar_t szDrive[MAX_PATH];
	wchar_t szDirectory[MAX_PATH];
	wchar_t szFilename[MAX_PATH];
	wchar_t szExt[MAX_PATH];
	szDrive[0] = '\0';
	szDirectory[0] = '\0';
	szFilename[0] = '\0';
	szExt[0] = '\0';
	_wsplitpath(szPath, szDrive, szDirectory, szFilename, szExt);
	if (szDrive[0] == '\0' && szDirectory[0] == '\0') {
		wchar_t szTmpPath[MAX_PATH];
		wcscpy(szTmpPath, L"recordings\\");
		wcsncpy(szTmpPath + wcslen(szTmpPath), szPath, MAX_PATH - wcslen(szTmpPath));
		szTmpPath[MAX_PATH-1] = '\0';
		wcscpy(szPath, szTmpPath);
	}
}

static void DisplayReplayProperties(HWND hDlg, bool bClear)
{
	// save status of read only checkbox
	static bool bReadOnlyStatus = true;
	if (IsWindowEnabled(GetDlgItem(hDlg, IDC_READONLY))) {
		bReadOnlyStatus = (BST_CHECKED == SendDlgItemMessage(hDlg, IDC_READONLY, BM_GETCHECK, 0, 0));
	}

	// set default values
	SetDlgItemTextA(hDlg, IDC_LENGTH, "");
	SetDlgItemTextA(hDlg, IDC_FRAMES, "");
	SetDlgItemTextA(hDlg, IDC_UNDO, "");
	SetDlgItemTextA(hDlg, IDC_METADATA, "");
	SetDlgItemTextA(hDlg, IDC_REPLAYRESET, "");
	EnableWindow(GetDlgItem(hDlg, IDC_READONLY), FALSE);
	SendDlgItemMessage(hDlg, IDC_READONLY, BM_SETCHECK, BST_UNCHECKED, 0);
	EnableWindow(GetDlgItem(hDlg, IDOK), TRUE);
	if(bClear) {
		return;
	}

	long lCount = SendDlgItemMessage(hDlg, IDC_CHOOSE_LIST, CB_GETCOUNT, 0, 0);
	long lIndex = SendDlgItemMessage(hDlg, IDC_CHOOSE_LIST, CB_GETCURSEL, 0, 0);
	if (lIndex == CB_ERR) {
		return;
	}

	if (lIndex == lCount - 1) {							// Last item is "Browse..."
		EnableWindow(GetDlgItem(hDlg, IDOK), TRUE);		// Browse is selectable
		return;
	}

	long lStringLength = SendDlgItemMessage(hDlg, IDC_CHOOSE_LIST, CB_GETLBTEXTLEN, (WPARAM)lIndex, 0);
	if(lStringLength + 1 > MAX_PATH) {
		return;
	}

	SendDlgItemMessage(hDlg, IDC_CHOOSE_LIST, CB_GETLBTEXT, (WPARAM)lIndex, (LPARAM)szChoice);

	// check relative path
	GetRecordingPath(szChoice);

	const char szFileHeader[] = "FB1 ";					// File identifier
	const char szSavestateHeader[] = "FS1 ";			// Chunk identifier
	const char szRecordingHeader[] = "FR1 ";			// Chunk identifier
	const char szMetadataHeader[] = "FRM1";				// Chunk identifier
	char ReadHeader[4];
	int nChunkSize = 0;
	int nChunkDataPosition = 0;
	int nFileVer = 0;
	int nFileMin = 0;
	int t1 = 0, t2 = 0;
	int nFrames = 0;
	int nUndoCount = 0;
	wchar_t* local_metadata = NULL;

	FILE* fd = _wfopen(szChoice, L"r+b");
	if (!fd) {
		return;
	}

	if (_waccess(szChoice, W_OK)) {
		SendDlgItemMessage(hDlg, IDC_READONLY, BM_SETCHECK, BST_CHECKED, 0);
	} else {
		EnableWindow(GetDlgItem(hDlg, IDC_READONLY), TRUE);
		//SendDlgItemMessage(hDlg, IDC_READONLY, BM_SETCHECK, (bReadOnlyStatus) ? BST_CHECKED : BST_UNCHECKED, 0); //always evaluates to false!
		SendDlgItemMessage(hDlg, IDC_READONLY, BM_SETCHECK, BST_CHECKED, 0); //read-only by default
	}


	memset(ReadHeader, 0, 4);
	fread(ReadHeader, 1, 4, fd);						// Read identifier
	if (memcmp(ReadHeader, szFileHeader, 4)) {			// Not the right file type
		fclose(fd);
		return;
	}

	fread(&movieFlags, 1, 1, fd);						// Read identifier
	if (movieFlags&MOVIE_FLAG_FROM_POWERON)			// starts from reset
		bStartFromReset = 1;
	else
		bStartFromReset = 0;

	if (!bStartFromReset) {
		memset(ReadHeader, 0, 4);
		fread(ReadHeader, 1, 4, fd);						// Read identifier
		if (memcmp(ReadHeader, szSavestateHeader, 4)) {		// Not the chunk type
			fclose(fd);
			return;
		}

		fread(&nChunkSize, 1, 4, fd);
		if (nChunkSize <= 0x40) {							// Not big enough
			fclose(fd);
			return;
		}

		nChunkDataPosition = ftell(fd);

		fread(&nFileVer, 1, 4, fd);							// Version of FB that this file was saved from

		fread(&t1, 1, 4, fd);								// Min version of FB that NV  data will work with
		fread(&t2, 1, 4, fd);								// Min version of FB that All data will work with

		nFileMin = t2;										// Replays require a full state

//		if (nBurnVer < nFileMin) {							// Error - emulator is too old to load this state
//			fclose(fd);
//			return;
//		}

		fseek(fd, nChunkDataPosition + nChunkSize, SEEK_SET);
	}

	memset(ReadHeader, 0, 4);
	fread(ReadHeader, 1, 4, fd);						// Read identifier
	if (memcmp(ReadHeader, szRecordingHeader, 4)) {		// Not the chunk type
		fclose(fd);
		return;
	}

	nChunkSize = 0;
	fread(&nChunkSize, 1, 4, fd);
	if (nChunkSize <= 0x10) {							// Not big enough
		fclose(fd);
		return;
	}

	nChunkDataPosition = ftell(fd);
	fread(&nFrames, 1, 4, fd);
	fread(&nUndoCount, 1, 4, fd);

	// read metadata
	fseek(fd, nChunkDataPosition + nChunkSize, SEEK_SET);
	memset(ReadHeader, 0, 4);
	fread(ReadHeader, 1, 4, fd);						// Read identifier
	if (memcmp(ReadHeader, szMetadataHeader, 4) == 0) {
		nChunkSize = 0;
		fread(&nChunkSize, 1, 4, fd);
		int nMetaLen = nChunkSize >> 1;
		if(nMetaLen >= MAX_METADATA) {
			nMetaLen = MAX_METADATA-1;
		}
		local_metadata = (wchar_t*)malloc((nMetaLen+1)*sizeof(wchar_t));
		int i;
		for(i=0; i<nMetaLen; ++i) {
			wchar_t c = 0;
			c |= fgetc(fd) & 0xff;
			c |= (fgetc(fd) & 0xff) << 8;
			local_metadata[i] = c;
		}
		local_metadata[i] = L'\0';
	}

	// done reading file
	fclose(fd);

	// file exists and is the corrent format,
	// so enable the "Ok" button
	EnableWindow(GetDlgItem(hDlg, IDOK), TRUE);

	// turn nFrames into a length string
	int nSeconds = (nFrames * 100 + (nBurnFPS>>1)) / nBurnFPS;
	int nMinutes = nSeconds / 60;
	int nHours = nSeconds / 3600;

	// write strings to dialog
	char szFramesString[32];
	char szLengthString[32];
	char szUndoCountString[32];
	sprintf(szFramesString, "%d", nFrames);
	sprintf(szLengthString, "%02d:%02d:%02d", nHours, nMinutes % 60, nSeconds % 60);
	sprintf(szUndoCountString, "%d", nUndoCount);

	SetDlgItemTextA(hDlg, IDC_LENGTH, szLengthString);
	SetDlgItemTextA(hDlg, IDC_FRAMES, szFramesString);
	SetDlgItemTextA(hDlg, IDC_UNDO, szUndoCountString);
	SetDlgItemTextW(hDlg, IDC_METADATA, local_metadata);
	if (bStartFromReset)
		SetDlgItemTextA(hDlg, IDC_REPLAYRESET, "Power-On");
	else
		SetDlgItemTextA(hDlg, IDC_REPLAYRESET, "Savestate");
	free(local_metadata);
}

static BOOL CALLBACK ReplayDialogProc(HWND hDlg, UINT Msg, WPARAM wParam, LPARAM)
{
	if (Msg == WM_INITDIALOG) {
		wchar_t szFindPath[32] = L"recordings\\*.fbm";
		WIN32_FIND_DATA wfd;
		HANDLE hFind;
		int i = 0;

		SendDlgItemMessage(hDlg, IDC_READONLY, BM_SETCHECK, BST_UNCHECKED, 0);

		memset(&wfd, 0, sizeof(WIN32_FIND_DATA));
		if (bDrvOkay) {
			_stprintf(szFindPath, _T("recordings\\%.8s*.fbm"), BurnDrvGetText(DRV_NAME));
		}

		hFind = FindFirstFile(szFindPath, &wfd);
		if (hFind != INVALID_HANDLE_VALUE) {
			do {
				if(!(wfd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY))
				  SendDlgItemMessage(hDlg, IDC_CHOOSE_LIST, CB_INSERTSTRING, i++, (LPARAM)wfd.cFileName);
			} while(FindNextFile(hFind, &wfd));
			FindClose(hFind);
		}
		SendDlgItemMessage(hDlg, IDC_CHOOSE_LIST, CB_INSERTSTRING, i, (LPARAM)_T("Browse..."));
		SendDlgItemMessage(hDlg, IDC_CHOOSE_LIST, CB_SETCURSEL, i, 0);

		if (i>=1) {
			DisplayReplayProperties(hDlg, false);
			SendDlgItemMessage(hDlg, IDC_CHOOSE_LIST, CB_SETCURSEL, i, 0);
		}

		SetFocus(GetDlgItem(hDlg, IDC_CHOOSE_LIST));
		return FALSE;
	}

	if (Msg == WM_COMMAND) {
		if (HIWORD(wParam) == CBN_SELCHANGE) {
			LONG lCount = SendDlgItemMessage(hDlg, IDC_CHOOSE_LIST, CB_GETCOUNT, 0, 0);
			LONG lIndex = SendDlgItemMessage(hDlg, IDC_CHOOSE_LIST, CB_GETCURSEL, 0, 0);
			if (lIndex != CB_ERR) {
				DisplayReplayProperties(hDlg, (lIndex == lCount - 1));		// Selecting "Browse..." will clear the replay properties display
			}
		} else if (HIWORD(wParam) == CBN_CLOSEUP) {
			LONG lCount = SendDlgItemMessage(hDlg, IDC_CHOOSE_LIST, CB_GETCOUNT, 0, 0);
			LONG lIndex = SendDlgItemMessage(hDlg, IDC_CHOOSE_LIST, CB_GETCURSEL, 0, 0);
			if (lIndex != CB_ERR) {
				if (lIndex == lCount - 1) {
					// send an OK notification to open the file browser
					SendMessage(hDlg, WM_COMMAND, (WPARAM)IDOK, 0);
				}
			}
		} else {
			int wID = LOWORD(wParam);
			switch (wID) {
				case IDOK:
					{
						LONG lCount = SendDlgItemMessage(hDlg, IDC_CHOOSE_LIST, CB_GETCOUNT, 0, 0);
						LONG lIndex = SendDlgItemMessage(hDlg, IDC_CHOOSE_LIST, CB_GETCURSEL, 0, 0);
						if (lIndex != CB_ERR) {
							if (lIndex == lCount - 1) {
								MakeOfn(szFilter);
								ofn.lpstrTitle = L"Replay Input from File";
								ofn.Flags &= ~OFN_HIDEREADONLY;

								int nRet = GetOpenFileName(&ofn);
								if (nRet != 0) {
									LONG lOtherIndex = SendDlgItemMessage(hDlg, IDC_CHOOSE_LIST, CB_FINDSTRING, (WPARAM)-1, (LPARAM)szChoice);
									if (lOtherIndex != CB_ERR) {
										// select already existing string
										SendDlgItemMessage(hDlg, IDC_CHOOSE_LIST, CB_SETCURSEL, lOtherIndex, 0);
									} else {
										SendDlgItemMessage(hDlg, IDC_CHOOSE_LIST, CB_INSERTSTRING, lIndex, (LPARAM)szChoice);
										SendDlgItemMessage(hDlg, IDC_CHOOSE_LIST, CB_SETCURSEL, lIndex, 0);
									}
									// restore focus to the dialog
									SetFocus(GetDlgItem(hDlg, IDC_CHOOSE_LIST));
									DisplayReplayProperties(hDlg, false);
									if (ofn.Flags & OFN_READONLY) {
										SendDlgItemMessage(hDlg, IDC_READONLY, BM_SETCHECK, BST_CHECKED, 0);
									} else {
										SendDlgItemMessage(hDlg, IDC_READONLY, BM_SETCHECK, BST_UNCHECKED, 0);
									}
								}
							} else {
								// get readonly status
								bReplayReadOnly = false;
								if (BST_CHECKED == SendDlgItemMessage(hDlg, IDC_READONLY, BM_GETCHECK, 0, 0)) {
									bReplayReadOnly = true;
								}
								EndDialog(hDlg, 1);					// only allow OK if a valid selection was made
							}
						}
					}
					return TRUE;
				case IDCANCEL:
					szChoice[0] = '\0';
					EndDialog(hDlg, 0);
					return FALSE;
			}
		}
	}

	return FALSE;
}

static int ReplayDialog()
{
	return DialogBox(hAppInst, MAKEINTRESOURCE(IDD_REPLAYINP), hScrnWnd, ReplayDialogProc);
}

static int VerifyRecordingAccessMode(wchar_t* szFilename, int mode)
{
	GetRecordingPath(szFilename);
	if(_waccess(szFilename, mode)) {
		return 0;							// not writeable, return failure
	}

	return 1;
}

static void VerifyRecordingFilename(HWND hDlg)
{
	wchar_t szFilename[MAX_PATH];
	GetDlgItemText(hDlg, IDC_FILENAME, szFilename, MAX_PATH);

	// if filename null, or, file exists and is not writeable
	// then disable the dialog controls
	if(szFilename[0] == '\0' ||
		(VerifyRecordingAccessMode(szFilename, 0) != 0 && VerifyRecordingAccessMode(szFilename, W_OK) == 0)) {
		EnableWindow(GetDlgItem(hDlg, IDOK), FALSE);
		EnableWindow(GetDlgItem(hDlg, IDC_METADATA), FALSE);
	} else {
		EnableWindow(GetDlgItem(hDlg, IDOK), TRUE);
		EnableWindow(GetDlgItem(hDlg, IDC_METADATA), TRUE);
	}
}

static BOOL CALLBACK RecordDialogProc(HWND hDlg, UINT Msg, WPARAM wParam, LPARAM)
{
	if (Msg == WM_INITDIALOG) {
		// come up with a unique name
		wchar_t szPath[MAX_PATH];
		wchar_t szFilename[MAX_PATH];
		int i = 0;
		_stprintf(szFilename, _T("%.8s.fbm"), BurnDrvGetText(DRV_NAME));
		wcscpy(szPath, szFilename);
		while(VerifyRecordingAccessMode(szPath, 0) == 1) {
			_stprintf(szFilename, _T("%.8s-%d.fbm"), BurnDrvGetText(DRV_NAME), ++i);
			wcscpy(szPath, szFilename);
		}

		SetDlgItemText(hDlg, IDC_FILENAME, szFilename);
		SetDlgItemTextW(hDlg, IDC_METADATA, L"");
		CheckDlgButton(hDlg, IDC_REPLAYRESET, BST_CHECKED);

		VerifyRecordingFilename(hDlg);

		SetFocus(GetDlgItem(hDlg, IDC_METADATA));
		return FALSE;
	}

	if (Msg == WM_COMMAND) {
		if (HIWORD(wParam) == EN_CHANGE) {
			VerifyRecordingFilename(hDlg);
		} else {
			int wID = LOWORD(wParam);
			switch (wID) {
				case IDC_BROWSE:
					{
						_stprintf(szChoice, _T("%.8s"), BurnDrvGetText(DRV_NAME));
						MakeOfn(szFilter);
						ofn.lpstrTitle = L"Record Input to File";
						ofn.Flags |= OFN_OVERWRITEPROMPT;
						int nRet = GetSaveFileName(&ofn);
						if (nRet != 0) {
							// this should trigger an EN_CHANGE message
							SetDlgItemText(hDlg, IDC_FILENAME, szChoice);
						}
					}
					return TRUE;
				case IDOK:
					GetDlgItemText(hDlg, IDC_FILENAME, szChoice, MAX_PATH);
					GetDlgItemTextW(hDlg, IDC_METADATA, wszMetadata, MAX_METADATA);
					bStartFromReset = false;
					if (BST_CHECKED == SendDlgItemMessage(hDlg, IDC_REPLAYRESET, BM_GETCHECK, 0, 0)) {
						bStartFromReset = true;
					}
					wszMetadata[MAX_METADATA-1] = L'\0';
					// ensure a relative path has the "recordings\" path in prepended to it
					GetRecordingPath(szChoice);
					EndDialog(hDlg, 1);
					return TRUE;
				case IDCANCEL:
					szChoice[0] = '\0';
					EndDialog(hDlg, 0);
					return FALSE;
			}
		}
	}

	return FALSE;
}

static int RecordDialog()
{
	return DialogBox(hAppInst, MAKEINTRESOURCE(IDD_RECORDINP), hScrnWnd, RecordDialogProc);
}
