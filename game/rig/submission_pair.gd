class_name SubmissionPair
extends RefCounted
## The submissions once locked in, posed from the rig (D366): the guillotine, triangle, armbar, rear-naked choke,
## arm-triangle and the three leg locks. Each hold is a loose pose (the danger meter near empty: he is nearly out)
## and a tight one (near full: about to tap), blended by the danger (Kyle, D366: "tightens with the danger"), and
## a tap for the finish. Written like RigPairs with the man attacking as "a" and the man defending as "b".
## Presentation only.
##
## Each hold is drawn in one of three frames (FRAMES): "ground", the frame of the ground position it was locked
## from (ArenaView.ground_frame: its origin on the canvas under the bottom man's hips, +Z toward his feet, the top
## man on its -X side in a side position); "standing", the clinch frame (between them, "a" on its +Z side facing
## -Z); "legs", the same between them, for the leg locks, which are fought face to face.

const ANKLE: float = FighterRig.ANKLE_UP
## The holds posed from the rig.
const HOLDS: Array[String] = ["guillotine", "triangle", "armbar", "rear_naked_choke", "arm_triangle", "ankle_lock",
	"kneebar", "heel_hook"]
const LEG_LOCKS: Array[String] = ["ankle_lock", "kneebar", "heel_hook"]
## The frames a hold is drawn in (see above).
const FRAMES: Array[String] = ["ground", "standing", "legs"]
## A standing guillotine sits back and pulls him into the guard once it gets this deep (danger out of 100:
## Kyle, D366 "standing, sits back if deep"); once down it stays down.
const GUARD_PULL_AT: float = 70.0
## The tap (D366): how many times a second his hand comes down, and how high it comes up between (metres).
const TAP_HZ: float = 3.0
const TAP_LIFT: float = 0.09
## The holds the attacker is beside the man in, on the frame's -X side (mirrored by `far`), by TAPS key.
const SIDE_HOLDS: Array[String] = ["arm_triangle", "armbar_mount"]
## Which of the defender's hands taps, and where: the hand free of the hold, on the attacker or the canvas.
const TAPS := {
	"guillotine": {"hand": "hand_r", "to": "a.back", "off": [0.0, 0.0, 0.06]},
	"guillotine_guard": {"hand": "hand_r", "to": "a.thigh_l", "off": [0.0, 0.0, 0.08]},
	"triangle": {"hand": "hand_r", "to": "a.thigh_r", "off": [0.0, 0.0, 0.08]},
	"armbar": {"hand": "hand_l", "to": "a.thigh_l", "off": [0.0, 0.0, 0.08]},
	"armbar_mount": {"hand": "hand_l", "to": "a.shin_r", "off": [0.0, 0.0, 0.07]},
	"rear_naked_choke": {"hand": "hand_l", "to": "a.thigh_l", "off": [0.0, 0.0, 0.08]},
	"arm_triangle": {"hand": "hand_l", "at": [0.42, 0.06, -0.2]},
	"arm_triangle_mount": {"hand": "hand_l", "to": "a.back", "off": [0.0, 0.0, 0.06]},
	"ankle_lock": {"hand": "hand_l", "at": [0.32, 0.06, -0.57]},
	"kneebar": {"hand": "hand_l", "at": [0.32, 0.06, -0.78]},
	"heel_hook": {"hand": "hand_l", "at": [0.32, 0.06, -0.76]},
}


## The hold `action` locked from `from` (a position id) with the attacker on top there (`on_top`; the leg locks
## and the guillotine ignore it): {loose: pair, tight: pair, frame: FRAMES kind, tap: TAPS key}, both pairs with
## the attacker "a"; `pulled` gives the guillotine pulled into the guard; `far` +1 mirrors a hold the attacker is
## beside him in (SIDE_HOLDS) to put him on the frame's +X side, as GroundPair does. Empty when it isn't posed.
static func build(action: String, from: String = "", on_top: bool = false, pulled: bool = false, far: float = -1.0) -> Dictionary:
	var built: Dictionary = _build(action, from, on_top, pulled)
	if far > 0.0 and SIDE_HOLDS.has(String(built.get("tap", ""))):
		built.loose = ClinchPair.mirror(built.loose)
		built.tight = ClinchPair.mirror(built.tight)
		built.mirrored = true
	return built


