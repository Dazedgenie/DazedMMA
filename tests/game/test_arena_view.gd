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


func test_a_feint_dips_and_a_fighter_who_bit_puts_his_hands_up() -> void:
	var sim: FightSim = _sim()
	var figure := FighterFigure.new(Color.RED)
	add_child_autofree(figure)
	var rest: Dictionary = figure.pose_for(sim, 1)
	sim.fighters[0].action_id = "feint"
	sim.fighters[0].phase = "active"
	assert_lt(figure.pose_for(sim, 0).hip_y, rest.hip_y, "a dip of the level (D131)")
	sim.fighters[1].bit_ticks = 5
	var bit: Dictionary = figure.pose_for(sim, 1)
	assert_gt(bit.arm_lead, rest.arm_lead + 0.3, "hands up")
	assert_gt(bit.lean, rest.lean, "weight back")


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


func test_in_a_leg_lock_the_attacker_lies_back_holding_the_leg_out() -> void:
	var sim: FightSim = _sim()
	var figure := FighterFigure.new(Color.RED)
	add_child_autofree(figure)
	sim.apply_transition(1, "double_leg")  # Red underneath in full guard.
	var guard: Dictionary = figure.pose_for(sim, 1)
	assert_true(sim._lock_in(0, sim.actions.get_action("ankle_lock")))
	assert_eq(figure.pose_for(sim, 0).lie, 1.0, "lying back with the foot (D132)")
	assert_gt(figure.pose_for(sim, 1).leg_lead, guard.leg_lead, "his leg out straight in the lock")
	assert_string_contains(ArenaView.tag_text(sim), "ankle lock")


## The top man's spot against the man underneath (fighter 1): [metres toward his feet, metres to his side, facing · his].
func _against_bottom(sim: FightSim) -> Array[float]:
	var spots: Array[Vector2] = [sim.fighters[0].pos, sim.fighters[1].pos]
	var placed: Array[Dictionary] = ArenaView.ground_spots(sim, spots)
	var feet: Vector2 = Vector2.from_angle(placed[1].facing)
	var d: Vector2 = placed[0].at - placed[1].at
	return [d.dot(feet), absf(d.dot(feet.orthogonal())), Vector2.from_angle(placed[0].facing).dot(feet)]


func test_standing_the_view_keeps_them_where_the_sim_has_them_face_to_face() -> void:
	var sim: FightSim = _sim()
	var spots: Array[Vector2] = [sim.fighters[0].pos, sim.fighters[1].pos]
	var placed: Array[Dictionary] = ArenaView.ground_spots(sim, spots)
	assert_eq(placed[0].at, spots[0])
	assert_almost_eq(Vector2.from_angle(placed[0].facing).dot((spots[1] - spots[0]).normalized()), 1.0, 0.001)


func test_each_ground_position_puts_the_top_man_somewhere_different() -> void:
	var sim: FightSim = _sim()
	sim.apply_transition(0, "double_leg")  # The Wrestler on top of the Kicker.
	var guard: Array[float] = _against_bottom(sim)
	assert_gt(guard[0], 0.3, "in the guard he kneels by the other man's feet (D210)")
	assert_lt(guard[2], -0.9, "facing him")
	sim.apply_transition(0, "guard_pass", PositionLibrary.PARTIAL)
	var half: Array[float] = _against_bottom(sim)
	assert_lt(half[0], guard[0], "half guard: further up his body")
	assert_gt(half[1], 0.1, "and off to one side")
	sim.apply_transition(0, "guard_pass")
	var side: Array[float] = _against_bottom(sim)
	assert_lt(side[0], 0.0, "side control: up by his chest")
	assert_gt(side[1], 0.4, "from the side")
	assert_lt(absf(side[2]), 0.2, "across him")
	sim.apply_transition(0, "take_mount")
	var mount: Array[float] = _against_bottom(sim)
	assert_lt(Vector2(mount[0], mount[1]).length(), 0.35, "mount: sat on him")
	assert_lt(mount[2], -0.9, "facing his head")
	sim.apply_transition(0, "take_back")
	var back: Array[float] = _against_bottom(sim)
	assert_lt(back[0], -0.3, "the back: behind him")
	assert_gt(back[2], 0.9, "facing the same way he does")


