extends SceneTree
## Screenshots of the fight screen at its usual moments (D460): standing, the clinch, the ground, a hold locked in and
## the round break, from real seeded fights with the real game flow. Needs a display (xvfb-run is fine):
##   xvfb-run -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --script res://tools/hud_shots.gd -- --out=build/hud
## --out= the folder the PNGs go in (default build/hud_shots).

const SIZE := Vector2i(1920, 1080)

var _out: String = "build/hud_shots"
## --clean also saves each shot with the HUD hidden (for mock-ups drawn over the cage).
var _clean: bool = false
var _main: Node
## [file name, red, blue, seed, condition]
var _shots: Array = [
	["1-standing", "kicker", "boxer", 4101, "standing"],
	["2-clinch", "muay_thai", "wrestler", 4102, "clinch"],
	["3-ground", "wrestler", "bjj", 4103, "ground"],
	["4-hold", "bjj", "wrestler", 4104, "hold"],
	["5-round-break", "kicker", "boxer", 4101, "break"],
]


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		if arg == "--clean":
			_clean = true
	_run.call_deferred()


func _run() -> void:
	root.size = SIZE
	DirAccess.make_dir_recursive_absolute(_out)
	for shot: Array in _shots:
		await _take(shot)
	quit()


func _take(shot: Array) -> void:
	if _main != null:
		_main.queue_free()
		await process_frame
	_main = load("res://game/main.tscn").instantiate()
	root.add_child(_main)
	_main.record_dir = ""
	await process_frame
	var setup := {"red": shot[1], "blue": shot[2], "seed": shot[3], "sound_volume": 0.0, "easy": true, "moments": false,
		"label": "%s vs %s" % [shot[1], shot[2]],
		"rules": [[1, "check_the_leg_kick", 70.0], [2, "sprawl_on_the_shot", 60.0]],
		"gameplan": {"approach": "pressure", "target": "", "where": ""}}
	_main.start_fight(setup)
	await process_frame
	var sim: FightSim = _main.driver.sim
	var found: bool = false
	var min_tick: int = 35 * FightClock.TICKS_PER_SECOND
	for n in 3 * 5 * 60 * FightClock.TICKS_PER_SECOND:
		if sim.is_over():
			break
		_main.driver.step()
		if String(shot[4]) == "break":
			if _main.state == _main.ROUND_BREAK:
				found = true
				break
			continue
		if _main.state == _main.ROUND_BREAK:
			_main.hud.hide_dialog()
			_main._start_next_round()
			await process_frame
		if sim.now < min_tick:
			continue
		if _matches(sim, String(shot[4])):
			found = true
			break
	if String(shot[4]) != "break":
		_main.driver.held = true
	_main.driver._snap()
	for f in 20:
		await process_frame
	var image: Image = root.get_texture().get_image()
	image.save_png("%s/%s.png" % [_out, shot[0]])
	if _clean:
		_main.hud.visible = false
		for f in 3:
			await process_frame
		root.get_texture().get_image().save_png("%s/%s-clean.png" % [_out, shot[0]])
		_main.hud.visible = true
	print("%s: %s at %s" % [shot[0], "found" if found else "NOT FOUND", sim.clock.display()])


func _matches(sim: FightSim, what: String) -> bool:
	match what:
		"standing":
			return sim.situation.is_standing() and sim.situation.position != PositionLibrary.CLINCH
		"clinch":
			return sim.situation.position == PositionLibrary.CLINCH and sim.hold().is_empty()
		"ground":
			return not sim.situation.is_standing() and sim.hold().is_empty() and PositionDiagram.position_for(sim) != ""
		"hold":
			return not sim.hold().is_empty() and float(sim.hold().danger) > 30.0
	return false
