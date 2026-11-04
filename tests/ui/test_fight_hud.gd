extends GutTest
## FightHud: the fight screen's HUD (docs/06 §6.17, D460–D466; first built as HUD v0, #19).

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
	assert_false(hud.call_button("get_up").visible, "Get up! is off the row standing (D462)")
	assert_true(hud.call_button("takedown").visible)
	assert_false(hud.call_button("takedown").disabled)
	assert_eq(hud._round.text, "ROUND 1")
	assert_eq(hud._clock.text, "5:00")


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


func test_the_position_diagram_shows_the_ground_position_and_who_is_on_top() -> void:
	var sim: FightSim = _sim()
	assert_eq(PositionDiagram.position_for(sim), "", "nothing to draw standing")
	assert_eq(FightHud.position_text(sim), "")
	sim.apply_transition(0, "double_leg")
	assert_eq(PositionDiagram.position_for(sim), "full_guard")
	assert_eq(PositionDiagram.top_fighter(sim), 0)
	sim.apply_transition(0, "guard_pass")
	sim.apply_transition(0, "take_mount")
	assert_eq(FightHud.position_text(sim), "MOUNT · WRESTLER ON TOP")
	sim.apply_transition(0, "take_back")
	assert_eq(FightHud.position_text(sim), "BACK CONTROL · WRESTLER HAS THE BACK")
	for where: String in ["full_guard", "half_guard", "side_control", "mount", "back_control", "scramble"]:
		assert_true(PositionDiagram.POSES.has(where), "a drawing for %s (D210)" % where)


func test_in_a_submission_the_diagram_shows_where_it_was_locked_from() -> void:
	var sim: FightSim = _sim()
	sim.apply_transition(0, "double_leg")
	assert_true(sim._lock_in(1, _actions.get_action("triangle")))
	assert_eq(PositionDiagram.position_for(sim), "full_guard")
	assert_eq(PositionDiagram.top_fighter(sim), 0, "the Wrestler is still drawn on top")
	assert_eq(FightHud.position_text(sim), "TRIANGLE CHOKE FROM FULL GUARD")


func test_the_diagram_panel_is_up_only_while_the_fight_is_on_the_ground() -> void:
	var hud := FightHud.new()
	add_child_autofree(hud)
	var sim: FightSim = _sim()
	hud.watch(FightDriver.new(sim))
	hud._process(0.1)
	assert_false(hud._position_panel.visible, "standing")
	sim.apply_transition(0, "double_leg")
	hud._process(0.1)
	assert_true(hud._position_panel.visible, "on the ground")
	assert_eq(hud._diagram.where, "full_guard")
	assert_eq(hud._diagram.top_colour, FightHud.FIGHTER_COLOURS[0])


func test_the_call_row_shows_only_the_calls_that_work_from_here_each_key_once() -> void:
	var sim: FightSim = _sim()
	var hud := FightHud.new()
	add_child_autofree(hud)
	hud.watch(FightDriver.new(sim))
	hud._process(0.1)
	assert_eq(_shown_keys(hud), ["1 Pressure", "2 Circle out", "3 Work the range", "4 Takedown", "5 Clinch", "6 Defend the shot",
		"7 Feint", "8 Survive", "9 Stay safe", "R Cut the cage", "Q Catch the kick", "E Fire back"], "standing: twelve")
	sim.apply_transition(0, "double_leg")
	hud._process(0.1)
	assert_eq(_shown_keys(hud), ["1 Ground and pound", "2 Go for the finish", "4 Pass", "7 Get up", "8 Survive", "9 Stay safe",
		"H Hand fight"], "the Wrestler on top in the guard")
	assert_false(hud._read_gap.visible, "no read calls on the ground, no gap for them")


