extends GutTest
## ArenaView and FighterFigure: the grey-box fight view (#19, D80, D51).

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


func _sim() -> FightSim:
	return FightSim.new(3, _roster.make_pair("wrestler", "kicker"), _actions)


func test_the_tag_names_the_range_standing_and_the_position_tied_up() -> void:
	var sim: FightSim = _sim()
	assert_eq(ArenaView.tag_text(sim), "Out of range")
	sim.apply_transition(0, "double_leg")
	assert_eq(ArenaView.tag_text(sim), "Full guard · Wrestler on top")


func test_kicks_lift_a_leg_and_shots_drop_the_hips() -> void:
	var sim: FightSim = _sim()
	var figure := FighterFigure.new(Color.RED)
	add_child_autofree(figure)
	var rest: Dictionary = figure.pose_for(sim, 1)
	sim.fighters[1].action_id = "body_kick"
	sim.fighters[1].phase = "active"
	var kick: Dictionary = figure.pose_for(sim, 1)
	assert_gt(kick.leg_rear, rest.leg_rear + 1.0, "the rear leg comes up")
	sim.fighters[0].action_id = "double_leg"
	sim.fighters[0].phase = "active"
	assert_lt(figure.pose_for(sim, 0).hip_y, rest.hip_y - 0.3, "the shooter changes levels")
	sim.fighters[1].clear_action()
	sim.fighters[0].clear_action()
	sim.apply_transition(0, "double_leg")
	assert_eq(figure.pose_for(sim, 1).lie, 1.0, "the fighter on the bottom lies on their back")


func test_the_body_kick_is_thrown_with_the_rear_leg_for_the_tell_cue() -> void:
	assert_eq(FighterFigure.limb_for("body_kick"), "rear_leg")
	assert_eq(FighterFigure.limb_for("jab"), "lead_arm")
	assert_eq(FighterFigure.limb_for("double_leg"), "hips")


func test_a_scouted_tell_lights_up_until_the_move_comes() -> void:
	var view := ArenaView.new()
	add_child_autofree(view)
	var sim: FightSim = _sim()
	var driver := FightDriver.new(sim)
	view.watch(driver)
	# The Kicker's tell: his jab gets blocked, the body kick follows (data/fighters/kicker.json).
	sim.event_emitted.emit(FightEvent.new(sim.now, 1, FightEvent.STRIKE_MISSED, 1, { "action_id": "jab", "chance": 0.5 }))
	assert_eq(view._tell_limb[1], "rear_leg")
	assert_gt(view._tell_until[1], sim.now)
	view._process(0.016)
	assert_true(view.figures[1]._tell.visible)
	view.tell_cues = false
	view._process(0.016)
	assert_false(view.figures[1]._tell.visible, "the cue can be switched off for the playtest's comparison (D51)")
	sim.event_emitted.emit(FightEvent.new(sim.now, 1, FightEvent.ACTION_PHASE, 1, { "action_id": "body_kick", "phase": "active" }))
	assert_eq(view._tell_until[1], -1, "gone once the kick is on its way")


func test_the_view_only_watches_the_fight() -> void:
	var view := ArenaView.new()
	add_child_autofree(view)
	var watched: FightSim = _sim()
	var driver := FightDriver.new(watched)
	view.watch(driver)
	view.debug_marks = true
	while not watched.is_over():
		driver.step()
		if watched.now % 7 == 0:
			view._process(0.016)
	var plain: FightSim = _sim()
	plain.run_to_end()
	assert_eq(watched.events_as_dicts(), plain.events_as_dicts())


func test_a_collar_tie_pulls_his_head_down_and_puts_the_holders_hands_behind_it() -> void:
	var sim: FightSim = _sim()
	var figure := FighterFigure.new(Color.RED)
	add_child_autofree(figure)
	sim.apply_transition(0, "clinch_entry")
	var clinched: Dictionary = figure.pose_for(sim, 1)
	var holding: Dictionary = figure.pose_for(sim, 0)
	sim.fighters[1].tied_up_ticks = 40
	assert_lt(figure.pose_for(sim, 1).lean, clinched.lean - 0.3, "bent over in the tie (D129)")
	assert_gt(figure.pose_for(sim, 0).arm_lead, holding.arm_lead, "hands up behind his head")


func test_mount_sits_up_side_control_lies_across_and_the_back_sits_behind() -> void:
	var sim: FightSim = _sim()
	var figure := FighterFigure.new(Color.RED)
	add_child_autofree(figure)
	sim.apply_transition(0, "double_leg")
	var guard: Dictionary = figure.pose_for(sim, 0)
	sim.apply_transition(0, "guard_pass")
	assert_lt(figure.pose_for(sim, 0).lean, guard.lean, "flat across him in side control (D130)")
	sim.apply_transition(0, "take_mount")
	assert_gt(figure.pose_for(sim, 0).lean, guard.lean, "sat up on his chest in mount")
	assert_eq(ArenaView.tag_text(sim), "Mount · Wrestler on top")
	sim.apply_transition(0, "take_back")
	assert_lt(figure.pose_for(sim, 1).lie, 1.0, "sat up with him behind")
	assert_eq(ArenaView.tag_text(sim), "Back control · Wrestler has the back")
