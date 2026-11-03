class_name ChildhoodScreen
extends PanelContainer
## His childhood (docs/03 §11.2, D312): three scenes, at about 8, 12 and 15 (Childhood.draw), one at a time on a
## corner-board card, with him at that age beside it (docs/06 §6.14, D434). Pick one of three choices, read what came of it, then Next. After the third, *Who he became*: the
## background his choices add up to, the flavour of the runner-up, the people they brought in and his starting money,
## and Start career.

signal finished(picks: Array)
signal back_pressed

const BACKGROUND := Color(0.06, 0.07, 0.09)
const CARD := Color("#1b1f26")
const RED_CORNER := Color("#ff6b6b")
const TEXT := Color("#e9ecef")
const DIM := Color("#8a8f98")
const GOOD := Color("#69db7c")

## Him at each scene's age (D434): his height, reach and build (lean) then, and no beard before 15. Past the last
## age, he's drawn as Who he became makes him.
const AGE_FRAMES := {
	8: { "height_cm": 128, "reach_cm": 126, "build": "lean" },
	12: { "height_cm": 151, "reach_cm": 150, "build": "lean" },
	15: { "height_cm": 170, "reach_cm": 171, "build": "lean" },
}
const PORTRAIT_SIZE := Vector2(340.0, 620.0)

## What he chose so far: [{scene, choice}], oldest first.
var picks: Array = []

var _childhood: Childhood
var _backgrounds: BackgroundLibrary
var _roster: FighterLibrary
var _scenes: Array = []
var _choices: Dictionary = {}
var _seed: int = 0
var _index: int = 0

var _age: Label
var _title: Label
var _body: Label
var _buttons: VBoxContainer
var _outcome: Label
var _next: Button
var _start: Button
## Him at the age of the scene showing (D434).
var portrait: FighterPortrait


func _init(p_childhood: Childhood = null, p_backgrounds: BackgroundLibrary = null) -> void:
	_childhood = p_childhood if p_childhood != null else Childhood.shared()
	_backgrounds = p_backgrounds if p_backgrounds != null else BackgroundLibrary.shared()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override("panel", FightHud._panel_style(BACKGROUND))
	var center := CenterContainer.new()
	add_child(center)
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 24)
	center.add_child(pair)
	# Him at that age beside the card (D434, Kyle's card "Him at that age"): shorter and slighter at 8 and 12, nearly
	# grown at 15, and as he'll start at 16 on Who he became.
	portrait = FighterPortrait.new(FighterPortrait.FULL, 0, -20.0)
	portrait.custom_minimum_size = PORTRAIT_SIZE
	pair.add_child(portrait)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(900.0, 560.0)
	var style: StyleBoxFlat = FightHud._panel_style(CARD)
	style.set_content_margin_all(32)
	style.border_width_top = 6
	style.border_color = RED_CORNER
	card.add_theme_stylebox_override("panel", style)
	pair.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	card.add_child(box)
	_age = Label.new()
	DisplayFont.apply(_age, 28)
	_age.add_theme_color_override("font_color", RED_CORNER)
	box.add_child(_age)
	_title = Label.new()
	DisplayFont.apply(_title, 48)
	_title.add_theme_color_override("font_color", TEXT)
	box.add_child(_title)
	_body = _wrapped(20, TEXT)
	box.add_child(_body)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 10)
	box.add_child(_buttons)
	_outcome = _wrapped(20, GOOD)
	box.add_child(_outcome)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var back: Button = CampPlanner._button(row, "Back", func() -> void: back_pressed.emit())
	back.custom_minimum_size.x = 180.0
	_next = CampPlanner._button(row, "Next", press_next)
	_next.custom_minimum_size.x = 260.0
	_start = CampPlanner._button(row, "Start career", press_start)
	_start.custom_minimum_size = Vector2(280.0, 60.0)
	CampPlanner.style_fight_button(_start, 32)


## A new childhood: the scenes this career's seed draws, for the fighter on the new-career screen (`choices`).
## `roster`: the fighters a background builds on (loaded when not given).
func begin(career_seed: int, p_choices: Dictionary, roster: FighterLibrary = null) -> void:
	if roster != null:
		_roster = roster
	_seed = career_seed
	_choices = p_choices
	_scenes = _childhood.draw(career_seed)
	picks = []
	_index = 0
	_show_scene()


func scene_ids() -> Array:
	return _scenes.duplicate()


func on_summary() -> bool:
	return _index >= _scenes.size()


## Picks choice `n` (0–2) of the scene showing.
func press_choice(n: int) -> void:
	if on_summary() or picks.size() > _index:
		return
	var sc: Dictionary = _childhood.scene(String(_scenes[_index]))
	var ch: Dictionary = sc.choices[n]
	picks.append({ "scene": String(sc.id), "choice": String(ch.id) })
	for b: Control in _choice_buttons():
		b.visible = false
	_outcome.text = String(ch.get("outcome", ""))
	_outcome.visible = true
	_next.text = "See who he became" if _index == _scenes.size() - 1 else "Next"
	_next.visible = true
	FightHud.focus_later(_next)


func press_next() -> void:
	if picks.size() <= _index:
		return
	_index += 1
	if on_summary():
		_show_summary()
	else:
		_show_scene()


func press_start() -> void:
	if on_summary():
		finished.emit(picks.duplicate(true))


