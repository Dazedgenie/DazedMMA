extends GutTest
## Limbs that stay put (D395; docs/13 "Limbs that stay put"): the skinned body following the pieces sinks its hips
## until both feet on the canvas reach, and a nearly straight leg's knee bends forward instead of swinging about.

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


## A figure with the body, in guard, and the pose its pieces hand the body.
func _figure() -> FighterFigure:
	var sim := FightSim.new(3, _roster.make_pair("boxer", "kicker"), _actions)
	var figure := FighterFigure.new(Color.RED, false, 0)
	add_child_autofree(figure)
	assert_true(figure.use_body(ArenaView.BODY), "the body loads")
	for frame in 3:
		figure.show_state(sim, 0, Vector2.ZERO, Vector2(1.4, 0), 1.0)
	return figure


func _foot(body: SkinnedBody, side: String) -> Vector3:
	return body._world_at("LeftFoot" if side == "l" else "RightFoot")


func test_lifted_hips_sink_until_both_feet_on_the_canvas_reach() -> void:
	var figure: FighterFigure = _figure()
	var pose: Dictionary = figure.body_pose()
	for key: String in ["pelvis_at", "shoulders_at", "shoulder_l", "shoulder_r"]:
		pose[key] = Vector3(pose[key]) + Vector3.UP * 0.12  # His trunk lifted off his feet.
	figure.body.follow_joints(pose)
	for side: String in ["l", "r"]:
		assert_lt(_foot(figure.body, side).distance_to(figure.body._foot_target(pose, side)), 0.02,
			"the %s foot still reaches the canvas" % side)


func test_feet_off_the_canvas_dont_pull_him_down() -> void:
	var figure: FighterFigure = _figure()
	var pose: Dictionary = figure.body_pose()
	for side: String in ["l", "r"]:
		pose["ankle_" + side] = Vector3(pose["ankle_" + side]) + Vector3.UP * 0.6  # Kicks, not feet on the canvas.
	figure.body.follow_joints(pose)
	assert_eq(figure.body._sink_to_feet(pose), 0.0, "nothing to sink for")


func test_a_nearly_straight_legs_knee_bends_forward_not_sideways() -> void:
	var figure: FighterFigure = _figure()
	var pose: Dictionary = figure.body_pose()
	var forward: Vector3 = Basis(pose.pelvis) * Vector3.FORWARD
	for side: String in ["l", "r"]:
		# The pieces' knee a hair off the line from hip to ankle, out to the side: it hardly says which way it bends.
		var hip: Vector3 = pose["hip_" + side]
		var ankle: Vector3 = pose["ankle_" + side]
		var out: Vector3 = Basis(pose.pelvis) * (Vector3.LEFT if side == "l" else Vector3.RIGHT)
		pose["knee_" + side] = hip.lerp(ankle, 0.5) + out * 0.01
	for key: String in ["pelvis_at", "shoulders_at", "shoulder_l", "shoulder_r"]:
		pose[key] = Vector3(pose[key]) + Vector3.UP * 0.08  # So the body's legs have to bend.
	figure.body.follow_joints(pose)
	for side: String in ["l", "r"]:
		var body: SkinnedBody = figure.body
		var hip: Vector3 = body._world_at("LeftUpLeg" if side == "l" else "RightUpLeg")
		var knee: Vector3 = body._world_at("LeftLeg" if side == "l" else "RightLeg")
		var bend: Vector3 = knee - hip.lerp(_foot(body, side), 0.5)
		assert_gt(bend.normalized().dot(forward), 0.5, "the %s knee bends forward" % side)
