extends GutTest
## FightSummary: one fight as one row of numbers for the balance harness (#18).

const SEED: int = 20261024

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


## A short fight (one 60-second round) keeps the tests quick.
func _row(fight_seed: int = SEED, red: String = "kicker", blue: String = "boxer") -> Dictionary:
	return FightSummary.run(fight_seed, _roster, _actions, red, blue, 1, 60)


func test_a_row_has_every_csv_column() -> void:
	var row: Dictionary = _row()
	for column: String in FightSummary.COLUMNS:
		assert_true(row.has(column), "missing column %s" % column)
	assert_eq(row.size(), FightSummary.COLUMNS.size(), "no columns beyond the CSV's")


func test_the_same_seed_gives_the_same_row() -> void:
	assert_eq(JSON.stringify(_row()), JSON.stringify(_row()))


func test_a_row_matches_the_fight_it_came_from() -> void:
	var sim := FightSim.new(SEED, _roster.make_pair("kicker", "boxer"), _actions, 1, 60)
	sim.run_to_end()
	var row: Dictionary = FightSummary.of(sim)
	var end: FightEvent = sim.events[-1]
	assert_eq(row.red, "kicker")
	assert_eq(row.blue, "boxer")
	assert_eq(row.result, end.data.result)
	assert_eq(row.winner, "draw" if end.data.winner < 0 else FightSummary.SIDES[end.data.winner])
	assert_eq(row.thrown_red, sim.fighters[0].strikes_thrown)
	assert_eq(row.landed_blue, sim.fighters[1].strikes_landed)
	assert_eq(row.head_damage_red, sim.fighters[0].damage.head)
	assert_eq(row.events, sim.events.size())
	assert_eq(row.ruleset, "pro")


func test_lowest_stamina_is_never_above_stamina_at_the_end() -> void:
	var row: Dictionary = _row()
	for side: String in FightSummary.SIDES:
		assert_lte(row["stamina_low_" + side], row["stamina_end_" + side])
		assert_gt(row["stamina_low_" + side], 0.0)


func test_a_fight_to_the_judges_has_three_cards_a_round() -> void:
	var row: Dictionary = _row()
	if row.method in [FightSummary.METHOD_KO, FightSummary.METHOD_TKO]:
		pass_test("this seed was finished early; the card count only holds for decisions")
		return
	assert_eq(row.round_cards, Judging.JUDGES)
	assert_lte(row.even_cards, row.round_cards)


func test_every_strike_that_rolled_odds_counts_as_an_exchange() -> void:
	var sim := FightSim.new(SEED, _roster.make_pair("kicker", "boxer"), _actions, 1, 60)
	sim.run_to_end()
	var rolled: int = 0
	for e in sim.events:
		if e.data.has("odds"):
			rolled += 1
	var row: Dictionary = FightSummary.of(sim)
	assert_gt(row.exchanges, 0)
	assert_eq(row.exchanges, rolled)
	assert_lte(row.clamped, row.exchanges)


func test_results_sort_into_ko_tko_decision_or_draw() -> void:
	assert_eq(FightSummary.method_of(FightSim.RESULT_KO), FightSummary.METHOD_KO)
	assert_eq(FightSummary.method_of(FightSim.RESULT_TKO), FightSummary.METHOD_TKO)
	assert_eq(FightSummary.method_of(Judging.DRAW), FightSummary.METHOD_DRAW)
	for verdict: String in [Judging.UNANIMOUS, Judging.SPLIT, Judging.MAJORITY]:
		assert_eq(FightSummary.method_of(verdict), FightSummary.METHOD_DECISION)


func test_movement_columns_are_shares_of_standing_time() -> void:
	var row: Dictionary = _row()
	for column: String in ["fence_red", "pinned_red", "centre_red", "fence_blue", "pinned_blue", "centre_blue", "chase"]:
		assert_between(float(row[column]), 0.0, 1.0, column)
	for side: String in FightSummary.SIDES:
		assert_lte(row["pinned_" + side], row["fence_" + side], "pinned on the fence is part of the time near it")
	assert_lte(row.centre_red + row.centre_blue, 1.001, "only one fighter can be nearer the centre at a time")


func test_a_row_made_without_movement_counts_has_no_movement() -> void:
	var sim := FightSim.new(SEED, _roster.make_pair("kicker", "boxer"), _actions, 1, 60)
	sim.run_to_end()
	var row: Dictionary = FightSummary.of(sim)
	assert_eq(row.chase, 0.0)
	assert_eq(row.fence_red, 0.0)
