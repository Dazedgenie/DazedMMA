class_name SkinnedBody
extends Node3D
## A skinned, auto-rigged body (D284) driven by a FighterRig: one continuous mesh that bends at the joints, posed
## from the rig's paired poses instead of the faceted pieces. The body is a glTF file with a Mixamo-named
## humanoid skeleton (Tripo's Mixamo preset). It is scaled so its hips stand at the rig's pelvis height and
## turned to face -Z like the rig.
##
## The trunk, neck, head and feet copy the rig's turns; the arms and legs are solved again in the body's own bone
## lengths (FighterMotion.solve_bones) toward the rig's wrists and ankles, bent toward the rig's elbows and knees,
## so a hand on the other man stays on him even though the body's limbs are shorter than the rig's.
## Presentation only.

## The first body (Kyle's, made in Tripo with its Mixamo skeleton preset, 2026-10-31): kept with the tools, out of
## the exported game, until a body goes into the fight screen.
const TRIPO_BODY := "res://tools/bodies/tripo_fighter.glb"
## Mixamo bone names (Godot turns "mixamorig:" into "mixamorig_") for the rig's joints.
const PREFIX := "mixamorig_"
## [body bone, rig bone, share]: the trunk copies the rig's pelvis and chest; the lower spine is part way between.
const TRUNK := [
	["Hips", "pelvis", 0.0], ["Spine", "waist", 0.35], ["Spine1", "waist", 0.7], ["Spine2", "waist", 1.0],
	["Neck", "neck", 1.0], ["Head", "head", 1.0],
]
## [upper bone, lower bone, end bone, rig side, rig limb]: the limbs solved again in the body's own lengths.
const LIMBS := [
	["LeftArm", "LeftForeArm", "LeftHand", "l", "arm"], ["RightArm", "RightForeArm", "RightHand", "r", "arm"],
	["LeftUpLeg", "LeftLeg", "LeftFoot", "l", "leg"], ["RightUpLeg", "RightLeg", "RightFoot", "r", "leg"],
]

var skeleton: Skeleton3D
## The body's scale (the file's units to metres) and the bones' rests in the world when the body stands as the
## rig does at rest (facing -Z at the origin).
var body_scale: float = 1.0
var _rest_world := {}
var _ids := {}
## Where the hip joints' middle is at rest (the rig's pelvis point).
var _pelvis_rest := Vector3.ZERO


## Loads the body from a glTF/GLB file (`path`, res:// or a file path). Returns false if it isn't a humanoid.
func load_body(path: String) -> bool:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		push_error("SkinnedBody: could not load %s" % path)
		return false
	var scene: Node3D = doc.generate_scene(state)
	add_child(scene)
	return attach(scene)


## Uses `scene` (already a child of this node) as the body.
func attach(scene: Node3D) -> bool:
	var found: Array[Node] = scene.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		push_error("SkinnedBody: no skeleton in the body")
		return false
	skeleton = found[0]
	for name_in_rig: String in ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", "LeftShoulder", "RightShoulder",
			"LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "RightHand", "LeftUpLeg", "LeftLeg",
			"LeftFoot", "LeftToeBase", "RightUpLeg", "RightLeg", "RightFoot", "RightToeBase"]:
		var id: int = skeleton.find_bone(PREFIX + name_in_rig)
		if id < 0:
			push_error("SkinnedBody: no %s bone" % name_in_rig)
			return false
		_ids[name_in_rig] = id
	# Stand it up like the rig: hip joints at the rig's pelvis height, facing -Z (Mixamo bodies face +Z).
	var hips: float = 0.0
	for leg: String in ["LeftUpLeg", "RightUpLeg"]:
		hips += (skeleton.global_transform * skeleton.get_bone_global_rest(_ids[leg])).origin.y / 2.0
	body_scale = FighterRig.PELVIS_HEIGHT / maxf(hips, 0.01)
	scene.transform = Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * body_scale), Vector3.ZERO) * scene.transform
	var to_world: Transform3D = global_transform.affine_inverse() * skeleton.global_transform
	for key: String in _ids:
		_rest_world[key] = to_world * skeleton.get_bone_global_rest(_ids[key])
	_pelvis_rest = (_at("LeftUpLeg") + _at("RightUpLeg")) / 2.0
	return true


## Colours the body's light-grey shorts in a corner's colour (the rest of the texture stays as it is). The body
## file's shorts are light grey on purpose so one body serves both corners.
func set_colour(colour: Color) -> void:
	for found: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = found
		var base: StandardMaterial3D = mesh.get_active_material(0) as StandardMaterial3D
		if base == null or base.albedo_texture == null:
			continue
		var tinted := ShaderMaterial.new()
		tinted.shader = _tint_shader()
		tinted.set_shader_parameter("albedo", base.albedo_texture)
		tinted.set_shader_parameter("tint", colour)
		mesh.material_override = tinted


static var _shader: Shader


## Light, colourless texels (the shorts) take the tint; skin, gloves, hair and the dark panels don't.
static func _tint_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """
shader_type spatial;
uniform sampler2D albedo : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	vec3 c = texture(albedo, UV).rgb;
	float top = max(c.r, max(c.g, c.b));
	float grey = (1.0 - smoothstep(0.1, 0.22, (top - min(c.r, min(c.g, c.b))) / max(top, 0.001))) * smoothstep(0.3, 0.5, top);
	ALBEDO = mix(c, tint.rgb * (0.35 + 0.75 * top), grey);
	ROUGHNESS = 0.85;
}
"""
	return _shader


