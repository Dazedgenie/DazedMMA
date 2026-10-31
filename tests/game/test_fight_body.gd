extends GutTest
## The fighters drawn with the skinned Tripo body (D285): the faceted pieces still pose every frame but aren't
## drawn, and the body follows their joints. Presentation only; the sim is never changed.

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


func _sim() -> FightSim:
	return FightSim.new(3, _roster.make_pair("boxer", "kicker"), _actions)


## Two figures with bodies facing each other `gap` metres apart along x.
func _pair() -> Array[FighterFigure]:
	var figures: Array[FighterFigure] = [FighterFigure.new(Color.RED, false, 0), FighterFigure.new(Color.BLUE, true, 1)]
	for figure in figures:
		add_child_autofree(figure)
		assert_true(figure.use_body(ArenaView.BODY), "the body loads")
	figures[0].opponent = figures[1]
	figures[1].opponent = figures[0]
	return figures


func _pose(sim: FightSim, figures: Array[FighterFigure], gap: float) -> void:
	for frame in 3:
		figures[1].show_state(sim, 1, Vector2(gap, 0), Vector2.ZERO, 1.0)
		figures[0].show_state(sim, 0, Vector2.ZERO, Vector2(gap, 0), 1.0)


func _throw(sim: FightSim, action: String) -> void:
	var f: FighterState = sim.fighters[0]
	f.action_id = action
	f.phase = "active"
	f.phase_ticks_left = 1


func _bone(figure: FighterFigure, bone: String) -> Vector3:
	var skeleton: Skeleton3D = figure.body.skeleton
	return (skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(SkinnedBody.PREFIX + bone))).origin


func test_the_fight_draws_the_body_and_hides_the_pieces_but_not_the_tell() -> void:
	assert_ne(ArenaView.BODY, "", "the fight screen uses a body")
	var figures: Array[FighterFigure] = _pair()
	for figure in figures:
		assert_not_null(figure.body)
		for found: Node in figure._hips.find_children("*", "GeometryInstance3D", true, false):
			var piece: GeometryInstance3D = found
			if piece == figure._tell or figure._tell.is_ancestor_of(piece):
				assert_ne(piece.layers, 0, "the scouted tell still shows")
			else:
				assert_eq(piece.layers, 0, "%s isn't drawn" % piece.name)
	var red: ShaderMaterial = figures[0].body.find_children("*", "MeshInstance3D", true, false)[0].material_override
	assert_eq(Color(red.get_shader_parameter("tint")), Color.RED, "red's shorts are red")


func test_the_bodys_shoulders_sit_where_the_pieces_are() -> void:
	var sim: FightSim = _sim()
	var figures: Array[FighterFigure] = _pair()
	_pose(sim, figures, 1.4)
	for figure in figures:
		var pieces: float = figure._arm_meshes[0].global_position.y
		assert_almost_eq(_bone(figure, "RightArm").y, pieces, 0.05, "shoulders at the pieces' height")


func test_the_bodys_hands_go_where_the_gloves_do_in_guard_strikes_and_the_clinch() -> void:
	var sim: FightSim = _sim()
	var figures: Array[FighterFigure] = _pair()
	for setup: Array in [
		["guard", func() -> void: sim.fighters[0].clear_action()],
		["jab", func() -> void: _throw(sim, "jab")],
		["hook", func() -> void: _throw(sim, "hook")],
		["clinch", func() -> void: sim.apply_transition(0, "clinch_entry")],
	]:
		setup[1].call()
		_pose(sim, figures, 1.4)
		var figure: FighterFigure = figures[0]
		for i in 2:
			var side: String = "Left" if (figure.lead if i == 0 else -figure.lead) < 0.0 else "Right"
			var glove: Vector3 = figure._gloves[i].global_position
			# His arms are a little shorter than the pieces'; a long punch throws his shoulder to make up the gap.
			assert_lt(_bone(figure, side + "Hand").distance_to(glove), 0.04, "%s: %s hand" % [setup[0], side])


func test_standing_his_feet_are_on_the_mat_under_the_pieces_feet() -> void:
	var sim: FightSim = _sim()
	var figures: Array[FighterFigure] = _pair()
	_pose(sim, figures, 1.4)
	for figure in figures:
		for i in 2:
			var side: String = "Left" if (figure.lead if i == 0 else -figure.lead) < 0.0 else "Right"
			var ankle: Vector3 = _bone(figure, side + "Foot")
			var piece: Vector3 = figure._shins[i].global_transform * Vector3(0, -FighterMotion.SHIN, 0)
			assert_lt(Vector2(ankle.x, ankle.z).distance_to(Vector2(piece.x, piece.z)), 0.05, "%s foot under the piece's" % side)
			assert_between(_bone(figure, side + "ToeBase").y, 0.0, 0.08, "%s toes on the mat" % side)
