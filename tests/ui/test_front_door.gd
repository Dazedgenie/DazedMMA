extends GutTest
## The front door rebuilt (docs/06 §6.14, D434; the placeholder title art §6.18, D470, D471): a real fight behind the title (game/title_backdrop.gd) with the menu
## down the left, the new-career page with him in the middle and the backgrounds as tiles, him at each age of his
## childhood, the gym cards with the owner and chips, him in the doorway at the walk-in, and his face on the load slots.

const SAVE_DIR := "user://test_front_door_saves/"


func after_each() -> void:
	if DirAccess.dir_exists_absolute(SAVE_DIR):
		for file in DirAccess.get_files_at(SAVE_DIR):
			DirAccess.remove_absolute(SAVE_DIR.path_join(file))


func _choices() -> Dictionary:
	return { "coach": "Sam Reed", "name": "Danny Hill", "nickname": "The Kid", "hometown": "Leeds", "country": "England",
		"country_id": "england", "background": "farm_kid", "stance": "orthodox",
		"look": { "skin": 2, "hair": "black", "hair_style": "short", "beard": "beard" } }


func test_the_title_fight_is_two_different_men_never_the_tests_own() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var ids: Array = FighterLibrary.load_dir().ids()
	for i in 40:
		var pair: Array[String] = TitleBackdrop.pick_pair(ids, rng)
		assert_eq(pair.size(), 2)
		assert_ne(pair[0], pair[1], "two different men")
		for id in pair:
			assert_false(id.begins_with(TitleBackdrop.LEFT_OUT_PREFIX), "not a test fighter")
	assert_eq(TitleBackdrop.pick_pair(["check_red", "boxer"], rng), [] as Array[String], "not enough to make a pair")


func test_the_title_fight_runs_in_the_cage_and_a_new_pair_follows_the_end() -> void:
	var arena: ArenaView = add_child_autofree(ArenaView.new())
	var backdrop := TitleBackdrop.new(FighterLibrary.load_dir(), ActionLibrary.load_dir(), 7)
	backdrop.start(arena)
	assert_true(backdrop.running())
	assert_eq(arena.driver, backdrop.driver, "the cage shows it")
	assert_true(arena.backdrop, "no names over their heads, no range tag")
	for i in 2:
		assert_eq(backdrop.driver.sim.corners[i].style, Corner.AI, "both corners the AI's")
	var before: int = backdrop.driver.sim.now
	backdrop.advance(arena, 1.0)
	assert_gt(backdrop.driver.sim.now, before, "the fight moves on at its own pace")
	while not backdrop.driver.sim.is_over():
		backdrop.driver.step()
	var first: FightDriver = backdrop.driver
	backdrop.advance(arena, TitleBackdrop.NEXT_AFTER * 0.5)
	assert_eq(backdrop.driver, first, "the finish is held a while")
	backdrop.advance(arena, TitleBackdrop.NEXT_AFTER)
	assert_ne(backdrop.driver, first, "then a new pair")
	assert_eq(backdrop.fights, 2)
	backdrop.stop(arena)
	assert_false(backdrop.running())
	assert_null(arena.driver, "the cage is left free for a real fight")
	assert_false(arena.backdrop)


func test_the_title_starts_its_fight_and_leaving_it_stops_the_fight() -> void:
	var main: Node = load("res://game/main.tscn").instantiate()
	main.backdrop_in_headless = true
	main.title_fight = true  # As with TitleScreen.PAINTED off (D470).
	add_child_autofree(main)
	main.save_dir = SAVE_DIR
	main.show_title()
	assert_true(main.backdrop.running(), "a fight behind the title")
	main.quick_fight()
	assert_false(main.backdrop.running(), "stopped when the title goes")
	main.show_title()
	assert_true(main.backdrop.running())
	var s: Dictionary = main.setup.settings()
	s.seed = 3
	main.start_fight(s)
	assert_false(main.backdrop.running(), "a real fight has the cage")
	assert_eq(main.arena.driver, main.driver)


func test_the_title_shows_the_painting_and_leaves_the_cage_empty() -> void:
	assert_true(TitleScreen.PAINTED, "the placeholder painting is on (D470)")
	var main: Node = load("res://game/main.tscn").instantiate()
	main.backdrop_in_headless = true
	add_child_autofree(main)
	main.save_dir = SAVE_DIR
	main.show_title()
	assert_false(main.backdrop.running(), "no fight behind the painting")
	assert_null(main.arena.driver, "the cage is left free")
	var art: TextureRect = main.title.find_child("Art", true, false)
	assert_not_null(art, "the painting is behind the menu")
	assert_not_null(art.texture, "and it loads")


func test_the_title_logo_loads_and_sits_in_the_strip() -> void:
	var title: TitleScreen = add_child_autofree(TitleScreen.new())
	await wait_process_frames(2)
	var logo: TextureRect = title.find_child("Logo", true, false)
	assert_not_null(logo)
	assert_not_null(logo.texture, "the emblem loads (D471)")
	assert_lt(logo.get_global_rect().end.x, TitleScreen.STRIP_WIDTH, "the logo is in the strip")
	assert_gt(logo.size.y, 100.0, "and is drawn big")


func test_the_title_menu_sits_down_the_left() -> void:
	var title: TitleScreen = add_child_autofree(TitleScreen.new())
	await wait_process_frames(2)
	for b: Button in title.find_children("*", "Button", true, false):
		if b.visible:
			assert_lt(b.get_global_rect().end.x, TitleScreen.STRIP_WIDTH, "%s is in the strip" % b.text)


