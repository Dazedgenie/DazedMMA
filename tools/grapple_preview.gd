extends SceneTree
## Arranged grappling clips for reviewing D282 (a pose for every grappling move): the clinch grips, each grip and
## clinch move, ground and pound, covering up and turning away, the submissions, leg locks, sweeps, passes and
## throws, in the real fight scene. Needs a display.
##   godot --path . --script res://tools/grapple_preview.gd -- --out=res://build/grapples [--only=pummel,armbar]
##   ffmpeg -framerate 24 -i build/grapples/frame-%04d.png -c:v libx264 -pix_fmt yuv420p build/grapples.mp4
## Frames run at fight time (24 a fight second). The preview arranges a throwaway fight's state directly;
## no fight rules or saved fights are changed.

const FPS: int = 24
const T := PositionLibrary.TOP
const B := PositionLibrary.BOTTOM
const N := PositionLibrary.NEUTRAL
const X := FightSim.NO_GRIP
## [title, position, [red role, blue role], grips [side 0, side 1] (clinch only), who moves (0 red, 1 blue),
## the move, and whether it ends in a hold (a submission locked in, held for a second)]
const CASES := [
	["Hand fighting", "clinch", [N, N], [X, X], 0, "", false],
	["Red has an underhook", "clinch", [N, N], [0, X], 0, "", false],
	["Red has the body lock", "clinch", [N, N], [0, 0], 0, "", false],
	["Red pummels for the underhook", "clinch", [N, N], [1, X], 0, "pummel", false],
	["Red strips the underhook", "clinch", [N, N], [1, X], 0, "strip_grip", false],
	["Red goes for the collar tie", "clinch", [N, N], [X, X], 0, "collar_tie", false],
	["Red drives him to the fence", "clinch", [N, N], [0, X], 0, "fence_drive", false],
	["Red turns him onto the fence", "clinch", [N, N], [0, X], 0, "turn_him", false],
	["Blue spins off the fence", "clinch", [N, N], [0, X], 1, "spin_off", false],
	["Knee with the underhook in", "clinch", [N, N], [0, X], 0, "knee", false],
	["Hip throw", "clinch", [N, N], [0, 0], 0, "hip_throw", false],
	["Outside trip", "clinch", [N, N], [0, X], 0, "outside_trip", false],
	["Guard pull", "clinch", [N, N], [X, X], 0, "guard_pull", false],
	["Guillotine", "clinch", [N, N], [X, X], 0, "guillotine", true],
	["Foot sweep", "standing", [N, N], [X, X], 0, "foot_sweep", false],
	["Hammerfist from the guard", "full_guard", [T, B], [X, X], 0, "hammerfist", false],
	["Body punch from side control", "side_control", [T, B], [X, X], 0, "ground_body_punch", false],
	["Posture-up bomb", "full_guard", [T, B], [X, X], 0, "posture_bomb", false],
	["Covering up under mount", "mount", [T, B], [X, X], 1, "ground_cover", false],
	["Turning away under mount", "mount", [T, B], [X, X], 1, "turn_away", false],
	["Bridge out of mount", "mount", [T, B], [X, X], 1, "bridge", false],
	["Guard pass", "full_guard", [T, B], [X, X], 0, "guard_pass", false],
	["Sweep from the guard", "full_guard", [T, B], [X, X], 1, "sweep", false],
	["Taking mount", "side_control", [T, B], [X, X], 0, "take_mount", false],
	["Taking the back", "mount", [T, B], [X, X], 0, "take_back", false],
	["Recovering guard", "side_control", [T, B], [X, X], 1, "recover_guard", false],
	["Escaping the back", "back_control", [T, B], [X, X], 1, "escape_back", false],
	["Scramble", "scramble", [N, N], [X, X], 0, "scramble", false],
	["Triangle", "full_guard", [T, B], [X, X], 1, "triangle", true],
	["Armbar from the guard", "full_guard", [T, B], [X, X], 1, "armbar", true],
	["Armbar from mount", "mount", [T, B], [X, X], 0, "armbar", true],
	["Rear-naked choke", "back_control", [T, B], [X, X], 0, "rear_naked_choke", true],
	["Arm-triangle", "side_control", [T, B], [X, X], 0, "arm_triangle", true],
	["Heel hook", "full_guard", [T, B], [X, X], 1, "heel_hook", true],
]

var _out := "res://build/grapples"
var _only: Array[String] = []
var _main: Node3D
var _frame: int = 0
var _title: Label


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			for id: String in arg.trim_prefix("--only=").split(","):
				_only.append(id)
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
	for case: Array in CASES:
		if _only.is_empty() or _only.has(String(case[5])) or _only.has(String(case[1])):
			await _case(case)
	print("Grapple preview: %d frames in %s" % [_frame, _out])
	_main.queue_free()
	await process_frame
	quit()


func _case(case: Array) -> void:
	_main.start_fight({"red": "wrestler", "blue": "boxer", "seed": 35003, "sound_volume": 0.0, "easy": true})
	_main.set_process(false)
	_main.arena.set_process(false)
	_main.hud.visible = false
	var driver: FightDriver = _main.driver
	driver.held = true
	driver.normal_rate = 1.0
	var sim: FightSim = driver.sim
	var roles: Array[String] = []
	for role: String in case[2]:
		roles.append(role)
	sim.situation.set_to(sim.positions.get_position(String(case[1])), roles)
	var grips: Array[int] = []
	for g: int in case[3]:
		grips.append(g)
	sim.set_grips(grips)
	# Side on to the camera, a clinch apart (the view lays the ground positions out itself).
	var across: Vector2 = Vector2(ArenaView.CAMERA_FROM.z, -ArenaView.CAMERA_FROM.x).normalized()
	var gap: float = 0.9 if String(case[1]) != "standing" else float(Octagon.BAND_CENTRES["pocket"])
	sim.fighters[0].pos = -across * gap / 2.0
	sim.fighters[1].pos = across * gap / 2.0
	for i in 2:
		driver._before[i] = sim.fighters[i].pos
	_title.text = String(case[0])
	print("Case: %s from frame %d" % [_title.text, _frame])
	await _frames(sim, 24)
	var move: String = case[5]
	if move == "":
		await _frames(sim, 24)
		return
	var who: int = case[4]
	var f: FighterState = sim.fighters[who]
	for phase: String in ["telegraph", "windup", "active", "recovery"]:
		var ticks: int = sim.phase_ticks(f, move, phase)
		if bool(case[6]) and phase == "recovery":
			break
		for t in ticks:
			f.action_id = move
			f.phase = phase
			f.phase_ticks_left = ticks - t
			sim.now += 1
			await _frames(sim, roundi(float(FPS) / FightClock.TICKS_PER_SECOND * (t + 1)) - roundi(float(FPS) / FightClock.TICKS_PER_SECOND * t))
	f.clear_action()
	if bool(case[6]):  # Locked in: held for a second, posed as where it was locked from.
		sim.set("_hold", { "attacker": who, "action_id": move, "danger": 50.0, "beats": 0, "next_at": sim.now + 100,
			"from": String(case[1]), "from_roles": roles.duplicate(), "near": false })
		await _frames(sim, 30)
		sim.set("_hold", {})
	await _frames(sim, 18)


func _frames(sim: FightSim, count: int) -> void:
	for n in count:
		_main.arena._process(1.0 / FPS)
		await process_frame
		await RenderingServer.frame_post_draw
		var path: String = _out.path_join("frame-%04d.png" % _frame)
		var error: Error = root.get_texture().get_image().save_png(path)
		if error != OK:
			push_error("Could not save grapple preview: %s (%s)" % [path, error])
		_frame += 1
