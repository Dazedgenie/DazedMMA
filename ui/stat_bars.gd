class_name StatBars
extends Control
## The fighter's stats as bars on the camp planner (D160, docs/02 §3.10), in their groups: each stat's bar runs
## 0–100, the part the camp has added so far is green (a lost part red, past the bar's end), a tick marks where this
## week's forecast takes it, and the number, grade and camp change sit at the right.

const ROW_H: float = 24.0
const HEADER_H: float = 28.0
const NAME_W: float = 150.0
const VALUE_W: float = 112.0
const BAR_H: float = 7.0
const FONT_SIZE: int = 15
const TEXT := Color("#dee2e6")
const DIM := Color("#8a8f98")
const TRACK := Color("#2b3038")
const BASE := Color("#5c6573")
const GAIN := Color("#69db7c")
const LOSS := Color("#ff8787")
const COMING := Color("#fcc419")

## { group: "Physical" } or { name, value, grade, change (camp so far), coming (this week's forecast) }, top to bottom.
var rows: Array[Dictionary] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_rows(new_rows: Array[Dictionary]) -> void:
	rows = new_rows
	var h: float = 0.0
	for row in rows:
		h += HEADER_H if row.has("group") else ROW_H
	custom_minimum_size.y = h
	queue_redraw()


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var y: float = 0.0
	var bar_x: float = NAME_W
	var bar_w: float = maxf(20.0, size.x - NAME_W - VALUE_W - 8.0)
	for row in rows:
		if row.has("group"):
			draw_string(DisplayFont.font(), Vector2(0.0, y + HEADER_H - 7.0), String(row.group).to_upper(), HORIZONTAL_ALIGNMENT_LEFT,
				-1, FONT_SIZE + 2, DIM)
			y += HEADER_H
			continue
		var base_line: float = y + ROW_H - 7.0
		draw_string(font, Vector2(8.0, base_line), String(row.name), HORIZONTAL_ALIGNMENT_LEFT, NAME_W - 12.0, FONT_SIZE, TEXT)
		var value: float = float(row.value)
		var change: float = float(row.get("change", 0.0))
		var bar_y: float = y + (ROW_H - BAR_H) * 0.5
		var at := func(v: float) -> float: return bar_x + bar_w * clampf(v, 0.0, 100.0) / 100.0
		draw_rect(Rect2(bar_x, bar_y, bar_w, BAR_H), TRACK)
		var start: float = value - change
		draw_rect(Rect2(bar_x, bar_y, at.call(minf(start, value)) - bar_x, BAR_H), BASE)
		if absf(change) >= 0.005:
			# Gains are small on a 0–100 bar, so the camp's part is at least a few pixels wide to be seen.
			var x0: float = at.call(minf(start, value))
			var w: float = maxf(3.0, absf(at.call(value) - at.call(start)))
			draw_rect(Rect2(x0, bar_y, w, BAR_H), GAIN if change > 0.0 else LOSS)
		var coming: float = float(row.get("coming", 0.0))
		if coming >= 0.005:
			var cx: float = maxf(at.call(value + coming), at.call(value) + 4.0)
			draw_rect(Rect2(cx - 1.0, bar_y - 3.0, 2.0, BAR_H + 6.0), COMING)
		var text: String = "%d %s" % [roundi(value), row.grade]
		var vx: float = size.x - VALUE_W
		draw_string(DisplayFont.font(), Vector2(vx + 4.0, base_line), text, HORIZONTAL_ALIGNMENT_LEFT, 56.0, FONT_SIZE + 3, TEXT)
		if absf(change) >= 0.005:
			draw_string(font, Vector2(vx + 56.0, base_line), "%+.2f" % change, HORIZONTAL_ALIGNMENT_LEFT, VALUE_W - 56.0,
				FONT_SIZE - 1, GAIN if change > 0.0 else LOSS)
		y += ROW_H
