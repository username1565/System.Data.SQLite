@ECHO OFF

::
:: build.bat --
::
:: Wrapper Tool for MSBuild
::
:: Written by Joe Mistachkin.
:: Released to the public domain, use at your own risk!
::

SETLOCAL

REM SET __ECHO=ECHO
REM SET __ECHO2=ECHO
REM SET __ECHO3=ECHO
IF NOT DEFINED _AECHO (SET _AECHO=REM)
IF NOT DEFINED _CECHO (SET _CECHO=REM)
IF NOT DEFINED _VECHO (SET _VECHO=REM)

%_AECHO% Running %0 %*

SET DUMMY2=%4

IF DEFINED DUMMY2 (
  GOTO usage
)

SET ROOT=%~dp0\..
SET ROOT=%ROOT:\\=\%

%_VECHO% Root = '%ROOT%'

SET CONFIGURATION=%1

IF DEFINED CONFIGURATION (
  CALL :fn_UnquoteVariable CONFIGURATION
) ELSE (
  %_AECHO% No configuration specified, using default...
  SET CONFIGURATION=Release
)

%_VECHO% Configuration = '%CONFIGURATION%'

SET PLATFORM=%2

IF DEFINED PLATFORM (
  CALL :fn_UnquoteVariable PLATFORM
) ELSE (
  %_AECHO% No platform specified, using default...
  SET PLATFORM=Win32
)

%_VECHO% Platform = '%PLATFORM%'

SET YEAR=%3

IF DEFINED YEAR (
  CALL :fn_UnquoteVariable YEAR
) ELSE (
  %_AECHO% No year specified, using default...
)

%_VECHO% Year = '%YEAR%'

SET BASE_CONFIGURATION=%CONFIGURATION%
SET BASE_CONFIGURATION=%BASE_CONFIGURATION:ManagedOnly=%
SET BASE_CONFIGURATION=%BASE_CONFIGURATION:NativeOnly=%
SET BASE_CONFIGURATION=%BASE_CONFIGURATION:Static=%

%_VECHO% BaseConfiguration = '%BASE_CONFIGURATION%'

SET TOOLS=%~dp0
SET TOOLS=%TOOLS:~0,-1%

%_VECHO% Tools = '%TOOLS%'

SET EXTERNALS=%ROOT%\Externals
SET EXTERNALS=%EXTERNALS:\\=\%

%_VECHO% Externals = '%EXTERNALS%'

IF NOT DEFINED VSWHERE_EXE (
  SET VSWHERE_EXE=%EXTERNALS%\vswhere\vswhere.exe
)

SET VSWHERE_EXE=%VSWHERE_EXE:\\=\%

%_VECHO% VsWhereExe = '%VSWHERE_EXE%'

IF EXIST "%TOOLS%\set_%CONFIGURATION%_%PLATFORM%.bat" (
  CALL :fn_ResetErrorLevel

  %_AECHO% Running "%TOOLS%\set_%CONFIGURATION%_%PLATFORM%.bat"...
  %__ECHO3% CALL "%TOOLS%\set_%CONFIGURATION%_%PLATFORM%.bat"

  IF ERRORLEVEL 1 (
    ECHO File "%TOOLS%\set_%CONFIGURATION%_%PLATFORM%.bat" failed.
    GOTO errors
  )
)

IF NOT DEFINED NOUSER (
  IF EXIST "%TOOLS%\set_user_%USERNAME%_%BASE_CONFIGURATION%_%PLATFORM%.bat" (
    CALL :fn_ResetErrorLevel

    %_AECHO% Running "%TOOLS%\set_user_%USERNAME%_%BASE_CONFIGURATION%_%PLATFORM%.bat"...
    %__ECHO3% CALL "%TOOLS%\set_user_%USERNAME%_%BASE_CONFIGURATION%_%PLATFORM%.bat"

    IF ERRORLEVEL 1 (
      ECHO File "%TOOLS%\set_user_%USERNAME%_%BASE_CONFIGURATION%_%PLATFORM%.bat" failed.
      GOTO errors
    )
  )

  IF EXIST "%TOOLS%\set_user_%USERNAME%_%BASE_CONFIGURATION%.bat" (
    CALL :fn_ResetErrorLevel

    %_AECHO% Running "%TOOLS%\set_user_%USERNAME%_%BASE_CONFIGURATION%.bat"...
    %__ECHO3% CALL "%TOOLS%\set_user_%USERNAME%_%BASE_CONFIGURATION%.bat"

    IF ERRORLEVEL 1 (
      ECHO File "%TOOLS%\set_user_%USERNAME%_%BASE_CONFIGURATION%.bat" failed.
      GOTO errors
    )
  )

  IF EXIST "%TOOLS%\set_user_%USERNAME%.bat" (
    CALL :fn_ResetErrorLevel

    %_AECHO% Running "%TOOLS%\set_user_%USERNAME%.bat"...
    %__ECHO3% CALL "%TOOLS%\set_user_%USERNAME%.bat"

    IF ERRORLEVEL 1 (
      ECHO File "%TOOLS%\set_user_%USERNAME%.bat" failed.
      GOTO errors
    )
  )
)

IF NOT DEFINED MSBUILD (
  SET MSBUILD=MSBuild.exe
)

%_VECHO% MsBuild = '%MSBUILD%'

IF NOT DEFINED DOTNET (
  SET DOTNET=dotnet.exe
)

%_VECHO% DotNet = '%DOTNET%'

IF NOT DEFINED CSC (
  SET CSC=csc.exe
)

%_VECHO% Csc = '%CSC%'

REM ****************************************************************************
REM ********************* .NET Framework Version Overrides *********************
REM ****************************************************************************

