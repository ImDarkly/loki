# Deploy the Windows release build to itch.io via butler.
# Usage: powershell -ExecutionPolicy Bypass -File scripts/deploy-to-itch.ps1
# Prereqs (one-time, interactive): install butler and run `butler login` once.
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Godot = "C:\Godot\Godot_v4.6.2-stable_win64.exe"
$Preset = "Windows Desktop"
$ItchTarget = "baby-came-home/chum-demo:windows"
$CredsFile = Join-Path $RepoRoot "eos_credentials.cfg"
$StageDir = Join-Path $RepoRoot "build\itch\windows"
$ExeName = "Chum!.exe"


function Resolve-Version {
	$tag = git describe --tags --always --dirty 2>$null
	if ($LASTEXITCODE -eq 0 -and $tag -and $tag -notmatch '^[0-9a-f]{7,}$') {
		return $tag
	}
	if (Test-Path $CredsFile) {
		$content = Get-Content $CredsFile -Raw
		if ($content -match 'PRODUCT_VERSION="([^"]+)"') {
			return $matches[1]
		}
	}
	return "dev"
}


function Assert-Butler {
	$cmd = Get-Command butler -ErrorAction SilentlyContinue
	if (-not $cmd) {
		Write-Error "butler not found on PATH. Install from https://itch.io/docs/butler/installing.html then run 'butler login' once."
	}
}


$version = Resolve-Version
Write-Host "Deploying version '$version' to $ItchTarget"

Assert-Butler
if (-not (Test-Path $Godot)) {
	Write-Error "Godot not found at $Godot"
}
if (-not (Test-Path $CredsFile)) {
	Write-Error "eos_credentials.cfg not found at $CredsFile - the shipped build needs it for EOS networking."
}

if (Test-Path $StageDir) {
	Remove-Item -Recurse -Force $StageDir
}
New-Item -ItemType Directory -Force -Path $StageDir | Out-Null

Write-Host "Exporting '$Preset' to $StageDir..."
& $Godot --headless --path $RepoRoot --export-release $Preset (Join-Path $StageDir $ExeName)
if ($LASTEXITCODE -ne 0) {
	Write-Error "Export failed with exit code $LASTEXITCODE"
}

$ExpectedFiles = @($ExeName, "EOSSDK-Win64-Shipping.dll", "libeosg.windows.template_release.x86_64.dll", "xaudio2_9redist.dll")
$MinExeSize = 10MB
foreach ($name in $ExpectedFiles) {
	$path = Join-Path $StageDir $name
	if (-not (Test-Path $path)) {
		Write-Error "Export produced no '$name' at $path - aborting before push."
	}
	if ($name -eq $ExeName -and (Get-Item $path).Length -lt $MinExeSize) {
		Write-Error "'$ExeName' is only $((Get-Item $path).Length) bytes (expected >= $MinExeSize) - aborting before push."
	}
}

Write-Host "Staging contents (about to push):"
Get-ChildItem $StageDir | ForEach-Object { "{0,12:N0}  {1}" -f $_.Length, $_.Name }

Write-Host "Pushing to $ItchTarget..."
butler push $StageDir $ItchTarget --userversion $version
if ($LASTEXITCODE -ne 0) {
	Write-Error "butler push failed with exit code $LASTEXITCODE"
}

$slug = $ItchTarget -replace ':.*', ''
Write-Host ""
Write-Host "Done. Build live at https://$($slug -replace '/', '.itch.io/')"
