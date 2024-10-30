xcopy "%~dp0PSWindowsUpdate" "C:\Program Files\WindowsPowerShell\Modules\PSWindowsUpdate\" /S /Y /E

Set cmdpowershell=powershell
if defined PROCESSOR_ARCHITEW6432 Set cmdpowershell=%SystemRoot%\sysnative\WindowsPowerShell\v1.0\powershell.exe

 
%cmdpowershell% -noprofile -command "Set-ExecutionPolicy bypass LocalMachine"
%cmdpowershell% -file "%~dp0uninstallKB.ps1"