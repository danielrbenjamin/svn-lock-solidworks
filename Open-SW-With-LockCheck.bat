@echo off
:: Wrapper for Open-SW-With-LockCheck.ps1
:: Works with multiple files dropped onto the .bat

set script=%~dp0Open-SW-With-LockCheck.ps1

:: Build argument list with proper quotes
set args=
:loop
if "%~1"=="" goto run
set args=%args% "%~1"
shift
goto loop

:run
powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File "%script%" %args%
