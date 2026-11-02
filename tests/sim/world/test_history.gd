extends GutTest
## The world's history (sim/world/history.gd, docs/03 §12.8, D358): a new career's world played for years before his
## first week, every reign kept, the legends, former champions marked, his hometown's legend and the History page.
## (The test run turns the history off for every other test, tests/pre_run.gd; these turn a little back on.)

const YEARS: int = 2


func before_each() -> void:
	Career.history_years = YEARS


func after_each() -> void:
	Career.history_years = 0


func _career(career_seed: int = 3) -> Career:
	return Career.start({ "coach": "Sam Reed", "name": "Danny Hill", "hometown": "Leeds", "country": "England",
		"background": "street_kid", "stance": "orthodox" }, career_seed, FighterLibrary.load_dir())


func test_a_new_career_starts_after_years_of_the_worlds_history_on_the_same_date() -> void:
	var c: Career = _career()
	assert_eq(c.start_week, YEARS * 52)
	assert_eq(c.week, c.start_week)
	assert_eq(c.date_text(), "Mon 4 Jan 2027", "his first week is the same date as before")
	assert_eq(int(c.date(0, 0).year), 2027 - YEARS, "the calendar starts that much earlier")
	assert_true(c.history_pending())
	var steps: int = 0
	var last: float = 0.0
	while true:
		var done: float = c.play_history(13)
		assert_gte(done, last, "it only goes forward")
		last = done
		steps += 1
		if done >= 1.0:
			break
	assert_between(steps, YEARS * 4 - 1, YEARS * 4 + 1, "a slice at a time")
	assert_false(c.history_pending())
	var w: World = c.world()
	assert_eq(w.played, c.week - 1, "played up to his first week")
	var fought: Array = w.men.values().filter(func(m: Dictionary) -> bool: return int(m.record.win) + int(m.record.loss) >= 5)
	assert_gt(fought.size(), 100, "men with records behind them")
	assert_false(w.reigns.is_empty(), "belts have changed hands")
	var hub := CareerHub.new()
	add_child_autofree(hub)
	hub.show_career(c)
	assert_string_contains(hub._date.text, "WEEK 1", "his weeks count from his start")


func test_every_reign_is_kept_and_saved() -> void:
	var c: Career = _career()
	var w: World = c.world()
	var ended: int = 0
	for id: String in w.reigns:
		for r: Array in w.reigns[id]:
			ended += 1
			assert_true(w.titles.has(String(r[0])))
			assert_lte(int(r[1]), int(r[2]), "won before lost")
			assert_true(String(r[4]) in ["lost", "retired", "stripped", "called up", "left"])
			assert_false(w.man(id).is_empty(), "the man is kept")
	assert_gt(ended, 20)
	var line: Array = History.line_of(w, "org_0:lightweight")
	assert_false(line.is_empty())
	assert_eq(String(line[0][0]), Titles.champion(w, "org_0", "lightweight"), "the champion now first")
	var back: Career = Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.start_week, c.start_week)
	assert_eq(JSON.stringify(back.world().reigns), JSON.stringify(w.reigns), "saved")
	assert_false(back.history_pending(), "a loaded career doesn't play it again")


func test_legends_are_world_champions_and_long_reigns_and_former_champions_are_marked() -> void:
	var c: Career = _career()
	var w: World = c.world()
	var legends: Array = History.legends(w)
	assert_false(legends.is_empty())
	for id: String in legends:
		var big: bool = false
		for r: Array in History.reigns_of(w, id):
			big = big or History.belt_rank(w, String(r[0])) == Promotions.MAJOR or int(r[3]) >= History.LEGEND_DEFENCES
		assert_true(big, "a world champion or a long reign")
	for i in range(1, legends.size()):
		assert_gte(History.legacy(w, legends[i - 1]), History.legacy(w, legends[i]), "best first")
	var former: String = ""
	for id: String in w.reigns:
		if World.active(w.man(id)) and Titles.held_by(w, id) == "":
			former = id
			break
	assert_ne(former, "")
	var tag: String = History.former_tag(w, former)
	assert_string_starts_with(tag, "former ")
	assert_string_ends_with(tag, " champion")
	assert_eq(History.former_tag(w, Titles.champion(w, "org_0", "lightweight")), "", "a champion now isn't a former one")


func test_his_hometown_has_a_legend_and_the_hub_names_him() -> void:
	var c: Career = _career()
	var w: World = c.world()
	var id: String = History.home_legend(w)
	assert_ne(id, "")
	var home: Dictionary = Promotions.home(w)
	assert_true(History.reigns_of(w, id).any(func(r: Array) -> bool: return String(r[0]).get_slice(":", 0) == String(home.id)),
		"he's held the home promotion's belt")
	var text: String = CareerHub.home_legend_text(c)
	assert_string_contains(text, "The %s's best ever" % String(home.short))
	assert_string_contains(text, String(w.man(id).name))
	assert_string_contains(CareerHub.promotions_text(c), "best ever")
	c.trainee.age_years = 21.0
	c.pro = true
	c.division = c.natural_division()
	assert_string_contains(CareerHub.week_text(c), "best ever", "in his first pro weeks")


func test_the_history_page_shows_each_belts_champions_and_the_legends() -> void:
	var c: Career = _career()
	var text: String = CareerHub.history_text(c)
	var w: World = c.world()
	for p: Dictionary in w.promotions:
		assert_string_contains(text, "%s %s champions" % [String(p.name), Weight.name_of(c.division_now()).to_lower()])
	assert_string_contains(text, "LEGENDS")
	assert_string_contains(text, "defence")
	assert_string_contains(CareerHub.history_title(c), Weight.name_of(c.division_now()))
	var hub := CareerHub.new()
	add_child_autofree(hub)
	hub.show_career(c)
	var opened: Array = []
	hub.history_pressed.connect(func() -> void: opened.append(true))
	hub.press_history()
	assert_eq(opened.size(), 1)


func test_a_career_saved_before_the_history_carries_on_without_one() -> void:
	Career.history_years = 0
	var c: Career = _career()
	c.world()
	var old: Dictionary = c.to_dict()
	(old.calendar as Dictionary).erase("start_week")
	(old.world as Dictionary).erase("reigns")
	var back: Career = Career.from_dict(JSON.parse_string(JSON.stringify(old)))
	assert_eq(back.start_week, 0)
	assert_false(back.history_pending())
	assert_true(back.world().reigns.is_empty())
	assert_eq(CareerHub.home_legend_text(back), "", "no history to look back on")
