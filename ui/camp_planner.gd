class_name CampPlanner
extends PanelContainer
## The training camp planner (D133, docs/02 §3.6): plan a fight camp week by week for
## the red corner's fighter, then take them into the fight. Each week starts from a
## focus week (data/week_plans) and any slot can be changed by hand; the forecast says
## what the week will probably do before it's run (TrainingCamp.forecast), and the log
## says what it did. Presentation only: TrainingCamp does the training.

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
const GROUPS: Array[String] = ["Physical", "Striking", "Wrestling", "Grappling", "Mental"]
## Forecast gains this small aren't worth a line.
const SHOWN_GAIN: float = 0.005
const DIM := "#8a8f98"
const GAIN := "#69db7c"
const LOSS := "#ff8787"

## The camp being planned (rebuilt when the length, age or potential change before week 1).
var camp: TrainingCamp
var weeks: int = WEEKS_DEFAULT
## What each week that has been run did (TrainingCamp.run_plan reports).
var reports: Array[Dictionary] = []

var _start: Dictionary  # The fighter@1 profile as the camp found them.
var _library: TrainingLibrary
var _camp_seed: int
var _plan_ids: Array[String] = []
var _session_ids: Array[String] = []
var _instruction_ids: Array[String] = [""]
var _groups: Dictionary = {}  # stat id → attribute group

var _title: Label
var _week_label: Label
var _weeks_picker: OptionButton
var _age: SpinBox
var _potential: SpinBox
var _preset: OptionButton
var _instruction: OptionButton
var _about: Label
var _slots: Array[OptionButton] = []
var _forecast: RichTextLabel
var _log: RichTextLabel
var _stats: RichTextLabel
var _run: Button
var _run_rest: Button
var _fight: Button
var _filling: bool = false  # Setting the slots from a preset, not by hand.


func _init(profile: Dictionary, camp_seed: int = 1, library: TrainingLibrary = null) -> void:
	_start = profile.duplicate(true)
	_library = library if library != null else TrainingLibrary.shared()
	_camp_seed = camp_seed
	_plan_ids = _library.plan_ids()
	_session_ids = _library.session_ids()
	var enum_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(TrainingCamp.STATS_PATH))
	if enum_data is Dictionary:
		_groups = enum_data.get("values", {})
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 40.0
	offset_top = 40.0
	offset_right = -40.0
	offset_bottom = -40.0
	add_theme_stylebox_override("panel", FightHud._panel_style(Color(0.08, 0.09, 0.11, 0.97)))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 36)
	column.add_child(_title)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	body.add_child(_build_plan_column())
	body.add_child(_build_middle_column())
	_stats = _text_box(Vector2(380.0, 0.0))
	body.add_child(_stats)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(buttons)
	_button(buttons, "Back to the fight setup", func() -> void: back_pressed.emit())
	_button(buttons, "Start the camp again", reset)
	_run = _button(buttons, "Run week 1", run_week)
	_run_rest = _button(buttons, "Run every week left like this one", run_rest)
	_fight = _button(buttons, "Fight!", func() -> void: fight_pressed.emit(trained_profile()))
	_fight.add_theme_font_size_override("font_size", 24)
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
			_slots[day * TrainingCamp.SLOTS_PER_DAY + slot].selected = _session_ids.find(String(plan.days[day][slot]))
	var instruction: Variant = plan.get("instruction")
	_instruction.selected = maxi(0, _instruction_ids.find("" if instruction == null else String(instruction)))
	_filling = false
	_refresh()


## Puts a session in one slot (0–11: day × 2 + slot), by hand: the week becomes a custom week.
func set_slot(index: int, session_id: String) -> void:
	_slots[index].selected = _session_ids.find(session_id)
	_on_changed_by_hand()


## The week as it stands on screen, as a week_plan@1 Dictionary.
func week_plan() -> Dictionary:
	var id: String = _preset_id()
	var days: Array = []
	for day in TrainingCamp.DAYS:
		var pair: Array = []
		for slot in TrainingCamp.SLOTS_PER_DAY:
			pair.append(_session_ids[maxi(0, _slots[day * TrainingCamp.SLOTS_PER_DAY + slot].selected)])
		days.append(pair)
	var instruction: String = _instruction_ids[maxi(0, _instruction.selected)]
	return { "id": id, "name": CUSTOM_NAME if id == CUSTOM else String(_library.plan(id).name),
		"instruction": null if instruction == "" else instruction, "days": days }


## Runs the week on screen (the next week of the camp).
func run_week() -> void:
	if done():
		return
	reports.append(camp.run_plan(week_plan()))
	_refresh()


