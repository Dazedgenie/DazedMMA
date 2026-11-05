extends GutTest
## Clinch takedowns from the rig on the fight screen (D288): a takedown in the clinch starts falling during the
## attempt, lands in the ground position it ends in (where today's figures carry on) with a thud, goes back to
## the clinch when it is stuffed, puts the shooter on his knees when he is sprawled on, and lands both on their
## knees when it half works. Presentation only.

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


## A watched clinch in the middle of the cage, red with an underhook: [sim, view].
func _clinch() -> Array:
	var sim := FightSim.new(3, _roster.make_pair("wrestler", "judoka"), _actions)
	sim.apply_transition(0, "clinch_entry")
	for f: FighterState in sim.fighters:
		f.clear_action()
	sim.fighters[0].pos = Vector2(0.3, 0.6)
	sim.fighters[1].pos = Vector2(-0.1, 0.4)
	sim.set_grips([0, 1])
	var view := ArenaView.new()
	add_child_autofree(view)
	view.watch(FightDriver.new(sim))
	_frames(view, 3, 1.0)
	return [sim, view]


func _frames(view: ArenaView, count: int, delta: float = 1.0 / 30.0) -> void:
	for n in count:
		view._process(delta)


## Fighter `i` is `phase` of `action`, `share` (0–1) of the way through it.
func _doing(sim: FightSim, i: int, action: String, phase: String, share: float) -> void:
	var f: FighterState = sim.fighters[i]
	f.action_id = action
	f.phase = phase
	var total: int = sim.phase_ticks(f, action, phase)
	f.phase_ticks_left = maxi(1, int(round(total * (1.0 - share))))


func _won(view: ArenaView, sim: FightSim, i: int, action: String, result: String) -> void:
	view._on_event(FightEvent.new(sim.now, i, FightEvent.GRAPPLE_WON, i, {"action_id": action, "result": result}))
	sim.apply_transition(i, action, result)
	view.driver._snap()


func _stopped(view: ArenaView, sim: FightSim, i: int, action: String, reason: String) -> void:
	view._on_event(FightEvent.new(sim.now, i, FightEvent.GRAPPLE_STOPPED, i, {"action_id": action, "reason": reason}))
	sim.fighters[i].phase = "recovery"
	sim.fighters[i].phase_ticks_left = 10


func _pelvis(view: ArenaView, i: int) -> Vector3:
	return view._clinch_rigs[i].bones.pelvis.global_position


func test_a_double_leg_starts_falling_during_the_attempt_and_lands_in_his_guard_with_a_thud() -> void:
	var setup: Array = _clinch()
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	watch_signals(view)
	var standing: float = _pelvis(view, 1).y
	_doing(sim, 0, "double_leg", "windup", 0.5)
	_frames(view, 1)
	assert_false(view._takedown.is_empty(), "the shot is posed from the rig")
	assert_lt(_pelvis(view, 0).y, standing - 0.15, "he changes levels")
	_doing(sim, 0, "double_leg", "active", 0.9)
	_frames(view, 1)
	assert_gt(float(view._takedown.x), 1.5, "past the entry: he is going over before the roll")
	assert_lt(_pelvis(view, 1).y, standing - 0.05, "blue is tipping back")
	_won(view, sim, 0, "double_leg", PositionLibrary.SUCCESS)
	assert_signal_not_emitted(view, "takedown_landed", "still in the air")
	_frames(view, 30)
	assert_signal_emitted_with_parameters(view, "takedown_landed", [TakedownPair.TIMING.double_leg.thud])
	assert_true(view._takedown.is_empty(), "done: today's figures carry on")
	assert_lt(_pelvis(view, 1).y, 0.35, "blue on his back")


func test_the_landing_lines_up_with_the_ground_position_today_s_figures_carry_on_in() -> void:
	var setup: Array = _clinch()
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	_doing(sim, 0, "double_leg", "active", 0.5)
	_frames(view, 1)
	_won(view, sim, 0, "double_leg", PositionLibrary.SUCCESS)
	var landed: Array = []
	for n in 30:
		_frames(view, 1)
		if view._takedown.is_empty() and landed.is_empty():
			landed = [_pelvis(view, 1), view._clinch_rigs[1].point("head")]
	_frames(view, 60)  # Today's figures settle where they are drawn.
	var hips: Vector3 = landed[0]
	var figure: FighterFigure = view.figures[1]
	assert_almost_eq(Vector2(figure.global_position.x, figure.global_position.z).distance_to(Vector2(hips.x, hips.z)), 0.0, 0.2,
		"blue is drawn where he landed")
	var feet: Vector3 = hips - Vector3(landed[1])
	var facing: Vector3 = -figure.global_basis.z
	assert_gt(Vector2(feet.x, feet.z).normalized().dot(Vector2(facing.x, facing.z).normalized()), 0.8,
		"lying the way today's figure lies")


