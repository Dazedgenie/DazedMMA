class_name Ruleset
extends RefCounted
## The rules a fight is held under, loaded from data/rulesets/*.json (ruleset@1,
## docs/09 §3, docs/08). The sim reads round counts and lengths, damage scaling
## and which actions are legal from here, so amateur and pro fights run on the
## same engine with different data (docs/08 §1 "Simulation impact").

const DEFAULT_DIR := "res://data/rulesets/"
const DEFAULT_ID := "pro"
## How the judges score a fight that goes the distance: 10-point must cards round by round
## (unified rules), or one verdict on the whole fight (PRIDE, D141: Judging.whole_fight).
const ROUND_CARDS := "rounds"
const WHOLE_FIGHT := "whole_fight"

var id: String
var name: String
var rounds: int
var round_seconds: int
## Each round's length in seconds when they differ (PRIDE: 600, 300, 300; D141); empty =
## every round is round_seconds.
var round_lengths: Array[int] = []
## Rounds for a title fight (5 in the pros).
var title_rounds: int
## allow key → bool, exactly the keys listed in docs/09 §3 ruleset@1.
var allows: Dictionary
## Protective gear: damage dealt × this (pro 1.0, teen amateur 0.6).
var damage_multiplier: float
## How much sooner the referee stops a fight (0 in the pros, 0.3 adult amateur, 0.5 teen):
## FightSim's stoppage line moves up by this × STOP_BIAS_HEALTH (D120).
var early_stoppage_bias: float
## ROUND_CARDS or WHOLE_FIGHT.
var judging: String = ROUND_CARDS


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
	for n: Variant in d.get("round_lengths", []):
		r.round_lengths.append(int(n))
	r.allows = d.get("allows", {})
	r.damage_multiplier = float(d.get("damage_multiplier", 1.0))
	r.early_stoppage_bias = float(d.get("early_stoppage_bias", 0.0))
	r.judging = String(d.get("judging", ROUND_CARDS))
	return r


## The pro rules with a different round count or length, for short test fights.
static func pro_with(p_rounds: int, p_round_seconds: int) -> Ruleset:
	var r: Ruleset = load_id(DEFAULT_ID)
	r.rounds = p_rounds
	r.round_seconds = p_round_seconds
	r.round_lengths = []
	r.judging = ROUND_CARDS
	return r


## True when this action may be used under these rules. Takedowns can be switched
## off (a kickboxing bout, docs/08 §3), and elbows (D121) and the heel hook (D132, banned
## under both amateur rulesets), soccer kicks and stomps (D141: PRIDE rules only, off where
## a ruleset doesn't list them); slams join here as that action arrives.
func allows_action(action: Dictionary) -> bool:
	if action.category == "takedown":
		return bool(allows.get("takedowns", true))
	if String(action.id).contains("elbow"):
		return bool(allows.get("elbows", true))
	if String(action.id).begins_with("heel_hook"):
		return bool(allows.get("heel_hooks", true))
	if String(action.id).begins_with("soccer_kick"):
		return bool(allows.get("soccer_kicks", false))
	if String(action.id).begins_with("stomp"):
		return bool(allows.get("stomps", false))
	return true


## True when this strike may go to `target` here: a knee only goes to the head where
## knees to the head are allowed (an opening such as HEAD_LOW can send it there, #15),
## and a ground strike only where head strikes on the ground are (amateur rules: the
## body, docs/08, D121).
func allows_target(action: Dictionary, target: String) -> bool:
	if target != "head":
		return true
	if String(action.id).begins_with("knee"):
		return bool(allows.get("knees_to_head_standing", true))
	if is_ground_strike(action) and String(action.id).contains("knee"):
		return bool(allows.get("knees_to_head_grounded", false))  # PRIDE only (D141); elsewhere the body.
	if is_ground_strike(action):
		return bool(allows.get("head_strikes_on_ground", true))
	return true


## A strike thrown only from the ground (ground and pound, D121).
static func is_ground_strike(action: Dictionary) -> bool:
	return action.category == "strike" and not action.positions.has("standing") and not action.positions.has("clinch")
