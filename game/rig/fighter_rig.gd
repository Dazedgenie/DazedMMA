class_name FighterRig
extends Node3D
## The rig prototype (D283): a joint skeleton built in code, in today's faceted look, that can be posed
## against a second fighter. A pelvis, a waist that bends, the chest, neck and head, and two-bone arms and
## legs (fixed lengths, solved like FighterMotion's legs) whose hands and feet go to points on either body:
## his back, his waist, the back of his head, the canvas. Paired poses (RigPairs) are written in a shared
## frame for both men, so a guard player's legs wrap round the man on top instead of passing through him.
## Presentation only, and not in the fight screen yet: tools/rig_preview.gd shows it.
##
## The fighter faces -Z; his left is -X. Angles in poses are degrees.

## Body sizes, in metres (the same as FighterFigure's).
const PELVIS_HEIGHT: float = 0.92
## The waist joint sits this far above the hip joints; the torso is cut there (FighterSculpt.torso).
const WAIST_UP: float = 0.29
const WAIST_CUT: float = -0.07  # the torso ring the cut is at, from the torso mesh's middle
const TORSO_MIDDLE: float = 0.36  # the torso mesh's middle, above the hip joints
const NECK_UP: float = 0.35  # neck joint above the waist joint
const HEAD_UP := Vector3(0, 0.19, -0.015)  # head above the neck joint
const SHOULDER := Vector3(0.245, 0.31, 0.0)  # shoulder joints from the waist joint (x mirrored)
const HIP_X: float = 0.13
const UPPER_ARM: float = 0.31
const FOREARM: float = 0.32
const THIGH: float = FighterMotion.THIGH
const SHIN: float = FighterMotion.SHIN
## The ankle sits this far above the sole.
const ANKLE_UP: float = 0.07
const SIDES: Array[String] = ["l", "r"]

## Named points on a body that hands and feet can go to: [bone, offset in that bone's frame].
## Torso points are on the waist (chest) or pelvis joints; limb points on the solved limb segments.
const POINTS := {
	"chest": ["chest", Vector3(0, 0.2, -0.17)],
	"sternum": ["chest", Vector3(0, 0.12, -0.17)],
	"back": ["chest", Vector3(0, 0.2, 0.16)],
	"blade_l": ["chest", Vector3(-0.12, 0.24, 0.15)],
	"blade_r": ["chest", Vector3(0.12, 0.24, 0.15)],
	"belly": ["pelvis", Vector3(0, 0.2, -0.16)],
	"lower_back": ["pelvis", Vector3(0, 0.2, 0.17)],
	"waist_l": ["pelvis", Vector3(-0.2, 0.2, 0.0)],
	"waist_r": ["pelvis", Vector3(0.2, 0.2, 0.0)],
	"hip_l": ["pelvis", Vector3(-0.2, 0.0, 0.0)],
	"hip_r": ["pelvis", Vector3(0.2, 0.0, 0.0)],
	"seat": ["pelvis", Vector3(0, -0.08, 0.12)],
	"neck": ["neck", Vector3(0, 0.05, 0.0)],
	"nape": ["neck", Vector3(0, 0.07, 0.07)],
	"head": ["head", Vector3(0, 0.03, 0.0)],
	"back_of_head": ["head", Vector3(0, 0.03, 0.13)],
	"chin": ["head", Vector3(0, -0.11, -0.09)],
	"shoulder_l": ["chest", Vector3(-0.245, 0.33, 0.0)],
	"shoulder_r": ["chest", Vector3(0.245, 0.33, 0.0)],
	"armpit_l": ["chest", Vector3(-0.2, 0.2, 0.0)],
	"armpit_r": ["chest", Vector3(0.2, 0.2, 0.0)],
}

## The same joints by the names of Godot's standard humanoid skeleton (SkeletonProfileHumanoid), which
## auto-rigged bodies (Tripo, Mixamo) import as: a skinned body can later be driven from bone_transforms()
## instead of the faceted pieces, without rewriting the paired poses.
const HUMANOID := {
	"pelvis": "Hips", "waist": "Chest", "neck": "Neck", "head": "Head",
	"upper_l": "LeftUpperArm", "fore_l": "LeftLowerArm", "glove_l": "LeftHand",
	"upper_r": "RightUpperArm", "fore_r": "RightLowerArm", "glove_r": "RightHand",
	"thigh_l": "LeftUpperLeg", "shin_l": "LeftLowerLeg", "foot_l": "LeftFoot",
	"thigh_r": "RightUpperLeg", "shin_r": "RightLowerLeg", "foot_r": "RightFoot",
}

