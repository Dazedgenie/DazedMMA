extends SceneTree
## Records the moments before, between and after the rounds (D390-D394) from a real seeded fight with the real game
## flow (the main scene running, its waits and its round panel). Needs a display; never saves a fight. Run it with
## Godot's movie maker at a fixed frame rate, which writes the frames:
##   godot --path . --fixed-fps 24 --write-movie build/moments/frame.png --script res://tools/moment_preview.gd -- --moment=break
## --moment= intro (the touch of gloves before the bell), break (the end of round 1: to the stools, the corner team,
## the round panel, then out again) or end (the fight's last seconds, the finish held, the celebration and the hand
## raised). --red=, --blue= and --seed= pick the fight (default the Dirty boxer against the Muay Thai fighter,
## seed 35001). --skip presses a key a second into each moment to show skipping.
## Encode with ffmpeg -framerate 24 -i build/moments/frame%08d.png -c:v libx264 -pix_fmt yuv420p build/moments.mp4

## Fight seconds before the end of round 1 (or the fight) that play on screen before the moment.
const LEAD_SECONDS: float = 2.0
## Between rounds: how long the corner sits before Start round is pressed, and how long after the walk out it keeps
## recording.
const SEATED_SECONDS: float = 9.0
const AFTER_SECONDS: float = 2.0

var _moment: String = "break"
var _skip: bool = false
var _setup := {"red": "dirty_boxer", "blue": "muay_thai", "seed": 35001, "sound_volume": 0.0, "easy": true, "moments": true}
var _main: Node
var _clock: float = 0.0
var _stage: String = ""
var _stage_time: float = 0.0
var _skipped: bool = false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--moment="):
			_moment = arg.trim_prefix("--moment=")
		if arg == "--skip":
			_skip = true
		for key: String in ["red", "blue", "seed"]:
			if arg.begins_with("--%s=" % key):
				var value: String = arg.trim_prefix("--%s=" % key)
				_setup[key] = int(value) if key == "seed" else value
	_start.call_deferred()


func _start() -> void:
	root.size = Vector2i(1280, 720)
	_main = load("res://game/main.tscn").instantiate()
	root.add_child(_main)
	_main.record_dir = ""
	_main.start_fight(_setup)
	if _moment == "intro":
		_stage = "intro"
		return
	# Get to LEAD_SECONDS before the bell (round 1's, or the fight's last) without drawing, then play it on screen.
	_main.arena.skip_moment()
	await process_frame
	var sim: FightSim = _main.driver.sim
	var until: int = _end_tick(sim) - roundi(LEAD_SECONDS * FightClock.TICKS_PER_SECOND)
	_main._moments = false  # Through any earlier round breaks without them.
	while sim.now < until and not sim.is_over():
		_main.driver.step()
		if _main.state == _main.ROUND_BREAK:
			_main.hud.hide_dialog()
			_main.state = _main.FIGHT
			_main.driver.resume()
	_main._moments = true
	_main.driver._snap()
	_stage = "lead"


## The tick round 1 ends at (break), or the fight's last (end), found on a copy of the fight.
func _end_tick(sim: FightSim) -> int:
	var copy := FightSim.new(sim.fight_seed, _main._roster.make_pair(String(_setup.red), String(_setup.blue)), sim.actions,
		Ruleset.load_id(Ruleset.DEFAULT_ID))
	copy.corners[1] = Corner.new(Corner.AI, sim.fight_seed)  # As main.start_fight sets the fight up.
	var their_plan: Dictionary = StyleLibrary.gameplan_of(copy.fighters[1].profile)
	if not their_plan.is_empty():
		copy.submit(FightCommand.set_gameplan(0, 1, their_plan))
	var ended: Array[int] = [-1]
	copy.event_emitted.connect(func(event: FightEvent) -> void:
		if _moment == "break" and event.type == FightEvent.ROUND_ENDED and ended[0] < 0:
			ended[0] = copy.now
		if event.type == FightEvent.FIGHT_ENDED and ended[0] < 0:
			ended[0] = copy.now)
	while ended[0] < 0 and not copy.is_over():
		copy.tick()
	return ended[0] if ended[0] >= 0 else copy.now


func _process(delta: float) -> bool:
	if _main == null or _stage == "":
		return false
	_clock += delta
	_stage_time += delta
	var arena: ArenaView = _main.arena
	if _skip and arena.moment_playing() and not _skipped and _stage_time > 1.0:
		arena.skip_moment()
		_skipped = true
	match _stage:
		"intro":
			if _clock > 0.5 and not arena.moment_playing():
				_next("after")
		"lead":
			if _moment == "break" and _main.state == _main.ROUND_BREAK:
				_next("seated")
			if _moment == "end" and _main.result.visible:
				_next("after")
		"seated":
			if _stage_time >= SEATED_SECONDS:
				_main._start_next_round()
				_next("walk_out")
		"walk_out":
			if _main.state == _main.FIGHT:
				_next("after")
		"after":
			if _stage_time >= AFTER_SECONDS:
				_main.queue_free()
				_main = null
				quit()
	return false


func _next(stage: String) -> void:
	_stage = stage
	_stage_time = 0.0
	_skipped = false
