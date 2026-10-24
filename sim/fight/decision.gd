class_name Decision
extends RefCounted
## What a fighter's decision step chose this tick (DecisionLayer): the action to
## start ("" = keep working the feet), which layer chose it and why, for the log
## (docs/01 §16 A16: every call and rule says why it fired).

var action_id: String = ""
## DecisionLayer.COMMAND, CALL, RULE or AI.
var layer: String = ""
var reason: String = ""
## The source that claimed it (null for commands and the AI).
var source: DecisionSource


func _init(p_action_id: String = "", p_layer: String = "", p_reason: String = "") -> void:
	action_id = p_action_id
	layer = p_layer
	reason = p_reason


func is_idle() -> bool:
	return action_id == ""
