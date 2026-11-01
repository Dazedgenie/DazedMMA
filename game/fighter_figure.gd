class_name FighterFigure
extends Node3D
## Faceted procedural fighter (docs/13), using the existing move poses with articulated
## elbows and knees, planted stepping feet, skin, hair and corner-coloured gear.
## A procedural art pass before a production rig.
##
## Over the head (docs/06 §2): the move's name (coloured by phase), the delay ring
## while a call is being processed (it shrinks as the fighter gets to it), "nah" when
## a call is ignored, READ while a read call is primed, and stars when rocked. The
## tell cue (D51) lights the limb that's about to go when a scouted tell shows.
## Presentation only: it reads the fight and never changes it.

## Body sizes, in metres (the cage is 9 m across, docs/01 §3).
const HIP_HEIGHT: float = 0.92
const TORSO_LENGTH: float = 0.62
const ARM_LENGTH: float = 0.55
const LEG_LENGTH: float = 0.9
const HIP_WIDTH: float = 0.13
const SHOULDER_WIDTH: float = 0.245
const OVERHEAD: float = 2.05
## Default skin fallback; corner colours are reserved for equipment.
const FACE_COLOUR := Color("#e8c4a0")
## How quickly the pose follows the move (per second; higher is snappier).
const POSE_SPEED: float = 14.0
## How far each phase of a move goes, as a share of the full extension.
const PHASE_REACH := { "telegraph": 0.3, "windup": 0.55, "active": 1.0, "recovery": 0.35 }
const PHASE_COLOURS := {
	"telegraph": Color("#ffe066"), "windup": Color("#ffa94d"), "active": Color("#ff6b6b"), "recovery": Color("#adb5bd"),
}
## Real seconds a "nah" (call ignored) stays up.
const IGNORED_SECONDS: float = 1.5
const TELL_COLOUR := Color("#fff3a0")
const RING_COLOUR := Color("#ffc94d")
const READ_COLOUR := Color("#66d9e8")
## Arm bones (D281): shoulder to elbow, and elbow to the glove's centre. An arm never stretches past
## them; a punch that has further to go turns the shoulder, leans and steps in (ArenaView.lunge_for).
const UPPER_ARM: float = 0.31
const FOREARM: float = 0.32
## Strikes that aim at the man in front (D281). limb: what throws it. point: where it lands on him
## (head, body, legs or calf). contact: the drawn centre-to-centre gap it lands at, so the view knows how
## far to step in. across: metres the contact sits toward the striking limb's side (a hook lands on the
## side of the head, a round kick on the ribs). bend: which way the elbow or knee points ("down" for a
## straight punch, "out" for a hook, "under" for an uppercut, "round" for a round kick, "up" for a teep).
## drop (if set): metres below the point it lands (the uppercut comes up under the chin, D360; was 0.8 contact).
const AIMS := {
	"jab": { "limb": "lead_arm", "point": "head", "contact": 1.0, "across": 0.0, "bend": "down" },
	"cross": { "limb": "rear_arm", "point": "head", "contact": 1.0, "across": 0.0, "bend": "down" },
	"hook": { "limb": "lead_arm", "point": "head", "contact": 0.85, "across": 0.1, "bend": "out" },
	"overhand": { "limb": "rear_arm", "point": "head", "contact": 0.95, "across": 0.06, "bend": "out" },
	"uppercut": { "limb": "rear_arm", "point": "head", "contact": 0.72, "across": 0.0, "bend": "under", "drop": 0.14 },
	"body_hook": { "limb": "lead_arm", "point": "body", "contact": 0.8, "across": 0.12, "bend": "out" },
	"short_hook": { "limb": "lead_arm", "point": "head", "contact": 0.7, "across": 0.1, "bend": "out" },
	"short_uppercut": { "limb": "rear_arm", "point": "head", "contact": 0.7, "across": 0.0, "bend": "under" },
	"elbow": { "limb": "rear_arm", "point": "head", "contact": 0.7, "across": 0.08, "bend": "out" },
	"ground_punch": { "limb": "rear_arm", "point": "head", "contact": 0.0, "across": 0.0, "bend": "down" },
	"ground_elbow": { "limb": "rear_arm", "point": "head", "contact": 0.0, "across": 0.0, "bend": "out" },
	"hammerfist": { "limb": "rear_arm", "point": "head", "contact": 0.0, "across": 0.0, "bend": "out" },
	"ground_body_punch": { "limb": "rear_arm", "point": "body", "contact": 0.0, "across": 0.06, "bend": "down" },
	"posture_bomb": { "limb": "rear_arm", "point": "head", "contact": 0.0, "across": 0.0, "bend": "down" },
	"teep": { "limb": "lead_leg", "point": "body", "contact": 1.1, "across": 0.0, "bend": "up" },
	"body_kick": { "limb": "rear_leg", "point": "body", "contact": 1.0, "across": 0.14, "bend": "round" },
	"head_kick": { "limb": "rear_leg", "point": "head", "contact": 0.9, "across": 0.14, "bend": "round" },
	"leg_kick": { "limb": "rear_leg", "point": "legs", "contact": 0.95, "across": 0.1, "bend": "round" },
	"calf_kick": { "limb": "rear_leg", "point": "calf", "contact": 0.95, "across": 0.08, "bend": "round" },
}
## How far a glove or shin stops short of the point's centre (the head, ribs or thigh is that thick).
const STANDOFF := { "head": 0.15, "body": 0.2, "legs": 0.1, "calf": 0.08 }
## A strike that misses goes this far past the side of him, and this far through (D281).
const MISS_PAST: float = 0.35
const MISS_THROUGH: float = 0.12
## Hit reactions (D281): the head snaps back and turns (radians at full), the body folds, the legs dip,
## and he is knocked back this far (metres). Full is a hit of HIT_FULL_DAMAGE or more; it fades in HIT_FADE s.
const HIT_HEAD_SNAP: float = 0.42
const HIT_HEAD_TURN: float = 0.35
const HIT_BODY_FOLD: float = 0.35
const HIT_LEG_DIP: float = 0.07
const HIT_KNOCK: float = 0.14
const HIT_FULL_DAMAGE: float = 18.0
const HIT_FADE: float = 0.3
## The support feet turn on the ball of the foot with the hips (D281): this share of the hip turn for the
## lead and rear foot, and the rear heel lifts this much (radians) per radian of turn.
const FOOT_PIVOT: Array[float] = [0.35, 0.8]
const HEEL_LIFT: float = 0.6
## Where the ball of the foot is, in front of the foot's origin (metres): the foot turns about it.
const FOOT_BALL: float = 0.09
## The labels over his head sit this far (metres) above it, wherever his head is (D281).
const LABEL_ABOVE_HEAD: float = 0.5
## Clinch grips you can see (D282): where each hand sits on the other man, in metres from the middle of his
## chest: x out to the side the arm is on, y up, z round behind his back. "under": the underhook, under his
## arm to the shoulder blade; "over": the overhook, over his arm, clamping it at the triceps; "lock": the body
## lock, both hands locked at the small of his back; "collar": the collar tie, behind his head (from his head);
## "elbow": on his elbow, where a strip pushes it off.
const GRIP_HANDS := {
	"under": Vector3(0.09, 0.08, 0.17),
	"over": Vector3(0.2, 0.04, 0.03),
	"lock": Vector3(0.03, -0.14, 0.19),
	"collar": Vector3(0.04, -0.06, 0.07),
	"elbow": Vector3(0.21, -0.14, -0.06),
}
## Moves that aren't strikes but move smoothly through their phases like one (D282), not in steps.
const SMOOTH_MOVES: Array[String] = ["pummel", "strip_grip", "collar_tie", "fence_drive", "turn_him", "spin_off",
	"ground_cover", "turn_away", "guillotine", "triangle", "armbar", "rear_naked_choke", "arm_triangle", "ankle_lock",
	"kneebar", "heel_hook", "bridge", "escape_back", "recover_guard", "sweep", "guard_pass", "take_mount", "take_back",
	"scramble", "follow_down", "foot_sweep", "hip_throw", "outside_trip", "guard_pull", "wrist_control", "dig_underhook",
	"posture_up", "crossface", "frame", "flatten", "take_crucifix", "escape_crucifix", "two_on_one", "strip_hands"]
## Wind-ups that read (D360). Standing, a strike's telegraph shows a tell and its wind-up travels out over its
## whole length instead of snapping out at the end. TELLS: each strike's tell at full size, pose keys added to
## today's pose (radians and metres; a punch's twist loads against the way it turns him when thrown, a kick's
## opens the hips the way it goes). Its size is the telegraph the sim gave him over the move's own (quicker men, kickers and the second
## shot of a combination show less), between TELL_SIZE_MIN and TELL_SIZE_MAX.
const TELLS := {
	"jab": { "twist": -0.08, "hip_y": -0.02, "lean": -0.06, "arm_lead": -0.15 },
	"cross": { "twist": 0.2, "hip_y": -0.03, "arm_rear": -0.1 },
	"overhand": { "twist": 0.28, "hip_y": -0.05, "arm_rear": 0.35, "lean": 0.08 },
	"hook": { "twist": -0.22, "hip_y": -0.03, "arm_lead": -0.2 },
	"uppercut": { "twist": -0.12, "hip_y": -0.09, "lean": -0.12, "arm_rear": -0.75, "reach_rear": -0.2 },
	"body_hook": { "twist": -0.18, "hip_y": -0.08, "arm_lead": -0.25 },
	"body_kick": { "twist": 0.22, "lean": 0.06, "arm_rear": -0.3 },
	"head_kick": { "twist": 0.26, "lean": 0.1, "arm_rear": -0.3 },
	"leg_kick": { "twist": 0.18, "arm_rear": -0.2 },
	"calf_kick": { "twist": 0.12, "arm_rear": -0.15 },
	"teep": { "lean": 0.1, "hip_y": -0.02 },
}
const TELL_SIZE_MIN: float = 0.35
const TELL_SIZE_MAX: float = 1.25
## Kicks chamber (D360): the knee comes up with the shin folded before the leg goes out, and back through it on
## the way down. How high the knee comes up (radians forward of hanging), and the share of the wind-up spent
## chambering before the leg starts out (KICK_CHAMBER_SHARE) and lifting the knee (KICK_LIFT_SHARE).
const KICK_CHAMBER := { "body_kick": 1.3, "head_kick": 1.6, "leg_kick": 0.95, "calf_kick": 0.75, "teep": 1.45 }
const KICK_CHAMBER_SHARE: float = 0.35
const KICK_LIFT_SHARE: float = 0.45
## How much of the chamber the leg comes back through in the recovery.
const KICK_RECHAMBER: float = 0.7
## The kicking side's arm swings down and back as the kick goes out (radians off its guard at full extension).
const KICK_ARM_SWING: float = -1.1
## How tall he kneels when he postures up out of the guard for the bomb (D282): hip height, metres.
const POSTURE_HIP: float = 0.68
## How quickly a gripping hand follows a grip changing (per second).
const GRIP_EASE: float = 18.0
## A pummel's hand dips this far under his arm on the way in (metres, at the middle of the swim).
const PUMMEL_DIP: float = 0.14
## A strip pushes his elbow this far out to the side (metres).
const STRIP_PUSH: float = 0.1

