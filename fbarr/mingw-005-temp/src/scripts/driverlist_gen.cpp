/*	-----------------------------------------------------------------------------
	Driverlist Generator for FB Alpha [by CaptainCPS-X / Jezer Andino]
	-----------------------------------------------------------------------------
	http://www.barryharris.me.uk/	[Official FB Alpha Home]
	http://neosource.1emu.net/		[Official FB Alpha Forums]
	-----------------------------------------------------------------------------

	v0.1 
	----|

		+ independent directory scanning
		
		+ independent file scanning and filtering
		
		+ source files parsing for data manipulation (d_*.cpp)
		
		+ sort structured data by title
		
		+ generate 'src\generated\driverlist.h' and 'gamelist.html'

	v0.2
	----|

		+ when generating the driverlist.h the program will avoid adding (#if defined FBA_DEBUG)
		  and (#endif) for every single driver processed, now it will evaluate if a (#if defined FBA_DEBUG) 
		  has been started or if it hasn't. The new final size of the generated driverlist.h is a lot smaller, 
		  in lines and bytes :)

		+ added a fix for MinGW string handling

		+ added various modules/functions to check if driverlist.h needs to be updated
		  due to a driver being added, or removed from the source code.
		
		+ updated notifications so we know better what the generator is doing.
		
		+ added some defines at the top to ensure the compiler build the generator 
		  without any kind of problems.
		
		+ removed un-needed / commented code.
		
	----------------------------------------------------------------------------- */

#ifndef _UNICODE
#define _UNICODE
#endif

#ifndef UNICODE
#define UNICODE
#endif

#ifndef _CRT_SECURE_NO_WARNINGS
#define _CRT_SECURE_NO_WARNINGS
#endif

#ifndef _CRT_NON_CONFORMING_SWPRINTFS
#define _CRT_NON_CONFORMING_SWPRINTFS
#endif

#include <windows.h>
#include <stdio.h>
#include <tchar.h>
#include <shellapi.h>

// -----------------------------------------------------------------
// Directory Scanning Stuff

struct BURNDIR {
	TCHAR sub[4][260];	// ( burn/dir1/dir2/dir3 )
};

static struct BURNDIR BurnDir[100];
unsigned int nSub[4] = {0,0,0};
unsigned int nSubCount[3] = {0,0};
static int ScanBurnDir(TCHAR szBurnDir[260]);

// -----------------------------------------------------------------

char* TCHARToANSI(const TCHAR* pszInString, char* pszOutString, int nOutSize);
TCHAR* ANSIToTCHAR(const char* pszInString, TCHAR* pszOutString, int nOutSize);
#define _TtoA(a)	TCHARToANSI(a, NULL, 0)
#define _AtoT(a)	ANSIToTCHAR(a, NULL, 0)

// -----------------------------------------------------------------

void GetBurnDrivers();
bool VerifyDriverlistHdr(TCHAR szDriverlistHdr[260]);
int CreateGamelistHTML(TCHAR szGamelistHTML[260]);
int CreateDriverlist(TCHAR szDriverlistHdr[260]);

// -----------------------------------------------------------------

//bool bViewGeneratedFiles = 1;	// for debug
//bool bCheckOneFile = 0;	// debug option

TCHAR szDrvFile[2048][260];
unsigned int nFileCount = 0;

int main(int argc, char *argv[]) 
{
	// Get proper driver files from makefile cmd. line args., not from directories
	for(int x = 1, z = 0; x < argc; x++) {
		if(!strncmp("d_", argv[x], 2)) {
		
			// copy file name, without .o
			_sntprintf(szDrvFile[z], _tcslen(_AtoT(argv[x]))-2,  _T("%s"), _AtoT(argv[x]));
			
			// put the .cpp at the end
			_stprintf(szDrvFile[z], _T("%s.cpp"), szDrvFile[z]);
			
			//_tprintf(_T("\n%d %s"), z, szDrvFile[z]);	// lets see results please xD (debug)

			z++;
			nFileCount++;
		} else {
			//_tprintf(_T("\n%d %s [excluded]"), x, _AtoT(argv[x]));
		}
	}

	_tprintf(_T("\nInitializing FB Alpha Driverlist Generator..."));

	TCHAR szBurnDirectory[260] = _T("src\\burn"); 

	// scan 'burn\' for directories and sub-directories (up to 3 sub directories depth supported , can be updated if neccessary)
	if(ScanBurnDir(szBurnDirectory)) {
		_tprintf(_T("\nThere was an error while trying to scan directories."));
		return 0;
	}

	_tprintf(_T("\nDirectories scanned, continue to get driver's structure data"));

	GetBurnDrivers();

	_tprintf(_T("\nVerifying driverlist.h structure"));

	bool bNeedUpdate = VerifyDriverlistHdr(_T("src\\generated\\driverlist.h"));

	// driverlist.h was not found, or it was found but needs to be updated
	if(bNeedUpdate) {

		_tprintf(_T("\ndriverlist.h was verified and needs to be updated"));
		_tprintf(_T("\ncontinue to create gamelist.html and driverlist.h"));

		if(!CreateDriverlist(_T("src\\generated\\driverlist.h"))) {
			_tprintf(_T("\ndriverlist.h couldn't be generated (file open error)"));
		} else {
			_tprintf(_T("\n.\\src\\generated\\driverlist.h was successfully generated!"));
			//if(bViewGeneratedFiles) {
				//ShellExecute(NULL, _T("open"), _T("src\\generated\\driverlist.h"),	NULL, NULL, SW_SHOWNORMAL);
			//}	
		}
	} else {
		_tprintf(_T("\ndriverlist.h was verified and doesn't need to be updated"));
	}

	if(!CreateGamelistHTML(_T("gamelist.html"))) {
		_tprintf(_T("\ngamelist.html couldn't be generated (file open error)"));
	} else {
		_tprintf(_T("\ngamelist.html was successfully generated!\n"));
		//if(bViewGeneratedFiles) {
			//ShellExecute(NULL, _T("open"), _T("gamelist.html"),	NULL, NULL, SW_SHOWNORMAL);
		//}	
	}

	//system("pause");
	return 0;
}


