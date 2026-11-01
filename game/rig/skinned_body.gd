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

## The first body (Kyle's, made in Tripo with its Mixamo skeleton preset, 2026-10-31): imported with the game, since
## the fight screen draws both fighters with it (D285).
const TRIPO_BODY := "res://game/bodies/tripo_fighter.glb"
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
## The bones' poses shown last frame and the easing time left (ease_over, settle).
var _shown: Array[Transform3D] = []
var _ease_left: float = 0.0
## The body's scale (the file's units to metres) and the bones' rests in the world when the body stands as the
## rig does at rest (facing -Z at the origin).
var body_scale: float = 1.0
var _rest_world := {}
var _ids := {}
## Where the hip joints' middle is at rest (the rig's pelvis point).
var _pelvis_rest := Vector3.ZERO
## His build (D364, set_size): each bone's scale in its own frame (Y runs along the bone), and how long his arms are.
var _bone_scale := {}
var _arm_length: float = 1.0


func _init() -> void:
	top_level = true  # The body's rest is taken at the world's origin; it is posed in world space.


## Loads the body from a glTF/GLB file (`path`, res:// or a file path). Returns false if it isn't a humanoid.
## `shoulder_height` (metres, 0 for none) scales the body so its shoulders stand that high instead of its hips at
## the rig's pelvis height (D285: today's figures are taller in the trunk than the body).
func load_body(path: String, shoulder_height: float = 0.0) -> bool:
	var scene: Node3D
	if ResourceLoader.exists(path, "PackedScene"):  # Imported with the game (exports with it).
		var packed: PackedScene = load(path)
		scene = packed.instantiate()
	else:  # A raw file (the tools' bodies, or one from outside the project).
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(path, state) != OK:
			push_error("SkinnedBody: could not load %s" % path)
			return false
		scene = doc.generate_scene(state)
	add_child(scene)
	return attach(scene, shoulder_height)


## Uses `scene` (already a child of this node) as the body.
func attach(scene: Node3D, shoulder_height: float = 0.0) -> bool:
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
	if shoulder_height > 0.0:
		var shoulder: float = (skeleton.global_transform * skeleton.get_bone_global_rest(_ids.RightArm)).origin.y
		body_scale = shoulder_height / maxf(shoulder, 0.01)
	scene.transform = Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * body_scale), Vector3.ZERO) * scene.transform
	var to_world: Transform3D = global_transform.affine_inverse() * skeleton.global_transform
	for key: String in _ids:
		_rest_world[key] = to_world * skeleton.get_bone_global_rest(_ids[key])
	_pelvis_rest = (_at("LeftUpLeg") + _at("RightUpLeg")) / 2.0
	curl_fingers(FIST_CURL)
	return true


## The trunk's and the limbs' bones (D364): set_size thickens them across, and lengthens the arms' along.
const GIRTH_TRUNK: Array[String] = ["Hips", "Spine", "Spine1", "Spine2", "Neck"]
const GIRTH_LIMBS: Array[String] = ["LeftArm", "LeftForeArm", "RightArm", "RightForeArm", "LeftUpLeg", "LeftLeg",
	"RightUpLeg", "RightLeg"]
## The neck takes this share of the trunk's thickening.
const NECK_GIRTH_SHARE: float = 0.7


## Draws him at his build (FighterLook.sizes, D364): `girth` thickens his trunk across, `limbs` his arms and legs,
## and `arm` lengthens his arms (upper arm and forearm alike). Run before posing, and before the rig is fitted to
## measure(), which gives the longer arms.
func set_size(sizes: Dictionary) -> void:
	var girth: float = float(sizes.get("girth", 1.0))
	var limbs: float = float(sizes.get("limbs", 1.0))
	_arm_length = float(sizes.get("arm", 1.0))
	_bone_scale.clear()
	for bone: String in GIRTH_TRUNK:
		var g: float = 1.0 + (girth - 1.0) * (NECK_GIRTH_SHARE if bone == "Neck" else 1.0)
		_bone_scale[bone] = Vector3(g, 1.0, g)
	for bone: String in GIRTH_LIMBS:
		_bone_scale[bone] = Vector3(limbs, _arm_length if bone.contains("Arm") else 1.0, limbs)


