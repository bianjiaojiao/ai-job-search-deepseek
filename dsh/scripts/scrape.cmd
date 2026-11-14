@echo off
REM ai-job-search - scrape (Windows wrapper)
REM Why: PowerShell execution policy blocks unsigned .ps1 on many machines;
REM this wrapper re-invokes it with -ExecutionPolicy Bypass.
REM Usage: scrape.cmd -Query "machine learning" -Category ml_ai -Remote remote -Limit 10
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scrape.ps1" %*
exit /b %ERRORLEVEL%