// String Conversion Stuff
char* TCHARToANSI(const TCHAR* pszInString, char* pszOutString, int nOutSize)
{
	static char szStringBuffer[1024];
	memset(szStringBuffer, 0, sizeof(szStringBuffer));

	char* pszBuffer = pszOutString ? pszOutString : szStringBuffer;
	int nBufferSize = pszOutString ? nOutSize * 2 : sizeof(szStringBuffer);

	if (WideCharToMultiByte(CP_ACP, 0, pszInString, -1, pszBuffer, nBufferSize, NULL, NULL)) {
		return pszBuffer;
	}
	return NULL;
}

TCHAR* ANSIToTCHAR(const char* pszInString, TCHAR* pszOutString, int nOutSize)
{
	static TCHAR szStringBuffer[1024];

	TCHAR* pszBuffer = pszOutString ? pszOutString : szStringBuffer;
	int nBufferSize  = pszOutString ? nOutSize * 2 : sizeof(szStringBuffer);

	if (MultiByteToWideChar(CP_ACP, 0, pszInString, -1, pszBuffer, nBufferSize)) {
		return pszBuffer;
	}

	return NULL;
}

// Return a string with all occurrences of substring sub replaced by rep
TCHAR *replace_str(TCHAR *str, TCHAR *sub, TCHAR *rep)
{
	static TCHAR buffer[4096];
	TCHAR *p;

	if(!(p = _tcsstr(str, sub))) {
		return str;
	}

	_tcsncpy(buffer, str, p - str); // Copy characters from 'str' start to 'orig'

	buffer[p - str] = _T('\0');

	_stprintf(buffer + (p - str), _T("%s%s"), rep, p + _tcslen(sub));

	return buffer;
}

#define BRN_DRV			0	// Always included
#define BRN_DRV_D		1	// Debug build only
#define BRN_DRV_X		2	// Excluded from build

int GetDirFiles(TCHAR dir[MAX_PATH]);
int ParseDrvSource(TCHAR szSrcFile[MAX_PATH]);

FILE* glFp			= NULL;
FILE* dlFp			= NULL;

// File writting functions
void wt(TCHAR szStr[2400]) {	
	char s[2450];
	sprintf(s, "%s", _TtoA(szStr));
	fwrite(s, sizeof(char), strlen(s), glFp);
}

void wDL(TCHAR szStr[2400]) {	
	char s[2450];
	sprintf(s, "%s", _TtoA(szStr));
	fwrite(s, sizeof(char), strlen(s), dlFp);
}

void wAnsi(char str[3500]) {
	fwrite(str, sizeof(char), strlen(str), glFp);
}

// Driver parsing stuff
unsigned int DrvCount = 1;

struct BURNDRV {
	TCHAR szStructName[260];
	TCHAR szBuildStatus[260];
	TCHAR szShortName[260];
	TCHAR szParent[260];
	TCHAR szBoardROM[260]; // not used
	TCHAR szDate[260];
	char szFullNameA[260];	
	TCHAR szCommentA[260];
	TCHAR szManufacturerA[260];
	TCHAR szSystemA[260];
	TCHAR szStatus[260];
};
struct BURNDRV BurnDrv[9999];

// qsort struct comparision function
int __cdecl struct_cmp_by_title(const void *a, const void *b)
{
    struct BURNDRV *ia = (struct BURNDRV *)a;
    struct BURNDRV *ib = (struct BURNDRV *)b;
    return strcmp(ia->szFullNameA, ib->szFullNameA);	
} 

void GetBurnDrivers() {

	// Manipulate directories data (store it, print, etc)
	for(unsigned int i = 0; i < 3; i++) {
		for(unsigned int x = 0; x < nSub[i]; x++) {
			GetDirFiles(BurnDir[x].sub[i]);
			//if(bCheckOneFile) break;
		}
		//if(bCheckOneFile) break;
	}
	qsort(BurnDrv, DrvCount, sizeof(struct BURNDRV), struct_cmp_by_title); 

}

struct DRVLIST {
	TCHAR szStruct[260];
};

DRVLIST DrvList[9999];

TCHAR szHdr[30000][1000];

unsigned int DrvListCount = 1;

bool CompareDrvStructs() 
{
	// Weird value (1\n) MINGW is passing here lol, so just in case
	
	//_tprintf(_T("%s\n"), DrvList[1].szStruct); // now you see it!
	
	_stprintf(DrvList[1].szStruct, _T("%s"), replace_str(DrvList[1].szStruct, _T("1\n"), _T("")));
	
	//_tprintf(_T("%s\n"), DrvList[1].szStruct); // now you don't! LOL

	// Ok lets roll!...

	unsigned int y = 1;
	for(unsigned int x = 1; x < DrvListCount; x++) 
	{
		// Skip eXcluded drivers
		if(!_tcscmp(BurnDrv[y].szBuildStatus, _T("I")) || !_tcscmp(BurnDrv[y].szBuildStatus, _T("D"))) 
		{
			//_tprintf(_T("[x][%d] cmp-> drvlist: %s | [y][%d] burndrv: %s\n"), x, DrvList[x].szStruct, y, BurnDrv[y].szStructName);
		
			// If a difference is found in driverlist.h
			if(_tcscmp(DrvList[x].szStruct, BurnDrv[y].szStructName)) {

				return 1;
			}
		} else {
			x--;
		}
		y++;
	}

	// no need to update driverlist.h
	return 0;
}

