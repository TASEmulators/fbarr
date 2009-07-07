// Run module
#include "burner.h"

#include "maphkeys.h"

int bRunPause = 0;
int bAltPause = 0;

int bAlwaysDrawFrames = 1;

static bool bShowFPS = false;
static unsigned int nDoFPS = 0;

int kNetGame = 0;							// Non-zero if Kaillera is being used

#ifdef FBA_DEBUG
int counter;								// General purpose variable used when debugging
#endif

static unsigned int nNormalLast = 0;		// Last value of timeGetTime()
static int nNormalFrac = 0;					// Extra fraction we did

static bool bAppDoStep = 0;
static bool bAppDoFast = 0;
static int nFastSpeed = 6;
static int nFpsScale = 100;

static int GetInput(bool bCopy)
{
	static int i = 0;
	InputMake(bCopy); 						// get input

	// Update Input dialog ever 3 frames
	if (i == 0) {
		InpdUpdate();
	}

	i++;

	if (i >= 3) {
		i = 0;
	}

	// Update Input Set dialog
	InpsUpdate();
	return 0;
}

static void DisplayFPS()
{
	static time_t fpstimer;
	static unsigned int nPreviousFrames;

	TCHAR fpsstring[8];
	time_t temptime = clock();
	double fps = (double)(nFramesRendered - nPreviousFrames) * CLOCKS_PER_SEC / (temptime - fpstimer);
	_sntprintf(fpsstring, 7, _T("%2.2lf"), fps);
	VidSNewShortMsg(fpsstring, 0xDFDFFF, 480, 0);

	fpstimer = temptime;
	nPreviousFrames = nFramesRendered;
}

// define this function somewhere above RunMessageLoop()
void ToggleLayer(unsigned char thisLayer)
{
	nBurnLayer ^= thisLayer;				// xor with thisLayer
	VidRedraw();
	VidPaint(0);
}

// With or without sound, run one frame.
// If bDraw is true, it's the last frame before we are up to date, and so we should draw the screen
static int RunFrame(int bDraw, int bPause)
{
	static int bPrevPause = 0;
	static int bPrevDraw = 0;

	extern bool bDoPostInitialize;

	// Exit Jukebox properly
	
	if(bDoPostInitialize == true && bJukeboxInUse == true) {
		DrvExit();
		bJukeboxDisplayed	= false;
		bJukeboxInUse		= false;
		bDoPostInitialize = false;
		POST_INITIALISE_MESSAGE;
	}

	if (bPrevDraw && !bPause) {
		VidPaint(0);							// paint the screen (no need to validate)
	}

	if (!bDrvOkay) {
		return 1;
	}

	if (bPause && bJukeboxInUse == true) {
		GetInput(false);						// Update burner inputs, but not game inputs
		if (bPause != bPrevPause) {
			VidPaint(2);                        // Redraw the screen (to ensure mode indicators are updated)
		}
		return 0;
	}
	
	if (!bPause && bJukeboxInUse == true) {
		//if (!bJukeboxDisplayed) JukeboxDialogCreate();
		int TracklistDialog();

		if (bJukeboxDisplayed == false) TracklistDialog();
		nFramesEmulated++;
		nCurrentFrame++;
		BurnJukeboxFrame();
		return 0;		
	}

	if (bPause) {
		GetInput(false);						// Update burner inputs, but not game inputs
		if (bPause != bPrevPause) {
			VidPaint(2);                        // Redraw the screen (to ensure mode indicators are updated)
		}
	} else {

		nFramesEmulated++;
		nCurrentFrame++;

		if (kNetGame) {
			GetInput(true);						// Update inputs
			if (KailleraGetInput()) {			// Synchronize input with Kaillera
				return 0;
			}
		} else {
			if (nReplayStatus == 2) {
				GetInput(false);				// Update burner inputs, but not game inputs
				if (ReplayInput()) {			// Read input from file
//					bAltPause = 1;
//					bRunPause = 1;
					VidSNewShortMsg(L"replay stopped");
					MenuEnableItems();
					InputSetCooperativeLevel(false, false);
				}
			} else {
				GetInput(true);					// Update inputs
			}
		}

		if (nReplayStatus == 1) {
			RecordInput();						// Write input to file
		}

		if (bDraw || bAviRecording) {
			nFramesRendered++;

			if (VidFrame()) {					// Do one frame
				AudBlankSound();
			}
			AviVideoUpdate();
		} else {								// frame skipping
			pBurnDraw = NULL;					// Make sure no image is drawn
			BurnDrvFrame();
		}

		if (bShowFPS) {
			if (nDoFPS < nFramesRendered) {
				DisplayFPS();
				nDoFPS = nFramesRendered + 30;
			}
		}
	}

	bPrevPause = bPause;
	bPrevDraw = bDraw;

	return 0;
}

