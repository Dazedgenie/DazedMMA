extends GutTest
## Guards the simulation layer rules in sim/README.md and docs/04 §2.2:
## sim/ must stay scene-free, clock-free and input-free so fights run headless
## and replay exactly from a seed.

const SIM_DIR := "res://sim/"

const FORBIDDEN := {
	"uses the scene tree": ["extends Node", "get_tree(", "get_node(", "add_child("],
	"reads real time": ["Time.", "OS.get_ticks", "OS.delay"],
	"reads player input": ["Input."],
	"uses unseeded global randomness": ["randomize()", "randi(", "randf(", "randi_range(", "randf_range(", "randfn("],
}


func test_sim_scripts_follow_the_layer_rules() -> void:
	var scripts: Array[String] = _find_scripts(SIM_DIR)
	assert_gt(scripts.size(), 0, "expected at least one script in sim/")
	var node_path := RegEx.create_from_string("(^|[^\\w\"'])\\$[\\w\"]")
	for path in scripts:
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for n in lines.size():
			var code: String = _strip_comment(lines[n])
			for rule: String in FORBIDDEN:
				for pattern: String in FORBIDDEN[rule]:
					assert_false(code.contains(pattern) and not code.contains("." + pattern),
						"%s:%d %s (`%s`)" % [path, n + 1, rule, pattern])
			assert_null(node_path.search(code), "%s:%d uses the scene tree (`$`)" % [path, n + 1])


func _find_scripts(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd"):
			found.append(dir_path.path_join(file))
	for sub in DirAccess.get_directories_at(dir_path):
		found.append_array(_find_scripts(dir_path.path_join(sub)))
	return found


func _strip_comment(line: String) -> String:
	var hash_at: int = line.find("#")
	return line if hash_at == -1 else line.substr(0, hash_at)