REM
REM TODO: When the next version of Visual Studio is released, this section may
REM       need updating.
REM
IF DEFINED NETCORE20ONLY (
  %_AECHO% Forcing the use of the .NET Core 2.0...
  IF NOT DEFINED YEAR (
    IF DEFINED NETCORE20YEAR (
      SET YEAR=%NETCORE20YEAR%
    ) ELSE (
      SET YEAR=NetStandard20
    )
  )
  CALL :fn_VerifyDotNetCore
  IF ERRORLEVEL 1 GOTO errors
  SET NOBUILDTOOLDIR=1
  SET USEDOTNET=1
  GOTO setup_buildToolDir
)

IF DEFINED NETCORE30ONLY (
  %_AECHO% Forcing the use of the .NET Core 3.0...
  IF NOT DEFINED YEAR (
    IF DEFINED NETCORE30YEAR (
      SET YEAR=%NETCORE30YEAR%
    ) ELSE (
      SET YEAR=NetStandard21
    )
  )
  CALL :fn_VerifyDotNetCore
  IF ERRORLEVEL 1 GOTO errors
  SET NOBUILDTOOLDIR=1
  SET USEDOTNET=1
  GOTO setup_buildToolDir
)

IF DEFINED NETFX20ONLY (
  %_AECHO% Forcing the use of the .NET Framework 2.0...
  IF NOT DEFINED YEAR (
    IF DEFINED NETFX20YEAR (
      SET YEAR=%NETFX20YEAR%
    ) ELSE (
      SET YEAR=2005
    )
  )
  CALL :fn_CheckFrameworkDir v2.0.50727
  GOTO setup_buildToolDir
)

IF DEFINED NETFX35ONLY (
  %_AECHO% Forcing the use of the .NET Framework 3.5...
  IF NOT DEFINED YEAR (
    IF DEFINED NETFX35YEAR (
      SET YEAR=%NETFX35YEAR%
    ) ELSE (
      SET YEAR=2008
    )
  )
  CALL :fn_CheckFrameworkDir v3.5
  GOTO setup_buildToolDir
)

IF DEFINED NETFX40ONLY (
  %_AECHO% Forcing the use of the .NET Framework 4.0...
  IF NOT DEFINED YEAR (
    IF DEFINED NETFX40YEAR (
      SET YEAR=%NETFX40YEAR%
    ) ELSE (
      SET YEAR=2010
    )
  )
  CALL :fn_CheckFrameworkDir v4.0.30319
  GOTO setup_buildToolDir
)

IF DEFINED NETFX45ONLY (
  %_AECHO% Forcing the use of the .NET Framework 4.5...
  IF NOT DEFINED YEAR (
    IF DEFINED NETFX45YEAR (
      SET YEAR=%NETFX45YEAR%
    ) ELSE (
      SET YEAR=2012
    )
  )
  CALL :fn_CheckFrameworkDir v4.0.30319
  GOTO setup_buildToolDir
)

IF DEFINED NETFX451ONLY (
  %_AECHO% Forcing the use of the .NET Framework 4.5.1...
  IF NOT DEFINED YEAR (
    IF DEFINED NETFX451YEAR (
      SET YEAR=%NETFX451YEAR%
    ) ELSE (
      SET YEAR=2013
    )
  )
  CALL :fn_CheckFrameworkDir v4.0.30319
  CALL :fn_CheckMsBuildDir 12.0
  GOTO setup_buildToolDir
)

IF DEFINED NETFX452ONLY (
  %_AECHO% Forcing the use of the .NET Framework 4.5.2...
  IF NOT DEFINED YEAR (
    IF DEFINED NETFX452YEAR (
      SET YEAR=%NETFX452YEAR%
    ) ELSE (
      SET YEAR=2013
    )
  )
  CALL :fn_CheckFrameworkDir v4.0.30319
  CALL :fn_CheckMsBuildDir 12.0
  GOTO setup_buildToolDir
)

IF DEFINED NETFX46ONLY (
  %_AECHO% Forcing the use of the .NET Framework 4.6...
  IF NOT DEFINED YEAR (
    IF DEFINED NETFX46YEAR (
      SET YEAR=%NETFX46YEAR%
    ) ELSE (
      SET YEAR=2015
    )
  )
  CALL :fn_CheckFrameworkDir v4.0.30319
  CALL :fn_CheckMsBuildDir 14.0
  GOTO setup_buildToolDir
)

IF DEFINED NETFX461ONLY (
  %_AECHO% Forcing the use of the .NET Framework 4.6.1...
  IF NOT DEFINED YEAR (
    IF DEFINED NETFX461YEAR (
      SET YEAR=%NETFX461YEAR%
    ) ELSE (
      SET YEAR=2015
    )
  )
  CALL :fn_CheckFrameworkDir v4.0.30319
  CALL :fn_CheckMsBuildDir 14.0
  GOTO setup_buildToolDir
)

IF DEFINED NETFX462ONLY (
  %_AECHO% Forcing the use of the .NET Framework 4.6.2...
  IF NOT DEFINED YEAR (
    IF DEFINED NETFX462YEAR (
      SET YEAR=%NETFX462YEAR%
    ) ELSE (
      SET YEAR=2015
    )
  )
  CALL :fn_CheckFrameworkDir v4.0.30319
  CALL :fn_CheckMsBuildDir 14.0
  GOTO setup_buildToolDir
)

IF DEFINED NETFX47ONLY (
  %_AECHO% Forcing the use of the .NET Framework 4.7...
  IF NOT DEFINED YEAR (
    IF DEFINED NETFX47YEAR (
      SET YEAR=%NETFX47YEAR%
    ) ELSE (
      SET YEAR=2017
    )
  )
  IF NOT DEFINED NOUSEPACKAGERESTORE (
    IF NOT DEFINED USEPACKAGERESTORE (
      SET USEPACKAGERESTORE=1
    )
  )
  CALL :fn_CheckFrameworkDir v4.0.30319
  CALL :fn_CheckMsBuildDir 14.0
  CALL :fn_CheckVisualStudioMsBuildDir 15.0 15.0
  GOTO setup_buildToolDir
)

