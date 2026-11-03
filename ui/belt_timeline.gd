class_name BeltTimeline
extends Control
## A belt's champions as a timeline (docs/06 §6.12, D432; Kyle's pick on the D432 cards): one row per reign, newest at
## the top, his name on the left and a bar across the years for how long he held it, in the promotion's colour (yours
## green), the current reign running on to today. The number of defences sits on the bar and how it ended after it.
## Clicking a row picks that man (man_picked).

signal man_picked(id: String)

const ROW_HEIGHT: float = 30.0
const NAME_WIDTH: float = 250.0
const AXIS_HEIGHT: float = 26.0
const BAR_HEIGHT: float = 18.0
## Room after a bar for how the reign ended ("lost it").
const END_ROOM: float = 90.0
## A reign shorter than this many pixels is drawn this wide, so a short one still shows.
const BAR_MIN: float = 6.0
const TEXT := Color("#e9ecef")
const DIM := Color("#8a8f98")
const GRID := Color(1.0, 1.0, 1.0, 0.06)
const YOU := Color("#69db7c")
const ROW_HOVER := Color(1.0, 1.0, 1.0, 0.05)

## [id, name, won week, lost week (-1 still holds it), defences, how it ended], newest first (History.line_of with names).
var reigns: Array = []
var colour: Color = Color("#d6a531")
var now_week: int = 0
## Week → year, from the career's calendar.
var year_of: Callable = func(week: int) -> int: return 2026 + int(floor(week / 52.0))
var _hover: int = -1
## [week, year] for each year marked along the top (worked out once in show_reigns).
var _ticks: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(func() -> void:
		_hover = -1
		queue_redraw())


## Shows these reigns (see `reigns`) up to this week.
func show_reigns(p_reigns: Array, p_colour: Color, p_now_week: int, p_year_of: Callable) -> void:
	reigns = p_reigns
	colour = p_colour
	now_week = p_now_week
	year_of = p_year_of
	custom_minimum_size.y = AXIS_HEIGHT + ROW_HEIGHT * maxi(reigns.size(), 1) + 6.0
	_ticks.clear()
	var s: Vector2i = span()
	var first_year: int = year_of.call(s.x)
	var step: int = maxi(1, int(ceil((int(year_of.call(s.y)) - first_year + 1) / 12.0)))
	var week: int = s.x + 1
	var year: int = first_year + 1  # Each new year as it starts (the axis's own start is part way through one).
	while week <= s.y:
		if int(year_of.call(week)) >= year:
			_ticks.append([week, int(year_of.call(week))])
			year = int(year_of.call(week)) + step
		week += 1
	queue_redraw()


## The first and last week the axis covers: the first reign's start to now, in whole years.
func span() -> Vector2i:
	var first: int = now_week
	for r: Array in reigns:
		first = mini(first, int(r[2]))
	return Vector2i(first, now_week)


## The x of a week on the axis.
func x_of(week: int) -> float:
	var s: Vector2i = span()
	var left: float = NAME_WIDTH
	var right: float = maxf(size.x - END_ROOM, left + 10.0)
	if s.y <= s.x:
		return left
	return left + (right - left) * float(week - s.x) / float(s.y - s.x)


## The bar of reign `i`: from when he won it to when it ended (or now).
func bar_of(i: int) -> Rect2:
	var r: Array = reigns[i]
	var x0: float = x_of(int(r[2]))
	var x1: float = x_of(now_week if int(r[3]) < 0 else int(r[3]))
	var y: float = AXIS_HEIGHT + ROW_HEIGHT * i + (ROW_HEIGHT - BAR_HEIGHT) * 0.5
	return Rect2(x0, y, maxf(x1 - x0, BAR_MIN), BAR_HEIGHT)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var at: int = _row_at(event.position.y)
		if at != _hover:
			_hover = at
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var at: int = _row_at(event.position.y)
		if at >= 0:
			man_picked.emit(String(reigns[at][0]))
			accept_event()


func _row_at(y: float) -> int:
	var at: int = int(floor((y - AXIS_HEIGHT) / ROW_HEIGHT))
	return at if y >= AXIS_HEIGHT and at >= 0 and at < reigns.size() else -1


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 16
	if reigns.is_empty():
		draw_string(font, Vector2(0.0, AXIS_HEIGHT + 20.0), "Nobody's held it yet.", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, DIM)
		return
	# The years along the top, a faint line down from each.
	for tick: Array in _ticks:
		var x: float = x_of(int(tick[0]))
		draw_line(Vector2(x, AXIS_HEIGHT - 4.0), Vector2(x, size.y), GRID, 1.0)
		draw_string(font, Vector2(x + 3.0, AXIS_HEIGHT - 8.0), str(tick[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, DIM)
	for i in reigns.size():
		var r: Array = reigns[i]
		var y: float = AXIS_HEIGHT + ROW_HEIGHT * i
		if i == _hover:
			draw_rect(Rect2(0.0, y, size.x, ROW_HEIGHT), ROW_HOVER)
		var mine: bool = String(r[0]) == Career.FIGHTER_ID
		var name_colour: Color = YOU if mine else TEXT
		draw_string(font, Vector2(4.0, y + ROW_HEIGHT * 0.5 + 6.0), String(r[1]), HORIZONTAL_ALIGNMENT_LEFT, NAME_WIDTH - 12.0, font_size, name_colour)
		var bar: Rect2 = bar_of(i)
		var fill: Color = YOU if mine else colour
		draw_rect(bar, fill if int(r[3]) >= 0 else fill.lightened(0.15))
		if int(r[3]) < 0:  # Still his: a bright cap on the end.
			draw_rect(Rect2(bar.end.x - 3.0, bar.position.y - 2.0, 3.0, bar.size.y + 4.0), Color.WHITE)
		var defences: int = int(r[4])
		if defences > 0:
			var label: String = "×%d" % defences
			var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			if bar.size.x > w + 8.0:
				draw_string(font, Vector2(bar.position.x + 4.0, bar.position.y + 14.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#0f1217"))
			else:
				draw_string(font, Vector2(bar.end.x + 4.0, bar.position.y + 14.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, fill)
		var how: String = String(r[5])
		if how != "":
			draw_string(font, Vector2(bar.end.x + (34.0 if defences > 0 and bar.size.x <= 40.0 else 6.0), bar.position.y + 14.0), how,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, DIM)

