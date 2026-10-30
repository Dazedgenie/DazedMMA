class_name FightHud
extends Control
## HUD v0 for the fight screen (#19, docs/06 §1–§2): the top bar (names, a body figure
## with head, body and leg damage (D150), stamina, round clock, speed, the judges' rough estimate), the plan panel
## (drilled rules with reliability and cooldown, the call being acted on, primed
## reads), the opponent corner's speech bubble (D68), the feed, the voice meter and
## the call bar, and while a submission is locked in, the danger meter (D126). One dialog in the middle serves the bell, the result, the menu and
## the towel question. Presentation only: buttons send signals, the fight screen acts.
##
## Laid out for 1920×1080; the project's canvas_items stretch scales it to the window.

signal call_pressed(call_id: String)
## "slow", "fast", "pause" or "towel".
signal control_pressed(which: String)

const PANEL := Color(0.06, 0.07, 0.09, 0.82)
const FIGHTER_COLOURS: Array[Color] = [Color("#ff6b6b"), Color("#5fa8ff")]
const PIP_COLOURS: Array[Color] = [Color("#51cf66"), Color("#fcc419"), Color("#ff6b6b")]
## The figure's readout, top to bottom (D150): what's left of each area, 1 − hurt.
## Head is health (D120): at 0 the referee stops it.
const AREAS: Array[String] = ["head", "body", "legs"]
## The top bar's figure, at 1080p.
const FIGURE_SIZE := Vector2(60.0, 96.0)
## Real seconds the opponent corner's call stays up, a fired rule flashes, the banner shows.
## The ground position diagram's height on the left (D210); its panel sits just above the call bar.
const DIAGRAM_HEIGHT: float = 220.0
const BUBBLE_SECONDS: float = 3.0
const FLASH_SECONDS: float = 1.2
const BANNER_SECONDS: float = 1.6
## The read-call slots, in order (docs/06 §3).
const READ_KEYS: Array[String] = ["Q", "E"]

var driver: FightDriver
var feed: FightFeed

var _names: Array[Label] = []
var _stamina: Array[ProgressBar] = []
var _figures: Array[BodyDamageFigure] = []
var _area_labels: Array = [[], []]  # per fighter: [head, body, legs] Labels
var _rocked: Array[Label] = []
var _clock: Label
var _speed: Label
var _judges: Label
var _plan: RichTextLabel
var _bubble: PanelContainer
var _bubble_label: Label
var _voice: VoiceMeter
var _voice_label: Label
var _call_bar: HFlowContainer
var _call_buttons: Dictionary = {}  # call id → Button
var _read_ids: Array[String] = []
var _speed_buttons: Dictionary = {}  # "slow"/"fast"/"pause" → Button
var _banner: Label
var _danger_panel: PanelContainer
var _position_panel: PanelContainer
var _position_label: Label
var _diagram: PositionDiagram
var _danger_label: Label
var _danger: ProgressBar
var _dialog: PanelContainer
var _dialog_title: Label
var _dialog_body: RichTextLabel
var _dialog_extra: VBoxContainer
var _dialog_buttons: HBoxContainer
var _bubble_left: float = 0.0
var _banner_left: float = 0.0
var _flash_left: Array[float] = [0.0, 0.0]  # per rule slot
var _plan_every: float = 0.0
## The calls the call bar offers ([] = all): a playtest fight starts with a few (D118, docs/07 §1).
var allowed_calls: Array = []
## Easy difficulty: the Pause button is live (D50).
var pause_allowed: bool = false:
	set(value):
		pause_allowed = value
		if _speed_buttons.has("pause"):
			_speed_buttons.pause.visible = value


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


## Starts showing a fight.
func watch(p_driver: FightDriver) -> void:
	driver = p_driver
	feed.clear()
	hide_dialog()
	_bubble.visible = false
	_banner.visible = false
	var sim: FightSim = driver.sim
	for i in 2:
		_names[i].text = sim.fighters[i].name + ("  (your corner)" if i == driver.player else "")
	sim.event_emitted.connect(_on_event.bind(sim))
	driver.flourish.connect(_on_flourish)
	_build_calls(sim)
	_refresh(0.0)


