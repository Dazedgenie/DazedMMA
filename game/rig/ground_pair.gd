class_name GroundPair
extends RefCounted
## The ground positions as paired poses for the rig (D289): full guard, half guard, side control, mount, the back
## and the crucifix, each with the grips the sim says are held (D263, D264) and ground and pound thrown from
## the pose. Written like RigPairs with the man on top as "a" and the man underneath as "b". Presentation only.
##
## The ground frame is laid out like today's ground positions (ArenaView.lay_out): its origin on the canvas
## under the bottom man's hips, its +Z toward his feet. The top man is on the frame's -X side of him in a side
## position (half guard, side control, the crucifix); `far` +1 mirrors the pose to put him on the +X side.

const ANKLE: float = FighterRig.ANKLE_UP
## The positions posed from the rig.
const POSITIONS: Array[String] = ["full_guard", "half_guard", "side_control", "mount", "back_control", "crucifix"]
## The positions the man on top is beside the man underneath in (mirrored by `far`).
const SIDE_POSITIONS: Array[String] = ["half_guard", "side_control", "crucifix"]
## Posturing up on top (posture_up, the posture-up bomb's wind-up: Kyle, D289 "the bomb sits up"): how much
## more upright he sits (degrees off his lean) and how much higher his hips come.
const POSTURE_LEAN: float = 26.0
const POSTURE_RISE: float = 0.08
## A collar tie held from underneath (D263): how much further his posture is broken (degrees) and his hips sink.
const COLLAR_LEAN: float = 30.0
const COLLAR_SINK: float = 0.03
const COLLAR_FORWARD: float = 0.08
## Turned toward him for the half-guard underhook (degrees of roll), flattened by the crossface.
const UNDERHOOK_ROLL: float = 24.0
## A sweep or a bridge rolling them over (D289): at the top of the roll the man going over ("a") is tipped this
## far onto his side and the man coming up ("b") this far (degrees), both lifted ROLL_RISE.
const ROLL_SIDE := {"a": 70.0, "b": 30.0}
const ROLL_RISE: float = 0.06
## The moves that roll them over (Kyle, D289): the man underneath ends up on top.
const ROLLS: Array[String] = ["sweep", "bridge", "escape_back"]
## Ground and pound from the pose (Kyle, D289: the striking arm only, the bomb sits him up first): where each
## strike's hand goes on the man underneath ({to, off} in that point's bone, and the way the elbow points, out to
## his striking side), from cocked by his own ear.
const STRIKES := {
	"ground_punch": {"to": "head", "off": [0.0, 0.0, -0.1]},
	"hammerfist": {"to": "head", "off": [0.0, 0.04, -0.12]},
	"ground_elbow": {"to": "head", "off": [0.0, 0.04, -0.12], "pole": [0.3, 1.0, 0.4]},  # The elbow up, coming down.
	"ground_body_punch": {"to": "belly", "off": [0.0, 0.0, -0.06]},
	"posture_bomb": {"to": "head", "off": [0.0, 0.0, -0.1]},
}
## Strikes from the bottom (D271): the man underneath ("b") throws up from his back at the man on top's head,
## from his hand by his own face. The elbow comes across (`pole` out to his side), the punch straight up.
const BOTTOM_STRIKES := {
	"bottom_punch": {"to": "head", "off": [0.0, 0.0, -0.1]},
	"bottom_elbow": {"to": "head", "off": [0.06, 0.0, -0.06], "pole": [1.0, -0.2, 0.6]},
}
## His fist before it goes: by his own face (in his head's frame; x toward the striking side).
const BOTTOM_COCKED := [0.1, 0.0, -0.12]
## Throwing it he lifts his head and shoulders this much off the canvas (degrees of lean).
const BOTTOM_LIFT: float = 10.0
## Throwing it he leans this much further into it (degrees): his arm does the work, his weight follows a little.
const STRIKE_LEAN: float = 14.0
## The cocked fist: by his own ear, out to the side and back (in his head's frame; x toward the striking side).
const COCKED := [0.16, 0.06, 0.1]


