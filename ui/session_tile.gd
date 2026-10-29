class_name SessionTile
extends Button
## One slot of the camp planner's week (D160, docs/02 §3.10): the session's name on a tile with a stripe in its
## kind's colour, and the fatigue the forecast says the fighter is at after it. Pressing it opens the planner's
## session list. A Play box sits above that line when the session's minigame can be played (D137).

## Each kind of training's colour (data/sessions `kind`): the tile's stripe, the session list and the legend.
const KIND_COLOURS := {
	"striking": Color("#ff6b6b"),
	"wrestling": Color("#4dabf7"),
	"grappling": Color("#f06595"),
	"sparring": Color("#ffa94d"),
	"conditioning": Color("#69db7c"),
	"mind": Color("#b197fc"),
	"recovery": Color("#63e6be"),
}
const KIND_NAMES := {
	"striking": "Striking", "wrestling": "Wrestling", "grappling": "Grappling", "sparring": "Sparring",
	"conditioning": "Conditioning", "mind": "Mind", "recovery": "Recovery",
}
const FILL := Color("#252a33")
const FILL_HOVER := Color("#2d333d")
const TEXT := Color("#e9ecef")
const DIM := Color("#8a8f98")
## A ticked Play box outlines the tile in this.
const PLAY := Color("#fcc419")
const STRIPE: float = 6.0
const PAD: float = 10.0
const NAME_SIZE: int = 17
const NOTE_SIZE: int = 14

var session_name: String = ""
var kind: String = ""
## What the line under the name says (the fatigue after it, or why it isn't on).
var note: String = ""
var play: CheckBox


func _init() -> void:
	custom_minimum_size = Vector2(0.0, 112.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_ALL
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	play = CheckBox.new()
	play.text = "Play"
	play.add_theme_font_size_override("font_size", 13)
	play.anchor_left = 1.0
	play.anchor_top = 1.0
	play.anchor_right = 1.0
	play.anchor_bottom = 1.0
	play.anchor_left = 0.0
	play.offset_left = STRIPE + 4.0
	play.offset_top = -56.0
	play.offset_right = -4.0
	play.offset_bottom = -30.0
	play.toggled.connect(func(_on: bool) -> void: queue_redraw())
	add_child(play)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


## Shows a session (data/sessions) and the line under it.
func show_session(session: Dictionary, note_text: String) -> void:
	session_name = String(session.get("name", ""))
	kind = String(session.get("kind", ""))
	note = note_text
	tooltip_text = "%s (%s): click to change it" % [session_name, KIND_NAMES.get(kind, "training")]
	queue_redraw()


static func kind_colour(kind_id: String) -> Color:
	return KIND_COLOURS.get(kind_id, DIM)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var hovered: bool = is_hovered() and not disabled
	var box := StyleBoxFlat.new()
	box.bg_color = FILL_HOVER if hovered else FILL
	box.set_corner_radius_all(6)
	if play.button_pressed and play.visible:
		box.set_border_width_all(2)
		box.border_color = PLAY
	elif has_focus():
		box.set_border_width_all(1)
		box.border_color = DIM
	draw_style_box(box, rect)
	var stripe := StyleBoxFlat.new()
	stripe.bg_color = kind_colour(kind)
	stripe.corner_radius_top_left = 6
	stripe.corner_radius_bottom_left = 6
	draw_style_box(stripe, Rect2(0.0, 0.0, STRIPE, size.y))
	var font: Font = get_theme_default_font()
	var alpha: float = 0.45 if disabled else 1.0
	var width: float = size.x - STRIPE - 2.0 * PAD
	draw_multiline_string(font, Vector2(STRIPE + PAD, PAD + font.get_ascent(NAME_SIZE)), session_name,
		HORIZONTAL_ALIGNMENT_LEFT, width, NAME_SIZE, 2, Color(TEXT, alpha))
	draw_string(font, Vector2(STRIPE + PAD, size.y - PAD), note, HORIZONTAL_ALIGNMENT_LEFT, width, NOTE_SIZE, Color(DIM, alpha))
