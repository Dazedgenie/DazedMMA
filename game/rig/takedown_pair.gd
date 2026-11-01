class_name TakedownPair
extends RefCounted
## Clinch takedowns from the rig (D288): the double leg, the outside trip, the hip throw and the guard pull
## as a path of paired poses for the two rigs, from the clinch pose they start in, through the entry and the
## fall, to the canvas. Written like RigPairs, with the man taking it down as "a" (on the +Z side of the pair
## frame, facing -Z) and the other man as "b". Presentation only.
##
## A path is an array of keys, each [pair, frame]: the clinch pose it starts from, the move's own keys (the
## entry first, then the fall) in that same frame, and the landing in the landing frame. The landing frame is
## laid out like today's ground position (ArenaView.lay_out): its origin on the canvas under the bottom man's
## hips, its +Z toward his feet. pose_along poses the rigs at any point along a path (0 the clinch, 1 the
## entry, the last key the landing), easing between the keys and between their frames.

const ANKLE: float = FighterRig.ANKLE_UP
## The clinch takedowns posed from the rig.
const MOVES: Array[String] = ["double_leg", "outside_trip", "hip_throw", "guard_pull"]
## Per move (Kyle, D288: the fall starts during the attempt, a thud on landing bigger for the throws):
## fall: how far from the entry toward the landing he is taken while the attempt is still being decided (its
##   active part), as a share of the way;
## land: seconds from there to the canvas once it works;
## thud: how hard the landing sounds, 0–1;
## at: where the bottom man's hips land (x, z) in the frame the move starts in (the hip throw puts him on the far
##   side of the man throwing him; the guard pull sits the puller down where he stood).
const TIMING := {
	"double_leg": {"fall": 0.5, "land": 0.35, "thud": 0.7, "at": Vector2(0.0, -0.55)},
	"outside_trip": {"fall": 0.5, "land": 0.3, "thud": 0.8, "at": Vector2(0.05, -0.6)},
	"hip_throw": {"fall": 0.3, "land": 0.5, "thud": 1.0, "at": Vector2(0.0, 0.75)},
	"guard_pull": {"fall": 0.6, "land": 0.3, "thud": 0.35, "at": Vector2(0.0, 0.25)},
}
## A takedown that only half works lands them both on their knees (a scramble), this hard.
const SCRAMBLE_THUD: float = 0.4
## Who ends up underneath: the other man, except in the guard pull.
const PULLS: Array[String] = ["guard_pull"]


## The move's own keys (the entry, then the fall), in the frame the move starts in.
static func keys(action: String) -> Array[Dictionary]:
	match action:
		"double_leg":
			return [RigPairs.double_leg(), _dl_drive()]
		"outside_trip":
			return [_trip_hook(), _trip_tip()]
		"hip_throw":
			return [_hip_load(), _hip_over(), _hip_flip()]
		"guard_pull":
			return [_pull_sit()]
	return []


## Where the move lands them, in the landing frame (the bottom man's hips at its origin, his feet toward +Z):
## his guard after a double leg, a trip or a guard pull, side control after the hip throw. `far` is the side
## of the bottom man the top man ends up on in a side position: +1 the landing frame's +X, -1 its -X.
static func landing(action: String, far: float = -1.0) -> Dictionary:
	match action:
		"hip_throw":
			var pair: Dictionary = GroundPair.side_control()
			return pair if far < 0.0 else ClinchPair.mirror(pair)
		"guard_pull":  # The puller underneath: the full guard with the men the other way round.
			return _at_hips(ClinchPair.half_turn(ClinchPair.swap(RigPairs.full_guard())), "a")
	return _at_hips(RigPairs.full_guard(), "b")


## The man underneath in `action`'s landing: "b", or "a" when he pulled guard.
static func bottom_man(action: String) -> String:
	return "a" if PULLS.has(action) else "b"


