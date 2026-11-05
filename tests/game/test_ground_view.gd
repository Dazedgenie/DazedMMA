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

func test_half_guard_pass_and_recovery_clear_the_arms_and_legs() -> void:
	for top in 2:
		for route: Array in [["half_guard", "side_control"], ["side_control", "half_guard"], ["full_guard", "half_guard"], ["half_guard", "full_guard"], ["side_control", "full_guard"], ["side_control", "mount"]]:
			for rate: int in [30, 60]:
				var setup: Array = _ground(route[0], top)
				var sim: FightSim = setup[0]
				var view: ArenaView = setup[1]
				_put(sim, route[1], top)
				var arms := INF
				var legs := INF
				for frame in 3 * rate:
					view._process(1.0 / rate)
					legs = minf(legs, _closest_legs(view.figures[0].body, view.figures[1].body))
					for i in 2:
						var body: SkinnedBody = view.figures[i].body
						for side: String in ["Left", "Right"]:
							arms = minf(arms, FighterRig.limb_clearance(body._world_at(side + "Arm"), body._world_at(side + "ForeArm"), body._world_at(side + "Hand"), view.figures[1 - i].body.trunk()))
				var label := "%s to %s, top %d at %d Hz" % [route[0], route[1], top, rate]
				assert_gt(arms, FighterRig.TRUNK_RADIUS - 0.005, label + " arms stay outside the other torso")
				assert_gt(legs, 0.105, label + " the passer clears the hooked legs")
				assert_true(view._roll.is_empty(), label + " reaches the destination")


func test_back_take_circles_around_the_rising_defender() -> void:
	for top in 2:
		var setup: Array = _ground("mount", top)
		var sim: FightSim = setup[0]
		var view: ArenaView = setup[1]
		_put(sim, "back_control", top)
		var heads: float = INF
		var legs: float = INF
		var limbs: float = INF
		var worst: String = ""
		var trunks: float = INF
		for frame in 96:
			view._process(1.0 / 60.0)
			var a: SkinnedBody = view.figures[0].body
			var b: SkinnedBody = view.figures[1].body
			heads = minf(heads, a._world_at("Head").distance_to(b._world_at("Head")))
			legs = minf(legs, _closest_legs(a, b))
			var ta := a.trunk()
			var tb := b.trunk()
			var near := Geometry3D.get_closest_points_between_segments(ta[0], ta[1], tb[0], tb[1])
			trunks = minf(trunks, near[0].distance_to(near[1]))
			for i in 2:
				var body: SkinnedBody = view.figures[i].body
				for side: String in ["Left", "Right"]:
					for bones: Array in [["Arm", "ForeArm", "Hand"], ["UpLeg", "Leg", "Foot"]]:
						var gap: float = FighterRig.limb_clearance(body._world_at(side + bones[0]), body._world_at(side + bones[1]), body._world_at(side + bones[2]), view.figures[1 - i].body.trunk())
						if gap < limbs:
							limbs = gap
							worst = "%d %s%s frame %d" % [i, side, bones[0], frame]
		assert_gt(heads, 0.22, "heads clear as the defender sits up")
		assert_gt(legs, 0.10, "rider steps around the legs before closing the hooks")
		assert_gt(trunks, 0.21, "rider circles outside the defender")
		assert_gt(limbs, FighterRig.TRUNK_RADIUS - 0.005, "top %d, %s passes around the torso" % [top, worst])
		assert_true(view._roll.is_empty(), "back take completes")


func test_ground_hooks_wrap_the_leg_without_crossing_it() -> void:
	for where: String in ["half_guard", "back_control"]:
		for top in 2:
			var view: ArenaView = _ground(where, top)[1]
			for far: float in [-1.0, 1.0]:
				var holds: Array = [{}, {"underhook": true}, {"crossface": true}, {"collar": true}] if where == "half_guard" else [{}, {"two_on_one": true}]
				for grip: Dictionary in holds:
					var pair: Dictionary = GroundPair.build(where, grip, false, far).pair
					FighterRig.pose_pair(view._clinch_rigs[top], view._clinch_rigs[1 - top], pair, view._ground_frame)
					for i in 2:
						view.figures[i].body.follow(view._clinch_rigs[i])
					view._settle_bodies(1.0)
					var rider: SkinnedBody = view.figures[top].body
					var defender: SkinnedBody = view.figures[1 - top].body
					var label := "%s top %d side %.0f grip %s" % [where, top, far, grip]
					assert_gt(_closest_legs(rider, defender), 0.115, label + " opposing legs stay apart")
					for side: String in ["Left", "Right"]:
						var foot: Vector3
						var start: Vector3
						var end: Vector3
						if where == "half_guard":
							var trapped := "Left" if far > 0.0 else "Right"
							foot = defender._world_at(side + "Foot")
							start = rider._world_at(trapped + "Leg")
							end = rider._world_at(trapped + "Foot")
						else:
							foot = rider._world_at(side + "Foot")
							start = defender._world_at(side + "UpLeg")
							end = defender._world_at(side + "Leg")
						assert_lt(foot.distance_to(Geometry3D.get_closest_point_to_segment(foot, start, end)), 0.22, label + " hook stays on its leg")


func _closest_legs(a: SkinnedBody, b: SkinnedBody) -> float:
	var gap := INF
	for left: String in ["Left", "Right"]:
		for right: String in ["Left", "Right"]:
			for bones: Array in [["UpLeg", "Leg"], ["Leg", "Foot"]]:
				var other: Array[Vector3] = [b._world_at(right + bones[0]), b._world_at(right + bones[1])]
				gap = minf(gap, FighterRig.limb_clearance(a._world_at(left + "UpLeg"), a._world_at(left + "Leg"), a._world_at(left + "Foot"), other))
	return gap


func test_mount_keeps_the_defenders_knees_between_the_riders_knees() -> void:
	for top in 2:
		var view: ArenaView = _ground("mount", top)[1]
		var body: SkinnedBody = view.figures[1 - top].body
		var left := body._world_at("LeftUpLeg")
		var right := body._world_at("RightUpLeg")
		var across := right.direction_to(left)
		assert_gt((body._world_at("LeftLeg") - body._world_at("RightLeg")).dot(across), 0.10, "knees stay on their respective sides")
		assert_gt(_closest_legs(view.figures[top].body, body), 0.115, "the rider straddles the defender's knees")

func test_an_interrupted_guard_recovery_reverses_from_the_current_step() -> void:
	var setup: Array = _ground("side_control")
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	_put(sim, "full_guard", 0)
	_frames(view, 34, 1.0 / 60.0)
	var before := float(view._roll.x)
	_put(sim, "side_control", 0)
	view._process(1.0 / 60.0)
	assert_almost_eq(float(view._roll.start_x), before, 0.0001, "the return starts where the recovery reached")
	var gap := INF
	for frame in 180:
		view._process(1.0 / 60.0)
		gap = minf(gap, _closest_legs(view.figures[0].body, view.figures[1].body))
	assert_gt(gap, 0.105, "the knee clears the legs on the way back")
	assert_true(view._roll.is_empty(), "returned to side control")
	_put(sim, "full_guard", 0)
	_frames(view, 12, 1.0 / 60.0)
	_doing(sim, 0, "ground_punch", "active", 0.5)
	view._process(1.0 / 60.0)
	assert_true(view._roll.is_empty(), "a new ground strike gets its own pose immediately")
