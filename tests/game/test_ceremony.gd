extends GutTest
## Before, between and after the rounds (D390-D394): touching gloves at the centre before the bell, the stools and the
## corner team between rounds with the cutman closing a cut, the winner celebrating and the referee raising his hand,
## and a key or click skipping any of them. Presentation only: the fight is held while one plays.

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


## A watched fight: [sim, view].
func _watched(red := "dirty_boxer", blue := "muay_thai", fight_seed: int = 3) -> Array:
	var sim := FightSim.new(fight_seed, _roster.make_pair(red, blue), _actions)
	var view := ArenaView.new()
	add_child_autofree(view)
	view.watch(FightDriver.new(sim))
	view.driver._snap()
	_frames(view, 5)
	return [sim, view]


func _frames(view: ArenaView, count: int, delta: float = 1.0 / 20.0) -> void:
	for n in count:
		view._process(delta)


## Plays frames until the moment playing gets to its end (at most `seconds`): how long it took.
func _play_out(view: ArenaView, seconds: float = 20.0, delta: float = 1.0 / 20.0) -> float:
	var took: float = 0.0
	while view.moment_playing() and took < seconds:
		view._process(delta)
		took += delta
	return took


func _hand_height(view: ArenaView, i: int, side: String) -> float:
	return Vector3(view._clinch_rigs[i].joints["wrist_" + side]).y


func test_the_stools_are_in_each_mans_corner_inside_the_cage_and_across_from_each_other() -> void:
	for i in 2:
		var stool: Vector2 = Ceremony.stool_spot(i)
		assert_gt(Octagon.distance_to_fence(stool), 0.4, "inside the cage")
		assert_lt(Octagon.distance_to_fence(stool), 1.2, "in his corner")
		assert_lt(stool.distance_to(FightSim.START_POSITIONS[i]), stool.distance_to(FightSim.START_POSITIONS[1 - i]),
			"on his side")
	assert_almost_eq(Ceremony.stool_spot(0).distance_to(-Ceremony.stool_spot(1)), 0.0, 0.001, "across from each other")
	assert_gt(Octagon.distance_to_fence(Ceremony.neutral_spot()), 0.5, "the referee waits inside it too")


func test_a_watched_fight_with_the_bodies_and_the_referee_can_play_them() -> void:
	var view: ArenaView = _watched()[1]
	assert_true(view.can_play_moments())
	assert_false(view.moment_playing())
	var bare := ArenaView.new()
	add_child_autofree(bare)
	assert_false(bare.can_play_moments(), "nothing to play them on")
	assert_false(bare.play_moment(Ceremony.INTRO))


func test_before_the_bell_they_walk_from_their_corners_touch_gloves_and_back_off_to_their_marks() -> void:
	var made: Array = _watched()
	var sim: FightSim = made[0]
	var view: ArenaView = made[1]
	view.driver.held = true
	watch_signals(view.ceremony)
	view.play_moment(Ceremony.INTRO)
	assert_true(view.moment_playing())
	for i in 2:
		assert_almost_eq(view.ceremony.men[i].spot.distance_to(Ceremony.stool_spot(i)), 0.0, 0.01, "from his corner")
	var touched: bool = false
	var took: float = 0.0
	while view.moment_playing() and took < 20.0:
		view._process(0.05)
		took += 0.05
		if view.ceremony.beat == "touch":
			touched = touched or view.ceremony.men[0].spot.distance_to(view.ceremony.men[1].spot) < Ceremony.TOUCH_GAP + 0.05
	assert_true(touched, "close enough to touch gloves")
	assert_lt(took, 9.0, "a few seconds")
	assert_signal_emitted_with_parameters(view.ceremony, "moment_done", [Ceremony.INTRO])
	assert_false(view.ceremony.active(), "the fight draws them again")
	for i in 2:
		assert_almost_eq(view.ceremony.men[i].spot.distance_to(FightSim.START_POSITIONS[i]), 0.0, 0.02, "on his mark")
	assert_eq(sim.now, 0, "the fight waited")


