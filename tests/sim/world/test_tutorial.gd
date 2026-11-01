extends GutTest
## The story as the tutorial (sim/world/tutorial.gd, docs/03 §11.6, D316): the first three amateur fights each open a
## little more, each of his first three offer sets has a lesson fight (the Coach's pick), and tips show once each.


func _career(tutorial: bool = true, career_seed: int = 1) -> Career:
	return Career.start({ "coach": "Sam Reed", "name": "Danny Hill", "hometown": "Leeds", "country": "England",
		"background": "wrestling_family", "stance": "orthodox", "tutorial": tutorial }, career_seed, FighterLibrary.load_dir())


func _ids(tips: Array[Dictionary]) -> Array:
	return tips.map(func(t: Dictionary) -> String: return String(t.id))


## Runs weeks until offers come in (at most `weeks`).
func _offers(c: Career, weeks: int = 12) -> void:
	for i in weeks:
		if not c.offers.is_empty():
			return
		c.run_week("time_off")


func test_the_first_three_fights_are_the_lessons() -> void:
	var c: Career = _career()
	assert_true(c.tutorial, "on for a new career")
	assert_eq(Tutorial.lesson(c), 1)
	c.add_opponent({ "id": "opp_1", "name": "First Man" })
	c.add_fight({ "result": "win", "opponent": "opp_1" })
	assert_eq(Tutorial.lesson(c), 2)
	c.add_fight({ "result": "loss", "opponent": "opp_1" })
	assert_eq(Tutorial.lesson(c), 3, "a loss still counts: the lessons go on")
	c.add_fight({ "result": "win", "opponent": "opp_1" })
	assert_eq(Tutorial.lesson(c), 0, "done after three")
	assert_eq(Tutorial.lesson(_career(false)), 0, "I know the game: no lessons")


func test_each_lesson_opens_a_little_more() -> void:
	assert_eq(Tutorial.calls(1), Tutorial.FIRST_CALLS, "Pressure!, Circle out!, Takedown! and the calls on their keys")
	assert_false("catch_the_kick" in Tutorial.calls(1))
	assert_true("catch_the_kick" in Tutorial.calls(2), "the read call in the kicker fight")
	assert_true(Tutorial.calls(3).is_empty(), "every call from lesson 3")
	assert_true(Tutorial.calls(0).is_empty(), "and with no lessons")
	assert_false(Tutorial.tell_cue(1))
	assert_true(Tutorial.tell_cue(2))
	assert_false(Tutorial.plan_open(1))
	assert_false(Tutorial.plan_open(2))
	assert_true(Tutorial.plan_open(3), "drilled rules and the gameplan with lesson 3")
	assert_true(Tutorial.plan_open(0))
	for id: String in Tutorial.FIRST_CALLS + Tutorial.SECOND_CALLS:
		assert_true(FileAccess.file_exists("res://data/calls/%s.json" % id), "a real call: %s" % id)


func test_each_offer_set_has_a_lesson_fight_until_his_third_fight() -> void:
	var c: Career = _career()
	c.run_week("time_off")
	assert_false(c.offers.is_empty())
	var first: Dictionary = c.offers[0]
	assert_eq(int(first.get("lesson", 0)), 1, "the first offer is the Coach's pick")
	assert_eq(String(first.difficulty), "easier")
	assert_false(String(first.style) in Tutorial.KICKER_STYLES, "the kicker is fight 2's")
	for o: Dictionary in c.offers.slice(1):
		assert_false(o.has("lesson"), "the others are rolled as usual")
	assert_string_contains(CareerHub.offer_text(c, first), "Coach's pick")
	c.accept(String(first.id))
	while c.week < int(c.booked.week):
		c.end_week()
	c.finish_fight({ "result": "win", "method": "KO", "round": 1 })
	c.suspended_days = 0
	c.next_offers_week = c.week + 1
	_offers(c)
	var second: Dictionary = c.offers[0]
	assert_eq(int(second.lesson), 2)
	assert_eq(String(second.style), "kicker", "fight 2 is against a kicker")
	c.decline(String(second.id))
	c.add_opponent({ "id": "opp_x", "name": "Someone Else" })
	c.add_fight({ "result": "win", "opponent": "opp_x" })  # He fought someone else: lesson 3 next.
	c.offers.clear()
	c.next_offers_week = c.week + 1
	_offers(c)
	assert_eq(int(c.offers[0].lesson), 3)
	assert_eq(String(c.offers[0].difficulty), "even")
	c.add_fight({ "result": "win", "opponent": "opp_x" })
	c.offers.clear()
	c.next_offers_week = c.week + 1
	_offers(c)
	for o: Dictionary in c.offers:
		assert_false(o.has("lesson"), "no lessons after three fights")
	var quick: Career = _career(false)
	quick.run_week("time_off")
	for o: Dictionary in quick.offers:
		assert_false(o.has("lesson"), "I know the game: offers as usual")


func test_a_tip_shows_once_and_goes_in_the_notebook() -> void:
	var c: Career = _career()
	assert_eq(_ids(Tutorial.due(c, "hub")), ["hub"])
	assert_true(c.see_tip("hub"))
	assert_false(c.see_tip("hub"), "once")
	assert_true(Tutorial.due(c, "hub").is_empty())
	assert_eq(_ids(Tutorial.notebook(c)), ["hub"], "the Notebook keeps what he's seen")
	assert_eq(_ids(Tutorial.due(c, "fight")), ["first_fight"], "the fight tip is the lesson's")
	c.add_opponent({ "id": "opp_1", "name": "First Man" })
	c.add_fight({ "result": "win", "opponent": "opp_1" })
	assert_eq(_ids(Tutorial.due(c, "fight")), ["catch_the_kick"])
	c.add_fight({ "result": "win", "opponent": "opp_1" })
	assert_eq(_ids(Tutorial.due(c, "fight")), ["every_call"])
	c.add_fight({ "result": "win", "opponent": "opp_1" })
	assert_true(Tutorial.due(c, "fight").is_empty(), "no fight tips after the lessons")
	var quick: Career = _career(false)
	assert_true(Tutorial.due(quick, "hub").is_empty(), "I know the game: no tips")
	assert_eq(Tutorial.notebook(quick).size(), Tutorial.tips().size(), "and every tip is in the Notebook")


func test_the_tutorial_comes_back_with_a_saved_career() -> void:
	var c: Career = _career()
	c.see_tip("hub")
	c.see_tip("offers")
	var back: Career = Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_true(back.tutorial)
	assert_eq(back.tips_seen, c.tips_seen)
	var old: Dictionary = c.to_dict()
	old.erase("tutorial")
	old.erase("tips_seen")
	var before: Career = Career.from_dict(JSON.parse_string(JSON.stringify(old)))
	assert_false(before.tutorial, "a career saved before D316 already knows the game")
	assert_true(before.tips_seen.is_empty())