var colour: Color
## Overhead labels and marks are sized in metres; the view shrinks them as the camera moves in.
var label_scale: float = 1.0
## Lead side: -1 (left, orthodox) or +1 (southpaw), along the figure's own x.
var lead: float = -1.0

var _hips: Node3D
var _torso: MeshInstance3D
var _head: MeshInstance3D
var _arms: Array[Node3D] = []  # [lead, rear] shoulder pivots
var _legs: Array[Node3D] = []  # [lead, rear] hip pivots
var _arm_meshes: Array[Node3D] = []  # arm pivots at the shoulder (stretch from there)
var _leg_meshes: Array[Node3D] = []  # leg pivots at the hip
var _gloves: Array[Node3D] = []  # [lead, rear], at the end of each arm
var _feet: Array[Node3D] = []  # [lead, rear], at the end of each leg, toes forward
var _move_label: Label3D
var _call_label: Label3D
var _ring: MeshInstance3D
var _stars: Node3D
var _tell: MeshInstance3D
var _tell_label: Label3D
var _skin := FACE_COLOUR
var _appearance: int = 0
var _upper_arms: Array[MeshInstance3D] = []
var _forearms: Array[MeshInstance3D] = []
var _cut: MeshInstance3D
var _bruise: MeshInstance3D
var motion := FighterMotion.new()
var _thighs: Array[Node3D] = []
var _shins: Array[Node3D] = []
var _motion_delta: float = 0.0
var _motion_clock: float = 0.0
var _seen_tick: int = -1
var _tick_fraction: float = 0.0
var _clinch_grip: bool = false
## What each hand [lead, rear] is doing on him in the clinch (D282): "" (hand fighting on his arm), "under",
## "over", "lock" or "collar"; and the grip move one hand is making: {arm, move ("pummel"/"strip"), amount}.
var _grip_hands: Array[String] = ["", ""]
var _grip_move := {}
## Which of his own arms the striking move uses, so the other hand keeps its grip (D282): -1 none.
var _striking_arm: int = -1
## Where each gripping hand sits, in the other man's chest frame, eased so a grip changing hands doesn't jump.
var _grip_at: Array[Vector3] = [Vector3.INF, Vector3.INF]
var _body_material: StandardMaterial3D
var _pose := {}
var _ignored_left: float = 0.0
var _time: float = 0.0
## The other man, whose head, body and legs strikes aim at (D281); set by the view. Null: no aiming.
var opponent: FighterFigure
## A skinned body (D285) drawn instead of the faceted pieces, posed from them every frame; null draws the pieces.
var body: SkinnedBody
## How high the pieces' ankle sits over the sole (the foot is drawn 0.065 below and the ball 0.032 up).
const BODY_ANKLE_UP: float = 0.097
## Which way the overhead labels lean so the two don't overlap (-1 left, 0 centred, +1 right on screen).
var label_side: float = 0.0
## How far a hit knocks him back right now (metres); the view draws him that far away from the hitter.
var knock: float = 0.0
var _hit := { "head": 0.0, "body": 0.0, "legs": 0.0, "guard": 0.0 }
var _hit_turn: float = 0.0
## What became of the strike he is throwing (D281): "" (not known yet), "landed", "covered", "missed",
## "short" or "checked"; and how far the aim has moved off him for a miss (0 to 1).
var _outcome: String = ""
var _outcome_action: String = ""
var _miss: float = 0.0


func _init(p_colour: Color = Color.WHITE, southpaw: bool = false, appearance: int = 0) -> void:
	colour = p_colour
	lead = 1.0 if southpaw else -1.0
	_appearance = appearance
	_skin = Color("#bd9274") if appearance == 0 else Color("#80573e")
	_body_material = _material(_skin)
	_build()
	_pose = _rest_pose()


## Puts the figure where the fighter is, facing `toward`, posed for what they're doing.
## `delta` is real seconds for smoothing; `motion_delta` follows fight speed, including pause.
func show_state(sim: FightSim, i: int, at: Vector2, toward: Vector2, delta: float, motion_delta: float = -1.0) -> void:
	_motion_delta = delta if motion_delta < 0.0 else motion_delta
	_motion_clock += _motion_delta
	if sim.now != _seen_tick:
		_seen_tick = sim.now
		_tick_fraction = 0.0
	else:
		_tick_fraction = minf(0.99, _tick_fraction + _motion_delta * FightClock.TICKS_PER_SECOND)
	_time += delta
	for part: String in _hit:
		_hit[part] = maxf(0.0, float(_hit[part]) - _motion_delta / HIT_FADE)
	knock = maxf(0.0, knock - _motion_delta * HIT_KNOCK / HIT_FADE)
	var f: FighterState = sim.fighters[i]
	if f.action_id != _outcome_action:
		_outcome = ""
		_outcome_action = f.action_id
	_miss = move_toward(_miss, 1.0 if _outcome == "missed" else 0.0, _motion_delta * 10.0)
	_clinch_grip = sim.situation.position == PositionLibrary.CLINCH and sim.hold().is_empty() and f.tied_up_ticks == 0
	var limb: String = limb_for(f.action_id)
	_striking_arm = 0 if limb == "lead_arm" else (1 if limb == "rear_arm" else -1)
	_read_grips(sim, i)
	position = Vector3(at.x, 0.0, at.y)
	var facing: Vector2 = toward - at
	if facing.length() > 0.01:
		rotation.y = atan2(-facing.x, -facing.y)
	var target: Dictionary = pose_for(sim, i, _tick_fraction)
	var response: float = 45.0 if f.phase == "active" or f.phase == "windup" else POSE_SPEED
	var k: float = 1.0 - exp(-response * delta)
	for key: String in target:
		_pose[key] = lerpf(float(_pose.get(key, target[key])), float(target[key]), k)
	_apply_pose(f)
	if body != null:
		body.follow_joints(body_pose())
	_show_overhead(sim, i, delta)
	_place_overhead()


## Draws the skinned body at `path` (D285; SkinnedBody) instead of the faceted pieces. The pieces still pose
## every frame (strikes aim, grips and tells read them) but aren't drawn; the body follows their joints. False
## (and the pieces stay) if the body can't be loaded.
func use_body(path: String) -> bool:
	var skinned := SkinnedBody.new()
	add_child(skinned)
	var shoulders: float = _arm_meshes[0].global_position.y - global_position.y
	if not skinned.load_body(path, shoulders):
		skinned.queue_free()
		return false
	body = skinned
	body.set_colour(colour)
	for found: Node in _hips.find_children("*", "GeometryInstance3D", true, false):
		if found != _tell and not _tell.is_ancestor_of(found):
			var piece: GeometryInstance3D = found
			piece.layers = 0  # Not drawn by any camera or light, whatever the posing does to `visible`.
	return true


## Which side of his body arm `arm` (0 lead, 1 rear) is on: "l" or "r".
func arm_letter(arm: int) -> String:
	return "l" if (lead if arm == 0 else -lead) < 0.0 else "r"


## The pieces' joints in the world, for the skinned body (SkinnedBody.follow_joints).
func body_pose() -> Dictionary:
	var pose := {
		"pelvis_at": _hips.global_position, "pelvis": _hips.global_basis.orthonormalized(),
		"chest": _torso.global_basis.orthonormalized(), "neck": _torso.global_basis.orthonormalized(),
		"head": _head.global_basis.orthonormalized(), "ankle_up": BODY_ANKLE_UP,
		"shoulders_at": (_arm_meshes[0].global_position + _arm_meshes[1].global_position) / 2.0,
	}
	for i in 2:
		var side: String = arm_letter(i)
		pose["shoulder_" + side] = _arm_meshes[i].global_position
		pose["elbow_" + side] = _upper_arms[i].global_transform * Vector3(0, -1, 0)
		pose["wrist_" + side] = _gloves[i].global_position
		pose["hip_" + side] = _leg_meshes[i].global_position
		pose["knee_" + side] = _thighs[i].global_transform * Vector3(0, -FighterMotion.THIGH, 0)
		pose["ankle_" + side] = _shins[i].global_transform * Vector3(0, -FighterMotion.SHIN, 0)
		pose["foot_" + side] = _feet[i].global_basis.orthonormalized()
	return pose


