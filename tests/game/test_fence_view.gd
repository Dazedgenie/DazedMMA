extends GutTest
## The fence from the rig (D287): held on the fence he is pressed flat on it, squared to it, and the fence bows;
## working off it his hips come out and a hand posts on the wire; a drive steps them across the canvas and slams
## him in (the fence rattles); a turn takes them round each other. Presentation only.

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


## A watched clinch, red at `red_at` and blue at `blue_at` on the canvas, both idle, red with an underhook.
func _clinch(red_at: Vector2, blue_at: Vector2) -> Array:
	var sim := FightSim.new(3, _roster.make_pair("wrestler", "kicker"), _actions)
	sim.apply_transition(0, "clinch_entry")
	for f: FighterState in sim.fighters:
		f.clear_action()
	sim.fighters[0].pos = red_at
	sim.fighters[1].pos = blue_at
	sim.set_grips([0, 1])
	var view := ArenaView.new()
	add_child_autofree(view)
	view.watch(FightDriver.new(sim))
	_settle(view)
	return [sim, view]


## Blue held on the fence panel facing +X, red in on him.
func _on_the_fence() -> Array:
	return _clinch(Vector2(3.65, 0.3), Vector2(4.1, 0.3))


func _settle(view: ArenaView) -> void:
	for n in 3:
		view._process(1.0)


func _bone(figure: FighterFigure, bone: String) -> Vector3:
	var skeleton: Skeleton3D = figure.body.skeleton
	return (skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(SkinnedBody.PREFIX + bone))).origin


func test_held_on_the_fence_he_is_pressed_flat_on_it_and_it_bows() -> void:
	var setup: Array = _on_the_fence()
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	assert_eq(view.held_now(sim), 1, "blue is held on the fence")
	assert_true(view.rig_clinch(sim))
	assert_almost_eq(view.fence_bow(), ArenaView.PRESS_DEPTH, 0.005, "the fence gives under him")
	var face: float = Octagon.APOTHEM + view.fence_bow()
	var blue: FighterRig = view._clinch_rigs[1]
	for spot: String in ["back", "lower_back", "back_of_head"]:
		assert_almost_eq(blue.point(spot).x, face, 0.04, "his %s on the wire" % spot)
	var red: FighterRig = view._clinch_rigs[0]
	assert_almost_eq(red.bones.pelvis.global_position.z, blue.bones.pelvis.global_position.z, 0.08, "square to the fence")


func test_working_off_the_fence_his_hips_come_out_and_a_hand_posts_on_the_wire() -> void:
	var setup: Array = _on_the_fence()
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	var blue: FighterRig = view._clinch_rigs[1]
	var hips_flat: float = blue.bones.pelvis.global_position.x
	var f: FighterState = sim.fighters[1]
	f.action_id = "spin_off"
	f.phase = "windup"
	f.phase_ticks_left = 5
	_settle(view)
	assert_true(view.rig_clinch(sim), "a spin-off is posed from the rig")
	assert_lt(blue.bones.pelvis.global_position.x, hips_flat - 0.05, "his hips come off the fence")
	var face: float = Octagon.APOTHEM + view.fence_bow()
	var posted: bool = false
	for side: String in FighterRig.SIDES:
		posted = posted or absf(Vector3(blue.joints["wrist_" + side]).x - face) < 0.06
	assert_true(posted, "a hand posted on the wire")


func test_a_drive_steps_them_across_and_slams_him_into_the_fence() -> void:
	var setup: Array = _clinch(Vector2(2.4, 0.0), Vector2(2.8, 0.0))
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	watch_signals(view)
	sim._drive = {"by": 0, "dir": Vector2.RIGHT, "left": 3.0}
	var driver: FightDriver = view.driver
	var feet: Array[Vector3] = []
	var red: FighterFigure = view.figures[0]
	for n in 40:
		sim._drive_step()
		driver._snap()
		view._process(1.0 / 30.0)
		if n == 3 or n == 10:
			feet.append(_bone(red, "LeftFoot") - red.global_position)
			assert_lt(view._clinch_rigs[0].bones.pelvis.global_position.y, view._clinch_rigs[1].bones.pelvis.global_position.y - 0.1, "he drives in low")
	assert_gt(feet[0].distance_to(feet[1]), 0.05, "his feet step")
	assert_eq(view.held_now(sim), 1, "driven onto the fence")
	assert_signal_emitted(view, "fence_slammed", "the fence rattles")
	var strength: float = get_signal_parameters(view, "fence_slammed")[0]
	assert_gt(strength, ArenaView.DRIVE_SLAM_MIN, "a long drive slams him in hard")


func test_a_slam_bows_the_fence_further_then_it_springs_back_to_his_weight() -> void:
	var view: ArenaView = _on_the_fence()[1]
	view._slam(1.0)
	var deepest: float = 0.0
	for n in 20:
		view._process(1.0 / 60.0)
		deepest = maxf(deepest, view.fence_bow())
	assert_gt(deepest, ArenaView.PRESS_DEPTH + ArenaView.SLAM_DEPTH * 0.5, "bowed by the slam")
	_settle(view)
	assert_almost_eq(view.fence_bow(), ArenaView.PRESS_DEPTH, 0.005, "back to his weight on it")


func test_a_turn_takes_them_round_each_other_onto_the_fence() -> void:
	var setup: Array = _on_the_fence()
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	watch_signals(view)
	var red_rig: FighterRig = view._clinch_rigs[0]
	var red_before: Vector3 = red_rig.bones.pelvis.global_position
	# Blue turns him: the two swap places, as the fight does (FightSim._turn).
	var spot: Vector2 = sim.fighters[0].pos
	sim.fighters[0].pos = sim.fighters[1].pos
	sim.fighters[1].pos = spot
	view.driver._snap()
	view._on_event(FightEvent.new(sim.now, 1, FightEvent.GRAPPLE_WON, 1, {"action_id": "turn_him", "result": "turned"}))
	view._process(ArenaView.TURN_SECONDS / 2.0)
	var middle: Vector3 = red_rig.bones.pelvis.global_position
	var blue_middle: Vector3 = view._clinch_rigs[1].bones.pelvis.global_position
	var across: Vector3 = middle - blue_middle
	assert_gt(absf(across.z), absf(across.x), "half way round they stand side by side to the fence")
	assert_signal_not_emitted(view, "fence_slammed")
	view._process(ArenaView.TURN_SECONDS)
	assert_eq(view.held_now(sim), 0, "red is on the fence now")
	assert_gt(red_rig.point("back").x, red_before.x + 0.2, "red ends up with his back on it")
	assert_signal_emitted(view, "fence_slammed", "turning him slams him in")


func test_the_fence_bows_only_on_the_panel_he_is_against() -> void:
	var venue := LocalVenue.new()
	add_child_autofree(venue)
	venue.bow_fence(Vector3(Octagon.APOTHEM, 1.2, 0.3), 0.05)
	assert_almost_eq(venue.fence_bowed(), 0.05, 0.001)
	var bowed: int = 0
	for panel: Dictionary in venue.fence_panels:
		var depth: Variant = (panel.material as ShaderMaterial).get_shader_parameter("bow_depth")
		if depth != null and absf(float(depth)) > 0.0:
			bowed += 1
			assert_gt((panel.normal as Vector2).x, 0.9, "the panel he is against")
	assert_eq(bowed, 1, "one panel bows")
	venue.bow_fence(Vector3.ZERO, 0.0)
	assert_eq(venue.fence_bowed(), 0.0, "flat again")
