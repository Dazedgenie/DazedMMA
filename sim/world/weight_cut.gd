class_name WeightCut
extends RefCounted
## The weight cut and the weigh-in (docs/03 §13.9, D405). A pro fight's weigh-in is the day before (docs/08), so in fight
## week he sheds water to make the limit and puts most of it back by fight night. How hard he cuts is one pick in the
## camp (Kyle, 2026-11-02: "One pick now, planner later"): light, normal, hard or extreme.
##
##   the cut      what he walks around at over the limit comes off: up to WATER (a share of his walking weight) as water in
##                fight week, the rest dieted off in camp. He gets REGAIN of the water back by fight night, so a harder
##                cut makes him heavier on the night. A man with less to lose than the level's share sheds only that much.
##   what it costs  TANK_COST of his gas tank and CHIN_COST Chin, both scaled by how much of the level's share he really
##                shed (a light cut costs nothing)
##   what it wins  STRENGTH_PER_KG Strength for each whole kg he outweighs the other man on fight night, up to
##                STRENGTH_MAX (Strength drives damage and the clinch)
##   missing it   MISS_CHANCE by level (× HARD_CUT_MISS with the Hard cut flaw), by MISS_BY kg; the fight goes ahead, a
##                FINE of his purse goes to the other man, and a man who missed can't win a belt (a champion who misses is
##                stripped at the scale)
##
## The other man cuts too: his corner picks a level at OPP_LEVEL_ODDS. Amateurs weigh in on the day at what they walk
## around at (docs/08), so there's no cut: of() is {} for an amateur fight or a tournament.
## Pure and seeded: the same booking and pick always give the same weigh-in. Every number is a first guess.

const LIGHT := "light"
const NORMAL := "normal"
const HARD := "hard"
const EXTREME := "extreme"
const LEVELS: Array[String] = [LIGHT, NORMAL, HARD, EXTREME]
const NAMES := { "light": "Light", "normal": "Normal", "hard": "Hard", "extreme": "Extreme" }
## What he picks to start with.
const DEFAULT := NORMAL
## The most water he sheds in fight week, a share of what he walks around at.
const WATER := { "light": 0.03, "normal": 0.06, "hard": 0.09, "extreme": 0.12 }
## The share of the water he gets back by fight night.
const REGAIN: float = 0.9
## A full cut at each level costs this share of his gas tank, and this much Chin, for the fight.
const TANK_COST := { "light": 0.0, "normal": 0.03, "hard": 0.08, "extreme": 0.15 }
const CHIN_COST := { "light": 0.0, "normal": 0.0, "hard": 3.0, "extreme": 8.0 }
## The chance he misses weight at each level, × HARD_CUT_MISS with the Hard cut flaw; by MISS_BY kg when he does.
const MISS_CHANCE := { "light": 0.0, "normal": 0.02, "hard": 0.06, "extreme": 0.15 }
const HARD_CUT_MISS: float = 1.5
const HARD_CUT_FLAW := "hard_cut"
const MISS_BY: Array[float] = [0.3, 1.5]
## The size edge on fight night: Strength for each whole kg he's heavier than the other man, up to STRENGTH_MAX.
const STRENGTH_PER_KG: float = 1.0
const STRENGTH_MAX: float = 6.0
## Missing weight: this share of the missed man's purse goes to the other man.
const FINE: float = 0.2
## How the other man's corner picks his cut: light, normal, hard, extreme.
const OPP_LEVEL_ODDS: Array[float] = [0.15, 0.5, 0.25, 0.1]


