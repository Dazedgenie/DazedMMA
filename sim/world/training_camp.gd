class_name TrainingCamp
extends RefCounted
## A fighter in training (docs/02 §3.5, D125): week plans of sessions from
## data/sessions and data/week_plans turn into attribute points, fatigue, style
## pushes, chin wear and the odd camp injury. Pure logic and seeded, so the same
## fighter, plans and seed always train the same way.
##
## Every session auto-resolves at quality 1.0 (A5); a session the player plays as
## a minigame passes its score (0.8–1.5) in `played`. The minigames come later.
##
## Usage: TrainingCamp.new(profile, seed).run_camp(["wrestler", …, "taper"]), then
## profile() is the fighter@1 profile with the trained stats and style.

## A week: Monday to Saturday, morning and evening; Sunday is always off.
const DAYS: int = 6
const SLOTS_PER_DAY: int = 2
const DAY_NAMES: Array[String] = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

## A session the player doesn't play scores this (A5: the baseline, never a gate) …
const AUTO_QUALITY: float = 1.0
## … and a played one scores within these (bad play still 0.8, great play 1.5).
const PLAYED_MIN: float = 0.8
const PLAYED_MAX: float = 1.5

## XP for one point: XP_PER_POINT × e^(stat / XP_CURVE), so every 25 points costs e (≈2.7) times as much.
const XP_PER_POINT: float = 10.0
const XP_CURVE: float = 25.0
## Near the fighter's potential it slows down more: × e^(points past (potential − CEILING_SOFT) / CEILING_SCALE).
const CEILING_SOFT: float = 10.0
const CEILING_SCALE: float = 8.0
## Without `potential` or `age` in the profile (docs/09 fighter@1).
const DEFAULT_POTENTIAL: float = 75.0
const DEFAULT_AGE: int = 25
## Gifts that raise a stat's ceiling (docs/11 §4.3).
const GIFT_CEILINGS := {
	"freak_athlete": { "speed": 10.0, "strength": 10.0 },
	"heavy_hands": { "power": 10.0 },
}
## Fast learner gift: training XP × this.
const FAST_LEARNER: float = 1.15
## Coachable +100 learns × 1.25, Stubborn −100 × 0.75 (docs/11 §4.1).
const COACHABLE_PER_POINT: float = 1.0 / 400.0
## [up to this age, XP ×]: young fighters learn fastest.
const AGE_LEARNING: Array = [[23, 1.2], [29, 1.0], [33, 0.8], [999, 0.6]]
## Each stat's points past this in one camp count half (the soft cap per camp, D13).
const CAMP_SOFT_CAP: float = 3.0
const PAST_SOFT_CAP: float = 0.5
## A week plan that trains stats from this many attribute groups (data/enums/stats) gets × VARIETY_BONUS.
const VARIETY_GROUPS: int = 3
const VARIETY_BONUS: float = 1.1

## Fatigue 0–100. A session adds its `fatigue` × (FATIGUE_RECOVERY_BASE − Recovery / 200), so ×1 at Recovery 50;
## rest and recovery sessions (negative fatigue) take theirs off as it is.
const FATIGUE_RECOVERY_BASE: float = 1.25
## Each night keeps this share of the fatigue, and Sunday keeps this share again.
const NIGHT_KEEPS: float = 0.6
const SUNDAY_KEEPS: float = 0.4
## XP is full up to FATIGUE_FREE, then falls in a line to × FATIGUE_FLOOR at 100.
const FATIGUE_FREE: float = 40.0
const FATIGUE_FLOOR: float = 0.5

## Injury chance per session: injury_risk × (1 + (fatigue / INJURY_FATIGUE)²) × (INJURY_DURABILITY_BASE − Durability / 100).
const INJURY_FATIGUE: float = 30.0
const INJURY_DURABILITY_BASE: float = 1.5
## A camp injury keeps the fighter out this many days (Sundays count); Slow healer × SLOW_HEALER.
const INJURY_DAYS_MIN: int = 2
const INJURY_DAYS_MAX: int = 10
const SLOW_HEALER: float = 1.5
## Party animals skip sessions: chance = −Discipline / 400 (25% at −100); disciplined fighters never do.
const SKIP_PER_PARTY_POINT: float = 1.0 / 400.0

## Style pushes (docs/11 §4.2): a session's own `leanings` per session, plus the week's instruction
## (a gameplan) at its leanings / INSTRUCTION_DIVISOR per session ("Push the pace" all week ≈ +3 Pace).
const INSTRUCTION_DIVISOR: float = 160.0
## Coachable +100 changes style × 1.5, Stubborn −100 × 0.5; from STYLE_SETS_AT a style sets: × STYLE_SET.
const STYLE_COACHABLE_PER_POINT: float = 1.0 / 200.0
const STYLE_SETS_AT: int = 30
const STYLE_SET: float = 0.4

