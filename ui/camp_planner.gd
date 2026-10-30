class_name CampPlanner
extends PanelContainer
## The training camp planner (D133, docs/02 §3.6): plan a fight camp week by week for
## the red corner's fighter, then take them into the fight. Each week starts from a
## focus week (data/week_plans) and any slot can be changed by hand; the forecast says
## what the week will probably do before it's run (TrainingCamp.forecast), and the log
## says what it did. On fight night it says how the camp sends the fighter in (tired, hurt,
## what the doctor says, D135) and offers Fight! or Pull out. Up to PLAY_MAX sessions a week with a
## minigame built so far (mitt work, D137) can be ticked to Play: running the week plays them first and their
## scores count in the camp. Laid out as the camp week HUD (D170, docs/02 §3.10): the camp's weeks counting down
## to the fight along the top, the fighter's condition on the left, the week as coloured session tiles over a
## fatigue line in the middle, and the stats as bars on the right. Presentation only: TrainingCamp does the training.

signal fight_pressed(profile: Dictionary)
signal back_pressed

## Camp length in weeks: usually 4–8, 1–2 on short notice (docs/02 §4).
const WEEKS_MIN: int = 1
const WEEKS_MAX: int = 8
const WEEKS_DEFAULT: int = 6
## The week plan the planner opens on, and the name of a week changed by hand.
const START_PLAN := "balanced"
const CUSTOM := "custom"
const CUSTOM_NAME := "Custom week"
const SLOT_NAMES: Array[String] = ["Morning", "Evening"]
const DAY_SHORT: Array[String] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
const GROUPS: Array[String] = ["Physical", "Striking", "Wrestling", "Grappling", "Mental"]
## Forecast gains this small aren't worth a line.
const SHOWN_GAIN: float = 0.005
## The minigames that can be played so far (D137), and how many sessions a week the player can play (docs/02 §3.1).
const PLAYABLE: Array[String] = ["mitt_work"]
const PLAY_MAX: int = 3
## The fight is on the last week's Saturday evening (D135): this many days after that week's Monday.
const FIGHT_DAY: int = 5
const DIM := "#8a8f98"
const GAIN := "#69db7c"
const LOSS := "#ff8787"
## The HUD's colours (D170): the screen behind, the cards on it, and the red corner's.
const BACKGROUND := Color(0.08, 0.09, 0.11, 0.97)
const CARD := Color("#1b1f26")
const RED_CORNER := Color("#ff6b6b")
## Fatigue and injury gauges: green under the first number, yellow under the second, red past it.
const FATIGUE_BANDS: Array[float] = [20.0, 40.0]
const INJURY_BANDS: Array[float] = [0.03, 0.06]
## The injury gauge is full at this chance in a week.
const INJURY_FULL: float = 0.1
## What a hurt area does to the fighter in the fight (FighterState: head and legs hurt slow stats down, body hurt shrinks the tank).
const HURT_EFFECTS := {
	"head": "a lower health bar, slower hands and reads",
	"body": "a smaller gas tank",
	"legs": "slower feet and weaker kicks",
}

## The camp being planned (rebuilt when the length, age or potential change before week 1).
var camp: TrainingCamp
var weeks: int = WEEKS_DEFAULT
## What each week that has been run did (TrainingCamp.run_plan reports).
var reports: Array[Dictionary] = []
## The player pulled out of the fight on fight night: the camp is wasted (D135).
var pulled_out: bool = false
## Who the fight is against, for the countdown ("vs Kicker"); empty says nothing.
var opponent_name: String = "":
	set(value):
		opponent_name = value
		if _days_note != null:
			_refresh()

var _start: Dictionary  # The fighter@1 profile as the camp found them.
var _library: TrainingLibrary
var _camp_seed: int
var _plan_ids: Array[String] = []
var _session_ids: Array[String] = []
var _instruction_ids: Array[String] = [""]
var _groups: Dictionary = {}  # stat id → attribute group
var _slot_ids: Array[String] = []  # The week on screen: a session id in each of the 12 slots.

var _title: Label
var _subtitle: Label
var _countdown: CampCountdown
var _days: Label
var _days_note: Label
var _figure: BodyDamageFigure
var _condition: RichTextLabel
var _gauges: Dictionary = {}  # name → { bar: ProgressBar, value: Label }
var _week_label: Label
var _weeks_picker: OptionButton
var _age: SpinBox
var _potential: SpinBox
var _preset: OptionButton
var _instruction: OptionButton
var _about: Label
var _slots: Array[SessionTile] = []
var _play: Array[CheckBox] = []  # In each tile's corner: play its minigame this week.
var _session_menu: PopupMenu
var _menu_slot: int = -1  # The tile the session list is open for.
## The minigame on screen while a week is being played, else null.
var minigame: MittWorkScreen
var _to_play: Array[int] = []
var _played: Dictionary = {}  # slot → quality, this week
var _fatigue_line: FatigueLine
var _forecast: RichTextLabel
var _log: RichTextLabel
var _stat_bars: StatBars
var _stats_text: String = ""
var _run: Button
var _run_rest: Button
var _fight: Button
var _pull_out: Button
var _filling: bool = false  # Setting the slots from a preset, not by hand.


