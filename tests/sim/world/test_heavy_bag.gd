extends GutTest
## The heavy bag minigame (sim/world/heavy_bag.gd, docs/03 §13.6, D412): the meter, the green at its top, the bag's
## swing, meeting it as it comes back, whiffs, the chain, the score, and the drill getting harder with Power and tiredness.


## A whole round played perfectly: each hold starts so the meter tops out just as the bag comes back.
func _perfect(bag: HeavyBag) -> void:
	var at: float = 0.0
	bag.hold(at)
	at += bag.load_seconds
	bag.release(at)
	while true:
		var back: float = bag.back_at()
		if bag.is_over(back):
			break
		bag.hold(back - bag.load_seconds)
		bag.release(back)


func test_a_shot_let_go_at_the_top_meeting_the_bag_every_swing_is_a_perfect_round() -> void:
	var bag := HeavyBag.new(50.0, 0.0)
	_perfect(bag)
	assert_eq(bag.counts[HeavyBag.GREEN], bag.shots.size())
	assert_gte(bag.shots.size(), bag.expected_shots())
	assert_eq(bag.best_chain, bag.shots.size())
	assert_almost_eq(bag.quality(), TrainingCamp.PLAYED_MAX, 0.001)


func test_the_meter_climbs_to_the_top_and_back_down_while_held() -> void:
	var bag := HeavyBag.new(50.0, 0.0)
	assert_eq(bag.load_at(0.5), 0.0, "nothing held")
	bag.hold(1.0)
	assert_almost_eq(bag.load_at(1.0 + bag.load_seconds * 0.5), 0.5, 0.001)
	assert_almost_eq(bag.load_at(1.0 + bag.load_seconds), 1.0, 0.001)
	assert_almost_eq(bag.load_at(1.0 + bag.load_seconds * 1.5), 0.5, 0.001, "held too long, it comes back down")


func test_letting_go_low_is_weak_and_in_between_is_good() -> void:
	var bag := HeavyBag.new(50.0, 0.0)
	bag.hold(0.0)
	assert_eq(String(bag.release(bag.load_seconds * 0.3).result), HeavyBag.WEAK)
	var good := HeavyBag.new(50.0, 0.0)
	good.hold(0.0)
	assert_eq(String(good.release(good.load_seconds * (1.0 - good.green - 0.05)).result), HeavyBag.GOOD)


func test_a_shot_while_the_bag_swings_away_finds_nothing_and_a_late_one_misses_the_swing() -> void:
	var bag := HeavyBag.new(50.0, 0.0)
	bag.hold(0.0)
	bag.release(bag.load_seconds)
	var landed: float = bag.load_seconds
	bag.hold(landed + 0.1)
	var whiff: Dictionary = bag.release(landed + 0.1 + bag.load_seconds)
	assert_true(whiff.t < bag.back_at() - HeavyBag.MEET_WINDOW)
	assert_eq(String(whiff.result), HeavyBag.WHIFF)
	assert_eq(bag.chain, 0)
	bag.hold(bag.back_at() + 0.5 - bag.load_seconds)
	var late: Dictionary = bag.release(bag.back_at() + 0.5)
	assert_eq(String(late.result), HeavyBag.GREEN)
	assert_false(late.met, "the bag had already come back")
	assert_almost_eq(float(late.score), HeavyBag.MISSED_SWING, 0.001)
	assert_lt(bag.accuracy(), 2.0 / bag.expected_shots())


func test_a_harder_hitter_gets_a_quicker_meter_and_a_smaller_green_and_tiredness_shrinks_it() -> void:
	var low := HeavyBag.new(20.0, 0.0)
	var high := HeavyBag.new(90.0, 0.0)
	assert_lt(high.load_seconds, low.load_seconds)
	assert_lt(high.green, low.green)
	assert_lt(HeavyBag.new(50.0, 100.0).green, HeavyBag.new(50.0, 0.0).green)
	assert_almost_eq(HeavyBag.new(50.0, 100.0).green, HeavyBag.new(50.0, 0.0).green * HeavyBag.TIRED_FLOOR, 0.0001)
	assert_lt(HeavyBag.LOAD_SLOW, HeavyBag.SWING_SECONDS, "the meter can top out while the bag swings")


func test_nothing_hit_is_the_lowest_quality() -> void:
	assert_almost_eq(HeavyBag.new(50.0, 0.0).quality(), TrainingCamp.PLAYED_MIN, 0.001)
