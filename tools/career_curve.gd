extends MainLoop
## Runs a fighter through years of camps and prints their stats by age: the climb to the
## prime and the decline after it (docs/02 §3.8, D136). There's no career calendar yet, so
## this is where ageing and the size of camp gains are checked.
##
## Usage:
##   godot --headless --script res://tools/career_curve.gd [-- --fighter=wrestler --start=45 --age=18 --to=38 --potential=90 --fights=3 --camp=8 --between=on --plans=wrestler,wrestler,jiu_jitsu,balanced --seed=1]
##
## --start sets every stat to that number (0 keeps the fighter file's), --fights is fights a year, --camp the weeks of each
## camp (its last week is a Taper fight week), --between=on trains the weeks between camps (data/week_plans/between_fights)
## and off rests them (time_off), --plans the week plans a camp rotates through. Writes build/career/curve.csv too.

const GROUPS: Array[String] = ["Physical", "Striking", "Wrestling", "Grappling", "Mental"]
const OUT_DIR := "res://build/career/"


func _initialize() -> void:
	var fighter_id: String = "wrestler"
	var start: float = 45.0
	var from_age: int = 18
	var to_age: int = 38
	var potential: float = 90.0
	var fights: int = 3
	var camp_weeks: int = 8
	var between: bool = true
	var plans: Array[String] = ["wrestler", "wrestler", "jiu_jitsu", "balanced"]
	var camp_seed: int = 1
	for arg in OS.get_cmdline_user_args():
		var value: String = arg.get_slice("=", 1)
		match arg.get_slice("=", 0):
			"--fighter": fighter_id = value
			"--start": start = float(value)
			"--age": from_age = int(value)
			"--to": to_age = int(value)
			"--potential": potential = float(value)
			"--fights": fights = maxi(1, int(value))
			"--camp": camp_weeks = maxi(1, int(value))
			"--between": between = value != "off"
			"--plans": plans.assign(value.split(","))
			"--seed": camp_seed = int(value)
	var roster := FighterLibrary.load_dir()
	if not roster.has(fighter_id):
		printerr("No fighter '%s' in data/fighters" % fighter_id)
		return
	var profile: Dictionary = roster.profile(fighter_id)
	if start > 0.0:
		for id: String in TrainingCamp.STAT_NAMES:
			profile.stats[id] = start
	profile.age = from_age
	profile.potential = potential
	var camp := TrainingCamp.new(profile, camp_seed)
	var library := TrainingLibrary.shared()
	var cycle: int = roundi(Ageing.WEEKS_PER_YEAR / fights)
	var rows: Array[Dictionary] = [_row(camp)]
	var week: int = 0
	while camp.age < to_age:
		camp.start_camp()
		for w in camp_weeks:
			var plan: String = "taper" if w == camp_weeks - 1 else plans[(week + w) % plans.size()]
			camp.run_plan(library.plan(plan), {}, w == camp_weeks - 1)
		week += camp_weeks
		camp.start_camp()
		for w in maxi(0, cycle - camp_weeks):
			camp.run_plan(library.plan("between_fights" if between else "time_off"))
		week += maxi(0, cycle - camp_weeks)
		if camp.age > int(rows[-1].age):
			rows.append(_row(camp))
	print(_report(profile, rows, fights, camp_weeks, between, plans))
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var file := FileAccess.open(OUT_DIR.path_join("curve.csv"), FileAccess.WRITE)
	file.store_line("age," + ",".join(GROUPS.map(func(g: String) -> String: return g.to_lower())) + ",overall")
	for r in rows:
		var cells: Array[String] = [str(r.age)]
		for g in GROUPS:
			cells.append("%.1f" % r[g])
		cells.append("%.1f" % r.overall)
		file.store_line(",".join(cells))


## The fighter's group averages at this age.
func _row(camp: TrainingCamp) -> Dictionary:
	var groups: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TrainingCamp.STATS_PATH)).values
	var row := { "age": camp.age }
	var total: float = 0.0
	for g in GROUPS:
		var sum: float = 0.0
		var n: int = 0
		for id: String in groups:
			if groups[id] == g:
				sum += camp.stat(id)
				n += 1
		row[g] = sum / n
		total += sum
	row.overall = total / groups.size()
	return row


func _report(profile: Dictionary, rows: Array[Dictionary], fights: int, camp_weeks: int, between: bool, plans: Array[String]) -> String:
	var lines: Array[String] = ["Career curve: %s from %d, potential %d, %d fights a year, %d-week camps (%s, then a taper), %s between camps" % [
		profile.name, rows[0].age, roundi(profile.potential), fights, camp_weeks, ", ".join(plans), "training" if between else "resting"], ""]
	lines.append("Age  " + "  ".join(GROUPS.map(func(g: String) -> String: return "%9s" % g)) + "    Overall")
	var peak: Dictionary = rows[0]
	var physical_peak: Dictionary = rows[0]
	for r in rows:
		var cells: Array[String] = []
		for g in GROUPS:
			cells.append("%9.1f" % r[g])
		lines.append("%3d  %s  %9.1f  %s" % [r.age, "  ".join(cells), r.overall, TrainingCamp.grade(r.overall)])
		if r.overall > peak.overall:
			peak = r
		if r.Physical > physical_peak.Physical:
			physical_peak = r
	lines.append("")
	lines.append("Physical peak at %d (%.1f), overall peak at %d (%.1f)" % [physical_peak.age, physical_peak.Physical, peak.age, peak.overall])
	return "\n".join(lines)


func _process(_delta: float) -> bool:
	return true
