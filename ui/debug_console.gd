class_name DebugConsole
extends PanelContainer
## Developer console: shows what the fight engine is doing, line by line.
##
## - "Run test fight" plays a short check fight instantly and reports pass/fail (SimCheck).
## - "Live fight" plays a full fight in real time at Normal speed (2x, docs/01 §2), between
##   the matchup picked next to it (Kicker vs Boxer, or the Wrestler against either, #15).
## - In a live fight, the call bar (or keys 1–9 and 0) makes Red's corner's calls (LiveCalls,
##   docs/01 §22): the Wrestler against the Kicker is the playtest matchup (calling the
##   takedown during the kick, D112). Calls can be made while paused; they land on the next tick.
## - "Rule 1" / "Rule 2" and the "Drilled" slider put drilled rules in Red's two slots before the
##   live fight (DrilledRules, docs/01 §23): slot 1 goes first; the slider stands in for camp drilling.
## - "Cage view" shows a TEMPORARY top-down map of the live fight (CageMap, D106) on the
##   left of the screen, to judge how the AI moves. It hides with the console.
## - Toggle the window with the ` key (left of 1). "Copy" puts the log on the clipboard
##   for bug reports; the seed is printed with every fight so it can be replayed.

const MAX_LINES: int = 2000
const TOGGLE_KEY: Key = KEY_QUOTELEFT
## Normal speed: 2x fight time, so 20 ticks per real second.
const LIVE_TICKS_PER_SECOND: float = 20.0
const CAGE_VIEW_WIDTH: float = 780.0
## The matchups "Live fight" can play: [label, red id, blue id] from data/fighters.
const MATCHUPS: Array = [
	["Wrestler vs Kicker", "wrestler", "kicker"],
	["Kicker vs Boxer", "kicker", "boxer"],
	["Wrestler vs Boxer", "wrestler", "boxer"],
]

## Also print every line to Godot's Output panel (and the terminal).
var echo_to_output: bool = true

var _log: RichTextLabel
var _live_button: Button
var _details_toggle: CheckBox
var _matchup: OptionButton
var _cage_toggle: CheckBox
var _cage_map: CageMap
var _call_buttons: Array[Button] = []
var _voice_label: Label
var _rule_pickers: Array[OptionButton] = []
var _drilled: HSlider
var _drilled_label: Label
var _rules: RuleLibrary
var _actions: ActionLibrary
var _calls: CallLibrary
var _live_sim: FightSim
var _live_paused: bool = false
var _tick_budget: float = 0.0


func _ready() -> void:
	_actions = ActionLibrary.load_dir()
	_calls = CallLibrary.shared()
	_rules = RuleLibrary.shared()
	_build()
	write("[b]Debug console[/b]  (press ` to hide/show)")
	write("Loaded %d moves from data/actions." % _actions.ids().size())


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == TOGGLE_KEY:
		visible = not visible
		get_viewport().set_input_as_handled()
	elif _live() and event.keycode >= KEY_0 and event.keycode <= KEY_9:
		for id in _calls.ids():
			var key: Variant = _calls.get_call(id).get("hotkey")
			if key != null and int(key) == event.keycode - KEY_0:
				make_call(id)
				get_viewport().set_input_as_handled()


## Red's corner makes a call in the live fight (lands on the next tick, paused or not).
func make_call(id: String) -> void:
	if _live():
		_live_sim.submit(FightCommand.live_call(_live_sim.now, 0, id))


func _live() -> bool:
	return _live_sim != null and not _live_sim.is_over()


func _process(delta: float) -> void:
	_show_corner()
	if _live_sim == null or _live_paused or _live_sim.is_over():
		return
	_tick_budget += delta * LIVE_TICKS_PER_SECOND
	while _tick_budget >= 1.0 and not _live_sim.is_over():
		_tick_budget -= 1.0
		_live_sim.tick()
		_cage_map.sample()
	if _live_sim.is_over():
		_print_summary(_live_sim)
		_live_button.text = "Live fight"


