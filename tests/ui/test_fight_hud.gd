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


func test_the_figure_readout_says_whats_left_of_each_area() -> void:
	var sim: FightSim = _sim()
	sim.fighters[1].damage.head = 350  # The Kicker: Chin 50, so 35% of his head is gone.
	assert_eq(FightHud.area_text(sim.fighters[1], "head"), "HEAD 65%")
	assert_eq(FightHud.area_text(sim.fighters[1], "legs"), "LEGS 100%")


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
	assert_eq(hud.read_call(0), "catch_the_kick", "Q is the first read call")
	assert_eq(hud.read_call(1), "fire_back", "E is Fire back! (D133)")
	hud._process(0.1)
	assert_true(hud.call_button("get_up").disabled, "Get up! is dimmed standing")
	assert_false(hud.call_button("takedown").disabled)
	assert_eq(hud._clock.text, "R1 5:00")


func test_the_top_bar_figure_shows_each_fighters_damage_by_area() -> void:
	var sim: FightSim = _sim()
	var hud := FightHud.new()
	add_child_autofree(hud)
	hud.watch(FightDriver.new(sim))
	sim.fighters[1].damage.head = 500  # The Kicker: Chin 50, so half his health.
	sim.fighters[1].rocked_ticks = 10
	hud._refresh(0.0)
	assert_almost_eq(float(hud._figures[1].hurt.head), 0.5, 0.0001)
	assert_true(hud._figures[1].rocked)
	assert_eq(hud._area_labels[1][0].text, "HEAD 50%")
	assert_eq(hud._area_labels[1][0].get_theme_color("font_color"), BodyDamageFigure.HALF, "half gone is yellow")
	assert_true(hud._rocked[1].visible)
	assert_eq(hud._area_labels[0][0].text, "HEAD 100%")
	assert_false(hud._rocked[0].visible)


func test_a_clean_shot_flashes_the_area_it_landed_on() -> void:
	var sim: FightSim = _sim()
	var hud := FightHud.new()
	add_child_autofree(hud)
	hud.watch(FightDriver.new(sim))
	sim._emit(FightEvent.STRIKE_LANDED, 0, { "action_id": "body_kick", "target": "body", "damage": 8 })
	assert_true(hud._figures[1].is_flashing("body"), "the Wrestler kicked the Kicker's body")
	assert_false(hud._figures[1].is_flashing("head"))
	assert_false(hud._figures[0].is_flashing("body"))



func test_the_danger_meter_names_the_hold_while_one_is_locked_in() -> void:
	var sim: FightSim = _sim()
	assert_eq(FightHud.danger_text(sim), "", "no hold, no meter")
	sim.apply_transition(0, "double_leg")
	assert_true(sim._lock_in(1, _actions.get_action("triangle")))
	assert_eq(FightHud.danger_text(sim), "Kicker's TRIANGLE CHOKE on Wrestler · danger 38", "40 + 0.5 × (57.5 − 62.5)")