func _init(profile: Dictionary, camp_seed: int = 1, library: TrainingLibrary = null) -> void:
	_start = profile.duplicate(true)
	_library = library if library != null else TrainingLibrary.shared()
	_camp_seed = camp_seed
	_plan_ids = _library.plan_ids()
	_session_ids = _library.session_ids()
	_slot_ids.resize(TrainingCamp.DAYS * TrainingCamp.SLOTS_PER_DAY)
	_slot_ids.fill(_session_ids[0])
	var enum_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(TrainingCamp.STATS_PATH))
	if enum_data is Dictionary:
		_groups = enum_data.get("values", {})
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 24.0
	offset_top = 24.0
	offset_right = -24.0
	offset_bottom = -24.0
	add_theme_stylebox_override("panel", FightHud._panel_style(BACKGROUND))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	add_child(column)
	column.add_child(_build_top_bar())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	body.add_child(_build_condition_card())
	body.add_child(_build_week_card())
	body.add_child(_build_stats_card())

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(buttons)
	_button(buttons, "Back to the fight setup", func() -> void: back_pressed.emit())
	_button(buttons, "Start the camp again", reset)
	_run = _button(buttons, "Run week 1", run_week)
	_run_rest = _button(buttons, "Run every week left like this one", run_rest)
	_pull_out = _button(buttons, "Pull out of the fight", pull_out)
	_fight = _button(buttons, "Fight!", func() -> void: fight_pressed.emit(trained_profile()))
	DisplayFont.apply(_fight, 30)
	_fight.custom_minimum_size.x = 160.0
	_style_fight_button()
	_build_session_menu()
	_new_camp()
	pick_preset(START_PLAN if _plan_ids.has(START_PLAN) else _plan_ids[0])


## Starts the camp over: week 1, the fighter as they came in (the week on screen stays).
func reset() -> void:
	_new_camp()
	_refresh()


## Fills the week from a week plan (data/week_plans id): its sessions and instruction.
func pick_preset(plan_id: String) -> void:
	var plan: Dictionary = _library.plan(plan_id)
	_filling = true
	_preset.selected = _plan_ids.find(plan_id)
	for day in TrainingCamp.DAYS:
		for slot in TrainingCamp.SLOTS_PER_DAY:
			_slot_ids[day * TrainingCamp.SLOTS_PER_DAY + slot] = String(plan.days[day][slot])
	var instruction: Variant = plan.get("instruction")
	_instruction.selected = maxi(0, _instruction_ids.find("" if instruction == null else String(instruction)))
	_filling = false
	_refresh()


## Puts a session in one slot (0–11: day × 2 + slot), by hand: the week becomes a custom week.
func set_slot(index: int, session_id: String) -> void:
	_slot_ids[index] = session_id
	_on_changed_by_hand()


## The week as it stands on screen, as a week_plan@1 Dictionary.
func week_plan() -> Dictionary:
	var id: String = _preset_id()
	var days: Array = []
	for day in TrainingCamp.DAYS:
		var pair: Array = []
		for slot in TrainingCamp.SLOTS_PER_DAY:
			pair.append(_slot_ids[day * TrainingCamp.SLOTS_PER_DAY + slot])
		days.append(pair)
	var instruction: String = _instruction_ids[maxi(0, _instruction.selected)]
	return { "id": id, "name": CUSTOM_NAME if id == CUSTOM else String(_library.plan(id).name),
		"instruction": null if instruction == "" else instruction, "days": days }


## Runs the week on screen (the next week of the camp). Sessions ticked to Play are played first, one
## minigame after another, and the week runs when the last one is done.
func run_week() -> void:
	if done() or minigame != null:
		return
	_to_play = played_slots()
	_played = {}
	_play_next()


## The slots ticked to Play (0–11) whose minigame exists.
func played_slots() -> Array[int]:
	var out: Array[int] = []
	for i in _play.size():
		if _play[i].button_pressed and not _play[i].disabled:
			out.append(i)
	return out


## Ticks or unticks a slot's Play box (only a session with a playable minigame, at most PLAY_MAX a week).
func set_play(index: int, on: bool) -> void:
	_play[index].button_pressed = on
	_refresh()


func _play_next() -> void:
	if _to_play.is_empty():
		var report: Dictionary = camp.run_plan(week_plan(), _played, fight_week())
		report.played = _played.duplicate()
		reports.append(report)
		_refresh()
		return
	var index: int = _to_play.pop_front()
	var forecast: Dictionary = camp.forecast(week_plan(), fight_week())
	var fatigue: float = float(forecast.slots[index].fatigue_before) if index < forecast.slots.size() else camp.fatigue
	var drill := MittWork.new(camp.stat("boxing"), fatigue, hash([_camp_seed, reports.size(), index]))
	var day: int = index / TrainingCamp.SLOTS_PER_DAY
	minigame = MittWorkScreen.new(drill, "Mitt work · week %d, %s %s · fatigue %d" % [reports.size() + 1,
		TrainingCamp.DAY_NAMES[day], SLOT_NAMES[index % TrainingCamp.SLOTS_PER_DAY].to_lower(), roundi(fatigue)])
	minigame.finished.connect(func(quality: float, played: bool) -> void:
		if played:
			_played[index] = quality
		minigame.queue_free()
		minigame = null
		_play_next())
	add_child(minigame)


