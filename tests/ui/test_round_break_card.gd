extends GutTest
## RoundBreakCard: the round break's judges' chips and the two men as bars (docs/06 §6.17, D465).


func _sim() -> FightSim:
	return FightSim.new(5, FighterLibrary.load_dir().make_pair("wrestler", "kicker"), ActionLibrary.load_dir())


func test_the_rows_put_the_two_men_side_by_side() -> void:
	var sim: FightSim = _sim()
	sim.fighters[0].strikes_landed = 12
	sim.fighters[0].strikes_thrown = 30
	sim.fighters[1].damage.legs = 40
	var rows: Array = RoundBreakCard.rows(sim)
	assert_eq(rows.map(func(r: Array) -> String: return String(r[0])), ["LANDED", "STAMINA", "HEAD HURT", "BODY HURT", "LEGS HURT"])
	assert_eq(rows[0][1], "12 of 30")
	assert_eq(rows[4][2], "40")
	assert_eq(float(rows[4][4]), 40.0)


func test_each_card_goes_to_a_man_and_the_most_cards_win_the_round() -> void:
	var sim: FightSim = _sim()
	assert_eq(RoundBreakCard.card_winner([10, 9]), 0)
	assert_eq(RoundBreakCard.card_winner([9, 10]), 1)
	assert_eq(RoundBreakCard.card_winner([10, 10]), -1)
	assert_eq(RoundBreakCard.round_verdict(sim, [[9, 10], [10, 9], [9, 10]]), "Kicker's round")
	assert_eq(RoundBreakCard.round_verdict(sim, [[10, 10], [10, 10], [10, 10]]), "An even round")


func test_the_card_shows_a_chip_for_each_judge() -> void:
	var sim: FightSim = _sim()
	var card := RoundBreakCard.new()
	add_child_autofree(card)
	card.show_round(sim, FightEvent.new(3000, 1, FightEvent.ROUND_ENDED, -1, {"cards": [[10, 9], [10, 9], [9, 10]]}))
	var judges: HBoxContainer = card.get_child(0) as HBoxContainer
	var chips: Array = judges.get_children().filter(func(c: Node) -> bool: return c is Label and (c as Label).text.contains("-"))
	assert_eq(chips.size(), 3)
	assert_eq((judges.get_child(judges.get_child_count() - 1) as Label).text, "Wrestler's round")
