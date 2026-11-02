class_name WorldCheck
extends RefCounted
## The 30-year check (docs/03 §12.9, D359; A10's long-run validation): a career's world played YEARS years, with a
## stand-in of his own fighting through them, measured every SNAPSHOT_YEARS and held to the bounds below. Kyle
## (2026-11-02) picked a 10-defence reign about once a decade across the divisions ("About one a decade, any division"),
## reigns ended by both closer title fights and the best men fading after 34 ("Both a little"), retired men kept only when
## notable ("Notable ones and the last 5 years"), the check as a test on every PR ("A test on every PR"), a stand-in
## career through it ("Yes, a stand-in career too") and divisions biggest in the middle ("Most at lightweight and
## welter").
##
## The stand-in (stand_in_week) is his fighter played by rule: he takes the offers as they come (a step up, a title
## shot or an eliminator first), turns pro as soon as he can, asks for a step up now and then, and wins STAND_IN_WINS of
## his fights by decision; his camp weeks are weeks on his plan. The test (tests/sim/world/test_world_check.gd) and the tool
## (tools/world_check.gd) both run it.
##
## Pure (D100): the same career seed plays the same 30 years.

const YEARS: int = 30
const SNAPSHOT_YEARS: int = 5
## The stand-in's share of fights won, and how often (a week he can) he asks for a step up.
const STAND_IN_WINS: float = 0.65
const STAND_IN_ASKS: float = 0.25

## The bounds (each snapshot unless it says the end): active men in the world, and pros in each division.
const ACTIVE: Array[int] = [550, 800]
const PROS_IN_A_DIVISION: Array[int] = [45, 140]
## The best man's average stat, and the share of belts vacant at once at most.
const BEST: Array[float] = [72.0, 90.0]
const VACANT_SHARE: float = 0.25
## A world organisation champion's defences, on average over the reigns that have ended (Kyle, 2026-11-02: "champs
## averaging 2-4 defenses ... with the chance at less and more possible").
const WORLD_DEFENCES: Array[float] = [2.0, 4.0]
## Reigns of 10 defences or more in the whole run, across every belt (5 to 8 expected in 30 years), and the most
## defences in one reign.
const LONG_REIGN: int = 10
const LONG_REIGNS_MAX: int = 12
const MOST_DEFENCES: int = 28
## Every world organisation belt changes hands at least this often in the run (champions turn over).
const WORLD_CHAMPIONS_MIN: int = 4
## Retired pros' median age when they stop, and the oldest active pro.
const RETIRED_MEDIAN: Array[float] = [30.0, 39.0]
const OLDEST: float = 46.0
## The most fights on one active pro's record, and the save at the end (KB).
const BUSIEST: int = 80
const SAVE_KB: int = 1500


## Plays `years` of the world from the career's week, the stand-in fighting through them when `stand_in` (else the world
## alone). `on_year` is called after each year with (year, report so far). Returns the report: { years, seed, snapshots
## ([measure()]), end (measure() at the end), stand_in ({ record, fights, rung, ...}) }.
static func play(c: Career, years: int = YEARS, stand_in: bool = true, on_year: Callable = Callable()) -> Dictionary:
	var report: Dictionary = { "years": years, "seed": c.career_seed, "snapshots": [], "stand_in": {} }
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([c.career_seed, "world check"])
	var start: int = c.week
	for year in years:
		var to: int = start + (year + 1) * Career.WEEKS_PER_YEAR
		if stand_in:
			while c.week < to:
				stand_in_week(c, rng)
		else:
			c.week = to
		c.world()
		if (year + 1) % SNAPSHOT_YEARS == 0 or year + 1 == years:
			var m: Dictionary = measure(c)
			m.year = year + 1
			(report.snapshots as Array).append(m)
		if on_year.is_valid():
			on_year.call(year + 1, report)
	report.end = (report.snapshots as Array).back() if not (report.snapshots as Array).is_empty() else measure(c)
	report.stand_in = { "record": c.record_text(true), "amateur": c.record_text(false), "fights": c.fights.size(),
		"age": c.age(), "promotion": String(c.world().him.get("promotion", "")), "rung": Climb.rung(c.world()),
		"belt": Titles.held_by(c.world(), Career.FIGHTER_ID) }
	return report


