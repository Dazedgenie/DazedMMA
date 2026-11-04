class_name BackgroundIcon
extends Control
## A small picture for each of the 12 backgrounds (data/backgrounds, docs/02 §1.2), drawn in code (docs/06 §6.14,
## D434; Kyle's picks "Drawn in code", the D430 cards, and the background tiles on the D434 cards): a glove for the
## boxing gym kid, a plaster for the bullied underdog, a football, a barn, a belt for the jiu-jitsu prodigy, a gi for
## the judo and sambo household, a clock for the late starter, Thai pads, a brick wall for the street kid, a running
## track, a gate for traditional martial arts and a wrestling mat's circles. The five gym kinds (data/gyms) borrow the
## nearest one (ALIASES), and the MMA gym gets a cage. An id it doesn't know gets a dot.

const SIZE := Vector2(44.0, 44.0)
## Each background's colour.
const COLOURS := {
	"boxing_gym_kid": Color("#ff6b6b"), "bullied_underdog": Color("#f8f9fa"), "college_football": Color("#c08552"),
	"farm_kid": Color("#e8590c"), "jiu_jitsu_prodigy": Color("#748ffc"), "judo_sambo_household": Color("#e9ecef"),
	"late_starter": Color("#ffd43b"), "muay_thai_abroad": Color("#ff922b"), "street_kid": Color("#adb5bd"),
	"track_star": Color("#69db7c"), "traditional_martial_arts": Color("#fa5252"), "wrestling_family": Color("#4dabf7"),
}
## The gym kinds (D434's gym cards), drawn as the background nearest them.
const ALIASES := {
	"boxing_gym": "boxing_gym_kid", "wrestling_club": "wrestling_family", "bjj_academy": "jiu_jitsu_prodigy",
	"muay_thai_camp": "muay_thai_abroad",
}
const MMA_GYM := "mma_gym"
const MMA_COLOUR := Color("#69db7c")
const INK := Color("#14171c")

var id: String = ""


func _init(p_id: String = "") -> void:
	id = p_id
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func colour_of(p_id: String) -> Color:
	if p_id == MMA_GYM:
		return MMA_COLOUR
	return COLOURS.get(ALIASES.get(p_id, p_id), Color("#adb5bd"))


