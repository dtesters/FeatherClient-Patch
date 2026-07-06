@echo off
title Patch Feather - keep Feather, block Dawn
echo Starting the Feather patcher...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0patch-feather.ps1"
if errorlevel 1 (
  echo.
  echo The patcher reported a problem. See the messages above.
  pause
)
