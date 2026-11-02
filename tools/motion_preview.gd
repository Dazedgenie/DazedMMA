extends SceneTree
## Fixed-frame capture of a real seeded fight. Needs a display; never saves a fight.
## --red=, --blue= and --seed= pick another fight (default the Boxer against the Kicker, seed 35003). --from=
## plays the fight's first seconds without saving frames (D288: to get to a moment quickly); --seconds= how long
## to save after that. --hold=n plays on (unsaved, after --from) until the fight's nth submission is locked in
## (D366: to see a hold from the rig), then saves --seconds from there; the frames keep going after the fight ends.
## --move=<move>[:n] does the same for the nth time the fight screen starts posing that move from the rig (D368,
## D369: scramble, scramble_up, get_up, get_up_fence, stand_up, double_leg, catch_kick_single, follow_down, or a
## clinch takedown by its move's name). --knockdown=n starts saving a second before the fight's nth knockdown
## (D370: plays the fight once to find it). Every pass plays on through the round breaks.
## Encode with ffmpeg -framerate 24 -i build/motion/frame-%04d.png -c:v libx264 -pix_fmt yuv420p build/motion.mp4

const FPS: int = 24
var _out := "res://build/motion"
var _seconds: float = 12.0
var _from: float = 0.0
## --hold=n: start saving at the nth submission locked in (0: don't wait for one).
var _hold: int = 0
## --move=<move>[:n]: start saving the nth time that move is posed from the rig ("" don't wait for one).
var _move: String = ""
var _move_n: int = 1
## --knockdown=n: start saving KNOCKDOWN_LEAD s before the nth knockdown (0: don't wait for one). The fight is played
## once to find it, then again from the start.
var _knockdown: int = 0
const KNOCKDOWN_LEAD: float = 1.0
var _setup := {"red": "boxer", "blue": "kicker", "seed": 35003, "sound_volume": 0.0, "easy": true}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		if arg.begins_with("--seconds="):
			_seconds = float(arg.trim_prefix("--seconds="))
		if arg.begins_with("--from="):
			_from = float(arg.trim_prefix("--from="))
		if arg.begins_with("--hold="):
			_hold = int(arg.trim_prefix("--hold="))
		if arg.begins_with("--move="):
			var parts: PackedStringArray = arg.trim_prefix("--move=").split(":")
			_move = parts[0]
			_move_n = int(parts[1]) if parts.size() > 1 else 1
		if arg.begins_with("--knockdown="):
			_knockdown = int(arg.trim_prefix("--knockdown="))
		for key: String in ["red", "blue", "seed"]:
			if arg.begins_with("--%s=" % key):
				var value: String = arg.trim_prefix("--%s=" % key)
				_setup[key] = int(value) if key == "seed" else value
	_capture.call_deferred()


func _capture() -> void:
	root.size = Vector2i(960, 540)
	if _knockdown > 0:
		var at: float = _find_knockdown()
		if at < 0.0:
			push_error("Motion preview: no knockdown %d in this fight" % _knockdown)
			quit(1)
			return
		_from = maxf(0.0, at - KNOCKDOWN_LEAD)
		print("Motion preview: knockdown %d at %.1f s" % [_knockdown, at])
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
		main.driver.held = false  # On through the round breaks.
		main.driver.advance(1.0 / FPS)
		main.arena._process(1.0 / FPS)
	var locked: Array[int] = [0]
	main.driver.sim.event_emitted.connect(func(event: FightEvent) -> void:
		if event.type == FightEvent.SUBMISSION_LOCKED:
			locked[0] += 1)
	while locked[0] < _hold and not main.driver.sim.is_over():
		main.driver.held = false  # On through the round breaks.
		main.driver.advance(1.0 / FPS)
		main.arena._process(1.0 / FPS)
	if _hold > 0:
		print("Motion preview: hold %d at %.1f s" % [locked[0], main.driver.sim.now * FightClock.TICK_MS / 1000.0])
	var seen: int = 0
	while _move != "" and seen < _move_n and not main.driver.sim.is_over():
		var was: bool = not main.arena._takedown.is_empty()
		main.driver.held = false  # On through the round breaks.
		main.driver.advance(1.0 / FPS)
		main.arena._process(1.0 / FPS)
		var now: Dictionary = main.arena._takedown
		if not was and not now.is_empty() and String(now.get("move", now.get("action", ""))) == _move:
			seen += 1
	if _move != "":
		print("Motion preview: %s %d at %.1f s" % [_move, seen, main.driver.sim.now * FightClock.TICK_MS / 1000.0])
	for frame in roundi(_seconds * FPS):
		main.driver.held = false  # On through the round breaks.
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


## Seconds into the fight screen's playback (as --from counts them) of the nth knockdown, or -1.
func _find_knockdown() -> float:
	var main: Node3D = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	main.record_dir = ""
	main.start_fight(_setup)
	main.set_process(false)
	main.arena.set_process(false)
	main.driver.normal_rate = 1.0
	main.driver.auto_slow = false
	main.driver.flourishes = false
	var seen: Array[int] = [0]
	main.driver.sim.event_emitted.connect(func(event: FightEvent) -> void:
		if event.type == FightEvent.KNOCKDOWN:
			seen[0] += 1)
	var frames: int = 0
	while seen[0] < _knockdown and not main.driver.sim.is_over():
		main.driver.held = false  # On through the round breaks.
		main.driver.advance(1.0 / FPS)
		frames += 1
	var found: bool = seen[0] >= _knockdown
	root.remove_child(main)
	main.free()
	return float(frames) / FPS if found else -1.0
