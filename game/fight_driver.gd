class_name FightDriver
extends RefCounted
## Plays a FightSim in real time for the fight screen (#19, docs/06 §3, docs/01 §2):
## turns frame time into whole sim ticks at the chosen speed and remembers where
## each fighter stood one tick ago, so the 3D view can slide between ticks.
##
## Speed only changes how many ticks are fed in per real second, never what a tick
## does, so a fight plays out exactly the same at any speed, paused or not (A13
## "Slow motion", tested in tests/game/test_fight_driver.gd). Every number is in
## real seconds unless it says fight time.
##
## Speeds (D9, D91): Normal is 2× fight time (1× for the D91 playtest comparison),
## Fast is 4×, slow-mo is half of Normal. On top of the player's choice:
## - auto slow-mo (D53): a fighter rocked or knocked down, a scramble, or a submission
##   locked in (each beat of the struggle, D126) slows the
##   fight for AUTO_SLOW_SECONDS;
## - the perfect-call flourish (D52): a move the player's call started that works
##   as a counter (a takedown off a caught kick, a strike into the opponent's
##   commitment) slows it for FLOURISH_SECONDS and says so (`flourish`);
## - the bell holds the fight between rounds (`round_over`) until resume().

signal flourish(event: FightEvent)
signal round_over(event: FightEvent)
signal fight_over(event: FightEvent)

const SLOW := "slow"
const NORMAL := "normal"
const FAST := "fast"
## Fight seconds per real second.
const FAST_RATE: float = 4.0
const NORMAL_RATES: Array[float] = [2.0, 1.0]
## Slow-mo plays at this share of Normal (2× → 1× fight time, docs/01 §2).
const SLOW_SHARE: float = 0.5
const AUTO_SLOW_SECONDS: float = 1.5
const FLOURISH_SECONDS: float = 1.2
## A frame never runs more than this many ticks (a long hitch doesn't fast-forward the fight).
const MAX_TICKS_PER_FRAME: int = 8

var sim: FightSim
## The fighter whose corner the player is (their calls, their flourishes).
var player: int = 0
## Normal speed in fight seconds per real second: 2 (D9) or 1 (the D91 comparison).
var normal_rate: float = 2.0
## The speed the player picked: SLOW, NORMAL or FAST.
var speed: String = NORMAL
## Active pause (Easy only, D50: the fight screen allows it). Calls still go in.
var paused: bool = false
## Held by the game: the bell between rounds, the menu, the towel question.
var held: bool = false
var auto_slow: bool = true
var flourishes: bool = true

## Each fighter's spot one tick ago, for sliding between ticks.
var _before: Array[Vector2] = []
var _budget: float = 0.0
var _slow_left: float = 0.0
## Which layer started each fighter's current move ("call", "rule", "ai" …), from its telegraph.
var _started_by: Array[String] = ["", ""]


func _init(p_sim: FightSim, p_player: int = 0) -> void:
	sim = p_sim
	player = p_player
	for f in sim.fighters:
		_before.append(f.pos)
	sim.event_emitted.connect(_on_event)


## Fight seconds per real second right now (0 while paused or held).
func rate() -> float:
	if paused or held or sim.is_over():
		return 0.0
	if speed == SLOW or _slow_left > 0.0:
		return normal_rate * SLOW_SHARE
	return FAST_RATE if speed == FAST else normal_rate


## True while auto slow-mo or a flourish is slowing the fight.
func is_auto_slowed() -> bool:
	return _slow_left > 0.0 and speed != SLOW and rate() > 0.0


## Feeds in the ticks that `delta` real seconds are worth. Returns how many ran.
func advance(delta: float) -> int:
	var r: float = rate()
	if r <= 0.0:
		return 0
	_slow_left = maxf(0.0, _slow_left - delta)
	_budget += delta * r * FightClock.TICKS_PER_SECOND
	var ran: int = 0
	while _budget >= 1.0 and ran < MAX_TICKS_PER_FRAME and rate() > 0.0:
		_budget -= 1.0
		step()
		ran += 1
	if ran >= MAX_TICKS_PER_FRAME or rate() <= 0.0:
		_budget = minf(_budget, 0.999)
	return ran


## One tick, remembering where the fighters stood before it.
func step() -> void:
	if sim.is_over():
		return
	var round_before: int = sim.clock.current_round
	for i in sim.fighters.size():
		_before[i] = sim.fighters[i].pos
	sim.tick()
	if sim.clock.current_round != round_before:
		_snap()