## The pair pose for one moment on the ground in `where` (POSITIONS):
## `grips` (ArenaView.ground_grips_now): {wrists: how many of the top man's wrists the man underneath holds (0–2),
## collar: he holds the collar tie, underhook: he has the half-guard underhook, crossface: the top man took it
## back with the crossface, frame: his forearm frame is up, two_on_one: both his hands on the choking arm,
## cover: he is covering up}, missing keys false;
## `posture`: the top man is posturing up (the posture-up move, or the bomb's wind-up);
## `far`: the side of the bottom man the top man is on in a side position (-1 the frame's -X, +1 its +X).
## Returns {pair: {a: top, b: bottom}, kind: `where`}, or empty when `where` isn't posed from the rig.
static func build(where: String, grips: Dictionary = {}, posture: bool = false, far: float = -1.0) -> Dictionary:
	if not POSITIONS.has(where):
		return {}
	var pair: Dictionary = base(where)
	var a: Dictionary = pair.a
	var b: Dictionary = pair.b
	var wrists: int = int(grips.get("wrists", 0))
	var collar: bool = bool(grips.get("collar", false))
	match where:
		"full_guard", "half_guard":
			if posture and not collar:
				_sit_up(a)
				b.erase("hand_l")  # His grips torn off: hands up against what's coming.
				b.erase("hand_r")
			if collar:  # Both hands behind his head, pulling it down: his posture broken.
				a.lean = float(a.lean) + COLLAR_LEAN
				a.root = [a.root[0], float(a.root[1]) - COLLAR_SINK, float(a.root[2]) - COLLAR_FORWARD]
				a.head = [-30, 0]
				b.hand_l = {"to": "a.nape", "off": [0.05, 0.0, 0.0], "pole": [1, 0.2, 0.4]}
				b.hand_r = {"to": "a.nape", "off": [-0.05, 0.0, 0.0], "pole": [-1, 0.2, 0.4]}
			elif wrists > 0:  # His wrists held: the bottom man's hands on them.
				b.hand_l = {"to": "a.wrist_r", "off": [0.0, 0.0, 0.0], "pole": [1, 0.0, 0.3]}
				if wrists > 1:
					b.hand_r = {"to": "a.wrist_l", "off": [0.0, 0.0, 0.0], "pole": [-1, 0.0, 0.3]}
			if where == "half_guard":
				if bool(grips.get("crossface", false)):
					_crossface(pair)
				elif bool(grips.get("underhook", false)):
					_underhook(pair)
		"side_control", "mount":
			if posture:
				_sit_up(a)
			if bool(grips.get("frame", false)):  # A forearm across his neck, the other hand on his hip.
				if where == "side_control":
					b.hand_l = {"to": "a.neck", "off": [0.0, 0.0, 0.0], "pole": [1, -0.2, 0.4]}
				else:
					b.hand_r = {"to": "a.sternum", "off": [0.0, 0.0, -0.04], "pole": [-1, -0.4, 0.2]}
		"back_control":
			if bool(grips.get("two_on_one", false)):  # Both hands on the choking arm.
				b.hand_l = {"to": "a.fore_r", "off": [0.0, -0.06, 0.04], "pole": [1, -0.6, 0.4]}
				b.hand_r = {"to": "a.fore_r", "off": [0.0, 0.06, 0.04], "pole": [-1, -0.6, 0.4]}
	if bool(grips.get("cover", false)):  # Gloves up in front of his face.
		b.hand_l = {"to": "b.head", "off": [0.0 if where == "crucifix" else 0.07, 0.0, -0.13], "pole": [1, -0.2, 0.0]}
		if where != "crucifix":  # The rider's legs still pin this arm.
			b.hand_r = {"to": "b.head", "off": [-0.07, 0.0, -0.13], "pole": [-1, -0.2, 0.0]}
	if far > 0.0 and SIDE_POSITIONS.has(where):
		pair = ClinchPair.mirror(pair)
	return {"pair": pair, "kind": where}


## Each position held with no grips, the man on top "a".
static func base(where: String) -> Dictionary:
	match where:
		"full_guard":
			return _at_hips(RigPairs.full_guard(), "b")
		"half_guard":
			return _half_guard()
		"side_control":
			return side_control()
		"mount":
			return _mount()
		"back_control":
			return _back()
		"crucifix":
			return _crucifix()
	return {}


