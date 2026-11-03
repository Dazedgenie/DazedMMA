extends GutTest
## The hub rebuilt round the next fight (ui/career_hub.gd, ui/fight_poster.gd, ui/calendar_icon.gd; docs/06 §6.13,
## D433): offers as posters, the booked fight counting down, the tab bar, his card's tabs, the calendar's icons and the
## promotion badges on the news.


func _career() -> Career:
	return Career.start({ "coach": "Sam Reed", "name": "Danny Hill", "nickname": "The Kid", "hometown": "Leeds", "country": "England",
		"background": "street_kid", "stance": "orthodox" }, 3, FighterLibrary.load_dir())


func _with_offers() -> Career:
	var c: Career = _career()
	var guard: int = 0
	while c.offers.is_empty() and guard < 12:
		c.advance()
		guard += 1
	return c


func _hub(c: Career) -> CareerHub:
	var hub: CareerHub = add_child_autofree(CareerHub.new())
	hub.show_career(c)
	return hub


func test_each_offer_is_a_poster_with_both_men_face_to_face() -> void:
	var c: Career = _with_offers()
	assert_false(c.offers.is_empty(), "offers came in")
	var hub: CareerHub = _hub(c)
	for o: Dictionary in c.offers:
		var poster: FightPoster = hub.poster(String(o.id))
		assert_not_null(poster, "a poster for each offer")
		assert_eq(String(poster.his_face.profile.get("id", "")), Career.FIGHTER_ID, "him on the left")
		assert_eq(String(poster.their_face.profile.get("id", "")), String(o.profile.id), "the other man on the right")
		assert_eq(poster.his_face.corner, 0)
		assert_eq(poster.their_face.corner, 1)
		assert_string_contains(poster.details.text, String(o.profile.name), "the scouting card under them")
	assert_null(hub.poster(CareerHub.BOOKED_POSTER), "nothing booked")


func test_take_the_fight_on_a_poster_takes_that_offer() -> void:
	var c: Career = _with_offers()
	var hub: CareerHub = _hub(c)
	var taken: Array = []
	hub.accept_pressed.connect(func(id: String) -> void: taken.append(id))
	var id: String = String(c.offers[-1].id)
	hub.poster(id).take.pressed.emit()
	assert_eq(taken, [id])


func test_a_coachs_pick_wears_its_ribbon() -> void:
	var c: Career = _with_offers()
	var hub: CareerHub = _hub(c)
	for o: Dictionary in c.offers:
		var ribbons: Array[String] = hub.poster(String(o.id)).ribbons()
		assert_eq("COACH'S PICK" in ribbons, int(o.get("lesson", 0)) > 0, "the ribbon only on the Coach's pick")


func test_a_booked_fight_counts_down_the_weeks_to_fight_night() -> void:
	var c: Career = _with_offers()
	c.accept(String(c.offers[0].id))
	var hub: CareerHub = _hub(c)
	var poster: FightPoster = hub.poster(CareerHub.BOOKED_POSTER)
	assert_not_null(poster, "the booked fight's poster")
	var left: int = c.camp_weeks_left()
	assert_eq(poster.countdown.text, "%d WEEK%s" % [left, "" if left == 1 else "S"])
	assert_false(poster.take.is_visible_in_tree(), "nothing to take")
	c.run_week()
	hub.show_career(c)
	assert_eq(hub.poster(CareerHub.BOOKED_POSTER), poster, "the same poster week to week")
	assert_eq(poster.countdown.text, "%d WEEK%s" % [left - 1, "" if left - 1 == 1 else "S"], "a week nearer")


func test_the_calendar_has_an_icon_for_each_thing_coming() -> void:
	var c: Career = _with_offers()
	c.accept(String(c.offers[0].id))
	var hub: CareerHub = _hub(c)
	var icons: Array[String] = []
	for icon: Node in hub.find_children("*", "CalendarIcon", true, false):
		icons.append((icon as CalendarIcon).kind)
	assert_true(Career.FIGHT_NIGHT in icons, "fight night on the calendar")
	assert_string_contains(hub.text(), "Fight night")
	for kind: String in CalendarIcon.COLOURS:
		assert_ne(CalendarIcon.colour_of(kind), Color("#adb5bd"), "%s has its own colour" % kind)


func test_his_card_has_about_and_stats_on_tabs() -> void:
	var hub: CareerHub = _hub(_career())
	var scrolls: Array[ScrollContainer] = hub.scrolls()
	assert_true(scrolls[0].visible, "About first")
	assert_false(scrolls[1].visible)
	hub.show_card_tab(true)
	assert_false(scrolls[0].visible)
	assert_true(scrolls[1].visible, "his stat bars")


func test_the_tab_bar_opens_the_world_pages_and_the_hub_stays_down() -> void:
	var hub: CareerHub = _hub(_career())
	var opened: Array[String] = []
	hub.division_pressed.connect(func() -> void: opened.append("division"))
	hub.rankings_pressed.connect(func() -> void: opened.append("rankings"))
	hub.promotions_pressed.connect(func() -> void: opened.append("promotions"))
	hub.history_pressed.connect(func() -> void: opened.append("history"))
	hub.notebook_pressed.connect(func() -> void: opened.append("notebook"))
	hub.press_division()
	hub.press_rankings()
	hub.press_promotions()
	hub.press_history()
	hub.press_notebook()
	assert_eq(opened, ["division", "rankings", "promotions", "history", "notebook"])
	assert_false(hub._division.button_pressed, "springs back: the hub's still the tab that's down")


func test_news_lines_carry_their_promotion_for_its_badge() -> void:
	var c: Career = _career()
	c.trainee.age_years = 21.0
	c.pro = true
	c.division = c.natural_division()
	WorldWeeks.advance(c.world(), c.week + 8, {}, func(w: int) -> Dictionary: return c.date(0, w))
	c.week += 9
	var items: Array = CareerHub.news_items(c, 9)
	assert_false(items.is_empty(), "nine weeks of a division make news")
	var with_badge: int = 0
	for item: Array in items:
		assert_eq(item.size(), 2)
		if String(item[1]) != "":
			with_badge += 1
			assert_false(Promotions.by_id(c.world(), String(item[1])).is_empty(), "a real promotion")
	assert_gt(with_badge, 0, "fights on promotions' cards carry their badge")
	assert_string_contains(CareerHub.news_text(c, 9), String(items[0][0]), "the text version says the same")
	var hub: CareerHub = _hub(c)
	var promotion: String = ""
	for item: Array in items:
		if String(item[1]) != "":
			promotion = String(item[1])
	var row: HBoxContainer = hub._line_row(c.world(), promotion, String(items[0][0]))
	add_child_autofree(row)
	assert_eq(row.find_children("*", "PromotionBadge", true, false).size(), 1, "the line's badge on the hub")
