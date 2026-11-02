extends GutTest
## The referee (D373) and the hold on the finish (D374): a third body in the cage all fight in a striped shirt,
## shadowing them on the far side from the camera, crouched over them on the ground, over a knocked-down man, and
## jumping in to wave it off before the result comes up. Presentation only.

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


## A watched fight between `red` and `blue`, red at `red_at` and blue at `blue_at`: [sim, view].
func _watched(red := "boxer", blue := "kicker", red_at := Vector2(0.6, 0.0), blue_at := Vector2(-0.6, 0.0)) -> Array:
	var sim := FightSim.new(3, _roster.make_pair(red, blue), _actions)
	sim.fighters[0].pos = red_at
	sim.fighters[1].pos = blue_at
	var view := ArenaView.new()
	add_child_autofree(view)
	view.watch(FightDriver.new(sim))
	view.driver._snap()
	_frames(view, 10, 1.0 / 10.0)
	return [sim, view]


func _frames(view: ArenaView, count: int, delta: float = 1.0 / 30.0) -> void:
	for n in count:
		view._process(delta)


func _ended(view: ArenaView, sim: FightSim, result: String, winner: int = 0) -> void:
	view._on_event(FightEvent.new(sim.now, 1, FightEvent.FIGHT_ENDED, winner, {"result": result, "winner": winner}))


func _hips_height(view: ArenaView) -> float:
	return view.referee.body.hips_at().y


func test_watching_he_stands_clear_of_both_men_and_the_fence_on_the_far_side_from_the_camera() -> void:
	var men: Array[Vector2] = [Vector2(0.6, 0.0), Vector2(-0.6, 0.0)]
	var camera := Vector2(0.0, 8.0)
	var at: Vector2 = Referee.watch_spot(men, Referee.STANDING_OFF, camera, Vector2.ZERO)
	assert_lt(at.y, -1.0, "behind them as the camera sees it")
	for man in men:
		assert_gte(at.distance_to(man), Referee.CLEAR_OF_MEN, "clear of each man")
	assert_gte(Octagon.distance_to_fence(at), Referee.CLEAR_OF_FENCE - 0.01, "clear of the fence")


func test_with_them_against_the_far_fence_he_stays_inside_the_cage_and_off_them() -> void:
	var men: Array[Vector2] = [Vector2(0.5, -3.7), Vector2(-0.5, -3.7)]
	var at: Vector2 = Referee.watch_spot(men, Referee.STANDING_OFF, Vector2(0.0, 8.0), Vector2(0.0, -2.0))
	assert_gte(Octagon.distance_to_fence(at), Referee.CLEAR_OF_FENCE - 0.01, "inside the cage")
	for man in men:
		assert_gte(at.distance_to(man), Referee.CLEAR_OF_MEN - 0.2, "not on top of them")


func test_he_doesnt_dance_about_when_they_shift_a_little() -> void:
	var camera := Vector2(0.0, 8.0)
	var men: Array[Vector2] = [Vector2(0.6, 0.0), Vector2(-0.6, 0.0)]
	var at: Vector2 = Referee.watch_spot(men, Referee.STANDING_OFF, camera, Vector2(0.0, -2.3))
	var moved: Array[Vector2] = [Vector2(0.7, 0.1), Vector2(-0.5, 0.1)]
	var then: Vector2 = Referee.watch_spot(moved, Referee.STANDING_OFF, camera, at)
	assert_lt(at.distance_to(then), 0.5, "a small shift of theirs is a small shift of his")


func test_stopping_two_men_apart_he_gets_between_them_by_the_beaten_man() -> void:
	var winner := Vector2(1.5, 0.0)
	var loser := Vector2(-1.5, 0.0)
	var at: Vector2 = Referee.stop_spot(winner, loser, Vector2(0.0, 8.0))
	assert_lt(at.distance_to(loser), at.distance_to(winner), "by the beaten man")
	assert_lt(absf(at.y), 0.05, "between them")
	assert_gt(at.x, loser.x, "on the winner's side of him")


func test_stopping_two_men_too_close_to_get_between_he_steps_in_beside_them_where_the_camera_sees_him() -> void:
	var camera := Vector2(0.0, 8.0)
	var winner := Vector2(0.4, 0.0)
	var loser := Vector2(-0.4, 0.0)
	var at: Vector2 = Referee.stop_spot(winner, loser, camera)
	var view: Vector2 = (Vector2.ZERO - camera).normalized()
	for man in [winner, loser]:
		var across: float = absf((at - camera).cross(man - camera)) / (man - camera).length()
		assert_gt(across, 0.5, "not hidden behind %s" % man)
	assert_lt(at.distance_to(loser), at.distance_to(winner), "on the beaten man's side")
	assert_lt(at.distance_to(Vector2.ZERO), 1.4, "close enough to put a hand on him")
	assert_gt((at - camera).dot(view), 0.0, "in front of the camera")