## Adds one line (BBCode) to the console and to Godot's Output panel.
func write(text: String) -> void:
	_log.append_text(text + "\n")
	while _log.get_paragraph_count() > MAX_LINES:
		_log.remove_paragraph(0)
	if echo_to_output:
		print_rich(text)


func run_test_fight() -> SimCheck:
	_stop_live()
	var fight_seed: int = randi()
	write("")
	write("[b]▶ Test fight[/b]  seed %d, 1 round of %d s" % [fight_seed, SimCheck.ROUND_SECONDS])
	var check: SimCheck = SimCheck.run(fight_seed, _actions)
	if check.sim != null:
		for e in check.sim.events:
			_write_event(e, check.sim)
		_print_summary(check.sim)
	for r in check.results:
		var colour: String = FightLogFormatter.PASS_COLOUR if r.passed else FightLogFormatter.FAIL_COLOUR
		write("[color=%s]%s %s[/color]  [color=%s](%s)[/color]" % [
			colour, "✔" if r.passed else "✘", r.name, FightLogFormatter.DIM_COLOUR, r.detail])
	if check.passed():
		write("[color=%s][b]All %d checks passed.[/b][/color]" % [FightLogFormatter.PASS_COLOUR, check.results.size()])
	else:
		write("[color=%s][b]Something is wrong: see the ✘ lines above.[/b][/color]" % FightLogFormatter.FAIL_COLOUR)
	return check


func _toggle_live() -> void:
	if _live_sim != null and not _live_sim.is_over():
		_live_paused = not _live_paused
		_live_button.text = "Resume" if _live_paused else "Pause"
		write("[color=%s]%s[/color]" % [FightLogFormatter.DIM_COLOUR, "Paused" if _live_paused else "Resumed"])
		return
	var fight_seed: int = randi()
	var pick: Array = MATCHUPS[maxi(0, _matchup.selected)]
	_live_sim = FightSim.new(fight_seed, FighterLibrary.load_dir().make_pair(pick[1], pick[2]), _actions)
	# Blue's corner coaches too (D68): its calls show in the log as "<Blue>'s corner: …".
	_live_sim.corners[1] = Corner.new(Corner.AI, fight_seed)
	_live_sim.event_emitted.connect(_on_live_event)
	for slot in _rule_pickers.size():
		var pick_rule: int = _rule_pickers[slot].selected
		if pick_rule > 0:
			_live_sim.submit(FightCommand.set_rule(0, 0, slot + 1, _rules.ids()[pick_rule - 1], _drilled.value))
	_cage_map.watch(_live_sim)
	_cage_map.sample()
	_live_paused = false
	_tick_budget = 0.0
	_live_button.text = "Pause"
	write("")
	write("[b]▶ Live fight[/b]  %s, seed %d, 3 rounds of 5:00 at 2x speed" % [pick[0], fight_seed])
	write("[color=%s]You're %s's corner (keys 1–9, 0). %s's corner is the AI and calls too.[/color]" % [
		FightLogFormatter.DIM_COLOUR, _live_sim.fighters[0].name, _live_sim.fighters[1].name])


func _stop_live() -> void:
	if _live_sim != null and not _live_sim.is_over():
		write("[color=%s]Live fight stopped.[/color]" % FightLogFormatter.DIM_COLOUR)
	_live_sim = null
	_cage_map.watch(null)
	_live_button.text = "Live fight"


## The call bar is live only in a live fight; the label shows both corners' voice and trust.
func _show_corner() -> void:
	var live: bool = _live()
	for b in _call_buttons:
		b.disabled = not live
	if live:
		var calls: LiveCalls = _live_sim.decisions[0].calls
		var theirs: LiveCalls = _live_sim.decisions[1].calls
		_voice_label.text = "Red's corner · voice %d · trust %d   (Blue's AI corner · voice %d)" % [
			roundi(calls.voice(_live_sim.now)), roundi(calls.trust), roundi(theirs.voice(_live_sim.now))]
	else:
		_voice_label.text = "Calls (live fight only):"


