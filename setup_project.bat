@echo off
setlocal enabledelayedexpansion

rem Bootstrap: _source (via setup_source_folders), Docs/*, DEV_* + UI_BRIEF + ARCHITECTURE templates, first iteration.
rem Usage:
rem   setup_project.bat "D:\Path\To\UnityProject"
rem If PROJECT_ROOT is omitted, script tries current directory first.

set "SKILL_DIR=%~dp0"
for %%I in ("%SKILL_DIR%") do set "SKILL_DIR=%%~fI"
set "PROJECT_ROOT=%~1"
if "%PROJECT_ROOT%"=="" (
  set "PROJECT_ROOT=%CD%"
)
for %%I in ("%PROJECT_ROOT%") do set "PROJECT_ROOT=%%~fI"

set "DOCS=%PROJECT_ROOT%\Docs"
set "TEMPLATES=%SKILL_DIR%templates"

echo [Setup] Root: "%PROJECT_ROOT%"

if not exist "%TEMPLATES%\DEV_STATE.md" (
  echo [ERROR] Templates not found. Run from .cursor\skills\unity-game
  exit /b 1
)

if not exist "%PROJECT_ROOT%\Assets" (
  echo [ERROR] Assets folder not found: "%PROJECT_ROOT%\Assets"
  echo Pass Unity project root explicitly, example:
  echo   setup_project.bat "D:\Git\_Fork\BestHands"
  exit /b 1
)

if not exist "%PROJECT_ROOT%\ProjectSettings" (
  echo [ERROR] ProjectSettings folder not found: "%PROJECT_ROOT%\ProjectSettings"
  echo This does not look like a Unity project root.
  exit /b 1
)

mkdir "%DOCS%" 2>nul
mkdir "%DOCS%\DEV_LOG" 2>nul
mkdir "%DOCS%\Screenshots" 2>nul
mkdir "%DOCS%\Screenshots\iter-01" 2>nul

for %%F in (DEV_CONFIG.md GAME_DESIGN.md DEV_STATE.md DEV_PLAN.md AGENT_MEMORY.md ARCHITECTURE.md UI_BRIEF.md) do (
  if exist "%DOCS%\%%F" (
    echo [SKIP] Docs/%%F already exists
  ) else (
    copy /Y "%TEMPLATES%\%%F" "%DOCS%\%%F" >nul 2>&1
    echo [OK] Docs/%%F
  )
)

for /f "usebackq delims=" %%T in (`powershell -NoProfile -Command "Get-Date -Format 'yyyyMMdd-HHmm'"`) do set "STAMP=%%T"
for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd HH:mm'"`) do set "DATETIME=%%D"
dir /b "%DOCS%\DEV_LOG\iteration-*.md" >nul 2>&1
if errorlevel 1 (
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
) else (
  echo [SKIP] Iteration log already exists in Docs/DEV_LOG
)

call "%SKILL_DIR%setup_source_folders.bat" "%PROJECT_ROOT%"
if errorlevel 1 echo [WARN] setup_source_folders failed.

echo [OK] Bootstrap done. DEV_STATE uses emoji template.
