class_name LiveCalls
extends DecisionSource
## Live calls (docs/01 §6.1–6.3, §22, #16): one fighter's corner shouting and the
## fighter acting on it. Every call goes through the same pipeline:
##
##   heard ─► voice (D28): costs voice; under 30 the call is garbled
##         ─► delay in fight time (D92): 6 ticks × Fight IQ × trust × tired/hurt (× 1.5 garbled)
##         ─► compliance (D5): ego, stubbornness, trust, panic, a garbled call
##         ─► feasibility: position, role, rules, a move the fighter knows
##         ─► one of three shapes (CallLibrary):
##              attempt  Takedown!, Clinch!, Get up!: the fighter goes for it, stepping
##                       in for up to 2 s to find the range (and catches a kick if one comes).
##                       An attempt with `then` (Feint!, D131) goes on: once the first move is
##                       over, the fighter goes straight into the first of those that would work
##              focus    Pressure!, Circle out! …: style leanings and weights tilt for 15 s;
##                       Go for the finish! (D200) sends the top fighter hunting a hold for 10 s
##              read     Catch the kick!: primed for 6 s; when the trigger comes the fighter
##                       reacts with their own reaction time (D93), at an attention cost (D67).
##                       A call with `combo` (Fire back!, D133) answers with the fighter's first
##                       combination that works from there, thrown as a whole
##
## Every outcome is logged as a call_answered event with its reason (A16): accepted,
## ignored, infeasible, fired (a read went off), missed (a read came too late),
## expired, replaced. A new call replaces one of the same shape still being processed
## (reads stack up to 2, D67). Every number is a first guess for the harness.

## 0.6 s of fight time (D92).
const BASE_DELAY_TICKS: int = 6
## Fight IQ 100 takes 25% off the delay, 0 adds 25%; trust 100 takes 20% off, 0 adds 20%.
const DELAY_PER_IQ: float = 0.25
const DELAY_PER_TRUST: float = 0.2
## Being tired adds its stat penalty (up to 30%), a hurt head up to another 30%.
const DELAY_PER_HEAD_HURT: float = 0.3
## Crowd noise and the coach's level (D15) arrive with venues and careers; 1.0 = no effect.
const CROWD_NOISE: float = 1.0
const COACH_LEVEL: float = 1.0

## The voice meter (D28): 100 at the bell, refills 8 a fight-second; under 30 calls are
## garbled: half as slow again and 20% less likely to be followed.
const VOICE_MAX: float = 100.0
const VOICE_PER_SECOND: float = 8.0
const GARBLED_BELOW: float = 30.0
const GARBLED_DELAY: float = 1.5
## Coach trust, 0–100, for this fight (the career relationship replaces the 50 start).
## The same call again within 3 s of fight time is spam and costs trust (D28).
const TRUST_START: float = 50.0
const SPAM_TICKS: int = 30
const SPAM_TRUST_COST: float = 2.0

## Compliance (D5): chance to ignore a call. Rare for a calm, neutral fighter.
const IGNORE_BASE: float = 0.03
const IGNORE_PER_EGO: float = 0.10  # at Ego +100; Humble fighters take it off
const IGNORE_PER_STUBBORN: float = 0.05  # at Stubborn (Coachable −100); Coachable takes it off
const IGNORE_PER_DISTRUST: float = 0.40  # at trust 0; trust 100 takes it off
const IGNORE_PANICKING: float = 0.25
const IGNORE_GARBLED: float = 0.50
const IGNORE_MAX: float = 0.9

