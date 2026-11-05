class_name TitleScreen
extends PanelContainer
## The title screen (docs/03 §10.2, D302), in the corner-board look of the screens off the cage (D170): over the
## placeholder painting of the coach in the corner (D470, docs/06 §6.18), or a real fight in the cage with PAINTED off
## (TitleBackdrop, docs/06 §6.14, D434), down a dark strip on the left: the impact emblem logo (D471), Lampsmoke Games
## under it (D242), then Continue (the career saved last, with who and when), New career,
## Load career, Quick fight (the fight setup and the Playtest fights, as they were) and Quit (not in the browser build,
## which can't close its own tab).

signal continue_pressed(slot: int)
signal new_career_pressed
signal load_pressed
signal quick_fight_pressed
signal quit_pressed

const BACKGROUND := Color(0.06, 0.07, 0.09)
const RED_CORNER := Color("#ff6b6b")
const TEXT := Color("#e9ecef")
const DIM := Color("#8a8f98")
const BUTTON_W: float = 380.0
## The dark strip down the left that the menu sits in (D434): its width, how dark it is, and the share of it that's
## solid before it fades out over the fight.
const STRIP_WIDTH: float = 900.0
const STRIP_ALPHA: float = 0.92
const STRIP_SOLID: float = 0.55
## The menu's left edge.
const MENU_LEFT: float = 110.0
## The placeholder title art (D470, D471): the painting of the coach in the corner behind the menu, in place of the
## fight in the cage. Off (false) brings the fight back (game/main.gd reads it).
const PAINTED: bool = true
const ART_PATH := "res://ui/art/title_art.png"
## The logo: the fist on the chin with CHIN CHECK under it, this tall and wide on a 1080-high screen.
const LOGO_PATH := "res://ui/art/title_logo.png"
const LOGO_SIZE: float = 420.0

## Where the career saves are (CareerSaves.DIR; tests use their own folder).
var save_dir: String = CareerSaves.DIR

var _continue: Button
var _continue_note: Label
var _quit: Button
var _buttons: Array[Button] = []
var _latest: int = -1


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# The cage shows through (D434): the menu sits in a dark strip down the left, fading out over the fight.
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	if PAINTED:
		var art := TextureRect.new()
		art.name = "Art"
		art.texture = load(ART_PATH) as Texture2D
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(art)
	var strip := TextureRect.new()
	strip.texture = strip_texture()
	strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	strip.stretch_mode = TextureRect.STRETCH_SCALE
	strip.anchor_bottom = 1.0
	strip.offset_right = STRIP_WIDTH
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(strip)
	var margin := MarginContainer.new()
	margin.anchor_bottom = 1.0
	margin.offset_right = STRIP_WIDTH
	margin.add_theme_constant_override("margin_left", int(MENU_LEFT))
	layer.add_child(margin)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var logo := TextureRect.new()
	logo.name = "Logo"
	logo.texture = load(LOGO_PATH) as Texture2D
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	logo.custom_minimum_size = Vector2(LOGO_SIZE, LOGO_SIZE)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(logo)
	var studio := FightNightCard._label(22, DIM)
	DisplayFont.apply(studio, 22)
	studio.text = "LAMPSMOKE GAMES"
	column.add_child(studio)
	var gap := Control.new()
	gap.custom_minimum_size.y = 36.0
	column.add_child(gap)

	_continue = _add_button(column, "Continue", func() -> void: continue_pressed.emit(_latest))
	CampPlanner.style_fight_button(_continue, 30)
	_continue_note = FightNightCard._label(16, DIM)
	column.add_child(_continue_note)
	_add_button(column, "New career", func() -> void: new_career_pressed.emit())
	_add_button(column, "Load career", func() -> void: load_pressed.emit())
	_add_button(column, "Quick fight", func() -> void: quick_fight_pressed.emit())
	var quick_note := FightNightCard._label(16, DIM)
	quick_note.text = "Any two fighters, and the Playtest fights"
	column.add_child(quick_note)
	_quit = _add_button(column, "Quit", func() -> void: quit_pressed.emit())
	_quit.visible = not OS.has_feature("web")


## The strip behind the menu: BACKGROUND, solid for the menu's width, then fading out to the right over the picture.
static func strip_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(BACKGROUND, STRIP_ALPHA))
	gradient.set_color(1, Color(BACKGROUND, 0.0))
	gradient.add_point(STRIP_SOLID, Color(BACKGROUND, STRIP_ALPHA))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 4
	return texture


## Reads the save slots again: Continue loads the career saved last, and is greyed out when there's none.
func refresh() -> void:
	_latest = CareerSaves.latest(save_dir)
	_continue.disabled = _latest < 0
	if _latest < 0:
		_continue_note.text = "No career saved yet"
		return
	var slot: Dictionary = CareerSaves.info(_latest, save_dir)
	_continue_note.text = "%s · age %d · %s" % [_who(slot), int(slot.get("age", 0)), String(slot.get("date", ""))]


## Where the keyboard starts: Continue when there's a career, New career when not.
func focus_first() -> void:
	FightHud.focus_later(_buttons[1] if _continue.disabled else _continue)


func can_continue() -> bool:
	return not _continue.disabled


## The buttons on show, top to bottom (for tests and the smoke run).
func button_labels() -> Array[String]:
	var out: Array[String] = []
	for b in _buttons:
		if b.visible:
			out.append(b.text)
	return out


## Presses the button with this text, as a click would.
func press(label: String) -> void:
	for b in _buttons:
		if b.text == label and b.visible and not b.disabled:
			b.pressed.emit()
			return


func text() -> String:
	return "%s\n%s" % ["\n".join(button_labels()), _continue_note.text]


## "Name 'Nickname'" for a slot's summary.
static func _who(slot: Dictionary) -> String:
	var nick: String = String(slot.get("nickname", ""))
	return String(slot.get("name", "")) + (" '%s'" % nick if nick != "" else "")


func _add_button(parent: Control, label: String, pressed: Callable) -> Button:
	var b: Button = CampPlanner._button(parent, label, pressed)
	b.custom_minimum_size = Vector2(BUTTON_W, 54.0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	DisplayFont.apply(b, 26)
	_buttons.append(b)
	return b
