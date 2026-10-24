class_name FightCommand
extends RefCounted
## An instruction from outside the sim (player, bot, test), applied at the start
## of a given tick. The sim never reads input; everything arrives as a command,
## so seed + command log replays a fight exactly (docs/04-tech-and-production.md §2.2).
##
## Fighter starts this action as soon as they are free. data: {action_id}
const QUEUE_ACTION := "queue_action"
## The coach calls for this action: it goes through the fighter's call delay,
## compliance and feasibility checks first (LiveCalls, docs/01 §6.2). data: {action_id}
## Call ids, voice and read calls replace the bare action with #16.
const LIVE_CALL := "live_call"

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


static func live_call(p_tick: int, p_fighter: int, action_id: String) -> FightCommand:
	return FightCommand.new(p_tick, p_fighter, LIVE_CALL, { "action_id": action_id })


func to_dict() -> Dictionary:
	return { "tick": tick, "fighter": fighter, "type": type, "data": data }


static func from_dict(d: Dictionary) -> FightCommand:
	return FightCommand.new(int(d.tick), int(d.fighter), String(d.type), d.get("data", {}))
