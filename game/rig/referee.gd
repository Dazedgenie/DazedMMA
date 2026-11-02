class_name Referee
extends Node3D
## The referee (D373, D374; docs/13 "The referee and the finish"): a third body in the cage all fight, in a striped
## shirt, shadowing the action a few steps off on the far side from the camera, closer and crouched when they're on
## the ground, closer again over a knocked-down man. At a stoppage he jumps in between them and waves it off.
## Presentation only: the fight doesn't know he's there.

## How far from the middle of the two men he stands: apart on their feet, tied up, and on the ground.
const STANDING_OFF: float = 2.3
const CLINCH_OFF: float = 1.8
const GROUND_OFF: float = 1.6
## Over a knocked-down man: how far from him.
const DOWN_OFF: float = 1.4
## The closest he lets a fighter come, and the fence.
const CLEAR_OF_MEN: float = 1.2
const CLEAR_OF_FENCE: float = 0.55
## Stopping two men too close to get between: how far to the side of them (across the camera's view) he steps in.
const SIDE_ON: float = 0.95
## Where round the two men he looks for his spot: this many angles, and how much moving his spot costs against
## being on the far side from the camera (so he doesn't dance about as they move).
const SPOT_TRIES: int = 16
const STAY_WEIGHT: float = 0.6
## How quickly he walks to his spot (m/s), and when he jumps in.
const WALK_SPEED: float = 1.5
const RUSH_SPEED: float = 4.0
## How quickly he turns to face them (radians a second).
const TURN_SPEED: float = 5.0
## Stepping: a foot steps when it's this far from where it should be, taking this long (quicker rushing), lifted
## this high, and landing this far ahead of where he's going (seconds of his speed).
const STEP_FROM: float = 0.12
const STEP_SECONDS: float = 0.3
const RUSH_STEP_SECONDS: float = 0.17
const STEP_LIFT: float = 0.08
const STEP_LEAD: float = 0.2
## Where his feet sit under him (his frame, -Z ahead), a little apart.
const FEET: Array[Vector3] = [Vector3(-0.16, 0.0, 0.02), Vector3(0.16, 0.0, -0.04)]
## Waving it off: crossing his hands over his head this many times a second.
const WAVE_RATE: float = 1.6
## His shoulder height when standing (m), which sizes the body.
const SHOULDER_HEIGHT: float = 1.5
## The look's seed against the fight's, so he's the same man for a fight's seed.
const LOOK_SEED: int = 0x5EF

## What he's doing: "watch" (on their feet or tied up), "ground" (crouched over them), "down" (over a man knocked
## down), "stop" (jumping in and waving it off).
var mode: String = "watch"
var spot := Vector2.ZERO
var facing: float = 0.0
var rig: FighterRig
var body: SkinnedBody
var look: Dictionary = {}
var _want := Vector2.ZERO
var _look_at := Vector2.ZERO
var _speed: float = WALK_SPEED
var _feet: Array[Vector3] = []
## A step under way: {foot, from, to, t (0 to 1)}.
var _step: Dictionary = {}
var _wave_time: float = 0.0
## At a stoppage, a point in the world he puts a hand on (the beaten man, or the winner on top to pull him off), or
## INF for none; and whether he's bent down to it (they're on the ground).
var _hold_at := Vector3.INF
var _low: bool = false
var _placed: bool = false


## Builds him: the body dressed as the referee, with a look rolled from `look_seed`, and the hidden rig that poses it.
func setup(look_seed: int) -> bool:
	body = SkinnedBody.new()
	add_child(body)
	if not body.load_body(SkinnedBody.TRIPO_BODY, SHOULDER_HEIGHT):
		body.queue_free()
		body = null
		return false
	look = FighterLook.roll(look_seed ^ LOOK_SEED, "")
	body.set_referee(look)
	rig = FighterRig.new(Color.WHITE)
	add_child(rig)
	rig.visible = false
	rig.fit(body.measure())
	return true


## Puts him at `at` facing `toward` at once (the start of a fight).
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


