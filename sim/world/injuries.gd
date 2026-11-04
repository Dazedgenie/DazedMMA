class_name Injuries
extends RefCounted
## Named injuries (docs/03 §13.10, D406). Every injury is data (data/injuries/, docs/09 injury@1): where it is, how long it
## takes to heal, what it does to him until it has (Kyle, 2026-11-04: "Each hurts its own thing": a sprained ankle cuts
## Footwork, a broken hand Power), the training it comes from, the fights it comes from, and the rare one that leaves a
## lasting dent ("Rarely, a small dent": a few points off a stat for good, no career-ending injuries yet).
##
##   in camp     a session that hurts him (TrainingCamp.injury_chance) picks one of the injuries its kind of session can
##               cause, by their `camp.weight`
##   in a fight  ("Yes, by what happened") after a career fight: FIGHT_CHANCE × how hurt he finished in each area for a
##               head, body or legs injury, and HAND_PER_PUNCH a punch he landed (× BRITTLE_HANDS with Brittle hands) for
##               his hand. The worst one counts; its days run alongside his suspension
##   hiding it   ("Hide it, he may be found out") on fight night, an injury the doctor won't clear can be hidden: he's
##               found out at HIDE_BASE + HIDE_PER_DAY a day still to heal (up to HIDE_MAX) and the fight is off; if
##               not, he fights hurt and fighting on it is HIDDEN_WORSEN times as likely to make it worse
##
## Pure: the injury files and dice handed in.

const DIR := "res://data/injuries/"
## Where an injury can be: head, body and legs start the fight hurt there (FighterState); hands don't, they only cut stats.
const AREAS: Array[String] = ["head", "body", "legs", "hands"]
## A fight injury: FIGHT_CHANCE × how hurt he finished in an area (0–1) that one of that area's fight injuries happens.
const FIGHT_CHANCE: float = 0.35
## His hand: this chance for each punch he landed, × BRITTLE_HANDS with the Brittle hands flaw.
const HAND_PER_PUNCH: float = 0.0015
const BRITTLE_HANDS: float = 2.0
const BRITTLE_FLAW := "brittle_hands"
## Hiding an injury from the doctor: the chance he's found out.
const HIDE_BASE: float = 0.15
const HIDE_PER_DAY: float = 0.025
const HIDE_MAX: float = 0.9
## Fighting on a hidden injury: the chance it gets worse is this many times the usual (TrainingCamp.WORSEN_BASE …).
const HIDDEN_WORSEN: float = 2.0
## The moves that count as punches for his hand.
const PUNCHES: Array[String] = ["jab", "cross", "hook", "uppercut", "overhand", "body_hook", "short_uppercut", "short_hook",
	"ground_punch", "hammerfist", "ground_body_punch", "posture_bomb", "bottom_punch"]

static var _all: Dictionary = {}


## Every injury, id → its file (loaded once).
static func all() -> Dictionary:
	if _all.is_empty():
		var files: PackedStringArray = DirAccess.get_files_at(DIR)
		files.sort()
		for file in files:
			if file.ends_with(".json"):
				var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR.path_join(file)))
				if parsed is Dictionary:
					_all[String(parsed.id)] = parsed
	return _all


static func get_injury(id: String) -> Dictionary:
	return all().get(id, {})


## What an unnamed injury (an old save's) is called by its area.
const AREA_NAMES := { "head": "Head injury", "body": "Body injury", "legs": "Leg injury", "hands": "Hand injury" }


## Its name ("Sprained ankle"), or by `area` when it has none (an old save's: "Leg injury").
static func name_of(id: String, area: String = "") -> String:
	return String(get_injury(id).get("name", AREA_NAMES.get(area, "Injury")))


## Where it is: head, body, legs or hands ("" when unknown).
static func area_of(id: String) -> String:
	return String(get_injury(id).get("area", ""))


## What it does to him until it's healed: stat id → points (negative).
static func effects(id: String) -> Dictionary:
	return get_injury(id).get("effects", {})


## "Footwork −6, Kicking −3" ("" when it only starts him hurt).
static func effects_text(id: String) -> String:
	var parts: Array[String] = []
	var fx: Dictionary = effects(id)
	for stat: String in fx:
		parts.append("%s %d" % [TrainingCamp.STAT_NAMES.get(stat, stat.capitalize()), int(fx[stat])])
	return ", ".join(parts).replace("-", "−")


