extends GutTest
## The Thai pads minigame (sim/world/thai_pads.gd, docs/03 §13.7, D413): the pads he holds, striking the right one
## quickly, wrong strikes and pads dropped unhit, checking his kick back, combinations, the score, and the drill getting
## harder with Kicking and tiredness.


## Every pad struck with the right strike the moment it goes up.
func _perfect(pads: ThaiPads) -> void:
	for pad: Dictionary in pads.pads.duplicate():
		pads.press(String(pad.key), float(pad.t))


func test_the_right_strike_the_moment_each_pad_goes_up_is_a_perfect_round() -> void:
	var pads := ThaiPads.new(50.0, 0.0, 7)
	_perfect(pads)
	assert_eq(pads.counts[ThaiPads.PERFECT], pads.pads.size())
	assert_gte(pads.pads.size(), 25, "about a minute of pads")
	assert_almost_eq(pads.quality(), TrainingCamp.PLAYED_MAX, 0.001)


func test_a_slower_strike_is_good_the_wrong_one_misses_and_a_dropped_pad_is_missed() -> void:
	var pads := ThaiPads.new(50.0, 0.0, 3)
	var first: Dictionary = pads.pads[0]
	var span: float = float(first.until) - float(first.t)
	assert_eq(String(pads.press(String(first.key), float(first.t) + span * 0.8).result), ThaiPads.GOOD)
	var second: Dictionary = pads.pads[1]
	var wrong: String = ThaiPads.LOW_KICK if second.key != ThaiPads.LOW_KICK else ThaiPads.HEAD_KICK
	assert_eq(String(pads.press(wrong, float(second.t)).result), ThaiPads.MISS)
	assert_eq(pads.miss_late(float(pads.pads[2].until)), 1, "the third dropped unhit")
	assert_eq(String(pads.press(String(pads.pads[2].key), float(pads.pads[2].until) + 0.01).result), "stray",
		"too late: he's dropped it")


func test_a_strike_with_no_pad_up_or_at_one_already_hit_is_stray_and_costs() -> void:
	var pads := ThaiPads.new(50.0, 0.0, 5)
	assert_eq(String(pads.press(ThaiPads.KNEE, 0.5).result), "stray", "the count-in")
	var first: Dictionary = pads.pads[0]
	pads.press(String(first.key), float(first.t))
	assert_eq(String(pads.press(String(first.key), float(first.t) + 0.05).result), "stray", "it's been hit")
	assert_almost_eq(pads.accuracy(), (1.0 - 2.0 * ThaiPads.STRAY_COST) / pads.pads.size(), 0.0001)


func test_he_kicks_back_now_and_then_and_a_check_answers_it() -> void:
	var pads := ThaiPads.new(50.0, 0.0, 11)
	var checks: Array = pads.pads.filter(func(p: Dictionary) -> bool: return p.key == ThaiPads.CHECK)
	assert_gt(checks.size(), 0)
	assert_lt(checks.size(), pads.pads.size() / 2)
	assert_eq(String(pads.press(ThaiPads.CHECK, float(checks[0].t)).result), ThaiPads.PERFECT)


func test_combinations_come_only_from_kicking_60_and_threes_from_80() -> void:
	var biggest := func(pads: ThaiPads) -> int:
		var most: int = 0
		for s: Dictionary in pads.sets:
			most = maxi(most, int(s.count))
		return most
	assert_eq(biggest.call(ThaiPads.new(50.0, 0.0, 1)), 1)
	assert_eq(biggest.call(ThaiPads.new(70.0, 0.0, 1)), 2)
	assert_eq(biggest.call(ThaiPads.new(90.0, 0.0, 1)), 3)
	var pads := ThaiPads.new(90.0, 0.0, 2)
	for i in range(1, pads.pads.size()):
		var a: Dictionary = pads.pads[i - 1]
		var b: Dictionary = pads.pads[i]
		assert_true(float(b.t) >= float(a.until) - 0.0001, "never two pads up at once")
		if a.combo == b.combo:
			assert_ne(a.key, b.key, "he moves the pad between strikes in a combination")


func test_a_better_kicker_gets_less_time_on_each_pad_and_tiredness_takes_more() -> void:
	assert_lt(ThaiPads.new(90.0, 0.0, 1).open, ThaiPads.new(20.0, 0.0, 1).open)
	assert_lt(ThaiPads.new(90.0, 0.0, 1).gap, ThaiPads.new(20.0, 0.0, 1).gap)
	assert_almost_eq(ThaiPads.new(50.0, 100.0, 1).open, ThaiPads.new(50.0, 0.0, 1).open * ThaiPads.TIRED_FLOOR, 0.0001)


func test_the_same_seed_gives_the_same_round_and_nothing_hit_is_the_lowest_quality() -> void:
	var a := ThaiPads.new(70.0, 20.0, 42)
	var b := ThaiPads.new(70.0, 20.0, 42)
	assert_eq(a.pads.map(func(p: Dictionary) -> String: return p.key), b.pads.map(func(p: Dictionary) -> String: return p.key))
	assert_almost_eq(a.quality(), TrainingCamp.PLAYED_MIN, 0.001)
