@echo off
REM Pornire Roulette Lab pe Windows. Dublu-click pe acest fisier.
REM Cauta Python in ordinea in care il instaleaza de obicei Windows-ul.
title Roulette Lab
cd /d "%~dp0"

set PYTHON=
for %%C in ("py -3" "python" "python3") do (
    if not defined PYTHON (
        %%~C --version >nul 2>&1 && set "PYTHON=%%~C"
    )
)

if not defined PYTHON (
    echo.
    echo   Nu am gasit Python pe acest calculator.
    echo.
    echo   Instaleaza-l de aici:  https://www.python.org/downloads/
    echo   IMPORTANT: la instalare bifeaza casuta "Add Python to PATH",
    echo   altfel Windows nu il va gasi nici dupa instalare.
    echo.
    echo   Dupa instalare, dai din nou dublu-click pe acest fisier.
    echo.
    pause
    exit /b 1
)

echo.
echo   Pornesc Roulette Lab...
echo   Se deschide singur in browser. Lasa aceasta fereastra deschisa.
echo   Ca sa opresti: inchide fereastra, sau apasa Ctrl+C.
echo.
%PYTHON% -m roulette_lab serve
if errorlevel 1 (
    echo.
    echo   Ceva n-a mers. Mesajul de eroare este mai sus.
    pause
)
