// Very simple module to download a file using WinInet API (CaptainCPS-X)
#include "burner.h"
#include <wininet.h>

bool bEnableAutoSupportFileDownload = false;
static TCHAR szFILESERVER1[512] = _T("http://fightercore.plesk3.freepgs.com/files/neosource/fba/support/");

int FileDownload(TCHAR* szLocalImageDir, TCHAR* szLocalFilePath, TCHAR* szFile, TCHAR* szServerDir)
{
	HINTERNET url, open;
	//int nErrorCode	= 0;
	DWORD buffer	= 0;
	char *content	= NULL;

	FILE* dlPointer = NULL;
	TCHAR szFinalURL[512] = _T("");
	
	if (bEnableAutoSupportFileDownload == false) return 0;
	
	// Prepare final URL for current download
	_stprintf(szFinalURL, _T("%s%s%s"), szFILESERVER1, szServerDir, szFile);

	// Start initialization for this connection
	open = InternetOpen(_T("FBA_Download"), INTERNET_OPEN_TYPE_DIRECT, NULL, NULL, 0);
	
	// Connect to the final URL to start transfer later
	url = InternetOpenUrl(open, szFinalURL, NULL, 0, INTERNET_FLAG_NO_AUTO_REDIRECT, 0);
	TCHAR szStatusCode[32];                                              
	DWORD dwStatusCodeSize = 32;                                            

	if (!HttpQueryInfo(url,HTTP_QUERY_STATUS_CODE,szStatusCode, &dwStatusCodeSize, NULL)) 
	{
		return 0; // server not available

	} else {

		long nStatusCode = _ttol(szStatusCode);

		if (nStatusCode == HTTP_STATUS_OK)
		{
			// Create a new empty file for writing binary data
			dlPointer = _tfopen(szLocalFilePath, _T("wb"));

			// Check if the file was created...
			if(!dlPointer)
			{
				// Make sure a directory is present for the file
				CreateDirectory(szLocalImageDir, NULL);

				// Try creating the file again...
				dlPointer = _tfopen(szLocalFilePath, _T("wb"));

				if(!dlPointer) 
					return 0; // error creating the file
			}

			TCHAR szContentSize[32];                                              
			DWORD dwContentSizeSize = 32;   
			if (HttpQueryInfo(url,HTTP_QUERY_CONTENT_LENGTH,szContentSize, &dwContentSizeSize, NULL))
			{
				long nContentSize = _ttol(szContentSize);
				content = (char*)malloc(nContentSize);
				// Transfer the file contents and write them to the created file
				while(InternetReadFile(url, content, sizeof(content), &buffer) && buffer != 0) {
					fwrite(content, 1, buffer, dlPointer);
					content[buffer] = '\0';
				}

				// Done with file writing so close the file pointer
				fclose(dlPointer);
			} else {
				return 0; // HttpQueryInfo() failed [?]
			}
		} else {
			return 0;
		}
		//nErrorCode = nStatusCode;
	}

	if (content) {
		free(content);
	}

	buffer = 0;
	
	if(url) {
		InternetCloseHandle(url);
	}

	if(open) {
		InternetCloseHandle(open);
	}

	//if(nErrorCode != HTTP_STATUS_OK) return 0; // error

	return 1; // All good!
}
