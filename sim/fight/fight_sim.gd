class_name FightSim
extends RefCounted
## Headless fight simulation core (docs/01-fight-engine.md §2, issue #12).
##
## Each tick() is 100 ms of fight time: apply that tick's commands, then advance
## both fighters (action phases, placeholder AI), emitting FightEvents. All
## randomness comes from one seeded RNG, so the same seed + command log always
## produces the same fight (see FightSim.replay).
##
## The standing game (#13, docs/01 §3, §5, §8): fighters move in a 2D octagon,
## distance bands decide which strikes reach, the fence pins whoever backs onto
## it, and clean head shots can rock, drop or finish. Rounds are scored 10-point
## must by three judges (Judging).
##
## Every contest uses Contest.chance on effective stats (docs/11 §3), and Speed
## and Kicking change how long telegraphs and wind-ups last (§3.3). Strike events
## carry an OddsBreakdown saying where the odds came from. Takedowns get their
## odds from odds() but land with #15.
##
## The sim owns time, movement and resolution; what each fighter tries comes from
## their DecisionLayer (commands → live calls → drilled rules → AI, docs/01 §6.0),
## which reads the fight through a FightView. The fight runs under a Ruleset.

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
## Range and cage changes are announced once they've held this long (0.5 s), so
## shuffling across a line isn't news. Flags and odds always use the exact state.
const ANNOUNCE_AFTER_TICKS: int = 5
## Hitting someone mid-commitment (wind-up or recovery, docs/01 §5) is a counter.
const COUNTER_PHASES: Array[String] = ["windup", "recovery"]
const COUNTER_BONUS: float = 0.10
const COUNTER_DAMAGE: float = 1.3
## Below a quarter tank the hands drop (docs/01 §5: HANDS_LOW from fatigue).
const HANDS_LOW_BELOW: float = 0.25

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

const RESULT_KO := "ko"
const RESULT_TKO := "tko"

var fight_seed: int
var clock: FightClock
var actions: ActionLibrary
var ruleset: Ruleset
var fighters: Array[FighterState]
## Each fighter's decision step, and the view of the fight it reads.
var decisions: Array[DecisionLayer] = []
var views: Array[FightView] = []
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
## Announced state for range ("band") and each fighter's cage proximity (0, 1):
## key → {shown, candidate, held} (see _announce).
var _space: Dictionary = {}


## `p_rules` is a Ruleset (null = pro rules), or a round count with
## `p_round_seconds` for a short pro-rules test fight.
func _init(p_seed: int, p_fighters: Array[FighterState], p_actions: ActionLibrary, p_rules: Variant = null, p_round_seconds: int = 300) -> void:
	assert(p_fighters.size() == 2, "a fight has two fighters")
	fight_seed = p_seed
	_rng.seed = p_seed
	fighters = p_fighters
	actions = p_actions
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
	_apply_commands()
	for i in fighters.size():
		_advance_fighter(i)
		if _fight_over:
			now += 1
			return
	_update_space()
	if clock.tick():
		_end_round()
	now += 1


func distance() -> float:
	return fighters[0].pos.distance_to(fighters[1].pos)


## "out", "long", "mid" or "pocket" (Octagon).
func band() -> String:
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
			decisions[command.fighter].calls.hear(views[command.fighter], command.data.action_id)
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
			return "" if actions.has(id) else "unknown action"  # Feasibility is checked once the call is processed.
	return "unknown command"


## "" when fighter i could start this action now, else why not.
func why_not(i: int, id: String) -> String:
	if not actions.has(id):
		return "unknown action"
	var action: Dictionary = actions.get_action(id)
	if not ruleset.allows_action(action):
		return "not allowed under %s rules" % ruleset.name
	if not action.positions.has(fighters[i].position):
		return "not possible from this position"
	return ""


## One draw from the fight's seeded RNG, for decision sources (through FightView).
func roll() -> float:
	return _rng.randf()


func _advance_fighter(i: int) -> void:
	var f: FighterState = fighters[i]
	f.regen_tick()
	if f.is_down():
		f.down_ticks -= 1
		if f.down_ticks == 0:
			_emit(FightEvent.GOT_UP, i)
		return
	if f.is_rocked():
		f.rocked_ticks -= 1
		if f.rocked_ticks == 0:
			_emit(FightEvent.RECOVERED, i)
	if not f.is_free():
		f.phase_ticks_left -= 1
		if f.phase_ticks_left <= 0:
			_next_phase(i)
	if f.is_free():
		var seen: FightView = views[i]
		_move(i, decisions[i].preferred_distance(seen))
		var decision: Decision = decisions[i].decide(seen)
		if not decision.is_idle():
			_start_action(i, decision.action_id)
			decisions[i].started(seen, decision)
		for n: Dictionary in decisions[i].take_notes():
			_emit(n.type, i, n.data)


# --- Space: moving, range and the cage (docs/01 §3) --------------------------

## How far apart fighter i wants to be (their decision step decides; the feet follow).
func preferred_distance(i: int) -> float:
	return decisions[i].preferred_distance(views[i])


