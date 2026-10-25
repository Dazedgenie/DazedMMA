extends MainLoop
## Adds up the playtest's saved fights for the write-up (#20, D118, docs/playtests/).
##
## Usage:
##   godot --headless --script res://tools/playtest_report.gd -- --dir=/path/to/fights [--out=build/playtest]
##
## Testers send the folder their game saved fights in (the result screen's "Open saved
## fights" button; on Windows %APPDATA%\Godot\app_userdata\Chin Check\fights). Put every
## tester's files in one folder and point --dir at it. Writes playtest.csv (one line per
## fight, PlaytestReport.COLUMNS) and summary.txt to --out, and prints the summary.


func _initialize() -> void:
	var dir: String = FightRecord.DIR
	var out: String = "res://build/playtest"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dir="):
			dir = arg.trim_prefix("--dir=")
		elif arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	var records: Array[Dictionary] = PlaytestReport.load_dir(dir)
	if records.is_empty():
		printerr("No saved fights (fight_record@1 .json files) in %s" % dir)
		return
	DirAccess.make_dir_recursive_absolute(out)
	var csv := FileAccess.open(out.path_join("playtest.csv"), FileAccess.WRITE)
	csv.store_string(PlaytestReport.csv(records))
	csv.close()
	var text: String = PlaytestReport.summary(records)
	var summary := FileAccess.open(out.path_join("summary.txt"), FileAccess.WRITE)
	summary.store_string(text)
	summary.close()
	print(text)
	print("Wrote %s and %s" % [ProjectSettings.globalize_path(out.path_join("playtest.csv")), ProjectSettings.globalize_path(out.path_join("summary.txt"))])


func _process(_delta: float) -> bool:
	return true
