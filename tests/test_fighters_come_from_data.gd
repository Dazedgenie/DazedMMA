extends GutTest
## Issue #32: outside tests, every fighter is made from data/fighters (FighterLibrary),
## never built in code, so the AI, harness, world and replays all share one format.

const DIRS: Array[String] = ["res://game/", "res://ui/", "res://tools/", "res://sim/"]


func test_no_fighter_is_built_in_code_outside_tests() -> void:
	for dir_path in DIRS:
		for path in _find_scripts(dir_path):
			var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
			for n in lines.size():
				var code: String = lines[n].get_slice("#", 0)
				if path.ends_with("fighter_state.gd") and code.contains("FighterState.new(p.name"):
					continue  # from_profile itself.
				assert_false(code.contains("FighterState.new("), "%s:%d builds a fighter in code; add it to data/fighters" % [path, n + 1])


func _find_scripts(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd"):
			found.append(dir_path.path_join(file))
	for sub in DirAccess.get_directories_at(dir_path):
		found.append_array(_find_scripts(dir_path.path_join(sub)))
	return found