## An accepted attempt: the fighter keeps looking for the range or the opening this long.
const ATTEMPT_TICKS: int = 20
## An attempt with `then` (Feint!, D131): the follow-up waits for the first move to be over and
## must start within this many ticks after it, inside the feint's set-up (FightSim.SET_UP_TICKS).
const THEN_TICKS: int = 3
## Read calls primed at once (D67); a third replaces the oldest.
const MAX_READS: int = 2
## A move started on a call takes the place of one the fighter would have tried: their own
## tries of that kind of move from standing (takedowns, clinch entries) wait this long after
## it. Calls pick the moment; they don't add work. Moves off the feet (getting up, breaking
## the clinch) are never held back.
const SPENT_TICKS: int = 450
## A combination fired on a call (Fire back!, D133) takes the place of the fighter's own
## attacks the same way: they don't lead with anything of their own for this long after it
## (counters, the rest of a combination and their own reads still go).
const LEADS_HELD_TICKS: int = 100
## Every call heard takes the fighter's eyes off the opponent for a moment: this much
## off their striking and takedown defense (like a primed read, D67) for this long.
const HEARD_ATTENTION: float = 0.2
const HEARD_TICKS: int = 5

const ATTEMPT := "attempt"
const FOCUS := "focus"
const READ := "read"

const ACCEPTED := "accepted"
const IGNORED := "ignored"
const INFEASIBLE := "infeasible"
const FIRED := "fired"
const MISSED := "missed"
const EXPIRED := "expired"
const REPLACED := "replaced"

## Coach trust for this fight, 0–100.
var trust: float = TRUST_START
## Calls heard and still being processed: [{call, heard, ready_at, garbled}], in the order heard.
var pending: Array[Dictionary] = []
## The attempt the fighter is going for: {call, heard, until, why, then?}, or empty. `then` is
## true once the first move of a call with a `then` list has started: the follow-up is next.
var attempt: Dictionary = {}
## The focus the fighter is fighting to: {call, until}, or empty.
var focus: Dictionary = {}
## Primed reads, oldest first: [{call, until, notice, move}]. notice ≥ 0 once the trigger came.
var reads: Array[Dictionary] = []
## How much the primed reads cost the fighter's other defense (0–1), for the sim to apply.
var attention: float = 0.0
## True when a focus started or ended: the AI should look at its leanings again now.
var retilt: bool = false
## True while anything is pending, being attempted, focused on or primed (update() has work).
var active: bool = false

var _triggers: TriggerLibrary
var _voice: float = VOICE_MAX
var _voice_at: int = 0
var _last_heard: Dictionary = {}  # call id → tick
## The read or attempt whose move the fighter just started (claimed_started logs it).
var _claimed: Dictionary = {}
## Move category → tick until which the fighter's own tries of that kind from standing wait (SPENT_TICKS).
var _spent: Dictionary = {}
## Tick until which the last call heard has the fighter's attention (HEARD_TICKS).
var _listening_until: int = -1
## Tick until which the fighter leads with nothing of their own (LEADS_HELD_TICKS).
var _leads_held_until: int = -1


func _init(p_triggers: TriggerLibrary = null) -> void:
	layer = DecisionLayer.CALL
	may_claim = false
	_triggers = p_triggers if p_triggers != null else TriggerLibrary.shared()


## Attempt, focus or read (see the class notes).
static func shape(call: Dictionary) -> String:
	if call.get("kind", "now") == READ:
		return READ
	return FOCUS if call.has("focus") else ATTEMPT


## The voice meter at tick `now` (it refills between calls).
func voice(now: int) -> float:
	return minf(VOICE_MAX, _voice + VOICE_PER_SECOND * float(now - _voice_at) / FightClock.TICKS_PER_SECOND)


## The corner makes a call. Returns what the call_heard event says: {call_id, voice, garbled, delay, trust, spam}.
func hear(view: FightView, call: Dictionary) -> Dictionary:
	var before: float = voice(view.now)
	var garbled: bool = before < GARBLED_BELOW
	_voice = maxf(0.0, before - float(call.voice_cost))
	_voice_at = view.now
	var spam: bool = garbled or (_last_heard.has(call.id) and view.now - int(_last_heard[call.id]) <= SPAM_TICKS)
	if spam:
		trust = maxf(0.0, trust - SPAM_TRUST_COST)
	_last_heard[call.id] = view.now
	var kind: String = shape(call)
	if kind != READ:
		for n in range(pending.size() - 1, -1, -1):
			if shape(pending[n].call) == kind:
				_answer(pending[n].call, REPLACED, "%s came first" % call.name)
				pending.remove_at(n)
	_listening_until = view.now + HEARD_TICKS
	_count_attention(view.now)
	var delay: int = delay_ticks(view, garbled)
	pending.append({ "call": call, "heard": view.now, "ready_at": view.now + delay, "garbled": garbled })
	active = true
	return { "call_id": call.id, "voice": roundi(_voice), "garbled": garbled, "delay": delay, "trust": roundi(trust), "spam": spam }


