@ECHO OFF

::
:: release.bat --
::
:: Binary Release Tool
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

SET TOOLS=%~dp0
SET TOOLS=%TOOLS:~0,-1%

%_VECHO% Tools = '%TOOLS%'

SET CONFIGURATION=%1

IF DEFINED CONFIGURATION (
  CALL :fn_UnquoteVariable CONFIGURATION
) ELSE (
  %_AECHO% No configuration specified, using default...
  SET CONFIGURATION=Release
)

%_VECHO% Configuration = '%CONFIGURATION%'
%_VECHO% ConfigurationSuffix = '%CONFIGURATIONSUFFIX%'

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
  SET YEAR=2008
)

%_VECHO% Year = '%YEAR%'

SET BASE_CONFIGURATION=%CONFIGURATION%
SET BASE_CONFIGURATION=%BASE_CONFIGURATION:ManagedOnly=%
SET BASE_CONFIGURATION=%BASE_CONFIGURATION:NativeOnly=%
SET BASE_CONFIGURATION=%BASE_CONFIGURATION:Static=%

%_VECHO% BaseConfiguration = '%BASE_CONFIGURATION%'
%_VECHO% BaseConfigurationSuffix = '%BASE_CONFIGURATIONSUFFIX%'

IF NOT DEFINED BASE_PLATFORM (
  CALL :fn_SetVariable BASE_PLATFORM PLATFORM
)

%_VECHO% BasePlatform = '%BASE_PLATFORM%'
%_VECHO% ExtraPlatform = '%EXTRA_PLATFORM%'

IF NOT DEFINED TYPE (
  IF NOT DEFINED NOBUNDLE (
    IF /I "%CONFIGURATION%" == "%BASE_CONFIGURATION%" (
      IF /I "%BASE_CONFIGURATION%" == "Debug" (
        SET TYPE=%TYPE_PREFIX%binary-debug-bundle
      ) ELSE (
        SET TYPE=%TYPE_PREFIX%binary-bundle
      )
    ) ELSE (
      IF /I "%BASE_CONFIGURATION%" == "Debug" (
        SET TYPE=%TYPE_PREFIX%binary-debug
      ) ELSE (
        SET TYPE=%TYPE_PREFIX%binary
      )
    )
  ) ELSE (
    IF /I "%BASE_CONFIGURATION%" == "Debug" (
      SET TYPE=%TYPE_PREFIX%binary-debug
    ) ELSE (
      SET TYPE=%TYPE_PREFIX%binary
    )
  )
)

%_VECHO% Type = '%TYPE%'

CALL :fn_ResetErrorLevel

%__ECHO3% CALL "%TOOLS%\set_common.bat"

IF ERRORLEVEL 1 (
  ECHO Could not set common variables.
  GOTO errors
)

IF NOT DEFINED FRAMEWORK (
  IF DEFINED YEAR (
    CALL :fn_SetVariable FRAMEWORK FRAMEWORK%YEAR%
  ) ELSE (
    SET FRAMEWORK=netFx20
  )
)

%_VECHO% Framework = '%FRAMEWORK%'

SET ROOT=%~dp0\..
SET ROOT=%ROOT:\\=\%

SET TOOLS=%~dp0
SET TOOLS=%TOOLS:~0,-1%

%_VECHO% Root = '%ROOT%'
%_VECHO% Tools = '%TOOLS%'

CALL :fn_ResetErrorLevel

%__ECHO2% PUSHD "%ROOT%"

IF ERRORLEVEL 1 (
  ECHO Could not change directory to "%ROOT%".
  GOTO errors
)

FOR /F "delims=" %%V IN ('TYPE System.Data.SQLite\AssemblyInfo.cs ^| find.exe "AssemblyVersion"') DO (
  SET VERSION=%%V
)

IF NOT DEFINED VERSION (
  SET VERSION=1.0.0.0
  GOTO skip_mungeVersion
)

REM
REM NOTE: Strip off all the extra stuff from the AssemblyVersion line we found
REM       in the AssemblyInfo.cs file that we do not need (i.e. everything
REM       except the raw version number itself).
REM
SET VERSION=%VERSION:(=%
SET VERSION=%VERSION:)=%
SET VERSION=%VERSION:[=%
SET VERSION=%VERSION:]=%
SET VERSION=%VERSION: =%
SET VERSION=%VERSION:assembly:=%
SET VERSION=%VERSION:AssemblyVersion=%
SET VERSION=%VERSION:"=%
REM "

:skip_mungeVersion

%_VECHO% Version = '%VERSION%'

CALL :fn_ResetErrorLevel

IF NOT EXIST Setup\Output (
  %__ECHO% MKDIR Setup\Output

  IF ERRORLEVEL 1 (
    ECHO Could not create directory "Setup\Output".
    GOTO errors
  )
)

SET EXCLUDE_BIN=@data\exclude_bin.txt
SET PREFIX=sqlite

%_VECHO% ExcludeBin = '%EXCLUDE_BIN%'
%_VECHO% Prefix = '%PREFIX%'

