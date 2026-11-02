extends GutTest
## The 30-year check (sim/world/world_check.gd, docs/03 §12.9, D359): a career's world played 30 years with a stand-in
## of his own through it stays inside its bounds, the save still loads and every hub page still opens; and the changes
## it brought: closer title fights, the best men fading faster after 34, retired men forgotten unless notable, and
## divisions biggest in the middle.


func _career(career_seed: int = 3) -> Career:
	return Career.start({ "coach": "Sam Reed", "name": "Danny Hill", "hometown": "Leeds", "country": "England",
		"background": "street_kid", "stance": "orthodox" }, career_seed, FighterLibrary.load_dir())


func test_thirty_years_of_the_world_stay_healthy_with_a_stand_in_career_through_them() -> void:
	var c: Career = _career()
	var report: Dictionary = WorldCheck.play(c)
	var text: String = WorldCheck.report_text(report)
	gut.p(text)
	assert_eq(WorldCheck.problems(report), [] as Array[String], text)
	assert_eq((report.snapshots as Array).size(), WorldCheck.YEARS / WorldCheck.SNAPSHOT_YEARS)
	assert_gt(int(report.stand_in.fights), 60, "he fought all the way through")
	assert_true(c.pro, "and turned pro")
	assert_gte(c.age(), 36, "and got old doing it")
	# The 30-year save loads and carries on.
	var back: Career = Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.week, c.week)
	assert_eq(back.record_text(true), c.record_text(true))
	assert_eq(JSON.stringify(back.world().reigns), JSON.stringify(c.world().reigns))
	back.run_week()
	# Every hub page opens on it.
	var hub := CareerHub.new()
	add_child_autofree(hub)
	hub.show_career(back)
	assert_ne(hub.text(), "")
	for page: String in [CareerHub.week_text(back), CareerHub.fights_text(back), CareerHub.news_text(back, 8),
			CareerHub.promotions_text(back), CareerHub.rankings_text(back), CareerHub.division_text(back),
			CareerHub.history_text(back), CareerHub.fighter_card_text(back)]:
		assert_ne(page, "")
	assert_string_contains(CareerHub.history_text(back), "LEGENDS")
	for o: Dictionary in back.offers:
		assert_ne(CareerHub.offer_text(back, o), "")


func test_the_check_names_what_is_out_of_bounds() -> void:
	var s: Dictionary = { "year": 5, "active": 400, "pros": { "lightweight": 200 }, "best": 95.0, "belts": 36, "vacant": 20,
		"oldest": 50.0, "busiest": 90, "retired_median": 25.0 }
	var end: Dictionary = s.duplicate()
	end.merge({ "long_reigns": 20, "most_defences": 30, "world_champions": { "lightweight": 1 }, "save_kb": 3000 })
	var p: Array[String] = WorldCheck.problems({ "years": 30, "snapshots": [s], "end": end })
	assert_eq(p.size(), 11, "\n".join(p))
	assert_string_contains("\n".join(p), "400 active men")
	assert_string_contains("\n".join(p), "a reign of 30 defences")


func test_a_title_fight_is_closer_than_the_mens_averages_say() -> void:
	var c: Career = _career()
	var w: World = c.world()
	var pros: Array = w.men.values().filter(func(m: Dictionary) -> bool: return bool(m.pro) and String(m.tier) == "world")
	pros.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return w.average(a) > w.average(b))
	var a: Dictionary = pros[0]
	var b: Dictionary = pros[-1]
	assert_gt(w.average(a) - w.average(b), 5.0)
	var rng := RandomNumberGenerator.new()
	var plain: float = float(WorldWeeks.fight(w, a, b, w.played + 1, rng).chance)
	var title: float = float(WorldWeeks.fight(w, a, b, w.played + 1, rng, Titles.ROUNDS, Titles.SQUEEZE).chance)
	assert_gt(plain, title, "the better man's edge counts for less")
	assert_gt(title, 0.5, "but he's still the favourite")


func test_the_best_men_fade_faster_after_34() -> void:
	var c: Career = _career()
	var w: World = c.world()
	var pros: Array = w.men.values().filter(func(x: Dictionary) -> bool: return bool(x.pro))
	pros.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return w.average(a) > w.average(b))
	var best: Dictionary = pros[0].duplicate(true)
	var plain: Dictionary = pros[-1].duplicate(true)
	best.potential = 0.0
	plain.potential = 0.0
	assert_gt(w.average(best), WorldWeeks.TOP_DECLINE_FROM + 5.0)
	assert_lt(w.average(plain), WorldWeeks.TOP_DECLINE_FROM)
	var a_year: Callable = func(m: Dictionary, age: float) -> float:
		return -WorldWeeks.change_a_week(w, m, age) * Career.WEEKS_PER_YEAR
	assert_almost_eq(float(a_year.call(plain, 35.0)), WorldWeeks.DECLINE_LATE, 0.01, "an ordinary man")
	assert_almost_eq(float(a_year.call(best, 35.0)),
		WorldWeeks.DECLINE_LATE + WorldWeeks.TOP_DECLINE * (w.average(best) - WorldWeeks.TOP_DECLINE_FROM), 0.01,
		"a champion has further to fall")
	assert_almost_eq(float(a_year.call(best, 32.0)), WorldWeeks.DECLINE, 0.01, "but not before 34")


func test_retired_men_nobody_will_look_for_are_forgotten_after_five_years() -> void:
	var c: Career = _career()
	var w: World = c.world()
	var pros: Array = w.men.values().filter(func(m: Dictionary) -> bool: return bool(m.pro))
	var plain: Dictionary = pros[0]
	var met: Dictionary = pros[1]
	var champ: Dictionary = pros[2]
	var recent: Dictionary = pros[3]
	var gone: int = maxi(0, w.played)
	var week: int = gone + WorldWeeks.FORGET_PROS_WEEKS + 10
	for m: Dictionary in [plain, met, champ]:
		m.retired = gone
	recent.retired = week - 52
	met.met_week = gone
	History.note_reign(w, "org_0:lightweight", String(champ.id), 0, 20, 2, "retired")
	WorldWeeks.let_go(w, week)
	assert_true(w.man(String(plain.id)).is_empty(), "a retired pro nobody will look for, after 5 years")
	assert_false(w.man(String(met.id)).is_empty(), "a man he fought")
	assert_false(w.man(String(champ.id)).is_empty(), "a champion")
	assert_false(w.man(String(recent.id)).is_empty(), "retired a year ago")


func test_the_divisions_are_biggest_in_the_middle_and_lads_grow_into_theirs() -> void:
	var w: World = _career().world()
	var pros: Dictionary = {}
	for m: Dictionary in w.men.values():
		if bool(m.pro):
			pros[String(m.division)] = int(pros.get(String(m.division), 0)) + 1
	assert_gt(int(pros.lightweight), int(pros.bantamweight))
	assert_gt(int(pros.welterweight), int(pros.light_heavyweight))
	assert_gt(int(pros.lightweight), int(pros.light_heavyweight) + 20)
	var pyramid: int = 0
	for level: Dictionary in World.LEVELS:
		if bool(level.pro):
			pyramid += World.count_in(level, "lightweight")
	assert_eq(int(pros.lightweight), pyramid, "the pyramid's pros times its size")
	var lads: Array = w.men.values().filter(func(m: Dictionary) -> bool: return not bool(m.pro))
	var fits: int = 0
	for m: Dictionary in lads:
		if String(m.id).begins_with(Weight.natural(m.frame) + "_"):
			fits += 1
	assert_gt(float(fits) / lads.size(), 0.9, "a lad made for a division grows into it")