static func _build(action: String, from: String, on_top: bool, pulled: bool) -> Dictionary:
	match action:
		"guillotine":
			if pulled:
				return {"loose": _guillotine_guard(false), "tight": _guillotine_guard(true), "frame": "standing",
					"tap": "guillotine_guard"}
			return {"loose": _guillotine(false), "tight": _guillotine(true), "frame": "standing", "tap": "guillotine"}
		"triangle":
			return {"loose": _triangle(false), "tight": _triangle(true), "frame": "ground", "tap": "triangle"}
		"armbar":
			if on_top or from == "mount":
				return {"loose": _armbar_mount(false), "tight": _armbar_mount(true), "frame": "ground", "tap": "armbar_mount"}
			return {"loose": _armbar(false), "tight": _armbar(true), "frame": "ground", "tap": "armbar"}
		"rear_naked_choke":
			return {"loose": _rear_naked_choke(false), "tight": _rear_naked_choke(true), "frame": "ground", "tap": "rear_naked_choke"}
		"arm_triangle":
			if from == "mount":
				return {"loose": _arm_triangle_mount(false), "tight": _arm_triangle_mount(true), "frame": "ground", "tap": "arm_triangle_mount"}
			return {"loose": _arm_triangle(false), "tight": _arm_triangle(true), "frame": "ground", "tap": "arm_triangle"}
		"ankle_lock":
			return {"loose": _ankle_lock(false), "tight": _ankle_lock(true), "frame": "legs", "tap": "ankle_lock"}
		"kneebar":
			return {"loose": _kneebar(false), "tight": _kneebar(true), "frame": "legs", "tap": "kneebar"}
		"heel_hook":
			return {"loose": _heel_hook(false), "tight": _heel_hook(true), "frame": "legs", "tap": "heel_hook"}
	return {}


## The pair at `danger` (0–100) into `built`: the loose pose blended toward the tight one, for
## FighterRig.pose_pair (returns [pair, to, t]).
static func at_danger(built: Dictionary, danger: float) -> Array:
	return [built.loose, built.tight, smoothstep(0.0, 1.0, clampf(danger / 100.0, 0.0, 1.0))]


## The tight pose with the defender's free hand tapping (TAPS), `seconds` into the tap: down on the beat, up
## TAP_LIFT between.
static func tapping(built: Dictionary, seconds: float) -> Dictionary:
	var pair: Dictionary = (built.tight as Dictionary).duplicate(true)
	var tap: Dictionary = TAPS[built.tap]
	var lift: float = TAP_LIFT * absf(sin(seconds * TAP_HZ * PI))
	var want := {"pole": [0.0, -0.4, 0.4]}
	if tap.has("at"):
		want.at = [tap.at[0], float(tap.at[1]) + lift, tap.at[2]]
	else:
		want.to = tap.to
		want.off = [tap.off[0], tap.off[1], float(tap.off[2]) + lift]
	var hand: String = tap.hand
	if bool(built.get("mirrored", false)):
		hand = "hand_r" if hand == "hand_l" else "hand_l"
		want = ClinchPair._mirror_limb(want)
	pair.b[hand] = want
	return pair


## Every hold, loose and tight, to look at and test, by name: [action, from, on_top, pulled, danger].
static func examples() -> Dictionary:
	var out := {}
	var cases := {
		"guillotine": ["guillotine", "standing", false, false],
		"guillotine_guard": ["guillotine", "standing", false, true],
		"triangle": ["triangle", "full_guard", false, false],
		"armbar": ["armbar", "full_guard", false, false],
		"armbar_mount": ["armbar", "mount", true, false],
		"rear_naked_choke": ["rear_naked_choke", "back_control", true, false],
		"arm_triangle": ["arm_triangle", "side_control", true, false],
		"arm_triangle_mount": ["arm_triangle", "mount", true, false],
		"ankle_lock": ["ankle_lock", "full_guard", false, false],
		"kneebar": ["kneebar", "half_guard", true, false],
		"heel_hook": ["heel_hook", "half_guard", false, false],
	}
	for key: String in cases:
		var c: Array = cases[key]
		out[key + "_loose"] = c + [0.0]
		out[key + "_tight"] = c + [100.0]
	return out


# --- The holds -------------------------------------------------------------------

