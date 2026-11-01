class_name ClinchPair
extends RefCounted
## The clinch as a paired pose for the rig (D286): who holds what on each side of the clinch (the sim's grips,
## D261), the collar tie (D129) and being held on the fence (D220) turned into a pose for two rigs, written
## like RigPairs. Presentation only.
##
## The fence (D287): held on the fence, the pair frame is squared to the fence behind him (the caller's
## fence_frame) and he is pressed flat on it, back, hips and head on the wire at FENCE_Z behind the frame's
## origin. When he works to get off it (a spin-off, a turn or a break: `motion` "work") his hips come out, he
## posts a hand on the fence and his head goes to the side he is escaping to. A drive to the fence ("drive")
## has the driver low with his head in the man's chest, both men stepping (`step`, metres driven). A turn
## swaps the men's places: `turning` poses the pair part way round from one pose to the next.
##
## The pose is written for two roles: the man driving it ("a": the one holding the collar tie, the one holding
## the other on the fence, the one with the body lock, else red) on the +Z side of the pair frame, and the other
## man ("b"). When blue drives, `build` says so (flip) and the caller turns the frame round and swaps the men.

const ANKLE: float = FighterRig.ANKLE_UP
## How far a man's head turns to lie on the other man's shoulder (degrees).
const HEAD_TURN: float = 25.0
## Held on the fence (D287): how far behind the pair frame's origin the fence's inner face is, in metres.
const FENCE_Z: float = 0.5
## Working off the fence: how far his hips come out (m) and turn toward his way out (degrees), and where his
## posting hand goes on the wire (out to the side, up from the canvas).
const WORK_HIPS_OUT: float = 0.07
const WORK_TURN: float = 16.0
const POST_OUT: float = 0.34
const POST_UP: float = 1.02
## A clinch break: how far the man breaking pushes his hips back (m).
const BREAK_HIPS_BACK: float = 0.05
## Driving: one full step of each foot every DRIVE_STRIDE metres driven, a foot down for STANCE_SHARE of it,
## lifted STEP_LIFT at most between.
const DRIVE_STRIDE: float = 0.9
const STANCE_SHARE: float = 0.6
const STEP_LIFT: float = 0.08
## The moves the held man makes to get off the fence (D287: he fights off it while making one).
const WORK_MOVES: Array[String] = ["spin_off", "turn_him", "clinch_break"]


## The pair pose for one moment of the clinch:
## `grips` [side 0, side 1]: who has the inside (the underhook) on each side of the clinch, a fighter's index or
## FightSim.NO_GRIP; `red_sides`: red's arm on each clinch side as "l" or "r" (blue's arm across is the other
## one); `collar`: who holds the collar tie (-1 none); `held`: who is held on the fence (-1 none).
## `motion` (D287, optional): {move: "drive", by, step} while fighter `by` drives the other to the fence
## (`step`: metres driven so far); {move: "work", by, action} while the held man works to get off it with
## `action` (WORK_MOVES); {move: "break", by} while fighter `by` breaks the clinch away from the fence.
## Returns {pair: {a, b}, flip: true when blue is the "a" man, kind: "drive", "collar", "fence", "lock" or "tie"}.
static func build(grips: Array, red_sides: Array, collar: int, held: int, motion: Dictionary = {}) -> Dictionary:
	var lock_owner: int = int(grips[0]) if int(grips[0]) == int(grips[1]) and int(grips[0]) >= 0 else -1
	var kind: String = "tie"
	var driver: int = 0
	var move: String = String(motion.get("move", ""))
	if move == "drive":
		kind = "drive"
		driver = int(motion.by)
		collar = -1  # Driving, his hands go to the body.
	elif collar >= 0:
		kind = "collar"
		driver = collar
	elif held >= 0:
		kind = "fence"
		driver = 1 - held
	elif lock_owner >= 0:
		kind = "lock"
		driver = lock_owner
	# The a man's arm on each clinch side, and what each man does with it.
	var a_sides: Array[String] = []
	for side in 2:
		var red: String = String(red_sides[side])
		a_sides.append(red if driver == 0 else _other(red))
	var hands := {"a": {}, "b": {}}
	for side in 2:
		var owner: int = int(grips[side])
		for man: String in ["a", "b"]:
			var me: int = driver if man == "a" else 1 - driver
			var letter: String = a_sides[side] if man == "a" else _other(a_sides[side])
			var grip: String
			if kind == "collar":
				grip = "collar" if me == collar else "frame"
			elif owner < 0:
				grip = "fight"
			elif owner == me:
				grip = "lock" if lock_owner == me else "under"
			else:
				grip = "over"
			hands[man]["hand_" + letter] = hand(grip, letter, "b" if man == "a" else "a")
	# Heads go to the side of the a man's underhook (his first, else the other man's overhook side).
	var head_side: float = 1.0
	for side in 2:
		if int(grips[side]) == driver:
			head_side = 1.0 if a_sides[side] == "r" else -1.0
			break
	var pair: Dictionary = body(kind, head_side)
	for man: String in ["a", "b"]:
		pair[man].merge(hands[man], true)
	if kind == "drive":
		_step(pair, float(motion.get("step", 0.0)))
	elif move == "work" and kind == "fence" and int(motion.by) == held:
		_work(pair, String(motion.get("action", "")), grips, a_sides, held)
	elif move == "break" and kind != "collar":
		_break(pair, "a" if int(motion.by) == driver else "b")
	return {"pair": pair, "flip": driver == 1, "kind": kind}


