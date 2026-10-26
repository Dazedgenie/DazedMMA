class_name FightSim
extends RefCounted
## Headless fight simulation core (docs/01-fight-engine.md §2, issue #12).
##
## Each tick() is 100 ms of fight time: apply that tick's commands, then advance
## both fighters (action phases, fighter AI), emitting FightEvents. All
## randomness comes from one seeded RNG, so the same seed + command log always
## produces the same fight (see FightSim.replay).
##
## The standing game (#13, docs/01 §3, §5, §8): fighters move in a 2D octagon,
## distance bands decide which strikes reach, the fence pins whoever backs onto
## it, and clean head shots can rock, drop or finish. Rounds are scored 10-point
## must by three judges (Judging).
##
## Every contest uses Contest.chance on effective stats (docs/11 §3), and Speed
## and Kicking change how long telegraphs and wind-ups last (§3.3). Strike,
## takedown and sprawl events carry an OddsBreakdown saying where the odds came from.
##
## The sim owns time, movement and resolution; what each fighter tries comes from
## their DecisionLayer (commands → live calls → drilled rules → AI, docs/01 §6.0),
## which reads the fight through a FightView. The fight runs under a Ruleset.
##
## Positions (#34, docs/01 §4): one Situation both fighters share says where the
## fight is (phase, named position, each fighter's role). Moves between positions
## come from the position data (PositionLibrary), and the fighters' cage spot
## carries through, so a takedown on the fence lands on the fence.
##
## Clinch, takedowns and the trimmed ground game (#15, docs/01 §21): a takedown,
## clinch or ground move makes contact as its active phase starts (range, a
## required opening such as ONE_LEG, and its odds are fixed then) and is rolled as
## the active phase ends; in between the defender can sprawl on it or knee into it.
## A win moves the fight by the position data; a near miss can end in a scramble.
## Each position drains stamina, scores control for the judges and scales strikes.
signal event_emitted(event: FightEvent)

## Speed (and Kicking, for kick telegraphs) shortens or stretches telegraph and
## wind-up by up to 20% (docs/11 §3.3); being tired stretches them up to another
## 30% (docs/01 §8). Rounded to whole ticks.
const MAX_TIMING_SHIFT: float = 0.2
const TIMED_PHASES: Array[String] = ["telegraph", "windup"]

## Each fighter's corner at the bell: 3.5 m apart, out of range.
const START_POSITIONS: Array[Vector2] = [Vector2(-1.75, 0.0), Vector2(1.75, 0.0)]
## Walking speed in m/s: 0.8 + 1.2 × average of Footwork and Speed / 100 (50/50 → 1.4).
const MOVE_BASE: float = 0.8
const MOVE_PER_STAT: float = 1.2
## Moving costs stamina (D96): this much per second at full pace, × (share of full pace)²,
## so walking in is cheap and running all night isn't.
const MOVE_STAMINA_PER_S: float = 0.6
## Range and cage changes are announced once they've held this long (0.5 s), so
## shuffling across a line isn't news. Flags and odds always use the exact state.
const ANNOUNCE_AFTER_TICKS: int = 5
## A strike that `stops` a move (a knee into a shot) stops it in these phases, before it's done.
const STOPPABLE_PHASES: Array[String] = ["telegraph", "windup", "active"]
## Hitting someone mid-commitment (wind-up or recovery, docs/01 §5) is a counter.
const COUNTER_PHASES: Array[String] = ["windup", "recovery"]
const COUNTER_BONUS: float = 0.10
const COUNTER_DAMAGE: float = 1.3
## Below a quarter tank the hands drop (docs/01 §5: HANDS_LOW from fatigue).
const HANDS_LOW_BELOW: float = 0.25
## A clean shot stops the feet for a moment: 1 tick + 1 per 4 damage (a jab 2, a
## body kick 3, a head kick 4), so landing on someone who walks in stops the advance.
const STAGGER_BASE: int = 1
const STAGGER_PER_DAMAGE: float = 0.25

## Head shots: shock = damage × (1 + head hurt) / (6 + 0.12 × Chin).
## Rock chance = (shock − 0.6) × 0.5, up to 60%. Rocked again while rocked = knockdown.
const ROCK_THRESHOLD_BASE: float = 6.0
const ROCK_THRESHOLD_PER_CHIN: float = 0.12
const ROCK_FROM: float = 0.6
const ROCK_SLOPE: float = 0.5
const ROCK_MAX: float = 0.6
## Rocked lasts 4 s × (1.5 − Recovery / 100); a knockdown keeps them down 2 s, then rocked.
const ROCKED_TICKS: int = 40
const DOWN_TICKS: int = 20
## KO on a knockdown: 15% + (shock − 1) × 50%, 5–80%, × (1.5 − Heart / 100).
const KO_BASE: float = 0.15
const KO_SLOPE: float = 0.5
const KO_MIN: float = 0.05
const KO_MAX: float = 0.8
## The referee stops it: three knockdowns in a round, or rocked with nothing left (head fully hurt).
const TKO_KNOCKDOWNS: int = 3

## Tied up (clinch or ground), the fighters' centres are this close, on the spot
## where the one being taken down or tied up stood.
const TANGLED_GAP: float = 0.4
## Sprawled on, the shooter is stuck under the sprawl, head low, for this many ticks
## on top of the shot's recovery (D29: a stuffed shot gets punished).
const SPRAWL_STUCK_TICKS: int = 5
## Takedowns, clinch and ground moves: they make contact when their active phase starts
## and are rolled when it ends.
const GRAPPLES := { "takedown": true, "clinch": true, "ground": true }
## In open space a circling fighter keeps their direction unless one way is clearly
## more open (by this much, in metres toward the middle).
const CIRCLE_SIDE_DEADBAND: float = 0.3
## Cutting off the cage (D107): the cut fades in as the opponent goes from CUT_FROM to
## CUT_FULL metres out from the middle: it's the fence that traps them, so in open space
## there's no way out to shut.
const CUT_FROM: float = 3.0
const CUT_FULL: float = 4.0
## What counts as circling for the time reported after a fight (D119): a step where at
## least this much of it goes round the opponent (an outside fighter's everyday drift
## sideways, 0.25 × how far outside they lean, doesn't count).
const CIRCLING_FROM: float = 0.4
## Walking pace and the footwork contest are worked out again every this many ticks.
const FEET_EVERY: int = 5

const RESULT_KO := "ko"
const RESULT_TKO := "tko"
## How a TKO came about when it wasn't the referee: the corner threw in the towel (D31).
const STOPPED_BY_TOWEL := "towel"

