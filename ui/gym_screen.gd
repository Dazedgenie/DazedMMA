class_name GymScreen
extends PanelContainer
## Your gym and the walk-in (docs/03 §11.3 and §14.1, D313, D441): the last step of a new career. *Where you open your
## gym* shows three run-down places in his hometown (Gym.offers) side by side: the name, the place, the kind and its
## culture, what it trains better and worse, the man you take it over from, and its money (members, dues and rent).
## Pick one, then *The walk-in*: the January morning he walks through your door and you meet him.
## Since D434 (docs/06 §6.14) each gym is a card topped in its kind's colour with its picture, the owner's face, what it
## trains as green and red chips and the fee big; the walk-in shows him standing in a lit doorway beside the words.
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
const BAD := Color("#ff8787")
const DOOR := Color("#0b0d10")
const DOOR_LIGHT := Color("#3a2f24")
## The gym cards (D434): how wide each is, the owner's face and the doorway he stands in.
const CARD_WIDTH: float = 400.0
const OWNER_FACE := Vector2(96.0, 112.0)
const DOORWAY := Vector2(340.0, 600.0)
## An owner's frame (he's drawn from his name's country, D364).
const OWNER_FRAME := { "height_cm": 178, "reach_cm": 180, "build": "stocky" }

## The gyms on offer (Gym.offers) and the one picked (-1 = none yet).
var gyms: Array = []
var picked: int = -1

var _choices: Dictionary = {}
var _seed: int = 0
## The walk-in (D434, Kyle's card "Him in the doorway"): him in a lit doorway beside the words, the owner under them.
var _walk_row: HBoxContainer
var doorway: FighterPortrait
var owner_face: FighterPortrait
var _owner_line: Label
## The gym cards' owners (D434), one per card.
var owner_faces: Array[FighterPortrait] = []
var _title: Label
var _sub: Label
var _cards: HBoxContainer
var _walk_in: Label
var _pick_buttons: Array[Button] = []
var _start: Button


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override("panel", OffCage.hall_panel())  # The dimmed hall shows through (D435).
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
	_walk_row = HBoxContainer.new()
	_walk_row.add_theme_constant_override("separation", 32)
	box.add_child(_walk_row)
	var door := PanelContainer.new()
	door.custom_minimum_size = DOORWAY
	var door_style: StyleBoxFlat = FightHud._panel_style(DOOR_LIGHT)
	door_style.set_border_width_all(14)
	door_style.border_width_bottom = 0
	door_style.border_color = DOOR
	door_style.set_content_margin_all(0)
	door.add_theme_stylebox_override("panel", door_style)
	_walk_row.add_child(door)
	var glow := TextureRect.new()
	glow.texture = NewCareerScreen.spotlight_texture()
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	door.add_child(glow)
	doorway = FighterPortrait.new(FighterPortrait.FULL, 0, 0.0)
	door.add_child(doorway)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 18)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_walk_row.add_child(words)
	_walk_in = FightNightCard._label(21, TEXT)
	_walk_in.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_walk_in.custom_minimum_size = Vector2(720.0, 0.0)
	words.add_child(_walk_in)
	var owner_row := HBoxContainer.new()
	owner_row.add_theme_constant_override("separation", 14)
	words.add_child(owner_row)
	owner_face = FighterPortrait.new(FighterPortrait.BUST, 1, 10.0)
	owner_face.custom_minimum_size = OWNER_FACE
	owner_row.add_child(owner_face)
	_owner_line = FightNightCard._label(16, DIM)
	_owner_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_owner_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_owner_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	owner_row.add_child(_owner_line)
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
	_seed = career_seed
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
		for gym: Dictionary in gyms:
			lines.append(gym_text(gym))
	if _walk_row.visible:
		lines.append(_walk_in.text)
	return "\n".join(lines)


## A gym as its card says it: its name, place, kind and culture, what it trains, who you take it over from and its money.
static func gym_text(gym: Dictionary) -> String:
	var lines: Array[String] = [String(gym.get("name", "")), Gym.kind_line(gym)]
	lines.append(place_line(gym))
	lines.append(String(Gym.kind(String(gym.get("kind", ""))).get("about", "")))
	lines.append(String(Gym.culture(String(gym.get("culture", ""))).get("about", "")))
	lines.append(Gym.trains_line(gym))
	lines.append("Taken over from %s. %s" % [String(gym.get("owner_name", "")), String(gym.get("owner", ""))])
	lines.append(money_text(gym))
	return "\n".join(lines)


## "An old hall: a gym that's closing, sold to you as it stands." (the place's name and line).
static func place_line(gym: Dictionary) -> String:
	var where: Dictionary = Gym.place(String(gym.get("place", "")))
	return "%s. %s" % [String(where.get("name", "")), String(where.get("about", ""))] if not where.is_empty() else ""