## Poses red's rig and blue's (`red`, `blue`) in the clinch `built` (from build) in the pair frame `frame`
## (origin on the canvas between them, its +Z toward red).
static func pose(red: FighterRig, blue: FighterRig, built: Dictionary, frame: Transform3D) -> void:
	if bool(built.flip):
		FighterRig.pose_pair(red, blue, swap(built.pair), frame * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO))
	else:
		FighterRig.pose_pair(red, blue, built.pair, frame)


## Clinches to look at and test, by name: [grips, red_sides, collar, held, motion] for build. Red is orthodox
## (his lead, left arm on clinch side 0).
static func examples() -> Dictionary:
	var sides: Array[String] = ["l", "r"]
	var none: int = FightSim.NO_GRIP
	return {
		"tied_up": [[none, none], sides, -1, -1, {}],
		"red_underhook": [[0, none], sides, -1, -1, {}],
		"over_under": [[0, 1], sides, -1, -1, {}],
		"over_under_other_way": [[1, 0], sides, -1, -1, {}],
		"red_body_lock": [[0, 0], sides, -1, -1, {}],
		"blue_body_lock": [[1, 1], sides, -1, -1, {}],
		"red_collar_tie": [[none, none], sides, 0, -1, {}],
		"blue_collar_tie": [[none, none], sides, 1, -1, {}],
		"blue_on_the_fence": [[0, 1], sides, -1, 1, {}],
		"red_on_the_fence_locked": [[1, 1], sides, -1, 0, {}],
		"red_drives_blue": [[0, 1], sides, -1, -1, {"move": "drive", "by": 0, "step": 0.3}],
		"red_drives_blue_mid_step": [[0, 1], sides, -1, -1, {"move": "drive", "by": 0, "step": 0.75}],
		"blue_spins_off_the_fence": [[0, 1], sides, -1, 1, {"move": "work", "by": 1, "action": "spin_off"}],
		"blue_turns_red": [[0, 1], sides, -1, 1, {"move": "work", "by": 1, "action": "turn_him"}],
		"blue_breaks_off_the_fence": [[0, 1], sides, -1, 1, {"move": "work", "by": 1, "action": "clinch_break"}],
		"red_breaks": [[0, 1], sides, -1, -1, {"move": "break", "by": 0}],
	}


