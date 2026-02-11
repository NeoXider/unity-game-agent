@echo off
rem Wrapper for dev_complete_task.ps1. Example: dev_complete_task.bat -TaskTitle "Main menu" -Description "Done" -ProgressProject "2/10"
set "SCRIPT_DIR=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%dev_complete_task.ps1" %*
