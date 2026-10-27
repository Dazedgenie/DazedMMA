extends MainLoop
## Runs a training camp on a fighter from data/fighters and prints what it did
## (docs/02 §3.5, D125): each week's sessions, fatigue and injuries, the stats that
## moved, the style pushes and how fresh the fighter is for the fight.
##
## Usage:
##   godot --headless --script res://tools/camp.gd [-- --fighter=wrestler --plan=wrestler --weeks=8 --taper=1 --seed=1 --age=17 --potential=80 --fights=100 --opponent=kicker]
##
## --plan is a data/week_plans id (one for every week), --taper how many of the last weeks use the taper plan.
## --age and --potential stand in for a fighter file that doesn't give them (docs/09 fighter@1).
## --fights=N also plays N fights (seeds 1…N) against --opponent with the fighter as they were and as the camp left them.

const STAT_NAMES := {
	"strength": "Strength", "speed": "Speed", "cardio": "Cardio", "recovery": "Recovery", "durability": "Durability",
	"chin": "Chin", "boxing": "Boxing", "kicking": "Kicking", "clinch_striking": "Clinch striking",
	"striking_defense": "Striking defense", "footwork": "Footwork", "power": "Power", "takedowns": "Takedowns",
	"takedown_defense": "Takedown defense", "clinch_control": "Clinch control", "scrambles": "Scrambles",
	"top_control": "Top control", "guard": "Guard", "submissions": "Submissions",
	"submission_defense": "Submission defense", "fight_iq": "Fight IQ", "composure": "Composure", "heart": "Heart",
}


func _initialize() -> void:
	var fighter_id: String = "wrestler"
	var plan_id: String = "wrestler"
	var weeks: int = 8
	var taper: int = 1
	var camp_seed: int = 1
	var fights: int = 0
	var opponent: String = "kicker"
	var overrides: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fighter="):
			fighter_id = arg.trim_prefix("--fighter=")
		elif arg.begins_with("--plan="):
			plan_id = arg.trim_prefix("--plan=")
		elif arg.begins_with("--weeks="):
			weeks = maxi(1, int(arg.trim_prefix("--weeks=")))
		elif arg.begins_with("--taper="):
			taper = maxi(0, int(arg.trim_prefix("--taper=")))
		elif arg.begins_with("--seed="):
			camp_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--fights="):
			fights = maxi(0, int(arg.trim_prefix("--fights=")))
		elif arg.begins_with("--opponent="):
			opponent = arg.trim_prefix("--opponent=")
		elif arg.begins_with("--age="):
			overrides.age = float(arg.trim_prefix("--age="))
		elif arg.begins_with("--potential="):
			overrides.potential = float(arg.trim_prefix("--potential="))
	var roster := FighterLibrary.load_dir()
	var library := TrainingLibrary.shared()
	for id in [fighter_id, opponent]:
		if not roster.has(id):
			printerr("No fighter '%s' in data/fighters (have: %s)" % [id, ", ".join(roster.ids())])
			return
	if not library.has_plan(plan_id):
		printerr("No week plan '%s' in data/week_plans (have: %s)" % [plan_id, ", ".join(library.plan_ids())])
		return
	var before: Dictionary = roster.profile(fighter_id)
	before.merge(overrides, true)
	var plans: Array[String] = []
	for w in weeks:
		plans.append("taper" if w >= weeks - taper else plan_id)
	var camp := TrainingCamp.new(before, camp_seed, library)
	var reports: Array[Dictionary] = camp.run_camp(plans)
	print(_report(before, camp, reports, library, camp_seed))
	if fights > 0:
		var after: Dictionary = camp.profile()
		after.id = fighter_id + "_after_camp"
		roster.add(after)
		print(_fights(roster, fighter_id, after.id, opponent, fights))


