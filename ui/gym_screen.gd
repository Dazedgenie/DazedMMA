class_name GymScreen
extends PanelContainer
## Your gym and the walk-in (docs/03 §11.3, D313): the last step of a new career. *Where you coach* shows three gyms in
## his hometown (Gym.offers) side by side: the name, the kind and its culture, what it trains better and worse, the owner
## and the monthly fee. Pick one, then *The walk-in*: the January morning he walks through its door and you meet him.
## Start career sends the gym on (finished).

signal finished(gym: Dictionary)
signal back_pressed

const BACKGROUND := Color(0.06, 0.07, 0.09)
const CARD := Color("#1b1f26")
const PICKED := Color("#2a2f38")
const RED_CORNER := Color("#ff6b6b")
const TEXT := Color("#e9ecef")
const DIM := Color("#8a8f98")
const GOOD := Color("#69db7c")

## The gyms on offer (Gym.offers) and the one picked (-1 = none yet).
var gyms: Array = []
var picked: int = -1

var _choices: Dictionary = {}
var _title: Label
var _sub: Label
var _cards: HBoxContainer
var _walk_in: Label
var _pick_buttons: Array[Button] = []
var _start: Button


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override("panel", FightHud._panel_style(BACKGROUND))
	var center := CenterContainer.new()
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.custom_minimum_size = Vector2(1100.0, 0.0)
	center.add_child(box)
	_title = Label.new()
	DisplayFont.apply(_title, 56)
	_title.add_theme_color_override("font_color", RED_CORNER)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_sub = FightNightCard._label(18, DIM)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_sub)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 16)
	box.add_child(_cards)
	_walk_in = FightNightCard._label(21, TEXT)
	_walk_in.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_walk_in.custom_minimum_size = Vector2(900.0, 0.0)
	box.add_child(_walk_in)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var back: Button = CampPlanner._button(row, "Back", press_back)
	back.custom_minimum_size.x = 180.0
	_start = CampPlanner._button(row, "Start career", press_start)
	_start.custom_minimum_size = Vector2(280.0, 60.0)
	CampPlanner.style_fight_button(_start, 32)


## The three gyms for this new career (`choices` as Career.start takes them, with the background his childhood made).
func begin(p_choices: Dictionary, career_seed: int) -> void:
	_choices = p_choices
	gyms = Gym.offers(String(_choices.get("hometown", "")), String(_choices.get("country_id", "")),
		String(_choices.get("background", "")), career_seed)
	picked = -1
	_show_gyms()


## Picks gym `n` (0–2) and goes on to the walk-in.
func pick(n: int) -> void:
	if n < 0 or n >= gyms.size():
		return
	picked = n
	_show_walk_in()


func on_walk_in() -> bool:
	return picked >= 0


func press_start() -> void:
	if on_walk_in():
		finished.emit((gyms[picked] as Dictionary).duplicate(true))


## Back from the walk-in goes back to the three gyms; from there, back out of the new career.
func press_back() -> void:
	if on_walk_in():
		picked = -1
		_show_gyms()
	else:
		back_pressed.emit()


func text() -> String:
	var lines: Array[String] = [_title.text, _sub.text]
	if _cards.visible:
		for card: Node in _cards.get_children():
			lines.append((card.get_child(0).get_child(0) as Label).text)
	if _walk_in.visible:
		lines.append(_walk_in.text)
	return "\n".join(lines)


## A gym as its card says it: its name, kind and culture, what it trains, the owner and the fee.
static func gym_text(gym: Dictionary) -> String:
	var lines: Array[String] = [String(gym.get("name", "")), Gym.kind_line(gym)]
	lines.append(String(Gym.kind(String(gym.get("kind", ""))).get("about", "")))
	lines.append(String(Gym.culture(String(gym.get("culture", ""))).get("about", "")))
	lines.append(Gym.trains_line(gym))
	lines.append("Owner: %s. %s" % [String(gym.get("owner_name", "")), String(gym.get("owner", ""))])
	lines.append("$%d a month" % int(gym.get("fee", 0)))
	return "\n".join(lines)


## The walk-in: the morning he comes through the door of `gym`, from the new career's choices (his name, his
## background's hook, someone from his childhood if there was anyone).
static func walk_in_text(gym: Dictionary, choices: Dictionary, coach: String) -> String:
	var his_name: String = String(choices.get("name", ""))
	var lines: Array[String] = []
	lines.append("Monday 4 January %d. It's still dark when the door of %s bangs open and a kid walks in out of the cold, sixteen and trying to look older." % [Career.START_DATE[0], String(gym.get("name", "the gym"))])
	var hook: String = String(BackgroundLibrary.shared().get_background(String(choices.get("background", ""))).get("hook", ""))
	if hook != "":
		lines.append(hook)
	var people: Array = choices.get("people", [])
	if not people.is_empty() and people[0] is Dictionary:
		lines.append("%s told him to come here." % _who(people[0]))
	lines.append("\"I'm %s,\" he says. \"I want to fight.\"" % his_name)
	lines.append("%s nods at you from the office door. You're %s, you coach here, and from today he's yours." % [String(gym.get("owner_name", "The owner")), coach if coach != "" else "the coach"])
	return "\n\n".join(lines)


static func _who(person: Dictionary) -> String:
	var role: String = String(person.get("role", ""))
	var called: String = String(person.get("name", ""))
	return "His %s, %s," % [role.to_lower(), called] if called != "" else "His %s" % role.to_lower()


func _show_gyms() -> void:
	_title.text = "WHERE YOU COACH"
	_sub.text = "Three gyms in %s would have you. Pick the one you coach at: it's where he trains, and its fee comes out of his savings every month." % String(_choices.get("hometown", "his hometown"))
	for card: Node in _cards.get_children():
		_cards.remove_child(card)
		card.queue_free()
	_pick_buttons.clear()
	for n in gyms.size():
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style: StyleBoxFlat = FightHud._panel_style(CARD)
		style.set_content_margin_all(18)
		card.add_theme_stylebox_override("panel", style)
		_cards.add_child(card)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 10)
		card.add_child(col)
		var label := FightNightCard._label(17, TEXT)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(320.0, 0.0)
		label.text = gym_text(gyms[n])
		col.add_child(label)
		_pick_buttons.append(CampPlanner._button(col, "Coach here", pick.bind(n)))
	_cards.visible = true
	_walk_in.visible = false
	_start.visible = false
	if not _pick_buttons.is_empty():
		FightHud.focus_later(_pick_buttons[0])


func _show_walk_in() -> void:
	_title.text = "THE WALK-IN"
	_sub.text = "%s · %s" % [String(gyms[picked].get("name", "")), Gym.kind_line(gyms[picked])]
	_walk_in.text = walk_in_text(gyms[picked], _choices, String(_choices.get("coach", "")))
	_cards.visible = false
	_walk_in.visible = true
	_start.visible = true
	FightHud.focus_later(_start)
