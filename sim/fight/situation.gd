class_name Situation
extends RefCounted
## Where the fight is right now, shared by both fighters (docs/01 §4, issue #34):
## the phase (standing / clinch / ground), the named position and each fighter's
## role in it. Positions are relational (one fighter is on top), so they live
## here once instead of in each FighterState.
##
## Where in the cage the fight is stays with the fighters' own `pos`: a takedown
## against the fence stays against the fence (docs/01 §3).

var position: String = PositionLibrary.STANDING
var phase: String = PositionLibrary.PHASE_STANDING
## Role per fighter index: "neutral" when standing, "top" / "bottom" on the ground.
var roles: Array[String] = [PositionLibrary.NEUTRAL, PositionLibrary.NEUTRAL]


func role(i: int) -> String:
	return roles[i]


func is_standing() -> bool:
	return phase == PositionLibrary.PHASE_STANDING


## Moves the fight into `def` (a position@2 dictionary) with these roles.
func set_to(def: Dictionary, p_roles: Array[String]) -> void:
	position = def.id
	phase = def.phase
	roles = p_roles.duplicate()


func reset() -> void:
	position = PositionLibrary.STANDING
	phase = PositionLibrary.PHASE_STANDING
	roles = [PositionLibrary.NEUTRAL, PositionLibrary.NEUTRAL]


func to_dict() -> Dictionary:
	return { "position": position, "phase": phase, "roles": roles.duplicate() }
