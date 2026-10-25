extends GutTest
## The position model (issue #34, docs/01 §4): one shared situation for both
## fighters, transitions from data/positions, and the cage spot carrying through.

const SEED: int = 20261024

var _actions: ActionLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()


func _sim() -> FightSim:
	var red := FighterState.new("Red", {}, [], 0.0)
	var blue := FighterState.new("Blue", {}, [], 0.0)
	return FightSim.new(SEED, [red, blue], _actions, 2, 10)


func test_both_fighters_share_one_situation_that_starts_standing() -> void:
	var sim: FightSim = _sim()
	assert_eq(sim.situation.position, "standing")
	assert_eq(sim.situation.phase, "standing")
	assert_eq(sim.role(0), "neutral")
	assert_eq(sim.role(1), "neutral")
	assert_eq(sim.views[0].position(), "standing")


func test_transitions_come_from_the_position_data() -> void:
	var library: PositionLibrary = PositionLibrary.load_dir()
	var t: Dictionary = library.transition("standing", "neutral", "double_leg")
	assert_eq(t.to, "full_guard")
	assert_eq(t.roles.actor, "top")
	assert_eq(t.roles.opponent, "bottom")
	assert_eq(library.transition("standing", "neutral", "jab"), {}, "a jab doesn't move the fight anywhere")


func test_a_landed_double_leg_puts_the_shooter_on_top_in_full_guard() -> void:
	var sim: FightSim = _sim()
	assert_true(sim.apply_transition(1, "double_leg"))
	assert_eq(sim.situation.position, "full_guard")
	assert_eq(sim.situation.phase, "ground")
	assert_eq(sim.role(1), "top")
	assert_eq(sim.role(0), "bottom")
	assert_eq(sim.views[0].my_role(), "bottom")
	assert_eq(sim.views[0].opponent_role(), "top")
	assert_eq(sim.band(), Octagon.BAND_CLINCH, "tied up, whatever the distance")
	var e: FightEvent = sim.events.back()
	assert_eq(e.type, FightEvent.POSITION_CHANGED)
	assert_eq(e.actor, 1)
	assert_eq(e.data.roles, ["bottom", "top"])


func test_an_action_with_no_transition_leaves_the_fight_where_it_is() -> void:
	var sim: FightSim = _sim()
	assert_false(sim.apply_transition(0, "jab"))
	assert_eq(sim.situation.position, "standing")
	assert_eq(sim.events.size(), 0)


func test_actions_are_checked_against_the_shared_position() -> void:
	var sim: FightSim = _sim()
	assert_eq(sim.why_not(0, "jab"), "")
	sim.apply_transition(0, "double_leg")
	assert_eq(sim.why_not(0, "jab"), "not possible from this position")
	assert_eq(sim.why_not(1, "jab"), "not possible from this position")


func test_a_takedown_on_the_fence_stays_on_the_fence() -> void:
	var sim: FightSim = _sim()
	sim.fighters[0].pos = Vector2(4.1, 0.0)  # Red's back on the fence.
	sim.fighters[1].pos = Vector2(2.6, 0.0)
	sim.apply_transition(1, "double_leg")
	assert_eq(sim.fighters[0].pos, Vector2(4.1, 0.0), "the one taken down stays where they stood")
	assert_almost_eq(sim.distance(), FightSim.TANGLED_GAP, 0.0001)
	assert_eq(sim.cage_proximity(0), Octagon.CAGE_PINNED)
	assert_has(sim.active_flags(0), "BACK_TO_CAGE", "ready for wall-walking (#15)")


func test_nobody_walks_around_while_tied_up() -> void:
	var sim: FightSim = _sim()
	sim.fighters[0].pos = Vector2(-1.0, 0.0)
	sim.fighters[1].pos = Vector2(1.0, 0.0)
	sim.apply_transition(1, "double_leg")
	var red: Vector2 = sim.fighters[0].pos
	var blue: Vector2 = sim.fighters[1].pos
	for n in 20:
		sim.tick()
	assert_eq(sim.fighters[0].pos, red)
	assert_eq(sim.fighters[1].pos, blue)


func test_getting_back_up_separates_the_fighters_where_they_were() -> void:
	var sim: FightSim = _sim()
	sim.fighters[0].pos = Vector2(4.1, 0.0)
	sim.fighters[1].pos = Vector2(2.6, 0.0)
	sim.apply_transition(1, "double_leg")
	assert_true(sim.apply_transition(0, "get_up"), "the bottom fighter's move from the data")
	assert_true(sim.situation.is_standing())
	assert_eq(sim.role(0), "neutral")
	assert_almost_eq(sim.distance(), Octagon.MIN_GAP, 0.0001)
	assert_gt(sim.fighters[0].pos.x, 3.0, "still near the fence where it happened")


func test_the_top_fighter_cannot_use_the_bottom_fighters_way_out() -> void:
	var sim: FightSim = _sim()
	sim.apply_transition(1, "double_leg")
	assert_false(sim.apply_transition(1, "get_up"))
	assert_eq(sim.situation.position, "full_guard")


func test_every_round_starts_standing() -> void:
	var sim: FightSim = _sim()
	sim.apply_transition(1, "double_leg")
	for n in 100:  # Round one is 10 s.
		sim.tick()
	assert_eq(sim.clock.current_round, 2)
	assert_true(sim.situation.is_standing())
	assert_eq(sim.role(1), "neutral")