// This Will return bNeedUpdate if driverlist.h needs to be updated
bool VerifyDriverlistHdr(TCHAR szDriverlistHdr[260]) {

	FILE *fp = _tfopen(szDriverlistHdr, _T("rt"));

	unsigned int nCppLineCount = 0;

	if(fp) 
	{
		while (!feof(fp)) 
		{
			// 1 - count source file lines
			nCppLineCount++;

			// 2 - copy lines to szHdrLine[] array for future proccesing
			TCHAR szTmp[1000];

			if(_fgetts(szTmp, 1000, fp) == NULL) {
				break;
			}

			_stprintf(szHdr[nCppLineCount], _T("%s"), szTmp);

			// copy of data done
		}
		
	} else {
		return 1; // driverlist was not found, create it
	}
	
	fclose(fp); // close file pointer
	
	TCHAR szMainStr[260];
	TCHAR szBrnDrv[260];
	
	DrvListCount = 1;

	for(unsigned int z = 0; z < nCppLineCount + 1; z++) 
	{
		// loop till end of lines array and evaluate data

		_stprintf(szMainStr, _T("%s"), _T("DRV \t"));
		
		_stprintf(szBrnDrv, _T("%s"), szHdr[z]);
		
		if(!_tcsncmp(_T("#undef DRV"), szBrnDrv, _tcslen(_T("#undef DRV")) )) {
			return CompareDrvStructs();
		}

		_tcscpy(szBrnDrv, replace_str(szBrnDrv, _T(" "), _T("")));	// remove
		_tcscpy(szBrnDrv, replace_str(szBrnDrv, _T("\t"), _T("")));	// remove 

		// if we find a DRV structure declaration add it to DrvList[x].szStruct
		if (!_tcsncmp(szMainStr, szBrnDrv, _tcslen(szMainStr))) 
		{
			_stprintf(szBrnDrv, _T("%s"), replace_str(szBrnDrv, szMainStr, _T("\0")));	// remove 

			TCHAR szTmpStr[260];
			for(unsigned int x = 0; x < _tcslen(szBrnDrv); x++) 
			{
				TCHAR szChar[2];
				_stprintf(szChar, _T("%c"), szBrnDrv[x]);

				if(!_tcsncmp(_T(";"), szChar, 1)) break;

				_tcsncat(szTmpStr, szChar, 1);
			}

			// done! ready to compare both structs! :)
			_stprintf(DrvList[DrvListCount].szStruct, _T("%s"), szTmpStr);
			
			_stprintf(szTmpStr, _T("%s"), _T(""));

			DrvListCount++;
		}
	}
	return CompareDrvStructs();
}

