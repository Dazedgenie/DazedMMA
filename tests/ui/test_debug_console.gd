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
