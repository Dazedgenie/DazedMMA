class_name PlaceholderAI
extends RefCounted
## The fighter's own choices until the utility AI lands (#14, docs/01 §7): walk to
## where their moves reach, and now and then throw something that reaches from
## here, nudged by style leanings (docs/11 §4.2) and panic (§3.2). It sits at the
## bottom of the DecisionLayer stack and only reads the fight through FightView.

## Range leaning +100 stands 0.5 m closer than their moves need; Pace +100 another 0.3 m.
const RANGE_LEANING_SHIFT: float = 0.5
const PACE_LEANING_SHIFT: float = 0.3

var _reach_cache: Dictionary = {}  # FighterState → distance their repertoire works from


## How far apart the fighter wants to be: where their moves reach, shifted by the
## Range and Pace leanings. Rocked fighters get out; a hurt opponent gets swarmed.
func preferred_distance(view: FightView) -> float:
	var f: FighterState = view.me
	if f.is_rocked():
		return Octagon.LONG_WITHIN + 1.0
	var want: float = _repertoire_distance(f, view.actions)
	var o: FighterState = view.opponent
	if o.is_rocked() or o.is_down():
		want = Octagon.BAND_CENTRES[Octagon.BAND_POCKET]
	want -= f.style.value(StyleLeanings.RANGE) / 100.0 * RANGE_LEANING_SHIFT
	want -= f.style.value(StyleLeanings.PACE) / 100.0 * PACE_LEANING_SHIFT
	return clampf(want, Octagon.MIN_GAP, Octagon.LONG_WITHIN + 1.0)


## Sometimes picks a legal move that reaches from here. Nobody hits a downed opponent standing.
func choose(view: FightView, layer: DecisionLayer) -> Decision:
	var f: FighterState = view.me
	if f.repertoire.is_empty() or view.opponent.is_down() or view.roll() >= idle_work_rate(view):
		return DecisionLayer.IDLE
	var reach: String = view.band()
	var options: Array[String] = []
	var weights: Array[float] = []
	var total: float = 0.0
	for id in f.repertoire:
		var action: Dictionary = view.actions.get_action(id)
		if action.ranges.has(reach) and view.ruleset.allows_action(action):
			options.append(id)
			weights.append(layer.weight(view, action, choice_weight(f, action)))
			total += weights[-1]
	if total <= 0.0:
		return DecisionLayer.IDLE
	var roll: float = view.roll() * total
	for n in weights.size():
		roll -= weights[n]
		if roll < 0.0:
			return Decision.new(options[n], DecisionLayer.AI)
	return Decision.new(options[-1], DecisionLayer.AI)


## Chance per idle tick to start something. Pace +100 = 1.5× as busy, −100 = half;
## panic adds 20%. Rocked fighters mostly cover up; against a rocked opponent they
## let it go (more so with a Wild Risk leaning).
func idle_work_rate(view: FightView) -> float:
	var f: FighterState = view.me
	var rate: float = f.work_rate * (1.0 + f.style.value(StyleLeanings.PACE) / 200.0)
	if f.is_panicking():
		rate *= 1.0 + FighterState.PANIC_WORK_RATE_BONUS
	if f.is_rocked():
		rate *= 0.3
	elif view.opponent.is_rocked():
		rate *= 1.5 + f.style.value(StyleLeanings.RISK) / 200.0
	return rate


## How much the AI favours an action from its repertoire. The Base leaning tilts
## strikes against takedowns: +100 doubles takedowns and halves strikes, −100 never shoots.
func choice_weight(f: FighterState, action: Dictionary) -> float:
	var base_leaning: float = f.style.value(StyleLeanings.BASE) / 100.0
	match action.category:
		"takedown":
			return 1.0 + base_leaning
		"strike":
			return 1.0 - base_leaning / 2.0
	return 1.0


func _repertoire_distance(f: FighterState, actions: ActionLibrary) -> float:
	if _reach_cache.has(f):
		return _reach_cache[f]
	var total: float = 0.0
	var count: int = 0
	for id in f.repertoire:
		for r: String in actions.get_action(id).ranges:
			if Octagon.BAND_CENTRES.has(r):
				total += Octagon.BAND_CENTRES[r]
				count += 1
	_reach_cache[f] = total / count if count > 0 else Octagon.BAND_CENTRES[Octagon.BAND_MID]
	return _reach_cache[f]