var colour: Color
var _skin := FighterFigure.FACE_COLOUR
## Joint nodes: pelvis, waist (carries the chest), neck, head; and the limb segments, posed directly.
var bones := {}
## Where each joint ended up after the last solve, in the world: shoulder_l, elbow_l, wrist_l, hip_l,
## knee_l, ankle_l and the right side's.
var joints := {}


func _init(p_colour: Color = Color.WHITE) -> void:
	colour = p_colour
	_build()


## Poses the body (pelvis, waist, neck, head) from `spec` in the pair frame `frame` (D283).
## spec: root [x, y, z] (pelvis), turn (yaw: 0 faces the frame's -Z), lean (forward +, -90 lies him on his
## back, 90 on his front), roll (sideways), bend [forward, twist, side] at the waist, head [nod, turn].
func set_body(spec: Dictionary, frame: Transform3D) -> void:
	var root: Vector3 = _vec(spec.get("root", [0, PELVIS_HEIGHT, 0]))
	var basis := Basis.from_euler(Vector3(deg_to_rad(-float(spec.get("lean", 0.0))),
		deg_to_rad(float(spec.get("turn", 0.0))), deg_to_rad(float(spec.get("roll", 0.0)))), EULER_ORDER_YXZ)
	var pelvis: Node3D = bones.pelvis
	pelvis.global_transform = frame * Transform3D(basis, root)
	var bend: Vector3 = _vec(spec.get("bend", [0, 0, 0]))
	bones.waist.rotation = Vector3(deg_to_rad(-bend.x), deg_to_rad(bend.y), deg_to_rad(bend.z))
	var head: Vector3 = _vec(spec.get("head", [0, 0, 0]))
	bones.neck.rotation = Vector3(deg_to_rad(-head.x) * 0.4, deg_to_rad(head.y) * 0.4, 0)
	bones.head.rotation = Vector3(deg_to_rad(-head.x) * 0.6, deg_to_rad(head.y) * 0.6, 0)


## Solves the hands and feet (D283): each goes to its target from `spec` (or `blend_to`'s, mixed by `t`),
## on this body, the other one (`other`) or a point in the pair frame, with the elbows and knees bent toward
## the spec's poles. Run it after both bodies are placed, twice when the hands go to each other's limbs.
func set_limbs(spec: Dictionary, frame: Transform3D, other: FighterRig, blend_to: Dictionary = {}, t: float = 0.0) -> void:
	for side: String in SIDES:
		for limb: String in ["hand", "foot"]:
			var key: String = "%s_%s" % [limb, side]
			var target: Vector3 = target_for(spec.get(key, {}), key, frame, other)
			var pole: Vector3 = _pole(spec, key)
			if not blend_to.is_empty():
				target = target.lerp(target_for(blend_to.get(key, {}), key, frame, other), t)
				pole = pole.lerp(_pole(blend_to, key), t)
			if limb == "hand":
				_solve_arm(side, target, pole)
			else:
				_solve_leg(side, target, pole, _planted(spec, key, target))


## Where a hand or foot target `want` points, in the world. {"to": "b.back", "off": [x, y, z]} is a named
## point on a body (a = this one, b = the other) offset in that bone's frame; {"at": [x, y, z]} is a point in
## the pair frame; empty is the limb's resting place (hands up in a guard, feet under the hips).
func target_for(want: Dictionary, key: String, frame: Transform3D, other: FighterRig) -> Vector3:
	if want.has("at"):
		return frame * _vec(want.at)
	if want.has("to"):
		var point_name: String = String(want.to)
		var body: FighterRig = self if point_name.begins_with("a.") else other
		return body.point(point_name.substr(2), _vec(want.get("off", [0, 0, 0])))
	var pelvis: Node3D = bones.pelvis
	var side: float = -1.0 if key.ends_with("_l") else 1.0
	if key.begins_with("hand"):  # Hands up in front of the face.
		var chest: Node3D = bones.waist
		return chest.global_transform * Vector3(side * 0.1, 0.42, -0.3)
	var hip: Vector3 = pelvis.global_transform * Vector3(side * HIP_X, 0, 0)
	return Vector3(hip.x, ANKLE_UP, hip.z)  # Feet under the hips on the canvas.


