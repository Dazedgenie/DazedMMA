class_name FreeCamera
extends RefCounted
## The fight camera turned by hand, for looking at a move from any side (D472–D476, docs/06 §6.19).
##
## Right-drag (or the arrow keys) turns it round the fighters and tilts it up and down, the wheel (or - and =) zooms,
## C puts it back. Once turned it holds that angle: it still follows the fighters round the cage, but the camera's own
## swing to see them side-on (D361) stops moving it, so the angle you picked stays put until C. It never changes
## what the fight does or where anyone is drawn: ArenaView keeps working out its own swing for laying the fighters
## out and only aims the camera from here. Presentation only.
##
## `swing` and `rise` are the same angles as ArenaView.camera_from's (radians round from CAMERA_FROM, radians more
## above it); `zoom` is a share of the distance the camera would stand at.

## Radians turned (round) and tilted (up or down) for each pixel the mouse is dragged.
const TURN_PER_PIXEL: float = 0.008
const TILT_PER_PIXEL: float = 0.005
## Radians a second while an arrow key is held.
const KEY_TURN_SPEED: float = 1.6
const KEY_TILT_SPEED: float = 0.9
## How low and how high it tilts against where it normally sits (about 28° down at rise 0): RISE_MIN is a couple of
## degrees off the canvas, RISE_MAX nearly straight down (ArenaView.camera_from stops at 1.4 radians up).
const RISE_MIN: float = -0.45
const RISE_MAX: float = 0.9
## Each wheel notch moves it to this share of its distance (closer) or back out by the same; - and = held zoom by
## KEY_ZOOM_SPEED notches a second. ZOOM_MIN is right up at them, ZOOM_MAX takes in the whole cage.
const ZOOM_STEP: float = 0.9
const KEY_ZOOM_SPEED: float = 3.0
const ZOOM_MIN: float = 0.3
const ZOOM_MAX: float = 2.5
## How fast it eases back to the normal camera after C (per second).
const RETURN_SPEED: float = 4.0

## True from the first turn or zoom until C.
var held: bool = false
var swing: float = 0.0
var rise: float = 0.0
var zoom: float = 1.0
## How much of the camera is the hand's (1 held, easing to 0 after C).
var share: float = 0.0


## Turns it `turn` radians round and `tilt` radians up; `from_swing` and `from_rise` are where the camera is aimed
## now (ArenaView.aimed_swing and aimed_rise), so the first turn starts from what's on screen.
func turn_by(turn: float, tilt: float, from_swing: float, from_rise: float) -> void:
	_take(from_swing, from_rise)
	swing = wrapf(swing + turn, -PI, PI)
	rise = clampf(rise + tilt, RISE_MIN, RISE_MAX)


## A right-drag of `pixels` (x right, y down): dragging right turns it round to the left, dragging down raises it.
func drag(pixels: Vector2, from_swing: float, from_rise: float) -> void:
	turn_by(-pixels.x * TURN_PER_PIXEL, pixels.y * TILT_PER_PIXEL, from_swing, from_rise)


## Zooms `notches` wheel notches in (negative is out).
func zoom_by(notches: float, from_swing: float, from_rise: float) -> void:
	_take(from_swing, from_rise)
	zoom = clampf(zoom * pow(ZOOM_STEP, notches), ZOOM_MIN, ZOOM_MAX)


## Puts it back (C): it eases back to the normal camera.
func reset() -> void:
	held = false


## Forgets it at once (a new fight).
func clear() -> void:
	held = false
	share = 0.0
	zoom = 1.0


func advance(delta: float) -> void:
	if held:
		share = 1.0
		return
	share *= exp(-RETURN_SPEED * delta)
	if share < 0.01:
		share = 0.0
		zoom = 1.0


## The camera's swing, rise and zoom share with the hand's turn laid over the camera's own (`auto_*`).
func aim_swing(auto_swing: float) -> float:
	return lerp_angle(auto_swing, swing, share)


func aim_rise(auto_rise: float) -> float:
	return lerpf(auto_rise, rise, share)


func aim_zoom() -> float:
	return lerpf(1.0, zoom, share)


func _take(from_swing: float, from_rise: float) -> void:
	if held:
		return
	zoom = aim_zoom()
	swing = from_swing
	rise = clampf(from_rise, RISE_MIN, RISE_MAX)
	held = true
	share = 1.0
