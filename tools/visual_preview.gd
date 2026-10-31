extends SceneTree
## Reproducible rendered samples, using the real game scene and HUD. Needs a graphics display.
## godot --path . --script res://tools/visual_preview.gd -- --out=res://build/visual
## The arranged poses live only in this preview; no fight rules or saved data are changed.

var _main: Node3D
var _out := "res://build/visual"
var _size := Vector2i(1600, 900)


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--720p":
			_size = Vector2i(1280, 720)
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	_capture.call_deferred()


func _capture() -> void:
	root.size = _size
	_main = load("res://game/main.tscn").instantiate()
	root.add_child(_main)
	_main.record_dir = ""
	_main.start_fight({"red": "boxer", "blue": "wrestler", "seed": 35003, "sound_volume": 0.0, "easy": true})
	_main.driver.held = true
	_main.hud._banner_left = 0.0
	var sim: FightSim = _main.driver.sim
	sim.fighters[0].pos = Vector2(-0.7, 0.7)
	sim.fighters[1].pos = Vector2(0.7, -0.7)
	_sync_spots()
	await _save("standing")
	_main.hud.visible = false
	await _save("arena")
	_main.hud.visible = true
	sim.fighters[0].action_id = "jab"
	sim.fighters[0].phase = "active"
	sim.fighters[1].damage.head = 250
	await _save("striking")
	sim.fighters[0].action_id = "body_kick"
	await _save("kicking")
	sim.fighters[0].clear_action()
	sim.apply_transition(0, "clinch_entry")
	_sync_spots()
	await _save("clinch")
	sim.apply_transition(0, "double_leg")
	_sync_spots()
	await _save("ground")
	sim.apply_transition(0, "guard_pass")
	await _save("side-control")
	sim.apply_transition(0, "take_mount")
	await _save("mount")
	_main.start_fight({"red": "boxer", "blue": "wrestler", "seed": 35003, "sound_volume": 0.0, "easy": true})
	_main.driver.held = true
	_main.hud._banner_left = 0.0
	sim = _main.driver.sim
	sim.fighters[0].pos = Vector2(2.8, 1.8)
	sim.fighters[1].pos = Vector2(3.8, 0.6)
	_sync_spots()
	await _save("fence")
	_main.queue_free()
	await process_frame
	quit()


func _sync_spots() -> void:
	for i in 2:
		_main.driver._before[i] = _main.driver.sim.fighters[i].pos


func _save(label: String) -> void:
	for frame in 75:
		# Fixed preview delta settles camera and pose even on an uncapped renderer.
		_main.arena._process(1.0 / 30.0)
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var path: String = _out.path_join(label + ".png")
	var error: Error = root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Could not save visual preview: %s (%s)" % [path, error])
		quit(1)
	print("Visual preview: ", path)
