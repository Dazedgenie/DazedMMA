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
	"forehead": ["head", Vector3(0, 0.08, -0.11)],
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
## Which man of the pair this is ("a" red or "b" blue), for the "a."/"b." points in paired poses.
var corner: String = "a"
## This rig's sizes: the constants above unless fit() has measured them from a body (D284), so the rig a skinned
## body follows has that body's trunk and limbs.
var waist_up: float = WAIST_UP
var neck_up: float = NECK_UP
## Middle-joint strike intent, separate from the positional joints consumed by bounds/path checks (D427).
var joint_strikes: Dictionary = {}
var head_up: Vector3 = HEAD_UP
var shoulder: Vector3 = SHOULDER
var hip_x: float = HIP_X
var upper_arm: float = UPPER_ARM
var forearm: float = FOREARM
var thigh: float = THIGH
var shin: float = SHIN
var ankle_up: float = ANKLE_UP
## The torso's points (POINTS) stretched to a fitted body: across and front to back by its shoulders, up by its trunk.
var point_scale := Vector3.ONE
var _skin := FighterFigure.FACE_COLOUR
## Joint nodes: pelvis, waist (carries the chest), neck, head; and the limb segments, posed directly.
var bones := {}
## Where each joint ended up after the last solve, in the world: shoulder_l, elbow_l, wrist_l, hip_l,
## knee_l, ankle_l and the right side's.
var joints := {}


func _init(p_colour: Color = Color.WHITE) -> void:
	colour = p_colour
	_build()


## Takes a body's sizes (D284; SkinnedBody.measure()): any of waist_up, neck_up, head_up, shoulder, hip_x,
## upper_arm, forearm, thigh, shin and ankle_up, in metres. The faceted pieces aren't rebuilt: a fitted rig is
## hidden and drives the body.
func fit(sizes: Dictionary) -> void:
	for key: String in sizes:
		set(key, sizes[key])
	bones.waist.position = Vector3(0, waist_up, 0)
	bones.neck.position = Vector3(0, neck_up, 0)
	bones.head.position = head_up
	point_scale = Vector3(shoulder.x / SHOULDER.x, (waist_up + neck_up) / (WAIST_UP + NECK_UP), shoulder.x / SHOULDER.x)


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
			var strike_key: String = "joint_strike_" + ("arm_" if limb == "hand" else "leg_") + side
			joint_strikes.erase(strike_key)
			var strike: Dictionary = _joint_aim(spec.get(key, {}), blend_to.get(key, {}), not blend_to.is_empty(), t, key, frame, other)
			if not strike.is_empty():
				joint_strikes[strike_key] = strike
			var target: Vector3 = target_for(spec.get(key, {}), key, frame, other)
			var pole: Vector3 = _pole(spec, key)
			if not blend_to.is_empty():
				target = target.lerp(target_for(blend_to.get(key, {}), key, frame, other), t)
				pole = pole.lerp(_pole(blend_to, key), t)
			# Nothing reaches through the canvas (D396): a foot hooked on a man lying there, a hand on the mat.
			target.y = maxf(target.y, ankle_up * FOOT_FLOOR if limb == "foot" else HAND_FLOOR)
			var trunk: Array[Vector3] = []
			if other != null:
				trunk = other.trunk()
			if not trunk.is_empty():  # Nor into the other man (D397): a hand or foot that would be is put on him.
				target = out_of(target, trunk[0], trunk[1])
			if limb == "hand":
				_solve_arm(side, target, pole, trunk, strike)
			else:
				_solve_leg(side, target, pole, _planted(spec, key, target), trunk, strike)