## The week on screen is the last one: the fight is on its Saturday evening (D135).
func fight_week() -> bool:
	return reports.size() == weeks - 1


## Days from the Monday of the week on screen to the fight (0 on fight night).
func days_to_fight() -> int:
	return 0 if done() else (weeks - 1 - reports.size()) * 7 + FIGHT_DAY


## Runs every week left with the week on screen.
func run_rest() -> void:
	if minigame != null:
		return
	while not done():
		reports.append(camp.run_plan(week_plan(), {}, fight_week()))
	_refresh()


func done() -> bool:
	return reports.size() >= weeks


## Whether Fight! is on: the camp is over, the player hasn't pulled out and the doctor clears the fighter.
func can_fight() -> bool:
	return done() and not pulled_out and camp.fight_night().doctor != TrainingCamp.NOT_CLEARED


## Pulls the fighter out of the fight (fight night only): the fight is off and the camp is wasted.
func pull_out() -> void:
	if done():
		pulled_out = true
		_refresh()


## The fighter as the camp has left them, ready for FighterLibrary (id: theirs + "_camp"), with the
## condition fight night leaves them in (TrainingCamp.fight_profile).
func trained_profile() -> Dictionary:
	var out: Dictionary = camp.fight_profile()
	out.id = String(_start.get("id", "fighter")) + "_camp"
	return out


## What the camp was, for the fight's record: its weeks (each week's plan id) and fight night (TrainingCamp.fight_night).
func summary() -> Dictionary:
	var night: Dictionary = camp.fight_night()
	return { "weeks": reports.map(func(r: Dictionary) -> String: return String(r.plan)),
		"fatigue": snappedf(night.fatigue, 0.1), "tank": snappedf(night.tank, 0.001), "injury_area": night.injury_area,
		"injured_days": night.injured_days, "doctor": night.doctor, "worsen_chance": snappedf(night.worsen_chance, 0.001) }


## The forecast, log, stats and condition card as text (tests read them).
func forecast_text() -> String:
	return _forecast.get_parsed_text()


func log_text() -> String:
	return _log.get_parsed_text()


func stats_text() -> String:
	return _stats_text


func condition_text() -> String:
	var lines: Array[String] = [_condition.get_parsed_text()]
	for gauge: String in _gauges:
		lines.append("%s %s" % [gauge, _gauges[gauge].value.text])
	return "\n".join(lines)


## The tiles' text, one per slot (tests read them).
func tile_text(index: int) -> String:
	return "%s · %s" % [_slots[index].session_name, _slots[index].note]


## Opens the session list for a slot (what clicking its tile does); `choose_session` picks from it.
func open_session_menu(index: int) -> void:
	if _slots[index].disabled:
		return
	_menu_slot = index
	var tile: SessionTile = _slots[index]
	if tile.is_inside_tree():
		_session_menu.reset_size()
		_session_menu.popup(Rect2i(Vector2i(tile.get_screen_position() + Vector2(0.0, tile.size.y)), Vector2i(int(tile.size.x), 0)))


## Puts a session in the slot the list is open for, as a hand change.
func choose_session(session_id: String) -> void:
	if _menu_slot >= 0:
		set_slot(_menu_slot, session_id)
	_menu_slot = -1


func focus_run() -> void:
	FightHud.focus_later(_run)


# --- building the screen ------------------------------------------------------

func _build_top_bar() -> Control:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.custom_minimum_size.x = 520.0
	top.add_child(names)
	_title = Label.new()
	DisplayFont.apply(_title, 46)
	_title.add_theme_color_override("font_color", RED_CORNER)
	names.add_child(_title)
	_subtitle = _dim_label(16)
	names.add_child(_subtitle)
	_countdown = CampCountdown.new()
	_countdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_countdown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_countdown)
	var days := VBoxContainer.new()
	days.add_theme_constant_override("separation", 0)
	days.custom_minimum_size.x = 300.0
	top.add_child(days)
	_days = Label.new()
	DisplayFont.apply(_days, 46)
	_days.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	days.add_child(_days)
	_days_note = _dim_label(16)
	_days_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	days.add_child(_days_note)
	return top