## Ticks between the call and the fighter acting on it (docs/01 §6.2), at least their reaction time.
func delay_ticks(view: FightView, garbled: bool = false) -> int:
	var f: FighterState = view.me
	var ticks: float = BASE_DELAY_TICKS
	ticks *= 1.0 - DELAY_PER_IQ * (f.effective_stat("fight_iq") - FighterState.DEFAULT_STAT) / 50.0
	ticks *= 1.0 - DELAY_PER_TRUST * (trust - TRUST_START) / 50.0
	ticks *= 1.0 + f.tired() + DELAY_PER_HEAD_HURT * f.hurt("head")
	ticks *= CROWD_NOISE * COACH_LEVEL
	if garbled:
		ticks *= GARBLED_DELAY
	return maxi(f.reaction_ticks(), roundi(ticks))


## Chance the fighter ignores this call (D5), with each part named: {chance, parts: {reason: share}}.
func ignore_odds(view: FightView, garbled: bool = false) -> Dictionary:
	var f: FighterState = view.me
	var personality: Dictionary = f.profile.get("personality", {})
	var parts := {
		"doesn't go with it": IGNORE_BASE,
		"ego: wants it their way": IGNORE_PER_EGO * float(personality.get("ego", 0)) / 100.0,
		"stubborn": -IGNORE_PER_STUBBORN * float(personality.get("coachable", 0)) / 100.0,
		"doesn't trust the corner": IGNORE_PER_DISTRUST * (TRUST_START - trust) / TRUST_START,
	}
	if f.is_panicking():
		parts["panicking"] = IGNORE_PANICKING
	elif f.is_rocked():
		parts["rocked"] = IGNORE_PANICKING
	if garbled:
		parts["couldn't make out the call"] = IGNORE_GARBLED
	var chance: float = 0.0
	for why: String in parts:
		chance += parts[why]
	return { "chance": clampf(chance, 0.0, IGNORE_MAX), "parts": parts }


## "" when the fighter goes along with the call, else why not: the biggest reason to ignore it.
func refusal(view: FightView, heard: Dictionary) -> String:
	var odds: Dictionary = ignore_odds(view, heard.garbled)
	if view.roll() >= odds.chance:
		return ""
	var top: String = ""
	for why: String in odds.parts:
		if top == "" or odds.parts[why] > odds.parts[top]:
			top = why
	return top


## Moves on the clock: processes calls whose delay is up, ends focuses and reads that
## ran out and attempts that found nothing. The sim calls it every tick while `active`.
func update(view: FightView) -> void:
	if _listening_until >= 0 and view.now >= _listening_until:
		_listening_until = -1
		_count_attention(view.now)
	var n: int = 0
	while n < pending.size():
		if view.now < pending[n].ready_at:
			n += 1
			continue
		var heard: Dictionary = pending[n]
		pending.remove_at(n)
		_process(view, heard)
	if not focus.is_empty() and view.now >= focus.until:
		_answer(focus.call, EXPIRED, "back to the gameplan")
		focus = {}
		retilt = true
	for k in range(reads.size() - 1, -1, -1):
		var read: Dictionary = reads[k]
		if read.notice >= 0 and view.opponent.action_id != read.move:
			_answer(read.call, MISSED, "too late: the %s was over" % _move_name(view, read.move))
			read.notice = -1
		if view.now >= read.until:
			_answer(read.call, EXPIRED, "nothing came in %d s" % roundi(float(read.call.read.duration_ms) / 1000.0))
			reads.remove_at(k)
			_count_attention(view.now)
	if not attempt.is_empty() and view.now >= attempt.until:
		_answer(attempt.call, INFEASIBLE, attempt.why if attempt.why != "" else "busy until it was too late")
		attempt = {}
	_settle()


