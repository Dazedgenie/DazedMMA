extends GutTest
## The rankings (sim/world/rankings.gd, docs/03 §12.5, D355): every promotion's own table in each division, from points
## for recent results, men out of action sliding and coming off, ranked men matched near their rank, each move with its
## reason, and the career's fighter ranked from his pro fights on a promotion's card.


func _career(career_seed: int = 3) -> Career:
	return Career.start({ "coach": "Sam Reed", "name": "Danny Hill", "hometown": "Leeds", "country": "England",
		"background": "street_kid", "stance": "orthodox" }, career_seed, FighterLibrary.load_dir())


func _new_year(c: Career) -> Callable:
	return func(w: int) -> Dictionary: return c.date(0, w)


func test_beating_a_better_ranked_man_scores_more_and_losing_to_one_costs_less() -> void:
	var n: int = Rankings.TOP_ORGANISATION
	assert_gt(Rankings.points_for("w", "decision", 1, n), Rankings.points_for("w", "decision", 15, n), "beating #1 beats beating #15")
	assert_gt(Rankings.points_for("w", "decision", 15, n), Rankings.points_for("w", "decision", 0, n))
	assert_eq(Rankings.points_for("w", "decision", 0, n), Rankings.WIN_POINTS)
	assert_gt(Rankings.points_for("w", "ko", 0, n), Rankings.points_for("w", "decision", 0, n), "a finish counts more")
	assert_gt(Rankings.points_for("l", "decision", 1, n), Rankings.points_for("l", "decision", 0, n), "losing to #1 costs less")
	assert_lt(Rankings.points_for("l", "ko", 0, n), Rankings.points_for("l", "decision", 0, n), "being finished costs more")
	assert_eq(Rankings.points_for("d", "draw", 3, n), Rankings.DRAW_POINTS)


func test_points_fade_and_a_man_out_of_action_slides_then_comes_off() -> void:
	var m: Dictionary = { "points": [[0, 20.0, Promotions.MAJOR, 0, "w", "decision", ""]] }
	assert_almost_eq(Rankings.score(m, Promotions.MAJOR, 0), 20.0, 0.001)
	assert_almost_eq(Rankings.score(m, Promotions.MAJOR, Rankings.FADE_WEEKS / 4), 15.0, 0.001, "a quarter faded after six months")
	var at_slide: float = 20.0 * (1.0 - float(Rankings.SLIDE_WEEKS + 10) / Rankings.FADE_WEEKS)
	assert_almost_eq(Rankings.score(m, Promotions.MAJOR, Rankings.SLIDE_WEEKS + 10), at_slide * (1.0 - 10.0 * Rankings.SLIDE_PER_WEEK), 0.001,
		"sliding after six months out")
	assert_eq(Rankings.score(m, Promotions.MAJOR, Rankings.OUT_WEEKS), -INF, "off after a year out")
	var regional: Dictionary = { "points": [[0, 20.0, Promotions.REGIONAL, 0, "w", "decision", ""]] }
	assert_almost_eq(Rankings.score(regional, Promotions.MAJOR, 0), 20.0 * Rankings.LOWER_SHARE * Rankings.LOWER_SHARE, 0.001,
		"regional wins count for less in the world organisation")


func test_day_one_ranks_every_promotions_men_by_level() -> void:
	var c: Career = _career()
	var w: World = c.world()
	for p: Dictionary in w.promotions:
		for division_id: String in Weight.ids():
			var ids: Array = Rankings.table(w, String(p.id), division_id)
			assert_lte(ids.size(), Rankings.size_for(p))
			for i in range(1, ids.size()):
				assert_gte(w.average(w.man(ids[i - 1])), w.average(w.man(ids[i])), "%s %s by level" % [p.short, division_id])
			for id: String in ids:
				assert_eq(String(w.man(id).promotion), String(p.id))
				assert_eq(Rankings.rank_of(w, id), ids.find(id) + 1)
	assert_eq(Rankings.table(w, "org_0", "lightweight").size(), Rankings.TOP_ORGANISATION, "the world organisation's top 15 is full")
	var home: Dictionary = Promotions.home(w)
	assert_eq(Rankings.table(w, String(home.id), "lightweight").size(), mini(Rankings.TOP_REGIONAL, Rankings._men_of(w, String(home.id), "lightweight").size()),
		"a regional top 10, as far as its men go")


