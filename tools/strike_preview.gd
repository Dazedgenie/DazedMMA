extends SceneTree
## Arranged strike clips for reviewing D281 (strikes that connect): each strike thrown in range and landing,
## blocked, slipped or checked, missing, or thrown out of range, in the real fight scene. Needs a display.
##   godot --path . --script res://tools/strike_preview.gd -- --out=res://build/strikes
##   ffmpeg -framerate 24 -i build/strikes/frame-%04d.png -c:v libx264 -pix_fmt yuv420p build/strikes.mp4
## Frames run at fight time (24 a fight second); slow the video down with ffmpeg's setpts to study one.
## The preview arranges a throwaway fight's state directly; no fight rules or saved fights are changed.

const FPS: int = 24
## [strike, outcome, the defender's move (or ""), the sim band they stand at]
const CASES := [
	["jab", "landed", "", "mid"], ["jab", "missed", "slip", "mid"],
	["cross", "landed", "", "mid"], ["cross", "covered", "cover_up", "mid"], ["cross", "short", "", "long"],
	["hook", "landed", "", "pocket"], ["uppercut", "landed", "", "pocket"],
	["body_kick", "landed", "", "long"], ["body_kick", "covered", "cover_up", "mid"],
	["leg_kick", "landed", "", "mid"], ["leg_kick", "checked", "check_kick", "mid"],
	["head_kick", "landed", "", "mid"], ["teep", "landed", "", "long"], ["calf_kick", "landed", "", "pocket"],
]

var _out := "res://build/strikes"
var _main: Node3D
var _frame: int = 0
var _title: Label


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
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
		await _case(case)
	print("Strike preview: %d frames in %s" % [_frame, _out])
	_main.queue_free()
	await process_frame
	quit()


func _case(case: Array) -> void:
	var strike: String = case[0]
	var outcome: String = case[1]
	var defence: String = case[2]
	_main.start_fight({"red": "boxer", "blue": "kicker", "seed": 35003, "sound_volume": 0.0, "easy": true})
	_main.set_process(false)
	_main.arena.set_process(false)
	_main.hud.visible = false
	var driver: FightDriver = _main.driver
	driver.held = true
	driver.normal_rate = 1.0
	var sim: FightSim = driver.sim
	var gap: float = float(Octagon.BAND_CENTRES[case[3]])
	# Side on to the camera, so the contact isn't hidden behind the man being hit.
	var across: Vector2 = Vector2(ArenaView.CAMERA_FROM.z, -ArenaView.CAMERA_FROM.x).normalized()
	sim.fighters[0].pos = -across * gap / 2.0
	sim.fighters[1].pos = across * gap / 2.0
	for i in 2:
		driver._before[i] = sim.fighters[i].pos
	_title.text = "%s: %s" % [String(sim.actions.get_action(strike).name), outcome]
	await _frames(sim, 18)
	var f: FighterState = sim.fighters[0]
	var d: FighterState = sim.fighters[1]
	for phase: String in ["telegraph", "windup", "active", "recovery"]:
		var ticks: int = maxi(1, sim.phase_ticks(f, strike, phase))
		for t in ticks:
			f.action_id = strike
			f.phase = phase
			f.phase_ticks_left = ticks - t
			if defence != "" and phase in ["windup", "active"]:
				d.action_id = defence
				d.phase = "active"
				d.phase_ticks_left = 1
			elif defence != "":
				d.clear_action()
			if phase == "active" and t == 0:
				_main.arena._on_event(_event(sim, strike, outcome))
				print("Contact: %s %s at frame %d" % [strike, outcome, _frame])
			sim.now += 1
			await _frames(sim, roundi(float(FPS) / FightClock.TICKS_PER_SECOND * (t + 1)) - roundi(float(FPS) / FightClock.TICKS_PER_SECOND * t))
	f.clear_action()
	d.clear_action()
	await _frames(sim, 18)


func _event(sim: FightSim, strike: String, outcome: String) -> FightEvent:
	var target: String = String(sim.actions.get_action(strike).strike.target)
	if outcome == "landed" or outcome == "covered":
		return FightEvent.new(sim.now, 1, FightEvent.STRIKE_LANDED, 0, {"action_id": strike, "target": target, "damage": 12, "covered": outcome == "covered"})
	var data := {"action_id": strike, "target": target, "chance": 0.0}
	match outcome:
		"short": data.reason = "out of range"
		"checked":
			data.reason = "defended"
			data.by_action = "check_kick"
		"missed":
			data.reason = "defended"
			data.by_action = "slip"
	return FightEvent.new(sim.now, 1, FightEvent.STRIKE_MISSED, 0, data)


func _frames(sim: FightSim, count: int) -> void:
	for n in count:
		_main.arena._process(1.0 / FPS)
		await process_frame
		await RenderingServer.frame_post_draw
		var path: String = _out.path_join("frame-%04d.png" % _frame)
		var error: Error = root.get_texture().get_image().save_png(path)
		if error != OK:
			push_error("Could not save strike preview: %s (%s)" % [path, error])
		_frame += 1
