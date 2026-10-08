class_name StoragePaths
extends RefCounted
## Keeps test files out of the player's save folder. Tests, e2e scripts and
## tools all run with `--script`; in those runs every user:// file path is
## redirected into SANDBOX_DIR, a gitignored folder inside the project (Godot
## skips dot-folders, so the editor never imports it). The real game never
## runs with --script, so its user://save.json is untouched.

const SANDBOX_DIR: String = "res://.test_saves"


## True for `godot --script ...` runs (tests, e2e scripts, tools).
static func is_script_run() -> bool:
	return "--script" in OS.get_cmdline_args()


## `path`, or for a user:// path in a script run the same file inside
## SANDBOX_DIR (whose folders are created on demand).
static func resolve(path: String) -> String:
	if not is_script_run() or not path.begins_with("user://"):
		return path
	var resolved: String = "%s/%s" % [SANDBOX_DIR, path.trim_prefix("user://")]
	DirAccess.make_dir_recursive_absolute(resolved.get_base_dir())
	return resolved