## Runs every week left with the week on screen.
func run_rest() -> void:
	while not done():
		reports.append(camp.run_plan(week_plan()))
	_refresh()


func done() -> bool:
	return reports.size() >= weeks


## The fighter as the camp has left them, ready for FighterLibrary (id: theirs + "_camp").
func trained_profile() -> Dictionary:
	var out: Dictionary = camp.profile()
	out.id = String(_start.get("id", "fighter")) + "_camp"
	return out


## What the camp was, for the fight's record: its weeks (each week's plan id) and how the fighter came out of it.
func summary() -> Dictionary:
	return { "weeks": reports.map(func(r: Dictionary) -> String: return String(r.plan)),
		"fatigue": snappedf(camp.fatigue, 0.1), "injured_days": camp.injured_days }


## The forecast, log and stats as text (tests read them).
func forecast_text() -> String:
	return _forecast.get_parsed_text()


func log_text() -> String:
	return _log.get_parsed_text()


func stats_text() -> String:
	return _stats.get_parsed_text()


func focus_run() -> void:
	FightHud.focus_later(_run)


# --- building the screen ------------------------------------------------------

func _build_plan_column() -> Control:
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.custom_minimum_size = Vector2(620.0, 0.0)
	var setup := GridContainer.new()
	setup.columns = 6
	setup.add_theme_constant_override("h_separation", 10)
	left.add_child(setup)
	FightSetup._add_label(setup, "Weeks")
	_weeks_picker = OptionButton.new()
	for n in range(WEEKS_MIN, WEEKS_MAX + 1):
		_weeks_picker.add_item("%d" % n)
	_weeks_picker.selected = WEEKS_DEFAULT - WEEKS_MIN
	_weeks_picker.item_selected.connect(func(_i: int) -> void: reset())
	setup.add_child(_weeks_picker)
	_age = _spin(setup, "Age", 16.0, 45.0, float(_start.get("age", TrainingCamp.DEFAULT_AGE)))
	_potential = _spin(setup, "Potential", 30.0, 100.0, float(_start.get("potential", TrainingCamp.DEFAULT_POTENTIAL)))

	_week_label = Label.new()
	_week_label.add_theme_font_size_override("font_size", 24)
	left.add_child(_week_label)
	var picks := GridContainer.new()
	picks.columns = 2
	picks.add_theme_constant_override("h_separation", 10)
	left.add_child(picks)
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
	left.add_child(_about)

	var grid := GridContainer.new()
	grid.columns = 1 + TrainingCamp.SLOTS_PER_DAY
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	left.add_child(grid)
	FightSetup._add_label(grid, "")
	for slot_name in SLOT_NAMES:
		FightSetup._add_label(grid, slot_name)
	var session_names: Array = _session_ids.map(func(id: String) -> String: return String(_library.session(id).name))
	for day in TrainingCamp.DAYS:
		FightSetup._add_label(grid, TrainingCamp.DAY_NAMES[day])
		for slot in TrainingCamp.SLOTS_PER_DAY:
			var picker := OptionButton.new()
			for n in session_names:
				picker.add_item(n)
			picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			picker.item_selected.connect(func(_i: int) -> void: _on_changed_by_hand())
			grid.add_child(picker)
			_slots.append(picker)
	FightSetup._add_label(grid, "Sunday")
	for slot in TrainingCamp.SLOTS_PER_DAY:
		var off := Label.new()
		off.text = "Day off"
		off.add_theme_color_override("font_color", Color(DIM))
		grid.add_child(off)
	return left


func _build_middle_column() -> Control:
	var middle := VBoxContainer.new()
	middle.add_theme_constant_override("separation", 10)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_forecast = _text_box(Vector2(0.0, 300.0))
	middle.add_child(_forecast)
	_log = _text_box(Vector2.ZERO)
	_log.scroll_following = true
	middle.add_child(_log)
	return middle


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


func _refresh() -> void:
	var fighter_name: String = String(_start.get("name", "Fighter"))
	_title.text = "Training camp · %s, %d, potential %d" % [fighter_name, camp.age, roundi(camp.potential)]
	var started: bool = not reports.is_empty()
	_weeks_picker.disabled = started
	_age.editable = not started
	_potential.editable = not started
	_week_label.text = "Camp over: fight night" if done() else "Week %d of %d" % [reports.size() + 1, weeks]
	var id: String = _preset_id()
	_about.text = "Changed by hand." if id == CUSTOM else String(_library.plan(id).get("about", ""))
	_run.text = "Run week" if done() else "Run week %d" % (reports.size() + 1)
	_run.disabled = done()
	_run_rest.disabled = done()
	_fight.disabled = not done()
	var forecast: Dictionary = {} if done() else camp.forecast(week_plan())
	_forecast.text = _forecast_bbcode(forecast)
	_log.text = _log_bbcode()
	_stats.text = _stats_bbcode(forecast.get("gains", {}))
	if done():
		FightHud.focus_later(_fight)


