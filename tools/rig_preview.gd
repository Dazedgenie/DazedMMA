extends SceneTree
## The rig prototype's clips (D283): two FighterRigs posed against each other in the real fight scene, each
## pair pose blended from the one before and then held, side on. The clinch and the full guard are shown
## first as today's figures draw them, then as the rig does. Needs a display.
##   godot --path . --script res://tools/rig_preview.gd -- --out=res://build/rig [--stills] [--angle=40]
##   ffmpeg -framerate 24 -i build/rig/frame-%04d.png -c:v libx264 -pix_fmt yuv420p build/rig.mp4
## --stills saves one frame per pose (rig-<name>.png) instead of the clips; --angle turns the camera round the
## pair (degrees). --clinch saves the clinch poses built from grips (D286, clinch-<name>.png). --body puts the
## skinned Tripo body on the rigs (D284; --body=<file.glb> another Mixamo-rigged
## body). --takedowns saves the clinch takedowns' keys from the clinch to the landing (D288, takedown-<move>-<n>.png,
## n 0 the clinch) and the scramble and sprawl. --ground saves the ground positions with their grips (D289,
## ground-<name>.png, GroundPair.examples). Nothing in the fight or the fight screen changes.

const FPS: int = 24
const BLEND_FRAMES: int = 24
const HOLD_FRAMES: int = 20
## How far the camera sits from the pair, in metres (the fight camera is further out).
const CAMERA_DISTANCE: float = 3.9
## Today's figures for the same positions, shown before the rig's: [title, position, roles, grips].
const TODAY := {
	"The clinch (body lock)": ["Today: the body lock", "clinch", [PositionLibrary.NEUTRAL, PositionLibrary.NEUTRAL], [0, 0]],
	"The full guard": ["Today: the full guard", "full_guard", [PositionLibrary.TOP, PositionLibrary.BOTTOM],
		[FightSim.NO_GRIP, FightSim.NO_GRIP]],
}

