class_name ScramblePair
extends RefCounted
## Scrambles and getting up from the rig (D368): the scramble as both men on their knees fighting for it, the
## scramble for the top driving over him, getting up out of it, the man underneath getting back to his feet
## (the technical stand-up in the open, walking up the fence with his back on it) and the top man standing up out
## of the position. Each move is a list of paired poses, like TakedownPair's, that ArenaView plays along from the
## pose they were in. Presentation only.
##
## The frames: in the scramble, between the two on the canvas with the man making the move as "a" on the +Z side.
## On the ground, the ground frame (GroundPair: the bottom man's hips at the origin, his feet toward +Z, the top man
## "a" and the bottom man "b"). On the fence (the fence walk), the origin FENCE_BACK in from the fence's face, +Z
## toward the middle of the cage, the man getting up "b" with his back to it.

const ANKLE: float = FighterRig.ANKLE_UP
## The moves posed: the scramble's two (for the top, and getting up out of it) and the two ways off the ground.
const MOVES: Array[String] = ["scramble", "scramble_up", "get_up", "get_up_fence", "stand_up"]
## Per move, as TakedownPair.TIMING (Kyle, D368: the scramble a fight on the knees, getting up by the technical
## stand-up or up the fence):
## entry: the keys gone through over the move's telegraph and wind-up;
## fall: how far from there to the last key he gets while the move is still being decided (its active part);
## land: seconds from there to the last key once it works;
## thud: how hard the end sounds, 0–1 (0: none; getting up is quiet).
const TIMING := {
	"scramble": {"entry": 1, "fall": 0.4, "land": 0.35, "thud": 0.3},
	"scramble_up": {"entry": 1, "fall": 0.4, "land": 0.4, "thud": 0.0},
	"get_up": {"entry": 1, "fall": 0.5, "land": 0.45, "thud": 0.0},
	"get_up_fence": {"entry": 1, "fall": 0.5, "land": 0.45, "thud": 0.0},
	"stand_up": {"entry": 1, "fall": 0.5, "land": 0.4, "thud": 0.0},
}
## Where the fence walk is posed from: the frame's origin this far in from the fence's face (metres).
const FENCE_BACK: float = 0.4
## Who gets up (the moves' "a" or "b"): the scramble's moves and standing up are the a man's, getting up the b man's.
const RISER := {"scramble": "a", "scramble_up": "a", "get_up": "b", "get_up_fence": "b", "stand_up": "a"}


## The move's own keys after the pose it starts from, in its frame (see the top). The last is where it ends:
## standing apart for the ways up, kneeling over him on the way into the guard for the scramble (the landing in
## the guard is laid out by ArenaView, from GroundPair).
static func keys(move: String) -> Array[Dictionary]:
	match move:
		"scramble":
			return [scramble_over()]
		"scramble_up":
			return [scramble_rise(), apart(0.45, -0.45)]
		"get_up":
			return [sit_out(), hips_up(), apart(1.0, -0.15)]
		"get_up_fence":
			return [wall_sit(), wall_half(), wall_up(), apart(0.85, -0.12)]
		"stand_up":
			return [base_up(), over_him(), stepped_off()]
	return []


## Whether a move ends on the ground: the scramble for the top lands in the guard.
static func lands(move: String) -> bool:
	return move == "scramble"


## The keys with names, for the preview and the tests.
static func examples() -> Dictionary:
	var out := {"kneeling": kneeling()}
	for move: String in MOVES:
		var all: Array[Dictionary] = keys(move)
		for n in all.size():
			out["%s_%d" % [move, n + 1]] = all[n]
	return out


# --- The scramble ---------------------------------------------------------------------

## The scramble (Kyle, D368: both on their knees fighting for it): up on their knees face to face, hands on each
## other's waist and shoulders.
static func kneeling() -> Dictionary:
	return TakedownPair.scramble()


