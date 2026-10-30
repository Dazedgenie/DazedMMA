extends GutTest
## BalanceReport: rows in, CSV and a readable summary out, with the balance
## targets from D96, D97 and docs/12 §4 marked as met or missed (#18).


## A made-up row: only the fields a test cares about differ from a quiet decision win for red.
func _row(changes: Dictionary = {}) -> Dictionary:
	var row: Dictionary = {}
	for column: String in FightSummary.COLUMNS:
		row[column] = 0
	row.merge({ "seed": 1, "ruleset": "pro", "red": "kicker", "blue": "boxer", "winner": "red", "winner_id": "kicker",
		"result": Judging.UNANIMOUS, "method": FightSummary.METHOD_DECISION, "end_round": 3, "end_second": 300,
		"stamina_end_red": 0.9, "stamina_low_red": 0.8, "stamina_end_blue": 0.9, "stamina_low_blue": 0.8,
		"round_cards": 9, "even_cards": 0, "exchanges": 100, "clamped": 0 }, true)
	row.merge(changes, true)
	return row


func _report(rows: Array[Dictionary]) -> BalanceReport:
	var report := BalanceReport.new()
	for row in rows:
		report.add(row)
	return report


func _check(report: BalanceReport, starts_with: String) -> Dictionary:
	for c in report.checks():
		if c.name.begins_with(starts_with):
			return c
	return {}


