extends GutTest
## DisplayFont: the display font, and the symbols fallback a browser build needs (D240, docs/04 §2.4).


func _draws(f: Font, c: int) -> bool:
	if f.has_char(c):
		return true
	for fallback: Font in f.fallbacks:
		if fallback.has_char(c):
			return true
	return false


## Every character past plain ASCII in the screens' scripts and the data files.
func _symbols_in_use() -> Dictionary:
	var found: Dictionary = {}
	for dir: String in ["res://game/", "res://ui/", "res://data/actions/", "res://data/calls/", "res://data/styles/"]:
		for file: String in DirAccess.get_files_at(dir):
			if file.ends_with(".gd") or file.ends_with(".json"):
				var text: String = FileAccess.get_file_as_string(dir + file)
				for i in text.length():
					var c: int = text.unicode_at(i)
					if c > 127:
						found[c] = dir + file
	return found


func test_every_symbol_the_screens_use_has_a_font_that_draws_it() -> void:
	DisplayFont.add_symbols_fallback()
	var symbols: Dictionary = _symbols_in_use()
	assert_true(symbols.has("→".unicode_at(0)), "the scan should find the feed's arrow")
	for c: int in symbols:
		assert_true(_draws(ThemeDB.fallback_font, c), "%s (in %s) has no font" % [String.chr(c), symbols[c]])


func test_the_display_font_gets_the_symbols_too() -> void:
	DisplayFont.add_symbols_fallback()
	assert_true(_draws(DisplayFont.font(), "▶".unicode_at(0)))


func test_adding_the_fallback_twice_adds_it_once() -> void:
	DisplayFont.add_symbols_fallback()
	DisplayFont.add_symbols_fallback()
	var symbols: Font = load(DisplayFont.SYMBOLS_PATH)
	assert_eq(ThemeDB.fallback_font.fallbacks.count(symbols), 1)
