extends GutTest
## A pose for every grappling move (D282): the clinch grips are where they should be on the other man, and every
## move in the library moves the figure when it's thrown. Presentation only.

var _actions: ActionLibrary
var _sim: FightSim
var _figures: Array[FighterFigure] = []


func before_each() -> void:
	_actions = ActionLibrary.load_dir()
	_sim = FightSim.new(3, FighterLibrary.load_dir().make_pair("wrestler", "boxer"), _actions)
	_figures = []
	for i in 2:
		var figure := FighterFigure.new(Color.RED if i == 0 else Color.BLUE)
		add_child_autofree(figure)
		_figures.append(figure)
	_figures[0].opponent = _figures[1]
	_figures[1].opponent = _figures[0]


func _place(position: String, roles: Array[String], gap: float = ArenaView.CLINCH_BODY_GAP) -> void:
	_sim.situation.set_to(_sim.positions.get_position(position), roles)
	_sim.fighters[0].pos = Vector2(0, gap / 2.0)
	_sim.fighters[1].pos = Vector2(0, -gap / 2.0)


func _show(frames: int = 30) -> void:
	for frame in frames:
		for i in 2:
			_figures[i].show_state(_sim, i, _sim.fighters[i].pos, _sim.fighters[1 - i].pos, 1.0 / 60.0)


## How far behind the other man's chest (along his back) a hand is: positive is behind him.
func _behind(hand: Node3D, him: FighterFigure) -> float:
	return (hand.global_position - him._torso.global_position).dot(him.global_basis.z)


func test_an_underhook_reaches_round_his_back_and_an_overhook_comes_over_the_top() -> void:
	_place(PositionLibrary.CLINCH, [PositionLibrary.NEUTRAL, PositionLibrary.NEUTRAL])
	_sim.set_grips([0, FightSim.NO_GRIP])
	_show()
	var red: FighterFigure = _figures[0]
	var blue: FighterFigure = _figures[1]
	var under: Node3D = red._gloves[red.grip_arm(0, 0)]
	var over: Node3D = blue._gloves[blue.grip_arm(1, 0)]
	assert_gt(_behind(under, blue), 0.05, "the underhook's hand is on his back")
	assert_gt(blue._forearms[blue.grip_arm(1, 0)].global_position.y, red._forearms[red.grip_arm(0, 0)].global_position.y,
		"the overhook's arm sits over the underhook's")
	assert_ne(red.grip_arm(0, 0), red.grip_arm(0, 1), "each of his arms is on its own side")
	assert_true(over.global_position.is_finite())


func test_the_body_lock_locks_both_hands_behind_his_back_and_hand_fighting_stays_in_front() -> void:
	_place(PositionLibrary.CLINCH, [PositionLibrary.NEUTRAL, PositionLibrary.NEUTRAL])
	_show()
	for glove: Node3D in _figures[0]._gloves:
		assert_lt(_behind(glove, _figures[1]), 0.0, "hand fighting: the hands are on his arms, in front of him")
	_sim.set_grips([0, 0])
	_show()
	var hands: Array[Node3D] = _figures[0]._gloves
	for glove: Node3D in hands:
		assert_gt(_behind(glove, _figures[1]), 0.08, "both hands behind his back")
	assert_lt(hands[0].global_position.distance_to(hands[1].global_position), 0.2, "locked together")


func test_a_pummel_swims_the_hand_in_to_the_underhook() -> void:
	_place(PositionLibrary.CLINCH, [PositionLibrary.NEUTRAL, PositionLibrary.NEUTRAL])
	_sim.set_grips([1, FightSim.NO_GRIP])
	_show()
	var red: FighterFigure = _figures[0]
	var arm: int = red.grip_arm(0, 0)
	var start: float = _behind(red._gloves[arm], _figures[1])
	var f: FighterState = _sim.fighters[0]
	f.action_id = "pummel"
	f.phase = "active"
	f.phase_ticks_left = 1
	_show()
	assert_gt(_behind(red._gloves[arm], _figures[1]), start + 0.05, "the overhooked arm swims round to his back")
	assert_lt(red._gloves[arm].global_position.distance_to(red.grip_point(arm, "under")), 0.12, "to the underhook")