func _process(delta: float) -> void:
	if driver != null:
		_refresh(delta)


## Why the player's corner can't make this call right now, or "" when it can (dims the button).
static func call_problem(sim: FightSim, i: int, call: Dictionary) -> String:
	if sim.is_over():
		return "the fight is over"
	if sim.decisions[i].calls.voice(sim.now) < float(call.get("voice_cost", 0)):
		return "not enough voice"
	var positions: Array = call.get("positions", [])
	if not positions.is_empty() and not positions.has(sim.situation.position):
		return "not from here"
	if call.has("roles") and not call.roles.has(sim.situation.role(i)):
		return "not from the %s" % sim.situation.role(i)
	var technique: Variant = call.get("requires_technique")
	if technique != null and not sim.fighters[i].repertoire.has(technique):
		return "not learned"
	return ""


## Is this call on the call bar in this fight?
func is_allowed(id: String) -> bool:
	return allowed_calls.is_empty() or allowed_calls.has(id)


## The judges' rough score for the round so far (docs/06 §2), e.g. "≈ 10-9 Wrestler".
static func judges_estimate(sim: FightSim) -> String:
	if sim.ruleset.judging == Ruleset.WHOLE_FIGHT:
		var lean: Dictionary = Judging.whole_fight_pick(sim.fight_scores())
		if int(lean.winner) < 0:
			return "Judges: nothing in it yet"
		return "Judges: ≈ %s (%s)" % [sim.fighters[int(lean.winner)].name, FightLogFormatter.JUDGED_ON[lean.on]]
	var points: Array[float] = sim.round_points()
	if points[0] + points[1] < 1.0:
		return "Judges: nothing in it yet"
	var card: Array[int] = Judging.round_card(points, [0, 0], [], sim.round_impact())
	if card[0] == card[1]:
		return "Judges: ≈ even"
	var w: int = 0 if card[0] > card[1] else 1
	return "Judges: ≈ %d-%d %s" % [card[w], card[1 - w], sim.fighters[w].name]


## The submission meter's words (D126), e.g. "Kicker's TRIANGLE CHOKE on Wrestler · danger 60";
## "" when no hold is locked in.
static func danger_text(sim: FightSim) -> String:
	var hold: Dictionary = sim.hold()
	if hold.is_empty():
		return ""
	var a: int = int(hold.attacker)
	var hold_name: String = String(sim.actions.get_action(hold.action_id).name).to_upper()
	return "%s's %s on %s · danger %d" % [sim.fighters[a].name, hold_name, sim.fighters[1 - a].name, roundi(maxf(0.0, float(hold.danger)))]


## One line of the figure's readout, e.g. "HEAD 65%": what's left of that area.
## The ground diagram's caption (D210): the position and who's on top, or the hold and where it was locked from.
static func position_text(sim: FightSim) -> String:
	var where: String = PositionDiagram.position_for(sim)
	if where == "":
		return ""
	var name: String = String(sim.positions.get_position(where).name).to_upper()
	var hold: Dictionary = sim.hold()
	if not hold.is_empty():
		return "%s FROM %s" % [String(sim.actions.get_action(hold.action_id).name).to_upper(), name]
	var top: int = sim.situation.roles.find(PositionLibrary.TOP)
	if top < 0:
		return name
	return "%s · %s %s" % [name, sim.fighters[top].name.to_upper(), sim.positions.top_label(where).to_upper()]


static func area_text(f: FighterState, area: String) -> String:
	return "%s %d%%" % [area.to_upper(), roundi((1.0 - f.hurt(area)) * 100.0)]


