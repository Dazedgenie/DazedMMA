class_name TrainingCamp
extends RefCounted
## A fighter in training (docs/02 §3.5, D125): week plans of sessions from
## data/sessions and data/week_plans turn into attribute points, fatigue, style
## pushes, chin wear and the odd camp injury. Pure logic and seeded, so the same
## fighter, plans and seed always train the same way.
##
## Every session auto-resolves at quality 1.0 (A5); a session the player plays as
## a minigame passes its score (0.8–1.5) in `played`: so far mitt work (MittWork, D137).
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
## 4 (was 10) so a top prospect reaches the top level by 28–29 (D136, docs/02 §3.8).
const XP_PER_POINT: float = 4.0
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
## The body's own curve, for the stats that age (Ageing.DECLINE): it stops answering training soon after 27, so even
## a fighter who trains perfectly peaks physically around 28–29 (D136, Kyle) while skills and Fight IQ keep growing.
const BODY_AGE_LEARNING: Array = [[23, 1.2], [27, 1.0], [30, 0.6], [34, 0.3], [999, 0.1]]
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
## Below this fatigue a fighter is fresh; below FATIGUE_FREE a little tired; past it worn down.
const FRESH_BELOW: float = 15.0

## Injury chance per session: injury_risk × (1 + (fatigue / INJURY_FATIGUE)²) × (INJURY_DURABILITY_BASE − Durability / 100).
const INJURY_FATIGUE: float = 30.0
const INJURY_DURABILITY_BASE: float = 1.5
## A camp injury keeps the fighter out this many days (Sundays count); Slow healer × SLOW_HEALER.
const INJURY_DAYS_MIN: int = 2
const INJURY_DAYS_MAX: int = 10
const SLOW_HEALER: float = 1.5
## Where a session's injury is (its `injury_area`): a healing injury starts the fight hurt there (D135).
const INJURY_AREAS: Array[String] = ["head", "body", "legs"]
## Party animals skip sessions: chance = −Discipline / 400 (25% at −100); disciplined fighters never do.
const SKIP_PER_PARTY_POINT: float = 1.0 / 400.0

## Style pushes (docs/11 §4.2): a session's own `leanings` per session, plus the week's instruction
## (a gameplan): its strongest leaning moves INSTRUCTION_PUSH a session and the others in proportion
## ("Push the pace" all week ≈ +3 Pace).
const INSTRUCTION_PUSH: float = 0.25
## Coachable +100 changes style × 1.5, Stubborn −100 × 0.5; from STYLE_SETS_AT a style sets: × STYLE_SET.
const STYLE_COACHABLE_PER_POINT: float = 1.0 / 200.0
const STYLE_SETS_AT: int = 30
const STYLE_SET: float = 0.4

## Fight night (docs/02 §3.7, D135). The gas tank: full up to TANK_FREE_FATIGUE fatigue, then TANK_PER_FATIGUE less a point
## (fatigue 30 → 90%, 60 → 75%), never under TANK_FLOOR.
const TANK_FREE_FATIGUE: float = 10.0
const TANK_PER_FATIGUE: float = 0.005
const TANK_FLOOR: float = 0.5
## A healing injury starts the fight this hurt in its area for each day it still needs (3 days → 9%).
const HURT_PER_DAY: float = 0.03
## The doctor won't clear a fighter with more than this many days still to heal.
const DOCTOR_MAX_DAYS: int = 7
## Fighting hurt: a chance of WORSEN_BASE + WORSEN_PER_DAY a day still to heal that the injury gets worse,
## adding WORSEN_DAYS_MIN–WORSEN_DAYS_MAX days out after the fight.
const WORSEN_BASE: float = 0.05
const WORSEN_PER_DAY: float = 0.01
const WORSEN_DAYS_MIN: int = 7
const WORSEN_DAYS_MAX: int = 28
## What the doctor says on fight night.
const FIT := "fit"
const CLEARED_HURT := "cleared_hurt"
const NOT_CLEARED := "not_cleared"

## What happened to one slot.
const DONE := "done"
const SKIPPED := "skipped"
const INJURED := "injured"
const RESTED := "rested"

