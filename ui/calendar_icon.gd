class_name CalendarIcon
extends Control
## A small icon for a calendar event on the hub, drawn in code (docs/06 §6.13, D433; Kyle's picks "Drawn in code" on the
## D430 cards and "Icons drawn in code" on the D433 cards): crossed gloves for fight night, a red cross for hurt, a green
## cross for healed, a tick for cleared to fight, a candle for a birthday, a book for school, a sun for the summer
## holidays, an envelope for offers, a coin for the gym behind on its rent, a low battery for worn down and a little
## building for a room built at your gym (D442); a lad or your stable's news is a dot in its colour (D444, D445).

const SIZE := Vector2(26.0, 26.0)
## Each kind's colour.
const COLOURS := {
	Career.FIGHT_NIGHT: Color("#ff6b6b"), Career.HURT: Color("#ff8787"), Career.HEALED: Color("#69db7c"),
	Career.CLEARED: Color("#69db7c"), Career.BIRTHDAY: Color("#f783ac"), Career.BACK_TO_SCHOOL: Color("#74c0fc"),
	Career.LEFT_SCHOOL: Color("#74c0fc"), Career.SCHOOL_OUT: Color("#ffd43b"), Career.OFFERS: Color("#fcc419"),
	Career.GYM_BEHIND: Color("#fcc419"), Career.WORN_DOWN: Color("#ffa94d"), Career.ROOM_DONE: Color("#4dabf7"),
	Career.COACH_UNPAID: Color("#fcc419"), Career.COACH_LEFT: Color("#ff8787"),
	Career.LAD_IN: Color("#69db7c"), Career.LAD_LEFT: Color("#91a7ff"),
	Career.STABLE_SIGNED: Color("#38d9a9"), Career.STABLE_FOUGHT: Color("#e599f7"),
	Career.STABLE_UNHAPPY: Color("#ffa94d"), Career.STABLE_LEFT: Color("#748ffc"),
}

var kind: String = ""


func _init(p_kind: String = "") -> void:
	kind = p_kind
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func colour_of(p_kind: String) -> Color:
	return COLOURS.get(p_kind, Color("#adb5bd"))


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var o := Vector2((size.x - s) * 0.5, (size.y - s) * 0.5)
	var c: Color = colour_of(kind)
	var ink := Color("#0f1217")
	var line: float = maxf(2.0, s * 0.1)
	match kind:
		Career.FIGHT_NIGHT:
			# Two gloves, crossed.
			for side in [-1.0, 1.0]:
				var centre: Vector2 = o + Vector2(s * (0.5 + 0.17 * side), s * 0.42)
				draw_circle(centre, s * 0.24, c)
				draw_rect(Rect2(centre + Vector2(-s * 0.12, s * 0.16), Vector2(s * 0.24, s * 0.22)), c.darkened(0.25))
			draw_line(o + Vector2(s * 0.5, s * 0.2), o + Vector2(s * 0.5, s * 0.65), ink, 1.5)
		Career.HURT, Career.HEALED:
			var bar: float = s * 0.26
			draw_rect(Rect2(o + Vector2((s - bar) * 0.5, s * 0.12), Vector2(bar, s * 0.76)), c)
			draw_rect(Rect2(o + Vector2(s * 0.12, (s - bar) * 0.5), Vector2(s * 0.76, bar)), c)
		Career.CLEARED:
			draw_polyline(PackedVector2Array([o + Vector2(s * 0.15, s * 0.52), o + Vector2(s * 0.4, s * 0.78), o + Vector2(s * 0.86, s * 0.22)]),
				c, line * 1.4)
		Career.BIRTHDAY:
			draw_rect(Rect2(o + Vector2(s * 0.12, s * 0.55), Vector2(s * 0.76, s * 0.35)), c)
			draw_rect(Rect2(o + Vector2(s * 0.45, s * 0.25), Vector2(s * 0.1, s * 0.3)), Color("#f8f9fa"))
			draw_circle(o + Vector2(s * 0.5, s * 0.17), s * 0.08, Color("#ffd43b"))
		Career.BACK_TO_SCHOOL, Career.LEFT_SCHOOL:
			# An open book.
			draw_colored_polygon(PackedVector2Array([o + Vector2(s * 0.08, s * 0.25), o + Vector2(s * 0.48, s * 0.33),
				o + Vector2(s * 0.48, s * 0.85), o + Vector2(s * 0.08, s * 0.75)]), c)
			draw_colored_polygon(PackedVector2Array([o + Vector2(s * 0.52, s * 0.33), o + Vector2(s * 0.92, s * 0.25),
				o + Vector2(s * 0.92, s * 0.75), o + Vector2(s * 0.52, s * 0.85)]), c.darkened(0.2))
		Career.SCHOOL_OUT:
			var centre: Vector2 = o + Vector2(s, s) * 0.5
			draw_circle(centre, s * 0.22, c)
			for i in 8:
				var a: float = TAU * i / 8.0
				draw_line(centre + Vector2(cos(a), sin(a)) * s * 0.3, centre + Vector2(cos(a), sin(a)) * s * 0.45, c, line * 0.8)
		Career.OFFERS:
			var r := Rect2(o + Vector2(s * 0.08, s * 0.22), Vector2(s * 0.84, s * 0.56))
			draw_rect(r, c)
			draw_polyline(PackedVector2Array([r.position, r.position + Vector2(r.size.x * 0.5, r.size.y * 0.55), r.position + Vector2(r.size.x, 0.0)]),
				ink, 1.5)
		Career.GYM_BEHIND, Career.COACH_UNPAID, Career.COACH_LEFT:
			draw_circle(o + Vector2(s, s) * 0.5, s * 0.4, c)
			draw_string(DisplayFont.font(), o + Vector2(s * 0.36, s * 0.7), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 0.55), ink)
		Career.ROOM_DONE:
			draw_colored_polygon(PackedVector2Array([o + Vector2(s * 0.1, s * 0.45), o + Vector2(s * 0.5, s * 0.12), o + Vector2(s * 0.9, s * 0.45)]), c)
			draw_rect(Rect2(o + Vector2(s * 0.2, s * 0.45), Vector2(s * 0.6, s * 0.43)), c)
			draw_rect(Rect2(o + Vector2(s * 0.42, s * 0.6), Vector2(s * 0.16, s * 0.28)), ink)
		Career.WORN_DOWN:
			draw_rect(Rect2(o + Vector2(s * 0.1, s * 0.3), Vector2(s * 0.7, s * 0.4)), c, false, line * 0.7)
			draw_rect(Rect2(o + Vector2(s * 0.8, s * 0.42), Vector2(s * 0.1, s * 0.16)), c)
			draw_rect(Rect2(o + Vector2(s * 0.16, s * 0.36), Vector2(s * 0.14, s * 0.28)), c)
		_:
			draw_circle(o + Vector2(s, s) * 0.5, s * 0.18, c)