## A named point on this body (POINTS, or a limb point: elbow_l, wrist_l, knee_l, ankle_l, thigh_l, shin_l
## and the right side's), with `off` in that bone's frame, in the world.
func point(point_name: String, off: Vector3 = Vector3.ZERO) -> Vector3:
	if POINTS.has(point_name):
		var bone: Node3D = bones.waist if String(POINTS[point_name][0]) == "chest" else bones[POINTS[point_name][0]]
		return bone.global_transform * (Vector3(POINTS[point_name][1]) + off)
	if point_name.begins_with("thigh_") or point_name.begins_with("shin_") or point_name.begins_with("upper_") or point_name.begins_with("fore_"):
		var segment: Node3D = bones[point_name]
		var length: float = {"thigh": THIGH, "shin": SHIN, "upper": UPPER_ARM, "fore": FOREARM}[point_name.get_slice("_", 0)]
		return segment.global_transform * (Vector3(0, -length * 0.5, 0) + off)  # Half way down the bone.
	if joints.has(point_name):
		return Vector3(joints[point_name]) + off
	push_error("FighterRig: no point called %s" % point_name)
	return global_position


## Every joint's place and turn in the world after the last pose, by its humanoid bone name (HUMANOID), with
## the limb segments' stretch taken out.
func bone_transforms() -> Dictionary:
	var out := {}
	for key: String in HUMANOID:
		var node: Node3D = bones[key]
		out[HUMANOID[key]] = Transform3D(node.global_basis.orthonormalized(), node.global_position)
	return out


## Poses two rigs against each other (D283): the pair pose `pair` ({a: spec, b: spec}), or a blend from it
## to `to` by `t`, in the frame `frame` (origin on the canvas between them, a on the +Z side facing -Z).
static func pose_pair(a: FighterRig, b: FighterRig, pair: Dictionary, frame: Transform3D, to: Dictionary = {}, t: float = 0.0) -> void:
	var bodies: Array[Dictionary] = [pair.a, pair.b]
	if not to.is_empty():
		bodies = [blend_body(pair.a, to.a, t), blend_body(pair.b, to.b, t)]
	a.set_body(bodies[0], frame)
	b.set_body(bodies[1], frame)
	for repeat in 2:  # Twice, so a hand on his wrist finds the wrist where it ended up.
		a.set_limbs(pair.a, frame, b, {} if to.is_empty() else to.a, t)
		b.set_limbs(pair.b, frame, a, {} if to.is_empty() else to.b, t)


## The body numbers of `from` mixed toward `to` by `t` (limbs are mixed in set_limbs, in the world).
static func blend_body(from: Dictionary, to: Dictionary, t: float) -> Dictionary:
	var out := {}
	for key: String in ["root", "bend", "head"]:
		var x: Vector3 = _vec(from.get(key, [0, PELVIS_HEIGHT, 0] if key == "root" else [0, 0, 0]))
		var y: Vector3 = _vec(to.get(key, [0, PELVIS_HEIGHT, 0] if key == "root" else [0, 0, 0]))
		var v: Vector3 = x.lerp(y, t)
		out[key] = [v.x, v.y, v.z]
	for key: String in ["turn", "lean", "roll"]:
		out[key] = lerpf(float(from.get(key, 0.0)), float(to.get(key, 0.0)), t)
	return out


func _pole(spec: Dictionary, key: String) -> Vector3:
	var pelvis: Node3D = bones.pelvis
	var side: float = -1.0 if key.ends_with("_l") else 1.0
	var fallback: Vector3 = Vector3(side * 0.6, -1, 0.3) if key.begins_with("hand") else Vector3(side * 0.15, 0, -1)
	var want: Dictionary = spec.get(key, {})
	var local: Vector3 = _vec(want.pole) if want.has("pole") else fallback
	return pelvis.global_basis * local


func _planted(spec: Dictionary, key: String, target: Vector3) -> float:
	var want: Dictionary = spec.get(key, {})
	if want.has("flat"):
		return float(want.flat)
	return 1.0 if target.y < ANKLE_UP + 0.03 and not want.has("to") else 0.0