IF DEFINED NETFX471ONLY (
  %_AECHO% Forcing the use of the .NET Framework 4.7.1...
  IF NOT DEFINED YEAR (
    IF DEFINED NETFX471YEAR (
      SET YEAR=%NETFX471YEAR%
    ) ELSE (
      SET YEAR=2017
    )
  )
  IF NOT DEFINED NOUSEPACKAGERESTORE (
    IF NOT DEFINED USEPACKAGERESTORE (
      SET USEPACKAGERESTORE=1
    )
  )
  CALL :fn_CheckFrameworkDir v4.0.30319
  CALL :fn_CheckMsBuildDir 14.0
  CALL :fn_CheckVisualStudioMsBuildDir 15.0 15.0
  GOTO setup_buildToolDir
)

IF DEFINED NETFX472ONLY (
  %_AECHO% Forcing the use of the .NET Framework 4.7.2...
  IF NOT DEFINED YEAR (
    IF DEFINED NETFX472YEAR (
      SET YEAR=%NETFX472YEAR%
    ) ELSE (
      SET YEAR=2017
    )
  )
  IF NOT DEFINED NOUSEPACKAGERESTORE (
    IF NOT DEFINED USEPACKAGERESTORE (
      SET USEPACKAGERESTORE=1
    )
  )
  CALL :fn_CheckFrameworkDir v4.0.30319
  CALL :fn_CheckMsBuildDir 14.0
  CALL :fn_CheckVisualStudioMsBuildDir 15.0 15.0
  GOTO setup_buildToolDir
)

IF DEFINED NETFX48ONLY (
  %_AECHO% Forcing the use of the .NET Framework 4.8...
  IF NOT DEFINED YEAR (
    IF DEFINED NETFX48YEAR (
      SET YEAR=%NETFX48YEAR%
    ) ELSE (
      SET YEAR=2017
    )
  )
  IF NOT DEFINED NOUSEPACKAGERESTORE (
    IF NOT DEFINED USEPACKAGERESTORE (
      SET USEPACKAGERESTORE=1
    )
  )
  CALL :fn_CheckFrameworkDir v4.0.30319
  CALL :fn_CheckMsBuildDir 14.0
  CALL :fn_CheckVisualStudioMsBuildDir Current 16.0
  GOTO setup_buildToolDir
)

REM ****************************************************************************
REM ********************* Visual Studio Version Detection **********************
REM ****************************************************************************

CALL :fn_DetectVisualStudioDir

REM ****************************************************************************
REM ************************ MSBuild Version Detection *************************
REM ****************************************************************************

CALL :fn_DetectMsBuildDir

REM ****************************************************************************
REM ********************* .NET Framework Version Detection *********************
REM ****************************************************************************

CALL :fn_DetectFrameworkDir

REM ****************************************************************************
REM ***************************** Build Tool Setup *****************************
REM ****************************************************************************

:setup_buildToolDir

CALL :fn_SetupBuildTool

IF ERRORLEVEL 1 (
  ECHO Initial build tool setup failed.
  GOTO errors
)

REM ****************************************************************************
REM ****************************** Save Directory ******************************
REM ****************************************************************************

CALL :fn_ResetErrorLevel

%__ECHO2% PUSHD "%ROOT%"

IF ERRORLEVEL 1 (
  ECHO Could not change directory to "%ROOT%".
  GOTO errors
)

REM ****************************************************************************
REM **************************** Solution Handling *****************************
REM ****************************************************************************

IF DEFINED USEDOTNET IF DEFINED INTEROPONLY (
  CALL :fn_ForceMsBuildForInteropProject
)

%_VECHO% Configuration = '%CONFIGURATION%'
%_VECHO% Year = '%YEAR%'
%_VECHO% InteropYear = '%INTEROPYEAR%'
%_VECHO% NoBuildToolDir = '%NOBUILDTOOLDIR%'
%_VECHO% UseDotNet = '%USEDOTNET%'

CALL :fn_SetupSolution

%_VECHO% Solution = '%SOLUTION%'

IF NOT DEFINED SOLUTION (
  ECHO Solution file is not defined.
  GOTO errors
)

IF NOT EXIST "%SOLUTION%" (
  ECHO Solution file "%SOLUTION%" does not exist.
  GOTO errors
)

FOR /F %%E IN ('ECHO %SOLUTION%') DO (SET SOLUTIONEXT=%%~xE)
CALL :fn_ResetErrorLevel

%_VECHO% SolutionExt = '%SOLUTIONEXT%'

IF /I "%SOLUTIONEXT%" == ".csproj" (
  SET MSBUILD_CONFIGURATION=%BASE_CONFIGURATION%
) ELSE (
  SET MSBUILD_CONFIGURATION=%CONFIGURATION%
)

%_VECHO% MsBuildConfiguration = '%MSBUILD_CONFIGURATION%'

IF DEFINED INTEROPONLY (
  CALL :fn_DetectVisualStudioDir
  CALL :fn_DetectMsBuildDir
  CALL :fn_DetectFrameworkDir
  CALL :fn_SetupBuildTool

  IF ERRORLEVEL 1 (
    ECHO Updated build tool setup failed.
    GOTO errors
  )
)

REM ****************************************************************************
REM ***************************** Target Handling ******************************
REM ****************************************************************************

CALL :fn_SetupTarget

%_VECHO% Target = '%TARGET%'

REM ****************************************************************************
REM ******************************* Log Handling *******************************
REM ****************************************************************************

CALL :fn_SetupLogging
IF ERRORLEVEL 1 GOTO errors

%_VECHO% Temp = '%TEMP%'
%_VECHO% LogAsm = '%LOGASM%'
%_VECHO% LogDir = '%LOGDIR%'
%_VECHO% LogPrefix = '%LOGPREFIX%'
%_VECHO% LogSuffix = '%LOGSUFFIX%'
%_VECHO% Logging = '%LOGGING%'

