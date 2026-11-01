class_name StyleLibrary
extends RefCounted
## Opponent style sheets loaded from data/styles/*.json (docs/09 style@1, docs/03 §6, D160).
##
## A sheet names a signature fighter in data/fighters (the style done well, at an
## average level) and says how far opponents made from it may differ. generate()
## turns a sheet, a seed and a quality level into a complete fighter@1 profile, the
## same every time for the same inputs, so the world can fill its divisions with
## fighters who share a style but not every number. The sheet's scouting card is
## the player-facing read on the style. Validated by tests/data/test_data_files.gd.

const DEFAULT_DIR := "res://data/styles/"
## How far a quality level may move every stat: -30 is a raw novice, +30 a contender.
const MAX_LEVEL: int = 30
## Reach keeps the signature fighter's ape index give or take this much (cm).
const REACH_SPREAD_CM: int = 3

static var _default: StyleLibrary
static var _stat_ids: Array = []

var _styles: Dictionary = {}  # id → style sheet Dictionary


static func load_dir(dir_path: String = DEFAULT_DIR) -> StyleLibrary:
	var library := StyleLibrary.new()
	var files: PackedStringArray = DirAccess.get_files_at(dir_path)
	files.sort()  # Same order on every platform.
	for file in files:
		if file.ends_with(".json"):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir_path.path_join(file)))
			if parsed is Dictionary:
				library.add(parsed)
	return library


## The data/ library, loaded once and shared (sheets don't change mid-run).
static func shared() -> StyleLibrary:
	if _default == null:
		_default = load_dir()
	return _default


func add(style: Dictionary) -> void:
	_styles[style.id] = style


func has(id: String) -> bool:
	return _styles.has(id)


func ids() -> Array:
	return _styles.keys()


func get_style(id: String) -> Dictionary:
	assert(_styles.has(id), "no style '%s' in data/styles" % id)
	return _styles[id]


## A new opponent of this style as a complete fighter@1 profile (no template).
## `level` (−MAX_LEVEL to +MAX_LEVEL) moves every stat; the seed picks the rest:
## each stat, style leaning and move preference a little off the signature
## fighter's, a personality of their own, height (reach follows), and stance.
## Moves, combinations, tells, gifts and flaws are the style's and stay as they are.
## Register the result with FighterLibrary.add() before a fight, so replays find it.
func generate(style_id: String, fighter_seed: int, level: int, roster: FighterLibrary, fighter_id: String = "", fighter_name: String = "") -> Dictionary:
	var style: Dictionary = get_style(style_id)
	var base: Dictionary = roster.profile(style.fighter)
	var v: Dictionary = style.variation
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%s:%d" % [style_id, fighter_seed]).hash()
	var shift: int = clampi(level, -MAX_LEVEL, MAX_LEVEL)

	var p: Dictionary = base.duplicate(true)
	p.id = fighter_id if fighter_id != "" else "%s_%d" % [style_id, fighter_seed]
	p.name = fighter_name if fighter_name != "" else "%s #%d" % [style.name, fighter_seed]
	p.template = null
	p.style_id = style_id
	p.level = shift

	var stats: Dictionary = {}
	for stat: String in StyleLibrary.stat_ids():
		var at: float = float(base.stats.get(stat, FighterState.DEFAULT_STAT))
		stats[stat] = clampi(roundi(at) + shift + rng.randi_range(-int(v.stats), int(v.stats)), 0, 100)
	p.stats = stats

	for leaning: String in StyleLeanings.LEANINGS:
		var lean: int = int(base.style.get(leaning, 0))
		p.style[leaning] = clampi(lean + rng.randi_range(-int(v.style), int(v.style)), -100, 100)

	var axes: Array = base.personality.keys()
	axes.sort()
	for axis: String in axes:
		p.personality[axis] = clampi(int(base.personality[axis]) + rng.randi_range(-int(v.personality), int(v.personality)), -100, 100)

	var actions: Array = base.tendencies.actions.keys()
	actions.sort()
	for action: String in actions:
		var weight: float = float(base.tendencies.actions[action])
		p.tendencies.actions[action] = snappedf(weight * (1.0 + rng.randf_range(-float(v.tendencies), float(v.tendencies))), 0.01)

	var ape: int = int(base.frame.reach_cm) - int(base.frame.height_cm)
	p.frame.height_cm = int(base.frame.height_cm) + rng.randi_range(-int(v.height_cm), int(v.height_cm))
	p.frame.reach_cm = int(p.frame.height_cm) + ape + rng.randi_range(-REACH_SPREAD_CM, REACH_SPREAD_CM)
	if rng.randf() < float(style.southpaw_chance):
		p.stance = "southpaw"
	return p


## The plan his corner gives a fighter (D324): his style sheet's `gameplan` ({approach, target,
## where}), the sheet being his `style_id` (a generated opponent) or the one built on his data file
## (an authored fighter). Empty when he has none: he fights his own way.
static func gameplan_of(profile: Dictionary, library: StyleLibrary = null) -> Dictionary:
	var styles: StyleLibrary = library if library != null else shared()
	var id: String = String(profile.get("style_id", ""))
	if id == "" or not styles.has(id):
		id = ""
		for style_id: String in styles.ids():
			if String(styles.get_style(style_id).get("fighter", "")) == String(profile.get("id", "")):
				id = style_id
				break
	if id == "":
		return {}
	var plan: Variant = styles.get_style(id).get("gameplan", {})
	return plan if plan is Dictionary else {}


## Every attribute id (data/enums/stats), sorted so generation rolls them in a fixed order.
static func stat_ids() -> Array:
	if _stat_ids.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/enums/stats.json"))
		_stat_ids = parsed.values.keys() if parsed is Dictionary else []
		_stat_ids.sort()
	return _stat_ids
