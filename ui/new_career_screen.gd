class_name NewCareerScreen
extends PanelContainer
## New career (docs/03 §10.2, D302): you, his head coach (your name, your background and your specialty: Coach, D311,
## §11.1), then the fighter's name, nickname, hometown (real cities,
## data/names; the country follows the city), stance, his look (D364: skin tone, hair colour, hair and beard; FighterLook)
## and one of the 12 backgrounds (data/backgrounds, docs/02 §1.2).
## One page (D434, docs/06 §6.14): you and him on the left, his full figure big in the middle under a spotlight with
## his name under him, and where he comes from on the right, the 12 backgrounds as tiles with a picture each.
## Roll fills it all at random; the screen opens rolled, so Start career works straight away. With *Play his
## childhood* ticked (the default, D312, §11.2) three short scenes pick the background instead of the list: Start
## career opens them (ChildhoodScreen); untick it to pick from the list and start straight away.

signal start_pressed(choices: Dictionary)
signal back_pressed

const BACKGROUND := Color(0.06, 0.07, 0.09)
const CARD := Color("#1b1f26")
const RED_CORNER := Color("#ff6b6b")
const TEXT := Color("#e9ecef")
const DIM := Color("#8a8f98")
const GOOD := Color("#69db7c")
const BAD := Color("#ff8787")
const STANCES: Array = [["Orthodox", "orthodox"], ["Southpaw", "southpaw"]]
## The chance Roll makes him a southpaw (about one fighter in five is).
const SOUTHPAW_CHANCE: float = 0.2
const NAME_LENGTH: int = 28
## The preview's frame (D430): an average 16-year-old's, until his background or childhood sets his own.
const PREVIEW_FRAME := { "height_cm": 175, "reach_cm": 177, "build": "average" }
## The middle of the page (D434): the stage he stands on, its width and colour, and the background tiles' grid.
const STAGE := Color("#12151a")
const STAGE_WIDTH: float = 400.0
const TILE_COLUMNS: int = 3
const TILE_SIZE := Vector2(0.0, 74.0)

## False when all the save slots are in use (main.gd sets it): Start career says to delete one first.
var slot_free: bool = true

var _names: NameLibrary
var _backgrounds: BackgroundLibrary
var _styles: StyleLibrary
var _towns: Array = []
var _background_ids: Array = []

var _coach: LineEdit
var _coach_background: OptionButton
var _coach_specialty: OptionButton
var _coach_about: Label
var _coach_background_ids: Array = []
var _specialty_ids: Array = []
var _name: LineEdit
var _nickname: LineEdit
var _hometown: OptionButton
var _stance: OptionButton
## His look (D364, Kyle: "You pick for your own fighter"): a swatch for each skin tone, and his hair colour, hair and beard.
var _skin: Array[Button] = []
var _skin_picked: int = 2
var _hair: OptionButton
var _hair_style: OptionButton
var _beard: OptionButton
## The 12 backgrounds as tiles (D434), and which is picked.
var _tiles: Array[Button] = []
var _tile_grid: GridContainer
var _picked_background: int = 0
var _plate_name: Label
var _plate_from: Label
var _childhood: CheckBox
## I know the game (D316): no tips, and every call open from his first fight.
var _know_the_game: CheckBox
var _about: RichTextLabel
var _problem: Label
var _start: Button
## Him as picked (D430): his look and stance, in 3D, beside where he comes from.
var preview: FighterPortrait