func _forecast_bbcode(forecast: Dictionary) -> String:
	var lines: Array[String] = []
	if forecast.is_empty():
		lines.append("[b]Fight night[/b]")
		lines.append("Fatigue %d (%s)%s." % [roundi(camp.fatigue), TrainingCamp.freshness(camp.fatigue),
			", still hurt (%d more days)" % camp.injured_days if camp.injured_days > 0 else ""])
		lines.append("[color=%s]Fatigue and injuries don't reach the fight yet: that comes next.[/color]" % DIM)
		return "\n".join(lines)
	lines.append("[b]This week, if nothing goes wrong[/b]")
	if camp.injured_days > 0:
		lines.append("[color=%s]Still hurt for %d more days: those sessions become rest.[/color]" % [LOSS, camp.injured_days])
	lines.append("Fatigue: starts at %d, peaks at %d, Sunday night %d (%s)" % [roundi(forecast.fatigue_start),
		roundi(forecast.fatigue_peak), roundi(forecast.fatigue_end), TrainingCamp.freshness(forecast.fatigue_end)])
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
	var style: Array[String] = []
	for leaning: String in forecast.leanings:
		if absf(float(forecast.leanings[leaning])) >= 0.05:
			style.append("%s %+.1f" % [leaning.capitalize(), forecast.leanings[leaning]])
	if not style.is_empty():
		lines.append("Style: " + ", ".join(style))
	return "\n".join(lines)


func _log_bbcode() -> String:
	if reports.is_empty():
		return "[color=%s]Each week you run shows up here.[/color]" % DIM
	var lines: Array[String] = ["[b]The camp so far[/b]"]
	for i in reports.size():
		var r: Dictionary = reports[i]
		var plan_name: String = CUSTOM_NAME if r.plan == CUSTOM else String(_library.plan(r.plan).name)
		var bits: Array[String] = ["%d sessions" % r.done]
		if r.skipped > 0:
			bits.append("[color=%s]%d skipped[/color]" % [LOSS, r.skipped])
		if r.injured > 0:
			bits.append("[color=%s]%d missed hurt[/color]" % [LOSS, r.injured])
		bits.append("fatigue peaked at %d" % roundi(r.fatigue_peak))
		lines.append("Week %d, %s: %s. %s" % [i + 1, plan_name, ", ".join(bits), _top_gains(r.gains, 3)])
		for injury: Dictionary in r.injuries:
			lines.append("  [color=%s]Hurt on %s in %s: out %d days.[/color]" % [LOSS, TrainingCamp.DAY_NAMES[injury.day],
				_library.session(injury.session).name, injury.days_out])
	return "\n".join(lines)


## Every stat with its grade and what the camp has done to it; `coming` (this week's forecast) in brackets.
func _stats_bbcode(coming: Dictionary) -> String:
	var lines: Array[String] = []
	var start_stats: Dictionary = _start.get("stats", {})
	for group in GROUPS:
		lines.append("[b]%s[/b]" % group)
		for id: String in TrainingCamp.STAT_NAMES:
			if _groups.get(id, "") != group:
				continue
			var now: float = camp.stat(id)
			var change: float = now - float(start_stats.get(id, FighterState.DEFAULT_STAT))
			var line: String = "  %s %d %s" % [TrainingCamp.STAT_NAMES[id], roundi(now), TrainingCamp.grade(now)]
			if absf(change) >= SHOWN_GAIN:
				line += " [color=%s](%+.2f)[/color]" % [GAIN if change > 0.0 else LOSS, change]
			if float(coming.get(id, 0.0)) >= SHOWN_GAIN:
				line += " [color=%s]this week +%.2f[/color]" % [DIM, coming[id]]
			lines.append(line)
	lines.append("[color=%s]Fights use each stat to the nearest point.[/color]" % DIM)
	return "\n".join(lines)


static func _top_gains(gains: Dictionary, count: int) -> String:
	var ids: Array = gains.keys().filter(func(id: String) -> bool: return float(gains[id]) >= SHOWN_GAIN)
	if ids.is_empty():
		return "none"
	ids.sort_custom(func(a: String, b: String) -> bool: return gains[a] > gains[b])
	var bits: Array[String] = []
	for id: String in ids.slice(0, count):
		bits.append("%s +%.2f" % [TrainingCamp.STAT_NAMES.get(id, id), gains[id]])
	return ", ".join(bits)
