class_name FightEvent
extends RefCounted
## Something that happened in the fight, emitted by FightSim for presentation,
## commentary, triggers and logs to listen to (docs/04-tech-and-production.md §2.2).
##
## Type names are snake_case to match data/triggers (e.g. "action_phase").

const ACTION_PHASE := "action_phase"  # data: {action_id, phase}
const ACTION_ENDED := "action_ended"  # data: {action_id}
const STRIKE_LANDED := "strike_landed"  # data: {action_id, target, damage, chance, counter, odds, into?}  into: the opponent's move it stopped
const STRIKE_MISSED := "strike_missed"  # data: {action_id, target, chance, odds? | reason?} reason: "out of range" / "opponent down"
## `odds` is OddsBreakdown.to_dict(): {base, attack, defense, stat_gap, bonuses: [{name, value}], chance, clamped?}
const RANGE_CHANGED := "range_changed"  # data: {band}
const POSITION_CHANGED := "position_changed"  # actor's action moved the fight. data: {action_id, position, phase, roles: [red, blue]}
## A takedown, clinch or ground move (#15) worked (result "success") or half worked ("partial": into a scramble);
## a position_changed follows. data: {action_id, result, chance, odds}
const GRAPPLE_WON := "grapple_won"
## A takedown, clinch or ground move didn't work. data: {action_id, reason, chance?, odds?, by_action?}
## reason: "out of range" / "opponent down" / "nothing to catch" (a required opening wasn't there, see odds.missing) /
## "defended" (lost the roll) / "sprawled on" / "stopped" (a strike into it stopped it, by_action says which)
const GRAPPLE_STOPPED := "grapple_stopped"
## Actor's sprawl met the opponent's shot. data: {action_id (the sprawl), against (the shot), worked, chance, odds}
const SPRAWLED := "sprawled"
const CAGE_CHANGED := "cage_changed"  # actor's cage proximity. data: {proximity}
const ROCKED := "rocked"  # actor got rocked. data: {by, again? (rocked again on the ground, D121)}
const KNOCKDOWN := "knockdown"  # actor got knocked down. data: {by}
const GOT_UP := "got_up"  # actor is back up after a knockdown
const RECOVERED := "recovered"  # actor is no longer rocked
const COMMAND_REJECTED := "command_rejected"  # data: {command, reason}
## The actor's corner made a call (LiveCalls.hear, #16). data: {call_id, voice (left after it), garbled,
## delay (ticks before the fighter acts on it), trust, spam (the same call again within 3 s)}
const CALL_HEARD := "call_heard"
## What the actor did with a live call (LiveCalls). data: {call_id, outcome, reason, action_id?}
## outcome: accepted (the move started, the focus or read began) / ignored (compliance) / infeasible /
## fired (a read went off; action_id says with what) / missed (a read came too late) / expired / replaced
const CALL_ANSWERED := "call_answered"
## What one of the actor's drilled rules did (DrilledRules, #17). data: {rule_id, outcome, reason, slot, action_id?, drilled?}
## outcome: set (put in a slot before a round) / fired (action_id says with what) / cooling (fired too recently) /
## slow (the reliability roll: didn't see it in time) / outranked (the rule in slot 1 went) / not_eligible (out of range,
## too tired, rocked, no opening …) / missed (busy until the moment had gone)
const RULE_ANSWERED := "rule_answered"
const ROUND_ENDED := "round_ended"  # data: {cards: per judge [red, blue]}
const FIGHT_ENDED := "fight_ended"  # data: {result, winner (-1 = draw), cards? (judges' totals), stopped_by? ("towel"), why? (the referee's reason: "health", "unanswered", "knockdowns", D120)}

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
