extends GutTest
## Scrambles, getting up and standing up (D368, ScramblePair) and the shots from range and following him down
## (D369, ShotPair) as paired poses, on rigs fitted to the Tripo body. Presentation only.

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


## Every pose the moves go through, by name.
func _poses() -> Dictionary:
	var out: Dictionary = ScramblePair.examples()
	for key: String in ShotPair.examples():
		out["shot " + key] = ShotPair.examples()[key]
	for move: String in ShotPair.MOVES:
		out["shot %s landing" % move] = ShotPair.landing(move)
	return out


## How deep `rig`'s torso and head go into the other man's core (a 9 cm rod from his hips to his neck).
func _depth_into(rig: FighterRig, other: FighterRig) -> float:
	var from: Vector3 = other.bones.pelvis.global_position
	var to: Vector3 = other.point("neck")
	var deepest: float = -INF
	for key: String in ["pelvis", "waist", "neck", "head"]:
		var bone: Node3D = rig.bones[key]
		for child: Node in bone.find_children("*", "MeshInstance3D", false, false):
			var mesh: MeshInstance3D = child
			for v: Vector3 in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				var p: Vector3 = mesh.to_global(v)
				deepest = maxf(deepest, 0.09 - p.distance_to(Geometry3D.get_closest_point_to_segment(p, from, to)))
	return deepest


func test_every_move_has_its_keys() -> void:
	for move: String in ScramblePair.MOVES:
		assert_gt(ScramblePair.keys(move).size(), 0, move)
		assert_true(ScramblePair.TIMING.has(move), move)
	for move: String in ShotPair.MOVES:
		assert_gt(ShotPair.keys(move, 1.2).size(), 0, move)
		assert_true(ShotPair.TIMING.has(move), move)
	assert_eq(ShotPair.keys("double_leg", 1.2).size(), int(ShotPair.TIMING.double_leg.entry) + 1,
		"from range: the level change and the step in, then the drive")


func test_every_hand_and_foot_gets_to_its_place() -> void:
	var poses: Dictionary = _poses()
	for key: String in poses:
		var pair: Dictionary = poses[key]
		FighterRig.pose_pair(_rigs[0], _rigs[1], pair, Transform3D.IDENTITY)
		for i in 2:
			var spec: Dictionary = pair["a" if i == 0 else "b"]
			for limb: String in ["hand_l", "hand_r", "foot_l", "foot_r"]:
				if not spec.has(limb):
					continue
				var want: Vector3 = _rigs[i].target_for(spec[limb], limb, Transform3D.IDENTITY, _rigs[1 - i])
				var got: Vector3 = _rigs[i].joints[("wrist_" if limb.begins_with("hand") else "ankle_") + limb.right(1)]
				assert_lt(want.distance_to(got), 0.05, "%s: %s %s" % [key, "a" if i == 0 else "b", limb])


func test_the_bodies_meet_but_do_not_pass_through_each_other() -> void:
	var poses: Dictionary = _poses()
	for key: String in poses:
		FighterRig.pose_pair(_rigs[0], _rigs[1], poses[key], Transform3D.IDENTITY)
		var deepest: float = maxf(_depth_into(_rigs[0], _rigs[1]), _depth_into(_rigs[1], _rigs[0]))
		assert_lt(deepest, 0.04, "%s: one inside the other" % key)


func test_no_one_ends_up_under_the_canvas() -> void:
	var poses: Dictionary = _poses()
	for key: String in poses:
		FighterRig.pose_pair(_rigs[0], _rigs[1], poses[key], Transform3D.IDENTITY)
		for i in 2:
			for spot: String in ["back", "lower_back", "back_of_head", "chest", "belly", "head", "seat"]:
				assert_gt(_rigs[i].point(spot).y, -0.02, "%s: %s's %s" % [key, "a" if i == 0 else "b", spot])


func test_walking_up_the_fence_he_leans_on_it_but_not_through_it() -> void:
	for key: Dictionary in ScramblePair.keys("get_up_fence").slice(0, 3):
		FighterRig.pose_pair(_rigs[0], _rigs[1], key, Transform3D.IDENTITY)
		var back: Vector3 = _rigs[1].point("back")
		assert_lt(back.z, -ScramblePair.FENCE_BACK + 0.15, "his back on the fence")
		for spot: String in ["back", "lower_back", "back_of_head", "seat"]:
			assert_gt(_rigs[1].point(spot).z, -ScramblePair.FENCE_BACK - 0.02, "%s not through it" % spot)


func test_each_way_up_ends_with_both_on_their_feet_and_standing_up_leaves_him_down() -> void:
	for move: String in ["scramble_up", "get_up", "get_up_fence"]:
		var keys: Array[Dictionary] = ScramblePair.keys(move)
		FighterRig.pose_pair(_rigs[0], _rigs[1], keys[keys.size() - 1], Transform3D.IDENTITY)
		for i in 2:
			assert_gt(_rigs[i].point("head").y, 1.4, "%s: %s up" % [move, "a" if i == 0 else "b"])
	var stood: Array[Dictionary] = ScramblePair.keys("stand_up")
	FighterRig.pose_pair(_rigs[0], _rigs[1], stood[stood.size() - 1], Transform3D.IDENTITY)
	assert_gt(_rigs[0].point("head").y, 1.4, "the top man up")
	assert_lt(_rigs[1].point("head").y, 0.4, "the man underneath left down")


func test_the_shot_from_range_drops_his_level_before_he_gets_there() -> void:
	var gap: float = 1.4
	FighterRig.pose_pair(_rigs[0], _rigs[1], ShotPair.start("double_leg", gap), Transform3D.IDENTITY)
	var standing: float = _rigs[0].bones.pelvis.global_position.y
	FighterRig.pose_pair(_rigs[0], _rigs[1], ShotPair.level_change(gap), Transform3D.IDENTITY)
	assert_lt(_rigs[0].bones.pelvis.global_position.y, standing - ShotPair.LEVEL_DROP + 0.05, "level changed")
	var apart: float = _rigs[0].bones.pelvis.global_position.distance_to(_rigs[1].bones.pelvis.global_position)
	assert_gt(apart, 0.75, "still out at range")