func _solve_arm(side: String, target: Vector3, pole: Vector3) -> void:
	var chest: Node3D = bones.waist
	var shoulder: Vector3 = chest.global_transform * Vector3(SHOULDER.x * (-1.0 if side == "l" else 1.0), SHOULDER.y, SHOULDER.z)
	var chain: Array[Vector3] = FighterMotion.solve_bones(Vector3.ZERO, target - shoulder, pole, UPPER_ARM, FOREARM)
	var elbow: Vector3 = shoulder + chain[0]
	var wrist: Vector3 = shoulder + chain[1]
	_lay(bones["upper_" + side], shoulder, elbow, pole, UPPER_ARM)
	_lay(bones["fore_" + side], elbow, wrist, pole, FOREARM)
	var glove: Node3D = bones["glove_" + side]
	glove.global_transform = Transform3D(_aim(wrist - elbow, pole), wrist)
	joints["shoulder_" + side] = shoulder
	joints["elbow_" + side] = elbow
	joints["wrist_" + side] = wrist


func _solve_leg(side: String, target: Vector3, pole: Vector3, planted: float) -> void:
	var pelvis: Node3D = bones.pelvis
	var hip: Vector3 = pelvis.global_transform * Vector3(HIP_X * (-1.0 if side == "l" else 1.0), 0, 0)
	var chain: Array[Vector3] = FighterMotion.solve_bones(Vector3.ZERO, target - hip, pole, THIGH, SHIN)
	var knee: Vector3 = hip + chain[0]
	var ankle: Vector3 = hip + chain[1]
	_lay(bones["thigh_" + side], hip, knee, pole, THIGH)
	_lay(bones["shin_" + side], knee, ankle, pole, SHIN)
	# The foot follows the shin, or lies flat on the canvas when it's planted there.
	var up: Vector3 = (knee - ankle).normalized().lerp(Vector3.UP, planted).normalized()
	var toes: Vector3 = pole - pole.project(up)
	if toes.length() < 0.01:
		toes = -pelvis.global_basis.z
	var z: Vector3 = -toes.normalized()
	var foot: Node3D = bones["foot_" + side]
	foot.global_transform = Transform3D(Basis(up.cross(z).normalized(), up, z), ankle)
	joints["hip_" + side] = hip
	joints["knee_" + side] = knee
	joints["ankle_" + side] = ankle


## Lays a limb segment from `from` to `to` (its mesh runs down its -Y, `length` long at rest), turned so
## its front faces away from the pole.
static func _lay(node: Node3D, from: Vector3, to: Vector3, pole: Vector3, length: float) -> void:
	var basis: Basis = _aim(to - from, pole)
	node.global_transform = Transform3D(basis.scaled_local(Vector3(1, from.distance_to(to) / length, 1)), from)


## A basis whose -Y runs along `down` and whose -Z leans toward `toward`.
static func _aim(down: Vector3, toward: Vector3) -> Basis:
	var y: Vector3 = -down.normalized()
	var front: Vector3 = toward - toward.project(y)
	if front.length() < 0.001:
		front = Vector3.FORWARD - Vector3.FORWARD.project(y)
		if front.length() < 0.001:
			front = Vector3.RIGHT
	var z: Vector3 = -front.normalized()
	return Basis(y.cross(z).normalized(), y, z)


static func _vec(v: Variant) -> Vector3:
	if v is Vector3:
		return v
	var a: Array = v
	return Vector3(float(a[0]), float(a[1]), float(a[2]) if a.size() > 2 else 0.0)