func _init(p_names: NameLibrary = null, p_backgrounds: BackgroundLibrary = null) -> void:
	_names = p_names if p_names != null else NameLibrary.shared()
	_backgrounds = p_backgrounds if p_backgrounds != null else BackgroundLibrary.shared()
	_styles = StyleLibrary.shared()
	_towns = _names.hometowns()
	_background_ids = _backgrounds.ids()

	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override("panel", OffCage.hall_panel())  # The dimmed hall shows through (D435).
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	add_child(column)
	var title := Label.new()
	title.text = "NEW CAREER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	DisplayFont.apply(title, 64)
	title.add_theme_color_override("font_color", RED_CORNER)
	column.add_child(title)
	var subtitle := FightNightCard._label(18, DIM)
	subtitle.text = "He's %d, it's January %d, and you're his coach." % [BackgroundLibrary.START_AGE, Career.START_DATE[0]]
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)

	var who := _card(Vector2(460.0, 0.0))
	body.add_child(who)
	var who_box: VBoxContainer = who.get_child(0)
	who_box.add_child(_heading("You"))
	_coach = _field(who_box, "Your name (his coach)")
	_caption(who_box, "Before him, you were a")
	_coach_background = OptionButton.new()
	_coach_background_ids = Coach.backgrounds().keys()
	for id: String in _coach_background_ids:
		_coach_background.add_item(Coach.background_name(id))
	_coach_background.item_selected.connect(func(_i: int) -> void: _refresh())
	who_box.add_child(_coach_background)
	_caption(who_box, "Your specialty")
	_coach_specialty = OptionButton.new()
	_specialty_ids = Coach.specialty_ids()
	for id: String in _specialty_ids:
		_coach_specialty.add_item(Coach.specialty_name(id))
	_coach_specialty.item_selected.connect(func(_i: int) -> void: _refresh())
	who_box.add_child(_coach_specialty)
	_coach_about = FightNightCard._label(15, DIM)
	_coach_about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_coach_about.custom_minimum_size.x = 400.0
	who_box.add_child(_coach_about)
	_know_the_game = CheckBox.new()
	_know_the_game.text = "I know the game: skip the tips and open every call from his first fight"
	_know_the_game.add_theme_font_size_override("font_size", 16)
	who_box.add_child(_know_the_game)
	who_box.add_child(_heading("Your fighter"))
	_name = _field(who_box, "His name")
	_nickname = _field(who_box, "Nickname (can be blank)")
	_caption(who_box, "Hometown")
	_hometown = OptionButton.new()
	for town: Dictionary in _towns:
		_hometown.add_item("%s, %s" % [town.city, town.country])
	_hometown.fit_to_longest_item = false
	who_box.add_child(_hometown)
	_caption(who_box, "Stance")
	_stance = OptionButton.new()
	for entry: Array in STANCES:
		_stance.add_item(entry[0])
	_stance.item_selected.connect(func(_i: int) -> void: _refresh())
	who_box.add_child(_stance)
	_caption(who_box, "His look")
	var skins := HBoxContainer.new()
	skins.add_theme_constant_override("separation", 6)
	who_box.add_child(skins)
	for tone in FighterLook.SKIN_TONES.size():
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(34.0, 30.0)
		swatch.toggle_mode = true
		swatch.tooltip_text = "Skin tone %d of %d" % [tone + 1, FighterLook.SKIN_TONES.size()]
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			var box := StyleBoxFlat.new()
			box.bg_color = Color(FighterLook.SKIN_TONES[tone])
			box.set_corner_radius_all(4)
			if state.contains("pressed") or state == "focus":
				box.border_color = TEXT if state.contains("pressed") else DIM
				box.set_border_width_all(3)
				box.draw_center = true
			swatch.add_theme_stylebox_override(state, box)
		swatch.pressed.connect(func() -> void: pick_skin(tone))
		skins.add_child(swatch)
		_skin.append(swatch)
	var hair_row := HBoxContainer.new()
	hair_row.add_theme_constant_override("separation", 8)
	who_box.add_child(hair_row)
	_hair = _look_option(hair_row, FighterLook.HAIR_COLOURS.keys())
	_hair_style = _look_option(hair_row, FighterLook.HAIR_STYLES.keys())
	_beard = _look_option(hair_row, FighterLook.BEARDS.keys())

	# Him in the middle (D434, Kyle's card "One page, him big in the middle"): his full figure under a spotlight,
	# changing as his look is picked, and his name under him.
	var stage := PanelContainer.new()
	stage.custom_minimum_size = Vector2(STAGE_WIDTH, 0.0)
	var stage_style: StyleBoxFlat = FightHud._panel_style(STAGE)
	stage_style.set_content_margin_all(0)
	stage.add_theme_stylebox_override("panel", stage_style)
	body.add_child(stage)
	var spot := TextureRect.new()
	spot.texture = spotlight_texture()
	spot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spot.stretch_mode = TextureRect.STRETCH_SCALE
	spot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(spot)
	var stage_box := VBoxContainer.new()
	stage_box.add_theme_constant_override("separation", 2)
	stage.add_child(stage_box)
	preview = FighterPortrait.new(FighterPortrait.FULL, 0, -20.0)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.tooltip_text = "Him as you've picked him: his skin, hair and beard, in his stance"
	stage_box.add_child(preview)
	_plate_name = Label.new()
	DisplayFont.apply(_plate_name, 40)
	_plate_name.add_theme_color_override("font_color", TEXT)
	_plate_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plate_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stage_box.add_child(_plate_name)
	_plate_from = FightNightCard._label(16, DIM)
	_plate_from.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_box.add_child(_plate_from)
	var plate_gap := Control.new()
	plate_gap.custom_minimum_size.y = 14.0
	stage_box.add_child(plate_gap)

	var bg_card := _card(Vector2(0.0, 0.0))
	bg_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(bg_card)
	var bg_box: VBoxContainer = bg_card.get_child(0)
	bg_box.add_child(_heading("Where he comes from"))
	_childhood = CheckBox.new()
	_childhood.text = "Play his childhood: three short scenes, at 8, 12 and 15, decide it"
	_childhood.button_pressed = true
	_childhood.add_theme_font_size_override("font_size", 17)
	_childhood.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_childhood.toggled.connect(func(_on: bool) -> void: _refresh())
	bg_box.add_child(_childhood)
	# The 12 backgrounds as tiles with a picture each (D434, Kyle's card "Tiles with an icon each").
	_tile_grid = GridContainer.new()
	_tile_grid.columns = TILE_COLUMNS
	_tile_grid.add_theme_constant_override("h_separation", 8)
	_tile_grid.add_theme_constant_override("v_separation", 8)
	bg_box.add_child(_tile_grid)
	var group := ButtonGroup.new()
	for i in _background_ids.size():
		var id: String = _background_ids[i]
		_tiles.append(_background_tile(id, String(_backgrounds.get_background(id).name), group, i))
	_about = RichTextLabel.new()
	_about.bbcode_enabled = true
	_about.fit_content = false
	_about.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_about.add_theme_font_size_override("normal_font_size", 17)
	_about.add_theme_color_override("default_color", TEXT)
	bg_box.add_child(_about)

	_problem = FightNightCard._label(17, BAD)
	_problem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_problem)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	var back: Button = CampPlanner._button(buttons, "Back", func() -> void: back_pressed.emit())
	back.custom_minimum_size.x = 200.0
	var dice: Button = CampPlanner._button(buttons, "Roll everything", func() -> void: roll(randi()))
	dice.custom_minimum_size.x = 240.0
	_start = CampPlanner._button(buttons, "Start career", press_start)
	_start.custom_minimum_size = Vector2(280.0, 64.0)
	CampPlanner.style_fight_button(_start, 34)
	for edit: LineEdit in [_coach, _name, _nickname]:
		edit.text_changed.connect(func(_t: String) -> void: _refresh())
	_hometown.item_selected.connect(func(_i: int) -> void: _refresh())
	_pick_tile(0)
	_refresh()


