extends SceneTree
## Shows the heavy bag minigame (D412, docs/03 §13.6) with the round started at once and played perfectly (each shot
## loaded to meet the bag as it swings back), so its look can be checked. Needs a display; with Godot's movie maker:
##   godot --path . --fixed-fps 24 --write-movie build/bag/frame.png --script res://tools/bag_preview.gd -- --seconds=6
## --power= his Power (default 50), --fatigue= how tired (default 0), --seconds= how long to record (default 6).

var _screen: HeavyBagScreen
var _left: float = 6.0


func _initialize() -> void:
	var args: Dictionary = {}
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	_left = float(args.get("seconds", "6"))
	var drill := HeavyBag.new(float(args.get("power", "50")), float(args.get("fatigue", "0")))
	_screen = HeavyBagScreen.new(drill, "Heavy bag · week 1, Tuesday morning · fatigue 0")
	root.add_child(_screen)
	_screen.start()


func _process(delta: float) -> bool:
	_left -= delta
	var d: HeavyBag = _screen.drill
	var due: float = d.load_seconds if d.shots.is_empty() else d.back_at()
	if not d.holding() and _screen.now >= due - d.load_seconds:
		_screen.load_shot()
	if d.holding() and _screen.now >= due:
		_screen.let_go()
	return _left <= 0.0
