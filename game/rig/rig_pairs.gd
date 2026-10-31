class_name RigPairs
extends RefCounted
## Paired poses for the rig prototype (D283), written as data in one frame for both men: the origin is on
## the canvas between them, red (a) stands on the +Z side facing -Z, blue (b) on the -Z side facing +Z
## (turn 180). Each pose is {a: body spec, b: body spec}; see FighterRig.set_body and set_limbs for the keys.
## Hands and feet go to points on the other man ("to": "b.back") so the contact holds as the bodies move.
## Angles are degrees, lengths metres.

const ANKLE: float = FighterRig.ANKLE_UP


## Both men squared up a step apart, hands up: where the clips start.
static func standing() -> Dictionary:
	return {
		"a": _stance(0.62, 0.0),
		"b": _stance(-0.62, 180.0),
	}


## A body lock in the clinch: red's arms under blue's, hands round his back; blue's overhooks on red's
## shoulders; heads on each other's shoulder, hips back, feet staggered.
static func clinch() -> Dictionary:
	return {
		"a": {
			"root": [0.04, 0.86, 0.3], "lean": 16, "bend": [8, -6, 12], "head": [10, -25],
			"hand_l": {"to": "b.blade_r", "off": [0.02, -0.02, 0.06], "pole": [-1, -0.6, 0.2]},
			"hand_r": {"to": "b.blade_l", "off": [-0.02, -0.06, 0.06], "pole": [1, -0.6, 0.2]},
			"foot_l": {"at": [-0.2, ANKLE, 0.12]},
			"foot_r": {"at": [0.2, ANKLE, 0.62]},
		},
		"b": {
			"root": [0.04, 0.88, -0.3], "turn": 180, "lean": 12, "bend": [6, 6, 12], "head": [8, 25],
			"hand_l": {"to": "a.blade_r", "off": [0.06, 0.06, 0.04], "pole": [-0.8, 0.2, 0.4]},
			"hand_r": {"to": "a.blade_l", "off": [-0.06, 0.06, 0.04], "pole": [0.8, 0.2, 0.4]},
			"foot_l": {"at": [0.2, ANKLE, -0.12]},
			"foot_r": {"at": [-0.2, ANKLE, -0.62]},
		},
	}


## A double leg: red has changed levels and stepped in, his head on blue's ribs to the outside, both arms
## round the backs of blue's knees, his rear knee down; blue stands tall with his hands on red's back.
static func double_leg() -> Dictionary:
	return {
		"a": {
			"root": [0.2, 0.52, 0.42], "turn": -14, "lean": 50, "bend": [12, 0, -14], "head": [-24, -16],
			"hand_l": {"to": "b.thigh_r", "off": [0.0, -0.17, 0.09], "pole": [-0.9, -0.5, 0.3]},
			"hand_r": {"to": "b.thigh_l", "off": [0.0, -0.17, 0.09], "pole": [0.9, -0.5, 0.3]},
			"foot_l": {"at": [-0.16, ANKLE, 0.02]},
			"foot_r": {"at": [0.2, ANKLE, 0.98], "pole": [0, -0.4, -1]},
		},
		"b": {
			"root": [0, 0.9, -0.28], "turn": 180, "lean": -6, "bend": [16, 0, 0], "head": [20, 0],
			"hand_l": {"to": "a.back", "off": [-0.12, 0.04, 0.0], "pole": [-0.6, 0.2, 0.6]},
			"hand_r": {"to": "a.blade_l", "off": [0.0, 0.0, 0.02], "pole": [0.6, 0.2, 0.6]},
			"foot_l": {"at": [0.15, ANKLE, -0.22]},
			"foot_r": {"at": [-0.15, ANKLE, -0.28]},
		},
	}


## The double leg finished: blue on his back, red kneeling in his full guard, blue's legs wrapped round
## red's waist with the ankles crossed behind his back and his hands on red's head and arm.
static func full_guard() -> Dictionary:
	return {
		"a": {
			"root": [0, 0.5, 0.32], "lean": 28, "bend": [10, 0, 0], "head": [-6, 0],
			"hand_l": {"to": "b.belly", "off": [0.1, 0.0, -0.02], "pole": [-0.8, -0.6, 0.2]},
			"hand_r": {"to": "b.belly", "off": [-0.12, 0.1, -0.02], "pole": [0.8, -0.6, 0.2]},
			"foot_l": {"at": [-0.2, ANKLE, 0.82], "pole": [0, -0.3, -1], "flat": 0.0},
			"foot_r": {"at": [0.2, ANKLE, 0.82], "pole": [0, -0.3, -1], "flat": 0.0},
		},
		"b": {
			"root": [0, 0.25, 0.1], "turn": 180, "lean": -66, "bend": [-14, 0, 0], "head": [30, 0],
			"hand_l": {"to": "a.nape", "off": [0.06, 0.0, 0.0], "pole": [-1, 0.4, 0.2]},
			"hand_r": {"to": "a.upper_l", "off": [0.0, 0.0, -0.06], "pole": [1, 0.4, 0.2]},
			"foot_l": {"to": "b.lower_back", "off": [0.07, 0.0, 0.05], "pole": [-1, 0.3, -0.3]},
			"foot_r": {"to": "b.lower_back", "off": [-0.07, 0.03, 0.08], "pole": [1, 0.3, -0.3]},
		},
	}


