// Run module
#include "burner.h"

#include "maphkeys.h"

int bRunPause = 0;
int bAltPause = 0;

int bAlwaysDrawFrames = 1;

bool bShowFPS = false;
static unsigned int nDoFPS = 0;

int kNetGame = 0;							// Non-zero if Kaillera is being used

#ifdef FBA_DEBUG
int counter;								// General purpose variable used when debugging
#endif

static unsigned int nNormalLast = 0;		// Last value of timeGetTime()
static int nNormalFrac = 0;					// Extra fraction we did

bool bAppDoStep = 0;
bool bAppDoFast = 0;
int nFastSpeed = 6;
int nFpsScale = 100;

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

void DisplayFPS()
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
		VidRedraw();
		VidPaint(0);
	}
	else {
		CallRegisteredLuaFunctions(LUACALL_BEFOREEMULATION); //TODO: find proper place

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
				GetInput(true); // Update inputs 
				if (FBA_LuaUsingJoypad()) {
					FBA_LuaReadJoypad(); 
				} 
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

		FBA_LuaFrameBoundary(); 
		Update_RAM_Search();
		UpdateMemWatch();
		CallRegisteredLuaFunctions(LUACALL_AFTEREMULATION); //TODO: find proper place 
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

static int RunKeyMsg(const MSG& Msg)
{
	if (Msg.message == WM_SYSKEYDOWN || Msg.message == WM_KEYDOWN) {
		return MHkeysDownHandle(Msg);
	} else {
		if (Msg.message == WM_SYSKEYUP || Msg.message == WM_KEYUP) {
			return MHkeysUpHandle(Msg);
		}
	}

	return 0;
}

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

				// process key message
				RunKeyMsg(Msg);

				if (Msg.message == WM_SYSKEYDOWN || Msg.message == WM_KEYDOWN) {
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
				}

				// Check for messages for dialogs etc.
				if (AppMessage(&Msg)) {
					if (TranslateAccelerator(hScrnWnd, hAccel, &Msg) == 0) {

						//mbg 12-aug-2010 - commented out the check for hwndChat.
						//may have unintended consequences by interacting poorly with hotkeys or something
						//if (hwndChat) {
							TranslateMessage(&Msg);
						//}
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
