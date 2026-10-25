extends GutTest
## Judging: simple 10-point must scoring with three judges (docs/01-fight-engine.md §11).


func test_the_fighter_who_did_more_wins_the_round_10_9() -> void:
	assert_eq(Judging.round_card([40.0, 30.0], [0, 0]), [10, 9] as Array[int])
	assert_eq(Judging.round_card([30.0, 40.0], [0, 0]), [9, 10] as Array[int])


func test_only_a_round_where_nothing_separates_them_is_10_10() -> void:
	assert_eq(Judging.round_card([40.0, 39.0], [0, 0]), [10, 10] as Array[int], "even striking, nothing else to go on")
	assert_eq(Judging.round_card([0.0, 0.0], [0, 0]), [10, 10] as Array[int])
	assert_eq(Judging.round_card([40.0, 39.0], [0, 0], [[25.0, 25.0], [0, 0]]), [10, 10] as Array[int], "dead even on everything")


func test_even_striking_goes_to_aggression_then_cage_control() -> void:
	# D97, docs/01 §11: effective striking first, then aggression, then cage control.
	assert_eq(Judging.round_card([39.0, 40.0], [0, 0], [[60.0, 30.0], [0, 0]]), [10, 9] as Array[int], "within 5%: the busier fighter")
	assert_eq(Judging.round_card([40.0, 40.0], [0, 0], [[30.0, 30.0], [0, 120]]), [9, 10] as Array[int], "then who held the other on the fence")
	assert_eq(Judging.round_card([0.0, 0.0], [0, 0], [[12.0, 3.0], [0, 0]]), [10, 9] as Array[int], "nobody landed, one fighter made the fight")
	assert_eq(Judging.round_card([50.0, 40.0], [0, 0], [[0.0, 90.0], [0, 300]]), [10, 9] as Array[int], "clearly better striking still wins")


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
