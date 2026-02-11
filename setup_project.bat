@echo off
setlocal enabledelayedexpansion

rem Bootstrap: _source (via setup_source_folders), Docs/*, DEV_* + UI_BRIEF + ARCHITECTURE templates, first iteration.
rem Run from skill folder; ROOT = 3 levels up.

set "SKILL_DIR=%~dp0"
for %%I in ("%SKILL_DIR%") do set "SKILL_DIR=%%~fI"
set "ROOT=%SKILL_DIR%..\..\.."
for %%I in ("%ROOT%") do set "ROOT=%%~fI"
set "DOCS=%ROOT%\Docs"
set "TEMPLATES=%SKILL_DIR%templates"

echo [Setup] Root: "%ROOT%"

if not exist "%TEMPLATES%\DEV_STATE.md" (
  echo [ERROR] Templates not found. Run from .cursor\skills\unity-game-agent
  exit /b 1
)

mkdir "%DOCS%" 2>nul
mkdir "%DOCS%\DEV_LOG" 2>nul
mkdir "%DOCS%\Screenshots" 2>nul
mkdir "%DOCS%\Screenshots\iter-01" 2>nul

for %%F in (DEV_CONFIG.md GAME_DESIGN.md DEV_STATE.md DEV_PLAN.md AGENT_MEMORY.md ARCHITECTURE.md UI_BRIEF.md) do (
  copy /Y "%TEMPLATES%\%%F" "%DOCS%\%%F" >nul 2>&1
  echo [OK] Docs/%%F
)

for /f "usebackq delims=" %%T in (`powershell -NoProfile -Command "Get-Date -Format 'yyyyMMdd-HHmm'"`) do set "STAMP=%%T"
for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd HH:mm'"`) do set "DATETIME=%%D"
set "ITERFILE=%DOCS%\DEV_LOG\iteration-01-%STAMP%.md"
(
  echo # Iteration 01
  echo.
  echo **Started:** %DATETIME%
  echo **Finished:** in progress
  echo.
  echo ---
  echo.
  echo ## Iteration summary
  echo.
  echo [2-3 sentences: what was done, key results.]
  echo.
  echo ---
  echo.
  echo ## Completed tasks
  echo.
  echo ^> New entries go above.
) > "%ITERFILE%"
echo [OK] %ITERFILE%

call "%SKILL_DIR%setup_source_folders.bat"
if errorlevel 1 echo [WARN] setup_source_folders failed.

echo [OK] Bootstrap done. DEV_STATE uses emoji template.
