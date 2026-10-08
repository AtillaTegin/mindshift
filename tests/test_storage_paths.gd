extends "res://tests/test_case.gd"
## Test and e2e files must never be written to the player's save folder
## (user://). Script runs are redirected into StoragePaths.SANDBOX_DIR.


func test_script_runs_redirect_user_paths_into_the_sandbox() -> void:
	assert_true(StoragePaths.is_script_run(), "tests run with --script")
	assert_eq(StoragePaths.resolve("user://e2e_demo.json"), StoragePaths.SANDBOX_DIR + "/e2e_demo.json")
	assert_eq(StoragePaths.resolve("res://data/levels"), "res://data/levels", "other paths are unchanged")
	assert_true(DirAccess.dir_exists_absolute(StoragePaths.SANDBOX_DIR))


func test_saves_created_by_tests_and_the_app_stay_out_of_user() -> void:
	assert_eq(SaveSystem.new("user://e2e_anything.json").path, StoragePaths.SANDBOX_DIR + "/e2e_anything.json")
	assert_eq(SaveSystem.new().path, StoragePaths.SANDBOX_DIR + "/save.json", "even the default path")
	var app: Node = (Engine.get_main_loop() as SceneTree).root.get_node("App")
	assert_true(app.save.path.begins_with(StoragePaths.SANDBOX_DIR), app.save.path)


func test_the_sandbox_is_ignored_by_git() -> void:
	var ignored: String = FileAccess.get_file_as_string("res://.gitignore")
	assert_true(ignored.contains(".test_saves/"), ".test_saves/ in .gitignore")


func test_no_test_file_names_a_user_path() -> void:
	var offenders: Array[String] = []
	for file_name: String in DirAccess.get_files_at("res://tests"):
		if file_name.ends_with(".gd") and file_name != "test_storage_paths.gd":
			if FileAccess.get_file_as_string("res://tests/" + file_name).contains("\"user://"):
				offenders.append(file_name)
	assert_eq(offenders, [] as Array[String], "use res://.test_saves/... in tests")