## A takedown that half worked: both on their knees, face to face, red's hands on blue's waist, in the frame
## the move started in.
static func scramble() -> Dictionary:
	var kneel := {"pole": [0, -0.3, -1], "flat": 0.0}
	return {
		"a": {
			"root": [0.12, 0.46, 0.4], "lean": 30, "bend": [10, 0, 0], "head": [-10, 30],
			"hand_l": {"to": "b.waist_r", "off": [0.0, 0.0, -0.02], "pole": [-1, -0.6, 0.2]},
			"hand_r": {"to": "b.waist_l", "off": [0.0, 0.0, -0.02], "pole": [1, -0.6, 0.2]},
			"foot_l": _with(kneel, {"at": [-0.2, ANKLE, 0.85]}),
			"foot_r": _with(kneel, {"at": [0.2, ANKLE, 0.87]}),
		},
		"b": {
			"root": [-0.1, 0.5, -0.4], "turn": 180, "lean": 24, "bend": [8, 0, 0], "head": [0, 30],
			"hand_l": {"to": "a.blade_r", "off": [0.0, 0.0, 0.03], "pole": [-0.6, 0.2, 0.6]},
			"hand_r": {"to": "a.shoulder_l", "off": [0.0, -0.04, 0.06], "pole": [0.6, -0.2, 0.6]},
			"foot_l": _with(kneel, {"at": [0.2, ANKLE, -0.86]}),
			"foot_r": _with(kneel, {"at": [-0.2, ANKLE, -0.84]}),
		},
	}


## The path for `action` started from `start` ([pair, frame]: the clinch pose as it was, the man taking it down as
## "a"), landing in `lying` (the landing frame's turn, with its origin anywhere: the move's TIMING `at` places
## it), with the top man on the `far` side (see landing). Each key's turns are set to go the short way round
## from the key before.
static func path(action: String, start: Array, lying: Basis, far: float = -1.0) -> Array:
	var from: Transform3D = start[1]
	var out: Array = [start]
	for pair: Dictionary in keys(action):
		out.append([pair, from])
	var land: Dictionary = landing(action, far)
	var at: Vector2 = TIMING[action].at
	out.append([land, Transform3D(lying, from * Vector3(at.x, 0.0, at.y))])
	return chain(out)


## The same path with its last key (the landing) swapped for the scramble, where a half-worked takedown ends.
static func to_scramble(keys_in: Array) -> Array:
	var out: Array = keys_in.duplicate()
	out[out.size() - 1] = [scramble(), Transform3D(out[0][1])]
	return chain(out)


## The same path with its moves after `x` swapped for the sprawl on the shot (RigPairs.sprawl, a double leg
## stopped): from where he is now, down onto his knees under the man sprawling on him.
static func to_sprawl(keys_in: Array, x: float) -> Array:
	return chain([[pose_at(keys_in, x), Transform3D(keys_in[0][1])], [RigPairs.sprawl(), Transform3D(keys_in[0][1])]])


## Poses the rigs `x` along `keys_in` (see path): between key floor(x) and the next one, each man's body and
## the frame mixed part of the way, the hands and feet moved between their places in the world.
static func pose_along(a: FighterRig, b: FighterRig, keys_in: Array, x: float) -> void:
	var at: Array = _between(keys_in, x)
	var from: Array = keys_in[at[0]]
	var to: Array = keys_in[at[0] + 1]
	var t: float = at[1]
	FighterRig.pose_pair(a, b, from[0], Transform3D(from[1]).interpolate_with(to[1], t), to[0], t)


## The body numbers at `x` along `keys_in` (the frame of the key it is in), for starting a new path from there.
static func pose_at(keys_in: Array, x: float) -> Dictionary:
	var at: Array = _between(keys_in, x)
	var from: Dictionary = keys_in[at[0]][0]
	var to: Dictionary = keys_in[at[0] + 1][0]
	var t: float = at[1]
	if t >= 0.5:  # The limbs where the nearer key has them.
		return {"a": _with(to.a, FighterRig.blend_body(from.a, to.a, t)), "b": _with(to.b, FighterRig.blend_body(from.b, to.b, t))}
	return {"a": _with(from.a, FighterRig.blend_body(from.a, to.a, t)), "b": _with(from.b, FighterRig.blend_body(from.b, to.b, t))}