var fight_seed: int
var clock: FightClock
var actions: ActionLibrary
## The coach calls a live_call command can name (data/calls, #16).
var calls: CallLibrary
var ruleset: Ruleset
var positions: PositionLibrary
## Where the fight is: phase, position and both roles (shared, docs/01 §4).
var situation := Situation.new()
var fighters: Array[FighterState]
## Each fighter's decision step, and the view of the fight it reads.
var decisions: Array[DecisionLayer] = []
var views: Array[FightView] = []
## Each fighter's corner when it makes its own calls (the AI corner, the harness's coaching
## bots); null for a corner that only passes on the player's calls (docs/01 §22.7).
var corners: Array[Corner] = [null, null]
## Ticks processed since the opening bell. The next tick() processes tick `now`.
var now: int = 0
var events: Array[FightEvent] = []
var command_log: Array[FightCommand] = []

## Per judge, per fighter: points so far, e.g. [[20, 18], [19, 19], [20, 18]].
var judge_totals: Array = []

var _rng := RandomNumberGenerator.new()
var _pending: Array[FightCommand] = []
var _fight_over: bool = false
var _round_points: Array[float] = [0.0, 0.0]  # effective striking this round, by who scored it
var _round_knockdowns: Array[int] = [0, 0]  # knockdowns scored this round
var _round_aggression: Array[float] = [0.0, 0.0]  # attacks thrown + metres walked forward this round
var _round_control: Array[int] = [0, 0]  # ticks this round the opponent spent pinned on the fence
## What the current position does to each fighter every tick (its data, worked out
## when the position changes): stamina drained, judges' control points, strike damage ×.
var _drain: Array[float] = [0.0, 0.0]
var _control: Array[float] = [0.0, 0.0]
var _damage_scale: Array[float] = [1.0, 1.0]
## Announced state for range (slot 0) and each fighter's cage proximity (slots 1
## and 2), see _announce: what was last announced, what it's turning into, and for
## how many ticks. Arrays rather than dictionaries: this runs every tick.
var _shown: Array[String] = ["", "", ""]
var _candidate: Array[String] = ["", "", ""]
var _held: Array[int] = [0, 0, 0]
## Each fighter's footwork the last time they moved: the distance they wanted, how
## much they circled (0–1) and which way (±1), and how hard they cut the cage off (0–1).
var _wants: Array[float] = [0.0, 0.0]
var _circling: Array[float] = [0.0, 0.0]
var _cutting: Array[float] = [0.0, 0.0]
var _circle_sign: Array[float] = [1.0, 1.0]
## Fight time (ticks) each fighter spent circling (a step at least CIRCLING_FROM round
## the opponent) and cutting off the cage (pressing or holding with the cut working: the
## opponent out past CUT_FROM), reported after the fight (D119). Read-only; never changes the fight.
var circling_ticks: Array[int] = [0, 0]
var cutting_ticks: Array[int] = [0, 0]
## How far each fighter moved on their last tick (zero when they stood still).
var _strides: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
## Walking pace (m per tick), footwork-contest share and footwork edge per fighter, as of _feet_at.
var _feet_at: int = -FEET_EVERY
var _step: Array[float] = [0.0, 0.0]
var _share: Array[float] = [0.5, 0.5]
var _feet_edge: Array[float] = [1.0, 1.0]


## `p_rules` is a Ruleset (null = pro rules), or a round count with
## `p_round_seconds` for a short pro-rules test fight.
func _init(p_seed: int, p_fighters: Array[FighterState], p_actions: ActionLibrary, p_rules: Variant = null, p_round_seconds: int = 300) -> void:
	assert(p_fighters.size() == 2, "a fight has two fighters")
	fight_seed = p_seed
	_rng.seed = p_seed
	fighters = p_fighters
	actions = p_actions
	positions = PositionLibrary.shared()
	calls = CallLibrary.shared()
	if p_rules is Ruleset:
		ruleset = p_rules
	elif p_rules is int:
		ruleset = Ruleset.pro_with(p_rules, p_round_seconds)
	else:
		ruleset = Ruleset.load_id()
	clock = FightClock.new(ruleset.rounds, ruleset.round_seconds)
	for i in fighters.size():
		decisions.append(DecisionLayer.new())
		views.append(FightView.new(self, i))
	for j in Judging.JUDGES:
		judge_totals.append([0, 0])
	_to_corners()


## Rebuilds a fight from its seed and command log. Pass freshly made fighters set
## up the same way as in the original fight (FighterState is mutated by a fight);
## from_record() does that from fighter ids.
static func replay(p_seed: int, p_fighters: Array[FighterState], p_actions: ActionLibrary, commands: Array, p_rules: Variant = null, p_round_seconds: int = 300) -> FightSim:
	var sim := FightSim.new(p_seed, p_fighters, p_actions, p_rules, p_round_seconds)
	for entry: Variant in commands:
		sim.submit(entry if entry is FightCommand else FightCommand.from_dict(entry))
	sim.run_to_end()
	return sim


## Everything needed to replay this fight (docs/04 §2.2, #32): seed, the
## data/fighters ids, the rules and the command log. Plain data, safe to save as JSON.
func record() -> Dictionary:
	var ids: Array[String] = []
	for f in fighters:
		assert(f.id != "", "only fighters made from data/fighters can be recorded")
		ids.append(f.id)
	return { "seed": fight_seed, "fighters": ids, "ruleset": ruleset.id, "rounds": ruleset.rounds,
		"round_seconds": ruleset.round_seconds, "commands": command_log_as_dicts() }


## Replays a record() with fresh fighters made from the same profiles.
static func from_record(rec: Dictionary, roster: FighterLibrary, p_actions: ActionLibrary) -> FightSim:
	var rules: Ruleset = Ruleset.load_id(rec.ruleset)
	rules.rounds = int(rec.rounds)
	rules.round_seconds = int(rec.round_seconds)
	return replay(int(rec.seed), roster.make_pair(rec.fighters[0], rec.fighters[1]), p_actions, rec.commands, rules)


## Queues a command for its tick. Commands for ticks already processed are refused.
func submit(command: FightCommand) -> bool:
	if command.tick < now or _fight_over:
		return false
	# Keep pending sorted by tick, stable for equal ticks, so order is reproducible.
	var at: int = _pending.size()
	while at > 0 and _pending[at - 1].tick > command.tick:
		at -= 1
	_pending.insert(at, command)
	return true


func is_over() -> bool:
	return _fight_over


