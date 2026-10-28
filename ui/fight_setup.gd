class_name FightSetup
extends PanelContainer
## The screen before a fight (#19): who fights, how fast Normal speed is (D91: the
## playtest compares 1× and 2×), the difficulty (Easy allows active pause, D50), the
## tell cue, auto slow-mo and flourish toggles (D51–D53), the player's two drilled
## rules (docs/01 §23) and the seed. The player is always the red corner.
## For the playtest (#20, D118): the tester's name and a "Playtest" picker that sets up
## each of the playtest's fights in order (Playtest, data/playtest).

signal start_pressed(settings: Dictionary)

## [label, red id, blue id] from data/fighters. The playtest matchup comes first (D112); the
## Judoka and the BJJ fighter (D128), then the Muay Thai fighter (D129), come last.
const MATCHUPS: Array = [
	["Wrestler vs Kicker", "wrestler", "kicker"],
	["Kicker vs Boxer", "kicker", "boxer"],
	["Wrestler vs Boxer", "wrestler", "boxer"],
	["Boxer vs Kicker", "boxer", "kicker"],
	["Judoka vs Boxer", "judoka", "boxer"],
	["Judoka vs Wrestler", "judoka", "wrestler"],
	["BJJ vs Wrestler", "bjj", "wrestler"],
	["BJJ vs Kicker", "bjj", "kicker"],
	["Muay Thai vs Boxer", "muay_thai", "boxer"],
	["Muay Thai vs Wrestler", "muay_thai", "wrestler"],
	["Muay Thai vs Kicker", "muay_thai", "kicker"],
]
const SPEEDS: Array = [["Normal is 2× fight time", 2.0], ["Normal is 1× fight time", 1.0]]
const HELP := "[b]Keys[/b]  1–9 calls · Q/E read calls · Space slow-mo · F fast · P pause (Easy) · T towel · Esc menu · F3 debug overlay · ` console"

var _matchup: OptionButton
var _speed: OptionButton
var _difficulty: OptionButton
var _tells: CheckBox
var _auto_slow: CheckBox
var _flourish: CheckBox
var _seed: LineEdit
var _rules_box: VBoxContainer
var _rules: RuleSlots
var _start: Button
var _step: OptionButton
var _tester: LineEdit
var _steps: Array[Dictionary] = []
var _roster: FighterLibrary
var _actions: ActionLibrary


func _init(p_roster: FighterLibrary = null, p_actions: ActionLibrary = null) -> void:
	_roster = p_roster if p_roster != null else FighterLibrary.load_dir()
	_actions = p_actions if p_actions != null else ActionLibrary.load_dir()
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -460.0
	offset_right = 460.0
	offset_top = -390.0
	offset_bottom = 390.0
	add_theme_stylebox_override("panel", FightHud._panel_style(Color(0.08, 0.09, 0.11, 0.96)))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	var title := Label.new()
	title.text = "Chin Check · fight prototype"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var intro := Label.new()
	intro.text = "You're the red corner. Call the takedown when he kicks."
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.add_theme_color_override("font_color", Color("#adb5bd"))
	column.add_child(intro)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 10)
	column.add_child(grid)
	_steps = Playtest.steps()
	_step = _picker(grid, "Playtest", ["Free fight"] + _steps.map(func(st: Dictionary) -> String: return String(st.name)))
	_step.item_selected.connect(func(_i: int) -> void: _apply_step())
	_add_label(grid, "Your name")
	_tester = LineEdit.new()
	_tester.placeholder_text = "for the playtest notes (optional)"
	grid.add_child(_tester)
	_matchup = _picker(grid, "Fight", MATCHUPS.map(func(m: Array) -> String: return m[0]))
	_matchup.item_selected.connect(func(_i: int) -> void: _build_rules())
	_speed = _picker(grid, "Speed", SPEEDS.map(func(s: Array) -> String: return s[0]))
	_difficulty = _picker(grid, "Difficulty", ["Normal", "Easy (P pauses the fight)"])
	_add_label(grid, "Seed")
	_seed = LineEdit.new()
	_seed.placeholder_text = "random"
	grid.add_child(_seed)

	var toggles := HBoxContainer.new()
	toggles.add_theme_constant_override("separation", 20)
	column.add_child(toggles)
	_tells = _toggle(toggles, "Tell cue", true)
	_auto_slow = _toggle(toggles, "Auto slow-mo", true)
	_flourish = _toggle(toggles, "Perfect-call flourish", true)

	var rules_title := Label.new()
	rules_title.text = "Drilled rules for your fighter"
	column.add_child(rules_title)
	_rules_box = VBoxContainer.new()
	column.add_child(_rules_box)
	_build_rules()

	var help := RichTextLabel.new()
	help.bbcode_enabled = true
	help.fit_content = true
	help.scroll_active = false
	help.text = HELP
	help.add_theme_color_override("default_color", Color("#adb5bd"))
	column.add_child(help)

	_start = Button.new()
	_start.text = "Start fight"
	_start.custom_minimum_size = Vector2(0.0, 56.0)
	_start.add_theme_font_size_override("font_size", 24)
	_start.pressed.connect(func() -> void: start_pressed.emit(settings()))
	column.add_child(_start)