## The weigh-in for the booked fight: { him: side, opp: side, edge: Strength he gains (0 when the other man is the
## heavier), opp_edge }, where a side is { cut (level), walk_kg, limit_kg, water_kg, scale_kg, made, night_kg, tank_cost,
## chin_cost, miss_chance }. {} for an amateur fight, a tournament or nobody booked.
static func of(c: Career) -> Dictionary:
	var him: Dictionary = c.booked_opponent()
	if him.is_empty() or not bool(c.booked.get("pro", c.pro)) or c.booked.get("tournament") is Dictionary:
		return {}
	var d: Dictionary = Weight.division(c.division_now())
	if d.is_empty():
		return {}
	var limit: float = float(d.limit_kg)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([c.career_seed, String(him.get("id", "")), int(c.booked.get("week", 0)), "weigh-in"])
	# Every roll is made every time, in the same order, so changing your pick never changes his.
	var my_miss: float = rng.randf()
	var my_by: float = rng.randf()
	var his_level: float = rng.randf()
	var his_miss: float = rng.randf()
	var his_by: float = rng.randf()
	var mine: Dictionary = side(c.weight_kg(), limit, level_of(c), _flawed(c.profile()), my_miss, my_by)
	var his_walk: float = Weight.walk_kg(him.get("frame", {}), float(him.get("age", 25)))
	var theirs: Dictionary = side(his_walk, limit, opponent_level(his_level), _flawed(him), his_miss, his_by)
	return { "him": mine, "opp": theirs, "edge": edge(float(mine.night_kg), float(theirs.night_kg)),
		"opp_edge": edge(float(theirs.night_kg), float(mine.night_kg)) }


## The cut you picked for the booked fight (`booked.cut`), DEFAULT until you pick one.
static func level_of(c: Career) -> String:
	var level: String = String(c.booked.get("cut", DEFAULT))
	return level if level in LEVELS else DEFAULT


## One man's cut and weigh-in: walking at `walk` kg to a `limit` kg limit at `level`, with the two 0–1 rolls for missing
## weight and by how much.
static func side(walk: float, limit: float, level: String, flawed: bool, miss_roll: float, by_roll: float) -> Dictionary:
	var over: float = maxf(0.0, walk - limit)
	var water: float = minf(over, walk * float(WATER[level]))
	var full: float = walk * float(WATER[level])
	var used: float = water / full if full > 0.0 else 0.0  # How much of the level's share he really shed.
	var chance: float = float(MISS_CHANCE[level]) * (HARD_CUT_MISS if flawed else 1.0) if water > 0.0 else 0.0
	var made: bool = miss_roll >= chance
	var scale: float = limit if made else limit + lerpf(MISS_BY[0], MISS_BY[1], by_roll)
	return { "cut": level, "walk_kg": snappedf(walk, 0.1), "limit_kg": limit, "water_kg": snappedf(water, 0.1),
		"scale_kg": snappedf(minf(walk, scale), 0.1), "made": made,
		"night_kg": snappedf(minf(walk, scale + water * REGAIN), 0.1),
		"tank_cost": snappedf(float(TANK_COST[level]) * used, 0.001), "chin_cost": snappedf(float(CHIN_COST[level]) * used, 0.1),
		"miss_chance": snappedf(chance, 0.001) }


## The Strength a man `mine` kg on fight night gains over one `theirs` kg: STRENGTH_PER_KG a whole kg, up to STRENGTH_MAX.
static func edge(mine: float, theirs: float) -> float:
	return clampf(floorf(maxf(0.0, mine - theirs) + 0.0001) * STRENGTH_PER_KG, 0.0, STRENGTH_MAX)


## The other man's cut from a 0–1 roll (OPP_LEVEL_ODDS).
static func opponent_level(roll: float) -> String:
	var at: float = 0.0
	for i in LEVELS.size():
		at += OPP_LEVEL_ODDS[i]
		if roll < at:
			return LEVELS[i]
	return LEVELS[-1]


