class_name Gym
extends RefCounted
## Your gym (docs/03 §11.3, D313): where you coach, and where he walks in at 16. A new career offers three gyms in his
## hometown (offers()), each one of the five kinds in data/gyms/ (docs/09 gym@1) with a culture from
## data/enums/gym_cultures, a name, an owner and a monthly fee. The one you pick changes his training:
##
##   kind     each session kind's XP × the kind's `xp` (a boxing gym's striking 1.2, its grappling 0.7; missing = 1)
##   culture  skips × `skips` (a family gym 0.75, a party gym 1.5), injury odds × `injury` and sparring XP × `sparring_xp`
##            (hard sparring 1.5 and 1.2)
##   fee      comes out of his savings on the first Monday of every month (Career.end_week)
##
## A gym is plain data on the career ({kind, culture, name, owner_name, owner, fee}), so it saves as it is. Pure and
## seeded: the same career seed offers the same three gyms.

const DEFAULT_DIR := "res://data/gyms/"
const CULTURES_PATH := "res://data/enums/gym_cultures.json"
## How many gyms a new career offers. The first always suits where he comes from (a kind whose `backgrounds` has his).
const OFFERS: int = 3

static var _kinds: Dictionary = {}  # id → gym@1
static var _kind_ids: Array = []
static var _cultures: Dictionary = {}


static func kinds() -> Dictionary:
	if _kinds.is_empty():
		var files: PackedStringArray = DirAccess.get_files_at(DEFAULT_DIR)
		files.sort()
		for file in files:
			if file.ends_with(".json"):
				var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DEFAULT_DIR.path_join(file)))
				if parsed is Dictionary:
					_kinds[String(parsed.id)] = parsed
					_kind_ids.append(String(parsed.id))
	return _kinds


## The kinds' ids, sorted.
static func kind_ids() -> Array:
	kinds()
	return _kind_ids.duplicate()


static func kind(id: String) -> Dictionary:
	return kinds().get(id, {})


## The cultures: id → { name, about, skips, injury, sparring_xp }, in the file's order.
static func cultures() -> Dictionary:
	if _cultures.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CULTURES_PATH))
		if data is Dictionary:
			_cultures = data.get("values", {})
	return _cultures


static func culture(id: String) -> Dictionary:
	return cultures().get(id, {})


## The three gyms a new career offers in his hometown (`city`, named from `country_id`), for his `background`:
## three different kinds, the first one that suits his background. Each { kind, culture, name, owner_name, owner, fee }.
static func offers(city: String, country_id: String, background: String, career_seed: int, names: NameLibrary = null) -> Array:
	var lib: NameLibrary = names if names != null else NameLibrary.shared()
	var rng := RandomNumberGenerator.new()
	rng.seed = ("gyms:%d" % career_seed).hash()
	var pool: Array = kind_ids()
	var picked: Array = []
	var suits: Array = pool.filter(func(id: String) -> bool: return background in kind(id).get("backgrounds", []))
	if not suits.is_empty():
		picked.append(suits[rng.randi_range(0, suits.size() - 1)])
	while picked.size() < mini(OFFERS, pool.size()):
		var id: String = pool[rng.randi_range(0, pool.size() - 1)]
		if not id in picked:
			picked.append(id)
	var culture_ids: Array = cultures().keys()
	var out: Array = []
	for id: String in picked:
		var k: Dictionary = kind(id)
		var owner_name: String = lib.random_name(rng, country_id)
		var surname: String = owner_name.get_slice(" ", owner_name.get_slice_count(" ") - 1)
		var pattern: String = String(_pick(rng, k.get("names", ["{city} Gym"])))
		var fee: Array = k.get("fee", [50, 50])
		out.append({
			"kind": id, "culture": String(_pick(rng, culture_ids)) if not culture_ids.is_empty() else "",
			"name": pattern.format({ "city": city, "surname": surname }),
			"owner_name": owner_name, "owner": String(_pick(rng, k.get("owners", [""]))),
			"fee": rng.randi_range(int(fee[0]), int(fee[1])),
		})
	return out


## Session XP × this for a session of this kind (data/sessions `kind`) at this gym (1 with no gym).
static func xp_share(gym: Dictionary, session_kind: String) -> float:
	if gym.is_empty():
		return 1.0
	var out: float = float(kind(String(gym.get("kind", ""))).get("xp", {}).get(session_kind, 1.0))
	if session_kind == "sparring":
		out *= float(culture(String(gym.get("culture", ""))).get("sparring_xp", 1.0))
	return out


## The chance a party animal skips × this.
static func skip_share(gym: Dictionary) -> float:
	return float(culture(String(gym.get("culture", ""))).get("skips", 1.0)) if not gym.is_empty() else 1.0


## A session's injury odds × this.
static func injury_share(gym: Dictionary) -> float:
	return float(culture(String(gym.get("culture", ""))).get("injury", 1.0)) if not gym.is_empty() else 1.0


## "Boxing gym · Family gym".
static func kind_line(gym: Dictionary) -> String:
	var bits: Array[String] = []
	for name: String in [String(kind(String(gym.get("kind", ""))).get("name", "")), String(culture(String(gym.get("culture", ""))).get("name", ""))]:
		if name != "":
			bits.append(name)
	return " · ".join(bits)


## What the gym's kind trains better and worse: "Better at striking and sparring, worse at grappling and wrestling".
static func trains_line(gym: Dictionary) -> String:
	var xp: Dictionary = kind(String(gym.get("kind", ""))).get("xp", {})
	var better: Array = []
	var worse: Array = []
	for id: String in xp:
		if float(xp[id]) > 1.0:
			better.append(id)
		elif float(xp[id]) < 1.0:
			worse.append(id)
	var bits: Array[String] = []
	if not better.is_empty():
		bits.append("better at %s" % _and(better))
	if not worse.is_empty():
		bits.append("worse at %s" % _and(worse))
	if bits.is_empty():
		return "Trains everything the same."
	var out: String = ", ".join(bits)
	return out.left(1).to_upper() + out.substr(1) + "."


static func _and(items: Array) -> String:
	if items.size() == 1:
		return String(items[0])
	return "%s and %s" % [", ".join(items.slice(0, items.size() - 1)), String(items[-1])]


static func _pick(rng: RandomNumberGenerator, pool: Array) -> Variant:
	return pool[rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else ""
