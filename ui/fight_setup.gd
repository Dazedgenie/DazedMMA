class_name FightSetup
extends PanelContainer
## The screen before a fight (#19), as a tale of the tape (D172, docs/06 §6.7): your fighter (red) and his
## opponent (blue) side by side with ◀ ▶ to pick any two, their frames and stat groups face to face
## (TaleOfTheTape: the frame and the headline stats, the opponent's scouted as grades), the keys to the fight, and the options under it:
## the rules, how fast Normal speed is (D91: the playtest compares 1× and 2×), the difficulty (Easy allows
## active pause, D50), the tell cue, auto slow-mo and flourish toggles (D51–D53), the player's two drilled
## rules (docs/01 §23) and the seed. The player is always the red corner.
## For the playtest (#20, D118): the tester's name and a "Playtest" picker that sets up
## each of the playtest's fights in order (Playtest, data/playtest).
## "Training camp first" opens the camp planner for the red fighter (CampPlanner, D134).

signal start_pressed(settings: Dictionary)
signal camp_pressed(settings: Dictionary)

## The fighters the arrows step through come in this order (the playtest matchup's two first, D112), then
## every other fighter with a style sheet (data/styles, D160) by id.
const FIRST: Array[String] = ["wrestler", "kicker", "boxer", "judoka", "bjj", "muay_thai", "sambo"]
## Who the screen opens on: the playtest matchup (D112).
const DEFAULT_RED := "wrestler"
const DEFAULT_BLUE := "kicker"
## The rules the fight is held under: label, data/rulesets id (D141: PRIDE).
const RULESETS: Array = [["Pro (unified rules)", "pro"], ["PRIDE rules", "pride"], ["Amateur, 18+", "amateur_adult"], ["Amateur, 16–17", "amateur_teen"]]
const SPEEDS: Array = [["Normal is 2× fight time", 2.0], ["Normal is 1× fight time", 1.0]]
const HELP := "[b]Keys[/b]  1–9 calls · Q/E read calls · Space slow-mo · F fast · P pause (Easy) · T towel · Esc menu · F3 debug overlay · ` console"
const BACKGROUND := Color(0.06, 0.07, 0.09)
const CARD := Color("#1b1f26")
const TEXT := Color("#e9ecef")
const DIM := Color("#8a8f98")
const NOTE := Color("#adb5bd")
const CORNERS: Array[Color] = [TaleOfTheTape.RED, TaleOfTheTape.BLUE]
## The body figure's height for the tallest fighter (px); shorter men are drawn shorter.
const FIGURE_H: float = 200.0
const FIGURE_TALLEST_CM: float = 190.0
## The fighter's name between the arrows: its size, and how small a long name may shrink to fit NAME_W (px).
const NAME_SIZE: int = 46
const NAME_MIN_SIZE: int = 26
const NAME_W: float = 300.0

## Fighter ids in arrow order.
var fighters: Array[String] = []
## The picked fighters, red then blue.
var picked: Array[String] = [DEFAULT_RED, DEFAULT_BLUE]

var _speed: OptionButton
var _ruleset: OptionButton
var _difficulty: OptionButton
var _tells: CheckBox
var _auto_slow: CheckBox
var _flourish: CheckBox
var _seed: LineEdit
var _rules_box: VBoxContainer
var _rules: RuleSlots
var _start: Button
var _camp: Button
var _step: OptionButton
var _tester: LineEdit
var _steps: Array[Dictionary] = []
var _roster: FighterLibrary
var _actions: ActionLibrary
var _styles: StyleLibrary
var _style_of: Dictionary = {}  # fighter id → his style sheet
var _subtitle: Label
var _tape: TaleOfTheTape
var _keys: RichTextLabel
var _names: Array[Label] = []
var _kinds: Array[Label] = []
var _figures: Array[BodyDamageFigure] = []
var _scouting: Array[RichTextLabel] = []


