extends MainLoop
## The balance harness (#18, D95): many seeded fights between fighters from
## data/fighters, written to a CSV and a readable summary with the balance
## targets marked as met or missed (BalanceReport).
##
## Usage:
##   godot --headless --script res://tools/balance.gd [-- --fights=100 --seed=1 --pairs=kicker:boxer,check_red:check_blue --ruleset=pro --out=build/balance --corners=none,ideal,spam]
##
## --corners runs every pair once per coaching bot (Corner styles: none, ideal, ai, spam),
## on the same seeds, with the bot in red's corner, then in blue's (--coach=red or blue for
## one side only; the other corner makes no calls), so the report can check what good
## coaching and spam do to the coached fighter's wins (D12).
## Writes <out>/balance.csv (one line per fight) and <out>/summary.txt, and prints the summary.
## A 3-round fight takes about half a second, so 100 fights per pair is ~1 minute.


func _initialize() -> void:
	var first_seed: int = 1
	var fights: int = 100
	var pairs: PackedStringArray = ["kicker:boxer"]
	var ruleset_id: String = Ruleset.DEFAULT_ID
	var out_dir: String = "build/balance"
	var corners: PackedStringArray = [Corner.NONE]
	var coach_sides: Array[int] = [0, 1]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			first_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--fights="):
			fights = int(arg.trim_prefix("--fights="))
		elif arg.begins_with("--pairs="):
			pairs = arg.trim_prefix("--pairs=").split(",")
		elif arg.begins_with("--ruleset="):
			ruleset_id = arg.trim_prefix("--ruleset=")
		elif arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--corners="):
			corners = arg.trim_prefix("--corners=").split(",")
		elif arg.begins_with("--coach="):
			var side: String = arg.trim_prefix("--coach=")
			coach_sides = [0] if side == "red" else ([1] if side == "blue" else [0, 1])
	var actions := ActionLibrary.load_dir()
	var roster := FighterLibrary.load_dir()
	var names: Dictionary = {}
	for pair in pairs:
		for id in pair.split(":"):
			if not roster.has(id):
				printerr("No fighter '%s' in data/fighters (have: %s)" % [id, ", ".join(roster.ids())])
				return
			names[id] = roster.profile(id).name
		if pair.split(":").size() != 2:
			printerr("A pair is two fighter ids joined by a colon, e.g. kicker:boxer (got '%s')" % pair)
			return
	for style in corners:
		if style not in Corner.STYLES:
			printerr("No coaching bot '%s' (have: %s)" % [style, ", ".join(Corner.STYLES)])
			return
	var rules: Ruleset = Ruleset.load_id(ruleset_id)
	var report := BalanceReport.new()
	var started: int = Time.get_ticks_msec()
	for pair in pairs:
		var ids: PackedStringArray = pair.split(":")
		for style in corners:
			for side in ([0] if style == Corner.NONE else coach_sides):
				var both: Array[String] = [Corner.NONE, Corner.NONE]
				both[side] = style
				for n in fights:
					report.add(FightSummary.run(first_seed + n, roster, actions, ids[0], ids[1], rules, 300, both))
				var label: String = pair if style == Corner.NONE else "%s, %s caller in %s's corner" % [pair, style, ["red", "blue"][side]]
				print("%s: %d fights done (%.0f s so far)" % [label, fights, (Time.get_ticks_msec() - started) / 1000.0])
	var summary: String = report.summary(names)
	var dir: String = ProjectSettings.globalize_path("res://").path_join(out_dir) if out_dir.is_relative_path() else out_dir
	DirAccess.make_dir_recursive_absolute(dir)
	_write(dir.path_join("balance.csv"), report.csv())
	_write(dir.path_join("summary.txt"), summary)
	print("")
	print(summary)
	print("Wrote %s and summary.txt" % dir.path_join("balance.csv"))


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("Couldn't write %s (error %d)" % [path, FileAccess.get_open_error()])
		return
	file.store_string(text)


func _process(_delta: float) -> bool:
	return true  # Quit after _initialize.