## A paired short strike keeps its ordinary grip/guard target and blends its elbow or knee toward a separate
## contact (D427). Carry this intent to the final body so retargeting cannot turn an elbow back into a punch.
func _joint_aim(from: Dictionary, to: Dictionary, blending: bool, t: float, key: String, frame: Transform3D, other: FighterRig) -> Dictionary:
	var a: float = float(from.get("joint_weight", 1.0)) if from.has("joint_to") else 0.0
	var b: float = float(to.get("joint_weight", 1.0)) if to.has("joint_to") else 0.0
	var weight: float = lerpf(a, b, t) if blending else a
	if weight < 0.001:
		return {}
	var want: Dictionary = from if a > 0.0 else to
	var target: Vector3 = target_for({"to": want.joint_to, "off": want.get("joint_off", [0, 0, 0])}, key, frame, other)
	if a > 0.0 and b > 0.0:
		target = target.lerp(target_for({"to": to.joint_to, "off": to.get("joint_off", [0, 0, 0])}, key, frame, other), t)
	var side: float = -1.0 if key.ends_with("_l") else 1.0
	var fold: Vector3 = bones.pelvis.global_basis * Vector3(0, -0.65, 1)
	if key.begins_with("hand"):
		fold = point("head") + bones.waist.global_basis * Vector3(side * 0.16, -0.10, -0.10) - target
	return {"target": target, "weight": weight, "fold": fold.normalized(), "shoulder_reach": key.begins_with("hand")}


## Where a hand or foot target `want` points, in the world. {"to": "b.back", "off": [x, y, z]} is a named
## point on a body (a = red, the pair's first man; b = blue) offset in that bone's frame; {"at": [x, y, z]} is a point in
## the pair frame; empty is the limb's resting place (hands up in a guard, feet under the hips).
func target_for(want: Dictionary, key: String, frame: Transform3D, other: FighterRig) -> Vector3:
	if want.has("at"):  # Feet are placed for the standard ankle height; a fitted body's ankle may sit higher.
		return frame * (_vec(want.at) + (Vector3(0, ankle_up - ANKLE_UP, 0) if key.begins_with("foot") else Vector3.ZERO))
	if want.has("to"):
		var point_name: String = String(want.to)
		var body: FighterRig = self if point_name.begins_with(corner + ".") else other
		return body.point(point_name.substr(2), _vec(want.get("off", [0, 0, 0])))
	var pelvis: Node3D = bones.pelvis
	var side: float = -1.0 if key.ends_with("_l") else 1.0
	if key.begins_with("hand"):  # Hands up in front of the face.
		var chest: Node3D = bones.waist
		return chest.global_transform * (Vector3(side * 0.1, 0.42, -0.3) * point_scale)
	var hip: Vector3 = pelvis.global_transform * Vector3(side * hip_x, 0, 0)
	return Vector3(hip.x, ankle_up, hip.z)  # Feet under the hips on the canvas.


## A named point on this body (POINTS, or a limb point: elbow_l, wrist_l, knee_l, ankle_l, thigh_l, shin_l
## and the right side's), with `off` in that bone's frame, in the world.
func point(point_name: String, off: Vector3 = Vector3.ZERO) -> Vector3:
	if POINTS.has(point_name):
		var bone: Node3D = bones.waist if String(POINTS[point_name][0]) == "chest" else bones[POINTS[point_name][0]]
		return bone.global_transform * (Vector3(POINTS[point_name][1]) * (point_scale if bone == bones.waist or bone == bones.pelvis else Vector3.ONE) + off)
	if point_name.begins_with("thigh_") or point_name.begins_with("shin_") or point_name.begins_with("upper_") or point_name.begins_with("fore_"):
		var segment: Node3D = bones[point_name]
		var length: float = {"thigh": thigh, "shin": shin, "upper": upper_arm, "fore": forearm}[point_name.get_slice("_", 0)]
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
	a.corner = "a"
	b.corner = "b"
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
	return 1.0 if target.y < ankle_up + 0.03 and not want.has("to") else 0.0