func claim(view: FightView) -> Decision:
	for read: Dictionary in reads:
		if read.notice < 0 or view.now < read.notice:
			continue
		var id: String = _pick(view, read.call, read)
		if id != "":
			_claimed = read
			if read.call.get("combo", false):
				var d := Decision.new(id, DecisionLayer.CALL, "fires back after the %s" % _move_name(view, read.move))
				d.combo = String(read.get("combo", ""))
				d.combo_runs = d.combo != ""
				return d
			return Decision.new(id, DecisionLayer.CALL, "read the %s" % _move_name(view, read.move))
	if not attempt.is_empty():
		var id: String = _pick(view, attempt.call, attempt)
		if id != "":
			_claimed = attempt
			if attempt.get("then", false):
				return Decision.new(id, DecisionLayer.CALL, "off the %s" % _move_name(view, attempt.call.actions[0]))
			return Decision.new(id, DecisionLayer.CALL, "call after %d ticks" % (view.now - attempt.heard))
	return null


func claimed_started(view: FightView, decision: Decision) -> void:
	if _claimed.is_empty():
		return
	var action: Dictionary = view.actions.get_action(decision.action_id)
	if action.positions.has(PositionLibrary.STANDING) and action.category != FighterAI.STRIKE:
		_spent[action.category] = view.now + SPENT_TICKS  # Strikes are never held back (D133).
	if decision.combo != "":
		_leads_held_until = view.now + LEADS_HELD_TICKS
	if reads.has(_claimed):
		_answer(_claimed.call, FIRED, "%s, %d ticks after the %s started" % [decision.reason, view.now - _claimed.seen, _move_name(view, _claimed.move)], decision.action_id)
		reads.erase(_claimed)
		_count_attention(view.now)
	else:
		_answer(_claimed.call, ACCEPTED, decision.reason, decision.action_id)
		attempt = {}
		if _claimed.call.has("then") and not _claimed.get("then", false):
			attempt = { "call": _claimed.call, "heard": _claimed.heard, "why": "", "then": true,
				"until": view.now + _move_ticks(view, decision.action_id) + THEN_TICKS }
	_claimed = {}
	_settle()


func on_event(view: FightView, event: FightEvent) -> void:
	if reads.is_empty():
		return
	for read: Dictionary in reads:
		if read.notice < 0 and _triggers.matches(read.call.read.trigger, event, view.index):
			# Fighters step in turn each tick: a move started after this fighter's step is
			# first seen next tick (as the AI's reads, docs/01 §20).
			read.seen = event.tick + (1 if view.steps_after_me(event.actor) else 0)
			read.notice = read.seen + view.me.reaction_ticks()
			read.move = event.data.action_id
	_settle()


func adjust_lead_rate(view: FightView, rate: float) -> float:
	return 0.0 if view.now < _leads_held_until else rate


func adjust_leaning(_view: FightView, which: String, value: float) -> float:
	if focus.is_empty():
		return value
	return value + float(focus.call.focus.get("leanings", {}).get(which, 0.0))


func adjust_weight(view: FightView, action: Dictionary, weight: float) -> float:
	if not _spent.is_empty() and view.now < int(_spent.get(action.category, -1)) and action.positions.has(PositionLibrary.STANDING):
		return 0.0
	if focus.is_empty():
		return weight
	return Gameplan.scale_weight(focus.call.focus.get("weights", {}), action, weight)


func adjust_read(_view: FightView, action: Dictionary, chance: float) -> float:
	if focus.is_empty():
		return chance
	return chance + float(focus.call.focus.get("read_bonus", {}).get(action.category, 0.0))


func adjust_sprawl(_view: FightView, chance: float) -> float:
	if focus.is_empty():
		return chance
	return chance + float(focus.call.focus.get("sprawl_bonus", 0.0))


## A focus call's push on covering up when rocked (D180): Survive!'s cover_bonus.
func adjust_cover(_view: FightView, chance: float) -> float:
	if focus.is_empty():
		return chance
	return chance + float(focus.call.focus.get("cover_bonus", 0.0))


