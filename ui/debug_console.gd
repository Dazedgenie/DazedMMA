class_name DebugConsole
extends PanelContainer
## Developer console: shows what the fight engine is doing, line by line.
##
## - "Run test fight" plays a short check fight instantly and reports pass/fail (SimCheck).
## - "Live fight" plays a full fight in real time at Normal speed (2x, docs/01 §2).
## - Toggle the window with the ` key (left of 1). "Copy" puts the log on the clipboard
##   for bug reports; the seed is printed with every fight so it can be replayed.

const MAX_LINES: int = 2000
const TOGGLE_KEY: Key = KEY_QUOTELEFT
## Normal speed: 2x fight time, so 20 ticks per real second.
const LIVE_TICKS_PER_SECOND: float = 20.0

## Also print every line to Godot's Output panel (and the terminal).
var echo_to_output: bool = true

var _log: RichTextLabel
var _live_button: Button
var _details_toggle: CheckBox
var _actions: ActionLibrary
var _live_sim: FightSim
var _live_paused: bool = false
var _tick_budget: float = 0.0


func _ready() -> void:
	_actions = ActionLibrary.load_dir()
	_build()
	write("[b]Debug console[/b]  (press ` to hide/show)")
	write("Loaded %d moves from data/actions." % _actions.ids().size())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == TOGGLE_KEY:
		visible = not visible
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _live_sim == null or _live_paused or _live_sim.is_over():
		return
	_tick_budget += delta * LIVE_TICKS_PER_SECOND
	while _tick_budget >= 1.0 and not _live_sim.is_over():
		_tick_budget -= 1.0
		_live_sim.tick()
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
	_live_sim = FightSim.new(fight_seed, SimCheck.showcase_fighters(), _actions)
	_live_sim.event_emitted.connect(_on_live_event)
	_live_paused = false
	_tick_budget = 0.0
	_live_button.text = "Pause"
	write("")
	write("[b]▶ Live fight[/b]  seed %d, 3 rounds of 5:00 at 2x speed" % fight_seed)


func _stop_live() -> void:
	if _live_sim != null and not _live_sim.is_over():
		write("[color=%s]Live fight stopped.[/color]" % FightLogFormatter.DIM_COLOUR)
	_live_sim = null
	_live_button.text = "Live fight"


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
	_details_toggle = CheckBox.new()
	_details_toggle.text = "Phase details"
	bar.add_child(_details_toggle)
	_add_button(bar, "Copy", func() -> void: DisplayServer.clipboard_set(_log.get_parsed_text()))
	_add_button(bar, "Clear", func() -> void: _log.clear())

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.selection_enabled = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", 15)
	_log.add_theme_font_size_override("bold_font_size", 15)
	column.add_child(_log)


func _add_button(parent: Control, label: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.pressed.connect(on_press)
	parent.add_child(button)
	return button
