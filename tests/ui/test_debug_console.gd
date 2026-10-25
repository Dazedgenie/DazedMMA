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


func test_the_console_logs_the_fight_on_screen_as_it_happens() -> void:
	var console := DebugConsole.new()
	console.echo_to_output = false
	add_child_autofree(console)
	assert_false(console.visible, "it starts hidden (the ` key shows it)")
	var sim := FightSim.new(9, FighterLibrary.load_dir().make_pair("wrestler", "kicker"), ActionLibrary.load_dir())
	console.watch(sim, "Wrestler vs Kicker, seed 9")
	sim.submit(FightCommand.live_call(0, 0, "pressure"))
	for n in 10:
		sim.tick()
	var text: String = console._log.get_parsed_text()
	assert_string_contains(text, "Wrestler vs Kicker, seed 9")
	assert_string_contains(text, "Wrestler's corner: Pressure!")
	console.watch(null)
	sim.tick()