func test_a_hold_is_laid_out_where_it_was_locked_from_and_a_leg_lock_is_left_alone() -> void:
	var sim: FightSim = _sim()
	sim.apply_transition(0, "double_leg")
	sim.apply_transition(0, "guard_pass")
	sim.apply_transition(0, "take_mount")
	assert_true(sim._lock_in(0, sim.actions.get_action("armbar")))
	assert_lt(_against_bottom(sim)[2], -0.9, "the armbar from mount keeps the mount's layout")
	var legs: FightSim = _sim()
	legs.apply_transition(1, "double_leg")
	assert_true(legs._lock_in(0, legs.actions.get_action("ankle_lock")))
	var spots: Array[Vector2] = [legs.fighters[0].pos, legs.fighters[1].pos]
	assert_eq(ArenaView.ground_spots(legs, spots)[1].at, spots[1], "a leg lock stays as the sim has it")


func test_the_man_underneath_wraps_his_legs_in_the_guard_and_is_flattened_in_mount() -> void:
	var sim: FightSim = _sim()
	var figure := FighterFigure.new(Color.RED)
	add_child_autofree(figure)
	sim.apply_transition(0, "double_leg")
	var guard: Dictionary = figure.pose_for(sim, 1)
	assert_gt(guard.spread, 0.0, "legs apart round his waist (D210)")
	assert_eq(figure.pose_for(sim, 0).kneel, 1.0, "the top man is on his knees")
	sim.apply_transition(0, "guard_pass")
	sim.apply_transition(0, "take_mount")
	assert_lt(figure.pose_for(sim, 1).leg_lead, guard.leg_lead - 0.5, "flat under the mount")
	assert_gt(figure.pose_for(sim, 0).spread, 0.5, "astride him")


func test_the_view_slides_the_top_man_round_to_his_new_spot() -> void:
	var view := ArenaView.new()
	add_child_autofree(view)
	var sim: FightSim = _sim()
	sim.apply_transition(0, "double_leg")
	view.watch(FightDriver.new(sim))
	view._process(0.016)
	var guard_at: Vector2 = Vector2(view.figures[0].position.x, view.figures[0].position.z)
	sim.apply_transition(0, "guard_pass")
	var spots: Array[Vector2] = [sim.fighters[0].pos, sim.fighters[1].pos]
	var want: Vector2 = ArenaView.ground_spots(sim, spots)[0].at
	view._process(0.016)
	var moving: Vector2 = Vector2(view.figures[0].position.x, view.figures[0].position.z)
	assert_gt(moving.distance_to(want), 0.1, "not there in one frame")
	for n in 120:
		view._process(0.016)
	assert_almost_eq(Vector2(view.figures[0].position.x, view.figures[0].position.z).distance_to(want), 0.0, 0.01,
		"there within two seconds")
	assert_ne(guard_at, want)


func test_the_face_gloves_and_toes_are_on_the_front_of_the_fighter() -> void:
	var sim: FightSim = _sim()
	var figure := FighterFigure.new(Color.RED)
	add_child_autofree(figure)
	figure.show_state(sim, 0, Vector2.ZERO, Vector2(1.0, 0.0), 1.0)  # Facing +x on the canvas.
	var head: Vector3 = figure._head.global_position
	var face: Node3D = figure._head.get_child(0)
	assert_gt(face.global_position.x, head.x + 0.05, "the face is on the front of the head (D211)")
	for side in 2:
		var foot: Node3D = figure._feet[side]
		var foot_box: Vector3 = foot.global_position
		var leg_end: Vector3 = figure._leg_meshes[side].to_global(Vector3(0.0, -FighterFigure.LEG_LENGTH, 0.0))
		assert_gt(foot_box.x, leg_end.x, "toes forward")
		assert_true(foot.visible, "standing, the feet show")
	assert_gt(figure._gloves[0].global_position.x, figure._hips.global_position.x, "his guard is up in front of him")
	sim.apply_transition(0, "double_leg")
	figure.show_state(sim, 0, Vector2.ZERO, Vector2(1.0, 0.0), 1.0)
	assert_true(figure._feet[0].visible, "kneeling keeps the folded lower leg and foot")
	assert_almost_eq(figure._shins[0].global_position.y, 0.075, 0.005, "the knee rests on the canvas")
	assert_lt(figure._feet[0].global_position.x, figure._shins[0].global_position.x, "the shin folds behind the knee")


