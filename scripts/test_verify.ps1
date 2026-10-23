param([string]$Case = '')

$ErrorActionPreference = 'Stop'
$verify = Join-Path $PSScriptRoot 'verify.ps1'
$shell = Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
$cases = @(
	@{ Name = 'success'; Code = 'exit 0'; Expected = 0 },
	@{ Name = 'failure'; Code = 'exit 7'; Expected = 1 },
	@{ Name = 'script_error'; Code = "Write-Output 'SCRIPT ERROR: regression'; exit 0"; Expected = 1 },
	@{ Name = 'parse_error'; Code = "Write-Output 'Parse Error: regression'; exit 0"; Expected = 1 },
	@{ Name = 'timeout'; Code = 'Start-Sleep -Seconds 5'; Expected = 1 },
	@{ Name = 'selected_success'; Code = "Write-Output 'res://tests/unit/test_verify.gd','Tests 1','Passing Tests 1'; exit 0"; Expected = 0 },
	@{ Name = 'selected_missing'; Code = "Write-Output 'Could not find script matching test_verify.gd'; exit 0"; Expected = 1 },
	@{ Name = 'selected_skipped'; Code = "Write-Output 'res://tests/unit/test_verify.gd','Tests 1','Passing Tests 1','[Skipped]'; exit 0"; Expected = 1 },
	@{ Name = 'selected_empty'; Code = "Write-Output 'res://tests/unit/test_verify.gd','Tests 0','Passing Tests 0'; exit 0"; Expected = 1 },
	@{ Name = 'selected_pending'; Code = "Write-Output 'res://tests/unit/test_verify.gd','Tests 1','Pending Tests 1'; exit 0"; Expected = 1 }
)

if ($Case) {
	$scenario = $cases | Where-Object { $_.Name -eq $Case }
	if (-not $scenario) { throw "Unknown case: $Case" }
	$tokens = $null
	$parse_errors = $null
	$ast = [System.Management.Automation.Language.Parser]::ParseFile($verify, [ref]$tokens, [ref]$parse_errors)
	if ($parse_errors.Count) { throw $parse_errors[0] }
	$function = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Invoke-Check' }, $true)
	Invoke-Expression $function.Extent.Text
	$Godot = $shell
	$Root = Split-Path -Parent $PSScriptRoot
	$ErrorPattern = 'SCRIPT ERROR|Parse Error'
	$id = "verify_regression_${PID}_$Case"
	if ($Case.StartsWith('selected_')) { $id = 'gut:test_verify.gd' }
	$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($scenario.Code))
	$timeout = if ($Case -eq 'timeout') { 1 } else { 10 }
	try {
		Invoke-Check $id @('-NoProfile', '-NonInteractive', '-EncodedCommand', $encoded) $timeout
	} finally {
		$log = Join-Path $env:TEMP ('chum_verify_' + ($id -replace '[^a-zA-Z0-9]', '_') + '.log')
		Remove-Item -LiteralPath $log, "$log.err" -ErrorAction SilentlyContinue
	}
	exit 0
}

$failed = 0
foreach ($scenario in $cases) {
	$log = Join-Path $env:TEMP "chum_verify_regression_${PID}_$($scenario.Name).log"
	try {
		$arguments = @('-NoProfile', '-NonInteractive', '-File', ('"' + $PSCommandPath + '"'), '-Case', $scenario.Name)
		$process = Start-Process $shell -ArgumentList $arguments -NoNewWindow -PassThru -RedirectStandardOutput $log -RedirectStandardError "$log.err"
		$handle = $process.Handle
		$process.WaitForExit()
		$output = (@(Get-Content $log) + @(Get-Content "$log.err")) -join "`n"
		$marker = if ($scenario.Expected -eq 0) { 'GREEN ' } else { 'RED ' }
		if ($process.ExitCode -ne $scenario.Expected -or -not $output.Contains($marker)) {
			$failed++
			Write-Host "FAIL $($scenario.Name): expected $($scenario.Expected), got $($process.ExitCode)"
			Write-Host $output
		} else {
			Write-Host "PASS $($scenario.Name)"
		}
	} finally {
		Remove-Item -LiteralPath $log, "$log.err" -ErrorAction SilentlyContinue
	}
}
if ($failed) { exit 1 }
exit 0
