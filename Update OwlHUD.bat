@echo off
title OwlHUD updater
setlocal
echo.
echo   OwlHUD updater
echo   --------------
echo   This downloads the newest OwlHUD from GitHub and copies it into your
echo   World of Warcraft: Forever AddOns folder. It does nothing else.
echo.
set "URL=https://github.com/christianbeard75-blip/OwlHUD/archive/refs/heads/main.zip"
set "WORK=%TEMP%\OwlHUD-update"
set "KEEP=%APPDATA%\OwlHUD-wow-folder.txt"
set "WOW="
if not "%~1"=="" set "WOW=%~1"
if not defined WOW if exist "%KEEP%" set /p WOW=<"%KEEP%"
if defined WOW set "WOW=%WOW:"=%"
if defined WOW if not exist "%WOW%\_forever_\" set "WOW="
if not defined WOW for %%P in ("C:\Program Files (x86)\World of Warcraft" "C:\Program Files\World of Warcraft" "C:\World of Warcraft" "C:\Games\World of Warcraft" "D:\World of Warcraft" "D:\Games\World of Warcraft" "D:\Program Files (x86)\World of Warcraft" "E:\World of Warcraft" "E:\Games\World of Warcraft") do (
  if not defined WOW if exist "%%~P\_forever_\" set "WOW=%%~P"
)
if not defined WOW (
  echo   I could not find the game in the usual places.
  echo   Open the Battle.net app, pick the game, click the cog next to Play
  echo   and choose "Show in Explorer". Then copy the address of the
  echo   "World of Warcraft" folder and paste it here.
  echo.
  set /p "WOW=  World of Warcraft folder: "
)
set "WOW=%WOW:"=%"
if not exist "%WOW%\_forever_\" (
  echo.
  echo   There is no _forever_ folder inside "%WOW%".
  echo   Nothing was changed.
  echo.
  if "%~2"=="" pause
  exit /b 1
)
set "DEST=%WOW%\_forever_\Interface\AddOns\OwlHUD"
echo   Game found:  %WOW%
echo.
echo   Downloading the newest OwlHUD...
if exist "%WORK%" rmdir /s /q "%WORK%"
mkdir "%WORK%"
curl -L -s -S -f -o "%WORK%\owlhud.zip" "%URL%"
if errorlevel 1 (
  echo.
  echo   The download did not work. Check your internet connection and try
  echo   again. Nothing was changed.
  echo.
  if "%~2"=="" pause
  exit /b 1
)
tar -xf "%WORK%\owlhud.zip" -C "%WORK%"
set "TOP="
for /d %%D in ("%WORK%\*") do if exist "%%~D\OwlHUD\OwlHUD.toc" set "TOP=%%~D"
if not defined TOP (
  echo.
  echo   The download arrived but I could not open it. Nothing was changed.
  echo.
  if "%~2"=="" pause
  exit /b 1
)
robocopy "%TOP%\OwlHUD" "%DEST%" /E /NFL /NDL /NJH /NJS /NP >nul
if errorlevel 8 (
  echo.
  echo   Windows would not let me copy the files.
  echo   Right-click "Update OwlHUD" and choose "Run as administrator".
  echo.
  if "%~2"=="" pause
  exit /b 1
)
>"%KEEP%" echo %WOW%
set "VER="
for /f "tokens=3" %%V in ('findstr /B /C:"## Version:" "%DEST%\OwlHUD.toc"') do set "VER=%%V"
rmdir /s /q "%WORK%"
echo.
echo   Done. OwlHUD %VER% is installed.
echo.
echo   If the game is open, type  /reload  in chat.
echo   If your owl looks wrong after that, close the game completely and
echo   start it again ^(needed only when an update adds new pictures^).
echo.
if "%~2"=="" pause
exit /b 0