## One step of the stand-in: a fight night if he's booked (the camp's weeks go by, then a result), else a week on his
## plan, offers taken as they come.
static func stand_in_week(c: Career, rng: RandomNumberGenerator) -> void:
	if not c.booked.is_empty():
		while c.week < int(c.booked.week):
			c.run_week()  # His camp's weeks, on his plan.
		var result: String = "win" if rng.randf() < STAND_IN_WINS else "loss"
		c.finish_fight({ "result": result, "method": "Decision (unanimous)", "round": 3 })
		if not c.booked.is_empty() and c.week >= int(c.booked.week):
			return  # A tournament's next round, the same day.
		c.end_week()
		return
	if Matchmaker.can_turn_pro(c):
		c.turn_pro()
	if Climb.can_ask(c) and rng.randf() < STAND_IN_ASKS:
		c.ask_step_up()
	c.run_week()
	if c.offers.is_empty():
		return
	var pick: Dictionary = c.offers[0]
	for o: Dictionary in c.offers:
		if String(o.get("step", "")) != "" or o.has("title") or o.has("eliminator"):
			pick = o
			break
	c.accept(String(pick.id))


## The world as it stands: men, divisions, belts, ages, records and the save.
static func measure(c: Career) -> Dictionary:
	var w: World = c.world()
	var active: Array = w.men.values().filter(func(m: Dictionary) -> bool: return World.active(m))
	var pros: Dictionary = {}
	for d: String in Weight.ids():
		pros[d] = 0
	var best: float = 0.0
	var busiest: int = 0
	var oldest: float = 0.0
	for m: Dictionary in active:
		best = maxf(best, w.average(m))
		if bool(m.pro):
			var d: String = World.division_of(m, w.played)
			pros[d] = int(pros.get(d, 0)) + 1
			busiest = maxi(busiest, int(m.record.win) + int(m.record.loss) + int(m.record.get("draw", 0)))
			oldest = maxf(oldest, World.age_of(m, w.played))
	var retired_ages: Array = []
	for m: Dictionary in w.men.values():
		if not World.active(m) and bool(m.get("pro", false)):
			retired_ages.append(World.age_of(m, int(m.retired)))
	retired_ages.sort()
	var long_reigns: int = 0
	var most: int = 0
	var reigns: int = 0
	for id: String in w.reigns:
		for r: Array in w.reigns[id]:
			reigns += 1
			most = maxi(most, int(r[3]))
			if int(r[3]) >= LONG_REIGN:
				long_reigns += 1
	var world_defences: Array = []
	for id: String in w.reigns:
		for r: Array in w.reigns[id]:
			if History.belt_rank(w, String(r[0])) == Promotions.MAJOR:
				world_defences.append(int(r[3]))
	world_defences.sort()
	var world_total: int = 0
	for d: int in world_defences:
		world_total += d
	var vacant: int = 0
	var world_champions: Dictionary = {}
	for k: String in w.titles:
		var b: Dictionary = w.titles[k]
		if String(b.champion) == "":
			vacant += 1
		else:
			most = maxi(most, int(b.defences))
			if int(b.defences) >= LONG_REIGN:
				long_reigns += 1
		if History.belt_rank(w, k) == Promotions.MAJOR:
			world_champions[k.get_slice(":", 1)] = History.line_of(w, k).size()
	return { "active": active.size(), "retired_kept": w.men.size() - active.size(), "pros": pros, "best": snappedf(best, 0.1),
		"belts": w.titles.size(), "vacant": vacant, "reigns_ended": reigns, "long_reigns": long_reigns, "most_defences": most,
		"world_champions": world_champions,
		"world_median_defences": world_defences[world_defences.size() / 2] if not world_defences.is_empty() else 0,
		"world_mean_defences": snappedf(float(world_total) / maxf(1.0, float(world_defences.size())), 0.01), "legends": History.legends(w).size(),
		"retired_median": snappedf(retired_ages[retired_ages.size() / 2], 0.1) if not retired_ages.is_empty() else 0.0,
		"oldest": snappedf(oldest, 0.1), "busiest": busiest, "save_kb": JSON.stringify(c.to_dict()).length() / 1024 }