func test_waving_it_off_his_hands_go_over_his_head_and_with_a_man_to_hold_one_goes_on_him() -> void:
	var rig := FighterRig.new(Color.WHITE)
	add_child_autofree(rig)
	var spec: Dictionary = Referee.pose_spec("stop", 0.1)
	for side in FighterRig.SIDES:
		assert_gt(float(spec["hand_" + side].at[1]), 1.6, "the %s hand is up over his head" % side)
	var hold := Vector3(-0.4, 1.2, -0.6)
	spec = Referee.pose_spec("stop", 0.1, hold)
	assert_eq(Vector3(spec.hand_l.at[0], spec.hand_l.at[1], spec.hand_l.at[2]), hold, "his near hand on the man")
	assert_gt(float(spec.hand_r.at[1]), 1.6, "the other waving over his head")
	var low: Dictionary = Referee.pose_spec("stop", 0.1, Vector3(0.4, 0.5, -0.6), true)
	assert_lt(float(low.root[1]), float(spec.root[1]), "bent down to men on the ground")


func test_every_fight_has_a_referee_in_a_striped_shirt_off_to_the_side() -> void:
	var made: Array = _watched()
	var view: ArenaView = made[1]
	assert_not_null(view.referee, "a referee in the cage")
	assert_not_null(view.referee.body, "drawn with the body")
	var skin: ShaderMaterial = view.referee.body.find_children("*", "MeshInstance3D", true, false)[0].material_override
	assert_true(bool(skin.get_shader_parameter("has_clothes")), "dressed")
	assert_eq(view.referee.mode, "watch")
	for figure in view.figures:
		var hips: Vector3 = figure.body.hips_at()
		assert_gt(view.referee.spot.distance_to(Vector2(hips.x, hips.z)), Referee.CLEAR_OF_MEN - 0.2, "off the men")


func test_he_is_the_same_man_for_the_same_fight() -> void:
	var first: ArenaView = _watched()[1]
	var second: ArenaView = _watched()[1]
	assert_eq(first.referee.look, second.referee.look, "same seed, same referee")


func test_on_the_ground_he_crouches_over_them() -> void:
	var made: Array = _watched("wrestler", "bjj", Vector2(0.3, 0.6), Vector2(-0.1, 0.4))
	var sim: FightSim = made[0]
	var view: ArenaView = made[1]
	var standing: float = _hips_height(view)
	var roles: Array[String] = [PositionLibrary.TOP, PositionLibrary.BOTTOM]
	sim.situation.set_to(sim.positions.get_position("mount"), roles)
	for f: FighterState in sim.fighters:
		f.clear_action()
	_frames(view, 30, 1.0 / 10.0)
	assert_eq(view.referee.mode, "ground")
	assert_lt(_hips_height(view), standing - 0.1, "crouched")


func test_over_a_knocked_down_man_he_stands_over_him() -> void:
	var made: Array = _watched()
	var sim: FightSim = made[0]
	var view: ArenaView = made[1]
	var f: FighterState = sim.fighters[1]
	f.clear_action()
	f.down_ticks = FightSim.DOWN_TICKS
	view._on_event(FightEvent.new(sim.now, 1, FightEvent.KNOCKDOWN, 1, {"by": 0}))
	_frames(view, 20, 1.0 / 10.0)
	assert_eq(view.referee.mode, "down")
	var hips: Vector3 = view.figures[1].body.hips_at()
	assert_lt(view.referee.spot.distance_to(Vector2(hips.x, hips.z)), Referee.DOWN_OFF + 0.6, "close by him")


func test_a_stoppage_brings_him_in_to_wave_it_off_and_the_result_waits_a_few_seconds() -> void:
	var made: Array = _watched("boxer", "kicker", Vector2(1.6, 0.0), Vector2(-1.6, 0.0))
	var sim: FightSim = made[0]
	var view: ArenaView = made[1]
	assert_true(view.holds_finish({"result": FightSim.RESULT_TKO, "winner": 0}), "a stoppage is held")
	assert_true(view.holds_finish({"result": FightSim.RESULT_KO, "winner": 0}), "a knockout is held")
	assert_true(view.holds_finish({"result": FightSim.RESULT_SUB, "winner": 0}), "a submission is held")
	assert_false(view.holds_finish({"result": "decision", "winner": 0}), "a decision goes straight to the cards")
	assert_eq(view.finish_seconds(), ArenaView.FINISH_HOLD)
	watch_signals(view)
	_ended(view, sim, FightSim.RESULT_TKO, 0)
	_frames(view, 30, 1.0 / 30.0)
	assert_eq(view.referee.mode, "stop", "jumping in")
	var loser: Vector3 = view.figures[1].body.hips_at()
	var winner: Vector3 = view.figures[0].body.hips_at()
	var spot: Vector2 = view.referee.spot
	assert_lt(spot.distance_to(Vector2(loser.x, loser.z)), spot.distance_to(Vector2(winner.x, winner.z)), "by the beaten man")
	assert_signal_not_emitted(view, "finish_shown", "the result waits")
	_frames(view, roundi((ArenaView.FINISH_HOLD - 1.0) * 30.0) + 2, 1.0 / 30.0)
	assert_signal_emit_count(view, "finish_shown", 1, "then it comes up, once")
	_frames(view, 30, 1.0 / 30.0)
	assert_signal_emit_count(view, "finish_shown", 1, "only once")
