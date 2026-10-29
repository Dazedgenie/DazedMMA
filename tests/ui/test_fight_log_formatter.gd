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


func test_a_move_in_a_combination_says_which_one_and_how_far_in() -> void:
	var e := FightEvent.new(34, 1, FightEvent.ACTION_PHASE, 0, { "action_id": "cross", "phase": "telegraph", "by": "ai", "why": "combination", "combo": "one_two_three", "step": 1 })
	assert_eq(_plain(FightLogFormatter.line(e, _sim)), "R1 0:03.4  t34  Red starts a Cross in a 1-2-3 (2 of 3)  (combination)")
	var landed := FightEvent.new(36, 1, FightEvent.STRIKE_LANDED, 0, { "action_id": "leg_kick", "target": "legs", "damage": 6, "chance": 0.6,
		"odds": { "base": 0.5, "stat_gap": 0.12, "chance": 0.82, "bonuses": [{ "name": "changes levels", "value": 0.2 }, { "name": "seen it", "value": -0.1 }] } })
	assert_eq(_plain(FightLogFormatter.line(landed, _sim)), "R1 0:03.6  t36  Red's Leg kick LANDS (legs, 6 damage) 60% (base 50 · stats +12 · changes levels +20 · seen it -10)")


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


func test_a_call_says_what_was_called_how_much_voice_is_left_and_when_the_fighter_acts() -> void:
	var e := FightEvent.new(40, 1, FightEvent.CALL_HEARD, 0, { "call_id": "takedown", "voice": 12, "garbled": true, "delay": 9, "trust": 46, "spam": true })
	assert_eq(_plain(FightLogFormatter.line(e, _sim)), "R1 0:04.0  t40  Red's corner: Takedown!  (voice 12 left · acts in 0.9 s · garbled · spam: trust 46)")


func test_a_call_the_fighter_acted_on_names_the_move() -> void:
	var e := FightEvent.new(46, 1, FightEvent.CALL_ANSWERED, 0, { "call_id": "takedown", "action_id": "catch_kick_single", "outcome": "accepted", "reason": "call after 6 ticks" })
	assert_eq(_plain(FightLogFormatter.line(e, _sim)), "R1 0:04.6  t46  Red takes the Takedown! call: Catch-kick single leg (call after 6 ticks)")
	var ignored := FightEvent.new(46, 1, FightEvent.CALL_ANSWERED, 0, { "call_id": "pressure", "outcome": "ignored", "reason": "panicking" })
	assert_eq(_plain(FightLogFormatter.line(ignored, _sim)), "R1 0:04.6  t46  Red IGNORES the Pressure! call (panicking)")


func test_a_drilled_rule_says_what_it_did_and_why() -> void:
	var fired := FightEvent.new(23, 1, FightEvent.RULE_ANSWERED, 0, { "rule_id": "catch_kick_and_shoot", "outcome": "fired", "slot": 1, "action_id": "catch_kick_single", "reason": "3 ticks after the body kick started" })
	assert_eq(_plain(FightLogFormatter.line(fired, _sim)), "R1 0:02.3  t23  Red goes on the rule \"When he kicks → catch & shoot\": Catch-kick single leg (3 ticks after the body kick started)")
	var cooling := FightEvent.new(60, 1, FightEvent.RULE_ANSWERED, 0, { "rule_id": "catch_kick_and_shoot", "outcome": "cooling", "slot": 1, "reason": "fired 4 s ago" })
	assert_eq(_plain(FightLogFormatter.line(cooling, _sim)), "R1 0:06.0  t60  Red holds the rule \"When he kicks → catch & shoot\" (fired 4 s ago)")


func test_a_referee_stoppage_says_why_it_was_stopped() -> void:
	var tko := FightEvent.new(400, 1, FightEvent.FIGHT_ENDED, FightEvent.NO_ACTOR, { "result": FightSim.RESULT_TKO, "winner": 1, "why": FightSim.STOP_SHOTS })
	assert_eq(_plain(FightLogFormatter.result_text(tko, _sim)), "Blue wins by TKO (the referee stops it: taking shots and not answering)")
	tko.data.why = FightSim.STOP_HEALTH
	assert_eq(_plain(FightLogFormatter.result_text(tko, _sim)), "Blue wins by TKO (the referee stops it: nothing left)")


func test_ground_and_pound_and_the_answers_to_it_read_naturally() -> void:
	var punch := FightEvent.new(50, 1, FightEvent.STRIKE_LANDED, 0, { "action_id": "ground_punch", "target": "head", "damage": 3 })
	assert_eq(_plain(FightLogFormatter.line(punch, _sim)), "R1 0:05.0  t50  Red's Ground punch LANDS (head, 3 damage)")
	var tied := FightEvent.new(50, 1, FightEvent.GRAPPLE_WON, 1, { "action_id": "tie_up", "result": "tied_up" })
	assert_string_contains(_plain(FightLogFormatter.line(tied, _sim)), "Blue TIES HIM UP from the bottom")
	var again := FightEvent.new(50, 1, FightEvent.ROCKED, 1, { "by": 0, "again": true })
	assert_string_contains(_plain(FightLogFormatter.line(again, _sim)), "Blue is ROCKED again underneath!")


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


