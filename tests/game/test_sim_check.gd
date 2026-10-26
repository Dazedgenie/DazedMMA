extends GutTest
## SimCheck: the short self-check fight behind the debug console's "Run test fight" button.


func test_the_self_check_passes_on_a_healthy_build() -> void:
	for fight_seed in [1, 2, 3, 99, 123456]:
		var check: SimCheck = SimCheck.run(fight_seed)
		for r in check.results:
			assert_true(r.passed, "seed %d: %s (%s)" % [fight_seed, r.name, r.detail])
		assert_true(check.passed())


func test_the_self_check_fails_when_no_moves_load() -> void:
	var check: SimCheck = SimCheck.run(1, ActionLibrary.new())
	assert_false(check.passed())
	assert_eq(check.results[0].name, "Moves load from data/actions")


func test_ci_machines_get_the_slow_machine_margin_and_others_dont() -> void:
	var was: String = OS.get_environment("CI")
	OS.set_environment("CI", "true")
	assert_almost_eq(SimCheck.budget_ms(60.0), 60.0 * SimCheck.CI_MARGIN, 0.001)
	OS.set_environment("CI", "")
	assert_almost_eq(SimCheck.budget_ms(60.0), 60.0, 0.001)
	OS.set_environment("CI", was)
