class_name FightTheme
extends RefCounted
## Restrained broadcast treatment for the local-fight-night visual sample (docs/13).

static func create() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", Color("#dddcd3"))
	theme.set_color("default_color", "RichTextLabel", Color("#c4c9cc"))
	for type: String in ["Button", "OptionButton"]:
		theme.set_font("font", type, DisplayFont.font())
		theme.set_font_size("font_size", type, 20)
		theme.set_color("font_color", type, Color("#dddcd3"))
		theme.set_color("font_hover_color", type, Color("#ffffff"))
		theme.set_color("font_disabled_color", type, Color("#737c87"))
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("#202a35")
			style.border_color = Color("#3a4653")
			style.border_width_bottom = 2
			style.set_content_margin_all(9)
			style.content_margin_left = 14
			style.content_margin_right = 14
			style.set_corner_radius_all(2)
			if state == "hover":
				style.bg_color = Color("#344150")
				style.border_color = Color("#c1ad80")
			elif state == "pressed":
				style.bg_color = Color("#455362")
				style.border_color = Color("#e0be76")
			elif state == "disabled":
				style.bg_color = Color("#171e27")
			elif state == "focus":
				style.bg_color = Color.TRANSPARENT
				style.set_border_width_all(2)
				style.border_color = Color("#e0be76")
			theme.set_stylebox(state, type, style)
	return theme
