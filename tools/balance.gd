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
## --rules=wrestler:catch_kick_and_shoot@80,kicker:sprawl_on_the_shot@60 runs every pair once more
## with those fighters' drilled rules (data/rules ids @ how well drilled, 0–100; a fighter's
## rules fill slots 1 and 2 in order), so the report shows what the rules did (#17).
## --jobs=N plays the fights in N Godot processes at once (default: one per CPU core; --jobs=1 plays
## them all in this one). The CSV and summary are the same whatever N is (D123, docs/01 §2.3).
## Writes <out>/balance.csv (one line per fight) and <out>/summary.txt, and prints the summary.
## A 3-round fight takes just under a second on one core, so 100 fights per pair is ~1.5 minutes,
## divided by the number of cores.


func _initialize() -> void:
	var first_seed: int = 1
	var fights: int = 100
	var pairs: PackedStringArray = ["kicker:boxer"]
	var ruleset_id: String = Ruleset.DEFAULT_ID
	var out_dir: String = "build/balance"
	var corners: PackedStringArray = [Corner.NONE]
	var coach_sides: Array[int] = [0, 1]
	var drilled: Dictionary = {}  # fighter id → ["rule_id@percent", …]
	var processes: int = OS.get_processor_count()
	var worker: int = -1  # Set when this process is one of the extra ones (--worker=k), playing its share.
	var rows_path: String = ""
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
			coach_sides.assign([0] if side == "red" else ([1] if side == "blue" else [0, 1]))
		elif arg.begins_with("--jobs="):
			processes = maxi(1, int(arg.trim_prefix("--jobs=")))
		elif arg.begins_with("--worker="):
			worker = int(arg.trim_prefix("--worker="))
		elif arg.begins_with("--rows="):
			rows_path = arg.trim_prefix("--rows=")
		elif arg.begins_with("--rules="):
			for entry in arg.trim_prefix("--rules=").split(","):
				var parts: PackedStringArray = entry.split(":")
				if parts.size() != 2 or not RuleLibrary.shared().has(parts[1].split("@")[0]):
					printerr("A rule is fighter:rule@percent with a data/rules id, e.g. wrestler:catch_kick_and_shoot@80 (got '%s')" % entry)
					return
				drilled.get_or_add(parts[0], []).append(parts[1])
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
	var jobs: Array[Dictionary] = HarnessJobs.plan(pairs, fights, first_seed, corners, coach_sides, drilled)
	processes = mini(processes, jobs.size())
	if worker >= 0:
		var file := FileAccess.open(rows_path, FileAccess.WRITE)
		if file == null:
			printerr("Couldn't write %s (error %d)" % [rows_path, FileAccess.get_open_error()])
			return
		file.store_var(_play(jobs, HarnessJobs.share(jobs.size(), processes, worker), roster, actions, rules))  # Binary, so floats come back exactly.
		return
	var dir: String = ProjectSettings.globalize_path("res://").path_join(out_dir) if out_dir.is_relative_path() else out_dir
	DirAccess.make_dir_recursive_absolute(dir)
	var started: int = Time.get_ticks_msec()
	print("Playing %d fights in %d process%s." % [jobs.size(), processes, "" if processes == 1 else "es"])
	var rows: Array[Dictionary] = _play_shared(jobs, processes, dir, roster, actions, rules, started)
	if rows.is_empty():
		return
	print("All %d fights done in %.0f s." % [jobs.size(), (Time.get_ticks_msec() - started) / 1000.0])
	var report := BalanceReport.new()
	for row in rows:
		report.add(row)
	var summary: String = report.summary(names)
	_write(dir.path_join("balance.csv"), report.csv())
	_write(dir.path_join("summary.txt"), summary)
	print("")
	print(summary)
	print("Wrote %s and summary.txt" % dir.path_join("balance.csv"))


## Plays the jobs at `indexes` in this process, printing progress at the end of each group.
func _play(jobs: Array[Dictionary], indexes: Array[int], roster: FighterLibrary, actions: ActionLibrary, rules: Ruleset, started: int = -1) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for i in indexes.size():
		var job: Dictionary = jobs[indexes[i]]
		rows.append(HarnessJobs.run(job, roster, actions, rules))
		var last_of_group: bool = i == indexes.size() - 1 or jobs[indexes[i + 1]].group != job.group
		if started >= 0 and last_of_group:
			print("%s: done (%.0f s so far)" % [job.group, (Time.get_ticks_msec() - started) / 1000.0])
	return rows


## Plays every job: share 0 here, the other shares in extra Godot processes
## started with the same arguments plus --worker=k, each writing its rows to a
## file in `dir`. Returns the rows in job order, or [] if a process failed.
func _play_shared(jobs: Array[Dictionary], processes: int, dir: String, roster: FighterLibrary, actions: ActionLibrary, rules: Ruleset, started: int) -> Array[Dictionary]:
	var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tools/balance.gd", "--"]
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--jobs=") and not arg.begins_with("--worker=") and not arg.begins_with("--rows="):
			args.append(arg)
	var pids: Array[int] = []
	var paths: Array[String] = []
	for k in range(1, processes):
		paths.append(dir.path_join(".rows_%d.bin" % k))
		DirAccess.remove_absolute(paths[-1])
		pids.append(OS.create_process(OS.get_executable_path(), args + PackedStringArray(["--jobs=%d" % processes, "--worker=%d" % k, "--rows=" + paths[-1]])))
	var parts: Array = [_play(jobs, HarnessJobs.share(jobs.size(), processes, 0), roster, actions, rules, started if processes == 1 else -1)]
	if processes > 1:
		print("Process 1 of %d done (%.0f s so far)." % [processes, (Time.get_ticks_msec() - started) / 1000.0])
	for k in pids.size():
		while OS.is_process_running(pids[k]):
			OS.delay_msec(100)
		var file := FileAccess.open(paths[k], FileAccess.READ)
		var saved: Variant = file.get_var() if file != null else null
		file = null  # Closes it before it's removed.
		DirAccess.remove_absolute(paths[k])
		if pids[k] < 0 or not saved is Array:
			printerr("Process %d of %d failed (exit code %d): no rows from it." % [k + 2, processes, OS.get_process_exit_code(pids[k]) if pids[k] >= 0 else -1])
			return []
		parts.append(saved)
		print("Process %d of %d done (%.0f s so far)." % [k + 2, processes, (Time.get_ticks_msec() - started) / 1000.0])
	return HarnessJobs.merge(parts, jobs.size())


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("Couldn't write %s (error %d)" % [path, FileAccess.get_open_error()])
		return
	file.store_string(text)


func _process(_delta: float) -> bool:
	return true  # Quit after _initialize.