func tick() -> void:
	if _fight_over:
		return
	for v in views:
		v.now = now
	for i in corners.size():
		if corners[i] != null:
			for id: String in corners[i].due(views[i], decisions[i].calls.voice(now)):
				submit(FightCommand.live_call(now, i, id))
	_apply_commands()
	if _fight_over:  # The towel came in.
		now += 1
		return
	for i in fighters.size():
		_advance_fighter(i)
		if _fight_over:
			now += 1
			return
	if not situation.is_standing():
		_round_points[0] += _control[0]
		_round_points[1] += _control[1]
	_update_space()
	if clock.tick():
		_end_round()
	now += 1


func distance() -> float:
	return fighters[0].pos.distance_to(fighters[1].pos)


## "out", "long", "mid" or "pocket" (Octagon) standing; "clinch" once tied up.
func band() -> String:
	if not situation.is_standing():
		return Octagon.BAND_CLINCH
	return Octagon.band(distance())


## "centre", "near" or "pinned" for fighter i.
func cage_proximity(i: int) -> String:
	return Octagon.proximity(fighters[i].pos, distance())


func run_to_end() -> void:
	while not _fight_over:
		tick()


func events_as_dicts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in events:
		out.append(e.to_dict())
	return out


func command_log_as_dicts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in command_log:
		out.append(c.to_dict())
	return out


func _apply_commands() -> void:
	while not _pending.is_empty() and _pending[0].tick == now:
		var command: FightCommand = _pending.pop_front()
		var reason: String = _reject_reason(command)
		if reason != "":
			_emit(FightEvent.COMMAND_REJECTED, command.fighter, { "command": command.type, "reason": reason })
		elif command.type == FightCommand.LIVE_CALL:
			var i: int = command.fighter
			_emit(FightEvent.CALL_HEARD, i, decisions[i].hear_call(views[i], call_for(command)))
			for n: Dictionary in decisions[i].take_notes():
				_emit(n.type, i, n.data)
		elif command.type == FightCommand.SET_RULE:
			var i: int = command.fighter
			decisions[i].set_rule(views[i], int(command.data.slot), String(command.data.rule_id), float(command.data.drilled))
			for n: Dictionary in decisions[i].take_notes():
				_emit(n.type, i, n.data)
		elif command.type == FightCommand.THROW_TOWEL:
			command_log.append(command)
			_finish(1 - command.fighter, RESULT_TKO, STOPPED_BY_TOWEL)
			return
		else:
			fighters[command.fighter].queued_action_id = command.data.action_id
		command_log.append(command)


func _reject_reason(command: FightCommand) -> String:
	if command.fighter < 0 or command.fighter >= fighters.size():
		return "unknown fighter"
	var id: String = command.data.get("action_id", "")
	match command.type:
		FightCommand.QUEUE_ACTION:
			return why_not(command.fighter, id)
		FightCommand.LIVE_CALL:
			var call: Dictionary = call_for(command)
			if call.is_empty():
				return "unknown call"
			if decisions[command.fighter].calls.voice(now) < float(call.voice_cost):
				return "no voice left"  # D28: every call costs voice; feasibility is checked once it's processed.
			return ""
		FightCommand.THROW_TOWEL:
			return ""
		FightCommand.SET_RULE:
			if clock.tick_in_round != 0:
				return "rules are set before a round"
			return decisions[command.fighter].rules.check(views[command.fighter], int(command.data.get("slot", 0)),
				String(command.data.get("rule_id", "")), float(command.data.get("drilled", -1.0)))
	return "unknown command"


## The call a live_call command names: a data/calls id, or a move from data/actions
## called straight (CallLibrary.bare: tests, the debug console). Empty when it's neither.
func call_for(command: FightCommand) -> Dictionary:
	var id: String = command.data.get("call_id", command.data.get("action_id", ""))
	if calls.has(id):
		return calls.get_call(id)
	if actions.has(id):
		return CallLibrary.bare(actions.get_action(id))
	return {}


## "" when fighter i could start this action now, else why not.
func why_not(i: int, id: String) -> String:
	if not actions.has(id):
		return "unknown action"
	var action: Dictionary = actions.get_action(id)
	if not ruleset.allows_action(action):
		return "not allowed under %s rules" % ruleset.name
	if not action.positions.has(situation.position):
		return "not possible from this position"
	if not ActionLibrary.allows_role(action, situation.role(i)):
		return "not possible from the %s" % situation.role(i)
	return ""


## One draw from the fight's seeded RNG, for decision sources (through FightView).
func roll() -> float:
	return _rng.randf()


## The RNG behind roll(), for the fighters' views to draw from directly (FightView.roll).
func rng_for_views() -> RandomNumberGenerator:
	return _rng


func _advance_fighter(i: int) -> void:
	var f: FighterState = fighters[i]
	f.regen_tick()
	f.spend_stamina(_drain[i])
	_strides[i] = Vector2.ZERO
	if f.is_down():
		f.down_ticks -= 1
		if f.down_ticks == 0:
			_emit(FightEvent.GOT_UP, i)
		return
	if f.is_rocked():
		f.rocked_ticks -= 1
		if f.rocked_ticks == 0:
			_emit(FightEvent.RECOVERED, i)
	if f.stagger_ticks > 0:
		f.stagger_ticks -= 1
	var calls_here: LiveCalls = decisions[i].calls
	if calls_here.active:
		decisions[i].update_calls(views[i])
		f.attention = calls_here.attention
	if not f.is_free():
		f.phase_ticks_left -= 1
		if f.phase_ticks_left <= 0:
			_next_phase(i)
	if f.is_free():
		var seen: FightView = views[i]
		if situation.is_standing():
			var feet: FeetPlan = decisions[i].plan_feet(seen)
			if f.stagger_ticks <= 0:
				_move(i, feet.want, feet.circle, feet.cut, feet.way)
		var decision: Decision = decisions[i].decide(seen)
		if not decision.is_idle():
			_start_action(i, decision.action_id, decision)
			decisions[i].started(seen, decision)
			f.attention = calls_here.attention
	for n: Dictionary in decisions[i].take_notes():
		_emit(n.type, i, n.data)


# --- Space: moving, range and the cage (docs/01 §3) --------------------------

## How far apart fighter i wants to be (their decision step decides; the feet follow).
func preferred_distance(i: int) -> float:
	return decisions[i].preferred_distance(views[i])


## The distance fighter i was walking toward, how much they circled (0–1) and how hard
## they cut the cage off (0–1), the last time they moved. Read-only, for the debug cage
## view (docs/01 §20.1); 0 before the first step.
func last_wanted_distance(i: int) -> float:
	return _wants[i]


func last_circling(i: int) -> float:
	return _circling[i]


func last_cutting(i: int) -> float:
	return _cutting[i]


func move_speed(f: FighterState) -> float:
	return MOVE_BASE + MOVE_PER_STAT * (f.effective_stat("footwork") + f.effective_stat("speed")) / 200.0