var _out := "res://build/rig"
var _stills: bool = false
## --clinch: stills of the clinch poses built from grips (D286, ClinchPair.examples) instead of RigPairs.
var _clinch: bool = false
## --takedowns: stills along each clinch takedown's path (D288, TakedownPair).
var _takedowns: bool = false
## --ground: stills of the ground positions and their grips (D289, GroundPair).
var _ground: bool = false
var _angle: float = 0.0
var _main: Node3D
var _frame: int = 0
var _title: Label
var _rigs: Array[FighterRig] = []
## Skinned bodies the rigs drive (--body=, D284); the rigs stay hidden when there are any.
var _bodies: Array[SkinnedBody] = []
var _body_path: String = ""
var _pair_frame := Transform3D.IDENTITY


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg == "--stills":
			_stills = true
		elif arg == "--clinch":
			_clinch = true
		elif arg == "--takedowns":
			_takedowns = true
		elif arg == "--ground":
			_ground = true
		elif arg == "--body":
			_body_path = SkinnedBody.TRIPO_BODY
		elif arg.begins_with("--body="):
			_body_path = arg.trim_prefix("--body=")
		elif arg.begins_with("--angle="):
			_angle = float(arg.trim_prefix("--angle="))
	_capture.call_deferred()


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	_main = load("res://game/main.tscn").instantiate()
	root.add_child(_main)
	_main.record_dir = ""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var layer := CanvasLayer.new()
	root.add_child(layer)
	_title = Label.new()
	_title.position = Vector2(24, 18)
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_outline_color", Color.BLACK)
	_title.add_theme_constant_override("outline_size", 8)
	layer.add_child(_title)
	_start("standing", [PositionLibrary.NEUTRAL, PositionLibrary.NEUTRAL], [FightSim.NO_GRIP, FightSim.NO_GRIP])
	# Side on to the camera: the pair's Z runs across the picture.
	var across := Vector3(ArenaView.CAMERA_FROM.z, 0, -ArenaView.CAMERA_FROM.x).normalized()
	_pair_frame = Transform3D(Basis(Vector3.UP.cross(across).normalized(), Vector3.UP, across), Vector3.ZERO)
	for colour: Color in [Color.RED, Color.BLUE]:
		var rig := FighterRig.new(colour)
		_main.arena.add_child(rig)
		rig.visible = false
		_rigs.append(rig)
		if _body_path != "":
			var body := SkinnedBody.new()
			_main.arena.add_child(body)
			if not body.load_body(_body_path):
				quit(1)
				return
			body.visible = false
			rig.fit(body.measure())
			body.set_colour(colour)
			_bodies.append(body)
	if _ground:
		var examples: Dictionary = GroundPair.examples()
		for example_name: String in examples:
			var e: Array = examples[example_name]
			_title.text = _prefix() + example_name.replace("_", " ")
			_pose(GroundPair.build(e[0], e[1], e[2], e[3]).pair)
			_show_rigs(true)
			await _frames(1, "ground-%s.png" % example_name)
		# A sweep from the guard rolling them over (D289), in steps.
		var swept: Transform3D = _pair_frame * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, 0.55))
		var roll: Array = GroundPair.roll_path(GroundPair.build("full_guard").pair, _pair_frame,
			ClinchPair.swap(GroundPair.build("full_guard").pair), swept)
		for n in 9:
			_title.text = "%ssweep %d" % [_prefix(), n]
			_takedown_pose(roll, n / 4.0)
			await _frames(1, "ground-sweep-%d.png" % n)
	elif _takedowns:
		var start: Array = [ClinchPair.build([0, 0], ["l", "r"], -1, -1).pair, _pair_frame]
		for move: String in TakedownPair.MOVES:
			var path: Array = TakedownPair.path(move, start, _pair_frame.basis)
			var extra: Array = [["scramble", TakedownPair.to_scramble(path)]]
			if move == "double_leg":
				extra.append(["sprawl", TakedownPair.to_sprawl(path, 1.0)])
			for n in path.size():
				_title.text = "%s%s %d" % [_prefix(), move.replace("_", " "), n]
				_takedown_pose(path, float(n))
				await _frames(1, "takedown-%s-%d.png" % [move, n])
			if move == "double_leg" or move == "hip_throw":
				for n in path.size() * 2 - 2:  # The halves between, too.
					if n % 2 == 1:
						continue
					_title.text = "%s%s %.1f" % [_prefix(), move.replace("_", " "), n / 2.0 + 0.5]
					_takedown_pose(path, n / 2.0 + 0.5)
					await _frames(1, "takedown-%s-%d-half.png" % [move, n / 2])
			if move == "outside_trip" or move == "double_leg":
				for e: Array in extra:
					_title.text = "%s%s %s" % [_prefix(), move.replace("_", " "), e[0]]
					_takedown_pose(e[1], float((e[1] as Array).size() - 1))
					await _frames(1, "takedown-%s-%s.png" % [move, e[0]])
	elif _clinch:
		var examples: Dictionary = ClinchPair.examples()
		for example_name: String in examples:
			var e: Array = examples[example_name]
			_title.text = _prefix() + example_name.replace("_", " ")
			ClinchPair.pose(_rigs[0], _rigs[1], ClinchPair.build(e[0], e[1], e[2], e[3], e[4]), _pair_frame)
			for i in _bodies.size():
				_bodies[i].follow(_rigs[i])
			_show_rigs(true)
			await _frames(1, "clinch-%s.png" % example_name)
	elif _stills:
		var poses: Dictionary = RigPairs.all()
		for pose_name: String in poses:
			_title.text = _prefix() + pose_name
			_pose(poses[pose_name])
			_show_rigs(true)
			await _frames(1, "rig-%s.png" % pose_name)
	else:
		for clip: Array in RigPairs.clips():
			if TODAY.has(clip[0]):
				await _today(TODAY[clip[0]])
			await _clip(clip)
	print("Rig preview: %d frames in %s" % [_frame, _out])
	_main.queue_free()
	await process_frame
	quit()


