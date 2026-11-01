extends MainLoop
## The balance harness (#18, D95): many seeded fights between fighters from
## data/fighters, written to a CSV and a readable summary with the balance
## targets marked as met or missed (BalanceReport).
##
## Usage:
##   godot --headless --script res://tools/balance.gd [-- --fights=100 --seed=1 --pairs=kicker:boxer,check_red:check_blue --ruleset=pro --out=build/balance --corners=none,ideal,spam]
##
## --corners runs every pair once per coaching bot (Corner styles: none, ideal, ai, spam, mash:<call>;
## ideal:fire_back+pass for the ideal bot with only those of its D257 moments),
## on the same seeds, with the bot in red's corner, then in blue's (--coach=red or blue for
## one side only; the other corner makes no calls), so the report can check what good
## coaching and spam do to the coached fighter's wins (D12).
## --rules=wrestler:catch_kick_and_shoot@80,kicker:sprawl_on_the_shot@60 runs every pair once more
## with those fighters' drilled rules (data/rules ids @ how well drilled, 0–100; a fighter's
## rules fill slots 1 and 2 in order), so the report shows what the rules did (#17).
## --gameplans=pressure,legs,pressure+legs+wrestle_heavy runs every pair once more per plan (data/gameplans
## ids joined by +, one per part), with the plan in red's corner, then in blue's (--coach=red or blue for one
## side), so the report shows what each plan did to that fighter's wins (D320, docs/01 §42).
## --gameplans=style gives each fighter his style sheet's plan, the one his corner picks in the game (D324).
## --jobs=N plays the fights in N Godot processes at once (default: one per CPU core; --jobs=1 plays
## them all in this one). The CSV and summary are the same whatever N is (D123, docs/01 §2.3).
## Writes <out>/balance.csv (one line per fight) and <out>/summary.txt, and prints the summary.
## Also <out>/run.json, what the run was made from and how fast it went (D250, docs/01 §2.4): the
## arguments, the commit, a hash of data/, the Godot version and the time a simulated tick took.
## To compare two runs fight by fight, use tools/balance_compare.gd.
## --blue-first has blue step first on the first tick instead of red (they take turns after, D253),
## the mirror of the usual run (the corner-lean check, D252, docs/01 §2.5). Real fights never do it.
## A 3-round fight takes just under a second on one core, so 100 fights per pair is ~1.5 minutes,
## divided by the number of cores.


## --blue-first: blue steps first on the first tick (D252, D253).
var _blue_first: bool = false


func _initialize() -> void:
	var first_seed: int = 1
	var fights: int = 100
	var pairs: PackedStringArray = ["kicker:boxer"]
	var ruleset_id: String = Ruleset.DEFAULT_ID
	var out_dir: String = "build/balance"
	var corners: PackedStringArray = [Corner.NONE]
	var coach_sides: Array[int] = [0, 1]
	var drilled: Dictionary = {}  # fighter id → ["rule_id@percent", …]
	var gameplans: PackedStringArray = []
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
		elif arg == "--blue-first":
			_blue_first = true
		elif arg.begins_with("--rows="):
			rows_path = arg.trim_prefix("--rows=")
		elif arg.begins_with("--gameplans="):
			gameplans = arg.trim_prefix("--gameplans=").split(",", false)
			for g in gameplans:
				if g == FightSummary.STYLE_PLAN:
					continue  # Each fighter's own style sheet's plan (D324).
				var parts: Dictionary = {}
				for id in g.split("+", false):
					if not FileAccess.file_exists(Gameplan.DEFAULT_DIR.path_join(id + ".json")):
						printerr("A gameplan is data/gameplans ids joined by +, e.g. pressure+legs (got '%s')" % g)
						return
					parts[String(Gameplan.read(id).part)] = id
				if Gameplan.check(parts) != "":
					printerr("Gameplan '%s': %s" % [g, Gameplan.check(parts)])
					return
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
		if not Corner.valid(style):
			printerr("No coaching bot '%s' (have: %s; ideal:a+b or ai:a+b for only some of its moments, %s; mash:<call id>)" % [style, ", ".join(Corner.STYLES), "+".join(Corner.MOMENTS)])
			return
	var rules: Ruleset = Ruleset.load_id(ruleset_id)
	var jobs: Array[Dictionary] = HarnessJobs.plan(pairs, fights, first_seed, corners, coach_sides, drilled, gameplans)
	processes = mini(processes, jobs.size())
	if worker >= 0:
		var file := FileAccess.open(rows_path, FileAccess.WRITE)
		if file == null:
			printerr("Couldn't write %s (error %d)" % [rows_path, FileAccess.get_open_error()])
			return
		var played: Dictionary = _play(jobs, HarnessJobs.share(jobs.size(), processes, worker), roster, actions, rules)
		file.store_var(played)  # Binary, so floats come back exactly.
		return
	var dir: String = ProjectSettings.globalize_path("res://").path_join(out_dir) if out_dir.is_relative_path() else out_dir
	DirAccess.make_dir_recursive_absolute(dir)
	var started: int = Time.get_ticks_msec()
	print("Playing %d fights in %d process%s." % [jobs.size(), processes, "" if processes == 1 else "es"])
	var played: Dictionary = _play_shared(jobs, processes, dir, roster, actions, rules, started)
	if played.rows.is_empty():
		return
	var seconds: float = (Time.get_ticks_msec() - started) / 1000.0
	print("All %d fights done in %.0f s." % [jobs.size(), seconds])
	var report := BalanceReport.new()
	for row in played.rows:
		report.add(row)
	var run := { "commit": _commit(), "data": data_hash(), "godot": Engine.get_version_info().string }
	if _blue_first:
		run.order = "blue steps first on the first tick"
	var summary: String = report.summary(names, run)
	var ticks: float = 0.0
	for row in played.rows:
		ticks += float(row.fight_seconds) * FightClock.TICKS_PER_SECOND
	var tick_usec: float = played.usec / ticks if ticks > 0.0 else 0.0
	run.merge({ "args": " ".join(OS.get_cmdline_user_args()), "fights": jobs.size(), "seeds": [first_seed, first_seed + fights - 1],
		"pairs": Array(pairs), "ruleset": ruleset_id, "corners": Array(corners), "processes": processes,
		"seconds": snappedf(seconds, 0.1), "simulated_ticks": int(ticks), "usec_per_tick": snappedf(tick_usec, 0.1),
		"made": Time.get_datetime_string_from_system(true) + "Z" })
	_write(dir.path_join("balance.csv"), report.csv())
	_write(dir.path_join("summary.txt"), summary)
	_write(dir.path_join("run.json"), JSON.stringify(run, "  ") + "\n")
	print("")
	print(summary)
	# Not in summary.txt, which must come out the same whatever --jobs is (D123).
	print("Speed: %.0f µs of computer time a simulated tick, with %d process%s at once (D105's budget is 100 µs; this includes the harness's own counting) (D250)" % [
		tick_usec, processes, "" if processes == 1 else "es"])
	print("Wrote %s, summary.txt and run.json" % dir.path_join("balance.csv"))


