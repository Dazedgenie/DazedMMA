extends GutTest
## The submissions from the rig on the fight screen (D366): a hold posed by SubmissionPair in the frame of where it
## was locked from, tightening with the danger meter, the standing guillotine sitting back into the guard once
## deep, the leg locks side on to the camera, letting go on an escape, and the tap before the result.
## Presentation only.

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


## A watched fight, red and blue in `where` (red on top when `top` is 0), in the middle of the cage: [sim, view].
func _watched(where: String, top: int = 0) -> Array:
	var sim := FightSim.new(3, _roster.make_pair("wrestler", "bjj"), _actions)
	if where != "standing":
		var roles: Array[String] = [PositionLibrary.TOP, PositionLibrary.BOTTOM]
		if top == 1:
			roles = [PositionLibrary.BOTTOM, PositionLibrary.TOP]
		sim.situation.set_to(sim.positions.get_position(where), roles)
	for f: FighterState in sim.fighters:
		f.clear_action()
	sim.fighters[0].pos = Vector2(0.3, 0.6)
	sim.fighters[1].pos = Vector2(-0.1, 0.4)
	var view := ArenaView.new()
	add_child_autofree(view)
	view.watch(FightDriver.new(sim))
	_frames(view, 3, 1.0)
	return [sim, view]


func _frames(view: ArenaView, count: int, delta: float = 1.0 / 30.0) -> void:
	for n in count:
		view._process(delta)


func _lock(sim: FightSim, i: int, action: String) -> void:
	assert_true(sim._lock_in(i, sim.actions.get_action(action)), "%s locked in" % action)


func test_a_hold_is_posed_from_the_rig_where_it_was_locked_from() -> void:
	var setup: Array = _watched("mount")
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	var mount: Transform3D = view._ground_frame
	_lock(sim, 0, "armbar")
	_frames(view, 2)
	assert_true(view.shows_hold())
	assert_eq(view._hold_pose.built.tap, "armbar_mount", "the armbar from mount, not from the guard")
	var frame: Transform3D = view._hold_pose.frame
	assert_lt(frame.origin.distance_to(mount.origin), 0.05, "drawn where the mount was")
	assert_gt(frame.basis.z.dot(mount.basis.z), 0.99, "facing the same way")
	_frames(view, 30)
	var at: Array = SubmissionPair.at_danger(view._hold_pose.built, float(view._hold_pose.danger))
	var root: Array = at[0].b.root
	var want: Vector3 = frame * Vector3(float(root[0]), float(root[1]), float(root[2]))
	assert_lt(view._clinch_rigs[1].bones.pelvis.global_position.distance_to(want), 0.03, "the man in it posed by the hold")


func test_the_danger_slides_the_hold_tighter_rather_than_jumping() -> void:
	var setup: Array = _watched("full_guard", 1)
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	_lock(sim, 0, "triangle")
	_frames(view, 2)
	var start: float = float(view._hold_pose.danger)
	sim._hold.danger = 95.0
	_frames(view, 1)
	assert_between(float(view._hold_pose.danger), start + 1.0, 94.0, "on its way, not there in a frame")
	_frames(view, 60)
	assert_almost_eq(float(view._hold_pose.danger), 95.0, 1.0, "there within two seconds")


func test_a_standing_guillotine_sits_back_into_the_guard_once_deep_and_stays_down() -> void:
	var setup: Array = _watched("standing")
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	_lock(sim, 0, "guillotine")
	sim._hold.danger = 30.0
	_frames(view, 30)
	assert_eq(view._hold_pose.built.frame, "standing")
	assert_false(bool(view._hold_pose.pulled), "on his feet while it's shallow")
	assert_gt(view._clinch_rigs[0].point("head").y, 1.2, "standing")
	sim._hold.danger = SubmissionPair.GUARD_PULL_AT + 10.0
	_frames(view, 60)
	assert_true(bool(view._hold_pose.pulled), "deep: he pulls guard")
	assert_eq(view._hold_pose.built.tap, "guillotine_guard")
	sim._hold.danger = 20.0
	_frames(view, 60)
	assert_true(bool(view._hold_pose.pulled), "and stays down when it loosens")


func test_a_leg_lock_is_drawn_side_on_to_the_camera() -> void:
	var setup: Array = _watched("full_guard", 1)
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	_lock(sim, 0, "ankle_lock")
	_frames(view, 2)
	assert_eq(view._hold_pose.built.frame, "legs")
	var camera := Vector3(ArenaView.CAMERA_FROM.x, 0.0, ArenaView.CAMERA_FROM.z).rotated(Vector3.UP, view.camera_swing)
	assert_lt(absf(view._hold_pose.frame.basis.z.dot(camera.normalized())), 0.01, "along the cage, not into it")


func test_an_escape_lets_go_of_the_hold() -> void:
	var setup: Array = _watched("full_guard", 1)
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	_lock(sim, 0, "armbar")
	_frames(view, 2)
	assert_true(view.shows_hold())
	sim._hold = {}
	sim.situation.set_to(sim.positions.get_position("full_guard"), [PositionLibrary.BOTTOM, PositionLibrary.TOP])
	_frames(view, 2)
	assert_false(view.shows_hold(), "back to the guard")


func test_a_finish_plays_the_tap_before_the_result() -> void:
	var setup: Array = _watched("full_guard", 1)
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	_lock(sim, 0, "triangle")
	_frames(view, 30)
	watch_signals(view)
	sim._finish(0, FightSim.RESULT_SUB)
	var wrist: String = "wrist_" + String(SubmissionPair.TAPS.triangle.hand).right(1)
	var low: float = INF
	var high: float = -INF
	var frames: int = int(ArenaView.TAP_SECONDS * 30.0) - 3
	for n in frames:
		view._process(1.0 / 30.0)
		var y: float = view._clinch_rigs[1].joints[wrist].y
		low = minf(low, y)
		high = maxf(high, y)
	assert_signal_not_emitted(view, "tapped", "still tapping")
	assert_gt(high - low, SubmissionPair.TAP_LIFT * 0.5, "his hand coming up and down")
	_frames(view, 6)
	assert_signal_emit_count(view, "tapped", 1, "then the result")
