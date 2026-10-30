extends GutTest
## The fight night card (ui/fight_night_card.gd, D171, docs/02 §3.11): shown over the camp planner when the camp is
## over, with the gas tank, fatigue, injury, the doctor's stamp and Fight! or Pull out.

var _planner: CampPlanner


func before_each() -> void:
	_planner = CampPlanner.new(FighterLibrary.load_dir().profile("wrestler"), 1)
	_planner.opponent_name = "Kicker"
	add_child_autofree(_planner)


func test_it_opens_when_the_last_week_has_run_and_not_before() -> void:
	_planner.run_week()
	assert_false(_planner.night_card.visible)
	_planner.run_rest()
	assert_true(_planner.night_card.visible)
	var text: String = _planner.night_card.text()
	assert_string_contains(text, "vs Kicker")
	assert_string_contains(text, "Gas tank")
	assert_true(_planner.night_card.can_fight())


func test_a_fit_fighter_gets_the_cleared_stamp_and_a_full_tank() -> void:
	_planner.run_rest()
	_planner.camp.fatigue = 0.0
	_planner.camp.injured_days = 0
	_planner._refresh()
	var text: String = _planner.night_card.text()
	assert_string_contains(text, "CLEARED")
	assert_string_contains(text, "Gas tank 100%")
	assert_string_contains(text, "Injury None")


func test_a_hurt_fighter_is_cleared_to_fight_hurt_and_the_figure_shows_where() -> void:
	_planner.run_rest()
	_planner.camp.fatigue = 60.0
	_planner.camp.injured_days = 3
	_planner.camp.injury_area = "legs"
	_planner._refresh()
	var text: String = _planner.night_card.text()
	assert_string_contains(text, "CLEARED TO FIGHT HURT")
	assert_string_contains(text, "Gas tank 75%")
	assert_string_contains(text, "Legs, 3 days to heal")
	assert_gt(float(_planner.night_card._figure.hurt.legs), 0.0)
	assert_true(_planner.night_card.can_fight())


func test_the_doctor_stamps_not_cleared_and_fight_is_off() -> void:
	_planner.run_rest()
	_planner.camp.injured_days = 9
	_planner.camp.injury_area = "head"
	_planner._refresh()
	assert_string_contains(_planner.night_card.text(), "NOT CLEARED")
	assert_false(_planner.night_card.can_fight())


func test_pulling_out_from_the_card_stamps_it_and_calls_the_fight_off() -> void:
	_planner.run_rest()
	_planner.night_card.pull_out_pressed.emit()
	assert_true(_planner.pulled_out)
	assert_string_contains(_planner.night_card.text(), "PULLED OUT")
	assert_false(_planner.night_card.can_fight())


func test_fight_on_the_card_takes_the_trained_fighter_into_the_fight() -> void:
	_planner.run_rest()
	watch_signals(_planner)
	_planner.night_card.press_fight()
	assert_signal_emitted(_planner, "fight_pressed")
	assert_eq(get_signal_parameters(_planner, "fight_pressed")[0].id, "wrestler_camp")


func test_going_back_shows_the_camp_and_fight_night_brings_the_card_back() -> void:
	_planner.run_rest()
	_planner.night_card.back_pressed.emit()
	assert_false(_planner.night_card.visible)
	assert_true(_planner._night_button.visible)
	_planner._night_button.pressed.emit()
	assert_true(_planner.night_card.visible)
	_planner.reset()
	assert_false(_planner.night_card.visible, "a new camp starts on week 1")
