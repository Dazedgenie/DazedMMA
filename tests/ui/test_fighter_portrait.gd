extends GutTest
## Fighter portraits (ui/fighter_portrait.gd, D431, docs/06 §6.11): each man drawn as himself off the fight screen,
## with the body figure as a small hurt badge.

var _roster: FighterLibrary


func before_all() -> void:
	_roster = FighterLibrary.load_dir()


func _portrait(id: String, framing: String = FighterPortrait.FULL, corner: int = 0) -> FighterPortrait:
	var portrait := FighterPortrait.new(framing, corner)
	portrait.size = Vector2(300.0, 500.0)
	add_child_autofree(portrait)
	portrait.show_fighter(_roster.profile(id))
	portrait.build_now()
	return portrait


func test_a_portrait_draws_the_man_with_the_skinned_body_and_his_look() -> void:
	var portrait: FighterPortrait = _portrait("boxer")
	assert_not_null(portrait.figure, "he's built")
	assert_not_null(portrait.figure.body, "with the skinned body, not the pieces")
	assert_eq(portrait.figure.look, FighterLook.for_profile(_roster.profile("boxer")), "his own look")


func test_nothing_is_built_until_he_is_drawn() -> void:
	var portrait := FighterPortrait.new()
	add_child_autofree(portrait)
	portrait.show_fighter(_roster.profile("boxer"))
	assert_null(portrait.figure, "a screen that's never shown costs nothing")


func test_full_body_portraits_share_one_scale_so_the_taller_man_stands_taller() -> void:
	var heights: Dictionary = {}
	for id: String in _roster.ids():
		heights[id] = float(_roster.profile(id).get("frame", {}).get("height_cm", 0.0))
	var ids: Array = heights.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return heights[a] < heights[b])
	var short: FighterPortrait = _portrait(ids[0])
	var tall: FighterPortrait = _portrait(ids[-1])
	assert_gt(heights[ids[-1]], heights[ids[0]], "the roster has men of different heights")
	assert_gt(tall.figure.scale.y, short.figure.scale.y, "drawn taller")
	assert_almost_eq(tall._camera.position.y, short._camera.position.y, 0.0001, "the same camera for both")


func test_a_bust_looks_at_his_head_and_chest() -> void:
	var full: FighterPortrait = _portrait("wrestler")
	var bust: FighterPortrait = _portrait("wrestler", FighterPortrait.BUST)
	assert_gt(bust._camera.position.y, full._camera.position.y, "higher up him")
	assert_lt(bust._camera.position.length(), full._camera.position.length(), "and closer")


func test_his_shorts_are_his_corners() -> void:
	assert_eq(_portrait("boxer", FighterPortrait.FULL, 0).figure.colour, ArenaView.FIGHTER_COLOURS[0])
	assert_eq(_portrait("boxer", FighterPortrait.FULL, 1).figure.colour, ArenaView.FIGHTER_COLOURS[1])


func test_the_hurt_badge_shows_only_once_he_is_hurt_unless_always_up() -> void:
	var portrait: FighterPortrait = _portrait("kicker")
	portrait.set_hurt({ "head": 0.0, "body": 0.0, "legs": 0.0 })
	assert_false(portrait.badge.visible, "fresh: no badge")
	portrait.set_hurt({ "head": 0.0, "body": 0.0, "legs": 0.3 })
	assert_true(portrait.badge.visible, "hurt: the badge shows where")
	assert_almost_eq(float(portrait.badge.hurt.legs), 0.3, 0.0001)
	portrait.set_hurt({})
	portrait.badge_always = true
	portrait.set_hurt({})
	assert_true(portrait.badge.visible, "the result keeps it up")


func test_a_new_look_rebuilds_him() -> void:
	var portrait: FighterPortrait = _portrait("boxer")
	var profile: Dictionary = _roster.profile("boxer")
	profile.look = { "skin": 6, "hair": "blonde", "hair_style": "shaved", "beard": "beard" }
	portrait.show_fighter(profile)
	assert_eq(int(portrait.figure.look.skin), 6)
	assert_eq(String(portrait.figure.look.beard), "beard")
