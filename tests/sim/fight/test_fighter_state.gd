extends GutTest
## FighterState condition: a tired, hurt fighter fights below their numbers
## (docs/11-attributes-and-traits.md §3.2).


func _fighter(p_stats: Dictionary = {}) -> FighterState:
	return FighterState.new("Red", p_stats, [])


func _hurt_head(f: FighterState, amount: float) -> void:
	f.damage.head = int(amount * FighterState.HURT_SCALE * (f.stat("chin") + 50))


func test_a_fresh_fighter_fights_at_their_stats() -> void:
	var f := _fighter({ "boxing": 70, "speed": 60 })
	assert_eq(f.effective_stat("boxing"), 70.0)
	assert_eq(f.effective_stat("speed"), 60.0)
	assert_eq(f.describe_stat("boxing"), "Boxing 70")


func test_stats_hold_until_half_a_tank_then_drop_to_minus_30_percent_when_empty() -> void:
	var f := _fighter({ "boxing": 70 })
	f.stamina = f.max_stamina() * 0.5
	assert_eq(f.effective_stat("boxing"), 70.0)
	f.stamina = f.max_stamina() * 0.25
	assert_almost_eq(f.effective_stat("boxing"), 70.0 * 0.85, 0.001)
	f.stamina = 0.0
	assert_almost_eq(f.effective_stat("boxing"), 49.0, 0.001)
	assert_eq(f.describe_stat("boxing"), "Boxing 70 → 49 (tired)")


func test_fatigue_does_not_wear_down_mental_stats_or_the_chin() -> void:
	var f := _fighter({ "fight_iq": 70, "chin": 70 })
	f.stamina = 0.0
	assert_eq(f.effective_stat("fight_iq"), 70.0)
	assert_eq(f.effective_stat("chin"), 70.0)


func test_head_damage_slows_speed_defense_and_fight_iq_but_not_boxing() -> void:
	var f := _fighter({ "composure": 100 })  # Composure 100 so this stays about damage, not panic.
	_hurt_head(f, 0.5)
	for id in ["speed", "striking_defense", "fight_iq"]:
		assert_almost_eq(f.effective_stat(id), 50.0 * 0.85, 0.01, id)
	assert_eq(f.effective_stat("boxing"), 50.0)
	assert_eq(f.describe_stat("speed"), "Speed 50 → 43 (hurt)")


func test_a_better_chin_takes_more_damage_before_it_shows() -> void:
	var glass := _fighter({ "chin": 20 })
	var granite := _fighter({ "chin": 90 })
	glass.damage.head = 300
	granite.damage.head = 300
	assert_gt(granite.effective_stat("speed"), glass.effective_stat("speed"))


func test_leg_damage_slows_footwork_speed_and_kicking() -> void:
	var f := _fighter()
	f.damage.legs = 1000
	for id in ["footwork", "speed", "kicking"]:
		assert_almost_eq(f.effective_stat(id), 35.0, 0.01, id)
	assert_eq(f.effective_stat("boxing"), 50.0)


func test_body_damage_shrinks_the_stamina_tank() -> void:
	var f := _fighter()
	var fresh_tank: float = f.max_stamina()
	f.damage.body = 500
	assert_almost_eq(f.max_stamina(), fresh_tank * 0.85, 0.01)


func test_panic_drops_defense_and_fight_iq_but_swings_get_harder() -> void:
	var f := _fighter({ "composure": 50 })  # panics at 65% hurt
	_hurt_head(f, 0.6)
	assert_false(f.is_panicking())
	_hurt_head(f, 0.7)
	assert_true(f.is_panicking())
	assert_almost_eq(f.effective_stat("takedown_defense"), 40.0, 0.01)
	assert_almost_eq(f.effective_stat("power"), 57.5, 0.01)
	assert_true(f.describe_stat("striking_defense").ends_with("(hurt, panicking)"))


func test_high_composure_holds_off_panic_longer() -> void:
	var cool := _fighter({ "composure": 90 })
	var shaky := _fighter({ "composure": 10 })
	_hurt_head(cool, 0.6)
	_hurt_head(shaky, 0.6)
	assert_false(cool.is_panicking())
	assert_true(shaky.is_panicking())


func test_better_cardio_means_a_bigger_tank_that_refills_faster() -> void:
	var low := _fighter({ "cardio": 20 })
	var high := _fighter({ "cardio": 90 })
	assert_gt(high.max_stamina(), low.max_stamina())
	low.stamina = 0.0
	high.stamina = 0.0
	for i in FightClock.TICKS_PER_SECOND:
		low.regen_tick()
		high.regen_tick()
	assert_almost_eq(low.stamina, 0.84, 0.001)
	assert_almost_eq(high.stamina, 1.68, 0.001)


func test_stamina_never_goes_below_empty_or_above_full() -> void:
	var f := _fighter()
	f.spend_stamina(1000.0)
	assert_eq(f.stamina, 0.0)
	f.stamina = f.max_stamina()
	f.regen_tick()
	assert_eq(f.stamina, f.max_stamina())


func test_the_corner_gives_back_more_stamina_with_better_recovery() -> void:
	var low := _fighter({ "recovery": 0 })
	var high := _fighter({ "recovery": 100 })
	low.stamina = 0.0
	high.stamina = 0.0
	low.recover_between_rounds()
	high.recover_between_rounds()
	assert_almost_eq(low.stamina, 30.0, 0.001)
	assert_almost_eq(high.stamina, 80.0, 0.001)


func test_reaction_time_is_two_ticks_at_speed_50_and_fatigue_stretches_it() -> void:
	assert_eq(FighterState.new("Slow", { "speed": 0 }, []).reaction_ticks(), 3)
	var average := FighterState.new("Average", {}, [])
	assert_eq(average.reaction_ticks(), 2)
	assert_eq(FighterState.new("Fast", { "speed": 100 }, []).reaction_ticks(), 1)
	average.stamina = 0.0
	assert_eq(average.reaction_ticks(), 3, "D93: stretched by fatigue")


func test_a_camp_condition_starts_the_fight_with_a_smaller_tank_and_hurt() -> void:
	var fresh := FighterState.from_profile({ "name": "Fresh", "stats": { "cardio": 60, "durability": 50 } })
	var tired := FighterState.from_profile({ "name": "Tired", "stats": { "cardio": 60, "durability": 50 },
		"condition": { "tank": 0.75, "hurt": { "legs": 0.09 } } })
	assert_almost_eq(tired.max_stamina(), fresh.max_stamina() * 0.75, 0.001, "a quarter of the tank gone for the whole fight (D135)")
	assert_eq(tired.stamina, tired.max_stamina(), "but it starts full")
	assert_almost_eq(tired.hurt("legs"), 0.09, 0.001)
	assert_eq(tired.tired(), 0.0, "a smaller tank, not tired yet")
	assert_lt(tired.effective_stat("footwork"), fresh.effective_stat("footwork"), "hurt legs slow the feet")


func test_a_hurt_body_from_camp_shrinks_the_tank_further() -> void:
	var fighter := FighterState.from_profile({ "name": "Ribs", "stats": {}, "condition": { "tank": 1.0, "hurt": { "body": 0.1 } } })
	var fresh := FighterState.from_profile({ "name": "Fresh", "stats": {} })
	assert_almost_eq(fighter.max_stamina(), fresh.max_stamina() * (1.0 - FighterState.MAX_BODY_DRAIN * 0.1), 0.01)