REM ****************************************************************************
REM ************************ Extra Properties Handling *************************
REM ****************************************************************************

IF NOT DEFINED NOPROPS (
  IF EXIST Externals\Eagle\bin\netFramework40\EagleShell.exe (
    IF DEFINED INTEROP_EXTRA_PROPS_FILE (
      REM
      REM HACK: This is used to work around a limitation of Visual Studio 2005
      REM       and 2008 that prevents the "InheritedPropertySheets" attribute
      REM       value from working correctly when it refers to a property that
      REM       evaluates to an empty string.
      REM
      %_CECHO% Externals\Eagle\bin\netFramework40\EagleShell.exe -evaluate "set fileName {SQLite.Interop/props/include.vsprops}; set data [readFile $fileName]; regsub -- {	InheritedPropertySheets=\"\"} $data {	InheritedPropertySheets=\"$^(INTEROP_EXTRA_PROPS_FILE^)\"} data; writeFile $fileName $data"
      %__ECHO% Externals\Eagle\bin\netFramework40\EagleShell.exe -evaluate "set fileName {SQLite.Interop/props/include.vsprops}; set data [readFile $fileName]; regsub -- {	InheritedPropertySheets=\"\"} $data {	InheritedPropertySheets=\"$^(INTEROP_EXTRA_PROPS_FILE^)\"} data; writeFile $fileName $data"

      IF ERRORLEVEL 1 (
        ECHO Property file modification of "SQLite.Interop\props\include.vsprops" failed.
        GOTO errors
      ) ELSE (
        ECHO Property file modification successful.
      )
    )
  ) ELSE (
    ECHO WARNING: Property file modification skipped, Eagle binaries are not available.
  )
) ELSE (
  ECHO WARNING: Property file modification skipped, disabled via NOPROPS environment variable.
)

REM ****************************************************************************
REM *************************** Version Tag Handling ***************************
REM ****************************************************************************

IF NOT DEFINED NOTAG (
  IF EXIST Externals\Eagle\bin\netFramework40\EagleShell.exe (
    %_CECHO% Externals\Eagle\bin\netFramework40\EagleShell.exe -file Setup\sourceTag.eagle SourceIdMode SQLite.Interop\src\generic\interop.h
    %__ECHO% Externals\Eagle\bin\netFramework40\EagleShell.exe -file Setup\sourceTag.eagle SourceIdMode SQLite.Interop\src\generic\interop.h

    IF ERRORLEVEL 1 (
      ECHO Source tagging of "SQLite.Interop\src\generic\interop.h" failed.
      GOTO errors
    )

    %_CECHO% Externals\Eagle\bin\netFramework40\EagleShell.exe -file Setup\sourceTag.eagle SourceIdMode System.Data.SQLite\SQLitePatchLevel.cs
    %__ECHO% Externals\Eagle\bin\netFramework40\EagleShell.exe -file Setup\sourceTag.eagle SourceIdMode System.Data.SQLite\SQLitePatchLevel.cs

    IF ERRORLEVEL 1 (
      ECHO Source tagging of "System.Data.SQLite\SQLitePatchLevel.cs" failed.
      GOTO errors
    )
  ) ELSE (
    ECHO WARNING: Source tagging skipped, Eagle binaries are not available.
  )
) ELSE (
  ECHO WARNING: Source tagging skipped, disabled via NOTAG environment variable.
)

REM ****************************************************************************
REM ****************************** Build Solution ******************************
REM ****************************************************************************

CALL :fn_CopyVariable MSBUILD_ARGS_%BASE_CONFIGURATION% MSBUILD_ARGS_CFG

IF DEFINED USEDOTNET (
  SET MSBUILD=%DOTNET%
  SET BUILD_SUBCOMMANDS=build
  SET TARGET=Build
) ELSE (
  CALL :fn_UnsetVariable BUILD_SUBCOMMANDS
)

IF NOT DEFINED RESTORE_SUBCOMMANDS (
  SET RESTORE_SUBCOMMANDS=restore
)

%_VECHO% MsBuild = '%MSBUILD%'
%_VECHO% BuildSubCommands = '%BUILD_SUBCOMMANDS%'
%_VECHO% Target = '%TARGET%'
%_VECHO% BuildArgs = '%BUILD_ARGS%'
%_VECHO% MsBuildArgs = '%MSBUILD_ARGS%'
%_VECHO% MsBuildArgsCfg = '%MSBUILD_ARGS_CFG%'
%_VECHO% RestoreSubCommands = '%RESTORE_SUBCOMMANDS%'

IF DEFINED USEPACKAGERESTORE (
  %_CECHO% "%DOTNET%" %RESTORE_SUBCOMMANDS% "%SOLUTION%"
  %__ECHO% "%DOTNET%" %RESTORE_SUBCOMMANDS% "%SOLUTION%"

  IF ERRORLEVEL 1 (
    ECHO Restore failed.
    GOTO errors
  )
)

IF NOT DEFINED NOBUILD (
  %_CECHO% "%MSBUILD%" %BUILD_SUBCOMMANDS% "%SOLUTION%" "/target:%TARGET%" "/property:Configuration=%MSBUILD_CONFIGURATION%" "/property:Platform=%PLATFORM%" %LOGGING% %BUILD_ARGS% %MSBUILD_ARGS% %MSBUILD_ARGS_CFG%
  %__ECHO% "%MSBUILD%" %BUILD_SUBCOMMANDS% "%SOLUTION%" "/target:%TARGET%" "/property:Configuration=%MSBUILD_CONFIGURATION%" "/property:Platform=%PLATFORM%" %LOGGING% %BUILD_ARGS% %MSBUILD_ARGS% %MSBUILD_ARGS_CFG%

  IF ERRORLEVEL 1 (
    ECHO Build failed.
    GOTO errors
  )
) ELSE (
  ECHO WARNING: Build skipped, disabled via NOBUILD environment variable.
)