## What happened to one slot.
const DONE := "done"
const SKIPPED := "skipped"
const INJURED := "injured"
const RESTED := "rested"

const STATS_PATH := "res://data/enums/stats.json"

var stats: Dictionary = {}  # stat id → 0–100 (fractions kept, so small gains add up)
var style: StyleLeanings
var fatigue: float = 0.0
var injured_days: int = 0
var age: int
var potential: float

var _profile: Dictionary
var _library: TrainingLibrary
var _rng := RandomNumberGenerator.new()
var _camp_gains: Dictionary = {}  # stat id → points gained this camp
var _groups: Dictionary = {}  # stat id → attribute group, from data/enums/stats
var _instructions: Dictionary = {}  # gameplan id → its leanings


func _init(profile_in: Dictionary, camp_seed: int, library: TrainingLibrary = null) -> void:
	_profile = profile_in.duplicate(true)
	_library = library if library != null else TrainingLibrary.shared()
	_rng.seed = camp_seed
	for id: String in _profile.get("stats", {}):
		stats[id] = float(_profile.stats[id])
	style = StyleLeanings.new(_profile.get("style", {}))
	age = int(_profile.get("age", DEFAULT_AGE))
	potential = float(_profile.get("potential", DEFAULT_POTENTIAL))
	var enum_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(STATS_PATH))
	if enum_data is Dictionary:
		_groups = enum_data.get("values", {})


func stat(id: String) -> float:
	return float(stats.get(id, FighterState.DEFAULT_STAT))


## A new camp: the soft cap per camp starts again.
func start_camp() -> void:
	_camp_gains.clear()


## Runs a camp of these week plans (data/week_plans ids, one per week) and returns each week's report.
func run_camp(plan_ids: Array[String]) -> Array[Dictionary]:
	start_camp()
	var weeks: Array[Dictionary] = []
	for id in plan_ids:
		weeks.append(run_week(id))
	return weeks


## One week of a plan. `played` maps a slot (0–11: day × 2 + slot) to the minigame score it got.
## Returns what happened: each slot, the points each stat gained, style pushes, fatigue, injuries.
func run_week(plan_id: String, played: Dictionary = {}) -> Dictionary:
	var plan: Dictionary = _library.plan(plan_id)
	var week := {
		"plan": plan_id, "slots": [], "gains": {}, "leanings": {}, "injuries": [],
		"done": 0, "skipped": 0, "injured": 0, "chin_wear": 0.0,
		"fatigue_start": fatigue, "fatigue_peak": fatigue, "fatigue_end": 0.0,
	}
	var variety: float = VARIETY_BONUS if _groups_trained(plan) >= VARIETY_GROUPS else 1.0
	var instruction: Dictionary = _instruction(plan.get("instruction"))
	for day in DAYS:
		for slot in SLOTS_PER_DAY:
			var index: int = day * SLOTS_PER_DAY + slot
			var outcome: String = _run_slot(plan.days[day][slot], day, float(played.get(index, AUTO_QUALITY)), variety, instruction, week)
			week.slots.append({ "day": day, "slot": slot, "session": plan.days[day][slot], "result": outcome, "fatigue": fatigue })
			week.fatigue_peak = maxf(week.fatigue_peak, fatigue)
		fatigue *= NIGHT_KEEPS
		injured_days = maxi(0, injured_days - 1)
	fatigue *= SUNDAY_KEEPS
	injured_days = maxi(0, injured_days - 1)
	week.fatigue_end = fatigue
	return week


## The fighter@1 profile with the trained stats and style (fractions kept to 2 places; fights read whole points).
func profile() -> Dictionary:
	var out: Dictionary = _profile.duplicate(true)
	out.template = null
	var trained: Dictionary = {}
	for id: String in stats:
		trained[id] = snappedf(stats[id], 0.01)
	out.stats = trained
	var leanings: Dictionary = {}
	for leaning in StyleLeanings.LEANINGS:
		leanings[leaning] = snappedf(style.value(leaning), 0.01)
	out.style = leanings
	return out


## XP for one more point of this stat at its current value.
func xp_per_point(id: String) -> float:
	var v: float = stat(id)
	return XP_PER_POINT * exp(v / XP_CURVE) * exp(maxf(0.0, v - (ceiling(id) - CEILING_SOFT)) / CEILING_SCALE)


## Where this stat's growth slows right down: potential, plus any gift for it.
func ceiling(id: String) -> float:
	var out: float = potential
	for gift: Variant in _profile.get("gifts", []):
		out += float(GIFT_CEILINGS.get(gift, {}).get(id, 0.0))
	return out


