@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Test-Windows.ps1"
set "TISA_TEST_RESULT=%ERRORLEVEL%"
echo.
pause
exit /b %TISA_TEST_RESULT%