func test_the_tables_follow_results_and_each_move_says_why() -> void:
	var c: Career = _career()
	var w: World = c.world()
	WorldWeeks.advance(w, 60, {}, _new_year(c))
	var said: int = 0
	for k: String in w.ranking_moves:
		for mv: Dictionary in w.ranking_moves[k].moves:
			assert_ne(String(mv.why), "", "a reason")
			if String(mv.why).begins_with("beat ") or String(mv.why).begins_with("lost to "):
				said += 1
	assert_gt(said, 20, "moves for fights")
	for k: String in w.rankings:
		for id: String in w.rankings[k]:
			var m: Dictionary = w.man(id)
			assert_true(World.active(m))
			assert_lt(60 - int(m.points[-1][0]), Rankings.OUT_WEEKS, "everyone ranked has fought within the year")
	var top: Array = w.results.filter(func(r: Dictionary) -> bool: return String(r.get("kind", "")) == "ranked")
	assert_false(top.is_empty(), "a new #1 is news")


func test_ranked_men_are_matched_near_their_rank() -> void:
	var c: Career = _career()
	var w: World = c.world()
	var events: Array = WorldWeeks.advance(w, 52, {}, _new_year(c))
	var both: Array = events.filter(func(r: Dictionary) -> bool:
		return r.get("ranks") is Array and int(r.ranks[0]) > 0 and int(r.ranks[1]) > 0)
	assert_gt(both.size(), 100)
	var near: int = both.filter(func(r: Dictionary) -> bool: return absi(int(r.ranks[0]) - int(r.ranks[1])) <= 3).size()
	assert_gt(float(near) / both.size(), 0.75, "most within three places")


func test_his_pro_fight_on_a_card_ranks_him_in_that_promotion() -> void:
	var c: Career = _career()
	c.trainee.age_years = 21.0
	c.pro = true
	c.division = c.natural_division()
	var w: World = c.world()
	var home: Dictionary = Promotions.home(w)
	var week: int = Promotions.card_weeks(home, 1, 30)[0]
	c.week = week
	w = c.world()
	var ids: Array = Rankings.table(w, String(home.id), c.division)
	var victim: String = String(ids[0])
	c.booked = { "opponent": victim, "week": week, "ruleset": "amateur_mma", "card": Promotions.card(w, home, week) }
	c.finish_fight({ "result": "win", "method": "KO/TKO", "round": 1 })
	assert_eq(String(w.him.promotion), String(home.id))
	assert_eq((w.him.points as Array).size(), 1)
	assert_eq(int(w.him.points[0][3]), 1, "he beat the #1")
	Rankings.update(w, week)
	assert_gt(Rankings.rank_of(w, Career.FIGHTER_ID), 0, "he's ranked")
	assert_string_contains(CareerHub.his_rank_text(c), "Ranked #")
	var mine: Array = w.results.filter(func(r: Dictionary) -> bool: return String(r.get("kind", "")) == "ranked" and String(r.id) == Career.FIGHTER_ID)
	assert_eq(mine.size(), 1, "his move is news")
	assert_string_contains(String(mine[0].why), "beat #1")
	assert_lt((w.man(victim).points as Array)[-1][1], 0.0, "the man he beat lost points")


func test_rankings_are_saved_and_a_world_saved_before_them_gets_them() -> void:
	var c: Career = _career()
	c.world()
	c.run_week("time_off")
	var back: Career = Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(JSON.stringify(back.world().rankings), JSON.stringify(c.world().rankings), "saved")
	assert_eq(Rankings.rank_of(back.world(), String(c.world().rankings["org_0:lightweight"][0])), 1)
	var old: Dictionary = c.to_dict()
	old.world.erase("rankings")
	old.world.erase("ranking_moves")
	old.world.erase("him")
	for m: Dictionary in old.world.men:
		m.erase("points")
	var older: Career = Career.from_dict(JSON.parse_string(JSON.stringify(old)))
	assert_eq(older.world().rankings.size(), c.world().rankings.size(), "made when loaded")


func test_the_hub_shows_the_rankings_and_the_numbers_by_names() -> void:
	var c: Career = _career()
	c.trainee.age_years = 21.0
	c.pro = true
	c.division = c.natural_division()
	var w: World = c.world()
	WorldWeeks.advance(w, 30, {}, _new_year(c))
	c.week = 31
	var text: String = CareerHub.rankings_text(c)
	for p: Dictionary in w.promotions:
		assert_string_contains(text, String(p.name))
	assert_string_contains(text, "1. ")
	assert_string_contains(text, "Moves after ")
	assert_string_contains(text, "Not ranked yet")
	assert_string_contains(CareerHub.division_text(c), "#1 ")
	assert_eq(CareerHub.rankings_title(c), "%s rankings" % Weight.name_of(c.division_now()))
	var id: String = String(Rankings.table(w, String(Promotions.home(w).id), c.division_now())[0])
	assert_string_contains(CareerHub.opponent_rank_text(c, id), "Ranked #1")