## Each key after the first rewritten to follow the one before without spinning: its frame turned half round
## (and the pose with it, ClinchPair.half_turn) when it faces more than a quarter turn away, and each man's turn
## set so he goes the short way round to where he faces in the world.
static func chain(keys_in: Array) -> Array:
	var out: Array = [keys_in[0]]
	for k in range(1, keys_in.size()):
		var before: Array = out[k - 1]
		var pair: Dictionary = keys_in[k][0]
		var frame: Transform3D = keys_in[k][1]
		var was: Transform3D = before[1]
		if was.basis.z.dot(frame.basis.z) < 0.0:
			pair = ClinchPair.half_turn(pair)
			frame = frame * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
		var frame_turn: float = wrapf(_yaw(frame) - _yaw(was), -180.0, 180.0)
		var turned := {}
		for man: String in ["a", "b"]:
			var spec: Dictionary = (pair[man] as Dictionary).duplicate()
			var turn_was: float = float(before[0][man].get("turn", 0.0))
			var world: float = wrapf(float(spec.get("turn", 0.0)) + _yaw(frame) - turn_was - _yaw(was), -180.0, 180.0)
			spec.turn = turn_was + world - frame_turn
			turned[man] = spec
		out.append([turned, frame])
	return out


## The move's keys with names, for the preview and the tests.
static func examples() -> Dictionary:
	var out := {}
	for action: String in MOVES:
		var all: Array[Dictionary] = keys(action)
		for n in all.size():
			out["%s_%d" % [action, n + 1]] = all[n]
	return out


# --- The keys ------------------------------------------------------------------

## The double leg driving through: his arms round the backs of the knees, red drives forward off his back foot
## and blue tips back, his feet coming up off the canvas.
static func _dl_drive() -> Dictionary:
	return {
		"a": {
			"root": [0.2, 0.58, 0.0], "turn": -14, "lean": 46, "bend": [10, 0, -10], "head": [-20, -16],
			"hand_l": {"to": "b.thigh_r", "off": [0.0, -0.08, 0.09], "pole": [-0.9, -0.5, 0.3]},
			"hand_r": {"to": "b.thigh_l", "off": [0.0, -0.02, 0.09], "pole": [0.9, -0.5, 0.3]},
			"foot_l": {"at": [-0.16, ANKLE, -0.24]},
			"foot_r": {"at": [0.22, ANKLE, 0.5], "pole": [0, -0.4, -1]},
		},
		"b": {
			"root": [0.0, 0.78, -0.52], "turn": 180, "lean": -32, "bend": [-6, 0, 0], "head": [24, 0],
			"hand_l": {"at": [0.38, 0.95, -0.5], "pole": [-0.6, 0.4, 0.6]},
			"hand_r": {"at": [-0.42, 0.85, -0.7], "pole": [0.4, -0.4, 0.8]},
			"foot_l": {"at": [0.14, 0.3, -0.2]},
			"foot_r": {"at": [-0.14, 0.16, -0.28]},
		},
	}


## The outside trip hooked: red, in his body lock, steps his right leg round behind blue's left and hooks his heel.
static func _trip_hook() -> Dictionary:
	return {
		"a": {
			"root": [0.06, 0.84, 0.26], "turn": -12, "lean": 18, "bend": [8, -10, 0], "head": [8, -25],
			"hand_l": {"to": "b.blade_r", "off": [0.0, -0.04, 0.02], "pole": [-1, -0.6, 0.2]},
			"hand_r": {"to": "b.blade_l", "off": [-0.03, -0.1, 0.0], "pole": [1, -0.6, 0.2]},
			"foot_l": {"at": [-0.16, ANKLE, 0.3]},
			"foot_r": {"at": [0.28, 0.14, -0.3], "pole": [0.3, 0, -1]},
		},
		"b": {
			"root": [0.02, 0.88, -0.28], "turn": 180, "lean": 4, "bend": [4, 6, 0], "head": [10, 25],
			"hand_l": {"to": "a.blade_r", "off": [0.03, 0.02, 0.0], "pole": [-0.8, 0.2, 0.4]},
			"hand_r": {"to": "a.blade_l", "off": [-0.03, 0.02, 0.0], "pole": [0.8, 0.2, 0.4]},
			"foot_l": {"at": [0.2, ANKLE, -0.2]},
			"foot_r": {"at": [-0.2, ANKLE, -0.56]},
		},
	}


