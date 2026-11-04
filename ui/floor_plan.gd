class_name FloorPlan
extends Control
## Your gym from above (docs/03 §14.2, D442; Kyle's pick "A drawn floor plan from above"): the place's floor as a
## grid of squares inside its walls, each built room drawn on the squares it takes (mats as blue tiles, bags hanging,
## a ring with its ropes, the cage's octagon, weights, an ice bath, a screen and sofa, lockers), its name and level
## pips on it, a room being built striped and counting down, and the free squares dashed. Clicking a room picks it;
## clicking a free square picks nothing (the page then lists what you can build). Drawn in code.

signal picked(room_id: String)

const WALL := Color("#ced4da")
const CONCRETE := Color("#2b3038")
const GRID := Color("#363c46")
const FREE := Color("#5c636e")
const PICKED := Color("#ff6b6b")
const LABEL := Color("#f1f3f5")
const PIP_ON := Color("#fcc419")
const PIP_OFF := Color("#495057")
const STRIPE := Color("#fcc419")
## Each room's floor colour.
const FLOOR := {
	"mats": Color("#1c5d99"), "bags": Color("#3d3d45"), "ring": Color("#3b4a5c"), "cage": Color("#2f3d33"),
	"weights": Color("#3a3530"), "recovery": Color("#2c4650"), "video": Color("#2e2a3d"), "changing": Color("#3a3f44"),
}
const WALL_WIDTH: float = 8.0

var gym: Dictionary = {}
var week: int = 0
var picked_room: String = ""
## Where each room is drawn: id → Rect2 (in this control), from layout().
var rects: Dictionary = {}
## The free squares' rects.
var free_cells: Array[Rect2] = []


func _init() -> void:
	custom_minimum_size = Vector2(560.0, 420.0)
	mouse_filter = Control.MOUSE_FILTER_STOP


func show_gym(p_gym: Dictionary, p_week: int, p_picked: String = "") -> void:
	gym = p_gym
	week = p_week
	picked_room = p_picked
	queue_redraw()


## The grid's columns and rows for this gym's floor (Gym.grid_of).
static func grid_of(floor_squares: int) -> Vector2i:
	return Gym.grid_of(floor_squares)


## Which squares each room takes (Gym.spots: where it was built stays put).
static func cells_for(g: Dictionary) -> Dictionary:
	return Gym.spots(g)


## Lays the plan out in this size: rects and free_cells.
func layout() -> void:
	rects.clear()
	free_cells.clear()
	var floor_squares: int = Gym.floor_size(gym)
	if floor_squares <= 0:
		return
	var grid: Vector2i = grid_of(floor_squares)
	var cell: float = minf((size.x - WALL_WIDTH * 2.0) / grid.x, (size.y - WALL_WIDTH * 2.0) / grid.y)
	var origin := Vector2((size.x - cell * grid.x) * 0.5, (size.y - cell * grid.y) * 0.5)
	var used: Dictionary = {}
	var cells: Dictionary = cells_for(gym)
	for id: String in cells:
		var r := Rect2()
		var first: bool = true
		for c: Vector2i in cells[id]:
			used[c] = true
			var cr := Rect2(origin + Vector2(c) * cell, Vector2(cell, cell))
			r = cr if first else r.merge(cr)
			first = false
		rects[id] = r.grow(-4.0)
	for n in floor_squares:
		var c := Vector2i(n % grid.x, n / grid.x)
		if not used.has(c):
			free_cells.append(Rect2(origin + Vector2(c) * cell, Vector2(cell, cell)).grow(-4.0))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		layout()
		var hit: String = ""
		for id: String in rects:
			if (rects[id] as Rect2).has_point(event.position):
				hit = id
		picked_room = hit
		queue_redraw()
		picked.emit(hit)
		accept_event()


