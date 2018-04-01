What does the Recording Version do?
===================================

FinalBurn Alpha Rerecording is the rerecording version of [Final Burn Alpha]
with many customized features designed to aid in recording movie input files

Resources
=========

http://tasvideos.org/forum/viewtopic.php?t=7234
http://tasvideos.org/EmulatorResources/Fbarr.html
http://tasvideos.org/EmulatorResources/Fbarr/FBM.html


Windows Compilation Guide for Dummies
=====================================

For people like myself who aren't familiar with compiling code in Windows, this is easiest way to get yourself building FBA-rr.

Follow the FBA [Compilation Guide] for GCC 3.4.5. *BUT*, before running `mingw32-make mingw345`, you'll have to take care of LUA dependencies


- In `c:\mingw345\makefile.mingw345`, comment out this line

  ```
  allobj += $(srcdir)depend/libs/lua/liblua51.a
  ```

- Copy Lua Headers into place
  1. Download [Lua 5.1.5 source code]
  2. Copy `src\*.h` into `c:\mingw345\include`

- Copy Lua Binaries into place
  1. Download latest build of [Lua 5.1.5 Libraries] files from Sourceforge
  1. Copy `lua5.1.dll` and `lua5.1.lib` into `c:\mingw345\lib`  

[Compilation Guide]: https://www.fbalpha.com/compile/
[Lua 5.1.5 source code]: https://www.lua.org/versions.html#5.1
[Lua 5.1.5 Libraries]: https://sourceforge.net/projects/luabinaries/files/5.1.5/Windows%20Libraries/Dynamic/
[Final Burn Alpha]: https://www.fbalpha.com/
