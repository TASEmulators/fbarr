// Burner data file module (for ROM managers)
// written    2001 LoqiqX
// updated 11/2003 by LvR -- essentially a rewrite

#include "burner.h"

static void ReplaceAmpersand(char *szBuffer, char *szGameName)
{
	unsigned int nStringPos = 0;
	
	for (unsigned int i = 0; i < strlen(szGameName); i++) {
		if (szGameName[i] == '&') {
			szBuffer[nStringPos + 0] = '&';
			szBuffer[nStringPos + 1] = 'a';
			szBuffer[nStringPos + 2] = 'm';
			szBuffer[nStringPos + 3] = 'p';
			szBuffer[nStringPos + 4] = ';';
			nStringPos += 5;
		} else {
			szBuffer[nStringPos] = szGameName[i];
			nStringPos++;
		}
	}
}

int write_datfile(int nDatType, int bIncMegadrive, FILE* fDat)
{
	int nRet=0;
	unsigned int nOldSelect=0;
	unsigned int nGameSelect=0;
	unsigned int nParentSelect,nBoardROMSelect;

	nOldSelect=nBurnDrvSelect;										// preserve the currently selected driver

	// Go over each of the games
	for (nGameSelect=0;nGameSelect<nBurnDrvCount;nGameSelect++)
	{
		char sgName[16];
		char spName[16];
		char sbName[16];
		unsigned int i=0;
		int nPass=0;

		nBurnDrvSelect=nGameSelect;									// Switch to driver nGameSelect

		if (BurnDrvGetFlags() & BDF_BOARDROM) {
			continue;
		}
		
		if (((BurnDrvGetHardwareCode() & HARDWARE_PUBLIC_MASK) == HARDWARE_SEGA_MEGADRIVE) && (bIncMegadrive == 0)) {
			continue;
		}
		
		if (((BurnDrvGetHardwareCode() & HARDWARE_PUBLIC_MASK) != HARDWARE_SEGA_MEGADRIVE) && (bIncMegadrive == 2)) {
			continue;
		}

		strcpy(sgName, BurnDrvGetTextA(DRV_NAME));
		strcpy(spName, "");											// make sure this string is empty before we start
		strcpy(sbName, "");											// make sure this string is empty before we start

		// Check to see if the game has a parent
		if (BurnDrvGetTextA(DRV_PARENT))
		{
			nParentSelect=-1U;
			while (BurnDrvGetTextA(DRV_PARENT))
			{
				strcpy(spName, BurnDrvGetTextA(DRV_PARENT));
				for (i=0;i<nBurnDrvCount;i++)
				{
					nBurnDrvSelect=i;
					if (!strcmp(spName, BurnDrvGetTextA(DRV_NAME)))
					{
						nParentSelect=i;
						break;
					}
				}
			}

			nBurnDrvSelect=nGameSelect;								// restore driver select
		}
		else
			nParentSelect=nGameSelect;

		// Check to see if the game has a BoardROM
		if (BurnDrvGetTextA(DRV_BOARDROM))
		{
			nBoardROMSelect=-1U;
			strcpy(sbName, BurnDrvGetTextA(DRV_BOARDROM));
			for (i=0;i<nBurnDrvCount;i++)
			{
				nBurnDrvSelect=i;
				if (!strcmp(sbName, BurnDrvGetTextA(DRV_NAME)))
				{
					nBoardROMSelect=i;
					break;
				}
			}

			nBurnDrvSelect=nGameSelect;								// restore driver select
		}
		else
			nBoardROMSelect=nGameSelect;

		if (nDatType == 0)
		{
			// Report problems
			if (nParentSelect==-1U)
				fprintf(fDat, "# Missing parent %s. It needs to be added to " APP_TITLE "!\n\n", spName);
			if (nBoardROMSelect==-1U)
				fprintf(fDat, "# Missing boardROM %s. It needs to be added to " APP_TITLE "!\n\n", sbName);

			// Write the header
			fprintf(fDat, "game (\n");
			fprintf(fDat, "\tname %s\n", sgName);

			if (nParentSelect!=nGameSelect && nParentSelect!=-1U)
			{
				fprintf(fDat, "\tcloneof %s\n", spName);
				fprintf(fDat, "\tromof %s\n", spName);
			}
			else
			{
				// Add "romof" (but not 'cloneof') line for games that have boardROMs
				if (nBoardROMSelect!=nGameSelect && nBoardROMSelect!=-1U)
				{
					fprintf(fDat, "\tromof %s\n", sbName);
				}
			}

			fprintf(fDat, "\tdescription \"%s\"\n", DecorateGameName(nBurnDrvSelect));
			fprintf(fDat, "\tyear %s\n", BurnDrvGetTextA(DRV_DATE));
			fprintf(fDat, "\tmanufacturer \"%s\"\n", BurnDrvGetTextA(DRV_MANUFACTURER));
		}
		
		if (nDatType == 2)
		{
			// Report problems
			if (nParentSelect==-1U)
				fprintf(fDat, "# Missing parent %s. It needs to be added to " APP_TITLE "!\n\n", spName);
			if (nBoardROMSelect==-1U)
				fprintf(fDat, "# Missing boardROM %s. It needs to be added to " APP_TITLE "!\n\n", sbName);

			// Write the header
			if (nParentSelect!=nGameSelect && nParentSelect!=-1U)
			{
				fprintf(fDat, "\t<game name=\"%s\" cloneof=\"%s\" romof=\"%s\">\n", sgName, spName, sbName);
			}
			else
			{
				// Add "romof" (but not 'cloneof') line for games that have boardROMs
				if (nBoardROMSelect!=nGameSelect && nBoardROMSelect!=-1U)
				{
					fprintf(fDat, "\t<game name=\"%s\" romof=\"%s\">\n", sgName, sbName);
				} else {
					fprintf(fDat, "\t<game name=\"%s\">\n", sgName);
				}
			}
			
			char szGameName[255];
			char szGameNameBuffer[255];
			char szManufacturer[255];
			char szManufacturerBuffer[255];
			
			memset(szGameName, 0, 255);
			memset(szGameNameBuffer, 0, 255);
			memset(szManufacturer, 0, 255);
			memset(szManufacturerBuffer, 0, 255);
			
			strcpy(szGameName, DecorateGameName(nBurnDrvSelect));
			ReplaceAmpersand(szGameNameBuffer, szGameName);
			strcpy(szManufacturer, BurnDrvGetTextA(DRV_MANUFACTURER));
			ReplaceAmpersand(szManufacturerBuffer, szManufacturer);
			
//			fprintf(fDat, "\t\t<description>%s</description>\n", DecorateGameName(nBurnDrvSelect));
			fprintf(fDat, "\t\t<description>%s</description>\n", szGameNameBuffer);
			fprintf(fDat, "\t\t<year>%s</year>\n", BurnDrvGetTextA(DRV_DATE));
//			fprintf(fDat, "\t\t<manufacturer>%s</manufacturer>\n", BurnDrvGetTextA(DRV_MANUFACTURER));
			fprintf(fDat, "\t\t<manufacturer>%s</manufacturer>\n", szManufacturerBuffer);
		}

		// Write the individual ROM info
		for (nPass=0; nPass<2; nPass++)
		{
			nBurnDrvSelect=nGameSelect;

			// Skip pass 0 if possible
			if (nPass==0 && (nBoardROMSelect==nGameSelect || nBoardROMSelect==-1U || nDatType == 1 || nDatType == 2))
				continue;

			// Go over each of the files needed for this game (upto 0x0100)
			for (i=0, nRet=0; nRet==0 && i<0x100; i++)
			{
				int nRetTmp=0;
				struct BurnRomInfo ri;
				int nLen; unsigned int nCrc;
				char *szPossibleName=NULL;
				int j, nMerged=0;

				memset(&ri,0,sizeof(ri));

				// Get info on this file
				nBurnDrvSelect=nGameSelect;
				nRet=BurnDrvGetRomInfo(&ri,i);
				nRet+=BurnDrvGetRomName(&szPossibleName,i,0);

				if (ri.nLen==0) continue;

				if (nRet==0)
				{
					struct BurnRomInfo riTmp;
					char *szPossibleNameTmp;
					nLen=ri.nLen; nCrc=ri.nCrc;

					// Check for files from boardROMs
					if (nBoardROMSelect!=nGameSelect && nBoardROMSelect!=-1U) {
						nBurnDrvSelect=nBoardROMSelect;
						nRetTmp=0;

						// Go over each of the files needed for this game (upto 0x0100)
						for (j=0; nRetTmp==0 && j<0x100; j++)
						{
							memset(&riTmp,0,sizeof(riTmp));

							nRetTmp+=BurnDrvGetRomInfo(&riTmp,j);
							nRetTmp+=BurnDrvGetRomName(&szPossibleNameTmp,j,0);

							if (nRetTmp==0)
							{
								if (riTmp.nLen && riTmp.nCrc==nCrc && !strcmp(szPossibleName, szPossibleNameTmp))
								{
									// This file is from a boardROM
									nMerged|=2;
									nRetTmp++;
								}
							}
						}
					}

					if (!nMerged && nParentSelect!=nGameSelect && nParentSelect!=-1U) {
						nBurnDrvSelect=nParentSelect;
						nRetTmp=0;

						// Go over each of the files needed for this game (upto 0x0100)
						for (j=0; nRetTmp==0 && j<0x100; j++)
						{
							memset(&riTmp,0,sizeof(riTmp));

							nRetTmp+=BurnDrvGetRomInfo(&riTmp,j);
							nRetTmp+=BurnDrvGetRomName(&szPossibleNameTmp,j,0);

							if (nRetTmp==0)
							{
								if (riTmp.nLen && riTmp.nCrc==nCrc && !strcmp(szPossibleName, szPossibleNameTmp))
								{
									// This file is from a parent set
									nMerged|=1;
									nRetTmp++;
								}
							}
						}
					}

					nBurnDrvSelect=nGameSelect;						// Switch back to game
				}

				if (nDatType == 0)
				{
					// Selectable BIOS meta info
					if (nPass==0 && nMerged&2 && ri.nType&BRF_SELECT)
						fprintf(fDat, "\tbiosset ( name %d description \"%s\" %s)\n", i - 128, szPossibleName, ri.nType & BRF_OPT ? "" : "default yes ");
					// File info
					if (nPass==1 && !nMerged) {
						if (ri.nType & BRF_NODUMP) {
							fprintf(fDat, "\trom ( name %s size %d flags nodump )\n", szPossibleName, ri.nLen);
						} else {
							fprintf(fDat, "\trom ( name %s size %d crc %08x )\n", szPossibleName, ri.nLen, ri.nCrc);
						}
					}
					if (nPass==1 && nMerged)
					{
						// Selectable BIOS file info
						if (nMerged&2 && ri.nType&BRF_SELECT)
							fprintf(fDat, "\trom ( name %s merge %s bios %d size %d crc %08x )\n", szPossibleName, szPossibleName, i - 128, ri.nLen, ri.nCrc);
						// Files from parent/boardROMs
						else {
							if (ri.nType & BRF_NODUMP) {
								fprintf(fDat, "\trom ( name %s merge %s size %d flags nodump )\n", szPossibleName, szPossibleName, ri.nLen);
							} else {
								fprintf(fDat, "\trom ( name %s merge %s size %d crc %08x )\n", szPossibleName, szPossibleName, ri.nLen, ri.nCrc);
							}
						}
					}
				}
				
				if (nDatType == 1)
				{
					if (nPass == 0) continue;						// No meta info needed

					if (nParentSelect!=nGameSelect && nParentSelect!=-1U)
					{
						nBurnDrvSelect=nParentSelect;				// Switch to parent
						fprintf(fDat, "�%s�%s", spName, DecorateGameName(nBurnDrvSelect));
						nBurnDrvSelect=nGameSelect;					// Switch back to game
					}
					else
						fprintf(fDat, "�%s�%s", BurnDrvGetTextA(DRV_NAME), DecorateGameName(nBurnDrvSelect));

					fprintf(fDat, "�%s�%s", BurnDrvGetTextA(DRV_NAME), DecorateGameName(nBurnDrvSelect));

		   			fprintf(fDat, "�%s�%08x�%d", szPossibleName, ri.nCrc, ri.nLen);

					if (nParentSelect!=nGameSelect && nParentSelect!=-1U)
					{
						// Files from parent
						fprintf(fDat, "�%s", spName);
					}
					else
					{
						// Files from boardROM
						if (nBoardROMSelect!=nGameSelect && nBoardROMSelect!=-1U)
							fprintf(fDat, "�%s", sbName);
					}

					if (!nMerged)
						fprintf(fDat, "���\n");
					else
						fprintf(fDat, "�%s�\n", szPossibleName);
				}
				
				if (nDatType == 2)
				{
					char szPossibleNameBuffer[255];
			
					memset(szPossibleNameBuffer, 0, 255);
			
					ReplaceAmpersand(szPossibleNameBuffer, szPossibleName);
					
					// File info
					if (nPass==1 && !nMerged) {
						if (ri.nType & BRF_NODUMP) {
							fprintf(fDat, "\t\t<rom name=\"%s\" size=\"%d\" status=\"nodump\"/>\n", szPossibleNameBuffer, ri.nLen);
						} else {
							fprintf(fDat, "\t\t<rom name=\"%s\" size=\"%d\" crc=\"%08x\"/>\n", szPossibleNameBuffer, ri.nLen, ri.nCrc);
						}
					}
					if (nPass==1 && nMerged)
					{
						// Files from parent/boardROMs
						if (ri.nType & BRF_NODUMP) {
							fprintf(fDat, "\t\t<rom name=\"%s\" merge=\"%s\" size=\"%d\" status=\"nodump\"/>\n", szPossibleNameBuffer, szPossibleNameBuffer, ri.nLen);
						} else {
							fprintf(fDat, "\t\t<rom name=\"%s\" merge=\"%s\" size=\"%d\" crc=\"%08x\"/>\n", szPossibleNameBuffer, szPossibleNameBuffer, ri.nLen, ri.nCrc);
						}
					}
				}
			}
		}

		if (nDatType == 0) fprintf(fDat, ")\n\n");
		if (nDatType == 2) fprintf(fDat, "\t</game>\n");
	}

	if (nDatType == 1 && (bIncMegadrive != 2)) fprintf(fDat, "[RESOURCES]\n");

	// Do another pass over each of the games to find boardROMs
	for (nBurnDrvSelect=0; nBurnDrvSelect<nBurnDrvCount; nBurnDrvSelect++)
	{
		int i, nPass;

		if (!(BurnDrvGetFlags() & BDF_BOARDROM)) {
			continue;
		}
		
		if (((BurnDrvGetHardwareCode() & HARDWARE_PUBLIC_MASK) != HARDWARE_SEGA_MEGADRIVE) && (bIncMegadrive == 2)) {
			continue;
		}

		if (nDatType == 0)
		{
			fprintf(fDat, "resource (\n");
			fprintf(fDat, "\tname %s\n", BurnDrvGetTextA(DRV_NAME));
			fprintf(fDat, "\tdescription \"%s\"\n", DecorateGameName(nBurnDrvSelect));
			fprintf(fDat, "\tyear %s\n", BurnDrvGetTextA(DRV_DATE));
			fprintf(fDat, "\tmanufacturer \"%s\"\n", BurnDrvGetTextA(DRV_COMMENT));

		}
		
		if (nDatType == 2)
		{
			fprintf(fDat, "\t<game isbios=\"yes\" name=\"%s\">\n", BurnDrvGetTextA(DRV_NAME));
			fprintf(fDat, "\t\t<description>%s</description>\n", DecorateGameName(nBurnDrvSelect));
			fprintf(fDat, "\t\t<year>%s</year>\n", BurnDrvGetTextA(DRV_DATE));
			fprintf(fDat, "\t\t<manufacturer>%s</manufacturer>\n", BurnDrvGetTextA(DRV_MANUFACTURER));		
		}

		for (nPass=0; nPass<2; nPass++)
		{
			// No meta information needed
			if (nPass==0 && (nDatType == 1 || nDatType == 2)) continue;

			// Go over each of the individual files (upto 0x0100)
			for (i=0; i<0x100; i++)
			{
				struct BurnRomInfo ri;
				char *szPossibleName=NULL;

				memset(&ri,0,sizeof(ri));

				nRet=BurnDrvGetRomInfo(&ri,i);
				nRet+=BurnDrvGetRomName(&szPossibleName,i,0);

				if (ri.nLen==0) continue;

				if (nRet==0) {
					if (nDatType == 0)
					{
						if (nPass==0)
						{
							if (ri.nType&BRF_SELECT)
								fprintf(fDat, "\tbiosset ( name %d description \"%s\" %s)\n", i, szPossibleName, ri.nType & 0x80 ? "" : "default yes ");
						}
						else
						{
							if (ri.nType&BRF_SELECT)
								fprintf(fDat, "\trom ( name %s bios %d size %d crc %08x )\n", szPossibleName, i, ri.nLen, ri.nCrc);
							else
								fprintf(fDat, "\trom ( name %s size %d crc %08x )\n", szPossibleName, ri.nLen, ri.nCrc);
						}
					}
					
					if (nDatType == 1)
					{
						fprintf(fDat, "�%s�%s", BurnDrvGetTextA(DRV_NAME), DecorateGameName(nBurnDrvSelect));
						fprintf(fDat, "�%s�%s", BurnDrvGetTextA(DRV_NAME), DecorateGameName(nBurnDrvSelect));
			   			fprintf(fDat, "�%s�%08x�%d", szPossibleName, ri.nCrc, ri.nLen);
						fprintf(fDat, "���\n");
					}
					
					if (nDatType == 2)
					{
						char szPossibleNameBuffer[255];
			
						memset(szPossibleNameBuffer, 0, 255);
			
						ReplaceAmpersand(szPossibleNameBuffer, szPossibleName);
					
						fprintf(fDat, "\t\t<rom name=\"%s\" size=\"%d\" crc=\"%08x\"/>\n", szPossibleNameBuffer, ri.nLen, ri.nCrc);
					}
				}
			}
		}

		if (nDatType == 0) fprintf(fDat, ")\n");
		if (nDatType == 2) fprintf(fDat, "\t</game>\n");
	}

	// Restore current driver
	nBurnDrvSelect=nOldSelect;
	
	if (nDatType == 2) fprintf(fDat, "</datafile>");

	return 0;
}

