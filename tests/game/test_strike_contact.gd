extends GutTest
## Strikes that connect (D281): human spacing, stepping in, aiming at the man, the outcome showing,
## hit reactions, foot pivots and the near fence. All presentation; the sim is never changed.

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


func _sim() -> FightSim:
	return FightSim.new(3, _roster.make_pair("boxer", "kicker"), _actions)


## Two figures facing each other `gap` metres apart along x, red (0) throwing `action` in `phase`.
func _pair(sim: FightSim, gap: float) -> Array[FighterFigure]:
	var figures: Array[FighterFigure] = [FighterFigure.new(Color.RED, false, 0), FighterFigure.new(Color.BLUE, false, 1)]
	for figure in figures:
		add_child_autofree(figure)
	figures[0].opponent = figures[1]
	figures[1].opponent = figures[0]
	_pose(sim, figures, gap)
	return figures


func _pose(sim: FightSim, figures: Array[FighterFigure], gap: float) -> void:
	for frame in 3:
		figures[1].show_state(sim, 1, Vector2(gap, 0), Vector2.ZERO, 1.0)
		figures[0].show_state(sim, 0, Vector2.ZERO, Vector2(gap, 0), 1.0)


func _throw(sim: FightSim, action: String, phase: String = "active") -> void:
	var f: FighterState = sim.fighters[0]
	f.action_id = action
	f.phase = phase
	f.phase_ticks_left = 1


func test_the_view_draws_standing_fighters_at_a_persons_reach_but_keeps_a_man_on_the_fence_there() -> void:
	assert_almost_eq(ArenaView.drawn_gap(0.8), 0.8, 0.001, "close in, a gap is drawn as it is")
	assert_lt(ArenaView.drawn_gap(1.85), 1.4, "mid range is drawn at a person's reach")
	assert_gt(ArenaView.drawn_gap(2.6), ArenaView.drawn_gap(1.85), "further is still further")
	var middle: Array[Vector2] = [Vector2(-1.0, 0.0), Vector2(1.0, 0.0)]
	var drawn: Array[Vector2] = ArenaView.standing_spots(middle)
	assert_almost_eq(drawn[0].distance_to(drawn[1]), ArenaView.drawn_gap(2.0), 0.001)
	assert_almost_eq(drawn[0].x, -drawn[1].x, 0.001, "in open space both come in")
	var fence: Array[Vector2] = [Vector2(Octagon.APOTHEM - Octagon.BODY_MARGIN, 0.0), Vector2(1.7, 0.0)]
	drawn = ArenaView.standing_spots(fence)
	assert_almost_eq(drawn[0].x, fence[0].x, 0.001, "the man on the fence stays on it")
	assert_lt(drawn[1].x, fence[0].x, "the other man comes to him")


func test_a_strike_steps_in_far_enough_to_land_and_falls_short_out_of_range() -> void:
	var sim: FightSim = _sim()
	sim.fighters[0].pos = Vector2(-0.9, 0)
	sim.fighters[1].pos = Vector2(0.9, 0)  # Mid range in the sim.
	var gap: float = ArenaView.drawn_gap(1.8)
	_throw(sim, "cross")
	var lunge: float = ArenaView.lunge_for(sim, 0, gap)
	assert_almost_eq(gap - lunge, float(FighterFigure.AIMS.cross.contact), 0.001, "he steps in to the cross's contact gap")
	sim.fighters[0].phase = "recovery"
	sim.fighters[0].phase_ticks_left = 0
	assert_almost_eq(ArenaView.lunge_for(sim, 0, gap), 0.0, 0.001, "and back out by the end of the recovery")
	sim.fighters[0].pos = Vector2(-1.6, 0)
	sim.fighters[1].pos = Vector2(1.6, 0)  # Out of range for a cross (long range).
	_throw(sim, "cross")
	gap = ArenaView.drawn_gap(3.2)
	assert_gt(gap - ArenaView.lunge_for(sim, 0, gap), float(FighterFigure.AIMS.cross.contact) + 0.2, "out of range it falls short")


func test_two_strikers_stepping_in_never_walk_through_each_other() -> void:
	var sim: FightSim = _sim()
	sim.fighters[0].pos = Vector2(-0.9, 0)
	sim.fighters[1].pos = Vector2(0.9, 0)
	_throw(sim, "cross")
	sim.fighters[1].action_id = "body_kick"
	sim.fighters[1].phase = "active"
	sim.fighters[1].phase_ticks_left = 1
	var spots: Array[Vector2] = [Vector2(-0.65, 0), Vector2(0.65, 0)]
	var shown: Array[Vector2] = ArenaView.strike_spots(sim, spots, [0.0, 0.0])
	assert_gte(shown[0].distance_to(shown[1]), ArenaView.LUNGE_CLOSEST - 0.001)
	assert_lt(shown[0].distance_to(shown[1]), 1.3, "but they do step in")