## Share of the footwork battle fighter i wins (Footwork vs Footwork): pressing,
## how well they cut the cage off; on the move, how well they stop it being cut off.
func footwork_share(i: int) -> float:
	return Contest.chance(Contest.STRIKE_BASE, fighters[i].effective_stat("footwork"), fighters[1 - i].effective_stat("footwork"))


## Metres fighter i walks in one tick.
func step_length(i: int) -> float:
	_refresh_feet()
	return _step[i]


## How much of a chase or a cut a fighter's feet get done against the opponent's
## (D107), from their Footwork contest share: doubled and squared, at most 1. Even
## feet get all of it; 50 against 70 (a 30% share) gets 0.36, and 70 against 50 all of it.
static func footwork_edge(share: float) -> float:
	return minf(1.0, pow(2.0 * share, 2.0))


## Walking pace and the footwork contest change only with fatigue and damage, so
## they're worked out every FEET_EVERY ticks rather than every tick.
func _refresh_feet() -> void:
	if now < _feet_at + FEET_EVERY and now >= _feet_at:
		return
	_feet_at = now
	# As move_speed() and footwork_share(), with each fighter's Footwork worked out once.
	var footwork: Array[float] = [fighters[0].effective_stat("footwork"), fighters[1].effective_stat("footwork")]
	for i in fighters.size():
		_step[i] = (MOVE_BASE + MOVE_PER_STAT * (footwork[i] + fighters[i].effective_stat("speed")) / 200.0) / FightClock.TICKS_PER_SECOND
		_share[i] = Contest.chance(Contest.STRIKE_BASE, footwork[i], footwork[1 - i])
		_feet_edge[i] = footwork_edge(_share[i])


## The feet: step toward the preferred distance and circle as much as the fighter
## wants (0–1) and which `way` (0 = toward the middle, see way_toward_middle), never
## faster than their walking pace. The fence stops the part of a step that goes into
## it; the rest slides along it. Pressing someone who is on the move, they aim where
## that fighter is going: how far ahead is the presser's share of a Footwork contest.
## Chasing someone who's getting away, they keep up only as well as their footwork
## edge lets them, and cutting the cage off (`cut`, 0–1) they step sideways toward the
## spot between the opponent and the middle, as much as the edge lets them (D107):
## good feet get out, bad feet get trapped.
func _move(i: int, want: float, circle: float, cut: float = 0.0, way: int = 0) -> void:
	var f: FighterState = fighters[i]
	var o: FighterState = fighters[1 - i]
	var from: Vector2 = f.pos
	var gap: Vector2 = o.pos - f.pos
	var apart: float = gap.length()
	var toward: Vector2 = gap.normalized() if apart > 0.0 else Vector2.RIGHT
	var step: float = step_length(i)
	var radial: float = clampf(apart - want, -step, step)
	if radial > 0.0 and _strides[1 - i].dot(toward) > 0.0:
		radial *= _feet_edge[i]  # Chasing someone who's getting away.
	_wants[i] = want
	_circling[i] = circle
	_cutting[i] = cut
	var stride: Vector2 = toward * radial
	if radial > 0.0 and _strides[1 - i] != Vector2.ZERO:
		var ahead: Vector2 = o.pos + _strides[1 - i] * (apart / step) * (1.0 - _share[1 - i])
		if ahead != f.pos:
			stride = (ahead - f.pos).normalized() * radial
	if circle > 0.0:
		stride += _circle_side(i, toward, way) * step * circle
		if circle >= CIRCLING_FROM:
			circling_ticks[i] += 1
	if cut > 0.0 and o.pos.length_squared() > CUT_FROM * CUT_FROM:
		stride += _cut_step(i, toward, apart, step) * cut * _share[i]
		cutting_ticks[i] += 1
	if stride.length() > step:
		stride = stride.normalized() * step
	# The fence stops the part of the step that goes into it; the rest slides along it.
	f.pos = Octagon.keep_inside(f.pos + stride)
	var effort: float = (f.pos - from).length() / step if step > 0.0 else 0.0
	f.spend_stamina(MOVE_STAMINA_PER_S * effort * effort / FightClock.TICKS_PER_SECOND)
	var after: Vector2 = f.pos - o.pos
	if after.length() < Octagon.MIN_GAP:
		f.pos = Octagon.keep_inside(o.pos + (after.normalized() if after.length() > 0.0 else -toward) * Octagon.MIN_GAP)
	_strides[i] = f.pos - from
	_round_aggression[i] += maxf(0.0, apart - (o.pos - f.pos).length()) * Judging.AGGRESSION_PER_METRE


## Shoves fighter k straight back from the opponent (a landed teep), up to the fence.
func _push(k: int, metres: float) -> void:
	var away: Vector2 = fighters[k].pos - fighters[1 - k].pos
	if away.length() > 0.0:
		fighters[k].pos = Octagon.keep_inside(fighters[k].pos + away.normalized() * metres)


## The sideways step that puts fighter k between the opponent and the middle of the cage,
## as far from them as now: at most a step, and nothing while the opponent is in the middle.
func _cut_step(k: int, toward_opponent: Vector2, apart: float, step: float) -> Vector2:
	var o: Vector2 = fighters[1 - k].pos
	var out: float = o.length()
	if out <= CUT_FROM:
		return Vector2.ZERO
	var spot: Vector2 = o - o / out * apart
	var side := Vector2(-toward_opponent.y, toward_opponent.x)
	return side * clampf((spot - fighters[k].pos).dot(side), -step, step) * clampf((out - CUT_FROM) / (CUT_FULL - CUT_FROM), 0.0, 1.0)


## Which way fighter k circles: sideways (relative to the opponent), `way` if the
## fighter picked one, else toward the middle of the cage. In open space, where
## neither way is clearly better, they keep going the way they were, so they don't jitter.
func _circle_side(k: int, toward_opponent: Vector2, way: int = 0) -> Vector2:
	var side := Vector2(-toward_opponent.y, toward_opponent.x)
	if way != 0:
		_circle_sign[k] = float(way)
	else:
		var lean: float = side.dot(-fighters[k].pos)  # As in way_toward_middle.
		if absf(lean) > CIRCLE_SIDE_DEADBAND:
			_circle_sign[k] = 1.0 if lean > 0.0 else -1.0
	return side * _circle_sign[k]


## For someone at `me` facing along `toward_opponent`: +1 if sideways one way round
## the opponent (the left-hand perpendicular) heads toward the middle of the cage, −1 if
## the other way does, 0 if neither clearly does (by CIRCLE_SIDE_DEADBAND metres).
static func way_toward_middle(me: Vector2, toward_opponent: Vector2) -> int:
	var lean: float = Vector2(-toward_opponent.y, toward_opponent.x).dot(-me)
	if absf(lean) <= CIRCLE_SIDE_DEADBAND:
		return 0
	return 1 if lean > 0.0 else -1


