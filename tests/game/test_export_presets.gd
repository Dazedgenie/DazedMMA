extends GutTest
## export_presets.cfg: the builds the Playtest build workflow makes (D118, D240).


func _presets() -> Dictionary:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK)
	var by_name: Dictionary = {}
	for section: String in cfg.get_sections():
		if not section.ends_with(".options"):
			by_name[cfg.get_value(section, "name")] = section
	by_name["_cfg"] = cfg
	return by_name


func test_there_are_windows_linux_and_web_builds() -> void:
	var presets: Dictionary = _presets()
	for preset_name: String in ["Windows Desktop", "Linux", "Web"]:
		assert_true(presets.has(preset_name), preset_name)


func test_the_web_build_has_thread_support_off_so_github_pages_can_serve_it() -> void:
	var presets: Dictionary = _presets()
	var cfg: ConfigFile = presets["_cfg"]
	var options: String = String(presets["Web"]) + ".options"
	assert_eq(cfg.get_value(options, "variant/thread_support"), false)
	assert_eq(cfg.get_value(String(presets["Web"]), "include_filter"), "data/*.json", "the game reads its data files at run time")
