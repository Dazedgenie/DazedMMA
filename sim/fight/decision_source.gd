class_name DecisionSource
extends RefCounted
## One layer of coaching that feeds a fighter's choice (docs/01 §6.0): live
## calls, drilled rules (#17) and gameplans all extend this and plug into the
## same DecisionLayer, so none of them is a special case inside the fight loop.
##
## A source can claim the choice outright (a call the fighter accepted, a rule
## that fired) or tilt the AI's own weights (a gameplan, habits from calls).

## DecisionLayer.CALL, RULE or GAMEPLAN: decides where in the stack it sits.
var layer: String = ""
## False while the source has nothing it could claim, so the layer can skip it
## cheaply (decide() runs every free tick). Rules leave it on; calls switch it.
var may_claim: bool = true
## Outcomes to log (why a call was ignored, why a rule didn't fire): [{type, data}].
var _notes: Array[Dictionary] = []


## The action this source insists on now, or null to leave the choice to lower layers.
func claim(_view: FightView) -> Decision:
	return null


## The AI's weight for an action after this source's bias (1.0 = unchanged).
func adjust_weight(_view: FightView, _action: Dictionary, weight: float) -> float:
	return weight


## A style leaning (StyleLeanings.PACE …) as the AI should read it for this fight,
## e.g. a Pressure gameplan adds Pace. Unchanged by default.
func adjust_leaning(_view: FightView, _leaning: String, value: float) -> float:
	return value


## Every fight event, as this fighter's side sees it (read calls and rules watch for triggers).
func on_event(_view: FightView, _event: FightEvent) -> void:
	pass


## Called by the sim once the fighter starts an action this source claimed.
func claimed_started(_view: FightView, _decision: Decision) -> void:
	pass


## Records an outcome for the fight log (docs/01 §16 A16). `type` is a FightEvent type.
func note(type: String, data: Dictionary) -> void:
	_notes.append({ "type": type, "data": data })


func take_notes() -> Array[Dictionary]:
	if _notes.is_empty():
		return _notes
	var out: Array[Dictionary] = _notes
	_notes = []
	return out


func has_notes() -> bool:
	return not _notes.is_empty()
