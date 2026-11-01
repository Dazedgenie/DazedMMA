class_name Weight
extends RefCounted
## Weight divisions (docs/03 §12.1, D351). The six men's divisions (D56) are data (data/divisions, docs/09 division@1).
## Every fighter has a grown weight (`frame.adult_kg`, what he walks around at once he's filled out) that comes from his
## height and build; a teenager weighs a share of it that grows to all of it at GROWN_AT. His division is the lightest
## one he can make with a normal cut (CUT of what he walks around at; the weight cut itself is phase 4).
##
## Kyle (2026-11-01) picked "Grows into it, move at debut": until his pro debut he fights at whatever division his weight
## that year makes; at the debut you pick his natural division (the one his grown weight makes) or the one either side
## of it, and he stays there (Career.division).
##
## Pure: frames, ages and the division files.

const DIVISIONS_DIR := "res://data/divisions/"
## A fighter's body-mass index (kg / m²) by build, at 70 kg; heavier men carry more for their height (BMI_PER_KG).
const BUILD_BMI := { "lean": 23.5, "average": 25.0, "stocky": 26.5 }
## How much the body-mass index rises for each kg over 70 (and falls under it).
const BMI_PER_KG: float = 0.06
## How far his grown weight may sit off what his height and build make, either way (a share of it), rolled once at
## the start of a career.
const PERSONAL_SPREAD: float = 0.04
## The age he's grown into his weight.
const GROWN_AT: float = 21.0
## The share of his grown weight he walks around at at 16, rising evenly to all of it at GROWN_AT.
const SHARE_AT_16: float = 0.88
## The share each year younger than 16 takes off (an opponent can be 13), down to SHARE_FLOOR.
const SHARE_PER_YEAR_UNDER_16: float = 0.03
const SHARE_FLOOR: float = 0.7
## The share of what he walks around at that he cuts to make weight: his division is the lightest whose limit he can
## make with this cut.
const CUT: float = 0.12
const LB_PER_KG: float = 2.20462262
## An opponent made to fit a division (fit()) walks around somewhere in this part of the division's band (0 = the
## lightest who'd be in it, 1 = the heaviest), and stands this many cm either side of what his weight and build make.
const FIT_BAND: Array[float] = [0.15, 0.95]
const FIT_HEIGHT_SPREAD_CM: int = 3

static var _divisions: Array[Dictionary] = []


## Every division, lightest first.
static func divisions() -> Array[Dictionary]:
	if _divisions.is_empty():
		for file: String in DirAccess.get_files_at(DIVISIONS_DIR):
			if not file.ends_with(".json"):
				continue
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIVISIONS_DIR + file))
			if parsed is Dictionary:
				_divisions.append(parsed)
		_divisions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("order", 0)) < int(b.get("order", 0)))
	return _divisions


static func ids() -> Array[String]:
	var out: Array[String] = []
	for d: Dictionary in divisions():
		out.append(String(d.id))
	return out


static func division(id: String) -> Dictionary:
	for d: Dictionary in divisions():
		if String(d.id) == id:
			return d
	return {}


## The division's name ("Lightweight"), or "" for none.
static func name_of(id: String) -> String:
	return String(division(id).get("name", ""))


## "Lightweight (70.3 kg, 155 lb)".
static func label(id: String) -> String:
	var d: Dictionary = division(id)
	if d.is_empty():
		return ""
	return "%s (%s kg, %d lb)" % [String(d.name), _kg(float(d.limit_kg)), int(d.limit_lb)]


## His grown weight in kg: the frame's `adult_kg`, or what his height and build make when it has none (a fighter file,
## or a career saved before D351).
static func adult_kg(frame: Dictionary) -> float:
	if frame.has("adult_kg"):
		return float(frame.adult_kg)
	return _kg_for_height(float(frame.get("height_cm", 178)) / 100.0, String(frame.get("build", "average")))


## The share of his grown weight he walks around at, at this age.
static func share(age_years: float) -> float:
	if age_years >= GROWN_AT:
		return 1.0
	if age_years >= 16.0:
		return lerpf(SHARE_AT_16, 1.0, (age_years - 16.0) / (GROWN_AT - 16.0))
	return maxf(SHARE_FLOOR, SHARE_AT_16 - SHARE_PER_YEAR_UNDER_16 * (16.0 - age_years))


