extends MainLoop
## Compares two balance harness runs fight by fight (D250, docs/01 §2.4): run the harness
## before a change and after it on the same seeds, then
##
##   godot --headless --script res://tools/balance_compare.gd -- --before=build/before/balance.csv --after=build/balance/balance.csv [--columns=shots_red,shots_blue] [--out=build/compare.txt]
##
## Per pairing it says how many fights played out differently, each side's win share,
## draws and finishes before → after, and the change with its 95% range from the
## seed-by-seed differences (BalanceCompare). A range that doesn't cross 0 is a real
## change; one that does could be luck. --columns adds any numeric CSV columns.


func _initialize() -> void:
	var paths := { "before": "", "after": "" }
	var columns: PackedStringArray = []
	var out_path: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--before="):
			paths.before = arg.trim_prefix("--before=")
		elif arg.begins_with("--after="):
			paths.after = arg.trim_prefix("--after=")
		elif arg.begins_with("--columns="):
			columns = arg.trim_prefix("--columns=").split(",", false)
		elif arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
	var runs: Dictionary = {}
	for which: String in paths:
		var path: String = paths[which]
		if path == "":
			printerr("Give both runs' CSVs: --before=<balance.csv> --after=<balance.csv>")
			return
		var at: String = ProjectSettings.globalize_path("res://").path_join(path) if path.is_relative_path() else path
		if not FileAccess.file_exists(at):
			printerr("No file %s" % at)
			return
		runs[which] = BalanceCompare.parse_csv(FileAccess.get_file_as_string(at))
		if runs[which].is_empty():
			printerr("No fights in %s" % at)
			return
	var text: String = BalanceCompare.report(runs.before, runs.after, columns)
	print(text)
	if out_path != "":
		var file := FileAccess.open(out_path, FileAccess.WRITE)
		if file == null:
			printerr("Couldn't write %s (error %d)" % [out_path, FileAccess.get_open_error()])
			return
		file.store_string(text)
		print("Wrote %s" % out_path)


func _process(_delta: float) -> bool:
	return true  # Quit after _initialize.
