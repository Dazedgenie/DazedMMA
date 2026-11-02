extends SceneTree
## The 30-year check (docs/03 §12.9, D359): a new career's world played 30 years with a stand-in of his own fighting
## through it (WorldCheck), measured every 5 years and held to WorldCheck's bounds. The test on every PR
## (tests/sim/world/test_world_check.gd) runs one seed; run this for more, or after changing the world's numbers.
##
## Usage:
##   godot --headless --script res://tools/world_check.gd [-- --seeds=3,7,11 --years=30 --world-only]
## Each seed takes about 30 s. It starts without the 10 years of history (Career.history_years 0), so the world is
## 30 years old at the end. Prints each seed's report and exits 1 when any is out of bounds.


func _initialize() -> void:
	var seeds: Array[int] = [3]
	var years: int = WorldCheck.YEARS
	var stand_in: bool = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds.clear()
			for s in arg.trim_prefix("--seeds=").split(",", false):
				seeds.append(int(s))
		elif arg.begins_with("--years="):
			years = maxi(1, int(arg.trim_prefix("--years=")))
		elif arg == "--world-only":
			stand_in = false
	Career.history_years = 0
	var bad: int = 0
	for s: int in seeds:
		var c: Career = Career.start({ "coach": "Sam Reed", "name": "Danny Hill", "hometown": "Leeds", "country": "England",
			"background": "street_kid", "stance": "orthodox" }, s, FighterLibrary.load_dir())
		var started: int = Time.get_ticks_msec()
		var report: Dictionary = WorldCheck.play(c, years, stand_in, func(y: int, _r: Dictionary) -> void:
			if y % WorldCheck.SNAPSHOT_YEARS == 0:
				print("  seed %d: year %d" % [s, y]))
		report.ms_per_year = (Time.get_ticks_msec() - started) / years
		print(WorldCheck.report_text(report))
		print("")
		if not WorldCheck.problems(report).is_empty():
			bad += 1
	print("%d of %d seeds healthy." % [seeds.size() - bad, seeds.size()])
	quit(1 if bad > 0 else 0)
