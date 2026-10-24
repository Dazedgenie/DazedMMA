class_name OddsBreakdown
extends RefCounted
## Where an exchange's odds came from (docs/12 §3 item 3, A16): the action's base,
## the stat gap on effective stats, and each bonus by name (a counter, or an
## opening such as ONE_LEG). Strike events carry it as `odds`, so the feed, the
## debug console and the harness can explain why something landed.
##
##   chance = base + (attack − defense) / 100 + Σ bonuses, clamped 5–95% (Contest)

var action_id: String
var base: float = 0.0
## Average effective offense and defense stats the action uses.
var attack: float = 0.0
var defense: float = 0.0
## [{name, value}] in the order they were added.
var bonuses: Array[Dictionary] = []
## A required opening the opponent doesn't show (catch-kick needs ONE_LEG): the move can't work. "" = none.
var missing: String = ""
var chance: float = 0.0


func _init(p_action_id: String = "") -> void:
	action_id = p_action_id


func add_bonus(bonus_name: String, value: float) -> void:
	bonuses.append({ "name": bonus_name, "value": value })


func bonus_total() -> float:
	var total: float = 0.0
	for b in bonuses:
		total += b.value
	return total


func stat_gap() -> float:
	return (attack - defense) / 100.0


## Works the chance out from the parts with the shared formula.
func settle() -> OddsBreakdown:
	chance = 0.0 if missing != "" else Contest.chance(base, attack, defense, bonus_total())
	return self


## True when the 5–95% clamp cut the sum (the harness counts how often, docs/12 §4).
func is_clamped() -> bool:
	return missing == "" and not is_equal_approx(chance, base + stat_gap() + bonus_total())


func to_dict() -> Dictionary:
	var d := { "base": base, "attack": attack, "defense": defense, "stat_gap": stat_gap(), "bonuses": bonuses.duplicate(true), "chance": chance }
	if missing != "":
		d.missing = missing
	if is_clamped():
		d.clamped = true
	return d