## The guillotine standing (from a shot or the clinch): red upright, blue bent over in front of him with his head
## under red's right arm, red's forearm under his chin and his left hand clasped on his own right wrist; blue's
## hands on the choking arm. Tight: red arched back pulling up, blue's head pulled up and in.
static func _guillotine(tight: bool) -> Dictionary:
	var k: float = 1.0 if tight else 0.0
	return {
		"a": {
			"root": [0.04, 0.84 - 0.04 * k, 0.24 + 0.04 * k], "lean": 14 - 22 * k, "bend": [16 - 14 * k, 18, 0],
			"head": [24, -10],
			"hand_r": {"to": "b.chin", "off": [-0.08, -0.02, 0.0], "pole": [1, -0.2, -0.6]},
			"hand_l": {"to": "b.chin", "off": [0.06, -0.04, 0.02], "pole": [-1, -0.4, 0.4]},
			"foot_l": {"at": [-0.2, ANKLE, 0.2]},
			"foot_r": {"at": [0.2, ANKLE, 0.48]},
		},
		"b": {
			"root": [0.08, 0.8 + 0.04 * k, -0.34 + 0.04 * k], "turn": 196, "lean": 62 - 8 * k, "bend": [18, 0, 0],
			"head": [-10 - 10 * k, 0],
			"hand_l": {"to": "a.fore_r", "off": [0.0, -0.04, 0.04], "pole": [-0.6, -0.6, 0.4]},
			"hand_r": {"to": "a.waist_l", "off": [0.0, 0.0, 0.0], "pole": [0.6, -0.6, 0.2]},
			"foot_l": {"at": [0.26, ANKLE, -0.72]},
			"foot_r": {"at": [-0.08, ANKLE, -0.82]},
		},
	}


## The guillotine pulled into the guard: red on his back, blue on his knees in red's closed guard with his head
## trapped against red's chest, red's arm round his neck and his legs round blue's waist. Tight: red's hips up
## and back arched, blue's head pulled in.
static func _guillotine_guard(tight: bool) -> Dictionary:
	var k: float = 1.0 if tight else 0.0
	var pair: Dictionary = _flipped(ClinchPair.swap(RigPairs.full_guard()), 0.34)
	var a: Dictionary = pair.a
	var b: Dictionary = pair.b
	a.root = [a.root[0], float(a.root[1]) + 0.04 * k, a.root[2]]
	a.lean = float(a.lean) - 8 - 10 * k
	a.bend = [-4 + 14 * k, 0, 0]
	a.head = [30, 0]
	a.hand_r = {"to": "b.chin", "off": [-0.08, -0.02, 0.0], "pole": [1, 0.4, -0.4]}
	a.hand_l = {"to": "b.chin", "off": [0.06, -0.04, 0.02], "pole": [-1, 0.4, 0.2]}
	b.lean = float(b.lean) + 24 + 10 * k
	b.bend = [16, 0, 0]
	b.head = [-30 - 10 * k, 0]
	b.hand_l = {"to": "a.fore_r", "off": [0.0, -0.04, 0.04], "pole": [-0.6, -0.6, 0.4]}
	b.hand_r = {"to": "a.waist_l", "off": [0.0, 0.0, 0.0], "pole": [0.6, -0.6, 0.2]}
	return pair


