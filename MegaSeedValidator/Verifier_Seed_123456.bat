@echo off
cd /d "%~dp0"
py -3 seed_validator.py seed 123456
pause
