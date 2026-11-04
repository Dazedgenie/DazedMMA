extends GutTest
## The weight cut and the weigh-in (sim/world/weight_cut.gd, docs/03 §13.9, D405): how much water each level sheds, what
## it costs, the bigger man's Strength on the night, missing weight and what that does to the purse and a belt.


func _career(career_seed: int = 3) -> Career:
	return Career.start({ "coach": "Sam Reed", "name": "Danny Hill", "hometown": "Leeds", "country": "England",
		"background": "street_kid", "stance": "orthodox" }, career_seed, FighterLibrary.load_dir())


## A pro lightweight walking around at 78 kg, booked against a man walking at `his_kg`.
func _pro_booked(c: Career, his_kg: float = 77.0, id: String = "cut_test_man") -> Dictionary:
	c.trainee.age_years = 21.0
	c.pro = true
	c.division = "lightweight"
	c.fighter.frame.adult_kg = 78.0
	var him: Dictionary = { "id": id, "name": "Lee Marsh", "style_id": "kicker", "age": 25,
		"frame": { "height_cm": 178, "reach_cm": 182, "build": "average", "adult_kg": his_kg }, "stats": {}, "techniques": [] }
	c.opponents[id] = him
	c.booked = { "opponent": id, "week": c.week + 3, "camp_weeks": 4, "pro": true, "ruleset": "pro",
		"purse": { "show": 1000, "win": 1000 } }
	return him


func test_a_harder_cut_sheds_more_water_and_leaves_him_heavier_on_fight_night() -> void:
	var last: float = 0.0
	for level: String in WeightCut.LEVELS:
		var s: Dictionary = WeightCut.side(78.0, 70.3, level, false, 1.0, 0.0)
		assert_true(bool(s.made))
		assert_almost_eq(float(s.scale_kg), 70.3, 0.01, "on the limit at the scale")
		assert_almost_eq(float(s.water_kg), minf(7.7, 78.0 * float(WeightCut.WATER[level])), 0.06)
		assert_gt(float(s.night_kg), last, "%s leaves him heavier than the cut below it" % level)
		last = float(s.night_kg)
	var light: Dictionary = WeightCut.side(78.0, 70.3, WeightCut.LIGHT, false, 1.0, 0.0)
	assert_eq(float(light.tank_cost), 0.0, "a light cut costs nothing")
	var hard: Dictionary = WeightCut.side(78.0, 70.3, WeightCut.HARD, false, 1.0, 0.0)
	assert_almost_eq(float(hard.tank_cost), 0.08, 0.001)
	assert_almost_eq(float(hard.chin_cost), 3.0, 0.01)
	var extreme: Dictionary = WeightCut.side(78.0, 70.3, WeightCut.EXTREME, false, 1.0, 0.0)
	assert_lt(float(extreme.tank_cost), 0.15, "he only had 7.7 kg to lose, less than an extreme cut's 9.4: so less of its cost")
	assert_gt(float(extreme.tank_cost), 0.12)


func test_a_man_with_nothing_to_cut_pays_nothing_and_cannot_miss() -> void:
	var s: Dictionary = WeightCut.side(69.0, 70.3, WeightCut.EXTREME, true, 0.0, 0.5)
	assert_true(bool(s.made))
	assert_eq(float(s.water_kg), 0.0)
	assert_eq(float(s.tank_cost), 0.0)
	assert_eq(float(s.chin_cost), 0.0)
	assert_almost_eq(float(s.night_kg), 69.0, 0.01, "he fights at what he walks around at")
	assert_string_contains(WeightCut.cost_text(s), "Nothing to cut")


func test_the_bigger_man_on_the_night_gains_a_point_of_strength_a_kg_up_to_six() -> void:
	assert_eq(WeightCut.edge(77.9, 74.5), 3.0)
	assert_eq(WeightCut.edge(74.5, 77.9), 0.0, "the lighter man gains nothing")
	assert_eq(WeightCut.edge(85.0, 70.0), WeightCut.STRENGTH_MAX)
	assert_eq(WeightCut.edge(71.0, 70.3), 0.0, "under a kg is no edge")


func test_he_misses_weight_more_often_the_harder_he_cuts_and_more_with_the_hard_cut_flaw() -> void:
	for level: String in WeightCut.LEVELS:
		var s: Dictionary = WeightCut.side(80.0, 70.3, level, false, 0.0, 0.0)
		assert_almost_eq(float(s.miss_chance), float(WeightCut.MISS_CHANCE[level]), 0.001)
		assert_eq(bool(s.made), float(WeightCut.MISS_CHANCE[level]) <= 0.0, "a roll of 0 misses whenever there's a chance")
	var flawed: Dictionary = WeightCut.side(80.0, 70.3, WeightCut.EXTREME, true, 0.2, 1.0)
	assert_almost_eq(float(flawed.miss_chance), 0.225, 0.001, "× 1.5 with Hard cut")
	assert_false(bool(flawed.made))
	assert_almost_eq(float(flawed.scale_kg), 70.3 + WeightCut.MISS_BY[1], 0.01, "over the limit by up to 1.5 kg")


