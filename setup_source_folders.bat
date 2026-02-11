@echo off
setlocal enabledelayedexpansion

rem Creates Assets/_source structure for this repo.
rem This script intentionally does NOT use Unity MCP.

set "SKILL_DIR=%~dp0"
set "ROOT=%SKILL_DIR%..\..\.."
for %%I in ("%ROOT%") do set "ROOT=%%~fI"

set "ASSETS=%ROOT%\Assets"
set "SOURCE=%ASSETS%\_source"

echo Repo root: "%ROOT%"
echo Assets:    "%ASSETS%"
echo _source:   "%SOURCE%"
echo.

if not exist "%ASSETS%" (
  echo [ERROR] Assets folder not found: "%ASSETS%"
  echo Open the Unity project at "%ROOT%" and try again.
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
mkdir "%ROOT%\Docs\Screenshots" 2>nul

echo [OK] Created/verified folders.
echo - "%SOURCE%"
echo - "%ASSETS%\Screenshots"
echo - "%ROOT%\Docs\Screenshots"
exit /b 0
