**v0.0.5.01** <sub>(2010-09-01)</sub>
  * Added "Graphics layers" menu.
  * Added "Lua drawings in captures" option (enabled by default).
  * Map hotkeys: setting "Select Slot 1" to 0, "Load State 1" to F1, or "Save State 1" to Shift+F1 will cause the remaining to auto-fill.
  * Loadstate errors now successfully restore a movie instead of corrupting it.
  * Backup loadstate function.
  * Bind savestates to movies, with a toggle option in the menu. (Note: it is highly recommended keep this feature on because FBA can corrupt movie files due to poor handling of savestates.)
  * Movie name displayed in title bar.
  * New lua functions: movie.playbeginning(), movie.setreadonly(), movie.getreadonly() and movie.length().
  * Menu items for frame counter toggle and play movie from beginning.
  * Play movie from beginning hotkey now works.
  * Update frame counter on loadstate.
  * Doesn't crash when canceling open ROM dialog.
  * Save/load state message include slot number.
  * Crash fixes.
  * Fullscreen (-f) commandline option.
  * Menu is now a real menu (and thus alt key combos work again).
  * 10 Saveslots now (instead of 9).
  * Drag & Drop support for savestates, movie files, and lua scripts (both main window and lua console window).
  * GUI cleanups.
  * Windowed mode default when loading game from commandline (instead of fullscreen).
  * RAM Search: fix reset to update previous values.
  * RAM Search: fix counting number of changes.
  * RAM Watch: Add Separator button.

**v0.0.5** <sub>(2010-08-09)</sub>
  * Updated core to FB Alpha v0.2.97.08.
  * 77% less crashes.
  * Added a lot of new Lua functions.
  * Added RAM Watch and RAM Search from Gens. RAM Search is very slow because FBA-RR can't filter addresses, so you may want to use MAME-RR to find them (.wch files are 100% compatible between both emulators.)

**v0.0.4.01** <sub>(2009-11-17)</sub>
  * Disabled unused RAM Watch accelerators, which were opening a dialog every time the R key was pressed.
  * Reverted to the old Pause behavior.
  * The screen is now automatically refreshed when emulation is paused. This makes some Lua scripts, such as FatRatKnight's "Multi-track rerecording", work better with gui.register.
  * Added "Haunted Castle" driver to the release build.
  * Fixed the input for player 4 in the TMNT driver.
  * Fixed the Lua function joypad.set().

**v0.0.4** <sub>(2009-11-13)</sub>
  * Updated core to FB Alpha v0.2.97.07.
  * Added Lua scripting.
  * Added RAM Search of FBA Shuffle (which unfortunately just crashes in most games).
  * Added the old RAM Watch of PCSX-RR.
  * Added many new hotkeys and better handling of them.
  * Fixed some desyncs that were caused when loading existing NV-RAM files. These files are now ignored.
  * Fixed "everything causes frame advancing".
  * Other minor fixes and changes here and there.

**v0.0.3.03** <sub>(2009-07-07)</sub>
  * Bugfix: couldn't save/load current state during movie playback/recording.
  * Bugfix: default filename for AVI files was a single letter; now it's the loaded ROM name.

**v0.0.3.02** <sub>(2009-06-08)</sub>
  * Bugfix: custom input config was not loaded.

**v0.0.3.01** <sub>(2009-06-02)</sub>
  * I forgot to re-arrange menu items in v0.0.3, that's been fixed now.
  * Added configurable hotkeys.
  * FBA-RR won't unpause automatically anymore after the DIP switches config or a movie start.

**v0.0.3** <sub>(2009-06-01)</sub>
  * Quick update to FB Alpha v0.2.97.06.
  * Reverted some changes from v0.0.2, mainly menu and skin related.

**v0.0.2** <sub>(2008-09-15)</sub>
  * Added shortcut keys to some of the menus and dialogs.
  * Fixed various crashes in movie functions (hopefully).
  * Record/replay dialogs are accessible without a rom loaded, and will load a rom as needed.
  * Input mapper recalls mapped inputs.
  * SRAM is no longer loaded on playback (and thus no longer causes desyncs).
  * Read-only is enabled by default.
  * Frameskip is disabled by default.
  * Movie replay dialog selects "browse" when there are no movies; not a null entry.
  * Emulation speed is properly reset on rom load.
  * Temp fix to prevent crashes when changing emulation speed.
  * You may no longer attempt to save/load a savestate when no rom is open.
  * More minutiae than is reasonable to list.

**v0.0.1** <sub>(2008-08-31)</sub>
  * "Start recording from power-on" option.
  * Read-only toggle.
  * New hotkeys mapping.
  * Frame counter shows total movie frames.
  * Screen redraws after loading a savestate, even if emulation is paused.
  * Screen updates after showing a message, even if emulation is paused.
  * Pause automatically at last frame of playback to prevent movie end.
  * Emulation isn't automatically paused anymore **after** the movie ends.
  * New "replay stopped" message.

**v0.0.0** <sub>(2008-08-28)</sub>
  * Ported blip's patch to v0.2.96.94.