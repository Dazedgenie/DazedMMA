class_name CageMap
extends Control
## TEMPORARY debug view (D106, docs/01 §20.1): the cage seen from straight above, so
## the fighter AI's movement can be judged by eye (range, cage pressure, circling)
## before the grey-box fight view (#19) exists. Delete it once #19 shows the same.
##
## Draws the fence, the near-the-fence zone, both fighters with the way they face
## and the way they're moving, a 4 s trail behind each, the distance each one is
## walking toward (a ring around the opponent) and a line between them coloured by
## range. Presentation only: reads the sim, never changes it.

## How much of the path behind each fighter is drawn: 4 s of fight time.
const TRAIL_TICKS: int = 40
## The movement arrow points where the fighter would be in this long at their current pace.
const ARROW_SECONDS: float = 1.0
## Pace is measured over the last 0.5 s.
const SPEED_WINDOW: int = 5
## Slower than this counts as standing still (no arrow).
const STILL_BELOW: float = 0.05
## Length of the facing mark, in metres from the fighter's centre.
const FACING_LENGTH: float = 0.55
const HEADER_LINES: int = 3
const LINE_HEIGHT: float = 24.0
const FONT_SIZE: int = 17
const PAD: float = 12.0
const LEGEND: Array[String] = [
	"White point: the way they face.  Arrow: where they're heading (1 s at this pace).  Trail: the last 4 s.",
	"Ring: the distance each wants from the other.  White halo: pinned.  Faint lines: near the fence / pinned zone.",
]

const FIGHTER_COLOURS: Array[Color] = [Color("#ff6b6b"), Color("#5fa8ff")]
const BAND_COLOURS := {
	"out": Color("#8a8f98"), "long": Color("#6bd66b"), "mid": Color("#f2d04b"),
	"pocket": Color("#ff9d3b"), "clinch": Color("#d77bff"),
}
const BACKGROUND := Color(0.06, 0.07, 0.09, 0.88)
const FLOOR := Color(0.16, 0.17, 0.2)
const FENCE := Color(0.82, 0.84, 0.88)
const ZONE_LINE := Color(0.82, 0.84, 0.88, 0.25)
const PINNED := Color("#ffffff")
const TEXT := Color(0.9, 0.91, 0.93)
const DIM := Color("#8a8f98")

var sim: FightSim
var _trails: Array[PackedVector2Array] = [PackedVector2Array(), PackedVector2Array()]
var _round: int = 0
## Cage metres → pixels, worked out each draw from the control's size.
var _centre: Vector2
var _scale: float = 1.0


## Starts following a fight (null clears the map).
func watch(p_sim: FightSim) -> void:
	sim = p_sim
	_trails = [PackedVector2Array(), PackedVector2Array()]
	_round = sim.clock.current_round if sim != null else 0
	queue_redraw()


## Records where both fighters are now. Call once after every sim tick.
func sample() -> void:
	if sim == null:
		return
	if sim.clock.current_round != _round:
		# Back to the corners for a new round: the walk there isn't movement.
		_round = sim.clock.current_round
		_trails = [PackedVector2Array(), PackedVector2Array()]
	for i in sim.fighters.size():
		var t: PackedVector2Array = _trails[i]
		t.append(sim.fighters[i].pos)
		if t.size() > TRAIL_TICKS + 1:
			t.remove_at(0)
		_trails[i] = t
	queue_redraw()


func trail(i: int) -> PackedVector2Array:
	return _trails[i]


## Fighter i's pace and direction over the last SPEED_WINDOW ticks, in m/s.
func velocity(i: int) -> Vector2:
	var t: PackedVector2Array = _trails[i]
	var back: int = mini(SPEED_WINDOW, t.size() - 1)
	if back <= 0:
		return Vector2.ZERO
	return (t[t.size() - 1] - t[t.size() - 1 - back]) * FightClock.TICKS_PER_SECOND / back