REM ****************************************************************************
REM **************************** Restore Directory *****************************
REM ****************************************************************************

%__ECHO2% POPD

IF ERRORLEVEL 1 (
  ECHO Could not restore directory.
  GOTO errors
)

REM ****************************************************************************
REM *********************************** Done ***********************************
REM ****************************************************************************

GOTO no_errors

REM ****************************************************************************
REM ****************** Epilogue / Functions / Return Handling ******************
REM ****************************************************************************

:fn_CheckFrameworkDir
  IF DEFINED NOFRAMEWORKDIR GOTO :EOF
  SET FRAMEWORKVER=%1
  %_AECHO% Checking for .NET Framework "%FRAMEWORKVER%"...
  IF NOT DEFINED FRAMEWORKVER GOTO :EOF
  IF DEFINED NOFRAMEWORK64 (
    %_AECHO% Forced into using 32-bit version of MSBuild from Microsoft.NET...
    SET FRAMEWORKDIR=%windir%\Microsoft.NET\Framework\%FRAMEWORKVER%
    CALL :fn_VerifyFrameworkDir
    GOTO :EOF
  )
  IF NOT "%PROCESSOR_ARCHITECTURE%" == "x86" (
    %_AECHO% The operating system appears to be 64-bit.
    IF EXIST "%windir%\Microsoft.NET\Framework64\%FRAMEWORKVER%" (
      IF EXIST "%windir%\Microsoft.NET\Framework64\%FRAMEWORKVER%\%MSBUILD%" (
        IF EXIST "%windir%\Microsoft.NET\Framework64\%FRAMEWORKVER%\%CSC%" (
          %_AECHO% Using 64-bit version of MSBuild from Microsoft.NET...
          SET FRAMEWORKDIR=%windir%\Microsoft.NET\Framework64\%FRAMEWORKVER%
          CALL :fn_VerifyFrameworkDir
          GOTO :EOF
        ) ELSE (
          %_AECHO% Missing 64-bit version of "%CSC%".
        )
      ) ELSE (
        %_AECHO% Missing 64-bit version of "%MSBUILD%".
      )
    ) ELSE (
      %_AECHO% Missing 64-bit version of .NET Framework "%FRAMEWORKVER%".
    )
  ) ELSE (
    %_AECHO% The operating system appears to be 32-bit.
  )
  %_AECHO% Using 32-bit version of MSBuild from Microsoft.NET...
  SET FRAMEWORKDIR=%windir%\Microsoft.NET\Framework\%FRAMEWORKVER%
  CALL :fn_VerifyFrameworkDir
  GOTO :EOF

:fn_VerifyFrameworkDir
  IF DEFINED NOFRAMEWORKDIR GOTO :EOF
  IF NOT DEFINED FRAMEWORKDIR (
    %_AECHO% .NET Framework directory is not defined.
    GOTO :EOF
  )
  IF DEFINED FRAMEWORKDIR IF NOT EXIST "%FRAMEWORKDIR%" (
    %_AECHO% .NET Framework directory does not exist, unsetting...
    CALL :fn_UnsetVariable FRAMEWORKDIR
    GOTO :EOF
  )
  IF DEFINED FRAMEWORKDIR IF NOT EXIST "%FRAMEWORKDIR%\%MSBUILD%" (
    %_AECHO% File "%MSBUILD%" not in .NET Framework directory, unsetting...
    CALL :fn_UnsetVariable FRAMEWORKDIR
    GOTO :EOF
  )
  IF DEFINED FRAMEWORKDIR IF NOT EXIST "%FRAMEWORKDIR%\%CSC%" (
    %_AECHO% File "%CSC%" not in .NET Framework directory, unsetting...
    CALL :fn_UnsetVariable FRAMEWORKDIR
    GOTO :EOF
  )
  %_AECHO% .NET Framework directory "%FRAMEWORKDIR%" verified.
  GOTO :EOF

:fn_CheckMsBuildDir
  IF DEFINED NOMSBUILDDIR GOTO :EOF
  SET MSBUILDVER=%1
  %_AECHO% Checking for MSBuild "%MSBUILDVER%"...
  IF NOT DEFINED MSBUILDVER GOTO :EOF
  IF DEFINED NOMSBUILD64 (
    %_AECHO% Forced into using 32-bit version of MSBuild from Program Files...
    GOTO set_msbuild_x86
  )
  IF "%PROCESSOR_ARCHITECTURE%" == "x86" GOTO set_msbuild_x86
  %_AECHO% The operating system appears to be 64-bit.
  %_AECHO% Using 32-bit version of MSBuild from Program Files...
  SET MSBUILDDIR=%ProgramFiles(x86)%\MSBuild\%MSBUILDVER%\bin
  GOTO set_msbuild_done
  :set_msbuild_x86
  %_AECHO% The operating system appears to be 32-bit.
  %_AECHO% Using native version of MSBuild from Program Files...
  SET MSBUILDDIR=%ProgramFiles%\MSBuild\%MSBUILDVER%\bin
  :set_msbuild_done
  CALL :fn_VerifyMsBuildDir
  GOTO :EOF

