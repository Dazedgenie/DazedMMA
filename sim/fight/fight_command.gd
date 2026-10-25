class_name FightCommand
extends RefCounted
## An instruction from outside the sim (player, bot, test), applied at the start
## of a given tick. The sim never reads input; everything arrives as a command,
## so seed + command log replays a fight exactly (docs/04-tech-and-production.md §2.2).
##
## Fighter starts this action as soon as they are free. data: {action_id}
const QUEUE_ACTION := "queue_action"
## The corner makes a call: it costs voice and goes through the fighter's call delay,
## compliance and feasibility checks first (LiveCalls, docs/01 §6.2, §22). data: {call_id}:
## a data/calls id, or an action id for a bare call of that move (tests, the debug console).
const LIVE_CALL := "live_call"
## Before a round (tick 0, or a round's first tick): a drilled rule goes in one of the fighter's
## slots (DrilledRules, docs/01 §23). data: {slot (1 or 2), rule_id (a data/rules id, "" empties
## the slot), drilled (0–100: how well it was drilled in camp)}
const SET_RULE := "set_rule"

var tick: int
var fighter: int
var type: String
var data: Dictionary


func _init(p_tick: int, p_fighter: int, p_type: String, p_data: Dictionary = {}) -> void:
	tick = p_tick
	fighter = p_fighter
	type = p_type
	data = p_data


static func queue_action(p_tick: int, p_fighter: int, action_id: String) -> FightCommand:
	return FightCommand.new(p_tick, p_fighter, QUEUE_ACTION, { "action_id": action_id })


static func live_call(p_tick: int, p_fighter: int, call_id: String) -> FightCommand:
	return FightCommand.new(p_tick, p_fighter, LIVE_CALL, { "call_id": call_id })


static func set_rule(p_tick: int, p_fighter: int, slot: int, rule_id: String, drilled: float) -> FightCommand:
	return FightCommand.new(p_tick, p_fighter, SET_RULE, { "slot": slot, "rule_id": rule_id, "drilled": drilled })


func to_dict() -> Dictionary:
	return { "tick": tick, "fighter": fighter, "type": type, "data": data }


static func from_dict(d: Dictionary) -> FightCommand:
	return FightCommand.new(int(d.tick), int(d.fighter), String(d.type), d.get("data", {}))