func _update_space() -> void:
	var apart: float = distance()
	_announce(0, Octagon.band(apart) if situation.is_standing() else Octagon.BAND_CLINCH, FightEvent.RANGE_CHANGED, FightEvent.NO_ACTOR, "band")
	for i in fighters.size():
		var proximity: String = Octagon.proximity(fighters[i].pos, apart)
		_announce(1 + i, proximity, FightEvent.CAGE_CHANGED, i, "proximity")
		if proximity == Octagon.CAGE_PINNED:
			_round_control[1 - i] += 1


func _announce(slot: int, value: String, type: String, actor: int, field: String) -> void:
	if value == _shown[slot]:
		_held[slot] = 0
		return
	if value != _candidate[slot]:
		_candidate[slot] = value
		_held[slot] = 0
	_held[slot] += 1
	if _held[slot] >= ANNOUNCE_AFTER_TICKS:
		_shown[slot] = value
		_held[slot] = 0
		_emit(type, actor, { field: value })


func _to_corners() -> void:
	situation.reset()
	_position_effects()
	_wants = [0.0, 0.0]
	_circling = [0.0, 0.0]
	_cutting = [0.0, 0.0]
	_strides = [Vector2.ZERO, Vector2.ZERO]
	for i in fighters.size():
		fighters[i].pos = START_POSITIONS[i]
	_shown = [band(), cage_proximity(0), cage_proximity(1)]
	_candidate = _shown.duplicate()
	_held = [0, 0, 0]


# --- Positions: standing, clinch and ground (docs/01 §4, #34) -----------------

## Fighter i's role in the current position ("neutral", "top", "bottom").
func role(i: int) -> String:
	return situation.role(i)


## The transition fighter i would make by landing this action from here (or half
## landing it, `result` "partial"), or {}.
func transition_for(i: int, action_id: String, result: String = PositionLibrary.SUCCESS) -> Dictionary:
	return positions.transition(situation.position, situation.role(i), action_id, result)


## Moves the fight to where fighter i's action takes it (from the position data).
## Returns false, changing nothing, when the action doesn't move the fight from
## here. The fight stays on the spot where the opponent stood, so the cage carries
## over: tied up on the fence stays on the fence, and getting up separates there.
## Whatever either fighter was in the middle of stops. Ending up on top scores a
## takedown with the judges (Judging.TAKEDOWN_POINTS). Grapple resolution calls this
## when a takedown, clinch move or get-up works.
func apply_transition(i: int, action_id: String, result: String = PositionLibrary.SUCCESS) -> bool:
	var t: Dictionary = transition_for(i, action_id, result)
	if t.is_empty():
		return false
	var was_top: bool = situation.role(i) == PositionLibrary.TOP
	var roles: Array[String] = ["", ""]
	roles[i] = t.roles.actor
	roles[1 - i] = t.roles.opponent
	situation.set_to(positions.get_position(t.to), roles)
	_position_effects()
	for f in fighters:
		f.clear_action()
	_place_bodies(i)
	_emit(FightEvent.POSITION_CHANGED, i, { "action_id": action_id, "position": situation.position, "phase": situation.phase, "roles": roles.duplicate() })
	if roles[i] == PositionLibrary.TOP and not was_top:
		_round_points[i] += Judging.TAKEDOWN_POINTS
		if actions.has(action_id) and actions.get_action(action_id).category == "takedown":
			fighters[i].takedowns_landed += 1
	return true


## Back to standing without anyone's move (a knockdown in the clinch): the fighters
## come apart where they are, a standing gap apart.
func _break_apart(i: int) -> void:
	situation.reset()
	_position_effects()
	_place_bodies(i)
	_emit(FightEvent.POSITION_CHANGED, i, { "action_id": "", "position": situation.position, "phase": situation.phase, "roles": situation.roles.duplicate() })


## Reads what the current position does to each fighter per tick from its data.
func _position_effects() -> void:
	var def: Dictionary = positions.get_position(situation.position)
	for i in fighters.size():
		var r: String = situation.role(i)
		_drain[i] = float(def.stamina_drain_per_s.get(r, 0.0)) / FightClock.TICKS_PER_SECOND
		_control[i] = float(def.control_score.get(r, 0.0)) * Judging.CONTROL_POINTS_PER_S / FightClock.TICKS_PER_SECOND
		_damage_scale[i] = float(def.strike_damage_multiplier.get(r, 1.0))


## Puts fighter i next to the opponent: tangled when tied up, a standing gap apart otherwise.
## The opponent keeps their spot unless the fence is in the way.
func _place_bodies(i: int) -> void:
	var f: FighterState = fighters[i]
	var o: FighterState = fighters[1 - i]
	var from_o: Vector2 = f.pos - o.pos
	var side: Vector2 = from_o.normalized() if from_o.length() > 0.0 else Vector2.LEFT
	var gap: float = Octagon.MIN_GAP if situation.is_standing() else TANGLED_GAP
	f.pos = Octagon.keep_inside(o.pos + side * gap)
	o.pos = Octagon.keep_inside(f.pos - side * gap)  # Only moves them when the fence was in fighter i's way.


# --- Choosing and running actions ---------------------------------------------


## Starts an action. The telegraph event says which layer chose it and why
## (`by`, `why`), so the log can explain every move (docs/01 §16 A16).
func _start_action(i: int, id: String, decision: Decision = null) -> void:
	var f: FighterState = fighters[i]
	f.action_id = id
	var action: Dictionary = actions.get_action(id)
	f.spend_stamina(float(action.stamina_cost))
	if action.category == "strike":
		f.strikes_thrown += 1
	elif action.category == "takedown":
		f.takedowns_tried += 1
	if action.category == "strike" or action.category == "takedown" or (action.category == "clinch" and situation.is_standing()):
		_round_aggression[i] += 1.0
	var why: Dictionary = {}
	if decision != null:
		why = { "by": decision.layer, "why": decision.reason }
	_enter_phase(i, 0, why)


func _next_phase(i: int) -> void:
	if fighters[i].grip != null and fighters[i].phase == "active" and _finish_grip(i):
		return  # It worked: the fight moved and both fighters' moves are over.
	var at: int = ActionLibrary.PHASES.find(fighters[i].phase) + 1
	if at >= ActionLibrary.PHASES.size():
		var id: String = fighters[i].action_id
		fighters[i].clear_action()
		_emit(FightEvent.ACTION_ENDED, i, { "action_id": id })
	else:
		_enter_phase(i, at)