const STATS_PATH := "res://data/enums/stats.json"
## How the planner and the camp report name each stat (data/enums/stats ids), in the docs/02 §2 order.
const STAT_NAMES := {
	"strength": "Strength", "speed": "Speed", "cardio": "Cardio", "recovery": "Recovery", "durability": "Durability",
	"chin": "Chin", "boxing": "Boxing", "kicking": "Kicking", "clinch_striking": "Clinch striking",
	"striking_defense": "Striking defense", "footwork": "Footwork", "cage_cutting": "Cage cutting", "power": "Power", "takedowns": "Takedowns",
	"takedown_defense": "Takedown defense", "clinch_control": "Clinch control", "scrambles": "Scrambles",
	"top_control": "Top control", "guard": "Guard", "submissions": "Submissions",
	"submission_defense": "Submission defense", "fight_iq": "Fight IQ", "composure": "Composure", "heart": "Heart",
}
## [from this value, letter grade] (docs/11 §2.4), best first.
const GRADES: Array = [[80.0, "A+"], [72.0, "A"], [65.0, "A−"], [50.0, "B"], [35.0, "C"], [20.0, "D"], [0.0, "F"]]

var stats: Dictionary = {}  # stat id → 0–100 (fractions kept, so small gains add up)
var style: StyleLeanings
var fatigue: float = 0.0
var injured_days: int = 0
var injury_area: String = ""  # Where the injury that's healing is ("" when not hurt).
var age: int
var age_years: float  # Age with the weeks since the last birthday: each week run adds one (Ageing, D136).
var potential: float

var _profile: Dictionary
## The head coach's specialty (Coach, D311): a career sets it; "" trains as before.
var coach_specialty: String = ""
var _library: TrainingLibrary
var _rng := RandomNumberGenerator.new()
var _camp_gains: Dictionary = {}  # stat id → points gained this camp
var _groups: Dictionary = {}  # stat id → attribute group, from data/enums/stats
var _instructions: Dictionary = {}  # gameplan id → its leanings
var _forecasting: bool = false  # A forecast copy rolls no dice: nobody skips or gets hurt.
var _unhurt: float = 1.0  # The chance of getting through this week's sessions so far without an injury.


func _init(profile_in: Dictionary, camp_seed: int, library: TrainingLibrary = null) -> void:
	_profile = profile_in.duplicate(true)
	_library = library if library != null else TrainingLibrary.shared()
	_rng.seed = camp_seed
	for id: String in _profile.get("stats", {}):
		stats[id] = float(_profile.stats[id])
	style = StyleLeanings.new(_profile.get("style", {}))
	age = int(_profile.get("age", DEFAULT_AGE))
	age_years = float(age)
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
## With `ends_in_a_fight` the last week is fight week (run_plan's `fight_week`).
func run_camp(plan_ids: Array[String], ends_in_a_fight: bool = false) -> Array[Dictionary]:
	start_camp()
	var weeks: Array[Dictionary] = []
	for i in plan_ids.size():
		weeks.append(run_plan(_library.plan(plan_ids[i]), {}, ends_in_a_fight and i == plan_ids.size() - 1))
	return weeks


## One week of a plan. `played` maps a slot (0–11: day × 2 + slot) to the minigame score it got.
## Returns what happened: each slot, the points each stat gained, style pushes, fatigue, injuries.
func run_week(plan_id: String, played: Dictionary = {}) -> Dictionary:
	return run_plan(_library.plan(plan_id), played)