## Scrambling for the top: red comes up onto his right foot and drives through, his head down by blue's ribs and
## his arms round his waist, blue knocked back onto his seat with his hands on red's shoulders.
static func scramble_over() -> Dictionary:
	return {
		"a": {
			"root": [0.08, 0.48, 0.1], "lean": 52, "bend": [14, 0, 0], "head": [-20, 25],
			"hand_l": {"to": "b.waist_r", "off": [0.0, 0.0, 0.06], "pole": [-1, -0.5, 0.2]},
			"hand_r": {"to": "b.waist_l", "off": [0.0, 0.0, 0.06], "pole": [1, -0.5, 0.2]},
			"foot_l": {"at": [-0.18, ANKLE, 0.62], "pole": [0, -0.3, -1], "flat": 0.0},
			"foot_r": {"at": [0.24, ANKLE, 0.02], "pole": [0.2, 0.2, -1]},
		},
		"b": {
			"root": [-0.04, 0.24, -0.46], "turn": 180, "lean": -36, "bend": [10, 0, 0], "head": [16, 0],
			"hand_l": {"to": "a.shoulder_r", "off": [0.0, 0.02, 0.0], "pole": [0.8, -0.2, 0.6]},
			"hand_r": {"to": "a.shoulder_l", "off": [0.0, 0.02, 0.0], "pole": [-0.8, -0.2, 0.6]},
			"foot_l": {"at": [0.18, ANKLE, -0.02], "pole": [0, 0.6, -1]},
			"foot_r": {"at": [-0.2, ANKLE, 0.0], "pole": [0, 0.6, -1]},
		},
	}


## Getting up out of the scramble: red up onto his right foot, his hands framing on blue's shoulders to push off,
## blue still on his knees.
static func scramble_rise() -> Dictionary:
	var pair: Dictionary = kneeling()
	pair.a = {
		"root": [0.08, 0.66, 0.5], "lean": 22, "bend": [8, 0, 0], "head": [-4, 0],
		"hand_l": {"to": "b.shoulder_r", "off": [0.0, 0.02, -0.04], "pole": [-1, -0.4, 0]},
		"hand_r": {"to": "b.shoulder_l", "off": [0.0, 0.02, -0.04], "pole": [1, -0.4, 0]},
		"foot_l": {"at": [-0.18, ANKLE, 0.86], "pole": [0, -0.3, -1], "flat": 0.0},
		"foot_r": {"at": [0.22, ANKLE, 0.3], "pole": [0.2, 0.2, -1]},
	}
	pair.b = (pair.b as Dictionary).duplicate()
	pair.b.lean = 10
	pair.b.erase("hand_l")
	pair.b.erase("hand_r")
	return pair


# --- Getting up from underneath ------------------------------------------------------------

## The technical stand-up, sitting out: blue (underneath) sits up onto his right hand posted behind him, his left
## forearm framing on red's shoulder and his right foot on red's hip, pushing him back; red sat up on his knees.
static func sit_out() -> Dictionary:
	return {
		"a": {
			"root": [0.0, 0.56, 0.48], "lean": 14, "bend": [6, 0, 0], "head": [-4, 0],
			"hand_l": {"to": "b.shin_r", "off": [0.0, 0.0, 0.0], "pole": [-1, -0.4, 0.2]},
			"hand_r": {"to": "b.shin_l", "off": [0.0, 0.2, 0.0], "pole": [1, -0.4, 0.2]},
			"foot_l": {"at": [-0.2, ANKLE, 0.96], "pole": [0, -0.3, -1], "flat": 0.0},
			"foot_r": {"at": [0.2, ANKLE, 0.96], "pole": [0, -0.3, -1], "flat": 0.0},
		},
		"b": {
			"root": [-0.04, 0.22, -0.08], "turn": 180, "lean": -44, "roll": -14, "bend": [18, 10, 0], "head": [26, 0],
			"hand_r": {"at": [-0.26, 0.06, -0.29], "pole": [-0.6, 0.4, 1]},
			"foot_l": {"at": [0.16, ANKLE, 0.3], "pole": [0, 0.4, -1]},
			"foot_r": {"to": "a.hip_l", "off": [0.0, 0.0, -0.02], "pole": [-0.3, 0.4, -1]},
		},
	}


## The technical stand-up, hips up: blue lifts his hips off the canvas on his posted hand and left foot and swings
## his right leg back under him; red comes up onto his right foot.
static func hips_up() -> Dictionary:
	return {
		"a": {
			"root": [0.04, 0.66, 0.74], "lean": 14, "bend": [6, 0, 0], "head": [0, 0],
			"foot_l": {"at": [-0.2, ANKLE, 1.16], "pole": [0, -0.3, -1], "flat": 0.0},
			"foot_r": {"at": [0.22, ANKLE, 0.5], "pole": [0.2, 0.2, -1]},
		},
		"b": {
			"root": [-0.06, 0.42, -0.08], "turn": 180, "lean": -70, "roll": -18, "bend": [24, 12, 0], "head": [24, 0],
			"hand_r": {"at": [-0.26, 0.06, -0.5], "pole": [-0.6, 0.4, 1]},
			"foot_l": {"at": [0.16, ANKLE, 0.18], "pole": [0, 0.4, -1]},
			"foot_r": {"at": [-0.12, ANKLE, -0.5], "pole": [0, -1, 0.6], "flat": 0.0},
		},
	}


