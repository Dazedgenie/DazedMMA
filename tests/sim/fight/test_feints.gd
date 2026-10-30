extends GutTest
## Feints and blind shots (D131, docs/01 §29): the feint and the bite, which shots and clinch
## entries count as blind, what a blind shot costs, and grapplers setting their shots up.

const SEED: int = 20261028
const SEEDS: int = 40

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


## Two fighters who do nothing unless told, `gap` metres apart in the middle of the cage.
func _pair(red_stats: Dictionary = {}, blue_stats: Dictionary = {}, gap: float = 1.8, fight_seed: int = SEED) -> FightSim:
	var sim := FightSim.new(fight_seed, [FighterState.new("Red", red_stats, [], 0.0), FighterState.new("Blue", blue_stats, [], 0.0)], _actions, 1, 300)
	sim.fighters[0].pos = Vector2(-gap / 2.0, 0.0)
	sim.fighters[1].pos = Vector2(gap / 2.0, 0.0)
	return sim


func _queue(sim: FightSim, tick: int, fighter: int, action_id: String) -> void:
	assert_true(sim.submit(FightCommand.queue_action(tick, fighter, action_id)))


func _ticks(sim: FightSim, n: int) -> void:
	for k in n:
		sim.tick()


func _events(sim: FightSim, type: String, actor: int = FightEvent.NO_ACTOR) -> Array[FightEvent]:
	var out: Array[FightEvent] = []
	for e in sim.events:
		if e.type == type and (actor == FightEvent.NO_ACTOR or e.actor == actor):
			out.append(e)
	return out


func _bonus(odds: Dictionary, bonus_name: String) -> float:
	for b: Dictionary in odds.bonuses:
		if b.name == bonus_name:
			return float(b.value)
	return 0.0