## How far into the next tick the view is (0–1), for sliding between ticks.
func alpha() -> float:
	return clampf(_budget, 0.0, 1.0)


## Where fighter i is drawn this frame: between last tick's spot and this tick's.
func shown_pos(i: int) -> Vector2:
	return _before[i].lerp(sim.fighters[i].pos, alpha())


## The player's corner makes a call; it lands on the next tick, paused or not (docs/01 §2).
func make_call(call_id: String) -> bool:
	return sim.submit(FightCommand.live_call(sim.now, player, call_id))


## Puts a drilled rule in one of the player's slots (only before a round: tick 0 or between rounds).
func set_rule(slot: int, rule_id: String, drilled: float) -> bool:
	return sim.submit(FightCommand.set_rule(sim.now, player, slot, rule_id, drilled))


## The player's corner throws in the towel (D31): a TKO loss on the next tick.
func throw_towel() -> void:
	sim.submit(FightCommand.throw_towel(sim.now, player))
	held = false
	paused = false
	while not sim.is_over():
		step()


## Starts the next round after the bell (or the first one).
func resume() -> void:
	held = false


func toggle_slow() -> void:
	speed = NORMAL if speed == SLOW else SLOW


func toggle_fast() -> void:
	speed = NORMAL if speed == FAST else FAST


## The speed as the top bar shows it, e.g. "2×", "1× slow-mo", "paused".
func label() -> String:
	if paused:
		return "paused"
	if held:
		return "%s× · stopped" % _number(normal_rate)
	var r: float = rate()
	var text: String = "%s×" % _number(r)
	if speed == SLOW or is_auto_slowed():
		text += " slow-mo"
	elif speed == FAST:
		text += " fast"
	return text


static func _number(r: float) -> String:
	return "%d" % roundi(r) if is_equal_approx(r, roundf(r)) else "%.1f" % r


func _snap() -> void:
	for i in sim.fighters.size():
		_before[i] = sim.fighters[i].pos
	_budget = 0.0


func _on_event(event: FightEvent) -> void:
	match event.type:
		FightEvent.ACTION_PHASE:
			if event.data.phase == "telegraph":
				_started_by[event.actor] = String(event.data.get("by", ""))
		FightEvent.ROCKED, FightEvent.KNOCKDOWN, FightEvent.LIVER_SHOT:
			_slow_down(AUTO_SLOW_SECONDS, auto_slow)
		FightEvent.POSITION_CHANGED:
			if event.data.get("position", "") == PositionLibrary.SCRAMBLE:
				_slow_down(AUTO_SLOW_SECONDS, auto_slow)
		FightEvent.SUBMISSION_LOCKED, FightEvent.SUBMISSION_BEAT:
			_slow_down(AUTO_SLOW_SECONDS, auto_slow)  # Slow for the whole struggle (D53, D126).
		FightEvent.GRAPPLE_WON, FightEvent.STRIKE_LANDED:
			if is_perfect_call(event):
				_slow_down(FLOURISH_SECONDS, flourishes)
				flourish.emit(event)
		FightEvent.ROUND_ENDED:
			if not sim.clock.is_fight_over():
				held = true
				round_over.emit(event)
		FightEvent.FIGHT_ENDED:
			fight_over.emit(event)


## A move the player's call started that worked against the opponent's commitment (D52).
func is_perfect_call(event: FightEvent) -> bool:
	return event.actor == player and counts_as_perfect(event, _started_by[player], sim.actions)


## The rule for a perfect call, given who chose the actor's move: their corner's call, and
## it worked (a takedown that lands, or a strike that lands in the opponent's wind-up or recovery).
static func counts_as_perfect(event: FightEvent, started_by: String, actions: ActionLibrary) -> bool:
	if started_by != DecisionLayer.CALL:
		return false
	if event.type == FightEvent.GRAPPLE_WON:
		var id: String = event.data.get("action_id", "")
		return event.data.get("result", "") == PositionLibrary.SUCCESS and actions.has(id) \
			and actions.get_action(id).category == "takedown"
	return event.type == FightEvent.STRIKE_LANDED and bool(event.data.get("counter", false))


func _slow_down(seconds: float, allowed: bool) -> void:
	if allowed:
		_slow_left = maxf(_slow_left, seconds)