IF DEFINED NO_RELEASE_YEAR (
  IF DEFINED NO_RELEASE_PLATFORM (
    SET RELEASE_OUTPUT_FILE=Setup\Output\%PREFIX%-%FRAMEWORK%-%TYPE%-%VERSION%.zip
  ) ELSE (
    SET RELEASE_OUTPUT_FILE=Setup\Output\%PREFIX%-%FRAMEWORK%-%TYPE%-%BASE_PLATFORM%%EXTRA_PLATFORM%-%VERSION%.zip
  )
) ELSE (
  IF DEFINED NO_RELEASE_PLATFORM (
    SET RELEASE_OUTPUT_FILE=Setup\Output\%PREFIX%-%FRAMEWORK%-%TYPE%-%YEAR%-%VERSION%.zip
  ) ELSE (
    SET RELEASE_OUTPUT_FILE=Setup\Output\%PREFIX%-%FRAMEWORK%-%TYPE%-%BASE_PLATFORM%%EXTRA_PLATFORM%-%YEAR%-%VERSION%.zip
  )
)

%_VECHO% ReleaseOutputFile = '%RELEASE_OUTPUT_FILE%'
%_VECHO% ReleaseRmDirSubDir = '%RELEASE_RMDIR_SUBDIR%'
%_VECHO% ReleaseRmDirPlatforms = '%RELEASE_RMDIR_PLATFORMS%'
%_VECHO% ReleaseManagedOnly = '%RELEASE_MANAGEDONLY%'
%_VECHO% NoReleaseInterop = '%NO_RELEASE_INTEROP%'

IF DEFINED BASE_CONFIGURATIONSUFFIX (
  IF NOT DEFINED NO_RELEASE_RMDIR (
    IF DEFINED RELEASE_RMDIR_SUBDIR (
      %_AECHO% Checking for directories under "bin\%YEAR%\%BASE_CONFIGURATION%%BASE_CONFIGURATIONSUFFIX%\bin\%RELEASE_RMDIR_SUBDIR%" for removal...

      IF DEFINED RELEASE_RMDIR_PLATFORMS (
        FOR %%N IN (%RELEASE_RMDIR_PLATFORMS%) DO (
          FOR /F "delims=" %%F IN ('DIR /B /S /AD "bin\%YEAR%\%BASE_CONFIGURATION%%BASE_CONFIGURATIONSUFFIX%\bin\%RELEASE_RMDIR_SUBDIR%" 2^> NUL') DO (
            IF /I "%%~nxF" == "%%N" (
              %_CECHO% RMDIR /S /Q "%%F"
              %__ECHO% RMDIR /S /Q "%%F"
            )
          )
        )
      ) ELSE (
        FOR /F "delims=" %%F IN ('DIR /B /S /AD "bin\%YEAR%\%BASE_CONFIGURATION%%BASE_CONFIGURATIONSUFFIX%\bin\%RELEASE_RMDIR_SUBDIR%" 2^> NUL') DO (
          %_CECHO% RMDIR /S /Q "%%F"
          %__ECHO% RMDIR /S /Q "%%F"
        )
      )
    ) ELSE (
      %_AECHO% Checking for directories under "bin\%YEAR%\%BASE_CONFIGURATION%%BASE_CONFIGURATIONSUFFIX%\bin" for removal...

      FOR /F "delims=" %%F IN ('DIR /B /S /AD "bin\%YEAR%\%BASE_CONFIGURATION%%BASE_CONFIGURATIONSUFFIX%\bin" 2^> NUL') DO (
        %_CECHO% RMDIR /S /Q "%%F"
        %__ECHO% RMDIR /S /Q "%%F"
      )
    )
  )
  IF DEFINED RELEASE_RMDIR_SUBDIR (
    %_CECHO% zip.exe -v -j -r "%RELEASE_OUTPUT_FILE%" "bin\%YEAR%\%BASE_CONFIGURATION%%BASE_CONFIGURATIONSUFFIX%\bin\%RELEASE_RMDIR_SUBDIR%" -x "%EXCLUDE_BIN%"
    %__ECHO% zip.exe -v -j -r "%RELEASE_OUTPUT_FILE%" "bin\%YEAR%\%BASE_CONFIGURATION%%BASE_CONFIGURATIONSUFFIX%\bin\%RELEASE_RMDIR_SUBDIR%" -x "%EXCLUDE_BIN%"
  ) ELSE (
    %_CECHO% zip.exe -v -j -r "%RELEASE_OUTPUT_FILE%" "bin\%YEAR%\%BASE_CONFIGURATION%%BASE_CONFIGURATIONSUFFIX%\bin" -x "%EXCLUDE_BIN%"
    %__ECHO% zip.exe -v -j -r "%RELEASE_OUTPUT_FILE%" "bin\%YEAR%\%BASE_CONFIGURATION%%BASE_CONFIGURATIONSUFFIX%\bin" -x "%EXCLUDE_BIN%"
  )
) ELSE (
  IF NOT DEFINED NO_RELEASE_RMDIR (
    IF DEFINED RELEASE_RMDIR_SUBDIR (
      %_AECHO% Checking for directories under "bin\%YEAR%\%BASE_CONFIGURATION%\bin\%RELEASE_RMDIR_SUBDIR%" for removal...

      IF DEFINED RELEASE_RMDIR_PLATFORMS (
        FOR %%N IN (%RELEASE_RMDIR_PLATFORMS%) DO (
          FOR /F "delims=" %%F IN ('DIR /B /S /AD "bin\%YEAR%\%BASE_CONFIGURATION%\bin\%RELEASE_RMDIR_SUBDIR%" 2^> NUL') DO (
            IF /I "%%~nxF" == "%%N" (
              %_CECHO% RMDIR /S /Q "%%F"
              %__ECHO% RMDIR /S /Q "%%F"
            )
          )
        )
      ) ELSE (
        FOR /F "delims=" %%F IN ('DIR /B /S /AD "bin\%YEAR%\%BASE_CONFIGURATION%\bin\%RELEASE_RMDIR_SUBDIR%" 2^> NUL') DO (
          %_CECHO% RMDIR /S /Q "%%F"
          %__ECHO% RMDIR /S /Q "%%F"
        )
      )
    ) ELSE (
      %_AECHO% Checking for directories under "bin\%YEAR%\%BASE_CONFIGURATION%\bin" for removal...

      FOR /F "delims=" %%F IN ('DIR /B /S /AD "bin\%YEAR%\%BASE_CONFIGURATION%\bin" 2^> NUL') DO (
        %_CECHO% RMDIR /S /Q "%%F"
        %__ECHO% RMDIR /S /Q "%%F"
      )
    )
  )
  IF DEFINED RELEASE_RMDIR_SUBDIR (
    %_CECHO% zip.exe -v -j -r "%RELEASE_OUTPUT_FILE%" "bin\%YEAR%\%BASE_CONFIGURATION%\bin\%RELEASE_RMDIR_SUBDIR%" -x "%EXCLUDE_BIN%"
    %__ECHO% zip.exe -v -j -r "%RELEASE_OUTPUT_FILE%" "bin\%YEAR%\%BASE_CONFIGURATION%\bin\%RELEASE_RMDIR_SUBDIR%" -x "%EXCLUDE_BIN%"
  ) ELSE (
    %_CECHO% zip.exe -v -j -r "%RELEASE_OUTPUT_FILE%" "bin\%YEAR%\%BASE_CONFIGURATION%\bin" -x "%EXCLUDE_BIN%"
    %__ECHO% zip.exe -v -j -r "%RELEASE_OUTPUT_FILE%" "bin\%YEAR%\%BASE_CONFIGURATION%\bin" -x "%EXCLUDE_BIN%"
  )
)

