class_name BodyDamageFigure
extends Control
## A little fighter on the top bar that shows where he's hurt (D150, docs/06 §6): the head,
## body and legs each run from green (fresh) through yellow to red (FighterState.hurt).
## The head is health (D120): red means the referee is close. Both legs share the one
## "legs" area until the fight engine tracks them apart. A part flashes white when a
## clean shot lands on it, and the head pulses while he's rocked.

const AREAS: Array[String] = ["head", "body", "legs"]
## Hurt 0 → 0.5 → 1 blends these (green, yellow, red: the HUD's pip colours).
const FRESH := Color("#51cf66")
const HALF := Color("#fcc419")
const DONE := Color("#ff6b6b")
const LIMB := Color("#3a404a")
const FLASH := Color.WHITE
const FLASH_SECONDS: float = 0.35
## The rocked head's pulse: one beat this long, down to this much opacity.
const PULSE_SECONDS: float = 0.7
const PULSE_LOW: float = 0.35
## The figure's own size; it scales to fit its rect and keeps this shape.
const DESIGN := Vector2(60.0, 100.0)

## Area → 0 (fresh) to 1 (fully hurt).
var hurt: Dictionary = { "head": 0.0, "body": 0.0, "legs": 0.0 }
var rocked: bool = false

var _flash_left: Dictionary = { "head": 0.0, "body": 0.0, "legs": 0.0 }
var _pulse: float = 0.0
var _boxes: Dictionary = {}  # part → StyleBoxFlat (rounded rects)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	for part: String in ["body", "leg_left", "leg_right", "arm_left", "arm_right"]:
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(6 if part == "body" else 5)
		box.anti_aliasing = true
		_boxes[part] = box
	(_boxes.arm_left as StyleBoxFlat).bg_color = LIMB
	(_boxes.arm_right as StyleBoxFlat).bg_color = LIMB


## Reads a fighter's damage and rocked state.
func show_fighter(f: FighterState) -> void:
	for area: String in AREAS:
		hurt[area] = f.hurt(area)
	rocked = f.is_rocked()
	queue_redraw()


## A clean shot landed on this area ("head", "body" or "legs").
func flash(area: String) -> void:
	if _flash_left.has(area):
		_flash_left[area] = FLASH_SECONDS
		queue_redraw()


func is_flashing(area: String) -> bool:
	return float(_flash_left.get(area, 0.0)) > 0.0


## The colour of an area this hurt: green at 0, yellow at 0.5, red at 1.
static func damage_colour(amount: float) -> Color:
	var t: float = clampf(amount, 0.0, 1.0)
	return FRESH.lerp(HALF, t * 2.0) if t < 0.5 else HALF.lerp(DONE, (t - 0.5) * 2.0)


## What the area's fill is drawn in right now (its damage colour, whitened by a flash).
func area_colour(area: String) -> Color:
	var c: Color = damage_colour(float(hurt[area]))
	var left: float = float(_flash_left[area])
	if left > 0.0:
		c = c.lerp(FLASH, left / FLASH_SECONDS)
	if area == "head" and rocked:
		c.a = lerpf(1.0, PULSE_LOW, 0.5 - 0.5 * cos(TAU * _pulse / PULSE_SECONDS))
	return c


func _process(delta: float) -> void:
	var busy: bool = rocked
	for area: String in AREAS:
		if _flash_left[area] > 0.0:
			_flash_left[area] = maxf(0.0, _flash_left[area] - delta)
			busy = true
	_pulse = fmod(_pulse + delta, PULSE_SECONDS) if rocked else 0.0
	if busy:
		queue_redraw()


func _get_minimum_size() -> Vector2:
	return DESIGN * 0.9


func _draw() -> void:
	var s: float = minf(size.x / DESIGN.x, size.y / DESIGN.y)
	draw_set_transform((size - DESIGN * s) * 0.5, 0.0, Vector2(s, s))
	draw_style_box(_boxes.arm_left, Rect2(8.0, 27.0, 8.0, 28.0))
	draw_style_box(_boxes.arm_right, Rect2(44.0, 27.0, 8.0, 28.0))
	var legs: Color = area_colour("legs")
	for part: String in ["leg_left", "leg_right"]:
		(_boxes[part] as StyleBoxFlat).bg_color = legs
	draw_style_box(_boxes.leg_left, Rect2(18.5, 59.0, 10.5, 38.0))
	draw_style_box(_boxes.leg_right, Rect2(31.0, 59.0, 10.5, 38.0))
	(_boxes.body as StyleBoxFlat).bg_color = area_colour("body")
	draw_style_box(_boxes.body, Rect2(18.0, 25.0, 24.0, 32.0))
	draw_circle(Vector2(30.0, 12.0), 10.0, area_colour("head"), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
