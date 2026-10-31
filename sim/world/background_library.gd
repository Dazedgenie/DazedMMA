class_name BackgroundLibrary
extends RefCounted
## Where a career's fighter comes from (docs/02 §1.2, D34; docs/03 §10.2, D302): the 12 backgrounds in
## data/backgrounds/*.json (docs/09 background@1). Until the childhood scenes exist (phase 2), the new-career screen picks
## one from a list; then the scenes will pick it, so the files stay.
##
## make_fighter() turns a background, a seed and the player's choices into a 16-year-old's fighter@1 profile: every stat
## rolled low (a teenager), his background's strengths higher and its weaknesses lower; his style leaning its way; a
## frame in its height range; a personality of his own, nudged its way; a hidden potential; 0 to 2 gifts and 0 to 1 flaw
## (D90), more likely the ones the background favours. His moves, combinations, tendencies and tells are those of the
## background's fighter in data/fighters (a wrestling family's son wrestles like the Wrestler, only worse). The same
## background, seed and choices always make the same fighter. Validated by tests/data/test_data_files.gd.

const DEFAULT_DIR := "res://data/backgrounds/"
const GIFTS_PATH := "res://data/enums/gifts.json"
const FLAWS_PATH := "res://data/enums/flaws.json"
## How old a new career's fighter is (Q3: the teen amateur years first, docs/03 §1).
const START_AGE: int = 16
## Every stat starts somewhere in this range: a 16-year-old who has trained a little.
const STAT_LOW: int = 20
const STAT_HIGH: int = 35
## His background's strengths start this much higher, its weaknesses this much lower.
const STRENGTH_BONUS: int = 12
const WEAKNESS_PENALTY: int = 8
## No stat starts under this.
const STAT_FLOOR: int = 5
## Potential (docs/02 §3.3, D136; hidden, scouted as a range): POTENTIAL_BASE plus two dice of 1 to POTENTIAL_DIE each,
## so 62 to 92 and most often around 77.
const POTENTIAL_BASE: int = 60
const POTENTIAL_DIE: int = 16
## The chance of 0, 1 and 2 gifts (D90: 0 to 2).
const GIFT_COUNT_ODDS: Array[float] = [0.45, 0.4, 0.15]
## The chance of a flaw (D90: 0 to 1).
const FLAW_CHANCE: float = 0.35
## A gift or flaw the background doesn't name has this weight; `gift_weights` and `flaw_weights` give the rest.
const DEFAULT_WEIGHT: float = 1.0
## Each personality axis: the background's lean, then ± this much at random.
const PERSONALITY_SPREAD: int = 30
## Each style leaning: the background's lean, then ± this much at random.
const STYLE_SPREAD: int = 10
## Reach is his height plus this many cm (from, to).
const REACH_OVER_HEIGHT: Array[int] = [-2, 6]

static var _default: BackgroundLibrary

var _backgrounds: Dictionary = {}  # id → background Dictionary
var _gifts: Array = []
var _flaws: Array = []


static func load_dir(dir_path: String = DEFAULT_DIR) -> BackgroundLibrary:
	var library := BackgroundLibrary.new()
	var files: PackedStringArray = DirAccess.get_files_at(dir_path)
	files.sort()  # Same order on every platform.
	for file in files:
		if file.ends_with(".json"):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir_path.path_join(file)))
			if parsed is Dictionary:
				library.add(parsed)
	return library


## The data/ library, loaded once and shared.
static func shared() -> BackgroundLibrary:
	if _default == null:
		_default = load_dir()
	return _default


func _init() -> void:
	_gifts = _enum_ids(GIFTS_PATH)
	_flaws = _enum_ids(FLAWS_PATH)


func add(background: Dictionary) -> void:
	_backgrounds[background.id] = background


func has(id: String) -> bool:
	return _backgrounds.has(id)


## Every background id, sorted by its name (the order the new-career screen lists them).
func ids() -> Array:
	var out: Array = _backgrounds.keys()
	out.sort_custom(func(a: String, b: String) -> bool: return String(_backgrounds[a].name) < String(_backgrounds[b].name))
	return out


func get_background(id: String) -> Dictionary:
	assert(_backgrounds.has(id), "no background '%s' in data/backgrounds" % id)
	return _backgrounds[id]


