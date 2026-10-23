class_name FightSim
extends RefCounted
## Headless fight simulation core (docs/01-fight-engine.md §2, issue #12).
##
## Each tick() is 100 ms of fight time: apply that tick's commands, then advance
## both fighters (action phases, placeholder AI), emitting FightEvents. All
## randomness comes from one seeded RNG, so the same seed + command log always
## produces the same fight (see FightSim.replay).
##
## Every contest uses Contest.chance on effective stats (docs/11 §3), and Speed
## and Kicking change how long telegraphs and wind-ups last (§3.3). Strikes
## resolve; takedowns get their odds from odds() but land with #15. Distance and
## the real damage model are the standing game (#13), and the utility AI is #14.

signal event_emitted(event: FightEvent)

## Speed (and Kicking, for kick telegraphs) shortens or stretches telegraph and
## wind-up by up to 20% (docs/11 §3.3); being tired stretches them up to another
## 30% (docs/01 §8). Rounded to whole ticks.
const MAX_TIMING_SHIFT: float = 0.2
const TIMED_PHASES: Array[String] = ["telegraph", "windup"]

var fight_seed: int
var clock: FightClock
var actions: ActionLibrary
var fighters: Array[FighterState]
## Ticks processed since the opening bell. The next tick() processes tick `now`.
var now: int = 0
var events: Array[FightEvent] = []
var command_log: Array[FightCommand] = []

var _rng := RandomNumberGenerator.new()
var _pending: Array[FightCommand] = []
var _fight_over: bool = false


func _init(p_seed: int, p_fighters: Array[FighterState], p_actions: ActionLibrary, p_rounds: int = 3, p_round_seconds: int = 300) -> void:
	assert(p_fighters.size() == 2, "a fight has two fighters")
	fight_seed = p_seed
	_rng.seed = p_seed
	fighters = p_fighters
	actions = p_actions
	clock = FightClock.new(p_rounds, p_round_seconds)


## Rebuilds a fight from its seed and command log. Pass freshly made fighters set
## up the same way as in the original fight (FighterState is mutated by a fight).
static func replay(p_seed: int, p_fighters: Array[FighterState], p_actions: ActionLibrary, commands: Array, p_rounds: int = 3, p_round_seconds: int = 300) -> FightSim:
	var sim := FightSim.new(p_seed, p_fighters, p_actions, p_rounds, p_round_seconds)
	for entry: Variant in commands:
		sim.submit(entry if entry is FightCommand else FightCommand.from_dict(entry))
	sim.run_to_end()
	return sim


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
	_apply_commands()
	for i in fighters.size():
		_advance_fighter(i)
	if clock.tick():
		_emit(FightEvent.ROUND_ENDED)
		if clock.is_fight_over():
			_fight_over = true
			_emit(FightEvent.FIGHT_ENDED, FightEvent.NO_ACTOR, { "result": "time" })
		else:
			for f in fighters:
				f.clear_action()
				f.recover_between_rounds()
			clock.start_next_round()
	now += 1


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
		else:
			fighters[command.fighter].queued_action_id = command.data.action_id
		command_log.append(command)


func _reject_reason(command: FightCommand) -> String:
	if command.fighter < 0 or command.fighter >= fighters.size():
		return "unknown fighter"
	if command.type != FightCommand.QUEUE_ACTION:
		return "unknown command"
	var id: String = command.data.get("action_id", "")
	if not actions.has(id):
		return "unknown action"
	if not actions.get_action(id).positions.has(fighters[command.fighter].position):
		return "not possible from this position"
	return ""


func _advance_fighter(i: int) -> void:
	var f: FighterState = fighters[i]
	f.regen_tick()
	if not f.is_free():
		f.phase_ticks_left -= 1
		if f.phase_ticks_left <= 0:
			_next_phase(i)
	if f.is_free():
		var id: String = _choose_action(f)
		if id != "":
			_start_action(i, id)


## Queued commands win; otherwise the placeholder AI sometimes throws from its
## repertoire, nudged by style leanings (docs/11 §4.2) and panic (§3.2).
func _choose_action(f: FighterState) -> String:
	if f.queued_action_id != "":
		var id: String = f.queued_action_id
		f.queued_action_id = ""
		return id
	if f.repertoire.is_empty() or _rng.randf() >= idle_work_rate(f):
		return ""
	var weights: Array[float] = []
	var total: float = 0.0
	for id in f.repertoire:
		weights.append(choice_weight(f, id))
		total += weights[-1]
	if total <= 0.0:
		return ""
	var roll: float = _rng.randf() * total
	for n in weights.size():
		roll -= weights[n]
		if roll < 0.0:
			return f.repertoire[n]
	return f.repertoire[-1]


## Chance per idle tick to start something. Pace +100 = 1.5× as busy, −100 = half; panic adds 20%.
func idle_work_rate(f: FighterState) -> float:
	var rate: float = f.work_rate * (1.0 + f.style.value(StyleLeanings.PACE) / 200.0)
	if f.is_panicking():
		rate *= 1.0 + FighterState.PANIC_WORK_RATE_BONUS
	return rate


## How much the AI favours an action from its repertoire. The Base leaning tilts
## strikes against takedowns: +100 doubles takedowns and halves strikes, −100 never shoots.
func choice_weight(f: FighterState, id: String) -> float:
	var base_leaning: float = f.style.value(StyleLeanings.BASE) / 100.0
	match actions.get_action(id).category:
		"takedown":
			return 1.0 + base_leaning
		"strike":
			return 1.0 - base_leaning / 2.0
	return 1.0


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


## Flags fighter i carries right now from their current action's phase (docs/09 flags_self).
func active_flags(i: int) -> Array[String]:
	var f: FighterState = fighters[i]
	var out: Array[String] = []
	if f.is_free():
		return out
	var at: int = ActionLibrary.PHASES.find(f.phase)
	for entry: Dictionary in actions.get_action(f.action_id).flags_self:
		if ActionLibrary.PHASES.find(entry.from) <= at and at <= ActionLibrary.PHASES.find(entry.to):
			out.append(entry.flag)
	return out


## Fighter i's odds for this action against the opponent right now: the shared
## contest formula on effective stats, plus opportunity bonuses for flags the
## opponent carries. 0 when a required opportunity is missing (catch-kick needs a kick).
func odds(i: int, id: String) -> float:
	var action: Dictionary = actions.get_action(id)
	var opponent_flags: Array[String] = active_flags(1 - i)
	var bonus: float = 0.0
	for opp: Dictionary in action.opportunities:
		if opponent_flags.has(opp.opponent_flag):
			bonus += float(opp.success_bonus)
		elif opp.get("required", false):
			return 0.0
	return Contest.chance(Contest.base_for(action),
		_average_stat(fighters[i], action.stats.offense),
		_average_stat(fighters[1 - i], action.stats.defense),
		bonus)


func _resolve_active(i: int) -> void:
	var action: Dictionary = actions.get_action(fighters[i].action_id)
	if action.category != "strike":
		return  # Takedowns and the rest resolve from #15.
	var attacker: FighterState = fighters[i]
	var defender: FighterState = fighters[1 - i]
	var target: String = action.strike.target
	var chance: float = odds(i, action.id)
	if _rng.randf() < chance:
		var dealt: int = int(action.strike.base_damage)
		defender.damage[target] += dealt
		attacker.strikes_landed += 1
		_emit(FightEvent.STRIKE_LANDED, i, { "action_id": action.id, "target": target, "damage": dealt, "chance": chance })
	else:
		_emit(FightEvent.STRIKE_MISSED, i, { "action_id": action.id, "target": target, "chance": chance })


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