## The lines of text above the cage.
func header_lines() -> Array[String]:
	if sim == null:
		return ["Top-down cage view (temporary debug view)", "Press Live fight to watch the fighters move.", ""]
	var out: Array[String] = []
	for i in sim.fighters.size():
		out.append(_fighter_line(i))
	var band: String = sim.band()
	out.append("%s   %.2f m apart: %s" % [sim.clock.display(), sim.distance(), FightLogFormatter.RANGE_NAMES.get(band, band)])
	return out


func _fighter_line(i: int) -> String:
	var f: FighterState = sim.fighters[i]
	var parts: Array[String] = ["%s (%s)" % [f.name, "red" if i == 0 else "blue"]]
	if f.is_down():
		parts.append("DOWN")
	elif f.is_rocked():
		parts.append("ROCKED")
	parts.append("wants %.1f m" % sim.last_wanted_distance(i))
	parts.append("circling %d%%" % roundi(sim.last_circling(i) * 100.0))
	parts.append("%.1f m/s" % velocity(i).length())
	var cage: String = sim.cage_proximity(i)
	if cage != Octagon.CAGE_CENTRE:
		parts.append("PINNED" if cage == Octagon.CAGE_PINNED else "near the fence")
	if f.action_id != "":
		parts.append("%s (%s)" % [_action_name(f.action_id), f.phase])
	return " · ".join(parts)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	var font: Font = get_theme_default_font()
	var lines: Array[String] = header_lines()
	for n in lines.size():
		var colour: Color = TEXT
		if sim != null and n < sim.fighters.size():
			colour = FIGHTER_COLOURS[n]
		elif sim != null:
			colour = BAND_COLOURS.get(sim.band(), TEXT)
		draw_string(font, Vector2(PAD, PAD + LINE_HEIGHT * (n + 0.8)), lines[n], HORIZONTAL_ALIGNMENT_LEFT, size.x - 2.0 * PAD, FONT_SIZE, colour)

	var top: float = PAD + LINE_HEIGHT * HEADER_LINES
	var area := Rect2(PAD, top, size.x - 2.0 * PAD, size.y - top - PAD - LINE_HEIGHT * LEGEND.size())
	var corner: float = Octagon.APOTHEM / cos(PI / 8.0)
	_scale = minf(area.size.x, area.size.y) / (2.0 * corner + 0.2)
	_centre = area.get_center()

	draw_colored_polygon(_octagon(Octagon.APOTHEM), FLOOR)
	_draw_closed(_octagon(Octagon.APOTHEM - Octagon.BODY_MARGIN - Octagon.NEAR_WITHIN), ZONE_LINE, 1.5)
	_draw_closed(_octagon(Octagon.APOTHEM - Octagon.BODY_MARGIN - Octagon.PINNED_WITHIN), ZONE_LINE, 1.5)
	_draw_closed(_octagon(Octagon.APOTHEM), FENCE, 3.0)
	draw_line(_to_screen(Vector2(-0.15, 0)), _to_screen(Vector2(0.15, 0)), ZONE_LINE, 1.0)
	draw_line(_to_screen(Vector2(0, -0.15)), _to_screen(Vector2(0, 0.15)), ZONE_LINE, 1.0)
	_draw_legend(font, area)
	if sim == null:
		return

	var a: Vector2 = sim.fighters[0].pos
	var b: Vector2 = sim.fighters[1].pos
	draw_line(_to_screen(a), _to_screen(b), BAND_COLOURS.get(sim.band(), TEXT), 2.0)
	for i in sim.fighters.size():
		_draw_trail(i)
	for i in sim.fighters.size():
		_draw_fighter(i, font)


