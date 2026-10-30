class_name EscapeRoutes
extends RefCounted
## Escape routes (D233, docs/01 §20.6): the ways out a fighter being cut off still has, as
## a cage cutter reads them. From where the runner stands, HEADINGS straight routes (the
## first toward the middle of the cage, the rest round from it), each walked SAMPLES steps
## of SAMPLE_M metres and slid along the fence where it meets it. A route is open while he
## gets to every point on it before the chaser could reach it with a punch: its margin is
## the chaser's time to get within THREAT_REACH of the point (plus his reaction) less the
## runner's time to get there (plus turning off the way he was drifting), in ticks, at the
## worst point. Only routes that don't head back into the fence count (at most BACK_INTO the
## cosine against the way off it). A route's worth is its margin (capped at MARGIN_CAP) plus
## SPACE_TICKS_PER_M for every metre further off the fence it ends (less, sliding along it).
## The cutter steps where the runner's best route is worth least; the runner takes the open
## route worth most (read). Pure maths, no RNG: it never changes a fight on its own. One per
## fighter, reused, so the hot loop doesn't allocate.

const HEADINGS: int = 8
const SAMPLES: int = 2
const SAMPLE_M: float = 1.2
## Within this of a point, the chaser's punches reach it: the pocket.
const THREAT_REACH: float = Octagon.POCKET_WITHIN
## Ticks the chaser takes to react to the runner going.
const CHASER_LAG_TICKS: float = 2.0
## Ticks the runner loses turning straight back against his drift (half of it turning square).
const TURN_TICKS: float = 4.0
const MARGIN_CAP: float = 10.0
const SPACE_TICKS_PER_M: float = 4.0
const BACK_INTO: float = 0.2
## A route counts as going one way round the chaser (for which way to circle) when it heads
## at least this much sideways (the cosine to straight across).
const SIDEWAYS_FROM: float = 0.3

## The runner's spot when the routes were last walked, and where each route's points are,
## when he gets to each (ticks), the metres off the fence each route gains, and which count.
var runner: Vector2 = Vector2.ZERO
var headings: PackedVector2Array = PackedVector2Array()
var usable: Array[bool] = []
var points: PackedVector2Array = PackedVector2Array()
var arrive: PackedFloat32Array = PackedFloat32Array()
var space: PackedFloat32Array = PackedFloat32Array()
## The runner's side of the last read: whether any route is open, which way round the chaser
## the best open one goes (±1, 0 = none), and the best one open or not (the least shut).
var open: bool = false
var way: int = 0
var least_shut: int = 0

## Each heading as a turn off the first (toward the middle): cos and sin of TAU × h / HEADINGS.
static var _turns: PackedVector2Array = PackedVector2Array()


func _init() -> void:
	if _turns.is_empty():
		for h in HEADINGS:
			_turns.append(Vector2.from_angle(TAU * h / HEADINGS))
	headings.resize(HEADINGS)
	points.resize(HEADINGS * SAMPLES)
	arrive.resize(HEADINGS * SAMPLES)
	space.resize(HEADINGS)
	usable.resize(HEADINGS)


## Walks the routes out from `from` for a runner who covers `step` metres a tick and has
## been drifting `drift` (m per tick, as the chaser reads it).
func walk(from: Vector2, step: float, drift: Vector2) -> void:
	runner = from
	var start: Vector2 = -from.normalized() if from.length_squared() > 0.0001 else Vector2.RIGHT
	var drifting: Vector2 = drift.normalized() if drift.length_squared() > 0.000001 else Vector2.ZERO
	var fence: float = Octagon.distance_to_fence(from)
	var off: Vector2 = Octagon.inward(from)
	var pace: float = maxf(step, 0.001)
	for h in HEADINGS:
		var t: Vector2 = _turns[h]
		var dir := Vector2(start.x * t.x - start.y * t.y, start.x * t.y + start.y * t.x)
		headings[h] = dir
		usable[h] = dir.dot(off) >= -BACK_INTO
		if not usable[h]:
			continue
		var turn: float = TURN_TICKS * (1.0 - dir.dot(drifting)) * 0.5 if drifting != Vector2.ZERO else 0.0
		var p: Vector2 = from
		var walked: float = 0.0
		for s in SAMPLES:
			var next: Vector2 = Octagon.keep_inside(p + dir * SAMPLE_M)
			walked += p.distance_to(next)
			p = next
			points[h * SAMPLES + s] = p
			arrive[h * SAMPLES + s] = turn + walked / pace
		space[h] = Octagon.distance_to_fence(p) - fence


## Route h's margin (ticks) against a chaser at `chaser` covering `step` metres a tick:
## positive, the runner gets along it clear; negative, the chaser can hit him on the way.
func margin(h: int, chaser: Vector2, step: float) -> float:
	var pace: float = maxf(step, 0.001)
	var worst: float = INF
	for s in SAMPLES:
		var k: int = h * SAMPLES + s
		var reach: float = CHASER_LAG_TICKS + maxf(0.0, chaser.distance_to(points[k]) - THREAT_REACH) / pace
		worst = minf(worst, reach - arrive[k])
	return worst


## What route h is worth to the runner with the chaser at `chaser`.
func worth(h: int, chaser: Vector2, step: float) -> float:
	return minf(margin(h, chaser, step), MARGIN_CAP) + SPACE_TICKS_PER_M * space[h]


## The runner's best route's worth with the chaser at `chaser`: what a cutter tries to bring down.
func best_worth(chaser: Vector2, step: float) -> float:
	var best: float = -INF
	for h in HEADINGS:
		if usable[h]:
			best = maxf(best, worth(h, chaser, step))
	return best


## The runner's side, against the chaser at `chaser` (`toward`: the unit vector from the runner
## to him): sets open, way and least_shut. Routes count for a way round him when they head at
## least SIDEWAYS_FROM across.
func read(chaser: Vector2, step: float, toward: Vector2) -> void:
	var side := Vector2(-toward.y, toward.x)
	var best_open: float = -INF
	var best_any: float = -INF
	open = false
	way = 0
	least_shut = 0
	for h in HEADINGS:
		if not usable[h]:
			continue
		var m: float = margin(h, chaser, step)
		open = open or m > 0.0
		var across: float = headings[h].dot(side)
		if absf(across) < SIDEWAYS_FROM:
			continue
		var w: float = minf(m, MARGIN_CAP) + SPACE_TICKS_PER_M * space[h]
		var sign: int = 1 if across > 0.0 else -1
		if w > best_any:
			best_any = w
			least_shut = sign
		if m > 0.0 and w > best_open:
			best_open = w
			way = sign


## Whether any route is still open.
func any_open(chaser: Vector2, step: float) -> bool:
	for h in HEADINGS:
		if usable[h] and margin(h, chaser, step) > 0.0:
			return true
	return false