## Fills every choice at random from this seed: a name from his hometown's country, a nickname, a background, a stance
## and a look like where he's from (D364).
func roll(roll_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = roll_seed
	var person: Dictionary = _names.roll(rng)
	_name.text = person.name
	_nickname.text = person.nickname
	for i in _towns.size():
		if _towns[i].city == person.hometown and _towns[i].country_id == person.country_id:
			_hometown.select(i)
	_coach.text = _names.random_name(rng)
	_pick_tile(rng.randi_range(0, _background_ids.size() - 1))
	_stance.select(1 if rng.randf() < SOUTHPAW_CHANCE else 0)
	_coach_background.select(rng.randi_range(0, _coach_background_ids.size() - 1))
	_coach_specialty.select(rng.randi_range(0, _specialty_ids.size() - 1))
	set_look(FighterLook.roll(rng.randi(), String(person.country_id), {}, _names))  # Looks like where he's from.
	_refresh()


## What the player picked, as Career.start() takes it.
func choices() -> Dictionary:
	var town: Dictionary = _towns[maxi(_hometown.selected, 0)]
	return {
		"coach": _coach.text.strip_edges(), "coach_background": coach_background_id(), "coach_specialty": coach_specialty_id(),
		"name": _name.text.strip_edges(), "nickname": _nickname.text.strip_edges(),
		"hometown": town.city, "country": town.country, "country_id": String(town.get("country_id", "")),
		"background": background_id(), "stance": String(STANCES[maxi(_stance.selected, 0)][1]),
		"play_childhood": play_childhood(), "tutorial": not _know_the_game.button_pressed,
		"look": look(),
	}


## His look as picked (FighterLook).
func look() -> Dictionary:
	return {
		"skin": _skin_picked, "hair": String(FighterLook.HAIR_COLOURS.keys()[maxi(_hair.selected, 0)]),
		"hair_style": String(FighterLook.HAIR_STYLES.keys()[maxi(_hair_style.selected, 0)]),
		"beard": String(FighterLook.BEARDS.keys()[maxi(_beard.selected, 0)]),
	}


## Shows `look_in` as picked (Roll, and tests).
func set_look(look_in: Dictionary) -> void:
	pick_skin(int(look_in.get("skin", 2)))
	_hair.select(maxi(FighterLook.HAIR_COLOURS.keys().find(String(look_in.get("hair", ""))), 0))
	_hair_style.select(maxi(FighterLook.HAIR_STYLES.keys().find(String(look_in.get("hair_style", ""))), 0))
	_beard.select(maxi(FighterLook.BEARDS.keys().find(String(look_in.get("beard", ""))), 0))


func pick_skin(tone: int) -> void:
	_skin_picked = clampi(tone, 0, FighterLook.SKIN_TONES.size() - 1)
	for i in _skin.size():
		_skin[i].set_pressed_no_signal(i == _skin_picked)
	_show_preview()


## The preview of him (D430): his look and stance as picked, at an average 16-year-old's frame (his height comes from his
## background or childhood once the career starts).
func preview_profile() -> Dictionary:
	return { "id": "new_career_preview", "name": _name.text.strip_edges() if _name != null else "",
		"stance": String(STANCES[maxi(_stance.selected, 0)][1]) if _stance != null else "orthodox",
		"look": look(), "frame": PREVIEW_FRAME.duplicate() }


func _show_preview() -> void:
	if preview != null and _hair != null and _hair_style != null and _beard != null:
		preview.show_fighter(preview_profile())


## Whether Start career plays his childhood first (the background comes from it, not the list).
func play_childhood() -> bool:
	return _childhood.button_pressed


## For tests and quick starts: ticks or unticks I know the game.
func set_know_the_game(on: bool) -> void:
	_know_the_game.button_pressed = on


func set_play_childhood(on: bool) -> void:
	_childhood.button_pressed = on
	_refresh()


func coach_background_id() -> String:
	return String(_coach_background_ids[maxi(_coach_background.selected, 0)]) if not _coach_background_ids.is_empty() else ""


func coach_specialty_id() -> String:
	return String(_specialty_ids[maxi(_coach_specialty.selected, 0)])


func pick_coach(background: String, specialty: String) -> void:
	_coach_background.select(maxi(_coach_background_ids.find(background), 0))
	_coach_specialty.select(maxi(_specialty_ids.find(specialty), 0))
	_refresh()


func background_id() -> String:
	return String(_background_ids[clampi(_picked_background, 0, _background_ids.size() - 1)])


func pick_background(id: String) -> void:
	_pick_tile(maxi(_background_ids.find(id), 0))
	_refresh()


## The background tiles, for tests: one per background, in the list's order.
func tiles() -> Array[Button]:
	return _tiles


func _pick_tile(i: int) -> void:
	_picked_background = i
	for t in _tiles.size():
		_tiles[t].set_pressed_no_signal(t == i)


## Why Start career can't go yet ("" when it can).
func problem() -> String:
	if _coach.text.strip_edges() == "":
		return "Give yourself a name: you're his coach."
	if _name.text.strip_edges() == "":
		return "Give your fighter a name."
	if not slot_free:
		return "All %d save slots are in use: delete one on Load career first." % CareerSaves.SLOTS
	return ""


func press_start() -> void:
	if problem() == "":
		start_pressed.emit(choices())


func focus_start() -> void:
	FightHud.focus_later(_start)


func text() -> String:
	return "%s\n%s\n%s\n%s" % [JSON.stringify(choices()), _coach_about.text, _about.get_parsed_text(), _problem.text]


## Sets a field by name, as typing would (for tests): coach, name or nickname.
func set_field(field: String, value: String) -> void:
	var edit: LineEdit = { "coach": _coach, "name": _name, "nickname": _nickname }[field]
	edit.text = value
	_refresh()


func _refresh() -> void:
	_show_preview()
	_coach_about.text = "%s %s" % [Coach.background_about(coach_background_id()), Coach.specialty_does(coach_specialty_id())]
	_start.text = "Play his childhood" if play_childhood() else "Start career"
	for tile in _tiles:
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE if play_childhood() else Control.MOUSE_FILTER_STOP
		tile.focus_mode = Control.FOCUS_NONE if play_childhood() else Control.FOCUS_ALL
	_tile_grid.modulate.a = 0.35 if play_childhood() else 1.0
	_show_plate()
	if play_childhood():
		_about.text = "\n".join([
			"[font_size=30][b]His childhood decides[/b][/font_size]",
			"Three short scenes, at about 8, 12 and 15. In each you pick what he did. What he chose makes him: the background his choices add up to (one of these 12), a bit of the runner-up, a few stats, his height, the people in his life and the money he's saved.",
			"",
			"[color=%s]Untick it to pick his background from the list instead.[/color]" % DIM.to_html(false),
		])
		_problem.text = problem()
		_start.disabled = _problem.text != ""
		return
	var bg: Dictionary = _backgrounds.get_background(background_id())
	var lines: Array[String] = []
	lines.append("[font_size=30][b]%s[/b][/font_size]" % bg.name)
	lines.append(String(bg.about))
	lines.append("")
	lines.append("[color=%s]Strong:[/color] %s" % [GOOD.to_html(false), _stat_list(bg.strengths)])
	lines.append("[color=%s]Weak:[/color] %s" % [BAD.to_html(false), _stat_list(bg.weaknesses)])
	for id: String in _styles.ids():
		if String(_styles.get_style(id).fighter) == String(bg.fighter):
			lines.append("[color=%s]Fights like:[/color] a %s" % [DIM.to_html(false), String(_styles.get_style(id).name).to_lower()])
			break
	lines.append("[color=%s]Starts with:[/color] $%d saved" % [DIM.to_html(false), int(bg.get("money", 0))])
	lines.append("")
	lines.append("[i]%s[/i]" % bg.hook)
	lines.append("")
	lines.append("[color=%s]His stats start low (he's %d) and his potential is hidden: the gym's scouts will give you a range.[/color]" % [DIM.to_html(false), BackgroundLibrary.START_AGE])
	_about.text = "\n".join(lines)
	_problem.text = problem()
	_start.disabled = _problem.text != ""


static func _stat_list(ids: Array) -> String:
	var out: Array[String] = []
	for id: String in ids:
		out.append(String(TrainingCamp.STAT_NAMES.get(id, id)))
	return ", ".join(out)


func _card(min_size: Vector2) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = min_size
	var style: StyleBoxFlat = FightHud._panel_style(CARD)
	style.set_content_margin_all(22)
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	return card


func _heading(text_in: String) -> Label:
	var label := FightNightCard._label(20, DIM)
	DisplayFont.apply(label, 20)
	label.text = text_in.to_upper()
	return label


func _caption(parent: Control, label_text: String) -> void:
	var label := FightNightCard._label(16, DIM)
	label.text = label_text
	parent.add_child(label)


## A drop-down of a look's choices ("dark_brown" shows as "Dark brown").
func _look_option(parent: Control, ids: Array) -> OptionButton:
	var option := OptionButton.new()
	for id: Variant in ids:
		option.add_item(String(id).replace("_", " ").capitalize())
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.item_selected.connect(func(_i: int) -> void: _show_preview())
	parent.add_child(option)
	return option


func _field(parent: Control, label_text: String) -> LineEdit:
	_caption(parent, label_text)
	var edit := LineEdit.new()
	edit.max_length = NAME_LENGTH
	edit.add_theme_font_size_override("font_size", 20)
	parent.add_child(edit)
	return edit


## His name under him on the stage, and where he's from.
func _show_plate() -> void:
	var nick: String = _nickname.text.strip_edges()
	var name_text: String = _name.text.strip_edges()
	_plate_name.text = (name_text if nick == "" else "%s '%s'" % [name_text, nick]).to_upper()
	var town: Dictionary = _towns[maxi(_hometown.selected, 0)] if not _towns.is_empty() else {}
	_plate_from.text = "%s · %s, %s · age %d" % [String(STANCES[maxi(_stance.selected, 0)][0]), String(town.get("city", "")),
		String(town.get("country", "")), BackgroundLibrary.START_AGE]


## The stage's spotlight: a soft pool of light from above, fading out to the sides.
static func spotlight_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.95, 0.85, 0.16))
	gradient.set_color(1, Color(1.0, 0.95, 0.85, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.62)
	texture.fill_to = Vector2(1.0, 0.62)
	texture.width = 128
	texture.height = 128
	return texture


## One background's tile: its picture and its name, lit when picked.
func _background_tile(id: String, label_text: String, group: ButtonGroup, i: int) -> Button:
	var tile := Button.new()
	tile.toggle_mode = true
	tile.button_group = group
	tile.custom_minimum_size = TILE_SIZE
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.tooltip_text = label_text
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var box: StyleBoxFlat = FightHud._panel_style(Color("#232831") if state.begins_with("hover") or state == "pressed" else Color("#1f232b"))
		box.set_content_margin_all(6)
		if state.contains("pressed"):
			box.border_color = BackgroundIcon.colour_of(id)
			box.set_border_width_all(2)
		elif state == "focus":
			box.draw_center = false
			box.border_color = DIM
			box.set_border_width_all(1)
		tile.add_theme_stylebox_override(state, box)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8.0
	row.offset_right = -6.0
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(row)
	var icon := BackgroundIcon.new(id)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var label := FightNightCard._label(15, TEXT)
	label.text = label_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	tile.pressed.connect(func() -> void:
		_picked_background = i
		_refresh())
	_tile_grid.add_child(tile)
	return tile