## The pose (joint angles and heights) for fighter i right now: plain numbers, so it can be tested.
## Keys: hip_y, lean (radians, forward is negative), lie (0 standing, 1 flat on the back),
## arm_lead/arm_rear and leg_lead/leg_rear (radians forward from hanging down),
## reach_lead/reach_rear (arm stretch, 1 = normal), spread (legs apart, radians each way),
## kneel (0 to 1: knees on the mat, shins folded behind).
func pose_for(sim: FightSim, i: int, fractional_tick: float = 0.0) -> Dictionary:
	var f: FighterState = sim.fighters[i]
	var p: Dictionary = _rest_pose()
	var role: String = sim.situation.role(i)
	var where: String = sim.situation.position
	var hold: Dictionary = sim.hold()
	if not hold.is_empty():
		role = String(hold.from_roles[i])  # In a submission (D126): posed as where it was locked from.
		where = String(hold.from)
	if f.is_down() or role == PositionLibrary.BOTTOM:
		p.lie = 1.0
		p.hip_y = 0.22
		p.arm_lead = 2.4
		p.arm_rear = 2.4
		p.leg_lead = 0.4
		p.leg_rear = 0.4
		if role == PositionLibrary.BOTTOM and not f.is_down():
			match where:  # D210: what his legs and hands are doing underneath.
				"full_guard":  # Legs up and wrapped round his waist.
					p.leg_lead = 1.0
					p.leg_rear = 1.0
					p.spread = 0.5
				"half_guard":  # One leg hooked over his, the other flat under it.
					p.leg_lead = 0.9
					p.leg_rear = 0.1
					p.spread = 0.35
				"side_control":  # Flat, knees bent, hands framing on his neck and hip.
					p.leg_lead = 0.55
					p.leg_rear = 0.25
					p.arm_lead = 1.6
					p.arm_rear = 2.0
				"mount":  # Pinned flat, hands pushing on his hips.
					p.leg_lead = 0.15
					p.leg_rear = 0.15
					p.arm_lead = 1.3
					p.arm_rear = 1.3
				"crucifix":  # Flat on his back, both arms stretched out and trapped, legs kicking (D264).
					p.leg_lead = 0.5
					p.leg_rear = 0.3
					p.arm_lead = 2.9
					p.arm_rear = 2.9
					p.spread = 0.3
				"back_control":  # Sat up with him behind (D130), legs out in front.
					p.lie = 0.25
					p.hip_y = 0.3
					p.leg_lead = 1.1
					p.leg_rear = 1.1
					p.spread = 0.15
					p.arm_lead = 2.3
					p.arm_rear = 2.3
					p.reach_lead = 0.75
					p.reach_rear = 0.75
	elif f.liver_ticks > 0:
		# A liver shot taking him (D143): bent over it, hands dropped to the body.
		p.hip_y = HIP_HEIGHT * 0.85
		p.lean = -0.9
		p.arm_lead = 0.7
		p.arm_rear = 0.7
	elif role == PositionLibrary.TOP:
		p.hip_y = 0.6
		p.lean = -0.75
		p.leg_lead = 0.9
		p.leg_rear = 0.9
		p.arm_lead = 1.2
		p.arm_rear = 1.2
		p.kneel = 1.0
		match where:  # D130, D210: on his knees in the guard, sat up on the chest, flat across it, or behind with the hooks in.
			"half_guard":  # Chest down on his, the free leg back, the other caught between his.
				p.lean = -1.1
				p.hip_y = 0.5
				p.leg_lead = 0.1
				p.leg_rear = 1.1
				p.spread = 0.2
			"mount":  # Sat on his belly, knees either side of him.
				p.hip_y = 0.55
				p.lean = -0.25
				p.leg_lead = 0.2
				p.leg_rear = 0.2
				p.spread = 0.75
			"side_control":  # Chest across his chest, knees by his hip.
				p.hip_y = 0.4
				p.lean = -1.3
				p.leg_lead = 0.6
				p.leg_rear = 0.6
				p.spread = 0.25
			"crucifix":  # Chest across his chest from the head side, his near arm between the knees, one hand free (D264).
				p.hip_y = 0.42
				p.lean = -1.25
				p.leg_lead = 1.2
				p.leg_rear = 0.5
				p.spread = 0.2
				p.arm_lead = 1.5
				p.arm_rear = 0.9
			"back_control":  # Sat behind him, legs round his waist, arms round his neck.
				p.hip_y = 0.32
				p.lean = 0.15
				p.kneel = 0.0
				p.leg_lead = 1.45
				p.leg_rear = 1.45
				p.spread = 0.4
				p.arm_lead = 1.9
				p.arm_rear = 1.7
				p.reach_lead = 0.8
				p.reach_rear = 0.8
		if f.tied_up_ticks > 0:  # Pulled down into the guard (D121).
			p.lean = -1.1
			p.arm_lead = 0.6
			p.arm_rear = 0.6
	elif sim.situation.position == PositionLibrary.SCRAMBLE:
		p.hip_y = 0.6
		p.lean = -0.6
		p.leg_lead = 0.9
		p.leg_rear = 0.5
		p.kneel = 1.0
	elif not hold.is_empty():
		p.lean = -0.9 if int(hold.attacker) != i else -0.3  # The guillotine: head trapped under the arm.
		p.arm_lead = 1.75
		p.arm_rear = 1.75
	elif sim.situation.position == PositionLibrary.CLINCH:
		p.lean = -0.3
		p.arm_lead = 1.75
		p.arm_rear = 1.75
		p.reach_lead = 1.2
		p.reach_rear = 1.2
		if f.tied_up_ticks > 0:  # Head pulled down in a collar tie (D129).
			p.lean = -0.8
		elif sim.fighters[1 - i].tied_up_ticks > 0:  # Holding the collar tie: hands behind his head.
			p.arm_lead = 2.1
			p.arm_rear = 2.1
	elif sim.situation.is_standing() and f.bit_ticks > 0:  # Bit on a feint (D131): hands up, weight back.
		p.arm_lead = 2.4
		p.arm_rear = 2.4
		p.lean = 0.25
	if not hold.is_empty() and ActionLibrary.is_leg_lock(sim.actions.get_action(hold.action_id)):
		# A leg lock (D132): the attacker lies back with the leg clamped, the defender's leg out straight.
		if int(hold.attacker) == i:
			p.lie = 1.0
			p.hip_y = 0.22
			p.leg_lead = 1.3
			p.leg_rear = 1.3
			p.arm_lead = 1.2
			p.arm_rear = 1.2
		else:  # Sat back on the mat with the caught leg out straight, reaching for it (D282; was kneeling up).
			p.lie = 0.3
			p.hip_y = 0.28
			p.kneel = 0.0
			p.lean = 0.2
			p.leg_lead = 1.45
			p.leg_rear = 1.0
			p.spread = 0.2
			p.arm_lead = 1.2
			p.arm_rear = 1.2
	elif not hold.is_empty():  # Held in a choke or an arm lock (D282).
		_sub_pose(p, String(hold.action_id), int(hold.attacker) == i, 1.0)
	if f.action_id == "" or not sim.actions.has(f.action_id):
		return p
	var reach: float = float(PHASE_REACH.get(f.phase, 0.0))
	var action: Dictionary = sim.actions.get_action(f.action_id)
	if action.category == "strike" or SMOOTH_MOVES.has(f.action_id):
		reach = move_reach(sim, f, fractional_tick)
	var shape: Dictionary = {}
	if TELLS.has(f.action_id) and sim.situation.is_standing():
		shape = strike_shape(sim, f, fractional_tick)
		reach = float(shape.reach)
	match f.action_id:
		"jab":
			p.twist = 0.12 * reach
			p.lean = lerpf(p.lean, -0.14, reach)
			p.arm_lead = lerpf(p.arm_lead, 1.57, reach)
			p.reach_lead = lerpf(1.0, 1.45, reach)
		"cross":
			p.twist = -0.32 * reach
			p.arm_rear = lerpf(p.arm_rear, 1.57, reach)
			p.reach_rear = lerpf(1.0, 1.5, reach)
			p.lean = lerpf(p.lean, -0.2, reach)
		"hook":
			p.arm_lead = lerpf(p.arm_lead, 1.7, reach)
			p.reach_lead = lerpf(1.0, 1.2, reach)
			p.twist = lerpf(0.0, 0.5, reach)
		"uppercut":  # Dips (its tell, D360), then drives up off the legs with the rear hand up the middle.
			p.arm_rear = lerpf(p.arm_rear, 1.3, reach)
			p.reach_rear = lerpf(1.0, 1.2, reach)
			p.hip_y = lerpf(p.hip_y, HIP_HEIGHT - 0.03, reach)
			p.lean = lerpf(p.lean, 0.04, reach)
			p.twist = lerpf(0.0, 0.3, reach)
		"overhand":  # The rear hand loops over the top, leaning in behind it.
			p.arm_rear = lerpf(p.arm_rear, 2.0, reach)
			p.reach_rear = lerpf(1.0, 1.45, reach)
			p.lean = lerpf(p.lean, 0.3, reach)
			p.twist = lerpf(0.0, 0.4, reach)
		"body_hook":  # The lead hook, dropped to the ribs.
			p.arm_lead = lerpf(p.arm_lead, 1.4, reach)
			p.reach_lead = lerpf(1.0, 1.15, reach)
			p.hip_y = lerpf(p.hip_y, HIP_HEIGHT - 0.12, reach)
			p.twist = lerpf(0.0, 0.5, reach)
		"short_uppercut":  # Up the middle from chest to chest.
			p.arm_rear = lerpf(p.arm_rear, 1.1, reach)
			p.reach_rear = lerpf(1.0, 0.9, reach)
			p.twist = lerpf(0.0, 0.25, reach)
		"short_hook":
			p.arm_lead = lerpf(p.arm_lead, 1.6, reach)
			p.reach_lead = lerpf(1.0, 0.9, reach)
			p.twist = lerpf(0.0, 0.4, reach)
		"elbow":
			p.arm_rear = lerpf(p.arm_rear, 1.8, reach)
			p.reach_rear = lerpf(1.0, 0.9, reach)
			p.twist = lerpf(0.0, 0.5, reach)
		"leg_kick":
			p.leg_rear = lerpf(0.0, 0.9, reach)
			p.twist = lerpf(0.0, 0.7, reach)
		"soccer_kick":  # A punt at the head of a man on the floor (PRIDE, D141).
			p.leg_rear = lerpf(0.0, 1.1, reach)
			p.lean = lerpf(p.lean, 0.35, reach)
			p.twist = lerpf(0.0, 0.2, reach)
		"stomp":  # The knee comes up, then the heel drives down.
			p.leg_lead = lerpf(0.0, 1.2 if f.phase == "telegraph" or f.phase == "windup" else 0.4, reach)
			p.knee_short = reach
		"ground_knee":  # From side control, into the body or (PRIDE) the head.
			p.leg_rear = lerpf(p.leg_rear, 1.4, reach)
			p.knee_short = reach
		"calf_kick":  # Lower and shorter than the leg kick.
			p.leg_rear = lerpf(0.0, 0.6, reach)
			p.twist = lerpf(0.0, 0.3, reach)
		"body_kick":
			p.leg_rear = lerpf(0.0, 1.45, reach)
			p.twist = lerpf(0.0, 1.0, reach)
			p.lean = lerpf(p.lean, 0.25, reach)
		"head_kick":
			p.leg_rear = lerpf(0.0, 2.1, reach)
			p.twist = lerpf(0.0, 1.1, reach)
			p.lean = lerpf(p.lean, 0.4, reach)
		"teep":
			p.leg_lead = lerpf(0.0, 1.5, reach)
			p.lean = lerpf(p.lean, 0.2, reach)
		"knee":
			p.leg_rear = lerpf(p.leg_rear, 1.6, reach)
			p.knee_short = reach
		"double_leg", "catch_kick_single":
			p.hip_y = lerpf(p.hip_y, 0.5, reach)
			p.lean = lerpf(p.lean, -0.95, reach)
			p.arm_lead = lerpf(p.arm_lead, 1.5, reach)
			p.arm_rear = lerpf(p.arm_rear, 1.5, reach)
			p.leg_lead = lerpf(p.leg_lead, 0.8, reach)
		"sprawl":
			p.hip_y = lerpf(p.hip_y, 0.35, reach)
			p.lean = lerpf(p.lean, -1.25, reach)
			p.leg_lead = lerpf(p.leg_lead, -0.9, reach)
			p.leg_rear = lerpf(p.leg_rear, -1.0, reach)
		"feint":  # Half a jab and a dip of the level (D131).
			p.arm_lead = lerpf(p.arm_lead, 1.2, reach)
			p.hip_y = lerpf(p.hip_y, HIP_HEIGHT - 0.1, reach)
			p.lean = lerpf(p.lean, -0.25, reach)
		"stance_shift":
			p.hip_y = lerpf(p.hip_y, 0.75, maxf(reach, 0.6))
			p.lean = lerpf(p.lean, -0.3, maxf(reach, 0.6))
		"clinch_entry":
			p.arm_lead = lerpf(p.arm_lead, 1.7, reach)
			p.arm_rear = lerpf(p.arm_rear, 1.7, reach)
			p.reach_lead = lerpf(1.0, 1.3, reach)
			p.reach_rear = lerpf(1.0, 1.3, reach)
			p.lean = lerpf(p.lean, -0.35, reach)
		"clinch_break":
			p.arm_lead = lerpf(p.arm_lead, 1.4, reach)
			p.arm_rear = lerpf(p.arm_rear, 1.4, reach)
			p.lean = lerpf(p.lean, 0.3, reach)
		"get_up":
			p.lie = lerpf(p.lie, 0.0, reach)
			p.hip_y = lerpf(p.hip_y, HIP_HEIGHT, reach)
		"stand_up":  # Off his knees and up out of it, weight back off the man underneath (D330).
			_ease(p, "kneel", 0.0, reach)
			_ease(p, "lie", 0.0, reach)
			_ease(p, "hip_y", HIP_HEIGHT - 0.1, reach)
			_ease(p, "lean", 0.15, reach)
		"up_kick":  # Flat on his back, the lead heel driven up at the man standing over him (D333).
			_ease(p, "leg_lead", 2.3, reach)
			_ease(p, "leg_rear", 0.6, reach)
			_ease(p, "hip_y", p.hip_y + 0.08, reach)
		"ground_punch":  # Postures up, then drives the rear hand down (D121).
			p.lean = lerpf(p.lean, -0.4, reach)
			p.arm_rear = lerpf(p.arm_rear, 0.5, reach)
			p.reach_rear = lerpf(1.0, 1.35, reach)
		"ground_elbow":
			p.lean = lerpf(p.lean, -0.35, reach)
			p.arm_rear = lerpf(p.arm_rear, 2.7 if f.phase == "telegraph" or f.phase == "windup" else 0.5, reach)
		"hammerfist":  # The rear fist up by the ear, then the bottom of it dropped on his head (D270, D282).
			p.lean = lerpf(p.lean, -0.45, reach)
			p.arm_rear = lerpf(p.arm_rear, 2.9 if f.phase == "telegraph" or f.phase == "windup" else 0.6, reach)
		"ground_body_punch":  # Leans down low and digs the rear hand into his ribs (D270, D282).
			p.lean = lerpf(p.lean, -1.0, reach)
			p.hip_y = lerpf(p.hip_y, p.hip_y - 0.06, reach)
			p.arm_rear = lerpf(p.arm_rear, 0.8, reach)
		"posture_bomb":  # Sits up tall out of his guard with the hand cocked high, then drops it all on him (D270, D282).
			if f.phase == "telegraph" or f.phase == "windup":
				p.lean = 0.05
				p.hip_y = POSTURE_HIP
				p.arm_rear = lerpf(p.arm_rear, 3.0, maxf(reach, 0.5))
			else:
				p.lean = lerpf(p.lean, -0.7, reach)
				p.arm_rear = lerpf(p.arm_rear, 0.5, reach)
		"ground_cover":  # Forearms over his face, elbows in (D270, D282).
			p.cover = reach
		"turn_away":  # Rolls onto his front, away from the punches, giving up his back (D270, D282).
			p.roll = 2.0 * lead * reach
			p.arm_lead = lerpf(p.arm_lead, 2.9, reach)
			p.arm_rear = lerpf(p.arm_rear, 2.9, reach)
		"pummel", "strip_grip":  # The shoulder dips into the swim or the shove (D261, D282); the hand is placed by the grip.
			p.lean = lerpf(p.lean, -0.42, reach)
			p.hip_y = lerpf(p.hip_y, HIP_HEIGHT - 0.12, reach)
			p.twist = lerpf(0.0, 0.18, reach)
		"fence_drive":  # Head in his chest, hips low, driving off the back foot (D220, D282).
			p.lean = lerpf(p.lean, -0.5, reach)
			p.hip_y = lerpf(p.hip_y, HIP_HEIGHT - 0.12, reach)
			p.leg_rear = lerpf(p.leg_rear, -0.4, reach)
		"turn_him", "spin_off":  # The hips turn the corner, his way or out of it (D220, D282).
			p.twist = lerpf(0.0, 0.75 if f.action_id == "turn_him" else -0.75, reach)
			p.lean = lerpf(p.lean, -0.4, reach)
			p.hip_y = lerpf(p.hip_y, HIP_HEIGHT - 0.1, reach)
		"collar_tie":  # Both hands go up to the back of his head (D129, D282); the hands are placed by the grip.
			p.lean = lerpf(p.lean, -0.2, reach)
		"guillotine", "triangle", "armbar", "rear_naked_choke", "arm_triangle":  # Going for the hold (D126, D130, D282).
			_sub_pose(p, f.action_id, true, reach)
		"ankle_lock", "kneebar", "heel_hook":  # Sitting back onto the leg (D132, D282).
			_ease(p, "lie", 1.0, reach)
			_ease(p, "hip_y", 0.22, reach)
			_ease(p, "leg_lead", 1.3, reach)
			_ease(p, "leg_rear", 1.3, reach)
			_ease(p, "arm_lead", 1.2, reach)
			_ease(p, "arm_rear", 1.2, reach)
		"bridge":  # Feet planted, hips thrown up, rolling him off to one side (D130, D282).
			_ease(p, "hip_y", 0.42, reach)
			_ease(p, "leg_lead", 0.75, reach)
			_ease(p, "leg_rear", 0.75, reach)
			p.roll = 0.5 * lead * reach
		"escape_back":  # Turning in to face him, peeling the hands off his neck (D130, D282).
			p.twist = lerpf(0.0, -0.8, reach)
			_ease(p, "arm_lead", 2.6, reach)
			_ease(p, "arm_rear", 2.6, reach)
		"recover_guard":  # Onto his hip, a knee back in between them (D130, D282).
			_ease(p, "leg_lead", 1.4, reach)
			_ease(p, "leg_rear", 1.1, reach)
			p.roll = 0.6 * lead * reach
		"sweep":  # A leg hooks under and kicks him over, rolling with him (D128, D282).
			_ease(p, "leg_lead", 1.75, reach)
			_ease(p, "leg_rear", 0.6, reach)
			_ease(p, "arm_lead", 2.6, reach)
			p.roll = 1.0 * lead * reach
		"guard_pass":  # Hips up and back, knee cutting across the legs (D130, D282).
			_ease(p, "hip_y", p.hip_y + 0.15, reach)
			_ease(p, "lean", -0.9, reach)
			_ease(p, "leg_rear", -0.3, reach)
			p.twist = lerpf(0.0, 0.6, reach)
		"take_mount":  # The knee slides over his belly (D130, D282).
			_ease(p, "leg_lead", 1.6, reach)
			_ease(p, "spread", 0.6, reach)
			_ease(p, "hip_y", p.hip_y + 0.1, reach)
			_ease(p, "lean", -0.7, reach)
		"take_back":  # Swinging round behind him (D130, D282).
			p.twist = lerpf(0.0, 1.0, reach)
			_ease(p, "leg_lead", 1.3, reach)
			_ease(p, "lean", -0.6, reach)
		"scramble":  # Hips turning, fighting to come up on top (D108, D282).
			p.twist = lerpf(0.0, 0.6, reach)
			_ease(p, "hip_y", 0.75, reach)
			_ease(p, "lean", -0.5, reach)
		"follow_down":  # Dropping onto the man on the floor (D142, D282).
			_ease(p, "hip_y", 0.55, reach)
			_ease(p, "lean", -0.9, reach)
			_ease(p, "kneel", 1.0, reach)
			_ease(p, "arm_lead", 1.2, reach)
			_ease(p, "arm_rear", 1.2, reach)
		"foot_sweep":  # The lead foot sweeps his across while the hands pull him the other way (D128, D282).
			_ease(p, "leg_lead", 0.55, reach)
			_ease(p, "arm_lead", 1.6, reach)
			_ease(p, "arm_rear", 1.6, reach)
			p.twist = lerpf(0.0, -0.5, reach)
		"hip_throw":  # Hips in low and across, turning him over the hip (D128, D282).
			p.twist = lerpf(0.0, 1.3, reach)
			_ease(p, "hip_y", HIP_HEIGHT - 0.2, reach)
			_ease(p, "lean", -0.5, reach)
		"outside_trip":  # The lead leg reaps behind his while the chest drives into him (D128, D282).
			_ease(p, "leg_lead", -0.45, reach)
			_ease(p, "lean", -0.55, reach)
			p.twist = lerpf(0.0, 0.4, reach)
		"guard_pull":  # Sitting down with the legs coming up round him (D128, D282).
			_ease(p, "lie", 0.7, reach)
			_ease(p, "hip_y", 0.4, reach)
			_ease(p, "leg_lead", 1.2, reach)
			_ease(p, "leg_rear", 1.2, reach)
		"tie_up":
			p.arm_lead = lerpf(p.arm_lead, 3.0, reach)
			p.arm_rear = lerpf(p.arm_rear, 3.0, reach)
			p.reach_lead = lerpf(1.0, 1.3, reach)
			p.reach_rear = lerpf(1.0, 1.3, reach)
		"wrist_control":  # Both hands up to his wrist and pinned to the chest (D263).
			_ease(p, "arm_lead", 2.2, reach)
			_ease(p, "arm_rear", 2.2, reach)
			_ease(p, "reach_lead", 0.8, reach)
			_ease(p, "reach_rear", 0.8, reach)
		"dig_underhook":  # Onto his side, the near arm swimming in under his armpit (D263).
			_ease(p, "arm_lead", 2.6, reach)
			_ease(p, "reach_lead", 1.3, reach)
			p.roll = 0.4 * lead * reach
		"posture_up":  # Hips back and chest up out of his grips, hands on his body (D263).
			_ease(p, "lean", 0.05, reach)
			_ease(p, "hip_y", POSTURE_HIP, reach)
			_ease(p, "arm_lead", 0.6, reach)
			_ease(p, "arm_rear", 0.6, reach)
		"frame":  # A forearm into his neck, the other hand on his hip, making space (D264).
			_ease(p, "arm_lead", 2.0, reach)
			_ease(p, "reach_lead", 0.7, reach)
			_ease(p, "arm_rear", 1.4, reach)
			p.roll = 0.3 * lead * reach
		"flatten":  # Chest heavy on him, driving the framing arm down (D264).
			_ease(p, "lean", -1.0, reach)
			_ease(p, "hip_y", p.hip_y - 0.08, reach)
			_ease(p, "arm_rear", 1.2, reach)
		"take_crucifix":  # Reaching down to trap the near arm between his knees, swinging round to his head (D264).
			_ease(p, "lean", -0.8, reach)
			_ease(p, "arm_lead", 0.9, reach)
			_ease(p, "leg_lead", 1.3, reach)
			p.twist = lerpf(0.0, 0.4, reach)
		"escape_crucifix":  # Turning in towards him, dragging the trapped arm out from under his legs (D264).
			p.roll = 0.5 * lead * reach
			_ease(p, "arm_rear", 2.4, reach)
			_ease(p, "leg_lead", 0.9, reach)
		"two_on_one":  # Both hands up on the arm across his throat (D264).
			_ease(p, "arm_lead", 2.8, reach)
			_ease(p, "arm_rear", 2.8, reach)
			_ease(p, "reach_lead", 0.6, reach)
			_ease(p, "reach_rear", 0.6, reach)
		"strip_hands":  # The free hand peels his grip off the choking arm (D264).
			_ease(p, "arm_rear", 2.2, reach)
			_ease(p, "reach_rear", 1.2, reach)
			p.twist = lerpf(0.0, 0.3, reach)
		"crossface":  # The forearm drives across his face, the shoulder down on him (D263).
			_ease(p, "lean", -0.85, reach)
			_ease(p, "arm_lead", 1.4, reach)
			_ease(p, "reach_lead", 1.2, reach)
			p.twist = lerpf(0.0, -0.4, reach)
		"check_kick":  # The lead knee comes up and turns out to meet the shin (D180, D281).
			p.leg_lead = lerpf(p.leg_lead, 1.25, reach)
			p.check = reach
		"slip":  # The head drops off the line to the outside (D180, D281).
			p.slip = reach
			p.hip_y = lerpf(p.hip_y, HIP_HEIGHT - 0.14, reach)
			p.lean = lerpf(p.lean, -0.22, reach)
		"cover_up":  # Gloves to the temples, elbows in, chin down (D180, D281).
			p.cover = reach
			p.lean = lerpf(p.lean, -0.18, reach)
		_:
			if action.category == "strike":
				p.arm_lead = lerpf(p.arm_lead, 1.57, reach)
	if not shape.is_empty():
		_tell_and_chamber(p, f.action_id, shape)
	if AIMS.has(f.action_id):
		p.aim = reach
	return p


