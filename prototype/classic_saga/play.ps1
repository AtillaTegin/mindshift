# Launch only the Saga preview with its own test save.
$project = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$godot = 'C:/Users/User/Tools/godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
& $godot --path $project --resolution 390x844 res://prototype/classic_saga/classic_saga.tscn -- '--save-path=res://.test_saves/classic_saga.json'
