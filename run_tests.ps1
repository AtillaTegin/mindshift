# Runs the headless test suite.
#   .\run_tests.ps1                 all tests
#   .\run_tests.ps1 -Filter solver  only tests/test_*solver*.gd
# Set GODOT_BIN to override the Godot console executable path.
param([string]$Filter = "")

$godot = $env:GODOT_BIN
if (-not $godot) { $godot = "C:\Users\User\Tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe" }
if (-not (Get-Command $godot -ErrorAction SilentlyContinue)) {
	Write-Error "Godot executable not found: $godot (set GODOT_BIN)"
	exit 2
}

# Builds .godot/ (global class cache) so class_name types resolve in --script mode.
& $godot --headless --path $PSScriptRoot --import | Out-Null
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$godotArgs = @("--headless", "--path", $PSScriptRoot, "--script", "res://tests/test_runner.gd")
if ($Filter) { $godotArgs += @("--", "--filter=$Filter") }
& $godot @godotArgs
exit $LASTEXITCODE