## How far each finger joint bends to make a fist (radians; the thumb folds about half as far).
const FIST_CURL: float = 1.35
## The finger bones of a Mixamo hand, each bent by curl_fingers.
const FINGERS := ["Index", "Middle", "Ring", "Pinky", "Thumb"]
## The axis each thumb's joints turn about to fold it into the palm (in the bone's own frame; the two hands'
## thumb bones are not plain mirror images, so each has its own).
const THUMB_AXIS := {"Right": Vector3(-0.87, -0.5, 0.0), "Left": Vector3(0.75, -0.5, 0.43)}


## Bends the fingers in (a gloved fist at FIST_CURL; 0 opens the hand).
func curl_fingers(amount: float) -> void:
	for side: String in ["Left", "Right"]:
		for finger: String in FINGERS:
			for joint in [1, 2, 3]:
				var id: int = skeleton.find_bone("%s%sHand%s%d" % [PREFIX, side, finger, joint])
				if id < 0:
					continue
				# Mixamo fingers bend about their own X, the left hand's the other way round (its bones are
				# mirrored); the thumb folds across the fingers about an axis found by search (THUMB_AXIS).
				var bend := Quaternion(THUMB_AXIS[side].normalized(), amount * 0.52) if finger == "Thumb" \
					else Quaternion(Vector3.LEFT if side == "Left" else Vector3.RIGHT, amount)
				skeleton.set_bone_pose_rotation(id, skeleton.get_bone_rest(id).basis.get_rotation_quaternion() * bend)


## Colours the body's light-grey shorts in a corner's colour (the rest of the texture stays as it is). The body
## file's shorts are light grey on purpose so one body serves both corners.
func set_colour(colour: Color) -> void:
	set_look(colour, {})


## The body's regions (D364): a texture over the body's own, baked from where each part of it is
## (tools/body_regions.py): red the hair on his head, green where a beard grows, blue his eyebrows, alpha his shorts.
const REGIONS := "res://game/bodies/tripo_fighter_regions.png"
## The skin and hair colours the body's own texture has (sRGB), which a look's colours replace.
const BODY_SKIN := Color(0.745, 0.525, 0.384)
const BODY_HAIR := Color(0.21, 0.17, 0.14)
## How much of the hair's colour a buzzed head keeps over the scalp's (a shaved head keeps none).
const BUZZED_HAIR: float = 0.55
## How far the hair's shell sinks toward the scalp (metres) for a buzzed or shaved head.
const HAIR_SINK := { "short": 0.0, "buzzed": 0.014, "shaved": 0.022 }
## How much of the texture's own skin colour (its blush, lips and shadows) a new skin tone keeps against an even tone
## shaded as the texture is.
const SKIN_DETAIL: float = 0.65


## Colours the body: the shorts in the corner's `colour` and the skin, hair, eyebrows and beard as `look` (FighterLook,
## D364) has them; an empty look leaves the body's own skin and hair.
func set_look(colour: Color, look: Dictionary) -> void:
	var regions: Texture2D = load(REGIONS) if ResourceLoader.exists(REGIONS) else null
	for found: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = found
		var base: StandardMaterial3D = mesh.get_active_material(0) as StandardMaterial3D
		if base == null or base.albedo_texture == null:
			continue
		var tinted := ShaderMaterial.new()
		tinted.shader = _tint_shader()
		tinted.set_shader_parameter("albedo", base.albedo_texture)
		tinted.set_shader_parameter("tint", colour)
		tinted.set_shader_parameter("body_skin", BODY_SKIN)
		tinted.set_shader_parameter("body_hair", BODY_HAIR)
		tinted.set_shader_parameter("skin_detail", SKIN_DETAIL)
		if regions != null:
			tinted.set_shader_parameter("regions", regions)
			tinted.set_shader_parameter("has_regions", true)
		var has_look: bool = not look.is_empty()
		tinted.set_shader_parameter("skin", FighterLook.skin_colour(look) if has_look else BODY_SKIN)
		tinted.set_shader_parameter("hair", FighterLook.hair_colour(look) if has_look else BODY_HAIR)
		var style: String = String(look.get("hair_style", "short"))
		tinted.set_shader_parameter("hair_kept", 1.0 if style == "short" else (BUZZED_HAIR if style == "buzzed" else 0.0))
		tinted.set_shader_parameter("hair_sink", HAIR_SINK.get(style, 0.0) / maxf(mesh.global_basis.get_scale().y, 0.001))
		tinted.set_shader_parameter("beard", float(FighterLook.BEARD_SHADE.get(String(look.get("beard", "none")), 0.0)))
		mesh.material_override = tinted


