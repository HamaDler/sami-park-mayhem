@echo off
"C:\Users\7amad\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --editor --path "%~dp0." --import --quit
if errorlevel 1 exit /b %errorlevel%
"C:\Users\7amad\Desktop\Godot_v4.7.1-stable_win64.exe" --path "%~dp0."
