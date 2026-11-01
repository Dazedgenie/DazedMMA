extends SceneTree
## Fixed-frame capture of a real seeded fight. Needs a display; never saves a fight.
## --red=, --blue= and --seed= pick another fight (default the Boxer against the Kicker, seed 35003). --from=
## plays the fight's first seconds without saving frames (D288: to get to a moment quickly); --seconds= how long
## to save after that.
## Encode with ffmpeg -framerate 24 -i build/motion/frame-%04d.png -c:v libx264 -pix_fmt yuv420p build/motion.mp4

const FPS: int = 24
var _out := "res://build/motion"
var _seconds: float = 12.0
var _from: float = 0.0
var _setup := {"red": "boxer", "blue": "kicker", "seed": 35003, "sound_volume": 0.0, "easy": true}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		if arg.begins_with("--seconds="):
			_seconds = float(arg.trim_prefix("--seconds="))
		if arg.begins_with("--from="):
			_from = float(arg.trim_prefix("--from="))
		for key: String in ["red", "blue", "seed"]:
			if arg.begins_with("--%s=" % key):
				var value: String = arg.trim_prefix("--%s=" % key)
				_setup[key] = int(value) if key == "seed" else value
	_capture.call_deferred()


func _capture() -> void:
	root.size = Vector2i(960, 540)
	var main: Node3D = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	main.record_dir = ""
	main.start_fight(_setup)
	main.set_process(false)
	main.arena.set_process(false)
	main.hud.visible = false
	main.driver.normal_rate = 1.0
	main.driver.auto_slow = false
	main.driver.flourishes = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	for frame in roundi(_from * FPS):  # Played, not saved.
		main.driver.advance(1.0 / FPS)
		main.arena._process(1.0 / FPS)
	for frame in roundi(_seconds * FPS):
		main.driver.advance(1.0 / FPS)
		main.arena._process(1.0 / FPS)
		await process_frame
		await RenderingServer.frame_post_draw
		var path: String = _out.path_join("frame-%04d.png" % frame)
		var error: Error = root.get_texture().get_image().save_png(path)
		if error != OK:
			push_error("Could not save motion frame: %s (%s)" % [path, error])
			quit(1)
			return
		if frame % FPS == 0:
			print("Motion preview: %s / %s seconds" % [frame / FPS, _seconds])
	main.queue_free()
	await process_frame
	quit()