## The plan panel's text (BBCode): rules, the call being acted on, primed reads.
static func plan_text(sim: FightSim, i: int, flashing: Array[float] = [0.0, 0.0]) -> String:
	var lines: Array[String] = ["[b]PLAN[/b]  [color=#8a8f98]own game[/color]", "", "[b]Rules[/b]"]
	var rules: DrilledRules = sim.decisions[i].rules
	for n in rules.slots.size():
		var entry: Dictionary = rules.slots[n]
		if entry.is_empty():
			lines.append("%d  [color=#8a8f98]empty[/color]" % (n + 1))
			continue
		var reliability: int = roundi(rules.reliability(sim.views[i], entry) * 100.0)
		var wait: int = int(entry.ready_at) - sim.now
		var timer: String = "ready" if wait <= 0 else "%d s" % ceili(float(wait) / FightClock.TICKS_PER_SECOND)
		var colour: String = "#69db7c" if flashing[n] > 0.0 else "#e9ecef"
		lines.append("[color=%s]%d  %s[/color]" % [colour, n + 1, entry.rule.name])
		lines.append("    %d%% sharp · %s" % [reliability, timer])
	var calls: LiveCalls = sim.decisions[i].calls
	lines.append("")
	lines.append("[b]Calls[/b]")
	var any: bool = false
	for heard: Dictionary in calls.pending:
		lines.append("[color=#ffc94d]%s[/color]  hearing it…" % heard.call.name)
		any = true
	if not calls.attempt.is_empty():
		lines.append("[color=#ffc94d]%s[/color]  going for it" % calls.attempt.call.name)
		any = true
	if not calls.focus.is_empty():
		lines.append("%s  %d s" % [calls.focus.call.name, _seconds_left(sim, int(calls.focus.until))])
		any = true
	for read: Dictionary in calls.reads:
		lines.append("[color=#66d9e8]%s[/color]  primed %d s" % [read.call.name, _seconds_left(sim, int(read.until))])
		any = true
	if not any:
		lines.append("[color=#8a8f98]none[/color]")
	return "\n".join(lines)


static func _seconds_left(sim: FightSim, until: int) -> int:
	return maxi(0, ceili(float(until - sim.now) / FightClock.TICKS_PER_SECOND))


## Shows the dialog in the middle. `buttons`: [[label, Callable], …]; `extra` goes under the text.
func show_dialog(title: String, body: String, buttons: Array, extra: Control = null) -> void:
	_dialog_title.text = title
	_dialog_body.text = body
	for c in _dialog_extra.get_children():
		_dialog_extra.remove_child(c)
		c.queue_free()
	if extra != null:
		_dialog_extra.add_child(extra)
	for c in _dialog_buttons.get_children():
		_dialog_buttons.remove_child(c)
		c.queue_free()
	for entry: Array in buttons:
		var b := Button.new()
		b.text = entry[0]
		b.pressed.connect(entry[1])
		b.custom_minimum_size = Vector2(180.0, 48.0)
		_dialog_buttons.add_child(b)
	_dialog.visible = true
	if _dialog_buttons.get_child_count() > 0:
		focus_later(_dialog_buttons.get_child(0) as Control)


## Gives a control the keyboard focus after this frame, if it's still on screen then.
static func focus_later(control: Control) -> void:
	var ref: WeakRef = weakref(control)
	(func() -> void:
		var c: Control = ref.get_ref() as Control
		if c != null and c.is_visible_in_tree():
			c.grab_focus()).call_deferred()


func hide_dialog() -> void:
	_dialog.visible = false


func dialog_open() -> bool:
	return _dialog.visible


func dialog_title() -> String:
	return _dialog_title.text if _dialog.visible else ""


## A big line in the middle of the screen for a moment ("PERFECT CALL", "Round 2").
func show_banner(text: String, colour: Color = Color.WHITE) -> void:
	_banner.text = text
	_banner.modulate = colour
	_banner.visible = true
	_banner_left = BANNER_SECONDS


## The call bar's button for a call (tests).
func call_button(id: String) -> Button:
	return _call_buttons.get(id)


func read_call(slot: int) -> String:
	return _read_ids[slot] if slot < _read_ids.size() else ""