func _init(p_roster: FighterLibrary = null, p_actions: ActionLibrary = null) -> void:
	_roster = p_roster if p_roster != null else FighterLibrary.load_dir()
	_actions = p_actions if p_actions != null else ActionLibrary.load_dir()
	_styles = StyleLibrary.shared()
	for id: String in _styles.ids():
		var sheet: Dictionary = _styles.get_style(id)
		_style_of[String(sheet.fighter)] = sheet
	for id: String in FIRST:
		if _roster.has(id):
			fighters.append(id)
	var rest: Array = _roster.ids().filter(func(id: String) -> bool: return _style_of.has(id) and not FIRST.has(id))
	rest.sort()
	fighters.append_array(rest)

	set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel: StyleBoxFlat = FightHud._panel_style(BACKGROUND)
	panel.content_margin_bottom = 40.0  # Room for the version line under it.
	add_theme_stylebox_override("panel", panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	add_child(column)

	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 0)
	column.add_child(head)
	var title := Label.new()
	title.text = "TALE OF THE TAPE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	DisplayFont.apply(title, 54)
	title.add_theme_color_override("font_color", TaleOfTheTape.RED)
	head.add_child(title)
	_subtitle = _label(18, DIM)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(_subtitle)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	body.add_child(_build_fighter_card(0))
	var middle := _card(Vector2(0.0, 0.0))
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(middle)
	var middle_box: VBoxContainer = middle.get_child(0)
	_tape = TaleOfTheTape.new()
	middle_box.add_child(_tape)
	middle_box.add_child(_heading("Keys to the fight"))
	_keys = RichTextLabel.new()
	_keys.bbcode_enabled = true
	_keys.fit_content = true
	_keys.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_keys.add_theme_font_size_override("normal_font_size", 18)
	_keys.add_theme_color_override("default_color", TEXT)
	middle_box.add_child(_keys)
	body.add_child(_build_fighter_card(1))

	var options := _card(Vector2(0.0, 0.0))
	column.add_child(options)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	options.get_child(0).add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	left.add_child(grid)
	_steps = Playtest.steps()
	_step = _picker(grid, "Playtest", ["Free fight"] + _steps.map(func(st: Dictionary) -> String: return String(st.name)))
	_step.item_selected.connect(func(_i: int) -> void: _apply_step())
	_ruleset = _picker(grid, "Rules", RULESETS.map(func(r: Array) -> String: return r[0]))
	_ruleset.item_selected.connect(func(_i: int) -> void: _refresh())
	_speed = _picker(grid, "Speed", SPEEDS.map(func(s: Array) -> String: return s[0]))
	_add_label(grid, "Your name")
	_tester = LineEdit.new()
	_tester.placeholder_text = "for the playtest notes (optional)"
	_tester.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(_tester)
	_difficulty = _picker(grid, "Difficulty", ["Normal", "Easy (P pauses the fight)"])
	_add_label(grid, "Seed")
	_seed = LineEdit.new()
	_seed.placeholder_text = "random"
	_seed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(_seed)

	var toggles := HBoxContainer.new()
	toggles.add_theme_constant_override("separation", 20)
	left.add_child(toggles)
	_tells = _toggle(toggles, "Tell cue", true)
	_auto_slow = _toggle(toggles, "Auto slow-mo", true)
	_flourish = _toggle(toggles, "Perfect-call flourish", true)
	var rules_title := Label.new()
	rules_title.text = "Drilled rules for your fighter"
	rules_title.add_theme_color_override("font_color", DIM)
	toggles.add_child(rules_title)
	_rules_box = VBoxContainer.new()
	left.add_child(_rules_box)
	var help := RichTextLabel.new()
	help.bbcode_enabled = true
	help.fit_content = true
	help.scroll_active = false
	help.text = HELP
	help.add_theme_color_override("default_color", NOTE)
	left.add_child(help)

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.custom_minimum_size.x = 360.0
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(buttons)
	_start = CampPlanner._button(buttons, "Start fight", func() -> void: start_pressed.emit(settings()))
	_start.custom_minimum_size.y = 72.0
	CampPlanner.style_fight_button(_start, 40)
	_camp = CampPlanner._button(buttons, "Training camp first", func() -> void: camp_pressed.emit(settings()))
	_camp.custom_minimum_size.y = 52.0
	pick_fighters(DEFAULT_RED, DEFAULT_BLUE)


