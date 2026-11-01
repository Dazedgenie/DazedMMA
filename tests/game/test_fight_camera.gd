extends GutTest
## The camera seeing the two side-on (D361): standing, it eases round the cage to square them up when one is
## behind the other, never more than CAMERA_SWING_MAX either way, climbs where it can't, and goes back to
## CAMERA_FROM off the feet. Presentation only.

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


## A watched fight with the two standing at `a` and `b`, the camera settled for `seconds`: [sim, view].
func _watch(a: Vector2, b: Vector2, seconds: float = 6.0) -> Array:
	var sim := FightSim.new(3, _roster.make_pair("boxer", "kicker"), _actions)
	var view := ArenaView.new()
	add_child_autofree(view)
	view.watch(FightDriver.new(sim))
	sim.fighters[0].pos = a
	sim.fighters[1].pos = b
	_settle(view, sim, a, b, seconds)
	return [sim, view]


func _settle(view: ArenaView, sim: FightSim, a: Vector2, b: Vector2, seconds: float) -> void:
	var shown: Array[Vector2] = [a, b]
	for frame in int(seconds * 10.0):
		view._place_camera(0.1, (a + b) / 2.0, sim, shown)


## The line along the camera's view, flat on the canvas (from the camera toward what it looks at).
func _view_line(view: ArenaView) -> Vector2:
	var from: Vector3 = ArenaView.camera_from(view.camera_swing, view.camera_rise)
	return -Vector2(from.x, from.z).normalized()


func test_side_on_already_the_camera_stays_where_it_is() -> void:
	var across := Vector2(ArenaView.CAMERA_FROM.z, -ArenaView.CAMERA_FROM.x).normalized()
	var view: ArenaView = _watch(-across * 0.6, across * 0.6)[1]
	assert_almost_eq(view.camera_swing, 0.0, 0.001)
	assert_almost_eq(view.camera_rise, 0.0, 0.001)


func test_one_behind_the_other_it_turns_round_to_see_them_side_on() -> void:
	var line := Vector2(1.0, 0.25).normalized()  # Mostly along the camera's view, a little off it.
	var setup: Array = _watch(-line * 0.6, line * 0.6)
	var view: ArenaView = setup[1]
	assert_ne(view.camera_swing, 0.0, "it turned")
	assert_lte(absf(view.camera_swing), ArenaView.CAMERA_SWING_MAX + 0.001, "but not past its limit")
	var before: float = absf(Vector2(ArenaView.CAMERA_FROM.x, ArenaView.CAMERA_FROM.z).normalized().cross(line))
	assert_gt(ArenaView.side_on(-line, line, view.camera_swing), before + 0.2, "more side-on than before")


func test_where_turning_can_t_square_them_up_it_climbs_instead() -> void:
	var line := Vector2(ArenaView.CAMERA_FROM.x, ArenaView.CAMERA_FROM.z).normalized().rotated(0.05)
	var view: ArenaView = _watch(-line * 0.6, line * 0.6)[1]
	assert_almost_eq(absf(view.camera_swing), ArenaView.CAMERA_SWING_MAX, 0.05, "turned as far as it goes")
	assert_gt(view.camera_rise, 0.1, "and up above them")
	assert_gt(view.camera.position.y, ArenaView.CAMERA_FROM.normalized().y * 6.0, "higher than it sits")


func test_off_their_feet_it_goes_back_to_where_the_clinch_and_ground_are_laid_out_for() -> void:
	var line := Vector2(1.0, 0.25).normalized()
	var setup: Array = _watch(-line * 0.6, line * 0.6)
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	var roles: Array[String] = [PositionLibrary.TOP, PositionLibrary.BOTTOM]
	sim.situation.set_to(sim.positions.get_position("mount"), roles)
	_settle(view, sim, -line * 0.6, line * 0.6, 8.0)
	assert_almost_eq(view.camera_swing, 0.0, 0.02)
	assert_almost_eq(view.camera_rise, 0.0, 0.02)


func test_it_eases_round_rather_than_cutting() -> void:
	var line := Vector2(1.0, 0.25).normalized()
	var setup: Array = _watch(-line * 0.6, line * 0.6, 0.1)
	var view: ArenaView = setup[1]
	assert_lt(absf(view.camera_swing), 0.2, "a tenth of a second in, it has only started to turn")