func move_speed(f: FighterState) -> float:
	return MOVE_BASE + MOVE_PER_STAT * (f.effective_stat("footwork") + f.effective_stat("speed")) / 200.0


## Share of the sideways footwork battle fighter i wins: circling off the fence
## when backing up, cutting the cage off when pressing (Footwork vs Footwork).
func footwork_share(i: int) -> float:
	return Contest.chance(Contest.STRIKE_BASE, fighters[i].effective_stat("footwork"), fighters[1 - i].effective_stat("footwork"))


## The feet: step toward the preferred distance. Backing up near
## the fence turns into circling toward open space; pressing a fighter who is
## circling mirrors them to cut the cage off.
func _move(i: int, want: float) -> void:
	var f: FighterState = fighters[i]
	var o: FighterState = fighters[1 - i]
	var gap: Vector2 = o.pos - f.pos
	var toward: Vector2 = gap.normalized() if gap.length() > 0.0 else Vector2.RIGHT
	var step: float = move_speed(f) / FightClock.TICKS_PER_SECOND
	var radial: float = clampf(gap.length() - want, -step, step)
	var side := Vector2.ZERO
	if radial < 0.0 and _near_fence(f):
		side = _open_side(f.pos, toward) * step * footwork_share(i)
	elif radial > 0.0 and _near_fence(o) and o.is_free() and distance() < preferred_distance(1 - i):
		side = _open_side(o.pos, -toward) * step * (1.0 - footwork_share(1 - i))
	f.pos = Octagon.keep_inside(f.pos + toward * radial + side)
	var after: Vector2 = f.pos - o.pos
	if after.length() < Octagon.MIN_GAP:
		f.pos = Octagon.keep_inside(o.pos + (after.normalized() if after.length() > 0.0 else -toward) * Octagon.MIN_GAP)


func _near_fence(f: FighterState) -> bool:
	return Octagon.distance_to_fence(f.pos) - Octagon.BODY_MARGIN < Octagon.NEAR_WITHIN


## Sideways (relative to the opponent) toward the middle of the cage.
func _open_side(p: Vector2, toward_opponent: Vector2) -> Vector2:
	var side := Vector2(-toward_opponent.y, toward_opponent.x)
	return side if side.dot(-p) >= 0.0 else -side


func _update_space() -> void:
	_announce("band", band(), FightEvent.RANGE_CHANGED, FightEvent.NO_ACTOR, "band")
	for i in fighters.size():
		_announce(i, cage_proximity(i), FightEvent.CAGE_CHANGED, i, "proximity")


func _announce(key: Variant, value: String, type: String, actor: int, field: String) -> void:
	var s: Dictionary = _space[key]
	if value == s.shown:
		s.held = 0
		return
	if value != s.candidate:
		s.candidate = value
		s.held = 0
	s.held += 1
	if s.held >= ANNOUNCE_AFTER_TICKS:
		s.shown = value
		s.held = 0
		_emit(type, actor, { field: value })


func _to_corners() -> void:
	for i in fighters.size():
		fighters[i].pos = START_POSITIONS[i]
	_space = { "band": _quiet(band()), 0: _quiet(cage_proximity(0)), 1: _quiet(cage_proximity(1)) }


func _quiet(value: String) -> Dictionary:
	return { "shown": value, "candidate": value, "held": 0 }


# --- Choosing and running actions ---------------------------------------------


func _start_action(i: int, id: String) -> void:
	var f: FighterState = fighters[i]
	f.action_id = id
	var action: Dictionary = actions.get_action(id)
	f.spend_stamina(float(action.stamina_cost))
	if action.category == "strike":
		f.strikes_thrown += 1
	_enter_phase(i, 0)


func _next_phase(i: int) -> void:
	var at: int = ActionLibrary.PHASES.find(fighters[i].phase) + 1
	if at >= ActionLibrary.PHASES.size():
		var id: String = fighters[i].action_id
		fighters[i].clear_action()
		_emit(FightEvent.ACTION_ENDED, i, { "action_id": id })
	else:
		_enter_phase(i, at)


## Enters phase `at`, skipping zero-length phases (each still emits its event).
func _enter_phase(i: int, at: int) -> void:
	var f: FighterState = fighters[i]
	f.phase = ActionLibrary.PHASES[at]
	f.phase_ticks_left = phase_ticks(f, f.action_id, f.phase)
	_emit(FightEvent.ACTION_PHASE, i, { "action_id": f.action_id, "phase": f.phase })
	if f.phase == "active":
		_resolve_active(i)
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
## flags_self), BACK_TO_CAGE when pinned, HANDS_LOW when exhausted or rocked.
func active_flags(i: int) -> Array[String]:
	var f: FighterState = fighters[i]
	var out: Array[String] = []
	if cage_proximity(i) == Octagon.CAGE_PINNED:
		out.append("BACK_TO_CAGE")
	if f.stamina_fraction() < HANDS_LOW_BELOW or f.is_rocked():
		out.append("HANDS_LOW")
	if f.is_free():
		return out
	var at: int = ActionLibrary.PHASES.find(f.phase)
	for entry: Dictionary in actions.get_action(f.action_id).flags_self:
		if ActionLibrary.PHASES.find(entry.from) <= at and at <= ActionLibrary.PHASES.find(entry.to):
			out.append(entry.flag)
	return out