:fn_VerifyMsBuildDir
  IF DEFINED NOMSBUILDDIR GOTO :EOF
  IF NOT DEFINED MSBUILDDIR (
    %_AECHO% MSBuild directory is not defined.
    GOTO :EOF
  )
  IF DEFINED MSBUILDDIR IF NOT EXIST "%MSBUILDDIR%" (
    %_AECHO% MSBuild directory does not exist, unsetting...
    CALL :fn_UnsetVariable MSBUILDDIR
    GOTO :EOF
  )
  IF DEFINED MSBUILDDIR IF NOT EXIST "%MSBUILDDIR%\%MSBUILD%" (
    %_AECHO% File "%MSBUILD%" not in MSBuild directory, unsetting...
    CALL :fn_UnsetVariable MSBUILDDIR
    GOTO :EOF
  )
  IF DEFINED MSBUILDDIR IF NOT EXIST "%MSBUILDDIR%\%CSC%" (
    %_AECHO% File "%CSC%" not in MSBuild directory, unsetting...
    CALL :fn_UnsetVariable MSBUILDDIR
    GOTO :EOF
  )
  %_AECHO% MSBuild directory "%MSBUILDDIR%" verified.
  GOTO :EOF

:fn_CheckVisualStudioMsBuildDir
  IF DEFINED NOVISUALSTUDIOMSBUILDDIR GOTO :EOF
  SET MSBUILDVER=%1
  SET VISUALSTUDIOVER=%2
  %_AECHO% Checking for MSBuild "%MSBUILDVER%" within Visual Studio "%VISUALSTUDIOVER%"...
  IF NOT DEFINED MSBUILDVER GOTO :EOF
  IF NOT DEFINED VISUALSTUDIOVER GOTO :EOF
  IF NOT DEFINED VSWHERE_EXE GOTO :EOF
  IF NOT EXIST "%VSWHERE_EXE%" GOTO :EOF
  SET VS_WHEREIS_CMD="%VSWHERE_EXE%" -version %VISUALSTUDIOVER% -products * -requires Microsoft.Component.MSBuild -property installationPath -latest
  IF DEFINED __ECHO (
    %__ECHO% %VS_WHEREIS_CMD%
    SET VISUALSTUDIOINSTALLDIR=C:\Program Files\Microsoft Visual Studio\2017\Community
    GOTO skip_visualStudioInstallDir
  )
  FOR /F "delims=" %%D IN ('%VS_WHEREIS_CMD%') DO (SET VISUALSTUDIOINSTALLDIR=%%D)
  :skip_visualStudioInstallDir
  IF NOT DEFINED VISUALSTUDIOINSTALLDIR (
    %_AECHO% Visual Studio "%VISUALSTUDIOVER%" is not installed.
    GOTO :EOF
  )
  %_AECHO% Visual Studio "%VISUALSTUDIOVER%" is installed.
  SET VISUALSTUDIOMSBUILDDIR=%VISUALSTUDIOINSTALLDIR%\MSBuild\%MSBUILDVER%\bin
  SET VISUALSTUDIOMSBUILDDIR=%VISUALSTUDIOMSBUILDDIR:\\=\%
  CALL :fn_VerifyVisualStudioMsBuildDir
  GOTO :EOF

:fn_VerifyVisualStudioMsBuildDir
  IF DEFINED NOVISUALSTUDIOMSBUILDDIR GOTO :EOF
  IF NOT DEFINED VISUALSTUDIOMSBUILDDIR (
    %_AECHO% Visual Studio directory is not defined.
    GOTO :EOF
  )
  IF DEFINED VISUALSTUDIOMSBUILDDIR IF NOT EXIST "%VISUALSTUDIOMSBUILDDIR%" (
    %_AECHO% Visual Studio directory does not exist, unsetting...
    CALL :fn_UnsetVariable VISUALSTUDIOMSBUILDDIR
    GOTO :EOF
  )
  IF DEFINED VISUALSTUDIOMSBUILDDIR IF NOT EXIST "%VISUALSTUDIOMSBUILDDIR%\%MSBUILD%" (
    %_AECHO% File "%MSBUILD%" not in Visual Studio directory, unsetting...
    CALL :fn_UnsetVariable VISUALSTUDIOMSBUILDDIR
    GOTO :EOF
  )
  IF DEFINED VISUALSTUDIOMSBUILDDIR IF NOT EXIST "%VISUALSTUDIOMSBUILDDIR%\Roslyn\%CSC%" (
    %_AECHO% File "%CSC%" not in Visual Studio directory, unsetting...
    CALL :fn_UnsetVariable VISUALSTUDIOMSBUILDDIR
    GOTO :EOF
  )
  %_AECHO% Visual Studio directory "%VISUALSTUDIOMSBUILDDIR%" verified.
  GOTO :EOF

:fn_CheckBuildToolDir
  %_AECHO% Checking for build tool directories...
  IF DEFINED VISUALSTUDIOMSBUILDDIR GOTO set_visualstudio_msbuild_tools
  IF DEFINED MSBUILDDIR GOTO set_msbuild_tools
  IF DEFINED FRAMEWORKDIR GOTO set_framework_tools
  %_AECHO% No build tool directories found.
  GOTO :EOF
  :set_visualstudio_msbuild_tools
  %_AECHO% Using Visual Studio MSBuild directory "%VISUALSTUDIOMSBUILDDIR%"...
  CALL :fn_CopyVariable VISUALSTUDIOMSBUILDDIR BUILDTOOLDIR
  GOTO :EOF
  :set_msbuild_tools
  %_AECHO% Using MSBuild directory "%MSBUILDDIR%"...
  CALL :fn_CopyVariable MSBUILDDIR BUILDTOOLDIR
  GOTO :EOF
  :set_framework_tools
  %_AECHO% Using .NET Framework directory "%FRAMEWORKDIR%"...
  CALL :fn_CopyVariable FRAMEWORKDIR BUILDTOOLDIR
  GOTO :EOF

