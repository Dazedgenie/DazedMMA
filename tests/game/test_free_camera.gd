extends GutTest
## The fight camera turned by hand (D472–D476, docs/06 §6.19): turning, tilting and zooming it round the fighters,
## holding the angle until C, easing back after C, and never changing how the fighters are laid out. Presentation only.

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


## A watched fight with the two standing at `a` and `b`: [sim, view].
func _watch(a: Vector2, b: Vector2) -> Array:
	var sim := FightSim.new(3, _roster.make_pair("boxer", "kicker"), _actions)
	var view := ArenaView.new()
	add_child_autofree(view)
	view.watch(FightDriver.new(sim))
	sim.fighters[0].pos = a
	sim.fighters[1].pos = b
	_settle(view, sim, a, b, 2.0)
	return [sim, view]


func _settle(view: ArenaView, sim: FightSim, a: Vector2, b: Vector2, seconds: float) -> void:
	var shown: Array[Vector2] = [a, b]
	for frame in int(seconds * 10.0):
		view.free_cam.advance(0.1)
		view._place_camera(0.1, (a + b) / 2.0, sim, shown)


func _across() -> Vector2:
	return Vector2(ArenaView.CAMERA_FROM.z, -ArenaView.CAMERA_FROM.x).normalized()


func test_turning_it_by_hand_moves_the_camera_round_them_and_nothing_else() -> void:
	var setup: Array = _watch(-_across() * 0.6, _across() * 0.6)
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	var before: Vector3 = view.camera.position
	view.turn_camera(1.2, 0.0)
	_settle(view, sim, -_across() * 0.6, _across() * 0.6, 0.1)
	assert_almost_eq(view.aimed_swing, 1.2, 0.01, "the camera turned round")
	assert_almost_eq(view.camera_swing, 0.0, 0.01, "its own swing, that the fighters are laid out from, didn't")
	assert_gt(view.camera.position.distance_to(before), 2.0, "it stands somewhere else")
	var focus := Vector3(0.0, 0.6, 0.0)
	assert_almost_eq(view.camera.position.distance_to(focus), before.distance_to(focus), 0.05, "as far from them as before")


func test_a_drag_right_turns_it_one_way_and_a_drag_down_raises_it() -> void:
	var cam := FreeCamera.new()
	cam.drag(Vector2(100.0, 0.0), 0.0, 0.0)
	assert_lt(cam.swing, 0.0)
	cam.drag(Vector2(0.0, 60.0), 0.0, 0.0)
	assert_gt(cam.rise, 0.0)


func test_once_turned_it_holds_the_angle_while_they_move_round() -> void:
	var setup: Array = _watch(-_across() * 0.6, _across() * 0.6)
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	view.turn_camera(0.5, 0.2)
	var line := Vector2(1.0, 0.25).normalized()  # One behind the other: the camera's own swing goes round.
	sim.fighters[0].pos = -line * 0.6
	sim.fighters[1].pos = line * 0.6
	_settle(view, sim, -line * 0.6, line * 0.6, 6.0)
	assert_ne(view.camera_swing, 0.0, "the camera's own swing moved")
	assert_almost_eq(view.aimed_swing, 0.5, 0.001, "but the camera stayed where it was turned")
	assert_almost_eq(view.aimed_rise, 0.2, 0.001)


func test_c_eases_it_back_to_the_normal_camera() -> void:
	var setup: Array = _watch(-_across() * 0.6, _across() * 0.6)
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	view.turn_camera(1.0, 0.3)
	view.zoom_camera(4.0)
	_settle(view, sim, -_across() * 0.6, _across() * 0.6, 0.1)
	view.reset_camera()
	_settle(view, sim, -_across() * 0.6, _across() * 0.6, 0.1)
	assert_gt(view.aimed_swing, 0.3, "a tenth of a second after C it's still on its way back")
	_settle(view, sim, -_across() * 0.6, _across() * 0.6, 2.0)
	assert_almost_eq(view.aimed_swing, view.camera_swing, 0.001, "then it's the normal camera again")
	assert_almost_eq(view.aimed_rise, view.camera_rise, 0.001)
	assert_eq(view.free_cam.aim_zoom(), 1.0)


func test_it_tilts_from_just_off_the_canvas_to_nearly_overhead_and_no_further() -> void:
	var cam := FreeCamera.new()
	cam.turn_by(0.0, -5.0, 0.0, 0.0)
	assert_eq(cam.rise, FreeCamera.RISE_MIN)
	var low: Vector3 = ArenaView.camera_from(0.0, cam.rise)
	assert_gt(low.y, 0.0, "still above what it looks at")
	cam.turn_by(0.0, 10.0, 0.0, 0.0)
	assert_eq(cam.rise, FreeCamera.RISE_MAX)


func test_the_wheel_zooms_in_and_out_between_its_limits() -> void:
	var cam := FreeCamera.new()
	cam.zoom_by(1.0, 0.0, 0.0)
	assert_almost_eq(cam.zoom, FreeCamera.ZOOM_STEP, 0.0001, "a notch in")
	cam.zoom_by(100.0, 0.0, 0.0)
	assert_eq(cam.zoom, FreeCamera.ZOOM_MIN)
	cam.zoom_by(-100.0, 0.0, 0.0)
	assert_eq(cam.zoom, FreeCamera.ZOOM_MAX)


func test_the_next_fight_starts_on_the_normal_camera() -> void:
	var setup: Array = _watch(-_across() * 0.6, _across() * 0.6)
	var view: ArenaView = setup[1]
	view.turn_camera(1.0, 0.3)
	view.watch(FightDriver.new(FightSim.new(4, _roster.make_pair("boxer", "kicker"), _actions)))
	assert_false(view.free_cam.held)
	assert_eq(view.free_cam.aim_swing(0.25), 0.25)