## A new 16-year-old from this background, as a complete fighter@1 profile with `age`, `potential` and `background`.
## `choices`: `name` and `stance` ("orthodox" or "southpaw"; left out, he's orthodox unless he rolls Natural southpaw).
func make_fighter(background_id: String, fighter_seed: int, roster: FighterLibrary, choices: Dictionary = {}) -> Dictionary:
	var bg: Dictionary = get_background(background_id)
	var base: Dictionary = roster.profile(String(bg.fighter))
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%s:%d" % [background_id, fighter_seed]).hash()

	var p: Dictionary = base.duplicate(true)
	p.id = "%s_%d" % [background_id, fighter_seed]
	p.name = String(choices.get("name", "")) if String(choices.get("name", "")) != "" else String(bg.name)
	p.template = null
	p.background = background_id
	p.age = START_AGE
	p.erase("style_id")
	p.erase("level")

	var stats: Dictionary = {}
	for stat: String in StyleLibrary.stat_ids():
		var value: int = rng.randi_range(STAT_LOW, STAT_HIGH)
		if stat in bg.strengths:
			value += STRENGTH_BONUS
		elif stat in bg.weaknesses:
			value -= WEAKNESS_PENALTY
		stats[stat] = maxi(value, STAT_FLOOR)
	p.stats = stats

	var style: Dictionary = {}
	for leaning: String in StyleLeanings.LEANINGS:
		style[leaning] = clampi(int(bg.style.get(leaning, 0)) + rng.randi_range(-STYLE_SPREAD, STYLE_SPREAD), -100, 100)
	p.style = style

	var personality: Dictionary = {}
	for axis: String in ["ego", "discipline", "coachable", "loyal"]:
		personality[axis] = clampi(int(bg.get("personality", {}).get(axis, 0)) + rng.randi_range(-PERSONALITY_SPREAD, PERSONALITY_SPREAD), -100, 100)
	p.personality = personality

	var heights: Array = bg.frame.height_cm
	var height: int = rng.randi_range(int(heights[0]), int(heights[1]))
	p.frame = { "height_cm": height, "reach_cm": height + rng.randi_range(REACH_OVER_HEIGHT[0], REACH_OVER_HEIGHT[1]),
		"build": String(bg.frame.build) }

	p.potential = POTENTIAL_BASE + rng.randi_range(1, POTENTIAL_DIE) + rng.randi_range(1, POTENTIAL_DIE)

	var stance: String = String(choices.get("stance", ""))
	var gift_pool: Array = _gifts.duplicate()
	if stance == "orthodox":
		gift_pool.erase("natural_southpaw")  # He chose to stand orthodox.
	var gifts: Array = []
	for i in _count(rng.randf(), GIFT_COUNT_ODDS):
		var gift: String = _pick(rng, gift_pool, bg.get("gift_weights", {}))
		if gift != "":
			gifts.append(gift)
			gift_pool.erase(gift)
	p.gifts = gifts
	p.flaws = []
	if rng.randf() < FLAW_CHANCE:
		p.flaws = [_pick(rng, _flaws.duplicate(), bg.get("flaw_weights", {}))]
	p.stance = stance if stance != "" else ("southpaw" if "natural_southpaw" in gifts else "orthodox")
	return p


## How many: the first n whose odds (added up) pass the roll.
static func _count(roll: float, odds: Array[float]) -> int:
	var total: float = 0.0
	for n in odds.size():
		total += odds[n]
		if roll < total:
			return n
	return odds.size() - 1


## One id from the pool, each as likely as its weight (DEFAULT_WEIGHT unless `weights` names it). "" from an empty pool.
static func _pick(rng: RandomNumberGenerator, pool: Array, weights: Dictionary) -> String:
	var total: float = 0.0
	for id: String in pool:
		total += float(weights.get(id, DEFAULT_WEIGHT))
	var roll: float = rng.randf() * total
	for id: String in pool:
		roll -= float(weights.get(id, DEFAULT_WEIGHT))
		if roll < 0.0:
			return id
	return String(pool[-1]) if not pool.is_empty() else ""


## An enum file's ids, sorted (so rolls happen in a fixed order).
static func _enum_ids(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var out: Array = parsed.values.keys() if parsed is Dictionary else []
	out.sort()
	return out
