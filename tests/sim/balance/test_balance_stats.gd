extends GutTest
## BalanceStats: the 95% ranges the balance harness puts on its numbers (D250).


func test_fifty_wins_in_a_hundred_is_pinned_to_about_ten_points_either_way() -> void:
	var r: Vector2 = BalanceStats.wilson(50, 100)
	assert_almost_eq(r.x, 0.404, 0.001)
	assert_almost_eq(r.y, 0.596, 0.001)


func test_more_fights_give_a_narrower_range() -> void:
	var hundred: Vector2 = BalanceStats.wilson(50, 100)
	var thousand: Vector2 = BalanceStats.wilson(500, 1000)
	assert_lt(thousand.y - thousand.x, (hundred.y - hundred.x) / 3.0, "√10 narrower")


func test_the_range_stays_inside_nought_to_a_hundred_percent() -> void:
	var none: Vector2 = BalanceStats.wilson(0, 10)
	assert_eq(none.x, 0.0)
	assert_almost_eq(none.y, 0.278, 0.001, "no wins in 10 still allows up to ~28%")
	var all: Vector2 = BalanceStats.wilson(10, 10)
	assert_almost_eq(all.x, 0.722, 0.001)
	assert_eq(all.y, 1.0)
	assert_eq(BalanceStats.wilson(0, 0), Vector2(0.0, 1.0), "no fights, anything goes")


func test_a_paired_change_is_the_mean_difference_with_its_range() -> void:
	var diffs: Array = []
	for n in 20:
		diffs.append(1.0 if n < 3 else 0.0)  # 3 of 20 seeds won with the change and lost without it.
	var change: Dictionary = BalanceStats.paired(diffs)
	assert_almost_eq(change.mean, 0.15, 0.0001)
	assert_almost_eq(change.low, -0.0106, 0.0001)
	assert_almost_eq(change.high, 0.3106, 0.0001)
	assert_eq(change.n, 20)


func test_fights_that_all_changed_the_same_way_have_no_spread() -> void:
	var change: Dictionary = BalanceStats.paired([1.0, 1.0, 1.0, 1.0])
	assert_eq([change.mean, change.low, change.high], [1.0, 1.0, 1.0])


func test_one_paired_fight_has_no_range() -> void:
	assert_true(BalanceStats.unknown(BalanceStats.paired([1.0])))
	assert_eq(BalanceStats.change_text(BalanceStats.paired([1.0])), "+100.0% (range unknown)")


func test_unpaired_fights_give_a_wider_range_than_the_same_fights_paired() -> void:
	var before: Array = []
	var after: Array = []
	var diffs: Array = []
	for n in 50:
		before.append(1.0 if n < 20 else 0.0)
		after.append(1.0 if n < 25 else 0.0)
		diffs.append(after[-1] - before[-1])
	var paired: Dictionary = BalanceStats.paired(diffs)
	var unpaired: Dictionary = BalanceStats.unpaired(before, after)
	assert_almost_eq(paired.mean, unpaired.mean, 0.0001)
	assert_lt(paired.high - paired.low, (unpaired.high - unpaired.low) / 2.0)


func test_ranges_read_as_percentages() -> void:
	assert_eq(BalanceStats.share_text(0.55, Vector2(0.453, 0.644)), "55.0% (45.3–64.4%)")
	assert_eq(BalanceStats.change_text({ "mean": 0.12, "low": 0.041, "high": 0.199 }), "+12.0% (+4.1 to +19.9)")
