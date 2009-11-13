#ifndef __MAPHKEYS_H__
#define __MAPHKEYS_H__

struct CustomKey
{
	typedef void (*KeyHandler) (int param);

	int key;
	int keymod;
	int menuid;
	const char* name;
	const char* config_code;

	KeyHandler handleKeyDown;
	KeyHandler handleKeyUp;
	int param;
};

extern CustomKey customKeys[];

inline bool lastCustomKey(const CustomKey& key) {
	return (key.key == 0xffff && key.keymod == 0xffff);
}

int MHkeysCreate();
int MHkeysUpdateMenuAcc();
int MHkeysDownHandle(const MSG& Msg);
int MHkeysUpHandle(const MSG& Msg);

// key functions
void HK_callMenu(int);
void HK_fastFowardKeyDown(int);
void HK_fastFowardKeyUp(int);
void HK_loadState(int param);
void HK_saveState(int param);
void HK_selectState(int param);
void HK_prevState(int);
void HK_nextState(int);
void HK_loadCurState(int);
void HK_saveCurState(int);
void HK_loadStateDialog(int);
void HK_saveStateDialog(int);
void HK_playRec(int);
void HK_playFromBeginning(int);
void HK_stopRec(int);
void HK_startRec(int);
void HK_startAvi(int);
void HK_stopAvi(int);
void HK_frameAdvance(int);
void HK_toggleReadOnly(int);
void HK_frameCounter(int);
void HK_pause(int);
void HK_speedInc(int);
void HK_speedDec(int);
void HK_speedNormal(int);
void HK_speedTurbo(int);
void HK_volumeDec(int);
void HK_volumeInc(int);
void HK_showFps(int);
void HK_configPad(int);
void HK_setDips(int);
void HK_cheatEditor(int);
void HK_ramSearch(int);
void HK_ramSearchOld(int);
void HK_ramWatch(int);
void HK_ramWatchOld(int);
void HK_windowSize(int param);
void HK_windowSizeMax(int);
void HK_fullscreen(int);
void HK_screenShot(int);
void HK_shotFactory(int);
void HK_openGame(int);
void HK_gameInfo(int);
void HK_quickOpenGame(int);
void HK_exitGame(int);
void HK_luaOpen(int);
void HK_luaCloseAll(int);
void HK_luaReload(int);
void HK_luaStop(int);

#endif /* __MAPHKEYS_H__ */