## The triangle from the bottom of the guard: red on his back (hips on the frame's origin, feet toward +Z), curled
## up with his left leg over blue's neck and his right shin locked over it behind blue's head, blue's right arm
## trapped in with his head; red's left hand pulls blue's head down, his right holds the trapped wrist. Blue on his
## knees in front of him, bent over into it. Tight: red's hips up, blue's head pulled down onto his chest.
static func _triangle(tight: bool) -> Dictionary:
	var k: float = 1.0 if tight else 0.0
	return {
		"a": {
			"root": [0.0, 0.19, 0.0], "turn": 180, "lean": 270, "roll": 10, "bend": [15, 0, 0],
			"head": [30, 0],
			"hand_l": {"to": "b.nape", "off": [0.1 - 0.1 * k, -0.14 + 0.18 * k, 0.02], "pole": [1, 0.2, 0.4]},
			"hand_r": {"to": "b.wrist_r", "off": [0.0, 0.0, 0.0], "pole": [-1, 0.2, 0.4]},
			"foot_l": {"to": "b.nape", "off": [-0.16, 0.04, 0.02], "pole": [1, 0.6, -0.2]},
			"foot_r": {"to": "b.nape", "off": [0.18, -0.02, 0.04], "pole": [-1, 0.6, 0.2]},
		},
		"b": {
			"root": [0.0, 0.46 - 0.02 * k, 0.28 - 0.02 * k], "turn": 0, "lean": 64 + 6 * k, "bend": [14 + 8 * k, 0, 0],
			"head": [-24 - 12 * k, 0],
			"hand_r": {"to": "a.chest", "off": [0.04, 0.0, -0.04], "pole": [1, -0.4, 0.2]},
			"hand_l": {"to": "a.waist_r", "off": [0.0, 0.04, 0.0], "pole": [-1, -0.4, 0.2]},
			"foot_l": {"at": [-0.2, ANKLE, 0.8], "pole": [0, -0.3, -1], "flat": 0.0},
			"foot_r": {"at": [0.2, ANKLE, 0.8], "pole": [0, -0.3, -1], "flat": 0.0},
		},
	}


## The armbar from the bottom of the guard: red on his back turned across under blue, curled up with his left leg
## across blue's face and his right on his back, both hands on blue's right wrist at his chest. Blue on his knees
## bent over him, that arm caught between red's legs. Tight: red's hips up into the elbow and his legs pinching,
## blue's arm straight.
static func _armbar(tight: bool) -> Dictionary:
	var k: float = 1.0 if tight else 0.0
	return {
		"a": {
			"root": [0.0, 0.14 + 0.07 * k, 0.04], "turn": 150, "lean": 270, "bend": [8 - 2 * k, 0, 0], "head": [30, 0],
			"hand_l": {"to": "b.wrist_r", "off": [0.0, 0.0, 0.0], "pole": [1, 0.0, 0.6]},
			"hand_r": {"to": "b.wrist_r", "off": [0.0, 0.06, 0.0], "pole": [-1, 0.0, 0.6]},
			"foot_l": {"to": "b.shoulder_l", "off": [-0.12, 0.08, -0.12 - 0.04 * k], "pole": [1, 0.6, 0.0]},
			"foot_r": {"to": "b.waist_r", "off": [0.12, 0.0, 0.06], "pole": [-1, 0.6, 0.2]},
		},
		"b": {
			"root": [0.04, 0.48, 0.32 + 0.03 * k], "turn": 10, "lean": 56 - 10 * k, "bend": [14 - 6 * k, 0, 0],
			"head": [-8 + 12 * k, 0],
			"hand_r": {"to": "a.chest", "off": [0.0, 0.1 + 0.06 * k, -0.1 - 0.06 * k], "pole": [1, -0.6, 0.2]},
			"hand_l": {"to": "b.hip_l", "off": [0.0, 0.02, -0.14], "pole": [-1, -0.4, 0.2]},
			"foot_l": {"at": [-0.2, ANKLE, 0.82], "pole": [0, -0.3, -1], "flat": 0.0},
			"foot_r": {"at": [0.2, ANKLE, 0.82], "pole": [0, -0.3, -1], "flat": 0.0},
		},
	}


## The armbar from mount: red has swung off to sit beside blue's head on the frame's -X side, his legs across blue's
## chest and face, both hands holding blue's right arm up between them. Blue flat on his back. Tight: red falls back
## to the canvas, the arm straight up and across his hips.
static func _armbar_mount(tight: bool) -> Dictionary:
	var k: float = 1.0 if tight else 0.0
	return {
		"a": {
			"root": [-0.3, 0.16, -0.3], "turn": 90, "lean": -30 - 50 * k, "bend": [16 - 10 * k, 0, 0], "head": [20, 0],
			"hand_l": {"to": "b.wrist_r", "off": [0.0, 0.0, 0.0], "pole": [-0.4, 0.2, 1]},
			"hand_r": {"to": "b.wrist_r", "off": [0.0, 0.07, 0.0], "pole": [0.4, 0.2, 1]},
			"foot_l": {"at": [0.42, 0.12, -0.24], "pole": [0, 1, 0.2]},
			"foot_r": {"at": [0.36, 0.12, -0.7], "pole": [0, 1, -0.2]},
		},
		"b": {
			"root": [0.0, 0.13, 0.0], "turn": 180, "lean": 270, "bend": [-2, 0, 0], "head": [14, 20],
			"hand_r": {"at": [-0.1, 0.56 - 0.08 * k, -0.26 + 0.1 * k], "pole": [-1, 0.0, 0.0]},
			"hand_l": {"to": "a.shin_r", "off": [0.0, 0.0, 0.06], "pole": [1, 0.0, 0.3]},
			"foot_l": {"at": [0.22, ANKLE, 0.6], "pole": [0.3, 1, 0.2]},
			"foot_r": {"at": [-0.2, ANKLE, 0.66], "pole": [-0.3, 1, 0.2]},
		},
	}


