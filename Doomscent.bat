@echo off
rem Doomscent launcher for Windows.
rem Put gzdoom.exe in .\gzdoom\ (or set GZDOOM=path\to\gzdoom.exe),
rem and your DOOM/DOOM2 WADs plus DESCENT.HOG and DESCENT.PIG in .\data\.
setlocal
set "ROOT=%~dp0"
cd /d "%ROOT%"

set "GZ="
if exist "%ROOT%gzdoom\gzdoom.exe" set "GZ=%ROOT%gzdoom\gzdoom.exe"
if exist "%ROOT%gzdoom.exe" set "GZ=%ROOT%gzdoom.exe"
if defined GZDOOM set "GZ=%GZDOOM%"
if not defined GZ (
    echo Could not find GZDoom. Download it from https://zdoom.org/downloads
    echo and unzip it into "%ROOT%gzdoom\", or set GZDOOM to gzdoom.exe.
    pause
    exit /b 1
)

set "PY="
where py >nul 2>nul && set "PY=py -3"
if not defined PY where python >nul 2>nul && set "PY=python"

if not exist "%ROOT%doomscent.pk3" (
    if not defined PY goto nopython
    %PY% "%ROOT%tools\build_pk3.py" "%ROOT%doomscent.pk3" || goto failed
)

if not exist "%ROOT%dd_descent_assets.pk3" (
    if not exist "%ROOT%data\DESCENT.PIG" (
        echo Put DESCENT.HOG and DESCENT.PIG from your copy of Descent 1
        echo ^(registered or shareware^) into "%ROOT%data\".
        pause
        exit /b 1
    )
    if not defined PY goto nopython
    echo Converting your Descent data...
    %PY% "%ROOT%tools\ddconvert.py" "%ROOT%data" -o "%ROOT%dd_descent_assets.pk3" || goto failed
)

rem Run from data\ so GZDoom finds the IWADs there and offers a choice.
cd /d "%ROOT%data"
"%GZ%" -file "%ROOT%dd_descent_assets.pk3" "%ROOT%doomscent.pk3" %*
exit /b %errorlevel%

:nopython
echo Python 3 is needed once to build the mod and convert the Descent data.
echo Get it from https://www.python.org/downloads/ and run this again.
pause
exit /b 1

:failed
echo Something went wrong; see the messages above.
pause
exit /b 1
