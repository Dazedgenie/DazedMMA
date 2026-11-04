class_name OffCage
extends RefCounted
## One look for the screens off the fight (docs/06 §6.15, D435; Kyle's picks on the four D435 cards): the dimmed hall
## behind every one of them (the empty cage, lights low, the camera drifting slowly round: ArenaView.hall_drift) seen
## through the screens' see-through backing (HALL), one button style (dark, edged in red-corner red on hover and under
## the keyboard, the display font on short labels; the main action stays solid red, CampPlanner.style_fight_button) and a
## quick fade up from the dark when one screen changes to the next (the veil in game/main.gd).

## The screens' backing: the hall shows through it, dark enough to read over.
const HALL := Color(0.06, 0.07, 0.09, 0.8)
## A page laid over another screen (the world pages over the hub, the fight night card over the camp) is solid, so the
## screen under it does not read through.
const OVER := Color(0.06, 0.07, 0.09, 1.0)
## Buttons: the face, hover and pressed colours, the edge on hover and focus, the text.
const BUTTON := Color("#22262e")
const BUTTON_HOVER := Color("#2a2f38")
const BUTTON_PRESSED := Color("#1a1d23")
const EDGE := Color("#ff6b6b")
const TEXT := Color("#e9ecef")
const TEXT_DISABLED := Color("#5c636e")
## A label this long or shorter is set in the display font (longer ones, the childhood's choices, stay readable).
const DISPLAY_UP_TO: int = 24
const DISPLAY_SIZE: int = 22
## How long the new screen takes to come up out of the dark (seconds).
const FADE_SECONDS: float = 0.2


## The see-through backing for a full-screen page.
static func hall_panel(over: bool = false) -> StyleBoxFlat:
	return FightHud._panel_style(OVER if over else HALL)


## The button states a Button carries, each with its own box.
const STATES: Array[String] = ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]
## A toggle that's down (a tab, a filter, a picked tile) is lit a shade and underlined in red.
const BUTTON_ON := Color("#323844")
const ON_LINE: int = 3

static var _theme: Theme


## The box for one button state. `toggle` is the look of a tab: down means picked, so it's lit, not pressed in.
static func button_box(state: String, toggle: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = {"hover": BUTTON_HOVER, "pressed": BUTTON_PRESSED, "hover_pressed": BUTTON_PRESSED}.get(state, BUTTON)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(8)
	box.content_margin_left = 14
	box.content_margin_right = 14
	if toggle and state.contains("pressed"):
		box.bg_color = BUTTON_ON
		box.border_color = EDGE
		box.border_width_bottom = ON_LINE
		if state == "hover_pressed":
			box.set_border_width_all(2)
			box.border_width_bottom = ON_LINE
	elif state in ["hover", "hover_pressed"]:
		box.border_color = EDGE
		box.set_border_width_all(2)
	elif state == "focus":
		box.draw_center = false
		box.border_color = EDGE
		box.set_border_width_all(2)
	elif state == "disabled":
		box.bg_color = Color(BUTTON, 0.55)
	return box


## Gives `b` the off-fight button look.
static func style_button(b: Button) -> void:
	for state: String in STATES:
		b.add_theme_stylebox_override(state, button_box(state))
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", TEXT)
	b.add_theme_color_override("font_pressed_color", TEXT)
	b.add_theme_color_override("font_disabled_color", TEXT_DISABLED)
	if b.text.length() <= DISPLAY_UP_TO and b.text != "":
		DisplayFont.apply(b, DISPLAY_SIZE)


## The theme every off-fight screen carries (game/main.gd), so a button no screen styled itself (the hub's and the
## world pages' tabs, the pickers) has the same look: tabs and other toggles lit and underlined when down. Tick boxes
## keep their own look.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	for state: String in STATES:
		_theme.set_stylebox(state, "Button", button_box(state, true))
	for item: Array in [["font_color", TEXT], ["font_hover_color", Color.WHITE], ["font_focus_color", TEXT],
			["font_pressed_color", Color.WHITE], ["font_hover_pressed_color", Color.WHITE], ["font_disabled_color", TEXT_DISABLED]]:
		_theme.set_color(String(item[0]), "Button", item[1])
	for state: String in STATES:
		var picker: StyleBoxFlat = button_box(state)  # A picker's box stays as low as before, so the pages still fit.
		picker.content_margin_top = 4
		picker.content_margin_bottom = 4
		picker.content_margin_left = 10
		_theme.set_stylebox(state, "OptionButton", picker)
	var plain: Theme = ThemeDB.get_default_theme()
	for kind: String in ["CheckBox", "CheckButton"]:
		for state: String in STATES:
			if plain.has_stylebox(state, kind):
				_theme.set_stylebox(state, kind, plain.get_stylebox(state, kind))
	return _theme
