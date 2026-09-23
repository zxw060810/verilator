# Job D: official Windows build chain, end to end.
#   ci-win-compile.ps1 has already produced ./install (MSVC-built Verilator with the patch).
#   Here: verilate the combo TB with that Verilator, build the model with cl, run + assert.
param(
  [string]$InstallRoot = "",   # defaults to <workspace>\install
  [string]$WorkDir     = $PWD.Path
)
$ErrorActionPreference = "Continue"
$base = $env:PATH
if ($InstallRoot -eq "") { $InstallRoot = Join-Path $WorkDir "install" }
$instFwd = ($InstallRoot -replace "\\","/")
function Die($m) { Write-Output "FATAL: $m"; exit 1 }

Write-Output "=== D0: locate install tree ==="
if (-not (Test-Path "$InstallRoot\bin")) { Die "no $InstallRoot\bin (ci-win-compile.ps1 not run?)" }
Get-ChildItem "$InstallRoot\bin" -Name | ForEach-Object { "  bin/$_" }
# runtime include: cmake install layout can be install/include or install/share/verilator/include
$rtInc = Join-Path $InstallRoot "include"
if (-not (Test-Path "$rtInc\verilated_random.cpp")) {
  $rtInc = Join-Path $InstallRoot "share\verilator\include"
}
if (-not (Test-Path "$rtInc\verilated_random.cpp")) { Die "verilated_random.cpp not found under install" }
Write-Output "  runtime include: $rtInc"
Select-String -Path "$rtInc\verilated_random.cpp" -Pattern "_VL_SOLVER_PIPE_WIN" -Quiet | Out-Null
$patched = Select-String -Path "$rtInc\verilated_random.cpp" -Pattern "_VL_SOLVER_PIPE_WIN" -Quiet
Write-Output "  patched runtime present: $patched"

Write-Output "=== D1: enter MSVC dev shell ==="
$VsPath = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -property installationPath
Import-Module "$VsPath\Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
Enter-VsDevShell -VsInstallPath $VsPath -SkipAutomaticLocation -DevCmdArguments "-arch=x64 -host_arch=x64" | Out-Null

Write-Output "=== D2: verilate combo TB with the MSVC-built Verilator ==="
$env:VERILATOR_ROOT = $instFwd
$objD = "ci_win32/obj_d"
& "$InstallRoot\bin\verilator.exe" --cc --exe --Mdir $objD -CFLAGS "/O2 /EHsc /std:c++17" --top-module tb_rand_combos ci_win32/tb_rand_combos.sv *> "$WorkDir\ci_win32\log_d2_verilate.txt"
Write-Output "  verilate exit=$LASTEXITCODE"
if (-not (Test-Path "$WorkDir\$objD\Vtb_rand_combos.mk")) { Die "mk not generated (see ci_win32/log_d2_verilate.txt)" }

Write-Output "=== D3: build model with cl (official chain runtime; all generated sources + our main) ==="
$objDAbs = "$WorkDir\$objD"
$srcs = @(Get-ChildItem "$objDAbs" -Filter "*.cpp" | ForEach-Object { $_.FullName })
$srcs += @(
  "$rtInc\verilated.cpp",
  "$rtInc\verilated_random.cpp",
  "$rtInc\verilated_threads.cpp",
  "$rtInc\verilated_timing.cpp",
  "$WorkDir\ci_win32\main_d.cpp"
)
if ($srcs.Count -lt 10) { Die "unexpectedly few sources ($($srcs.Count))" }
foreach ($s in $srcs) { if (-not (Test-Path $s)) { Die "missing src $s" } }
Write-Output "  compiling $($srcs.Count) sources with cl"
cl /nologo /EHsc /std:c++17 /O2 /W3 /Fe:ci_win32\Vtb_rand_combos_official.exe "-I$rtInc" "-I$objDAbs" @srcs *> "$WorkDir\ci_win32\log_d3_build.txt"
if ($LASTEXITCODE -ne 0) { Die "cl build failed (see ci_win32/log_d3_build.txt)" }

Write-Output "=== D4: run combo TB (official-chain build; z3 from PATH via choco) ==="
& "$WorkDir\ci_win32\Vtb_rand_combos_official.exe" *> "$WorkDir\ci_win32\log_d4_run.txt"
Write-Output "  run exit=$LASTEXITCODE"
& "$WorkDir\ci_win32\check.ps1" -Log "$WorkDir\ci_win32\log_d4_run.txt" -Expected 11 -Label official
if ($LASTEXITCODE -ne 0) { Die "combo TB check failed on official-chain build" }

Write-Output "=== D: ALL GREEN (official MSVC Verilator -> patched runtime -> 11 combos) ==="
exit 0
