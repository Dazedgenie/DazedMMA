class_name PromotionBadge
extends Control
## A promotion's badge, drawn in code (docs/06 §6.12, D432; Kyle's picks on the D430 and D432 cards): its colour and its
## initials on a shape that says how big it is: the world organisation a belt plate, the international one a shield,
## a regional promotion a round badge. The world organisation is always gold and the international one always crimson;
## each regional promotion gets its own colour from REGIONAL_COLOURS, shuffled by the world's seed so it's the same
## all career and differs between careers.

const PLATE := "plate"
const SHIELD := "shield"
const ROUND := "round"
const WORLD_GOLD := Color("#d6a531")
const INTERNATIONAL_CRIMSON := Color("#c22a3e")
## Regional colours, one each (a career has 3 or 4 regional promotions).
const REGIONAL_COLOURS: Array[Color] = [Color("#2f7dd1"), Color("#2a9d6f"), Color("#8a5cd6"), Color("#e07b28"),
	Color("#16a3b5"), Color("#c9468f"), Color("#7d9a2b"), Color("#b5613b")]
## The initials' size as a share of the badge's height, and the most letters shown.
const LETTERS_SHARE: float = 0.36
const LETTERS_MAX: int = 4
const INK := Color("#0f1217")

var colour: Color = REGIONAL_COLOURS[0]
var shape: String = ROUND
var initials: String = ""


func _init(p_size: Vector2 = Vector2(40.0, 40.0)) -> void:
	custom_minimum_size = p_size
	size = p_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows this promotion (a Promotions dict) of this world.
func show_promotion(w: World, p: Dictionary) -> void:
	colour = colour_of(w, p)
	shape = shape_of(p)
	initials = String(p.get("short", "")).substr(0, LETTERS_MAX)
	tooltip_text = String(p.get("name", ""))
	queue_redraw()


## The world organisation's gold, the international one's crimson, or this regional promotion's own colour.
static func colour_of(w: World, p: Dictionary) -> Color:
	var rank: int = int(p.get("rank", Promotions.REGIONAL))
	if rank == 0:
		return WORLD_GOLD
	if rank == 1:
		return INTERNATIONAL_CRIMSON
	var regionals: Array[String] = []
	if w != null:
		for q: Dictionary in w.promotions:
			if int(q.get("rank", 0)) >= Promotions.REGIONAL:
				regionals.append(String(q.id))
	regionals.sort()
	var at: int = maxi(regionals.find(String(p.get("id", ""))), 0)
	var order: Array = range(REGIONAL_COLOURS.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([w.seed_value if w != null else 0, "promotion colours"])
	for i in range(order.size() - 1, 0, -1):  # Fisher–Yates, so each regional gets a different colour.
		var j: int = rng.randi_range(0, i)
		var t: Variant = order[i]
		order[i] = order[j]
		order[j] = t
	return REGIONAL_COLOURS[int(order[at % order.size()])]


static func shape_of(p: Dictionary) -> String:
	var rank: int = int(p.get("rank", Promotions.REGIONAL))
	return PLATE if rank == 0 else SHIELD if rank == 1 else ROUND


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var dark: Color = colour.darkened(0.45)
	var light: Color = colour.lightened(0.25)
	match shape:
		PLATE:
			# A belt: the strap across, the plate in the middle with a rim.
			var strap := Rect2(0.0, r.size.y * 0.3, r.size.x, r.size.y * 0.4)
			draw_rect(strap, dark)
			draw_rect(Rect2(strap.position + Vector2(0.0, strap.size.y * 0.15), Vector2(strap.size.x, 1.5)), colour.darkened(0.2))
			draw_rect(Rect2(strap.position + Vector2(0.0, strap.size.y * 0.85), Vector2(strap.size.x, 1.5)), colour.darkened(0.2))
			var c: Vector2 = r.get_center()
			var radii := Vector2(r.size.x * 0.34, r.size.y * 0.48)
			draw_colored_polygon(_ellipse(c, radii), light)
			draw_colored_polygon(_ellipse(c, radii * 0.86), colour)
		SHIELD:
			var w: float = r.size.x
			var h: float = r.size.y
			var outer := PackedVector2Array([Vector2(w * 0.08, 0.0), Vector2(w * 0.92, 0.0), Vector2(w * 0.92, h * 0.5),
				Vector2(w * 0.5, h), Vector2(w * 0.08, h * 0.5)])
			draw_colored_polygon(outer, light)
			var inset: float = minf(w, h) * 0.08
			var inner := PackedVector2Array([Vector2(w * 0.08 + inset, inset), Vector2(w * 0.92 - inset, inset),
				Vector2(w * 0.92 - inset, h * 0.5 - inset * 0.3), Vector2(w * 0.5, h - inset * 1.6), Vector2(w * 0.08 + inset, h * 0.5 - inset * 0.3)])
			draw_colored_polygon(inner, colour)
		_:
			var c: Vector2 = r.get_center()
			var radius: float = minf(r.size.x, r.size.y) * 0.5
			draw_circle(c, radius, light)
			draw_circle(c, radius * 0.84, colour)
			draw_arc(c, radius * 0.7, 0.0, TAU, 40, dark, maxf(1.0, radius * 0.05))
	if initials == "":
		return
	var font: Font = DisplayFont.font()
	var font_size: int = maxi(8, int(r.size.y * LETTERS_SHARE))
	var text_w: float = font.get_string_size(initials, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var fit: float = r.size.x * (0.6 if shape == PLATE else 0.78)
	if text_w > fit:
		font_size = maxi(8, int(font_size * fit / text_w))
		text_w = font.get_string_size(initials, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var y: float = r.size.y * (0.42 if shape == SHIELD else 0.5) + font.get_ascent(font_size) * 0.5 - font.get_descent(font_size) * 0.3
	draw_string(font, Vector2((r.size.x - text_w) * 0.5, y), initials, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, INK)


static func _ellipse(c: Vector2, radii: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 32:
		var a: float = TAU * i / 32.0
		points.append(c + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return points
