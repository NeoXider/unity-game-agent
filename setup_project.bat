@echo off
setlocal enabledelayedexpansion

rem Bootstrap: creates Docs/ structure and Assets/_source/ folders for a Unity project.
rem Usage:
rem   setup_project.bat "D:\Path\To\UnityProject"
rem If path is omitted, uses current directory.
rem
rem NOTE: AI agents create these files directly — this script is for manual setup.

set "SKILL_DIR=%~dp0"
for %%I in ("%SKILL_DIR%") do set "SKILL_DIR=%%~fI"
set "PROJECT_ROOT=%~1"
if "%PROJECT_ROOT%"=="" set "PROJECT_ROOT=%CD%"
for %%I in ("%PROJECT_ROOT%") do set "PROJECT_ROOT=%%~fI"

set "DOCS=%PROJECT_ROOT%\Docs"
set "TEMPLATES=%SKILL_DIR%templates"
set "SOURCE=%PROJECT_ROOT%\Assets\_source"

echo [Setup] Project root: "%PROJECT_ROOT%"

rem === Validate ===
if not exist "%TEMPLATES%\DEV_STATE.md" (
  echo [ERROR] Templates not found. Run from skill folder.
  exit /b 1
)
if not exist "%PROJECT_ROOT%\Assets" (
  echo [ERROR] Assets folder not found. Pass Unity project root.
  exit /b 1
)
if not exist "%PROJECT_ROOT%\ProjectSettings" (
  echo [ERROR] Not a Unity project (no ProjectSettings).
  exit /b 1
)

rem === Create Docs/ ===
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

rem === Create DEV_PROFILE.json ===
if not exist "%DOCS%\DEV_PROFILE.json" (
  copy /Y "%TEMPLATES%\DEV_PROFILE.json" "%DOCS%\DEV_PROFILE.json" >nul 2>&1
  echo [OK] Docs/DEV_PROFILE.json
) else (
  echo [SKIP] Docs/DEV_PROFILE.json already exists
)

rem === Create first iteration log ===
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
    echo ## Completed tasks
    echo.
    echo ^> New entries go above.
  ) > "%ITERFILE%"
  echo [OK] First iteration log created
) else (
  echo [SKIP] Iteration log already exists
)

rem === Create Assets/_source/ (only for new projects) ===
if not exist "%SOURCE%" (
  for %%D in (Scripts Editor Data Prefabs Scenes Materials Textures Audio UI Resources) do (
    mkdir "%SOURCE%\%%D" 2>nul
  )
  echo [OK] Assets/_source/ structure created
) else (
  echo [SKIP] Assets/_source/ already exists
)

echo.
echo [DONE] Bootstrap complete.
echo   Docs:    %DOCS%
echo   Source:  %SOURCE%
