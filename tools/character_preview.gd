extends SceneTree
## Neutral, close character review using the actual game figures, not concept art.
## godot --script res://tools/character_preview.gd -- --out=res://build/characters

var _out := "res://build/characters"
var _scene: Node3D
var _figures: Array[FighterFigure] = []
var _sim: FightSim


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	_review.call_deferred()


func _review() -> void:
	root.size = Vector2i(1500, 1000)
	_scene = Node3D.new()
	root.add_child(_scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#202936")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#a9bad0")
	environment.environment.ambient_light_energy = 0.5
	_scene.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, -35, 0)
	key.light_color = Color("#ffe5cc")
	key.light_energy = 0.9
	key.shadow_enabled = true
	key.shadow_bias = 0.05
	key.directional_shadow_max_distance = 12.0
	key.shadow_normal_bias = 0.1
	_scene.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 145, 0)
	fill.light_color = Color("#b0c9e3")
	fill.light_energy = 0.45
	_scene.add_child(fill)
	var floor_node: MeshInstance3D = FightMesh.box(_scene, Vector3(20, 0.1, 20), FighterFigure._material(Color("#303a48")), Vector3(0, -0.14, 0))
	floor_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var camera := Camera3D.new()
	_scene.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.4
	camera.position = Vector3(0, 2.4, -7)
	camera.look_at(Vector3(0, 0.97, 0))
	camera.current = true
	_sim = FightSim.new(3, FighterLibrary.load_dir().make_pair("boxer", "wrestler"), ActionLibrary.load_dir())
	for i in 2:
		var platform := CylinderMesh.new()
		platform.height = 0.08
		platform.top_radius = 0.52
		platform.bottom_radius = 0.54
		platform.radial_segments = 48
		var stand: MeshInstance3D = FightMesh.instance(_scene, platform, FighterFigure._material(Color("#3b4656")), Vector3(-0.7 + i * 1.4, -0.04, 0))
		stand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var figure := FighterFigure.new(ArenaView.FIGHTER_COLOURS[i], false, i)
		_scene.add_child(figure)
		_figures.append(figure)
	for turn: Array in [["front", 0.0], ["three-quarter", 0.48], ["back", PI]]:
		for i in 2:
			var at := Vector2(-0.7 + i * 1.4, 0)
			_figures[i].show_state(_sim, i, at, at + Vector2(0, -1).rotated(turn[1]), 1.0)
		await _save(turn[0])
	_scene.queue_free()
	await process_frame
	quit()


func _save(label: String) -> void:
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var path: String = _out.path_join(label + ".png")
	var error: Error = root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Character preview failed: %s (%s)" % [path, error])
		quit(1)
	print("Character preview: ", path)
