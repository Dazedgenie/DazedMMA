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
	assert_eq(c.value, "6.0%")


func test_ten_ten_cards_count_against_all_judges_cards() -> void:
	var report := _report([_row({ "even_cards": 1 }), _row({ "even_cards": 2 })])
	assert_almost_eq(BalanceReport.even_card_share(report.rows), 3.0 / 18.0, 0.0001)
	assert_eq(_check(report, "10-10").status, BalanceReport.MISSED)
	assert_eq(_check(_report([_row()]), "10-10").status, BalanceReport.MET)


func test_the_showcase_pair_is_checked_in_either_corner() -> void:
	var lopsided: Array[Dictionary] = [_row(), _row(), _row(), _row({ "winner": "blue" })]
	assert_eq(_check(_report(lopsided), "Kicker vs Boxer").status, BalanceReport.MISSED, "75/25 is outside 60/40")
	var swapped: Array[Dictionary] = [_row({ "red": "boxer", "blue": "kicker" }), _row({ "red": "boxer", "blue": "kicker", "winner": "blue" })]
	assert_eq(_check(_report(swapped), "Kicker vs Boxer").status, BalanceReport.MET, "50/50 with the corners swapped")


func test_other_pairs_skip_the_showcase_check() -> void:
	assert_true(_check(_report([_row({ "red": "boxer", "blue": "boxer" })]), "Kicker vs Boxer").is_empty())


func test_a_fight_counts_as_tiring_when_either_fighter_dips_under_half_a_tank() -> void:
	var rows: Array[Dictionary] = [_row({ "stamina_low_blue": 0.4 }), _row(), _row({ "stamina_low_red": 0.49 }), _row()]
	assert_almost_eq(BalanceReport.tired_share(rows), 0.5, 0.0001)


func test_kos_and_tkos_count_as_finishes() -> void:
	var rows: Array[Dictionary] = [_row({ "method": FightSummary.METHOD_KO }), _row({ "method": FightSummary.METHOD_TKO }), _row(), _row()]
	assert_almost_eq(BalanceReport.finish_share(rows), 0.5, 0.0001)


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
	assert_string_contains(text, "Targets (all 2 fights)")
	assert_string_contains(text, "MET     Draws under 2%")


func test_harness_rows_from_real_fights_feed_the_report() -> void:
	var actions := ActionLibrary.load_dir()
	var roster := FighterLibrary.load_dir()
	var report := BalanceReport.new()
	for n in 3:
		report.add(FightSummary.run(n + 1, roster, actions, "check_red", "check_blue", 1, 30))
	assert_eq(report.pairs(), ["check_red:check_blue"] as Array[String])
	assert_eq(report.csv().strip_edges().split("\n").size(), 4)
	assert_gt(report.checks().size(), 0)
