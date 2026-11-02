class_name Walker
extends Node3D
## A body that walks round the cage on its own feet (D373, D390; docs/13 "Before, between and after the fight"): the
## referee all fight, and the fighters and their corner team in the moments before, between and after the rounds.
## It walks to a spot at a speed, turns to look at a point, steps one foot at a time and poses the body above them
## from a FighterRig spec in its own frame (-Z ahead). Presentation only: the fight doesn't know it's there.
##
## The body and its hidden rig are its own (`dress`) or a fighter's lent for a moment (`borrow`).

## How quickly he turns to face what he's looking at (radians a second).
const TURN_SPEED: float = 5.0
## Stepping: a foot steps when it's this far from where it should be, taking this long (quicker when he's hurrying),
## lifted this high, and landing this far ahead of where he's going (seconds of his speed).
const STEP_FROM: float = 0.12
const STEP_SECONDS: float = 0.3
const RUSH_STEP_SECONDS: float = 0.17
const STEP_LIFT: float = 0.08
const STEP_LEAD: float = 0.2
## Faster than this (m/s) and he's hurrying: quicker steps.
const HURRY_FROM: float = 2.0
## Where his feet sit under him (his frame, -Z ahead), a little apart.
const FEET: Array[Vector3] = [Vector3(-0.16, 0.0, 0.02), Vector3(0.16, 0.0, -0.04)]

var spot := Vector2.ZERO
var facing: float = 0.0
var rig: FighterRig
var body: SkinnedBody
## The pose above his feet this frame (FighterRig spec in his frame, without the feet unless they're planted
## somewhere else, as on a stool): hands may be {"world": Vector3} for a point in the world (another man's wrist).
var pose: Dictionary = {}
var _want := Vector2.ZERO
var _look_at := Vector2.ZERO
var _speed: float = 1.5
var _feet: Array[Vector3] = []
## A step under way: {foot, from, to, t (0 to 1)}.
var _step: Dictionary = {}
var _placed: bool = false


## Builds his own body at `shoulder_height` (m) and the hidden rig that poses it. False if the body can't load.
func dress(shoulder_height: float) -> bool:
	body = SkinnedBody.new()
	add_child(body)
	if not body.load_body(SkinnedBody.TRIPO_BODY, shoulder_height):
		body.queue_free()
		body = null
		return false
	rig = FighterRig.new(Color.WHITE)
	add_child(rig)
	rig.visible = false
	rig.fit(body.measure())
	return true


## Walks a body that's someone else's (a fighter's, with the hidden rig fitted to it) for a while.
func borrow(p_body: SkinnedBody, p_rig: FighterRig) -> void:
	body = p_body
	rig = p_rig


## Puts him at `at` facing `toward` at once.
func place(at: Vector2, toward: Vector2) -> void:
	spot = at
	_want = at
	_look_at = toward
	facing = facing_to(at, toward)
	_feet = []
	for foot in FEET:
		_feet.append(frame() * foot)
	_step = {}
	_placed = true


## Where he should go, at `speed` (m/s), and what he looks at.
func go(at: Vector2, toward: Vector2, speed: float = 1.5) -> void:
	_want = at
	_look_at = toward
	_speed = speed


## True once he's at his spot, turned to what he's looking at, with his feet under him.
func arrived() -> bool:
	if spot.distance_to(_want) > 0.01 or not _step.is_empty():
		return false
	return spot.distance_to(_look_at) <= 0.05 or absf(angle_difference(facing, facing_to(spot, _look_at))) < 0.05


## Walks, turns, steps and poses him for `delta` seconds.
func advance(delta: float) -> void:
	if body == null:
		return
	if not _placed:
		place(_want, _look_at)
	var to_go: Vector2 = _want - spot
	var moving: float = minf(to_go.length(), _speed * delta)
	var velocity := Vector2.ZERO
	if to_go.length() > 0.001:
		velocity = to_go.normalized() * (moving / maxf(delta, 0.0001))
		spot += to_go.normalized() * moving
	if spot.distance_to(_look_at) > 0.05:
		var turn: float = angle_difference(facing, facing_to(spot, _look_at))
		facing += clampf(turn, -TURN_SPEED * delta, TURN_SPEED * delta)
	_walk(velocity, delta)
	var at: Transform3D = frame()
	var spec: Dictionary = _spec(at.affine_inverse())
	rig.corner = "a"
	rig.set_body(spec, at)
	rig.set_limbs(spec, at, null)
	rig.set_limbs(spec, at, null)  # Twice: hands on his own knees find them where the legs ended up.
	body.follow(rig)


## The rig spec this frame, in his frame (`inverse` takes the world into it): `pose`, with world points for hands
## brought into his frame and his stepping feet where the pose doesn't plant them.
func _spec(inverse: Transform3D) -> Dictionary:
	var spec: Dictionary = pose.duplicate()
	for key: String in ["hand_l", "hand_r", "foot_l", "foot_r"]:
		var want: Variant = spec.get(key)
		if want is Dictionary and (want as Dictionary).has("world"):
			var local: Vector3 = inverse * Vector3((want as Dictionary).world)
			var put: Dictionary = (want as Dictionary).duplicate()
			put.erase("world")
			put["at"] = [local.x, local.y, local.z]
			spec[key] = put
	for i in 2:
		var key: String = "foot_" + FighterRig.SIDES[i]
		if spec.has(key):
			continue
		var foot: Vector3 = _feet[i]
		if not _step.is_empty() and int(_step.foot) == i:
			var t: float = float(_step.t)
			foot = Vector3(_step.from).lerp(Vector3(_step.to), smoothstep(0.0, 1.0, t)) + Vector3.UP * STEP_LIFT * sin(PI * t)
		var local: Vector3 = inverse * foot
		spec[key] = {"at": [local.x, FighterRig.ANKLE_UP + local.y, local.z]}
	return spec


## Moves his feet: one steps at a time, toward where it should be under him (a little ahead when he's moving).
func _walk(velocity: Vector2, delta: float) -> void:
	var at: Transform3D = frame()
	var ahead := Vector3(velocity.x, 0.0, velocity.y) * STEP_LEAD
	if not _step.is_empty():
		var seconds: float = RUSH_STEP_SECONDS if _speed > HURRY_FROM else STEP_SECONDS
		_step.t = float(_step.t) + delta / seconds
		_step.to = at * FEET[int(_step.foot)] + ahead
		if float(_step.t) >= 1.0:
			_feet[int(_step.foot)] = Vector3(_step.to)
			_step = {}
		return
	var worst: int = -1
	var worst_off: float = STEP_FROM
	for i in 2:
		var off: float = (_feet[i] - at * FEET[i]).length()
		if off > worst_off:
			worst = i
			worst_off = off
	if worst >= 0:
		_step = {"foot": worst, "from": _feet[worst], "to": at * FEET[worst] + ahead, "t": 0.0}


## Puts him where he was walking to, turned to what he's looking at (a walk that took too long).
func finish_walk() -> void:
	if _placed:
		place(_want, _look_at)


## Plants both feet under him where he stands now (he sat down, or was put somewhere at once).
func plant() -> void:
	_feet = []
	for foot in FEET:
		_feet.append(frame() * foot)
	_step = {}


## His frame: at his spot on the canvas, facing his way (-Z ahead).
func frame() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, facing), Vector3(spot.x, 0.0, spot.y))


## The turn (about Y, 0 facing -Z) from `from` to look at `to`.
static func facing_to(from: Vector2, to: Vector2) -> float:
	var d: Vector2 = to - from
	return atan2(-d.x, -d.y)
