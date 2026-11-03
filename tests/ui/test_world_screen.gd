extends GutTest
## The world pages (ui/world_screen.gd, docs/06 §6.12, D432): his division as a table to sort and filter, each
## promotion's rankings and belt history on its own tab, the promotions as cards, the badges drawn in code, and a man's
## card at the side. (One career with 2 years of history is shared by the tests that read it.)

var _c: Career
var _page: WorldScreen


func before_all() -> void:
	Career.history_years = 2
	_c = Career.start({ "coach": "Sam Reed", "name": "Danny Hill", "nickname": "The Kid", "hometown": "Leeds", "country": "England",
		"background": "street_kid", "stance": "orthodox" }, 3, FighterLibrary.load_dir())
	while _c.history_pending():
		_c.play_history(52)
	Career.history_years = 0


func before_each() -> void:
	_page = WorldScreen.new()
	_page.size = Vector2(1920.0, 1080.0)
	add_child_autofree(_page)
	_page.sort_key = "grade"
	_page.sort_down = true


func _names(tree: Tree) -> Array[String]:
	var out: Array[String] = []
	var item: TreeItem = tree.get_root().get_first_child()
	while item != null:
		out.append(String(item.get_metadata(0)) if item.get_metadata(0) != null else "")
		item = item.get_next()
	return out


func test_each_hub_button_opens_the_world_pages_on_its_own_tab() -> void:
	for tab: String in [WorldScreen.DIVISION, WorldScreen.RANKINGS, WorldScreen.PROMOTIONS, WorldScreen.HISTORY]:
		_page.show_world(_c, tab)
		assert_true(_page.visible)
		assert_eq(_page.tab, tab)
		for other: String in _page._pages:
			assert_eq((_page._pages[other] as Control).visible, other == tab, "%s shows only its own page" % tab)
	_page.close_page()
	assert_false(_page.visible, "back to the hub")


func test_his_division_lists_every_man_in_it_and_him_picked_out() -> void:
	_page.show_world(_c, WorldScreen.DIVISION)
	var ids: Array[String] = _names(_page.division_tree)
	var men: Array[Dictionary] = CareerHub.division_men(_c)
	assert_eq(ids.size(), men.size() + 1, "every man and him")
	assert_true(Career.FIGHTER_ID in ids, "him in it")
	var item: TreeItem = _page.division_tree.get_root().get_child(ids.find(Career.FIGHTER_ID))
	assert_eq(item.get_custom_bg_color(0), WorldScreen.HIM_ROW, "picked out")
	assert_string_contains(item.get_text(0), "Danny Hill")


func test_clicking_a_column_sorts_by_it_and_again_turns_it_round() -> void:
	_page.show_world(_c, WorldScreen.DIVISION)
	_page.sort_by("age")
	assert_eq(_page.sort_key, "age")
	assert_false(_page.sort_down, "youngest first the first time")
	var ages: Array[float] = []
	for r: Dictionary in _page.shown_rows():
		ages.append(float(r.keys.age))
	for i in range(1, ages.size()):
		assert_true(ages[i] >= ages[i - 1], "youngest first")
	_page.sort_by("age")
	assert_true(_page.sort_down, "the same column again: oldest first")
	var rows: Array[Dictionary] = _page.shown_rows()
	assert_true(float(rows[0].keys.age) >= float(rows[-1].keys.age))
	_page.sort_by("grade")
	assert_true(_page.sort_down, "best grade first")


func test_the_filters_keep_him_in_and_the_men_they_name() -> void:
	_page.show_world(_c, WorldScreen.DIVISION)
	_page.set_filter("pros")
	for r: Dictionary in _page.shown_rows():
		assert_true(bool(r.pro) or bool(r.mine), "pros (and him)")
	_page.set_filter("amateurs")
	for r: Dictionary in _page.shown_rows():
		assert_true(not bool(r.pro) or bool(r.mine))
	_page.set_filter("fought")
	assert_eq(_page.shown_rows().size(), 1, "nobody fought yet: just him")
	_page.set_filter("all")