## One week of a plan given as data (week_plan@1: the planner's own week, D134), as run_week.
## The report also gives `injury_odds` (the chance the week had of at least one injury), `skips_expected`
## and whether it got the `variety` bonus. In `fight_week` the fight is on Saturday evening (D135): the week
## stops after Saturday morning, with no night's sleep or Sunday to recover from it.
func run_plan(plan: Dictionary, played: Dictionary = {}, fight_week: bool = false) -> Dictionary:
	var week := {
		"plan": String(plan.get("id", "")), "slots": [], "gains": {}, "leanings": {}, "injuries": [],
		"done": 0, "skipped": 0, "injured": 0, "chin_wear": 0.0,
		"fatigue_start": fatigue, "fatigue_peak": fatigue, "fatigue_end": 0.0,
		"injury_odds": 0.0, "skips_expected": 0.0, "variety": false, "fight_week": fight_week,
	}
	var variety: float = VARIETY_BONUS if _groups_trained(plan) >= VARIETY_GROUPS else 1.0
	week.variety = variety > 1.0
	_unhurt = 1.0
	var instruction: Dictionary = _instruction(plan.get("instruction"))
	for day in DAYS:
		for slot in SLOTS_PER_DAY:
			if fight_week and day == DAYS - 1 and slot == SLOTS_PER_DAY - 1:
				break  # Saturday evening is the fight.
			var index: int = day * SLOTS_PER_DAY + slot
			var before: float = fatigue
			var outcome: String = _run_slot(plan.days[day][slot], day, float(played.get(index, AUTO_QUALITY)), variety, instruction, week)
			week.slots.append({ "day": day, "slot": slot, "session": plan.days[day][slot], "result": outcome, "fatigue": fatigue, "fatigue_before": before })
			week.fatigue_peak = maxf(week.fatigue_peak, fatigue)
		if fight_week and day == DAYS - 1:
			break
		fatigue *= NIGHT_KEEPS
		_heal(1)
	if not fight_week:
		fatigue *= SUNDAY_KEEPS
		_heal(1)
	week.fatigue_end = fatigue
	week.injury_odds = 1.0 - _unhurt
	week.aged = Ageing.age_a_week(stats, age_years)
	age_years += 1.0 / Ageing.WEEKS_PER_YEAR
	age = int(age_years + 0.0001)
	return week


## What this week would probably do, without changing the camp (the planner shows it, D133): the same
## week on a copy that rolls no dice, so every session is done and nobody gets hurt; `injury_odds` and
## `skips_expected` say how likely the dice were to change that.
func forecast(plan: Dictionary, fight_week: bool = false) -> Dictionary:
	var copy := TrainingCamp.new(profile(), 0, _library)
	copy.coach_specialty = coach_specialty
	copy.stats = stats.duplicate()
	copy.fatigue = fatigue
	copy.injured_days = injured_days
	copy.injury_area = injury_area
	copy.age_years = age_years
	copy.age = age
	copy._camp_gains = _camp_gains.duplicate()
	copy._forecasting = true
	return copy.run_plan(plan, {}, fight_week)


## How the camp sends the fighter in (docs/02 §3.7, D135): `fatigue`, the share of the gas tank they have (`tank`),
## any injury still healing (`injury_area`, `injured_days`) and how hurt it starts them (`hurt`: area → 0–1),
## what the doctor says (FIT, CLEARED_HURT or NOT_CLEARED) and the chance fighting hurt makes it worse.
func fight_night() -> Dictionary:
	var hurt: Dictionary = {}
	var doctor: String = FIT
	if injured_days > 0:
		hurt[injury_area] = minf(1.0, injured_days * HURT_PER_DAY)
		doctor = NOT_CLEARED if injured_days > DOCTOR_MAX_DAYS else CLEARED_HURT
	return { "fatigue": fatigue, "tank": tank_at(fatigue), "injury_area": injury_area if injured_days > 0 else "",
		"injured_days": injured_days, "hurt": hurt, "doctor": doctor,
		"worsen_chance": WORSEN_BASE + WORSEN_PER_DAY * injured_days if injured_days > 0 else 0.0 }


## The fighter@1 profile for the fight: profile() plus the `condition` fight night leaves them in (FighterState reads it).
func fight_profile() -> Dictionary:
	var out: Dictionary = profile()
	var night: Dictionary = fight_night()
	var hurt: Dictionary = {}
	for area: String in night.hurt:
		hurt[area] = snappedf(night.hurt[area], 0.001)
	out.condition = { "tank": snappedf(night.tank, 0.001), "hurt": hurt }
	if Coach.call_delay(coach_specialty) != 1.0:
		out.condition.call_delay = Coach.call_delay(coach_specialty)  # A Tactician's calls reach him sooner (D311).
	return out


## The share of the gas tank a fighter has at this fight-night fatigue.
static func tank_at(value: float) -> float:
	return clampf(1.0 - TANK_PER_FATIGUE * maxf(0.0, value - TANK_FREE_FATIGUE), TANK_FLOOR, 1.0)