int CreateGamelistHTML(TCHAR szGamelistHTML[260]) 
{
	glFp = _tfopen(szGamelistHTML, _T("wt"));		// open gamelist.html file for writting

	if(!glFp) return 0;

	TCHAR szDrvCount[260];
	_stprintf(szDrvCount, _T("%d"), DrvCount);

	// Check num. of clones
	int nCloneCnt = 0;

	for(unsigned int x = 1; x < DrvCount; x++) {
		if(_tcslen(BurnDrv[x].szParent)) {
			nCloneCnt++;
		}
	}

	// Start HTML Gamelist
	char szGameListHdr[3500];

	sprintf(szGameListHdr, " \
		<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.1//EN\" \"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd\"> \
		\
		<html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"en\"> \
		\
		<head> \
		<title>FB Alpha - Gamelist (generated by driverlist_gen.exe)</title> \
		<meta http-equiv=\"Content-Type\" content=\"text/html; charset=iso-8859-1\" /> \
		<style type=\"text/css\"> \
			body { \
				font-family: verdana, lucida, sans-serif; \
				font-size: 0.8em; \
				color: #333333; \
				background-color: #CE6A57; \
				margin: 0em; \
				text-align: center; \
			} \
		\
			a:link { \
				color: #C03029; \
				text-decoration: none; \
			} \
		\
			a:visited { \
				color: #C03029; \
				text-decoration: none; \
			} \
		\
			a:hover { \
				color: #333333; \
				text-decoration: underline; \
			} \
		\
			a:active { \
				color: #C03029; \
				text-decoration: underline; \
			} \
		\
			a.active:link { \
				color: #C03029; \
				text-decoration: none; \
				font-weight:bold; \
				font-style: italic; \
			} \
		\
			a.active:visited { \
				color: #C03029; \
				text-decoration: none; \
				font-weight:bold; \
				font-style: italic; \
			} \
		\
			a.active:hover { \
				color: #333333; \
				text-decoration: underline; \
				font-weight:bold; \
				font-style: italic; \
			} \
		\
			a.active:active { \
				color: #C03029; \
				text-decoration: underline; \
				font-weight:bold; \
				font-style: italic; \
			} \
		\
			h2 { \
				color: #C03029; \
				font-size: 1.4em; \
				margin-top: 1em; \
			} \
		\
			h3 { \
				color: #C03029; \
				font-size: 1.0em; \
			} \
		\
			li { \
				padding: 0.1em; \
			} \
			td { border: 1px; \
			border-style: dotted; \
			vertical-align: middle; padding-left: 0.5em; \
			/*text-align: center;*/ \
		} \
		.title { width: 600px; padding-left: 1em; } \
			.remarks { width: 200px; } \
			.a1 { background-color:#FFFCF4; } \
			.a2 { background-color:#FFFAE9; } \
		\
			.outer { \
				width: 1300px; \
				margin: 0em auto; \
				text-align: left; \
				padding: 0.7em 0.7em 0.7em 0.7em; \
				background-color: #FFFFFF; \
				border: 0.08em solid #808080; \
				margin-top: 1em; \
				margin-bottom: 1em; \
			} \
		\
			.note { \
				color: #C03029; \
				padding: 1em; \
				background-color: #DDD9D9; \
				font-style: italic; \
			} \
				.style1 \
				{ \
					width: 100%%; border-collapse: collapse;\
		\
				} \
		</style> \
		</head> \
		\
		<body> \
		\
		<div class=\"outer\"> \
		\
			<table align=\"center\" cellspacing=\"0\" cellpadding=\"2\" border=\"0\"class=\"style1\"> \
			<tr><td style=\"text-align: left;\"> \
			<h1>FB Alpha Gamelist</h1> \
			This list contains all games supported by FB Alpha.<br> \
			<br><br> \
			\
			%d games supported in total (%d clones); I = included in build; X = excluded from build; D = included in debug build only; W = working; NW = not working <br><br>\
			\
			</td></tr> \
			</table> \
			<br> \
			<table align=\"center\" cellspacing=\"0\" cellpadding=\"2\" border=\"0\" class=\"style1\"> \
			<tr style=\"font-weight:bold;background-color:#DDDBD8;\"><td>#</td><td>Name</td><td>Status</td><td class=\"title\">Full Name</td><td>Parent</td><td>Year</td><td>Company</td><td>Hardware</td><td class\"remarks\">Remarks</td></tr> \
		", 
		DrvCount, nCloneCnt);

	// Finalize HTML Gamelist
	char szGameListFtr[3500];

	sprintf(szGameListFtr, " </table> \
		<br> \
		</div> \
		\
		</body> \
		</html> \
		");

	// write -> gamelist.html

	int nRowAlt = 0;

	// Write Header
	wAnsi(szGameListHdr);

	// Content
	for(unsigned int x = 1; x < DrvCount; x++) {
		if(nRowAlt == 0) {
			nRowAlt = 1;
			wt(_T("<tr class=\"a1\"><td>")); 
		} else {
			nRowAlt = 0;
			wt(_T("<tr class=\"a2\"><td>"));
		}

		// Counter
		TCHAR szCnt[260];
		_stprintf(szCnt,_T("%d"), x);
		wt(szCnt);
		wt(_T("</td><td>"));

		//Name
		wt(BurnDrv[x].szShortName);
		wt(_T("</td><td>"));

		//Status
		wt(BurnDrv[x].szBuildStatus);
		wt(_T("&nbsp;&nbsp;"));
		wt(BurnDrv[x].szStatus);
		wt(_T("</td><td class=\"title\" style=\"text-align: left;\">"));

		//Full Name
		wt(_AtoT(BurnDrv[x].szFullNameA));
		wt(_T("</td><td>"));

		//parent
		wt(BurnDrv[x].szParent);
		wt(_T("</td><td>"));

		//Year
		wt(BurnDrv[x].szDate);
		wt(_T("</td><td>"));

		//Company
		wt(BurnDrv[x].szManufacturerA);
		wt(_T("</td><td>"));

		//Hardware
		wt(BurnDrv[x].szSystemA);
		wt(_T("</td><td class=\"remarks\">"));

		//Remarks
		wt(BurnDrv[x].szCommentA);
		wt(_T("</td></tr>"));
		
		wt(_T("\n"));
	
	}

	// Write footer
	wAnsi(szGameListFtr);

	if(glFp) fclose(glFp);

	return 1;
}

