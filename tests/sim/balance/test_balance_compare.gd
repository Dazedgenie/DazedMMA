extends GutTest
## BalanceCompare: two harness runs matched fight by fight, with the change and its range (D250).


func _row(changes: Dictionary = {}) -> Dictionary:
	var row: Dictionary = {}
	for column: String in FightSummary.COLUMNS:
		row[column] = 0
	row.merge({ "seed": 1, "ruleset": "pro", "red": "kicker", "blue": "boxer", "corner_red": "none", "corner_blue": "none",
		"rules_red": "", "rules_blue": "", "winner": "red", "winner_id": "kicker", "result": Judging.UNANIMOUS,
		"method": FightSummary.METHOD_DECISION, "end_round": 3, "end_second": 300, "events": 500 }, true)
	row.merge(changes, true)
	return row


## The rows as they come back from a balance.csv.
func _through_csv(rows: Array[Dictionary]) -> Array[Dictionary]:
	var report := BalanceReport.new()
	for row in rows:
		report.add(row)
	return BalanceCompare.parse_csv(report.csv())


## 20 Kicker vs Boxer fights, the Kicker winning the first `wins` seeds.
func _run(wins: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for n in 20:
		rows.append(_row({ "seed": n + 1, "winner": "red" if n < wins else "blue", "events": 500 + (n if n < wins else 0) }))
	return _through_csv(rows)


func test_a_csv_reads_back_with_every_column_and_value() -> void:
	var rows: Array[Dictionary] = _through_csv([_row({ "result": "odd, \"verdict\"", "shots_red": 4 }), _row({ "seed": 2 })])
	assert_eq(rows.size(), 2)
	assert_eq(rows[0].size(), FightSummary.COLUMNS.size())
	assert_eq(rows[0].result, "odd, \"verdict\"", "commas and quotes survive")
	assert_eq(rows[0].shots_red, "4")
	assert_eq(rows[1].seed, "2")


func test_the_same_run_twice_shows_no_change() -> void:
	var text: String = BalanceCompare.report(_run(10), _run(10))
	assert_string_contains(text, "kicker:boxer: 20 fights matched by seed (0 only before, 0 only after)")
	assert_string_contains(text, "played out differently   0 of 20")
	assert_string_contains(text, "red wins                 50.0% → 50.0%   change +0.0% (+0.0 to +0.0)")


func test_fights_won_after_a_change_show_as_a_paired_gain() -> void:
	var text: String = BalanceCompare.report(_run(10), _run(13))
	assert_string_contains(text, "played out differently   3 of 20")
	assert_string_contains(text, "red wins                 50.0% → 65.0%   change +15.0% (-1.1 to +31.1)")
	assert_string_contains(text, "blue wins                50.0% → 35.0%   change -15.0% (-31.1 to +1.1)")


func test_extra_columns_compare_their_means() -> void:
	var before: Array[Dictionary] = _through_csv([_row({ "shots_red": 10 }), _row({ "seed": 2, "shots_red": 12 })])
	var after: Array[Dictionary] = _through_csv([_row({ "shots_red": 4 }), _row({ "seed": 2, "shots_red": 4 })])
	var text: String = BalanceCompare.report(before, after, ["shots_red", "no_such_column"])
	assert_string_contains(text, "shots_red                11.00 → 4.00   change -7.00 (-8.96 to -5.04)")
	assert_string_contains(text, "no_such_column           not in both files")


func test_fights_only_one_run_has_are_counted_and_left_out() -> void:
	var before: Array[Dictionary] = _through_csv([_row(), _row({ "seed": 2 }), _row({ "red": "wrestler", "winner_id": "wrestler" })])
	var after: Array[Dictionary] = _through_csv([_row(), _row({ "seed": 3 })])
	var text: String = BalanceCompare.report(before, after)
	assert_string_contains(text, "kicker:boxer: 1 fights matched by seed (1 only before, 1 only after)")
	assert_string_contains(text, "wrestler:boxer: only in the before run (1 fights)")