## The two men's bodies and feet for the clinch `kind`, heads to `head_side` (+1 or -1, mirrors the pose).
static func body(kind: String, head_side: float) -> Dictionary:
	var pair: Dictionary
	match kind:
		"collar":  # The a man stands tall with both hands behind the other's head; he is bent over, head pulled down.
			pair = {
				"a": {"root": [0.0, 0.9, 0.42], "lean": 8, "bend": [4, 0, 0], "head": [6, 0],
					"foot_l": {"at": [-0.2, ANKLE, 0.3]}, "foot_r": {"at": [0.2, ANKLE, 0.62]}},
				"b": {"root": [0.0, 0.8, -0.42], "turn": 180, "lean": 34, "bend": [12, 0, 0], "head": [44, 0],
					"foot_l": {"at": [0.22, ANKLE, -0.4]}, "foot_r": {"at": [-0.2, ANKLE, -0.68]}},
			}
			return pair
		"fence":  # The b man is pressed flat on the fence (its face at -FENCE_Z): back, hips and head on the
			# wire, feet a little out. The a man is in low on him, head under his chin, hips square.
			pair = {
				"a": {"root": [0.04, 0.8, 0.29], "lean": 26, "bend": [10, -6, 8], "head": [-18, -HEAD_TURN],
					"foot_l": {"at": [-0.18, ANKLE, 0.16]}, "foot_r": {"at": [0.2, ANKLE, 0.7]}},
				"b": {"root": [0.02, 0.92, -0.33], "turn": 180, "lean": -4, "bend": [-2, 4, 4], "head": [-6, HEAD_TURN],
					"foot_l": {"at": [0.18, ANKLE, -0.2]}, "foot_r": {"at": [-0.16, ANKLE, -0.26]}},
			}
		"drive":  # The a man has changed levels, head in the other's chest, driving him back toward -Z; he
			# is upright and leaning back, giving ground. The feet are stepped by _step.
			pair = {
				"a": {"root": [0.03, 0.74, 0.32], "lean": 34, "bend": [12, -4, 6], "head": [-26, -HEAD_TURN],
					"foot_l": {"at": [-0.18, ANKLE, 0.3]}, "foot_r": {"at": [0.2, ANKLE, 0.66]}},
				"b": {"root": [0.02, 0.9, -0.28], "turn": 180, "lean": -10, "bend": [-4, 4, 4], "head": [12, HEAD_TURN],
					"foot_l": {"at": [0.18, ANKLE, -0.36]}, "foot_r": {"at": [-0.18, ANKLE, -0.62]}},
			}
		"lock":  # The a man has both arms under, hips in and a little lower; the other stands taller over him.
			pair = {
				"a": {"root": [0.04, 0.84, 0.28], "lean": 18, "bend": [8, -6, 12], "head": [6, -HEAD_TURN],
					"foot_l": {"at": [-0.2, ANKLE, 0.12]}, "foot_r": {"at": [0.2, ANKLE, 0.56]}},
				"b": {"root": [0.04, 0.9, -0.29], "turn": 180, "lean": 8, "bend": [4, 6, 12], "head": [6, HEAD_TURN],
					"foot_l": {"at": [0.2, ANKLE, -0.14]}, "foot_r": {"at": [-0.2, ANKLE, -0.56]}},
			}
		_:  # Tied up chest to chest: heads on each other's shoulder, hips back, feet staggered (RigPairs.clinch).
			pair = {
				"a": {"root": [0.04, 0.86, 0.29], "lean": 16, "bend": [8, -6, 16], "head": [10, -HEAD_TURN],
					"foot_l": {"at": [-0.2, ANKLE, 0.12]}, "foot_r": {"at": [0.2, ANKLE, 0.56]}},
				"b": {"root": [0.04, 0.88, -0.3], "turn": 180, "lean": 12, "bend": [6, 6, 16], "head": [8, HEAD_TURN],
					"foot_l": {"at": [0.2, ANKLE, -0.12]}, "foot_r": {"at": [-0.2, ANKLE, -0.56]}},
			}
	return mirror(pair) if head_side < 0.0 else pair


## Where a hand making `grip` goes, from a man's `letter` arm onto the other man (`other`, "a" or "b"):
## "under" round his back to the shoulder blade, "over" clamping his arm above the elbow, "lock" both hands
## locked at the small of his back, "collar" behind his head, "frame" on his chest, "fight" on his biceps.
static func hand(grip: String, letter: String, other: String) -> Dictionary:
	var across: String = _other(letter)  # His left arm meets the other man's right side.
	var out: float = -1.0 if letter == "l" else 1.0
	var theirs: float = -1.0 if across == "l" else 1.0  # The other man's side, in his own frame.
	match grip:
		"under":
			return {"to": "%s.blade_%s" % [other, across], "off": [0.0, 0.02, 0.02], "pole": [out, -0.6, 0.2]}
		"lock":
			return {"to": "%s.lower_back" % other, "off": [theirs * 0.06, 0.06, -0.02], "pole": [out, -0.6, 0.2]}
		"over":
			return {"to": "%s.upper_%s" % [other, across], "off": [theirs * 0.05, 0.0, 0.03], "pole": [out * 0.8, 0.2, 0.4]}
		"collar":
			return {"to": "%s.nape" % other, "off": [theirs * 0.04, 0.0, 0.0], "pole": [out, -0.3, 0.2]}
		"frame":
			return {"to": "%s.shoulder_%s" % [other, across], "off": [-theirs * 0.04, -0.08, -0.08], "pole": [out, -0.8, 0.1]}
	# Hand fighting: on the front of his shoulder, at the biceps (not on his hand, which is on yours).
	return {"to": "%s.shoulder_%s" % [other, across], "off": [-theirs * 0.02, -0.14, -0.08], "pole": [out, -0.8, 0.1]}


