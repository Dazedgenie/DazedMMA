class_name Ruleset
extends RefCounted
## The rules a fight is held under, loaded from data/rulesets/*.json (ruleset@1,
## docs/09 §3, docs/08). The sim reads round counts and lengths, damage scaling
## and which actions are legal from here, so amateur and pro fights run on the
## same engine with different data (docs/08 §1 "Simulation impact").

const DEFAULT_DIR := "res://data/rulesets/"
const DEFAULT_ID := "pro"

var id: String
var name: String
var rounds: int
var round_seconds: int
## Rounds for a title fight (5 in the pros).
var title_rounds: int
## allow key → bool, exactly the keys listed in docs/09 §3 ruleset@1.
var allows: Dictionary
## Protective gear: damage dealt × this (pro 1.0, teen amateur 0.6).
var damage_multiplier: float


static func load_id(ruleset_id: String = DEFAULT_ID, dir_path: String = DEFAULT_DIR) -> Ruleset:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir_path.path_join(ruleset_id + ".json")))
	assert(parsed is Dictionary, "no ruleset '%s' in %s" % [ruleset_id, dir_path])
	return from_dict(parsed)


static func from_dict(d: Dictionary) -> Ruleset:
	var r := Ruleset.new()
	r.id = d.id
	r.name = d.name
	r.rounds = int(d.rounds)
	r.title_rounds = int(d.get("title_rounds", d.rounds))
	r.round_seconds = int(d.round_seconds)
	r.allows = d.get("allows", {})
	r.damage_multiplier = float(d.get("damage_multiplier", 1.0))
	return r


## The pro rules with a different round count or length, for short test fights.
static func pro_with(p_rounds: int, p_round_seconds: int) -> Ruleset:
	var r: Ruleset = load_id(DEFAULT_ID)
	r.rounds = p_rounds
	r.round_seconds = p_round_seconds
	return r


## True when this action may be used under these rules. Takedowns can be switched
## off (a kickboxing bout, docs/08 §3); elbows, knees to a grounded opponent,
## ground strikes to the head and slams join here as those actions arrive (#15).
func allows_action(action: Dictionary) -> bool:
	if action.category == "takedown":
		return bool(allows.get("takedowns", true))
	return true