## Plays the jobs at `indexes` in this process, printing progress at the end of each group.
## Returns { rows, usec }: the rows in order and the microseconds spent playing them.
func _play(jobs: Array[Dictionary], indexes: Array[int], roster: FighterLibrary, actions: ActionLibrary, rules: Ruleset, started: int = -1) -> Dictionary:
	var rows: Array[Dictionary] = []
	var usec: int = 0
	for i in indexes.size():
		var job: Dictionary = jobs[indexes[i]]
		var before: int = Time.get_ticks_usec()
		rows.append(HarnessJobs.run(job, roster, actions, rules, _blue_first))
		usec += Time.get_ticks_usec() - before
		var last_of_group: bool = i == indexes.size() - 1 or jobs[indexes[i + 1]].group != job.group
		if started >= 0 and last_of_group:
			print("%s: done (%.0f s so far)" % [job.group, (Time.get_ticks_msec() - started) / 1000.0])
	return { "rows": rows, "usec": usec }


## Plays every job: share 0 here, the other shares in extra Godot processes
## started with the same arguments plus --worker=k, each writing its rows to a
## file in `dir`. Returns { rows, usec }: the rows in job order (none if a process failed)
## and the microseconds all the processes spent playing fights.
func _play_shared(jobs: Array[Dictionary], processes: int, dir: String, roster: FighterLibrary, actions: ActionLibrary, rules: Ruleset, started: int) -> Dictionary:
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
	var own: Dictionary = _play(jobs, HarnessJobs.share(jobs.size(), processes, 0), roster, actions, rules, started if processes == 1 else -1)
	var parts: Array = [own.rows]
	var usec: int = own.usec
	if processes > 1:
		print("Process 1 of %d done (%.0f s so far)." % [processes, (Time.get_ticks_msec() - started) / 1000.0])
	for k in pids.size():
		while OS.is_process_running(pids[k]):
			OS.delay_msec(100)
		var file := FileAccess.open(paths[k], FileAccess.READ)
		var saved: Variant = file.get_var() if file != null else null
		file = null  # Closes it before it's removed.
		DirAccess.remove_absolute(paths[k])
		if pids[k] < 0 or not saved is Dictionary or not saved.get("rows") is Array:
			printerr("Process %d of %d failed (exit code %d): no rows from it." % [k + 2, processes, OS.get_process_exit_code(pids[k]) if pids[k] >= 0 else -1])
			return { "rows": [] as Array[Dictionary], "usec": 0 }
		parts.append(saved.rows)
		usec += int(saved.usec)
		print("Process %d of %d done (%.0f s so far)." % [k + 2, processes, (Time.get_ticks_msec() - started) / 1000.0])
	return { "rows": HarnessJobs.merge(parts, jobs.size()), "usec": usec }


## The commit the run was made from (with "+changes" when files differ from it), or "unknown" without git.
static func _commit() -> String:
	var out: Array = []
	var at: String = ProjectSettings.globalize_path("res://")
	if OS.execute("git", ["-C", at, "rev-parse", "--short", "HEAD"], out) != 0 or out.is_empty():
		return "unknown"
	var commit: String = str(out[0]).strip_edges()
	var status: Array = []
	if OS.execute("git", ["-C", at, "status", "--porcelain", "--untracked-files=no"], status) == 0 and not str(status[0]).strip_edges().is_empty():
		commit += "+changes"
	return commit


## A short hash of every file in data/ (names and contents), so two runs show whether
## they used the same fighters, moves and numbers (D250).
static func data_hash() -> String:
	var files: PackedStringArray = []
	_list_files("res://data", files)
	files.sort()
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	for path in files:
		ctx.update(path.to_utf8_buffer())
		ctx.update(FileAccess.get_file_as_bytes(path))
	return ctx.finish().hex_encode().left(8)


static func _list_files(dir: String, into: PackedStringArray) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_list_files(dir.path_join(sub), into)
	for file in DirAccess.get_files_at(dir):
		if not file.ends_with(".import") and not file.ends_with(".uid"):
			into.append(dir.path_join(file))


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("Couldn't write %s (error %d)" % [path, FileAccess.get_open_error()])
		return
	file.store_string(text)


func _process(_delta: float) -> bool:
	return true  # Quit after _initialize.