func test_a_stuffed_shot_goes_back_to_the_clinch() -> void:
	var setup: Array = _clinch()
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	_doing(sim, 0, "double_leg", "active", 0.4)
	_frames(view, 1)
	_stopped(view, sim, 0, "double_leg", "defended")
	assert_true(view._takedown.is_empty())
	_frames(view, 1)
	assert_true(view.rig_clinch(sim), "the clinch from the rig again while he gets over it")
	assert_false(view._clinch_last.is_empty())


func test_a_sprawl_puts_the_shooter_on_his_knees_under_it_until_his_move_is_over() -> void:
	var setup: Array = _clinch()
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	_doing(sim, 0, "double_leg", "active", 0.3)
	_frames(view, 1)
	_stopped(view, sim, 0, "double_leg", "sprawled on")
	_frames(view, 15)
	assert_eq(String(view._takedown.state), "sprawl")
	assert_lt(_pelvis(view, 0).y, 0.5, "red down on his knees")
	assert_gt(_pelvis(view, 1).y, _pelvis(view, 0).y, "blue on top of him")
	sim.fighters[0].clear_action()
	_frames(view, 1)
	assert_true(view._takedown.is_empty(), "back up when his move is over")


func test_the_hip_throw_goes_feet_over_the_top_and_lands_him_beyond_the_thrower() -> void:
	var setup: Array = _clinch()
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	watch_signals(view)
	var red_from: Vector3 = _pelvis(view, 0)
	var blue_from: Vector3 = _pelvis(view, 1)
	_doing(sim, 0, "hip_throw", "active", 0.95)
	_frames(view, 1)
	_won(view, sim, 0, "hip_throw", PositionLibrary.SUCCESS)
	var over: bool = false
	for n in 30:
		_frames(view, 1)
		var rig: FighterRig = view._clinch_rigs[1]
		over = over or rig.joints.ankle_l.y > rig.point("head").y + 1.0
	assert_true(over, "his feet go over the top")
	assert_signal_emitted_with_parameters(view, "takedown_landed", [TakedownPair.TIMING.hip_throw.thud])
	assert_gt(TakedownPair.TIMING.hip_throw.thud, TakedownPair.TIMING.double_leg.thud, "a throw lands harder")
	var way: Vector3 = red_from - blue_from
	assert_gt((_pelvis(view, 1) - red_from).dot(way), 0.0, "blue lands on the far side of red")


func test_a_half_worked_takedown_lands_them_both_on_their_knees() -> void:
	var setup: Array = _clinch()
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	watch_signals(view)
	_doing(sim, 1, "outside_trip", "active", 0.5)
	_frames(view, 1)
	_won(view, sim, 1, "outside_trip", PositionLibrary.PARTIAL)
	_frames(view, 30)
	assert_signal_emitted_with_parameters(view, "takedown_landed", [TakedownPair.SCRAMBLE_THUD])
	for i in 2:
		assert_between(_pelvis(view, i).y, 0.35, 0.6, "on his knees")


func test_the_guard_pull_puts_the_puller_underneath() -> void:
	var setup: Array = _clinch()
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	_doing(sim, 1, "guard_pull", "active", 0.5)
	_frames(view, 1)
	_won(view, sim, 1, "guard_pull", PositionLibrary.SUCCESS)
	_frames(view, 30)
	assert_lt(_pelvis(view, 1).y, 0.35, "blue on his back")
	assert_gt(_pelvis(view, 0).y, 0.4, "red kneeling in his guard")


func test_turns_go_the_short_way_round_along_every_path() -> void:
	var start: Array = [ClinchPair.build([0, 1], ["l", "r"], -1, -1).pair, Transform3D.IDENTITY]
	for action: String in TakedownPair.MOVES:
		for turn_deg: float in [0.0, 60.0, 135.0, 180.0, -100.0]:
			var lying := Basis(Vector3.UP, deg_to_rad(turn_deg))
			var path: Array = TakedownPair.path(action, start, lying)
			for k in range(1, path.size()):
				for man: String in ["a", "b"]:
					var was: float = float(path[k - 1][0][man].get("turn", 0.0)) + TakedownPair._yaw(path[k - 1][1])
					var now: float = float(path[k][0][man].get("turn", 0.0)) + TakedownPair._yaw(path[k][1])
					assert_lte(absf(now - was), 180.01, "%s, lying %d: %s turns the long way into key %d" % [action, turn_deg, man, k])


