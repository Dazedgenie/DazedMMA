class_name Octagon
extends RefCounted
## The cage as a 2D shape (docs/01-fight-engine.md §3): a regular octagon around
## the origin, in metres. The isometric view only draws it. Distance bands and
## cage proximity are read from here.

## Centre to the middle of each fence panel: a 30 ft (9.1 m) cage across.
const APOTHEM: float = 4.5
## Fighters' centres stay this far from the fence.
const BODY_MARGIN: float = 0.3

const BAND_OUT := "out"
const BAND_LONG := "long"
const BAND_MID := "mid"
const BAND_POCKET := "pocket"
## Distance (between fighters' centres) where each band starts, from far to close.
const LONG_WITHIN: float = 3.0
const MID_WITHIN: float = 2.2
const POCKET_WITHIN: float = 1.5
## Standing fighters can't get closer than this until the clinch exists (#15).
const MIN_GAP: float = 0.9
## Where a fighter stands to work each band: its middle.
const BAND_CENTRES := { BAND_LONG: 2.6, BAND_MID: 1.85, BAND_POCKET: 1.2 }

const CAGE_CENTRE := "centre"
const CAGE_NEAR := "near"
const CAGE_PINNED := "pinned"
## Fence closer than this = near the cage. Pinned = at the fence with the opponent in mid range or closer.
const NEAR_WITHIN: float = 1.5
const PINNED_WITHIN: float = 0.5


static func band(distance: float) -> String:
	if distance > LONG_WITHIN:
		return BAND_OUT
	if distance > MID_WITHIN:
		return BAND_LONG
	if distance > POCKET_WITHIN:
		return BAND_MID
	return BAND_POCKET


## Outward normal of each fence panel. Panels face the axes and the diagonals.
const D: float = 0.70710678
const NORMALS: Array[Vector2] = [
	Vector2(1, 0), Vector2(D, D), Vector2(0, 1), Vector2(-D, D),
	Vector2(-1, 0), Vector2(-D, -D), Vector2(0, -1), Vector2(D, -D),
]


static func normal(k: int) -> Vector2:
	return NORMALS[k]


## Metres from a point to the nearest fence panel (negative outside the cage).
static func distance_to_fence(p: Vector2) -> float:
	var nearest: float = INF
	for n in NORMALS:
		nearest = minf(nearest, APOTHEM - p.dot(n))
	return nearest


## Pushes a point back inside the fence, keeping a fighter's body width.
static func keep_inside(p: Vector2) -> Vector2:
	var out: Vector2 = p
	for n in NORMALS:
		var over: float = out.dot(n) - (APOTHEM - BODY_MARGIN)
		if over > 0.0:
			out -= n * over
	return out


static func proximity(p: Vector2, opponent_distance: float) -> String:
	var fence: float = distance_to_fence(p) - BODY_MARGIN
	if fence < PINNED_WITHIN and opponent_distance <= MID_WITHIN:
		return CAGE_PINNED
	if fence < NEAR_WITHIN:
		return CAGE_NEAR
	return CAGE_CENTRE
