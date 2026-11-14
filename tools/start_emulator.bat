@echo off
REM Launches Android emulator with explicit Google DNS to avoid host adapter DNS resolution failures
echo Starting Android Emulator (Medium_Phone) with Google DNS (8.8.8.8, 1.1.1.1)...
"C:\Users\Acer\AppData\Local\Android\Sdk\emulator\emulator.exe" -avd Medium_Phone -dns-server 8.8.8.8,1.1.1.1 -netdelay none -netspeed full -no-snapstorage