func _build_condition_card() -> Control:
	var card := _card(Vector2(380.0, 0.0))
	var box: VBoxContainer = card.get_child(0)
	box.add_child(_heading("Condition"))
	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 14)
	box.add_child(who)
	_figure = BodyDamageFigure.new()
	_figure.custom_minimum_size = Vector2(60.0, 100.0)
	who.add_child(_figure)
	_condition = _text_box(Vector2(0.0, 100.0))
	_condition.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_condition.fit_content = true
	who.add_child(_condition)
	for gauge in ["Fatigue now", "Peak this week", "Injury chance"]:
		_add_gauge(box, gauge)

	box.add_child(_heading("Camp"))
	var setup := GridContainer.new()
	setup.columns = 2
	setup.add_theme_constant_override("h_separation", 10)
	box.add_child(setup)
	FightSetup._add_label(setup, "Weeks")
	_weeks_picker = OptionButton.new()
	for n in range(WEEKS_MIN, WEEKS_MAX + 1):
		_weeks_picker.add_item("%d" % n)
	_weeks_picker.selected = WEEKS_DEFAULT - WEEKS_MIN
	_weeks_picker.item_selected.connect(func(_i: int) -> void: reset())
	setup.add_child(_weeks_picker)
	_age = _spin(setup, "Age", 16.0, 45.0, float(_start.get("age", TrainingCamp.DEFAULT_AGE)))
	_potential = _spin(setup, "True potential", 30.0, 100.0, float(_start.get("potential", TrainingCamp.DEFAULT_POTENTIAL)))

	box.add_child(_heading("The camp so far"))
	_log = _text_box(Vector2.ZERO)
	_log.scroll_following = true
	_log.add_theme_font_size_override("normal_font_size", 14)
	_log.add_theme_font_size_override("bold_font_size", 14)
	box.add_child(_log)
	return card


func _build_week_card() -> Control:
	var card := _card(Vector2.ZERO)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box: VBoxContainer = card.get_child(0)
	_week_label = Label.new()
	DisplayFont.apply(_week_label, 32)
	box.add_child(_week_label)
	var picks := GridContainer.new()
	picks.columns = 4
	picks.add_theme_constant_override("h_separation", 10)
	box.add_child(picks)
	_preset = _picker(picks, "Start from", _plan_ids.map(func(id: String) -> String: return String(_library.plan(id).name)) + [CUSTOM_NAME])
	_preset.item_selected.connect(_on_preset_selected)
	var names: Array = ["No instruction"]
	for file in _sorted_files(Gameplan.DEFAULT_DIR):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(Gameplan.DEFAULT_DIR.path_join(file)))
		if data is Dictionary:
			_instruction_ids.append(String(data.id))
			names.append("Told to: %s" % data.get("name", data.id))
	_instruction = _picker(picks, "Instruction", names)
	_instruction.item_selected.connect(func(_i: int) -> void: _on_changed_by_hand())
	_about = Label.new()
	_about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_about.add_theme_color_override("font_color", Color("#adb5bd"))
	box.add_child(_about)

	var grid := GridContainer.new()
	grid.columns = 1 + DAY_SHORT.size()
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	FightSetup._add_label(grid, "")
	for day_name in DAY_SHORT:
		var label := _dim_label(15)
		label.text = day_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(label)
	var tiles: Array[SessionTile] = []
	for slot in TrainingCamp.SLOTS_PER_DAY:
		var row_label := _dim_label(15)
		row_label.text = SLOT_NAMES[slot]
		row_label.custom_minimum_size.x = 76.0
		grid.add_child(row_label)
		for day in DAY_SHORT.size():
			if day == TrainingCamp.DAYS:
				var off := Label.new()
				off.text = "Day off"
				off.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				off.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				off.add_theme_color_override("font_color", Color(DIM))
				off.custom_minimum_size.x = 70.0
				grid.add_child(off)
				continue
			var tile := SessionTile.new()
			var index: int = day * TrainingCamp.SLOTS_PER_DAY + slot
			tile.pressed.connect(func() -> void: open_session_menu(index))
			tile.play.tooltip_text = "Play this session's minigame yourself when the week runs (up to %d a week)" % PLAY_MAX
			tile.play.toggled.connect(func(_on: bool) -> void: _refresh())
			grid.add_child(tile)
			tiles.append(tile)
	# Built a row at a time; kept in slot order (day × 2 + slot).
	_slots.resize(tiles.size())
	for i in tiles.size():
		var slot: int = i / TrainingCamp.DAYS
		var day: int = i % TrainingCamp.DAYS
		_slots[day * TrainingCamp.SLOTS_PER_DAY + slot] = tiles[i]
	for tile in _slots:
		_play.append(tile.play)

	_fatigue_line = FatigueLine.new()
	_fatigue_line.tiles.assign(_slots)
	box.add_child(_fatigue_line)
	var legend := HFlowContainer.new()
	legend.add_theme_constant_override("h_separation", 18)
	box.add_child(legend)
	for kind in TrainingLibrary.KINDS:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 6)
		var swatch := ColorRect.new()
		swatch.color = SessionTile.kind_colour(kind)
		swatch.custom_minimum_size = Vector2(12.0, 12.0)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(swatch)
		var name_label := _dim_label(14)
		name_label.text = SessionTile.KIND_NAMES[kind]
		item.add_child(name_label)
		legend.add_child(item)
	var play_note := _dim_label(14)
	play_note.text = "Yellow outline: you play it"
	legend.add_child(play_note)
	_forecast = _text_box(Vector2.ZERO)
	box.add_child(_forecast)
	return card