## The rear-naked choke from the back: as GroundPair's back, red's right arm round blue's throat with the hand at
## his left shoulder and his left hand behind blue's head; blue's hands on the choking forearm. Tight: red leans
## back and pulls, blue's chin up and his body stretched back.
static func _rear_naked_choke(tight: bool) -> Dictionary:
	var k: float = 1.0 if tight else 0.0
	return {
		"a": {
			"root": [0.0, 0.14, -0.34], "turn": 180, "lean": -14 - 18 * k, "bend": [16 - 6 * k, 0, 0], "head": [-6, 30],
			"hand_r": {"to": "b.shoulder_l", "off": [0.04, 0.06, -0.08], "pole": [-1, -0.2, -0.3]},
			"hand_l": {"to": "b.back_of_head", "off": [0.0, 0.0, 0.04], "pole": [1, 0.2, 0.2]},
			"foot_l": {"to": "b.thigh_l", "off": [-0.07, 0.1, 0.0], "pole": [1, 0.6, 0.3]},
			"foot_r": {"to": "b.thigh_r", "off": [0.07, 0.1, 0.0], "pole": [-1, 0.6, 0.3]},
		},
		"b": {
			"root": [0.0, 0.14, 0.02 + 0.04 * k], "turn": 180, "lean": -18 - 16 * k, "bend": [10 - 8 * k, 0, 0],
			"head": [8 + 22 * k, 0],
			"hand_l": {"to": "a.fore_r", "off": [0.0, -0.06, 0.04], "pole": [1, -0.6, 0.4]},
			"hand_r": {"to": "a.fore_r", "off": [0.0, 0.06, 0.04], "pole": [-1, -0.6, 0.4]},
			"foot_l": {"at": [0.24, ANKLE, 0.7], "pole": [0.3, 1, 0.2]},
			"foot_r": {"at": [-0.24, ANKLE, 0.72], "pole": [-0.3, 1, 0.2]},
		},
	}


## The arm-triangle from side control: as GroundPair.side_control, red lower with his arms round blue's head and
## near arm, his left hand at blue's nape and his right round the far side of his head; blue's near (right) arm
## pinned up across his own face, his far hand free on the canvas. Tight: red drives in and sinks his hips, blue's
## head turned away.
static func _arm_triangle(tight: bool) -> Dictionary:
	var k: float = 1.0 if tight else 0.0
	var pair: Dictionary = GroundPair.side_control()
	var a: Dictionary = pair.a
	var b: Dictionary = pair.b
	a.root = [-0.3 + 0.02 * k, 0.29 - 0.02 * k, -0.38 - 0.01 * k]
	a.lean = 74 + 6 * k
	a.head = [-20, 40]
	a.hand_l = {"to": "b.nape", "off": [0.06, 0.0, 0.0], "pole": [-0.6, -0.6, -0.4]}
	a.hand_r = {"to": "b.head", "off": [0.06 + 0.04 * k, -0.06 + 0.04 * k, -0.1 + 0.08 * k], "pole": [0.6, -0.6, -0.4]}
	b.head = [10, 26 + 14 * k]
	b.hand_r = {"to": "b.head", "off": [0.1, 0.02, -0.08], "pole": [-1, 0.4, 0.0]}
	b.hand_l = {"at": [0.42, 0.06, -0.2], "pole": [1, 0, 0.3]}
	return pair


