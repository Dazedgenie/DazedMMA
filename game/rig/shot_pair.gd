class_name ShotPair
extends RefCounted
## Shots from range and following a knockdown down, from the rig (D369): the double leg shot from out in the open
## (dropping his level and blasting in, not stepping into the clinch first), the catch-kick single leg and
## following a man who's been dropped down to the canvas. Each move is a list of paired poses, like
## TakedownPair's, from the two standing apart to the ground position it lands in. Presentation only.
##
## The frame: on the canvas BEHIND_FEET in front of the other man ("b") toward the man taking him down ("a"),
## +Z toward a, so b's stance is where it was drawn and the shot's own poses (RigPairs.double_leg and on) are
## in the clinch takedown's frame. Following him down, the origin is under the downed man's hips, his feet
## toward a.

const ANKLE: float = FighterRig.ANKLE_UP
const MOVES: Array[String] = ["double_leg", "catch_kick_single", "follow_down"]
## The frame's origin this far in front of the man being taken down (metres): his stance is drawn round it.
const BEHIND_FEET: float = 0.26
## Per move, as TakedownPair.TIMING (Kyle, D369: from range he drops his level and blasts in; following him down
## he dives on top): entry, the keys gone through over the telegraph and wind-up; fall, how far from there to the
## landing during the active part; land, seconds from there to the canvas once it works; thud, 0–1; at, where the
## bottom man's hips land (x, z) in the move's frame.
const TIMING := {
	"double_leg": {"entry": 2, "fall": 0.5, "land": 0.35, "thud": 0.7, "at": Vector2(0.0, -0.55)},
	"catch_kick_single": {"entry": 1, "fall": 0.5, "land": 0.4, "thud": 0.75, "at": Vector2(0.0, -0.6)},
	"follow_down": {"entry": 1, "fall": 0.6, "land": 0.25, "thud": 0.5, "at": Vector2(0.0, 0.0)},
}
## The double leg's level change: his hips this far down (metres) and this far forward of his stance.
const LEVEL_DROP: float = 0.3
const LEVEL_STEP: float = 0.3


## The pose the move starts from, the two `gap` metres apart (hips to hips; the downed man's hips to the other's
## when following him down).
static func start(move: String, gap: float) -> Dictionary:
	match move:
		"follow_down":
			return {"a": _stance(gap, 0.0), "b": downed()}
		"catch_kick_single":
			return {"a": _stance(-BEHIND_FEET + gap, 0.0), "b": kicking()}
	return {"a": _stance(-BEHIND_FEET + gap, 0.0), "b": _stance(-BEHIND_FEET, 180.0)}


## The move's own keys after the start, in its frame (the landing is laid out by ArenaView: landing()).
static func keys(move: String, gap: float) -> Array[Dictionary]:
	match move:
		"double_leg":
			return [level_change(gap), RigPairs.double_leg(), TakedownPair._dl_drive()]
		"catch_kick_single":
			return [caught(), dumped()]
		"follow_down":
			return [dive()]
	return []


## Where the move lands them, in the landing frame (the bottom man's hips at its origin, his feet toward +Z):
## his guard after the double leg and the catch, half guard after following him down (his guard when it half
## works, D142). `far` as TakedownPair.landing.
static func landing(move: String, where: String = "", far: float = -1.0) -> Dictionary:
	if move == "follow_down" and where != "full_guard":
		return GroundPair.build("half_guard", {}, false, far).pair
	return TakedownPair.landing("double_leg")


## The keys with names, for the preview and the tests, at a mid-range gap.
static func examples() -> Dictionary:
	var out := {}
	for move: String in MOVES:
		out["%s_0" % move] = start(move, 1.2)
		var all: Array[Dictionary] = keys(move, 1.2)
		for n in all.size():
			out["%s_%d" % [move, n + 1]] = all[n]
	return out


# --- The double leg from range -------------------------------------------------------------------

## The level change (Kyle, D369): red drops his hips and steps his lead foot in deep, his hands low and reaching,
## still out at range; blue in his stance.
static func level_change(gap: float) -> Dictionary:
	var z: float = -BEHIND_FEET + gap
	return {
		"a": {
			"root": [0.06, FighterRig.PELVIS_HEIGHT - 0.06 - LEVEL_DROP, z - LEVEL_STEP], "turn": -10, "lean": 34,
			"bend": [12, 0, -6], "head": [-14, -10],
			"hand_l": {"at": [-0.2, 0.62, z - LEVEL_STEP - 0.5], "pole": [-0.9, -0.5, 0.3]},
			"hand_r": {"at": [0.18, 0.6, z - LEVEL_STEP - 0.46], "pole": [0.9, -0.5, 0.3]},
			"foot_l": {"at": [-0.14, ANKLE, z - LEVEL_STEP - 0.36]},
			"foot_r": {"at": [0.2, ANKLE, z - LEVEL_STEP + 0.44], "pole": [0, -0.4, -1], "flat": 0.0},
		},
		"b": _stance(-BEHIND_FEET, 180.0),
	}


# --- The catch-kick single -------------------------------------------------------------------

## Blue's right round kick coming in at red's ribs, red in his stance.
static func kicking() -> Dictionary:
	return {
		"root": [0.04, 0.88, -BEHIND_FEET], "turn": 160, "lean": -10, "roll": 8, "bend": [0, -10, 0], "head": [6, 0],
		"foot_l": {"at": [0.12, ANKLE, -BEHIND_FEET - 0.06]},
		"foot_r": {"at": [-0.42, 0.9, -BEHIND_FEET + 0.6], "pole": [-1, 0.3, 0]},
	}