## A profile for the fight with a side's cut on it: the tank cost on `condition.tank`, the Chin off, the Strength edge on.
static func apply(profile: Dictionary, s: Dictionary, strength: float) -> void:
	if s.is_empty():
		return
	var condition: Dictionary = profile.get("condition", {}) if profile.get("condition") is Dictionary else {}
	if float(s.tank_cost) > 0.0:
		condition.tank = snappedf(float(condition.get("tank", 1.0)) * (1.0 - float(s.tank_cost)), 0.001)
		profile.condition = condition
	var stats: Dictionary = profile.get("stats", {})
	if float(s.chin_cost) > 0.0:
		stats.chin = maxf(1.0, float(stats.get("chin", FighterState.DEFAULT_STAT)) - float(s.chin_cost))
	if strength > 0.0:
		stats.strength = minf(100.0, float(stats.get("strength", FighterState.DEFAULT_STAT)) + strength)
	profile.stats = stats


## What goes on his record (career@1 fight `weigh_in`): both men's cut, scale weight, made and fight-night weight, and
## the Strength edge.
static func record(w: Dictionary) -> Dictionary:
	if w.is_empty():
		return {}
	return { "cut": w.him.cut, "kg": w.him.scale_kg, "made": w.him.made, "night_kg": w.him.night_kg, "edge": w.edge,
		"opp_cut": w.opp.cut, "opp_kg": w.opp.scale_kg, "opp_made": w.opp.made, "opp_night_kg": w.opp.night_kg,
		"opp_edge": w.opp_edge }


## How a side looks at the scale and what it costs him, in a line ("Drained: 8% of his gas tank and 3 Chin.").
static func cost_text(s: Dictionary) -> String:
	if float(s.get("water_kg", 0.0)) <= 0.0:
		return "Nothing to cut: fresh."
	var tank: int = roundi(100.0 * float(s.tank_cost))
	var chin: float = float(s.chin_cost)
	if tank <= 0 and chin <= 0.0:
		return "An easy cut: fresh."
	var parts: Array[String] = []
	if tank > 0:
		parts.append("%d%% of his gas tank" % tank)
	if chin > 0.0:
		parts.append("%s Chin" % _num(chin))
	return "%s: %s." % ["Drained" if chin > 0.0 else "A little flat", " and ".join(parts)]


## The pick's line in the camp (his weights, what the cut takes off, what it costs and the chance he misses).
static func plan_text(s: Dictionary) -> String:
	if s.is_empty():
		return ""
	var out: String = "He walks around at %s; the limit is %s." % [Weight.kg_text(float(s.walk_kg)), Weight.kg_text(float(s.limit_kg))]
	if float(s.water_kg) <= 0.0:
		return out + " Nothing to cut."
	out += " %s of water in fight week (the rest dieted off in camp), about %s on fight night." % [
		Weight.kg_text(float(s.water_kg)), Weight.kg_text(float(s.night_kg))]
	out += " " + cost_text(s)
	if float(s.miss_chance) > 0.0:
		out += " A %d%% chance he misses weight." % roundi(100.0 * float(s.miss_chance))
	return out


## The weigh-in in lines for the fight night card's summary and the result.
static func lines(w: Dictionary, my_name: String, his_name: String) -> Array[String]:
	var out: Array[String] = []
	if w.is_empty():
		return out
	for pair: Array in [[my_name, w.him], [his_name, w.opp]]:
		var s: Dictionary = pair[1]
		out.append("%s %s%s" % [pair[0], Weight.kg_text(float(s.scale_kg)), "" if s.made else " (MISSED WEIGHT)"])
	if float(w.edge) > 0.0:
		out.append("%s is the bigger man tonight: +%s Strength." % [my_name, _num(float(w.edge))])
	elif float(w.opp_edge) > 0.0:
		out.append("%s is the bigger man tonight: +%s Strength." % [his_name, _num(float(w.opp_edge))])
	return out


static func _flawed(profile: Dictionary) -> bool:
	return HARD_CUT_FLAW in profile.get("flaws", [])


static func _num(x: float) -> String:
	return ("%.1f" % x).trim_suffix(".0")
