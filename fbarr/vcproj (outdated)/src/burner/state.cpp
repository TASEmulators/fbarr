// Driver Save State module
#include "burner.h"
#include "luasav.h"

// from dynhuff.cpp
int FreezeDecode(unsigned char **buffer, int *size);
int UnfreezeDecode(const unsigned char* buffer, int size);
int FreezeEncode(unsigned char **buffer, int *size);
int UnfreezeEncode(const unsigned char* buffer, int size);

// from replay.cpp
int FreezeInput(unsigned char** buf, int* size);
int UnfreezeInput(const unsigned char* buf, int size);

extern int nReplayStatus;
extern bool bReplayReadOnly;
extern int nReplayUndoCount;
extern unsigned int nReplayCurrentFrame;
extern unsigned int nStartFrame;

// If bAll=0 save/load all non-volatile ram to .fs
// If bAll=1 save/load all ram to .fs

// ------------ State len --------------------
static int nTotalLen = 0;

static int __cdecl StateLenAcb(struct BurnArea* pba)
{
	nTotalLen += pba->nLen;

	return 0;
}

static int StateInfo(int* pnLen, int* pnMinVer, int bAll)
{
	int nMin = 0;
	nTotalLen = 0;
	BurnAcb = StateLenAcb;

	BurnAreaScan(ACB_NVRAM, &nMin);						// Scan nvram
	if (bAll) {
		int m;
		BurnAreaScan(ACB_MEMCARD, &m);					// Scan memory card
		if (m > nMin) {									// Up the minimum, if needed
			nMin = m;
		}
		BurnAreaScan(ACB_VOLATILE, &m);					// Scan volatile ram
		if (m > nMin) {									// Up the minimum, if needed
			nMin = m;
		}
	}
	*pnLen = nTotalLen;
	*pnMinVer = nMin;

	return 0;
}

// State load
int BurnStateLoadEmbed(FILE* fp, int nOffset, int bAll, int (*pLoadGame)())
{
	const char* szHeader = "FS1 ";						// Chunk identifier

	int nLen = 0;
	int nMin = 0, nFileVer = 0, nFileMin = 0;
	int t1 = 0, t2 = 0;
	char ReadHeader[4];
	char szForName[33];
	int nChunkSize = 0;
	unsigned char *Def = NULL;
	int nDefLen = 0;									// Deflated version
	int nRet = 0;

	if (nOffset >= 0) {
		fseek(fp, nOffset, SEEK_SET);
	} else {
		if (nOffset == -2) {
			fseek(fp, 0, SEEK_END);
		} else {
			fseek(fp, 0, SEEK_CUR);
		}
	}

	memset(ReadHeader, 0, 4);
	fread(ReadHeader, 1, 4, fp);						// Read identifier
	if (memcmp(ReadHeader, szHeader, 4)) {				// Not the right file type
		return -2;
	}

	fread(&nChunkSize, 1, 4, fp);
	if (nChunkSize <= 0x40) {							// Not big enough
		return -1;
	}

	int nChunkData = ftell(fp);

	fread(&nFileVer, 1, 4, fp);							// Version of FB that this file was saved from

	fread(&t1, 1, 4, fp);								// Min version of FB that NV  data will work with
	fread(&t2, 1, 4, fp);								// Min version of FB that All data will work with

	if (bAll) {											// Get the min version number which applies to us
		nFileMin = t2;
	} else {
		nFileMin = t1;
	}

	fread(&nDefLen, 1, 4, fp);							// Get the size of the compressed data block

	memset(szForName, 0, sizeof(szForName));
	fread(szForName, 1, 32, fp);

//	if (nBurnVer < nFileMin) {							// Error - emulator is too old to load this state
//		return -5;
//	}

	// Check the game the savestate is for, and load it if needed.
	{
		bool bLoadGame = false;

		if (nBurnDrvSelect < nBurnDrvCount) {
			if (strcmp(szForName, BurnDrvGetTextA(DRV_NAME))) {	// The save state is for the wrong game
				bLoadGame = true;
			}
		} else {										// No game loaded
			bLoadGame = true;
		}

		if (bLoadGame) {
			unsigned int nCurrentGame = nBurnDrvSelect;
			unsigned int i;
			for (i = 0; i < nBurnDrvCount; i++) {
				nBurnDrvSelect = i;
				if (strcmp(szForName, BurnDrvGetTextA(DRV_NAME)) == 0) {
					break;
				}
			}
			if (i == nBurnDrvCount) {
				nBurnDrvSelect = nCurrentGame;
				return -3;
			} else {
				if (pLoadGame == NULL) {
					return -1;
				}
				if (pLoadGame()) {
					return -1;
				}
			}
		}
	}

	StateInfo(&nLen, &nMin, bAll);
	if (nLen <= 0) {									// No memory to load
		return -1;
	}

	// Check if the save state is okay
//	if (nFileVer < nMin) {								// Error - this state is too old and cannot be loaded.
//		return -4;
//	}

	fseek(fp, nChunkData + 0x30, SEEK_SET);				// Read current frame
	fread(&nReplayCurrentFrame, 1, 4, fp);
	nCurrentFrame = nStartFrame + nReplayCurrentFrame;

	fseek(fp, 0x0C, SEEK_CUR);							// Move file pointer to the start of the compressed block
	Def = (unsigned char*)malloc(nDefLen);
	if (Def == NULL) {
		return -1;
	}
	memset(Def, 0, nDefLen);
	fread(Def, 1, nDefLen, fp);							// Read in deflated block

	nRet = BurnStateDecompress(Def, nDefLen, bAll);		// Decompress block into driver
	free(Def);											// free deflated block

	fseek(fp, nChunkData + nChunkSize, SEEK_SET);

	if (nRet) {
		return -1;
	} else {
		return 0;
	}
}

