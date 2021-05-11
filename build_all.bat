::Go to "Setup"-folder
cd Setup

@(
::build all:
build_all.bat

::Show this:
echo.
echo See compiled files in "bin" and "obj" folders.
echo System.Data.SQLite.dll with SQLite.Interop.dll inside, contains in:
echo 	\bin\2010\Win32\Release\System.Data.SQLite.dll
echo and
echo 	\bin\2010\x64\Release\System.Data.SQLite.dll
echo This file have larger size, then \bin\2010\Release\bin\System.Data.SQLite.dll
echo.

::Do not close console-window, after finish.
pause
)
