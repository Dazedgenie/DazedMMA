extends GutTest
## The submissions from the rig (D366): each hold a loose and a tight pose blended by the danger meter, and the
## man in it tapping, on rigs fitted to the Tripo body. Presentation only.

var _sizes: Dictionary
var _rigs: Array[FighterRig] = []


func before_all() -> void:
	var body := SkinnedBody.new()
	add_child(body)
	body.load_body(SkinnedBody.TRIPO_BODY, 1.52)
	_sizes = body.measure()
	body.free()


func before_each() -> void:
	_rigs = []
	for colour: Color in [Color.RED, Color.BLUE]:
		var rig := FighterRig.new(colour)
		add_child_autofree(rig)
		rig.fit(_sizes)
		_rigs.append(rig)


## Every hold loose and tight by name, with the attacker "a".
func _poses() -> Dictionary:
	var out := {}
	var examples: Dictionary = SubmissionPair.examples()
	for key: String in examples:
		var e: Array = examples[key]
		var built: Dictionary = SubmissionPair.build(e[0], e[1], e[2], e[3])
		out[key] = built.loose if float(e[4]) < 50.0 else built.tight
	return out


func _misses(pair: Dictionary, label: String) -> void:
	for i in 2:
		var spec: Dictionary = pair["a" if i == 0 else "b"]
		for limb: String in ["hand_l", "hand_r", "foot_l", "foot_r"]:
			if not spec.has(limb):
				continue
			var want: Vector3 = _rigs[i].target_for(spec[limb], limb, Transform3D.IDENTITY, _rigs[1 - i])
			var got: Vector3 = _rigs[i].joints[("wrist_" if limb.begins_with("hand") else "ankle_") + limb.right(1)]
			assert_lt(want.distance_to(got), 0.06, "%s: %s %s" % [label, "a" if i == 0 else "b", limb])


func test_every_hold_has_a_loose_and_a_tight_pose_and_a_tap() -> void:
	for action: String in SubmissionPair.HOLDS:
		var built: Dictionary = SubmissionPair.build(action, "full_guard")
		assert_false(built.is_empty(), action)
		assert_ne(str(built.loose), str(built.tight), "%s tightens" % action)
		assert_true(SubmissionPair.TAPS.has(built.tap), "%s: a hand to tap with" % action)
		assert_true(SubmissionPair.FRAMES.has(built.frame), action)
	assert_true(SubmissionPair.build("double_leg").is_empty(), "only the holds")


func test_every_hand_and_foot_gets_to_its_place() -> void:
	var poses: Dictionary = _poses()
	for key: String in poses:
		FighterRig.pose_pair(_rigs[0], _rigs[1], poses[key], Transform3D.IDENTITY)
		_misses(poses[key], key)


func test_no_one_ends_up_under_the_canvas() -> void:
	var poses: Dictionary = _poses()
	for key: String in poses:
		FighterRig.pose_pair(_rigs[0], _rigs[1], poses[key], Transform3D.IDENTITY)
		for i in 2:
			for spot: String in ["back", "lower_back", "back_of_head", "chest", "belly", "head"]:
				assert_gt(_rigs[i].point(spot).y, -0.03, "%s: %s's %s" % [key, "a" if i == 0 else "b", spot])


func test_the_danger_meter_takes_it_from_loose_to_tight() -> void:
	var built: Dictionary = SubmissionPair.build("triangle", "full_guard")
	assert_eq(SubmissionPair.at_danger(built, 0.0)[2], 0.0, "nearly out: loose")
	assert_eq(SubmissionPair.at_danger(built, 100.0)[2], 1.0, "about to tap: tight")
	var half: float = SubmissionPair.at_danger(built, 50.0)[2]
	assert_almost_eq(half, 0.5, 0.01)
	assert_gt(SubmissionPair.at_danger(built, 70.0)[2], half, "tighter as it fills")


