class_name TitleBackdrop
extends RefCounted
## A real fight behind the title screen (docs/06 §6.14, D434; Kyle's card "A real fight in the cage"): two fighters
## picked at random from the roster fight a simmed fight in the cage behind the menu, both corners the AI's, at
## normal speed with the fight screen's own slow-downs on the big moments. No names over their heads and no range
## tag (ArenaView.backdrop). When it ends the finish is held, and NEXT_AFTER seconds later a new pair walks in.

## Fight seconds per real second.
const RATE: float = 1.0
## Real seconds after a fight ends before the next pair.
const NEXT_AFTER: float = 5.0
## How far (metres) the camera is slid left so the fight sits to the right of the menu.
const CAMERA_SHIFT: float = 1.4
## Roster fighters left out: the ones made for the tests.
const LEFT_OUT_PREFIX := "check_"

var driver: FightDriver
## Fights started so far (the first is 1).
var fights: int = 0

var _roster: FighterLibrary
var _actions: ActionLibrary
var _rng := RandomNumberGenerator.new()
var _over_for: float = 0.0


func _init(p_roster: FighterLibrary, p_actions: ActionLibrary, p_seed: int = -1) -> void:
	_roster = p_roster
	_actions = p_actions
	if p_seed >= 0:
		_rng.seed = p_seed
	else:
		_rng.randomize()


## The two fighters for a fight: two different men from `ids`, leaving out the tests' own.
static func pick_pair(ids: Array, rng: RandomNumberGenerator) -> Array[String]:
	var pool: Array[String] = []
	for id: Variant in ids:
		if not String(id).begins_with(LEFT_OUT_PREFIX):
			pool.append(String(id))
	pool.sort()
	if pool.size() < 2:
		return []
	var a: int = rng.randi_range(0, pool.size() - 1)
	var b: int = rng.randi_range(0, pool.size() - 2)
	if b >= a:
		b += 1
	return [pool[a], pool[b]]


## Starts a new fight between a fresh pair and shows it in `arena`.
func start(arena: ArenaView) -> void:
	var pair: Array[String] = pick_pair(_roster.ids(), _rng)
	if pair.is_empty():
		return
	var fight_seed: int = _rng.randi() & 0x7fffffff
	var sim := FightSim.new(fight_seed, _roster.make_pair(pair[0], pair[1]), _actions, Ruleset.load_id(Ruleset.DEFAULT_ID))
	for i in 2:
		sim.corners[i] = Corner.new(Corner.AI, fight_seed + i)
	driver = FightDriver.new(sim, 0)
	driver.normal_rate = RATE
	_over_for = 0.0
	fights += 1
	arena.tell_watch = null
	arena.tell_cues = false
	arena.drill = false
	arena.backdrop = true
	arena.watch(driver)
	arena.camera.h_offset = -CAMERA_SHIFT


## Moves the fight on by `delta` real seconds; a while after it ends, starts the next.
func advance(arena: ArenaView, delta: float) -> void:
	if driver == null:
		return
	if driver.sim.is_over():
		_over_for += delta
		if _over_for >= NEXT_AFTER:
			start(arena)
		return
	driver.advance(delta)


## Stops it and clears it out of the arena, leaving it free for a real fight.
func stop(arena: ArenaView) -> void:
	if driver != null and arena.driver == driver:
		arena.watch(null)
	driver = null
	arena.backdrop = false
	arena.camera.h_offset = 0.0


func running() -> bool:
	return driver != null
