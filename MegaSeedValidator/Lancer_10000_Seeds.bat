@echo off
cd /d "%~dp0"
py -3 seed_validator.py batch --start 1 --count 10000 --workers 0 --top 100 --render-top 20 --output output\seed_results
pause
