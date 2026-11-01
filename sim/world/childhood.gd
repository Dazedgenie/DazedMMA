class_name Childhood
extends RefCounted
## The childhood scenes (docs/03 §11.2, D312; docs/02 §1.1, D8, D83): three short scenes at about 8, 12 and 15, one drawn
## per age from data/vignettes/ (docs/09 vignette@1), each with three choices. What he chose makes him:
##
##   background  the one his choices weighed most (each choice adds to one or two of the 12, data/backgrounds); a tie goes
##               to the one he chose later
##   flavour     the runner-up adds half a strength bonus to its first two strengths (a mixed childhood feels mixed)
##   stats       each choice nudges two or three stats by 2 to 6 points
##   personality each choice can nudge an axis (docs/11 §4.1), on top of the background's own lean
##   frame       a choice can lean his height (`height` −1 or +1: HEIGHT_PER_LEAN cm, reach with it)
##   people      a choice can bring in someone (his dad, a sensei, a best friend), named and kept on his card
##               (`named: false` for someone who goes by the role alone: data/names has men's first names only)
##   money       a choice can add to the money his background starts him with
##
## Pure and seeded: the same career seed draws the same scenes, and the same picks make the same fighter.

const DEFAULT_DIR := "res://data/vignettes/"
## The ages the scenes are at, in order.
const AGES: Array[int] = [8, 12, 15]
## The runner-up background's flavour: this share of BackgroundLibrary.STRENGTH_BONUS on its first SECOND_STRENGTHS.
const SECOND_SHARE: float = 0.5
const SECOND_STRENGTHS: int = 2
## A choice's `height` lean moves him this many cm (and his reach with it).
const HEIGHT_PER_LEAN: int = 4
const STAT_MAX: int = 100

static var _default: Childhood

var _scenes: Dictionary = {}  # id → vignette@1


static func load_dir(dir_path: String = DEFAULT_DIR) -> Childhood:
	var library := Childhood.new()
	var files: PackedStringArray = DirAccess.get_files_at(dir_path)
	files.sort()
	for file in files:
		if file.ends_with(".json"):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir_path.path_join(file)))
			if parsed is Dictionary:
				library.add(parsed)
	return library


static func shared() -> Childhood:
	if _default == null:
		_default = load_dir()
	return _default


func add(scene: Dictionary) -> void:
	_scenes[String(scene.id)] = scene


func has(id: String) -> bool:
	return _scenes.has(id)


func scene(id: String) -> Dictionary:
	return _scenes.get(id, {})


## The scenes at this age, sorted by id.
func ids_at(age: int) -> Array:
	var out: Array = []
	for id: String in _scenes:
		if int(_scenes[id].age) == age:
			out.append(id)
	out.sort()
	return out


