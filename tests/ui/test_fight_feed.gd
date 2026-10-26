extends GutTest
## FightFeed: the fight screen's feed and its filter (docs/06 §2, A16).


func _event(type: String, data: Dictionary = {}, actor: int = 0, tick: int = 37) -> FightEvent:
	return FightEvent.new(tick, 1, type, actor, data)


func test_move_phases_and_out_of_range_swings_stay_out_of_the_feed() -> void:
	assert_eq(FightFeed.kind_of(_event(FightEvent.ACTION_PHASE, { "action_id": "jab", "phase": "telegraph" })), FightFeed.NONE)
	assert_eq(FightFeed.kind_of(_event(FightEvent.STRIKE_MISSED, { "action_id": "jab", "reason": "out of range" })), FightFeed.NONE)
	assert_eq(FightFeed.kind_of(_event(FightEvent.STRIKE_MISSED, { "action_id": "jab", "chance": 0.5 })), FightFeed.PLAY)


func test_big_moments_are_key_and_failures_get_explained() -> void:
	assert_eq(FightFeed.kind_of(_event(FightEvent.KNOCKDOWN, { "by": 1 })), FightFeed.KEY_MOMENT)
	assert_eq(FightFeed.kind_of(_event(FightEvent.STRIKE_LANDED, { "action_id": "jab", "damage": 3, "counter": true })), FightFeed.KEY_MOMENT)
	assert_eq(FightFeed.kind_of(_event(FightEvent.STRIKE_LANDED, { "action_id": "jab", "damage": 3 })), FightFeed.PLAY)
	assert_eq(FightFeed.kind_of(_event(FightEvent.CALL_ANSWERED, { "call_id": "catch_the_kick", "outcome": LiveCalls.FIRED })), FightFeed.KEY_MOMENT)
	assert_eq(FightFeed.kind_of(_event(FightEvent.CALL_ANSWERED, { "call_id": "takedown", "outcome": LiveCalls.IGNORED })), FightFeed.EXPLANATION)
	assert_eq(FightFeed.kind_of(_event(FightEvent.GRAPPLE_STOPPED, { "action_id": "double_leg", "reason": "sprawled on" })), FightFeed.EXPLANATION)
	assert_eq(FightFeed.kind_of(_event(FightEvent.RULE_ANSWERED, { "rule_id": "x", "outcome": DrilledRules.SLOW })), FightFeed.EXPLANATION)


func test_the_filter_shows_all_key_moments_or_explanations_only() -> void:
	assert_true(FightFeed.shows(FightFeed.PLAY, FightFeed.ALL))
	assert_false(FightFeed.shows(FightFeed.PLAY, FightFeed.KEY))
	assert_true(FightFeed.shows(FightFeed.KEY_MOMENT, FightFeed.KEY))
	assert_false(FightFeed.shows(FightFeed.KEY_MOMENT, FightFeed.EXPLAIN))
	assert_true(FightFeed.shows(FightFeed.EXPLANATION, FightFeed.EXPLAIN))
	var feed := FightFeed.new()
	add_child_autofree(feed)
	feed.add_line(FightFeed.PLAY, "a jab lands")
	feed.add_line(FightFeed.EXPLANATION, "the shot was sprawled on")
	feed.filter = FightFeed.EXPLAIN
	assert_string_contains(feed.text(), "sprawled on")
	assert_false(feed.text().contains("a jab lands"))
	feed.filter = FightFeed.ALL
	assert_string_contains(feed.text(), "a jab lands")


func test_lines_carry_the_round_clock_as_the_top_bar_shows_it() -> void:
	var sim := FightSim.new(1, FighterLibrary.load_dir().make_pair("wrestler", "kicker"), ActionLibrary.load_dir())
	var feed := FightFeed.new()
	add_child_autofree(feed)
	assert_eq(FightFeed.clock_label(_event(FightEvent.ROCKED, {}, 1, 0), sim), "5:00")
	assert_eq(FightFeed.clock_label(_event(FightEvent.ROCKED, {}, 1, 562), sim), "4:04")
	feed.add_event(_event(FightEvent.ROCKED, { "by": 0 }, 1, 562), sim)
	assert_string_contains(feed.text(), "4:04  Kicker is ROCKED!")