func test_rankings_open_on_his_home_promotion_with_its_champion_and_table() -> void:
	_page.show_world(_c, WorldScreen.RANKINGS)
	var w: World = _c.world()
	assert_eq(_page.promotion_id, String(Promotions.home(w).id), "an amateur's home promotion")
	var table: Array = Rankings.table(w, _page.promotion_id, _c.division_now())
	assert_eq(_names(_page.rank_tree).size(), table.size())
	if not table.is_empty():
		assert_eq(String(_page.rank_tree.get_root().get_first_child().get_metadata(0)), String(table[0]), "#1 first")
	var world_org: String = String(WorldScreen.ordered(w)[0].id)
	_page.show_promotion(world_org)
	assert_eq(_names(_page.rank_tree).size(), Rankings.table(w, world_org, _c.division_now()).size(), "another promotion's table")
	assert_string_contains(_page._champion.text, "Champion", "its champion (or that it's vacant) over it")


func test_history_shows_each_reign_on_the_timeline_newest_first() -> void:
	var w: World = _c.world()
	var with_reigns: String = ""
	for p: Dictionary in WorldScreen.ordered(w):
		if not History.line_of(w, Rankings.key(String(p.id), _c.division_now())).is_empty():
			with_reigns = String(p.id)
			break
	assert_ne(with_reigns, "", "two years of history crowned someone")
	_page.show_world(_c, WorldScreen.HISTORY)
	_page.show_promotion(with_reigns)
	var reigns: Array = _page.timeline.reigns
	assert_eq(reigns.size(), History.line_of(w, Rankings.key(with_reigns, _c.division_now())).size(), "a row a reign")
	for i in range(1, reigns.size()):
		assert_true(int(reigns[i][2]) <= int(reigns[i - 1][2]), "newest first")
	await wait_process_frames(2)
	var bar: Rect2 = _page.timeline.bar_of(0)
	assert_gt(bar.size.x, 0.0)
	assert_gt(_page.timeline.custom_minimum_size.y, BeltTimeline.AXIS_HEIGHT, "tall enough for its rows")


func test_clicking_a_man_opens_his_card_with_his_portrait() -> void:
	_page.show_world(_c, WorldScreen.DIVISION)
	var men: Array[Dictionary] = CareerHub.division_men(_c)
	var id: String = String(men[0].id)
	_page.show_man(id)
	assert_true(_page.man_card.visible)
	assert_eq(_page.man_card.id, id)
	assert_eq(_page.man_card._name.text, String(men[0].name))
	assert_string_contains(_page.man_card._text.text, World.record_text(men[0]))
	assert_string_contains(_page.man_card._text.text, "SCOUTED")
	assert_eq(String(_page.man_card.portrait.profile.get("id", "")), id, "his own portrait")
	_page.show_man(Career.FIGHTER_ID)
	assert_eq(_page.man_card._name.text, "Danny Hill", "and yours")


func test_badges_are_gold_and_crimson_at_the_top_and_each_regional_its_own_colour() -> void:
	var w: World = _c.world()
	var seen: Dictionary = {}
	for p: Dictionary in w.promotions:
		var colour: Color = PromotionBadge.colour_of(w, p)
		var shape: String = PromotionBadge.shape_of(p)
		match int(p.rank):
			0:
				assert_eq(colour, PromotionBadge.WORLD_GOLD)
				assert_eq(shape, PromotionBadge.PLATE, "the world organisation: a belt plate")
			1:
				assert_eq(colour, PromotionBadge.INTERNATIONAL_CRIMSON)
				assert_eq(shape, PromotionBadge.SHIELD, "the international one: a shield")
			_:
				assert_eq(shape, PromotionBadge.ROUND, "a regional: round")
				assert_false(seen.has(colour.to_html()), "every regional its own colour")
				seen[colour.to_html()] = true
				assert_eq(PromotionBadge.colour_of(w, p), colour, "the same all career")


func test_the_promotions_page_has_a_card_for_each_promotion() -> void:
	_page.show_world(_c, WorldScreen.PROMOTIONS)
	await wait_process_frames(1)
	assert_eq(_page._promotion_grid.get_child_count(), _c.world().promotions.size())


func test_the_main_scene_opens_the_world_pages_from_the_hub() -> void:
	var main: Node = load("res://game/main.tscn").instantiate()
	add_child_autofree(main)
	await wait_process_frames(1)
	main.career = _c
	main.show_hub()
	main.open_rankings()
	assert_true(main.world_page.visible)
	assert_eq(main.world_page.tab, WorldScreen.RANKINGS)
	main.world_page.close_page()
	assert_true(main.hub.visible, "the hub under it")
