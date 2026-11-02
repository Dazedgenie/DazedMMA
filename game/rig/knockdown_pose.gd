class_name KnockdownPose
extends RefCounted
## Knockdowns from the rig (D370): a man dropped falls the way the shot that dropped him sends him, lies there and
## gets up through a knee (D371), one man posed on his own, the other still drawn by today's figures. Presentation
## only: the fight is the same.
##
## Each pose is one man's rig spec (FighterRig.set_body, set_limbs) in his own frame: the origin on the canvas
## between his feet where he stood, +Z behind him (away from the other man), so he faces -Z. A fall is a list of
## [spec, frame] keys from his stance to how he lies; getting up, from how he lies back to his feet. The man is
## posed as corner "a", so "a." points are on his own body.

const ANKLE: float = FighterRig.ANKLE_UP
## The four ways down (Kyle, D370: by the shot that dropped him): "stiff" (a flash knockdown: out on his feet, he
## tips back straight, his arms up in front), "crumple" (dropped while rocked: his knees go, he sits and falls back),
## "liver" (a liver shot: he folds onto his knees and curls up over it) and "leg" (a leg giving out: down onto that
## knee, a hand on the canvas). "fence" is a stiff or crumpled fall with no room behind him: he slides down the fence
## and sits against it.
const KINDS: Array[String] = ["stiff", "crumple", "liver", "leg", "fence"]
## Seconds of fight time: fall, how long the fall takes; rise, how long getting up takes, at the end of his time
## down (FightSim: DOWN_TICKS 2 s, LIVER_DOWN_TICKS 3 s, LEG_DOWN_TICKS 1 s); twist, how far round (degrees) a
## hook or a round kick that dropped him turns the fall toward the side it came from.
const TIMING := {
	"stiff": {"fall": 0.45, "rise": 0.9, "twist": 55.0},
	"crumple": {"fall": 0.7, "rise": 0.9, "twist": 35.0},
	"liver": {"fall": 0.8, "rise": 1.0, "twist": 0.0},
	"leg": {"fall": 0.3, "rise": 0.45, "twist": 0.0},
	"fence": {"fall": 0.6, "rise": 0.9, "twist": 0.0},
}
## How far behind where his feet were (metres) his head ends up lying flat: the fall needs this much room inside the
## fence, or he goes down it instead ("fence").
const LYING_LENGTH: float = 1.75
## The room the fall keeps from the fence (metres).
const FENCE_ROOM: float = 0.15


## The keys of the fall, in order, starting from his stance.
static func falls(kind: String) -> Array[Dictionary]:
	match kind:
		"stiff":
			return [stance(), tipping(), flat()]
		"crumple":
			return [stance(), buckled(), seated(), flat()]
		"liver":
			return [hunched(), on_his_knees(), curled()]
		"leg":
			return [stance(), dropped_to_a_knee()]
		"fence":
			return [stance(), sliding_down(), sat_on_the_fence()]
	return []


## The keys of getting up (Kyle, D371: to a knee, then up on wobbly legs), from how the fall left him.
static func rises(kind: String) -> Array[Dictionary]:
	match kind:
		"liver":
			return [curled(), hand_and_knee(), on_one_knee(), up_hurt()]
		"leg":
			return [dropped_to_a_knee(), up_hurt()]
		"fence":
			return [sat_on_the_fence(), half_up_the_fence(), up_the_fence()]
	return [flat(), sat_up(), on_one_knee(), up_hurt()]


## How he lies at the end of a fall.
static func lying(kind: String) -> Dictionary:
	var keys: Array[Dictionary] = falls(kind)
	return keys[keys.size() - 1]


## The keys with names, for the preview and the tests.
static func examples() -> Dictionary:
	var out := {}
	for kind: String in KINDS:
		var down: Array[Dictionary] = falls(kind)
		for n in down.size():
			out["%s_down_%d" % [kind, n]] = down[n]
		var up: Array[Dictionary] = rises(kind)
		for n in range(1, up.size()):
			out["%s_up_%d" % [kind, n]] = up[n]
	return out


## Poses `rig` (as corner "a") at `x` along `path` ([spec, frame] keys, x from 0 to the last key's index), easing
## the frames and the bodies between keys. `other` is the other man's rig (nothing here reaches for him).
static func pose_along(rig: FighterRig, other: FighterRig, path: Array, x: float) -> void:
	var last: int = path.size() - 1
	var k: int = clampi(floori(x), 0, maxi(last - 1, 0))
	var t: float = clampf(x - k, 0.0, 1.0) if last > 0 else 0.0
	var from: Array = path[k]
	var to: Array = path[mini(k + 1, last)]
	var frame: Transform3D = Transform3D(from[1]).interpolate_with(to[1], t)
	rig.corner = "a"
	rig.set_body(FighterRig.blend_body(from[0], to[0], t), frame)
	for repeat in 2:  # Twice, so a hand on his own shin finds it where the leg ended up.
		rig.set_limbs(from[0], frame, other, to[0], t)