## Enters phase `at`, skipping zero-length phases (each still emits its event).
## `why` (who chose the action and why) goes on the telegraph event.
func _enter_phase(i: int, at: int, why: Dictionary = {}) -> void:
	var f: FighterState = fighters[i]
	f.phase = ActionLibrary.PHASES[at]
	f.phase_ticks_left = phase_ticks(f, f.action_id, f.phase)
	var data := { "action_id": f.action_id, "phase": f.phase }
	data.merge(why)
	_emit(FightEvent.ACTION_PHASE, i, data)
	if f.phase == "active":
		_resolve_active(i)
		if f.action_id == "":
			return  # A knockdown on the ground or in the clinch broke them apart and ended the move.
	if f.phase_ticks_left <= 0:
		_next_phase(i)


## How long this fighter takes over one phase of an action, in whole ticks.
## A fresh 50-Speed fighter matches the data exactly; zero-length phases stay zero.
func phase_ticks(f: FighterState, id: String, phase: String) -> int:
	var ticks: int = actions.phase_ticks(id, phase)
	if ticks == 0 or phase not in TIMED_PHASES:
		return ticks
	var quickness: float = f.effective_stat("speed")
	if phase == "telegraph" and actions.get_action(id).stats.offense.has("kicking"):
		quickness = (quickness + f.effective_stat("kicking")) / 2.0
	var factor: float = 1.0 - MAX_TIMING_SHIFT * clampf((quickness - FighterState.DEFAULT_STAT) / 50.0, -1.0, 1.0)
	factor *= 1.0 + f.tired()
	return maxi(1, roundi(ticks * factor))


## Flags fighter i carries right now: from their current action's phase (docs/09
## flags_self), BACK_TO_CAGE when pinned, HANDS_LOW when exhausted or rocked,
## HEAD_LOW while stuck under a sprawl.
func active_flags(i: int) -> Array[String]:
	var f: FighterState = fighters[i]
	var out: Array[String] = []
	if cage_proximity(i) == Octagon.CAGE_PINNED:
		out.append("BACK_TO_CAGE")
	if f.stamina_fraction() < HANDS_LOW_BELOW or f.is_rocked():
		out.append("HANDS_LOW")
	if f.is_free():
		return out
	if f.sprawled:
		out.append("HEAD_LOW")
	var at: int = ActionLibrary.PHASES.find(f.phase)
	for entry: Dictionary in actions.get_action(f.action_id).flags_self:
		if ActionLibrary.PHASES.find(entry.from) <= at and at <= ActionLibrary.PHASES.find(entry.to):
			out.append(entry.flag)
	return out


## Fighter i's flags `ahead` ticks from now if they carry on with their action:
## the flags of the phase they'll be in, plus the ones that come from where they
## stand and how they are (pinned, exhausted, rocked), as they are now.
func flags_ahead(i: int, ahead: int) -> Array[String]:
	if ahead <= 0:
		return active_flags(i)
	var f: FighterState = fighters[i]
	var out: Array[String] = []
	if cage_proximity(i) == Octagon.CAGE_PINNED:
		out.append("BACK_TO_CAGE")
	if f.stamina_fraction() < HANDS_LOW_BELOW or f.is_rocked():
		out.append("HANDS_LOW")
	var phase: String = phase_ahead(i, ahead)
	if phase == "":
		return out
	if f.sprawled:
		out.append("HEAD_LOW")
	var at: int = ActionLibrary.PHASES.find(phase)
	for entry: Dictionary in actions.get_action(f.action_id).flags_self:
		if ActionLibrary.PHASES.find(entry.from) <= at and at <= ActionLibrary.PHASES.find(entry.to):
			out.append(entry.flag)
	return out


## Fighter i's phase `ahead` ticks from now if they carry on with their action
## ("" when they're free or will be done by then). Committed moves can't be
## cancelled, so this is what an opponent who read the move can count on.
func phase_ahead(i: int, ahead: int) -> String:
	var f: FighterState = fighters[i]
	if f.is_free():
		return ""
	var at: int = ActionLibrary.PHASES.find(f.phase)
	var left: int = f.phase_ticks_left - ahead
	while left <= 0:
		at += 1
		if at >= ActionLibrary.PHASES.size():
			return ""
		left += phase_ticks(f, f.action_id, ActionLibrary.PHASES[at])
	return ActionLibrary.PHASES[at]


## Fighter i's odds for this action against the opponent right now: the shared
## contest formula on effective stats, plus opportunity bonuses for flags the
## opponent carries and for catching them mid-commitment (a counter).
## 0 when a required opportunity is missing (catch-kick needs a kick).
func odds(i: int, id: String) -> float:
	return odds_breakdown(i, id).chance


## Fighter i's odds for this action on stats alone: no flags, no counter (the AI's
## range plan, #14). Cheaper than odds_breakdown.
func plain_odds(i: int, id: String) -> float:
	var action: Dictionary = actions.get_action(id)
	return Contest.chance(Contest.base_for(action), _average_stat(fighters[i], action.stats.offense), _average_stat(fighters[1 - i], action.stats.defense))


## The same odds with every part named (OddsBreakdown), as strike events carry them.
## With `ahead` > 0: the odds if the action lands that many ticks from now, with the
## opponent carrying on with their action (the AI uses it to time counters, #14).
## Opportunities can also come from fighter i's own flags (`own_flag`: getting up
## with your back on the fence is easier, wall-walking), as they are now.
func odds_breakdown(i: int, id: String, ahead: int = 0) -> OddsBreakdown:
	var action: Dictionary = actions.get_action(id)
	var b := OddsBreakdown.new(id)
	b.base = Contest.base_for(action)
	b.attack = _average_stat(fighters[i], action.stats.offense)
	b.defense = _average_stat(fighters[1 - i], action.stats.defense)
	var countering: bool = is_counter(i) if ahead <= 0 else phase_ahead(1 - i, ahead) in COUNTER_PHASES
	if countering:
		b.add_bonus("counter", COUNTER_BONUS)
	var opponent_flags: Array[String] = active_flags(1 - i) if ahead <= 0 else flags_ahead(1 - i, ahead)
	var own_flags: Array[String] = []
	for opp: Dictionary in action.opportunities:
		if opp.has("own_flag"):
			if own_flags.is_empty():
				own_flags = active_flags(i)
			if own_flags.has(opp.own_flag):
				b.add_bonus("own " + String(opp.own_flag), float(opp.success_bonus))
		elif opponent_flags.has(opp.opponent_flag):
			b.add_bonus(opp.opponent_flag, float(opp.success_bonus))
		elif opp.get("required", false) and b.missing == "":
			b.missing = opp.opponent_flag
	return b.settle()


