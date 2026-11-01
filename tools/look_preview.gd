extends SceneTree
## Fighters who look different (D364): a line-up of fighters drawn with the skinned body, each with his own look
## (skin, hair, beard, height, reach and build), standing in his stance, with what he is under him.
## Needs a graphics display:
##   godot --path . --rendering-driver opengl3 --script res://tools/look_preview.gd -- --out=res://build/looks
## --men=boxer,wrestler,... picks the test fighters (default: all of them), five to a picture (lineup-1.png, ...);
## --plain draws everyone as the body was before D364.

var _out := "res://build/looks"
var _men: Array[String] = []
var _plain := false
var _scene: Node3D
var _camera: Camera3D
## Men to a picture, and the gap between them (metres).
const PER_PAGE: int = 5
const GAP: float = 0.95


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--men="):
			_men.assign(arg.trim_prefix("--men=").split(",", false))
		elif arg == "--plain":
			_plain = true
	_review.call_deferred()


func _review() -> void:
	root.size = Vector2i(2400, 1200)
	_scene = Node3D.new()
	root.add_child(_scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#202936")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#a9bad0")
	environment.environment.ambient_light_energy = 0.55
	_scene.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 160, 0)
	key.light_color = Color("#ffe5cc")
	key.light_energy = 0.95
	key.shadow_enabled = true
	_scene.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, -20, 0)
	fill.light_color = Color("#b0c9e3")
	fill.light_energy = 0.4
	_scene.add_child(fill)
	FightMesh.box(_scene, Vector3(40, 0.1, 20), FighterFigure._material(Color("#303a48")), Vector3(0, -0.05, 0))
	_camera = Camera3D.new()
	_scene.add_child(_camera)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.current = true
	var roster := FighterLibrary.load_dir()
	if _men.is_empty():
		_men.assign(roster.ids())
	var sim := FightSim.new(3, roster.make_pair(_men[0], _men[0]), ActionLibrary.load_dir())
	var page: int = 0
	for first in range(0, _men.size(), PER_PAGE):
		page += 1
		var men: Array[String] = []
		men.assign(_men.slice(first, first + PER_PAGE))
		var shown: Array[Node3D] = []
		var left: float = -GAP * (men.size() - 1) / 2.0
		for i in men.size():
			var profile: Dictionary = roster.profile(men[i])
			var figure := FighterFigure.new(ArenaView.FIGHTER_COLOURS[i % 2], profile.get("stance", "") == "southpaw", i % 2)
			_scene.add_child(figure)
			shown.append(figure)
			figure.use_body(ArenaView.BODY, {} if _plain else profile)
			var at := Vector2(left + i * GAP, 0)
			sim.fighters[0] = roster.make(men[i])
			figure.show_state(sim, 0, at, at + Vector2(0, 1), 1.0)
			var label := Label3D.new()
			var frame: Dictionary = profile.get("frame", {})
			var look: Dictionary = figure.look
			label.text = "%s\n%d cm, reach %d, %s\n%s" % [String(profile.get("name", "")), int(frame.get("height_cm", 0)),
				int(frame.get("reach_cm", 0)), String(frame.get("build", "")),
				"tone %d, %s %s, %s" % [int(look.get("skin", 0)), String(look.get("hair", "")).replace("_", " "),
				String(look.get("hair_style", "")), String(look.get("beard", ""))]]
			label.position = Vector3(at.x, 2.15, 0)
			label.pixel_size = 0.0016
			label.font_size = 28
			label.modulate = Color("#dfe6ef")
			_scene.add_child(label)
			shown.append(label)
		_camera.size = 2.5
		_camera.position = Vector3(0, 1.15, 7)
		_camera.look_at(Vector3(0, 1.15, 0))
		await _save("lineup-%d" % page)
		for node in shown:
			node.queue_free()
		await process_frame
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
		push_error("Look preview failed: %s (%s)" % [path, error])
		quit(1)
	print("Look preview: ", path)
