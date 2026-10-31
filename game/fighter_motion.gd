class_name FighterMotion
extends RefCounted
## Presentation-only support-foot planning and two-bone leg solving (docs/13).
## Feet stay in world space while planted; only one support foot swings at a time.

const THIGH: float = 0.46
const SHIN: float = 0.45
const STEP_TIME: float = 0.16
const STEP_HEIGHT: float = 0.075
var feet: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _enabled: Array[bool] = [false, false]
var swing: int = -1
var progress: float = 0.0
var _start := Vector3.ZERO
var _finish := Vector3.ZERO
var _previous: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]


func update(goals: Array[Vector3], support: Array[bool], delta: float) -> void:
	var velocity: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	for i in 2:
		if delta > 0.0 and _enabled[i]:
			velocity[i] = (goals[i] - _previous[i]) / delta
		_previous[i] = goals[i]
		if not support[i] or not _enabled[i] or feet[i].distance_to(goals[i]) > 1.0:
			feet[i] = goals[i]
			if swing == i:
				swing = -1
		_enabled[i] = support[i]
	if delta <= 0.0:
		return
	if swing >= 0:
		progress = minf(1.0, progress + delta / STEP_TIME)
		var ease: float = smoothstep(0.0, 1.0, progress)
		feet[swing] = _start.lerp(_finish, ease)
		feet[swing].y += sin(progress * PI) * STEP_HEIGHT
		if progress >= 1.0:
			swing = -1
	if swing < 0:
		var error: float = 0.10
		for i in 2:
			if support[i] and feet[i].distance_to(goals[i]) > error:
				error = feet[i].distance_to(goals[i])
				swing = i
		if swing >= 0:
			progress = 0.0
			_start = feet[swing]
			# Land ahead of a moving stance, giving the other foot time to follow.
			_finish = goals[swing] + (velocity[swing] * STEP_TIME * 1.25).limit_length(0.22)
			_finish.y = goals[swing].y


## Returns knee and reachable ankle; the knee bends toward the pole without stretching bones.
static func solve(hip: Vector3, ankle: Vector3, pole: Vector3) -> Array[Vector3]:
	return solve_bones(hip, ankle, pole, THIGH, SHIN)


## Any two-bone limb (a leg, or an arm from the shoulder, D281): the middle joint bends toward
## the pole, and an end out of reach stops at full extension instead of stretching the bones.
static func solve_bones(root: Vector3, end: Vector3, pole: Vector3, first: float, second: float) -> Array[Vector3]:
	var hip: Vector3 = root
	var offset: Vector3 = end - hip
	var distance: float = clampf(offset.length(), absf(first - second) + 0.02, first + second - 0.002)
	var axis: Vector3 = offset.normalized() if offset.length() > 0.001 else Vector3.DOWN
	var bend: Vector3 = pole - axis * pole.dot(axis)
	if bend.length_squared() < 0.001:
		bend = Vector3.UP - axis * Vector3.UP.dot(axis)
	if bend.length_squared() < 0.001:
		bend = Vector3.RIGHT - axis * Vector3.RIGHT.dot(axis)
	var along: float = (first * first - second * second + distance * distance) / (2.0 * distance)
	var height: float = sqrt(maxf(0.0, first * first - along * along))
	return [hip + axis * along + bend.normalized() * height, hip + axis * distance]