## A standing strike's shape right now (D360): {tell, chamber, reach}. tell: how much of its tell shows (0 to
## TELL_SIZE_MAX), up through the telegraph and gone as it goes out. chamber: a kick's knee up and shin folded
## (0 to 1). reach: how far out it is, over the whole wind-up (a kick's after its chamber), held through the
## active part and back over the recovery.
static func strike_shape(sim: FightSim, f: FighterState, fractional_tick: float = 0.0) -> Dictionary:
	var id: String = f.action_id
	var total: float = maxf(1.0, sim.phase_ticks(f, id, f.phase))
	var t: float = clampf((total - f.phase_ticks_left + fractional_tick) / total, 0.0, 1.0)
	var own: float = maxf(1.0, sim.actions.phase_ticks(id, "telegraph"))
	var size: float = clampf(sim.phase_ticks(f, id, "telegraph") / own, TELL_SIZE_MIN, TELL_SIZE_MAX)
	var kick: bool = KICK_CHAMBER.has(id)
	var out := { "tell": 0.0, "chamber": 0.0, "reach": 0.0 }
	match f.phase:
		"telegraph":
			out.tell = size * smoothstep(0.0, 1.0, t)
			out.reach = 0.05 * t
		"windup":
			out.tell = size * (1.0 - smoothstep(0.1, 0.7, t))
			if kick:
				var going: float = smoothstep(KICK_CHAMBER_SHARE, 1.0, t)
				out.chamber = smoothstep(0.0, KICK_LIFT_SHARE, t) * (1.0 - going)
				out.reach = lerpf(0.05, 1.0, going)
			else:
				out.reach = lerpf(0.05, 1.0, smoothstep(0.0, 1.0, t))
		"active":
			out.reach = 1.0
		"recovery":
			out.reach = 1.0 - smoothstep(0.0, 1.0, t)
			if kick:
				out.chamber = KICK_RECHAMBER * sin(PI * t)
	return out


