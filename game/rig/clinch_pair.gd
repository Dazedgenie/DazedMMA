class_name ClinchPair
extends RefCounted
## The clinch as a paired pose for the rig (D286): who holds what on each side of the clinch (the sim's grips,
## D261), the collar tie (D129) and being held on the fence (D220) turned into a pose for two rigs, written
## like RigPairs. Presentation only.
##
## The pose is written for two roles: the man driving it ("a": the one holding the collar tie, the one holding
## the other on the fence, the one with the body lock, else red) on the +Z side of the pair frame, and the other
## man ("b"). When blue drives, `build` says so (flip) and the caller turns the frame round and swaps the men.

const ANKLE: float = FighterRig.ANKLE_UP
## How far a man's head turns to lie on the other man's shoulder (degrees).
const HEAD_TURN: float = 25.0


## The pair pose for one moment of the clinch:
## `grips` [side 0, side 1]: who has the inside (the underhook) on each side of the clinch, a fighter's index or
## FightSim.NO_GRIP; `red_sides`: red's arm on each clinch side as "l" or "r" (blue's arm across is the other
## one); `collar`: who holds the collar tie (-1 none); `held`: who is held on the fence (-1 none).
## Returns {pair: {a, b}, flip: true when blue is the "a" man, kind: "collar", "fence", "lock" or "tie"}.
static func build(grips: Array, red_sides: Array, collar: int, held: int) -> Dictionary:
	var lock_owner: int = int(grips[0]) if int(grips[0]) == int(grips[1]) and int(grips[0]) >= 0 else -1
	var kind: String = "tie"
	var driver: int = 0
	if collar >= 0:
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
	return {"pair": pair, "flip": driver == 1, "kind": kind}


## Poses red's rig and blue's (`red`, `blue`) in the clinch `built` (from build) in the pair frame `frame`
## (origin on the canvas between them, its +Z toward red).
static func pose(red: FighterRig, blue: FighterRig, built: Dictionary, frame: Transform3D) -> void:
	if bool(built.flip):
		FighterRig.pose_pair(red, blue, swap(built.pair), frame * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO))
	else:
		FighterRig.pose_pair(red, blue, built.pair, frame)


## Clinches to look at and test, by name: [grips, red_sides, collar, held] for build. Red is orthodox (his lead,
## left arm on clinch side 0).
static func examples() -> Dictionary:
	var sides: Array[String] = ["l", "r"]
	var none: int = FightSim.NO_GRIP
	return {
		"tied_up": [[none, none], sides, -1, -1],
		"red_underhook": [[0, none], sides, -1, -1],
		"over_under": [[0, 1], sides, -1, -1],
		"over_under_other_way": [[1, 0], sides, -1, -1],
		"red_body_lock": [[0, 0], sides, -1, -1],
		"blue_body_lock": [[1, 1], sides, -1, -1],
		"red_collar_tie": [[none, none], sides, 0, -1],
		"blue_collar_tie": [[none, none], sides, 1, -1],
		"blue_on_the_fence": [[0, 1], sides, -1, 1],
		"red_on_the_fence_locked": [[1, 1], sides, -1, 0],
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
		"fence":  # The b man is held with his back on the fence (-Z); the a man drives in low, head in his chest.
			pair = {
				"a": {"root": [0.04, 0.8, 0.29], "lean": 26, "bend": [10, -6, 8], "head": [-18, -HEAD_TURN],
					"foot_l": {"at": [-0.18, ANKLE, 0.16]}, "foot_r": {"at": [0.2, ANKLE, 0.7]}},
				"b": {"root": [0.02, 0.92, -0.31], "turn": 180, "lean": -4, "bend": [0, 4, 6], "head": [4, HEAD_TURN],
					"foot_l": {"at": [0.18, ANKLE, -0.28]}, "foot_r": {"at": [-0.16, ANKLE, -0.4]}},
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