## The scene for each age (AGES order) a career with this seed plays.
func draw(career_seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = ("childhood:%d" % career_seed).hash()
	var out: Array = []
	for age: int in AGES:
		var pool: Array = ids_at(age)
		if not pool.is_empty():
			out.append(pool[rng.randi_range(0, pool.size() - 1)])
	return out


## The choice `choice_id` in scene `scene_id` ({} when there's no such choice).
func choice(scene_id: String, choice_id: String) -> Dictionary:
	for ch: Dictionary in scene(scene_id).get("choices", []):
		if String(ch.id) == choice_id:
			return ch
	return {}


## The choices picked, oldest first, from `picks` ([{scene, choice}]); unknown ones are left out.
func chosen(picks: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for pick: Dictionary in picks:
		var ch: Dictionary = choice(String(pick.get("scene", "")), String(pick.get("choice", "")))
		if not ch.is_empty():
			out.append(ch)
	return out


## Each background's weight from these picks, and the two that lead: { weights, background, second }.
## A tie goes to the background chosen later; `second` is "" when nothing else got any weight.
func tally(picks: Array) -> Dictionary:
	var weights: Dictionary = {}
	var last_seen: Dictionary = {}
	var n: int = 0
	for ch: Dictionary in chosen(picks):
		for bg: String in ch.get("backgrounds", {}):
			weights[bg] = float(weights.get(bg, 0.0)) + float(ch.backgrounds[bg])
			last_seen[bg] = n
		n += 1
	var order: Array = weights.keys()
	order.sort_custom(func(a: String, b: String) -> bool:
		if weights[a] != weights[b]:
			return weights[a] > weights[b]
		if last_seen[a] != last_seen[b]:
			return last_seen[a] > last_seen[b]
		return a < b)
	return { "weights": weights, "background": String(order[0]) if order.size() > 0 else "",
		"second": String(order[1]) if order.size() > 1 else "" }


## The money his choices add.
func money(picks: Array) -> int:
	var total: int = 0
	for ch: Dictionary in chosen(picks):
		total += int(ch.get("money", 0))
	return total


## The profile a background made (BackgroundLibrary.make_fighter), changed by what he chose: the runner-up's flavour,
## every stat nudge, the personality nudges and his height.
func apply(profile_in: Dictionary, picks: Array, backgrounds: BackgroundLibrary) -> Dictionary:
	var p: Dictionary = profile_in.duplicate(true)
	var t: Dictionary = tally(picks)
	if t.second != "" and backgrounds.has(t.second):
		var strengths: Array = backgrounds.get_background(t.second).strengths
		for i in mini(SECOND_STRENGTHS, strengths.size()):
			var id: String = String(strengths[i])
			p.stats[id] = int(p.stats.get(id, 0)) + roundi(BackgroundLibrary.STRENGTH_BONUS * SECOND_SHARE)
	var lean: int = 0
	for ch: Dictionary in chosen(picks):
		for id: String in ch.get("stats", {}):
			p.stats[id] = int(p.stats.get(id, 0)) + int(ch.stats[id])
		for axis: String in ch.get("personality", {}):
			p.personality[axis] = clampi(int(p.personality.get(axis, 0)) + int(ch.personality[axis]), -100, 100)
		lean += int(ch.get("height", 0))
	for id: String in p.stats:
		p.stats[id] = clampi(int(p.stats[id]), BackgroundLibrary.STAT_FLOOR, STAT_MAX)
	if lean != 0:
		p.frame.height_cm = int(p.frame.height_cm) + lean * HEIGHT_PER_LEAN
		p.frame.reach_cm = int(p.frame.reach_cm) + lean * HEIGHT_PER_LEAN
	return p


## The people his choices brought in, oldest first: [{ role, name, about, age }]. Family share his surname; everyone's
## first name comes from his country when it's known (`country_id`). Seeded by the career.
func people(picks: Array, fighter_name: String, country_id: String, career_seed: int, names: NameLibrary = null) -> Array:
	var lib: NameLibrary = names if names != null else NameLibrary.shared()
	var rng := RandomNumberGenerator.new()
	rng.seed = ("people:%d" % career_seed).hash()
	var surname: String = fighter_name.get_slice(" ", fighter_name.get_slice_count(" ") - 1) if fighter_name != "" else ""
	var out: Array = []
	var n: int = 0
	for ch: Dictionary in chosen(picks):
		var who: Variant = ch.get("person")
		if who is Dictionary:
			var name: String = lib.random_name(rng, country_id)
			if bool(who.get("family", false)) and surname != "":
				name = "%s %s" % [name.get_slice(" ", 0), surname]
			if not bool(who.get("named", true)):
				name = ""
			out.append({ "role": String(who.role), "name": name, "about": String(who.get("about", "")), "age": AGES[mini(n, AGES.size() - 1)] })
		n += 1
	return out


## One person his childhood brought in, as his card says it: "Dad (Jack Murray): Wrestled in college ..." or, for
## someone who goes by the role alone, "Grandma: Competed in sambo ...".
static func person_text(person: Dictionary) -> String:
	var who: String = String(person.get("role", ""))
	if String(person.get("name", "")) != "":
		who += " (%s)" % String(person.name)
	return "%s: %s" % [who, String(person.get("about", ""))]
