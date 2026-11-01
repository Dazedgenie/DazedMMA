extends GutTest
## Clinch takedowns from the rig (D288): the double leg, outside trip, hip throw and guard pull as paired poses
## from the clinch to the canvas, on rigs fitted to the Tripo body. Presentation only.

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


## Every pose a takedown goes through, by name: [pair, frame].
func _keys() -> Dictionary:
	var out := {}
	var examples: Dictionary = TakedownPair.examples()
	for key: String in examples:
		out[key] = [examples[key], Transform3D.IDENTITY]
	for action: String in TakedownPair.MOVES:
		for far: float in [-1.0, 1.0]:
			out["%s landing %d" % [action, far]] = [TakedownPair.landing(action, far), Transform3D.IDENTITY]
	out["scramble"] = [TakedownPair.scramble(), Transform3D.IDENTITY]
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


func test_every_hand_and_foot_gets_to_its_place() -> void:
	var keys: Dictionary = _keys()
	for key_name: String in keys:
		var pair: Dictionary = keys[key_name][0]
		var frame: Transform3D = keys[key_name][1]
		FighterRig.pose_pair(_rigs[0], _rigs[1], pair, frame)
		for i in 2:
			var spec: Dictionary = pair["a" if i == 0 else "b"]
			for limb: String in ["hand_l", "hand_r", "foot_l", "foot_r"]:
				if not spec.has(limb):
					continue
				var want: Vector3 = _rigs[i].target_for(spec[limb], limb, frame, _rigs[1 - i])
				var got: Vector3 = _rigs[i].joints[("wrist_" if limb.begins_with("hand") else "ankle_") + limb.right(1)]
				assert_lt(want.distance_to(got), 0.05, "%s: %s %s" % [key_name, "a" if i == 0 else "b", limb])


func test_the_bodies_meet_but_do_not_pass_through_each_other() -> void:
	var keys: Dictionary = _keys()
	for key_name: String in keys:
		FighterRig.pose_pair(_rigs[0], _rigs[1], keys[key_name][0], keys[key_name][1])
		var deepest: float = maxf(_depth_into(_rigs[0], _rigs[1]), _depth_into(_rigs[1], _rigs[0]))
		assert_lt(deepest, 0.04, "%s: one inside the other" % key_name)


func test_no_one_ends_up_under_the_canvas() -> void:
	var keys: Dictionary = _keys()
	for key_name: String in keys:
		FighterRig.pose_pair(_rigs[0], _rigs[1], keys[key_name][0], keys[key_name][1])
		for i in 2:
			for spot: String in ["back", "lower_back", "back_of_head", "chest", "belly", "head"]:
				assert_gt(_rigs[i].point(spot).y, -0.02, "%s: %s's %s" % [key_name, "a" if i == 0 else "b", spot])