IF DEFINED RELEASE_MANAGEDONLY GOTO skip_releaseInterop

IF /I "%CONFIGURATION%" == "%BASE_CONFIGURATION%" (
  IF NOT DEFINED BASE_CONFIGURATIONSUFFIX (
    %_CECHO% zip.exe -v -d "%RELEASE_OUTPUT_FILE%" SQLite.Interop.*
    %__ECHO% zip.exe -v -d "%RELEASE_OUTPUT_FILE%" SQLite.Interop.*
  )
)

IF DEFINED NO_RELEASE_INTEROP (
  %_CECHO% zip.exe -v -d "%RELEASE_OUTPUT_FILE%" SQLite.Interop.*
  %__ECHO% zip.exe -v -d "%RELEASE_OUTPUT_FILE%" SQLite.Interop.*

  GOTO skip_releaseInterop
)

%_CECHO% zip.exe -v -j -r "%RELEASE_OUTPUT_FILE%" "bin\%YEAR%\%PLATFORM%\%CONFIGURATION%%CONFIGURATIONSUFFIX%" -x "%EXCLUDE_BIN%"
%__ECHO% zip.exe -v -j -r "%RELEASE_OUTPUT_FILE%" "bin\%YEAR%\%PLATFORM%\%CONFIGURATION%%CONFIGURATIONSUFFIX%" -x "%EXCLUDE_BIN%"

:skip_releaseInterop

IF ERRORLEVEL 1 (
  ECHO Failed to archive binary files.
  GOTO errors
)

%__ECHO2% POPD

IF ERRORLEVEL 1 (
  ECHO Could not restore directory.
  GOTO errors
)

GOTO no_errors

:fn_SetVariable
  SETLOCAL
  SET __ECHO_CMD=ECHO %%%2%%
  FOR /F "delims=" %%V IN ('%__ECHO_CMD%') DO (
    SET VALUE=%%V
  )
  ENDLOCAL && (
    SET %1=%VALUE%
  )
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
  ECHO Release failure, errors were encountered.
  GOTO end_of_file

:no_errors
  CALL :fn_ResetErrorLevel
  ENDLOCAL
  ECHO.
  ECHO Release success, no errors were encountered.
  GOTO end_of_file

:end_of_file
%__ECHO% EXIT /B %ERRORLEVEL%