:fn_VerifyBuildToolDir
  IF NOT DEFINED BUILDTOOLDIR (
    %_AECHO% Build tool directory is not defined.
    GOTO :EOF
  )
  IF DEFINED BUILDTOOLDIR IF NOT EXIST "%BUILDTOOLDIR%" (
    %_AECHO% Build tool directory does not exist, unsetting...
    CALL :fn_UnsetVariable BUILDTOOLDIR
    GOTO :EOF
  )
  IF DEFINED BUILDTOOLDIR IF NOT EXIST "%BUILDTOOLDIR%\%MSBUILD%" (
    %_AECHO% File "%MSBUILD%" not in build tool directory, unsetting...
    CALL :fn_UnsetVariable BUILDTOOLDIR
    GOTO :EOF
  )
  IF DEFINED BUILDTOOLDIR IF NOT EXIST "%BUILDTOOLDIR%\%CSC%" IF NOT EXIST "%BUILDTOOLDIR%\Roslyn\%CSC%" (
    %_AECHO% File "%CSC%" not in build tool directory, unsetting...
    CALL :fn_UnsetVariable BUILDTOOLDIR
    GOTO :EOF
  )
  %_AECHO% Build tool directory "%BUILDTOOLDIR%" verified.
  GOTO :EOF

:fn_VerifyDotNetCore
  FOR %%T IN (%DOTNET%) DO (
    SET %%T_PATH=%%~dp$PATH:T
  )
  IF NOT DEFINED %DOTNET%_PATH (
    ECHO The .NET Core executable "%DOTNET%" is required to be in the PATH.
    CALL :fn_SetErrorLevel
    GOTO :EOF
  )
  GOTO :EOF

:fn_ForceMsBuildForInteropProject
  %_AECHO% Forcing use of MSBuild for interop project...
  SET CONFIGURATION=%CONFIGURATION:ManagedOnly=NativeOnly%
  IF DEFINED INTEROPYEAR (
    SET YEAR=%INTEROPYEAR%
  ) ELSE (
    REM TODO: Good default for Visual C++?
    SET YEAR=2015
  )
  CALL :fn_UnsetVariable NOBUILDTOOLDIR
  CALL :fn_UnsetVariable USEDOTNET
  GOTO :EOF

:fn_DetectVisualStudioDir
  REM
  REM TODO: When the next version of Visual Studio and/or
  REM       MSBuild is released, this section may need
  REM       updating.
  REM
  IF NOT DEFINED VISUALSTUDIOMSBUILDDIR (
    CALL :fn_CheckVisualStudioMsBuildDir Current 16.0
    IF DEFINED VISUALSTUDIOMSBUILDDIR (
      IF NOT DEFINED YEAR (
        SET YEAR=2017
      )
      IF NOT DEFINED NOUSEPACKAGERESTORE (
        IF NOT DEFINED USEPACKAGERESTORE (
          SET USEPACKAGERESTORE=1
        )
      )
    )
  )
  IF NOT DEFINED VISUALSTUDIOMSBUILDDIR (
    CALL :fn_CheckVisualStudioMsBuildDir 15.0 15.0
    IF DEFINED VISUALSTUDIOMSBUILDDIR (
      IF NOT DEFINED YEAR (
        SET YEAR=2017
      )
      IF NOT DEFINED NOUSEPACKAGERESTORE (
        IF NOT DEFINED USEPACKAGERESTORE (
          SET USEPACKAGERESTORE=1
        )
      )
    )
  )
  GOTO :EOF

:fn_DetectMsBuildDir
  REM
  REM TODO: When the next version of MSBuild is released,
  REM       this section may need updating.
  REM
  IF NOT DEFINED MSBUILDDIR (
    CALL :fn_CheckMsBuildDir 14.0
    IF DEFINED MSBUILDDIR (
      IF NOT DEFINED YEAR (
        SET YEAR=2015
      )
    )
  )
  IF NOT DEFINED MSBUILDDIR (
    CALL :fn_CheckMsBuildDir 12.0
    IF DEFINED MSBUILDDIR (
      IF NOT DEFINED YEAR (
        SET YEAR=2013
      )
    )
  )
  GOTO :EOF

:fn_DetectFrameworkDir
  REM
  REM TODO: When the next version of Visual Studio and/or
  REM       .NET Framework is released, this section may
  REM       need updating.
  REM
  IF NOT DEFINED FRAMEWORKDIR (
    CALL :fn_CheckFrameworkDir v4.0.30319
    IF DEFINED FRAMEWORKDIR (
      IF NOT DEFINED YEAR (
        SET YEAR=2010
      )
    )
  )
  IF NOT DEFINED FRAMEWORKDIR (
    CALL :fn_CheckFrameworkDir v3.5
    IF DEFINED FRAMEWORKDIR (
      IF NOT DEFINED YEAR (
        SET YEAR=2008
      )
    )
  )
  IF NOT DEFINED FRAMEWORKDIR (
    CALL :fn_CheckFrameworkDir v2.0.50727
    IF DEFINED FRAMEWORKDIR (
      IF NOT DEFINED YEAR (
        SET YEAR=2005
      )
    )
  )
  GOTO :EOF

:fn_SetupBuildTool
  %_AECHO% Setting up build tool...
  %_VECHO% NoBuildToolDir = '%NOBUILDTOOLDIR%'
  %_VECHO% UseDotNet = '%USEDOTNET%'
  %_VECHO% UsePackageRestore = '%USEPACKAGERESTORE%'
  IF NOT DEFINED NOBUILDTOOLDIR (
    IF DEFINED BUILDTOOLDIR (
      %_AECHO% Forcing the use of build tool directory "%BUILDTOOLDIR%"...
    ) ELSE (
      CALL :fn_CheckBuildToolDir
      CALL :fn_VerifyBuildToolDir
    )
  )
  %_VECHO% FrameworkDir = '%FRAMEWORKDIR%'
  %_VECHO% MsBuildDir = '%MSBUILDDIR%'
  %_VECHO% VisualStudioMsBuildDir = '%VISUALSTUDIOMSBUILDDIR%'
  %_VECHO% BuildToolDir = '%BUILDTOOLDIR%'
  IF NOT DEFINED NOBUILDTOOLDIR (
    IF NOT DEFINED BUILDTOOLDIR (
      ECHO.
      ECHO No directory containing MSBuild could be found.
      ECHO.
      ECHO Please install the .NET Framework or set the "FRAMEWORKDIR"
      ECHO environment variable to the location where it is installed.
      ECHO.
      CALL :fn_SetErrorLevel
      GOTO :EOF
    )
  )
  IF NOT DEFINED NOBUILDTOOLDIR (
    CALL :fn_PrependToPath BUILDTOOLDIR
  )
  %_VECHO% Path = '%PATH%'
  GOTO :EOF

