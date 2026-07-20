@echo off
cd /d "%~dp0"
py -3 meta_build_lab.py analyze --candidates 600 --top-event 40 --repetitions 8 --output meta_results
pause