func test_a_knee_in_the_clinch_keeps_both_grips_and_a_punch_lets_one_go() -> void:
	_place(PositionLibrary.CLINCH, [PositionLibrary.NEUTRAL, PositionLibrary.NEUTRAL])
	_sim.set_grips([0, 0])
	var f: FighterState = _sim.fighters[0]
	f.action_id = "knee"
	f.phase = "active"
	f.phase_ticks_left = 1
	_show()
	for glove: Node3D in _figures[0]._gloves:
		assert_gt(_behind(glove, _figures[1]), 0.08, "a knee keeps the body lock")
	f.action_id = "short_uppercut"
	_show()
	assert_lt(_behind(_figures[0]._gloves[1], _figures[1]), 0.08, "the rear hand leaves to throw")
	assert_gt(_behind(_figures[0]._gloves[0], _figures[1]), 0.08, "the lead hand keeps its grip")


func test_covering_up_underneath_puts_the_gloves_over_his_face() -> void:
	_place("mount", [PositionLibrary.TOP, PositionLibrary.BOTTOM])
	var f: FighterState = _sim.fighters[1]
	f.action_id = "ground_cover"
	f.phase = "active"
	f.phase_ticks_left = 10
	_show()
	var head: Vector3 = _figures[1]._head.global_position
	for glove: Node3D in _figures[1]._gloves:
		assert_lt(glove.global_position.distance_to(head), 0.25, "gloves at his face")
		assert_gt(glove.global_position.y, head.y - 0.02, "over it, between him and the punches")


func test_every_move_in_the_library_moves_the_figure_when_its_thrown() -> void:
	var still: Array[String] = []
	for id: String in _actions.ids():
		var action: Dictionary = _actions.get_action(id)
		var where: String = String(action.positions[0]) if not action.get("positions", []).is_empty() else PositionLibrary.STANDING
		var allowed: Array = action.get("roles", []) if action.get("roles") != null else []
		var mine: String = String(allowed[0]) if not allowed.is_empty() else PositionLibrary.NEUTRAL
		var roles: Array[String] = [PositionLibrary.NEUTRAL, PositionLibrary.NEUTRAL]
		if mine == PositionLibrary.TOP:
			roles = [PositionLibrary.TOP, PositionLibrary.BOTTOM]
		elif mine == PositionLibrary.BOTTOM:
			roles = [PositionLibrary.BOTTOM, PositionLibrary.TOP]
		_place(where, roles)
		var f: FighterState = _sim.fighters[0]
		f.clear_action()
		var before: Dictionary = _figures[0].pose_for(_sim, 0)
		f.action_id = id
		f.phase = "active"
		f.phase_ticks_left = 1
		var during: Dictionary = _figures[0].pose_for(_sim, 0)
		var moved: float = 0.0
		for key: String in during:
			moved = maxf(moved, absf(float(during[key]) - float(before.get(key, during[key]))))
		if moved < 0.05 and not ["pummel", "strip_grip", "collar_tie"].has(id):
			still.append(id)
		f.clear_action()
	assert_eq(still, [] as Array[String], "every move has a pose of its own")


func test_a_locked_armbar_from_the_guard_lies_him_back_with_the_legs_across() -> void:
	_place("full_guard", [PositionLibrary.TOP, PositionLibrary.BOTTOM])
	_sim.set("_hold", { "attacker": 1, "action_id": "armbar", "danger": 50.0, "beats": 0, "next_at": 100,
		"from": "full_guard", "from_roles": [PositionLibrary.TOP, PositionLibrary.BOTTOM], "near": false })
	var pose: Dictionary = _figures[1].pose_for(_sim, 1)
	assert_almost_eq(float(pose.lie), 1.0, 0.01)
	assert_gt(float(pose.leg_lead), 1.8, "legs up across him")
	assert_gt(float(_figures[0].pose_for(_sim, 0).reach_lead), 1.2, "his arm pulled straight")