## After a fight taken hurt (fight_night()'s report): did the injury get worse? Seeded, so the same fight says the same.
## {} when they weren't hurt, else { worse, area, days_out } (days out from the fight).
static func after_fight(night: Dictionary, roll_seed: int) -> Dictionary:
	var days: int = int(night.get("injured_days", 0))
	if days <= 0:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = roll_seed
	var worse: bool = rng.randf() < float(night.worsen_chance)
	if worse:
		days += rng.randi_range(WORSEN_DAYS_MIN, WORSEN_DAYS_MAX)
	return { "worse": worse, "area": String(night.injury_area), "days_out": days }


## How much each stat has gained since start_camp().
func camp_gains() -> Dictionary:
	return _camp_gains.duplicate()


## Everything that changes as the fighter trains, so a career can be saved in the middle of a camp and carry on
## exactly as if it never stopped (Career, docs/03 §10.1, D301): the stats with their fractions, the style, fatigue,
## any injury, the age to the week, the potential, this camp's gains (the soft cap) and where the dice are.
## The dice are text: a 64-bit number doesn't survive a JSON number.
func snapshot() -> Dictionary:
	var leanings: Dictionary = {}
	for leaning in StyleLeanings.LEANINGS:
		leanings[leaning] = style.value(leaning)
	return {
		"stats": stats.duplicate(), "style": leanings, "fatigue": fatigue,
		"injured_days": injured_days, "injury_area": injury_area,
		"age_years": age_years, "potential": potential,
		"camp_gains": _camp_gains.duplicate(), "dice": str(_rng.state),
	}


## Puts a snapshot() back. Numbers read back from JSON come as floats, so whole numbers are made whole again.
func restore(snap: Dictionary) -> void:
	stats = {}
	for id: String in snap.get("stats", {}):
		stats[id] = float(snap.stats[id])
	style = StyleLeanings.new(snap.get("style", {}))
	fatigue = float(snap.get("fatigue", 0.0))
	injured_days = int(snap.get("injured_days", 0))
	injury_area = String(snap.get("injury_area", ""))
	age_years = float(snap.get("age_years", age_years))
	age = int(age_years + 0.0001)
	potential = float(snap.get("potential", potential))
	_camp_gains = {}
	for id: String in snap.get("camp_gains", {}):
		_camp_gains[id] = float(snap.camp_gains[id])
	if snap.has("dice"):
		_rng.state = String(snap.dice).to_int()


## The letter grade for a stat value (docs/11 §2.4).
static func grade(value: float) -> String:
	for entry: Array in GRADES:
		if value >= entry[0]:
			return entry[1]
	return GRADES[-1][1]


## The fighter@1 profile with the trained stats and style (fractions kept to 2 places; fights read whole points).
func profile() -> Dictionary:
	var out: Dictionary = _profile.duplicate(true)
	out.template = null
	out.age = age
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


## Training XP × this, from age, Coachable and the Fast learner gift. A stat that ages (Speed, Strength …) uses the
## body's age curve, BODY_AGE_LEARNING.
func learning(stat_id: String = "") -> float:
	var out: float = 1.0 + float(_profile.get("personality", {}).get("coachable", 0.0)) * COACHABLE_PER_POINT
	for entry: Array in (BODY_AGE_LEARNING if Ageing.ages(stat_id) else AGE_LEARNING):
		if age <= entry[0]:
			out *= entry[1]
			break
	if "fast_learner" in _profile.get("gifts", []):
		out *= FAST_LEARNER
	return out * Coach.xp_share(coach_specialty, String(_groups.get(stat_id, "")))


## Style pushes × this, from Coachable and age.
func style_speed() -> float:
	var out: float = 1.0 + float(_profile.get("personality", {}).get("coachable", 0.0)) * STYLE_COACHABLE_PER_POINT
	return out * (STYLE_SET if age >= STYLE_SETS_AT else 1.0)


## XP × this at the current fatigue.
func fatigue_factor() -> float:
	return fatigue_factor_at(fatigue)


