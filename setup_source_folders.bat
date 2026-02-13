@echo off
setlocal enabledelayedexpansion

rem Creates Assets/_source structure for this repo.
rem This script intentionally does NOT use Unity MCP.
rem Usage:
rem   setup_source_folders.bat "D:\Path\To\UnityProject"
rem If PROJECT_ROOT is omitted, script tries current directory first.

set "PROJECT_ROOT=%~1"

if "%PROJECT_ROOT%"=="" (
  set "PROJECT_ROOT=%CD%"
)

for %%I in ("%PROJECT_ROOT%") do set "PROJECT_ROOT=%%~fI"

set "ASSETS=%PROJECT_ROOT%\Assets"
set "SOURCE=%ASSETS%\_source"

echo Repo root: "%PROJECT_ROOT%"
echo Assets:    "%ASSETS%"
echo _source:   "%SOURCE%"
echo.

if not exist "%ASSETS%" (
  echo [ERROR] Assets folder not found: "%ASSETS%"
  echo Pass Unity project root explicitly, example:
  echo   setup_source_folders.bat "D:\Git\_Fork\BestHands"
  exit /b 1
)

if not exist "%PROJECT_ROOT%\ProjectSettings" (
  echo [ERROR] ProjectSettings folder not found: "%PROJECT_ROOT%\ProjectSettings"
  echo This does not look like a Unity project root.
  exit /b 1
)

mkdir "%SOURCE%" 2>nul

for %%D in (
  "Scripts"
  "Editor"
  "Data"
  "Prefabs"
  "Scenes"
  "Materials"
  "Textures"
  "Audio"
  "UI"
  "Resources"
) do (
  mkdir "%SOURCE%\%%~D" 2>nul
)

rem Convenience folders used by tooling/docs.
mkdir "%ASSETS%\Screenshots" 2>nul
mkdir "%PROJECT_ROOT%\Docs\Screenshots" 2>nul

echo [OK] Created/verified folders.
echo - "%SOURCE%"
echo - "%ASSETS%\Screenshots"
echo - "%PROJECT_ROOT%\Docs\Screenshots"
exit /b 0