## A throwaway fight to stand the venue up, with today's figures in `where`, side on, a clinch apart.
func _start(where: String, roles_in: Array, grips_in: Array) -> void:
	_main.start_fight({"red": "wrestler", "blue": "boxer", "seed": 35003, "sound_volume": 0.0, "easy": true})
	_main.set_process(false)
	_main.arena.set_process(false)
	_main.hud.visible = false
	var driver: FightDriver = _main.driver
	driver.held = true
	var sim: FightSim = driver.sim
	var roles: Array[String] = []
	for role: String in roles_in:
		roles.append(role)
	sim.situation.set_to(sim.positions.get_position(where), roles)
	var grips: Array[int] = []
	for g: int in grips_in:
		grips.append(g)
	sim.set_grips(grips)
	var across: Vector2 = Vector2(ArenaView.CAMERA_FROM.z, -ArenaView.CAMERA_FROM.x).normalized()
	sim.fighters[0].pos = across * ArenaView.CLINCH_BODY_GAP / 2.0
	sim.fighters[1].pos = -across * ArenaView.CLINCH_BODY_GAP / 2.0
	for i in 2:
		driver._before[i] = sim.fighters[i].pos


func _today(case: Array) -> void:
	_start(String(case[1]), case[2], case[3])
	_show_rigs(false)
	_title.text = String(case[0])
	await _frames(HOLD_FRAMES + 10)


func _clip(clip: Array) -> void:
	_show_rigs(true)
	_title.text = _prefix() + String(clip[0])
	var from: Dictionary = clip[1]
	var to: Dictionary = clip[2]
	if not from.is_empty():
		for n in BLEND_FRAMES:
			_pose(from, to, smoothstep(0.0, 1.0, float(n) / (BLEND_FRAMES - 1)))
			await _frames(1)
	_pose(to)
	await _frames(HOLD_FRAMES)


func _prefix() -> String:
	return "Rig: " if _bodies.is_empty() else "Tripo body: "


func _pose(pair: Dictionary, to: Dictionary = {}, t: float = 0.0) -> void:
	FighterRig.pose_pair(_rigs[0], _rigs[1], pair, _pair_frame, to, t)
	for i in _bodies.size():
		_bodies[i].follow(_rigs[i])


func _takedown_pose(path: Array, x: float) -> void:
	TakedownPair.pose_along(_rigs[0], _rigs[1], path, x)
	for i in _bodies.size():
		_bodies[i].follow(_rigs[i])
	_show_rigs(true)


func _show_rigs(on: bool) -> void:
	for rig in _rigs:
		rig.visible = on and _bodies.is_empty()
	for body in _bodies:
		body.visible = on
	for figure: FighterFigure in _main.arena.figures:
		figure.visible = not on


func _frames(count: int, still: String = "") -> void:
	for n in count:
		_main.arena._process(1.0 / FPS)
		# Closer than the fight camera, on the middle of the pair, and without the range tag.
		var arena: ArenaView = _main.arena
		arena._tag.visible = false
		arena.camera.position = Vector3(0, 0.7, 0) + (ArenaView.CAMERA_FROM.normalized() * CAMERA_DISTANCE).rotated(Vector3.UP, deg_to_rad(_angle))
		arena.camera.look_at(Vector3(0, 0.7, 0), Vector3.UP)
		if _rigs[0].visible or (not _bodies.is_empty() and _bodies[0].visible):
			for figure: FighterFigure in _main.arena.figures:
				figure.visible = false
		await process_frame
		await RenderingServer.frame_post_draw
		var path: String = _out.path_join(still if still != "" else "frame-%04d.png" % _frame)
		var error: Error = root.get_texture().get_image().save_png(path)
		if error != OK:
			push_error("Could not save rig preview: %s (%s)" % [path, error])
		_frame += 1