func test_a_hip_throw_says_how_hard_it_landed() -> void:
	var thrown := FightEvent.new(10, 1, FightEvent.GRAPPLE_WON, 1, { "action_id": "hip_throw", "result": "success", "landing_damage": 12 })
	assert_string_contains(_plain(FightLogFormatter.line(thrown, _sim)), "Blue's Hip throw WORKS: slammed down (12 damage)")


func test_a_collar_tie_says_the_head_is_pulled_down() -> void:
	var tied := FightEvent.new(10, 1, FightEvent.GRAPPLE_WON, 0, { "action_id": "collar_tie", "result": "tied_up" })
	assert_string_contains(_plain(FightLogFormatter.line(tied, _sim)), "Red gets the COLLAR TIE: his head is pulled down for the knees")


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


func test_the_movement_line_says_how_long_each_fighter_circled_and_cut_off() -> void:
	_sim.now = 9000
	_sim.circling_ticks[0] = 4320
	_sim.cutting_ticks[1] = 905
	assert_eq(_plain(FightLogFormatter.movement_line(_sim, 0)), "%s circled 7:12 (48%% of the fight) · cut off the cage 0:00 (0%% of the fight)" % _sim.fighters[0].name)
	assert_string_contains(_plain(FightLogFormatter.movement_line(_sim, 1)), "cut off the cage 1:30 (10% of the fight)")


func test_a_submission_locking_in_its_beats_and_the_tap_read_naturally() -> void:
	var locked := FightEvent.new(50, 1, FightEvent.SUBMISSION_LOCKED, 1, { "action_id": "triangle", "danger": 45 })
	assert_eq(_plain(FightLogFormatter.line(locked, _sim)), "R1 0:05.0  t50  Blue LOCKS IN the triangle choke! danger 45")
	var beat := FightEvent.new(60, 1, FightEvent.SUBMISSION_BEAT, 1, { "action_id": "triangle", "danger": 65, "gained": true, "chance": 0.55 })
	assert_eq(_plain(FightLogFormatter.line(beat, _sim)), "R1 0:06.0  t60  Blue squeezes on the triangle choke: danger 65  (55% to win the beat)")
	var out := FightEvent.new(70, 1, FightEvent.SUBMISSION_ESCAPED, 0, { "action_id": "triangle", "danger": 0, "beats": 2 })
	assert_eq(_plain(FightLogFormatter.line(out, _sim)), "R1 0:07.0  t70  Red ESCAPES the triangle choke (danger 0 after 2 s)")
	var tap := FightEvent.new(80, 1, FightEvent.FIGHT_ENDED, FightEvent.NO_ACTOR, { "result": FightSim.RESULT_SUB, "winner": 1, "why": "triangle" })
	assert_eq(_plain(FightLogFormatter.result_text(tap, _sim)), "Blue wins by submission (triangle choke)")


func test_a_feint_says_whether_it_bit_and_a_blind_shot_says_so() -> void:
	var odds := { "base": 0.4, "attack": 50.0, "defense": 50.0, "stat_gap": 0.0, "bonuses": [{ "name": "feinted again", "value": -0.1 }], "chance": 0.3 }
	var bit := FightEvent.new(34, 1, FightEvent.FEINTED, 0, { "action_id": "feint", "bit": true, "chance": 0.3, "odds": odds })
	assert_eq(_plain(FightLogFormatter.line(bit, _sim)), "R1 0:03.4  t34  Red feints and Blue BITES: hands up, weight back 30% (base 40 · stats +0 · feinted again -10)")
	var not_bit := FightEvent.new(34, 1, FightEvent.FEINTED, 1, { "action_id": "feint", "bit": false, "chance": 0.4 })
	assert_eq(_plain(FightLogFormatter.line(not_bit, _sim)), "R1 0:03.4  t34  Blue feints; Red doesn't bite 40%")
	var far := FightEvent.new(34, 1, FightEvent.FEINTED, 0, { "action_id": "feint", "bit": false, "reason": "out of range" })
	assert_eq(_plain(FightLogFormatter.line(far, _sim)), "R1 0:03.4  t34  Red feints at nothing (out of range)")
	assert_eq(FightFeed.kind_of(far), FightFeed.NONE, "the feed skips a feint that reached nobody")
	var blind := FightEvent.new(34, 1, FightEvent.ACTION_PHASE, 0, { "action_id": "double_leg", "phase": "telegraph", "by": "ai", "why": "tell: stance shift", "blind": true })
	assert_eq(_plain(FightLogFormatter.line(blind, _sim)), "R1 0:03.4  t34  Red starts a Double-leg takedown blind  (tell: stance shift)")