func _bonus_names(odds: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for b: Dictionary in odds.bonuses:
		out.append(b.name)
	return out


## The telegraph event of fighter i's first move with this id.
func _started(sim: FightSim, i: int, id: String) -> FightEvent:
	for e in _events(sim, FightEvent.ACTION_PHASE, i):
		if e.data.phase == "telegraph" and e.data.action_id == id:
			return e
	return null


## Red feints and, on the first seed where Blue bites, the sim is left where the feint ends (tick 4).
func _bitten() -> FightSim:
	for n in SEEDS:
		var sim: FightSim = _pair({ "fight_iq": 100, "speed": 100 }, {}, 1.8, SEED + n)
		_queue(sim, 0, 0, "feint")
		_ticks(sim, 4)
		if _events(sim, FightEvent.FEINTED, 0)[0].data.bit:
			return sim
	return null


# --- The feint and the bite -----------------------------------------------------

func test_everyone_can_feint_and_it_is_one_roll_when_it_gets_there() -> void:
	assert_has(_actions.basic_ids(), "feint", "a basic move: everyone knows it")
	var bit: int = 0
	for n in SEEDS:
		var sim: FightSim = _pair({}, {}, 1.8, SEED + n)
		_queue(sim, 0, 0, "feint")
		_ticks(sim, 6)
		var feinted: Array[FightEvent] = _events(sim, FightEvent.FEINTED, 0)
		assert_eq(feinted.size(), 1, "one roll for the feint")
		assert_almost_eq(float(feinted[0].data.chance), 0.4, 0.001, "even fighters: the base from data/actions/feint.json")
		if feinted[0].data.bit:
			bit += 1
	assert_between(bit, 5, 30, "about 40%% of feints bite between even fighters (%d of %d)" % [bit, SEEDS])


func test_a_feint_that_bites_leaves_the_opponent_reacting_for_a_second() -> void:
	var sim: FightSim = _bitten()
	assert_not_null(sim, "a 75% feint bites on some seed")
	assert_has(sim.active_flags(1), "BIT_ON_FEINT", "hands up, weight back")
	assert_eq(sim.fighters[0].feints_tried, 1)
	assert_eq(sim.fighters[0].feints_bit, 1)
	_ticks(sim, 6)
	assert_has(sim.active_flags(1), "BIT_ON_FEINT", "still reacting most of a second later")
	_ticks(sim, 4)
	assert_does_not_have(sim.active_flags(1), "BIT_ON_FEINT", "a second after the bite it's gone")


func test_a_feint_from_out_of_range_fools_nobody() -> void:
	var sim: FightSim = _pair({}, {}, 5.0)
	_queue(sim, 0, 0, "feint")
	_ticks(sim, 6)
	var feinted: Array[FightEvent] = _events(sim, FightEvent.FEINTED, 0)
	assert_eq(feinted.size(), 1)
	assert_eq(feinted[0].data.reason, "out of range")
	assert_false(feinted[0].data.bit)


func test_the_same_feint_over_and_over_bites_less_each_time() -> void:
	var sim: FightSim = _pair()
	for k in 4:
		_queue(sim, 10 * k, 0, "feint")
	_ticks(sim, 40)
	var feinted: Array[FightEvent] = _events(sim, FightEvent.FEINTED, 0)
	assert_eq(feinted.size(), 4)
	assert_eq(_bonus(feinted[0].data.odds, "feinted again"), 0.0, "the first one is fresh")
	for k in range(1, 4):
		assert_almost_eq(_bonus(feinted[k].data.odds, "feinted again"), -FightSim.FEINT_REPEAT * k, 0.001, "feint %d" % (k + 1))
	assert_lt(float(feinted[3].data.chance), float(feinted[0].data.chance))


# --- Blind shots ------------------------------------------------------------------

func test_a_double_leg_with_nothing_before_it_is_a_blind_shot() -> void:
	var sim: FightSim = _pair()
	_queue(sim, 0, 0, "double_leg")
	_ticks(sim, 1)
	assert_true(_started(sim, 0, "double_leg").data.get("blind", false), "the feed says so")
	assert_true(sim.fighters[0].blind_shot)
	assert_has(sim.active_flags(0), "BLIND_SHOT")
	assert_eq(sim.fighters[0].blind_shots, 1)
	_ticks(sim, 20)
	var rolled: Array[FightEvent] = _events(sim, FightEvent.GRAPPLE_WON, 0)
	rolled.append_array(_events(sim, FightEvent.GRAPPLE_STOPPED, 0))
	assert_eq(rolled.size(), 1)
	assert_almost_eq(_bonus(rolled[0].data.odds, "own BLIND_SHOT"), -0.20, 0.001, "a worse shot: data/actions/double_leg.json")
	assert_false(sim.fighters[0].blind_shot, "over once the move is")


func test_a_jab_just_before_the_shot_sets_it_up_and_one_long_before_does_not() -> void:
	var sim: FightSim = _pair()
	_queue(sim, 0, 0, "jab")  # Over at tick 5.
	_queue(sim, 6, 0, "double_leg")
	_ticks(sim, 8)
	assert_false(_started(sim, 0, "double_leg").data.get("blind", false), "straight off the jab")
	var late: FightSim = _pair()
	_queue(late, 0, 0, "jab")
	_queue(late, 5 + FightSim.SET_UP_TICKS + 1, 0, "double_leg")
	_ticks(late, 5 + FightSim.SET_UP_TICKS + 3)
	assert_true(_started(late, 0, "double_leg").data.get("blind", false), "too long after the jab")


func test_a_shot_off_a_feint_that_bit_finds_him_reacting() -> void:
	var sim: FightSim = _bitten()
	_queue(sim, sim.now, 0, "double_leg")
	_ticks(sim, 10)
	assert_false(_started(sim, 0, "double_leg").data.get("blind", false), "set up by the feint")
	var rolled: Array[FightEvent] = _events(sim, FightEvent.GRAPPLE_WON, 0)
	rolled.append_array(_events(sim, FightEvent.GRAPPLE_STOPPED, 0))
	assert_eq(rolled.size(), 1)
	assert_has(_bonus_names(rolled[0].data.odds), "BIT_ON_FEINT", "still reacting as the shot arrives")


func test_a_feint_that_did_not_bite_still_sets_the_shot_up() -> void:
	for n in SEEDS:
		var sim: FightSim = _pair({}, { "fight_iq": 100 }, 1.8, SEED + n)
		_queue(sim, 0, 0, "feint")
		_ticks(sim, 4)
		if _events(sim, FightEvent.FEINTED, 0)[0].data.bit:
			continue
		_queue(sim, sim.now, 0, "double_leg")
		_ticks(sim, 2)
		assert_false(_started(sim, 0, "double_leg").data.get("blind", false), "he had to watch the feint")
		assert_does_not_have(sim.active_flags(1), "BIT_ON_FEINT")
		return
	fail_test("a 25% feint should fail on some seed")


func test_a_shot_timed_into_a_kick_is_not_blind_but_one_at_a_fighter_on_the_fence_is() -> void:
	var sim: FightSim = _pair()
	_queue(sim, 0, 1, "body_kick")  # Telegraph 3 ticks, wind-up 3 more.
	_queue(sim, 1, 0, "double_leg")  # Due to arrive 5 ticks later, in the kick's wind-up.
	_ticks(sim, 2)
	assert_false(_started(sim, 0, "double_leg").data.get("blind", false), "timed into the kick: a counter")
	var fence: FightSim = _pair()
	fence.fighters[1].pos = Vector2(Octagon.APOTHEM - Octagon.BODY_MARGIN, 0.0)
	fence.fighters[0].pos = fence.fighters[1].pos - Vector2(1.8, 0.0)
	assert_eq(fence.cage_proximity(1), Octagon.CAGE_PINNED)
	_queue(fence, 0, 0, "double_leg")
	_ticks(fence, 1)
	assert_true(_started(fence, 0, "double_leg").data.get("blind", false), "the fence stops the sprawl going back, it doesn't hide the shot")


func test_catches_throws_and_shots_from_the_clinch_are_never_blind() -> void:
	for id: String in ["catch_kick_single", "foot_sweep"]:
		var sim: FightSim = _pair()
		assert_false(sim.would_be_blind(0, id), "%s needs an opening: a reaction, not a blind shot" % id)
	var clinch: FightSim = _pair({}, {}, 0.6)
	assert_true(clinch.apply_transition(0, "clinch_entry"))
	for id: String in ["double_leg", "outside_trip", "hip_throw"]:
		assert_false(clinch.would_be_blind(0, id), "%s from the clinch" % id)


func test_a_clinch_entry_is_never_blind_but_finds_a_bitten_opponent_reacting() -> void:
	var sim: FightSim = _pair({}, {}, 1.2)
	assert_false(sim.would_be_blind(0, "clinch_entry"), "blind shots are takedowns: a strikers' clinch stays as it was")
	sim.fighters[1].bit_ticks = 10
	assert_has(_bonus_names(sim.odds_breakdown(0, "clinch_entry").to_dict()), "BIT_ON_FEINT")


func test_a_blind_shot_is_easier_to_sprawl_on_and_costs_more_when_it_is() -> void:
	var stuck: Array[int] = []
	var spent: Array[float] = []
	for setup: bool in [false, true]:
		for n in SEEDS:
			var sim: FightSim = _pair({}, { "takedown_defense": 100, "speed": 100 }, 1.8, SEED + n)
			var at: int = 0
			if setup:
				_queue(sim, 0, 0, "jab")
				at = 6
			_queue(sim, at, 0, "double_leg")
			_queue(sim, at + 3, 1, "sprawl")
			_ticks(sim, at + 1)
			var before: float = sim.fighters[0].stamina
			_ticks(sim, 5)
			var met: Array[FightEvent] = _events(sim, FightEvent.SPRAWLED, 1)
			assert_eq(met.size(), 1)
			assert_eq(_bonus_names(met[0].data.odds).has("BLIND_SHOT"), not setup)
			if met[0].data.worked:
				stuck.append(sim.fighters[0].phase_ticks_left)
				spent.append(before - sim.fighters[0].stamina)
				break
	assert_eq(stuck.size(), 2, "a sprawl that works on some seed, each way")
	assert_eq(stuck[0] - stuck[1], FightSim.BLIND_STUCK_TICKS, "stuck longer under the sprawl")
	assert_almost_eq(spent[0] - spent[1], FightSim.BLIND_STUFFED_STAMINA, 0.5, "and it costs more")


func test_a_blind_shot_that_is_defended_costs_more_stamina() -> void:
	var spent: Array[float] = []
	for setup: bool in [false, true]:
		for n in SEEDS:
			var sim: FightSim = _pair({}, { "takedown_defense": 100 }, 1.8, SEED + n)
			var at: int = 0
			if setup:
				_queue(sim, 0, 0, "jab")
				at = 6
			_queue(sim, at, 0, "double_leg")
			_ticks(sim, at + 1)
			var before: float = sim.fighters[0].stamina
			_ticks(sim, 10)
			var stopped: Array[FightEvent] = _events(sim, FightEvent.GRAPPLE_STOPPED, 0)
			if not stopped.is_empty() and stopped[0].data.reason == "defended":
				spent.append(before - sim.fighters[0].stamina)
				break
	assert_eq(spent.size(), 2)
	assert_almost_eq(spent[0] - spent[1], FightSim.BLIND_STUFFED_STAMINA, 0.5)


# --- The fighter AI ---------------------------------------------------------------

func test_grapplers_feint_before_some_shots_and_shoot_off_the_feint() -> void:
	var sim := FightSim.new(SEED, [_roster.make("wrestler"), FighterState.new("Statue", {}, [], 0.0)], _actions)
	for k in 3000:
		sim.tick()
		if not sim.situation.is_standing():
			sim._break_apart(1)
	var starts: Array[Dictionary] = []
	for e in _events(sim, FightEvent.ACTION_PHASE, 0):
		if e.data.phase == "telegraph":
			starts.append({ "id": e.data.action_id, "why": String(e.data.get("why", "")), "blind": e.data.get("blind", false) })
	var feints: int = 0
	for n in starts.size():
		if starts[n].id != "feint":
			continue
		feints += 1
		assert_string_starts_with(starts[n].why, "feints to set up the")
		if n + 1 < starts.size() and starts[n + 1].why == "shoots off the feint":
			assert_false(starts[n + 1].blind, "set up by the feint")
	assert_gt(feints, 3, "the Wrestler feints before some of his shots")


func test_a_smarter_fighter_sets_up_more_of_his_shots() -> void:
	var low := FighterState.new("Low", { "fight_iq": 20 })
	var high := FighterState.new("High", { "fight_iq": 90 })
	assert_lt(FighterAI.setup_chance(low), FighterAI.setup_chance(high))
	assert_almost_eq(FighterAI.setup_chance(FighterState.new("Even")), FighterAI.SETUP_BASE + FighterAI.SETUP_PER_IQ * 0.5, 0.001)


func test_strikers_feint_only_to_herd_a_man_they_are_cutting_off() -> void:
	var sim := FightSim.new(SEED, _roster.make_pair("kicker", "boxer"), _actions)
	_ticks(sim, 3000)
	for e in sim.events:
		if e.type == FightEvent.ACTION_PHASE and e.data.phase == "telegraph" and e.data.action_id == FightSim.FEINT:
			assert_eq(String(e.data.get("why", "")), "herds him with a feint", "no shots to set up: a striker's feints herd him by the fence (D232)")


func test_a_blind_shot_is_easier_to_read_and_one_off_a_bite_is_harder() -> void:
	var counts: Array[int] = [0, 0, 0]
	for which in 3:
		for n in 300:
			var sim: FightSim = _pair({}, {}, 1.8, SEED + n)
			var ai: FighterAI = sim.decisions[1].ai
			if which == 1:
				sim.fighters[0].blind_shot = true
			elif which == 2:
				sim.fighters[1].bit_ticks = 5
			sim.fighters[0].action_id = "double_leg"
			sim.fighters[0].phase = "telegraph"
			sim.fighters[0].phase_ticks_left = 3
			ai.on_event(sim.views[1], FightEvent.new(0, 1, FightEvent.ACTION_PHASE, 0, { "action_id": "double_leg", "phase": "telegraph" }), sim.decisions[1])
			if ai._opp.read:
				counts[which] += 1
	assert_gt(counts[1], counts[0] + 40, "blind: read more often (%d vs %d of 300)" % [counts[1], counts[0]])
	assert_lt(counts[2], counts[0] - 40, "bit on a feint: read less often (%d vs %d of 300)" % [counts[2], counts[0]])