## How far along the fall or the rise (0 to the last key) `seconds` into it is: quicker as he falls (gravity), and
## eased getting up.
static func fall_x(keys: int, seconds: float, kind: String) -> float:
	var t: float = clampf(seconds / float(TIMING[kind].fall), 0.0, 1.0)
	return (keys - 1) * pow(t, 1.6)


static func rise_x(keys: int, seconds: float, kind: String) -> float:
	var t: float = clampf(seconds / float(TIMING[kind].rise), 0.0, 1.0)
	return (keys - 1) * smoothstep(0.0, 1.0, t)


# --- Standing -------------------------------------------------------------------------------

## His stance where he stood, orthodox (mirror it for a southpaw), hands up.
static func stance() -> Dictionary:
	return {
		"root": [0, FighterRig.PELVIS_HEIGHT - 0.06, 0.0], "turn": -18, "lean": 6, "bend": [4, -14, 0],
		"foot_l": {"at": [-0.16, ANKLE, -0.24]},
		"foot_r": {"at": [0.18, ANKLE, 0.2]},
	}


## Back on his feet but still hurt: knees bent, bent over a little, hands low (the rocked wobble takes over, D372).
static func up_hurt() -> Dictionary:
	return {
		"root": [0, FighterRig.PELVIS_HEIGHT - 0.14, 0.04], "turn": -14, "lean": 16, "bend": [10, -10, 0], "head": [-6, 0],
		"hand_l": {"at": [-0.2, 1.08, -0.3], "pole": [-1, -0.6, 0.2]},
		"hand_r": {"at": [0.22, 1.02, -0.24], "pole": [1, -0.6, 0.2]},
		"foot_l": {"at": [-0.18, ANKLE, -0.22]},
		"foot_r": {"at": [0.2, ANKLE, 0.2]},
	}


# --- Down flat: the stiff fall and the crumple -------------------------------------------------------

## Out on his feet (a flash knockdown): stiff as a board, tipping back, his arms up in front of him.
static func tipping() -> Dictionary:
	return {
		"root": [0, 0.86, 0.24], "turn": -8, "lean": -30, "head": [12, 0],
		"hand_l": {"at": [-0.18, 1.45, 0.08], "pole": [-1, -0.2, 0.4]},
		"hand_r": {"at": [0.17, 1.47, 0.12], "pole": [1, -0.2, 0.4]},
		"foot_l": {"at": [-0.16, ANKLE, -0.2]},
		"foot_r": {"at": [0.18, ANKLE, 0.12]},
	}


## Dropped while rocked: his knees go out from under him, his hands falling.
static func buckled() -> Dictionary:
	return {
		"root": [0, 0.56, 0.1], "turn": -10, "lean": 16, "roll": 6, "bend": [14, 0, 6], "head": [-22, 10],
		"hand_l": {"at": [-0.26, 0.66, -0.12], "pole": [-1, -0.6, 0.2]},
		"hand_r": {"at": [0.26, 0.62, -0.04], "pole": [1, -0.6, 0.2]},
		"foot_l": {"at": [-0.18, ANKLE, -0.24], "pole": [0, 0.2, -1]},
		"foot_r": {"at": [0.2, ANKLE, 0.12], "pole": [0, 0.2, -1]},
	}


## Sat down hard, falling back, his arms limp.
static func seated() -> Dictionary:
	return {
		"root": [0, 0.17, 0.3], "turn": -6, "lean": -36, "bend": [-4, 0, 0], "head": [14, 8],
		"hand_l": {"at": [-0.3, 0.08, 0.42], "pole": [-1, 0.2, 0.4]},
		"hand_r": {"at": [0.3, 0.08, 0.48], "pole": [1, 0.2, 0.4]},
		"foot_l": {"at": [-0.18, ANKLE, -0.32], "pole": [-0.2, 1, -0.4]},
		"foot_r": {"at": [0.22, ANKLE, -0.22], "pole": [0.2, 1, -0.4]},
	}


