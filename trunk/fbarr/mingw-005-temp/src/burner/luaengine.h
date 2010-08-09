#ifndef _LUAENGINE_H
#define _LUAENGINE_H

enum LuaCallID
{
	LUACALL_BEFOREEMULATION,
	LUACALL_AFTEREMULATION,
	LUACALL_BEFOREEXIT,
	LUACALL_ONSTART,

	LUACALL_HOTKEY_1,
	LUACALL_HOTKEY_2,
	LUACALL_HOTKEY_3,
	LUACALL_HOTKEY_4,
	LUACALL_HOTKEY_5,

	LUACALL_COUNT
};
void CallRegisteredLuaFunctions(int calltype);

//void FBA_LuaWrite(UINT32 addr);
void FBA_LuaFrameBoundary();
int FBA_LoadLuaCode(const char *filename);
void FBA_ReloadLuaCode();
void FBA_LuaStop();
int FBA_LuaRunning();

int FBA_LuaUsingJoypad();
UINT32 FBA_LuaReadJoypad();
int FBA_LuaSpeed();
//int FBA_LuaFrameskip();
int FBA_LuaRerecordCountSkip();

void FBA_LuaGui(unsigned char *s, int width, int height, int bpp, int pitch);

void FBA_LuaWriteInform();

void FBA_LuaClearGui();
void FBA_LuaEnableGui(UINT8 enabled);

char* FBA_GetLuaScriptName();

void luasav_save(const char *filename);
void luasav_load(const char *filename);

#endif
