// Run module
#include "burner.h"

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

							case VK_OEM_PLUS: {
								TCHAR buffer[15];

								nAudVolume += 100;
								if (GetAsyncKeyState(VK_CONTROL) & 0x80000000) {
									nAudVolume += 900;
								}

								if (nAudVolume > 10000) {
									nAudVolume = 10000;
								}
								if (AudSoundSetVolume() == 0) {
									VidSNewShortMsg(FBALoadStringEx(hAppInst, IDS_SOUND_NOVOLUME, true));
								} else {
									_stprintf(buffer, FBALoadStringEx(hAppInst, IDS_SOUND_VOLUMESET, true), nAudVolume / 100);
									VidSNewShortMsg(buffer);
								}
								break;
							}
							case VK_OEM_MINUS: {
								TCHAR buffer[15];

								nAudVolume -= 100;
								if (GetAsyncKeyState(VK_CONTROL) & 0x80000000) {
									nAudVolume -= 900;
								}

								if (nAudVolume < 0) {
									nAudVolume = 0;
								}
								if (AudSoundSetVolume() == 0) {
									VidSNewShortMsg(FBALoadStringEx(hAppInst, IDS_SOUND_NOVOLUME, true));
								} else {
									_stprintf(buffer, FBALoadStringEx(hAppInst, IDS_SOUND_VOLUMESET, true), nAudVolume / 100);
									VidSNewShortMsg(buffer);
								}
								break;
							}
							case VK_MENU: {
								continue;
							}
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
							case VK_ESCAPE: {
								if (hwndChat) {
									DeActivateChat();
								} else {
									if (bCmdOptUsed) {
										PostQuitMessage(0);
									} else {
										if (nVidFullscreen) {
											nVidFullscreen = 0;
											POST_INITIALISE_MESSAGE;
										}
									}
								}
								break;
							}
							case VK_RETURN: {
								if (hwndChat) {
									int i = 0;
									while (EditText[i]) {
										if (EditText[i++] != 0x20) {
											break;
										}
									}
									if (i) {
										Kaillera_Chat_Send(TCHARToANSI(EditText, NULL, 0));
										//kailleraChatSend(TCHARToANSI(EditText, NULL, 0));
									}
									DeActivateChat();

									break;
								}
								if (GetAsyncKeyState(VK_CONTROL) & 0x80000000) {
									bMenuEnabled = !bMenuEnabled;
									POST_INITIALISE_MESSAGE;

									break;
								}

								break;
							}

//							case VK_F1: {
//								if (kNetGame) {
//									break;
//								}
//
//								if ((GetAsyncKeyState(VK_CONTROL) | GetAsyncKeyState(VK_SHIFT) & 0x80000000) == 0) {
//									if (bRunPause) {
//										bAppDoStep = 1;
//									} else {
//										bAppDoFast = 1;
//									}
//								}
//								break;
//							}

							case VK_PAUSE:
							case 'P': // pause - unpause
								bRunPause^=1;
								break;

							case VK_OEM_5:
							case VK_SPACE: // frame advance
								if (!bRunPause) bRunPause = 1;
									bAppDoStep = 1;
								break;

							case VK_TAB: // turbo mode
								bAppDoFast = 1;
								break;

							case '8': // read-only toggle
								if (GetKeyState(VK_SHIFT) & 0x8000) {
									bReplayReadOnly^=1;
									if (bReplayReadOnly)
										VidSNewShortMsg(L"read-only");
									else
										VidSNewShortMsg(L"read+write");
									VidRedraw();
									VidPaint(0);
								}
								break;

							case VK_F1:
								if (GetKeyState(VK_SHIFT) & 0x8000) StatedSave(1);
								else StatedLoad(1);
							break;
							case VK_F2:
								if (GetKeyState(VK_SHIFT) & 0x8000) StatedSave(2);
								else StatedLoad(2);
							break;
							case VK_F3:
								if (GetKeyState(VK_SHIFT) & 0x8000) StatedSave(3);
								else StatedLoad(3);
							break;
							case VK_F4:
								if (GetKeyState(VK_SHIFT) & 0x8000) StatedSave(4);
								else StatedLoad(4);
							break;
							case VK_F5:
								if (GetKeyState(VK_SHIFT) & 0x8000) StatedSave(5);
								else StatedLoad(5);
							break;
							case VK_F6:
								if (GetKeyState(VK_SHIFT) & 0x8000) StatedSave(6);
								else StatedLoad(6);
							break;
							case VK_F7:
								if (GetKeyState(VK_SHIFT) & 0x8000) StatedSave(7);
								else StatedLoad(7);
							break;
							case VK_F8:
								if (GetKeyState(VK_SHIFT) & 0x8000) StatedSave(8);
								else StatedLoad(8);
							break;
							case VK_F9:
								if (GetKeyState(VK_SHIFT) & 0x8000) StatedSave(9);
								else StatedLoad(9);
							break;

							case VK_BACK: {
								if (GetAsyncKeyState(VK_SHIFT) & 0x80000000) {
									bReplayFrameCounterDisplay = !bReplayFrameCounterDisplay;
									if (!bReplayFrameCounterDisplay) {
										VidSKillTinyMsg();
									}
								} else {
									bShowFPS = !bShowFPS;
									if (bShowFPS) {
										DisplayFPS();
									} else {
										VidSKillShortMsg();
										VidSKillOSDMsg();
									}
								}
								break;
							}
							case 'T': {
								if (kNetGame && hwndChat == NULL) {
									if (AppMessage(&Msg)) {
										ActivateChat();
									}
								}
								break;
							}
							case VK_OEM_PLUS: {
								if (GetAsyncKeyState(VK_SHIFT) & 0x80000000) {
									wchar_t buffer[15];

									if (nFpsScale < 10) {
										nFpsScale = 10;
									} else {
										if (nFpsScale >= 100) {
											nFpsScale += 50;
										} else {
											nFpsScale += 10;
										}
									}

									if (nFpsScale > 800) {
										nFpsScale = 800;
									}

									swprintf(buffer, L"speed %02i %%", nFpsScale);
									VidSNewShortMsg(buffer);
									VidRedraw();
									VidPaint(0);

									MediaChangeFps(nFpsScale);
								}
								break;
							}
							case VK_OEM_MINUS: {
								if(GetAsyncKeyState(VK_SHIFT) & 0x80000000) {
									wchar_t buffer[15];

									if (nFpsScale <= 10) {
										nFpsScale = 5;
									} else {
										if (nFpsScale > 100) {
											nFpsScale -= 50;
										} else {
											nFpsScale -= 10;
										}
									}

									swprintf(buffer, L"speed %02i %%", nFpsScale);
									VidSNewShortMsg(buffer);
									VidRedraw();
									VidPaint(0);

									MediaChangeFps(nFpsScale);
								}
								break;
							}
						}
					}
				} else {
					if (Msg.message == WM_SYSKEYUP || Msg.message == WM_KEYUP) {
						switch (Msg.wParam) {
							case VK_MENU:
								continue;
							case VK_TAB:
								bAppDoFast = 0;
								break;
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