## What he walks around at, at this age (kg, to 0.1).
static func walk_kg(frame: Dictionary, age_years: float) -> float:
	return snappedf(adult_kg(frame) * share(age_years), 0.1)


## The lightest division he can make from this walking-around weight with a normal cut (the heaviest when he's over
## them all: heavyweight comes after launch, D56).
static func division_for(kg: float) -> String:
	var made: float = kg * (1.0 - CUT)
	for d: Dictionary in divisions():
		if float(d.limit_kg) >= made:
			return String(d.id)
	return String(divisions().back().id) if not divisions().is_empty() else ""


## The division his grown weight makes: where he belongs once he's filled out.
static func natural(frame: Dictionary) -> String:
	return division_for(adult_kg(frame))


## The division `by` steps heavier (negative: lighter), held at the ends.
static func step(id: String, by: int) -> String:
	var all: Array[String] = ids()
	var at: int = all.find(id)
	if at < 0:
		return id
	return all[clampi(at + by, 0, all.size() - 1)]


## The divisions he can pick at his pro debut: one lighter, his natural one, one heavier (fewer at the ends).
static func debut_choices(frame: Dictionary) -> Array[String]:
	var home: String = natural(frame)
	var out: Array[String] = []
	for by in [-1, 0, 1]:
		var id: String = step(home, by)
		if not id in out:
			out.append(id)
	return out


## Gives a new career's fighter his own grown weight (frame.adult_kg): what his height and build make, give or take
## PERSONAL_SPREAD.
static func set_up(profile: Dictionary, rng: RandomNumberGenerator) -> void:
	var frame: Dictionary = profile.get("frame", {})
	var base: float = _kg_for_height(float(frame.get("height_cm", 178)) / 100.0, String(frame.get("build", "average")))
	frame.adult_kg = snappedf(base * (1.0 + rng.randf_range(-PERSONAL_SPREAD, PERSONAL_SPREAD)), 0.1)
	profile.frame = frame


## Makes a generated man fit a division at his age: a walking-around weight inside the division's band, the grown
## weight that makes it, and a height (and reach, keeping his ape index) to go with that weight and his build.
static func fit(profile: Dictionary, division_id: String, age_years: float, rng: RandomNumberGenerator) -> void:
	var d: Dictionary = division(division_id)
	if d.is_empty():
		return
	var frame: Dictionary = profile.get("frame", {})
	var at: int = ids().find(division_id)
	var limit: float = float(d.limit_kg)
	var below: float = float(divisions()[at - 1].limit_kg) if at > 0 else limit - (float(divisions()[1].limit_kg) - limit)
	var walk: float = lerpf(below, limit, rng.randf_range(FIT_BAND[0], FIT_BAND[1])) / (1.0 - CUT)
	var adult: float = walk / share(age_years)
	var build: String = String(frame.get("build", "average"))
	var ape: int = int(frame.get("reach_cm", 180)) - int(frame.get("height_cm", 178))
	var height: int = roundi(sqrt(adult / _bmi(adult, build)) * 100.0) + rng.randi_range(-FIT_HEIGHT_SPREAD_CM, FIT_HEIGHT_SPREAD_CM)
	frame.height_cm = height
	frame.reach_cm = height + ape
	frame.adult_kg = snappedf(adult, 0.1)
	profile.frame = frame


static func lb(kg: float) -> int:
	return roundi(kg * LB_PER_KG)


## "76.2 kg".
static func kg_text(kg: float) -> String:
	return "%s kg" % _kg(kg)


static func _kg(kg: float) -> String:
	return "%.1f" % kg


static func _bmi(kg: float, build: String) -> float:
	return float(BUILD_BMI.get(build, BUILD_BMI.average)) + BMI_PER_KG * (kg - 70.0)


## The weight a man of this height (m) and build carries, solving kg = BMI(kg) × h² with BMI rising BMI_PER_KG a kg.
static func _kg_for_height(h: float, build: String) -> float:
	var base: float = float(BUILD_BMI.get(build, BUILD_BMI.average)) - BMI_PER_KG * 70.0
	return base * h * h / (1.0 - BMI_PER_KG * h * h)
