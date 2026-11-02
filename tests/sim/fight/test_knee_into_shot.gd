extends GutTest
## Knees into shots (docs/01 §45, D182): the knee meets a shot from mid range as he brings his head
## to it, and outside fighters who know the knee throw it into a shot they read, ahead of the sprawl.

const SEED: int = 20261102
const SEEDS: int = 30

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


## Two fighters who do nothing unless told, `gap` metres apart (1.8 = mid range).
func _pair(red_stats: Dictionary = {}, blue_stats: Dictionary = {}, gap: float = 1.8, fight_seed: int = SEED) -> FightSim:
	var sim := FightSim.new(fight_seed, [FighterState.new("Red", red_stats, [], 0.0), FighterState.new("Blue", blue_stats, [], 0.0)], _actions, 1, 300)
	sim.fighters[0].pos = Vector2(-gap / 2.0, 0.0)
	sim.fighters[1].pos = Vector2(gap / 2.0, 0.0)
	return sim


func _queue(sim: FightSim, tick: int, fighter: int, action_id: String) -> void:
	assert_true(sim.submit(FightCommand.queue_action(tick, fighter, action_id)))


func _ticks(sim: FightSim, n: int) -> void:
	for k in n:
		if sim.is_over():
			return
		sim.tick()


func _events(sim: FightSim, type: String, actor: int = FightEvent.NO_ACTOR) -> Array[FightEvent]:
	var out: Array[FightEvent] = []
	for e in sim.events:
		if e.type == type and (actor == FightEvent.NO_ACTOR or e.actor == actor):
			out.append(e)
	return out


func _starts(sim: FightSim, actor: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in _events(sim, FightEvent.ACTION_PHASE, actor):
		if e.data.phase == "telegraph":
			out.append({ "tick": e.tick, "action_id": e.data.action_id, "why": String(e.data.get("why", "")) })
	return out


# --- Who has it ----------------------------------------------------------------------

func test_the_knee_meets_shots_and_the_karate_fighter_has_one_now() -> void:
	assert_true(_actions.get_action("knee").strike.get("into_shots", false))
	assert_has(_roster.profile("karate").techniques, "knee")
	assert_has(_roster.profile("kicker").techniques, "knee")


# --- Reaching a shot from mid range ----------------------------------------------------

func test_a_knee_from_mid_range_meets_a_shot_and_stops_it() -> void:
	var stopped: int = 0
	for n in SEEDS:
		var sim: FightSim = _pair({ "takedowns": 0 }, { "clinch_striking": 100, "power": 100 }, 1.8, SEED + n)
		_queue(sim, 0, 0, "double_leg")
		_queue(sim, 1, 1, "knee")  # Lands as the shot drives in, his head low.
		_ticks(sim, 12)
		assert_eq(_events(sim, FightEvent.STRIKE_MISSED, 1).filter(func(e: FightEvent) -> bool: return e.data.get("reason", "") == "out of range").size(), 0,
			"he brings his head to it")
		var landed: Array[FightEvent] = _events(sim, FightEvent.STRIKE_LANDED, 1)
		if landed.is_empty():
			continue
		stopped += 1
		assert_eq(landed[0].data.target, "head", "into the lowered head")
		assert_eq(landed[0].data.get("into", ""), "double_leg")
		assert_eq(_events(sim, FightEvent.GRAPPLE_WON, 0).size(), 0, "the shot is stopped")
	assert_gt(stopped, SEEDS / 2)


func test_from_mid_range_a_knee_still_falls_short_of_a_man_who_isn_t_shooting() -> void:
	var sim: FightSim = _pair()
	_queue(sim, 0, 1, "knee")
	_ticks(sim, 8)
	var missed: Array[FightEvent] = _events(sim, FightEvent.STRIKE_MISSED, 1)
	assert_eq(missed.size(), 1)
	assert_eq(missed[0].data.get("reason", ""), "out of range")
	assert_false(sim.meets_shot(1, _actions.get_action("knee")))
	assert_false(sim.meets_shot(1, _actions.get_action("jab")), "only a strike that meets shots")


# --- The AI --------------------------------------------------------------------------

func _knees_into_shots(range_leaning: int) -> int:
	var shooter := FighterState.new("Shooter", { "takedowns": 60 }, ["double_leg"], 0.08, StyleLeanings.new({ "range": 100, "base": 100 }))
	var kicker := FighterState.new("Kicker", { "fight_iq": 100, "clinch_striking": 70 }, ["jab", "knee"], 0.0001, StyleLeanings.new({ "range": range_leaning }))
	var sim := FightSim.new(SEED, [shooter, kicker], _actions, 1, 300)
	_ticks(sim, 3000)
	return _starts(sim, 1).filter(func(s: Dictionary) -> bool: return s.why == "knees into the shot").size()


func test_an_outside_fighter_knees_the_shots_he_reads_and_an_inside_one_sprawls_first() -> void:
	assert_gt(_knees_into_shots(-100), 2, "the outside fighter knees into the shot")
	assert_eq(_knees_into_shots(50), 0, "the inside fighter sprawls first, as before")