## Positions and grips to look at and test, by name: [where, grips, posture, far].
static func examples() -> Dictionary:
	return {
		"full_guard": ["full_guard", {}, false, -1.0],
		"full_guard_wrists": ["full_guard", {"wrists": 2}, false, -1.0],
		"full_guard_one_wrist": ["full_guard", {"wrists": 1}, false, -1.0],
		"full_guard_collar": ["full_guard", {"collar": true}, false, -1.0],
		"full_guard_postured": ["full_guard", {}, true, -1.0],
		"full_guard_cover": ["full_guard", {"cover": true}, false, -1.0],
		"half_guard": ["half_guard", {}, false, -1.0],
		"half_guard_underhook": ["half_guard", {"underhook": true}, false, -1.0],
		"half_guard_crossface": ["half_guard", {"crossface": true}, false, -1.0],
		"half_guard_far": ["half_guard", {}, false, 1.0],
		"side_control": ["side_control", {}, false, -1.0],
		"side_control_frame": ["side_control", {"frame": true}, false, -1.0],
		"side_control_far": ["side_control", {}, false, 1.0],
		"mount": ["mount", {}, false, -1.0],
		"mount_frame": ["mount", {"frame": true}, false, -1.0],
		"mount_postured": ["mount", {}, true, -1.0],
		"mount_cover": ["mount", {"cover": true}, false, -1.0],
		"back_control": ["back_control", {}, false, -1.0],
		"back_control_two_on_one": ["back_control", {"two_on_one": true}, false, -1.0],
		"crucifix": ["crucifix", {}, false, -1.0],
		"crucifix_far": ["crucifix", {}, false, 1.0],
	}


## A ground strike thrown from `pair` (built, the man on top "a") with his `letter` arm ("l" or "r"): the pair
## with that hand cocked by his ear and the pair with it landed on the man underneath (STRIKES), for posing
## the one blended toward the other. [cocked, landed].
static func strike(pair: Dictionary, action: String, letter: String, where: String = "") -> Array:
	var aim: Dictionary = STRIKES.get(action, STRIKES.ground_punch)
	var side: float = -1.0 if letter == "l" else 1.0
	var key: String = "hand_" + letter
	var cocked: Dictionary = pair.duplicate(true)
	cocked.a[key] = {"to": "a.head", "off": [COCKED[0] * side, COCKED[1], COCKED[2]], "pole": [side, -0.4, 0.6]}
	var landed: Dictionary = pair.duplicate(true)
	var pole: Array = aim.get("pole", [1.0, 0.6, 0.2])  # Out to his striking side.
	landed.a[key] = {"to": "b." + String(aim.to), "off": aim.off, "pole": [side * float(pole[0]), pole[1], pole[2]]}
	if action == "ground_elbow":
		landed.a[key] = cocked.a[key].duplicate(true)
		landed.a[key].joint_to = "b.head"
		landed.a[key].joint_off = aim.off
	landed.a.lean = float(landed.a.get("lean", 0.0)) + STRIKE_LEAN
	if action == "ground_elbow":
		# A short upper arm needs the shoulder over the target, not a punch's distant posture.
		match where:
			"full_guard":
				landed.a.lean = 62.0
				landed.a.root[2] -= 0.16
			"mount":
				landed.a.root[2] -= 0.10
				landed.a.lean = 78.0
			"side_control", "crucifix":
				landed.a.root[2] -= 0.28
		if where == "crucifix":
			# Turn the striking shoulder toward the guard while the knees keep the arm pinned.
			landed.a.turn -= signf(float(landed.a.root[0])) * 18.0
	return [cocked, landed]