func test_between_rounds_they_sit_on_their_stools_with_the_coach_and_cutman_then_walk_out_to_their_marks() -> void:
	var made: Array = _watched()
	var view: ArenaView = made[1]
	var c: Ceremony = view.ceremony
	view.driver.held = true
	view.play_moment(Ceremony.CORNERS)
	assert_eq(c.team.size(), 4, "a coach and a cutman in each corner")
	_play_out(view)
	assert_eq(c.beat, "seated")
	assert_true(c.active(), "held there through the break")
	for i in 2:
		assert_true(c.stools[i].visible)
		assert_almost_eq(c.men[i].spot.distance_to(Ceremony.stool_spot(i)), 0.0, 0.02, "at his stool")
		var hips: Vector3 = view.figures[i].body.hips_at()
		assert_lt(hips.y, 0.8, "sat down")
		assert_almost_eq(Vector2(hips.x, hips.z).distance_to(Ceremony.stool_spot(i)), 0.0, 0.25, "on it")
	for member in c.team:
		assert_true(member.visible)
	_frames(view, 20)
	view.play_moment(Ceremony.OUT)
	_play_out(view)
	assert_false(c.active())
	for i in 2:
		assert_false(c.stools[i].visible, "the stools go")
		assert_almost_eq(c.men[i].spot.distance_to(FightSim.START_POSITIONS[i]), 0.0, 0.02, "out to his mark")
		assert_gt(view.figures[i].body.hips_at().y, 0.8, "on his feet")
	for member in c.team:
		assert_false(member.visible, "the corner team are out of the cage")


func test_the_cutman_closes_a_cut_once_he_has_had_a_moment_on_the_stool_and_only_once_a_break() -> void:
	var view: ArenaView = _watched()[1]
	view.driver.held = true  # As between rounds: the trickle doesn't run on.
	view.marks[0].cut[0] = true
	view.marks[0].bleed[0] = 0.8
	view._cuts_open = true  # The bell (ROUND_ENDED) went with the fight to go on.
	view.play_moment(Ceremony.CORNERS)
	_frames(view, 10)
	assert_almost_eq(view.marks[0].bleed[0], 0.8, 0.0001, "still bleeding on the way to the stool")
	_play_out(view)
	_frames(view, roundi(Ceremony.CUTMAN_SECONDS * 20.0) + 2)
	assert_almost_eq(view.marks[0].bleed[0], 0.8 * BodyMarks.BLEED_AFTER_CORNER, 0.0001, "closed by the cutman")
	view.play_moment(Ceremony.OUT)
	_play_out(view)
	_frames(view, 5)
	assert_almost_eq(view.marks[0].bleed[0], 0.8 * BodyMarks.BLEED_AFTER_CORNER, 0.0001, "once a break")


func test_without_the_moments_the_cut_is_closed_at_the_bell_as_before() -> void:
	var view: ArenaView = _watched()[1]
	view.driver.held = true
	view.marks[1].cut[1] = true
	view.marks[1].bleed[1] = 0.6
	view._cuts_open = true
	_frames(view, 1)
	assert_almost_eq(view.marks[1].bleed[1], 0.6 * BodyMarks.BLEED_AFTER_CORNER, 0.0001)


func test_after_a_decision_the_referee_raises_the_winners_hand_between_them_at_the_centre() -> void:
	var view: ArenaView = _watched()[1]
	var c: Ceremony = view.ceremony
	watch_signals(c)
	view.play_moment(Ceremony.VERDICT, {"winner": 1, "finished": false})
	assert_eq(c.beat, "to_centre", "straight to the centre after a decision")
	_play_out(view)
	assert_signal_emitted_with_parameters(c, "moment_done", [Ceremony.VERDICT])
	assert_eq(c.beat, "raised")
	assert_true(c.active(), "held there for the result")
	var ref: Vector2 = view.referee.spot
	assert_lt(ref.length(), 0.1, "the referee in the middle")
	assert_almost_eq(c.men[0].spot.distance_to(ref), Ceremony.RAISE_GAP, 0.05)
	assert_almost_eq(c.men[1].spot.distance_to(ref), Ceremony.RAISE_GAP, 0.05)
	var winner_high: float = maxf(_hand_height(view, 1, "l"), _hand_height(view, 1, "r"))
	var loser_high: float = maxf(_hand_height(view, 0, "l"), _hand_height(view, 0, "r"))
	assert_gt(winner_high, 1.75, "the winner's hand up over his head")
	assert_lt(loser_high, 1.5, "the loser's isn't")
	var ref_high: float = maxf(Vector3(view.referee.rig.joints.wrist_l).y, Vector3(view.referee.rig.joints.wrist_r).y)
	assert_gt(ref_high, 1.7, "the referee holding it up")


