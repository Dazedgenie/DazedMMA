class_name FightEvent
extends RefCounted
## Something that happened in the fight, emitted by FightSim for presentation,
## commentary, triggers and logs to listen to (docs/04-tech-and-production.md §2.2).
##
## Type names are snake_case to match data/triggers (e.g. "action_phase").

const ACTION_PHASE := "action_phase"  # data: {action_id, phase}
const ACTION_ENDED := "action_ended"  # data: {action_id}
const STRIKE_LANDED := "strike_landed"  # data: {action_id, target, damage}
const STRIKE_MISSED := "strike_missed"  # data: {action_id, target}
const COMMAND_REJECTED := "command_rejected"  # data: {command, reason}
const ROUND_ENDED := "round_ended"  # data: {}
const FIGHT_ENDED := "fight_ended"  # data: {result}

const NO_ACTOR: int = -1

var tick: int
var round_number: int
var type: String
var actor: int
var data: Dictionary


func _init(p_tick: int, p_round: int, p_type: String, p_actor: int = NO_ACTOR, p_data: Dictionary = {}) -> void:
	tick = p_tick
	round_number = p_round
	type = p_type
	actor = p_actor
	data = p_data


func to_dict() -> Dictionary:
	return { "tick": tick, "round": round_number, "type": type, "actor": actor, "data": data }
