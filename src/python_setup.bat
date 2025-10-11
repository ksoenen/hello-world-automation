@echo off
setlocal

set "LOG_FILE=C:\Data\Temp\python_setup_log.txt"

echo Checking Python setup and saving to %LOG_FILE%...

> "%LOG_FILE%" echo --- Python Version ---
python --version >> "%LOG_FILE%" 2>&1

>> "%LOG_FILE%" echo. 
>> "%LOG_FILE%" echo --- Pip Version ---
pip --version >> "%LOG_FILE%" 2>&1

>> "%LOG_FILE%" echo. 
>> "%LOG_FILE%" echo --- Installed Packages (pip list) ---
pip list >> "%LOG_FILE%" 2>&1

>> "%LOG_FILE%" echo. 
>> "%LOG_FILE%" echo --- Dependency Check (pip check) ---
pip check >> "%LOG_FILE%" 2>&1

echo Done! Open %LOG_FILE% in Notepad, copy the contents, and paste them back to me in the chat.
pause
endlocal