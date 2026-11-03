class_name SprawlReflex
extends RefCounted
## The sprawl reflex minigame (docs/03 §13.5, D411): your fighter and a wrestling partner in the fight engine, the
## partner shooting double legs at you with feints mixed in, some of them shot off the feint. You press Space to sprawl.
## It plays a Sprawl drills session; how well it went is the session's quality (TrainingCamp.PLAYED_MIN–PLAYED_MAX).
##
## Pure logic and seeded. The engine is the referee, so the timing is the fights' own (docs/01 §21.2): a sprawl works
## when its active phase meets the shot's drive. The sim runs as a drill (FightSim.drill): a sprawl that meets the shot
## always works and a shot not sprawled on always lands, so only the timing counts. Both men are DrillAI: he waits for
## your key, the partner shoots on the drill's script. A shot that gets through takes you down; a moment later both are
## stood back up in a fresh sim (reset(): the screen re-watches the new one).
##
## The partner gets quicker as your Takedown defence grows: the reps come closer together, more of them are feints and
## the drill runs faster (fight seconds per real second), and tiredness speeds it up too (the reflexes are slower).

## The partner (a data/fighters id).
const PARTNER: String = "wrestler"
## About a minute on screen (D38): this many real seconds of drill.
const ROUND_SECONDS: float = 60.0
## Seconds (fight time) from one rep ending to the next starting: GAP_SLOW at Takedown defence LEVEL_LOW, GAP_FAST
## at LEVEL_HIGH, ± GAP_JITTER at random.
const GAP_SLOW: float = 2.4
const GAP_FAST: float = 1.2
const GAP_JITTER: float = 0.4
## The share of reps that are feints, FEINTS_LOW to FEINTS_HIGH; FEINT_SHOT_SHARE of those he shoots off the feint.
const FEINTS_LOW: float = 0.2
const FEINTS_HIGH: float = 0.5
const FEINT_SHOT_SHARE: float = 0.5
## Fight seconds per real second, SPEED_LOW to SPEED_HIGH; from fatigue TIRED_FROM it goes up in a line to
## × (1 + TIRED_SPEED) at 100 (the same 40 where mitt work's windows start shrinking).
const SPEED_LOW: float = 1.0
const SPEED_HIGH: float = 1.3
const TIRED_FROM: float = 40.0
const TIRED_SPEED: float = 0.2
const LEVEL_LOW: float = 20.0
const LEVEL_HIGH: float = 90.0
## The first rep comes this long (fight time) after a start or a reset: time to settle at range.
const SETTLE_SECONDS: float = 1.2
## Taken down: this long on the mat (fight time) before both are stood back up.
const DOWN_SECONDS: float = 1.2
## The score: shots stuffed, less STRAY_COST for each sprawl that met nothing (a bite on a feint, or just jumpy).
const STRAY_COST: float = 0.25
## A stray sprawl ending within this many ticks of the partner's feint starting was a bite on it.
const FEINT_BITE_TICKS: int = 12
## Where the two stand at a start or a reset, metres from the middle (mid range apart).
const START_SPOT: float = 0.95

const STUFFED := "stuffed"
const TAKEN_DOWN := "taken down"
const BIT := "bit on the feint"
const STRAY := "nothing there"

## Something happened worth saying on screen: STUFFED, TAKEN_DOWN, BIT or STRAY.
signal judged(what: String)

var him: Dictionary
var level: float
var fatigue: float
var speed: float
var gap: float
var feint_share: float
var seed_in: int
var sim: FightSim
## The drill's length in fight ticks, across every sim (each reset starts a new one at tick 0).
var length_ticks: int
var counts := { STUFFED: 0, TAKEN_DOWN: 0, BIT: 0, STRAY: 0 }
## Reps started, by kind: "shot", "feint", "feint_shot".
var reps: Array[String] = []

var _roster: FighterLibrary
var _actions: ActionLibrary
var _rng := RandomNumberGenerator.new()
var _partner: DrillAI
var _done_ticks: int = 0  # Fight ticks in the sims before this one.
var _resets: int = 0
var _reset_at: int = -1
var _sprawl_open: bool = false
var _feint_at: int = -1000
var _rep_open: bool = false


## `profile` is his fighter@1 profile (the camp's fighter as he is now); `level` his Takedown defence.
func _init(profile: Dictionary, level_in: float, fatigue_in: float, drill_seed: int, roster: FighterLibrary = null,
		actions: ActionLibrary = null) -> void:
	him = profile
	level = level_in
	fatigue = fatigue_in
	seed_in = drill_seed
	_rng.seed = hash([drill_seed, "sprawl"])
	_roster = roster if roster != null else FighterLibrary.load_dir()
	_actions = actions if actions != null else ActionLibrary.load_dir()
	var t: float = clampf((level - LEVEL_LOW) / (LEVEL_HIGH - LEVEL_LOW), 0.0, 1.0)
	gap = lerpf(GAP_SLOW, GAP_FAST, t)
	feint_share = lerpf(FEINTS_LOW, FEINTS_HIGH, t)
	speed = lerpf(SPEED_LOW, SPEED_HIGH, t) * (1.0 + TIRED_SPEED * clampf((fatigue - TIRED_FROM) / (100.0 - TIRED_FROM), 0.0, 1.0))
	length_ticks = roundi(ROUND_SECONDS * speed * FightClock.TICKS_PER_SECOND)
	_new_sim()


