@echo off
cd /d "%~dp0"
py -3 meta_build_lab.py analyze --candidates 120 --top-event 12 --repetitions 3 --output test_results
pause
