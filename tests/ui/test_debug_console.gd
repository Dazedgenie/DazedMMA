extends GutTest
## DebugConsole: the in-game developer console.


func test_run_test_fight_prints_the_fight_and_a_pass_verdict() -> void:
	var console := DebugConsole.new()
	console.echo_to_output = false
	add_child_autofree(console)
	var check: SimCheck = console.run_test_fight()
	var text: String = console._log.get_parsed_text()
	assert_true(check.passed())
	assert_string_contains(text, "Test fight")
	assert_string_contains(text, "End of round 1")
	assert_string_contains(text, "All %d checks passed." % check.results.size())


func test_the_call_bar_makes_red_corners_calls_in_a_live_fight() -> void:
	var console := DebugConsole.new()
	console.echo_to_output = false
	add_child_autofree(console)
	assert_true(console._call_buttons[0].disabled, "no fight, no calls")
	console._toggle_live()
	assert_string_contains(console._live_sim.fighters[0].name, "Wrestler", "the playtest matchup comes first")
	console.make_call("pressure")
	for n in 10:
		console._live_sim.tick()
	var text: String = console._log.get_parsed_text()
	assert_string_contains(text, "Wrestler's corner: Pressure!")
	assert_string_contains(text, "the Pressure! call")
	console._stop_live()
