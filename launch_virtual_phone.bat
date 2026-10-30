@echo off
title Launching DREAM Virtual Phone...
echo ========================================================
echo   Launching DREAM Virtual Phone (Pixel 5 - Android 15)
echo ========================================================
start "" "C:\Users\LENOVO\AppData\Local\Android\sdk\emulator\emulator.exe" -avd DreamPhone -netdelay none -netspeed full -gpu auto
echo.
echo Virtual Phone is starting in a separate window!
echo You can now run "flutter run" in your terminal.
timeout /t 3 >nul
