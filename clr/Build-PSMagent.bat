@echo off
REM ============================================================
REM  Build + firma di PSMagent.signed.dll (niente VS necessario).
REM  Output default: C:\ShaiyaServer\PSM_Client\PSMagent.signed.dll
REM  Per cambiare path:  Build-PSMagent.bat -OutDir "D:\altro\path"
REM ============================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build-PSMagent.ps1" %*
echo.
pause
