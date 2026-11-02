extends GutTest
## The ground positions from the rig on the fight screen (D289): each position posed by GroundPair where
## today's figures lay it out, the grips the sim holds, ground and pound thrown from the pose, a sweep rolling
## them over; standing up, getting up and the scramble are posed on their own (D368). Presentation only.

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


## A watched fight with red on top of blue in `where`, in the middle of the cage: [sim, view].
func _ground(where: String, top: int = 0) -> Array:
	var sim := FightSim.new(3, _roster.make_pair("wrestler", "bjj"), _actions)
	_put(sim, where, top)
	sim.fighters[0].pos = Vector2(0.3, 0.6)
	sim.fighters[1].pos = Vector2(-0.1, 0.4)
	var view := ArenaView.new()
	add_child_autofree(view)
	view.watch(FightDriver.new(sim))
	_frames(view, 3, 1.0)
	return [sim, view]


func _put(sim: FightSim, where: String, top: int) -> void:
	var roles: Array[String] = [PositionLibrary.TOP, PositionLibrary.BOTTOM]
	if top == 1:
		roles = [PositionLibrary.BOTTOM, PositionLibrary.TOP]
	sim.situation.set_to(sim.positions.get_position(where), roles)
	for f: FighterState in sim.fighters:
		f.clear_action()


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


func test_every_ground_position_is_posed_from_the_rig_where_today_s_figures_lay_it_out() -> void:
	for where: String in GroundPair.POSITIONS:
		var setup: Array = _ground(where)
		var sim: FightSim = setup[0]
		var view: ArenaView = setup[1]
		assert_true(view.rig_ground(sim), where)
		var built: Dictionary = GroundPair.build(where, ArenaView.ground_grips_now(sim, 0), false, view._ground_far)
		var root: Array = built.pair.a.root
		var want: Vector3 = view._ground_frame * Vector3(float(root[0]), float(root[1]), float(root[2]))
		assert_lt(view._clinch_rigs[0].bones.pelvis.global_position.distance_to(want), 0.01, "%s: the top man's hips" % where)
		var laid: Array[Dictionary] = ArenaView.lay_out(where, 0, [view.driver.shown_pos(0), view.driver.shown_pos(1)])
		var hips: Vector3 = view._ground_frame.origin
		assert_lt(Vector2(hips.x, hips.z).distance_to(laid[1].at), 0.01, "%s: the man underneath where today's figures put him" % where)


func test_in_a_side_position_the_top_man_is_on_the_far_side_from_the_camera() -> void:
	for where: String in GroundPair.SIDE_POSITIONS:
		var setup: Array = _ground(where)
		var view: ArenaView = setup[1]
		var top: Vector3 = view._clinch_rigs[0].bones.pelvis.global_position
		var bottom: Vector3 = view._clinch_rigs[1].bones.pelvis.global_position
		var away := -Vector3(ArenaView.CAMERA_FROM.x, 0.0, ArenaView.CAMERA_FROM.z).normalized()
		assert_gt((top - bottom).dot(away), 0.05, where)


func test_the_pose_does_not_swing_round_when_the_sim_nudges_their_spots() -> void:
	var setup: Array = _ground("side_control")
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	var frame: Transform3D = view._ground_frame
	sim.fighters[0].pos = Vector2(-0.6, 0.2)  # Now on the other side of him.
	view.driver._snap()
	_frames(view, 5)
	assert_true(view._ground_frame.is_equal_approx(frame), "the same frame while the position lasts")


func test_the_grips_held_on_the_ground_show_on_the_bodies() -> void:
	var setup: Array = _ground("full_guard")
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	sim.set_ground_grips(2, false)
	_frames(view, 30)
	var red: FighterRig = view._clinch_rigs[0]
	var blue: FighterRig = view._clinch_rigs[1]
	assert_lt(blue.joints.wrist_l.distance_to(red.joints.wrist_r), 0.06, "his wrists held")
	sim.set_ground_grips(0, true)
	_frames(view, 30)
	assert_lt(blue.joints.wrist_l.distance_to(red.point("nape")), 0.1, "the collar tie")
	assert_eq(ArenaView.ground_grips_now(sim, 0).collar, true)


func test_a_ground_punch_is_thrown_from_the_pose_and_the_bomb_sits_him_up_first() -> void:
	var setup: Array = _ground("mount")
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	var red: FighterRig = view._clinch_rigs[0]
	var blue: FighterRig = view._clinch_rigs[1]
	var rear: String = "wrist_" + view.figures[0].arm_letter(1)
	var resting: float = red.joints[rear].distance_to(blue.point("head"))
	_doing(sim, 0, "ground_punch", "active", 0.6)
	_frames(view, 1)
	assert_lt(red.joints[rear].distance_to(blue.point("head")), 0.24, "it lands on his head")
	assert_lt(red.joints[rear].distance_to(blue.point("head")), resting, "closer than his hand was")
	var sat: float = red.point("head").y
	_doing(sim, 0, "posture_bomb", "windup", 0.5)
	_frames(view, 20)
	assert_gt(red.point("head").y, sat + 0.05, "the bomb: up out of it first")


func test_a_sweep_rolls_them_over_and_the_sweeper_ends_up_on_top() -> void:
	var setup: Array = _ground("full_guard")
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	view._on_event(FightEvent.new(sim.now, 1, FightEvent.GRAPPLE_WON, 1, {"action_id": "sweep", "result": PositionLibrary.SUCCESS}))
	assert_false(view._roll.is_empty(), "a roll starts")
	_put(sim, "full_guard", 1)
	view.driver._snap()
	_frames(view, 8)
	assert_true(view._roll.has("path"), "rolling")
	_frames(view, 30)
	assert_true(view._roll.is_empty(), "over")
	assert_gt(view._clinch_rigs[1].point("chest").y, view._clinch_rigs[0].point("chest").y, "blue on top")


func test_standing_up_and_the_scramble_are_not_posed_as_a_ground_position() -> void:
	var setup: Array = _ground("half_guard")
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	_doing(sim, 0, "stand_up", "windup", 0.5)
	assert_false(view.rig_ground(sim), "standing up is a move of its own (D368)")
	_doing(sim, 0, "stand_up", "recovery", 0.5)
	assert_true(view.rig_ground(sim), "stopped: back in the position")
	sim.fighters[0].clear_action()
	assert_true(view.rig_ground(sim))
	_put(sim, "scramble", 0)
	assert_false(view.rig_ground(sim), "the scramble is posed on its own (D368)")
