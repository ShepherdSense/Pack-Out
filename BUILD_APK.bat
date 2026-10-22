@echo off
title Build Pack Out APK
cd /d "%~dp0"
echo [Pack Out build v8: item photos, either camera, Shepherd banner]
echo Building from: %CD%

rem --- Self-check: this folder must carry the CameraX 1.4.1 pin. If this
rem --- fires, the build is running from an old copy of the project and
rem --- would fail the same way as before, so stop and say so.
findstr /C:"camera_android_camerax: 0.6.17" pubspec.yaml >nul 2>nul
if errorlevel 1 (
  echo.
  echo STOP: this folder does NOT have the fix in it - it is an old copy
  echo of the project. Close this, find the newest unzipped folder
  echo ^(PackOut-v8^), and run BUILD_APK.bat from there.
  echo.
  pause
  exit /b 1
)

rem --- Find Flutter (PATH first, then the usual spots) ---
where flutter >nul 2>nul && set FLUTTER=flutter && goto found
if exist "%USERPROFILE%\flutter\bin\flutter.bat" set FLUTTER="%USERPROFILE%\flutter\bin\flutter.bat" && goto found
if exist "C:\flutter\bin\flutter.bat" set FLUTTER="C:\flutter\bin\flutter.bat" && goto found
if exist "%USERPROFILE%\Documents\flutter\bin\flutter.bat" set FLUTTER="%USERPROFILE%\Documents\flutter\bin\flutter.bat" && goto found
echo Flutter was not found on this PC.
echo Shepherd builds use Flutter on this machine - if it lives somewhere else,
echo edit BUILD_APK.bat and point FLUTTER at flutter.bat, then run again.
pause
exit /b 1

:found
echo Resolving dependencies...
call %FLUTTER% pub get
if errorlevel 1 goto fail

rem --- Verify what ACTUALLY resolved. The broken builds all came from
rem --- CameraX 1.5.3 sneaking back in; if the pin is not in effect, stop
rem --- NOW instead of burning minutes on a build that cannot succeed.
call %FLUTTER% pub deps --style=compact > "%TEMP%\equip-deps.txt" 2>nul
findstr /C:"camera_android_camerax" "%TEMP%\equip-deps.txt"
findstr /C:"camera_android_camerax 0.6.17" "%TEMP%\equip-deps.txt" >nul 2>nul
if errorlevel 1 (
  echo.
  echo STOP: the camera plugin did NOT resolve to the pinned version above.
  echo Do not keep rebuilding - send Spark the lines above plus this block.
  echo Building from: %CD%
  echo.
  pause
  exit /b 1
)
echo Camera pin confirmed: camera_android_camerax 0.6.17 = CameraX 1.4.1

echo Building the Pack Out APK...
call %FLUTTER% build apk --release
if errorlevel 1 goto fail

copy /Y "build\app\outputs\flutter-apk\app-release.apk" "PackOut.apk" >nul
echo.
echo DONE: PackOut.apk is in this folder.
echo Copy it to the Samsung Tab S6 Lite and tap it to install.
echo It installs as an UPDATE over the current app - registry, roster,
echo log, photos and your staff PIN all carry over.
echo.
echo Built from: %CD%
findstr /C:"camera_android_camerax" "%TEMP%\equip-deps.txt"
pause
exit /b 0

:fail
echo.
echo The build failed - the messages above say why. Nothing was copied.
echo Built from: %CD%
findstr /C:"camera_android_camerax" "%TEMP%\equip-deps.txt"
pause
exit /b 1
