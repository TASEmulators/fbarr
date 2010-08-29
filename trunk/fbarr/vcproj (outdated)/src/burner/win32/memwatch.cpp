#include "burner.h"

HWND hwndMemWatch=0;
static HDC hdc;
static char addresses[24][17];
static char labels[24][25];
static int NeedsInit = 1;
static BOOL bLoadingMemWatchFile;

HFONT hFixedFont=NULL;

static char *U8ToStr(UINT8 a)
{
 static char TempArray[16];
 TempArray[0] = '0' + a/100;
 TempArray[1] = '0' + (a%100)/10;
 TempArray[2] = '0' + (a%10);
 TempArray[3] = 0;
 return TempArray;
}

static char *IToStr(int a)
{
 static char TempArray[32];
 sprintf(TempArray,"% 5.5d",a);
 return TempArray;
}

static UINT32 FastStrToU32(char* s)
{
	UINT32 v=0;

	sscanf(s,"%x",&v);

	return v;
}

static char *U32ToDecStr(UINT32 a)
{
 static char TempArray[16];
 sprintf(TempArray, "%010u", a);
 return TempArray;
}

static char *U16ToDecStr(UINT16 a)
{
 static char TempArray[16];
 TempArray[0] = '0' + a/10000;
 TempArray[1] = '0' + (a%10000)/1000;
 TempArray[2] = '0' + (a%1000)/100;
 TempArray[3] = '0' + (a%100)/10;
 TempArray[4] = '0' + (a%10);
 TempArray[5] = 0;
 return TempArray;
}


static char *U32ToHexStr(UINT32 a)
{
 static char TempArray[16];
 sprintf(TempArray, "%08X", a);
 return TempArray;
}

static char *U16ToHexStr(UINT16 a)
{
 static char TempArray[16];
 TempArray[0] = a/4096 > 9?'A'+a/4096-10:'0' + a/4096;
 TempArray[1] = (a%4096)/256 > 9?'A'+(a%4096)/256 - 10:'0' + (a%4096)/256;
 TempArray[2] = (a%256)/16 > 9?'A'+(a%256)/16 - 10:'0' + (a%256)/16;
 TempArray[3] = a%16 > 9?'A'+(a%16) - 10:'0' + (a%16);
 TempArray[4] = 0;
 return TempArray;
}

static char *U8ToHexStr(UINT8 a)
{
 static char TempArray[16];
 TempArray[0] = a/16 > 9?'A'+a/16 - 10:'0' + a/16;
 TempArray[1] = a%16 > 9?'A'+(a%16) - 10:'0' + (a%16);
 TempArray[2] = 0;
 return TempArray;
}

static const int MW_ADDR_Lookup[] = {
	MW_ADDR00,MW_ADDR01,MW_ADDR02,MW_ADDR03,
	MW_ADDR04,MW_ADDR05,MW_ADDR06,MW_ADDR07,
	MW_ADDR08,MW_ADDR09,MW_ADDR10,MW_ADDR11,
	MW_ADDR12,MW_ADDR13,MW_ADDR14,MW_ADDR15,
	MW_ADDR16,MW_ADDR17,MW_ADDR18,MW_ADDR19,
	MW_ADDR20,MW_ADDR21,MW_ADDR22,MW_ADDR23
};
#define MWNUM sizeof(MW_ADDR_Lookup)/sizeof(MW_ADDR_Lookup[0])

static int yPositions[MWNUM];
static int xPositions[MWNUM];

struct MWRec
{
	int valid, bytes, hex, sign;
	UINT32 addr;
};

static struct MWRec mwrecs[MWNUM];

static int MWRec_findIndex(WORD ctl)
{
	for(unsigned int i=0;i<MWNUM;i++)
		if(MW_ADDR_Lookup[i] == ctl)
			return i;
	return -1;
}