func _draw() -> void:
	layout()
	var floor_squares: int = Gym.floor_size(gym)
	if floor_squares <= 0:
		return
	var grid: Vector2i = grid_of(floor_squares)
	var cell: float = minf((size.x - WALL_WIDTH * 2.0) / grid.x, (size.y - WALL_WIDTH * 2.0) / grid.y)
	var origin := Vector2((size.x - cell * grid.x) * 0.5, (size.y - cell * grid.y) * 0.5)
	# The floor, its squares and the walls (a short last row stops where the floor does).
	for n in floor_squares:
		var c := Vector2i(n % grid.x, n / grid.x)
		draw_rect(Rect2(origin + Vector2(c) * cell, Vector2(cell, cell)), CONCRETE)
		draw_rect(Rect2(origin + Vector2(c) * cell, Vector2(cell, cell)), GRID, false, 1.0)
	draw_rect(Rect2(origin, Vector2(cell * grid.x, cell * grid.y)).grow(WALL_WIDTH * 0.5), WALL, false, WALL_WIDTH)
	# The door, on the bottom wall.
	var door := Rect2(origin + Vector2(cell * 0.1, cell * grid.y - WALL_WIDTH * 0.5), Vector2(minf(cell * 0.3, 70.0), WALL_WIDTH * 1.2))
	draw_rect(door, CONCRETE)
	draw_arc(door.position, door.size.x, -PI * 0.5, 0.0, 12, WALL, 1.5)
	var font: Font = DisplayFont.font()
	for r: Rect2 in free_cells:
		_dashed_rect(r, FREE)
		draw_string(font, r.position + Vector2(0.0, r.size.y * 0.55), "+ free", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, FREE)
	var building: Dictionary = gym.get("building", {})
	for id: String in rects:
		var r: Rect2 = rects[id]
		draw_rect(r, FLOOR.get(id, CONCRETE))
		_draw_room(id, r)
		if String(building.get("room", "")) == id:
			_stripes(r)
			var left: int = maxi(1, int(building.get("done", week)) - week)
			var what: String = "tearing out" if int(building.get("level", 0)) == 0 else "building level %d" % int(building.level)
			_tag(r.get_center() + Vector2(0.0, 18.0), "%s · %d week%s" % [what, left, "" if left == 1 else "s"], STRIPE)
		_tag(r.position + Vector2(r.size.x * 0.5, 22.0), String(Gym.room(id).get("name", id)).to_upper(), LABEL)
		_pips(r, Gym.level(gym, id))
		if id == picked_room:
			draw_rect(r.grow(2.0), PICKED, false, 3.0)


