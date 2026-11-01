extends GutTest
## The fight screen's clinch from the rig (D286): with the Tripo bodies, a clinch where both men hold or fight
## for grips is posed from the grips on two hidden rigs; strikes from it move only the striking limb; other moves
## go back to today's figures, easing between. Presentation only.

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


## A watched clinch with `grips`, both men idle.
func _clinch(grips: Array[int]) -> Array:
	var sim := FightSim.new(3, _roster.make_pair("wrestler", "kicker"), _actions)
	sim.apply_transition(0, "clinch_entry")
	for f: FighterState in sim.fighters:
		f.clear_action()
	sim.set_grips(grips)
	var view := ArenaView.new()
	add_child_autofree(view)
	view.watch(FightDriver.new(sim))
	_settle(view)
	return [sim, view]


## Runs the view long enough for any easing to finish.
func _settle(view: ArenaView) -> void:
	for n in 3:
		view._process(1.0)


func _bone(figure: FighterFigure, bone: String) -> Vector3:
	var skeleton: Skeleton3D = figure.body.skeleton
	return (skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(SkinnedBody.PREFIX + bone))).origin


func test_a_body_lock_in_the_fight_is_drawn_from_the_rig_with_the_hands_round_his_back() -> void:
	var setup: Array = _clinch([0, 0])
	var view: ArenaView = setup[1]
	assert_true(view.rig_clinch(setup[0]), "the clinch is posed from the rig")
	var red: FighterFigure = view.figures[0]
	var blue: FighterFigure = view.figures[1]
	var behind: Vector3 = blue.global_position - red.global_position
	behind.y = 0.0
	for side: String in ["Left", "Right"]:
		var hand: Vector3 = _bone(red, side + "Hand")
		assert_lt(hand.distance_to(view._clinch_rigs[0].joints["wrist_" + side.left(1).to_lower()]), 0.03, "%s hand on the rig's" % side)
		assert_gt((hand - _bone(blue, "Hips")).dot(behind.normalized()), 0.0, "%s hand behind blue's back" % side)


func test_each_grip_changes_the_pose() -> void:
	var lock: ArenaView = _clinch([0, 0])[1]
	var under: ArenaView = _clinch([0, 1])[1]
	var collar_setup: Array = _clinch([FightSim.NO_GRIP, FightSim.NO_GRIP])
	var sim: FightSim = collar_setup[0]
	sim.fighters[1].tied_up_ticks = 30  # Red holds the collar tie.
	var collar: ArenaView = collar_setup[1]
	_settle(collar)
	var hands: Array[Vector3] = []
	for view in [lock, under, collar]:
		hands.append(_bone(view.figures[0], "LeftHand") - view.figures[0].global_position)
	assert_gt(hands[0].distance_to(hands[1]), 0.05, "an overhook is not a body lock")
	assert_gt(hands[2].y, hands[0].y + 0.1, "a collar tie is up behind his head")
	assert_lt(_bone(collar.figures[1], "Head").y, _bone(collar.figures[0], "Head").y - 0.1, "his head is pulled down")


func test_a_knee_from_the_clinch_keeps_the_hold_and_lifts_only_the_knee() -> void:
	var setup: Array = _clinch([0, 0])
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	var red: FighterFigure = view.figures[0]
	var hips: Vector3 = _bone(red, "Hips")
	var hands: Vector3 = _bone(red, "LeftHand")
	var f: FighterState = sim.fighters[0]
	f.action_id = "knee"
	f.phase = "active"
	f.phase_ticks_left = 1
	_settle(view)
	assert_true(view.rig_clinch(sim), "still posed from the rig")
	assert_lt(_bone(red, "Hips").distance_to(hips), 0.01, "the hips hold")
	assert_lt(_bone(red, "LeftHand").distance_to(hands), 0.01, "the grip holds")
	var knee: String = ("Left" if red.arm_letter(1) == "l" else "Right") + "Leg"
	assert_gt(_bone(red, knee).y, 0.6, "the rear knee comes up")


func test_a_takedown_from_the_clinch_goes_back_to_todays_figures_easing_out() -> void:
	var setup: Array = _clinch([0, 0])
	var sim: FightSim = setup[0]
	var view: ArenaView = setup[1]
	var red: FighterFigure = view.figures[0]
	var held: Vector3 = _bone(red, "LeftHand")
	var f: FighterState = sim.fighters[0]
	f.action_id = "double_leg"
	f.phase = "windup"
	f.phase_ticks_left = 5
	assert_false(view.rig_clinch(sim), "a double leg is drawn from today's figures")
	view._process(ArenaView.CLINCH_EASE * 0.25)
	var part_way: Vector3 = _bone(red, "LeftHand")
	_settle(view)
	var after: Vector3 = _bone(red, "LeftHand")
	assert_gt(after.distance_to(held), 0.05, "the hand goes to today's figure")
	assert_gt(part_way.distance_to(held), 0.005, "it starts moving at once")
	assert_lt(part_way.distance_to(held), after.distance_to(held) - 0.02, "but eases rather than jumping")


func test_standing_and_on_the_ground_the_rig_does_not_pose_them() -> void:
	var sim := FightSim.new(3, _roster.make_pair("wrestler", "kicker"), _actions)
	var view := ArenaView.new()
	add_child_autofree(view)
	view.watch(FightDriver.new(sim))
	assert_false(view.rig_clinch(sim), "standing apart")
	sim.apply_transition(0, "double_leg")
	assert_false(view.rig_clinch(sim), "on the ground")