## A strike from the bottom (BOTTOM_STRIKES, D271) thrown from `pair` (the man underneath "b") with his `letter`
## arm: [cocked by his face, landed on the man on top's head], like `strike`.
static func strike_up(pair: Dictionary, action: String, letter: String, where: String = "") -> Array:
	var aim: Dictionary = BOTTOM_STRIKES.get(action, BOTTOM_STRIKES.bottom_punch)
	var side: float = -1.0 if letter == "l" else 1.0
	var key: String = "hand_" + letter
	var cocked: Dictionary = pair.duplicate(true)
	cocked.b[key] = {"to": "b.head", "off": [BOTTOM_COCKED[0] * side, BOTTOM_COCKED[1], BOTTOM_COCKED[2]], "pole": [side, -0.4, 0.6]}
	var landed: Dictionary = pair.duplicate(true)
	var pole: Array = aim.get("pole", [1.0, -0.4, 0.4])
	var off: Array = aim.off
	landed.b[key] = {"to": "a." + String(aim.to), "off": [float(off[0]) * side, off[1], off[2]], "pole": [side * float(pole[0]), pole[1], pole[2]]}
	if action == "bottom_elbow":
		landed.b[key] = cocked.b[key].duplicate(true)
		landed.b[key].joint_to = "a.head"
		landed.b[key].joint_off = [float(off[0]) * side, off[1], off[2]]
	landed.b.lean = float(landed.b.get("lean", 0.0)) + BOTTOM_LIFT
	if action == "bottom_elbow" and where == "full_guard":
		landed.b.lean = float(pair.b.lean) + 30.0
		landed.a.lean = float(pair.a.lean) + 12.0
	elif action == "bottom_elbow":
		landed.b.lean = float(pair.b.lean) + 16.0
	return [cocked, landed]


## A roll (a sweep, a bridge, getting out from under the back: ROLLS) as a path of keys for
## TakedownPair.pose_along: from `from` in `from_frame` (the man on top "a"), over onto their sides, to `to` in
## `to_frame` (written with the same man as "a", the one now underneath).
static func roll_path(from: Dictionary, from_frame: Transform3D, to: Dictionary, to_frame: Transform3D) -> Array:
	var ends: Array = TakedownPair.chain([[_short_leans(from), from_frame], [_short_leans(to), to_frame]])
	var mid: Dictionary = TakedownPair.pose_at(ends, 0.5)
	for man: String in ["a", "b"]:
		var spec: Dictionary = mid[man]
		spec.roll = float(spec.get("roll", 0.0)) + float(ROLL_SIDE[man])
		spec.root = [spec.root[0], float(spec.root[1]) + ROLL_RISE, spec.root[2]]
		for limb: String in ["hand_l", "hand_r", "foot_l", "foot_r"]:  # Limbs loose as they go over.
			spec.erase(limb)
	var mid_frame: Transform3D = Transform3D(ends[0][1]).interpolate_with(ends[1][1], 0.5)
	return [ends[0], [mid, mid_frame], ends[1]]


# --- The positions ---------------------------------------------------------------

## The passer posts outside the hips as he frees his knee from half guard.
static func pass_path(from: Array, to: Dictionary, frame: Transform3D) -> Array:
	var ends: Array = TakedownPair.chain([[_short_leans(from[0]), from[1]], [_short_leans(to), frame]])
	var mid: Dictionary = TakedownPair.pose_at(ends, 0.5)
	var side: float = signf(float(ends[1][0].a.root[0]) - float(ends[1][0].b.root[0]))
	mid.a.root[0] = float(mid.b.root[0]) + side * 0.38
	mid.a.root[1] = float(mid.a.root[1]) + 0.12
	for man: String in ["a", "b"]:
		for limb: String in ["hand_l", "hand_r", "foot_l", "foot_r"]:
			mid[man].erase(limb)
	var post: String = "hand_l" if side < 0.0 else "hand_r"
	mid.a[post] = {"at": [mid.a.root[0] + side * 0.12, 0.07, mid.a.root[2]], "pole": [side, -0.3, 0.1]}
	# Open the hooks while the passer is still above the hips. He can now lift the
	# captured shin before turning it across the defender's legs.
	var release: Dictionary = ends[0][0].duplicate(true)
	var outside: float = signf(float(release.a.root[0]) - float(release.b.root[0]))
	var trapped := "foot_r" if outside < 0.0 else "foot_l"
	var free := "foot_l" if outside < 0.0 else "foot_r"
	_open_guard_feet(release.b, false)
	_open_guard_feet(mid.b, false)
	var lift: Dictionary = release.duplicate(true)
	lift.a.root[1] += 0.12
	lift.a[trapped] = {"at": [-outside * 0.075, 0.58, 0.42], "pole": [outside * 0.5, -0.1, -1]}
	mid.a[trapped] = {"at": [outside * 0.22, 0.58, -0.06], "pole": [outside, -0.2, -1]}
	mid.a[free] = {"at": [outside * 0.76, ANKLE, -0.2], "pole": [outside, -0.3, -1]}
	var halfway: Transform3D = Transform3D(ends[0][1]).interpolate_with(ends[1][1], 0.5)
	return [ends[0], [release, ends[0][1]], [lift, ends[0][1]], [mid, halfway], ends[1]]


