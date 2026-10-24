class_name LiveCalls
extends DecisionSource
## Live calls in front of the decision step (docs/01 §6.2, D92). A heard call
## waits out the fighter's processing delay in fight time, then goes through a
## compliance check and a feasibility check before it claims the next choice.
## Every outcome is logged as a call_answered event with its reason (A16).
##
## Voice, garbling, the delay modifiers, read calls and the compliance roll are
## #16; for now every call takes the base delay and the fighter always complies.

## 0.6 s of fight time (D92).
const BASE_DELAY_TICKS: int = 6

const ACCEPTED := "accepted"
const IGNORED := "ignored"
const INFEASIBLE := "infeasible"

## The call being processed: {action_id, heard, ready_at}, or empty. A new call replaces it.
var pending: Dictionary = {}


func _init() -> void:
	layer = DecisionLayer.CALL
	may_claim = false


func hear(view: FightView, action_id: String) -> void:
	pending = { "action_id": action_id, "heard": view.now, "ready_at": view.now + delay_ticks(view) }
	may_claim = true


## Ticks between the call and the fighter acting on it.
func delay_ticks(_view: FightView) -> int:
	return BASE_DELAY_TICKS


## "" when the fighter goes along with the call, else why not (ego, trust, panic: #16).
func refusal(_view: FightView, _call: Dictionary) -> String:
	return ""


func claim(view: FightView) -> Decision:
	if pending.is_empty() or view.now < pending.ready_at:
		return null
	var call: Dictionary = pending
	pending = {}
	may_claim = false
	var why: String = refusal(view, call)
	if why != "":
		_answer(call, IGNORED, why)
		return null
	why = view.why_not(call.action_id)
	if why != "":
		_answer(call, INFEASIBLE, why)
		return null
	return Decision.new(call.action_id, DecisionLayer.CALL, "call after %d ticks" % (view.now - call.heard))


func claimed_started(_view: FightView, decision: Decision) -> void:
	_answer({ "action_id": decision.action_id }, ACCEPTED, decision.reason)


func _answer(call: Dictionary, outcome: String, reason: String) -> void:
	note(FightEvent.CALL_ANSWERED, { "action_id": call.action_id, "outcome": outcome, "reason": reason })
