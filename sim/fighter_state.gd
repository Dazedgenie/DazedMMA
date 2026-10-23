class_name FighterState
extends RefCounted
## One fighter's live state inside FightSim.
##
## Kept deliberately small for the core loop (#12). Distance, stamina, flags and
## damage effects arrive with the standing game (#13); tendencies with the AI (#14).

const DEFAULT_STAT: int = 50

var name: String
var stats: Dictionary  # stat id → 0–100; missing stats count as DEFAULT_STAT
## Actions the placeholder AI picks from when nothing is queued.
var repertoire: Array[String]
## Chance per idle tick that the placeholder AI starts an action.
var work_rate: float

var position: String = "standing"
var damage: Dictionary = { "head": 0, "body": 0, "legs": 0 }
var strikes_landed: int = 0
var strikes_thrown: int = 0

var action_id: String = ""  # "" = free to act
var phase: String = ""
var phase_ticks_left: int = 0
var queued_action_id: String = ""


func _init(p_name: String, p_stats: Dictionary = {}, p_repertoire: Array[String] = ["jab"], p_work_rate: float = 0.08) -> void:
	name = p_name
	stats = p_stats
	repertoire = p_repertoire
	work_rate = p_work_rate


func is_free() -> bool:
	return action_id == ""


func stat(id: String) -> int:
	return int(stats.get(id, DEFAULT_STAT))


func clear_action() -> void:
	action_id = ""
	phase = ""
	phase_ticks_left = 0
