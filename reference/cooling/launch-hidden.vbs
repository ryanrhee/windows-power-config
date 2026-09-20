' Runs a PowerShell script with no console window (Windows Terminal would otherwise pop one).
Set sh = CreateObject("WScript.Shell")
result = sh.Run("powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & WScript.Arguments(0) & """", 0, True)
WScript.Quit result