## Open full guard, plant the defender's heels, then lift the free knee over one
## thigh before the defender traps the other shin. Reversed, this recovers full guard.
static func guard_path(full: Array, half: Array) -> Array:
	var ends := TakedownPair.chain([[_short_leans(full[0]), full[1]], [_short_leans(half[0]), half[1]]])
	var open: Dictionary = ends[0][0].duplicate(true)
	_open_guard_feet(open.b, true)
	var release: Dictionary = open.duplicate(true)
	_open_guard_feet(release.b, false)
	var chamber: Dictionary = ends[1][0].duplicate(true)
	_open_guard_feet(chamber.b, false)
	var side := signf(float(chamber.a.root[0]) - float(chamber.b.root[0]))
	var free := "foot_l" if side < 0.0 else "foot_r"
	var lift: Dictionary = release.duplicate(true)
	lift.a.root[1] += 0.16
	lift.a[free] = {"at": [side * 0.16, 0.58, 0.85], "pole": [-side * 0.4, -0.1, 1]}
	var over: Dictionary = release.duplicate(true)
	over.a.root[1] += 0.12
	over.a.root[2] += 0.12
	over.a[free] = {"at": [side * 0.48, 0.58, 0.50], "pole": [side, -0.2, 0.5]}
	return [ends[0], [open, ends[0][1]], [release, ends[0][1]], [lift, ends[0][1]],
		[over, ends[0][1]], [chamber, ends[1][1]], ends[1]]


static func _open_guard_feet(defender: Dictionary, raised: bool) -> void:
	for foot: String in ["foot_l", "foot_r"]:
		var side := 1.0 if foot == "foot_l" else -1.0
		defender[foot] = {"at": [side * 0.72, 0.55, 0.25], "pole": [-side, 0.3, -0.3]} if raised else \
			{"at": [side * 0.7, ANKLE, 0.75], "pole": [-side, 0.25, 0.3]}


## From side control, lift the near knee before stepping across the belly into mount.
static func mount_path(from: Array, to: Dictionary, frame: Transform3D) -> Array:
	var ends := TakedownPair.chain([[_short_leans(from[0]), from[1]], [_short_leans(to), frame]])
	var side := signf(float(ends[0][0].a.root[0]) - float(ends[0][0].b.root[0]))
	var inner := "foot_r" if side < 0.0 else "foot_l"
	var outer := "foot_l" if side < 0.0 else "foot_r"
	var lift: Dictionary = ends[0][0].duplicate(true)
	lift.a.root[1] += 0.24
	lift.a[inner] = {"at": [side * 0.45, 0.55, -0.32], "pole": [side * 0.5, -0.4, 0.6]}
	var over := TakedownPair.pose_at(ends, 0.62)
	over.a.root[1] += 0.24
	over.a[outer] = {"at": [side * 0.60, ANKLE, -0.12], "pole": [side, -0.2, -1]}
	over.a[inner] = {"at": [-side * 0.27, 0.55, -0.32], "pole": [-side * 0.85, 0.2, 0.6]}
	over.b.foot_l = ends[1][0].b.foot_l
	over.b.foot_r = ends[1][0].b.foot_r
	return [ends[0], [lift, ends[0][1]], [over, ends[1][1]], ends[1]]


