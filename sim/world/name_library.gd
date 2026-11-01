class_name NameLibrary
extends RefCounted
## Names and hometowns from real places (docs/03 §10.2, D302; D57): data/names/*.json (docs/09 names@1), one file a
## country with its cities and common first and last names, and the nicknames in data/enums/nicknames.json. The
## new-career screen lists the hometowns and its Roll button uses roll(); generated opponents (phase 1, PR 4) will be
## named from the same files, so a fighter's name fits where he's from.

const DEFAULT_DIR := "res://data/names/"
const NICKNAMES_PATH := "res://data/enums/nicknames.json"

static var _default: NameLibrary

var _countries: Dictionary = {}  # id → names@1 Dictionary
var _nicknames: Array = []


static func load_dir(dir_path: String = DEFAULT_DIR) -> NameLibrary:
	var library := NameLibrary.new()
	var files: PackedStringArray = DirAccess.get_files_at(dir_path)
	files.sort()
	for file in files:
		if file.ends_with(".json"):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir_path.path_join(file)))
			if parsed is Dictionary:
				library.add(parsed)
	return library


static func shared() -> NameLibrary:
	if _default == null:
		_default = load_dir()
	return _default


func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(NICKNAMES_PATH))
	if parsed is Dictionary:
		var ids: Array = parsed.values.keys()
		ids.sort()
		for id: String in ids:
			_nicknames.append(String(parsed.values[id]))


func add(country: Dictionary) -> void:
	_countries[country.id] = country


## Every country id, sorted by the country's name.
func countries() -> Array:
	var out: Array = _countries.keys()
	out.sort_custom(func(a: String, b: String) -> bool: return country_name(a) < country_name(b))
	return out


func country_name(id: String) -> String:
	return String(_countries.get(id, {}).get("country", ""))


## How often each skin tone and hair colour turns up in this country (names@1 `looks`, D364; FighterLook): { skin: [a
## weight for each FighterLook.SKIN_TONES tone], hair: { colour: weight } }, or {} when the file has none.
func looks(id: String) -> Dictionary:
	var out: Variant = _countries.get(id, {}).get("looks", {})
	return out if out is Dictionary else {}


## The id of the country with this name ("" when there's none).
func country_id_of(country: String) -> String:
	for id: String in _countries:
		if country_name(id) == country:
			return id
	return ""


## How much more often the world's best men come from this country (its `hotbed`, 1 when it has none; D352).
func hotbed(country_id: String) -> float:
	return float(_countries.get(country_id, {}).get("hotbed", 1.0))


## The styles more of this country's fighters have (its `styles`, D352), [] when it has none.
func home_styles(country_id: String) -> Array:
	return (_countries.get(country_id, {}).get("styles", []) as Array).duplicate()


## A country's cities, in the file's order ([] for an unknown id).
func cities(country_id: String) -> Array:
	return (_countries.get(country_id, {}).get("cities", []) as Array).duplicate()


## Every hometown as { city, country (its name), country_id }, by country then in the file's order.
func hometowns() -> Array:
	var out: Array = []
	for id: String in countries():
		for city: Variant in _countries[id].cities:
			out.append({ "city": String(city), "country": country_name(id), "country_id": id })
	return out


func nicknames() -> Array:
	return _nicknames.duplicate()


## A first and last name from this country (any country when "").
func random_name(rng: RandomNumberGenerator, country_id: String = "") -> String:
	var id: String = country_id if _countries.has(country_id) else String(_pick(rng, countries()))
	var c: Dictionary = _countries[id]
	return "%s %s" % [_pick(rng, c.first), _pick(rng, c.last)]


## A whole made-up person: { name, nickname, hometown, country, country_id }, the name from the hometown's country.
func roll(rng: RandomNumberGenerator) -> Dictionary:
	var town: Dictionary = _pick(rng, hometowns())
	return { "name": random_name(rng, town.country_id), "nickname": String(_pick(rng, _nicknames)),
		"hometown": town.city, "country": town.country, "country_id": town.country_id }


## As roll(), from one of this country's cities (local amateur cards, D314). Any country when the id is unknown.
## `city`, when given, is his hometown instead.
func roll_in(rng: RandomNumberGenerator, country_id: String, city_in: String = "") -> Dictionary:
	if not _countries.has(country_id):
		return roll(rng)
	var city: String = String(_pick(rng, _countries[country_id].cities))
	if city_in != "":
		city = city_in
	return { "name": random_name(rng, country_id), "nickname": String(_pick(rng, _nicknames)),
		"hometown": city, "country": country_name(country_id), "country_id": country_id }


static func _pick(rng: RandomNumberGenerator, items: Array) -> Variant:
	return items[rng.randi_range(0, items.size() - 1)]
