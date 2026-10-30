class_name DisplayFont
extends RefCounted
## The game's display font (D170, docs/02 §3.10): Barlow Condensed Bold (SIL Open Font License, ui/fonts/OFL.txt) for
## headings and big numbers off the fight screen, so they read at a glance. Body text stays in Godot's default font.
##
## Both fonts fall back to DejaVu Sans (ui/fonts/DejaVu-LICENSE.txt) for the symbols they lack (→ ← ↓ ▶ ◀ ✔ ✘ ─). A
## desktop borrows those from the system's fonts, but a browser build has none to borrow (D240, docs/04 §2.4).

const PATH := "res://ui/fonts/BarlowCondensed-Bold.ttf"
const SYMBOLS_PATH := "res://ui/fonts/DejaVuSans.ttf"

static var _font: Font


static func font() -> Font:
	if _font == null:
		_font = load(PATH) as Font
	return _font


## Sets a Label's or Button's font to the display font at this size.
static func apply(control: Control, font_size: int) -> void:
	control.add_theme_font_override("font", font())
	control.add_theme_font_size_override("font_size", font_size)


## Gives Godot's default font and the display font the symbols fallback (once; main.gd calls it at start).
static func add_symbols_fallback() -> void:
	var symbols: Font = load(SYMBOLS_PATH) as Font
	for f: Font in [ThemeDB.fallback_font, font()]:
		if not f.fallbacks.has(symbols):
			var list: Array[Font] = f.fallbacks.duplicate()
			list.append(symbols)
			f.fallbacks = list