func _refresh(delta: float) -> void:
	var sim: FightSim = driver.sim
	for i in 2:
		var f: FighterState = sim.fighters[i]
		_stamina[i].max_value = f.max_stamina()
		_stamina[i].value = f.stamina
		_figures[i].show_fighter(f)
		for a in AREAS.size():
			var label: Label = _area_labels[i][a]
			label.text = area_text(f, AREAS[a])
			label.add_theme_color_override("font_color", BodyDamageFigure.damage_colour(f.hurt(AREAS[a])))
		_rocked[i].visible = f.is_rocked()
	_clock.text = sim.clock.display()
	_speed.text = "▶ " + driver.label()
	_judges.text = judges_estimate(sim)
	var calls: LiveCalls = sim.decisions[driver.player].calls
	_voice.value = calls.voice(sim.now)
	_voice_label.text = "VOICE %d · trust %d" % [roundi(_voice.value), roundi(calls.trust)]
	for id: String in _call_buttons:
		var b: Button = _call_buttons[id]
		var why: String = call_problem(sim, driver.player, sim.calls.get_call(id))
		b.disabled = why != ""
		b.tooltip_text = why if why != "" else String(sim.calls.get_call(id).name)
		var live: bool = (not calls.focus.is_empty() and calls.focus.call.id == id) \
			or (not calls.attempt.is_empty() and calls.attempt.call.id == id)
		for read: Dictionary in calls.reads:
			live = live or read.call.id == id
		b.modulate = Color("#b2f2bb") if live else Color.WHITE
	var hold: Dictionary = sim.hold()
	_danger_panel.visible = not hold.is_empty()
	if not hold.is_empty():
		_danger.value = clampf(float(hold.danger), 0.0, FightSim.SUB_TAP)
		_danger_label.text = danger_text(sim)
	_diagram.show_fight(sim, FIGHTER_COLOURS)
	_position_panel.visible = _diagram.where != ""
	if _position_panel.visible:
		_position_label.text = position_text(sim)
	_speed_buttons.slow.button_pressed = driver.speed == FightDriver.SLOW
	_speed_buttons.fast.button_pressed = driver.speed == FightDriver.FAST
	_speed_buttons.pause.button_pressed = driver.paused
	_bubble_left = maxf(0.0, _bubble_left - delta)
	_bubble.visible = _bubble_left > 0.0
	_banner_left = maxf(0.0, _banner_left - delta)
	_banner.visible = _banner_left > 0.0
	for n in _flash_left.size():
		_flash_left[n] = maxf(0.0, _flash_left[n] - delta)
	_plan_every -= delta
	if _plan_every <= 0.0:
		_plan_every = 0.1
		_plan.text = plan_text(sim, driver.player, _flash_left)


func _on_event(event: FightEvent, sim: FightSim) -> void:
	feed.add_event(event, sim)
	match event.type:
		FightEvent.STRIKE_LANDED:
			_figures[1 - event.actor].flash(String(event.data.target), int(event.data.get("leg", -1)))
		FightEvent.CALL_HEARD:
			if event.actor != driver.player:
				_bubble_label.text = "%s's corner: \"%s\"" % [sim.fighters[event.actor].name, String(sim.calls.get_call(event.data.call_id).name) if sim.calls.has(event.data.call_id) else event.data.call_id]
				_bubble_left = BUBBLE_SECONDS
			elif event.data.get("spam", false):
				_voice.shake()
		FightEvent.RULE_ANSWERED:
			if event.actor == driver.player and event.data.outcome == DrilledRules.FIRED:
				var slot: int = int(event.data.get("slot", 1)) - 1
				if slot >= 0 and slot < _flash_left.size():
					_flash_left[slot] = FLASH_SECONDS