## The kick caught: blue's right leg trapped under red's left arm against his side, red's right hand on the knee;
## blue hopping on his left foot, his arms out for balance.
static func caught() -> Dictionary:
	return {
		"a": {
			"root": [0.0, 0.86, 0.36], "turn": 12, "lean": 8, "bend": [4, 0, 0], "head": [-6, 0],
			"hand_l": {"to": "b.shin_r", "off": [0.0, 0.04, 0.0], "pole": [-1, -0.6, 0.3]},
			"hand_r": {"to": "b.shin_r", "off": [0.0, 0.2, 0.0], "pole": [1, -0.5, 0.2]},
			"foot_l": {"at": [-0.16, ANKLE, 0.14]},
			"foot_r": {"at": [0.18, ANKLE, 0.58]},
		},
		"b": {
			"root": [0.04, 0.88, -0.3], "turn": 180, "lean": -8, "roll": 10, "bend": [0, -6, 0], "head": [8, 0],
			"hand_l": {"at": [0.48, 1.2, -0.36], "pole": [1, -0.4, 0]},
			"hand_r": {"at": [-0.4, 1.16, -0.16], "pole": [-1, -0.4, 0]},
			"foot_l": {"at": [0.12, ANKLE, -0.3]},
			"foot_r": {"at": [-0.34, 0.84, 0.34], "pole": [-1, 0.3, 0]},
		},
	}


## Dumped: red steps in and reaps blue's standing leg out with his right, still holding the caught one, blue
## tipping back off his feet.
static func dumped() -> Dictionary:
	return {
		"a": {
			"root": [0.0, 0.7, 0.04], "turn": 8, "lean": 36, "bend": [10, 0, 0], "head": [-14, 0],
			"hand_l": {"to": "b.shin_r", "off": [0.0, 0.04, 0.0], "pole": [-1, -0.6, 0.3]},
			"hand_r": {"to": "b.shin_r", "off": [0.0, 0.2, 0.0], "pole": [1, -0.5, 0.2]},
			"foot_l": {"at": [-0.18, ANKLE, 0.26]},
			"foot_r": {"at": [0.14, 0.18, -0.38], "pole": [0.4, 0, -1]},
		},
		"b": {
			"root": [0.02, 0.58, -0.56], "turn": 180, "lean": -44, "roll": 6, "bend": [-4, 0, 0], "head": [26, 0],
			"hand_l": {"at": [0.52, 0.9, -0.76], "pole": [1, -0.4, 0]},
			"hand_r": {"at": [-0.46, 0.9, -0.62], "pole": [-1, -0.4, 0]},
			"foot_l": {"at": [0.12, 0.26, -0.34]},
			"foot_r": {"at": [-0.3, 0.7, 0.0], "pole": [-1, 0.3, 0]},
		},
	}


# --- Following him down ------------------------------------------------------------------

## A man knocked down: flat on his back, his feet toward the man who dropped him, his hands up by his head.
static func downed() -> Dictionary:
	return {
		"root": [0.0, 0.15, 0.0], "turn": 180, "lean": -86, "bend": [-2, 0, 0], "head": [24, 0],
		"hand_l": {"at": [0.24, 0.1, -0.5], "pole": [1, 0.4, 0]},
		"hand_r": {"at": [-0.24, 0.1, -0.5], "pole": [-1, 0.4, 0]},
		"foot_l": {"at": [0.18, ANKLE, 0.72], "pole": [0.2, 1, -0.2]},
		"foot_r": {"at": [-0.18, ANKLE, 0.74], "pole": [-0.2, 1, -0.2]},
	}


## The dive (Kyle, D369: he dives on top): red launched in low over blue's legs, his hands reaching for his
## waist, his back leg driving off the canvas; blue's head and knees coming up.
static func dive() -> Dictionary:
	return {
		"a": {
			"root": [0.04, 0.5, 0.6], "lean": 68, "bend": [8, 0, 0], "head": [-30, 0],
			"hand_l": {"to": "b.waist_r", "off": [0.0, 0.0, 0.0], "pole": [-1, -0.5, 0.2]},
			"hand_r": {"to": "b.waist_l", "off": [0.0, 0.0, 0.0], "pole": [1, -0.5, 0.2]},
			"foot_l": {"at": [-0.16, ANKLE, 0.92], "pole": [0, -0.6, -1], "flat": 0.0},
			"foot_r": {"at": [0.2, 0.2, 1.3], "pole": [0, -0.2, -1], "flat": 0.0},
		},
		"b": {
			"root": [0.0, 0.17, 0.0], "turn": 180, "lean": -76, "bend": [-2, 0, 0], "head": [40, 0],
			"foot_l": {"at": [0.18, ANKLE, 0.5], "pole": [0.2, 1, -0.4]},
			"foot_r": {"at": [-0.18, ANKLE, 0.52], "pole": [-0.2, 1, -0.4]},
		},
	}


# --- Helpers ---------------------------------------------------------------------------------

## A stance at `z` facing -Z (`turn` 0) or +Z (180): orthodox, hands up.
static func _stance(z: float, turn: float) -> Dictionary:
	return ScramblePair._stance(z, turn)