:fn_SetupSolution
  IF DEFINED SOLUTION (
    %_AECHO% Building the specified project/solution only...
    GOTO :EOF
  )
  IF DEFINED COREONLY (
    %_AECHO% Building core managed project...
    SET SOLUTION=.\System.Data.SQLite\System.Data.SQLite.%YEAR%.csproj
    GOTO :EOF
  )
  IF DEFINED INTEROPONLY (
    IF DEFINED STATICONLY (
      %_AECHO% Building static core interop project...
      FOR /F "delims=" %%F IN ('DIR /B /S ".\SQLite.Interop\SQLite.Interop.Static.%YEAR%.vc*proj" 2^> NUL') DO (
        SET SOLUTION=%%F
      )
      IF NOT DEFINED SOLUTION (
        ECHO Could not locate static core interop project for %YEAR%.
        CALL :fn_SetErrorLevel
      )
      GOTO :EOF
    ) ELSE (
      %_AECHO% Building normal core interop project...
      FOR /F "delims=" %%F IN ('DIR /B /S ".\SQLite.Interop\SQLite.Interop.%YEAR%.vc*proj" 2^> NUL') DO (
        SET SOLUTION=%%F
      )
      IF NOT DEFINED SOLUTION (
        ECHO Could not locate normal core interop project for %YEAR%.
        CALL :fn_SetErrorLevel
      )
      GOTO :EOF
    )
  )
  IF DEFINED BUILD_FULL (
    %_AECHO% Building all projects...
    SET SOLUTION=.\SQLite.NET.%YEAR%.sln
    GOTO :EOF
  )
  %_AECHO% Building all projects...
  SET SOLUTION=.\SQLite.NET.%YEAR%.MSBuild.sln
  GOTO :EOF

:fn_SetupTarget
  IF NOT DEFINED TARGET (
    SET TARGET=Rebuild
  )
  GOTO :EOF

:fn_SetupLogging
  IF NOT DEFINED TEMP (
    ECHO The TEMP environment variable must be set first.
    CALL :fn_SetErrorLevel
    GOTO :EOF
  )
  IF NOT DEFINED LOGASM (
    IF DEFINED USEDOTNET (
      SET LOGASM=Microsoft.Build
    ) ELSE (
      SET LOGASM=Microsoft.Build.Engine
    )
  )
  IF NOT DEFINED LOGDIR (
    SET LOGDIR=%TEMP%
  )
  IF NOT DEFINED LOGPREFIX (
    SET LOGPREFIX=System.Data.SQLite.Build
  )
  IF NOT DEFINED LOGSUFFIX (
    SET LOGSUFFIX=Unknown
  )
  IF DEFINED LOGGING GOTO :EOF
  IF DEFINED NOLOG GOTO :EOF
  SET LOGGING="/logger:FileLogger,%LOGASM%;Logfile=%LOGDIR%\%LOGPREFIX%_%CONFIGURATION%_%PLATFORM%_%YEAR%_%LOGSUFFIX%.log;Verbosity=diagnostic"
  GOTO :EOF

:fn_UnquoteVariable
  IF NOT DEFINED %1 GOTO :EOF
  SETLOCAL
  SET __ECHO_CMD=ECHO %%%1%%
  FOR /F "delims=" %%V IN ('%__ECHO_CMD%') DO (
    SET VALUE=%%V
  )
  SET VALUE=%VALUE:"=%
  REM "
  ENDLOCAL && SET %1=%VALUE%
  GOTO :EOF

:fn_PrependToPath
  IF NOT DEFINED %1 GOTO :EOF
  SETLOCAL
  SET __ECHO_CMD=ECHO %%%1%%
  FOR /F "delims=" %%V IN ('%__ECHO_CMD%') DO (
    SET VALUE=%%V
  )
  SET VALUE=%VALUE:"=%
  REM "
  ENDLOCAL && SET PATH=%VALUE%;%PATH%
  GOTO :EOF

:fn_CopyVariable
  IF NOT DEFINED %1 GOTO :EOF
  IF "%2" == "" GOTO :EOF
  SETLOCAL
  SET __ECHO_CMD=ECHO %%%1%%
  FOR /F "delims=" %%V IN ('%__ECHO_CMD%') DO (
    SET VALUE=%%V
  )
  ENDLOCAL && SET %2=%VALUE%
  GOTO :EOF

:fn_UnsetVariable
  SETLOCAL
  SET VALUE=%1
  IF DEFINED VALUE (
    SET VALUE=
    ENDLOCAL
    SET %VALUE%=
  ) ELSE (
    ENDLOCAL
  )
  CALL :fn_ResetErrorLevel
  GOTO :EOF

:fn_ResetErrorLevel
  VERIFY > NUL
  GOTO :EOF

:fn_SetErrorLevel
  VERIFY MAYBE 2> NUL
  GOTO :EOF

:usage
  ECHO.
  ECHO Usage: %~nx0 [configuration] [platform] [year]
  ECHO.
  GOTO errors

:errors
  CALL :fn_SetErrorLevel
  ENDLOCAL
  ECHO.
  ECHO Build failure, errors were encountered.
  GOTO end_of_file

:no_errors
  CALL :fn_ResetErrorLevel
  ENDLOCAL
  ECHO.
  ECHO Build success, no errors were encountered.
  GOTO end_of_file

:end_of_file
%__ECHO% EXIT /B %ERRORLEVEL%
