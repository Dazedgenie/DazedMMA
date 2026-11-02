extends SceneTree
## Damage on the body (D375-D378): one fighter drawn at a few stages of a hard fight, his face up close and his whole
## body, each picture side by side from fresh to a war. Needs a graphics display:
##   godot --path . --rendering-driver opengl3 --script res://tools/damage_preview.gd -- --out=res://build/damage
## --man=brawler picks the test fighter (default the Boxer). Writes face.png, face-side.png and body.png.

var _out := "res://build/damage"
var _man := "boxer"
## The stages: [label, eyes' swelling (left, right), ribs, legs (left, right), cut (left, right), trickle (left,
## right), gloves, sweat, flush].
const STAGES := [
	["fresh", [0.0, 0.0], 0.0, [0.0, 0.0], [false, false], [0.0, 0.0], 0.0, 0.0, 0.0],
	["round 1", [0.25, 0.05], 0.2, [0.35, 0.0], [false, false], [0.0, 0.0], 0.0, 0.3, 0.0],
	["cut", [0.5, 0.15], 0.4, [0.6, 0.1], [true, false], [0.3, 0.0], 0.2, 0.55, 0.4],
	["a war", [1.0, 0.45], 0.8, [1.0, 0.3], [true, true], [1.0, 0.6], 0.8, 0.9, 1.0],
]


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--man="):
			_man = arg.trim_prefix("--man=")
	_review.call_deferred()


func _review() -> void:
	root.size = Vector2i(480, 560)
	var scene := Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#202936")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#a9bad0")
	environment.environment.ambient_light_energy = 0.55
	scene.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, 20, 0)
	key.light_color = Color("#ffe5cc")
	key.light_energy = 1.0
	scene.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -60, 0)
	fill.light_color = Color("#b0c9e3")
	fill.light_energy = 0.45
	scene.add_child(fill)
	FightMesh.box(scene, Vector3(40, 0.1, 20), FighterFigure._material(Color("#303a48")), Vector3(0, -0.05, 0))
	var roster := FighterLibrary.load_dir()
	var sim := FightSim.new(3, roster.make_pair(_man, _man), ActionLibrary.load_dir())
	var profile: Dictionary = roster.profile(_man)
	# One man, marked by each stage in turn (a skinned body drawn away from where it was posed can be culled).
	var figure := FighterFigure.new(ArenaView.FIGHTER_COLOURS[0], false, 0)
	scene.add_child(figure)
	figure.use_body(ArenaView.BODY, profile)
	for n in 2:
		figure.show_state(sim, 0, Vector2.ZERO, Vector2(0, 1), 1.0)
	var stages: Array[BodyMarks] = []
	for stage: Array in STAGES:
		var marks := BodyMarks.new()
		marks.swell.assign(stage[1])
		marks.body = float(stage[2])
		marks.legs.assign(stage[3])
		marks.cut.assign(stage[4])
		marks.bleed.assign(stage[5])
		marks.glove_blood = float(stage[6])
		marks.sweat = float(stage[7])
		marks.flush = float(stage[8])
		stages.append(marks)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.current = true
	# His face, then from his left, then the whole body; each a strip of the stages. He faces +Z, his left +X.
	for shot in [["face", Vector3(0, 0, 1)], ["face-side", Vector3(0.8, 0, 0.6)], ["body", Vector3(0.3, 0, 1)]]:
		var images: Array[Image] = []
		for marks in stages:
			figure.body.set_damage(marks)
			var head: Vector3 = figure.body._world_at("Head") + Vector3(0, 0.06, 0)
			var hips: Vector3 = figure.body.hips_at()
			var look_at: Vector3 = head if String(shot[0]).begins_with("face") else hips + Vector3(0, 0.15, 0)
			var away: Vector3 = Vector3(shot[1]).normalized()
			camera.fov = 22.0 if String(shot[0]).begins_with("face") else 40.0
			var reach: float = 0.75 if String(shot[0]).begins_with("face") else 2.9
			camera.look_at_from_position(look_at + away * reach + Vector3(0, 0.03, 0), look_at)
			for frame in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			images.append(root.get_texture().get_image())
		var sheet := Image.create(images[0].get_width() * images.size(), images[0].get_height(), false, images[0].get_format())
		for i in images.size():
			sheet.blit_rect(images[i], Rect2i(Vector2i.ZERO, images[i].get_size()), Vector2i(i * images[0].get_width(), 0))
		var path: String = _out.path_join("%s.png" % shot[0])
		sheet.save_png(path)
		print("Damage preview: ", ProjectSettings.globalize_path(path))
	quit()