func _draw_fighter(i: int, font: Font) -> void:
	var f: FighterState = sim.fighters[i]
	var o: FighterState = sim.fighters[1 - i]
	var colour: Color = FIGHTER_COLOURS[i]
	var at: Vector2 = _to_screen(f.pos)
	# The distance this fighter is walking toward, as a ring around the opponent.
	var want: float = sim.last_wanted_distance(i)
	if want > 0.0:
		draw_arc(_to_screen(o.pos), want * _scale, 0.0, TAU, 96, Color(colour, 0.3), 1.5)
	var body: Color = colour.darkened(0.55) if f.is_down() else colour
	draw_circle(at, Octagon.BODY_MARGIN * _scale, body)
	if sim.cage_proximity(i) == Octagon.CAGE_PINNED:
		draw_arc(at, Octagon.BODY_MARGIN * _scale + 3.0, 0.0, TAU, 48, PINNED, 3.0)
	elif f.is_rocked():
		draw_arc(at, Octagon.BODY_MARGIN * _scale + 3.0, 0.0, TAU, 48, BAND_COLOURS.clinch, 2.0)
	# Facing: the engine keeps both fighters squared up to each other (no separate facing yet).
	var facing: Vector2 = (o.pos - f.pos).normalized()
	var nose: PackedVector2Array = [
		_to_screen(f.pos + facing * FACING_LENGTH),
		_to_screen(f.pos + facing.rotated(0.6) * Octagon.BODY_MARGIN),
		_to_screen(f.pos + facing.rotated(-0.6) * Octagon.BODY_MARGIN),
	]
	draw_colored_polygon(nose, Color.WHITE)
	# Movement: where they'd be in ARROW_SECONDS at this pace.
	var v: Vector2 = velocity(i)
	if v.length() > STILL_BELOW:
		_draw_arrow(at, _to_screen(f.pos + v * ARROW_SECONDS), Color(colour.lightened(0.4), 0.95))
	var label: String = f.name
	if f.action_id != "":
		label += "  " + _action_name(f.action_id)
	draw_string(font, at + Vector2(-60.0, -Octagon.BODY_MARGIN * _scale - 8.0), label, HORIZONTAL_ALIGNMENT_CENTER, 120.0, FONT_SIZE - 2, colour)


func _draw_trail(i: int) -> void:
	var t: PackedVector2Array = _trails[i]
	if t.size() < 2:
		return
	var points := PackedVector2Array()
	var colours := PackedColorArray()
	for n in t.size():
		points.append(_to_screen(t[n]))
		colours.append(Color(FIGHTER_COLOURS[i], 0.9 * float(n + 1) / t.size()))
	draw_polyline_colors(points, colours, 2.0)


func _draw_arrow(from: Vector2, to: Vector2, colour: Color) -> void:
	draw_line(from, to, colour, 2.5)
	var back: Vector2 = (from - to).normalized() * 10.0
	draw_line(to, to + back.rotated(0.45), colour, 2.5)
	draw_line(to, to + back.rotated(-0.45), colour, 2.5)


func _draw_legend(font: Font, area: Rect2) -> void:
	for n in LEGEND.size():
		var y: float = area.end.y + LINE_HEIGHT * (n + 0.75)
		draw_string(font, Vector2(PAD, y), LEGEND[n], HORIZONTAL_ALIGNMENT_LEFT, size.x - 2.0 * PAD, FONT_SIZE - 3, DIM)
	# 1 m scale bar in the cage area's top-right corner (outside the fence).
	var right := Vector2(area.end.x, area.position.y + 16.0)
	draw_line(right - Vector2(_scale, 0), right, DIM, 2.0)
	draw_string(font, right - Vector2(_scale, 6.0), "1 m", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE - 3, DIM)


func _action_name(id: String) -> String:
	return String(sim.actions.get_action(id).name) if sim.actions.has(id) else id


## The octagon's corners for a given centre-to-panel distance (panels face the axes
## and the diagonals, as in Octagon.NORMALS), in screen pixels.
func _octagon(apothem: float) -> PackedVector2Array:
	var corner: float = apothem / cos(PI / 8.0)
	var points := PackedVector2Array()
	for k in 8:
		points.append(_to_screen(Vector2.from_angle(PI / 8.0 + k * PI / 4.0) * corner))
	return points


func _draw_closed(points: PackedVector2Array, colour: Color, width: float) -> void:
	var loop: PackedVector2Array = points.duplicate()
	loop.append(points[0])
	draw_polyline(loop, colour, width)


func _to_screen(p: Vector2) -> Vector2:
	return _centre + p * _scale