## Where he should go and what he looks at this frame, and how he holds himself (`mode`). Stopping it, `hold` is a
## point in the world for one hand (INF: none, he waves with both) and `low` bends him down to them on the ground.
func want(at: Vector2, toward: Vector2, p_mode: String, hold := Vector3.INF, low: bool = false) -> void:
	_hold_at = hold
	_low = low
	if p_mode == "stop" and mode != "stop":
		_wave_time = 0.0
	mode = p_mode
	_want = at
	_look_at = toward
	_speed = RUSH_SPEED if p_mode == "stop" else WALK_SPEED


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
	_wave_time += delta
	_walk(velocity, delta)
	var at: Transform3D = frame()
	var inverse: Transform3D = at.affine_inverse()
	var hold: Vector3 = inverse * _hold_at if _hold_at.is_finite() else Vector3.INF
	var spec: Dictionary = pose_spec(mode, _wave_time, hold, _low)
	for i in 2:
		var foot: Vector3 = _feet[i]
		if not _step.is_empty() and int(_step.foot) == i:
			var t: float = float(_step.t)
			foot = Vector3(_step.from).lerp(Vector3(_step.to), smoothstep(0.0, 1.0, t)) + Vector3.UP * STEP_LIFT * sin(PI * t)
		var local: Vector3 = inverse * foot
		spec["foot_" + FighterRig.SIDES[i]] = {"at": [local.x, FighterRig.ANKLE_UP + local.y, local.z]}
	rig.corner = "a"
	rig.set_body(spec, at)
	rig.set_limbs(spec, at, null)
	rig.set_limbs(spec, at, null)  # Twice: hands on his own knees find them where the legs ended up.
	body.follow(rig)


## Moves his feet: one steps at a time, toward where it should be under him (a little ahead when he's moving).
func _walk(velocity: Vector2, delta: float) -> void:
	var at: Transform3D = frame()
	var ahead := Vector3(velocity.x, 0.0, velocity.y) * STEP_LEAD
	if not _step.is_empty():
		var seconds: float = RUSH_STEP_SECONDS if _speed > WALK_SPEED else STEP_SECONDS
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


## His frame: at his spot on the canvas, facing his way (-Z ahead).
func frame() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, facing), Vector3(spot.x, 0.0, spot.y))


## The turn (about Y, 0 facing -Z) from `from` to look at `to`.
static func facing_to(from: Vector2, to: Vector2) -> float:
	var d: Vector2 = to - from
	return atan2(-d.x, -d.y)


## His pose in `mode` (FighterRig spec, without the feet), `seconds` into it for the wave. Stopping it, `hold` (his
## frame, INF none) is where one hand goes while the other waves, and `low` bends him down to men on the ground.
static func pose_spec(p_mode: String, seconds: float, hold := Vector3.INF, low: bool = false) -> Dictionary:
	match p_mode:
		"ground":  # Crouched, hands on his knees, watching them.
			return {
				"root": [0, FighterRig.PELVIS_HEIGHT - 0.2, 0.06], "lean": 28, "bend": [12, 0, 0], "head": [-24, 0],
				"hand_l": {"to": "a.thigh_l", "off": [0, -0.12, -0.04], "pole": [-1, 0, 0.3]},
				"hand_r": {"to": "a.thigh_r", "off": [0, -0.12, -0.04], "pole": [1, 0, 0.3]},
			}
		"down":  # Over a man who's down: bent in, a hand out, ready to step in.
			return {
				"root": [0, FighterRig.PELVIS_HEIGHT - 0.12, 0.04], "lean": 22, "bend": [8, 0, 0], "head": [-20, 0],
				"hand_l": {"at": [-0.22, 1.0, -0.42], "pole": [-1, -0.5, 0]},
				"hand_r": {"at": [0.24, 0.92, -0.2], "pole": [1, -0.6, 0.2]},
			}
		"stop":  # Waving it off: his hands crossing over his head, or one on the man and the other waving.
			var w: float = 0.5 + 0.5 * sin(TAU * WAVE_RATE * seconds)
			if hold.is_finite():
				var side: String = "l" if hold.x < 0.0 else "r"
				var other: String = "r" if side == "l" else "l"
				var outward: float = -1.0 if other == "l" else 1.0
				var spec := {
					"root": [0, FighterRig.PELVIS_HEIGHT - (0.2 if low else 0.06), 0.04 if low else 0.0],
					"lean": 30 if low else 10, "bend": [10 if low else 0, 0, 0], "head": [-10 if low else 0, 0],
				}
				spec["hand_" + side] = {"at": [hold.x, hold.y, hold.z], "pole": [-outward, -0.4, 0.4]}
				spec["hand_" + other] = {"at": [outward * lerpf(0.5, 0.05, w), 1.75 if not low else 1.5, -0.16],
					"pole": [outward, 0, 0.4]}
				return spec
			return {
				"root": [0, FighterRig.PELVIS_HEIGHT - 0.05, 0.0], "lean": 6, "head": [8, 0],
				"hand_l": {"at": [lerpf(-0.42, 0.12, w), 1.82, -0.12], "pole": [-1, 0, 0.4]},
				"hand_r": {"at": [lerpf(0.42, -0.12, w), 1.82, -0.14], "pole": [1, 0, 0.4]},
			}
		_:  # Watching: upright, a little forward, hands loose in front.
			return {
				"root": [0, FighterRig.PELVIS_HEIGHT - 0.04, 0.0], "lean": 6, "head": [-4, 0],
				"hand_l": {"at": [-0.2, 1.02, -0.2], "pole": [-1, -0.6, 0.3]},
				"hand_r": {"at": [0.2, 1.04, -0.2], "pole": [1, -0.6, 0.3]},
			}