## Fighter i's odds for this action against the opponent right now: the shared
## contest formula on effective stats, plus opportunity bonuses for flags the
## opponent carries and for catching them mid-commitment (a counter).
## 0 when a required opportunity is missing (catch-kick needs a kick).
func odds(i: int, id: String) -> float:
	return odds_breakdown(i, id).chance


## The same odds with every part named (OddsBreakdown), as strike events carry them.
func odds_breakdown(i: int, id: String) -> OddsBreakdown:
	var action: Dictionary = actions.get_action(id)
	var b := OddsBreakdown.new(id)
	b.base = Contest.base_for(action)
	b.attack = _average_stat(fighters[i], action.stats.offense)
	b.defense = _average_stat(fighters[1 - i], action.stats.defense)
	if is_counter(i):
		b.add_bonus("counter", COUNTER_BONUS)
	var opponent_flags: Array[String] = active_flags(1 - i)
	for opp: Dictionary in action.opportunities:
		if opponent_flags.has(opp.opponent_flag):
			b.add_bonus(opp.opponent_flag, float(opp.success_bonus))
		elif opp.get("required", false) and b.missing == "":
			b.missing = opp.opponent_flag
	return b.settle()


## True when fighter i's opponent is committed (wind-up or recovery) right now.
func is_counter(i: int) -> bool:
	return fighters[1 - i].phase in COUNTER_PHASES


func _resolve_active(i: int) -> void:
	var action: Dictionary = actions.get_action(fighters[i].action_id)
	if action.category != "strike":
		return  # Takedowns and the rest resolve from #15.
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
	var dealt: int = maxi(1, roundi(float(action.strike.base_damage) * strike_power(attacker) * (COUNTER_DAMAGE if counter else 1.0) * ruleset.damage_multiplier))
	defender.damage[target] += dealt
	attacker.strikes_landed += 1
	_round_points[i] += dealt * Judging.TARGET_WEIGHTS[target]
	_emit(FightEvent.STRIKE_LANDED, i, { "action_id": action.id, "target": target, "damage": dealt, "chance": chance, "counter": counter, "odds": breakdown.to_dict() })
	if target == "head":
		_head_impact(i, dealt)


## Damage multiplier from Power: 0.5 + Power / 100 (Power 50 → ×1).
func strike_power(f: FighterState) -> float:
	return 0.5 + f.effective_stat("power") / 100.0


## How hard a head shot landed relative to what fighter i's opponent can take.
func head_shock(i: int, dealt: float) -> float:
	var d: FighterState = fighters[1 - i]
	return dealt * (1.0 + d.hurt("head")) / (ROCK_THRESHOLD_BASE + ROCK_THRESHOLD_PER_CHIN * d.stat("chin"))


func rock_chance(shock: float) -> float:
	return clampf((shock - ROCK_FROM) * ROCK_SLOPE, 0.0, ROCK_MAX)


func ko_chance(shock: float, f: FighterState) -> float:
	var heart: float = 1.5 - f.effective_stat("heart") / 100.0
	return clampf(KO_BASE + (shock - 1.0) * KO_SLOPE, KO_MIN, KO_MAX) * heart


func _head_impact(i: int, dealt: int) -> void:
	var shock: float = head_shock(i, dealt)
	var chance: float = rock_chance(shock)
	if chance <= 0.0 or _rng.randf() >= chance:
		return
	var d: FighterState = fighters[1 - i]
	if d.is_rocked():
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
	if _rng.randf() < ko_chance(shock, d):
		_finish(i, RESULT_KO)
	elif d.knockdowns_this_round >= TKO_KNOCKDOWNS:
		_finish(i, RESULT_TKO)


# --- Rounds, judges and the result --------------------------------------------

func _end_round() -> void:
	var cards: Array = []
	for j in Judging.JUDGES:
		var seen: Array[float] = []
		for i in 2:
			seen.append(_round_points[i] * (1.0 + _rng.randf_range(-Judging.JUDGE_NOISE, Judging.JUDGE_NOISE)))
		var card: Array[int] = Judging.round_card(seen, _round_knockdowns)
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
		f.knockdowns_this_round = 0
	_round_points = [0.0, 0.0]
	_round_knockdowns = [0, 0]
	clock.start_next_round()
	_to_corners()


func _finish(winner: int, result: String) -> void:
	_fight_over = true
	_emit(FightEvent.FIGHT_ENDED, FightEvent.NO_ACTOR, { "result": result, "winner": winner })


func _average_stat(f: FighterState, ids: Array) -> float:
	if ids.is_empty():
		return FighterState.DEFAULT_STAT
	var total: float = 0.0
	for id: String in ids:
		total += f.effective_stat(id)
	return total / ids.size()


func _emit(type: String, actor: int = FightEvent.NO_ACTOR, data: Dictionary = {}) -> void:
	var event := FightEvent.new(now, clock.current_round, type, actor, data)
	events.append(event)
	event_emitted.emit(event)