## The arm-triangle from mount: red chest down on blue, his arms round blue's head and right arm, hands at the nape,
## his head beside blue's. Tight: red sprawls his hips down and drives his shoulder in.
static func _arm_triangle_mount(tight: bool) -> Dictionary:
	var k: float = 1.0 if tight else 0.0
	var kneel := {"pole": [0, -0.2, -1], "flat": 0.0}
	return {
		"a": {
			"root": [0.0, 0.36 - 0.06 * k, -0.2 - 0.04 * k], "lean": 70 + 8 * k, "bend": [12, 0, 0], "head": [-20, -36],
			"hand_l": {"to": "b.nape", "off": [0.06, 0.0, 0.0], "pole": [-0.8, -0.4, -0.2]},
			"hand_r": {"to": "b.nape", "off": [-0.04, 0.0, 0.04], "pole": [0.8, -0.4, -0.2]},
			"foot_l": {"pole": [0, -0.2, -1], "flat": 0.0, "at": [-0.28, ANKLE, 0.3]},
			"foot_r": GroundPair._with(kneel, {"at": [0.28, ANKLE, 0.3]}),
		},
		"b": {
			"root": [0.0, 0.13, 0.0], "turn": 180, "lean": 270, "bend": [-2, 0, 0], "head": [14, -20 - 14 * k],
			"hand_r": {"to": "b.head", "off": [-0.12, 0.02, -0.06], "pole": [1, 0.4, 0.0]},
			"hand_l": {"to": "a.hip_r", "off": [0.0, 0.04, -0.04], "pole": [1, -0.4, 0.2]},
			"foot_l": {"at": [0.2, ANKLE, 0.56], "pole": [0.3, 1, 0.2]},
			"foot_r": {"at": [-0.2, ANKLE, 0.56], "pole": [-0.3, 1, 0.2]},
		},
	}


## The ankle lock: face to face on the canvas, red sat at the frame's +Z side with blue's right foot under his right
## armpit, his forearm under the Achilles and his left foot on blue's hip; blue propped on his hands at -Z, his
## left foot on red's hip. Tight: red falls back arching, the leg pulled straight.
static func _ankle_lock(tight: bool) -> Dictionary:
	var k: float = 1.0 if tight else 0.0
	var z: float = -0.29 + 0.16 * k  # Blue's hips: pulled along as red falls back.
	return {
		"a": {
			"root": [0.06, 0.16, 0.34 + 0.06 * k], "turn": 0, "lean": -24 - 30 * k, "roll": -10 * k, "bend": [14, 0, 0],
			"head": [16, 0],
			"hand_r": {"to": "b.ankle_r", "off": [-0.04, 0.02, 0.0], "pole": [1, -0.6, 0.2]},
			"hand_l": {"to": "b.ankle_r", "off": [0.04, 0.06, 0.0], "pole": [-1, -0.6, 0.2]},
			"foot_l": {"to": "b.hip_r", "off": [0.04, 0.0, 0.06], "pole": [-1, 0.6, 0.0]},
			"foot_r": {"at": [0.34, ANKLE, 0.0], "pole": [1, 1, 0.0]},
		},
		"b": {
			"root": [0.04, 0.16, z], "turn": 180, "lean": -54 - 10 * k, "bend": [12, 0, 0], "head": [24, 0],
			"hand_l": {"at": [0.32, 0.06, z - 0.44], "pole": [1, 0.4, 0.0]},
			"hand_r": {"at": [-0.26, 0.06, z - 0.44], "pole": [-1, 0.4, 0.0]},
			"foot_r": {"to": "a.armpit_r", "off": [0.0, -0.04, -0.02], "pole": [0.4, 1, 0.0]},
			"foot_l": {"to": "a.hip_r", "off": [0.06, 0.04, -0.08], "pole": [-0.6, 1, 0.0]},
		},
	}


