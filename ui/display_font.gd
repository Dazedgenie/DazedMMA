class_name DisplayFont
extends RefCounted
## The game's display font (D160, docs/02 §3.10): Barlow Condensed Bold (SIL Open Font License, ui/fonts/OFL.txt) for
## headings and big numbers off the fight screen, so they read at a glance. Body text stays in Godot's default font.

const PATH := "res://ui/fonts/BarlowCondensed-Bold.ttf"

static var _font: Font


static func font() -> Font:
	if _font == null:
		_font = load(PATH) as Font
	return _font


## Sets a Label's or Button's font to the display font at this size.
static func apply(control: Control, font_size: int) -> void:
	control.add_theme_font_override("font", font())
	control.add_theme_font_size_override("font_size", font_size)