func _on_flourish(event: FightEvent) -> void:
	show_banner("PERFECT CALL", Color("#ffe066"))
	var sim: FightSim = driver.sim
	var move: String = String(sim.actions.get_action(event.data.action_id).name) if sim.actions.has(event.data.action_id) else ""
	feed.add_line(FightFeed.KEY_MOMENT, "[color=#ffe066][b]Perfect call![/b] The %s landed right in the opening.[/color]" % move.to_lower())


func _build_calls(sim: FightSim) -> void:
	for c in _call_bar.get_children():
		_call_bar.remove_child(c)
		c.queue_free()
	_call_buttons.clear()
	_read_ids.clear()
	for id in sim.calls.ids():
		if not is_allowed(id):
			continue
		var call: Dictionary = sim.calls.get_call(id)
		if call.get("kind", "now") == LiveCalls.READ:
			_read_ids.append(id)
			continue
		var key: Variant = call.get("hotkey")
		var label: String = String(call.name).trim_suffix("!")
		_add_call_button(id, "%d %s" % [int(key), label] if key != null else label)
	for n in READ_KEYS.size():
		if n < _read_ids.size():
			_add_call_button(_read_ids[n], "%s %s" % [READ_KEYS[n], String(sim.calls.get_call(_read_ids[n]).name).trim_suffix("!")])
		else:
			var empty := Button.new()
			empty.text = "%s  —" % READ_KEYS[n]
			empty.disabled = true
			empty.focus_mode = Control.FOCUS_NONE
			empty.tooltip_text = "no read call here yet"
			_call_bar.add_child(empty)


## A top-bar meter, filling from the fighter's own side: red from the left, blue from the right.
func _bar(i: int, height: float, colour: Color, max_value: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = max_value
	bar.value = max_value
	bar.custom_minimum_size = Vector2(0.0, height)
	bar.fill_mode = ProgressBar.FILL_BEGIN_TO_END if i == 0 else ProgressBar.FILL_END_TO_BEGIN
	var fill := StyleBoxFlat.new()
	fill.bg_color = colour
	bar.add_theme_stylebox_override("fill", fill)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.1)
	bar.add_theme_stylebox_override("background", back)
	return bar


func _add_call_button(id: String, label: String) -> void:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0.0, 40.0)
	b.add_theme_font_size_override("font_size", 19)
	b.pressed.connect(func() -> void: call_pressed.emit(id))
	_call_bar.add_child(b)
	_call_buttons[id] = b


