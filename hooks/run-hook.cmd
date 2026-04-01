: # Cross-platform polyglot hook launcher (bash + batch)
: # On Unix: runs as bash. On Windows: batch finds bash and delegates.
:<<"::BATCH"
@echo off
setlocal enabledelayedexpansion

:: Find bash.exe
set "BASH_EXE="
if exist "%ProgramFiles%\Git\bin\bash.exe" (
    set "BASH_EXE=%ProgramFiles%\Git\bin\bash.exe"
) else if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" (
    set "BASH_EXE=%ProgramFiles(x86)%\Git\bin\bash.exe"
) else (
    for %%i in (bash.exe) do set "BASH_EXE=%%~$PATH:i"
)

if not defined BASH_EXE (
    exit /b 0
)

:: Run the named hook script via bash
"%BASH_EXE%" "%~dp0%~1" %2 %3 %4 %5 %6 %7 %8 %9
exit /b %errorlevel%
::BATCH

# Unix path: just exec the named hook
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec bash "${SCRIPT_DIR}/$1" "$@"
