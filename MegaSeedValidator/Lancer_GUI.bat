@echo off
cd /d "%~dp0"
py -3 seed_validator.py gui
if errorlevel 1 pause