## Getting up with his back on the fence (Kyle, D368: he walks up it), sat against it: blue's back on the fence,
## knees up and feet planted, his hands framing on red's shoulders; red on his knees in front, hands on his hips.
static func wall_sit() -> Dictionary:
	return {
		"a": {
			"root": [0.0, 0.46, 0.62], "lean": 30, "bend": [10, 0, 0], "head": [-12, 0],
			"hand_l": {"to": "b.shin_r", "off": [0.0, 0.18, 0.0], "pole": [-1, -0.5, 0.2]},
			"hand_r": {"to": "b.shin_l", "off": [0.0, 0.18, 0.0], "pole": [1, -0.5, 0.2]},
			"foot_l": {"at": [-0.2, ANKLE, 1.08], "pole": [0, -0.3, -1], "flat": 0.0},
			"foot_r": {"at": [0.2, ANKLE, 1.08], "pole": [0, -0.3, -1], "flat": 0.0},
		},
		"b": {
			"root": [0.0, 0.17, -0.02], "turn": 180, "lean": -18, "bend": [8, 0, 0], "head": [6, 0],
			"hand_l": {"to": "a.shoulder_r", "off": [0.0, 0.0, -0.04], "pole": [0.8, -0.6, 0.2]},
			"hand_r": {"to": "a.shoulder_l", "off": [0.0, 0.0, -0.04], "pole": [-0.8, -0.6, 0.2]},
			"foot_l": {"at": [0.16, ANKLE, 0.42], "pole": [0, 0.4, -1]},
			"foot_r": {"at": [-0.16, ANKLE, 0.42], "pole": [0, 0.4, -1]},
		},
	}


## Half way up the fence: blue's back flat on it, his hips up off the canvas and feet under him, his hands on
## red's wrists; red up on one knee with his head in blue's chest, pinning him there.
static func wall_half() -> Dictionary:
	return {
		"a": {
			"root": [0.12, 0.58, 0.58], "lean": 46, "bend": [12, 0, 0], "head": [-10, 40],
			"hand_l": {"to": "b.hip_r", "off": [0.0, 0.0, 0.0], "pole": [-1, -0.5, 0.2]},
			"hand_r": {"to": "b.hip_l", "off": [0.0, 0.0, 0.0], "pole": [1, -0.5, 0.2]},
			"foot_l": {"at": [-0.2, ANKLE, 0.86], "pole": [0, -0.3, -1], "flat": 0.0},
			"foot_r": {"at": [0.22, ANKLE, 0.18], "pole": [0.2, 0.2, -1]},
		},
		"b": {
			"root": [0.0, 0.56, -0.18], "turn": 180, "lean": -6, "bend": [6, 0, 0], "head": [8, 0],
			"hand_l": {"to": "a.fore_r", "off": [0.0, 0.0, 0.0], "pole": [0.8, -0.6, 0.2]},
			"hand_r": {"to": "a.fore_l", "off": [0.0, 0.0, 0.0], "pole": [-0.8, -0.6, 0.2]},
			"foot_l": {"at": [0.16, ANKLE, 0.04], "pole": [0, 0.3, -1]},
			"foot_r": {"at": [-0.16, ANKLE, 0.0], "pole": [0, 0.3, -1]},
		},
	}


## Up the fence: blue standing with his back on it, red standing in front with his hands still on his hips.
static func wall_up() -> Dictionary:
	return {
		"a": {
			"root": [0.04, 0.82, 0.38], "lean": 24, "bend": [8, 0, 0], "head": [-6, 20],
			"hand_l": {"to": "b.hip_r", "off": [0.0, 0.0, 0.0], "pole": [-1, -0.5, 0.2]},
			"hand_r": {"to": "b.hip_l", "off": [0.0, 0.0, 0.0], "pole": [1, -0.5, 0.2]},
			"foot_l": {"at": [-0.18, ANKLE, 0.58]},
			"foot_r": {"at": [0.2, ANKLE, 0.14]},
		},
		"b": {
			"root": [0.0, 0.86, -0.2], "turn": 180, "lean": -2, "bend": [4, 0, 0], "head": [4, 0],
			"hand_l": {"to": "a.fore_r", "off": [0.0, 0.0, 0.0], "pole": [0.8, -0.6, 0.2]},
			"hand_r": {"to": "a.fore_l", "off": [0.0, 0.0, 0.0], "pole": [-0.8, -0.6, 0.2]},
			"foot_l": {"at": [0.16, ANKLE, -0.1]},
			"foot_r": {"at": [-0.16, ANKLE, -0.16]},
		},
	}