func text() -> String:
	var lines: Array[String] = [_age.text, _title.text, _body.text]
	for b: Button in _choice_buttons():
		if b.visible:
			lines.append(b.text)
	if _outcome.visible:
		lines.append(_outcome.text)
	return "\n".join(lines)


func _show_scene() -> void:
	var sc: Dictionary = _childhood.scene(String(_scenes[_index]))
	_age.text = "AGE %d · %d OF %d" % [int(sc.age), _index + 1, _scenes.size()]
	_title.text = String(sc.title)
	_body.text = String(sc.text)
	for b: Button in _choice_buttons():
		_buttons.remove_child(b)
		b.queue_free()
	var choices: Array = sc.choices
	for n in choices.size():
		var b: Button = CampPlanner._button(_buttons, String(choices[n].text), press_choice.bind(n))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 52.0
	_outcome.visible = false
	_next.visible = false
	_start.visible = false
	portrait.show_fighter(at_age(int(sc.age)))
	if not _choice_buttons().is_empty():
		FightHud.focus_later(_choice_buttons()[0])


func _show_summary() -> void:
	var t: Dictionary = _childhood.tally(picks)
	var bg: Dictionary = _backgrounds.get_background(String(t.background))
	_age.text = "AGE %d" % BackgroundLibrary.START_AGE
	_title.text = "WHO HE BECAME"
	var lines: Array[String] = []
	var who: String = String(bg.get("name", ""))
	if String(t.second) != "" and _backgrounds.has(String(t.second)):
		who += ", with a bit of %s" % String(_backgrounds.get_background(String(t.second)).name).to_lower()
	lines.append(who + ".")
	lines.append(String(bg.get("about", "")))
	lines.append("Strong: %s." % NewCareerScreen._stat_list(bg.get("strengths", [])))
	var him: Dictionary = he_became()
	var frame: Dictionary = him.get("frame", {})
	lines.append("%d cm, reach %d cm, %s at 16: growing into %s by %d." % [int(frame.get("height_cm", 0)), int(frame.get("reach_cm", 0)),
		Weight.kg_text(Weight.walk_kg(frame, float(him.get("age", BackgroundLibrary.START_AGE)))), Weight.name_of(Weight.natural(frame)).to_lower(),
		int(Weight.GROWN_AT)])
	var gift_names: Dictionary = CareerHub._enum("gifts")
	var flaw_names: Dictionary = CareerHub._enum("flaws")
	var gifts: Array[String] = []
	for g: Variant in him.get("gifts", []):
		gifts.append(String(gift_names.get(g, g)))
	var flaws: Array[String] = []
	for f: Variant in him.get("flaws", []):
		if not String(f) in CareerHub.DISCOVERED_FLAWS:
			flaws.append(String(flaw_names.get(f, f)))
	lines.append("Gifts: %s. Flaws: %s." % [", ".join(gifts) if not gifts.is_empty() else "none that show yet",
		", ".join(flaws) if not flaws.is_empty() else "none that show yet"])
	var people: Array = _childhood.people(picks, String(_choices.get("name", "")), String(_choices.get("country_id", "")), _seed)
	for person: Dictionary in people:
		lines.append("%s, %s: %s" % [person.name, String(person.role).to_lower(), person.about])
	lines.append("He starts with $%d saved." % (int(bg.get("money", 0)) + _childhood.money(picks)))
	lines.append(String(bg.get("hook", "")))
	_body.text = "\n".join(lines)
	var grown: Dictionary = him.duplicate(true)
	grown.id = "childhood_him"
	grown.look = _choices.get("look", {})
	portrait.show_fighter(grown)
	for b: Button in _choice_buttons():
		b.visible = false
	_outcome.visible = false
	_next.visible = false
	_start.visible = true
	FightHud.focus_later(_start)


## Him as a boy of `age` for the portrait: his look and stance from the new-career screen, at that age's frame
## (AGE_FRAMES: the nearest age at or under it), with no beard before 15.
func at_age(age: int) -> Dictionary:
	var frame: Dictionary = AGE_FRAMES[AGE_FRAMES.keys()[0]]
	for a: int in AGE_FRAMES:
		if a <= age:
			frame = AGE_FRAMES[a]
	var look: Dictionary = Dictionary(_choices.get("look", {})).duplicate()
	if age < 15:
		look.beard = "none"
	return { "id": "childhood_%d" % age, "name": String(_choices.get("name", "")),
		"stance": String(_choices.get("stance", "orthodox")), "look": look, "frame": frame.duplicate() }


## The fighter@1 profile these picks make (as Career.start makes him): his background's fighter, changed by his choices.
func he_became() -> Dictionary:
	if _roster == null:
		_roster = FighterLibrary.load_dir()
	var bg: String = String(_childhood.tally(picks).background)
	if not _backgrounds.has(bg):
		return {}
	var extra: Dictionary = _choices.duplicate(true)
	extra.background = bg
	var him: Dictionary = _childhood.apply(_backgrounds.make_fighter(bg, _seed, _roster, extra), picks, _backgrounds)
	Career.give_weight(him, _seed)
	return him


func _choice_buttons() -> Array[Button]:
	var out: Array[Button] = []
	for b: Node in _buttons.get_children():
		if b is Button:
			out.append(b as Button)
	return out


func _wrapped(font_size: int, color: Color) -> Label:
	var label := FightNightCard._label(font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 820.0
	return label