## Adds a standing strike's tell and a kick's chamber and arm swing to pose `p` (D360; strike_shape).
static func _tell_and_chamber(p: Dictionary, id: String, shape: Dictionary) -> void:
	var tell: Dictionary = TELLS[id]
	for key: String in tell:
		p[key] = float(p[key]) + float(tell[key]) * float(shape.tell)
	if not KICK_CHAMBER.has(id):
		return
	var chamber: float = float(shape.chamber)
	if String(AIMS[id].limb) == "lead_leg":
		p.leg_lead = maxf(float(p.leg_lead), float(KICK_CHAMBER[id]) * chamber)
		p.check = maxf(float(p.check), chamber)
	else:
		p.leg_rear = maxf(float(p.leg_rear), float(KICK_CHAMBER[id]) * chamber)
		p.knee_short = maxf(float(p.knee_short), chamber)
		p.arm_rear = float(p.arm_rear) + KICK_ARM_SWING * float(shape.reach)


## How far through his move he is, as a share of full extension, moving smoothly through its phases:
## up to 0.12 in the telegraph, out to 1 through the wind-up, held through the active part, back to 0 in the recovery.
static func move_reach(sim: FightSim, f: FighterState, fractional_tick: float = 0.0) -> float:
	var total: float = maxf(1.0, sim.phase_ticks(f, f.action_id, f.phase))
	var progress: float = clampf((total - f.phase_ticks_left + fractional_tick) / total, 0, 1)
	match f.phase:
		"telegraph": return 0.12 * progress
		"windup": return lerpf(0.12, 1.0, progress * progress)
		"active": return 1.0
		"recovery": return 1.0 - smoothstep(0.0, 1.0, progress)
	return 0.0


## A choke or arm lock (D282), for the man putting it on (`attacker`) or the man in it, eased in by `amount`.
func _sub_pose(p: Dictionary, id: String, attacker: bool, amount: float) -> void:
	match id:
		"guillotine":  # The arm under his chin, the head trapped under the armpit.
			if attacker:
				_ease(p, "lean", 0.2, amount)
				_ease(p, "hip_y", HIP_HEIGHT - 0.1, amount)
				_ease(p, "arm_lead", 1.3, amount)
				_ease(p, "arm_rear", 1.5, amount)
				_ease(p, "reach_lead", 0.7, amount)
				_ease(p, "reach_rear", 0.7, amount)
			else:
				_ease(p, "lean", -0.95, amount)
				_ease(p, "arm_lead", 1.0, amount)
				_ease(p, "arm_rear", 1.0, amount)
		"triangle":  # Legs locked round his head and one arm, pulling the head down.
			if attacker:
				_ease(p, "leg_lead", 2.1, amount)
				_ease(p, "leg_rear", 1.7, amount)
				_ease(p, "spread", 0.25, amount)
				_ease(p, "arm_lead", 2.6, amount)
				_ease(p, "arm_rear", 2.6, amount)
				_ease(p, "reach_lead", 0.8, amount)
				_ease(p, "reach_rear", 0.8, amount)
			else:
				_ease(p, "lean", -1.2, amount)
				_ease(p, "arm_lead", 0.6, amount)
		"armbar":  # Falls back with both legs across him, his arm straightened against the hips.
			if attacker:
				_ease(p, "lie", 1.0, amount)
				_ease(p, "hip_y", 0.22, amount)
				_ease(p, "leg_lead", 2.0, amount)
				_ease(p, "leg_rear", 2.0, amount)
				_ease(p, "spread", 0.15, amount)
				_ease(p, "arm_lead", 2.8, amount)
				_ease(p, "arm_rear", 2.8, amount)
				_ease(p, "reach_lead", 0.7, amount)
				_ease(p, "reach_rear", 0.7, amount)
			else:
				_ease(p, "arm_lead", 1.57, amount)
				_ease(p, "reach_lead", 1.3, amount)
		"rear_naked_choke":  # One arm round the neck, the other hand behind his head; he fights the hands.
			if attacker:
				_ease(p, "arm_lead", 2.0, amount)
				_ease(p, "arm_rear", 2.5, amount)
				_ease(p, "reach_lead", 0.65, amount)
				_ease(p, "reach_rear", 0.65, amount)
				_ease(p, "lean", 0.3, amount)
			else:
				_ease(p, "arm_lead", 2.6, amount)
				_ease(p, "arm_rear", 2.6, amount)
				_ease(p, "lean", 0.1, amount)
		"arm_triangle":  # Head and arm wrapped together, chest driving down; his arm pinned up by his head.
			if attacker:
				_ease(p, "lean", -1.35, amount)
				_ease(p, "hip_y", p.hip_y - 0.05, amount)
				_ease(p, "arm_lead", 2.2, amount)
				_ease(p, "arm_rear", 2.2, amount)
				_ease(p, "reach_lead", 0.7, amount)
				_ease(p, "reach_rear", 0.7, amount)
			else:
				_ease(p, "arm_lead", 2.8, amount)


## Moves pose key `key` toward `value` by `amount` (0 leaves it, 1 sets it).
static func _ease(p: Dictionary, key: String, value: float, amount: float) -> void:
	p[key] = lerpf(float(p[key]), value, amount)


## Which body part a move is thrown with ("lead_arm", "rear_leg", "hips" …), for the tell cue.
static func limb_for(action_id: String) -> String:
	match action_id:
		"jab", "hook", "body_hook", "short_hook":
			return "lead_arm"
		"cross", "uppercut", "short_uppercut", "overhand", "elbow", "ground_punch", "ground_elbow", "hammerfist", \
				"ground_body_punch", "posture_bomb":
			return "rear_arm"
		"teep", "stomp", "up_kick":
			return "lead_leg"
		"leg_kick", "calf_kick", "soccer_kick", "ground_knee", "body_kick", "head_kick", "knee":
			return "rear_leg"
	return "hips"


## Lights up the limb a scouted tell says is coming (D51), or switches the cue off ("").
func show_tell(limb: String) -> void:
	_tell.visible = limb != ""
	_tell_label.visible = limb != ""
	if limb == "":
		return
	var at: Node3D = _hips
	var down: float = 0.0
	match limb:
		"lead_arm":
			at = _arm_meshes[0]
			down = ARM_LENGTH * 0.6
		"rear_arm":
			at = _arm_meshes[1]
			down = ARM_LENGTH * 0.6
		"lead_leg":
			at = _leg_meshes[0]
			down = LEG_LENGTH * 0.55
		"rear_leg":
			at = _leg_meshes[1]
			down = LEG_LENGTH * 0.55
	if _tell.get_parent() != at:
		_tell.reparent(at, false)
	_tell.position = Vector3(0.0, -down, 0.0)


## Shows "nah" over the fighter for a moment: they ignored a call.
func show_ignored() -> void:
	_ignored_left = IGNORED_SECONDS


func _show_overhead(sim: FightSim, i: int, delta: float) -> void:
	var f: FighterState = sim.fighters[i]
	# The move in progress, coloured by phase.
	if f.action_id != "" and sim.actions.has(f.action_id):
		_move_label.text = String(sim.actions.get_action(f.action_id).name)
		_move_label.modulate = PHASE_COLOURS.get(f.phase, Color.WHITE)
		_move_label.visible = true
	else:
		_move_label.visible = false
	# The delay ring: a call heard and not acted on yet. Shrinks as the fighter gets to it.
	var calls: LiveCalls = sim.decisions[i].calls
	var left: float = -1.0
	for heard: Dictionary in calls.pending:
		var total: float = maxf(1.0, float(heard.ready_at - heard.heard))
		left = maxf(left, clampf(float(heard.ready_at - sim.now) / total, 0.0, 1.0))
	_ring.visible = left >= 0.0
	if _ring.visible:
		var s: float = lerpf(0.35, 1.0, left)
		_ring.scale = Vector3(s, 1.0, s)
	_ignored_left = maxf(0.0, _ignored_left - delta)
	if _ignored_left > 0.0:
		_call_label.text = "nah"
		_call_label.modulate = Color("#ff8787")
		_call_label.visible = true
	elif not calls.reads.is_empty():
		_call_label.text = "READ"
		_call_label.modulate = READ_COLOUR
		_call_label.visible = true
	else:
		_call_label.visible = false
	_stars.visible = f.is_rocked() and not f.is_down()
	if _stars.visible:
		_stars.rotation.y = _time * 4.0
	if _tell.visible:
		var pulse: float = 0.6 + 0.4 * sin(_time * 12.0)
		(_tell.material_override as StandardMaterial3D).emission_energy_multiplier = 1.5 + 2.0 * pulse