## The kneebar: face to face on the canvas, blue propped back on his hands at the frame's -Z side with his right leg out;
## red on his back along it (his head toward +Z), his hips at blue's knee, blue's heel held on his chest and his
## legs scissored round blue's thigh. Tight: red arches his hips up into the knee.
static func _kneebar(tight: bool) -> Dictionary:
	var k: float = 1.0 if tight else 0.0
	var z: float = -0.44 + 0.1 * k
	return {
		"a": {
			"root": [0.02, 0.15 + 0.07 * k, -0.08], "turn": 0, "lean": -78 - 6 * k, "roll": 12, "bend": [-4 - 14 * k, 0, 0],
			"head": [30, 0],
			"hand_r": {"to": "b.ankle_r", "off": [0.0, 0.02, 0.0], "pole": [1, 0.4, -0.4]},
			"hand_l": {"to": "b.ankle_r", "off": [0.0, -0.05, 0.04], "pole": [-1, 0.4, -0.4]},
			"foot_l": {"to": "b.hip_r", "off": [0.04, 0.04, -0.06], "pole": [-1, 1, 0.0]},
			"foot_r": {"to": "b.thigh_r", "off": [0.1, 0.0, 0.06], "pole": [1, 1, 0.0]},
		},
		"b": {
			"root": [0.06, 0.16, z], "turn": 180, "lean": -50, "roll": 6, "bend": [8, 0, 0], "head": [20, -10],
			"hand_l": {"at": [0.32, 0.06, z - 0.44], "pole": [1, 0.4, 0.0]},
			"hand_r": {"at": [-0.26, 0.06, z - 0.44], "pole": [-1, 0.4, 0.0]},
			"foot_r": {"to": "a.chest", "off": [0.08, 0.06, -0.12], "pole": [0, 1, 0.0]},
			"foot_l": {"at": [-0.36, ANKLE, z + 0.5], "pole": [-1, 1, 0.0]},
		},
	}


## The heel hook: red on his back at the frame's +Z side with blue's right leg between his, his outside foot on
## blue's hip and his inside leg behind blue's knee, the heel cupped in his elbow; blue on his back at -Z turning
## away. Tight: red turns the heel, rolling onto his side.
static func _heel_hook(tight: bool) -> Dictionary:
	var k: float = 1.0 if tight else 0.0
	var z: float = -0.31
	return {
		"a": {
			"root": [0.0, 0.14, 0.26], "turn": 0, "lean": -50 - 20 * k, "roll": -8 - 26 * k, "bend": [16, 0, 0], "head": [20, 0],
			"hand_r": {"to": "b.ankle_r", "off": [-0.02, 0.0, 0.04], "pole": [1, -0.6, 0.2]},
			"hand_l": {"to": "b.ankle_r", "off": [0.04, 0.06, 0.0], "pole": [-1, -0.6, 0.2]},
			"foot_l": {"to": "b.hip_r", "off": [0.06, 0.0, 0.06], "pole": [-1, 0.6, 0.0]},
			"foot_r": {"to": "b.knee_r", "off": [-0.06, -0.06, 0.0], "pole": [1, 0.6, 0.0]},
		},
		"b": {
			"root": [0.06, 0.14, z], "turn": 180, "lean": -64 - 8 * k, "roll": 10 * k, "bend": [12, 0, 0], "head": [20, -20 * k],
			"hand_l": {"at": [0.32, 0.06, z - 0.44], "pole": [1, 0.4, 0.0]},
			"hand_r": {"at": [-0.26, 0.06, z - 0.44], "pole": [-1, 0.4, 0.0]},
			"foot_r": {"to": "a.armpit_r", "off": [0.0, -0.06, -0.02], "pole": [0.4, 1, 0.0]},
			"foot_l": {"at": [-0.34, ANKLE, z + 0.6], "pole": [-1, 1, 0.0]},
		},
	}


# --- Helpers ---------------------------------------------------------------------

## `pair` turned half round the frame's up axis and moved `dz` along its +Z: the RigPairs poses have the man
## underneath facing +Z, the standing guillotine pulls guard falling back the other way.
static func _flipped(pair: Dictionary, dz: float = 0.0) -> Dictionary:
	var out := {}
	for man: String in pair:
		var spec: Dictionary = (pair[man] as Dictionary).duplicate(true)
		spec.root = [-float(spec.root[0]), spec.root[1], -float(spec.root[2]) + dz]
		spec.turn = float(spec.get("turn", 0.0)) + 180.0
		for key: String in spec:
			if not spec[key] is Dictionary:
				continue
			var limb: Dictionary = spec[key]
			if limb.has("at"):
				limb.at = [-float(limb.at[0]), limb.at[1], -float(limb.at[2]) + dz]
			if limb.has("pole"):
				limb.pole = [-float(limb.pole[0]), limb.pole[1], -float(limb.pole[2])]
		out[man] = spec
	return out
