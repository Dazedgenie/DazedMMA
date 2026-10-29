class_name Decision
extends RefCounted
## What a fighter's decision step chose this tick (DecisionLayer): the action to
## start ("" = keep working the feet), which layer chose it and why, for the log
## (docs/01 §16 A16: every call and rule says why it fired).

var action_id: String = ""
## DecisionLayer.COMMAND, CALL, RULE or AI.
var layer: String = ""
var reason: String = ""
## The combination this move is part of ("" for none) and which move of it (0 = the first, D133).
var combo: String = ""
var combo_step: int = 0
## The rest of the combination follows without the fighter's own say: it was called or commanded
## as a whole (D133). The fighter's own combinations go on a move at a time, like any strikes.
var combo_runs: bool = false
## The source that claimed it (null for commands and the AI).
var source: DecisionSource


func _init(p_action_id: String = "", p_layer: String = "", p_reason: String = "") -> void:
	action_id = p_action_id
	layer = p_layer
	reason = p_reason


func is_idle() -> bool:
	return action_id == ""