## The rider leaves mount beside the hips, then comes behind as the defender sits up.
static func back_take_path(from: Array, to: Dictionary, frame: Transform3D) -> Array:
	var ends: Array = TakedownPair.chain([[_short_leans(from[0]), from[1]], [_short_leans(to), frame]])
	var first: Dictionary = ends[0][0].duplicate(true)
	var behind: Dictionary = ends[1][0].duplicate(true)
	var back: float = signf(float(behind.a.root[2]) - float(behind.b.root[2]))
	for key: Dictionary in [first, behind]:
		key.a.root[0] = float(key.b.root[0]) - back * 0.5
		key.a.root[1] = 0.42
		key.a.lean = 0.0
		for limb: String in ["hand_l", "hand_r", "foot_l", "foot_r"]:
			key.a.erase(limb)
			key.b.erase(limb)
	behind.a.root[2] += back * 0.5
	var outside := signf(float(first.a.root[0]) - float(first.b.root[0]))
	var inner := "foot_r" if outside < 0.0 else "foot_l"
	var outer := "foot_l" if outside < 0.0 else "foot_r"
	var lift: Dictionary = ends[0][0].duplicate(true)
	lift.a.root[1] += 0.08
	lift.a[inner] = {"at": [-outside * 0.34, 0.62, -0.30], "pole": [-outside * 0.6, -0.4, -1]}
	first.a[outer] = {"at": [outside * 0.77, ANKLE, -0.05], "pole": [outside, -0.2, -1]}
	first.a[inner] = {"at": [outside * 0.2, 0.62, -0.30], "pole": [outside * 0.45, -0.4, -1]}
	var close: Dictionary = ends[1][0].duplicate(true)
	close.a.root[1] += 0.10
	close.a.root[2] += signf(float(close.a.root[2])) * 0.15
	for letter: String in ["l", "r"]:
		var side: float = -1.0 if letter == "l" else 1.0
		var foot := "foot_" + letter
		first.b[foot] = ends[0][0].b[foot]
		behind.b[foot] = ends[1][0].b[foot].duplicate(true)
		behind.b[foot].at[2] = signf(float(behind.b[foot].at[2])) * 0.65
		behind.a[foot] = {"at": [behind.a.root[0] - side * 0.34, ANKLE, behind.a.root[2] + 0.13], "pole": [side, -0.2, -1]}
		close.a[foot].off[0] += signf(float(close.a[foot].off[0])) * 0.15
		close.a[foot].off[1] += 0.08
		behind.a["hand_" + letter] = {"to": "b.shoulder_" + letter, "off": [side * 0.14, -0.08, 0.04], "pole": [side, -0.5, 0.1]}
	return [ends[0], [lift, ends[0][1]], [first, ends[0][1]], [behind, ends[1][1]], [close, ends[1][1]], ends[1]]


## Side control: blue flat on his back (his feet toward +Z, hips at the origin), red down on his -X side, chest
## across blue's chest, one arm round his head and the other at his far hip (the hip throw lands here, D288).
static func side_control() -> Dictionary:
	var kneel := {"pole": [0, -0.3, -1], "flat": 0.0}
	return {
		"a": {
			"root": [-0.34, 0.42, -0.34], "turn": 270, "lean": 70, "bend": [14, 0, 0], "head": [-10, 30],
			"hand_l": {"to": "b.neck", "off": [0.0, 0.0, 0.0], "pole": [-0.6, -0.6, -0.4]},
			"hand_r": {"to": "b.waist_l", "off": [0.0, 0.0, 0.04], "pole": [0.6, -0.6, -0.2]},
			"foot_l": _with(kneel, {"at": [-0.84, ANKLE, -0.48]}),
			"foot_r": _with(kneel, {"at": [-0.86, ANKLE, 0.02]}),
		},
		"b": {
			"root": [0.0, 0.13, 0.0], "turn": 180, "lean": 270, "bend": [-4, 0, 0], "head": [10, 20],
			"hand_l": {"at": [0.4, 0.06, -0.2], "pole": [1, 0, 0.3]},
			"hand_r": {"to": "a.hip_r", "off": [0.0, 0.0, 0.0], "pole": [-1, 0, 0.3]},
			"foot_l": {"at": [0.2, ANKLE, 0.66]},
			"foot_r": {"at": [-0.14, ANKLE, 0.72]},
		},
	}


