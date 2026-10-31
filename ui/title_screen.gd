class_name TitleScreen
extends PanelContainer
## The title screen (docs/03 §10.2, D302), in the corner-board look of the screens off the cage (D170): CHIN CHECK in the
## display font, Lampsmoke Games under it (D242), then Continue (the career saved last, with who and when), New career,
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

## Where the career saves are (CareerSaves.DIR; tests use their own folder).
var save_dir: String = CareerSaves.DIR

var _continue: Button
var _continue_note: Label
var _quit: Button
var _buttons: Array[Button] = []
var _latest: int = -1


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override("panel", FightHud._panel_style(BACKGROUND))
	var centre := CenterContainer.new()
	add_child(centre)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	centre.add_child(column)

	var title := Label.new()
	title.text = "CHIN CHECK"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	DisplayFont.apply(title, 132)
	title.add_theme_color_override("font_color", RED_CORNER)
	column.add_child(title)
	var studio := FightNightCard._label(22, DIM)
	DisplayFont.apply(studio, 22)
	studio.text = "LAMPSMOKE GAMES"
	studio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(studio)
	var gap := Control.new()
	gap.custom_minimum_size.y = 36.0
	column.add_child(gap)

	_continue = _add_button(column, "Continue", func() -> void: continue_pressed.emit(_latest))
	CampPlanner.style_fight_button(_continue, 30)
	_continue_note = FightNightCard._label(16, DIM)
	_continue_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_continue_note)
	_add_button(column, "New career", func() -> void: new_career_pressed.emit())
	_add_button(column, "Load career", func() -> void: load_pressed.emit())
	_add_button(column, "Quick fight", func() -> void: quick_fight_pressed.emit())
	var quick_note := FightNightCard._label(16, DIM)
	quick_note.text = "Any two fighters, and the Playtest fights"
	quick_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(quick_note)
	_quit = _add_button(column, "Quit", func() -> void: quit_pressed.emit())
	_quit.visible = not OS.has_feature("web")


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
	DisplayFont.apply(b, 26)
	_buttons.append(b)
	return b