func _build_stats_card() -> Control:
	var card := _card(Vector2(400.0, 0.0))
	var box: VBoxContainer = card.get_child(0)
	box.add_child(_heading("Stats"))
	var key := _dim_label(13)
	key.text = "Green: the camp so far · yellow tick: where this week takes it"
	key.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(key)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_stat_bars = StatBars.new()
	_stat_bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_stat_bars)
	var note := _dim_label(13)
	note.text = "Fights use each stat to the nearest point."
	box.add_child(note)
	return card


## A session list for the tiles: every session under its kind, with its colour and what it does to fatigue.
func _build_session_menu() -> void:
	_session_menu = PopupMenu.new()
	_session_menu.add_theme_font_size_override("font_size", 16)
	add_child(_session_menu)
	for kind in TrainingLibrary.KINDS:
		var ids: Array[String] = []
		for id in _session_ids:
			if String(_library.session(id).get("kind", "")) == kind:
				ids.append(id)
		if ids.is_empty():
			continue
		_session_menu.add_separator(SessionTile.KIND_NAMES[kind])
		var image := Image.create(14, 14, false, Image.FORMAT_RGBA8)
		image.fill(SessionTile.kind_colour(kind))
		var icon := ImageTexture.create_from_image(image)
		for id in ids:
			var session: Dictionary = _library.session(id)
			_session_menu.add_icon_item(icon, "%s   (fatigue %+d)" % [session.name, roundi(float(session.fatigue))], _session_ids.find(id))
	_session_menu.id_pressed.connect(func(id: int) -> void: choose_session(_session_ids[id]))


func _card(min_size: Vector2) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = min_size
	var style: StyleBoxFlat = FightHud._panel_style(CARD)
	style.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	return card


func _heading(text: String) -> Label:
	var label := _dim_label(13)
	DisplayFont.apply(label, 18)
	label.text = text.to_upper()
	return label


func _dim_label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(DIM))
	return label


## A labelled bar on the condition card: the label and number on one line, the bar under them.
func _add_gauge(parent: Control, label_text: String) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var value := Label.new()
	DisplayFont.apply(value, 24)
	row.add_child(value)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 8.0
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#2b3038")
	track.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", track)
	var fill := StyleBoxFlat.new()
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	_gauges[label_text] = { "bar": bar, "value": value, "fill": fill }


## Sets a gauge: the number shown, the bar's share (0–1) and its colour by bands (green, yellow, red); `text` empty hides the bar.
func _set_gauge(label_text: String, text: String, share: float, amount: float, bands: Array[float]) -> void:
	var gauge: Dictionary = _gauges[label_text]
	var colour: Color = FightHud.PIP_COLOURS[0]
	if amount >= bands[1]:
		colour = FightHud.PIP_COLOURS[2]
	elif amount >= bands[0]:
		colour = FightHud.PIP_COLOURS[1]
	(gauge.value as Label).text = text
	(gauge.value as Label).add_theme_color_override("font_color", colour if text != "–" else Color(DIM))
	(gauge.fill as StyleBoxFlat).bg_color = colour
	(gauge.bar as ProgressBar).max_value = 1.0
	(gauge.bar as ProgressBar).value = clampf(share, 0.0, 1.0) if text != "–" else 0.0


func _style_fight_button() -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#e03131") if state != "hover" else Color("#f03e3e")
		style.set_corner_radius_all(6)
		style.set_content_margin_all(10)
		if state == "focus":
			style.draw_center = false
			style.set_border_width_all(2)
			style.border_color = Color.WHITE
		_fight.add_theme_stylebox_override(state, style)
	_fight.add_theme_color_override("font_color", Color.WHITE)
	_fight.add_theme_color_override("font_hover_color", Color.WHITE)


func _text_box(min_size: Vector2) -> RichTextLabel:
	var box := RichTextLabel.new()
	box.bbcode_enabled = true
	box.custom_minimum_size = min_size
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_color_override("default_color", Color("#dee2e6"))
	return box


func _spin(grid: GridContainer, label: String, low: float, high: float, value: float) -> SpinBox:
	FightSetup._add_label(grid, label)
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.value = value
	spin.value_changed.connect(func(_v: float) -> void: reset())
	grid.add_child(spin)
	return spin


func _picker(grid: GridContainer, label: String, items: Array) -> OptionButton:
	FightSetup._add_label(grid, label)
	var picker := OptionButton.new()
	for item: String in items:
		picker.add_item(item)
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(picker)
	return picker


static func _button(parent: Control, text: String, pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0.0, 48.0)
	b.pressed.connect(pressed)
	parent.add_child(b)
	return b


static func _sorted_files(dir_path: String) -> PackedStringArray:
	var files: PackedStringArray = DirAccess.get_files_at(dir_path)
	files.sort()
	var out := PackedStringArray()
	for f in files:
		if f.ends_with(".json"):
			out.append(f)
	return out


# --- showing it -----------------------------------------------------------------

func _new_camp() -> void:
	_start.age = int(_age.value)
	_start.potential = _potential.value
	weeks = WEEKS_MIN + maxi(0, _weeks_picker.selected)
	camp = TrainingCamp.new(_start, _camp_seed, _library)
	reports.clear()
	pulled_out = false


