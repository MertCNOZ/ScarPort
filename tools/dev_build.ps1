# Developer build: cmake --build out\build\release, then marks SCAR.dll as current so the game does not rebuild its
# code on start. The runtime rebuilds when the DLL's stamp (compiler\work\SCAR\built.txt, written by its own builds)
# names another SCAR.exe, or without a stamp when the DLL is older than the exe; a build that relinks only the exe
# would otherwise cost a 5 minute rebuild in the game.
# Usage: powershell -ExecutionPolicy Bypass -File tools\dev_build.ps1
$root = Split-Path $PSScriptRoot
$out = Join-Path $root "out\build\release"
$log = Join-Path $root "out_build.log"
cmd /c "`"$root\tools\vsenv.bat`" cmake --build out\build\release > `"$log`" 2>&1"
if ($LASTEXITCODE -ne 0) {
    Select-String -Path $log -Pattern "error" | Select-Object -First 20 | ForEach-Object Line
    "BUILD FAILED"
    exit 1
}
Remove-Item -ErrorAction SilentlyContinue (Join-Path $out "compiler\work\SCAR\built.txt")
(Get-Item (Join-Path $out "SCAR.dll")).LastWriteTime = Get-Date
"build ok"
