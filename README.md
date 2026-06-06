# UniFi Auto-Launcher & Watchdog Setup

> [!NOTE]
> This documentation outlines the setup of an automated watchdog system for displaying a UniFi Protect dashboard on a Windows VM. 

## 🏗️ Architecture

The solution consists of four primary scripts that work together to ensure the UniFi Protect dashboard is always running and maximized.

1. **`unifi-launcher.bat`**: The primary startup script. It forcefully kills any existing Chrome instances, suppresses the "Chrome didn't shut down correctly" bubble, and launches Chrome directly to the UniFi URL. It then triggers the clicker script.
2. **`unifi-clicker.ps1`**: A PowerShell script utilizing `user32.dll` to forcibly bring Chrome to the foreground and simulate a physical mouse click at coordinates `(1270, 1010)` to trigger the fullscreen button in the UniFi UI.
3. **`unifi-watchdog.bat`**: A continuous loop that checks every 60 seconds if `chrome.exe` is running. If Chrome is closed or crashes, it automatically relaunches it using the same logic as the launcher.
4. **`run-watchdog-hidden.vbs`**: A VBScript wrapper whose sole purpose is to launch `unifi-watchdog.bat` entirely in the background without showing an ugly command prompt window.

---

## 🛠️ Code Reference

### 1. `unifi-launcher.bat`
```batch
@echo off
taskkill /IM chrome.exe 2>nul
timeout /t 8 /nobreak >nul
powershell -Command "(gc '%LOCALAPPDATA%\Google\Chrome\User Data\Default\Preferences') -replace '\"exit_type\":\"Crashed\"','\"exit_type\":\"Normal\"' | sc '%LOCALAPPDATA%\Google\Chrome\User Data\Default\Preferences'"
start "" "C:\Program Files\Google\Chrome\Application\chrome.exe" --disable-session-crashed-bubble --disable-infobars --start-maximized --no-first-run --autoplay-policy=no-user-gesture-required "https://unifi.ui.com/consoles/..."
start /min powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\UniFi\unifi-clicker.ps1"
```

### 2. `unifi-clicker.ps1`
```powershell
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinAPI {
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    public const uint MOUSEEVENTF_LEFTUP = 0x0004;
}
"@

Start-Sleep -Seconds 25

# Bring Chrome to foreground first
$chrome = Get-Process chrome -ErrorAction SilentlyContinue | Where-Object {$_.MainWindowHandle -ne 0} | Select-Object -First 1
if ($chrome) {
    [WinAPI]::ShowWindow($chrome.MainWindowHandle, 9)
    [WinAPI]::SetForegroundWindow($chrome.MainWindowHandle)
}

# Wait for Chrome to be in focus
Start-Sleep -Milliseconds 1500

# Now click the fullscreen button
[WinAPI]::SetCursorPos(1270, 1010)
Start-Sleep -Milliseconds 500
[WinAPI]::mouse_event([WinAPI]::MOUSEEVENTF_LEFTDOWN, 0, 0, 0, [UIntPtr]::Zero)
[WinAPI]::mouse_event([WinAPI]::MOUSEEVENTF_LEFTUP, 0, 0, 0, [UIntPtr]::Zero)
```

### 3. `unifi-watchdog.bat`
```batch
@echo off
:loop
timeout /t 60 /nobreak >nul
tasklist /FI "IMAGENAME eq chrome.exe" 2>NUL | find /I "chrome.exe" >NUL
if %ERRORLEVEL%==1 (
    powershell -Command "(gc '%LOCALAPPDATA%\Google\Chrome\User Data\Default\Preferences') -replace '\"exit_type\":\"Crashed\"','\"exit_type\":\"Normal\"' | sc '%LOCALAPPDATA%\Google\Chrome\User Data\Default\Preferences'"
    start "" "C:\Program Files\Google\Chrome\Application\chrome.exe" --start-maximized --disable-session-crashed-bubble --disable-infobars --autoplay-policy=no-user-gesture-required "https://unifi.ui.com/consoles/..."
start /min powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\UniFi\unifi-clicker.ps1"
)
goto loop
```

### 4. `run-watchdog-hidden.vbs`
```vbs
CreateObject("Wscript.Shell").Run "C:\UniFi\unifi-watchdog.bat", 0, False
```

---

## ⚠️ Robustness Analysis & Flaws

While this solution functions well under ideal conditions, there are several edge cases where it will fail.

> [!WARNING]
> **Hardcoded Coordinates are Brittle**  
> The `unifi-clicker.ps1` script moves the mouse to exact coordinates `(1270, 1010)`. If the VM's display resolution changes, Windows UI scaling is adjusted, or the UniFi UI updates and moves the fullscreen button slightly, the script will click on nothing (or worse, the wrong thing).

> [!CAUTION]
> **Popups & Session Expiration**  
> If UniFi shows a "Session Expired" popup, an update notification, or requires a login, Chrome will *still be running*. Because `chrome.exe` is active, the `unifi-watchdog.bat` will assume everything is fine and take no action, leaving a broken screen. 

> [!CAUTION]
> **Focus Stealing**  
> If an administrator is actively RDP'd into the VM troubleshooting something else, `unifi-clicker.ps1` will force Chrome into the foreground every time it runs, yanking control away from the user.