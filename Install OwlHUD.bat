@echo off
title OwlHUD installer
setlocal
echo.
echo   OwlHUD installer
echo   ----------------
echo   This copies the OwlHUD folder into your World of Warcraft: Forever
echo   AddOns folder. It does nothing else.
echo.
set "SRC=%~dp0OwlHUD"
if not exist "%SRC%\OwlHUD.toc" (
  echo   I cannot find the OwlHUD folder next to this installer.
  echo   Unzip the whole download first ^(right-click the zip, Extract All^),
  echo   then run this again from the unzipped folder.
  echo.
  if "%~2"=="" pause
  exit /b 1
)
set "WOW="
if not "%~1"=="" set "WOW=%~1"
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
  echo   Nothing was changed. See "How to install" for doing it by hand.
  echo.
  if "%~2"=="" pause
  exit /b 1
)
set "DEST=%WOW%\_forever_\Interface\AddOns\OwlHUD"
echo   Game found:    %WOW%
echo   Installing to: %DEST%
echo.
robocopy "%SRC%" "%DEST%" /E /NFL /NDL /NJH /NJS /NP >nul
if errorlevel 8 (
  echo   Windows would not let me copy the files.
  echo   Right-click "Install OwlHUD" and choose "Run as administrator",
  echo   or copy the OwlHUD folder there by hand.
  echo.
  if "%~2"=="" pause
  exit /b 1
)
echo   Done. Your owl is installed.
echo.
echo   Now close the game completely and start it again ^(a /reload is not
echo   enough the first time^). On the character screen, click AddOns and
echo   check that OwlHUD is ticked. Then log in and meet your owl.
echo.
if "%~2"=="" pause
exit /b 0