func test_a_draw_raises_both_hands() -> void:
	var view: ArenaView = _watched()[1]
	view.play_moment(Ceremony.VERDICT, {"winner": -1, "finished": false})
	_play_out(view)
	for i in 2:
		assert_gt(maxf(_hand_height(view, i, "l"), _hand_height(view, i, "r")), 1.75, "fighter %d's hand up" % i)


func test_after_a_finish_the_winner_celebrates_with_his_arms_up_before_the_hand_is_raised() -> void:
	var view: ArenaView = _watched()[1]
	var c: Ceremony = view.ceremony
	view.play_moment(Ceremony.VERDICT, {"winner": 0, "finished": true})
	assert_eq(c.beat, "celebrate")
	_frames(view, roundi(Ceremony.CELEBRATE_SECONDS * 20.0) - 4)
	assert_eq(c.beat, "celebrate")
	assert_gt(_hand_height(view, 0, "l"), 1.75, "both arms up")
	assert_gt(_hand_height(view, 0, "r"), 1.75)
	_play_out(view)
	assert_eq(c.beat, "raised", "then the hand raised")


func test_a_beaten_man_down_at_the_finish_sits_up_and_gets_to_his_feet_first() -> void:
	var view: ArenaView = _watched()[1]
	var c: Ceremony = view.ceremony
	# Down on the canvas: his body drawn lying there.
	var rig: FighterRig = view._clinch_rigs[1]
	rig.set_body({"root": [0, 0.15, 0], "lean": -90}, Transform3D(Basis(), Vector3(1.0, 0.0, 0.0)))
	rig.set_limbs({}, Transform3D(Basis(), Vector3(1.0, 0.0, 0.0)), null)
	view.figures[1].body.follow(rig)
	view.play_moment(Ceremony.VERDICT, {"winner": 0, "finished": true})
	assert_true(bool(c.verdict.low))
	assert_eq(c._beats.slice(0, 3), ["celebrate", "get_up", "to_centre"] as Array[String])
	_frames(view, roundi(Ceremony.CELEBRATE_SECONDS * 20.0) - 4)
	assert_lt(view.figures[1].body.hips_at().y, 0.45, "sat up on the canvas")
	_play_out(view)
	assert_gt(view.figures[1].body.hips_at().y, 0.8, "on his feet for the decision")


func test_a_key_or_click_skips_each_moment_to_its_end() -> void:
	var view: ArenaView = _watched()[1]
	var c: Ceremony = view.ceremony
	watch_signals(c)
	view.play_moment(Ceremony.INTRO)
	_frames(view, 5)
	view.skip_moment()
	assert_false(c.active(), "the intro's over")
	for i in 2:
		assert_almost_eq(c.men[i].spot.distance_to(FightSim.START_POSITIONS[i]), 0.0, 0.001, "on his mark")
	view.play_moment(Ceremony.CORNERS)
	_frames(view, 3)
	view.skip_moment()
	assert_eq(c.beat, "seated", "sat down at once")
	assert_false(view.moment_playing(), "held, not playing")
	view.play_moment(Ceremony.OUT)
	view.skip_moment()
	assert_false(c.active())
	view.play_moment(Ceremony.VERDICT, {"winner": 0, "finished": true})
	_frames(view, 3)
	view.skip_moment()
	assert_eq(c.beat, "raised", "straight to the hand raised")
	assert_signal_emit_count(c, "moment_done", 4, "each said it was done")
	_frames(view, 10)
	assert_gt(maxf(_hand_height(view, 0, "l"), _hand_height(view, 0, "r")), 1.75, "and it's up")