## Fight ticks run so far, across every sim.
func elapsed() -> int:
	return _done_ticks + sim.now


func is_over() -> bool:
	return elapsed() >= length_ticks


## Real seconds left on screen.
func seconds_left() -> float:
	return maxf(0.0, float(length_ticks - elapsed()) / FightClock.TICKS_PER_SECOND / speed)


## Space: sprawl, if he's free to (a sprawl still going, or getting back up from one, can't start another).
## Returns true when it went in.
func press() -> bool:
	if is_over() or not sim.situation.is_standing() or not sim.fighters[0].is_free() or sim.fighters[0].queued_action_id != "":
		return false
	return sim.submit(FightCommand.queue_action(sim.now, 0, "sprawl"))


## One tick of the drill (tests and tools; the screen's FightDriver ticks the sim itself and calls reset_if_due()).
func tick() -> void:
	sim.tick()
	reset_if_due()


## After a takedown, once he's had his moment on the mat: both stood back up in a fresh sim. True when it reset (the
## screen then watches the new sim).
func reset_if_due() -> bool:
	if _reset_at < 0 or sim.now < _reset_at or is_over():
		return false
	_close_sprawl()
	_done_ticks += sim.now
	_resets += 1
	_new_sim()
	return true


## The marks' part, 0–1: shots stuffed, less STRAY_COST a stray sprawl, over the shots he got to (stuffed or not).
func accuracy() -> float:
	var shots: int = shots_met()
	if shots == 0:
		return 0.0
	return clampf((float(counts[STUFFED]) - STRAY_COST * (counts[STRAY] + counts[BIT])) / shots, 0.0, 1.0)


## Shots that reached him: stuffed or taken down.
func shots_met() -> int:
	return counts[STUFFED] + counts[TAKEN_DOWN]


## The session's quality: TrainingCamp.PLAYED_MIN with nothing stuffed up to PLAYED_MAX for every shot.
func quality() -> float:
	return lerpf(TrainingCamp.PLAYED_MIN, TrainingCamp.PLAYED_MAX, accuracy())


func _new_sim() -> void:
	var pair: Array[FighterState] = [FighterState.from_profile(him), _roster.make(PARTNER)]
	sim = FightSim.new(hash([seed_in, _resets, "sprawl sim"]), pair, _actions)
	sim.drill = true
	var mine := DrillAI.new()
	_partner = DrillAI.new()
	sim.decisions[0] = DecisionLayer.new(mine)
	sim.decisions[1] = DecisionLayer.new(_partner)
	sim.fighters[0].pos = Vector2(-START_SPOT, 0.0)
	sim.fighters[1].pos = Vector2(START_SPOT, 0.0)
	sim.event_emitted.connect(_on_event)
	_reset_at = -1
	_sprawl_open = false
	_rep_open = false
	_next_rep(roundi(SETTLE_SECONDS * FightClock.TICKS_PER_SECOND))


## Queues the partner's next rep `after` ticks from now: a shot, a feint, or a feint and the shot off it.
func _next_rep(after: int) -> void:
	var kind: String = "shot"
	if _rng.randf() < feint_share:
		kind = "feint_shot" if _rng.randf() < FEINT_SHOT_SHARE else "feint"
	reps.append(kind)
	_partner.moves.assign({ "shot": ["double_leg"], "feint": ["feint"], "feint_shot": ["feint", "double_leg"] }[kind])
	_partner.next_at = sim.now + after
	_rep_open = true
	for f in sim.fighters:
		f.stamina = f.max_stamina()  # A drill, not a fight: nobody gasses.


func _gap_ticks() -> int:
	return maxi(1, roundi((gap + _rng.randf_range(-GAP_JITTER, GAP_JITTER)) * FightClock.TICKS_PER_SECOND))


func _on_event(e: FightEvent) -> void:
	match e.type:
		FightEvent.ACTION_PHASE:
			if e.actor == 0 and String(e.data.get("action_id", "")) == "sprawl" and String(e.data.get("phase", "")) == "telegraph":
				_sprawl_open = true
			elif e.actor == 1 and String(e.data.get("action_id", "")) == "feint" and String(e.data.get("phase", "")) == "telegraph":
				_feint_at = e.tick
		FightEvent.SPRAWLED:
			if e.actor == 0:
				_sprawl_open = false
				counts[STUFFED] += 1
				judged.emit(STUFFED)
		FightEvent.GRAPPLE_WON:
			if e.actor == 1:
				counts[TAKEN_DOWN] += 1
				judged.emit(TAKEN_DOWN)
				_reset_at = e.tick + roundi(DOWN_SECONDS * FightClock.TICKS_PER_SECOND)
		FightEvent.ACTION_ENDED:
			if e.actor == 0 and String(e.data.get("action_id", "")) == "sprawl":
				_close_sprawl()
			elif e.actor == 1 and _partner.moves.is_empty() and _rep_open and _reset_at < 0:
				_rep_open = false
				_next_rep(_gap_ticks())


## His sprawl is over: if it met no shot, it was a stray (a bite, when a feint had just gone).
func _close_sprawl() -> void:
	if not _sprawl_open:
		return
	_sprawl_open = false
	var what: String = BIT if sim.now - _feint_at <= FEINT_BITE_TICKS else STRAY
	counts[what] += 1
	judged.emit(what)