func _draws(count: int, of: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for n in of:
		rows.append(_row({ "seed": n + 1, "winner": "draw" if n < count else "red", "method": FightSummary.METHOD_DRAW if n < count else FightSummary.METHOD_DECISION }))
	return rows


func test_one_draw_in_a_hundred_meets_the_draw_target() -> void:
	assert_eq(_check(_report(_draws(1, 100)), "Draws").status, BalanceReport.MET)


func test_six_draws_in_a_hundred_miss_the_draw_target() -> void:
	var c: Dictionary = _check(_report(_draws(6, 100)), "Draws")
	assert_eq(c.status, BalanceReport.MISSED)
	assert_eq(c.value, "6.0% (2.8–12.5%)", "with its 95% range (D250)")


func test_ten_ten_cards_count_against_all_judges_cards() -> void:
	var report := _report([_row({ "even_cards": 1 }), _row({ "even_cards": 2 })])
	assert_almost_eq(BalanceReport.even_card_share(report.rows), 3.0 / 18.0, 0.0001)
	assert_eq(_check(report, "10-10").status, BalanceReport.MISSED)
	assert_eq(_check(_report([_row()]), "10-10").status, BalanceReport.MET)


func test_the_showcase_pair_is_checked_in_either_corner() -> void:
	var lopsided: Array[Dictionary] = [_row(), _row(), _row(), _row({ "winner": "blue", "winner_id": "boxer" })]
	assert_eq(_check(_report(lopsided), "Kicker vs Boxer").status, BalanceReport.MISSED, "75/25 is outside 60/40")
	var swapped: Array[Dictionary] = [_row({ "red": "boxer", "blue": "kicker", "winner_id": "boxer" }), _row({ "red": "boxer", "blue": "kicker", "winner": "blue", "winner_id": "kicker" })]
	assert_eq(_check(_report(swapped), "Kicker vs Boxer").status, BalanceReport.MET, "50/50 with the corners swapped")


func test_the_showcase_check_counts_wins_by_fighter_not_by_corner() -> void:
	# Red wins all four, but the Kicker and the Boxer each won two.
	var rows: Array[Dictionary] = [_row(), _row(), _row({ "red": "boxer", "blue": "kicker", "winner_id": "boxer" }), _row({ "red": "boxer", "blue": "kicker", "winner_id": "boxer" })]
	var c: Dictionary = _check(_report(rows), "Kicker vs Boxer")
	assert_eq(c.status, BalanceReport.MET)
	assert_eq(c.value, "favourite wins 50.0% (15.0–85.0%), too close to 60% to tell at this many fights")


func test_other_pairs_skip_the_showcase_check() -> void:
	assert_true(_check(_report([_row({ "red": "boxer", "blue": "boxer" })]), "Kicker vs Boxer").is_empty())


func test_a_fight_counts_as_tiring_when_either_fighter_dips_under_half_a_tank() -> void:
	var rows: Array[Dictionary] = [_row({ "stamina_low_blue": 0.4 }), _row(), _row({ "stamina_low_red": 0.49 }), _row()]
	assert_almost_eq(BalanceReport.tired_share(rows), 0.5, 0.0001)


func test_kos_tkos_and_submissions_count_as_finishes() -> void:
	var rows: Array[Dictionary] = [_row({ "method": FightSummary.METHOD_KO }), _row({ "method": FightSummary.METHOD_TKO }),
		_row({ "method": FightSummary.METHOD_SUB }), _row()]
	assert_almost_eq(BalanceReport.finish_share(rows), 0.75, 0.0001)


func test_the_csv_has_a_header_and_one_line_per_fight_with_every_column() -> void:
	var lines: PackedStringArray = _report([_row(), _row({ "seed": 2 })]).csv().strip_edges().split("\n")
	assert_eq(lines.size(), 3)
	assert_eq(lines[0], ",".join(FightSummary.COLUMNS))
	for line in lines:
		assert_eq(line.split(",").size(), FightSummary.COLUMNS.size())


func test_csv_cells_with_commas_are_quoted() -> void:
	var line: String = _report([_row({ "result": "odd, \"verdict\"" })]).csv().split("\n")[1]
	assert_string_contains(line, "\"odd, \"\"verdict\"\"\"")


func test_the_summary_has_a_block_per_pair_and_the_targets() -> void:
	var text: String = _report([_row(), _row({ "red": "boxer", "blue": "boxer", "winner": "blue" })]).summary({ "kicker": "Kicker", "boxer": "Boxer" })
	assert_string_contains(text, "Kicker (red) vs Boxer (blue): 1 fights")
	assert_string_contains(text, "Boxer (red) vs Boxer (blue): 1 fights")
	assert_string_contains(text, "Targets (all 2 fights; the engine's own on the 2 without calls or rules)")
	assert_string_contains(text, "MET     Draws under 2%")


func test_the_fence_check_follows_whichever_fighter_is_on_the_fence_more() -> void:
	var rows: Array[Dictionary] = [_row({ "fence_red": 0.8, "fence_blue": 0.1 }), _row({ "fence_red": 0.2, "fence_blue": 0.4 })]
	assert_almost_eq(BalanceReport.fenced_share(rows), 0.6, 0.0001)
	assert_eq(_check(_report(rows), "Standing time the more-fenced").value, "60.0%")


func test_the_summary_says_how_the_fighters_moved() -> void:
	var text: String = _report([_row({ "fence_red": 0.5, "pinned_red": 0.25, "centre_blue": 0.75, "chase": 0.4 })]).summary({ "kicker": "Kicker", "boxer": "Boxer" })
	assert_string_contains(text, "near the fence: Kicker (red) 50.0% (pinned 25.0%)")
	assert_string_contains(text, "Boxer (blue) 75.0%")
	assert_string_contains(text, "chasing 40.0%")


func test_the_summary_says_how_long_each_fighter_circled_and_cut_off_the_cage() -> void:
	var rows: Array[Dictionary] = [
		_row({ "fight_seconds": 900.0, "circling_red": 372.0, "cutting_blue": 90.0 }),
		_row({ "fight_seconds": 300.0, "circling_red": 108.0, "cutting_blue": 30.0, "circling_blue": 12.0 }),
	]
	assert_almost_eq(BalanceReport.time_share(rows, "circling_red"), 0.4, 0.0001, "480 of 1200 fight seconds")
	var text: String = _report(rows).summary({ "kicker": "Kicker", "boxer": "Boxer" })
	assert_string_contains(text, "Circling   Kicker (red) 4:00 a fight (40%), Boxer (blue) 0:06 a fight (1%)")
	assert_string_contains(text, "cutting off the cage: Kicker (red) 0:00 a fight (0%), Boxer (blue) 1:00 a fight (10%)")


func test_harness_rows_from_real_fights_feed_the_report() -> void:
	var actions := ActionLibrary.load_dir()
	var roster := FighterLibrary.load_dir()
	var report := BalanceReport.new()
	for n in 3:
		report.add(FightSummary.run(n + 1, roster, actions, "check_red", "check_blue", 1, 30))
	assert_eq(report.pairs(), ["check_red:check_blue"] as Array[String])
	assert_eq(report.csv().strip_edges().split("\n").size(), 4)
	assert_gt(report.checks().size(), 0)


func test_the_wrestlers_pairings_are_reported_with_no_pass_mark() -> void:
	var rows: Array[Dictionary] = [
		_row({ "red": "wrestler", "blue": "kicker", "winner_id": "wrestler" }),
		_row({ "red": "kicker", "blue": "wrestler", "winner_id": "kicker" }),
		_row({ "red": "wrestler", "blue": "kicker", "winner_id": "wrestler" }),
		_row({ "red": "kicker", "blue": "wrestler", "winner_id": "wrestler" }),
	]
	var c: Dictionary = _check(_report(rows), "Wrestler vs Kicker")
	assert_eq(c.status, BalanceReport.INFO, "Kyle: report only until after the playtest (D109)")
	assert_eq(c.value, "75.0%", "counted by fighter, whichever corner")
	assert_true(_check(_report(rows), "Wrestler vs Boxer").is_empty(), "no Wrestler vs Boxer fights, no line")


func test_the_judoka_and_the_bjj_fighter_are_reported_with_no_pass_mark() -> void:
	var rows: Array[Dictionary] = [
		_row({ "red": "judoka", "blue": "boxer", "winner_id": "judoka" }),
		_row({ "red": "boxer", "blue": "judoka", "winner_id": "boxer" }),
		_row({ "red": "bjj", "blue": "wrestler", "winner_id": "bjj" }),
	]
	var judoka: Dictionary = _check(_report(rows), "Judoka vs Boxer")
	assert_eq(judoka.status, BalanceReport.INFO, "report only, like the Wrestler (D128)")
	assert_eq(judoka.value, "50.0%")
	assert_eq(_check(_report(rows), "BJJ fighter vs Wrestler").value, "100.0%")
	assert_true(_check(_report(rows), "Judoka vs Kicker").is_empty(), "no fights, no line")


func test_the_summary_counts_throws() -> void:
	var report: BalanceReport = _report([_row({ "red": "judoka", "throws_red": 6, "throws_landed_red": 2 })])
	var text: String = report.summary({ "judoka": "Judoka", "boxer": "Boxer" })
	assert_string_contains(text, "Throws     Judoka (red) 2.0 of 6.0 a fight landed · Boxer (blue) 0.0 of 0.0 (D128)")


func test_the_muay_thai_fighter_is_reported_with_no_pass_mark() -> void:
	var rows: Array[Dictionary] = [_row({ "red": "muay_thai", "blue": "wrestler", "winner_id": "muay_thai" })]
	var line: Dictionary = _check(_report(rows), "Muay Thai fighter vs Wrestler")
	assert_eq(line.status, BalanceReport.INFO, "report only (D129)")
	assert_eq(line.value, "100.0%")


func test_the_summary_counts_collar_ties_and_clinch_knees() -> void:
	var report: BalanceReport = _report([_row({ "red": "muay_thai", "collar_ties_red": 5, "collar_ties_won_red": 3, "clinch_knees_red": 8, "tied_knees_red": 4 })])
	var text: String = report.summary({ "muay_thai": "Muay Thai", "boxer": "Boxer" })
	assert_string_contains(text, "Clinch     Muay Thai (red) collar ties 3.0 of 5.0 won, knees landed 8.0 (4.0 from the tie) · Boxer (blue) 0.0 of 0.0, 0.0 (0.0) (D129)")


func test_the_sambo_fighter_is_reported_against_the_strikers_the_wrestler_and_the_bjj_fighter() -> void:
	var rows: Array[Dictionary] = [
		_row({ "red": "sambo", "blue": "bjj", "winner_id": "bjj" }),
		_row({ "red": "boxer", "blue": "sambo", "winner_id": "sambo" }),
	]
	var bjj: Dictionary = _check(_report(rows), "Sambo fighter vs BJJ fighter")
	assert_eq(bjj.status, BalanceReport.INFO, "report only (D132)")
	assert_eq(bjj.value, "0.0%")
	assert_eq(_check(_report(rows), "Sambo fighter vs Boxer").value, "100.0%")
	assert_true(_check(_report(rows), "Sambo fighter vs Kicker").is_empty(), "no fights, no line")


func test_the_summary_counts_leg_locks_and_the_fights_they_end() -> void:
	var report: BalanceReport = _report([
		_row({ "red": "sambo", "leg_locks_red": 3, "leg_locked_red": 1, "leg_lock_finish": 1 }),
		_row({ "red": "sambo", "leg_locks_red": 1 }),
	])
	var text: String = report.summary({ "sambo": "Sambo", "boxer": "Boxer" })
	assert_string_contains(text, "Leg locks  Sambo (red) 2.0 tried, 0.5 locked a fight · Boxer (blue) 0.0 tried, 0.0 locked · ended 50.0% of fights (D132)")


func test_the_summary_counts_combinations_and_how_often_their_follow_ups_land() -> void:
	var report: BalanceReport = _report([
		_row({ "blue": "boxer", "combos_blue": 10, "combo_strikes_blue": 14, "combo_landed_blue": 7 }),
		_row({ "blue": "boxer", "combos_blue": 6, "combo_strikes_blue": 6, "combo_landed_blue": 5 }),
	])
	var text: String = report.summary({ "kicker": "Kicker", "boxer": "Boxer" })
	assert_string_contains(text, "Combos     Kicker (red) 0.0 a fight, follow-ups land 0.0% · Boxer (blue) 8.0, 60.0% (D133)")


func test_the_summary_says_how_much_grappling_there_was() -> void:
	var report: BalanceReport = _report([_row({ "red": "wrestler", "takedowns_red": 4, "shots_red": 9, "ground": 0.3, "top_red": 0.28, "clinch": 0.05 })])
	var text: String = report.summary({ "wrestler": "Wrestler", "boxer": "Boxer" })
	assert_string_contains(text, "Grappling  takedowns Wrestler (red) 4.0 of 9.0 a fight, Boxer (blue) 0.0 of 0.0 · clinch 5.0% of the fight · ground 30.0% (Wrestler (red) on top 28.0%")


# --- Coaching bots (D12, D68) ---------------------------------------------------------------

## `wins` of `of` fights won by red, with this bot in red's corner.
func _coached(style: String, wins: int, of: int = 20) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for n in of:
		rows.append(_row({ "seed": n + 1, "corner_red": style, "corner_blue": Corner.NONE,
			"winner": "red" if n < wins else "blue", "winner_id": "kicker" if n < wins else "boxer" }))
	return rows


func _coaching(none_wins: int, style: String, wins: int) -> BalanceReport:
	var rows: Array[Dictionary] = _coached(Corner.NONE, none_wins)
	rows.append_array(_coached(style, wins))
	return _report(rows)


func test_good_coaching_meets_the_target_when_it_adds_10_to_20_percent() -> void:
	var c: Dictionary = _check(_coaching(10, Corner.IDEAL, 13), "Kicker coached against the Boxer: good coaching")
	assert_eq(c.status, BalanceReport.MET)
	assert_eq(c.value, "+15.0% (-1.1 to +31.1), 50.0% → 65.0%, 20 fights paired by seed")
	assert_eq(_check(_coaching(10, Corner.IDEAL, 16), "Kicker coached against the Boxer: good coaching").status, BalanceReport.MISSED, "+30% is too much")
	assert_eq(_check(_coaching(10, Corner.IDEAL, 11), "Kicker coached against the Boxer: good coaching").status, BalanceReport.MISSED, "+5% too little")


func test_spam_meets_the_target_only_when_it_wins_less_than_no_calls() -> void:
	assert_eq(_check(_coaching(10, Corner.SPAM, 8), "Kicker coached against the Boxer: spam").status, BalanceReport.MET)
	assert_eq(_check(_coaching(10, Corner.SPAM, 12), "Kicker coached against the Boxer: spam").status, BalanceReport.MISSED)


func test_coached_fights_are_kept_out_of_the_engines_own_targets() -> void:
	var rows: Array[Dictionary] = _coached(Corner.NONE, 10)
	for row in _coached(Corner.SPAM, 0):
		rows.append(row.merged({ "winner": "draw", "winner_id": "", "method": FightSummary.METHOD_DRAW }, true))
	var report: BalanceReport = _report(rows)
	assert_eq(report.uncoached().size(), 20)
	assert_eq(_check(report, "Draws").status, BalanceReport.MET, "the spam fights' draws don't count")
	assert_eq(report.pairs(), ["kicker:boxer", "kicker:boxer red corner spam"] as Array[String])
	assert_string_contains(report.summary(), "Corner     kicker (red)'s corner: spam caller")


func test_a_bot_in_blues_corner_counts_for_the_fighter_it_coaches() -> void:
	# Red is the Kicker in every row: with the bot in blue's corner, it's the Boxer being coached.
	var rows: Array[Dictionary] = _coached(Corner.NONE, 10)
	for n in 20:
		rows.append(_row({ "seed": n + 1, "corner_blue": Corner.IDEAL, "corner_red": Corner.NONE,
			"winner": "blue" if n < 13 else "red", "winner_id": "boxer" if n < 13 else "kicker" }))
	var c: Dictionary = _check(_report(rows), "Boxer coached against the Kicker: good coaching")
	assert_eq(c.value, "+15.0% (-25.9 to +55.9), 50.0% → 65.0%, 20 fights paired by seed",
		"seeds 1–10 the Boxer lost without a coach and won with one, 14–20 the other way")
	assert_eq(c.status, BalanceReport.MET)


func test_coaching_is_compared_seed_by_seed_which_narrows_the_range() -> void:
	# The Kicker wins seeds 1–10 without the coach and 1–14 with it.
	var paired: Array[Dictionary] = _coached(Corner.NONE, 10)
	paired.append_array(_coached(Corner.IDEAL, 14))
	assert_eq(_check(_report(paired), "Kicker coached against the Boxer: good coaching").value,
		"+20.0% (+2.0 to +38.0), 50.0% → 70.0%, 20 fights paired by seed")
	# The same wins on seeds that don't match can only be compared as two separate shares.
	var unpaired: Array[Dictionary] = _coached(Corner.NONE, 10)
	for row in _coached(Corner.IDEAL, 14):
		unpaired.append(row.merged({ "seed": row.seed + 100 }, true))
	assert_eq(_check(_report(unpaired), "Kicker coached against the Boxer: good coaching").value,
		"+20.0% (-10.5 to +50.5), 50.0% → 70.0%, 20 and 20 fights, not paired")


# --- Ranges and the run (D250) ---------------------------------------------------------------

func test_the_wins_line_gives_each_corners_share_with_its_95_percent_range() -> void:
	var rows: Array[Dictionary] = []
	for n in 100:
		rows.append(_row({ "seed": n + 1, "winner": "red" if n < 50 else "blue" }))
	var text: String = _report(rows).summary({ "kicker": "Kicker", "boxer": "Boxer" })
	assert_string_contains(text, "Wins       Kicker (red) 50.0% (40.4–59.6%) · Boxer (blue) 50.0% (40.4–59.6%) · draw 0.0% (95% ranges, D250)")


func test_the_showcase_check_says_when_enough_fights_put_it_clear_of_the_line() -> void:
	var rows: Array[Dictionary] = []
	for n in 400:
		rows.append(_row({ "seed": n + 1, "winner": "red" if n < 200 else "blue", "winner_id": "kicker" if n < 200 else "boxer" }))
	var c: Dictionary = _check(_report(rows), "Kicker vs Boxer")
	assert_eq(c.value, "favourite wins 50.0% (45.1–54.9%)", "no warning: the whole range is under 60%")


func test_the_summary_starts_with_what_the_run_was_made_from() -> void:
	var text: String = _report([_row()]).summary({}, { "commit": "abc1234", "data": "0f0f0f0f", "godot": "4.7.2.stable" })
	assert_true(text.begins_with("Run: commit abc1234 · data files 0f0f0f0f · Godot 4.7.2.stable\n"))
	assert_false(_report([_row()]).summary().begins_with("Run:"), "no run given, no line")


func test_the_summary_says_who_chose_each_fighters_moves() -> void:
	var report: BalanceReport = _report([_row({ "chosen_ai_red": 90, "chosen_call_red": 8, "chosen_rule_red": 2, "chosen_ai_blue": 50 })])
	var text: String = report.summary({ "kicker": "Kicker", "boxer": "Boxer" })
	assert_string_contains(text, "Chosen by  Kicker (red) own AI 90.0% · calls 8.0% · rules 2.0% · commands 0.0% of 100 moves a fight · Boxer (blue) own AI 100.0%")


# --- Drilled rules (#17) --------------------------------------------------------------------

func test_a_fighters_drilled_rules_are_reported_against_the_same_fights_without_them() -> void:
	var rows: Array[Dictionary] = _coached(Corner.NONE, 10)
	for n in 20:
		rows.append(_row({ "seed": n + 1, "rules_red": "catch_kick_and_shoot@80", "fired_red": 4,
			"winner": "red" if n < 14 else "blue", "winner_id": "kicker" if n < 14 else "boxer" }))
	var report: BalanceReport = _report(rows)
	var c: Dictionary = _check(report, "Kicker drilled (catch_kick_and_shoot@80) against the Boxer")
	assert_eq(c.status, BalanceReport.INFO)
	assert_eq(c.value, "+20.0% (+2.0 to +38.0), 50.0% → 70.0%, 20 fights paired by seed")
	assert_eq(report.uncoached().size(), 20, "rules fights are kept out of the engine's own targets")
	assert_eq(report.pairs(), ["kicker:boxer", "kicker:boxer red rules catch_kick_and_shoot@80"] as Array[String])
	assert_string_contains(report.summary(), "Rules      kicker (red) drilled catch_kick_and_shoot@80, fired 4.0 times a fight")