func test_playing_them_through_a_whole_fight_doesnt_change_it() -> void:
	var plain := FightSim.new(35001, _roster.make_pair("dirty_boxer", "muay_thai"), _actions)
	var ends: Array[Dictionary] = [{}, {}]
	plain.event_emitted.connect(func(event: FightEvent) -> void:
		if event.type == FightEvent.FIGHT_ENDED:
			ends[0] = event.data)
	while not plain.is_over():
		plain.tick()
	var made: Array = _watched("dirty_boxer", "muay_thai", 35001)
	var sim: FightSim = made[0]
	var view: ArenaView = made[1]
	var driver: FightDriver = view.driver
	sim.event_emitted.connect(func(event: FightEvent) -> void:
		if event.type == FightEvent.FIGHT_ENDED:
			ends[1] = event.data)
	driver.round_over.connect(func(_event: FightEvent) -> void: view.play_moment(Ceremony.CORNERS))
	view.play_moment(Ceremony.INTRO)
	_play_out(view, 20.0, 0.1)
	var frames: int = 0
	while not sim.is_over() and frames < 20000:
		frames += 1
		driver.advance(0.25)
		view._process(0.1)
		if driver.held:
			_play_out(view, 20.0, 0.1)
			view.play_moment(Ceremony.OUT)
			_play_out(view, 20.0, 0.1)
			driver.resume()
	assert_true(sim.is_over())
	view.play_moment(Ceremony.VERDICT, {"winner": int(ends[1].get("winner", -1)), "finished": false})
	_play_out(view, 30.0, 0.1)
	assert_eq(sim.now, plain.now, "the same length")
	assert_eq(ends[1], ends[0], "the same result")


func test_the_setup_has_the_walk_out_and_corners_option_on_by_default() -> void:
	var setup := FightSetup.new()
	add_child_autofree(setup)
	assert_true(bool(setup.settings().get("moments", false)), "on")
	setup._moments.button_pressed = false
	assert_false(bool(setup.settings().moments), "and can be turned off")
	setup.show_settings({"moments": true})
	assert_true(bool(setup.settings().moments))


func test_the_round_panel_sits_down_the_side_while_the_corners_show() -> void:
	var hud := FightHud.new()
	add_child_autofree(hud)
	hud.show_dialog("End of round 1", "", [], null, true)
	assert_true(hud.dialog_on_side())
	hud.show_dialog("Paused", "", [])
	assert_false(hud.dialog_on_side(), "the other dialogs stay in the middle")

func test_corner_staff_clear_the_fighters_legs_and_still_reach_them() -> void:
	var view: ArenaView = _watched()[1]
	var c := view.ceremony
	view.driver.held = true
	view.play_moment(Ceremony.CORNERS)
	var least: float = INF
	var seated_frames: int = 0
	for frame in 600:
		view._process(1.0 / 30.0)
		if not c.active():
			break
		for i in 2:
			var legs := _legs(c.men[i].body)
			for n in 2:
				for staff_leg in _legs(c.team[2 * i + n].body):
					for leg in legs:
						var near := Geometry3D.get_closest_points_between_segments(staff_leg[0], staff_leg[1], leg[0], leg[1])
						least = minf(least, near[0].distance_to(near[1]))
		if c.beat == "seated":
			seated_frames += 1
			if seated_frames == 30:
				for i in 2:
					var knee_gap: float = INF
					for hand: String in ["RightHand", "LeftHand"]:
						for knee: String in ["LeftLeg", "RightLeg"]:
							knee_gap = minf(knee_gap, c.team[2 * i].body._world_at(hand).distance_to(c.men[i].body._world_at(knee)))
					assert_between(knee_gap, 0.05, 0.15, "coach reaches the knee surface")
					assert_lt(c.team[2 * i + 1].body._world_at("LeftHand").distance_to(c.men[i].body._world_at("Neck")), 0.17, "cutman reaches the nape")
				view.play_moment(Ceremony.OUT)
	assert_eq(seated_frames, 30, "checked the entire sit and rise")
	assert_gt(least, 0.15, "corner staff walk and crouch outside the fighters' legs")


func _legs(body: SkinnedBody) -> Array[PackedVector3Array]:
	var segments: Array[PackedVector3Array] = []
	for side: String in ["Left", "Right"]:
		var knee := body._world_at(side + "Leg")
		segments.append(PackedVector3Array([body._world_at(side + "UpLeg"), knee]))
		segments.append(PackedVector3Array([knee, body._world_at(side + "Foot")]))
	return segments