int create_datfile(TCHAR* szFilename, int nDatType, int bIncMegadrive)
{
	FILE *fDat=0;
	int nRet=0;
	
	if ((fDat = _tfopen(szFilename, _T("wt")))==0)
		return -1;

	if (nDatType==0)
	{
		fprintf(fDat, "clrmamepro (\n");
		fprintf(fDat, "\tname \"" APP_TITLE "\"\n");
		_ftprintf(fDat, _T("\tdescription \"") _T(APP_TITLE) _T(" v%s\"\n"), szAppBurnVer);
		fprintf(fDat, "\tcategory \"" APP_DESCRIPTION "\"\n");
		_ftprintf(fDat, _T("\tversion %s\n"), szAppBurnVer);
		_ftprintf(fDat, _T("\tauthor \"") _T(APP_TITLE) _T(" v%s\"\n"), szAppBurnVer);
		fprintf(fDat, "\tforcezipping zip\n");
		fprintf(fDat, ")\n\n");
	}
	
	if (nDatType == 1) {
		fprintf(fDat, "[CREDITS]\n");
		fprintf(fDat, "Author=" APP_TITLE "\n");
		_ftprintf(fDat, _T("Version=%s\n"), szAppBurnVer);
		fprintf(fDat, "Comment=" APP_DESCRIPTION "\n");
		fprintf(fDat, "[DAT]\n");
		fprintf(fDat, "version=2.50\n");
		fprintf(fDat, "plugin=arcade.dll\n");
		fprintf(fDat, "split=\n");
		fprintf(fDat, "merge=\n");
		fprintf(fDat, "[EMULATOR]\n");
		fprintf(fDat, "refname=" APP_TITLE "\n");
		_ftprintf(fDat, _T("version=") _T(APP_TITLE) _T(" v%s\n"), szAppBurnVer);
		fprintf(fDat, "[GAMES]\n");
	}
	
	if (nDatType == 2) {
		fprintf(fDat, "<?xml version=\"1.0\"?>\n");
		fprintf(fDat, "<!DOCTYPE datafile PUBLIC \"-//FB Alpha//DTD ROM Management Datafile//EN\" \"http://www.logiqx.com/Dats/datafile.dtd\">\n\n");
		fprintf(fDat, "<datafile>\n");
		fprintf(fDat, "\t<header>\n");
		fprintf(fDat, "\t\t<name>" APP_TITLE "</name>\n");
		_ftprintf(fDat, _T("\t\t<description>") _T(APP_TITLE) _T(" v%s") _T("</description>\n"), szAppBurnVer);
		fprintf(fDat, "\t\t<category>Standard DatFile</category>\n");
		_ftprintf(fDat, _T("\t\t<version>%s</version>\n"), szAppBurnVer);
		fprintf(fDat, "\t\t<author>" APP_TITLE "</author>\n");
		fprintf(fDat, "\t\t<homepage>http://www.barryharris.me.uk/</homepage>\n");
		fprintf(fDat, "\t\t<url>http://www.barryharris.me.uk/</url>\n");
		fprintf(fDat, "\t\t<clrmamepro forcenodump=\"ignore\"/>\n");		
		fprintf(fDat, "\t</header>\n");
	}

	nRet =  write_datfile(nDatType, bIncMegadrive, fDat);

	fclose(fDat);

	return nRet;
}
