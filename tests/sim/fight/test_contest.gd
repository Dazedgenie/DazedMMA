extends GutTest
## Contest: the one odds formula for every exchange (docs/11-attributes-and-traits.md §3.1).

var _actions: ActionLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()


func test_the_jab_example_from_the_design_doc_comes_out_at_65_percent() -> void:
	# Boxing 70 / Speed 60 (average 65) into Striking defense 50.
	assert_almost_eq(Contest.chance(Contest.STRIKE_BASE, 65.0, 50.0), 0.65, 0.0001)


func test_situation_bonuses_add_straight_onto_the_odds() -> void:
	assert_almost_eq(Contest.chance(0.35, 50.0, 50.0, 0.15), 0.50, 0.0001)


func test_stats_tilt_the_odds_but_never_guarantee_anything() -> void:
	assert_eq(Contest.chance(0.5, 100.0, 0.0), Contest.MAX_CHANCE)
	assert_eq(Contest.chance(0.5, 0.0, 100.0), Contest.MIN_CHANCE)
	assert_eq(Contest.chance(0.5, 50.0, 50.0, 2.0), Contest.MAX_CHANCE)


func test_each_kind_of_action_starts_from_its_own_base_odds() -> void:
	assert_eq(Contest.base_for(_actions.get_action("jab")), 0.5)
	assert_almost_eq(Contest.base_for(_actions.get_action("double_leg")), 0.45, 0.0001)
	assert_almost_eq(Contest.base_for(_actions.get_action("sprawl")), 0.45, 0.0001)
