class_name NewCareerScreen
extends PanelContainer
## New career (docs/03 §10.2, D302): you, his head coach (your name, your background and your specialty: Coach, D311,
## §11.1), then the fighter's name, nickname, hometown (real cities,
## data/names; the country follows the city), stance and one of the 12 backgrounds (data/backgrounds, docs/02 §1.2).
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
var _list: ItemList
var _childhood: CheckBox
var _about: RichTextLabel
var _problem: Label
var _start: Button


func _init(p_names: NameLibrary = null, p_backgrounds: BackgroundLibrary = null) -> void:
	_names = p_names if p_names != null else NameLibrary.shared()
	_backgrounds = p_backgrounds if p_backgrounds != null else BackgroundLibrary.shared()
	_styles = StyleLibrary.shared()
	_towns = _names.hometowns()
	_background_ids = _backgrounds.ids()

	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override("panel", FightHud._panel_style(BACKGROUND))
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
	who_box.add_child(_stance)

	var bg_card := _card(Vector2(0.0, 0.0))
	bg_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(bg_card)
	var bg_box: VBoxContainer = bg_card.get_child(0)
	bg_box.add_child(_heading("Where he comes from"))
	_childhood = CheckBox.new()
	_childhood.text = "Play his childhood: three short scenes, at 8, 12 and 15, decide it"
	_childhood.button_pressed = true
	_childhood.add_theme_font_size_override("font_size", 18)
	_childhood.toggled.connect(func(_on: bool) -> void: _refresh())
	bg_box.add_child(_childhood)
	var bg_row := HBoxContainer.new()
	bg_row.add_theme_constant_override("separation", 18)
	bg_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bg_box.add_child(bg_row)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(300.0, 0.0)
	_list.add_theme_font_size_override("font_size", 18)
	for id: String in _background_ids:
		_list.add_item(String(_backgrounds.get_background(id).name))
	_list.item_selected.connect(func(_i: int) -> void: _refresh())
	bg_row.add_child(_list)
	_about = RichTextLabel.new()
	_about.bbcode_enabled = true
	_about.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_about.add_theme_font_size_override("normal_font_size", 18)
	_about.add_theme_color_override("default_color", TEXT)
	bg_row.add_child(_about)

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
	_list.select(0)
	_refresh()


## Fills every choice at random from this seed: a name from his hometown's country, a nickname, a background, a stance.
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
	_list.select(rng.randi_range(0, _background_ids.size() - 1))
	_stance.select(1 if rng.randf() < SOUTHPAW_CHANCE else 0)
	_coach_background.select(rng.randi_range(0, _coach_background_ids.size() - 1))
	_coach_specialty.select(rng.randi_range(0, _specialty_ids.size() - 1))
	_refresh()


## What the player picked, as Career.start() takes it.
func choices() -> Dictionary:
	var town: Dictionary = _towns[maxi(_hometown.selected, 0)]
	return {
		"coach": _coach.text.strip_edges(), "coach_background": coach_background_id(), "coach_specialty": coach_specialty_id(),
		"name": _name.text.strip_edges(), "nickname": _nickname.text.strip_edges(),
		"hometown": town.city, "country": town.country, "country_id": String(town.get("country_id", "")),
		"background": background_id(), "stance": String(STANCES[maxi(_stance.selected, 0)][1]),
		"play_childhood": play_childhood(),
	}


## Whether Start career plays his childhood first (the background comes from it, not the list).
func play_childhood() -> bool:
	return _childhood.button_pressed


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
	var picked: PackedInt32Array = _list.get_selected_items()
	return String(_background_ids[picked[0] if not picked.is_empty() else 0])


func pick_background(id: String) -> void:
	_list.select(maxi(_background_ids.find(id), 0))
	_refresh()


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
	_coach_about.text = "%s %s" % [Coach.background_about(coach_background_id()), Coach.specialty_does(coach_specialty_id())]
	_start.text = "Play his childhood" if play_childhood() else "Start career"
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE if play_childhood() else Control.MOUSE_FILTER_STOP
	_list.focus_mode = Control.FOCUS_NONE if play_childhood() else Control.FOCUS_ALL
	_list.modulate.a = 0.35 if play_childhood() else 1.0
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


func _field(parent: Control, label_text: String) -> LineEdit:
	_caption(parent, label_text)
	var edit := LineEdit.new()
	edit.max_length = NAME_LENGTH
	edit.add_theme_font_size_override("font_size", 20)
	parent.add_child(edit)
	return edit
