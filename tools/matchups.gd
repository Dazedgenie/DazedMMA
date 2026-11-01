extends SceneTree
## The style matchup table for the world's quick result model (docs/03 §12.3, D353): every style against every other,
## on the fight engine, written to data/world/matchups.json (docs/09 matchups@1). Rebuild it when fights change.
##
## Each fight is two men made from their style sheets (StyleLibrary.generate) around an average stat of BASE_AVG,
## one a random 0–SPREAD points better than the other, the sides swapped every other fight, under pro rules. Then one
## fit over every fight (ResultModel.fit): each pair of styles' edge at an even level, and how much a point of
## average stat is worth, plus how each style's wins and losses end and in which round.
##
## Usage:
##   godot --headless --script res://tools/matchups.gd [-- --fights=40 --seed=1 --jobs=4 --out=data/world/matchups.json]
## --fights is per pair of styles (105 pairs), so 40 is 4,200 fights: about 15 minutes on 4 cores.

const BASE_AVG: float = 55.0
const BASE_SPREAD: float = 6.0
const SPREAD: int = 8

var _done: bool = false


func _initialize() -> void:
	var fights: int = 40
	var first_seed: int = 1
	var processes: int = OS.get_processor_count()
	var worker: int = -1
	var out_path: String = "res://data/world/matchups.json"
	var part_path: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fights="):
			fights = int(arg.trim_prefix("--fights="))
		elif arg.begins_with("--seed="):
			first_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--jobs="):
			processes = maxi(1, int(arg.trim_prefix("--jobs=")))
		elif arg.begins_with("--worker="):
			worker = int(arg.trim_prefix("--worker="))
		elif arg.begins_with("--part="):
			part_path = arg.trim_prefix("--part=")
		elif arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
			if not out_path.begins_with("res://") and not out_path.begins_with("/"):
				out_path = "res://" + out_path
	var jobs: Array[Dictionary] = plan(fights, first_seed)
	if worker >= 0:
		var rows: Array = _play(jobs, worker, processes)
		var f := FileAccess.open(part_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(rows))
		_done = true
		return
	var started: int = Time.get_ticks_msec()
	print("Playing %d fights (%d pairs of styles × %d) in %d process%s…" % [jobs.size(), jobs.size() / maxi(1, fights), fights, processes, "" if processes == 1 else "es"])
	var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tools/matchups.gd", "--",
		"--fights=%d" % fights, "--seed=%d" % first_seed, "--jobs=%d" % processes]
	var pids: Array[int] = []
	var parts: Array[String] = []
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/matchups"))
	for k in range(1, processes):
		parts.append(ProjectSettings.globalize_path("res://build/matchups/part_%d.json" % k))
		DirAccess.remove_absolute(parts[-1])
		pids.append(OS.create_process(OS.get_executable_path(), args + PackedStringArray(["--worker=%d" % k, "--part=" + parts[-1]])))
	var rows: Array = _play(jobs, 0, processes)
	for k in pids.size():
		while OS.is_process_running(pids[k]):
			OS.delay_msec(200)
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(parts[k]))
		if not parsed is Array:
			printerr("Process %d of %d failed: no fights from it." % [k + 2, processes])
			_done = true
			return
		rows.append_array(parsed)
	print("Played %d fights in %.0f s." % [rows.size(), (Time.get_ticks_msec() - started) / 1000.0])
	var table: Dictionary = ResultModel.fit(rows)
	table.fights_per_pair = fights
	table.made = { "commit": _commit(), "date": Time.get_date_string_from_system(), "seed": first_seed }
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(table, "\t", false) + "\n")
	f = null
	var check: Dictionary = ResultModel.check(rows, table)
	print("A point of average stat: %.3f (logit). Draws: %.1f%%. Model against the engine: %d of %d pairs inside the engine's 95%% range." % [
		float(table.per_point), 100.0 * float(table.draw), int(check.inside), int(check.pairs)])
	print("Wrote %s" % out_path)
	_done = true


## Every fight to play: each pair of different styles `fights` times, { a, b, seed, avg_a, avg_b, a_red }.
static func plan(fights: int, first_seed: int) -> Array[Dictionary]:
	var ids: Array = StyleLibrary.shared().ids().duplicate()
	ids.sort()
	var out: Array[Dictionary] = []
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			for n in fights:
				var s: int = first_seed + n
				var rng := RandomNumberGenerator.new()
				rng.seed = hash([ids[i], ids[j], s, "matchup"])
				var base: float = BASE_AVG + rng.randf_range(-BASE_SPREAD, BASE_SPREAD)
				var gap: int = rng.randi_range(-SPREAD, SPREAD)
				out.append({ "a": String(ids[i]), "b": String(ids[j]), "seed": int(hash([ids[i], ids[j], s])) & 0x7fffffff,
					"avg_a": base + gap / 2.0, "avg_b": base - gap / 2.0, "a_red": n % 2 == 0 })
	return out


## Plays this process's share (every `processes`-th job from `worker`): one row a fight, { a, b, avg_a, avg_b,
## winner ("a", "b" or "draw"), method, round }.
static func _play(jobs: Array[Dictionary], worker: int, processes: int) -> Array:
	var styles: StyleLibrary = StyleLibrary.shared()
	var roster := FighterLibrary.load_dir()
	var actions := ActionLibrary.load_dir()
	var rules: Ruleset = Ruleset.load_id(Ruleset.DEFAULT_ID)
	var model := World.new(styles, NameLibrary.shared(), roster)
	var rows: Array = []
	for i in range(worker, jobs.size(), processes):
		var job: Dictionary = jobs[i]
		var pa: Dictionary = styles.generate(String(job.a), int(job.seed), _level(model, String(job.a), float(job.avg_a)), roster, "a_%d" % i)
		var pb: Dictionary = styles.generate(String(job.b), int(job.seed) + 1, _level(model, String(job.b), float(job.avg_b)), roster, "b_%d" % i)
		roster.add(pa)
		roster.add(pb)
		var red: String = String(pa.id) if bool(job.a_red) else String(pb.id)
		var blue: String = String(pb.id) if bool(job.a_red) else String(pa.id)
		var row: Dictionary = FightSummary.run(int(job.seed), roster, actions, red, blue, rules)
		var winner: String = "draw"
		if String(row.winner_id) == String(pa.id):
			winner = "a"
		elif String(row.winner_id) == String(pb.id):
			winner = "b"
		rows.append({ "a": job.a, "b": job.b, "avg_a": Matchmaker.average_stat(pa.stats), "avg_b": Matchmaker.average_stat(pb.stats),
			"winner": winner, "method": String(row.method), "round": int(row.end_round) })
		if worker == 0 and rows.size() % 100 == 0:
			print("  %d of about %d fights here…" % [rows.size(), jobs.size() / processes])
	return rows


static func _level(model: World, style_id: String, avg: float) -> int:
	return clampi(roundi(avg - model.average({ "style": style_id, "level": 0 })), -StyleLibrary.MAX_LEVEL, StyleLibrary.MAX_LEVEL)


static func _commit() -> String:
	var out: Array = []
	if OS.execute("git", ["rev-parse", "--short", "HEAD"], out) == 0 and not out.is_empty():
		return String(out[0]).strip_edges()
	return "unknown"


func _process(_delta: float) -> bool:
	return _done
