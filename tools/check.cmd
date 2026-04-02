@echo off
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0check.ps1" %*
exit /b %ERRORLEVEL%