## Steps both men's feet for a drive `step` metres along (D287): the pair goes toward -Z, so a planted foot
## slides +Z in the pair frame as far as they go, then lifts and swings forward; the two feet take turns.
static func _step(pair: Dictionary, step: float) -> void:
	for man: String in ["a", "b"]:
		for n in 2:
			var key: String = "foot_" + ["l", "r"][n]
			var at: Array = pair[man][key].at
			var u: float = fposmod(step / DRIVE_STRIDE + n * 0.5, 1.0)
			var reach: float = DRIVE_STRIDE * STANCE_SHARE  # How far a planted foot slides back.
			var along: float
			var lift: float = 0.0
			if u < STANCE_SHARE:
				along = reach * (u / STANCE_SHARE - 0.5)
			else:
				var swing: float = (u - STANCE_SHARE) / (1.0 - STANCE_SHARE)
				along = reach * (0.5 - swing)
				lift = STEP_LIFT * sin(PI * swing)
			pair[man][key] = {"at": [at[0], float(at[1]) + lift, float(at[2]) + along]}


## The b man held on the fence working to get off it with `action` (D287): hips out, turned toward his way
## out, head to that side and the other hand posted on the wire (both hands framing on a clinch break).
static func _work(pair: Dictionary, action: String, grips: Array, a_sides: Array[String], held: int) -> void:
	var b: Dictionary = pair.b
	# His way out: his underhook's side to turn him, his overhook's to spin off (else his first side).
	var out_letter: String = _other(a_sides[0])
	for side in 2:
		var mine: bool = int(grips[side]) == held
		var theirs: bool = int(grips[side]) == 1 - held
		if (action == "turn_him" and mine) or (action == "spin_off" and theirs):
			out_letter = _other(a_sides[side])
			break
	var out_x: float = 1.0 if out_letter == "l" else -1.0  # Facing +Z, his left is +X in the pair frame.
	var root: Array = b.root
	b.root = [float(root[0]) + out_x * 0.02, float(root[1]) - 0.03, float(root[2]) + WORK_HIPS_OUT]
	var a_root: Array = pair.a.root  # He gives a little ground as the hips come out.
	pair.a.root = [a_root[0], a_root[1], float(a_root[2]) + WORK_HIPS_OUT * 0.6]
	if action == "clinch_break":
		for letter: String in ["l", "r"]:
			b["hand_" + letter] = hand("frame", letter, "a")
		return
	b.turn = 180.0 - WORK_TURN * out_x
	b.head = [4, HEAD_TURN * 1.4 * (1.0 if out_letter == "l" else -1.0)]
	var post: String = _other(out_letter)
	var post_x: float = 1.0 if post == "l" else -1.0
	b["hand_" + post] = {"at": [post_x * POST_OUT, POST_UP, -FENCE_Z + 0.04], "pole": [post_x, -0.4, -0.5]}


## `man` ("a" or "b") breaking the clinch (D287): both hands framing on the other man, hips pushed back.
static func _break(pair: Dictionary, man: String) -> void:
	var spec: Dictionary = pair[man]
	var back: float = BREAK_HIPS_BACK if man == "a" else -BREAK_HIPS_BACK
	var root: Array = spec.root
	spec.root = [root[0], root[1], float(root[2]) + back]
	spec.lean = float(spec.lean) - 6.0
	for letter: String in ["l", "r"]:
		spec["hand_" + letter] = hand("frame", letter, "b" if man == "a" else "a")


## Standing apart after a spin-off (D287), red the a man: a step between them, hands up, before the bodies go
## back to today's figures.
static func apart() -> Dictionary:
	return {
		"a": {"root": [0.0, FighterRig.PELVIS_HEIGHT - 0.04, 0.45], "lean": 6,
			"foot_l": {"at": [-0.16, ANKLE, 0.3]}, "foot_r": {"at": [0.18, ANKLE, 0.62]}},
		"b": {"root": [0.0, FighterRig.PELVIS_HEIGHT - 0.04, -0.45], "turn": 180, "lean": 6,
			"foot_l": {"at": [0.16, ANKLE, -0.3]}, "foot_r": {"at": [-0.18, ANKLE, -0.62]}},
	}


## The pose and frame `pose` would use for `built` in `frame`, with red as the a man: [pair, frame].
static func effective(built: Dictionary, frame: Transform3D) -> Array:
	if bool(built.flip):
		return [swap(built.pair), frame * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)]
	return [built.pair, frame]