int CreateDriverlist(TCHAR szDriverlistHdr[260]) {
		
	dlFp = _tfopen(szDriverlistHdr, _T("wt"));	// open driverlist.h file for writting
	
	if(!dlFp) return 0;

	// write 'driverlist.h'
	
	wDL(_T("// This file was generated at pre-build event by: driverlist_gen.exe \n"));
	wDL(_T("// Declaration of all drivers\n"));
	wDL(_T("#define DRV extern struct BurnDriver\n"));
	
	bool bDebugOpen = 0;

	for(unsigned int x = 1; x < DrvCount; x++) {
		if(_tcscmp(BurnDrv[x].szBuildStatus, _T("X"))) {
			if(!_tcscmp(BurnDrv[x].szBuildStatus, _T("D"))) {
				
				// check if need to start another define
				if(!bDebugOpen) {
					wDL(_T("#if defined FBA_DEBUG\n"));
					bDebugOpen = 1;
				}				

				wDL(_T("DRV \t")); wDL(BurnDrv[x].szStructName); wDL(_T("; \t"));
				if(!_tcscmp(BurnDrv[x].szStatus, _T("NW"))) {
					wDL(_T("// ")); wDL(BurnDrv[x].szCommentA); wDL(_T(" [Not Working]")); 
				}

				wDL(_T("\n"));			

			} else {

				if(bDebugOpen) {
					wDL(_T("#endif\n"));
					bDebugOpen = 0;
				}

				wDL(_T("DRV \t")); wDL(BurnDrv[x].szStructName); wDL(_T("; \t"));
				if(!_tcscmp(BurnDrv[x].szStatus, _T("NW"))) {
					wDL(_T("// ")); wDL(BurnDrv[x].szCommentA); wDL(_T(" [Not Working]")); 
				}

				wDL(_T("\n"));
			}
		}
	}
	if(bDebugOpen) {
		wDL(_T("#endif\n"));
		bDebugOpen = 0;	
	}
	wDL(_T("#undef DRV\n"));
	
	// second part, structure...
	
	bDebugOpen = 0;

	wDL(_T("// Structure containing addresses of all drivers\n"));
	wDL(_T("// Needs to be kept sorted (using the full game name as the key) to prevent problems with the gamelist in Kaillera\n"));
	wDL(_T("static struct BurnDriver* pDriver[] = {\n"));

	for(unsigned int x = 1; x < DrvCount; x++) {
		if(_tcscmp(BurnDrv[x].szBuildStatus, _T("X"))) 
		{
			if(!_tcscmp(BurnDrv[x].szBuildStatus, _T("D"))) {

				// check if need to start another define
				if(!bDebugOpen) {
					wDL(_T("#if defined FBA_DEBUG\n"));
					bDebugOpen = 1;
				}

				if(!_tcscmp(BurnDrv[x].szStatus, _T("NW"))) {
					wDL(_T("\t&")); wDL(BurnDrv[x].szStructName); wDL(_T(", \t"));
					wDL(_T("// ")); wDL(_AtoT(BurnDrv[x].szFullNameA)); wDL(_T(" [")); wDL(BurnDrv[x].szCommentA);  wDL(_T(", Not Working]")); 
				} else {
					wDL(_T("\t&")); wDL(BurnDrv[x].szStructName); wDL(_T(", \t")); wDL(_T("// ")); wDL(_AtoT(BurnDrv[x].szFullNameA));
				}

				wDL(_T("\n"));

			} else {
				
				if(bDebugOpen) {
					wDL(_T("#endif\n"));
					bDebugOpen = 0;
				}

				if(!_tcscmp(BurnDrv[x].szStatus, _T("NW"))) {
					wDL(_T("\t&")); wDL(BurnDrv[x].szStructName); wDL(_T(", \t"));
					wDL(_T("// ")); wDL(_AtoT(BurnDrv[x].szFullNameA)); wDL(_T(" [")); wDL(BurnDrv[x].szCommentA);  wDL(_T(", Not Working]"));
				} else {
					wDL(_T("\t&")); wDL(BurnDrv[x].szStructName); wDL(_T(", \t")); wDL(_T("// ")); wDL(_AtoT(BurnDrv[x].szFullNameA));
				}

				wDL(_T("\n"));

			}
		}
	}
	if(bDebugOpen) {
		wDL(_T("#endif\n"));
		bDebugOpen = 0;	
	}
	wDL(_T("};\n"));

	// done! phew!

	if(dlFp) fclose(dlFp);

	return 1;
}

int GetDirFiles(TCHAR szDir[MAX_PATH])
{
	
	WIN32_FIND_DATA ffd;
	LARGE_INTEGER filesize;
	HANDLE hFind = INVALID_HANDLE_VALUE;

	TCHAR szTmp[MAX_PATH];
	TCHAR szDirConst[MAX_PATH];

	_tcscpy(szDirConst, szDir);
	_tcscat(szDir, _T("\\d_*.cpp"));
	
	// Find the first file in the directory
	hFind = FindFirstFile(szDir, &ffd);

	if (INVALID_HANDLE_VALUE == hFind)	return 0;

	do
	{
		if (ffd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) 
		{
			// DIRECTORY
		} else {

			// FILE

			bool bIncluded = false;

			for(unsigned int x=0; x < nFileCount; x++) 
			{
				// Compare scanned file with files on makefile...
				if(!_tcscmp(szDrvFile[x], ffd.cFileName)) {
					bIncluded = true;			// file matches with one specified on makefile, lets roll...
					break;
				} else {
					continue;					// not this one, keep going...
				}
			}

			// was the driver included on makefile?
			if(!bIncluded) {
				continue;	// not included, so keep checking other files...
			}

			// Now we can parse the file :)

			filesize.LowPart = ffd.nFileSizeLow;
			filesize.HighPart = ffd.nFileSizeHigh;

			_stprintf(szTmp, _T("%s\\%s"), szDirConst, ffd.cFileName);
			
			ParseDrvSource(szTmp);

			//if(bCheckOneFile) return 0;
		}
	} while (FindNextFile(hFind, &ffd) != 0);

	FindClose(hFind);

	return 1;
}

TCHAR szCpp[50000][1000];