// State load
int BurnStateLoad(TCHAR* szName, int bAll, int (*pLoadGame)())
{
	const char szHeader[] = "FB1 ";						// File identifier
	char szReadHeader[4] = "";
	int nRet = 0;

	FILE* fp = _tfopen(szName, _T("rb"));
	if (fp == NULL) {
		return 1;
	}

	fread(szReadHeader, 1, 4, fp);						// Read identifier
	if (memcmp(szReadHeader, szHeader, 4) == 0) {		// Check filetype
		nRet = BurnStateLoadEmbed(fp, -1, bAll, pLoadGame);
	}

	// load movie extra info
	if(nReplayStatus)
	{
		const char szMovieExtra[] = "MOV ";
		const char szDecodeChunk[] = "HUFF";
		const char szInputChunk[] = "INP ";

		int nChunkSize;
		unsigned char* buf=NULL;

		do
		{
			fread(szReadHeader, 1, 4, fp);
			if(memcmp(szReadHeader, szMovieExtra, 4))           { nRet = -1;  break; }
			fread(&nChunkSize, 1, 4, fp);

			fread(szReadHeader, 1, 4, fp);
			if(memcmp(szReadHeader, szDecodeChunk, 4))          { nRet = -1;  break; }
			fread(&nChunkSize, 1, 4, fp);

			if((buf=(unsigned char*)malloc(nChunkSize))==NULL)  { nRet = -1;  break; }
			fread(buf, 1, nChunkSize, fp);

			int ret=-1;
			if(nReplayStatus == 1)
			{
				ret = UnfreezeEncode(buf, nChunkSize);
				if(!FBA_LuaRerecordCountSkip()) { ++nReplayUndoCount; }
			}
			else if(nReplayStatus == 2)
			{
				ret = UnfreezeDecode(buf, nChunkSize);
			}
			if(ret)                                             { nRet = -1;  break; }

			free(buf);
			buf = NULL;

			fread(szReadHeader, 1, 4, fp);
			if(memcmp(szReadHeader, szInputChunk, 4))           { nRet = -1;  break; }
			fread(&nChunkSize, 1, 4, fp);

			if((buf=(unsigned char*)malloc(nChunkSize))==NULL)  { nRet = -1;  break; }
			fread(buf, 1, nChunkSize, fp);
			if(UnfreezeInput(buf, nChunkSize))                  { nRet = -1;  break; }

			free(buf);
			buf = NULL;
		}
		while(false);

		if(buf) free(buf);
	}

	fclose(fp);

	luasav_load(_TtoA(szName));

	if (nRet < 0) {
		return -nRet;
	} else {
		return 0;
	}
}

