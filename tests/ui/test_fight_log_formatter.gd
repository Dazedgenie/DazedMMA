extends GutTest
## FightLogFormatter: readable console lines for fight events.

var _sim: FightSim


func before_each() -> void:
	_sim = FightSim.new(1, SimCheck.default_fighters(), ActionLibrary.load_dir())


func _plain(bbcode: String) -> String:
	return RegEx.create_from_string("\\[[^\\]]*\\]").sub(bbcode, "", true)


func test_a_landed_strike_names_the_fighter_move_target_and_damage() -> void:
	var e := FightEvent.new(34, 1, FightEvent.STRIKE_LANDED, 0, { "action_id": "jab", "target": "head", "damage": 3 })
	assert_eq(_plain(FightLogFormatter.line(e, _sim)), "R1 0:03.4  t34  Red's Jab LANDS (head, 3 damage)")


func test_time_is_counted_from_the_start_of_the_events_round() -> void:
	var e := FightEvent.new(3000 + 615, 2, FightEvent.STRIKE_MISSED, 1, { "action_id": "jab", "target": "head" })
	assert_eq(FightLogFormatter.time_label(e, 300), "R2 1:01.5")


func test_only_the_start_of_a_move_is_shown_without_phase_details() -> void:
	var start := FightEvent.new(0, 1, FightEvent.ACTION_PHASE, 0, { "action_id": "jab", "phase": "telegraph" })
	var windup := FightEvent.new(1, 1, FightEvent.ACTION_PHASE, 0, { "action_id": "jab", "phase": "windup" })
	assert_false(FightLogFormatter.is_detail(start))
	assert_true(FightLogFormatter.is_detail(windup))


func test_a_strike_shows_the_odds_it_was_rolled_at() -> void:
	var e := FightEvent.new(34, 1, FightEvent.STRIKE_MISSED, 1, { "action_id": "jab", "target": "head", "chance": 0.634 })
	assert_eq(_plain(FightLogFormatter.line(e, _sim)), "R1 0:03.4  t34  Blue's Jab misses 63%")


func test_the_condition_line_shows_stamina_and_worn_down_stats() -> void:
	var f := FighterState.new("Red", { "boxing": 70 }, [], 0.08, StyleLeanings.new({ "pace": 65 }))
	assert_eq(FightLogFormatter.condition_line(f), "Red stamina 100/100 · leaning aggressive · Natural aggressor")
	f.stamina = 0.0
	assert_string_contains(FightLogFormatter.condition_line(f), "Red stamina 0/100 · Boxing 70 → 49 (tired)")


func test_a_decision_names_the_winner_and_every_judges_card() -> void:
	var e := FightEvent.new(9000, 3, FightEvent.FIGHT_ENDED, FightEvent.NO_ACTOR,
		{ "result": Judging.SPLIT, "winner": 1, "cards": [[29, 28], [28, 29], [28, 29]] })
	assert_eq(_plain(FightLogFormatter.result_text(e, _sim)), "Blue wins by split decision (29-28, 28-29, 28-29)")


func test_a_knockout_and_a_draw_read_naturally() -> void:
	var ko := FightEvent.new(400, 1, FightEvent.FIGHT_ENDED, FightEvent.NO_ACTOR, { "result": FightSim.RESULT_KO, "winner": 0 })
	assert_eq(_plain(FightLogFormatter.result_text(ko, _sim)), "Red wins by KO")
	var draw := FightEvent.new(9000, 3, FightEvent.FIGHT_ENDED, FightEvent.NO_ACTOR,
		{ "result": Judging.DRAW, "winner": -1, "cards": [[29, 28], [28, 29], [28, 28]] })
	assert_eq(_plain(FightLogFormatter.result_text(draw, _sim)), "Draw (29-28, 28-29, 28-28)")


func test_big_moments_and_short_strikes_get_their_own_lines() -> void:
	var rocked := FightEvent.new(50, 1, FightEvent.ROCKED, 1, { "by": 0 })
	assert_string_contains(_plain(FightLogFormatter.line(rocked, _sim)), "Blue is ROCKED!")
	var short := FightEvent.new(51, 1, FightEvent.STRIKE_MISSED, 0, { "action_id": "jab", "target": "head", "chance": 0.0, "reason": "out of range" })
	assert_string_contains(_plain(FightLogFormatter.line(short, _sim)), "Red's Jab misses (out of range)")
	var pinned := FightEvent.new(52, 1, FightEvent.CAGE_CHANGED, 1, { "proximity": "pinned" })
	assert_string_contains(_plain(FightLogFormatter.line(pinned, _sim)), "Blue is PINNED against the cage")


func test_a_strike_explains_where_its_odds_came_from() -> void:
	var odds := { "base": 0.5, "attack": 55.0, "defense": 50.0, "stat_gap": 0.05, "chance": 0.65,
		"bonuses": [{ "name": "counter", "value": 0.1 }] }
	var e := FightEvent.new(34, 1, FightEvent.STRIKE_LANDED, 0, { "action_id": "jab", "target": "head", "damage": 3, "chance": 0.65, "odds": odds })
	assert_eq(_plain(FightLogFormatter.line(e, _sim)), "R1 0:03.4  t34  Red's Jab LANDS (head, 3 damage) 65% (base 50 · stats +5 · counter +10)")


func test_a_capped_chance_says_so() -> void:
	var odds := { "base": 0.5, "attack": 100.0, "defense": 0.0, "stat_gap": 1.0, "chance": 0.95, "bonuses": [], "clamped": true }
	assert_eq(FightLogFormatter.odds_reasons(odds), "base 50 · stats +100 · capped at 95")


func test_a_call_outcome_reads_naturally() -> void:
	var e := FightEvent.new(40, 1, FightEvent.CALL_ANSWERED, 1, { "action_id": "double_leg", "outcome": "infeasible", "reason": "not possible from this position" })
	assert_eq(_plain(FightLogFormatter.line(e, _sim)), "R1 0:04.0  t40  Blue can't do the Double-leg takedown call (not possible from this position)")


func test_a_change_of_position_says_who_did_it_and_who_is_on_top() -> void:
	var e := FightEvent.new(50, 1, FightEvent.POSITION_CHANGED, 1, { "action_id": "double_leg", "position": "full_guard", "phase": "ground", "roles": ["bottom", "top"] })
	assert_eq(_plain(FightLogFormatter.line(e, _sim)), "R1 0:05.0  t50  Blue's Double-leg takedown → Full guard (Blue on top)")