func _build() -> void:
	# Top bar.
	var top: PanelContainer = _panel()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16.0
	top.offset_right = -16.0
	top.offset_top = 12.0
	top.offset_bottom = 180.0
	add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	top.add_child(row)
	for i in 2:
		var block := VBoxContainer.new()
		block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label := Label.new()
		DisplayFont.apply(name_label, 32)
		name_label.add_theme_color_override("font_color", FIGHTER_COLOURS[i])
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		block.add_child(name_label)
		_names.append(name_label)
		var figure_row := HBoxContainer.new()
		figure_row.alignment = BoxContainer.ALIGNMENT_BEGIN if i == 0 else BoxContainer.ALIGNMENT_END
		figure_row.add_theme_constant_override("separation", 12)
		var figure := BodyDamageFigure.new()
		figure.custom_minimum_size = FIGURE_SIZE
		figure.tooltip_text = "damage: green is fresh, red is badly hurt. Head is health (at 0 the referee stops it); body damage shrinks the stamina tank; leg damage slows footwork, speed and kicks"
		_figures.append(figure)
		var readout := VBoxContainer.new()
		readout.alignment = BoxContainer.ALIGNMENT_CENTER
		readout.add_theme_constant_override("separation", 0)
		for area in AREAS:
			var line := Label.new()
			line.add_theme_font_size_override("font_size", 18)
			line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
			readout.add_child(line)
			_area_labels[i].append(line)
		var rocked := Label.new()
		rocked.text = "ROCKED"
		DisplayFont.apply(rocked, 22)
		rocked.add_theme_color_override("font_color", PIP_COLOURS[2])
		rocked.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		rocked.visible = false
		readout.add_child(rocked)
		_rocked.append(rocked)
		figure_row.add_child(figure if i == 0 else readout)
		figure_row.add_child(readout if i == 0 else figure)
		block.add_child(figure_row)
		var bar: ProgressBar = _bar(i, 12.0, FIGHTER_COLOURS[i], 100.0)
		bar.tooltip_text = "stamina"
		block.add_child(bar)
		_stamina.append(bar)
		if i == 1:
			row.add_child(_centre_block())
		row.add_child(block)

	# Plan panel (left).
	var plan_panel: PanelContainer = _panel()
	plan_panel.offset_left = 16.0
	plan_panel.offset_top = 196.0
	plan_panel.offset_right = 376.0
	add_child(plan_panel)
	_plan = RichTextLabel.new()
	_plan.bbcode_enabled = true
	_plan.fit_content = true
	_plan.scroll_active = false
	_plan.custom_minimum_size = Vector2(340.0, 0.0)
	_plan.add_theme_font_size_override("normal_font_size", 18)
	_plan.add_theme_font_size_override("bold_font_size", 18)
	plan_panel.add_child(_plan)

	# Ground position diagram (left, above the call bar; D210): only while the fight is on the ground.
	_position_panel = _panel()
	_position_panel.anchor_top = 1.0
	_position_panel.anchor_bottom = 1.0
	_position_panel.offset_left = 16.0
	_position_panel.offset_right = 376.0
	_position_panel.offset_top = -164.0 - DIAGRAM_HEIGHT - 60.0
	_position_panel.offset_bottom = -164.0
	_position_panel.visible = false
	add_child(_position_panel)
	var position_column := VBoxContainer.new()
	_position_panel.add_child(position_column)
	_position_label = Label.new()
	_position_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_position_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	DisplayFont.apply(_position_label, 24)
	position_column.add_child(_position_label)
	_diagram = PositionDiagram.new()
	_diagram.custom_minimum_size = Vector2(0.0, DIAGRAM_HEIGHT)
	_diagram.size_flags_vertical = Control.SIZE_EXPAND_FILL
	position_column.add_child(_diagram)

	# Opponent corner (right, above the feed).
	_bubble = _panel(Color(0.98, 0.97, 0.9, 0.95))
	_bubble.anchor_left = 1.0
	_bubble.anchor_right = 1.0
	_bubble.offset_left = -496.0
	_bubble.offset_right = -16.0
	_bubble.offset_top = 196.0
	add_child(_bubble)
	_bubble_label = Label.new()
	_bubble_label.add_theme_color_override("font_color", Color("#212529"))
	_bubble_label.add_theme_font_size_override("font_size", 20)
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.add_child(_bubble_label)
	_bubble.visible = false

	# Feed (right).
	feed = FightFeed.new()
	feed.add_theme_stylebox_override("panel", _panel_style(PANEL))
	feed.anchor_left = 1.0
	feed.anchor_right = 1.0
	feed.anchor_bottom = 1.0
	feed.offset_left = -496.0
	feed.offset_right = -16.0
	feed.offset_top = 268.0
	feed.offset_bottom = -164.0
	add_child(feed)

	# Bottom: voice meter, speed controls, call bar.
	var bottom: PanelContainer = _panel()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 16.0
	bottom.offset_right = -16.0
	bottom.offset_top = -148.0
	bottom.offset_bottom = -12.0
	add_child(bottom)
	var column := VBoxContainer.new()
	bottom.add_child(column)
	var voice_row := HBoxContainer.new()
	voice_row.add_theme_constant_override("separation", 16)
	column.add_child(voice_row)
	_voice_label = Label.new()
	_voice_label.custom_minimum_size = Vector2(220.0, 0.0)
	_voice_label.add_theme_font_size_override("font_size", 18)
	voice_row.add_child(_voice_label)
	_voice = VoiceMeter.new()
	_voice.custom_minimum_size = Vector2(420.0, 26.0)
	_voice.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_voice.tooltip_text = "Every call costs voice; under 30 your calls come out garbled"
	voice_row.add_child(_voice)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	voice_row.add_child(spacer)
	for entry: Array in [["slow", "Slow-mo [Space]"], ["fast", "Fast 4× [F]"], ["pause", "Pause [P]"], ["towel", "Towel [T]"]]:
		var b := Button.new()
		b.text = entry[1]
		b.toggle_mode = entry[0] != "towel"
		b.focus_mode = Control.FOCUS_NONE
		var which: String = entry[0]
		b.pressed.connect(func() -> void: control_pressed.emit(which))
		voice_row.add_child(b)
		_speed_buttons[which] = b
	_speed_buttons.pause.visible = pause_allowed
	_call_bar = HFlowContainer.new()
	_call_bar.add_theme_constant_override("h_separation", 8)
	column.add_child(_call_bar)

	# Middle: the banner and the dialog.
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_top = 230.0
	_banner.offset_left = -500.0
	_banner.offset_right = 500.0
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	DisplayFont.apply(_banner, 76)
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner.add_theme_constant_override("outline_size", 12)
	_banner.visible = false
	add_child(_banner)

	# Middle: the submission danger meter (D126), while a hold is locked in.
	_danger_panel = _panel()
	_danger_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_danger_panel.offset_top = 320.0
	_danger_panel.offset_left = -360.0
	_danger_panel.offset_right = 360.0
	add_child(_danger_panel)
	var danger_column := VBoxContainer.new()
	_danger_panel.add_child(danger_column)
	_danger_label = Label.new()
	_danger_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_danger_label.add_theme_font_size_override("font_size", 22)
	danger_column.add_child(_danger_label)
	_danger = _bar(0, 22.0, PIP_COLOURS[2], FightSim.SUB_TAP)
	_danger.value = 0.0
	_danger.tooltip_text = "submission danger: at 100 they tap, at 0 they're out"
	danger_column.add_child(_danger)
	_danger_panel.visible = false

	_dialog = _panel(Color(0.08, 0.09, 0.11, 0.96))
	_dialog.set_anchors_preset(Control.PRESET_CENTER)
	_dialog.offset_left = -520.0
	_dialog.offset_right = 520.0
	_dialog.offset_top = -260.0
	_dialog.offset_bottom = 260.0
	add_child(_dialog)
	var dialog_column := VBoxContainer.new()
	dialog_column.add_theme_constant_override("separation", 14)
	_dialog.add_child(dialog_column)
	_dialog_title = Label.new()
	DisplayFont.apply(_dialog_title, 44)
	_dialog_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog_column.add_child(_dialog_title)
	_dialog_body = RichTextLabel.new()
	_dialog_body.bbcode_enabled = true
	_dialog_body.fit_content = true
	_dialog_body.scroll_active = false
	_dialog_body.add_theme_font_size_override("normal_font_size", 20)
	_dialog_body.add_theme_font_size_override("bold_font_size", 20)
	dialog_column.add_child(_dialog_body)
	_dialog_extra = VBoxContainer.new()
	dialog_column.add_child(_dialog_extra)
	_dialog_buttons = HBoxContainer.new()
	_dialog_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_dialog_buttons.add_theme_constant_override("separation", 16)
	dialog_column.add_child(_dialog_buttons)
	_dialog.visible = false


func _centre_block() -> VBoxContainer:
	var block := VBoxContainer.new()
	block.custom_minimum_size = Vector2(340.0, 0.0)
	_clock = Label.new()
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	DisplayFont.apply(_clock, 42)
	block.add_child(_clock)
	_speed = Label.new()
	_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speed.add_theme_font_size_override("font_size", 18)
	block.add_child(_speed)
	_judges = Label.new()
	_judges.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_judges.add_theme_font_size_override("font_size", 18)
	_judges.add_theme_color_override("font_color", Color("#ced4da"))
	block.add_child(_judges)
	return block


static func _panel_style(colour: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	return style


static func _panel(colour: Color = PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _panel_style(colour))
	return p