## The trip tipping him: red reaps the hooked leg up and drives his chest into blue, who goes back over it,
## the hooked foot in the air and a hand reaching back for the canvas.
static func _trip_tip() -> Dictionary:
	return {
		"a": {
			"root": [0.05, 0.72, -0.16], "turn": -12, "lean": 40, "bend": [10, -6, 0], "head": [0, -20],
			"hand_l": {"to": "b.blade_r", "off": [0.0, -0.04, 0.02], "pole": [-1, -0.6, 0.2]},
			"hand_r": {"to": "b.blade_l", "off": [0.0, -0.08, 0.02], "pole": [1, -0.6, 0.2]},
			"foot_l": {"at": [-0.16, ANKLE, 0.2]},
			"foot_r": {"at": [0.24, 0.36, -0.12], "pole": [0.3, 0, -1]},
		},
		"b": {
			"root": [0.06, 0.62, -0.42], "turn": 180, "lean": -46, "bend": [-6, 10, 0], "head": [28, 0],
			"hand_l": {"to": "a.blade_r", "off": [0.03, 0.02, 0.0], "pole": [-0.8, 0.2, 0.4]},
			"hand_r": {"at": [-0.36, 0.38, -0.7], "pole": [0.4, -0.6, 0.6]},
			"foot_l": {"at": [0.18, 0.42, -0.1]},
			"foot_r": {"at": [-0.18, ANKLE, -0.5]},
		},
	}


## The hip throw loaded: red has turned in, his back to blue's front and his hips low under blue's, his right arm
## round blue's waist and his left hand pulling blue's right arm across; blue bends over him.
static func _hip_load() -> Dictionary:
	return {
		"a": {
			"root": [0.0, 0.7, -0.13], "turn": 175, "lean": 26, "bend": [12, 0, 0], "head": [-6, 20],
			"hand_l": {"to": "b.fore_r", "off": [0.0, 0.0, 0.0], "pole": [0.6, -0.8, -0.4]},
			"hand_r": {"to": "b.lower_back", "off": [-0.12, 0.02, 0.02], "pole": [-1, -0.2, 0.2]},
			"foot_l": {"at": [0.14, ANKLE, -0.12]},
			"foot_r": {"at": [-0.14, ANKLE, -0.1]},
		},
		"b": {
			"root": [0.0, 0.92, -0.34], "turn": 180, "lean": 26, "bend": [12, 0, 0], "head": [10, 0],
			"hand_l": {"to": "a.blade_l", "off": [0.0, 0.0, 0.04], "pole": [-0.6, 0.2, 0.6]},
			"hand_r": {"to": "a.shoulder_l", "off": [0.0, -0.06, -0.05], "pole": [-0.4, -0.4, -0.8]},
			"foot_l": {"at": [0.18, ANKLE, -0.36]},
			"foot_r": {"at": [-0.18, ANKLE, -0.44]},
		},
	}


## The hip throw lifting: red straightens his legs and bends over, blue's hips come up over red's and his body
## lies across red's back, his feet leaving the canvas.
static func _hip_over() -> Dictionary:
	return {
		"a": {
			"root": [0.0, 0.84, -0.02], "turn": 175, "lean": 62, "bend": [18, 0, 0], "head": [-24, 20],
			"hand_l": {"to": "b.fore_r", "off": [0.0, 0.0, 0.0], "pole": [0.6, -0.8, -0.4]},
			"hand_r": {"to": "b.lower_back", "off": [-0.12, 0.02, 0.02], "pole": [-1, -0.2, 0.2]},
			"foot_l": {"at": [0.14, ANKLE, -0.12]},
			"foot_r": {"at": [-0.14, ANKLE, -0.1]},
		},
		"b": {
			"root": [-0.17, 1.24, -0.08], "turn": 180, "lean": 80, "bend": [6, 0, 0], "head": [-10, 0],
			"hand_l": {"to": "a.back", "off": [0.06, 0.0, 0.06], "pole": [0.6, 0.2, 0.6]},
			"hand_r": {"to": "a.shoulder_r", "off": [0.0, -0.04, -0.04], "pole": [-0.4, -0.4, -0.8]},
			"foot_l": {"at": [0.18, 0.86, -0.72]},
			"foot_r": {"at": [-0.14, 0.7, -0.78]},
		},
	}