## What was picked: {label, red, blue, ruleset (data/rulesets id), normal_rate, easy, tell_cues, auto_slow,
## flourishes, rules ([[slot, rule id, drilled], …]), seed (-1 = random), tester}, and for a
## playtest fight also {step, calls (the call bar's calls, [] = all), tip}.
func settings() -> Dictionary:
	var typed: String = _seed.text.strip_edges()
	var s := {
		"label": "%s vs %s" % [_name(picked[0]), _name(picked[1])], "red": picked[0], "blue": picked[1],
		"normal_rate": float(SPEEDS[maxi(0, _speed.selected)][1]),
		"ruleset": String(RULESETS[maxi(0, _ruleset.selected)][1]),
		"easy": _difficulty.selected == 1,
		"tell_cues": _tells.button_pressed, "auto_slow": _auto_slow.button_pressed, "flourishes": _flourish.button_pressed,
		"rules": _rules.picked(),
		"seed": int(typed) if typed.is_valid_int() else -1,
		"tester": _tester.text.strip_edges(),
	}
	if _step.selected > 0:
		var step: Dictionary = _steps[_step.selected - 1]
		var rules: Array = s.rules
		s = Playtest.settings_for(step, s)
		s.rules = rules  # As shown (the step's rules, unless the tester changed them).
		s.tell_cues = _tells.button_pressed
	return s


## Puts these two fighters (data/fighters ids) in the red and blue corners.
func pick_fighters(red: String, blue: String) -> void:
	var red_changed: bool = red != picked[0] or _rules == null
	picked = [red, blue]
	if red_changed:
		_build_rules()
	_refresh()


## Steps one corner's fighter (0 red, 1 blue) through the list: +1 the next, -1 the one before.
func step_fighter(corner: int, step: int) -> void:
	var at: int = fighters.find(picked[corner])
	var next: String = fighters[posmod(at + step, fighters.size())]
	if corner == 0:
		pick_fighters(next, picked[1])
	else:
		pick_fighters(picked[0], next)


## Picks a playtest step (its id), or the free fight ("").
func pick_step(id: String) -> void:
	_step.selected = 0
	for n in _steps.size():
		if _steps[n].id == id:
			_step.selected = n + 1
	_apply_step()


## Sets the pickers back to these settings (after a fight, "Change setup").
func show_settings(s: Dictionary) -> void:
	pick_fighters(String(s.get("red", DEFAULT_RED)), String(s.get("blue", DEFAULT_BLUE)))
	_rules.show_rules(s.get("rules", []))
	_tells.button_pressed = bool(s.get("tell_cues", true))
	_ruleset.selected = maxi(0, RULESETS.map(func(r: Array) -> String: return r[1]).find(String(s.get("ruleset", "pro"))))
	_tester.text = String(s.get("tester", ""))
	_step.selected = 0
	for n in _steps.size():
		if _steps[n].id == s.get("step", ""):
			_step.selected = n + 1
	_refresh()


## The tape, the scouting and the keys as text (tests read it).
func text() -> String:
	return "\n".join([_subtitle.text, _names[0].text, _kinds[0].text, _scouting[0].get_parsed_text(), _names[1].text,
		_kinds[1].text, _scouting[1].get_parsed_text(), _tape.text(), _keys.get_parsed_text()])


## A playtest step sets the fight, the rules and the tell cue (they can still be changed).
func _apply_step() -> void:
	if _step.selected <= 0:
		return
	var step: Dictionary = _steps[_step.selected - 1]
	var s: Dictionary = Playtest.settings_for(step)
	pick_fighters(s.red, s.blue)
	_rules.show_rules(s.rules)
	_tells.button_pressed = s.tell_cues
	_ruleset.selected = 0  # The playtest fights are pro rules.
	_refresh()


func focus_start() -> void:
	FightHud.focus_later(_start)


func rule_slots() -> RuleSlots:
	return _rules


func _build_rules() -> void:
	for c in _rules_box.get_children():
		_rules_box.remove_child(c)
		c.queue_free()
	_rules = RuleSlots.new(_roster.profile(picked[0]), _actions)
	_rules_box.add_child(_rules)


func _name(id: String) -> String:
	return String(_roster.profile(id).get("name", id))


func _refresh() -> void:
	var profiles: Array[Dictionary] = [_roster.profile(picked[0]), _roster.profile(picked[1])]
	var step_name: String = String(_steps[_step.selected - 1].name) + " · " if _step.selected > 0 else ""
	_subtitle.text = "%s%s · you're the red corner" % [step_name, RULESETS[maxi(0, _ruleset.selected)][0]]
	for corner in 2:
		var profile: Dictionary = profiles[corner]
		var sheet: Dictionary = _style_of.get(picked[corner], {})
		_names[corner].text = String(profile.get("name", picked[corner])).to_upper()
		_fit_name(_names[corner])
		var kind: String = String(sheet.get("name", ""))
		_kinds[corner].text = kind if kind.to_upper() != _names[corner].text else ""
		var height: float = float(profile.get("frame", {}).get("height_cm", FIGURE_TALLEST_CM))
		_figures[corner].custom_minimum_size = Vector2(FIGURE_H * 0.6, FIGURE_H * minf(1.0, height / FIGURE_TALLEST_CM))
		_scouting[corner].text = _scouting_bbcode(sheet.get("scouting", {}))
	_tape.show_fighters(profiles[0], profiles[1])
	var keys: Array[String] = TaleOfTheTape.keys(profiles[0], profiles[1], _style_of.get(picked[1], {}).get("scouting", {}))
	_keys.text = "\n".join(keys.map(func(k: String) -> String: return "• " + k)) if not keys.is_empty() else "[color=%s]An even match on paper.[/color]" % DIM


