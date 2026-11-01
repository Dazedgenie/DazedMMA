extends GutTest
## Fighters who look different (sim/world/fighter_look.gd, docs/13, D364, D365): a look from where he's from, fixed
## for the man; the career's own fighter's look as picked; his size from his frame.


func _profile(id: String, home: String = "") -> Dictionary:
	var p: Dictionary = FighterLibrary.load_dir().profile("wrestler")
	p.id = id
	p.name = id.capitalize()
	if home != "":
		p.home = home
	else:
		p.erase("home")
	return p


func test_the_same_man_looks_the_same_every_time() -> void:
	var p: Dictionary = _profile("lightweight_042", "brazil")
	assert_eq(FighterLook.for_profile(p), FighterLook.for_profile(p))
	assert_eq(FighterLook.check(FighterLook.for_profile(p)), "", "a whole look")
	var looks: Dictionary = {}
	for i in 40:
		looks[JSON.stringify(FighterLook.for_profile(_profile("lightweight_%03d" % i, "brazil")))] = true
	assert_gt(looks.size(), 25, "but men differ")


func test_a_man_mostly_looks_like_where_hes_from() -> void:
	var dark: Dictionary = { "nigeria": 0, "ireland": 0 }
	var black_hair: Dictionary = { "japan": 0, "ireland": 0 }
	for i in 200:
		for home: String in dark:
			if int(FighterLook.for_profile(_profile("m%d" % i, home)).skin) >= 4:
				dark[home] += 1
		for home: String in black_hair:
			if String(FighterLook.for_profile(_profile("m%d" % i, home)).hair) == "black":
				black_hair[home] += 1
	assert_gt(dark.nigeria, 180, "a Nigerian is nearly always dark-skinned")
	assert_lt(dark.ireland, 20, "an Irishman seldom is")
	assert_gt(dark.ireland, 0, "but any country has a mix")
	assert_gt(black_hair.japan, 140, "a Japanese man mostly has black hair")
	assert_lt(black_hair.ireland, 40)


func test_a_dark_skinned_man_has_dark_hair() -> void:
	for i in 100:
		var look: Dictionary = FighterLook.for_profile(_profile("m%d" % i, "united_states"))
		if int(look.skin) >= FighterLook.DARK_HAIR_FROM:
			assert_has(["black", "dark_brown"], String(look.hair))


func test_a_given_look_is_kept_and_the_rest_rolled() -> void:
	var p: Dictionary = _profile("x", "england")
	p.look = { "skin": 6, "beard": "beard" }
	var look: Dictionary = FighterLook.for_profile(p)
	assert_eq(int(look.skin), 6)
	assert_eq(String(look.beard), "beard")
	assert_eq(FighterLook.check(look), "")
	assert_ne(FighterLook.check({ "skin": 2, "hair": "green", "hair_style": "short", "beard": "none" }), "")
	assert_ne(FighterLook.check({ "skin": 2.5 }, true), "", "a tone is a whole number")
	assert_ne(FighterLook.check({ "shorts": "red" }, true), "", "the shorts are the corner's")
	assert_eq(FighterLook.check({ "hair": "red" }, true), "", "part of a look")


func test_his_size_comes_from_his_height_reach_and_weight() -> void:
	var tall: Dictionary = FighterLook.sizes({ "frame": { "height_cm": 198, "reach_cm": 198, "build": "average" } })
	var short: Dictionary = FighterLook.sizes({ "frame": { "height_cm": 162, "reach_cm": 162, "build": "average" } })
	assert_almost_eq(float(tall.height), 1.1, 0.001, "drawn true to his height")
	assert_almost_eq(float(short.height), 0.9, 0.001)
	assert_almost_eq(float(tall.arm), 1.0, 0.001, "arms as long as he is tall: as drawn")
	var rangy: Dictionary = FighterLook.sizes({ "frame": { "height_cm": 180, "reach_cm": 192, "build": "lean" } })
	assert_almost_eq(float(rangy.arm), 1.0 + 6.0 / 59.4, 0.001, "half his extra reach on each arm")
	var stocky: Dictionary = FighterLook.sizes({ "frame": { "height_cm": 178, "reach_cm": 178, "build": "stocky" } })
	assert_gt(float(stocky.girth), 1.0, "a stocky man is thicker")
	assert_lt(float(rangy.girth), 1.0, "a lean one thinner")
	assert_lt(absf(float(stocky.limbs) - 1.0), absf(float(stocky.girth) - 1.0), "his limbs less than his trunk")
	var heavy: Dictionary = FighterLook.sizes({ "frame": { "height_cm": 190, "reach_cm": 195, "adult_kg": 125.0 }, "age": 30 })
	assert_almost_eq(float(heavy.girth), FighterLook.GIRTH_RANGE[1], 0.001, "a heavyweight, as thick as it goes")
	var teen: Dictionary = FighterLook.sizes({ "frame": { "height_cm": 178, "adult_kg": 80.0 }, "age": 16 })
	var grown: Dictionary = FighterLook.sizes({ "frame": { "height_cm": 178, "adult_kg": 80.0 }, "age": 25 })
	assert_lt(float(teen.girth), float(grown.girth), "a 16-year-old hasn't filled out")


func test_the_careers_own_fighter_keeps_the_look_he_was_given() -> void:
	var look: Dictionary = { "skin": 5, "hair": "black", "hair_style": "shaved", "beard": "stubble" }
	var c: Career = Career.start({ "coach": "Sam Reed", "name": "Danny Hill", "hometown": "Leeds", "country": "England",
		"background": "street_kid", "stance": "orthodox", "look": look }, 3, FighterLibrary.load_dir())
	assert_eq(c.profile().look, look)
	assert_eq(String(c.profile().home), "england")
	assert_eq(FighterLook.for_profile(c.profile()), look, "he's drawn as picked")
	var back: Career = Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.profile().look, look, "and the save keeps it")
	assert_typeof(back.profile().look.skin, TYPE_INT)
	var old: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	old.about.erase("look")
	var before: Career = Career.from_dict(old)
	assert_false(before.profile().has("look"), "a career saved before D365 has none")
	assert_eq(FighterLook.check(FighterLook.for_profile(before.profile())), "", "and gets one from where he's from")


func test_the_worlds_men_carry_where_theyre_from() -> void:
	var c: Career = Career.start({ "coach": "Sam Reed", "name": "Danny Hill", "hometown": "Leeds", "country": "England",
		"background": "street_kid", "stance": "orthodox" }, 3, FighterLibrary.load_dir())
	var names := NameLibrary.shared()
	var checked: int = 0
	for id: String in c.world().men.keys().slice(0, 30):
		var m: Dictionary = c.world().man(id)
		var p: Dictionary = c.world().profile(id, c.week)
		assert_eq(String(p.home), names.country_id_of(String(m.country)), id)
		checked += 1
	assert_eq(checked, 30)