void MWRec_parse(WORD ctl,int changed)
{
	char TempArray[16];
	GetDlgItemTextA(hwndMemWatch,ctl,TempArray,16);
	TempArray[15]=0;

	mwrecs[changed].valid = mwrecs[changed].hex = mwrecs[changed].sign = 0;
	mwrecs[changed].bytes = 1;
	switch(TempArray[0])
	{
		case 0:
			break;
		case '!':
			mwrecs[changed].valid = 1;
			if (TempArray[1] == '!') {
				mwrecs[changed].bytes = 4;
				mwrecs[changed].addr=FastStrToU32(TempArray+2);
			}
			else {
				mwrecs[changed].bytes = 2;
				mwrecs[changed].addr=FastStrToU32(TempArray+1);
			}
			break;
		case 'x':
			mwrecs[changed].hex = 1;
			mwrecs[changed].valid = 1;
			mwrecs[changed].addr=FastStrToU32(TempArray+1);
			break;
		case 'X':
			mwrecs[changed].hex = 1;
			mwrecs[changed].valid = 1;
			if (TempArray[1] == 'X') {
				mwrecs[changed].bytes = 4;
				mwrecs[changed].addr=FastStrToU32(TempArray+2);
			}
			else {
				mwrecs[changed].bytes = 2;
				mwrecs[changed].addr=FastStrToU32(TempArray+1);
			}
			break;
		case 's':
			mwrecs[changed].sign = 1;
			mwrecs[changed].valid = 1;
			mwrecs[changed].addr=FastStrToU32(TempArray+1);
			break;
		case 'S':
			mwrecs[changed].sign = 1;
			mwrecs[changed].valid = 1;
			if (TempArray[1] == 'S') {
				mwrecs[changed].bytes = 4;
				mwrecs[changed].addr=FastStrToU32(TempArray+2);
			}
			else {
				mwrecs[changed].bytes = 2;
				mwrecs[changed].addr=FastStrToU32(TempArray+1);
			}
			break;
		default:
			mwrecs[changed].valid = 1;
			mwrecs[changed].addr=FastStrToU32(TempArray);
			break;
		}
}

void UpdateMemWatch()
{
	char* text;
	int len;

	if(hwndMemWatch) {
		SetTextColor(hdc,RGB(0,0,0));
		SetBkColor(hdc,GetSysColor(COLOR_3DFACE));

		for(unsigned int i = 0; i < MWNUM; i++) {
			struct MWRec mwrec;
			memcpy(&mwrec,&mwrecs[i],sizeof(mwrecs[i]));

			 if(mwrec.valid) {
				if(mwrec.hex) {
					if(mwrec.bytes == 4)
						text = U32ToHexStr(ReadValueAtHardwareAddress(mwrec.addr,4,0));
					else if(mwrec.bytes == 2)
						text = U16ToHexStr(ReadValueAtHardwareAddress(mwrec.addr,2,0));
					else
						text = U8ToHexStr(ReadValueAtHardwareAddress(mwrec.addr,1,0));
				}
				else {
					if(mwrec.bytes == 4) {
						if(mwrec.sign)
							text = IToStr((INT32)ReadValueAtHardwareAddress(mwrec.addr,4,0));
						else
							text = U32ToDecStr(ReadValueAtHardwareAddress(mwrec.addr,4,0));
					}
					else if(mwrec.bytes == 2) {
						if(mwrec.sign)
							text = IToStr((INT16)ReadValueAtHardwareAddress(mwrec.addr,2,0));
						else
							text = U16ToDecStr(ReadValueAtHardwareAddress(mwrec.addr,2,0));
					}
					else {
						if(mwrec.sign)
							text = IToStr((INT8)ReadValueAtHardwareAddress(mwrec.addr,1,0));
						else
							text = U8ToStr(ReadValueAtHardwareAddress(mwrec.addr,1,0));
					}
				}
				len = strlen(text);
				for(int j=len;j<11;j++)
					text[j] = ' ';
				text[11] = 0;
			}
			else
				text = "      ";

			MoveToEx(hdc,xPositions[i],yPositions[i],NULL);
			TextOutA(hdc,0,0,text,strlen(text));
		}
	}
}

//Save labels/addresses so next time dialog is opened,
//you don't lose what you've entered.
static void SaveStrings()
{
	for(int i=0;i<24;i++)
	{
		GetDlgItemTextA(hwndMemWatch,1000+(i*3),labels[i],24);
		GetDlgItemTextA(hwndMemWatch,1001+(i*3),addresses[i],16);
	}
}

//replaces spaces with a dummy character
static void TakeOutSpaces(int i)
{
	int j;
	for(j=0;j<16;j++)
	{
		if(addresses[i][j] == ' ') addresses[i][j] = '|';
		if(labels[i][j] == ' ') labels[i][j] = '|';
	}
	for(;j<24;j++)
	{
		if(labels[i][j] == ' ') labels[i][j] = '|';
	}
}

//replaces dummy characters with spaces
static void PutInSpaces(int i)
{
	int j;
	for(j=0;j<16;j++)
	{
		if(addresses[i][j] == '|') addresses[i][j] = ' ';
		if(labels[i][j] == '|') labels[i][j] = ' ';
	}
	for(;j<24;j++)
	{
		if(labels[i][j] == '|') labels[i][j] = ' ';
	}
}

