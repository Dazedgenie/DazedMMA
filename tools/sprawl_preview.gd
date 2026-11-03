extends SceneTree
## Shows the sprawl reflex minigame (D411, docs/03 §13.5) with the drill started at once, so its look can be checked.
## Needs a display; run it with Godot's movie maker to write frames:
##   godot --path . --fixed-fps 24 --write-movie build/sprawl/frame.png --script res://tools/sprawl_preview.gd -- --seconds=8
## --level= his Takedown defence (default 50), --seed= the drill, --seconds= how long to record (default 8);
## --sprawl sprawls as each shot's wind-up starts (the level change), --bite on every feint too.

var _screen: SprawlReflexScreen
var _left: float = 8.0
var _sprawl: bool = false
var _bite: bool = false


func _initialize() -> void:
	var args: Dictionary = {}
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var s: int = int(args.get("seed", "1"))
	_left = float(args.get("seconds", "8"))
	_sprawl = args.has("sprawl")
	_bite = args.has("bite")
	var him: Dictionary = StyleLibrary.shared().generate("boxer", s, 0, FighterLibrary.load_dir())
	var drill := SprawlReflex.new(him, float(args.get("level", "50")), 0.0, s)
	_screen = SprawlReflexScreen.new(drill, "Sprawl drills · week 1, Monday evening · fatigue 0")
	root.add_child(_screen)
	_screen.start()


func _process(delta: float) -> bool:
	_left -= delta
	var p: FighterState = _screen.drill.sim.fighters[1]
	if (_sprawl and p.action_id == "double_leg" and p.phase == "windup") or (_bite and p.action_id == "feint"):
		_screen.sprawl()
	return _left <= 0.0