## "14 members at $40 a month, rent $480: +$80 a month".
static func money_text(gym: Dictionary) -> String:
	var net: int = Gym.month_net(gym)
	return "%d members at $%d a month, rent $%d: %s%d a month" % [int(gym.get("members", 0)), int(gym.get("dues", 0)),
		int(gym.get("rent", 0)), "+$" if net >= 0 else "−$", absi(net)]


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
	lines.append("The paint on the sign over the door is still wet. You're %s, this place is yours, and from today so is he." % (coach if coach != "" else "the coach"))
	return "\n\n".join(lines)


static func _who(person: Dictionary) -> String:
	var role: String = String(person.get("role", ""))
	var called: String = String(person.get("name", ""))
	return "His %s, %s," % [role.to_lower(), called] if called != "" else "His %s" % role.to_lower()


func _show_gyms() -> void:
	_title.text = "WHERE YOU OPEN YOUR GYM"
	_sub.text = "Three run-down places in %s you could take on. Pick one and it's yours: he trains there, its members' dues pay the rent, and it takes %d%% of his purses." % [String(_choices.get("hometown", "his hometown")), roundi(Gym.PURSE_CUT * 100.0)]
	for card: Node in _cards.get_children():
		_cards.remove_child(card)
		card.queue_free()
	_pick_buttons.clear()
	owner_faces.clear()
	for n in gyms.size():
		_cards.add_child(_gym_card(gyms[n], n))
	_cards.visible = true
	_walk_row.visible = false
	_start.visible = false
	if not _pick_buttons.is_empty():
		FightHud.focus_later(_pick_buttons[0])


func _show_walk_in() -> void:
	_title.text = "THE WALK-IN"
	_sub.text = "%s · %s" % [String(gyms[picked].get("name", "")), Gym.kind_line(gyms[picked])]
	_walk_in.text = walk_in_text(gyms[picked], _choices, String(_choices.get("coach", "")))
	doorway.show_fighter(his_profile(_choices, _seed))
	owner_face.show_fighter(owner_profile(gyms[picked], _choices))
	_owner_line.text = "%s, who let you %s. %s" % [String(gyms[picked].get("owner_name", "")), String(gyms[picked].get("name", "")),
		String(gyms[picked].get("owner", ""))]
	_cards.visible = false
	_walk_row.visible = true
	_start.visible = true
	FightHud.focus_later(_start)


## What the card says about how the gym trains him, as chips (D434, Kyle's card "Cards with owner and chips"):
## [text, good] for each stat its kind trains better or worse, then its culture's skips, injuries and sparring.
static func chips(gym: Dictionary) -> Array:
	var out: Array = []
	var xp: Dictionary = Gym.kind(String(gym.get("kind", ""))).get("xp", {})
	for id: String in xp:
		var share: float = float(xp[id])
		if not is_equal_approx(share, 1.0):
			out.append(["%s %s%d%%" % [id.capitalize(), "+" if share > 1.0 else "−", roundi(absf(share - 1.0) * 100.0)], share > 1.0])
	var culture: Dictionary = Gym.culture(String(gym.get("culture", "")))
	var skips: float = float(culture.get("skips", 1.0))
	if skips < 1.0:
		out.append(["Fewer skipped sessions", true])
	elif skips > 1.0:
		out.append(["More skipped sessions", false])
	if float(culture.get("injury", 1.0)) > 1.0:
		out.append(["More injuries", false])
	var sparring: float = float(culture.get("sparring_xp", 1.0))
	if sparring > 1.0:
		out.append(["Sparring +%d%%" % roundi((sparring - 1.0) * 100.0), true])
	return out


## The gym's owner as a portrait: a man from his hometown's country, his look rolled from his name.
static func owner_profile(gym: Dictionary, choices: Dictionary) -> Dictionary:
	var who: String = String(gym.get("owner_name", ""))
	var country: String = String(choices.get("country_id", ""))
	return { "id": "owner_%s" % who.to_snake_case(), "name": who, "stance": "orthodox",
		"look": FighterLook.roll(hash([who, "owner look"]), country), "frame": OWNER_FRAME.duplicate() }


## Him as Career.start will make him from these choices (his background, his childhood's picks, his look), for the
## doorway.
static func his_profile(choices: Dictionary, career_seed: int, roster: FighterLibrary = null) -> Dictionary:
	var bgs: BackgroundLibrary = BackgroundLibrary.shared()
	var background: String = String(choices.get("background", ""))
	if not bgs.has(background):
		return { "id": "walk_in", "look": choices.get("look", {}), "stance": String(choices.get("stance", "orthodox")),
			"frame": NewCareerScreen.PREVIEW_FRAME.duplicate() }
	var him: Dictionary = bgs.make_fighter(background, career_seed, roster if roster != null else FighterLibrary.load_dir(),
		choices.duplicate(true))
	var picks: Array = choices.get("childhood", [])
	if not picks.is_empty():
		him = Childhood.shared().apply(him, picks, bgs)
	him.id = "walk_in"
	him.look = choices.get("look", {})
	return him