//Saves all the addresses and labels to disk
static void SaveMemWatch()
{
	FILE *fp;
	const TCHAR filter[]=_T("Memory address list(*.txt)\0*.txt\0");
	TCHAR nameo[MAX_PATH];
	OPENFILENAME ofnmw;
	memset(&ofnmw,0,sizeof(ofnmw));
	ofnmw.lStructSize=sizeof(ofnmw);
	ofnmw.hInstance=hAppInst;
	ofnmw.lpstrTitle=_T("Save Memory Watch As...");
	ofnmw.lpstrFilter=filter;
	nameo[0]=0;
	ofnmw.lpstrFile=nameo;
	ofnmw.nMaxFile=MAX_PATH;
	ofnmw.Flags=OFN_EXPLORER|OFN_HIDEREADONLY|OFN_OVERWRITEPROMPT;
	ofnmw.lpstrInitialDir=_T(".\\");
	ofnmw.lpstrDefExt=_T("txt");
	if(GetSaveFileName(&ofnmw))
	{
		SaveStrings();
		fp=_tfopen(nameo,_T("w"));
		for(int i=0;i<24;i++)
		{
			//Use dummy strings to fill empty slots
			if(labels[i][0] == 0)
			{
				labels[i][0] = '|';
				labels[i][1] = 0;
			}
			if(addresses[i][0] == 0)
			{
				addresses[i][0] = '|';
				addresses[i][1] = 0;
			}
			//spaces can be a problem for scanf so get rid of them
			TakeOutSpaces(i);
			fwprintf(fp, _T("%s "), _AtoT(addresses[i]));
			fwprintf(fp, _T("%s\n"), _AtoT(labels[i]));
			PutInSpaces(i);
		}
		fclose(fp);
	}
}

int LoadMemWatchFile(TCHAR nameo[2048])
{
	FILE *fp;
	int i,j;

	fp=_tfopen(nameo,_T("r"));
	if (!fp)
		return 0;

	bLoadingMemWatchFile = TRUE;
	for(i=0;i<24;i++) {
		fwscanf(fp, _T("%s "), nameo);
		for(j = 0; j < 16; j++)
			addresses[i][j] = nameo[j];
		fwscanf(fp, _T("%s\n"), nameo);
		for(j = 0; j < 24; j++)
			labels[i][j] = nameo[j];

		//Replace dummy strings with empty strings
		if(addresses[i][0] == '|')
			addresses[i][0] = 0;
		if(labels[i][0] == '|')
			labels[i][0] = 0;
		PutInSpaces(i);

		addresses[i][15] = 0;
		labels[i][23] = 0; //just in case

		SetDlgItemText(hwndMemWatch,1001+i*3,(LPTSTR) _AtoT(addresses[i]));
		SetDlgItemText(hwndMemWatch,1000+i*3,(LPTSTR) _AtoT(labels[i]));
	}
	bLoadingMemWatchFile = FALSE;

	fclose(fp);

	return 1;
}

//Loads a previously saved file
static void LoadMemWatch()
{
	const TCHAR filter[]=_T("Memory address list(*.txt)\0*.txt\0");
	TCHAR nameo[MAX_PATH];
	OPENFILENAME ofnmw;
	memset(&ofnmw,0,sizeof(ofnmw));
	ofnmw.lStructSize=sizeof(ofnmw);
	ofnmw.hInstance=hAppInst;
	ofnmw.lpstrTitle=_T("Load Memory Watch...");
	ofnmw.lpstrFilter=filter;
	nameo[0]=0;
	ofnmw.lpstrFile=nameo;
	ofnmw.nMaxFile=MAX_PATH;
	ofnmw.Flags=OFN_EXPLORER|OFN_FILEMUSTEXIST|OFN_HIDEREADONLY;
	ofnmw.lpstrInitialDir=_T(".\\");
	ofnmw.lpstrDefExt=_T("txt");
	
	if(GetOpenFileName(&ofnmw)) {
		LoadMemWatchFile(nameo);
	}
	UpdateMemWatch();
}

