extends MainLoop
## Plays the golden fights (#35, D122, docs/01 §2.2) and says which ones changed.
##
## Usage:
##   godot --headless --script res://tools/golden.gd              (check only)
##   godot --headless --script res://tools/golden.gd -- --update  (re-pin them)
##
## Check only prints each fight's result and, for a changed one, what changed.
## --update writes the new results into tests/golden/golden_fights.json: do it
## only when the change to fights is meant, and say so in the PR.


func _initialize() -> void:
	var update: bool = "--update" in OS.get_cmdline_user_args()
	var roster := FighterLibrary.load_dir()
	var actions := ActionLibrary.load_dir()
	var entries: Array[Dictionary] = GoldenFights.load_cases()
	var pins: Array[Dictionary] = []
	var changed: int = 0
	for entry in entries:
		var started: int = Time.get_ticks_msec()
		var played: Dictionary = GoldenFights.play(entry, roster, actions)
		var row: Dictionary = played.row
		pins.append(played.pinned)
		var diffs: Array[String] = GoldenFights.differences(entry.get("pinned", {}), played.pinned)
		print("%s %s: %s by %s, round %d at %d:%02d, %d events (%d ms)" % [
			"CHANGED" if not diffs.is_empty() else "same   ", entry.name,
			row.winner_id if row.winner_id != "" else "nobody", row.method, row.end_round,
			row.end_second / 60, row.end_second % 60, row.events, Time.get_ticks_msec() - started])
		for line in diffs:
			print("          " + line)
		if not diffs.is_empty():
			changed += 1
	if not update:
		print("%d of %d golden fights changed.%s" % [changed, entries.size(),
			" If that's meant, run again with -- --update and commit tests/golden/golden_fights.json." if changed > 0 else ""])
		return
	var err: Error = GoldenFights.save(entries, pins)
	if err != OK:
		printerr("Couldn't write %s (error %d)" % [GoldenFights.PATH, err])
		return
	print("Pinned %d golden fights in %s (%d changed)." % [entries.size(), GoldenFights.PATH, changed])


func _process(_delta: float) -> bool:
	return true  # Quit after _initialize.