int ParseDrvSource(TCHAR szSrcFile[MAX_PATH])
{
	//bCheckOneFile = false; // just one CPP (debug)

	FILE *fp = _tfopen(szSrcFile, _T("rt"));

	if (fp) 
	{
		unsigned int nCppLineCount = 0;
		while (!feof(fp)) 
		{
			// 1 - count source file lines
			nCppLineCount++;

			// 2 - copy lines to szCppLine[] array for future proccesing
			TCHAR szTmp[1000];

			if(_fgetts(szTmp, 1000, fp) == NULL) break;
			
			_stprintf((TCHAR*)szCpp[nCppLineCount], _T("%s"), szTmp);

			// copy of data done, crc32 verified and is precise :)
		}
		
		fclose(fp); // close file pointer

		for(unsigned int z = 0; z < nCppLineCount + 1; z++) 
		{
			// loop till end of lines array and evaluate data

			TCHAR szMainStr[3][MAX_PATH];

			_tcscpy(szMainStr[BRN_DRV],		_T("struct BurnDriver "));
			_tcscpy(szMainStr[BRN_DRV_D],	_T("struct BurnDriverD "));
			_tcscpy(szMainStr[BRN_DRV_X],	_T("struct BurnDriverX "));

			for(unsigned int i = 0; i < 3; i++) 
			{
				TCHAR szTmpLine[1000];
				_stprintf(szTmpLine, _T("%s"), szCpp[z]);

				if (!_tcsncmp(szMainStr[i], szTmpLine, _tcslen(szMainStr[i]))) 
				{					
					// Verify driver category
					switch(i) 
					{
						case BRN_DRV:
							_stprintf(BurnDrv[DrvCount].szBuildStatus, _T("I"));
							break;
						case BRN_DRV_D:
							_stprintf(BurnDrv[DrvCount].szBuildStatus, _T("D"));
							break;
						case BRN_DRV_X:
							_stprintf(BurnDrv[DrvCount].szBuildStatus, _T("X"));
							break;
					}

					// found a driver structure

					// we need to get the next string after 'BurnDriver' for example in: 
					
					//		struct BurnDriver 'BurnDrvCps1941' = {
					
					// to achieve this i need to:
					
					// 1 - copy entire line to a new string
					// 2 - remove the 'struct BurnDriver ' from the new string
					// 3 - remove white space characters
					// 4 - collect characters 1 by 1 until a = character is found
					// 5 - this should leave the new string like 'BurnDrvCps1941'


					// 1
					TCHAR szBrnDrv[MAX_PATH];
					_tcscpy(szBrnDrv, szCpp[z]);
					
					// 2

					_tcscpy(szBrnDrv, replace_str(szBrnDrv, szMainStr[i], _T("")));	// remove 

					// 3
					_tcscpy(szBrnDrv, replace_str(szBrnDrv, _T(" "), _T("")));	// remove white spaces
					
					// 4
					TCHAR szTmpStr[MAX_PATH] = _T("");
					for(unsigned int x = 0; x < _tcslen(szBrnDrv); x++) {

						TCHAR szChar[1];
						_stprintf(szChar, _T("%c"), szBrnDrv[x]);

						if(!_tcscmp(_T("="), szChar)) break;

						_tcscat(szTmpStr, szChar);
					}

					// 5
					_stprintf(BurnDrv[DrvCount].szStructName, _T("%s"), szTmpStr);

					// Start making a collection of lines until "};"
					TCHAR szStringColl[1000] = _T("");

					// while }; is not found keep collecting lines
					
					while(_tcsncmp(_T("};"), szTmpLine, 2)) {

						_tcscpy(szTmpLine, szCpp[z]);
						z++;						
						_tcscat(szStringColl, szTmpLine);
					}

					// Convert the multi-line struct to a single line for better processing
					
					TCHAR seps[]   = _T("\n\t"); // remove tabs and new lines
					TCHAR* token;
					TCHAR szOneLine[MAX_PATH] = _T("");

				   // get the first token
				   token = _tcstok(szStringColl, seps);

				   _tcscat(szOneLine, token);

				   while(token != NULL)  
				   {
					  token = _tcstok(NULL, seps);
					  _stprintf(szOneLine, _T("%s%s"), szOneLine, token);
				   }

				   _stprintf(szStringColl, _T("%s"), szOneLine);

					// 1 - Start checking for first value (szShortName)...					
					// 2 - Check if we find a " first or we find a N...
					// 3 - If a " is found keep storing characters until another " is found
					// 4 - Else if N is found keep storing until a , is found
					// 5 - we got the (szShortName) !

					bool bGotIt = 0;

					TCHAR szShortName[260]		= _T("");
					TCHAR szParent[260]			= _T("");
					TCHAR szBoardROM[260]		= _T(""); // not used
					TCHAR szDate[260]			= _T("");
					TCHAR szFullNameA[260]		= _T("");
					TCHAR szCommentA[260]		= _T("");
					TCHAR szManufacturerA[260]	= _T("");
					TCHAR szSystemA[260]		= _T("");

					_stprintf(szTmpStr, _T("%s = {"), szTmpStr);
					_tcscpy(szStringColl, replace_str(szStringColl, szTmpStr, _T("")));	// remove unneeded section

					int nCharLoc = 0;

					// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
					// szShortName [NAME]

					for(unsigned int x = 0; x < _tcslen(szStringColl); x++) 
					{
						TCHAR szChar[1];
						_stprintf(szChar, _T("%c"), szStringColl[x]);

						// find value between " "
						if(!_tcsncmp(_T("\""), szChar, 1)){
							int n = x + 1;
							for(unsigned int y = n; y < _tcslen(szStringColl); y++) 
							{
								_stprintf(szChar, _T("%c"), szStringColl[y]);

								if(!_tcscmp(_T("\""), szChar)) {
									// end
									bGotIt = 1;
									x = y + 1;
									break;
								}
								_tcscat(szShortName, szChar);
							}
						}

						// NULL						
						if(!_tcscmp(_T("N"), szChar) && !bGotIt) {
							
							int n = x;
							for(unsigned int y = n; y < _tcslen(szStringColl); y++) {

								_stprintf(szChar, _T("%c"), szStringColl[y]);

								if(!_tcscmp(_T(","), szChar)) {
									// end
									bGotIt = 1;
									x = y;
									break;
								}
							}
						}						
						if(bGotIt) {
							nCharLoc = x;
							bGotIt=0;
							break;
						}
					}

					// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
					// szParent [PARENT]

					for(unsigned int x = nCharLoc; x < _tcslen(szStringColl); x++) {

						TCHAR szChar[1];
						_stprintf(szChar, _T("%c"), szStringColl[x]);

						// find value between " "
						if(!_tcsncmp(_T("\""), szChar, 1)){
							int n = x + 1;
							for(unsigned int y = n; y < _tcslen(szStringColl); y++) {

								_stprintf(szChar, _T("%c"), szStringColl[y]);

								if(!_tcscmp(_T("\""), szChar)) {
									// end
									bGotIt = 1;
									x = y + 1;
									break;
								}
								_tcscat(szParent, szChar);
							}
						}

						// NULL						
						if(!_tcscmp(_T("N"), szChar) && !bGotIt) {
							
							int n = x;
							for(unsigned int y = n; y < _tcslen(szStringColl); y++) {

								_stprintf(szChar, _T("%c"), szStringColl[y]);

								if(!_tcscmp(_T(","), szChar)) {
									// end
									bGotIt = 1;
									x = y + 1;
									break;
								}
							}
						}						
						if(bGotIt) {
							bGotIt=0;
							nCharLoc = x;
							break;
						}
					}
		
					// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
					// szBoardROM [NOT USED]
					for(unsigned int x = nCharLoc; x < _tcslen(szStringColl); x++) {

						TCHAR szChar[1];
						_stprintf(szChar, _T("%c"), szStringColl[x]);

						// find value between " "
						if(!_tcsncmp(_T("\""), szChar, 1)){
							int n = x + 1;
							for(unsigned int y = n; y < _tcslen(szStringColl); y++) {

								_stprintf(szChar, _T("%c"), szStringColl[y]);

								if(!_tcscmp(_T("\""), szChar)) {
									// end
									bGotIt = 1;
									x = y + 1;
									break;
								}
								_tcscat(szBoardROM, szChar);
							}
						}

						// NULL						
						if(!_tcscmp(_T("N"), szChar) && !bGotIt) {
							
							int n = x;
							for(unsigned int y = n; y < _tcslen(szStringColl); y++) {

								_stprintf(szChar, _T("%c"), szStringColl[y]);

								if(!_tcscmp(_T(","), szChar)) {
									// end
									bGotIt = 1;
									x = y + 1;
									break;
								}
							}
						}						
						if(bGotIt) {
							bGotIt=0;
							nCharLoc = x;
							break;
						}
					}

					// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
					// szDate
					for(unsigned int x = nCharLoc; x < _tcslen(szStringColl); x++) {

						TCHAR szChar[1];
						_stprintf(szChar, _T("%c"), szStringColl[x]);

						// find value between " "
						if(!_tcsncmp(_T("\""), szChar, 1)){
							int n = x + 1;
							for(unsigned int y = n; y < _tcslen(szStringColl); y++) {

								_stprintf(szChar, _T("%c"), szStringColl[y]);

								if(!_tcscmp(_T("\""), szChar)) {
									// end
									bGotIt = 1;
									x = y + 1;
									break;
								}
								_tcscat(szDate, szChar);
							}
						}

						// NULL						
						if(!_tcscmp(_T("N"), szChar) && !bGotIt) {
							
							int n = x;
							for(unsigned int y = n; y < _tcslen(szStringColl); y++) {

								_stprintf(szChar, _T("%c"), szStringColl[y]);

								if(!_tcscmp(_T(","), szChar)) {
									// end
									bGotIt = 1;
									x = y + 1;
									break;
								}
							}
						}						
						if(bGotIt) {
							bGotIt=0;
							nCharLoc = x;
							break;
						}
					}

					// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
					// szFullNameA
					for(unsigned int x = nCharLoc; x < _tcslen(szStringColl); x++) {

						TCHAR szChar[1];
						_stprintf(szChar, _T("%c"), szStringColl[x]);

						// find value between " "
						if(!_tcsncmp(_T("\""), szChar, 1)){
							int n = x + 1;
							for(unsigned int y = n; y < _tcslen(szStringColl); y++) {

								_stprintf(szChar, _T("%c"), szStringColl[y]);

								if(!_tcscmp(_T("\""), szChar)) {
									// end
									bGotIt = 1;
									x = y + 1;
									break;
								}
								_tcscat(szFullNameA, szChar);
							}
						}

						// NULL						
						if(!_tcscmp(_T("N"), szChar) && !bGotIt) {
							
							int n = x;
							for(unsigned int y = n; y < _tcslen(szStringColl); y++) {

								_stprintf(szChar, _T("%c"), szStringColl[y]);

								if(!_tcscmp(_T(","), szChar)) {
									// end
									bGotIt = 1;
									x = y + 1;
									break;
								}
							}
						}						
						if(bGotIt) {
							bGotIt=0;
							nCharLoc = x;
							break;
						}
					}

					// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
					// szCommentA
					for(unsigned int x = nCharLoc; x < _tcslen(szStringColl); x++) {

						TCHAR szChar[1];
						_stprintf(szChar, _T("%c"), szStringColl[x]);

						// find value between " "
						if(!_tcsncmp(_T("\""), szChar, 1)){
							int n = x + 1;
							for(unsigned int y = n; y < _tcslen(szStringColl); y++) {

								_stprintf(szChar, _T("%c"), szStringColl[y]);

								if(!_tcscmp(_T("\""), szChar)) {
									// end
									bGotIt = 1;
									x = y + 1;
									break;
								}
								_tcscat(szCommentA, szChar);
							}
						}

						// NULL						
						if(!_tcscmp(_T("N"), szChar) && !bGotIt) {
							
							int n = x;
							for(unsigned int y = n; y < _tcslen(szStringColl); y++) {

								_stprintf(szChar, _T("%c"), szStringColl[y]);

								if(!_tcscmp(_T(","), szChar)) {
									// end
									bGotIt = 1;
									x = y + 1;
									break;
								}
							}
						}						
						if(bGotIt) {
							bGotIt=0;
							nCharLoc = x;
							break;
						}
					}

					// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
					// szManufacturerA
					for(unsigned int x = nCharLoc; x < _tcslen(szStringColl); x++) {

						TCHAR szChar[1];
						_stprintf(szChar, _T("%c"), szStringColl[x]);

						// find value between " "
						if(!_tcsncmp(_T("\""), szChar, 1)){
							int n = x + 1;
							for(unsigned int y = n; y < _tcslen(szStringColl); y++) {

								_stprintf(szChar, _T("%c"), szStringColl[y]);

								if(!_tcscmp(_T("\""), szChar)) {
									// end
									bGotIt = 1;
									x = y + 1;
									break;
								}
								_tcscat(szManufacturerA, szChar);
							}
						}

						// NULL						
						if(!_tcscmp(_T("N"), szChar) && !bGotIt) {
							
							int n = x;
							for(unsigned int y = n; y < _tcslen(szStringColl); y++) {

								_stprintf(szChar, _T("%c"), szStringColl[y]);

								if(!_tcscmp(_T(","), szChar)) {
									// end
									bGotIt = 1;
									x = y + 1;
									break;
								}
							}
						}						
						if(bGotIt) {
							bGotIt=0;
							nCharLoc = x;
							break;
						}
					}

					// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
					// szSystemA
					for(unsigned int x = nCharLoc; x < _tcslen(szStringColl); x++) {

						TCHAR szChar[1];
						_stprintf(szChar, _T("%c"), szStringColl[x]);

						// find value between " "
						if(!_tcsncmp(_T("\""), szChar, 1)){
							int n = x + 1;
							for(unsigned int y = n; y < _tcslen(szStringColl); y++) {

								_stprintf(szChar, _T("%c"), szStringColl[y]);

								if(!_tcscmp(_T("\""), szChar)) {
									// end
									bGotIt = 1;
									x = y + 1;
									break;
								}
								_tcscat(szSystemA, szChar);
							}
						}

						// NULL						
						if(!_tcscmp(_T("N"), szChar) && !bGotIt) {
							
							int n = x;
							for(unsigned int y = n; y < _tcslen(szStringColl); y++) {

								_stprintf(szChar, _T("%c"), szStringColl[y]);

								if(!_tcscmp(_T(","), szChar)) {
									// end
									bGotIt = 1;
									x = y + 1;
									break;
								}
							}
						}						
						if(bGotIt) {
							bGotIt=0;
							nCharLoc = x;
							break;
						}
					}

					// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
					// BDF_GAME_WORKING

					if(_tcsstr(szStringColl, _T("BDF_GAME_WORKING"))) 
					{
						_stprintf(BurnDrv[DrvCount].szStatus,	_T("W"), szShortName);

					} else {
						_stprintf(BurnDrv[DrvCount].szStatus,	_T("NW"), szShortName);
					}

					_stprintf(BurnDrv[DrvCount].szShortName,	_T("%s"), szShortName);
					_stprintf(BurnDrv[DrvCount].szParent,		_T("%s"), szParent);
					_stprintf(BurnDrv[DrvCount].szBoardROM,		_T("%s"), szBoardROM);
					_stprintf(BurnDrv[DrvCount].szDate,			_T("%s"), szDate);

					sprintf(BurnDrv[DrvCount].szFullNameA,		"%s", _TtoA(szFullNameA));	// ANSI for qsort()

					TCHAR szTmp[260];
					_stprintf(szTmp, _T("%s"), replace_str(_AtoT(BurnDrv[DrvCount].szFullNameA), _T("\\0"), _T("")) );	// remove unneeded section
					
					sprintf(BurnDrv[DrvCount].szFullNameA, "%s", _TtoA(szTmp));

					_stprintf(BurnDrv[DrvCount].szCommentA,		_T("%s"), szCommentA);
					_stprintf(BurnDrv[DrvCount].szManufacturerA,_T("%s"), szManufacturerA);
					_stprintf(BurnDrv[DrvCount].szSystemA,		_T("%s"), szSystemA);

					DrvCount++;

				} // if
			} // for
		} //for	
	} else {
		return 0; // !fp
	}
	return 1;
}