func _build() -> void:
	var skin: StandardMaterial3D = FighterFigure._material(_skin)
	var gear: StandardMaterial3D = FighterFigure._material(Color("#232830"))
	var cloth: StandardMaterial3D = FighterFigure._material(colour.lerp(Color("#555158"), 0.22).darkened(0.13))
	var pelvis := Node3D.new()
	add_child(pelvis)
	bones.pelvis = pelvis
	FightMesh.instance(pelvis, FighterSculpt.torso(false, -0.32, WAIST_CUT), skin, Vector3(0, TORSO_MIDDLE, 0))
	FightMesh.instance(pelvis, FighterSculpt.contour([
		Vector4(-0.16, 0.225, 0.142, 0.16), Vector4(-0.065, 0.277, 0.159, 0.17), Vector4(0.065, 0.20, 0.146, 0.15)
	]), cloth)
	FightMesh.instance(pelvis, FighterSculpt.contour([
		Vector4(0.035, 0.219, 0.155, 0.159), Vector4(0.095, 0.198, 0.145, 0.15)
	]), gear)
	var waist := Node3D.new()
	waist.position = Vector3(0, WAIST_UP, 0)
	pelvis.add_child(waist)
	bones.waist = waist
	FightMesh.instance(waist, FighterSculpt.torso(false, WAIST_CUT, 1.0), skin, Vector3(0, -WAIST_CUT, 0))
	var neck := Node3D.new()
	neck.position = Vector3(0, NECK_UP, 0)
	waist.add_child(neck)
	bones.neck = neck
	FightMesh.instance(neck, FighterSculpt.contour([
		Vector4(-0.05, 0.103, 0.085, 0.09), Vector4(0.04, 0.079, 0.077, 0.08), Vector4(0.12, 0.079, 0.075, 0.08)
	]), skin)
	var head := Node3D.new()
	head.position = HEAD_UP
	neck.add_child(head)
	bones.head = head
	var skull: MeshInstance3D = FightMesh.instance(head, FighterSculpt.head(false), skin)
	skull.scale = Vector3(0.94, 0.89, 0.94)
	FightMesh.instance(skull, FighterSculpt.nose(), skin, Vector3(0, 0.005, -0.131))
	FightMesh.instance(skull, FighterSculpt.hair(false), FighterFigure._material(Color("#322820")))
	for side: String in SIDES:
		var x: float = -1.0 if side == "l" else 1.0
		FightMesh.instance(waist, FighterSculpt.ellipsoid(Vector3(0.106, 0.12, 0.112)), skin,
			Vector3(x * SHOULDER.x, SHOULDER.y - 0.018, SHOULDER.z))
		var upper := Node3D.new()
		add_child(upper)
		bones["upper_" + side] = upper
		FightMesh.instance(upper, FighterSculpt.contour([
			Vector4(0, 0.102 / UPPER_ARM * 0.31, 0.10, 0.10), Vector4(-0.09, 0.113, 0.115, 0.11),
			Vector4(-0.19, 0.096, 0.105, 0.09), Vector4(-UPPER_ARM, 0.057, 0.063, 0.06)
		]), skin)
		var fore := Node3D.new()
		add_child(fore)
		bones["fore_" + side] = fore
		FightMesh.instance(fore, FighterSculpt.contour([
			Vector4(0, 0.058, 0.061, 0.061), Vector4(-0.08, 0.077, 0.078, 0.07),
			Vector4(-0.18, 0.065, 0.063, 0.058), Vector4(-FOREARM, 0.043, 0.042, 0.042)
		]), skin)
		var glove := Node3D.new()
		add_child(glove)
		bones["glove_" + side] = glove
		var mitt: MeshInstance3D = FightMesh.instance(glove, FighterSculpt.ellipsoid(Vector3(0.067, 0.079, 0.055)), gear,
			Vector3(0, -0.06, 0))
		FightMesh.instance(mitt, FighterSculpt.contour([
			Vector4(0.045, 0.048, 0.045, 0.045), Vector4(0.087, 0.044, 0.041, 0.041)
		]), FighterFigure._material(colour.darkened(0.12)))
		var thigh := Node3D.new()
		add_child(thigh)
		bones["thigh_" + side] = thigh
		FightMesh.instance(thigh, FighterSculpt.contour([
			Vector4(0.0, 0.13, 0.13, 0.135), Vector4(-0.1, 0.125, 0.127, 0.13), Vector4(-0.2, 0.103, 0.107, 0.11),
			Vector4(-THIGH, 0.072, 0.077, 0.075)
		]), skin)
		FightMesh.instance(thigh, FighterSculpt.contour([
			Vector4(0.06, 0.15, 0.155, 0.16), Vector4(-0.08, 0.151, 0.154, 0.155), Vector4(-0.2, 0.142, 0.145, 0.147)
		]), cloth)
		var shin := Node3D.new()
		add_child(shin)
		bones["shin_" + side] = shin
		FightMesh.instance(shin, FighterSculpt.contour([
			Vector4(0.025, 0.072, 0.078, 0.075), Vector4(-0.08, 0.09, 0.077, 0.105),
			Vector4(-0.17, 0.087, 0.065, 0.1), Vector4(-0.32, 0.053, 0.046, 0.06), Vector4(-SHIN, 0.043, 0.042, 0.046)
		]), skin)
		var foot := Node3D.new()
		add_child(foot)
		bones["foot_" + side] = foot
		FightMesh.instance(foot, FighterSculpt.foot(), skin, Vector3(0, -ANKLE_UP + 0.035, -0.04))