## A struggle call's push on a submission hold (D126): Finish it! for the attacker, Defend the
## sub! for the defender, while the focus is on (FightSim.struggle_share).
func struggle_bonus() -> float:
	if focus.is_empty():
		return 0.0
	return float(focus.call.focus.get("struggle", 0.0))


## The extra stamina each beat of a struggle costs while a struggle call's focus is on.
func struggle_stamina() -> float:
	if focus.is_empty():
		return 0.0
	return float(focus.call.focus.get("struggle_stamina", 0.0))


## *Go for the finish!* (D200): while its focus is on, the top fighter hunts a hold (FighterAI._work_position).
func hunt(_view: FightView) -> Dictionary:
	if focus.is_empty() or not focus.call.focus.has("hunt"):
		return {}
	return { "since": focus.since, "rate": float(focus.call.focus.hunt.get("rate", 0.0)) }


## Going for an attempt that's out of range: step in to the nearest band one of its moves reaches from.
func adjust_feet(view: FightView, feet: FeetPlan) -> void:
	if attempt.is_empty() or not view.is_standing():
		return
	var gap: float = view.distance()
	var band: String = Octagon.band(gap)
	var target: float = -1.0
	for id: String in _moves(view, attempt.call, attempt.get("then", false)):
		var action: Dictionary = view.actions.get_action(id)
		if FighterAI._needs_opening(action):
			continue  # A catch waits for the kick: walk to where the plain moves reach.
		var ranges: Array = action.ranges
		if ranges.has(band):
			return  # In range already: stand and wait for the moment.
		var spot: String = FighterAI._nearest_band(ranges, band)
		if Octagon.BAND_CENTRES.has(spot) and (target < 0.0 or Octagon.BAND_CENTRES[spot] > target):
			target = Octagon.BAND_CENTRES[spot]
	if target > 0.0 and target < gap:
		feet.want = target
		feet.circle = 0.0
		feet.cut = 0.0


## The call's moves this fighter could use here (known, legal, from this position and role):
## its `actions`, or with `then` its follow-ups. A move at a downed man (following him down,
## D142) only while he's down: otherwise Takedown! is the shots it always was.
func _moves(view: FightView, call: Dictionary, then: bool = false) -> Array[String]:
	var out: Array[String] = []
	for id: String in (call.then if then else call.actions):
		if _at_downed_man(view.actions.get_action(id)) and not view.opponent.is_down():
			continue
		if view.why_not(id) == "" and (call.get("bare", false) or _knows(view.me, view.actions.get_action(id))):
			out.append(id)
	return out


## The first of the call's moves that would work right now: in range, with the stamina
## for it, and with the opening it needs there when it lands (a catch needs a kick).
## "" when none would; `entry.why` then says what was missing.
func _pick(view: FightView, call: Dictionary, entry: Dictionary) -> String:
	if call.get("combo", false):
		var first: String = _first_combo(view, entry)
		if first != "":
			return first
	var band: String = view.band()
	for id: String in _moves(view, call, entry.get("then", false)):
		var action: Dictionary = view.actions.get_action(id)
		if not action.ranges.has(band):
			entry.why = "couldn't get in range"
			continue
		if view.me.stamina < float(action.stamina_cost):
			entry.why = "too tired"
			continue
		var b: OddsBreakdown = view.odds_ahead(id, view.ticks_to_land(id))
		if b.missing != "":
			if entry.why == "":
				entry.why = "no opening (%s)" % b.missing
			continue
		return id
	return ""


## A call with `combo` (Fire back!, D133): the first of the fighter's combinations (in their
## profile's order) whose first move would work right now; `entry.combo` says which. "" when
## none would (the call's `actions` are then thrown as single strikes).
func _first_combo(view: FightView, entry: Dictionary) -> String:
	entry.combo = ""
	var band: String = view.band()
	for combo: String in view.me.combos:
		if not view.combos.has(combo):
			continue
		var id: String = view.combos.move(combo, 0)
		var action: Dictionary = view.actions.get_action(id)
		if view.why_not(id) == "" and _knows(view.me, action) and action.ranges.has(band) and view.me.stamina >= float(action.stamina_cost):
			entry.combo = combo
			return id
	return ""