## Whether there's a drawing for this background or gym kind (not just the dot).
static func knows(p_id: String) -> bool:
	return COLOURS.has(ALIASES.get(p_id, p_id)) or p_id == MMA_GYM


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var o := Vector2((size.x - s) * 0.5, (size.y - s) * 0.5)
	var c: Color = colour_of(id)
	var line: float = maxf(2.0, s * 0.07)
	var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	match String(ALIASES.get(id, id)):
		MMA_GYM:
			var cage := PackedVector2Array()
			for i in 9:
				var a: float = TAU * (i + 0.5) / 8.0
				cage.append(p.call(0.5 + cos(a) * 0.44, 0.5 + sin(a) * 0.44))
			draw_colored_polygon(cage.slice(0, 8), c.darkened(0.55))
			draw_polyline(cage, c, line)
			for i in 8:
				draw_circle(cage[i], line * 0.8, c)
		"boxing_gym_kid":
			draw_circle(p.call(0.52, 0.42), s * 0.3, c)
			draw_circle(p.call(0.26, 0.5), s * 0.13, c)
			draw_rect(Rect2(p.call(0.3, 0.6), Vector2(s * 0.42, s * 0.28)), c.darkened(0.2))
			draw_line(p.call(0.3, 0.68), p.call(0.72, 0.68), INK, line * 0.6)
		"bullied_underdog":
			for angle in [PI / 4.0, -PI / 4.0]:
				draw_set_transform(p.call(0.5, 0.5), angle)
				draw_rect(Rect2(Vector2(-s * 0.42, -s * 0.12), Vector2(s * 0.84, s * 0.24)), c.darkened(0.15 if angle > 0 else 0.0))
				draw_set_transform(Vector2.ZERO)
			draw_rect(Rect2(p.call(0.4, 0.4), Vector2(s * 0.2, s * 0.2)), Color("#d4a373"))
		"college_football":
			var points := PackedVector2Array()
			for i in 24:
				var a: float = TAU * i / 24.0
				points.append(p.call(0.5 + cos(a) * 0.42, 0.5 + sin(a) * 0.24))
			draw_colored_polygon(points, c)
			draw_line(p.call(0.32, 0.5), p.call(0.68, 0.5), Color.WHITE, line * 0.6)
			for x in [0.4, 0.5, 0.6]:
				draw_line(p.call(x, 0.43), p.call(x, 0.57), Color.WHITE, line * 0.5)
		"farm_kid":
			draw_colored_polygon(PackedVector2Array([p.call(0.12, 0.45), p.call(0.5, 0.12), p.call(0.88, 0.45),
				p.call(0.88, 0.9), p.call(0.12, 0.9)]), c)
			var door := Rect2(p.call(0.36, 0.55), Vector2(s * 0.28, s * 0.35))
			draw_rect(door, Color.WHITE, false, line * 0.6)
			draw_line(door.position, door.end, Color.WHITE, line * 0.5)
			draw_line(door.position + Vector2(door.size.x, 0), door.position + Vector2(0, door.size.y), Color.WHITE, line * 0.5)
		"jiu_jitsu_prodigy":
			draw_rect(Rect2(p.call(0.06, 0.42), Vector2(s * 0.88, s * 0.16)), Color("#212529"))
			draw_rect(Rect2(p.call(0.66, 0.42), Vector2(s * 0.14, s * 0.16)), Color("#e03131"))
			draw_rect(Rect2(p.call(0.4, 0.36), Vector2(s * 0.2, s * 0.28)), Color("#343a40"))
			draw_colored_polygon(PackedVector2Array([p.call(0.42, 0.62), p.call(0.5, 0.62), p.call(0.4, 0.92), p.call(0.32, 0.9)]), Color("#343a40"))
			draw_colored_polygon(PackedVector2Array([p.call(0.5, 0.62), p.call(0.58, 0.62), p.call(0.68, 0.9), p.call(0.6, 0.92)]), Color("#343a40"))
			draw_rect(Rect2(p.call(0.06, 0.42), Vector2(s * 0.88, s * 0.16)), c, false, 1.0)
		"judo_sambo_household":
			draw_colored_polygon(PackedVector2Array([p.call(0.2, 0.15), p.call(0.8, 0.15), p.call(0.86, 0.9), p.call(0.14, 0.9)]), c)
			draw_polyline(PackedVector2Array([p.call(0.36, 0.15), p.call(0.5, 0.52), p.call(0.64, 0.15)]), INK, line * 0.8)
			draw_line(p.call(0.5, 0.52), p.call(0.5, 0.9), INK, line * 0.5)
			draw_rect(Rect2(p.call(0.16, 0.6), Vector2(s * 0.68, s * 0.08)), Color("#1c7ed6"))
		"late_starter":
			draw_circle(p.call(0.5, 0.5), s * 0.42, c)
			draw_circle(p.call(0.5, 0.5), s * 0.34, INK)
			draw_line(p.call(0.5, 0.5), p.call(0.5, 0.26), c, line)
			draw_line(p.call(0.5, 0.5), p.call(0.68, 0.58), c, line)
		"muay_thai_abroad":
			for x in [0.1, 0.54]:
				draw_rect(Rect2(p.call(x, 0.14), Vector2(s * 0.36, s * 0.72)), c)
				draw_rect(Rect2(p.call(x + 0.06, 0.24), Vector2(s * 0.24, s * 0.06)), INK)
				draw_rect(Rect2(p.call(x + 0.06, 0.7), Vector2(s * 0.24, s * 0.06)), INK)
		"street_kid":
			for row in 4:
				var shift: float = 0.0 if row % 2 == 0 else 0.15
				for col in 4:
					var x: float = 0.06 + shift + col * 0.3 - 0.15
					var r := Rect2(p.call(maxf(x, 0.06), 0.1 + row * 0.2), Vector2.ZERO)
					r.end = p.call(minf(x + 0.27, 0.94), 0.1 + row * 0.2 + 0.17)
					if r.size.x > 1.0:
						draw_rect(r, c.darkened(0.1 * ((row + col) % 3)))
		"track_star":
			for i in 3:
				var r: float = 0.18 + i * 0.12
				draw_arc(p.call(0.5, 0.5), s * r, PI * 0.6, PI * 1.9, 20, c.darkened(0.12 * i), line * 0.8)
			draw_line(p.call(0.5, 0.1), p.call(0.5, 0.92), Color.WHITE, line * 0.5)
		"traditional_martial_arts":
			draw_rect(Rect2(p.call(0.06, 0.16), Vector2(s * 0.88, s * 0.1)), c)
			draw_rect(Rect2(p.call(0.14, 0.34), Vector2(s * 0.72, s * 0.07)), c)
			draw_rect(Rect2(p.call(0.22, 0.16), Vector2(s * 0.1, s * 0.76)), c)
			draw_rect(Rect2(p.call(0.68, 0.16), Vector2(s * 0.1, s * 0.76)), c)
		"wrestling_family":
			draw_circle(p.call(0.5, 0.5), s * 0.44, c.darkened(0.35))
			draw_circle(p.call(0.5, 0.5), s * 0.36, c)
			draw_arc(p.call(0.5, 0.5), s * 0.12, 0.0, TAU, 24, Color.WHITE, line * 0.6)
			draw_line(p.call(0.42, 0.5), p.call(0.58, 0.5), Color("#e03131"), line * 0.6)
		_:
			draw_circle(p.call(0.5, 0.5), s * 0.18, c)