## What's out of bounds in a report, one line each ([] when the world stayed healthy).
static func problems(report: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for s: Dictionary in report.get("snapshots", []):
		var at: String = "year %d: " % int(s.year)
		if int(s.active) < ACTIVE[0] or int(s.active) > ACTIVE[1]:
			out.append(at + "%d active men (%d to %d)" % [int(s.active), ACTIVE[0], ACTIVE[1]])
		for d: String in s.pros:
			if int(s.pros[d]) < PROS_IN_A_DIVISION[0] or int(s.pros[d]) > PROS_IN_A_DIVISION[1]:
				out.append(at + "%d pros at %s (%d to %d)" % [int(s.pros[d]), d, PROS_IN_A_DIVISION[0], PROS_IN_A_DIVISION[1]])
		if float(s.best) < BEST[0] or float(s.best) > BEST[1]:
			out.append(at + "the best man averages %.1f (%.0f to %.0f)" % [float(s.best), BEST[0], BEST[1]])
		if float(s.vacant) > VACANT_SHARE * float(s.belts):
			out.append(at + "%d of %d belts vacant" % [int(s.vacant), int(s.belts)])
		if float(s.oldest) > OLDEST:
			out.append(at + "an active pro aged %.1f (%.0f at most)" % [float(s.oldest), OLDEST])
		if int(s.busiest) > BUSIEST:
			out.append(at + "a record of %d fights (%d at most)" % [int(s.busiest), BUSIEST])
		if float(s.retired_median) > 0.0 and (float(s.retired_median) < RETIRED_MEDIAN[0] or float(s.retired_median) > RETIRED_MEDIAN[1]):
			out.append(at + "retired pros' median age %.1f (%.0f to %.0f)" % [float(s.retired_median), RETIRED_MEDIAN[0], RETIRED_MEDIAN[1]])
	var end: Dictionary = report.get("end", {})
	if end.is_empty():
		return out
	if int(end.long_reigns) > LONG_REIGNS_MAX:
		out.append("%d reigns of %d+ defences (%d at most)" % [int(end.long_reigns), LONG_REIGN, LONG_REIGNS_MAX])
	if int(end.most_defences) > MOST_DEFENCES:
		out.append("a reign of %d defences (%d at most)" % [int(end.most_defences), MOST_DEFENCES])
	if int(report.get("years", YEARS)) >= YEARS:
		for d: String in end.world_champions:
			if int(end.world_champions[d]) < WORLD_CHAMPIONS_MIN:
				out.append("the world %s belt had %d champions (%d at least)" % [d, int(end.world_champions[d]), WORLD_CHAMPIONS_MIN])
	if int(report.get("years", YEARS)) >= YEARS and (float(end.get("world_mean_defences", 0.0)) < WORLD_DEFENCES[0]
			or float(end.get("world_mean_defences", 0.0)) > WORLD_DEFENCES[1]):
		out.append("world champions averaged %.1f defences (%.0f to %.0f)" % [float(end.get("world_mean_defences", 0.0)),
			WORLD_DEFENCES[0], WORLD_DEFENCES[1]])
	if int(end.save_kb) > SAVE_KB:
		out.append("the save is %d KB (%d at most)" % [int(end.save_kb), SAVE_KB])
	return out


## The report as text, for the tool and a failing test.
static func report_text(report: Dictionary) -> String:
	var lines: PackedStringArray = ["The world over %d years (seed %d%s)" % [int(report.years), int(report.seed),
		(", %d ms a year" % int(report.ms_per_year)) if report.has("ms_per_year") else ""]]
	for s: Dictionary in report.get("snapshots", []):
		lines.append("Year %d: %d active men (%d retired kept), pros %s, best %.1f; %d/%d belts vacant, %d reigns ended, %d of %d+ defences, most %d; world champions %s (%.1f defences on average, median %d); %d legends; retired at %.1f, oldest %.1f, busiest record %d; save %d KB" % [
			int(s.year), int(s.active), int(s.retired_kept), JSON.stringify(s.pros), float(s.best), int(s.vacant), int(s.belts),
			int(s.reigns_ended), int(s.long_reigns), LONG_REIGN, int(s.most_defences), JSON.stringify(s.world_champions),
			float(s.get("world_mean_defences", 0.0)), int(s.world_median_defences), int(s.legends), float(s.retired_median), float(s.oldest), int(s.busiest), int(s.save_kb)])
	if not (report.get("stand_in", {}) as Dictionary).is_empty():
		var si: Dictionary = report.stand_in
		lines.append("The stand-in: %d fights, amateur %s, pro %s, aged %d, on rung %d (%s)%s" % [int(si.fights), String(si.amateur),
			String(si.record), int(si.age), int(si.rung), String(si.promotion), ", champion" if String(si.belt) != "" else ""])
	var p: Array[String] = problems(report)
	lines.append("Healthy." if p.is_empty() else "Out of bounds:\n- " + "\n- ".join(p))
	return "\n".join(lines)