// Write a savestate as a chunk of an "FB1 " file
// nOffset is the absolute offset from the beginning of the file
// -1: Append at current position
// -2: Append at EOF
int BurnStateSaveEmbed(FILE* fp, int nOffset, int bAll)
{
	const char* szHeader = "FS1 ";						// Chunk identifier

	int nLen = 0;
	int nNvMin = 0, nAMin = 0;
	int nZero = 0;
	char szGame[33];
	unsigned char *Def = NULL;
	int nDefLen = 0;									// Deflated version
	int nRet = 0;

	if (fp == NULL) {
		return -1;
	}

	StateInfo(&nLen, &nNvMin, 0);						// Get minimum version for NV part
	nAMin = nNvMin;
	if (bAll) {											// Get minimum version for All data
		StateInfo(&nLen, &nAMin, 1);
	}

	if (nLen <= 0) {									// No memory to save
		return -1;
	}

	if (nOffset >= 0) {
		fseek(fp, nOffset, SEEK_SET);
	} else {
		if (nOffset == -2) {
			fseek(fp, 0, SEEK_END);
		} else {
			fseek(fp, 0, SEEK_CUR);
		}
	}

	fwrite(szHeader, 1, 4, fp);							// Chunk identifier
	int nSizeOffset = ftell(fp);						// Reserve space to write the size of this chunk
	fwrite(&nZero, 1, 4, fp);							//

	fwrite(&nBurnVer, 1, 4, fp);						// Version of FB this was saved from
	fwrite(&nNvMin, 1, 4, fp);							// Min version of FB NV  data will work with
	fwrite(&nAMin, 1, 4, fp);							// Min version of FB All data will work with

	fwrite(&nZero, 1, 4, fp);							// Reserve space to write the compressed data size

	memset(szGame, 0, sizeof(szGame));					// Game name
	sprintf(szGame, "%.32s", BurnDrvGetTextA(DRV_NAME));			//
	fwrite(szGame, 1, 32, fp);							//

	nReplayCurrentFrame = GetCurrentFrame() - nStartFrame;
	fwrite(&nReplayCurrentFrame, 1, 4, fp);					// Current frame

	fwrite(&nZero, 1, 4, fp);							// Reserved
	fwrite(&nZero, 1, 4, fp);							//
	fwrite(&nZero, 1, 4, fp);							//

	nRet = BurnStateCompress(&Def, &nDefLen, bAll);		// Compress block from driver and return deflated buffer
	if (Def == NULL) {
		return -1;
	}

	nRet = fwrite(Def, 1, nDefLen, fp);					// Write block to disk
	free(Def);											// free deflated block and close file

	if (nRet != nDefLen) {								// error writing block to disk
		return -1;
	}

	if (nDefLen & 3) {									// Chunk size must be a multiple of 4
		fwrite(&nZero, 1, 4 - (nDefLen & 3), fp);		// Pad chunk if needed
	}

	fseek(fp, nSizeOffset + 0x10, SEEK_SET);			// Write size of the compressed data
	fwrite(&nDefLen, 1, 4, fp);							//

	nDefLen = (nDefLen + 0x43) & ~3;					// Add for header size and align

	fseek(fp, nSizeOffset, SEEK_SET);					// Write size of the chunk
	fwrite(&nDefLen, 1, 4, fp);							//

	fseek (fp, 0, SEEK_END);							// Set file pointer to the end of the chunk

	return nDefLen;
}

// State save
int BurnStateSave(TCHAR* szName, int bAll)
{
	const char szHeader[] = "FB1 ";						// File identifier
	int nLen = 0, nVer = 0;
	int nRet = 0;

	if (bAll) {											// Get amount of data
		StateInfo(&nLen, &nVer, 1);
	} else {
		StateInfo(&nLen, &nVer, 0);
	}
	if (nLen <= 0) {									// No data, so exit without creating a savestate
		return 0;										// Don't return an error code
	}

	FILE* fp = _tfopen(szName, _T("wb"));
	if (fp == NULL) {
		return 1;
	}

	fwrite(&szHeader, 1, 4, fp);
	nRet = BurnStateSaveEmbed(fp, -1, bAll);

	// save movie extra info
	if(nReplayStatus)
	{
		unsigned char* huff_buf = NULL;
		int huff_size;
		unsigned char* input_buf = NULL;
		int input_size;
		int ret=-1;

		if(nReplayStatus == 1)
		{
			ret = FreezeEncode(&huff_buf, &huff_size);
		}
		else if(nReplayStatus == 2)
		{
			ret = FreezeDecode(&huff_buf, &huff_size);
		}

		if(!ret &&
			!FreezeInput(&input_buf, &input_size))
		{
			const char szMovieExtra[] = "MOV ";
			const char szDecodeChunk[] = "HUFF";
			const char szInputChunk[] = "INP ";

			int nZero = 0;
			int nAlign = 0;
			int nChkLen = 0;
			int nMovChunkLen = 0;

			fwrite(szMovieExtra, 1, 4, fp);
			int nSizeOffset = ftell(fp);
			fwrite(&nZero, 1, 4, fp);						// Leave room for the chunk size
			nMovChunkLen = 0;

			// write Decode block
			nAlign = (huff_size&3) ? (4 - (huff_size&3)) : 0;
			nChkLen = huff_size + nAlign;

			fwrite(szDecodeChunk, 1, 4, fp);
			fwrite(&nChkLen, 1, 4, fp);
			fwrite(huff_buf, 1, huff_size, fp);
			if(nAlign)
			{
				fwrite(&nZero, 1, nAlign, fp);
			}
			nMovChunkLen += nChkLen + 8;

			// write Input block
			nAlign = (input_size&3) ? (4 - (input_size&3)) : 0;
			nChkLen = input_size + nAlign;

			fwrite(szInputChunk, 1, 4, fp);
			fwrite(&nChkLen, 1, 4, fp);
			fwrite(input_buf, 1, input_size, fp);
			if(nAlign)
			{
				fwrite(&nZero, 1, nAlign, fp);
			}
			nMovChunkLen += nChkLen + 8;

			fseek(fp, nSizeOffset, SEEK_SET);
			fwrite(&nMovChunkLen, 1, 4, fp);
			fseek(fp, nMovChunkLen, SEEK_CUR);
		}

		if(huff_buf)    free(huff_buf);
		if(input_buf)   free(input_buf);
	}

	fclose(fp);

	luasav_save(_TtoA(szName));

	if (nRet < 0) {
		return 1;
	} else {
		return 0;
	}
}
