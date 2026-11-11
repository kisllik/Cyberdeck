' Night City OS launcher - no console window
Option Explicit
Dim fso, sh, here, cmd
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")
here = fso.GetParentFolderName(WScript.ScriptFullName)
cmd = "powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File " & Chr(34) & here & "\NightCityShell.ps1" & Chr(34) & " -Shell"
sh.Run cmd, 0, False