## True when fighter i's opponent is committed (wind-up or recovery) right now.
func is_counter(i: int) -> bool:
	return fighters[1 - i].phase in COUNTER_PHASES


func _resolve_active(i: int) -> void:
	var action: Dictionary = actions.get_action(fighters[i].action_id)
	match action.category:
		"strike":
			_land_strike(i, action)
		"defense":
			_meet_shot(i)
		"takedown", "clinch", "ground":
			_make_contact(i, action)


func _land_strike(i: int, action: Dictionary) -> void:
	var attacker: FighterState = fighters[i]
	var defender: FighterState = fighters[1 - i]
	var target: String = action.strike.target
	var miss := { "action_id": action.id, "target": target, "chance": 0.0 }
	if defender.is_down():
		miss.reason = "opponent down"
		_emit(FightEvent.STRIKE_MISSED, i, miss)
		return
	if not action.ranges.has(band()):
		miss.reason = "out of range"
		_emit(FightEvent.STRIKE_MISSED, i, miss)
		return
	var counter: bool = is_counter(i)
	var breakdown: OddsBreakdown = odds_breakdown(i, action.id)
	var chance: float = breakdown.chance
	if _rng.randf() >= chance:
		miss.chance = chance
		miss.odds = breakdown.to_dict()
		_emit(FightEvent.STRIKE_MISSED, i, miss)
		return
	# An opening can change what the strike does (D29: a knee into a shot goes to the
	# lowered head, harder, and stops the shot): `target`, `damage_multiplier`, `stops`.
	var scale: float = (COUNTER_DAMAGE if counter else 1.0) * _damage_scale[i]
	var stops: bool = false
	if not breakdown.bonuses.is_empty():
		for opp: Dictionary in action.opportunities:
			if not opp.has("opponent_flag") or not _has_bonus(breakdown, opp.opponent_flag):
				continue
			if opp.has("target") and ruleset.allows_target(action, opp.target):
				target = opp.target
			scale *= float(opp.get("damage_multiplier", 1.0))
			stops = stops or bool(opp.get("stops", false))
	var into: String = defender.action_id if stops and defender.phase in STOPPABLE_PHASES else ""
	var dealt: int = maxi(1, roundi(strike_damage(attacker, action.id) * scale))
	defender.damage[target] += dealt
	defender.stagger_ticks = maxi(defender.stagger_ticks, STAGGER_BASE + roundi(dealt * STAGGER_PER_DAMAGE))
	var push: float = float(action.strike.get("push_m", 0.0))
	if push > 0.0:
		_push(1 - i, push)
	attacker.strikes_landed += 1
	_round_points[i] += dealt * Judging.TARGET_WEIGHTS[target]
	var landed := { "action_id": action.id, "target": target, "damage": dealt, "chance": chance, "counter": counter, "odds": breakdown.to_dict() }
	if into != "":
		landed.into = into
	_emit(FightEvent.STRIKE_LANDED, i, landed)
	if into != "":
		_emit(FightEvent.GRAPPLE_STOPPED, 1 - i, { "action_id": into, "reason": "stopped", "by_action": action.id })
		_to_recovery(1 - i)
	if target == "head":
		_head_impact(i, dealt, into != "")


static func _has_bonus(b: OddsBreakdown, bonus_name: String) -> bool:
	for x: Dictionary in b.bonuses:
		if x.name == bonus_name:
			return true
	return false


## Cuts fighter i's move short: straight into its recovery, nothing more to roll.
func _to_recovery(i: int) -> void:
	fighters[i].grip = null
	_enter_phase(i, ActionLibrary.PHASES.find("recovery"))


# --- Takedowns, clinch and ground moves (docs/01 §21, #15) ---------------------

## A takedown, clinch or ground move reaches its active phase: contact. It needs the
## range, and a required opening (the catch-kick needs the kick) has to be there now.
## Its odds are fixed here (the opening may be gone by the time it's rolled) and
## rolled as the active phase ends (_finish_grip); until then the defender can
## sprawl on it or knee into it.
func _make_contact(i: int, action: Dictionary) -> void:
	var stopped := { "action_id": action.id }
	if fighters[1 - i].is_down():
		stopped.reason = "opponent down"
	elif not action.ranges.has(band()):
		stopped.reason = "out of range"
	else:
		var b: OddsBreakdown = odds_breakdown(i, action.id)
		if b.missing == "":
			fighters[i].grip = b
			_meet_shot(1 - i)  # Already sprawling as it arrives?
			return
		stopped.reason = "nothing to catch"
		stopped.chance = 0.0
		stopped.odds = b.to_dict()
	_emit(FightEvent.GRAPPLE_STOPPED, i, stopped)
	_to_recovery(i)


## Fighter k's sprawl (a defense against the opponent's category of move) meets the
## opponent's shot, if the sprawl is in its active phase while the shot has contact.
## One roll: it works, and the shooter is stuck under it, head low, for longer; or
## it doesn't, and the shot goes on to its own roll. Either way the sprawl is spent.
func _meet_shot(k: int) -> void:
	var d: FighterState = fighters[k]
	var s: FighterState = fighters[1 - k]
	if d.phase != "active" or s.grip == null:
		return
	var sprawl: Dictionary = actions.get_action(d.action_id)
	if sprawl.category != "defense" or not sprawl.defense.against_categories.has(actions.get_action(s.action_id).category):
		return
	var b: OddsBreakdown = odds_breakdown(k, sprawl.id)
	var worked: bool = _rng.randf() < b.chance
	_emit(FightEvent.SPRAWLED, k, { "action_id": sprawl.id, "against": s.action_id, "worked": worked, "chance": b.chance, "odds": b.to_dict() })
	_to_recovery(k)
	if not worked:
		return
	_emit(FightEvent.GRAPPLE_STOPPED, 1 - k, { "action_id": s.action_id, "reason": "sprawled on", "chance": s.grip.chance, "odds": s.grip.to_dict() })
	_to_recovery(1 - k)
	s.phase_ticks_left += SPRAWL_STUCK_TICKS
	s.sprawled = true


