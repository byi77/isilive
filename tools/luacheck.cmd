@echo off
setlocal

set "LUACHECK_SCRIPT=%APPDATA%\luarocks\bin\luacheck"
if not exist "%LUACHECK_SCRIPT%" (
  echo luacheck shim could not find LuaRocks script at "%LUACHECK_SCRIPT%" 1>&2
  exit /b 1
)

lua "%LUACHECK_SCRIPT%" %*
exit /b %ERRORLEVEL%
