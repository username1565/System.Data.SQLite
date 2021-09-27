::Windows

:: Set pathway with msbuild.exe into variable %msbuild%
set fdir=%WINDIR%\Microsoft.NET\Framework
set msbuild=%fdir%\v4.0.30319\msbuild.exe

::	Build System.Data.SQLite.dll without SQLite.Interop.dll

::%msbuild% System.Data.SQLite\System.Data.SQLite.2010.csproj
:: out file: \sqlite-netFx-source-1.0.113.0\bin\2010\Debug\bin\System.Data.SQLite.dll not contains "SQLite.Interop.dll"

::	Build complete System.Data.SQLite.dll with SQLite.Interop.dll inside:

%msbuild% System.Data.SQLite\System.Data.SQLite.Module.2010.csproj
:: out file: \sqlite-netFx-source-1.0.113.0\bin\2010\DebugModule\bin\System.Data.SQLite.netmodule need to build "System.Data.SQLite.dll" with "SQLite.Interop.dll" inside.

%msbuild% SQLite.Interop\SQLite.Interop.2010.vcxproj
:: out file: \sqlite-netFx-source-1.0.113.0\bin\2010\Win32\Debug\System.Data.SQLite.dll have larger size, and consains "SQLite.Interop.dll" inside.

@(
::Show this:
echo.
echo See compiled files in "bin" and "obj" folders.
echo System.Data.SQLite.dll with SQLite.Interop.dll inside, contains in:
echo 	\bin\2010\Win32\Debug\System.Data.SQLite.dll
echo This file have larger size, then \bin\2010\Release\bin\System.Data.SQLite.dll
echo.

::Do not close console-window, after finish.
pause
)