## Where he stands to watch two men at `men` from `off` metres: round the middle of them, clear of each man and the
## fence, on the far side from the camera (seen from `camera`), not far from `now` so he doesn't dance about.
static func watch_spot(men: Array[Vector2], off: float, camera: Vector2, now: Vector2) -> Vector2:
	var middle: Vector2 = (men[0] + men[1]) / 2.0
	var away: Vector2 = (middle - camera).normalized() if middle.distance_to(camera) > 0.01 else Vector2.UP
	var best := middle + away * off
	var best_score: float = -INF
	for k in SPOT_TRIES:
		var at: Vector2 = middle + Vector2.from_angle(TAU * k / SPOT_TRIES) * off
		at = inside(at)
		var clear: float = minf(at.distance_to(men[0]), at.distance_to(men[1]))
		var score: float = (at - middle).normalized().dot(away) - STAY_WEIGHT * at.distance_to(now) / off
		if clear < CLEAR_OF_MEN:
			score -= 4.0 * (CLEAR_OF_MEN - clear)
		if score > best_score:
			best_score = score
			best = at
	return best


## Where he jumps in at a stoppage: between the winner at `winner` and the loser at `loser`, by the loser, or, when
## they're too close to get between, beside them side-on to the camera at `camera` (on the loser's side, a little
## beyond them) so they don't hide him.
static func stop_spot(winner: Vector2, loser: Vector2, camera: Vector2) -> Vector2:
	var apart: Vector2 = winner - loser
	var at: Vector2
	if apart.length() > CLEAR_OF_MEN:
		at = loser + apart.normalized() * 0.6
	else:
		var middle: Vector2 = (winner + loser) / 2.0
		var view: Vector2 = (middle - camera).normalized() if middle.distance_to(camera) > 0.01 else Vector2.UP
		var side := Vector2(-view.y, view.x)
		if (middle + side).distance_to(loser) > (middle - side).distance_to(loser):
			side = -side
		at = middle + side * SIDE_ON + view * 0.25
	return inside(at)


## `at` moved in toward the middle until it's CLEAR_OF_FENCE off the fence.
static func inside(at: Vector2) -> Vector2:
	for n in 4:  # Toward the middle isn't straight off a fence's face, so a few goes.
		var fence: float = Octagon.distance_to_fence(at)
		if fence >= CLEAR_OF_FENCE:
			break
		at = at.move_toward(Vector2.ZERO, CLEAR_OF_FENCE - fence + 0.01)
	return at
