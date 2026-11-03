class_name DrillAI
extends FighterAI
## A fighter in a training drill (the sprawl reflex minigame, docs/03 §13.5, D411), not a fight: he stands at `want`
## metres, square, and starts only the moves he's given. `moves` is the next few in order; the first goes once the
## clock reaches `next_at` and he's in range for it, and each after it as soon as he's free again. Nothing given, he
## waits (the player's fighter, whose sprawl comes from the player as a queued command).

## Metres apart he holds (mid range: a double leg reaches from here).
var want: float = Octagon.BAND_CENTRES[Octagon.BAND_MID]
## The moves to start, in order (data/actions ids), and the tick the first may start from.
var moves: Array[String] = []
var next_at: int = 0


func choose(view: FightView, _layer: DecisionLayer) -> Decision:
	if moves.is_empty() or view.now < next_at or not view.is_standing() or view.opponent.is_down():
		return DecisionLayer.IDLE
	if not view.actions.get_action(moves[0]).ranges.has(view.band()):
		return DecisionLayer.IDLE
	var id: String = moves.pop_front()
	next_at = view.now  # The rest follow as soon as he's free.
	return Decision.new(id, DecisionLayer.AI, "drill")


func preferred_distance(_view: FightView, _layer: DecisionLayer) -> float:
	return want


func plan_feet(_view: FightView, _layer: DecisionLayer, out: FeetPlan) -> void:
	out.want = want
	out.circle = 0.0
	out.way = 0
	out.cut = 0.0
	out.anywhere = false
	out.burst = false
	out.home = false
	out.resetting = false
	out.reset_why = ""
	out.reset_ended = ""


func circling(_view: FightView, _layer: DecisionLayer) -> float:
	return 0.0
