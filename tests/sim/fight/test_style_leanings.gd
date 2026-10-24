extends GutTest
## StyleLeanings: hidden style numbers that grow into named traits
## (docs/11-attributes-and-traits.md §4.2, D88, D89).


func test_a_new_fighter_has_no_leanings_hints_or_traits() -> void:
	var style := StyleLeanings.new()
	for leaning in StyleLeanings.LEANINGS:
		assert_eq(style.value(leaning), 0.0)
		assert_eq(style.hint(leaning), "")
	assert_eq(style.traits(), [] as Array[String])


func test_the_player_gets_a_fuzzy_hint_only_past_30() -> void:
	var style := StyleLeanings.new({ "pace": 29, "base": -35 })
	assert_eq(style.hint(StyleLeanings.PACE), "")
	assert_eq(style.hint(StyleLeanings.BASE), "leaning striker")
	style.push(StyleLeanings.PACE, 1)
	assert_eq(style.hint(StyleLeanings.PACE), "leaning aggressive")


func test_pushing_the_pace_past_60_earns_natural_aggressor() -> void:
	var style := StyleLeanings.new({ "pace": 55 })
	assert_eq(style.trait_for(StyleLeanings.PACE), "")
	style.push(StyleLeanings.PACE, 5)
	assert_eq(style.trait_for(StyleLeanings.PACE), "natural_aggressor")


func test_a_trait_survives_a_dip_and_fades_only_inside_40() -> void:
	var style := StyleLeanings.new({ "risk": -70 })
	assert_eq(style.trait_for(StyleLeanings.RISK), "fundamentalist")
	style.push(StyleLeanings.RISK, 25)  # −45: still a fundamentalist
	assert_eq(style.trait_for(StyleLeanings.RISK), "fundamentalist")
	style.push(StyleLeanings.RISK, 6)  # −39: fades
	assert_eq(style.trait_for(StyleLeanings.RISK), "")
	style.push(StyleLeanings.RISK, -15)  # −54: not earned again until −60
	assert_eq(style.trait_for(StyleLeanings.RISK), "")


func test_leanings_stop_at_plus_or_minus_100() -> void:
	var style := StyleLeanings.new({ "range": 90 })
	style.push(StyleLeanings.RANGE, 50)
	assert_eq(style.value(StyleLeanings.RANGE), 100.0)
	style.push(StyleLeanings.RANGE, -500)
	assert_eq(style.value(StyleLeanings.RANGE), -100.0)
	assert_eq(style.trait_for(StyleLeanings.RANGE), "range_fighter")


func test_a_fighter_holds_at_most_one_trait_per_leaning() -> void:
	var style := StyleLeanings.new({ "pace": 80, "range": 80, "base": -80, "risk": 80 })
	assert_eq(style.traits(), ["natural_aggressor", "phone_booth_fighter", "sprawl_and_brawl", "finisher"] as Array[String])