func test_a_call_short_of_voice_stays_on_the_row_dimmed() -> void:
	var sim: FightSim = _sim()
	var hud := FightHud.new()
	add_child_autofree(hud)
	hud.watch(FightDriver.new(sim))
	for n in 4:
		sim.decisions[0].calls.hear(sim.views[0], sim.calls.get_call("catch_the_kick"))
	hud._process(0.1)
	assert_true(hud.call_button("takedown").visible)
	assert_true(hud.call_button("takedown").disabled, "not enough voice")
	assert_eq(hud.call_button("takedown").tooltip_text, "not enough voice")


func test_the_damage_numbers_show_only_with_the_details() -> void:
	var sim: FightSim = _sim()
	var hud := FightHud.new()
	add_child_autofree(hud)
	hud.watch(FightDriver.new(sim))
	hud._process(0.1)
	assert_false(hud._readouts[0].visible, "the figure's colours only (D463)")
	assert_eq(hud._figures[1].tooltip_text, "HEAD 100% · BODY 100% · LEGS 100%", "hovering the figure gives them")
	assert_false(hud.feed.details)
	hud.feed.pinned = true  # The feed's ALL · TAB button, as Tab held does.
	hud._process(0.1)
	assert_true(hud.details_shown())
	assert_true(hud._readouts[0].visible)
	assert_true(hud.feed.details, "and the whole feed with its odds")


func test_the_corner_card_shows_the_plan_and_each_rule_with_how_sharp_and_whether_ready() -> void:
	var sim: FightSim = _sim()
	sim.submit(FightCommand.set_rule(0, 0, 1, "catch_kick_and_shoot", 80.0))
	sim.tick()
	var rule: Dictionary = FightHud.rule_state(sim, 0, 0)
	assert_eq(rule.name, "When he kicks → catch & shoot")
	assert_eq(rule.status, "READY")
	assert_gt(float(rule.sharp), 0.0)
	assert_eq(FightHud.rule_state(sim, 0, 1), {"name": "empty", "sharp": 0.0, "status": ""})
	assert_eq(FightHud.plan_words(sim.decisions[0].gameplan), [Gameplan.OWN_GAME, ""])
	sim.submit(FightCommand.live_call(sim.now, 0, "catch_the_kick"))
	for n in 12:
		sim.tick()
	assert_eq(FightHud.call_state(sim, 0), "Catch the kick! · primed 6 s", "your call's chip under your name")


func test_the_clock_splits_into_the_round_and_the_time() -> void:
	assert_eq(FightHud.clock_parts("R1 4:25"), ["ROUND 1", "4:25"])
	assert_eq(FightHud.clock_parts("R10 0:05"), ["ROUND 10", "0:05"])


func test_a_clinch_with_no_grips_shows_no_empty_card() -> void:
	var sim: FightSim = _sim()
	var hud := FightHud.new()
	add_child_autofree(hud)
	hud.watch(FightDriver.new(sim))
	sim.apply_transition(0, "clinch_entry")
	assert_eq(sim.situation.position, PositionLibrary.CLINCH)
	assert_eq(FightHud.grips_text(sim), "")
	hud._process(0.1)
	assert_false(hud._position_panel.visible, "nothing to show, so no card (it used to be an empty box)")


func test_a_dialog_takes_the_calls_and_the_feed_down_and_the_round_break_sits_down_the_side() -> void:
	var hud := FightHud.new()
	add_child_autofree(hud)
	hud.watch(FightDriver.new(_sim()))
	hud.show_dialog("End of round 1", "", [["Start round 2", func() -> void: pass]], null, true)
	assert_true(hud.dialog_on_side())
	assert_false(hud._strip.visible)
	assert_false(hud.feed.visible)
	assert_false(hud._corner.visible)
	hud.hide_dialog()
	assert_true(hud._strip.visible)
	assert_true(hud.feed.visible)


func _shown_keys(hud: FightHud) -> Array[String]:
	var out: Array[String] = []
	for b: Node in hud._call_bar.get_children():
		if b is Button and (b as Button).visible:
			out.append("%s %s" % [(b.get_child(0) as Label).text, (b as Button).text])
	return out