func test_the_new_career_page_has_a_tile_for_each_background_and_him_in_the_middle() -> void:
	var screen: NewCareerScreen = add_child_autofree(NewCareerScreen.new())
	screen.roll(5)
	var ids: Array = BackgroundLibrary.shared().ids()
	assert_eq(screen.tiles().size(), ids.size(), "a tile for each background")
	for i in ids.size():
		var icons: Array[Node] = screen.tiles()[i].find_children("*", "BackgroundIcon", true, false)
		assert_eq(icons.size(), 1)
		assert_true(BackgroundIcon.knows((icons[0] as BackgroundIcon).id), "%s has its own picture" % ids[i])
	screen.set_play_childhood(false)
	screen.tiles()[3].pressed.emit()
	assert_eq(screen.background_id(), String(ids[3]), "pressing a tile picks it")
	screen.pick_background(String(ids[7]))
	assert_true(screen.tiles()[7].button_pressed, "the picked tile lit")
	assert_false(screen.tiles()[3].button_pressed)
	screen.set_field("name", "Danny Hill")
	screen.set_field("nickname", "The Kid")
	assert_eq(screen._plate_name.text, "DANNY HILL 'THE KID'", "his name under him")


func test_his_childhood_shows_him_growing_up() -> void:
	var screen: ChildhoodScreen = add_child_autofree(ChildhoodScreen.new())
	screen.begin(9, _choices())
	assert_eq(String(screen.portrait.profile.get("id", "")), "childhood_8", "him at 8 beside the first scene")
	var eight: Dictionary = screen.at_age(8)
	var twelve: Dictionary = screen.at_age(12)
	var fifteen: Dictionary = screen.at_age(15)
	assert_lt(int(eight.frame.height_cm), int(twelve.frame.height_cm))
	assert_lt(int(twelve.frame.height_cm), int(fifteen.frame.height_cm))
	assert_eq(String(eight.look.beard), "none", "no beard at 8")
	assert_eq(String(fifteen.look.beard), "beard", "his own look at 15")
	assert_eq(String(eight.look.hair), "black", "his hair as picked")
	for i in 3:
		screen.press_choice(0)
		screen.press_next()
	assert_true(screen.on_summary())
	assert_eq(int(screen.portrait.profile.frame.height_cm), int(screen.he_became().frame.height_cm), "as he starts at 16")


func test_each_gym_card_shows_its_owner_and_what_it_trains_as_chips() -> void:
	var wrestling: Dictionary = { "kind": "wrestling_club", "culture": "party" }
	var chips: Array = GymScreen.chips(wrestling)
	assert_true(["Wrestling +25%", true] in chips, "better in green")
	assert_true(["Striking −25%", false] in chips, "worse in red")
	assert_true(["More skipped sessions", false] in chips, "the culture too")
	assert_true(["Fewer skipped sessions", true] in GymScreen.chips({ "kind": "boxing_gym", "culture": "family" }))
	var screen: GymScreen = add_child_autofree(GymScreen.new())
	screen.begin(_choices(), 5)
	assert_eq(screen.owner_faces.size(), 3, "an owner's face on each card")
	for n in 3:
		assert_eq(String(screen.owner_faces[n].profile.name), String(screen.gyms[n].owner_name))
		assert_false(Dictionary(screen.owner_faces[n].profile.look).is_empty(), "looks like where he's from")


func test_the_walk_in_shows_him_in_the_doorway_as_he_will_start() -> void:
	var screen: GymScreen = add_child_autofree(GymScreen.new())
	var choices: Dictionary = _choices()
	screen.begin(choices, 5)
	screen.pick(1)
	var him: Dictionary = screen.doorway.profile
	var c: Career = Career.start(choices, 5, FighterLibrary.load_dir())
	assert_eq(int(him.frame.height_cm), int(c.profile().frame.height_cm), "his own height, as his career makes him")
	assert_eq(String(him.look.hair), "black", "his look as picked")
	assert_eq(String(screen.owner_face.profile.name), String(screen.gyms[1].owner_name), "the owner by his line")


func test_each_load_slot_shows_his_face_division_and_belt() -> void:
	var c: Career = Career.start(_choices(), 3, FighterLibrary.load_dir())
	var s: Dictionary = c.summary()
	assert_false(Dictionary(s.portrait).is_empty(), "the save says how to draw him")
	assert_eq(String(s.belt), "", "no belt yet")
	assert_true(CareerSaves.save(c, 0, SAVE_DIR))
	var screen: LoadScreen = add_child_autofree(LoadScreen.new())
	screen.save_dir = SAVE_DIR
	screen.refresh()
	var faces: Array[Node] = screen.find_children("*", "FighterPortrait", true, false)
	assert_eq(faces.size(), CareerSaves.SLOTS)
	assert_true((faces[0] as FighterPortrait).visible, "his face on his slot")
	assert_false((faces[1] as FighterPortrait).visible, "none on an empty one")
	assert_eq(LoadScreen.portrait_of({ "name": "Old Save" }, 0), {}, "a save from before has no face")
	var champ: String = LoadScreen.slot_text({ "name": "Danny Hill", "pro": true, "pro_record": "9-0-0",
		"division": "welterweight", "belt": "the IML welterweight title" })
	assert_string_contains(champ, "Welterweight")
	assert_string_contains(champ, "Champion:")
	assert_string_contains(champ, "IML welterweight title")
