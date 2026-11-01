extends GutTest
## Stances by style (D362): standing, each man's stance comes from his leanings and what he throws, so the
## Boxer, the Kicker and a wrestler stand differently, and nobody carries a stance off his feet.
## Presentation only.

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


func _standing(red: String, blue: String) -> Array:
	var sim := FightSim.new(3, _roster.make_pair(red, blue), _actions)
	var figure := FighterFigure.new(Color.RED)
	add_child_autofree(figure)
	return [figure.pose_for(sim, 0), figure.pose_for(sim, 1), sim]


func test_the_boxer_stands_bladed_and_the_kicker_square_and_upright() -> void:
	var poses: Array = _standing("boxer", "kicker")
	var boxer: Dictionary = poses[0]
	var kicker: Dictionary = poses[1]
	assert_gt(float(boxer.twist), float(kicker.twist) + 0.2, "bladed against square")
	assert_gt(float(kicker.hip_y), float(boxer.hip_y) + 0.02, "the Kicker taller, the Boxer's knees bent")
	assert_gt(float(kicker.lean), float(boxer.lean), "the Kicker's weight further back")


func test_a_wrestler_stands_low_and_leaning_in_with_his_hands_lower() -> void:
	var poses: Array = _standing("wrestler", "boxer")
	var wrestler: Dictionary = poses[0]
	var boxer: Dictionary = poses[1]
	assert_lt(float(wrestler.hip_y), float(boxer.hip_y) - 0.03, "lower")
	assert_lt(float(wrestler.lean), float(boxer.lean) - 0.1, "leaning in")
	assert_lt(float(wrestler.arm_lead), float(boxer.arm_lead) - 0.2, "hands lower and out")
	var wide: Dictionary = FighterFigure.stance_for((poses[2] as FightSim).fighters[0])
	assert_gt(float(wide.width), 0.02, "a wider base")


func test_every_fighter_s_stance_stays_in_bounds() -> void:
	for id: String in _roster.ids():
		var sim := FightSim.new(3, _roster.make_pair(id, id), _actions)
		var stance: Dictionary = FighterFigure.stance_for(sim.fighters[0])
		assert_between(float(stance.get("hip_y", 0.0)), -0.12, 0.05, id)
		assert_between(float(stance.get("lean", 0.0)), -0.4, 0.15, id)
		assert_between(float(stance.width), -0.05, 0.1, id)
		assert_between(float(stance.length), -0.05, 0.1, id)


func test_off_his_feet_nobody_carries_a_stance() -> void:
	var sim := FightSim.new(3, _roster.make_pair("wrestler", "boxer"), _actions)
	var figure := FighterFigure.new(Color.RED)
	add_child_autofree(figure)
	var roles: Array[String] = [PositionLibrary.NEUTRAL, PositionLibrary.NEUTRAL]
	sim.situation.set_to(sim.positions.get_position("clinch"), roles)
	var wrestler: Dictionary = figure.pose_for(sim, 0)
	var boxer: Dictionary = figure.pose_for(sim, 1)
	assert_almost_eq(float(wrestler.hip_y), float(boxer.hip_y), 0.001, "the same in the clinch")
