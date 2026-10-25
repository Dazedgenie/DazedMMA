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


func test_the_start_of_a_move_says_why_the_fighter_chose_it() -> void:
	var e := FightEvent.new(34, 1, FightEvent.ACTION_PHASE, 0, { "action_id": "body_kick", "phase": "telegraph", "by": "ai", "why": "tell: jab blocked" })
	assert_eq(_plain(FightLogFormatter.line(e, _sim)), "R1 0:03.4  t34  Red starts a Body kick  (tell: jab blocked)")


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


func test_takedowns_say_whether_they_worked_and_why() -> void:
	var odds := { "base": 0.45, "attack": 60.0, "defense": 50.0, "stat_gap": 0.1, "bonuses": [{ "name": "BACK_TO_CAGE", "value": 0.15 }], "chance": 0.7 }
	var won := FightEvent.new(10, 1, FightEvent.GRAPPLE_WON, 1, { "action_id": "double_leg", "result": "success", "chance": 0.7, "odds": odds })
	assert_string_contains(_plain(FightLogFormatter.line(won, _sim)), "Blue's Double-leg takedown WORKS 70% (base 45 · stats +10 · BACK_TO_CAGE +15)")
	var half := FightEvent.new(10, 1, FightEvent.GRAPPLE_WON, 1, { "action_id": "double_leg", "result": "partial", "chance": 0.7, "odds": odds })
	assert_string_contains(_plain(FightLogFormatter.line(half, _sim)), "half works: they scramble")
	var defended := FightEvent.new(10, 1, FightEvent.GRAPPLE_STOPPED, 1, { "action_id": "double_leg", "reason": "defended", "chance": 0.7, "odds": odds })
	assert_string_contains(_plain(FightLogFormatter.line(defended, _sim)), "Blue's Double-leg takedown is DEFENDED 70%")


func test_a_punished_shot_explains_what_punished_it() -> void:
	var odds := { "base": 0.45, "attack": 50.0, "defense": 50.0, "stat_gap": 0.0, "bonuses": [], "chance": 0.45 }
	var sprawled := FightEvent.new(10, 1, FightEvent.GRAPPLE_STOPPED, 0, { "action_id": "double_leg", "reason": "sprawled on", "chance": 0.45, "odds": odds })
	assert_string_contains(_plain(FightLogFormatter.line(sprawled, _sim)), "Red's Double-leg takedown is SPRAWLED ON, stuck with the head low · the shot was 45%")
	var knee := FightEvent.new(10, 1, FightEvent.STRIKE_LANDED, 1, { "action_id": "knee", "target": "head", "damage": 20, "into": "double_leg" })
	assert_string_contains(_plain(FightLogFormatter.line(knee, _sim)), "Blue's Knee LANDS into the double-leg takedown (head, 20 damage)")
	var stopped := FightEvent.new(10, 1, FightEvent.GRAPPLE_STOPPED, 0, { "action_id": "double_leg", "reason": "stopped", "by_action": "knee" })
	assert_string_contains(_plain(FightLogFormatter.line(stopped, _sim)), "Red's Double-leg takedown is STOPPED by the knee")
	var nothing := FightEvent.new(10, 1, FightEvent.GRAPPLE_STOPPED, 0, { "action_id": "catch_kick_single", "reason": "nothing to catch", "chance": 0.0, "odds": { "base": 0.2, "attack": 50.0, "defense": 50.0, "stat_gap": 0.0, "bonuses": [], "chance": 0.0, "missing": "ONE_LEG" } })
	assert_string_contains(_plain(FightLogFormatter.line(nothing, _sim)), "finds nothing to catch 0% (base 20 · stats +0 · needs ONE_LEG)")
	var sprawl := FightEvent.new(10, 1, FightEvent.SPRAWLED, 1, { "action_id": "sprawl", "against": "double_leg", "worked": true, "chance": 0.55, "odds": odds })
	assert_string_contains(_plain(FightLogFormatter.line(sprawl, _sim)), "Blue SPRAWLS on it 55%")