## The roll at the end of a grapple's active phase, on the odds fixed at contact.
## Under the odds it works; within the move's `partial_within` above them it half
## works, if the position data says where that goes (a scramble). Returns true when
## the fight moved.
func _finish_grip(i: int) -> bool:
	var f: FighterState = fighters[i]
	var b: OddsBreakdown = f.grip
	f.grip = null
	var action: Dictionary = actions.get_action(f.action_id)
	var roll: float = _rng.randf()
	var result: String = ""
	if roll < b.chance:
		result = PositionLibrary.SUCCESS
	elif roll < b.chance + float(action[action.category].get("partial_within", 0.0)) \
			and not transition_for(i, action.id, PositionLibrary.PARTIAL).is_empty():
		result = PositionLibrary.PARTIAL
	if result == "" or transition_for(i, action.id, result).is_empty():
		_emit(FightEvent.GRAPPLE_STOPPED, i, { "action_id": action.id, "reason": "defended", "chance": b.chance, "odds": b.to_dict() })
		return false
	_emit(FightEvent.GRAPPLE_WON, i, { "action_id": action.id, "result": result, "chance": b.chance, "odds": b.to_dict() })
	return apply_transition(i, action.id, result)


## Damage multiplier from Power: 0.5 + Power / 100 (Power 50 → ×1).
func strike_power(f: FighterState) -> float:
	return 0.5 + f.effective_stat("power") / 100.0


## What this strike does when it lands clean (before the counter bonus and rounding).
func strike_damage(f: FighterState, id: String) -> float:
	return float(actions.get_action(id).strike.base_damage) * strike_power(f) * ruleset.damage_multiplier


## How hard a head shot landed relative to what fighter i's opponent can take.
func head_shock(i: int, dealt: float) -> float:
	var d: FighterState = fighters[1 - i]
	return dealt * (1.0 + d.hurt("head")) / (ROCK_THRESHOLD_BASE + ROCK_THRESHOLD_PER_CHIN * d.stat("chin"))


func rock_chance(shock: float) -> float:
	return clampf((shock - ROCK_FROM) * ROCK_SLOPE, 0.0, ROCK_MAX)


func ko_chance(shock: float, f: FighterState) -> float:
	var heart: float = 1.5 - f.effective_stat("heart") / 100.0
	return clampf(KO_BASE + (shock - 1.0) * KO_SLOPE, KO_MIN, KO_MAX) * heart


## A head shot's rock roll. `flash`: it caught them coming in (a knee into a shot,
## D29), so a rock drops them straight away.
func _head_impact(i: int, dealt: int, flash: bool = false) -> void:
	var shock: float = head_shock(i, dealt)
	var chance: float = rock_chance(shock)
	if chance <= 0.0 or _rng.randf() >= chance:
		return
	var d: FighterState = fighters[1 - i]
	if d.is_rocked() or flash:
		_knockdown(i, shock)
		return
	d.rocked_ticks = rocked_duration(d)
	d.clear_action()
	_round_points[i] += Judging.ROCKED_POINTS
	_emit(FightEvent.ROCKED, 1 - i, { "by": i })
	if d.hurt("head") >= 1.0:
		_finish(i, RESULT_TKO)


func rocked_duration(f: FighterState) -> int:
	return roundi(ROCKED_TICKS * (1.5 - f.effective_stat("recovery") / 100.0))


func _knockdown(i: int, shock: float) -> void:
	var d: FighterState = fighters[1 - i]
	d.knockdowns += 1
	d.knockdowns_this_round += 1
	d.clear_action()
	d.down_ticks = DOWN_TICKS
	d.rocked_ticks = rocked_duration(d)
	_round_points[i] += Judging.KNOCKDOWN_POINTS
	_round_knockdowns[i] += 1
	_emit(FightEvent.KNOCKDOWN, 1 - i, { "by": i })
	if not situation.is_standing():
		fighters[i].clear_action()
		_break_apart(i)
	if _rng.randf() < ko_chance(shock, d):
		_finish(i, RESULT_KO)
	elif d.knockdowns_this_round >= TKO_KNOCKDOWNS:
		_finish(i, RESULT_TKO)


# --- Rounds, judges and the result --------------------------------------------

func _end_round() -> void:
	var cards: Array = []
	for j in Judging.JUDGES:
		var seen: Array[float] = []
		var aggression: Array[float] = []
		for i in 2:
			seen.append(_round_points[i] * (1.0 + _rng.randf_range(-Judging.JUDGE_NOISE, Judging.JUDGE_NOISE)))
			aggression.append(_round_aggression[i] * (1.0 + _rng.randf_range(-Judging.JUDGE_NOISE, Judging.JUDGE_NOISE)))
		var card: Array[int] = Judging.round_card(seen, _round_knockdowns, [aggression, _round_control])
		judge_totals[j][0] += card[0]
		judge_totals[j][1] += card[1]
		cards.append(card)
	_emit(FightEvent.ROUND_ENDED, FightEvent.NO_ACTOR, { "cards": cards })
	if clock.is_fight_over():
		var verdict: Dictionary = Judging.decision(judge_totals)
		_fight_over = true
		_emit(FightEvent.FIGHT_ENDED, FightEvent.NO_ACTOR, { "result": verdict.result, "winner": verdict.winner, "cards": judge_totals.duplicate(true) })
		return
	for f in fighters:
		f.clear_action()
		f.recover_between_rounds()
		f.rocked_ticks = 0
		f.down_ticks = 0
		f.stagger_ticks = 0
		f.knockdowns_this_round = 0
	_round_points = [0.0, 0.0]
	_round_knockdowns = [0, 0]
	_round_aggression = [0.0, 0.0]
	_round_control = [0, 0]
	clock.start_next_round()
	_to_corners()


func _finish(winner: int, result: String, stopped_by: String = "") -> void:
	_fight_over = true
	var data := { "result": result, "winner": winner }
	if stopped_by != "":
		data.stopped_by = stopped_by
	_emit(FightEvent.FIGHT_ENDED, FightEvent.NO_ACTOR, data)


## Each fighter's effective striking and grappling points so far this round, as the
## judges add them up before their own noise (Judging): for the HUD's rough estimate.
func round_points() -> Array[float]:
	return _round_points.duplicate()


func _average_stat(f: FighterState, ids: Array) -> float:
	if ids.is_empty():
		return FighterState.DEFAULT_STAT
	var total: float = 0.0
	for id: String in ids:
		total += f.effective_stat(id)
	return total / ids.size()


## Records an event, lets both fighters' decision steps hear it (tells, reads,
## and later read calls and drilled rules), then tells listeners.
func _emit(type: String, actor: int = FightEvent.NO_ACTOR, data: Dictionary = {}) -> void:
	if _fight_over and type != FightEvent.FIGHT_ENDED:
		return  # Nothing happens after the end, even later in the same tick (a call answered as the KO lands).
	var event := FightEvent.new(now, clock.current_round, type, actor, data)
	events.append(event)
	for k in decisions.size():
		decisions[k].on_event(views[k], event)
		if corners[k] != null:
			corners[k].on_event(views[k], event)
	event_emitted.emit(event)