## Flat on his back, his head turned to the side, his arms out by his head, his knees a little bent; his feet
## toward the man who dropped him.
static func flat() -> Dictionary:
	return {
		"root": [0, 0.15, 0.62], "lean": -86, "bend": [-2, 0, 0], "head": [24, 14],
		"hand_l": {"at": [-0.34, 0.08, 1.08], "pole": [-1, 0.4, 0]},
		"hand_r": {"at": [0.36, 0.08, 1.0], "pole": [1, 0.4, 0]},
		"foot_l": {"at": [-0.2, ANKLE, -0.1], "pole": [-0.2, 1, -0.2]},
		"foot_r": {"at": [0.18, ANKLE, -0.14], "pole": [0.2, 1, -0.2]},
	}


## Getting up, sat up: propped on his hands behind him, his knees up.
static func sat_up() -> Dictionary:
	return {
		"root": [0, 0.16, 0.32], "lean": -45, "bend": [14, 0, 0], "head": [-14, 0],
		"hand_l": {"at": [-0.32, 0.04, 0.86], "pole": [-1, 0.4, 0.6]},
		"hand_r": {"at": [0.32, 0.04, 0.84], "pole": [1, 0.4, 0.6]},
		"foot_l": {"at": [-0.18, ANKLE, -0.24], "pole": [0, 1, -0.6]},
		"foot_r": {"at": [0.2, ANKLE, -0.16], "pole": [0, 1, -0.6]},
	}


## Up on one knee: his left knee on the canvas, the right foot planted, both hands on that knee pushing off it.
static func on_one_knee() -> Dictionary:
	return {
		"root": [0, 0.56, 0.18], "turn": -6, "lean": 28, "bend": [14, 0, 0], "head": [-10, 0],
		"hand_l": {"to": "a.shin_r", "off": [-0.06, 0.24, 0.0], "pole": [-1, -0.6, 0.2]},
		"hand_r": {"to": "a.shin_r", "off": [0.04, 0.2, 0.0], "pole": [1, -0.6, 0.2]},
		"foot_l": {"at": [-0.14, 0.08, 0.62], "pole": [0, -0.4, -1], "flat": 0.0},
		"foot_r": {"at": [0.2, ANKLE, -0.16], "pole": [0, 0.2, -1]},
	}


# --- The liver shot -----------------------------------------------------------------------------

## Bent over it, his hands going to his right side (the liver), as today's figure holds him while it takes him.
static func hunched() -> Dictionary:
	return {
		"root": [0, 0.8, 0.04], "turn": -10, "lean": 34, "bend": [18, -6, 0], "head": [-14, 0],
		"hand_l": {"to": "a.waist_r", "off": [0.0, 0.0, -0.04], "pole": [-1, -0.6, 0.2]},
		"hand_r": {"to": "a.waist_r", "off": [0.04, -0.06, 0.0], "pole": [1, -0.6, 0.2]},
		"foot_l": {"at": [-0.16, ANKLE, -0.22]},
		"foot_r": {"at": [0.18, ANKLE, 0.18]},
	}


## Folded onto both knees, still holding it.
static func on_his_knees() -> Dictionary:
	return {
		"root": [0, 0.5, 0.14], "lean": 34, "bend": [22, 0, 0], "head": [-18, 0],
		"hand_l": {"to": "a.waist_r", "off": [0.0, 0.0, -0.04], "pole": [-1, -0.6, 0.2]},
		"hand_r": {"to": "a.waist_r", "off": [0.04, -0.06, 0.0], "pole": [1, -0.6, 0.2]},
		"foot_l": {"at": [-0.14, 0.08, 0.6], "pole": [0, -0.4, -1], "flat": 0.0},
		"foot_r": {"at": [0.14, 0.08, 0.6], "pole": [0, -0.4, -1], "flat": 0.0},
	}


## Curled up over it on his knees, his forehead near the canvas.
static func curled() -> Dictionary:
	return {
		"root": [0, 0.36, 0.3], "lean": 66, "bend": [28, 0, 0], "head": [-20, 0],
		"hand_l": {"to": "a.waist_r", "off": [0.0, 0.0, -0.04], "pole": [-1, -0.6, 0.2]},
		"hand_r": {"to": "a.waist_r", "off": [0.04, -0.06, 0.0], "pole": [1, -0.6, 0.2]},
		"foot_l": {"at": [-0.14, 0.08, 0.66], "pole": [0, -0.4, -1], "flat": 0.0},
		"foot_r": {"at": [0.14, 0.08, 0.66], "pole": [0, -0.4, -1], "flat": 0.0},
	}


