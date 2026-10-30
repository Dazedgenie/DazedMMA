class_name DrilledRules
extends DecisionSource
## Drilled rules (docs/01 §6.0, §23, issue #17, D82): the answers the fighter drilled in
## camp, "when he kicks → catch & shoot". Third in the decision stack, under live calls
## and over the fighter's own AI. Each fighter has two slots:
##
##   set     before a round, a rule from data/rules goes in slot 1 or 2 with how well it
##           was drilled (0–100%, the playtest's slider for camp drilling)
##   trigger the rule's trigger fires (the opponent starts a body kick). Slot 1 goes first;
##           a rule that fired in the last cooldown_ms sits it out
##   roll    reliability: drilled × Fight IQ × tired × hurt × how wise the opponent is to it
##           (a fighter with high Fight IQ disguises a move the rule keeps catching)
##   act     the fighter's own reaction time later (D93), if eligible: legal from here, in
##           range, the stamina for it, not rocked, and the opening it needs (a catch waits
##           for the leg to come up while the kick goes on)
##
## Every outcome is logged as a rule_answered event with its reason (A16): set, fired,
## cooling, slow, outranked, not_eligible, missed. Rules come in as set_rule commands,
## so a fight with rules replays from its command log. Every number is a first guess.

## Slots at the start of a career (a third comes with the coach's Tactician skill, later).
const MAX_SLOTS: int = 2
## Fight IQ 100 makes a rule fire ×1.2 as reliably, Fight IQ 0 ×0.8.
const RELIABILITY_PER_IQ: float = 0.2
## A fully hurt head takes this share off; being tired takes its stat penalty off (up to 30%).
const RELIABILITY_PER_HEAD_HURT: float = 0.5
## Each time a rule fires on the opponent's move, they disguise it a little more: this much
## off the rule's reliability at Fight IQ 100 (half at 50), up to ADAPT_MAX.
const ADAPT_PER_FIRE: float = 0.1
const ADAPT_MAX: float = 0.5

const SET := "set"
const FIRED := "fired"
const COOLING := "cooling"
const SLOW := "slow"
const OUTRANKED := "outranked"
const NOT_ELIGIBLE := "not_eligible"
const MISSED := "missed"

## One entry per slot, slot 1 first: {rule, slot, drilled (0–1), ready_at, fires}, or empty.
var slots: Array[Dictionary] = []

## The presets the slots draw from (data/rules; tests can add their own).
var library: RuleLibrary
var _triggers: TriggerLibrary
## How many slots hold a rule (on_event does nothing while it's 0).
var _filled: int = 0
## The rule waiting for the fighter's reaction time: {entry, started, notice, move}, or empty.
var _armed: Dictionary = {}


func _init(p_rules: RuleLibrary = null, p_triggers: TriggerLibrary = null) -> void:
	layer = DecisionLayer.RULE
	may_claim = false
	library = p_rules if p_rules != null else RuleLibrary.shared()
	_triggers = p_triggers if p_triggers != null else TriggerLibrary.shared()
	for n in MAX_SLOTS:
		slots.append({})


## "" when rule `rule_id` can go in `slot` (1 or 2) drilled to `drilled` (0–100), else why not.
## rule_id "" empties the slot.
func check(view: FightView, slot: int, rule_id: String, drilled: float) -> String:
	if slot < 1 or slot > MAX_SLOTS:
		return "there are %d rule slots" % MAX_SLOTS
	if drilled < 0.0 or drilled > 100.0:
		return "drilled is 0–100%"
	if rule_id == "":
		return ""
	if not library.has(rule_id):
		return "unknown rule"
	return _unknown_move(view, library.get_rule(rule_id).action)


## Puts rule `rule_id` in `slot` drilled to `drilled`, or empties the slot (rule_id "").
## Returns "" or why not (check).
func set_rule(view: FightView, slot: int, rule_id: String, drilled: float) -> String:
	var why: String = check(view, slot, rule_id, drilled)
	if why != "":
		return why
	if not _armed.is_empty() and _armed.entry.slot == slot:
		_armed = {}
	if rule_id == "":
		slots[slot - 1] = {}
	else:
		var rule: Dictionary = library.get_rule(rule_id)
		var was: Dictionary = slots[slot - 1]
		var same: bool = not was.is_empty() and was.rule.id == rule_id  # Kept between rounds: the opponent still knows it.
		slots[slot - 1] = { "rule": rule, "slot": slot, "drilled": drilled / 100.0,
			"ready_at": was.ready_at if same else 0, "fires": was.fires if same else 0 }
		_answer(slots[slot - 1], SET, "slot %d, drilled %d%%" % [slot, roundi(drilled)])
	_filled = 0
	for entry: Dictionary in slots:
		_filled += 0 if entry.is_empty() else 1
	_settle()
	return ""


