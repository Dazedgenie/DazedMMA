class_name StyleLeanings
extends RefCounted
## How a fighter fights when nobody is calling: four hidden leanings from −100
## to +100 (docs/11-attributes-and-traits.md §4.2, D86–D89).
##
## Leanings move a little with every push (training, gameplans, accepted calls;
## those systems arrive later and call push()). Past ±60 a leaning earns a named
## trait; the trait fades only once the leaning falls back inside ±40, so it
## doesn't flicker. The player sees a fuzzy hint past ±30 (D88).

const PACE := "pace"
const RANGE := "range"
const BASE := "base"
const RISK := "risk"
const LEANINGS: Array[String] = [PACE, RANGE, BASE, RISK]

const HINT_AT: int = 30
const EARN_AT: int = 60
const LOSE_INSIDE: int = 40

## leaning → [word for the − end, word for the + end], for hints.
const ENDS := {
	PACE: ["patient", "aggressive"],
	RANGE: ["outside", "inside"],
	BASE: ["striker", "grappler"],
	RISK: ["safe", "wild"],
}
## leaning → [trait at −60, trait at +60] (docs/11 §4.2 table).
const TRAITS := {
	PACE: ["patient_counter_puncher", "natural_aggressor"],
	RANGE: ["range_fighter", "phone_booth_fighter"],
	BASE: ["sprawl_and_brawl", "wrestle_first"],
	RISK: ["fundamentalist", "finisher"],
}
const TRAIT_NAMES := {
	"patient_counter_puncher": "Patient counter-puncher", "natural_aggressor": "Natural aggressor",
	"range_fighter": "Range fighter", "phone_booth_fighter": "Phone-booth fighter",
	"sprawl_and_brawl": "Sprawl-and-brawl", "wrestle_first": "Wrestle-first",
	"fundamentalist": "Fundamentalist", "finisher": "Finisher",
}

var _values: Dictionary = { PACE: 0.0, RANGE: 0.0, BASE: 0.0, RISK: 0.0 }
var _traits: Dictionary = {}  # leaning → trait id; at most one per leaning


func _init(start: Dictionary = {}) -> void:
	for leaning: String in start:
		push(leaning, float(start[leaning]))


func value(leaning: String) -> float:
	return _values[leaning]


## Moves a leaning by `amount` (clamped to ±100) and earns or loses its trait.
func push(leaning: String, amount: float) -> void:
	assert(_values.has(leaning), "unknown leaning '%s'" % leaning)
	var v: float = clampf(_values[leaning] + amount, -100.0, 100.0)
	_values[leaning] = v
	if v >= EARN_AT:
		_traits[leaning] = TRAITS[leaning][1]
	elif v <= -EARN_AT:
		_traits[leaning] = TRAITS[leaning][0]
	elif absf(v) < LOSE_INSIDE:
		_traits.erase(leaning)


## The named trait this leaning has earned, or "".
func trait_for(leaning: String) -> String:
	return _traits.get(leaning, "")


func traits() -> Array[String]:
	var out: Array[String] = []
	for leaning in LEANINGS:
		if _traits.has(leaning):
			out.append(_traits[leaning])
	return out


## What the player is told (D88), e.g. "leaning aggressive"; "" until past ±30.
func hint(leaning: String) -> String:
	var v: float = _values[leaning]
	if absf(v) < HINT_AT:
		return ""
	return "leaning %s" % ENDS[leaning][1 if v > 0 else 0]