func _apply_pose(f: FighterState) -> void:
	var lie: float = _pose.lie
	var breathing: float = 0.004 * sin(_motion_clock * 2.6) if lie < 0.05 and float(_pose.kneel) < 0.05 else 0.0
	_hips.position.y = float(_pose.hip_y) - 0.12 * float(_pose.kneel) + breathing \
		- (0.05 * float(_hit.body) + HIT_LEG_DIP * float(_hit.legs)) * (1.0 - lie)
	var sway: float = 0.0
	if f.is_rocked() and not f.is_down():
		sway = 0.18 * sin(_time * 7.0)
	sway -= lead * 0.5 * float(_pose.slip)
	var lean: float = float(_pose.lean) + 0.1 * float(_hit.head) - HIT_BODY_FOLD * float(_hit.body)
	_hips.rotation = Vector3(lerpf(lean, PI / 2.0, lie), _pose.twist * lead, sway)
	if absf(float(_pose.roll)) > 0.001:  # Rolling about his own spine (turning away underneath, D282).
		_hips.basis = _hips.basis * Basis(Vector3.UP, float(_pose.roll))
	_arms[0].rotation.x = _pose.arm_lead
	_arms[1].rotation.x = _pose.arm_rear
	_pose_arm(0, float(_pose.reach_lead), float(_pose.arm_lead))
	_pose_arm(1, float(_pose.reach_rear), float(_pose.arm_rear))
	_legs[0].rotation = Vector3(_pose.leg_lead, 0.0, lead * _pose.spread)
	_legs[1].rotation = Vector3(_pose.leg_rear, 0.0, -lead * _pose.spread)
	_pose_legs()
	_head.rotation.x = -HIT_HEAD_SNAP * float(_hit.head) - 0.12 * float(_hit.guard)
	_head.rotation.y = HIT_HEAD_TURN * float(_hit.head) * _hit_turn
	_cut.visible = f.hurt("head") > 0.18
	_bruise.visible = f.hurt("head") > 0.08
	_body_material.albedo_color = _skin


## A strike landed on him (D281): a short snap of the part hit, scaled by the damage, or, through
## his guard (`covered`), his gloves knocked back into his face. `from_side` is +1 or -1, the way his
## head turns. Damage cosmetics read existing damage; they never create a new simulation injury.
func show_hit(target: String, damage: float, covered: bool = false, from_side: float = 0.0) -> void:
	var amount: float = clampf(damage / HIT_FULL_DAMAGE, 0.3, 1.0)
	if covered:
		_hit.guard = 1.0
		knock = maxf(knock, HIT_KNOCK * 0.35)
		return
	var part: String = target if _hit.has(target) else "body"
	_hit[part] = maxf(float(_hit[part]), amount)
	if part == "head":
		_hit_turn = from_side
	knock = maxf(knock, HIT_KNOCK * amount)


## What became of the strike he's throwing (D281), from the fight's events: "landed", "covered" (into the
## guard), "missed" (rolled out or slipped), "short" (out of range) or "checked". The aim follows it.
func show_outcome(action_id: String, outcome: String) -> void:
	_outcome_action = action_id
	_outcome = outcome


## Reads the clinch grips for his hands (D282): which side of the clinch each of his arms is on, who has the
## inside there, and the grip move one hand is making.
func _read_grips(sim: FightSim, i: int) -> void:
	_grip_hands = ["", ""]
	_grip_move = {}
	if not _clinch_grip:
		_grip_at = [Vector3.INF, Vector3.INF]
		return
	var f: FighterState = sim.fighters[i]
	if sim.fighters[1 - i].tied_up_ticks > 0:  # Holding the collar tie (D129): both hands behind his head.
		_grip_hands = ["collar", "collar"]
		return
	var who: Array[int] = sim.grips()
	var lock: bool = who[0] == i and who[1] == i
	for side in 2:
		if who[side] == i:
			_grip_hands[grip_arm(i, side)] = "lock" if lock else "under"
		elif who[side] == 1 - i:
			_grip_hands[grip_arm(i, side)] = "over"
	if not sim.actions.has(f.action_id):
		return
	var amount: float = move_reach(sim, f, _tick_fraction)
	match f.action_id:
		"pummel", "strip_grip":  # On the side the fight will take it: where he has the inside, or a free side.
			var side: int = who.find(1 - i)
			if side < 0 and f.action_id == "pummel":
				side = who.find(FightSim.NO_GRIP)
			if side >= 0:
				_grip_move = { "arm": grip_arm(i, side), "move": "pummel" if f.action_id == "pummel" else "strip", "amount": amount }
		"collar_tie":
			_grip_move = { "arm": -1, "move": "collar", "amount": amount }


## Which of his arms (0 lead, 1 rear) is on clinch side `side` (D282): red's arm `side` meets the blue arm
## across from it, his left against the other man's right.
func grip_arm(i: int, side: int) -> int:
	if i == 0 or opponent == null or not is_instance_valid(opponent):
		return side
	var theirs: Vector3 = opponent._arm_meshes[side].global_position
	var near_lead: bool = _arm_meshes[0].global_position.distance_to(theirs) <= _arm_meshes[1].global_position.distance_to(theirs)
	return 0 if near_lead else 1


## Where a hand making grip `kind` on arm `arm`'s side sits on the other man, in the world (D282).
func grip_point(arm: int, kind: String) -> Vector3:
	var offset: Vector3 = GRIP_HANDS.get(kind, Vector3.ZERO)
	var centre: Vector3 = opponent._head.global_position if kind == "collar" else opponent._torso.global_position
	var out: Vector3 = _limb_side("lead_arm" if arm == 0 else "rear_arm")
	return centre + out * offset.x + Vector3.UP * offset.y + opponent.global_basis.z * offset.z


## Where the hand on arm `arm` goes in the clinch (D282), in the world: its grip, or `fighting` (hand
## fighting on his arm), moved along by a pummel, strip or collar tie on the way.
func _grip_target(arm: int, fighting: Vector3) -> Vector3:
	var kind: String = _grip_hands[arm]
	var base: Vector3 = fighting if kind == "" else grip_point(arm, kind)
	if _grip_move.is_empty() or (int(_grip_move.arm) != arm and int(_grip_move.arm) != -1):
		return base
	var a: float = float(_grip_move.amount)
	match String(_grip_move.move):
		"pummel":  # Swims down under his arm and up inside it.
			return base.lerp(grip_point(arm, "under"), a) + Vector3.DOWN * PUMMEL_DIP * sin(PI * a)
		"strip":  # Onto his elbow and shoves it out.
			var out: Vector3 = _limb_side("lead_arm" if arm == 0 else "rear_arm")
			return base.lerp(grip_point(arm, "elbow") + out * STRIP_PUSH * a, a)
		"collar":
			return base.lerp(grip_point(arm, "collar"), a)
	return base


## Which way his elbow points for the grip on arm `arm` (D282), in the world: down for the underhook and
## the body lock, up and out over the top for the overhook, in front of his chest for the collar tie.
func _grip_bend(arm: int) -> Vector3:
	var out: Vector3 = _limb_side("lead_arm" if arm == 0 else "rear_arm")
	match _grip_hands[arm]:
		"over":
			return out + Vector3.UP * 0.7
		"collar":
			return Vector3.DOWN - global_basis.z * 0.6
	return Vector3.DOWN + out * 0.5


## Where on him a strike to `point` (head, body, legs or calf) lands, in the world (D281).
func strike_point(point: String) -> Vector3:
	match point:
		"head":
			return _head.global_position
		"legs":  # Above the lead knee, on the thigh.
			return _shins[0].global_position + Vector3.UP * 0.14
		"calf":
			return _shins[0].global_position + Vector3.DOWN * 0.14
	return _torso.global_position + Vector3.DOWN * 0.06  # Body: the lower ribs.


## Where his nearer glove is, in the world: a strike into his guard lands there (D281).
func guard_point(from: Vector3) -> Vector3:
	var a: Vector3 = _gloves[0].global_position
	var b: Vector3 = _gloves[1].global_position
	return a if a.distance_to(from) < b.distance_to(from) else b


## The way the striking limb's side points (lead or rear), in the world.
func _limb_side(limb: String) -> Vector3:
	return global_basis.x * (lead if limb.begins_with("lead") else -lead)


## Where the move he's throwing aims, in the world, from the limb's root (shoulder or hip); Vector3.INF
## when there's nothing to aim at (no opponent, or not an aimed strike, D281).
func aim_point(action_id: String, root: Vector3) -> Vector3:
	if opponent == null or not is_instance_valid(opponent) or not AIMS.has(action_id):
		return Vector3.INF
	var aim: Dictionary = AIMS[action_id]
	var side: Vector3 = _limb_side(String(aim.limb))
	var point: Vector3 = opponent.strike_point(String(aim.point)) + side * float(aim.across)
	point.y -= float(aim.get("drop", 0.0))
	var approach: Vector3 = point - root
	approach.y *= 0.3  # Stop short of him mostly along the ground, not down through his head.
	var toward: Vector3 = approach.normalized() if approach.length() > 0.01 else -global_basis.z
	point -= toward * float(STANDOFF.get(aim.point, 0.15))
	if _outcome == "covered" and String(aim.point) == "head":  # Into his gloves.
		point = opponent.guard_point(root) - toward * 0.07
	elif _outcome == "covered":  # Into his elbow, just short of the ribs.
		point -= toward * 0.06
	elif _outcome == "checked":
		point = opponent.strike_point("legs") - toward * 0.08  # Into the raised shin.
	return point + (-side * MISS_PAST + toward * MISS_THROUGH + Vector3.UP * 0.08) * _miss  # Over his shoulder.


## Labels, the delay ring, the stars and the tell's "!" ride a set height over his head, standing or
## down, and lean apart when the view says the two would overlap (D281).
func _place_overhead() -> void:
	var head: float = maxf(_head.global_position.y - global_position.y, 0.3)
	_move_label.position.y = head + LABEL_ABOVE_HEAD
	_call_label.position.y = head + LABEL_ABOVE_HEAD + 0.3
	_ring.position.y = head + 0.25
	_stars.position.y = head + 0.2
	_tell_label.position.y = head + 0.25
	for label: Label3D in [_move_label, _call_label, _tell_label]:
		label.scale = Vector3.ONE * label_scale
	var width: float = ThemeDB.fallback_font.get_string_size(_move_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _move_label.font_size).x
	_move_label.offset.x = label_side * (width / 2.0 + 12.0)