## The hip throw over the top (Kyle, D288: big, feet over the top): blue upside down over red's shoulder, his
## feet in the air above them both, his head coming down in front of red.
static func _hip_flip() -> Dictionary:
	return {
		"a": {
			"root": [0.0, 0.8, 0.02], "turn": 175, "lean": 76, "bend": [20, 0, 0], "head": [-30, 20],
			"hand_l": {"to": "b.fore_r", "off": [0.0, 0.0, 0.0], "pole": [0.6, -0.8, -0.4]},
			"hand_r": {"to": "b.lower_back", "off": [-0.12, 0.02, 0.02], "pole": [-1, -0.2, 0.2]},
			"foot_l": {"at": [0.14, ANKLE, -0.12]},
			"foot_r": {"at": [-0.14, ANKLE, -0.1]},
		},
		"b": {
			"root": [-0.42, 1.26, 0.2], "turn": 180, "lean": 186, "bend": [6, 0, 0], "head": [-20, 0],
			"hand_l": {"at": [-0.16, 0.36, 0.26], "pole": [0.6, 0.2, 0.6]},
			"hand_r": {"to": "a.shoulder_r", "off": [0.0, -0.04, -0.04], "pole": [-0.4, -0.4, -0.8]},
			"foot_l": {"at": [0.18, 1.86, 0.14]},
			"foot_r": {"at": [-0.14, 1.84, 0.0]},
		},
	}


## The guard pull: red sits down under blue, one foot on blue's hip and his hands on the back of blue's neck,
## pulling him forward and down.
static func _pull_sit() -> Dictionary:
	return {
		"a": {
			"root": [0.0, 0.42, 0.24], "lean": -34, "bend": [16, 0, 0], "head": [20, 0],
			"hand_l": {"to": "b.nape", "off": [0.04, 0.0, 0.0], "pole": [-1, -0.4, 0.2]},
			"hand_r": {"to": "b.nape", "off": [-0.04, 0.0, 0.0], "pole": [1, -0.4, 0.2]},
			"foot_l": {"at": [-0.2, ANKLE, -0.08]},
			"foot_r": {"to": "b.hip_l", "off": [0.0, 0.0, -0.06], "pole": [0.6, 0.6, -0.4]},
		},
		"b": {
			"root": [0.0, 0.8, -0.32], "turn": 180, "lean": 40, "bend": [16, 0, 0], "head": [-10, 0],
			"hand_l": {"to": "a.chest", "off": [0.12, 0.0, -0.04], "pole": [-0.6, -0.4, 0.6]},
			"hand_r": {"to": "a.chest", "off": [-0.12, 0.0, -0.04], "pole": [0.6, -0.4, 0.6]},
			"foot_l": {"at": [0.18, ANKLE, -0.36]},
			"foot_r": {"at": [-0.2, ANKLE, -0.62]},
		},
	}


# --- Helpers ---------------------------------------------------------------------

## `pair` moved on the canvas so `man`'s hips are over the frame's origin.
static func _at_hips(pair: Dictionary, man: String) -> Dictionary:
	var hips: Array = pair[man].root
	var dx: float = float(hips[0])
	var dz: float = float(hips[2])
	var out := {}
	for who: String in pair:
		var spec: Dictionary = (pair[who] as Dictionary).duplicate(true)
		spec.root = [float(spec.root[0]) - dx, spec.root[1], float(spec.root[2]) - dz]
		for key: String in spec:
			if spec[key] is Dictionary and (spec[key] as Dictionary).has("at"):
				var at: Array = spec[key].at
				spec[key].at = [float(at[0]) - dx, at[1], float(at[2]) - dz]
		out[who] = spec
	return out


## `base` with `extra`'s keys over it.
static func _with(base: Dictionary, extra: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate()
	out.merge(extra, true)
	return out


## [key index, share of the way to the next key] for `x` along a path of `keys_in`.
static func _between(keys_in: Array, x: float) -> Array:
	var last: int = keys_in.size() - 1
	var at: float = clampf(x, 0.0, float(last))
	var k: int = mini(floori(at), last - 1)
	return [k, at - float(k)]


## The way a frame faces, as a turn (degrees) about the vertical: 0 with its +Z the world's +Z.
static func _yaw(frame: Transform3D) -> float:
	var z: Vector3 = frame.basis.z
	return rad_to_deg(atan2(z.x, z.z))