func _process(view: FightView, heard: Dictionary) -> void:
	var call: Dictionary = heard.call
	var why: String = refusal(view, heard)
	if why != "":
		_answer(call, IGNORED, why)
		return
	why = _infeasible(view, call)
	if why != "":
		_answer(call, INFEASIBLE, why)
		return
	match shape(call):
		READ:
			var read := { "call": call, "until": view.now + int(call.read.duration_ms) / FightClock.TICK_MS,
				"notice": -1, "seen": -1, "move": "", "why": "" }
			for k in range(reads.size() - 1, -1, -1):
				if reads[k].call.id == call.id:
					reads.remove_at(k)  # Called again: primed afresh.
			if reads.size() >= MAX_READS:
				_answer(reads[0].call, REPLACED, "two reads at most")
				reads.remove_at(0)
			reads.append(read)
			_count_attention(view.now)
			_answer(call, ACCEPTED, "watching for it for %d s" % roundi(float(call.read.duration_ms) / 1000.0))
		FOCUS:
			if not focus.is_empty():
				_answer(focus.call, REPLACED, "now %s" % call.name)
			focus = { "call": call, "since": view.now, "until": view.now + int(call.focus.duration_ms) / FightClock.TICK_MS }
			retilt = true
			_answer(call, ACCEPTED, "for %d s" % roundi(float(call.focus.duration_ms) / 1000.0))
		_:
			attempt = { "call": call, "heard": heard.heard, "until": view.now + ATTEMPT_TICKS, "why": "" }
	_settle()


## "" when the fighter could act on this call from here, else why not.
func _infeasible(view: FightView, call: Dictionary) -> String:
	var positions: Array = call.get("positions", [])
	if not positions.is_empty() and not positions.has(view.position()):
		return "not possible from this position"
	if call.has("roles") and not call.roles.has(view.my_role()):
		return "not possible from the %s" % view.my_role()
	var technique: Variant = call.get("requires_technique")
	if technique != null and not view.me.repertoire.has(technique):
		return "hasn't learned the %s" % _move_name(view, technique)
	if call.get("actions", []).is_empty() or not _moves(view, call).is_empty():
		return ""
	for id: String in call.actions:
		if not call.get("bare", false) and not _knows(view.me, view.actions.get_action(id)):
			continue  # Where a move they don't know works from says nothing (Takedown! lists clinch throws, D128).
		var why: String = view.why_not(id)
		if why != "":
			return why
	return "doesn't know how"


static func _at_downed_man(action: Dictionary) -> bool:
	var block: Variant = action.get(action.category)
	return block is Dictionary and bool(block.get("downed", false))


func _knows(f: FighterState, action: Dictionary) -> bool:
	return action.get("basic", false) or f.repertoire.has(action.id)


func _count_attention(now: int) -> void:
	attention = HEARD_ATTENTION if now < _listening_until else 0.0
	for read: Dictionary in reads:
		attention += float(read.call.read.get("attention_cost", 0.0))


func _settle() -> void:
	var armed: bool = false
	for read: Dictionary in reads:
		armed = armed or read.notice >= 0
	may_claim = armed or not attempt.is_empty()
	steers_feet = not attempt.is_empty()
	active = may_claim or not pending.is_empty() or not focus.is_empty() or not reads.is_empty() or _listening_until >= 0


## Ticks a move takes this fighter from start to finish.
static func _move_ticks(view: FightView, id: String) -> int:
	var ticks: int = 0
	for phase: String in ActionLibrary.PHASES:
		ticks += view.phase_ticks(id, phase)
	return ticks


static func _move_name(view: FightView, id: String) -> String:
	return String(view.actions.get_action(id).name).to_lower() if view.actions.has(id) else id


func _answer(call: Dictionary, outcome: String, reason: String, action_id: String = "") -> void:
	var data := { "call_id": call.id, "outcome": outcome, "reason": reason }
	if action_id != "":
		data.action_id = action_id
	note(FightEvent.CALL_ANSWERED, data)