func _pose_legs() -> void:
	var upright: bool = float(_pose.lie) < 0.1 and float(_pose.kneel) < 0.1 and float(_pose.hip_y) > 0.72
	var goals: Array[Vector3] = []
	var support: Array[bool] = []
	for i in 2:
		var lateral: float = lead if i == 0 else -lead
		goals.append(global_position + global_basis * Vector3(lateral * 0.19, 0.032, -0.22 if i == 0 else 0.22))
		var tucked: float = float(_pose.knee_short) if i == 1 else float(_pose.check)
		support.append(upright and absf(_legs[i].rotation.x) < 0.5 and tucked < 0.1)
	motion.update(goals, support, _motion_delta)
	var weight: float = 0.0
	if upright and motion.swing >= 0:
		weight = (lead if motion.swing == 1 else -lead) * 0.03
		_hips.position.y -= sin(motion.progress * PI) * 0.008
	_hips.position.x = lerpf(_hips.position.x, weight, 1.0 - exp(-12.0 * _motion_delta))
	var kick: String = _outcome_action if AIMS.has(_outcome_action) and String(AIMS[_outcome_action].limb).ends_with("_leg") else ""
	var turn: float = _hips.rotation.y
	for i in 2:
		var pivot: Node3D = _leg_meshes[i]
		var hip: Vector3 = pivot.global_position
		var foot_basis: Basis = global_basis if support[i] else pivot.global_basis.orthonormalized()
		var pole: Vector3 = _hips.global_basis * Vector3.FORWARD
		var ankle: Vector3
		var knee: Vector3
		if float(_pose.kneel) > 0.5:
			# Knees on the canvas, shins folded behind: no shortening or disappearing lower legs.
			knee = hip + global_basis * Vector3(0, 0, -0.24)
			knee.y = global_position.y + 0.075
			ankle = knee + global_basis * Vector3(0, 0, 0.40)
			ankle.y = global_position.y + 0.097
			foot_basis = global_basis
		else:
			if support[i]:
				# The foot turns on its ball with the hips, and the rear heel comes up (D281).
				var lift: float = HEEL_LIFT * absf(turn) if i == 1 else 0.0
				foot_basis = Basis(Vector3.UP, turn * FOOT_PIVOT[i]) * global_basis * Basis(Vector3.RIGHT, -minf(lift, 0.45))
				var ball: Vector3 = motion.feet[i] + global_basis * Vector3(0, 0, -FOOT_BALL)
				ankle = ball - foot_basis * Vector3(0, 0, -FOOT_BALL) + foot_basis * Vector3(0, 0.065, 0.035)
			else:
				var tucked: float = float(_pose.knee_short) if i == 1 else float(_pose.check)
				var reach: float = lerpf(0.84, 0.53, tucked)
				if float(_pose.lie) > 0.5 and _legs[i].rotation.x > 0.5:
					reach = 0.62  # Bent knees wrapping the top fighter in guard.
				ankle = pivot.to_global(Vector3(0, -reach, 0))
				if kick != "" and String(AIMS[kick].limb) == ("lead_leg" if i == 0 else "rear_leg"):
					var target: Vector3 = aim_point(kick, hip)
					var aim: float = float(_pose.aim)
					if target.is_finite():
						ankle = ankle.lerp(target, aim)
						var bend: Vector3 = Vector3.UP + global_basis.z * -0.6  # A teep: the knee up in front.
						if String(AIMS[kick].bend) == "round":  # The knee turned over toward him.
							bend = (target - hip).normalized() + Vector3.UP * 0.5 + _limb_side(String(AIMS[kick].limb)) * 0.6
						pole = pole.lerp(bend, aim)
			var solved: Array[Vector3] = FighterMotion.solve(hip, ankle, pole)
			knee = solved[0]
			ankle = solved[1]
		_bone(_thighs[i], pivot.to_local(hip), pivot.to_local(knee), FighterMotion.THIGH)
		_bone(_shins[i], pivot.to_local(knee), pivot.to_local(ankle), FighterMotion.SHIN)
		_feet[i].visible = true
		_feet[i].global_basis = foot_basis
		_feet[i].global_position = ankle - foot_basis * Vector3(0, 0.065, 0.035)


static func _bone(node: Node3D, start: Vector3, end: Vector3, length: float) -> void:
	var direction: Vector3 = end - start
	node.position = start
	node.basis = Basis(Quaternion(Vector3.DOWN, direction.normalized())).scaled_local(Vector3(1, direction.length() / length, 1))


func _pose_arm(side: int, reach: float, angle: float) -> void:
	var guard: float = clampf((angle - 1.65) * 3.0, 0.0, 1.0)
	var length: float = lerpf(ARM_LENGTH, 0.4, guard) * reach
	var hand := Vector3((-lead if side == 0 else lead) * guard * 0.105, -length + guard * 0.05, -guard * 0.13)
	var elbow := Vector3(0, -length * 0.5, lerpf(0.035, 0.25, guard) / maxf(reach, 1.0))
	var pivot: Node3D = _arm_meshes[side]
	if _clinch_grip and side != _striking_arm:
		var lateral: float = lead if side == 0 else -lead
		var undo_shoulder := Basis(Vector3.RIGHT, -angle)
		hand = undo_shoulder * Vector3(-lateral * 0.08, 0.05, -0.35)
		elbow = undo_shoulder * Vector3(lateral * 0.035, -0.25, -0.12)
		if opponent != null and is_instance_valid(opponent):  # His grip on the other man (D282).
			var frame: Transform3D = opponent._torso.global_transform.orthonormalized()
			var target: Vector3 = frame.affine_inverse() * _grip_target(side, pivot.to_global(hand))
			var k: float = 1.0 - exp(-GRIP_EASE * _motion_delta)
			_grip_at[side] = target if not _grip_at[side].is_finite() else _grip_at[side].lerp(target, k)
			hand = pivot.to_local(frame * _grip_at[side])
			if _grip_hands[side] != "":
				elbow = pivot.global_basis.inverse() * _grip_bend(side)
	hand += Vector3(0.0, 0.06, 0.08) * float(_hit.guard)  # Knocked back toward his face.
	if float(_pose.cover) > 0.0:  # Covering up: gloves to the temples, elbows in (D180).
		var lateral: float = lead if side == 0 else -lead
		var frame: Basis = global_basis if float(_pose.lie) < 0.5 else _hips.global_basis.orthonormalized()  # Lying down (D282): over his face.
		var temple: Vector3 = _head.global_position + frame * Vector3(lateral * 0.12, 0.02, -0.06)
		var tucked: Vector3 = _head.global_position + frame * Vector3(lateral * 0.1, -0.32, -0.12)
		hand = hand.lerp(pivot.to_local(temple), float(_pose.cover))
		elbow = elbow.lerp(pivot.to_local(tucked), float(_pose.cover))
	var pole: Vector3 = elbow
	var aim: float = float(_pose.aim)
	var action: String = _outcome_action
	if aim > 0.001 and AIMS.has(action) and String(AIMS[action].limb) == ("lead_arm" if side == 0 else "rear_arm"):
		var target: Vector3 = aim_point(action, pivot.global_position)
		if target.is_finite():
			hand = hand.lerp(pivot.to_local(target), aim)
			var out: Vector3 = _limb_side(String(AIMS[action].limb))
			var bend: Vector3
			match String(AIMS[action].bend):
				"out":
					bend = out + Vector3.UP * 0.25
				"under":
					bend = Vector3.DOWN + global_basis.z * 0.4
				_:
					bend = Vector3.DOWN + out * 0.6
			pole = pole.lerp(pivot.global_basis.inverse() * bend, aim)
	# Fixed bones (D281): the hand stops at full extension instead of stretching the arm.
	var joints: Array[Vector3] = FighterMotion.solve_bones(Vector3.ZERO, hand, pole, UPPER_ARM, FOREARM)
	elbow = joints[0]
	hand = joints[1]
	_segment(_upper_arms[side], Vector3.ZERO, elbow)
	_segment(_forearms[side], elbow, hand)
	_gloves[side].position = hand
	_gloves[side].basis = Basis(Quaternion(Vector3.DOWN, (hand - elbow).normalized()))


static func _segment(mesh: MeshInstance3D, start: Vector3, end: Vector3) -> void:
	var direction: Vector3 = end - start
	mesh.position = start
	mesh.basis = Basis(Quaternion(Vector3.DOWN, direction.normalized())).scaled_local(Vector3(1, direction.length(), 1))


static func _rest_pose() -> Dictionary:
	return { "hip_y": HIP_HEIGHT - 0.07, "lean": -0.08, "lie": 0.0, "twist": 0.0, "arm_lead": 2.0, "arm_rear": 1.85,
		"leg_lead": 0.22, "leg_rear": -0.25, "reach_lead": 1.0, "reach_rear": 1.0, "knee_short": 0.0,
		"spread": 0.08, "kneel": 0.0, "aim": 0.0, "check": 0.0, "slip": 0.0, "cover": 0.0, "roll": 0.0 }


func _build() -> void:
	_hips = Node3D.new()
	_hips.position.y = HIP_HEIGHT
	add_child(_hips)
	_build_anatomy()
	_build_head()
	_build_gear_and_limbs()
	_move_label = _label(44)
	_move_label.position.y = OVERHEAD + 0.32
	add_child(_move_label)
	_call_label = _label(40)
	_call_label.position.y = OVERHEAD + 0.62
	add_child(_call_label)

	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.26
	torus.outer_radius = 0.32
	_ring.mesh = torus
	var ring_material: StandardMaterial3D = _material(RING_COLOUR)
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = ring_material
	_ring.position.y = OVERHEAD
	_ring.visible = false
	add_child(_ring)

	_stars = Node3D.new()
	_stars.position.y = OVERHEAD - 0.05
	var star_material: StandardMaterial3D = _material(Color("#ffe066"))
	star_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for n in 3:
		var star := MeshInstance3D.new()
		var star_mesh := SphereMesh.new()
		star_mesh.radius = 0.05
		star_mesh.height = 0.1
		star.mesh = star_mesh
		star.material_override = star_material
		star.position = Vector3.FORWARD.rotated(Vector3.UP, n * TAU / 3.0) * 0.25
		_stars.add_child(star)
	_stars.visible = false
	add_child(_stars)

	_tell = MeshInstance3D.new()
	var glow := SphereMesh.new()
	glow.radius = 0.16
	glow.height = 0.32
	_tell.mesh = glow
	var glow_material: StandardMaterial3D = _material(TELL_COLOUR)
	glow_material.emission_enabled = true
	glow_material.emission = TELL_COLOUR
	glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_material.albedo_color.a = 0.7
	glow_material.no_depth_test = true
	_tell.material_override = glow_material
	_tell.visible = false
	_hips.add_child(_tell)
	# Shape as well as colour (colour-blind safe, docs/06 §2): a "!" over the fighter.
	_tell_label = _label(72)
	_tell_label.text = "!"
	_tell_label.modulate = TELL_COLOUR
	_tell_label.position = Vector3(0.0, OVERHEAD + 0.05, 0.0)
	_tell_label.visible = false
	add_child(_tell_label)