## A camp injury from a session of kind `kind` whose own area is `area` (its `injury_area`): one of the injuries that
## kind of session can cause, by weight; failing any, the lightest in that area. Returns its id.
static func pick_camp(kind: String, area: String, roll: float) -> String:
	var pool: Array = []
	var total: float = 0.0
	var ids: Array = all().keys()
	ids.sort()
	for id: String in ids:
		var camp: Dictionary = all()[id].get("camp", {})
		if kind in camp.get("kinds", []):
			pool.append([id, float(camp.get("weight", 1.0))])
			total += float(camp.get("weight", 1.0))
	if pool.is_empty():
		for id: String in ids:
			if area_of(id) == area and all()[id].has("camp"):
				return id
		return ""
	var at: float = roll * total
	for entry: Array in pool:
		at -= float(entry[1])
		if at < 0.0:
			return String(entry[0])
	return String(pool[-1][0])


## Days to heal one, from a 0–1 roll (× TrainingCamp.SLOW_HEALER with Slow healer).
static func days_for(id: String, roll: float, slow_healer: bool) -> int:
	var range_days: Array = get_injury(id).get("days", [3, 7])
	var days: int = roundi(lerpf(float(range_days[0]), float(range_days[1]), roll))
	return ceili(days * TrainingCamp.SLOW_HEALER) if slow_healer else days


## The lasting dent it leaves, from two 0–1 rolls: { stat, points } or {} (most of the time).
static func lasting(id: String, roll: float, size_roll: float) -> Dictionary:
	var l: Dictionary = get_injury(id).get("lasting", {})
	if l.is_empty() or roll >= float(l.get("chance", 0.0)):
		return {}
	var pts: Array = l.get("points", [2, 2])
	return { "stat": String(l.stat), "points": roundi(lerpf(float(pts[0]), float(pts[1]), size_roll)) }


## What a fight did to him: `hurt` (area → 0–1 at the end), `punches` he landed, his `flaws`. Rolls on `rng`; returns
## the worst injury { id, days, area } or {}.
static func from_fight(hurt: Dictionary, punches: int, flaws: Array, rng: RandomNumberGenerator) -> Dictionary:
	var found: Array[String] = []
	for cause: String in ["head", "body", "legs", "punches"]:
		var chance: float = HAND_PER_PUNCH * punches * (BRITTLE_HANDS if BRITTLE_FLAW in flaws else 1.0) if cause == "punches" \
			else FIGHT_CHANCE * clampf(float(hurt.get(cause, 0.0)), 0.0, 1.0)
		var roll: float = rng.randf()
		var pick: float = rng.randf()
		if roll < chance:
			var id: String = _pick_fight(cause, pick)
			if id != "":
				found.append(id)
	var best: Dictionary = {}
	for id: String in found:
		var days: int = days_for(id, rng.randf(), "slow_healer" in flaws)
		if best.is_empty() or days > int(best.days):
			best = { "id": id, "days": days, "area": area_of(id) }
	return best


static func _pick_fight(cause: String, roll: float) -> String:
	var pool: Array = []
	var total: float = 0.0
	var ids: Array = all().keys()
	ids.sort()
	for id: String in ids:
		var fight: Dictionary = all()[id].get("fight", {})
		if String(fight.get("cause", "")) == cause:
			pool.append([id, float(fight.get("weight", 1.0))])
			total += float(fight.get("weight", 1.0))
	var at: float = roll * total
	for entry: Array in pool:
		at -= float(entry[1])
		if at < 0.0:
			return String(entry[0])
	return String(pool[-1][0]) if not pool.is_empty() else ""


## The punches `fighter` landed in a fight (for his hand).
static func punches_landed(sim: FightSim, fighter: int) -> int:
	var n: int = 0
	for e: FightEvent in sim.events:
		if e.type == FightEvent.STRIKE_LANDED and e.actor == fighter and String(e.data.get("action_id", "")) in PUNCHES:
			n += 1
	return n


## What a fight injury says on the result screen: "Hurt in the fight: Broken hand, 40 days to heal (Power −8, Boxing −5
## until then)." and any lasting dent.
static func fight_text(record: Dictionary) -> String:
	if record.is_empty():
		return ""
	var id: String = String(record.get("id", ""))
	var fx: String = effects_text(id)
	var out: String = "Hurt in the fight: %s, %d days to heal%s." % [name_of(id), int(record.get("days", 0)),
		(" (%s until then)" % fx) if fx != "" else ""]
	var dent: Dictionary = record.get("dent", {})
	if not dent.is_empty():
		out += " It leaves its mark: %s −%d for good." % [TrainingCamp.STAT_NAMES.get(String(dent.stat), String(dent.stat)), int(dent.points)]
	return out


## The chance the doctor finds an injury he's hiding with `days` still to heal.
static func found_chance(days: int) -> float:
	return clampf(HIDE_BASE + HIDE_PER_DAY * days, 0.0, HIDE_MAX)


## Whether he's found out hiding the booked fight's injury (seeded on the booking, so it's the same every time).
static func found_out(c: Career) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([c.career_seed, String(c.booked.get("opponent", "")), int(c.booked.get("week", 0)), "the doctor"])
	return rng.randf() < found_chance(c.trainee.injured_days)