func _solve_arm(side: String, target: Vector3, pole: Vector3, trunk: Array[Vector3] = [], strike: Dictionary = {}) -> void:
	var chest: Node3D = bones.waist
	var joint: Vector3 = chest.global_transform * Vector3(shoulder.x * (-1.0 if side == "l" else 1.0), shoulder.y, shoulder.z)
	var chain: Array[Vector3] = FighterMotion.solve_bones(Vector3.ZERO, target - joint, pole, upper_arm, forearm)
	if not strike.is_empty():
		chain = FighterMotion.strike_joint(Vector3.ZERO, chain, Vector3(strike.target) - joint, strike.fold, float(strike.weight), upper_arm, forearm)
	var elbow: Vector3 = clear_of(joint, joint + chain[0], joint + chain[1], trunk)
	var wrist: Vector3 = joint + chain[1]
	_lay(bones["upper_" + side], joint, elbow, pole, upper_arm)
	_lay(bones["fore_" + side], elbow, wrist, pole, forearm)
	var glove: Node3D = bones["glove_" + side]
	glove.global_transform = Transform3D(_aim(wrist - elbow, pole), wrist)
	joints["shoulder_" + side] = joint
	joints["elbow_" + side] = elbow
	joints["wrist_" + side] = wrist


## Overlay the bottom fighter's lead heel on the current ground or stand-up pose.
func up_kick(side: String, other: FighterRig, amount: float, missed: float) -> void:
	if amount <= 0.0:
		return
	var ankle: Vector3 = joints["ankle_" + side]
	var head: Vector3 = other.point("head")
	var trunk: Array[Vector3] = other.trunk()
	var out: Vector3 = bones.pelvis.global_basis.x * (-1.0 if side == "l" else 1.0)
	var hip: Vector3 = joints["hip_" + side]
	var front := Vector3(hip.x - head.x, 0, hip.z - head.z).normalized()
	var target: Vector3 = head + front * 0.19 + out * (0.08 + missed * 0.35)
	var knee: Vector3 = joints["knee_" + side]
	var pole: Vector3 = (knee - hip.lerp(ankle, 0.5)).normalized()
	var foot: Node3D = bones["foot_" + side]
	var before: Basis = foot.global_basis.orthonormalized()
	_solve_leg(side, ankle.lerp(target, amount), pole.lerp(Vector3.UP + out * 0.65, amount), 0.0, trunk)
	foot.global_basis = before.slerp(foot.global_basis.orthonormalized(), amount)


func _solve_leg(side: String, target: Vector3, pole: Vector3, planted: float, trunk: Array[Vector3] = [], strike: Dictionary = {}) -> void:
	var pelvis: Node3D = bones.pelvis
	var hip: Vector3 = pelvis.global_transform * Vector3(hip_x * (-1.0 if side == "l" else 1.0), 0, 0)
	var chain: Array[Vector3] = FighterMotion.solve_bones(Vector3.ZERO, target - hip, pole, thigh, shin)
	if not strike.is_empty():
		chain = FighterMotion.strike_joint(Vector3.ZERO, chain, Vector3(strike.target) - hip, strike.fold, float(strike.weight), thigh, shin)
		planted *= 1.0 - float(strike.weight)
	var knee: Vector3 = clear_of(hip, hip + chain[0], hip + chain[1], trunk)
	var ankle: Vector3 = hip + chain[1]
	_lay(bones["thigh_" + side], hip, knee, pole, thigh)
	_lay(bones["shin_" + side], knee, ankle, pole, shin)
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


## How close to the line up the middle of a man's trunk (his hips to his chest) the other man's joints may come
## (metres, D397): a hand or knee pressed on him sits further out than this, one inside him closer.
const TRUNK_RADIUS: float = 0.12
## Where that line ends at the top: this far up from his chest bone (a share of POINTS' scale, as they are).
const TRUNK_TOP: float = 0.2


## The line up the middle of his trunk, his hips to his chest, in the world (D397).
func trunk() -> Array[Vector3]:
	var pelvis: Node3D = bones.pelvis
	var chest: Node3D = bones.waist
	return [pelvis.global_position, chest.global_transform * (Vector3(0, TRUNK_TOP, 0) * point_scale)]


## The closest point to `p` on the line from `a` to `b`.
static func closest_on(p: Vector3, a: Vector3, b: Vector3) -> Vector3:
	var ab: Vector3 = b - a
	var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return a + ab * t