## Half guard: red down on blue's chest a little to his -X side, his right leg trapped between blue's (blue's
## legs locked round red's shin), his left leg posted out; blue on his back, turned a little toward him.
static func _half_guard() -> Dictionary:
	var kneel := {"pole": [0, -0.3, -1], "flat": 0.0}
	return {
		"a": {
			"root": [-0.1, 0.36, -0.04], "lean": 68, "bend": [12, 0, 0], "head": [-16, -24],
			"hand_l": {"to": "b.shoulder_r", "off": [0.0, 0.02, 0.0], "pole": [-1, -0.4, 0.0]},
			"hand_r": {"to": "b.armpit_l", "off": [0.0, 0.04, 0.0], "pole": [1, -0.4, 0.0]},
			"foot_l": {"at": [-0.65, ANKLE, 0.42], "pole": [-0.6, 0.2, -1]},
			"foot_r": _with(kneel, {"at": [0.18, ANKLE, 0.66]}),
		},
		"b": {
			"root": [0.0, 0.14, 0.0], "turn": 180, "lean": 270, "roll": 0, "bend": [-6, 0, 0], "head": [16, 0],
			"hand_l": {"to": "a.shoulder_r", "off": [0.0, 0.02, -0.04], "pole": [1, -0.2, 0.3]},
			"hand_r": {"to": "a.neck", "off": [-0.06, 0.0, -0.04], "pole": [-1, -0.2, 0.3]},
			"foot_l": {"to": "a.shin_r", "off": [0.15, 0.04, 0.06], "pole": [-1, 0.6, 0.3]},
			"foot_r": {"to": "a.shin_r", "off": [-0.15, -0.02, 0.02], "pole": [1, 0.6, 0.3]},
		},
	}


## Mount: red sat on blue's hips facing his head, knees down either side of his ribs, hands on his chest;
## blue flat with his hands on red's hips and his feet planted, ready to bridge.
static func _mount() -> Dictionary:
	var kneel := {"pole": [0, -0.2, -1], "flat": 0.0}
	return {
		"a": {
			"root": [0.0, 0.42, -0.14], "lean": 52, "bend": [10, 0, 0], "head": [-14, 0],
			"hand_l": {"to": "b.sternum", "off": [-0.1, 0.0, -0.02], "pole": [-0.8, -0.4, 0.2]},
			"hand_r": {"to": "b.sternum", "off": [0.1, 0.0, -0.02], "pole": [0.8, -0.4, 0.2]},
			"foot_l": _with(kneel, {"at": [-0.32, ANKLE, 0.32]}),
			"foot_r": _with(kneel, {"at": [0.32, ANKLE, 0.32]}),
		},
		"b": {
			"root": [0.0, 0.13, 0.0], "turn": 180, "lean": 270, "bend": [-2, 0, 0], "head": [14, 0],
			"hand_l": {"to": "a.hip_r", "off": [0.0, 0.04, -0.04], "pole": [1, -0.4, 0.2]},
			"hand_r": {"to": "a.hip_l", "off": [0.0, 0.04, -0.04], "pole": [-1, -0.4, 0.2]},
			"foot_l": {"at": [0.2, ANKLE, 0.65], "pole": [-0.05, 0.3, -1]},
			"foot_r": {"at": [-0.2, ANKLE, 0.65], "pole": [0.05, 0.3, -1]},
		},
	}


## The back taken: blue sat up facing +Z (the camera's way, as today's figures lay it out), red sat behind him,
## chest on his back, his heels hooked inside blue's thighs and his arms in a seat belt (one over the shoulder,
## one under the arm); blue's hands on red's top arm.
static func _back() -> Dictionary:
	return {
		"a": {
			"root": [0.0, 0.14, -0.34], "turn": 180, "lean": -10, "bend": [16, 0, 0], "head": [-6, 34],
			"hand_l": {"to": "b.chest", "off": [-0.08, -0.02, -0.03], "pole": [1, -0.4, -0.3]},
			"hand_r": {"to": "b.sternum", "off": [0.06, -0.02, -0.03], "pole": [-1, 0.2, -0.3]},
			"foot_l": {"to": "b.thigh_l", "off": [-0.14, 0.1, 0.0], "pole": [1, 0.6, 0.3]},
			"foot_r": {"to": "b.thigh_r", "off": [0.14, 0.1, 0.0], "pole": [-1, 0.6, 0.3]},
		},
		"b": {
			"root": [0.0, 0.14, 0.02], "turn": 180, "lean": -14, "bend": [10, 0, 0], "head": [8, 0],
			"hand_l": {"to": "a.fore_l", "off": [0.0, 0.0, 0.04], "pole": [1, -0.6, 0.4]},
			"hand_r": {"to": "a.fore_r", "off": [0.0, 0.0, 0.04], "pole": [-1, -0.6, 0.4]},
			"foot_l": {"at": [0.24, ANKLE, 0.66], "pole": [0.3, 1, 0.2]},
			"foot_r": {"at": [-0.24, ANKLE, 0.66], "pole": [-0.3, 1, 0.2]},
		},
	}