// Callback used when DSound needs more sound
static int RunGetNextSound(int bDraw)
{
	if (nAudNextSound == NULL) {
		return 1;
	}

	if (bRunPause) {
		if (bAppDoStep) {
			RunFrame(bDraw, 0);
			memset(nAudNextSound, 0, nAudSegLen << 2);	// Write silence into the buffer
		} else {
			AudBlankSound();
			RunFrame(bDraw, 1);
		}

		bAppDoStep = 0;									// done one step
		return 0;
	}

	if (bAppDoFast) {									// do more frames
		for (int i = 0; i < nFastSpeed; i++) {
			RunFrame(0, 0);
		}
	}

	// Render frame with sound
	pBurnSoundOut = nAudNextSound;
	RunFrame(bDraw, 0);

	AviSoundUpdate();

	if (WaveLog != NULL && pBurnSoundOut != NULL) {		// log to the file
		fwrite(pBurnSoundOut, 1, nBurnSoundLen << 2, WaveLog);
		pBurnSoundOut = NULL;
	}

	if (bAppDoStep) {
		memset(nAudNextSound, 0, nAudSegLen << 2);		// Write silence into the buffer
	}
	bAppDoStep = 0;										// done one step

	return 0;
}

int RunIdle()
{
	int nTime, nCount;

	if (bAudPlaying) {
		// Run with sound
		AudSoundCheck();
		return 0;
	}

	// Run without sound
	nTime = timeGetTime() - nNormalLast;
	nCount = (nTime * nAppVirtualFps - nNormalFrac) / 100000;
	if (nCount <= 0) {						// No need to do anything for a bit
		Sleep(2);

		return 0;
	}

	nNormalFrac += nCount * 100000;
	nNormalLast += nNormalFrac / nAppVirtualFps;
	nNormalFrac %= nAppVirtualFps;

	if (bAppDoFast){						// Temporarily increase virtual fps
		nCount *= nFastSpeed;
		nCount *= 10;
	}
	if (nCount > 100) {						// Limit frame skipping
		nCount = 100;
	}
	if (bRunPause) {
		if (bAppDoStep) {					// Step one frame
			nCount = 10;
		} else {
			RunFrame(1, 1);					// Paused
			return 0;
		}
	}
	bAppDoStep = 0;

	for (int i = nCount / 10; i > 0; i--) {	// Mid-frames
		RunFrame(!bAlwaysDrawFrames, 0);
	}
	RunFrame(1, 0);							// End-frame

	if (bAppDoStep) {
		VidRedraw();
		VidPaint(0);
	}
	bAppDoStep = 0;

	return 0;
}

int RunReset()
{
	// Reset the speed throttling code
	nNormalLast = 0; nNormalFrac = 0;
	// Reset FPS display
	nDoFPS = 0;
	nFpsScale = 100;

	if (!bAudPlaying) {
		// run without sound
		nNormalLast = timeGetTime();
	}
	return 0;
}

static int RunInit()
{
	// Try to run with sound
	AudSetCallback(RunGetNextSound);
	AudSoundPlay();
	nFpsScale = 100;

	RunReset();

	return 0;
}

