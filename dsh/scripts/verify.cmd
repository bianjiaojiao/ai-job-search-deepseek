@echo off
REM ai-job-search - verify (Windows wrapper)
REM Why: PowerShell execution policy blocks unsigned .ps1 on many machines;
REM this wrapper re-invokes it with -ExecutionPolicy Bypass.
REM Usage: verify.cmd -Pdf "cv\main_x.pdf" -Pages 1 -DumpText "cv\main_x.txt"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0verify.ps1" %*
exit /b %ERRORLEVEL%