func test_taken_down_off_the_fence_he_lands_inside_the_cage() -> void:
	var setup: Array = _clinch()
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	sim.fighters[0].pos = Vector2(3.65, 0.3)
	sim.fighters[1].pos = Vector2(4.1, 0.3)  # Blue held on the fence panel facing +X.
	view.driver._snap()
	_frames(view, 3, 1.0)
	assert_eq(view.held_now(sim), 1)
	_doing(sim, 0, "double_leg", "active", 0.5)
	_frames(view, 1)
	_won(view, sim, 0, "double_leg", PositionLibrary.SUCCESS)
	for n in 30:
		_frames(view, 1)
		for i in 2:
			for spot: String in ["head", "back_of_head", "lower_back"]:
				assert_lt(view._clinch_rigs[i].point(spot).x, Octagon.APOTHEM, "frame %d: %s's %s through the fence" % [n, "red" if i == 0 else "blue", spot])

func test_either_corner_starts_throws_from_the_existing_clinch_pose() -> void:
	for by in 2:
		for owner in 2:
			var setup := _clinch()
			var sim: FightSim = setup[0]
			var view: ArenaView = setup[1]
			sim.set_grips([owner, owner])
			_frames(view, 30)
			var hips: Array[Vector3] = [_pelvis(view, 0), _pelvis(view, 1)]
			var heads: Array[Vector3] = [view._clinch_rigs[0].point("head"), view._clinch_rigs[1].point("head")]
			_doing(sim, by, "double_leg", "telegraph", 0.0)
			_frames(view, 1)
			for i in 2:
				assert_lt(hips[i].distance_to(_pelvis(view, i)), 0.01, "first key preserves the fighter's hips")
				assert_lt(heads[i].distance_to(view._clinch_rigs[i].point("head")), 0.01, "first key preserves the fighter's facing")

func test_hip_throw_and_guard_pull_keep_the_fighters_separate_through_landing() -> void:
	for action: String in ["hip_throw", "guard_pull"]:
		for who in 2:
			for lead: float in [-1.0, 1.0]:
				_check_landing(action, who, lead)


func _check_landing(action: String, who: int, lead: float) -> void:
	var setup := _clinch()
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	view.figures[who].lead = lead
	view.figures[1 - who].lead = -lead
	view.driver.normal_rate = 1.0
	_frames(view, 30)
	var heads: float = INF
	var trunks: float = INF
	var limbs: float = INF
	var largest_step: float = 0.0
	var last_tip := Vector3.INF
	for phase: String in ["telegraph", "windup", "active", "landing"]:
		var ticks := 12 if phase == "landing" else sim.phase_ticks(sim.fighters[who], action, phase)
		if phase == "landing":
			_won(view, sim, who, action, PositionLibrary.SUCCESS)
			sim.fighters[who].phase = "recovery"
		for tick in ticks:
			sim.now += 1
			if phase != "landing":
				_doing(sim, who, action, phase, 0.0)
				sim.fighters[who].phase_ticks_left = ticks - tick
			for frame in 6:
				view.driver._budget = float(frame) / 6.0
				view._process(1.0 / 60.0)
				var a: SkinnedBody = view.figures[who].body
				var b: SkinnedBody = view.figures[1 - who].body
				var tip := a._world_at("RightHand")
				if last_tip.is_finite():
					largest_step = maxf(largest_step, tip.distance_to(last_tip))
				last_tip = tip
				heads = minf(heads, a._world_at("Head").distance_to(b._world_at("Head")))
				var ta := a.trunk()
				var tb := b.trunk()
				var near := Geometry3D.get_closest_points_between_segments(ta[0], ta[1], tb[0], tb[1])
				trunks = minf(trunks, near[0].distance_to(near[1]))
				for i in 2:
					var body := view.figures[i].body
					for limb: Array in SkinnedBody.LIMBS:
						limbs = minf(limbs, FighterRig.limb_clearance(body._world_at(limb[0]), body._world_at(limb[1]), body._world_at(limb[2]), view.figures[1 - i].body.trunk()))
	var label := "%s corner %d lead %s" % [action, who, lead]
	assert_gt(heads, 0.215, label + " keeps the heads separate")
	assert_gt(trunks, 0.20, label + " keeps the trunks separate")
	assert_gt(limbs, FighterRig.TRUNK_RADIUS - 0.005, label + " routes limbs around the torso")
	assert_lt(largest_step, 0.25, label + " has continuous hand travel")
