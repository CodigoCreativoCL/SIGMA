@echo off
REM ---------------------------------------------------------------------------
REM  Lanzador del generador de mantenedores.
REM
REM    generar.bat                          -> abre el asistente interactivo
REM    generar.bat ejemplos\producto.json   -> genera desde una definicion
REM    generar.bat mi.json --forzar         -> sobreescribe lo que ya existe
REM ---------------------------------------------------------------------------
setlocal
cd /d "%~dp0"

where python >nul 2>&1
if errorlevel 1 (
    echo.
    echo  ERROR: no se encontro "python" en el PATH.
    echo  Instala Python 3 desde https://www.python.org/downloads/
    echo.
    pause
    exit /b 1
)

if "%~1"=="" (
    python generar.py --asistente
) else (
    python generar.py --definicion %*
)

echo.
pause