func _report(before: Dictionary, camp: TrainingCamp, reports: Array[Dictionary], library: TrainingLibrary, camp_seed: int) -> String:
	var lines: Array[String] = []
	var names: Array[String] = []
	for r: Dictionary in reports:
		names.append(library.plan(r.plan).name)
	lines.append("Camp: %s, %d weeks (%s), seed %d, age %d, potential %d" % [
		before.name, reports.size(), _runs(names), camp_seed, camp.age, roundi(camp.potential)])
	lines.append("")
	lines.append("Week  Plan                  Done  Skipped  Hurt  Peak fatigue  Sunday fatigue  Biggest gains")
	var injuries: Array[String] = []
	for i in reports.size():
		var r: Dictionary = reports[i]
		lines.append("%4d  %-20s  %4d  %7d  %4d  %12d  %14d  %s" % [i + 1, library.plan(r.plan).name, r.done, r.skipped,
			r.injured, roundi(r.fatigue_peak), roundi(r.fatigue_end), _top_gains(r.gains, 3)])
		for injury: Dictionary in r.injuries:
			injuries.append("  Week %d, %s: hurt in %s, out %d days" % [i + 1, TrainingCamp.DAY_NAMES[injury.day],
				library.session(injury.session).name, injury.days_out])
	lines.append("")
	lines.append("Injuries:" if not injuries.is_empty() else "Injuries: none")
	lines.append_array(injuries)
	lines.append("")
	lines.append("Stats that moved (start → end):")
	var after: Dictionary = camp.profile()
	var moved: Array = []
	for id: String in STAT_NAMES:
		var start: float = float(before.get("stats", {}).get(id, FighterState.DEFAULT_STAT))
		var end: float = camp.stat(id)
		if absf(end - start) >= 0.05:
			moved.append([id, start, end])
	moved.sort_custom(func(a: Array, b: Array) -> bool: return a[2] - a[1] > b[2] - b[1])
	for m: Array in moved:
		lines.append("  %-20s %5.1f → %5.1f  (%+.1f)  %s → %s%s" % [STAT_NAMES[m[0]], m[1], m[2], m[2] - m[1],
			_grade(m[1]), _grade(m[2]), "  (fights see %d → %d)" % [int(m[1]), int(m[2])] if int(m[1]) != int(m[2]) else ""])
	if moved.is_empty():
		lines.append("  none")
	lines.append("")
	var style_bits: Array[String] = []
	for leaning in StyleLeanings.LEANINGS:
		var start: float = float(before.get("style", {}).get(leaning, 0.0))
		var end: float = float(after.style[leaning])
		if absf(end - start) >= 0.05:
			style_bits.append("%s %+.1f → %.1f" % [leaning.capitalize(), end - start, end])
	lines.append("Style: " + (", ".join(style_bits) if not style_bits.is_empty() else "no change"))
	var traits: Array[String] = []
	for t in camp.style.traits():
		traits.append(StyleLeanings.TRAIT_NAMES[t])
	if not traits.is_empty():
		lines.append("Style traits: " + ", ".join(traits))
	lines.append("Fight night: fatigue %d (%s)%s" % [roundi(camp.fatigue), _freshness(camp.fatigue),
		", still hurt (%d days)" % camp.injured_days if camp.injured_days > 0 else ""])
	lines.append("  (Fatigue and injuries don't carry into fights yet: that comes after the playtest, docs/02 §3.5.)")
	return "\n".join(lines)


func _fights(roster: FighterLibrary, before_id: String, after_id: String, opponent: String, fights: int) -> String:
	var actions := ActionLibrary.load_dir()
	var wins: Array[int] = [0, 0]
	for i in 2:
		var id: String = before_id if i == 0 else after_id
		for n in fights:
			if FightSummary.run(n + 1, roster, actions, id, opponent).winner == "red":
				wins[i] += 1
	return "\nAgainst %s, %d fights each (same seeds): before the camp won %.0f%%, after it %.0f%% (%+.0f%%)" % [
		roster.profile(opponent).name, fights, 100.0 * wins[0] / fights, 100.0 * wins[1] / fights,
		100.0 * (wins[1] - wins[0]) / fights]


## "7 × Wrestler, 1 × Taper (fight week)"
func _runs(names: Array[String]) -> String:
	var parts: Array[String] = []
	var i: int = 0
	while i < names.size():
		var j: int = i
		while j < names.size() and names[j] == names[i]:
			j += 1
		parts.append("%d × %s" % [j - i, names[i]])
		i = j
	return ", ".join(parts)


func _top_gains(gains: Dictionary, count: int) -> String:
	var ids: Array = gains.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return gains[a] > gains[b])
	var bits: Array[String] = []
	for id: String in ids.slice(0, count):
		bits.append("%s %+.2f" % [STAT_NAMES.get(id, id), gains[id]])
	return ", ".join(bits)


## Letter grades from docs/11 §2.4.
func _grade(value: float) -> String:
	if value >= 80.0:
		return "A+"
	if value >= 72.0:
		return "A"
	if value >= 65.0:
		return "A−"
	if value >= 50.0:
		return "B"
	if value >= 35.0:
		return "C"
	if value >= 20.0:
		return "D"
	return "F"


func _freshness(fatigue: float) -> String:
	if fatigue < 15.0:
		return "fresh"
	if fatigue < TrainingCamp.FATIGUE_FREE:
		return "a little tired"
	return "worn down"


func _process(_delta: float) -> bool:
	return true
