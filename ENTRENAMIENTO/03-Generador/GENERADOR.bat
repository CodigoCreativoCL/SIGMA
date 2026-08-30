@echo off
REM ---------------------------------------------------------------------------
REM  Generador de mantenedores - INTERFAZ GRAFICA
REM  Doble clic en este archivo.
REM ---------------------------------------------------------------------------
setlocal
cd /d "%~dp0"

REM pythonw abre la ventana sin consola negra detras.
where pythonw >nul 2>&1
if not errorlevel 1 (
    start "" pythonw interfaz.py
    exit /b 0
)

where python >nul 2>&1
if errorlevel 1 (
    echo.
    echo  ERROR: no se encontro Python en el PATH.
    echo  Instalalo desde https://www.python.org/downloads/
    echo  IMPORTANTE: marca "Add python.exe to PATH" durante la instalacion.
    echo.
    pause
    exit /b 1
)

python interfaz.py
if errorlevel 1 pause
