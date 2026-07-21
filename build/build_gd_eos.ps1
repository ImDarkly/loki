<#
.SYNOPSIS
    Builds the GD-EOS GDExtension for Windows x86_64.
.DESCRIPTION
    1. Verifies prerequisites (MSVC, Python, SCons, EOS SDK)
    2. Creates the thirdparty junction for GD-EOS
    3. Initializes godot-cpp submodule
    4. Compiles template_debug + template_release
    5. Copies output to addons/gd-eos/
    6. Cleans build artifacts from the submodule
#>

$ErrorActionPreference = "Stop"

# Warn if Godot is running (will lock DLLs during copy).
$godotProcs = Get-Process -Name "godot*" -ErrorAction SilentlyContinue
if ($godotProcs) {
    Write-Host ""
    Write-Host "WARNING: Godot is running. Close it before building to avoid locked DLLs." -ForegroundColor Yellow
    Write-Host "         If build succeeds, the copy step may fail for some files." -ForegroundColor Yellow
    Write-Host ""
}
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$GdEosDir = Join-Path $ProjectRoot "build\gd-eos"
$AddonDir = Join-Path $ProjectRoot "addons\gd-eos"
$EosSdkDir = Join-Path $ProjectRoot "thirdparty\eos-sdk"

function Step($msg) {
    Write-Host "==> $msg" -ForegroundColor Cyan
}

function Pass($msg) {
    Write-Host "    OK  $msg" -ForegroundColor Green
}

function Fail($msg) {
    Write-Host "    FAIL  $msg" -ForegroundColor Red
    exit 1
}

# --- Prerequisites ---

Step "Checking prerequisites"

$vswhere = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) {
    Fail "Visual Studio BuildTools not found. Install from: https://aka.ms/vs/17/release/vs_BuildTools.exe"
}
$vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
if (-not $vsPath) {
    Fail "C++ workload not found. Run Visual Studio Installer and add 'Desktop development with C++'."
}
$vcvars = Join-Path $vsPath "VC\Auxiliary\Build\vcvarsall.bat"
if (-not (Test-Path $vcvars)) {
    Fail "vcvarsall.bat not found at $vcvars"
}
Pass "MSVC: $vsPath"

$python = "python"
$scons = "python -m SCons"
& $python -c "import SCons; print(SCons.__version__)" 2>$null
if ($LASTEXITCODE -ne 0) {
    Fail "SCons not found. Install with: pip install SCons"
}
Pass "SCons available"

if (-not (Test-Path (Join-Path $EosSdkDir "SDK\Include\eos_version.h"))) {
    Fail "EOS SDK not found at $EosSdkDir. Download from Epic Dev Portal and extract to thirdparty/eos-sdk/"
}
Pass "EOS SDK: $EosSdkDir"

if (-not (Test-Path (Join-Path $GdEosDir "SConstruct"))) {
    Fail "GD-EOS submodule not found at $GdEosDir. Run: git submodule update --init"
}
Pass "GD-EOS submodule: $GdEosDir"

# --- Junction ---

Step "Setting up EOS SDK junction for GD-EOS build"
$junctionTarget = Join-Path $GdEosDir "thirdparty\eos-sdk"
if (-not (Test-Path $junctionTarget)) {
    New-Item -ItemType Directory -Path (Join-Path $GdEosDir "thirdparty") -Force | Out-Null
    New-Item -ItemType Junction -Path $junctionTarget -Target $EosSdkDir | Out-Null
    Pass "Created junction: $junctionTarget -> $EosSdkDir"
} else {
    Pass "Junction already exists"
}

# --- Init godot-cpp ---

Step "Initializing godot-cpp submodule"
& git -C $GdEosDir submodule update --init --depth 1 godot-cpp 2>&1
if ($LASTEXITCODE -ne 0) { Fail "godot-cpp init failed" }
Pass "godot-cpp initialized"

# --- Build ---

$buildArgs = @("platform=windows", "arch=x64", "-Q")
$sconsCmd = "python -m SCons $($buildArgs -join ' ')"
Step "Building template_debug"
$null = & cmd /c "`"$vcvars`" x64 >nul 2>nul && cd /d `"$GdEosDir`" && $sconsCmd target=template_debug"
if ($LASTEXITCODE -ne 0) { Fail "template_debug build failed" }
Pass "template_debug built"

Step "Building template_release"
$null = & cmd /c "`"$vcvars`" x64 >nul 2>nul && cd /d `"$GdEosDir`" && $sconsCmd target=template_release"
if ($LASTEXITCODE -ne 0) { Fail "template_release build failed" }
Pass "template_release built"

# --- Copy output ---

Step "Copying compiled addon to $AddonDir"
if (-not (Test-Path $AddonDir)) {
    New-Item -ItemType Directory -Path $AddonDir -Force | Out-Null
}
$buildOutput = Join-Path $GdEosDir "demo\addons\gd-eos"
$copyFailed = $false
$retries = 3
for ($i = 0; $i -lt $retries; $i++) {
    try {
        Copy-Item -Path "$buildOutput\*" -Destination $AddonDir -Recurse -Force -ErrorAction Stop
        $copyFailed = $false
        break
    } catch {
        $copyFailed = $true
        if ($i -lt $retries - 1) {
            Start-Sleep -Seconds 2
        }
    }
}
if ($copyFailed) {
    Write-Host "    WARN  Could not copy all files. Close Godot and re-run, or copy manually:" -ForegroundColor Yellow
    Write-Host "           Copy-Item '$buildOutput\*' '$AddonDir' -Recurse -Force" -ForegroundColor Yellow
} else {
    Pass "Addon output copied"
}

# --- Clean submodule ---

Step "Cleaning build artifacts from submodule"
& git -C $GdEosDir checkout -- demo/addons/gd-eos/gd-eos.gdextension 2>$null
& git -C $GdEosDir clean -fd 2>&1 | Out-Null
Pass "Submodule restored to clean state"

Write-Host ""
Write-Host "Done! GD-EOS is ready at addons/gd-eos/" -ForegroundColor Green