## The crucifix (D264): red across blue from his head side, chest on blue's chest, blue's near arm trapped
## between red's legs; red's top arm free over blue's far arm.
static func _crucifix() -> Dictionary:
	var kneel := {"pole": [0, -0.3, -1], "flat": 0.0}
	return {
		"a": {
			"root": [-0.4, 0.36, -0.46], "turn": 240, "lean": 72, "bend": [12, 0, 0], "head": [-10, 20],
			"hand_l": {"to": "b.waist_l", "off": [0.0, 0.0, 0.0], "pole": [-0.6, -0.6, -0.4]},
			"hand_r": {"to": "b.chest", "off": [0.0, 0.0, 0.0], "pole": [0.6, -0.6, -0.2]},
			"foot_l": _with(kneel, {"at": [-0.9, ANKLE, -0.4]}),
			"foot_r": _with(kneel, {"at": [-0.7, ANKLE, -0.04]}),
		},
		"b": {
			"root": [0.0, 0.13, 0.0], "turn": 180, "lean": 270, "bend": [-4, 0, 0], "head": [10, 20],
			"hand_l": {"at": [0.42, 0.06, -0.24], "pole": [1, 0, 0.3]},
			"hand_r": {"to": "a.thigh_l", "off": [0.0, 0.0, 0.08], "pole": [-1, 0.2, 0.3]},
			"foot_l": {"at": [0.2, ANKLE, 0.66]},
			"foot_r": {"at": [-0.14, ANKLE, 0.72]},
		},
	}


# --- The grips -------------------------------------------------------------------

## The top man sat up out of it (posturing up, the bomb wound up).
static func _sit_up(a: Dictionary) -> void:
	a.lean = float(a.lean) - POSTURE_LEAN
	a.root = [a.root[0], float(a.root[1]) + POSTURE_RISE, a.root[2]]
	a.head = [6, 0]
	a.erase("hand_l")  # Hands up in front of his face, ready to throw down.
	a.erase("hand_r")


## The half-guard underhook: blue turned onto his side toward red, his near arm under red's arm round his back.
static func _underhook(pair: Dictionary) -> void:
	var b: Dictionary = pair.b
	b.roll = -UNDERHOOK_ROLL
	b.hand_l = {"to": "a.blade_r", "off": [0.0, 0.0, 0.04], "pole": [1, -0.4, 0.3]}


## The crossface: red's arm across blue's face, his hand round on the far side, blue flat with his head turned away.
static func _crossface(pair: Dictionary) -> void:
	var a: Dictionary = pair.a
	var b: Dictionary = pair.b
	a.hand_l = {"to": "b.head", "off": [0.12, 0.0, 0.0], "pole": [-1, -0.2, -0.3]}
	b.head = [16, 40]


# --- Helpers ---------------------------------------------------------------------

## `pair` with each man's lean written between -180 and 180 (on his back is -90, not 270), so a blend between a
## man on his back and the same man on top goes the short way round.
static func _short_leans(pair: Dictionary) -> Dictionary:
	var out := {}
	for man: String in pair:
		var spec: Dictionary = (pair[man] as Dictionary).duplicate()
		spec.lean = wrapf(float(spec.get("lean", 0.0)), -180.0, 180.0)
		out[man] = spec
	return out

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
static func _with(base_in: Dictionary, extra: Dictionary) -> Dictionary:
	var out: Dictionary = base_in.duplicate()
	out.merge(extra, true)
	return out
