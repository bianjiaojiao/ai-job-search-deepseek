@echo off
REM ai-job-search - compile (Windows wrapper)
REM Why: PowerShell execution policy blocks unsigned .ps1 on many machines;
REM this wrapper re-invokes it with -ExecutionPolicy Bypass.
REM Usage: compile.cmd -Tex "cv\main_x.tex" -Engine xelatex -Pages 1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0compile.ps1" %*
exit /b %ERRORLEVEL%