## XP × this at that fatigue.
static func fatigue_factor_at(value: float) -> float:
	return 1.0 - (1.0 - FATIGUE_FLOOR) * clampf((value - FATIGUE_FREE) / (100.0 - FATIGUE_FREE), 0.0, 1.0)


## How a fighter at that fatigue would put it: "fresh", "a little tired" or "worn down".
static func freshness(value: float) -> String:
	if value < FRESH_BELOW:
		return "fresh"
	if value < FATIGUE_FREE:
		return "a little tired"
	return "worn down"


## The chance this session injures the fighter, at the fatigue they're doing it at.
func injury_chance(session: Dictionary) -> float:
	var tired: float = fatigue / INJURY_FATIGUE
	return float(session.injury_risk) * (1.0 + tired * tired) * (INJURY_DURABILITY_BASE - stat("durability") / 100.0)


func skip_chance() -> float:
	return maxf(0.0, -float(_profile.get("personality", {}).get("discipline", 0.0))) * SKIP_PER_PARTY_POINT * Coach.skip_share(coach_specialty)


func _run_slot(id: String, day: int, quality: float, variety: float, instruction: Dictionary, week: Dictionary) -> String:
	var session: Dictionary = _library.session(id)
	var trains: bool = float(session.xp) > 0.0
	if injured_days > 0 and not session.get("light", false) and (trains or float(session.fatigue) > 0.0):
		_add_fatigue(float(_library.session("rest").fatigue))  # Out hurt: the slot becomes rest.
		week.injured += 1
		return INJURED
	if trains:
		week.skips_expected += skip_chance()
	if trains and _roll(skip_chance()):
		week.skipped += 1
		return SKIPPED
	_add_fatigue(float(session.fatigue))
	if injured_days > 0 and float(session.get("heals", 0.0)) > 0.0:
		_heal(int(session.heals))  # Rehab: a light session that heals faster (D135).
	if not trains:
		return RESTED
	week.done += 1
	if float(session.injury_risk) > 0.0:
		_unhurt *= 1.0 - minf(1.0, injury_chance(session))
	if float(session.injury_risk) > 0.0 and _roll(injury_chance(session)):
		var days: int = _rng.randi_range(INJURY_DAYS_MIN, INJURY_DAYS_MAX)
		if "slow_healer" in _profile.get("flaws", []):
			days = ceili(days * SLOW_HEALER)
		var area: String = String(session.get("injury_area", INJURY_AREAS[1]))
		if days >= injured_days:
			injury_area = area
		injured_days = maxi(injured_days, days)
		week.injuries.append({ "day": day, "session": id, "days_out": days, "area": area })
	var mult: float = clampf(quality, PLAYED_MIN, PLAYED_MAX) * fatigue_factor() * variety
	for stat_id: String in session.trains:
		var points: float = float(session.xp) * float(session.trains[stat_id]) * mult * learning(stat_id) / xp_per_point(stat_id)
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
		_push(leaning, float(instruction[leaning]) * speed, week)
	return DONE


## Days of healing: the injury is gone at 0.
func _heal(days: int) -> void:
	injured_days = maxi(0, injured_days - days)
	if injured_days == 0:
		injury_area = ""


## A dice roll at this chance; a forecast never rolls (and never uses up the camp's dice).
func _roll(chance: float) -> bool:
	return not _forecasting and _rng.randf() < chance


func _add_fatigue(amount: float) -> void:
	if amount > 0.0:
		amount *= (FATIGUE_RECOVERY_BASE - stat("recovery") / 200.0) * Coach.fatigue_share(coach_specialty)
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


## The instruction's push per session for each leaning (its strongest at INSTRUCTION_PUSH).
func _instruction(gameplan_id: Variant) -> Dictionary:
	if gameplan_id == null or gameplan_id == "":
		return {}
	if not _instructions.has(gameplan_id):
		var leanings: Dictionary = Gameplan.load_id(gameplan_id).leanings
		var strongest: float = 0.0
		for leaning: String in leanings:
			strongest = maxf(strongest, absf(float(leanings[leaning])))
		var push: Dictionary = {}
		for leaning: String in leanings:
			push[leaning] = INSTRUCTION_PUSH * float(leanings[leaning]) / strongest
		_instructions[gameplan_id] = push
	return _instructions[gameplan_id]