## The two temporary looks share animation pivots, but have different builds and facial contours.
func _build_anatomy() -> void:
	_torso = FightMesh.instance(_hips, FighterSculpt.torso(_appearance == 1), _body_material,
		Vector3(0, TORSO_LENGTH / 2.0 + 0.05, 0))
	var neck_width: float = 0.092 if _appearance == 1 else 0.079
	FightMesh.instance(_torso, FighterSculpt.contour([
		Vector4(0.28, neck_width * 1.3, 0.085, 0.09),
		Vector4(0.37, neck_width, 0.077, 0.08), Vector4(0.43, neck_width, 0.075, 0.08)
	]), _body_material)


func _build_head() -> void:
	_head = FightMesh.instance(_torso, FighterSculpt.head(_appearance == 1), _body_material, Vector3(0, 0.49, -0.015))
	_head.scale = Vector3(0.94, 0.89, 0.94)
	# The nose is the first face feature: it also makes facing direction observable in tests.
	FightMesh.instance(_head, FighterSculpt.nose(), _body_material, Vector3(0, 0.005, -0.131))
	var hair_material: StandardMaterial3D = _material(Color("#322820") if _appearance == 0 else Color("#211f20"))
	FightMesh.instance(_head, FighterSculpt.hair(_appearance == 1), hair_material)
	var beard_color: Color = _skin.lerp(hair_material.albedo_color, 0.65 if _appearance == 0 else 0.95)
	var beard_material: StandardMaterial3D = _material(beard_color)
	FightMesh.instance(_head, FighterSculpt.beard(_appearance == 1), beard_material)
	var eye_white: StandardMaterial3D = _material(Color("#aaa799"))
	var eye_dark: StandardMaterial3D = _material(Color("#252825"))
	var lip_material: StandardMaterial3D = _material(_skin.lerp(Color("#6a3d34"), 0.4))
	for side: float in [-1, 1]:
		var brow: MeshInstance3D = FightMesh.instance(_head, FighterSculpt.ellipsoid(Vector3(0.034, 0.009, 0.009)),
			hair_material, Vector3(side * 0.057, 0.057, -0.116))
		brow.rotation.z = side * 0.14
		FightMesh.instance(_head, FighterSculpt.ellipsoid(Vector3(0.021, 0.006, 0.01)), eye_white, Vector3(side * 0.057, 0.034, -0.112))
		FightMesh.instance(_head, FighterSculpt.ellipsoid(Vector3(0.009, 0.006, 0.006)), eye_dark, Vector3(side * 0.055, 0.034, -0.121))
		var ear: MeshInstance3D = FightMesh.instance(_head, FighterSculpt.ellipsoid(Vector3(0.023, 0.045, 0.026)),
			_body_material, Vector3(side * 0.131, -0.006, 0.008))
		ear.rotation.z = side * -0.12
		FightMesh.instance(ear, FighterSculpt.ellipsoid(Vector3(0.009, 0.027, 0.015)), lip_material, Vector3(side * 0.014, 0, -0.006))
		var moustache: MeshInstance3D = FightMesh.instance(_head, FighterSculpt.ellipsoid(Vector3(0.035, 0.012, 0.008)),
			beard_material, Vector3(side * 0.029, -0.054, -0.128))
		moustache.rotation.z = side * -0.16
	FightMesh.instance(_head, FighterSculpt.ellipsoid(Vector3(0.043, 0.005, 0.008)), lip_material, Vector3(0, -0.075, -0.128))
	_cut = FightMesh.instance(_head, FighterSculpt.ellipsoid(Vector3(0.026, 0.004, 0.003)),
		_material(Color("#76292c")), Vector3(-0.055, 0.068, -0.122))
	_cut.rotation.z = -0.25
	_cut.visible = false
	_bruise = FightMesh.instance(_head, FighterSculpt.ellipsoid(Vector3(0.025, 0.018, 0.003)),
		_material(_skin.lerp(Color("#66445a"), 0.45)), Vector3(0.065, -0.003, -0.117))
	_bruise.visible = false


func _build_gear_and_limbs() -> void:
	var gear: StandardMaterial3D = _material(Color("#232830"))
	var cloth: StandardMaterial3D = _material(colour.lerp(Color("#555158"), 0.22).darkened(0.13))
	var trim: StandardMaterial3D = _material(Color("#b4afa0"))
	FightMesh.instance(_hips, FighterSculpt.contour([
		Vector4(-0.16, 0.225, 0.142, 0.16), Vector4(-0.065, 0.277, 0.159, 0.17),
		Vector4(0.065, 0.20, 0.146, 0.15)
	]), cloth)
	FightMesh.instance(_hips, FighterSculpt.contour([
		Vector4(0.035, 0.219, 0.155, 0.159), Vector4(0.095, 0.198, 0.145, 0.15)
	]), gear)
	var label := Label3D.new()
	label.text = "CHIN CHECK"
	label.font = DisplayFont.font()
	label.font_size = 24
	label.pixel_size = 0.00075
	label.outline_size = 0
	label.modulate = Color("#c6c1b2")
	label.shaded = true
	label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	label.position = Vector3(0, 0.066, -0.151)
	label.rotation.y = PI
	_hips.add_child(label)
	var muscle: float = 1.09 if _appearance == 1 else 1.0
	for side: float in [lead, -lead]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(side * (SHOULDER_WIDTH + (0.017 if _appearance == 1 else 0.0)), TORSO_LENGTH / 2.0 - 0.07, 0)
		_torso.add_child(shoulder)
		FightMesh.instance(shoulder, FighterSculpt.ellipsoid(Vector3(0.106 * muscle, 0.12, 0.112)), _body_material, Vector3(0, -0.018, 0))
		var arm_pivot := Node3D.new()
		shoulder.add_child(arm_pivot)
		_arms.append(shoulder)
		_arm_meshes.append(arm_pivot)
		var upper: MeshInstance3D = FightMesh.instance(arm_pivot, FighterSculpt.contour([
			Vector4(0, 0.102 * muscle, 0.10, 0.10), Vector4(-0.28, 0.113 * muscle, 0.115, 0.11),
			Vector4(-0.6, 0.096 * muscle, 0.105, 0.09), Vector4(-1, 0.057, 0.063, 0.06)
		]), _body_material)
		var lower: MeshInstance3D = FightMesh.instance(arm_pivot, FighterSculpt.contour([
			Vector4(0, 0.058, 0.061, 0.061), Vector4(-0.25, 0.077 * muscle, 0.078, 0.07),
			Vector4(-0.55, 0.065, 0.063, 0.058), Vector4(-1, 0.043, 0.042, 0.042)
		]), _body_material)
		_upper_arms.append(upper)
		_forearms.append(lower)
		var glove: MeshInstance3D = FightMesh.instance(arm_pivot, FighterSculpt.ellipsoid(Vector3(0.067, 0.079, 0.055)), gear)
		FightMesh.instance(glove, FighterSculpt.contour([
			Vector4(0.045, 0.048, 0.045, 0.045), Vector4(0.087, 0.044, 0.041, 0.041)
		]), _material(colour.darkened(0.12)))
		FightMesh.instance(glove, FighterSculpt.ellipsoid(Vector3(0.061, 0.058, 0.022)), gear, Vector3(0, -0.012, 0.034))
		for finger in 4:
			FightMesh.instance(glove, FighterSculpt.ellipsoid(Vector3(0.013, 0.018, 0.019), 8),
				_body_material, Vector3(-0.044 + finger * 0.029, -0.058, -0.024))
		var thumb: MeshInstance3D = FightMesh.instance(glove, FighterSculpt.ellipsoid(Vector3(0.024, 0.036, 0.024)),
			_body_material, Vector3(-side * 0.061, -0.01, -0.02))
		thumb.rotation.z = side * 0.35
		_gloves.append(glove)
		var hip := Node3D.new()
		hip.position = Vector3(side * HIP_WIDTH, 0, 0)
		_hips.add_child(hip)
		var leg_pivot := Node3D.new()
		hip.add_child(leg_pivot)
		_legs.append(hip)
		_leg_meshes.append(leg_pivot)
		var thigh := Node3D.new()
		leg_pivot.add_child(thigh)
		_thighs.append(thigh)
		var shin := Node3D.new()
		leg_pivot.add_child(shin)
		_shins.append(shin)
		FightMesh.instance(thigh, FighterSculpt.contour([
			Vector4(-0.23, 0.125 * muscle, 0.127, 0.13), Vector4(-0.32, 0.103 * muscle, 0.107, 0.11),
			Vector4(-FighterMotion.THIGH, 0.072, 0.077, 0.075)
		]), _body_material)
		FightMesh.instance(shin, FighterSculpt.contour([
			Vector4(0.025, 0.072, 0.078, 0.075), Vector4(-0.08, 0.09 * muscle, 0.077, 0.105),
			Vector4(-0.17, 0.087 * muscle, 0.065, 0.1), Vector4(-0.32, 0.053, 0.046, 0.06),
			Vector4(-FighterMotion.SHIN, 0.043, 0.042, 0.046)
		]), _body_material)
		FightMesh.instance(thigh, FighterSculpt.contour([
			Vector4(-0.065, 0.143 * muscle, 0.15, 0.155), Vector4(-0.14, 0.151 * muscle, 0.154, 0.155),
			Vector4(-0.255, 0.142 * muscle, 0.145, 0.147)
		]), cloth)
		FightMesh.instance(thigh, FighterSculpt.contour([
			Vector4(-0.252, 0.143 * muscle, 0.147, 0.149), Vector4(-0.267, 0.141 * muscle, 0.145, 0.147)
		]), gear)
		# A narrow sewn side stripe instead of the old large white rectangular patch.
		var stripe: MeshInstance3D = FightMesh.box(thigh, Vector3(0.009, 0.16, 0.035), trim, Vector3(side * 0.153 * muscle, -0.15, 0))
		stripe.rotation.z = side * -0.06
		FightMesh.box(thigh, Vector3(0.052, 0.028, 0.004), trim, Vector3(0.025 * side, -0.2, -0.151))
		var foot: MeshInstance3D = FightMesh.instance(leg_pivot, FighterSculpt.foot(), _body_material,
			Vector3(0, -LEG_LENGTH + 0.035, -0.04))
		for toe in 5:
			var width: float = 0.016 - toe * 0.0015
			FightMesh.instance(foot, FighterSculpt.ellipsoid(Vector3(width, 0.018, 0.027 - toe * 0.002), 8), _body_material,
				Vector3(side * (-0.043 + toe * 0.023), -0.008, -0.122 + toe * 0.006))
		_feet.append(foot)

static func _material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	return m


static func _label(font_size: int) -> Label3D:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = false
	label.pixel_size = 0.0045
	label.font_size = font_size
	label.outline_size = 14
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	label.render_priority = 10
	label.outline_render_priority = 9
	label.visible = false
	return label