func test_an_amateur_fight_has_no_weigh_in_and_a_pro_one_weighs_both_men_the_same_way_every_time() -> void:
	var c: Career = _career()
	_pro_booked(c)
	c.booked.pro = false
	assert_eq(WeightCut.of(c), {}, "amateurs weigh in on the day at what they walk around at")
	c.booked.pro = true
	var w: Dictionary = WeightCut.of(c)
	assert_false(w.is_empty())
	assert_eq(w, WeightCut.of(c), "seeded by the booking")
	assert_eq(String(w.him.cut), WeightCut.DEFAULT)
	assert_almost_eq(float(w.him.walk_kg), 78.0, 0.01)
	var his: Dictionary = w.opp
	c.booked.cut = WeightCut.EXTREME
	assert_eq(WeightCut.of(c).opp, his, "your pick never changes his cut")
	assert_gt(float(WeightCut.of(c).him.night_kg), float(w.him.night_kg))
	var levels: Dictionary = {}
	for s in 200:
		c.career_seed = s
		levels[String(WeightCut.of(c).opp.cut)] = int(levels.get(String(WeightCut.of(c).opp.cut), 0)) + 1
	assert_between(int(levels.get("normal", 0)), 75, 125, "about half his corners pick a normal cut")
	assert_eq(levels.size(), 4, "every level comes up")


func test_the_cut_goes_onto_both_mens_profiles_for_the_fight() -> void:
	var p: Dictionary = { "stats": { "chin": 60.0, "strength": 55.0 }, "condition": { "tank": 0.9 } }
	WeightCut.apply(p, { "tank_cost": 0.1, "chin_cost": 3.0 }, 2.0)
	assert_almost_eq(float(p.condition.tank), 0.81, 0.001)
	assert_eq(float(p.stats.chin), 57.0)
	assert_eq(float(p.stats.strength), 57.0)


func test_missing_weight_fines_him_a_fifth_of_his_purse_and_the_fight_goes_ahead() -> void:
	var c: Career = _career()
	_pro_booked(c)
	c.booked.cut = WeightCut.EXTREME
	var s: int = 0
	while bool(WeightCut.of(c).him.made):
		s += 1
		c.career_seed = s
	var paid: int = c.finish_fight({ "result": "win", "method": "Decision (unanimous)", "round": 3 })
	assert_eq(int(c.fights[-1].fine), 400, "20% of the $2,000 he'd have made")
	assert_eq(paid, 1600)
	assert_false(bool(c.fights[-1].weigh_in.made))
	assert_eq(String(c.fights[-1].weigh_in.cut), WeightCut.EXTREME)


func test_a_man_who_missed_weight_cannot_win_the_belt_and_a_champion_who_misses_is_stripped() -> void:
	var c: Career = _career()
	_pro_booked(c)
	var w: World = c.world()
	var home: Dictionary = Promotions.home(w)
	var k: String = Rankings.key(String(home.id), c.division)
	var champ: String = String(w.titles[k].champion)
	_pro_booked(c, 77.0, champ)
	c.booked.title = k
	c.booked.cut = WeightCut.EXTREME
	var s: int = 0
	while bool(WeightCut.of(c).him.made) or not bool(WeightCut.of(c).opp.made):
		s += 1
		c.career_seed = s
	c.finish_fight({ "result": "win", "method": "KO", "round": 2 })
	assert_eq(String(w.titles[k].champion), champ, "he missed weight: winning doesn't make him champion")
	# Now the champion misses.
	c.booked = { "opponent": champ, "week": c.week + 3, "camp_weeks": 4, "pro": true, "ruleset": "pro", "title": k,
		"purse": { "show": 1000, "win": 1000 }, "cut": WeightCut.LIGHT }
	while not bool(WeightCut.of(c).him.made) or bool(WeightCut.of(c).opp.made):
		s += 1
		c.career_seed = s
	c.finish_fight({ "result": "loss", "method": "KO", "round": 2 })
	assert_eq(String(w.titles[k].champion), "", "he was stripped at the scale and couldn't win it back")
	assert_gt(int(c.fights[-1].get("fine_got", 0)), 0, "his fine comes to you")
