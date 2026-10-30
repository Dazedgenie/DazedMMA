class_name FatigueLine
extends Control
## The week's fatigue as a line under the camp planner's tiles (D170, docs/02 §3.10): where the fighter starts the
## week, then after each of the twelve sessions (TrainingCamp.forecast's slots), with a dashed line where being
## tired starts costing XP (TrainingCamp.FATIGUE_FREE) and the peak marked.

## The chart's top: fatigue runs 0 to this (more is drawn at the top).
const TOP: float = 60.0
const LINE := Color("#fcc419")
const AREA := Color(0.99, 0.77, 0.10, 0.12)
const GUIDE := Color("#ff8787")
const GRID := Color(1.0, 1.0, 1.0, 0.06)
const TEXT := Color("#8a8f98")
const DAYS: Array[String] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
const FONT_SIZE: int = 13
const LABEL_W: float = 76.0
const BOTTOM: float = 20.0

## Fatigue at the start of the week, then after each slot (13 numbers; in fight week the last is the fight's), or
## empty for nothing to show.
var points: Array[float] = []
## The week's last slot is the fight (D135): it's marked there instead of a session.
var fight_week: bool = false
## The planner's tiles in slot order (day × 2 + slot), so each day lines up under its column; without them the
## days share the width evenly.
var tiles: Array[Control] = []


func _init() -> void:
	custom_minimum_size = Vector2(0.0, 120.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Reads a TrainingCamp.forecast() (or run_plan) report.
func show_week(report: Dictionary) -> void:
	points.clear()
	var slots: Array = report.get("slots", [])
	if not slots.is_empty():
		points.append(float(slots[0].fatigue_before))
		for slot: Dictionary in slots:
			points.append(float(slot.fatigue))
	fight_week = bool(report.get("fight_week", false))
	if fight_week and not points.is_empty():
		points.append(points[-1])  # He goes into the fight as Saturday morning left him.
	queue_redraw()


## The peak and the slot it's after (1–12), or 0 at the start of the week.
func peak() -> Vector2:
	var best := Vector2(0.0, -1.0)
	for i in points.size():
		if points[i] > best.y:
			best = Vector2(i, points[i])
	return best


## Where point i (0 the week's start, then after each slot) sits: the start on Monday's left edge, a morning in the
## middle of its day and an evening on its right edge.
func _x(i: int) -> float:
	if i == 0:
		return _day_span(0).x
	var day: int = (i - 1) / TrainingCamp.SLOTS_PER_DAY
	var span: Vector2 = _day_span(day)
	return span.x + span.y * (0.5 if (i - 1) % TrainingCamp.SLOTS_PER_DAY == 0 else 1.0)


## A day's column as (left, width) in this control.
func _day_span(day: int) -> Vector2:
	var index: int = day * TrainingCamp.SLOTS_PER_DAY
	if index < tiles.size() and tiles[index].is_inside_tree():
		return Vector2(tiles[index].global_position.x - global_position.x, tiles[index].size.x)
	var w: float = (size.x - LABEL_W - 8.0) / float(DAYS.size())
	return Vector2(LABEL_W + day * w, w)


func _y(value: float) -> float:
	return 6.0 + (size.y - BOTTOM - 6.0) * (1.0 - clampf(value, 0.0, TOP) / TOP)


func _draw() -> void:
	var font: Font = get_theme_default_font()
	draw_string(font, Vector2(0.0, _y(TOP * 0.5) + 5.0), "Fatigue", HORIZONTAL_ALIGNMENT_LEFT, LABEL_W, FONT_SIZE + 2, TEXT)
	for day in DAYS.size():
		var span: Vector2 = _day_span(day)
		draw_rect(Rect2(span.x, 6.0, span.y, size.y - BOTTOM - 6.0), GRID)
		draw_string(font, Vector2(span.x, size.y - 4.0), DAYS[day], HORIZONTAL_ALIGNMENT_CENTER, span.y, FONT_SIZE, TEXT)
	var free_y: float = _y(TrainingCamp.FATIGUE_FREE)
	var right: float = _day_span(DAYS.size() - 1).x + _day_span(DAYS.size() - 1).y
	var x := _x(0)
	while x < right:
		draw_line(Vector2(x, free_y), Vector2(minf(x + 6.0, right), free_y), GUIDE, 1.5)
		x += 11.0
	draw_string(font, Vector2(right + 6.0, free_y - 4.0), "learns less", HORIZONTAL_ALIGNMENT_LEFT, size.x - right - 6.0, FONT_SIZE, GUIDE)
	draw_string(font, Vector2(right + 6.0, free_y + 14.0), "past %d" % roundi(TrainingCamp.FATIGUE_FREE), HORIZONTAL_ALIGNMENT_LEFT,
		size.x - right - 6.0, FONT_SIZE, GUIDE)
	if points.size() < 2:
		return
	var line := PackedVector2Array()
	for i in points.size():
		line.append(Vector2(_x(i), _y(points[i])))
	var area := PackedVector2Array([Vector2(_x(0), _y(0.0))])
	area.append_array(line)
	area.append(Vector2(_x(points.size() - 1), _y(0.0)))
	draw_colored_polygon(area, AREA)
	draw_polyline(line, LINE, 2.5, true)
	var top: Vector2 = peak()
	var at := Vector2(_x(top.x), _y(top.y))
	draw_circle(at, 4.5, LINE, true, -1.0, true)
	draw_string(DisplayFont.font(), at + Vector2(-30.0, -9.0), "%d" % roundi(top.y), HORIZONTAL_ALIGNMENT_CENTER, 60.0, FONT_SIZE + 7,
		GUIDE if top.y > TrainingCamp.FATIGUE_FREE else LINE)
	if fight_week:
		var fx: float = _x(points.size() - 1)
		draw_line(Vector2(fx, 6.0), Vector2(fx, size.y - BOTTOM), GUIDE, 2.0)
		draw_string(font, Vector2(fx - 60.0, size.y - BOTTOM - 6.0), "FIGHT", HORIZONTAL_ALIGNMENT_RIGHT, 54.0, FONT_SIZE, GUIDE)