# --- Standing up from the top -------------------------------------------------------------------

## Standing up out of it (D330), the first step: red postures up onto his right foot, his hands on blue's
## thighs; blue on his back, his feet on red's hips.
static func base_up() -> Dictionary:
	return {
		"a": {
			"root": [0.0, 0.58, 0.44], "lean": 26, "bend": [8, 0, 0], "head": [-4, 0],
			"hand_l": {"to": "b.shin_r", "off": [0.0, 0.18, 0.0], "pole": [-1, -0.4, 0.2]},
			"hand_r": {"to": "b.shin_l", "off": [0.0, 0.18, 0.0], "pole": [1, -0.4, 0.2]},
			"foot_l": {"at": [-0.2, ANKLE, 0.92], "pole": [0, -0.3, -1], "flat": 0.0},
			"foot_r": {"at": [0.24, ANKLE, 0.22], "pole": [0.2, 0.2, -1]},
		},
		"b": {
			"root": [0.0, 0.22, 0.0], "turn": 180, "lean": -72, "bend": [-6, 0, 0], "head": [28, 0],
			"foot_l": {"to": "a.hip_r", "off": [0.0, 0.0, 0.0], "pole": [0.3, 0.6, -1]},
			"foot_r": {"to": "a.hip_l", "off": [0.0, 0.0, 0.0], "pole": [-0.3, 0.6, -1]},
		},
	}


## Standing over him: red on his feet over blue's legs, bent over with his hands on blue's knees; blue on his
## back with his feet up at him.
static func over_him() -> Dictionary:
	return {
		"a": {
			"root": [0.0, 0.74, 0.7], "lean": 46, "bend": [10, 0, 0], "head": [-14, 0],
			"hand_l": {"to": "b.shin_r", "off": [0.0, 0.0, 0.0], "pole": [-1, -0.4, 0.2]},
			"hand_r": {"to": "b.shin_l", "off": [0.0, 0.0, 0.0], "pole": [1, -0.4, 0.2]},
			"foot_l": {"at": [-0.18, ANKLE, 0.98]},
			"foot_r": {"at": [0.2, ANKLE, 0.56]},
		},
		"b": {
			"root": [0.0, 0.18, 0.0], "turn": 180, "lean": -80, "bend": [-4, 0, 0], "head": [30, 0],
			"foot_l": {"at": [0.14, 0.56, 0.44], "pole": [0.3, 1, -0.4]},
			"foot_r": {"at": [-0.14, 0.5, 0.48], "pole": [-0.3, 1, -0.4]},
		},
	}


## Stepped off him: red standing a step away out of reach, blue still down on his back (he is left down a second).
static func stepped_off() -> Dictionary:
	return {
		"a": _stance(1.22, 0.0),
		"b": {
			"root": [0.0, 0.16, 0.0], "turn": 180, "lean": -84, "bend": [-4, 0, 0], "head": [26, 0],
			"foot_l": {"at": [0.16, 0.3, 0.5], "pole": [0.3, 1, -0.4]},
			"foot_r": {"at": [-0.16, ANKLE, 0.6], "pole": [-0.3, 1, -0.4]},
		},
	}


# --- Helpers ---------------------------------------------------------------------------------

## Both on their feet in their stance, red at `a_z` and blue at `b_z` facing him: where the ways up end.
static func apart(a_z: float, b_z: float) -> Dictionary:
	return {"a": _stance(a_z, 0.0), "b": _stance(b_z, 180.0)}


## A stance at `z` facing -Z (`turn` 0) or +Z (180): orthodox, hands up.
static func _stance(z: float, turn: float) -> Dictionary:
	var ahead: float = -1.0 if turn < 90.0 else 1.0
	var x: float = 1.0 if turn < 90.0 else -1.0
	return {
		"root": [0, FighterRig.PELVIS_HEIGHT - 0.06, z], "turn": turn - 18.0 * x, "lean": 6, "bend": [4, -14, 0],
		"foot_l": {"at": [-0.16 * x, ANKLE, z + ahead * 0.24]},
		"foot_r": {"at": [0.18 * x, ANKLE, z - ahead * 0.2]},
	}