static int RunExit()
{
	nNormalLast = 0;
	// Stop sound if it was playing
	AudSoundStop();
	return 0;
}

void PADhandleKey(int key);

// The main message loop
int RunMessageLoop()
{
	int bRestartVideo;
	MSG Msg;

	do {
		bRestartVideo = 0;

		// Remove pending initialisation messages from the queue
		while (PeekMessage(&Msg, NULL, WM_APP + 0, WM_APP + 0, PM_NOREMOVE)) {
			if (Msg.message != WM_QUIT)	{
				PeekMessage(&Msg, NULL, WM_APP + 0, WM_APP + 0, PM_REMOVE);
			}
		}

		RunInit();

		ShowWindow(hScrnWnd, nAppShowCmd);												// Show the screen window
		nAppShowCmd = SW_NORMAL;

		SetForegroundWindow(hScrnWnd);

		GameInpCheckLeftAlt();
		GameInpCheckMouse();															// Hide the cursor

		while (1) {
			if (PeekMessage(&Msg, NULL, 0, 0, PM_REMOVE)) {
				// A message is waiting to be processed
				if (Msg.message == WM_QUIT)	{											// Quit program
					break;
				}
				if (Msg.message == (WM_APP + 0)) {										// Restart video
					bRestartVideo = 1;
					break;
				}

				if (bMenuEnabled && nVidFullscreen == 0) {								// Handle keyboard messages for the menu
					if (MenuHandleKeyboard(&Msg)) {
						continue;
					}
				}

				if (Msg.message == WM_SYSKEYDOWN || Msg.message == WM_KEYDOWN) {
					PADhandleKey(Msg.wParam);

					if (Msg.lParam & 0x20000000) {
						// An Alt/AltGr-key was pressed
						switch (Msg.wParam) {
#if defined (FBA_DEBUG)
							case 'C': {
								static int count = 0;
								if (count == 0) {
									count++;
									{ char* p = NULL; if (*p) { printf("crash...\n"); } }
								}
								break;
							}
#endif
						}
					} else {
						switch (Msg.wParam) {
#if defined (FBA_DEBUG)
							case 'N':
								counter--;
								bprintf(PRINT_IMPORTANT, _T("*** New counter value: %04X.\n"), counter);
								break;
							case 'M':
								counter++;
								bprintf(PRINT_IMPORTANT, _T("*** New counter value: %04X.\n"), counter);
								break;
#endif
						}
					}
				} else {
					if (Msg.message == WM_SYSKEYUP || Msg.message == WM_KEYUP) {
						if (Msg.wParam == (unsigned int)EmuCommandTable[EMUCMD_TURBOMODE].key) {
							int modifier = 0;
							if(GetAsyncKeyState(VK_MENU))
								modifier = VK_MENU;
							else if(GetAsyncKeyState(VK_CONTROL))
								modifier = VK_CONTROL;
							else if(GetAsyncKeyState(VK_SHIFT))
								modifier = VK_SHIFT;
							if(modifier == EmuCommandTable[EMUCMD_TURBOMODE].keymod)
								bAppDoFast = 0;
						}
					}
				}

				// Check for messages for dialogs etc.
				if (AppMessage(&Msg)) {
					if (TranslateAccelerator(hScrnWnd, hAccel, &Msg) == 0) {
						if (hwndChat) {
							TranslateMessage(&Msg);
						}
						DispatchMessage(&Msg);
					}
				}
			} else {
				// No messages are waiting
				SplashDestroy(0);
				RunIdle();
			}
		}

		RunExit();
		MediaExit();
		if (bRestartVideo) {
			MediaInit();
		}
	} while (bRestartVideo);

	return 0;
}

extern int nSavestateSlot;