func test_a_landed_cross_touches_his_head_and_a_missed_one_goes_past_it() -> void:
	var sim: FightSim = _sim()
	var figures: Array[FighterFigure] = _pair(sim, 1.0)
	_throw(sim, "cross")
	figures[0].show_outcome("cross", "landed")
	_pose(sim, figures, 1.0)
	var head: Vector3 = figures[1]._head.global_position
	var glove: Vector3 = figures[0]._gloves[1].global_position
	assert_lt(glove.distance_to(head), 0.24, "the glove meets his face")
	assert_gt(glove.distance_to(head), 0.08, "without passing into his head")
	figures[0].show_outcome("cross", "missed")
	_pose(sim, figures, 1.0)
	# Past the side of his head (D363: his weight carries him in behind it, so it passes closer than it did).
	var past: Vector3 = figures[0]._gloves[1].global_position - figures[1]._head.global_position
	assert_gt(absf(past.z), 0.15, "a miss goes past him")


func test_a_landed_body_kick_reaches_his_ribs() -> void:
	var sim: FightSim = _sim()
	var figures: Array[FighterFigure] = _pair(sim, float(FighterFigure.AIMS.body_kick.contact))
	_throw(sim, "body_kick")
	figures[0].show_outcome("body_kick", "landed")
	_pose(sim, figures, float(FighterFigure.AIMS.body_kick.contact))
	var ribs: Vector3 = figures[1].strike_point("body")
	var foot: Vector3 = figures[0]._feet[1].global_position
	assert_lt(foot.distance_to(ribs), 0.4, "the kicking foot gets to him")
	assert_gt(foot.y, 0.7, "at rib height, not a knee lift")


func test_arms_keep_their_length_in_guard_strikes_and_the_clinch() -> void:
	var sim: FightSim = _sim()
	var figures: Array[FighterFigure] = _pair(sim, 1.6)
	for setup: Callable in [
		func() -> void: sim.fighters[0].clear_action(),
		func() -> void: _throw(sim, "jab"),
		func() -> void: _throw(sim, "cross"),
		func() -> void: _throw(sim, "hook"),
		func() -> void: sim.apply_transition(0, "clinch_entry"),
	]:
		setup.call()
		_pose(sim, figures, 1.6)
		for side in 2:
			var upper: MeshInstance3D = figures[0]._upper_arms[side]
			var fore: MeshInstance3D = figures[0]._forearms[side]
			assert_almost_eq(upper.basis.get_scale().y, FighterFigure.UPPER_ARM, 0.002, "the upper arm never stretches")
			assert_almost_eq(fore.basis.get_scale().y, FighterFigure.FOREARM, 0.002, "nor the forearm")


func test_a_clean_hit_snaps_his_head_back_and_a_blocked_one_moves_his_guard() -> void:
	var sim: FightSim = _sim()
	var figures: Array[FighterFigure] = _pair(sim, 1.2)
	var still: Vector3 = figures[1]._head.rotation
	figures[1].show_hit("head", 12.0, false, 1.0)
	figures[1].show_state(sim, 1, Vector2(1.2, 0), Vector2.ZERO, 0.0, 0.0)
	assert_lt(figures[1]._head.rotation.x, still.x - 0.15, "his head snaps back")
	assert_gt(figures[1].knock, 0.05, "and he's knocked back a little")
	figures[1].show_state(sim, 1, Vector2(1.2, 0), Vector2.ZERO, 1.0, 1.0)
	assert_almost_eq(figures[1]._head.rotation.x, still.x, 0.001, "then it's over in a moment")
	var guard: Vector3 = figures[1]._gloves[0].global_position
	figures[1].show_hit("head", 12.0, true)
	figures[1].show_state(sim, 1, Vector2(1.2, 0), Vector2.ZERO, 0.0, 0.0)
	assert_gt(figures[1]._gloves[0].global_position.distance_to(guard), 0.04, "a blocked shot knocks his gloves back")
	assert_gt(figures[1]._head.rotation.x, still.x - 0.15, "but not his head")


func test_the_back_foot_turns_on_its_ball_without_sliding() -> void:
	var sim: FightSim = _sim()
	var figures: Array[FighterFigure] = _pair(sim, 1.0)
	var foot: Node3D = figures[0]._feet[1]
	var ball := func() -> Vector3: return foot.global_position + foot.global_basis * Vector3(0, 0, -FighterFigure.FOOT_BALL)
	var before: Vector3 = ball.call()
	var flat: Basis = foot.global_basis
	_throw(sim, "cross")
	figures[0].show_outcome("cross", "landed")
	_pose(sim, figures, 1.0)
	assert_lt(Vector3(ball.call()).distance_to(before), 0.01, "the ball of the foot stays put")
	assert_gt(foot.global_basis.z.angle_to(flat.z), 0.15, "while the foot turns and the heel comes up")


func test_the_near_fence_shows_only_while_someone_is_against_it() -> void:
	var venue := LocalVenue.new()
	add_child_autofree(venue)
	assert_false(venue.near_panels.is_empty(), "the camera-side panels exist")
	var normal: Vector2 = venue.near_panels[0].normal
	venue.show_near_fence([Vector2.ZERO, Vector2(0.5, 0)], 1.0)
	for panel: Dictionary in venue.near_panels:
		assert_false((panel.node as Node3D).visible, "open space: the near side stays cut away")
	var on_it: Vector2 = normal * (Octagon.APOTHEM - Octagon.BODY_MARGIN)
	venue.show_near_fence([on_it, Vector2.ZERO], 1.0)
	assert_true((venue.near_panels[0].node as Node3D).visible, "against it: that stretch of fence shows")
	var shown: int = venue.near_panels.filter(func(p: Dictionary) -> bool: return (p.node as Node3D).visible).size()
	assert_lt(shown, 3, "only the stretch he's against")
