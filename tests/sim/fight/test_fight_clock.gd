extends GutTest
## FightClock: fight time in 100 ms ticks (docs/01-fight-engine.md §2).


func test_a_tick_is_one_tenth_of_a_fight_second() -> void:
	assert_eq(FightClock.TICK_MS, 100)
	assert_eq(FightClock.TICKS_PER_SECOND, 10)


func test_a_five_minute_round_is_3000_ticks() -> void:
	assert_eq(FightClock.new(3, 300).ticks_per_round(), 3000)


func test_round_ends_exactly_on_its_last_tick() -> void:
	var clock := FightClock.new(3, 300)
	for i in 2999:
		assert_false(clock.tick(), "round should not end early (tick %d)" % (i + 1))
	assert_true(clock.tick(), "round should end on tick 3000")


func test_three_round_fight_lasts_900_fight_seconds() -> void:
	var clock := FightClock.new(3, 300)
	var ticks: int = 0
	while not clock.is_fight_over():
		if clock.tick():
			clock.start_next_round()
		ticks += 1
	assert_eq(ticks, 9000)
	assert_eq(clock.current_round, 3)


func test_clock_display_reads_like_a_broadcast_clock() -> void:
	var clock := FightClock.new(3, 300)
	assert_eq(clock.display(), "R1 5:00")
	clock.start_next_round()
	for i in 79 * FightClock.TICKS_PER_SECOND:
		clock.tick()
	assert_eq(clock.display(), "R2 3:41")


func test_partial_second_still_shows_the_full_second() -> void:
	var clock := FightClock.new(1, 300)
	clock.tick()
	assert_eq(clock.display(), "R1 5:00")


func test_ticking_after_the_fight_is_over_does_nothing() -> void:
	var clock := FightClock.new(1, 1)
	for i in FightClock.TICKS_PER_SECOND:
		clock.tick()
	assert_true(clock.is_fight_over())
	assert_false(clock.tick())
	assert_eq(clock.tick_in_round, FightClock.TICKS_PER_SECOND)


func test_there_is_no_round_after_the_last_round() -> void:
	var clock := FightClock.new(3, 300)
	clock.start_next_round()
	clock.start_next_round()
	clock.start_next_round()
	assert_eq(clock.current_round, 3)
