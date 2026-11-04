class_name FightTheme
extends RefCounted
## The fight screen's theme (docs/06 §6.17, D460): the off-fight screens' buttons and pickers (OffCage, D435) in the
## display font, so the fight's dialogs (the bell, the round break's pickers, the menu, the towel) look like the rest.

static func create() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", Color("#dddcd3"))
	theme.set_color("default_color", "RichTextLabel", Color("#c4c9cc"))
	var off: Theme = OffCage.theme()
	for type: String in ["Button", "OptionButton"]:
		theme.set_font("font", type, DisplayFont.font())
		theme.set_font_size("font_size", type, 20)
		for state: String in OffCage.STATES:
			if off.has_stylebox(state, type):
				theme.set_stylebox(state, type, off.get_stylebox(state, type))
		theme.set_color("font_color", type, OffCage.TEXT)
		theme.set_color("font_hover_color", type, Color.WHITE)
		theme.set_color("font_pressed_color", type, Color.WHITE)
		theme.set_color("font_hover_pressed_color", type, Color.WHITE)
		theme.set_color("font_focus_color", type, OffCage.TEXT)
		theme.set_color("font_disabled_color", type, OffCage.TEXT_DISABLED)
	return theme
