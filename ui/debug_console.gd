class_name DebugConsole
extends PanelContainer
## Developer console: shows what the fight engine is doing, line by line.
##
## - "Run test fight" plays a short check fight instantly and reports pass/fail (SimCheck).
## - The fight on screen (game/main.gd, #19) is logged here as it happens: every event
##   with its odds and reasons, and both fighters' condition at the end. "Phase details"
##   adds each move's phase changes.
## - Toggle the window with the ` key (left of 1); it starts hidden. "Copy" puts the log
##   on the clipboard for bug reports; the seed is printed with every fight so it can be replayed.

const MAX_LINES: int = 2000
const TOGGLE_KEY: Key = KEY_QUOTELEFT

## Also print every line to Godot's Output panel (and the terminal).
var echo_to_output: bool = true

var _log: RichTextLabel
var _details_toggle: CheckBox
var _actions: ActionLibrary
## The fight being logged as it happens (the one on screen).
var _watched: FightSim


func _ready() -> void:
	_actions = ActionLibrary.load_dir()
	_build()
	visible = false
	write("[b]Debug console[/b]  (press ` to hide/show)")
	write("Loaded %d moves from data/actions." % _actions.ids().size())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == TOGGLE_KEY:
		visible = not visible
		get_viewport().set_input_as_handled()


## Logs this fight's events as they happen, and its summary when it ends (null stops).
func watch(sim: FightSim, title: String = "") -> void:
	if _watched != null and _watched.event_emitted.is_connected(_on_watched_event):
		_watched.event_emitted.disconnect(_on_watched_event)
	_watched = sim
	if sim == null:
		return
	sim.event_emitted.connect(_on_watched_event)
	write("")
	write("[b]▶ Fight[/b]  %s" % title)
	write("[color=%s]Red: %s (your corner) · Blue: %s (the AI corner calls for him)[/color]" % [
		FightLogFormatter.DIM_COLOUR, sim.fighters[0].name, sim.fighters[1].name])


## Adds one line (BBCode) to the console and to Godot's Output panel.
func write(text: String) -> void:
	_log.append_text(text + "\n")
	while _log.get_paragraph_count() > MAX_LINES:
		_log.remove_paragraph(0)
	if echo_to_output:
		print_rich(text)


func run_test_fight() -> SimCheck:
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


func _on_watched_event(event: FightEvent) -> void:
	_write_event(event, _watched)
	if event.type == FightEvent.FIGHT_ENDED:
		_print_summary(_watched)


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
