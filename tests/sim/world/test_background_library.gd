extends GutTest
## Backgrounds (sim/world/background_library.gd, docs/02 §1.2, docs/03 §10.2, D302): where a new career's 16-year-old
## comes from, and the fighter each one makes.

var _bgs: BackgroundLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_bgs = BackgroundLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


func test_there_are_the_twelve_backgrounds_of_the_design() -> void:
	assert_eq(_bgs.ids().size(), 12)
	assert_true(_bgs.has("wrestling_family"))
	assert_true(_bgs.has("bullied_underdog"))


func test_every_background_makes_a_complete_16_year_old() -> void:
	for id: String in _bgs.ids():
		var p: Dictionary = _bgs.make_fighter(id, 1, _roster, { "name": "Danny Hill", "stance": "orthodox" })
		assert_eq(p.age, BackgroundLibrary.START_AGE, id)
		assert_eq(p.name, "Danny Hill", id)
		assert_eq(p.background, id)
		assert_null(p.template, id)
		assert_eq(p.stats.size(), StyleLibrary.stat_ids().size(), "%s has every stat" % id)
		for stat: String in p.stats:
			assert_between(int(p.stats[stat]), BackgroundLibrary.STAT_FLOOR, BackgroundLibrary.STAT_HIGH + BackgroundLibrary.STRENGTH_BONUS, "%s %s" % [id, stat])
		assert_between(int(p.potential), 62, 92, id)
		var heights: Array = _bgs.get_background(id).frame.height_cm
		assert_between(int(p.frame.height_cm), int(heights[0]), int(heights[1]), id)
		assert_false(p.techniques.is_empty(), "%s knows his background fighter's moves" % id)


func test_his_background_strengths_start_well_above_its_weaknesses() -> void:
	for id: String in _bgs.ids():
		var bg: Dictionary = _bgs.get_background(id)
		var strong: float = 0.0
		var weak: float = 0.0
		for fighter_seed in 20:
			var p: Dictionary = _bgs.make_fighter(id, fighter_seed, _roster)
			for stat: String in bg.strengths:
				strong += float(p.stats[stat]) / bg.strengths.size()
			for stat: String in bg.weaknesses:
				weak += float(p.stats[stat]) / bg.weaknesses.size()
		assert_gt(strong / 20.0, weak / 20.0 + 15.0, "%s: strengths %.1f, weaknesses %.1f" % [id, strong / 20.0, weak / 20.0])


func test_the_same_seed_makes_the_same_fighter_and_another_seed_another() -> void:
	var a: Dictionary = _bgs.make_fighter("street_kid", 5, _roster)
	var b: Dictionary = _bgs.make_fighter("street_kid", 5, _roster)
	assert_eq(JSON.stringify(a), JSON.stringify(b))
	assert_ne(JSON.stringify(_bgs.make_fighter("street_kid", 6, _roster).stats), JSON.stringify(a.stats))


func test_gifts_and_flaws_are_zero_to_two_and_zero_to_one_and_real() -> void:
	var gifts: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BackgroundLibrary.GIFTS_PATH)).values
	var flaws: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BackgroundLibrary.FLAWS_PATH)).values
	var counts: Array[int] = [0, 0, 0]
	var with_flaw: int = 0
	for fighter_seed in 200:
		var p: Dictionary = _bgs.make_fighter("farm_kid", fighter_seed, _roster, { "stance": "orthodox" })
		assert_lte(p.gifts.size(), 2)
		assert_lte(p.flaws.size(), 1)
		counts[p.gifts.size()] += 1
		with_flaw += p.flaws.size()
		for g: String in p.gifts:
			assert_true(gifts.has(g), g)
		for f: String in p.flaws:
			assert_true(flaws.has(f), f)
		assert_false("natural_southpaw" in p.gifts, "he chose orthodox")
		assert_eq(p.stance, "orthodox")
	assert_true(counts[0] > 0 and counts[1] > 0 and counts[2] > 0, "some have none, some one, some two: %s" % str(counts))
	assert_between(with_flaw, 40, 100, "about a third have a flaw")


func test_a_fighter_from_every_background_can_fight() -> void:
	var actions: ActionLibrary = ActionLibrary.load_dir()
	for id: String in _bgs.ids():
		var p: Dictionary = _bgs.make_fighter(id, 3, _roster)
		_roster.add(p)
		var sim := FightSim.new(7, _roster.make_pair(p.id, "kicker"), actions, Ruleset.load_id("amateur_teen"))
		sim.run_to_end()
		assert_true(sim.is_over(), "%s's fight ends" % id)


func test_a_new_career_starts_from_the_choices() -> void:
	var choices := { "coach": "Sam Reed", "name": "Danny Hill", "nickname": "The Kid", "hometown": "Leeds", "country": "England",
		"background": "boxing_gym_kid", "stance": "southpaw" }
	var c: Career = Career.start(choices, 42, _roster)
	assert_eq(c.fighter_name(), "Danny Hill")
	assert_eq(c.coach_name, "Sam Reed")
	assert_eq(c.age(), 16)
	assert_eq(c.fighter.stance, "southpaw")
	assert_eq(c.about.background, "boxing_gym_kid")
	assert_eq(c.money, int(_bgs.get_background("boxing_gym_kid").money))
	var s: Dictionary = c.summary()
	assert_eq(s.hometown, "Leeds")
	assert_eq(s.background, "boxing_gym_kid")
	var back: Career = Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict(), "", true, true)))
	assert_not_null(back, Career.load_error)
	assert_eq(back.fighter.background, "boxing_gym_kid", "the save keeps where he's from")