## Getting up from it: a hand on the canvas, the other still on his side, his right foot coming up under him.
static func hand_and_knee() -> Dictionary:
	return {
		"root": [0, 0.38, 0.28], "lean": 74, "bend": [20, 0, 0], "head": [-16, 0],
		"hand_l": {"at": [-0.28, 0.04, -0.42], "pole": [-1, -0.4, 0.2]},
		"hand_r": {"to": "a.waist_r", "off": [0.04, -0.06, 0.0], "pole": [1, -0.6, 0.2]},
		"foot_l": {"at": [-0.14, 0.08, 0.64], "pole": [0, -0.4, -1], "flat": 0.0},
		"foot_r": {"at": [0.2, ANKLE, -0.02], "pole": [0, 0.2, -1]},
	}


# --- A leg giving out -------------------------------------------------------------------------

## The front leg gone: down on that knee, the other foot planted, his hands on the other knee.
static func dropped_to_a_knee() -> Dictionary:
	return {
		"root": [0.04, 0.5, 0.12], "turn": -14, "lean": 30, "roll": -8, "bend": [10, 0, -6], "head": [-8, 0],
		"hand_l": {"to": "a.shin_r", "off": [-0.06, 0.24, 0.0], "pole": [-1, -0.6, 0.2]},
		"hand_r": {"to": "a.shin_r", "off": [0.04, 0.2, 0.0], "pole": [1, -0.6, 0.2]},
		"foot_l": {"at": [-0.14, 0.08, 0.52], "pole": [0, -0.4, -1], "flat": 0.0},
		"foot_r": {"at": [0.22, ANKLE, -0.12], "pole": [0, 0.2, -1]},
	}


# --- Down the fence ----------------------------------------------------------------------------
# In the fence's frame: the origin ScramblePair.FENCE_BACK in from the fence, +Z toward it (behind him, as in his own
# frame), so he faces the middle (ArenaView.wall_frame turned half round).

## Sliding down it, his back on it.
static func sliding_down() -> Dictionary:
	return {
		"root": [0, 0.58, 0.12], "lean": -10, "bend": [6, 0, 0], "head": [-16, 10],
		"hand_l": {"at": [-0.3, 0.56, 0.15], "pole": [-1, -0.6, 0]},
		"hand_r": {"at": [0.3, 0.56, 0.15], "pole": [1, -0.6, 0]},
		"foot_l": {"at": [-0.16, ANKLE, -0.3], "pole": [0, 0.3, -1]},
		"foot_r": {"at": [0.16, ANKLE, -0.26], "pole": [0, 0.3, -1]},
	}


## Sat against it, slumped, his legs out in front and his hands on his thighs.
static func sat_on_the_fence() -> Dictionary:
	return {
		"root": [0, 0.17, 0.0], "lean": -16, "bend": [14, 0, 6], "head": [-24, 16],
		"hand_l": {"to": "a.thigh_l", "off": [0.0, -0.06, 0.0], "pole": [-1, -0.4, 0]},
		"hand_r": {"to": "a.thigh_r", "off": [0.0, 0.0, 0.0], "pole": [1, -0.4, 0]},
		"foot_l": {"at": [-0.18, ANKLE, -0.72], "pole": [0, 1, -0.6]},
		"foot_r": {"at": [0.16, ANKLE, -0.6], "pole": [0, 1, -0.6]},
	}


## Getting up it: his back on it, his hips up and feet under him, bent over his hands on his thighs.
static func half_up_the_fence() -> Dictionary:
	return {
		"root": [0, 0.56, 0.16], "lean": 12, "bend": [40, 0, 0], "head": [-8, 0],
		"hand_l": {"to": "a.thigh_l", "off": [0.0, -0.12, 0.0], "pole": [-1, -0.6, 0.2]},
		"hand_r": {"to": "a.thigh_r", "off": [0.0, -0.12, 0.0], "pole": [1, -0.6, 0.2]},
		"foot_l": {"at": [-0.16, ANKLE, -0.06], "pole": [0, 0.3, -1]},
		"foot_r": {"at": [0.16, ANKLE, -0.02], "pole": [0, 0.3, -1]},
	}


## Up, still leaning back on it.
static func up_the_fence() -> Dictionary:
	return {
		"root": [0, FighterRig.PELVIS_HEIGHT - 0.12, 0.18], "lean": 4, "bend": [8, 0, 0], "head": [-4, 0],
		"hand_l": {"at": [-0.22, 1.1, -0.1], "pole": [-1, -0.6, 0.2]},
		"hand_r": {"at": [0.22, 1.06, -0.12], "pole": [1, -0.6, 0.2]},
		"foot_l": {"at": [-0.16, ANKLE, 0.08]},
		"foot_r": {"at": [0.16, ANKLE, 0.12]},
	}
