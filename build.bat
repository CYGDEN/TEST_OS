@echo off
echo === Building Temple OS ===

nasm -f bin os.asm -o os.img
if errorlevel 1 goto fail

powershell -Command "$f=[IO.File]::OpenWrite('os.img');$f.SetLength(1474560);$f.Close()"

echo === BUILD OK ===
echo Run: qemu-system-x86_64 -fda os.img
goto end

:fail
echo === BUILD FAILED ===

:end
pause