static var _shader: Shader


## Light, colourless texels in the shorts take the corner's tint; skin takes the look's tone (each texel shaded as the
## body's own skin is there), hair and eyebrows its hair colour (a shaved scalp shows skin), and the beard's zone
## darkens toward the hair colour by the beard. Gloves, eyes and the shorts' dark panels stay as they are.
static func _tint_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """
shader_type spatial;
uniform sampler2D albedo : source_color, filter_linear_mipmap;
uniform sampler2D regions : hint_default_black, filter_linear_mipmap;
uniform bool has_regions = false;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 skin : source_color = vec4(0.745, 0.525, 0.384, 1.0);
uniform vec4 hair : source_color = vec4(0.21, 0.17, 0.14, 1.0);
uniform vec4 body_skin : source_color = vec4(0.745, 0.525, 0.384, 1.0);
uniform vec4 body_hair : source_color = vec4(0.21, 0.17, 0.14, 1.0);
uniform float skin_detail = 0.5;
uniform float hair_kept = 1.0;
uniform float beard = 0.0;
uniform float hair_sink = 0.0;
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
void vertex() {
	// A buzzed or shaved head: the hair's shell sinks in toward the scalp.
	if (has_regions && hair_sink > 0.0) {
		VERTEX -= NORMAL * hair_sink * textureLod(regions, UV, 0.0).r;
	}
}
void fragment() {
	vec3 c = texture(albedo, UV).rgb;
	vec4 m = has_regions ? texture(regions, UV) : vec4(0.0, 0.0, 0.0, 1.0);
	float top = max(c.r, max(c.g, c.b));
	float sat = (top - min(c.r, min(c.g, c.b))) / max(top, 0.001);
	float grey = (1.0 - smoothstep(0.1, 0.22, sat)) * smoothstep(0.3, 0.5, top) * m.a;
	// Skin: an even tone shaded as the body's skin is here, with some of the texture's own colour kept.
	float shade = lum(c) / lum(body_skin.rgb);
	vec3 toned = mix(skin.rgb * shade, c * skin.rgb / max(body_skin.rgb, vec3(0.001)), skin_detail);
	float is_skin = smoothstep(0.3, 0.5, sat) * (1.0 - m.r) * (1.0 - m.b) * (1.0 - m.a);
	vec3 out_c = mix(c, toned, is_skin);
	// Hair and eyebrows in his hair colour, shaded as the body's hair is; a shaved scalp is skin in the hair's shading.
	float hair_shade = clamp(lum(c) / lum(body_hair.rgb), 0.0, 3.0);
	vec3 dyed = hair.rgb * hair_shade;
	vec3 scalp = skin.rgb * clamp(hair_shade * 0.55 + 0.35, 0.0, 1.1);
	out_c = mix(out_c, mix(scalp, dyed, hair_kept), m.r);
	out_c = mix(out_c, dyed, m.b);
	// The beard darkens the skin toward his hair colour.
	out_c = mix(out_c, hair.rgb * shade * 1.2, m.g * beard * is_skin);
	ALBEDO = mix(out_c, tint.rgb * (0.35 + 0.75 * top), grey);
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
		"upper_arm": _at("RightArm").distance_to(_at("RightForeArm")) * _arm_length,
		"forearm": _at("RightForeArm").distance_to(_at("RightHand")) * _arm_length,
		"thigh": _at("RightUpLeg").distance_to(_at("RightLeg")),
		"shin": _at("RightLeg").distance_to(_at("RightFoot")),
		"ankle_up": _at("RightFoot").y,
	}


func _at(bone: String) -> Vector3:
	return Transform3D(_rest_world[bone]).origin


## Poses the body as `rig` stands now (call after FighterRig.pose_pair).
func follow(rig: FighterRig) -> void:
	var pose := {}
	for key: String in ["pelvis", "waist", "neck", "head", "foot_l", "foot_r"]:
		var node: Node3D = rig.bones[key]
		pose["chest" if key == "waist" else key] = node.global_basis.orthonormalized()
	pose.pelvis_at = rig.bones.pelvis.global_position
	pose.merge(rig.joints)
	follow_joints(pose)


## Poses the body from joints in the world (D284, D285): `pelvis_at` (the hip joints' middle); the turns of
## `pelvis`, `chest`, `neck`, `head`, `foot_l` and `foot_r` (bases, the identity standing facing -Z); and the
## positions `shoulder_l`, `elbow_l`, `wrist_l`, `hip_l`, `knee_l`, `ankle_l` and the right side's; and,
## optionally, `ankle_up`, the driver's ankle height over the sole (the body's ankle sits higher or lower, so
## its ankles are moved along the feet to keep the soles where the driver's are). Any skeleton (the rig,
## today's figures) can drive the body through this. `only` ("arm_l", "leg_r", ...) re-poses just those limbs
## and leaves the rest as it is (D286: a strike thrown from the clinch pose).
func follow_joints(pose: Dictionary, only: Array[String] = []) -> void:
	var to_skeleton: Transform3D = skeleton.global_transform.affine_inverse()
	if only.is_empty():
		_follow_trunk(pose, Vector3(pose.pelvis_at), to_skeleton)
	if only.is_empty() and pose.has("shoulders_at"):
		# A driver with a longer trunk than the body's (the faceted pieces): the body's hips move along so its
		# shoulders are where the driver's are and the arms start from the right place. Its legs take up the gap.
		var shoulders: Vector3 = (_world_at("LeftArm") + _world_at("RightArm")) / 2.0
		_follow_trunk(pose, Vector3(pose.pelvis_at) + Vector3(pose.shoulders_at) - shoulders, to_skeleton)
	# The limbs, in the body's own lengths, to the driver's wrists and ankles.
	for limb: Array in LIMBS:
		var side: String = limb[3]
		var arm: bool = limb[4] == "arm"
		if not only.is_empty() and not only.has(String(limb[4]) + "_" + side):
			continue
		var upper: String = limb[0]
		var lower: String = limb[1]
		var end: String = limb[2]
		var root: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_pose(_ids[upper])).origin
		var middle_at: Vector3 = pose[("elbow_" if arm else "knee_") + side]
		var end_at: Vector3 = pose[("wrist_" if arm else "ankle_") + side]
		if not arm and pose.has("ankle_up"):
			end_at += Basis(pose["foot_" + side]).y * (_at("RightFoot").y - float(pose.ankle_up))
		var first: float = Transform3D(_rest_world[upper]).origin.distance_to(Transform3D(_rest_world[lower]).origin)
		var second: float = Transform3D(_rest_world[lower]).origin.distance_to(Transform3D(_rest_world[end]).origin)
		if arm:
			first *= _arm_length
			second *= _arm_length
		if arm and pose.has("shoulders_at"):
			# The pieces' arms are longer: a bent arm keeps the pieces' bend (so an arm round a man's back goes
			# round him, not straight through), and only a nearly straight one, a punch, reaches for the glove.
			var shoulder_at: Vector3 = pose["shoulder_" + side]
			var piece_reach: float = shoulder_at.distance_to(middle_at) + middle_at.distance_to(end_at)
			var straight: float = shoulder_at.distance_to(end_at) / maxf(piece_reach, 0.001)
			var bent_at: Vector3 = root + (end_at - root).normalized() * straight * (first + second)
			end_at = bent_at.lerp(end_at, smoothstep(STRAIGHT_FROM, STRAIGHT_AT, straight))
		if arm and root.distance_to(end_at) > first + second:
			root = _reach_with_shoulder(("Left" if side == "l" else "Right") + "Shoulder", root, end_at,
				root.distance_to(end_at) - first - second, to_skeleton)
		var root_at: Vector3 = pose[("shoulder_" if arm else "hip_") + side]
		var bend: Vector3 = middle_at - root_at.lerp(end_at, 0.5)
		var chain: Array[Vector3] = FighterMotion.solve_bones(root, end_at, bend, first, second)
		var middle: Vector3 = chain[0]
		var tip: Vector3 = chain[1]
		_aim_bone(upper, lower, root, middle, bend, arm, to_skeleton)
		_aim_bone(lower, end, middle, tip, bend, arm, to_skeleton)
		var end_turn: Basis
		if arm:  # The hand carries on along the forearm.
			var fore: Basis = (skeleton.global_transform.basis * skeleton.get_bone_global_pose(_ids[lower]).basis).orthonormalized()
			end_turn = fore * Transform3D(_rest_world[lower]).basis.orthonormalized().inverse()
		else:  # The foot copies the driver's foot.
			end_turn = pose["foot_" + side]
		_set_world(end, Transform3D(end_turn * Transform3D(_rest_world[end]).basis, tip), to_skeleton)


## The trunk: each bone turned as the driver's bone is turned from standing, the hips at `pelvis_at`.
func _follow_trunk(pose: Dictionary, pelvis_at: Vector3, to_skeleton: Transform3D) -> void:
	var rig_bone := {"pelvis": "pelvis", "waist": "chest", "neck": "neck", "head": "head"}
	for entry: Array in TRUNK:
		var bone: String = entry[0]
		var turn: Basis = pose[rig_bone[entry[1]]]
		if float(entry[2]) < 1.0:
			turn = Basis(Quaternion(Basis(pose.pelvis)).slerp(Quaternion(turn), float(entry[2])))
		var rest: Transform3D = _rest_world[bone]
		var world := Transform3D(turn * rest.basis, rest.origin)
		if bone == "Hips":
			world.origin = pelvis_at + turn * (rest.origin - _pelvis_rest)
		else:
			world.origin = _world_at(bone)
		_set_world(bone, world, to_skeleton)
		if bone == "Spine2":
			for shoulder: String in ["LeftShoulder", "RightShoulder"]:
				_set_world(shoulder, Transform3D(turn * Transform3D(_rest_world[shoulder]).basis, _world_at(shoulder)), to_skeleton)


## How far a shoulder blade may turn to carry a hand that's out of reach (radians): a punch throws the shoulder.
const SHOULDER_REACH: float = 0.5
## Following a longer-armed driver, an arm straighter than STRAIGHT_FROM (shoulder to wrist over the arm's length)
## starts reaching for the driver's hand, and from STRAIGHT_AT on goes all the way; a more bent arm keeps its bend.
const STRAIGHT_FROM: float = 0.85
const STRAIGHT_AT: float = 0.96


## Turns the shoulder blade `bone` so the arm's root at `root` comes `short` metres toward `target` (as far as
## SHOULDER_REACH allows), as a man throws his shoulder into a long punch. Returns where the arm now starts.
func _reach_with_shoulder(bone: String, root: Vector3, target: Vector3, short: float, to_skeleton: Transform3D) -> Vector3:
	var pivot: Vector3 = _world_at(bone)
	var out: Vector3 = root - pivot
	var axis: Vector3 = out.cross(target - pivot)
	if axis.length() < 0.0001:
		return root
	var angle: float = minf(short / out.length(), SHOULDER_REACH)
	var turn := Basis(axis.normalized(), angle)
	var now: Basis = (skeleton.global_transform.basis * skeleton.get_bone_global_pose(_ids[bone]).basis).orthonormalized()
	_set_world(bone, Transform3D(turn * now, pivot), to_skeleton)
	return pivot + turn * out


## Shows the next poses easing in over `seconds` from the pose shown now, instead of jumping to them (D286: from
## today's figures into the clinch from the rig and back, or from one grip to the next). Run settle after each pose.
func ease_over(seconds: float) -> void:
	_ease_left = seconds


## Call once a frame after posing the body: while easing (ease_over), each bone is shown part of the way from
## last frame's pose to the new one, arriving when the time is up.
func settle(delta: float) -> void:
	var count: int = skeleton.get_bone_count()
	if _ease_left > 0.0 and _shown.size() == count:
		var t: float = clampf(delta / _ease_left, 0.0, 1.0)
		for id in count:
			skeleton.set_bone_pose(id, _shown[id].interpolate_with(skeleton.get_bone_pose(id), t))
		_ease_left -= delta
	_shown.resize(count)
	for id in count:
		_shown[id] = skeleton.get_bone_pose(id)


## Where `bone` is in the world as posed now.
func _world_at(bone: String) -> Vector3:
	return (skeleton.global_transform * skeleton.get_bone_global_pose(_ids[bone])).origin


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
	if _bone_scale.has(bone):
		local.basis = local.basis * Basis.from_scale(_bone_scale[bone])  # His build (D364), in the bone's own frame.
	skeleton.set_bone_global_pose(_ids[bone], local)
