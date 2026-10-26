extends GutTest
## FightHud: HUD v0 (docs/06 §1–§2, #19).

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


func _sim() -> FightSim:
	return FightSim.new(5, _roster.make_pair("wrestler", "kicker"), _actions)


func test_a_call_is_dimmed_when_it_cant_be_made_from_here() -> void:
	var sim: FightSim = _sim()
	assert_eq(FightHud.call_problem(sim, 0, sim.calls.get_call("takedown")), "")
	assert_eq(FightHud.call_problem(sim, 0, sim.calls.get_call("get_up")), "not from here", "Get up! needs the ground")
	assert_eq(FightHud.call_problem(sim, 1, sim.calls.get_call("catch_the_kick")), "not learned", "the Kicker never learned the catch")
	sim.decisions[0].calls.hear(sim.views[0], sim.calls.get_call("catch_the_kick"))
	sim.decisions[0].calls.hear(sim.views[0], sim.calls.get_call("catch_the_kick"))
	sim.decisions[0].calls.hear(sim.views[0], sim.calls.get_call("catch_the_kick"))
	sim.decisions[0].calls.hear(sim.views[0], sim.calls.get_call("catch_the_kick"))
	assert_eq(FightHud.call_problem(sim, 0, sim.calls.get_call("takedown")), "not enough voice")


func test_the_judges_estimate_reads_the_round_so_far() -> void:
	var sim: FightSim = _sim()
	assert_eq(FightHud.judges_estimate(sim), "Judges: nothing in it yet")
	sim._round_points = [40.0, 10.0]
	assert_eq(FightHud.judges_estimate(sim), "Judges: ≈ 10-9 Wrestler")
	sim._round_points = [10.0, 10.2]
	assert_eq(FightHud.judges_estimate(sim), "Judges: ≈ even")


func test_health_bars_go_green_yellow_red() -> void:
	assert_eq(FightHud.health_colour(1.0), FightHud.PIP_COLOURS[0])
	assert_eq(FightHud.health_colour(0.5), FightHud.PIP_COLOURS[1])
	assert_eq(FightHud.health_colour(0.2), FightHud.PIP_COLOURS[2])


func test_the_plan_panel_shows_rules_calls_and_reads_with_their_timers() -> void:
	var sim: FightSim = _sim()
	sim.submit(FightCommand.set_rule(0, 0, 1, "catch_kick_and_shoot", 80.0))
	sim.submit(FightCommand.live_call(0, 0, "catch_the_kick"))
	for n in 12:
		sim.tick()
	var text: String = plan_plain(FightHud.plan_text(sim, 0))
	assert_string_contains(text, "When he kicks → catch & shoot")
	assert_string_contains(text, "% sharp · ready")
	assert_string_contains(text, "2  empty")
	assert_string_contains(text, "Catch the kick!  primed 6 s")


func plan_plain(bbcode: String) -> String:
	var r := RegEx.create_from_string("\\[[^\\]]*\\]")
	return r.sub(bbcode, "", true)


func test_the_hud_follows_a_fight_and_its_buttons_make_calls() -> void:
	var hud := FightHud.new()
	add_child_autofree(hud)
	var driver := FightDriver.new(_sim())
	hud.watch(driver)
	var called: Array[String] = []
	hud.call_pressed.connect(func(id: String) -> void: called.append(id))
	hud.call_button("takedown").pressed.emit()
	assert_eq(called, ["takedown"])
	assert_eq(hud.read_call(0), "catch_the_kick", "Q is the read call")
	hud._process(0.1)
	assert_true(hud.call_button("get_up").disabled, "Get up! is dimmed standing")
	assert_false(hud.call_button("takedown").disabled)
	assert_eq(hud._clock.text, "R1 5:00")


func test_the_top_bar_shows_each_fighters_health_from_their_head_damage() -> void:
	var sim: FightSim = _sim()
	var hud := FightHud.new()
	add_child_autofree(hud)
	hud.watch(FightDriver.new(sim))
	sim.fighters[1].damage.head = 500  # The Kicker: Chin 50, so half his health.
	sim.fighters[1].rocked_ticks = 10
	hud._refresh(0.0)
	assert_almost_eq(hud._health[1].value, 0.5, 0.0001)
	assert_eq(hud._health_label[1].text, "HEALTH 50%  ROCKED")
	assert_eq(hud._health_fill[1].bg_color, FightHud.PIP_COLOURS[1])
	assert_eq(hud._health_label[0].text, "HEALTH 100%")

