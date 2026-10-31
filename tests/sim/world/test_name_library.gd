extends GutTest
## Names and hometowns (sim/world/name_library.gd, data/names, docs/03 §10.2, D302).

var _names: NameLibrary


func before_all() -> void:
	_names = NameLibrary.load_dir()


func test_hometowns_are_real_cities_with_their_country() -> void:
	var towns: Array = _names.hometowns()
	assert_gt(towns.size(), 50)
	var leeds: Array = towns.filter(func(t: Dictionary) -> bool: return t.city == "Leeds")
	assert_eq(leeds.size(), 1)
	assert_eq(leeds[0].country, "England")
	assert_eq(_names.country_name("brazil"), "Brazil")


func test_a_rolled_person_is_named_like_where_he_comes_from() -> void:
	for roll_seed in 30:
		var rng := RandomNumberGenerator.new()
		rng.seed = roll_seed
		var person: Dictionary = _names.roll(rng)
		var country: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/names/%s.json" % person.country_id))
		assert_true(person.hometown in country.cities, person.hometown)
		assert_true(String(person.name).split(" ")[0] in country.first, "%s is a first name from %s" % [person.name, person.country])
		assert_true(person.nickname in _names.nicknames())


func test_the_same_seed_rolls_the_same_person() -> void:
	var a := RandomNumberGenerator.new()
	a.seed = 9
	var b := RandomNumberGenerator.new()
	b.seed = 9
	assert_eq(_names.roll(a), _names.roll(b))