## The same pose written for the pair frame turned half round: every place in the frame turned with it.
static func half_turn(pair: Dictionary) -> Dictionary:
	var out := {}
	for man: String in pair:
		var spec: Dictionary = pair[man]
		var m := {}
		for key: String in spec:
			var value: Variant = spec[key]
			if key == "root":
				m[key] = [-float(value[0]), value[1], -float(value[2])]
			elif key == "turn":
				m[key] = wrapf(float(value) + 180.0, -180.0, 180.0)
			elif value is Dictionary and (value as Dictionary).has("at"):
				var want: Dictionary = (value as Dictionary).duplicate()
				want.at = [-float(want.at[0]), want.at[1], -float(want.at[2])]
				m[key] = want
			else:
				m[key] = value
		out[man] = m
	return out


## Poses the two rigs `t` (0–1) of the way through a turn (D287) that swaps their places: from `from` to `to`
## (each [pair, frame] from effective, red the a man), the pair going round `way` (+1 or -1) half a turn.
static func turning(red: FighterRig, blue: FighterRig, from: Array, to: Array, t: float, way: float = 1.0) -> void:
	var start: Transform3D = from[1]
	var end_pair: Dictionary = half_turn(to[0])
	var end: Transform3D = Transform3D(to[1]) * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	if start.basis.z.dot(end.basis.z) > 0.0:  # The end frame already faces the other way round from the start.
		end_pair = to[0]
		end = to[1]
	var ease: float = smoothstep(0.0, 1.0, t)
	var turned_by := Transform3D(Basis(Vector3.UP, way * PI * ease), Vector3.ZERO)
	var start_pair: Dictionary = from[0]
	for man: String in ["a", "b"]:  # Turn each man the short way to his end facing.
		var from_turn: float = float(start_pair[man].get("turn", 0.0))
		end_pair[man] = (end_pair[man] as Dictionary).duplicate()
		end_pair[man].turn = from_turn + wrapf(float(end_pair[man].get("turn", 0.0)) - from_turn, -180.0, 180.0)
	var base: Transform3D = start.interpolate_with(end * Transform3D(Basis(Vector3.UP, -PI), Vector3.ZERO), ease)
	FighterRig.pose_pair(red, blue, start_pair, base * turned_by, end_pair, ease)


## `pair` seen in a mirror (left for right): every x and every turn to the side the other way, the left limbs'
## places swapped with the right's.
static func mirror(pair: Dictionary) -> Dictionary:
	var out := {}
	for man: String in pair:
		var spec: Dictionary = pair[man]
		var m := {}
		for key: String in spec:
			var value: Variant = spec[key]
			match key:
				"root":
					m[key] = [-value[0], value[1], value[2]]
				"bend":
					m[key] = [value[0], -value[1], -value[2]]
				"head":
					m[key] = [value[0], -value[1]]
				"roll":
					m[key] = -value
				"turn":
					m[key] = 360 - value if value > 0 else -value
				"lean":
					m[key] = value
				_:
					var limb: String = key.left(-1) + _other(key.right(1))
					m[limb] = _mirror_limb(value)
		out[man] = m
	return out


## Swaps the two men's roles: a's spec becomes b's and every "a." point "b." and back. With the frame turned
## half round, the pose looks the same with the men the other way.
static func swap(pair: Dictionary) -> Dictionary:
	return {"a": _relabel(pair.b), "b": _relabel(pair.a)}


static func _mirror_limb(want: Dictionary) -> Dictionary:
	var m := {}
	for key: String in want:
		var value: Variant = want[key]
		if key == "to":
			var point_name: String = String(value)
			if point_name.ends_with("_l") or point_name.ends_with("_r"):
				point_name = point_name.left(-1) + _other(point_name.right(1))
			m[key] = point_name
		elif key in ["at", "off", "pole"]:
			m[key] = [-value[0], value[1], value[2]]
		else:
			m[key] = value
	return m


static func _relabel(spec: Dictionary) -> Dictionary:
	var out := {}
	for key: String in spec:
		var value: Variant = spec[key]
		if value is Dictionary and (value as Dictionary).has("to"):
			var want: Dictionary = (value as Dictionary).duplicate()
			var point_name: String = String(want.to)
			want.to = ("b" if point_name.begins_with("a.") else "a") + point_name.substr(1)
			out[key] = want
		else:
			out[key] = value
	return out


static func _other(letter: String) -> String:
	return "r" if letter == "l" else "l"
