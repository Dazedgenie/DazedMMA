class_name DecisionLayer
extends RefCounted
## One fighter's decision step, separate from the fight loop (docs/12 §3 item 2,
## issue #33). Each tick the fighter is free, FightSim asks decide() what to
## start, and the answer comes from one priority stack (docs/01 §6.0, §7):
##
##   1. COMMAND  an action queued from outside (tests, bots, the debug console)
##   2. CALL     a live call the fighter heard, processed and accepted (#16)
##   3. RULE     a drilled rule whose trigger fired (#17)
##   4. AI       the fighter's own choice (FighterAI, #14), weighted by the gameplan and habits
##
## The first layer that claims the choice wins. Gameplan sources never claim;
## they only tilt the AI's weights and leanings, so the fighter never silently
## replaces the gameplan (docs/01 §16 A2). The sim still owns time, movement and
## resolution, and passes every fight event through on_event() so the AI and the
## sources can react to what they see.

const COMMAND := "command"
const CALL := "call"
const RULE := "rule"
const GAMEPLAN := "gameplan"
const AI := "ai"
## "Nothing to start": shared, so idle ticks don't allocate. Never modify it.
static var IDLE := Decision.new()
## Claiming layers, highest first.
const CLAIM_ORDER: Array[String] = [CALL, RULE]

var ai: FighterAI
## Every live call for this fighter goes through here (delay, compliance, feasibility).
var calls: LiveCalls
var sources: Array[DecisionSource] = []
## This fighter's footwork, refilled by plan_feet.
var feet := FeetPlan.new()
## The sources that can claim the choice, in CLAIM_ORDER.
var _claimers: Array[DecisionSource] = []
## Outcomes the sources reported this tick, for the sim to log: [{type, data}].
var _notes: Array[Dictionary] = []


func _init(p_ai: FighterAI = null) -> void:
	ai = p_ai if p_ai != null else FighterAI.new()
	calls = LiveCalls.new()
	add_source(calls)


func add_source(source: DecisionSource) -> void:
	sources.append(source)
	_claimers.clear()
	for layer in CLAIM_ORDER:
		for s in sources:
			if s.layer == layer:
				_claimers.append(s)


## How far apart this fighter wants to stand (their feet follow it every free tick).
func preferred_distance(view: FightView) -> float:
	return ai.preferred_distance(view, self)


## How much this fighter circles while they move (0 = straight in or out, 1 = all they can).
func circling(view: FightView) -> float:
	return ai.circling(view, self)


## This tick's footwork in one go (the sim asks once per free standing tick): distance,
## circling and which way, and cutting the cage off. The same FeetPlan comes back every time.
func plan_feet(view: FightView) -> FeetPlan:
	ai.plan_feet(view, self, feet)
	return feet


func decide(view: FightView) -> Decision:
	var f: FighterState = view.me
	if f.queued_action_id != "":
		return Decision.new(f.queued_action_id, COMMAND, "queued")
	for source in _claimers:
		if not source.may_claim:
			continue
		var claimed: Decision = source.claim(view)
		if source.has_notes():
			_notes.append_array(source.take_notes())
		if claimed != null and not claimed.is_idle():
			claimed.source = source
			return claimed
	return ai.choose(view, self)


## The AI's weight for an action after every gameplan-style bias.
func weight(view: FightView, action: Dictionary, base_weight: float) -> float:
	var w: float = base_weight
	for source in sources:
		w = source.adjust_weight(view, action, w)
	return w


## A style leaning as the AI reads it this fight: the fighter's own, shifted by
## the gameplan (−100 to +100).
func leaning(view: FightView, which: String) -> float:
	var v: float = view.me.style.value(which)
	for source in sources:
		v = source.adjust_leaning(view, which, v)
	return clampf(v, -100.0, 100.0)


## Every fight event, for the AI and every source (FightSim calls it as events happen).
func on_event(view: FightView, event: FightEvent) -> void:
	ai.on_event(view, event, self)
	for source in sources:
		source.on_event(view, event)


## The sim calls this once a decision's action has started.
func started(view: FightView, decision: Decision) -> void:
	if decision.layer == COMMAND:
		view.me.queued_action_id = ""
	if decision.source != null:
		decision.source.claimed_started(view, decision)
		_notes.append_array(decision.source.take_notes())


func take_notes() -> Array[Dictionary]:
	if _notes.is_empty():
		return _notes
	var out: Array[Dictionary] = _notes
	_notes = []
	return out