void PADhandleKey(int key) {
	int i;
	int modifiers = 0;
	if(GetAsyncKeyState(VK_CONTROL))
		modifiers = VK_CONTROL;
	else if(GetAsyncKeyState(VK_MENU))
		modifiers = VK_MENU;
	else if(GetAsyncKeyState(VK_SHIFT))
		modifiers = VK_SHIFT;

	for (i = EMUCMD_SELECTSTATE1; i <= EMUCMD_SELECTSTATE1+8; i++) {
		if(key == EmuCommandTable[i].key
		&& modifiers == EmuCommandTable[i].keymod)
		{
			TCHAR szString[256];
			nSavestateSlot = i-EMUCMD_SELECTSTATE1+1;
			_sntprintf(szString, 256, FBALoadStringEx(hAppInst, IDS_STATE_ACTIVESLOT, true), nSavestateSlot);
			VidSNewShortMsg(szString);
			VidRedraw();
			VidPaint(0);
		}
	}

	for (i = EMUCMD_LOADSTATE1; i <= EMUCMD_LOADSTATE1+8; i++) {
		if(key == EmuCommandTable[i].key
		&& modifiers == EmuCommandTable[i].keymod)
		{
			StatedLoad(i-EMUCMD_LOADSTATE1+1);
		}
	}

	for (i = EMUCMD_SAVESTATE1; i <= EMUCMD_SAVESTATE1+8; i++) {
		if(key == EmuCommandTable[i].key
		&& modifiers == EmuCommandTable[i].keymod)
		{
			StatedSave(i-EMUCMD_SAVESTATE1+1);
		}
	}

	if(key == EmuCommandTable[EMUCMD_PAUSE].key
	&& modifiers == EmuCommandTable[EMUCMD_PAUSE].keymod)
	{
		bRunPause^=1;
	}

	if(key == EmuCommandTable[EMUCMD_FRAMEADVANCE].key
	&& modifiers == EmuCommandTable[EMUCMD_FRAMEADVANCE].keymod)
	{
		if (!bRunPause)
			bRunPause = 1;
		bAppDoStep = 1;
	}

	if(key == EmuCommandTable[EMUCMD_TURBOMODE].key
	&& modifiers == EmuCommandTable[EMUCMD_TURBOMODE].keymod)
	{
		bAppDoFast = 1;
	}

	if(key == EmuCommandTable[EMUCMD_RWTOGGLE].key
	&& modifiers == EmuCommandTable[EMUCMD_RWTOGGLE].keymod)
	{
		bReplayReadOnly^=1;
		if (bReplayReadOnly)
			VidSNewShortMsg(_T("read-only"));
		else
			VidSNewShortMsg(_T("read+write"));
		VidRedraw();
		VidPaint(0);
	}

	if(key == EmuCommandTable[EMUCMD_FRAMECOUNTER].key
	&& modifiers == EmuCommandTable[EMUCMD_FRAMECOUNTER].keymod)
	{
		bReplayFrameCounterDisplay = !bReplayFrameCounterDisplay;
		if (!bReplayFrameCounterDisplay)
			VidSKillTinyMsg();
	}

	if(key == EmuCommandTable[EMUCMD_SPEEDNORMAL].key
	&& modifiers == EmuCommandTable[EMUCMD_SPEEDNORMAL].keymod)
	{
		wchar_t buffer[15];
		nFpsScale = 100;
		swprintf(buffer, _T("speed %02i %%"), nFpsScale);
		VidSNewShortMsg(buffer);
		VidRedraw();
		VidPaint(0);
		MediaChangeFps(nFpsScale);
	}

	if(key == EmuCommandTable[EMUCMD_SPEEDTURBO].key
	&& modifiers == EmuCommandTable[EMUCMD_SPEEDTURBO].keymod)
	{
		wchar_t buffer[15];
		nFpsScale = 800;
		swprintf(buffer, _T("speed %02i %%"), nFpsScale);
		VidSNewShortMsg(buffer);
		VidRedraw();
		VidPaint(0);
		MediaChangeFps(nFpsScale);
	}

	if(key == EmuCommandTable[EMUCMD_SPEEDINC].key
	&& modifiers == EmuCommandTable[EMUCMD_SPEEDINC].keymod)
	{
		wchar_t buffer[15];
		if (nFpsScale < 10)
			nFpsScale = 10;
		else {
			if (nFpsScale >= 100)
				nFpsScale += 50;
			else
				nFpsScale += 10;
		}
		if (nFpsScale > 800)
			nFpsScale = 800;
		swprintf(buffer, _T("speed %02i %%"), nFpsScale);
		VidSNewShortMsg(buffer);
		VidRedraw();
		VidPaint(0);
		MediaChangeFps(nFpsScale);
	}

	if(key == EmuCommandTable[EMUCMD_SPEEDDEC].key
	&& modifiers == EmuCommandTable[EMUCMD_SPEEDDEC].keymod)
	{
		wchar_t buffer[15];
		if (nFpsScale <= 10)
			nFpsScale = 5;
		else {
			if (nFpsScale > 100)
				nFpsScale -= 50;
			else
				nFpsScale -= 10;
		}
		swprintf(buffer, _T("speed %02i %%"), nFpsScale);
		VidSNewShortMsg(buffer);
		VidRedraw();
		VidPaint(0);
		MediaChangeFps(nFpsScale);
	}

	if(key == EmuCommandTable[EMUCMD_MENU].key
	&& modifiers == EmuCommandTable[EMUCMD_MENU].keymod)
	{
		if (nVidFullscreen) {
			nVidFullscreen = 0;
			bMenuEnabled = true;
			POST_INITIALISE_MESSAGE;
		}
		else {
			bMenuEnabled = !bMenuEnabled;
			POST_INITIALISE_MESSAGE;
		}
	}

	if(key == EmuCommandTable[EMUCMD_VOLUMEDEC].key
	&& modifiers == EmuCommandTable[EMUCMD_VOLUMEDEC].keymod)
	{
		TCHAR buffer[15];
		nAudVolume -= 100;
		if (nAudVolume < 0)
			nAudVolume = 0;
		if (AudSoundSetVolume() == 0)
			VidSNewShortMsg(FBALoadStringEx(hAppInst, IDS_SOUND_NOVOLUME, true));
		else {
			_stprintf(buffer, FBALoadStringEx(hAppInst, IDS_SOUND_VOLUMESET, true), nAudVolume / 100);
			VidSNewShortMsg(buffer);
		}
	}

	if(key == EmuCommandTable[EMUCMD_VOLUMEINC].key
	&& modifiers == EmuCommandTable[EMUCMD_VOLUMEINC].keymod)
	{
		TCHAR buffer[15];
		nAudVolume += 100;
		if (nAudVolume > 10000)
			nAudVolume = 10000;
		if (AudSoundSetVolume() == 0)
			VidSNewShortMsg(FBALoadStringEx(hAppInst, IDS_SOUND_NOVOLUME, true));
		else {
			_stprintf(buffer, FBALoadStringEx(hAppInst, IDS_SOUND_VOLUMESET, true), nAudVolume / 100);
			VidSNewShortMsg(buffer);
		}
	}

	if(key == EmuCommandTable[EMUCMD_SHOWFPS].key
	&& modifiers == EmuCommandTable[EMUCMD_SHOWFPS].keymod)
	{
		bShowFPS = !bShowFPS;
		if (bShowFPS)
			DisplayFPS();
		else {
			VidSKillShortMsg();
			VidSKillOSDMsg();
		}
	}

	if(key == EmuCommandTable[EMUCMD_SCREENSHOT].key
	&& modifiers == EmuCommandTable[EMUCMD_SCREENSHOT].keymod)
	{
		if (GetMenuState(hMenu,MENU_SAVESNAP,NULL) != MF_GRAYED)
			SendMessage(hScrnWnd, WM_COMMAND, (WPARAM)(MENU_SAVESNAP),(LPARAM)(NULL));
	}

	if(key == EmuCommandTable[EMUCMD_CHEATTOGLE].key
	&& modifiers == EmuCommandTable[EMUCMD_CHEATTOGLE].keymod)
	{
		if (GetMenuState(hMenu,MENU_ENABLECHEAT,NULL) != MF_GRAYED)
			SendMessage(hScrnWnd, WM_COMMAND, (WPARAM)(MENU_ENABLECHEAT),(LPARAM)(NULL));
	}

	if(key == EmuCommandTable[EMUCMD_CONFIGPAD].key
	&& modifiers == EmuCommandTable[EMUCMD_CONFIGPAD].keymod)
	{
		if (GetMenuState(hMenu,MENU_INPUT,NULL) != MF_GRAYED)
			SendMessage(hScrnWnd, WM_COMMAND, (WPARAM)(MENU_INPUT),(LPARAM)(NULL));
	}

	if(key == EmuCommandTable[EMUCMD_LOADSTATE].key
	&& modifiers == EmuCommandTable[EMUCMD_LOADSTATE].keymod)
	{
		StatedLoad(nSavestateSlot);
	}

	if(key == EmuCommandTable[EMUCMD_SAVESTATE].key
	&& modifiers == EmuCommandTable[EMUCMD_SAVESTATE].keymod)
	{
		StatedSave(nSavestateSlot);
	}

	if(key == EmuCommandTable[EMUCMD_STARTRECORDING].key
	&& modifiers == EmuCommandTable[EMUCMD_STARTRECORDING].keymod)
	{
		if (GetMenuState(hMenu,MENU_STARTRECORD,NULL) != MF_GRAYED)
			SendMessage(hScrnWnd, WM_COMMAND, (WPARAM)(MENU_STARTRECORD),(LPARAM)(NULL));
	}

	if(key == EmuCommandTable[EMUCMD_STARTPLAYBACK].key
	&& modifiers == EmuCommandTable[EMUCMD_STARTPLAYBACK].keymod)
	{
		if (GetMenuState(hMenu,MENU_STARTREPLAY,NULL) != MF_GRAYED)
			SendMessage(hScrnWnd, WM_COMMAND, (WPARAM)(MENU_STARTREPLAY),(LPARAM)(NULL));
	}

	if(key == EmuCommandTable[EMUCMD_STOPMOVIE].key
	&& modifiers == EmuCommandTable[EMUCMD_STOPMOVIE].keymod)
	{
		if (GetMenuState(hMenu,MENU_STOPREPLAY,NULL) != MF_GRAYED)
			SendMessage(hScrnWnd, WM_COMMAND, (WPARAM)(MENU_STOPREPLAY),(LPARAM)(NULL));
	}

	if(key == EmuCommandTable[EMUCMD_STARTAVI].key
	&& modifiers == EmuCommandTable[EMUCMD_STARTAVI].keymod)
	{
		if (GetMenuState(hMenu,MENU_AVI_BEGIN,NULL) != MF_GRAYED)
			SendMessage(hScrnWnd, WM_COMMAND, (WPARAM)(MENU_AVI_BEGIN),(LPARAM)(NULL));
	}

	if(key == EmuCommandTable[EMUCMD_STOPAVI].key
	&& modifiers == EmuCommandTable[EMUCMD_STOPAVI].keymod)
	{
		if (GetMenuState(hMenu,MENU_AVI_END,NULL) != MF_GRAYED)
			SendMessage(hScrnWnd, WM_COMMAND, (WPARAM)(MENU_AVI_END),(LPARAM)(NULL));
	}

	if(key == EmuCommandTable[EMUCMD_CHEATEDITOR].key
	&& modifiers == EmuCommandTable[EMUCMD_CHEATEDITOR].keymod)
	{
		if (GetMenuState(hMenu,MENU_ENABLECHEAT,NULL) != MF_GRAYED)
			SendMessage(hScrnWnd, WM_COMMAND, (WPARAM)(MENU_ENABLECHEAT),(LPARAM)(NULL));
	}

	if(key == EmuCommandTable[EMUCMD_EXITGAME].key
	&& modifiers == EmuCommandTable[EMUCMD_EXITGAME].keymod)
	{
		if (GetMenuState(hMenu,MENU_QUIT,NULL) != MF_GRAYED)
			SendMessage(hScrnWnd, WM_COMMAND, (WPARAM)(MENU_QUIT),(LPARAM)(NULL));
	}

	if(key == EmuCommandTable[EMUCMD_GAMEINFO].key
	&& modifiers == EmuCommandTable[EMUCMD_GAMEINFO].keymod)
	{
		if (GetMenuState(hMenu,MENU_VIEWGAMEINFO,NULL) != MF_GRAYED)
			SendMessage(hScrnWnd, WM_COMMAND, (WPARAM)(MENU_VIEWGAMEINFO),(LPARAM)(NULL));
	}

	if(key == EmuCommandTable[EMUCMD_DIPSWITCHES].key
	&& modifiers == EmuCommandTable[EMUCMD_DIPSWITCHES].keymod)
	{
		if (GetMenuState(hMenu,MENU_DIPSW,NULL) != MF_GRAYED)
			SendMessage(hScrnWnd, WM_COMMAND, (WPARAM)(MENU_DIPSW),(LPARAM)(NULL));
	}

	if(key == EmuCommandTable[EMUCMD_OPENGAME].key
	&& modifiers == EmuCommandTable[EMUCMD_OPENGAME].keymod)
	{
		if (GetMenuState(hMenu,MENU_LOAD,NULL) != MF_GRAYED)
			SendMessage(hScrnWnd, WM_COMMAND, (WPARAM)(MENU_LOAD),(LPARAM)(NULL));
	}

	if(key == EmuCommandTable[EMUCMD_LOADSTATEDIAG].key
	&& modifiers == EmuCommandTable[EMUCMD_LOADSTATEDIAG].keymod)
	{
		if (GetMenuState(hMenu,MENU_STATE_LOAD_DIALOG,NULL) != MF_GRAYED)
			SendMessage(hScrnWnd, WM_COMMAND, (WPARAM)(MENU_STATE_LOAD_DIALOG),(LPARAM)(NULL));
	}

	if(key == EmuCommandTable[EMUCMD_SAVESTATEDIAG].key
	&& modifiers == EmuCommandTable[EMUCMD_SAVESTATEDIAG].keymod)
	{
		if (GetMenuState(hMenu,MENU_STATE_SAVE_DIALOG,NULL) != MF_GRAYED)
			SendMessage(hScrnWnd, WM_COMMAND, (WPARAM)(MENU_STATE_SAVE_DIALOG),(LPARAM)(NULL));
	}

	if(key == EmuCommandTable[EMUCMD_SELECTSTATEPREV].key
	&& modifiers == EmuCommandTable[EMUCMD_SELECTSTATEPREV].keymod)
	{
		if (GetMenuState(hMenu,MENU_STATE_PREVSLOT,NULL) != MF_GRAYED)
			SendMessage(hScrnWnd, WM_COMMAND, (WPARAM)(MENU_STATE_PREVSLOT),(LPARAM)(NULL));
	}

	if(key == EmuCommandTable[EMUCMD_SELECTSTATENEXT].key
	&& modifiers == EmuCommandTable[EMUCMD_SELECTSTATENEXT].keymod)
	{
		if (GetMenuState(hMenu,MENU_STATE_NEXTSLOT,NULL) != MF_GRAYED)
			SendMessage(hScrnWnd, WM_COMMAND, (WPARAM)(MENU_STATE_NEXTSLOT),(LPARAM)(NULL));
	}

	if(key == EmuCommandTable[EMUCMD_SHOTFACTORY].key
	&& modifiers == EmuCommandTable[EMUCMD_SHOTFACTORY].keymod)
	{
		if (GetMenuState(hMenu,MENU_SNAPFACT,NULL) != MF_GRAYED)
			SendMessage(hScrnWnd, WM_COMMAND, (WPARAM)(MENU_SNAPFACT),(LPARAM)(NULL));
	}
}