static BOOL CALLBACK MemWatchCallB(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
	const int kLabelControls[] = {MW_ValueLabel1,MW_ValueLabel2};
	int col;
	RECT r;
	UINT8* rPtr;

	lParam = lParam; // silence annoying warning

	switch(uMsg)
	{
	case WM_INITDIALOG:
		hdc = GetDC(hwndDlg);
		hFixedFont = CreateFont(13,8,0,0,
		             400,FALSE,FALSE,FALSE,
		             ANSI_CHARSET,OUT_DEVICE_PRECIS,CLIP_MASK,
		             DEFAULT_QUALITY,DEFAULT_PITCH,_T("Courier"));
		SelectObject (hdc, hFixedFont);
		SetTextAlign(hdc,TA_UPDATECP | TA_TOP | TA_LEFT);
		//find the positions where we should draw string values
		for(unsigned int i=0;i<MWNUM;i++) {
			col=0;
			if(i>=(int)MWNUM/2)
				col=1;
			rPtr = (UINT8*)&r;
			GetWindowRect(GetDlgItem(hwndDlg,MW_ADDR_Lookup[i]),&r);
			ScreenToClient(hwndDlg,(LPPOINT)rPtr);
			ScreenToClient(hwndDlg,(LPPOINT)&r.right);
			yPositions[i] = r.top;
			yPositions[i] += ((r.bottom-r.top)-13)/2; //vertically center
			GetWindowRect(GetDlgItem(hwndDlg,kLabelControls[col]),&r);
			ScreenToClient(hwndDlg,(LPPOINT)rPtr);
			xPositions[i] = r.left;
		}
		break;
	case WM_PAINT: {
		PAINTSTRUCT ps;
		BeginPaint(hwndDlg, &ps);
		EndPaint(hwndDlg, &ps);
		UpdateMemWatch();
		break;
	}
	case WM_CLOSE:
	case WM_QUIT:
		SaveStrings();
		DeleteObject(hdc);
		DestroyWindow(hwndMemWatch);
		hwndMemWatch=0;
		break;
	case WM_COMMAND:
		switch(HIWORD(wParam))
		{
		
		case EN_CHANGE:
			{
				//the contents of an address box changed. re-parse it.
				//first, find which address changed
				int changed = MWRec_findIndex(LOWORD(wParam));
				if(changed==-1) break;
				MWRec_parse(LOWORD(wParam),changed);
				if (!bLoadingMemWatchFile)
					UpdateMemWatch();
				break;
			}
			
		case BN_CLICKED:
			switch(LOWORD(wParam))
			{
			case 101: //Save button clicked
				AudBlankSound();
				SaveMemWatch();
				break;			
			case 102: //Load button clicked
				AudBlankSound();
				LoadMemWatch();
				break;
			case 103: //Clear button clicked
				AudBlankSound();
				if(MessageBox(hwndMemWatch, _T("Clear all text?"), _T("Confirm clear"), MB_YESNO)==IDYES)
				{
					for(unsigned int i=0;i<24;i++)
					{
						addresses[i][0] = 0;
						labels[i][0] = 0;
						SetDlgItemText(hwndMemWatch,1001+i*3,(LPTSTR) _AtoT(addresses[i]));
						SetDlgItemText(hwndMemWatch,1000+i*3,(LPTSTR) _AtoT(labels[i]));
					}
					UpdateMemWatch();
				}
				break;
			default:
				break;
			}
		}

		if(!(wParam>>16)) //Close button clicked
		{
			switch(wParam&0xFFFF)
			{
			case 1:
				SaveStrings();
				DestroyWindow(hwndMemWatch);
				hwndMemWatch=0;
				break;
			}
		}
		break;
	default:
		break;
	}
	return 0;
}

//Open the Memory Watch dialog
void CreateMemWatch()
{
	if(NeedsInit) //Clear the strings
	{
		NeedsInit = 0;
		for(int i=0;i<24;i++)
		{
			for(int j=0;j<24;j++)
			{
				addresses[i][j] = 0;
				labels[i][j] = 0;
			}
		}
	}

	if(hwndMemWatch) //If already open, give focus
	{
		SetFocus(hwndMemWatch);
		return;
	}
	AudBlankSound();

	//Create
	hwndMemWatch=CreateDialog(hAppInst,MAKEINTRESOURCE(IDD_RAMWATCHOLD),NULL,(DLGPROC) MemWatchCallB);
	UpdateMemWatch();

	//Initialize values to previous entered addresses/labels
	{
		for(int i = 0; i < 24; i++)
		{
			SetDlgItemText(hwndMemWatch,1001+i*3,(LPTSTR) _AtoT(addresses[i]));
			SetDlgItemText(hwndMemWatch,1000+i*3,(LPTSTR) _AtoT(labels[i]));
		}
	}
}

void AddMemWatch(char memaddress[32])
{
	char TempArray[32];
	CreateMemWatch();
	for(unsigned int i = 0; i < MWNUM; i++)
	{
		GetDlgItemTextA(hwndMemWatch,MW_ADDR_Lookup[i],TempArray,32);
		if (TempArray[0] == 0)
		{
			SetDlgItemTextA(hwndMemWatch,MW_ADDR_Lookup[i],memaddress);
			break;
		}
	}
}