## The body's sizes at rest, in metres, for FighterRig.fit: the rig it follows gets its trunk and limbs.
func measure() -> Dictionary:
	var arm: Vector3 = _at("RightArm") - _at("Spine1")
	return {
		"waist_up": _at("Spine1").y - _pelvis_rest.y,
		"neck_up": _at("Neck").y - _at("Spine1").y,
		"head_up": Vector3(0, _at("Head").y - _at("Neck").y, _at("Head").z - _at("Neck").z),
		"shoulder": Vector3(absf(arm.x), arm.y, arm.z),
		"hip_x": absf(_at("RightUpLeg").x - _pelvis_rest.x),
		"upper_arm": _at("RightArm").distance_to(_at("RightForeArm")),
		"forearm": _at("RightForeArm").distance_to(_at("RightHand")),
		"thigh": _at("RightUpLeg").distance_to(_at("RightLeg")),
		"shin": _at("RightLeg").distance_to(_at("RightFoot")),
		"ankle_up": _at("RightFoot").y,
	}


func _at(bone: String) -> Vector3:
	return Transform3D(_rest_world[bone]).origin


## Poses the body as `rig` stands now (call after FighterRig.pose_pair).
func follow(rig: FighterRig) -> void:
	var to_skeleton: Transform3D = skeleton.global_transform.affine_inverse()
	var turn_of := func(key: String) -> Basis:
		var node: Node3D = rig.bones[key]
		return node.global_basis.orthonormalized()
	# The trunk: each bone turned as the rig's bone is turned from standing.
	for entry: Array in TRUNK:
		var bone: String = entry[0]
		var turn: Basis = turn_of.call(entry[1])
		if float(entry[2]) < 1.0:
			turn = Basis(Quaternion(turn_of.call("pelvis")).slerp(Quaternion(turn), float(entry[2])))
		var rest: Transform3D = _rest_world[bone]
		var world := Transform3D(turn * rest.basis, rest.origin)
		if bone == "Hips":
			world.origin = rig.bones.pelvis.global_position + turn * (rest.origin - _pelvis_rest)
		else:
			world.origin = (skeleton.global_transform * skeleton.get_bone_global_pose(_ids[bone])).origin
		_set_world(bone, world, to_skeleton)
		if bone == "Spine2":
			for shoulder: String in ["LeftShoulder", "RightShoulder"]:
				var at: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_pose(_ids[shoulder])).origin
				_set_world(shoulder, Transform3D(turn * Transform3D(_rest_world[shoulder]).basis, at), to_skeleton)
	# The limbs, in the body's own lengths, to the rig's wrists and ankles.
	for limb: Array in LIMBS:
		var side: String = limb[3]
		var arm: bool = limb[4] == "arm"
		var upper: String = limb[0]
		var lower: String = limb[1]
		var end: String = limb[2]
		var root: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_pose(_ids[upper])).origin
		var middle_rig: Vector3 = rig.joints[("elbow_" if arm else "knee_") + side]
		var end_rig: Vector3 = rig.joints[("wrist_" if arm else "ankle_") + side]
		var first: float = Transform3D(_rest_world[upper]).origin.distance_to(Transform3D(_rest_world[lower]).origin)
		var second: float = Transform3D(_rest_world[lower]).origin.distance_to(Transform3D(_rest_world[end]).origin)
		var shoulder_rig: Vector3 = rig.joints[("shoulder_" if arm else "hip_") + side]
		var bend: Vector3 = middle_rig - shoulder_rig.lerp(end_rig, 0.5)
		var chain: Array[Vector3] = FighterMotion.solve_bones(root, end_rig, bend, first, second)
		var middle: Vector3 = chain[0]
		var tip: Vector3 = chain[1]
		_aim_bone(upper, lower, root, middle, bend, arm, to_skeleton)
		_aim_bone(lower, end, middle, tip, bend, arm, to_skeleton)
		var end_turn: Basis
		if arm:  # The hand carries on along the forearm.
			var fore: Basis = (skeleton.global_transform.basis * skeleton.get_bone_global_pose(_ids[lower]).basis).orthonormalized()
			end_turn = fore * Transform3D(_rest_world[lower]).basis.orthonormalized().inverse()
		else:  # The foot copies the rig's foot.
			end_turn = turn_of.call("foot_" + side)
		_set_world(end, Transform3D(end_turn * Transform3D(_rest_world[end]).basis, tip), to_skeleton)


## Turns `bone` (whose child is `child`) so it runs from `from` to `to`, bent toward `bend`.
func _aim_bone(bone: String, child: String, from: Vector3, to: Vector3, bend: Vector3, arm: bool, to_skeleton: Transform3D) -> void:
	var rest: Transform3D = _rest_world[bone]
	var rest_dir: Vector3 = Transform3D(_rest_world[child]).origin - rest.origin
	# At rest an elbow bends back (+Z for a body facing -Z) and a knee forward (-Z).
	var rest_bend := Vector3(0, 0, 1) if arm else Vector3(0, 0, -1)
	var turn: Basis = _frame(to - from, bend) * _frame(rest_dir, rest_bend).inverse()
	_set_world(bone, Transform3D(turn * rest.basis, from), to_skeleton)


## An orthonormal basis whose Y runs along `along` and whose Z leans toward `toward`.
static func _frame(along: Vector3, toward: Vector3) -> Basis:
	var y: Vector3 = along.normalized()
	var z: Vector3 = toward - toward.project(y)
	if z.length() < 0.0001:
		z = Vector3.FORWARD - Vector3.FORWARD.project(y)
	z = z.normalized()
	return Basis(y.cross(z), y, z)


func _set_world(bone: String, world: Transform3D, to_skeleton: Transform3D) -> void:
	var local: Transform3D = to_skeleton * world
	# Keep the bones' own scale (the body's scale lives on the scene above the skeleton).
	local.basis = local.basis.orthonormalized()
	skeleton.set_bone_global_pose(_ids[bone], local)