func _on_preset_selected(index: int) -> void:
	if index < _plan_ids.size():
		pick_preset(_plan_ids[index])
	else:
		_refresh()


func _preset_id() -> String:
	var at: int = _preset.selected
	return _plan_ids[at] if at >= 0 and at < _plan_ids.size() else CUSTOM


func _on_changed_by_hand() -> void:
	if _filling:
		return
	_preset.selected = _plan_ids.size()  # Custom week.
	_refresh()


## What the scouts say the fighter's hidden potential is (D136): a range, e.g. "78–92". The True potential box in the
## setup is the real number, for testing.
func scouted_potential() -> String:
	var scouted: Array[int] = Ageing.scouted_range(camp.potential, hash(String(_start.get("id", _start.get("name", "")))))
	return "%d–%d" % scouted


func _refresh() -> void:
	var fighter_name: String = String(_start.get("name", "Fighter"))
	_title.text = "%s, %d" % [fighter_name, camp.age]
	_subtitle.text = "Training camp · potential %s (scouted)" % scouted_potential()
	var started: bool = not reports.is_empty()
	_weeks_picker.disabled = started
	_age.editable = not started
	_potential.editable = not started
	var id: String = _preset_id()
	var plan_name: String = CUSTOM_NAME if id == CUSTOM else String(_library.plan(id).name)
	_week_label.text = "Camp over: fight night" if done() else "Week %d of %d · %s" % [reports.size() + 1, weeks, plan_name]
	_about.text = "Changed by hand. Click any tile to change it." if id == CUSTOM else String(_library.plan(id).get("about", ""))
	_run.text = "Run week" if done() else "Run week %d" % (reports.size() + 1)
	_run.disabled = done()
	_run_rest.disabled = done()
	_fight.disabled = not can_fight()
	_pull_out.disabled = not done() or pulled_out
	for tile in _slots:
		tile.disabled = done()
	_slots[-1].disabled = fight_week() or done()
	_refresh_play()
	var forecast: Dictionary = {} if done() else camp.forecast(week_plan(), fight_week())
	var week: Dictionary = forecast if not done() else (reports[-1] if started else {})  # On fight night, how the last week went.
	_refresh_tiles(week)
	_fatigue_line.show_week(week)
	_refresh_top()
	_refresh_condition(forecast)
	_forecast.text = _forecast_bbcode(forecast)
	_log.text = _log_bbcode()
	_refresh_stats(forecast.get("gains", {}))
	if can_fight():
		FightHud.focus_later(_fight)


func _refresh_top() -> void:
	var off: bool = done() and not can_fight()
	var history: Array[Dictionary] = []
	for i in reports.size():
		var r: Dictionary = reports[i]
		history.append({ "plan": _plan_name(r.plan), "hurt": not (r.injuries as Array).is_empty(), "tip": _week_line(i, false) })
	_countdown.show_camp(weeks, history, off)
	var days: int = days_to_fight()
	if off:
		_days.text = "Fight off"
	elif done():
		_days.text = "Fight night"
	elif fight_week():
		_days.text = "Fight week"
	else:
		_days.text = "%d days" % days
	_days.add_theme_color_override("font_color", Color(DIM) if off else (RED_CORNER if done() or fight_week() else Color("#e9ecef")))
	var against: String = "vs %s · " % opponent_name if opponent_name != "" else ""
	_days_note.text = "%sSaturday evening, week %d" % [against, weeks]


## Each tile's session and the fatigue after it, from this week's forecast (or the last week's report on fight night).
func _refresh_tiles(week: Dictionary) -> void:
	var slots: Array = week.get("slots", [])
	for i in _slots.size():
		var tile: SessionTile = _slots[i]
		if (fight_week() or done()) and i == _slots.size() - 1:
			tile.show_session({ "name": "The fight", "kind": "" }, "Sat evening")
			tile.tooltip_text = "Fight week: Saturday evening is the fight"
			continue
		var session: Dictionary = _library.session(_slot_ids[i])
		var note: String = ""
		if i < slots.size():
			note = "fatigue %d" % roundi(slots[i].fatigue)
			match String(slots[i].result):
				TrainingCamp.INJURED:
					note = "out hurt · " + note
				TrainingCamp.SKIPPED:
					note = "skipped · " + note
		tile.show_session(session, note)


