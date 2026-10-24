extends GutTest
## ActionLibrary: loads data/actions/*.json for the sim (docs/09-data-formats.md).


func test_loads_every_action_file_in_data() -> void:
	var library := ActionLibrary.load_dir()
	for id in ["jab", "body_kick", "double_leg", "catch_kick_single", "sprawl"]:
		assert_true(library.has(id), "missing %s" % id)


func test_phase_timings_convert_from_milliseconds_to_ticks() -> void:
	var library := ActionLibrary.load_dir()
	assert_eq(library.phase_ticks("body_kick", "telegraph"), 3)
	assert_eq(library.phase_ticks("body_kick", "recovery"), 4)
	assert_eq(library.total_ticks("body_kick"), 12)
