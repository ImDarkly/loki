param(
    [string[]]$TestFiles
)
$godot = "C:\Godot\Godot_v4.6.2-stable_win64.exe"
$argsList = @("--headless", "--path", ".", "-s", "addons/gut/gut_cmdln.gd")

if ($TestFiles -and $TestFiles.Count -gt 0) {
    foreach ($tf in $TestFiles) {
        $argsList += "-gtest=$tf"
    }
} else {
    $argsList += "-gdir=res://tests/unit"
}

& $godot @argsList
exit $LASTEXITCODE
