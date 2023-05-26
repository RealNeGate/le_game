@echo off
git submodule update --init --recursive

:: Download cuik DLL
if not exist cuik.zip (
	curl -L https://github.com/RealNeGate/Cuik/releases/download/latest/cuik-windows.zip --output cuik.zip
	tar -xf cuik.zip
	copy cuik-windows\cuik.dll cuik.dll
)

:: Build LuaJIT
if not exist luajit/src/luajit.exe (
	cd luajit/src
	msvcbuild.bat
	cd ../..
)

:: Run game
luajit\src\luajit.exe main.lua
