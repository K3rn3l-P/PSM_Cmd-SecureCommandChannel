@echo off
REM ============================================================
REM  Build + sign PSMagent.signed.dll (no VS required).
REM  Default output: C:\ShaiyaServer\PSM_Client\PSMagent.signed.dll
REM  To change the path:  Build-PSMagent.bat -OutDir "D:\other\path"
REM ============================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build-PSMagent.ps1" %*
echo.
pause
