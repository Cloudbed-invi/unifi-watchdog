@echo off
:loop
timeout /t 60 /nobreak >nul
tasklist /FI "IMAGENAME eq chrome.exe" 2>NUL | find /I "chrome.exe" >NUL
if %ERRORLEVEL%==1 (
    powershell -Command "(gc '%LOCALAPPDATA%\Google\Chrome\User Data\Default\Preferences') -replace '\"exit_type\":\"Crashed\"','\"exit_type\":\"Normal\"' | sc '%LOCALAPPDATA%\Google\Chrome\User Data\Default\Preferences'"
    start "" "C:\Program Files\Google\Chrome\Application\chrome.exe" --start-maximized --disable-session-crashed-bubble --disable-infobars --autoplay-policy=no-user-gesture-required "https://unifi.ui.com/consoles/E43883813CFD00000000074D79910000000007A676C70000000063F0EF9E:1419448365/protect/dashboard"
start /min powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\UniFi\unifi-clicker.ps1"
)
goto loop