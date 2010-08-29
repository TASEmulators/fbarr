#include <string>

//Backup savestate/loadstate values
extern wchar_t lastSavestateMade[2048]; //Stores the filename of the last savestate made (needed for UndoSavestate)
extern bool undoSS;		  //This will be true if there is lastSavestateMade, it was made since ROM was loaded, a backup state for lastSavestateMade exists
extern bool redoSS;		  //This will be true if UndoSaveState is run, will turn false when a new savestate is made

extern wchar_t lastLoadstateMade[2048]; //Stores the filename of the last state loaded (needed for Undo/Redo loadstate)
extern bool undoLS;		  //This will be true if a backupstate was made and it was made since ROM was loaded
extern bool redoLS;		  //This will be true if a backupstate was loaded, meaning redoLoadState can be run

extern void LoadBackup(bool);