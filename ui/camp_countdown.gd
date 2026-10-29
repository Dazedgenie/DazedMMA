class_name CampCountdown
extends Control
## The camp as a row of weeks ending in the fight, across the top of the camp planner (D160, docs/02 §3.10):
## weeks already run are filled (with their week plan and a red dot if he got hurt), the week on screen is
## outlined in the red corner's colour, and the fight sits at the end. Hovering a run week shows what it did.

const PIP_H: float = 52.0
const PIP_GAP: float = 8.0
const FIGHT_W: float = 96.0
const FONT_SIZE: int = 15
const SMALL: int = 12
const TEXT := Color("#e9ecef")
const DIM := Color("#8a8f98")
const TRACK := Color("#22272f")
const DONE := Color("#3a2c2e")
const RED := Color("#ff6b6b")
const FIGHT := Color("#e03131")

var weeks: int = 6
## Weeks run so far (the week on screen is the next one; all of them on fight night).
var run: int = 0
## Per run week: { plan: its name, hurt: bool, tip: what it did }.
var history: Array[Dictionary] = []
## The fight is off (pulled out, or the doctor said no).
var cancelled: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(0.0, PIP_H)
	mouse_filter = Control.MOUSE_FILTER_PASS


func show_camp(total: int, done_weeks: Array[Dictionary], off: bool) -> void:
	weeks = total
	history = done_weeks
	run = done_weeks.size()
	cancelled = off
	queue_redraw()


func _pip_w() -> float:
	return clampf((size.x - FIGHT_W - PIP_GAP * weeks) / float(maxi(1, weeks)), 40.0, 130.0)


func _left() -> float:
	return (size.x - (_pip_w() + PIP_GAP) * weeks - FIGHT_W) * 0.5


func _get_tooltip(at_position: Vector2) -> String:
	var i: int = floori((at_position.x - _left()) / (_pip_w() + PIP_GAP))
	if i >= 0 and i < history.size():
		return String(history[i].get("tip", ""))
	return ""


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var display: Font = DisplayFont.font()
	var w: float = _pip_w()
	var x: float = _left()
	for i in weeks:
		var rect := Rect2(x, 0.0, w, PIP_H)
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(6)
		box.bg_color = DONE if i < run else TRACK
		if i == run:
			box.set_border_width_all(2)
			box.border_color = RED
		draw_style_box(box, rect)
		var colour: Color = TEXT if i <= run else DIM
		draw_string(display, Vector2(x, 24.0), "WEEK %d" % (i + 1), HORIZONTAL_ALIGNMENT_CENTER, w, FONT_SIZE + 3, colour)
		var under: String = ""
		if i < history.size():
			under = String(history[i].get("plan", ""))
		elif i == run:
			under = "fight week" if i == weeks - 1 else "now"
		draw_string(font, Vector2(x + 4.0, 41.0), under, HORIZONTAL_ALIGNMENT_CENTER, w - 8.0, SMALL, DIM)
		if i < history.size() and bool(history[i].get("hurt", false)):
			draw_circle(Vector2(x + w - 9.0, 9.0), 4.0, RED, true, -1.0, true)
		x += w + PIP_GAP
	var fight := StyleBoxFlat.new()
	fight.set_corner_radius_all(6)
	fight.bg_color = TRACK if cancelled else FIGHT
	draw_style_box(fight, Rect2(x, 0.0, FIGHT_W, PIP_H))
	draw_string(display, Vector2(x, 35.0), "OFF" if cancelled else "FIGHT", HORIZONTAL_ALIGNMENT_CENTER, FIGHT_W,
		FONT_SIZE + 9, DIM if cancelled else Color.WHITE)