## What was picked: {label, red, blue, normal_rate, easy, tell_cues, auto_slow,
## flourishes, rules ([[slot, rule id, drilled], …]), seed (-1 = random), tester}, and for a
## playtest fight also {step, calls (the call bar's calls, [] = all), tip}.
func settings() -> Dictionary:
	var m: Array = MATCHUPS[maxi(0, _matchup.selected)]
	var typed: String = _seed.text.strip_edges()
	var s := {
		"label": m[0], "red": m[1], "blue": m[2],
		"normal_rate": float(SPEEDS[maxi(0, _speed.selected)][1]),
		"easy": _difficulty.selected == 1,
		"tell_cues": _tells.button_pressed, "auto_slow": _auto_slow.button_pressed, "flourishes": _flourish.button_pressed,
		"rules": _rules.picked(),
		"seed": int(typed) if typed.is_valid_int() else -1,
		"tester": _tester.text.strip_edges(),
	}
	if _step.selected > 0:
		var step: Dictionary = _steps[_step.selected - 1]
		var picked: Array = s.rules
		s = Playtest.settings_for(step, s)
		s.rules = picked  # As shown (the step's rules, unless the tester changed them).
		s.tell_cues = _tells.button_pressed
	return s


## Picks a playtest step (its id), or the free fight ("").
func pick_step(id: String) -> void:
	_step.selected = 0
	for n in _steps.size():
		if _steps[n].id == id:
			_step.selected = n + 1
	_apply_step()


## Sets the pickers back to these settings (after a fight, "Change setup").
func show_settings(s: Dictionary) -> void:
	_select_matchup(String(s.get("red", "")), String(s.get("blue", "")))
	_rules.show_rules(s.get("rules", []))
	_tells.button_pressed = bool(s.get("tell_cues", true))
	_tester.text = String(s.get("tester", ""))
	_step.selected = 0
	for n in _steps.size():
		if _steps[n].id == s.get("step", ""):
			_step.selected = n + 1


## A playtest step sets the fight, the rules and the tell cue (they can still be changed).
func _apply_step() -> void:
	if _step.selected <= 0:
		return
	var step: Dictionary = _steps[_step.selected - 1]
	var s: Dictionary = Playtest.settings_for(step)
	_select_matchup(s.red, s.blue)
	_rules.show_rules(s.rules)
	_tells.button_pressed = s.tell_cues


func _select_matchup(red: String, blue: String) -> void:
	for n in MATCHUPS.size():
		if MATCHUPS[n][1] == red and MATCHUPS[n][2] == blue:
			_matchup.selected = n
	_build_rules()


func focus_start() -> void:
	FightHud.focus_later(_start)


func rule_slots() -> RuleSlots:
	return _rules


func _build_rules() -> void:
	for c in _rules_box.get_children():
		_rules_box.remove_child(c)
		c.queue_free()
	var red: String = MATCHUPS[maxi(0, _matchup.selected)][1]
	_rules = RuleSlots.new(_roster.profile(red), _actions)
	_rules_box.add_child(_rules)


func _picker(grid: GridContainer, label: String, items: Array) -> OptionButton:
	_add_label(grid, label)
	var picker := OptionButton.new()
	for item: String in items:
		picker.add_item(item)
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(picker)
	return picker


static func _add_label(grid: GridContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	grid.add_child(l)


static func _toggle(parent: Control, text: String, on: bool) -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	box.button_pressed = on
	parent.add_child(box)
	return box