func test_tight_is_tighter_than_loose() -> void:
	# The choke: his chin pulled further up; the triangle: his head pulled down further; the armbar: the arm straighter.
	var choke: Dictionary = SubmissionPair.build("rear_naked_choke", "back_control", true)
	FighterRig.pose_pair(_rigs[0], _rigs[1], choke.loose, Transform3D.IDENTITY)
	var loose_lean: float = _rigs[0].point("head").z
	FighterRig.pose_pair(_rigs[0], _rigs[1], choke.tight, Transform3D.IDENTITY)
	assert_lt(_rigs[0].point("head").z, loose_lean, "the rear-naked choke: he leans back and pulls")
	var triangle: Dictionary = SubmissionPair.build("triangle", "full_guard")
	FighterRig.pose_pair(_rigs[0], _rigs[1], triangle.loose, Transform3D.IDENTITY)
	var loose_head: float = _rigs[1].point("head").y
	FighterRig.pose_pair(_rigs[0], _rigs[1], triangle.tight, Transform3D.IDENTITY)
	assert_lt(_rigs[1].point("head").y, loose_head, "the triangle: his head pulled down")
	var armbar: Dictionary = SubmissionPair.build("armbar", "full_guard")
	FighterRig.pose_pair(_rigs[0], _rigs[1], armbar.loose, Transform3D.IDENTITY)
	var bent: float = _arm_reach(_rigs[1], "r")
	FighterRig.pose_pair(_rigs[0], _rigs[1], armbar.tight, Transform3D.IDENTITY)
	assert_gt(_arm_reach(_rigs[1], "r"), bent, "the armbar: his arm straighter")


func _arm_reach(rig: FighterRig, side: String) -> float:
	return Vector3(rig.joints["shoulder_" + side]).distance_to(rig.joints["wrist_" + side])


func test_the_man_in_it_taps_with_his_free_hand() -> void:
	for action: String in SubmissionPair.HOLDS:
		var built: Dictionary = SubmissionPair.build(action, "full_guard")
		var tap: Dictionary = SubmissionPair.TAPS[built.tap]
		var down: Dictionary = SubmissionPair.tapping(built, 0.0)
		var up: Dictionary = SubmissionPair.tapping(built, 0.5 / SubmissionPair.TAP_HZ)
		FighterRig.pose_pair(_rigs[0], _rigs[1], down, Transform3D.IDENTITY)
		var low: Vector3 = _rigs[1].joints["wrist_" + String(tap.hand).right(1)]
		FighterRig.pose_pair(_rigs[0], _rigs[1], up, Transform3D.IDENTITY)
		var high: Vector3 = _rigs[1].joints["wrist_" + String(tap.hand).right(1)]
		assert_almost_eq(high.distance_to(low), SubmissionPair.TAP_LIFT, 0.03, "%s: his hand comes up and down" % action)
		assert_eq(str(down.a), str(built.tight.a), "%s: the hold stays on" % action)


func test_a_standing_guillotine_is_standing_and_pulled_into_the_guard_he_is_underneath() -> void:
	var standing: Dictionary = SubmissionPair.build("guillotine", "standing")
	FighterRig.pose_pair(_rigs[0], _rigs[1], standing.tight, Transform3D.IDENTITY)
	assert_gt(_rigs[0].point("head").y, 1.3, "on his feet")
	assert_lt(_rigs[1].point("head").y, _rigs[0].point("chest").y, "his head down under the arm")
	var pulled: Dictionary = SubmissionPair.build("guillotine", "standing", false, true)
	FighterRig.pose_pair(_rigs[0], _rigs[1], pulled.tight, Transform3D.IDENTITY)
	assert_lt(_rigs[0].point("chest").y, 0.5, "on his back")
	assert_gt(_rigs[1].point("back").y, _rigs[0].point("chest").y, "the other man over him")


func test_the_far_side_puts_him_on_the_other_side_in_a_side_hold() -> void:
	var near: Dictionary = SubmissionPair.build("arm_triangle", "side_control", true)
	var far: Dictionary = SubmissionPair.build("arm_triangle", "side_control", true, false, 1.0)
	assert_lt(float(near.tight.a.root[0]), 0.0)
	assert_gt(float(far.tight.a.root[0]), 0.0, "mirrored")
	var guard: Dictionary = SubmissionPair.build("triangle", "full_guard", false, false, 1.0)
	assert_false(guard.has("mirrored"), "a hold from the guard isn't to one side")
	FighterRig.pose_pair(_rigs[0], _rigs[1], SubmissionPair.tapping(far, 0.0), Transform3D.IDENTITY)
	_misses(SubmissionPair.tapping(far, 0.0), "the arm-triangle tapping, mirrored")