## The condition card: the figure shows a healing injury where it is, as fight night would start him (D135).
func _refresh_condition(forecast: Dictionary) -> void:
	var night: Dictionary = camp.fight_night()
	for area: String in BodyDamageFigure.AREAS:
		_figure.hurt[area] = float(night.hurt.get(area, 0.0))
	_figure.leg_hurt = [float(night.hurt.get("legs", 0.0)), float(night.hurt.get("legs", 0.0))]
	_figure.queue_redraw()
	var lines: Array[String] = []
	if camp.injured_days > 0:
		lines.append("[color=%s]Hurt (%s): %d more days to heal[/color]" % [LOSS, camp.injury_area, camp.injured_days])
	else:
		lines.append("[color=%s]%s, no injuries[/color]" % [GAIN, _sentence(TrainingCamp.freshness(camp.fatigue))])
	lines.append("[color=%s]Chin %d %s · gas tank %d%%[/color]" % [DIM, roundi(camp.stat("chin")), TrainingCamp.grade(camp.stat("chin")),
		roundi(100.0 * TrainingCamp.tank_at(camp.fatigue))])
	_condition.text = "\n".join(lines)
	_set_gauge("Fatigue now", "%d" % roundi(camp.fatigue), camp.fatigue / 100.0, camp.fatigue, FATIGUE_BANDS)
	if forecast.is_empty():
		_set_gauge("Peak this week", "–", 0.0, 0.0, FATIGUE_BANDS)
		_set_gauge("Injury chance", "–", 0.0, 0.0, INJURY_BANDS)
	else:
		var peak: float = float(forecast.fatigue_peak)
		_set_gauge("Peak this week", "%d" % roundi(peak), peak / 100.0, peak, FATIGUE_BANDS)
		var odds: float = float(forecast.injury_odds)
		_set_gauge("Injury chance", "%d%%" % roundi(100.0 * odds), odds / INJURY_FULL, odds, INJURY_BANDS)


## A Play box shows only on a session with a playable minigame, and works until PLAY_MAX are ticked.
func _refresh_play() -> void:
	var plan: Dictionary = week_plan()
	var ticked: int = 0
	for i in _play.size():
		var session: Dictionary = _library.session(String(plan.days[i / TrainingCamp.SLOTS_PER_DAY][i % TrainingCamp.SLOTS_PER_DAY]))
		var playable: bool = session.get("minigame") is String and PLAYABLE.has(session.minigame) and not done() and not _slots[i].disabled
		if not playable:
			_play[i].set_pressed_no_signal(false)
		elif _play[i].button_pressed:
			ticked += 1
		_play[i].visible = playable
		_play[i].set_meta("playable", playable)
	for i in _play.size():
		_play[i].disabled = not _play[i].get_meta("playable") or (not _play[i].button_pressed and ticked >= PLAY_MAX)
		_slots[i].queue_redraw()
	_fatigue_line.queue_redraw()  # The tiles may have moved.


func _forecast_bbcode(forecast: Dictionary) -> String:
	var lines: Array[String] = []
	if forecast.is_empty():
		return _fight_night_bbcode()
	lines.append("[b]This week, if nothing goes wrong[/b]")
	if forecast.fight_week:
		lines.append("[b]Fight week:[/b] the fight is Saturday evening, so that slot is the fight and nothing after it heals.")
	if camp.injured_days > 0:
		lines.append("[color=%s]Hurt (%s) for %d more days: light sessions (film study, meditation, rehab, recovery, rest) still go ahead, the rest become rest. Rehab heals a day faster.[/color]" % [
			LOSS, camp.injury_area, camp.injured_days])
	lines.append("Fatigue: starts at %d, peaks at %d, %s %d (%s)" % [roundi(forecast.fatigue_start),
		roundi(forecast.fatigue_peak), "at the fight" if forecast.fight_week else "Sunday night", roundi(forecast.fatigue_end),
		TrainingCamp.freshness(forecast.fatigue_end)])
	if forecast.fatigue_peak > TrainingCamp.FATIGUE_FREE:
		lines.append("[color=%s]Past fatigue %d the fighter learns less (× %.2f at the peak).[/color]" % [LOSS,
			roundi(TrainingCamp.FATIGUE_FREE), TrainingCamp.fatigue_factor_at(forecast.fatigue_peak)])
	lines.append("Chance of an injury this week: %d%%" % roundi(100.0 * float(forecast.injury_odds)))
	if float(forecast.skips_expected) >= 0.05:
		lines.append("[color=%s]Party animal: likely to skip about %.1f sessions.[/color]" % [LOSS, forecast.skips_expected])
	lines.append("Variety bonus (3+ kinds of training): %s" % ("yes, XP × %.1f" % TrainingCamp.VARIETY_BONUS if forecast.variety else "no"))
	if float(forecast.chin_wear) > 0.0:
		lines.append("Hard sparring wears the Chin: −%.2f" % forecast.chin_wear)
	lines.append("Gains: " + _top_gains(forecast.gains, 5))
	var aged: Dictionary = forecast.get("aged", {})
	if not aged.is_empty():
		var names: Array[String] = []
		for id: String in aged:
			names.append(TrainingCamp.STAT_NAMES.get(id, id))
		lines.append("[color=%s]Age %d: the body is slowing (%s lose a little every week).[/color]" % [LOSS, camp.age, ", ".join(names)])
	var style: Array[String] = []
	for leaning: String in forecast.leanings:
		if absf(float(forecast.leanings[leaning])) >= 0.05:
			style.append("%s %+.1f" % [leaning.capitalize(), forecast.leanings[leaning]])
	if not style.is_empty():
		lines.append("Style: " + ", ".join(style))
	return "\n".join(lines)


