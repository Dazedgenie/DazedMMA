class_name FinishReplay
extends RefCounted
## The finish again, slowly, behind the verdict (docs/06 §6.16, D436; Kyle's pick on the D436 cards): when a fight ends
## inside the distance, its last few seconds play again in slow motion in the cage from another angle, over and over
## until the result screen goes. It's the real fight: a fresh FightSim from the same seed, the same two men made fresh
## and every command the fight took (the calls, the rules, the corners' calls, the towel), so it plays out exactly as it
## happened (FightSim.replay, docs/04 §2.2). If it ever doesn't end the same way, it isn't shown again.

## How many fight seconds before the end it starts, and how fast it plays (fight seconds a real second).
const SECONDS: float = 6.0
const RATE: float = 0.5
## How long the finish is held before it plays again (real seconds).
const HOLD_AFTER: float = 2.0
## The camera's turn away from the fight's own view (radians) and how much closer it stands.
const VIEW_TURN: float = 0.8
const VIEW_ZOOM: float = 0.8

var driver: FightDriver
## How many times it has played.
var plays: int = 0
## False once a replay ended differently from the fight (it stops showing).
var exact: bool = true

var _seed: int
var _make_fighters: Callable
var _actions: ActionLibrary
var _rules: Ruleset
var _commands: Array[FightCommand] = []
var _player: int
var _start_tick: int
var _end: Dictionary
var _held: float = 0.0


## Only a finish is replayed: a decision has no moment to see again.
static func wanted(sim: FightSim) -> bool:
	if sim.events.is_empty() or sim.events[-1].type != FightEvent.FIGHT_ENDED:
		return false
	return String(sim.events[-1].data.get("result", "")) in [FightSim.RESULT_KO, FightSim.RESULT_TKO, FightSim.RESULT_SUB]


## `make_fighters` returns the two men made fresh, as the fight made them (FighterState is changed by a fight).
func _init(sim: FightSim, make_fighters: Callable, p_actions: ActionLibrary, p_player: int = 0) -> void:
	_seed = sim.fight_seed
	_make_fighters = make_fighters
	_actions = p_actions
	_player = p_player
	_rules = Ruleset.load_id(sim.ruleset.id)
	_rules.rounds = sim.ruleset.rounds
	_rules.round_seconds = sim.ruleset.round_seconds
	_rules.round_lengths = sim.ruleset.round_lengths.duplicate()
	_commands.assign(sim.command_log.duplicate())
	_start_tick = maxi(0, sim.now - roundi(SECONDS * FightClock.TICKS_PER_SECOND))
	for e in sim.events:
		if e.type == FightEvent.ROUND_ENDED:
			_start_tick = maxi(_start_tick, e.tick + 1)  # Never across a bell: the replay would stop for the break.
	_end = sim.events[-1].data.duplicate(true) if not sim.events.is_empty() else {}


## Plays it in the cage.
func start(arena: ArenaView) -> void:
	_play(arena)


## Moves it on; when it has ended and been held a while it plays again (or stops, if it didn't end the same).
func advance(arena: ArenaView, delta: float) -> void:
	if driver == null:
		return
	if not driver.sim.is_over():
		driver.advance(delta)
		return
	if _held == 0.0:
		exact = exact and JSON.stringify(driver.sim.events[-1].data) == JSON.stringify(_end)
	_held += delta
	if _held >= HOLD_AFTER and exact:
		_play(arena)


func running() -> bool:
	return driver != null


## Gives the cage back.
func stop(arena: ArenaView) -> void:
	if driver != null and arena.driver == driver:
		arena.watch(null)
	arena.view_turn = 0.0
	arena.view_zoom = 1.0
	arena.backdrop = false
	driver = null


## A fresh copy of the fight, run quietly up to a few seconds before the end, then played slowly from there.
func _play(arena: ArenaView) -> void:
	var fighters: Array[FighterState] = []
	fighters.assign(_make_fighters.call())
	var sim := FightSim.new(_seed, fighters, _actions, _rules)
	for c in _commands:
		sim.submit(c)
	while sim.now < _start_tick and not sim.is_over():
		sim.tick()
	driver = FightDriver.new(sim, _player)
	driver.normal_rate = RATE
	driver.auto_slow = false
	driver.flourishes = false
	arena.backdrop = true  # No names over their heads, no range tag: a picture behind the verdict.
	arena.watch(driver)
	arena.view_turn = VIEW_TURN
	arena.view_zoom = VIEW_ZOOM
	_held = 0.0
	plays += 1
