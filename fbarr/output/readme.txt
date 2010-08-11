FinalBurn Alpha Rerecording
----------------------------------------

FinalBurn Alpha Rerecording is the
rerecording version of FinalBurn Alpha
with many customized features designed
to aid in recording movie input files.

http://code.google.com/p/fbarr/
----------------------------------------


Official  - http://www.barryharris.me.uk
FB Alpha  - http://fba.emuunlim.com
----------------------------------------

!!!Warning!!!
-----------

By default, most games use this configuration:
F2 : test
F3 : reset
So, if you want to use savestate slots 2 and 3, you'll need to change them ("Input" -> "Map game inputs...").


What's New?
-----------

v0.0.5
-77% less crashes.
-Added a lot of new Lua functions.
-Added RAM Watch and RAM Search from Gens. RAM Search is very slow because FBA-RR can't filter addresses, so you may want to use MAME-RR to find them (.wch files are 100% compatible between both emulators.)
-Updated core to FB Alpha v0.2.97.08.

v0.0.4.01
-Disabled unused RAM Watch accelerators, which were opening a dialog every time the R key was pressed.
-Reverted to the old Pause behavior.
-The screen is now automatically refreshed when emulation is paused. This makes some Lua scripts, such as FatRatKnight's "Multi-track rerecording", work better with gui.register.
-Added "Haunted Castle" driver to the release build.
-Fixed the input for player 4 in the TMNT driver.
-Fixed the Lua function joypad.set().

v0.0.4
-Updated core to FB Alpha v0.2.97.07.
-Added Lua scripting.
-Added RAM Search of FBA Shuffle (which unfortunately just crashes in most games).
-Added the old RAM Watch of PCSX-RR.
-Added many new hotkeys and better handling of them.
-Some minor fixes and changes here and there.

v0.0.3.03
-Bugfix: couldn't save/load current state during movie playback/recording.
-Bugfix: default filename for AVI files was a single letter; now it's the loaded ROM name.

v0.0.3.02
-Bugfix: custom input config was not loaded.

v0.0.3.01
-I forgot to re-arrange menu items in v0.0.3, that's been fixed now
-Added configurable hotkeys
-FBA-RR won't unpause automatically anymore after the DIP switches config or a movie start

v0.0.3
-Quick update to FB Alpha v0.2.97.06.
-Reverted some changes from v0.0.2, mainly menu and skin related.

v0.0.2
-Added shortcut keys to some of the menus and dialogs
-Fixed various crashes in movie functions (hopefully)
-Record/replay dialogs are accessible without a rom loaded, and will load a rom as needed
-Input mapper recalls mapped inputs
-SRAM is no longer loaded on playback (and thus no longer causes desyncs)
-Read-only is enabled by default
-Frameskip is disabled by default
-Movie replay dialog selects "browse" when there are no movies; not a null entry
-Emulation speed is properly reset on rom load
-Temp fix to prevent crashes when changing emulation speed
-You may no longer attempt to save/load a savestate when no rom is open
-More minutiae than is reasonable to list

v0.0.1
-"Start recording from power-on" option
-Read-only toggle
-New hotkeys mapping
-Frame counter shows total movie frames
-Screen redraws after loading a savestate, even if emulation is paused
-Screen updates after showing a message, even if emulation is paused
-Pause automatically at last frame of playback to prevent movie end
-Emulation isn't automatically paused anymore *after* the movie ends
-New "replay stopped" message

v0.0.0
-Ported blip's patch to v0.2.96.94