## A label centred on `at` on a dark strip.
func _tag(at: Vector2, text: String, colour: Color) -> void:
	var font: Font = DisplayFont.font()
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	draw_rect(Rect2(at - Vector2(w * 0.5 + 6.0, 15.0), Vector2(w + 12.0, 22.0)), Color(0.0, 0.0, 0.0, 0.55))
	draw_string(font, at - Vector2(w * 0.5, -1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, colour)


## The level as three pips in the room's bottom right.
func _pips(r: Rect2, lv: int) -> void:
	for i in Gym.ROOM_LEVELS:
		var at: Vector2 = r.end - Vector2(16.0 + (Gym.ROOM_LEVELS - 1 - i) * 16.0, 14.0)
		draw_circle(at, 5.5, PIP_ON if i < lv else PIP_OFF)


func _dashed_rect(r: Rect2, colour: Color) -> void:
	var corners: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		draw_dashed_line(corners[i], corners[(i + 1) % 4], colour, 2.0, 8.0)


func _stripes(r: Rect2) -> void:
	var step: float = 22.0
	var t: float = -r.size.y
	while t < r.size.x:
		var a := Vector2(maxf(0.0, t), maxf(0.0, -t))
		var b := Vector2(minf(r.size.x, t + r.size.y), minf(r.size.y, r.size.x - t))
		if b.x > a.x:
			draw_line(r.position + a, r.position + b, Color(STRIPE, 0.35), 6.0)
		t += step


## Each room's own drawing, from above.
func _draw_room(id: String, r: Rect2) -> void:
	var c: Vector2 = r.get_center()
	var inner: Rect2 = r.grow(-r.size.y * 0.18)
	match id:
		"mats":
			var tile: float = r.size.y / 4.0
			var y: float = r.position.y
			var row: int = 0
			while y < r.end.y - 1.0:
				var x: float = r.position.x
				var col: int = 0
				while x < r.end.x - 1.0:
					var t := Rect2(Vector2(x, y), Vector2(minf(tile, r.end.x - x), minf(tile, r.end.y - y)))
					draw_rect(t, Color("#1c5d99") if (row + col) % 2 == 0 else Color("#1971c2"))
					x += tile
					col += 1
				y += tile
				row += 1
		"bags":
			var n: int = 3
			for i in n:
				var at := Vector2(r.position.x + r.size.x * (i + 1) / (n + 1), c.y + 6.0)
				draw_circle(at, r.size.y * 0.11, Color("#c92a2a"))
				draw_arc(at, r.size.y * 0.11, 0.0, TAU, 20, Color("#1a1d23"), 2.0)
				draw_circle(at, r.size.y * 0.03, Color("#1a1d23"))
		"ring":
			var sq: float = minf(r.size.x, r.size.y) * 0.78
			var ring := Rect2(c - Vector2(sq, sq) * 0.5 + Vector2(0.0, 6.0), Vector2(sq, sq))
			draw_rect(ring, Color("#dee2e6"))
			for k in 3:
				draw_rect(ring.grow(-4.0 - k * 5.0), [Color("#e03131"), Color("#f8f9fa"), Color("#1c7ed6")][k], false, 2.0)
			for corner: Vector2 in [ring.position, Vector2(ring.end.x, ring.position.y), ring.end, Vector2(ring.position.x, ring.end.y)]:
				draw_circle(corner, 5.0, Color("#212529"))
		"cage":
			var rad: float = minf(r.size.x, r.size.y) * 0.4
			var pts := PackedVector2Array()
			for k in 8:
				var a: float = TAU * (k + 0.5) / 8.0
				pts.append(c + Vector2(0.0, 6.0) + Vector2(cos(a), sin(a)) * rad)
			draw_colored_polygon(pts, Color("#e9ecef"))
			pts.append(pts[0])
			draw_polyline(pts, Color("#212529"), 4.0)
			draw_circle(c + Vector2(0.0, 6.0), rad * 0.25, Color("#ff6b6b", 0.6))
		"weights":
			for k in 2:
				var y: float = inner.position.y + inner.size.y * (0.35 + 0.4 * k)
				draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), Color("#adb5bd"), 3.0)
				for side in [inner.position.x + 6.0, inner.end.x - 6.0]:
					draw_rect(Rect2(Vector2(side - 4.0, y - 10.0), Vector2(8.0, 20.0)), Color("#212529"))
		"recovery":
			var tub := Rect2(inner.position + Vector2(0.0, inner.size.y * 0.25), Vector2(inner.size.x * 0.55, inner.size.y * 0.6))
			draw_rect(tub, Color("#a5d8ff"))
			draw_rect(tub, Color("#dee2e6"), false, 3.0)
			draw_rect(Rect2(Vector2(tub.end.x + 8.0, tub.position.y), Vector2(inner.end.x - tub.end.x - 8.0, tub.size.y)), Color("#c0a37a"))
		"video":
			draw_rect(Rect2(Vector2(inner.position.x + inner.size.x * 0.15, inner.position.y + 6.0), Vector2(inner.size.x * 0.7, 6.0)), Color("#74c0fc"))
			var sofa := Rect2(Vector2(inner.position.x + inner.size.x * 0.2, inner.end.y - inner.size.y * 0.35), Vector2(inner.size.x * 0.6, inner.size.y * 0.3))
			draw_rect(sofa, Color("#7048e8"))
			draw_rect(sofa.grow(-5.0), Color("#845ef7"))
		"changing":
			var n: int = 5
			var w: float = inner.size.x / n
			for k in n:
				draw_rect(Rect2(Vector2(inner.position.x + k * w + 1.0, inner.position.y + 4.0), Vector2(w - 2.0, inner.size.y * 0.35)), Color("#868e96"))
			draw_rect(Rect2(Vector2(inner.position.x, inner.end.y - inner.size.y * 0.25), Vector2(inner.size.x, inner.size.y * 0.12)), Color("#c0a37a"))