static int ScanBurnDir(TCHAR szBurnDir[260]) 
{
	WIN32_FIND_DATA	ffd;
	HANDLE hFind = INVALID_HANDLE_VALUE;
	
	TCHAR filter[260];
	_stprintf(filter, _T("%s\\*"), szBurnDir);

	hFind = FindFirstFile(filter, &ffd);

	if(INVALID_HANDLE_VALUE == hFind) 
		return 1;
	
	// Scan for directories in 'burn\'
	while(FindNextFile(hFind, &ffd) != 0)
	{
		if (ffd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY && _tcscmp(ffd.cFileName, _T(".")) && _tcscmp(ffd.cFileName, _T("..")))
		{
			_stprintf(BurnDir[nSub[0]].sub[0], _T("%s\\%s"), szBurnDir, ffd.cFileName);
			nSub[0]++;
		} 
	}

	// Scan sub-directories (up to 3 sub directories supported, can be updated if neccessary)
	for(unsigned int x = 0; x < 1; x++) {
		for(unsigned int y = 0; y < 2; y++) {
			while(nSubCount[x] < nSub[y]) {	

				_stprintf(filter, _T("%s\\*"), BurnDir[nSubCount[x]].sub[y]);
				hFind = FindFirstFile(filter, &ffd);

				while(FindNextFile(hFind, &ffd) != 0) {
					// Filter directories only
					if (ffd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY && _tcscmp(ffd.cFileName, _T(".")) && _tcscmp(ffd.cFileName, _T("..")))
					{
						_stprintf(BurnDir[nSub[y]].sub[y], _T("%s\\%s"), BurnDir[nSubCount[x]].sub[y], ffd.cFileName);
						nSub[y]++;
					}
				}
				nSubCount[x]++;
			}
		}
	}
	
	// finish!
	FindClose(hFind);	
	return 0;
}