## Shrinks a long name's font until it fits between the arrows.
static func _fit_name(label: Label) -> void:
	var font_size: int = NAME_SIZE
	while font_size > NAME_MIN_SIZE and DisplayFont.font().get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > NAME_W:
		font_size -= 2
	label.add_theme_font_size_override("font_size", font_size)


static func _scouting_bbcode(scouting: Dictionary) -> String:
	var lines: Array[String] = []
	if String(scouting.get("summary", "")) != "":
		lines.append(String(scouting.summary))
	for strength: String in scouting.get("strengths", []):
		lines.append("[color=#51cf66]+[/color] " + strength)
	for weakness: String in scouting.get("weaknesses", []):
		lines.append("[color=#ff6b6b]−[/color] " + weakness)
	return "\n".join(lines)


func _build_fighter_card(corner: int) -> Control:
	var card := _card(Vector2(470.0, 0.0))
	var box: VBoxContainer = card.get_child(0)
	box.add_theme_constant_override("separation", 8)
	var whose := _heading("Your corner" if corner == 0 else "The opponent")
	whose.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(whose)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	box.add_child(name_row)
	var back := CampPlanner._button(name_row, "◀", func() -> void: step_fighter(corner, -1))
	back.custom_minimum_size.x = 48.0
	back.tooltip_text = "the fighter before"
	var fighter_name := Label.new()
	DisplayFont.apply(fighter_name, NAME_SIZE)
	fighter_name.add_theme_color_override("font_color", CORNERS[corner])
	fighter_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fighter_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fighter_name.clip_text = true
	name_row.add_child(fighter_name)
	_names.append(fighter_name)
	var next := CampPlanner._button(name_row, "▶", func() -> void: step_fighter(corner, 1))
	next.custom_minimum_size.x = 48.0
	next.tooltip_text = "the next fighter"
	var kind := _label(18, DIM)
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(kind)
	_kinds.append(kind)
	var stand := Control.new()  # The figure stands on the same line whatever his height.
	stand.custom_minimum_size.y = FIGURE_H
	box.add_child(stand)
	var figure := BodyDamageFigure.new()
	figure.tooltip_text = "fresh: drawn to his height"
	stand.add_child(figure)
	figure.resized.connect(func() -> void: figure.position = Vector2((stand.size.x - figure.size.x) * 0.5, FIGURE_H - figure.size.y))
	stand.resized.connect(func() -> void: figure.position = Vector2((stand.size.x - figure.size.x) * 0.5, FIGURE_H - figure.size.y))
	_figures.append(figure)
	var scouting := RichTextLabel.new()
	scouting.bbcode_enabled = true
	scouting.fit_content = true
	scouting.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scouting.add_theme_font_size_override("normal_font_size", 17)
	scouting.add_theme_color_override("default_color", NOTE)
	box.add_child(scouting)
	_scouting.append(scouting)
	return card


func _card(min_size: Vector2) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = min_size
	var style: StyleBoxFlat = FightHud._panel_style(CARD)
	style.set_content_margin_all(20)
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	return card


func _heading(text_in: String) -> Label:
	var label := _label(20, DIM)
	DisplayFont.apply(label, 20)
	label.text = text_in.to_upper()
	return label


static func _label(font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	return label


func _picker(grid: GridContainer, label: String, items: Array) -> OptionButton:
	_add_label(grid, label)
	var picker := OptionButton.new()
	for item: String in items:
		picker.add_item(item)
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(picker)
	return picker


static func _add_label(grid: GridContainer, text_in: String) -> void:
	var l := Label.new()
	l.text = text_in
	grid.add_child(l)


static func _toggle(parent: Control, text_in: String, on: bool) -> CheckBox:
	var box := CheckBox.new()
	box.text = text_in
	box.button_pressed = on
	parent.add_child(box)
	return box