## The chance the rule fires when its trigger comes (0–1), with the opponent's adaptation.
func reliability(view: FightView, entry: Dictionary) -> float:
	var f: FighterState = view.me
	var chance: float = entry.drilled
	chance *= 1.0 + RELIABILITY_PER_IQ * (f.effective_stat("fight_iq") - FighterState.DEFAULT_STAT) / 50.0
	chance *= (1.0 - f.tired()) * (1.0 - RELIABILITY_PER_HEAD_HURT * f.hurt("head"))
	chance *= 1.0 - adaptation(view, entry)
	return clampf(chance, 0.0, 1.0)


## How wise the opponent is to this rule: a share off its reliability (0 to ADAPT_MAX).
func adaptation(view: FightView, entry: Dictionary) -> float:
	return minf(ADAPT_MAX, ADAPT_PER_FIRE * entry.fires * view.opponent.effective_stat("fight_iq") / 100.0)


func on_event(view: FightView, event: FightEvent) -> void:
	if _filled == 0 or event.type == FightEvent.RULE_ANSWERED:
		return
	for entry: Dictionary in slots:
		if entry.is_empty() or not _triggers.matches(entry.rule.trigger, event, view.index):
			continue
		if not _armed.is_empty():
			if _armed.entry.slot <= entry.slot:
				_answer(entry, OUTRANKED, "the slot %d rule goes first" % _armed.entry.slot)
				continue
			_answer(_armed.entry, OUTRANKED, "the slot %d rule goes first" % entry.slot)
			_armed = {}
		if view.now < entry.ready_at:
			_answer(entry, COOLING, "fired %.0f s ago" % (float(view.now - entry.ready_at + _cooldown(entry)) / FightClock.TICKS_PER_SECOND))
			continue
		var chance: float = reliability(view, entry)
		if view.roll() >= chance:
			var wise: float = adaptation(view, entry)
			_answer(entry, SLOW, "didn't see it in time: %d%% sharp%s" % [roundi(chance * 100.0),
				", he's disguising it" if wise > 0.0 else ""])
			continue
		# Fighters step in turn each tick: a move started after this fighter's step is
		# first seen next tick (as the AI's reads and read calls, docs/01 §20).
		var seen: int = event.tick + (1 if view.steps_after_me(event.actor) else 0)
		_armed = { "entry": entry, "started": event.tick, "notice": seen + view.me.reaction_ticks(), "move": String(event.data.get("action_id", "")) }
	_settle()


func claim(view: FightView) -> Decision:
	if _armed.is_empty() or view.now < _armed.notice:
		return null
	var entry: Dictionary = _armed.entry
	if _armed.move != "" and view.opponent.action_id != _armed.move:
		_answer(entry, MISSED, "too late: the %s was over" % _move_name(view, _armed.move))
		_disarm()
		return null
	var id: String = entry.rule.action
	var action: Dictionary = view.actions.get_action(id)
	var why: String = view.why_not(id)
	if why == "" and view.me.is_rocked():
		why = "rocked"
	if why == "" and not action.ranges.has(view.band()):
		why = "out of range"
	if why == "" and view.me.stamina < float(action.stamina_cost):
		why = "too tired"
	if why != "":
		_answer(entry, NOT_ELIGIBLE, why)
		_disarm()
		return null
	if view.odds_ahead(id, view.ticks_to_land(id)).missing != "":
		return null  # Waits for the opening while the move goes on: a catch waits for the leg.
	return Decision.new(id, DecisionLayer.RULE, "rule: %s" % entry.rule.name)


func claimed_started(view: FightView, decision: Decision) -> void:
	if _armed.is_empty():
		return
	var entry: Dictionary = _armed.entry
	entry.ready_at = view.now + _cooldown(entry)
	entry.fires += 1
	var data := { "rule_id": entry.rule.id, "outcome": FIRED, "slot": entry.slot, "action_id": decision.action_id,
		"reason": "%d ticks after the %s started" % [view.now - _armed.started, _move_name(view, _armed.move)] }
	note(FightEvent.RULE_ANSWERED, data)
	_disarm()


static func _cooldown(entry: Dictionary) -> int:
	return int(entry.rule.cooldown_ms) / FightClock.TICK_MS


## "" when the fighter knows the move (their techniques or a basic move) and its technique.
static func _unknown_move(view: FightView, id: String) -> String:
	if not view.actions.has(id):
		return "unknown move"
	var action: Dictionary = view.actions.get_action(id)
	var technique: Variant = action.get("requires_technique")
	if (technique != null and not view.me.repertoire.has(technique)) or not (action.get("basic", false) or view.me.repertoire.has(id)):
		return "hasn't learned the %s" % _move_name(view, id)
	return ""


func _disarm() -> void:
	_armed = {}
	_settle()


func _settle() -> void:
	may_claim = not _armed.is_empty()


static func _move_name(view: FightView, id: String) -> String:
	return String(view.actions.get_action(id).name).to_lower() if view.actions.has(id) else id


func _answer(entry: Dictionary, outcome: String, reason: String) -> void:
	var data := { "rule_id": entry.rule.id, "outcome": outcome, "reason": reason, "slot": entry.slot }
	if outcome == SET:
		data.drilled = roundi(entry.drilled * 100.0)
	note(FightEvent.RULE_ANSWERED, data)
