@echo off
cd /d "%~dp0"
py -3 meta_build_lab.py gui
if errorlevel 1 pause
