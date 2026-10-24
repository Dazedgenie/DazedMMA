class_name FightView
extends RefCounted
## What one fighter's decision step may look at (docs/12 §3 item 2): the fight
## as seen from fighter `me`, read through FightSim's queries. Decision sources
## read from here and never change the fight; the sim applies what they decide.
##
## roll() draws from the fight's seeded RNG, so decisions stay replayable.
##
## The sim keeps one view per fighter and updates `now` each tick. The view holds
## the sim weakly: a strong reference both ways would keep every finished fight
## in memory.

var index: int
## Read these, never change them: the sim owns the fight.
var me: FighterState
var opponent: FighterState
var actions: ActionLibrary
var ruleset: Ruleset
## The tick being decided.
var now: int = 0
var _sim_ref: WeakRef


func _init(p_sim: FightSim, p_index: int) -> void:
	_sim_ref = weakref(p_sim)
	index = p_index
	me = p_sim.fighters[p_index]
	opponent = p_sim.fighters[1 - p_index]
	actions = p_sim.actions
	ruleset = p_sim.ruleset


func band() -> String:
	return _sim().band()


func distance() -> float:
	return _sim().distance()


## The current position id (e.g. "standing", "full_guard"), its phase, and roles.
func position() -> String:
	return _sim().situation.position


func phase() -> String:
	return _sim().situation.phase


func my_role() -> String:
	return _sim().role(index)


func opponent_role() -> String:
	return _sim().role(1 - index)


func my_flags() -> Array[String]:
	return _sim().active_flags(index)


func opponent_flags() -> Array[String]:
	return _sim().active_flags(1 - index)


func my_cage_proximity() -> String:
	return _sim().cage_proximity(index)


func odds(action_id: String) -> OddsBreakdown:
	return _sim().odds_breakdown(index, action_id)


## "" when I could start this action right now, else why not (unknown, illegal, wrong position).
func why_not(action_id: String) -> String:
	return _sim().why_not(index, action_id)


func roll() -> float:
	return _sim().roll()


func _sim() -> FightSim:
	return _sim_ref.get_ref()