## One gym's card: a band in its kind's colour with its picture, name and kind; the owner's face and words; what it
## trains as chips; the place, the kind and culture in a line each; the money a month big; Open it here.
func _gym_card(gym: Dictionary, n: int) -> PanelContainer:
	var colour: Color = BackgroundIcon.colour_of(String(gym.get("kind", "")))
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0.0)
	var style: StyleBoxFlat = FightHud._panel_style(CARD)
	style.set_content_margin_all(0)
	card.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	card.add_child(col)
	var band := PanelContainer.new()
	var band_style: StyleBoxFlat = FightHud._panel_style(colour.darkened(0.6))
	band_style.set_content_margin_all(14)
	band_style.border_width_top = 5
	band_style.border_color = colour
	band.add_theme_stylebox_override("panel", band_style)
	col.add_child(band)
	var band_row := HBoxContainer.new()
	band_row.add_theme_constant_override("separation", 12)
	band.add_child(band_row)
	band_row.add_child(BackgroundIcon.new(String(gym.get("kind", ""))))
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	band_row.add_child(names)
	var name_label := Label.new()
	DisplayFont.apply(name_label, 28)
	name_label.add_theme_color_override("font_color", TEXT)
	name_label.text = String(gym.get("name", ""))
	names.add_child(name_label)
	var kind_label := FightNightCard._label(15, colour.lightened(0.3))
	kind_label.text = Gym.kind_line(gym)
	names.add_child(kind_label)
	var inner := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		inner.add_theme_constant_override("margin_" + side, 18)
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(inner)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	inner.add_child(box)
	var owner_row := HBoxContainer.new()
	owner_row.add_theme_constant_override("separation", 12)
	box.add_child(owner_row)
	var face := FighterPortrait.new(FighterPortrait.BUST, 1, 10.0)
	face.custom_minimum_size = OWNER_FACE
	face.show_fighter(owner_profile(gym, _choices))
	owner_row.add_child(face)
	owner_faces.append(face)
	var owner_words := VBoxContainer.new()
	owner_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	owner_words.alignment = BoxContainer.ALIGNMENT_CENTER
	owner_row.add_child(owner_words)
	var owner_name := FightNightCard._label(18, TEXT)
	owner_name.text = "Taken over from %s" % String(gym.get("owner_name", ""))
	owner_words.add_child(owner_name)
	var owner_about := FightNightCard._label(15, DIM)
	owner_about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	owner_about.text = String(gym.get("owner", ""))
	owner_words.add_child(owner_about)
	var chip_row := HFlowContainer.new()
	chip_row.add_theme_constant_override("h_separation", 6)
	chip_row.add_theme_constant_override("v_separation", 6)
	box.add_child(chip_row)
	for chip: Array in chips(gym):
		chip_row.add_child(_chip(String(chip[0]), bool(chip[1])))
	var about := FightNightCard._label(15, DIM)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.text = "%s\n%s\n%s" % [place_line(gym), String(Gym.kind(String(gym.get("kind", ""))).get("about", "")),
		String(Gym.culture(String(gym.get("culture", ""))).get("about", ""))]
	box.add_child(about)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var fee_row := HBoxContainer.new()
	fee_row.add_theme_constant_override("separation", 8)
	box.add_child(fee_row)
	var fee := Label.new()
	DisplayFont.apply(fee, 40)
	fee.add_theme_color_override("font_color", TEXT)
	var net: int = Gym.month_net(gym)
	fee.text = "%s%d" % ["+$" if net >= 0 else "−$", absi(net)]
	fee_row.add_child(fee)
	var month := FightNightCard._label(16, DIM)
	month.text = "a month: %d members at $%d, rent $%d" % [int(gym.get("members", 0)), int(gym.get("dues", 0)), int(gym.get("rent", 0))]
	month.size_flags_vertical = Control.SIZE_SHRINK_END
	fee_row.add_child(month)
	_pick_buttons.append(CampPlanner._button(box, "Open it here", pick.bind(n)))
	return card


func _chip(text_in: String, good: bool) -> PanelContainer:
	var colour: Color = GOOD if good else BAD
	var chip := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(colour, 0.14)
	box.border_color = Color(colour, 0.7)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.content_margin_left = 9
	box.content_margin_right = 9
	box.content_margin_top = 2
	box.content_margin_bottom = 3
	chip.add_theme_stylebox_override("panel", box)
	var label := FightNightCard._label(14, colour)
	label.text = text_in
	chip.add_child(label)
	return chip
