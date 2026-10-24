extends GutTest
## Judging: simple 10-point must scoring with three judges (docs/01-fight-engine.md §11).


func test_the_fighter_who_did_more_wins_the_round_10_9() -> void:
	assert_eq(Judging.round_card([40.0, 30.0], [0, 0]), [10, 9] as Array[int])
	assert_eq(Judging.round_card([30.0, 40.0], [0, 0]), [9, 10] as Array[int])


func test_a_dead_even_or_empty_round_is_10_10() -> void:
	assert_eq(Judging.round_card([40.0, 39.0], [0, 0]), [10, 10] as Array[int])
	assert_eq(Judging.round_card([0.0, 0.0], [0, 0]), [10, 10] as Array[int])


func test_two_knockdowns_or_a_beating_is_10_8() -> void:
	assert_eq(Judging.round_card([60.0, 50.0], [2, 0]), [10, 8] as Array[int])
	assert_eq(Judging.round_card([100.0, 30.0], [0, 0]), [10, 8] as Array[int])
	assert_eq(Judging.round_card([50.0, 10.0], [0, 0]), [10, 9] as Array[int], "too quiet a round for 10-8")


func test_three_judges_give_unanimous_split_majority_or_draw() -> void:
	assert_eq(Judging.decision([[30, 27], [29, 28], [29, 28]]), { "result": Judging.UNANIMOUS, "winner": 0 })
	assert_eq(Judging.decision([[28, 29], [29, 28], [28, 29]]), { "result": Judging.SPLIT, "winner": 1 })
	assert_eq(Judging.decision([[29, 28], [28, 28], [29, 28]]), { "result": Judging.MAJORITY, "winner": 0 })
	assert_eq(Judging.decision([[29, 28], [28, 29], [28, 28]]), { "result": Judging.DRAW, "winner": -1 })
	assert_eq(Judging.decision([[28, 28], [28, 28], [29, 28]]), { "result": Judging.DRAW, "winner": -1 }, "majority draw")
