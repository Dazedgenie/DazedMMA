extends GutTest
## The camp planner (ui/camp_planner.gd, D133, docs/02 §3.6): plan each week from a focus
## week or by hand, see the forecast, run the camp and take the fighter into the fight.

var _planner: CampPlanner


func before_each() -> void:
	_planner = CampPlanner.new(FighterLibrary.load_dir().profile("wrestler"), 1)
	add_child_autofree(_planner)


func test_it_opens_on_week_one_of_a_six_week_camp_with_the_balanced_week() -> void:
	assert_eq(_planner.weeks, CampPlanner.WEEKS_DEFAULT)
	assert_eq(_planner.week_plan().id, "balanced")
	assert_eq(_planner.week_plan().days, TrainingLibrary.shared().plan("balanced").days)
	assert_string_contains(_planner.forecast_text(), "Chance of an injury this week")
	assert_string_contains(_planner.stats_text(), "Takedowns")
	assert_true(_planner._fight.disabled, "the fight comes after the camp")


func test_a_focus_week_fills_the_slots_and_its_instruction() -> void:
	_planner.pick_preset("wrestler")
	var plan: Dictionary = _planner.week_plan()
	assert_eq(plan.days, TrainingLibrary.shared().plan("wrestler").days)
	assert_eq(plan.instruction, "wrestle_heavy")
	assert_string_contains(_planner.forecast_text(), "Base")


func test_changing_a_slot_by_hand_makes_a_custom_week_and_a_new_forecast() -> void:
	var before: String = _planner.forecast_text()
	_planner.set_slot(11, "hard_sparring")
	var plan: Dictionary = _planner.week_plan()
	assert_eq(plan.id, CampPlanner.CUSTOM)
	assert_eq(plan.days[5][1], "hard_sparring", "Saturday evening")
	assert_eq(plan.days[0], ["boxing_drill", "wrestling_drill"], "the rest of the week stays")
	assert_ne(_planner.forecast_text(), before)


func test_running_a_week_logs_it_and_locks_the_camps_length_and_the_fighters_age() -> void:
	_planner.run_week()
	assert_eq(_planner.reports.size(), 1)
	assert_string_contains(_planner.log_text(), "Week 1, Balanced")
	assert_string_contains(_planner._week_label.text, "Week 2 of 6")
	assert_true(_planner._weeks_picker.disabled)
	assert_false(_planner._age.editable)


func test_running_the_rest_finishes_the_camp_and_the_fight_gets_the_trained_fighter() -> void:
	_planner.pick_preset("wrestler")
	_planner.run_rest()
	assert_true(_planner.done())
	assert_eq(_planner.reports.size(), 6)
	assert_false(_planner._fight.disabled)
	assert_string_contains(_planner.forecast_text(), "Fight night")
	watch_signals(_planner)
	_planner._fight.pressed.emit()
	assert_signal_emitted(_planner, "fight_pressed")
	var trained: Dictionary = get_signal_parameters(_planner, "fight_pressed")[0]
	assert_eq(trained.id, "wrestler_camp")
	assert_gt(float(trained.stats.takedowns), float(FighterLibrary.load_dir().profile("wrestler").stats.takedowns))
	assert_eq(_planner.summary().weeks.size(), 6)


func test_a_younger_fighter_learns_more_from_the_same_week() -> void:
	_planner._age.value = 30.0
	var old: float = _gain(_planner.camp.forecast(_planner.week_plan()))
	_planner._age.value = 19.0
	assert_eq(_planner.camp.age, 19)
	assert_gt(_gain(_planner.camp.forecast(_planner.week_plan())), old)


func test_starting_again_goes_back_to_week_one_with_the_fighter_as_they_came() -> void:
	_planner.run_week()
	_planner.reset()
	assert_eq(_planner.reports.size(), 0)
	assert_eq(_planner.camp.stat("takedowns"), float(FighterLibrary.load_dir().profile("wrestler").stats.takedowns))
	assert_false(_planner._weeks_picker.disabled)


func _gain(forecast: Dictionary) -> float:
	var total: float = 0.0
	for id: String in forecast.gains:
		total += float(forecast.gains[id])
	return total


func test_fight_night_says_how_the_camp_sends_the_fighter_in() -> void:
	_planner.run_rest()
	_planner.camp.fatigue = 60.0
	_planner.camp.injured_days = 3
	_planner.camp.injury_area = "legs"
	_planner._refresh()
	var text: String = _planner.forecast_text()
	assert_string_contains(text, "75% of the gas tank")
	assert_string_contains(text, "Still hurt (legs)")
	assert_string_contains(text, "clears him to fight hurt")
	assert_true(_planner.can_fight())
	var condition: Dictionary = _planner.trained_profile().condition
	assert_almost_eq(float(condition.tank), 0.75, 0.0001)
	assert_eq(_planner.summary().doctor, TrainingCamp.CLEARED_HURT)


func test_the_doctor_calls_off_the_fight_when_the_injury_is_bad() -> void:
	_planner.run_rest()
	_planner.camp.injured_days = 9
	_planner.camp.injury_area = "head"
	_planner._refresh()
	assert_false(_planner.can_fight())
	assert_true(_planner._fight.disabled)
	assert_string_contains(_planner.forecast_text(), "won't clear him")


func test_pulling_out_calls_off_the_fight_and_wastes_the_camp() -> void:
	assert_true(_planner._pull_out.disabled, "only on fight night")
	_planner.run_rest()
	_planner.pull_out()
	assert_true(_planner.pulled_out)
	assert_true(_planner._fight.disabled)
	assert_string_contains(_planner.forecast_text(), "camp is wasted")
	_planner.reset()
	assert_false(_planner.pulled_out, "a new camp")


func test_the_last_week_is_fight_week_with_the_fight_on_saturday_evening() -> void:
	for n in CampPlanner.WEEKS_DEFAULT - 1:
		_planner.run_week()
	assert_true(_planner.fight_week())
	assert_true(_planner._slots[-1].disabled, "Saturday evening is the fight")
	assert_string_contains(_planner.forecast_text(), "Fight week")
	_planner.run_week()
	assert_true(_planner.reports[-1].fight_week)