func _on_live_event(event: FightEvent) -> void:
	_write_event(event, _live_sim)


func _write_event(event: FightEvent, sim: FightSim) -> void:
	if FightLogFormatter.is_detail(event) and not _details_toggle.button_pressed:
		return
	write(FightLogFormatter.line(event, sim))


func _print_summary(sim: FightSim) -> void:
	for f in sim.fighters:
		write("  %s landed %d of %d strikes, damage taken: head %d, body %d, legs %d" % [
			f.name, f.strikes_landed, f.strikes_thrown, f.damage.head, f.damage.body, f.damage.legs])
		write("  [color=%s]%s[/color]" % [FightLogFormatter.DIM_COLOUR, FightLogFormatter.condition_line(f)])


func _build() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = -720.0
	offset_top = 64.0
	offset_right = -16.0
	offset_bottom = -16.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.09, 0.88)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	add_child(column)
	var bar := HBoxContainer.new()
	column.add_child(bar)
	_add_button(bar, "Run test fight", run_test_fight)
	_live_button = _add_button(bar, "Live fight", _toggle_live)
	_matchup = OptionButton.new()
	for m: Array in MATCHUPS:
		_matchup.add_item(m[0])
	bar.add_child(_matchup)
	_details_toggle = CheckBox.new()
	_details_toggle.text = "Phase details"
	bar.add_child(_details_toggle)
	_cage_toggle = CheckBox.new()
	_cage_toggle.text = "Cage view"
	_cage_toggle.button_pressed = true
	_cage_toggle.toggled.connect(func(on: bool) -> void: _cage_map.visible = on)
	bar.add_child(_cage_toggle)
	_add_button(bar, "Copy", func() -> void: DisplayServer.clipboard_set(_log.get_parsed_text()))
	_add_button(bar, "Clear", func() -> void: _log.clear())

	var call_bar := HFlowContainer.new()
	column.add_child(call_bar)
	_voice_label = Label.new()
	call_bar.add_child(_voice_label)
	for id in _calls.ids():
		var call: Dictionary = _calls.get_call(id)
		var key: Variant = call.get("hotkey")
		var label: String = String(call.name).trim_suffix("!")
		_call_buttons.append(_add_button(call_bar, "%d %s" % [int(key), label] if key != null else label, make_call.bind(id)))
	_show_corner()

	var rule_bar := HFlowContainer.new()
	column.add_child(rule_bar)
	for slot in DrilledRules.MAX_SLOTS:
		var label := Label.new()
		label.text = "Rule %d:" % (slot + 1)
		rule_bar.add_child(label)
		var picker := OptionButton.new()
		picker.add_item("none")
		for id in _rules.ids():
			picker.add_item(_rules.get_rule(id).name)
		rule_bar.add_child(picker)
		_rule_pickers.append(picker)
	_drilled_label = Label.new()
	rule_bar.add_child(_drilled_label)
	_drilled = HSlider.new()
	_drilled.min_value = 0.0
	_drilled.max_value = 100.0
	_drilled.step = 5.0
	_drilled.value = 80.0
	_drilled.custom_minimum_size = Vector2(140.0, 0.0)
	_drilled.value_changed.connect(func(v: float) -> void: _drilled_label.text = "Drilled %d%%" % roundi(v))
	_drilled_label.text = "Drilled %d%%" % roundi(_drilled.value)
	rule_bar.add_child(_drilled)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.selection_enabled = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", 15)
	_log.add_theme_font_size_override("bold_font_size", 15)
	column.add_child(_log)

	# Not laid out by this panel: it sits on the left of the screen, outside the console.
	_cage_map = CageMap.new()
	_cage_map.top_level = true
	_cage_map.anchor_bottom = 1.0
	_cage_map.offset_left = 16.0
	_cage_map.offset_top = 64.0
	_cage_map.offset_right = 16.0 + CAGE_VIEW_WIDTH
	_cage_map.offset_bottom = -16.0
	_cage_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cage_map)


func _add_button(parent: Control, label: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.pressed.connect(on_press)
	parent.add_child(button)
	return button
