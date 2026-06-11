@echo off
title PAPATRON OPTIMIZER
color 0C
cd /d "%~dp0"

REM ===== 1. Cere drepturi de Administrator (necesare pentru antivirus/optimizare) =====
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Cer drepturi de Administrator...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo.
echo  ============================================
echo            PAPATRON OPTIMIZER
echo  ============================================
echo.

REM ===== 2. Verifica daca Python este instalat =====
set "PYTHON_CMD="
where python >nul 2>&1 && set "PYTHON_CMD=python"
if not defined PYTHON_CMD (
    where py >nul 2>&1 && set "PYTHON_CMD=py -3"
)

if not defined PYTHON_CMD (
    echo Python nu este instalat. Il instalez automat cu winget...
    winget install --id Python.Python.3.12 -e --accept-source-agreements --accept-package-agreements
    if %errorlevel% neq 0 (
        echo.
        echo Nu am putut instala Python automat.
        echo Descarca-l manual de aici si bifeaza "Add Python to PATH":
        echo     https://www.python.org/downloads/
        start https://www.python.org/downloads/
        pause
        exit /b 1
    )
    echo Python instalat! Inchide aceasta fereastra si porneste START.bat din nou.
    pause
    exit /b 0
)

REM ===== 3. Instaleaza bibliotecile necesare (doar prima data) =====
echo Verific bibliotecile necesare...
%PYTHON_CMD% -m pip install --quiet --disable-pip-version-check -r requirements.txt
if %errorlevel% neq 0 (
    echo Instalarea bibliotecilor a esuat. Verifica conexiunea la internet.
    pause
    exit /b 1
)

REM ===== 4. Porneste aplicatia =====
echo Pornesc PAPATRON OPTIMIZER...
%PYTHON_CMD% PAPATRON_OPTIMIZER.py
if %errorlevel% neq 0 pause