## The sprawl on a failed shot: red shot in but blue threw his legs back and dropped his hips on red's
## shoulders; red is down on his knees with his arms short of blue's legs, blue's chest on his back.
static func sprawl() -> Dictionary:
	return {
		"a": {
			"root": [0, 0.4, 0.55], "lean": 82, "bend": [10, 0, 0], "head": [-45, 0],
			"hand_l": {"to": "b.hip_r", "off": [0.0, -0.04, -0.02], "pole": [-1, -0.6, 0]},
			"hand_r": {"to": "b.hip_l", "off": [0.0, -0.04, -0.02], "pole": [1, -0.6, 0]},
			"foot_l": {"at": [-0.2, ANKLE, 1.0], "pole": [0, -1, -0.15], "flat": 0.0},
			"foot_r": {"at": [0.2, ANKLE, 1.0], "pole": [0, -1, -0.15], "flat": 0.0},
		},
		"b": {
			"root": [0, 0.64, -0.56], "turn": 180, "lean": 72, "bend": [4, 0, 0], "head": [-20, 0],
			"hand_l": {"to": "a.back", "off": [-0.12, -0.12, 0.06], "pole": [-1, 0.3, 0]},
			"hand_r": {"to": "a.armpit_l", "off": [0.04, -0.02, 0.06], "pole": [1, -0.6, 0]},
			"foot_l": {"at": [0.3, ANKLE, -1.18], "pole": [0, -1, -0.2]},
			"foot_r": {"at": [-0.3, ANKLE, -1.14], "pole": [0, -1, -0.2]},
		},
	}


## Getting up off the canvas (the technical stand-up): red sits back on one hand posted behind him, the other
## up framing, one foot planted and the other leg out at blue, who waits a step away in his stance.
static func get_up() -> Dictionary:
	return {
		"a": {
			"root": [0.04, 0.24, 0.42], "lean": -34, "roll": -14, "bend": [18, -10, 0], "head": [24, 0],
			"hand_l": {"at": [-0.12, 0.56, 0.16], "pole": [-0.6, -1, 0.4]},
			"hand_r": {"at": [0.4, 0.06, 0.78], "pole": [1, 0, 0.6]},
			"foot_l": {"at": [-0.16, ANKLE, 0.02], "pole": [0, 0.2, -1]},
			"foot_r": {"at": [0.24, 0.24, -0.38], "pole": [0, 0.5, -1]},
		},
		"b": _stance(-0.7, 180.0),
	}


## Back on his feet after the stand-up, a long step out of range.
static func back_up() -> Dictionary:
	return {
		"a": _stance(0.9, 0.0),
		"b": _stance(-0.7, 180.0),
	}


## The prototype's clips (tools/rig_preview.gd, tests): [title, from pose, to pose] each blended over a second,
## then held. A missing from pose is a hold.
static func clips() -> Array:
	return [
		["Standing to the clinch", standing(), clinch()],
		["The clinch (body lock)", {}, clinch()],
		["Shooting the double leg", standing(), double_leg()],
		["Finishing it into his guard", double_leg(), full_guard()],
		["The full guard", {}, full_guard()],
		["Shooting into a sprawl", standing(), sprawl()],
		["The sprawl on a failed shot", {}, sprawl()],
		["Getting up", get_up(), back_up()],
	]


## The poses by name, for the tests.
static func all() -> Dictionary:
	return {"standing": standing(), "clinch": clinch(), "double_leg": double_leg(), "full_guard": full_guard(),
		"sprawl": sprawl(), "get_up": get_up(), "back_up": back_up()}


## A boxing stance at `z`: orthodox, left foot forward, hands up.
static func _stance(z: float, turn: float) -> Dictionary:
	var ahead: float = -1.0 if turn < 90.0 else 1.0
	var x: float = 1.0 if turn < 90.0 else -1.0
	return {
		"root": [0, 0.86, z], "turn": turn + 18.0 * x * -1.0, "lean": 6, "bend": [4, -14, 0],
		"foot_l": {"at": [-0.16 * x, ANKLE, z + ahead * 0.24]},
		"foot_r": {"at": [0.18 * x, ANKLE, z - ahead * 0.2]},
	}
