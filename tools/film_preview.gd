extends SceneTree
## Shows the film study minigame (D410, docs/03 §13.4) on a man of a style, starting the tape at once, so its look can
## be checked. Needs a display; run it with Godot's movie maker to write frames:
##   godot --path . --fixed-fps 24 --write-movie build/film/frame.png --script res://tools/film_preview.gd -- --style=kicker
## --style= and --seed= pick the man; --seconds= how long to record (default 8); --name shows the naming panel at the end.

var _screen: FilmStudyScreen
var _left: float = 8.0
var _name: bool = false


func _initialize() -> void:
	var args: Dictionary = {}
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var s: int = int(args.get("seed", "1"))
	_left = float(args.get("seconds", "8"))
	_name = args.has("name")
	var man: Dictionary = FilmStudy.sample_man(String(args.get("style", "kicker")), s)
	var study := FilmStudy.new(man, {}, true, 50.0, s)
	_screen = FilmStudyScreen.new(study, "Film study · week 1, Saturday morning")
	root.add_child(_screen)
	_screen.start()


func _process(delta: float) -> bool:
	_left -= delta
	if _name and _left < 2.0 and _screen.stage == "watching":
		_screen.end_tape()
	return _left <= 0.0
