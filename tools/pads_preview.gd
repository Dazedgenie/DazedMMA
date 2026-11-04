extends SceneTree
## Shows the Thai pads minigame (D413, docs/03 §13.7) with the round started at once and played perfectly (each pad
## struck a moment after it goes up), so its look can be checked. Needs a display; with Godot's movie maker:
##   godot --path . --fixed-fps 24 --write-movie build/pads/frame.png --script res://tools/pads_preview.gd -- --seconds=8
## --kicking= his Kicking (default 50), --fatigue= how tired (default 0), --seed= the round (default 1),
## --seconds= how long to record (default 8), --react= seconds after a pad goes up to strike it (default 0.15).

var _screen: ThaiPadsScreen
var _left: float = 8.0
var _react: float = 0.15


func _initialize() -> void:
	var args: Dictionary = {}
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	_left = float(args.get("seconds", "8"))
	_react = float(args.get("react", "0.15"))
	var drill := ThaiPads.new(float(args.get("kicking", "50")), float(args.get("fatigue", "0")), int(args.get("seed", "1")))
	_screen = ThaiPadsScreen.new(drill, "Thai pads · week 1, Tuesday evening · fatigue 0")
	root.add_child(_screen)
	_screen.start()


func _process(delta: float) -> bool:
	_left -= delta
	var pad: Dictionary = _screen.drill.pad_at(_screen.now)
	if not pad.is_empty() and pad.result == "" and _screen.now >= float(pad.t) + _react:
		_screen.strike(String(pad.key))
	return _left <= 0.0