func _fight_night_bbcode() -> String:
	var night: Dictionary = camp.fight_night()
	var lines: Array[String] = ["[b]Fight night[/b]"]
	var tank: int = roundi(100.0 * float(night.tank))
	lines.append("Fatigue %d (%s): %s" % [roundi(night.fatigue), TrainingCamp.freshness(night.fatigue),
		"a full gas tank for the fight." if tank >= 100 else "[color=%s]%d%% of the gas tank for the whole fight.[/color]" % [LOSS, tank]])
	if night.injured_days > 0:
		var area: String = night.injury_area
		lines.append("[color=%s]Still hurt (%s), %d more days to heal: he starts the fight %d%% hurt there (%s).[/color]" % [LOSS,
			area, night.injured_days, roundi(100.0 * float(night.hurt[area])), HURT_EFFECTS.get(area, "")])
	if pulled_out:
		lines.append("[color=%s]You pulled him out. The fight is off and the camp is wasted.[/color]" % LOSS)
	elif night.doctor == TrainingCamp.NOT_CLEARED:
		lines.append("[color=%s]The doctor won't clear him (more than %d days still to heal). The fight is off and the camp is wasted.[/color]" % [
			LOSS, TrainingCamp.DOCTOR_MAX_DAYS])
	elif night.doctor == TrainingCamp.CLEARED_HURT:
		lines.append("The doctor clears him to fight hurt. Fighting on it has a %d%% chance of making it worse (a longer layoff after). You can pull out instead." % roundi(100.0 * float(night.worsen_chance)))
	else:
		lines.append("The doctor clears him.")
	return "\n".join(lines)


func _plan_name(plan_id: String) -> String:
	return CUSTOM_NAME if plan_id == CUSTOM else String(_library.plan(plan_id).name)


## What week i did, as one line (the log, and the countdown's tooltip without colours).
func _week_line(i: int, colours: bool = true) -> String:
	var r: Dictionary = reports[i]
	var paint := func(text: String) -> String: return "[color=%s]%s[/color]" % [LOSS, text] if colours else text
	var bits: Array[String] = ["%d sessions" % r.done]
	if r.skipped > 0:
		bits.append(paint.call("%d skipped" % r.skipped))
	if r.injured > 0:
		bits.append(paint.call("%d missed hurt" % r.injured))
	bits.append("fatigue peaked at %d" % roundi(r.fatigue_peak))
	for slot: int in r.get("played", {}):
		bits.append("played %s × %.2f" % [_library.session(String(r.slots[slot].session)).name, r.played[slot]])
	var lines: Array[String] = ["Week %d, %s: %s. %s" % [i + 1, _plan_name(r.plan), ", ".join(bits), _top_gains(r.gains, 3)]]
	for injury: Dictionary in r.injuries:
		lines.append(paint.call("  Hurt (%s) on %s in %s: out %d days." % [injury.area, TrainingCamp.DAY_NAMES[injury.day],
			_library.session(injury.session).name, injury.days_out]))
	return "\n".join(lines)


func _log_bbcode() -> String:
	if reports.is_empty():
		return "[color=%s]Each week you run shows up here.[/color]" % DIM
	var lines: Array[String] = []
	for i in reports.size():
		lines.append(_week_line(i))
	return "\n".join(lines)


## Every stat with its grade and what the camp has done to it, as bars; `coming` is this week's forecast.
func _refresh_stats(coming: Dictionary) -> void:
	var rows: Array[Dictionary] = []
	var lines: Array[String] = []
	var start_stats: Dictionary = _start.get("stats", {})
	for group in GROUPS:
		rows.append({ "group": group })
		lines.append(group)
		for id: String in TrainingCamp.STAT_NAMES:
			if _groups.get(id, "") != group:
				continue
			var now: float = camp.stat(id)
			var change: float = now - float(start_stats.get(id, FighterState.DEFAULT_STAT))
			rows.append({ "name": TrainingCamp.STAT_NAMES[id], "value": now, "grade": TrainingCamp.grade(now), "change": change,
				"coming": float(coming.get(id, 0.0)) })
			var line: String = "  %s %d %s" % [TrainingCamp.STAT_NAMES[id], roundi(now), TrainingCamp.grade(now)]
			if absf(change) >= SHOWN_GAIN:
				line += " (%+.2f)" % change
			if float(coming.get(id, 0.0)) >= SHOWN_GAIN:
				line += " this week +%.2f" % coming[id]
			lines.append(line)
	_stat_bars.show_rows(rows)
	_stats_text = "\n".join(lines)


static func _sentence(text: String) -> String:
	return text.left(1).to_upper() + text.substr(1)


static func _top_gains(gains: Dictionary, count: int) -> String:
	var ids: Array = gains.keys().filter(func(id: String) -> bool: return float(gains[id]) >= SHOWN_GAIN)
	if ids.is_empty():
		return "none"
	ids.sort_custom(func(a: String, b: String) -> bool: return gains[a] > gains[b])
	var bits: Array[String] = []
	for id: String in ids.slice(0, count):
		bits.append("%s +%.2f" % [TrainingCamp.STAT_NAMES.get(id, id), gains[id]])
	return ", ".join(bits)
