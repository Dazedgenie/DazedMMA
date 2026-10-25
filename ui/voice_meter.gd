class_name VoiceMeter
extends Control
## The corner's voice (D28, docs/06 §2): a bar that refills between calls, with the
## garbled zone (under LiveCalls.GARBLED_BELOW) marked. It shakes when the corner
## spams the same call (LiveCalls: the same call again within 3 s).

const SHAKE_SECONDS: float = 0.45
const SHAKE_PIXELS: float = 6.0
const BACK := Color(1, 1, 1, 0.1)
const GARBLED_ZONE := Color("#ff6b6b", 0.25)
const FILL := Color("#e9ecef")
const FILL_GARBLED := Color("#ff6b6b")

var value: float = LiveCalls.VOICE_MAX:
	set(v):
		value = v
		queue_redraw()

var _shake_left: float = 0.0


func shake() -> void:
	_shake_left = SHAKE_SECONDS


func is_shaking() -> bool:
	return _shake_left > 0.0


func _process(delta: float) -> void:
	if _shake_left > 0.0:
		_shake_left = maxf(0.0, _shake_left - delta)
		queue_redraw()


func _draw() -> void:
	var dx: float = SHAKE_PIXELS * sin(_shake_left * 60.0) if _shake_left > 0.0 else 0.0
	var box := Rect2(Vector2(dx, 0.0), size)
	draw_rect(box, BACK)
	var zone: float = LiveCalls.GARBLED_BELOW / LiveCalls.VOICE_MAX
	draw_rect(Rect2(box.position, Vector2(size.x * zone, size.y)), GARBLED_ZONE)
	var share: float = clampf(value / LiveCalls.VOICE_MAX, 0.0, 1.0)
	draw_rect(Rect2(box.position + Vector2(0.0, 4.0), Vector2(size.x * share, size.y - 8.0)), FILL_GARBLED if value < LiveCalls.GARBLED_BELOW else FILL)
	draw_line(box.position + Vector2(size.x * zone, 0.0), box.position + Vector2(size.x * zone, size.y), Color("#ff6b6b"), 2.0)
