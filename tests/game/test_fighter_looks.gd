extends GutTest
## Fighters who look different on the fight screen (D364): the body drawn at his height, build and reach, in his
## look; the shorts stay the corner's.


func _figure(profile: Dictionary) -> FighterFigure:
	var figure := FighterFigure.new(Color.RED)
	add_child_autofree(figure)
	assert_true(figure.use_body(ArenaView.BODY, profile), "the body loads")
	return figure


func _man(height: int, reach: int, build: String, look: Dictionary = {}) -> Dictionary:
	var p: Dictionary = FighterLibrary.load_dir().profile("boxer")
	p.frame = { "height_cm": height, "reach_cm": reach, "build": build }
	if not look.is_empty():
		p.look = look
	return p


func _stand(figure: FighterFigure) -> void:
	var sim := FightSim.new(3, FighterLibrary.load_dir().make_pair("boxer", "wrestler"), ActionLibrary.load_dir())
	figure.show_state(sim, 0, Vector2.ZERO, Vector2(0, -1), 1.0)


func test_a_taller_man_stands_taller() -> void:
	var tall: FighterFigure = _figure(_man(195, 195, "average"))
	var short: FighterFigure = _figure(_man(168, 168, "average"))
	_stand(tall)
	_stand(short)
	var ratio: float = tall.body._world_at("Head").y / short.body._world_at("Head").y
	assert_almost_eq(ratio, 195.0 / 168.0, 0.03, "true to the numbers")
	assert_almost_eq(tall.scale.x, 195.0 / FighterLook.DRAWN_HEIGHT_CM, 0.001)


func test_long_arms_are_drawn_long_and_the_rig_fits_them() -> void:
	var long_arms: FighterFigure = _figure(_man(180, 195, "average"))
	var short_arms: FighterFigure = _figure(_man(180, 172, "average"))
	var long_measure: Dictionary = long_arms.body.measure()
	var short_measure: Dictionary = short_arms.body.measure()
	assert_gt(float(long_measure.upper_arm) + float(long_measure.forearm),
		(float(short_measure.upper_arm) + float(short_measure.forearm)) * 1.1)
	assert_almost_eq(float(long_measure.thigh), float(short_measure.thigh), 0.001, "his legs as they were")


func test_a_stocky_man_is_drawn_thicker() -> void:
	var stocky: FighterFigure = _figure(_man(178, 178, "stocky"))
	var lean: FighterFigure = _figure(_man(178, 178, "lean"))
	var thick: Vector3 = stocky.body.skeleton.get_bone_global_pose(stocky.body.skeleton.find_bone("mixamorig_Spine1")).basis.get_scale()
	_stand(stocky)
	_stand(lean)
	var bone: int = stocky.body.skeleton.find_bone("mixamorig_Spine1")
	var a: Vector3 = stocky.body.skeleton.get_bone_global_pose(bone).basis.get_scale()
	var b: Vector3 = lean.body.skeleton.get_bone_global_pose(bone).basis.get_scale()
	assert_gt(a.x, b.x + 0.05, "wider across")
	assert_almost_eq(a.y, b.y, 0.001, "not longer")
	assert_ne(thick, a, "posing gives the bone its build")


func test_the_body_is_coloured_as_his_look_and_his_shorts_as_his_corner() -> void:
	var look: Dictionary = { "skin": 6, "hair": "blonde", "hair_style": "shaved", "beard": "beard" }
	var figure: FighterFigure = _figure(_man(180, 180, "average", look))
	assert_eq(figure.look, look)
	var meshes: Array[Node] = figure.body.find_children("*", "MeshInstance3D", true, false)
	var material: ShaderMaterial = (meshes[0] as MeshInstance3D).material_override
	assert_eq(material.get_shader_parameter("skin"), FighterLook.skin_colour(look))
	assert_eq(material.get_shader_parameter("hair"), FighterLook.hair_colour(look))
	assert_eq(material.get_shader_parameter("tint"), Color.RED, "the corner's shorts")
	assert_eq(float(material.get_shader_parameter("hair_kept")), 0.0, "a shaved head")
	assert_gt(float(material.get_shader_parameter("hair_sink")), 0.0, "the hair sinks to the scalp")
	assert_almost_eq(float(material.get_shader_parameter("beard")), float(FighterLook.BEARD_SHADE.beard), 0.001)
	assert_not_null(material.get_shader_parameter("regions"), "the body's regions")


func test_with_no_profile_the_body_is_drawn_as_it_was() -> void:
	var figure := FighterFigure.new(Color.BLUE)
	add_child_autofree(figure)
	assert_true(figure.use_body(ArenaView.BODY))
	assert_eq(figure.scale, Vector3.ONE)
	assert_eq(figure.look, {})