## Training XP × this, from age, Coachable and the Fast learner gift.
func learning() -> float:
	var out: float = 1.0 + float(_profile.get("personality", {}).get("coachable", 0.0)) * COACHABLE_PER_POINT
	for entry: Array in AGE_LEARNING:
		if age <= entry[0]:
			out *= entry[1]
			break
	if "fast_learner" in _profile.get("gifts", []):
		out *= FAST_LEARNER
	return out


## Style pushes × this, from Coachable and age.
func style_speed() -> float:
	var out: float = 1.0 + float(_profile.get("personality", {}).get("coachable", 0.0)) * STYLE_COACHABLE_PER_POINT
	return out * (STYLE_SET if age >= STYLE_SETS_AT else 1.0)


## XP × this at the current fatigue.
func fatigue_factor() -> float:
	return 1.0 - (1.0 - FATIGUE_FLOOR) * clampf((fatigue - FATIGUE_FREE) / (100.0 - FATIGUE_FREE), 0.0, 1.0)


## The chance this session injures the fighter, at the fatigue they're doing it at.
func injury_chance(session: Dictionary) -> float:
	var tired: float = fatigue / INJURY_FATIGUE
	return float(session.injury_risk) * (1.0 + tired * tired) * (INJURY_DURABILITY_BASE - stat("durability") / 100.0)


func skip_chance() -> float:
	return maxf(0.0, -float(_profile.get("personality", {}).get("discipline", 0.0))) * SKIP_PER_PARTY_POINT


func _run_slot(id: String, day: int, quality: float, variety: float, instruction: Dictionary, week: Dictionary) -> String:
	var session: Dictionary = _library.session(id)
	var trains: bool = float(session.xp) > 0.0
	if injured_days > 0 and (trains or float(session.fatigue) > 0.0):
		_add_fatigue(float(_library.session("rest").fatigue))  # Out hurt: the slot becomes rest.
		week.injured += 1
		return INJURED
	if trains and _rng.randf() < skip_chance():
		week.skipped += 1
		return SKIPPED
	_add_fatigue(float(session.fatigue))
	if not trains:
		return RESTED
	week.done += 1
	if float(session.injury_risk) > 0.0 and _rng.randf() < injury_chance(session):
		var days: int = _rng.randi_range(INJURY_DAYS_MIN, INJURY_DAYS_MAX)
		if "slow_healer" in _profile.get("flaws", []):
			days = ceili(days * SLOW_HEALER)
		injured_days = maxi(injured_days, days)
		week.injuries.append({ "day": day, "session": id, "days_out": days })
	var mult: float = clampf(quality, PLAYED_MIN, PLAYED_MAX) * learning() * fatigue_factor() * variety
	for stat_id: String in session.trains:
		var points: float = float(session.xp) * float(session.trains[stat_id]) * mult / xp_per_point(stat_id)
		if _camp_gains.get(stat_id, 0.0) >= CAMP_SOFT_CAP:
			points *= PAST_SOFT_CAP
		stats[stat_id] = minf(100.0, stat(stat_id) + points)
		_camp_gains[stat_id] = _camp_gains.get(stat_id, 0.0) + points
		week.gains[stat_id] = week.gains.get(stat_id, 0.0) + points
	var wear: float = float(session.get("chin_wear", 0.0))
	if wear > 0.0:
		stats["chin"] = maxf(0.0, stat("chin") - wear)
		week.chin_wear += wear
	var speed: float = style_speed()
	for leaning: String in session.get("leanings", {}):
		_push(leaning, float(session.leanings[leaning]) * speed, week)
	for leaning: String in instruction:
		_push(leaning, float(instruction[leaning]) / INSTRUCTION_DIVISOR * speed, week)
	return DONE


func _add_fatigue(amount: float) -> void:
	if amount > 0.0:
		amount *= FATIGUE_RECOVERY_BASE - stat("recovery") / 200.0
	fatigue = clampf(fatigue + amount, 0.0, 100.0)


func _push(leaning: String, amount: float, week: Dictionary) -> void:
	style.push(leaning, amount)
	week.leanings[leaning] = week.leanings.get(leaning, 0.0) + amount


## How many attribute groups (Physical, Striking …) the plan's sessions train.
func _groups_trained(plan: Dictionary) -> int:
	var groups: Dictionary = {}
	for day: Array in plan.days:
		for id: String in day:
			for stat_id: String in _library.session(id).trains:
				groups[_groups.get(stat_id, stat_id)] = true
	return groups.size()


func _instruction(gameplan_id: Variant) -> Dictionary:
	if gameplan_id == null or gameplan_id == "":
		return {}
	if not _instructions.has(gameplan_id):
		_instructions[gameplan_id] = Gameplan.load_id(gameplan_id).leanings
	return _instructions[gameplan_id]