func test_the_closer_camera_keeps_heads_and_feet_clear_of_the_top_and_bottom_hud() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	add_child_autofree(viewport)
	var view := ArenaView.new()
	viewport.add_child(view)
	var sim: FightSim = _sim()
	view.watch(FightDriver.new(sim))
	for pair: Array in [
		[Vector2(-0.7, 0.7), Vector2(0.7, -0.7)],
		[Vector2(2.8, 1.8), Vector2(3.8, 0.6)],
		[Vector2(-3.8, -0.6), Vector2(-2.8, -1.8)],
		[Vector2(-4, 0), Vector2(4, 0)],
		[Vector2(-2.8, -2.8), Vector2(2.8, 2.8)]
	]:
		for i in 2:
			sim.fighters[i].pos = pair[i]
		for frame in 30:
			view._place_camera(0.2, (pair[0] + pair[1]) / 2.0, sim)
		for at: Vector2 in pair:
			for height: float in [0.0, 2.0]:
				var point := Vector3(at.x, height, at.y)
				var screen: Vector2 = view.camera.unproject_position(point) / Vector2(viewport.size)
				assert_false(view.camera.is_position_behind(point))
				assert_between(screen.x, 0.08, 0.92, "both fighters fit horizontally")
				assert_between(screen.y, 0.18, 0.82, "heads and feet clear the broadcast/control bars")


func test_clearing_the_arena_detaches_the_old_fight_events() -> void:
	var view := ArenaView.new()
	add_child_autofree(view)
	var sim: FightSim = _sim()
	view.watch(FightDriver.new(sim))
	view.watch(null)
	assert_false(sim.event_emitted.is_connected(view._on_event))
	sim.event_emitted.emit(FightEvent.new(1, 1, FightEvent.STRIKE_LANDED, 0, {"target": "head", "damage": 10}))
	assert_true(view.figures.is_empty())


func test_idle_feet_touch_the_mat_and_a_kick_can_lift_then_replant_them() -> void:
	var sim: FightSim = _sim()
	var figure := FighterFigure.new(Color.BLUE, false, 1)
	add_child_autofree(figure)
	figure.show_state(sim, 1, Vector2.ZERO, Vector2(1, 0), 1.0)
	for foot: MeshInstance3D in figure._feet:
		assert_almost_eq(_lowest_vertex(foot), 0.0, 0.005, "the neutral stance meets the canvas")
	sim.fighters[1].action_id = "body_kick"
	sim.fighters[1].phase = "active"
	figure.show_state(sim, 1, Vector2.ZERO, Vector2(1, 0), 1.0)
	assert_gt(_lowest_vertex(figure._feet[1]), 0.4, "planting must not pin a kicking foot to the floor")
	sim.fighters[1].clear_action()
	figure.show_state(sim, 1, Vector2.ZERO, Vector2(1, 0), 1.0)
	for foot: MeshInstance3D in figure._feet:
		assert_almost_eq(_lowest_vertex(foot), 0.0, 0.005, "returning to guard restores the stance")


func _lowest_vertex(mesh: MeshInstance3D) -> float:
	var lowest: float = INF
	var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for point: Vector3 in vertices:
		lowest = minf(lowest, mesh.to_global(point).y)
	return lowest


func test_clinch_bodies_have_room_at_the_fence_without_moving_the_sim() -> void:
	var sim: FightSim = _sim()
	sim.apply_transition(0, "clinch_entry")
	var before: Array[Vector2] = [sim.fighters[0].pos, sim.fighters[1].pos]
	var spots: Array[Vector2] = [Vector2(3.9, 0), Vector2(4.2, 0)]
	var placed: Array[Dictionary] = ArenaView.ground_spots(sim, spots)
	assert_gt(placed[0].at.distance_to(placed[1].at), 0.75, "the sculpted torsos must not pass through each other")
	for pose: Dictionary in placed:
		assert_gte(Octagon.distance_to_fence(pose.at), Octagon.BODY_MARGIN - 0.001)
	assert_eq([sim.fighters[0].pos, sim.fighters[1].pos], before, "spacing is presentation-only")
