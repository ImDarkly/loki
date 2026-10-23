# Scripted verify gate for Chum!. Costs zero model tokens.
# Default (pre-check): import once, load check, scoped GUT (serial, fail-fast).
# -Final: headless lobby boot (standard, deep) and full GUT suite (deep only).
# Exit codes: 0 green | 1 red (code defect) | 2 environment problem (fix it, do not escalate)
# UNVERIFIED on this machine: GUT exit codes, load-error detection, boot without EOS credentials.
param(
	[ValidateSet("cheap", "standard", "deep")][string]$Tier = "standard",
	[string[]]$Tests = @(),
	[switch]$Final
)

$Godot = "C:\Godot\Godot_v4.6.2-stable_win64.exe"
$Root = Split-Path -Parent $PSScriptRoot
$ErrorPattern = "SCRIPT ERROR|Parse Error"

function Fail-Env([string]$Message) {
	Write-Host "ENV $Message"
	exit 2
}

function Invoke-Check([string]$Id, [string[]]$GodotArgs, [int]$TimeoutSec) {
	$log = Join-Path $env:TEMP ("chum_verify_" + ($Id -replace "[^a-zA-Z0-9]", "_") + ".log")
	$p = Start-Process -FilePath $Godot -ArgumentList $GodotArgs -WorkingDirectory $Root -NoNewWindow -PassThru -RedirectStandardOutput $log -RedirectStandardError "$log.err"
	# Retain the handle so redirected Windows PowerShell processes preserve ExitCode after waiting.
	$process_handle = $p.Handle
	$finished = $p.WaitForExit($TimeoutSec * 1000)
	if (-not $finished) {
		$p.Kill()
		Write-Host "RED $Id (timeout ${TimeoutSec}s)"
		exit 1
	}
	$text = @(Get-Content $log -ErrorAction SilentlyContinue) + @(Get-Content "$log.err" -ErrorAction SilentlyContinue)
	$hasError = ($text | Select-String -Pattern $ErrorPattern -Quiet)
	if ($Id.StartsWith("gut:") -and $Id -ne "gut:full") {
		$output = ($text -join "`n") -replace '\x1B\[[0-?]*[ -/]*[@-~]', ''
		$scriptName = [regex]::Escape($Id.Substring(4))
		$ranScript = $output -match "(?m)^res://tests/unit/$scriptName\s*$"
		$ranTests = $output -match '(?m)^Tests\s+[1-9][0-9]*\s*$'
		$executedTests = $output -match '(?m)^(Passing|Failing) Tests\s+[1-9][0-9]*\s*$'
		$skipped = $output -match '(?im)Ignoring script|Could not find script matching|Script was skipped|\[Skipped\]'
		if (-not $ranScript -or -not $ranTests -or -not $executedTests -or $skipped) {
			Write-Host "RED $Id (selected script must execute tests without skips)"
			$text | Select-Object -Last 40 | ForEach-Object { Write-Host $_ }
			exit 1
		}
	}
	if ($p.ExitCode -ne 0 -or $hasError) {
		Write-Host "RED $Id"
		$text | Select-Object -Last 40 | ForEach-Object { Write-Host $_ }
		exit 1
	}
	Write-Host "GREEN $Id"
}

function Get-ScopedTests {
	$changedFiles = @(git -C $Root diff --name-only master 2>$null)
	if ($LASTEXITCODE -ne 0) { Fail-Env "Failed to discover changed files with git diff --name-only master" }
	$untrackedFiles = @(git -C $Root ls-files --others --exclude-standard 2>$null)
	if ($LASTEXITCODE -ne 0) { Fail-Env "Failed to discover untracked files with git ls-files --others --exclude-standard" }
	$files = $changedFiles + $untrackedFiles
	$found = @()
	foreach ($f in $files) {
		if (-not ($f -match "\.(gd|tscn)$")) { continue }
		$base = [System.IO.Path]::GetFileNameWithoutExtension($f)
		if ($base.StartsWith("test_")) { $candidate = "tests/unit/$base.gd" } else { $candidate = "tests/unit/test_$base.gd" }
		if (Test-Path (Join-Path $Root $candidate)) { $found += "res://$candidate" }
	}
	return $found | Sort-Object -Unique
}

if (-not (Test-Path $Godot)) { Fail-Env "Godot not found at $Godot" }
if (-not (Test-Path (Join-Path $Root "addons\gut"))) { Fail-Env "addons/gut missing (addons/ is gitignored)" }

if ($Final) {
	if ($Tier -eq "cheap") { Write-Host "GREEN final (nothing to run for cheap)"; exit 0 }
	if (-not (Test-Path (Join-Path $Root "addons\epic-online-services-godot"))) { Fail-Env "addons/epic-online-services-godot missing" }
	Invoke-Check "boot" @("--headless", "--path", ".", "--quit-after", "120") 90
	if ($Tier -eq "deep") {
		Invoke-Check "gut:full" @("--headless", "--path", ".", "-s", "addons/gut/gut_cmdln.gd") 600
	}
	exit 0
}

Invoke-Check "import" @("--headless", "--path", ".", "--import") 120
Invoke-Check "load" @("--headless", "--path", ".", "--quit") 90

if ($Tests.Count -eq 0) { $Tests = @(Get-ScopedTests) }
if ($Tests.Count -eq 0 -and $Tier -ne "cheap") { Write-Host "WARN no scoped test found for the changed files" }
foreach ($t in $Tests) {
	if (-not $t.StartsWith("res://")) {
		if ($t.EndsWith(".gd")) { $t = "res://tests/unit/$t" } else { $t = "res://tests/unit/$t.gd" }
	}
	Invoke-Check "gut:$([System.IO.Path]::GetFileName($t))" @("--headless", "--path", ".", "-s", "addons/gut/gut_cmdln.gd", "-gselect=$([System.IO.Path]::GetFileName($t))") 90
}
exit 0