## `p`, or if it's inside the trunk from `a` to `b` (nearer its middle line than TRUNK_RADIUS), put out on it the
## shortest way (D397).
static func out_of(p: Vector3, a: Vector3, b: Vector3) -> Vector3:
	var near: Vector3 = closest_on(p, a, b)
	var off: Vector3 = p - near
	if off.length() >= TRUNK_RADIUS:
		return p
	var line: Vector3 = (b - a).normalized()
	if off.length() < 0.001:  # Right on the line: out sideways to it.
		off = line.cross(Vector3.UP) if absf(line.dot(Vector3.UP)) < 0.9 else line.cross(Vector3.RIGHT)
	return near + off.normalized() * TRUNK_RADIUS


## The nearest either segment of a bent limb comes to the other torso's centre line (D425).
static func limb_clearance(root: Vector3, middle: Vector3, end: Vector3, trunk: Array[Vector3]) -> float:
	var upper: PackedVector3Array = Geometry3D.get_closest_points_between_segments(root, middle, trunk[0], trunk[1])
	var lower: PackedVector3Array = Geometry3D.get_closest_points_between_segments(middle, end, trunk[0], trunk[1])
	return minf(upper[0].distance_to(upper[1]), lower[0].distance_to(lower[1]))


## Keep both segments, not just the elbow/knee, outside the other trunk (D397, D425). Rotate the bend around
## root-to-end to retain both bone lengths and the contact point. If the fixed endpoints make clearance impossible,
## choose the least penetrating bend that still clears the canvas.
static func clear_of(root: Vector3, middle: Vector3, end: Vector3, trunk: Array[Vector3]) -> Vector3:
	var lifted: Vector3 = above_canvas(root, middle, end)
	if trunk.is_empty() or limb_clearance(root, lifted, end, trunk) >= TRUNK_RADIUS:
		return lifted
	var axis: Vector3 = end - root
	if axis.length() < 0.001:
		return lifted
	axis = axis.normalized()
	var arm: Vector3 = lifted - root
	var best: Vector3 = lifted
	var best_out: float = limb_clearance(root, lifted, end, trunk)
	for step in range(1, 37):
		for sign: float in [1.0, -1.0]:
			var turned: Vector3 = root + arm.rotated(axis, sign * step * FLOOR_STEP)
			var out: float = limb_clearance(root, turned, end, trunk)
			if turned.y < JOINT_FLOOR:
				continue
			if out >= TRUNK_RADIUS:
				return turned
			if out > best_out + 0.00001:
				best = turned
				best_out = out
	return best


## The lowest a knee or elbow's middle may sit (metres above the canvas; the canvas is at 0): a joint resting on it.
const JOINT_FLOOR: float = 0.05
## The lowest a hand's wrist and a foot's ankle (a share of its height standing) may be put (D396).
const HAND_FLOOR: float = 0.04
const FOOT_FLOOR: float = 0.7
## How far round its limb a knee or elbow is turned at a time looking for room above the canvas (radians).
const FLOOR_STEP: float = PI / 36.0


## A knee or elbow at `middle`, between `root` and `end`, kept out of the canvas (D396): a pose whose pole bends the
## joint down into the canvas (a mount's knees with his shins flat behind him, the crucifix) has it turned round the
## line from `root` to `end`, the least way that lifts it to JOINT_FLOOR. If no turn does (the limb's ends are both
## on the canvas), the highest it can go.
static func above_canvas(root: Vector3, middle: Vector3, end: Vector3) -> Vector3:
	if middle.y >= JOINT_FLOOR:
		return middle
	var axis: Vector3 = end - root
	if axis.length() < 0.001:
		return Vector3(middle.x, JOINT_FLOOR, middle.z)
	axis = axis.normalized()
	var arm: Vector3 = middle - root
	var best: Vector3 = middle
	for step in range(1, 37):
		for sign: float in [1.0, -1.0]:
			var turned: Vector3 = root + arm.rotated(axis, sign * step * FLOOR_STEP)
			if turned.y >= JOINT_FLOOR:
				return turned
			if turned.y > best.y:
				best = turned
	return best


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
