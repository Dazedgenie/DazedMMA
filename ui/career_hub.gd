class_name CareerHub
extends PanelContainer
## The career hub (docs/03 §10.3, D303; first version D302): the screen a career comes back to between fights.
##
## The top bar says who he is, his records, the date and the week. Left, his card: the body figure with any injury, how
## he feels, his background, hometown and frame, the style he's leaning toward (D88), the gifts and flaws he knows of
## and his scouted potential; then every stat as a bar and a grade. In the middle, *This week*: what's next (an offer,
## a booked fight, hurt, suspended), the week plan between fights (any data/week_plans plan; Between fights to start),
## Run this week, Advance (weeks until something happens, at most Career.ADVANCE_MAX_WEEKS) and Save and go to the
## title. Right, his fights, newest first. Along the bottom, the calendar: the coming weeks and what will happen in them.

signal week_pressed
signal advance_pressed
signal title_pressed

const BACKGROUND := Color(0.06, 0.07, 0.09)
const CARD := Color("#1b1f26")
const TILE := Color("#232830")
const NOW := Color("#2f3640")
const RED_CORNER := Color("#ff6b6b")
const TEXT := Color("#e9ecef")
const DIM := Color("#8a8f98")
const GOOD := Color("#69db7c")
const BAD := Color("#ff8787")
const WARN := Color("#fcc419")
## Flaws he only finds out about when they first matter (docs/11 §4.3, D90): not on his card until then.
const DISCOVERED_FLAWS: Array[String] = ["bleeder", "hard_cut"]
## The result letters on his fights list.
const RESULT_MARKS := { "win": ["W", GOOD], "loss": ["L", BAD], "draw": ["D", WARN], "no_contest": ["NC", DIM] }
## How many of his fights the list shows (newest first).
const FIGHTS_SHOWN: int = 12

var career: Career

var _who: Label
var _line: Label
var _date: Label
var _figure: BodyDamageFigure
var _card_text: RichTextLabel
var _bars: StatBars
var _week_text: RichTextLabel
var _plan: OptionButton
var _plan_ids: Array[String] = []
var _week: Button
var _advance: Button
var _fights_text: RichTextLabel
var _calendar: HBoxContainer
var _groups: Dictionary = {}
var _gift_names: Dictionary = {}
var _flaw_names: Dictionary = {}


func _init() -> void:
	_groups = _enum("stats")
	_gift_names = _enum("gifts")
	_flaw_names = _enum("flaws")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override("panel", FightHud._panel_style(BACKGROUND))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	add_child(column)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)
	column.add_child(top)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(names)
	_who = Label.new()
	DisplayFont.apply(_who, 54)
	_who.add_theme_color_override("font_color", RED_CORNER)
	names.add_child(_who)
	_line = FightNightCard._label(18, DIM)
	names.add_child(_line)
	_date = Label.new()
	DisplayFont.apply(_date, 34)
	_date.add_theme_color_override("font_color", TEXT)
	_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_date)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)

	var fighter_card := _card(Vector2(400.0, 0.0))
	body.add_child(fighter_card)
	var fighter_box: VBoxContainer = fighter_card.get_child(0)
	fighter_box.add_child(_heading("The fighter"))
	var fighter_row := HBoxContainer.new()
	fighter_row.add_theme_constant_override("separation", 12)
	fighter_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fighter_box.add_child(fighter_row)
	_figure = BodyDamageFigure.new()
	_figure.custom_minimum_size = Vector2(110.0, 200.0)
	_figure.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_figure.tooltip_text = "where he's hurt: green is fine, red is badly hurt"
	fighter_row.add_child(_figure)
	_card_text = _rich()
	_card_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fighter_row.add_child(_card_text)

	var stats_card := _card(Vector2(440.0, 0.0))
	body.add_child(stats_card)
	var stats_box: VBoxContainer = stats_card.get_child(0)
	stats_box.add_child(_heading("His stats"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stats_box.add_child(scroll)
	_bars = StatBars.new()
	_bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_bars)

	var week_card := _card(Vector2(0.0, 0.0))
	week_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(week_card)
	var week_box: VBoxContainer = week_card.get_child(0)
	week_box.add_child(_heading("This week"))
	_week_text = _rich()
	week_box.add_child(_week_text)
	var plan_label := FightNightCard._label(16, DIM)
	plan_label.text = "His week plan between fights"
	week_box.add_child(plan_label)
	_plan = OptionButton.new()
	for id: String in TrainingLibrary.shared().plan_ids():
		_plan_ids.append(id)
		_plan.add_item(String(TrainingLibrary.shared().plan(id).get("name", id)))
	_plan.item_selected.connect(func(i: int) -> void: pick_plan(_plan_ids[i]))
	week_box.add_child(_plan)
	_week = CampPlanner._button(week_box, "Run this week", func() -> void: week_pressed.emit())
	CampPlanner.style_fight_button(_week, 30)
	_advance = CampPlanner._button(week_box, "Advance until something happens", func() -> void: advance_pressed.emit())
	_advance.tooltip_text = "Runs weeks on his plan until he's hurt or healed, cleared to fight, has a birthday or an offer comes in (up to %d weeks)" % Career.ADVANCE_MAX_WEEKS
	var title: Button = CampPlanner._button(week_box, "Save and go to the title", func() -> void: title_pressed.emit())
	title.custom_minimum_size.y = 44.0

	var fights_card := _card(Vector2(340.0, 0.0))
	body.add_child(fights_card)
	var fights_box: VBoxContainer = fights_card.get_child(0)
	fights_box.add_child(_heading("His fights"))
	_fights_text = _rich()
	fights_box.add_child(_fights_text)

	column.add_child(_heading("The calendar"))
	_calendar = HBoxContainer.new()
	_calendar.add_theme_constant_override("separation", 8)
	column.add_child(_calendar)


## Shows the career. `reports`: what the last Run this week or Advance did (Career.run_week()'s reports, oldest first).
func show_career(p_career: Career, reports: Array = []) -> void:
	career = p_career
	var nick: String = String(career.about.get("nickname", ""))
	_who.text = career.fighter_name().to_upper() + (" '%s'" % nick.to_upper() if nick != "" else "")
	var records: String = "Amateur %s" % career.record_text(false)
	if career.pro:
		records += " · Pro %s" % career.record_text(true)
	_line.text = "Age %d · %s · coached by %s" % [career.age(), records, career.coach_name]
	_date.text = "%s\nWEEK %d" % [career.date_text(), career.week + 1]
	var night: Dictionary = career.trainee.fight_night()
	for area: String in BodyDamageFigure.AREAS:
		_figure.hurt[area] = float(night.hurt.get(area, 0.0))
	var legs: float = float(night.hurt.get("legs", 0.0))
	_figure.leg_hurt = [legs, legs]
	_figure.queue_redraw()
	_card_text.text = fighter_card_text(career, _gift_names, _flaw_names)
	_bars.show_rows(stat_rows(career.trainee, _groups))
	_week_text.text = week_text(career, reports)
	_plan.select(maxi(_plan_ids.find(career.week_plan), 0))
	_week.disabled = not career.booked.is_empty()
	_advance.disabled = not career.booked.is_empty()
	_fights_text.text = fights_text(career)
	_show_calendar(career.calendar())


## Sets the week plan he runs between fights (a data/week_plans id).
func pick_plan(id: String) -> void:
	if career == null or not id in _plan_ids:
		return
	career.week_plan = id
	_plan.select(_plan_ids.find(id))
	_week_text.text = week_text(career, [])


## The fighter card's text: background and hometown, stance and frame, gifts and flaws he knows of, scouted potential.
static func fighter_card_text(c: Career, gift_names: Dictionary = {}, flaw_names: Dictionary = {}) -> String:
	var p: Dictionary = c.fighter
	var lines: Array[String] = []
	var bg_id: String = String(c.about.get("background", ""))
	var bg_name: String = String(BackgroundLibrary.shared().get_background(bg_id).name) if BackgroundLibrary.shared().has(bg_id) else ""
	if bg_name != "":
		lines.append("[b]%s[/b]" % bg_name)
	var town: String = ", ".join([c.about.get("hometown", ""), c.about.get("country", "")].filter(func(s: String) -> bool: return s != ""))
	if town != "":
		lines.append("From %s" % town)
	var frame: Dictionary = p.get("frame", {})
	lines.append("%s · %d cm, reach %d cm · %s build" % [String(p.get("stance", "orthodox")).capitalize(), int(frame.get("height_cm", 0)),
		int(frame.get("reach_cm", 0)), String(frame.get("build", "average"))])
	lines.append("")
	lines.append("[color=%s]Feels:[/color] %s" % [DIM.to_html(false), feel_text(c.trainee)])
	lines.append("[color=%s]Style:[/color] %s" % [DIM.to_html(false), style_text(c.trainee.style)])
	var gifts: Array[String] = []
	for g: Variant in p.get("gifts", []):
		gifts.append(String(gift_names.get(g, g)))
	var flaws: Array[String] = []
	for f: Variant in p.get("flaws", []):
		if not String(f) in DISCOVERED_FLAWS:
			flaws.append(String(flaw_names.get(f, f)))
	lines.append("[color=%s]Gifts:[/color] %s" % [GOOD.to_html(false), ", ".join(gifts) if not gifts.is_empty() else "none that show yet"])
	lines.append("[color=%s]Flaws:[/color] %s" % [BAD.to_html(false), ", ".join(flaws) if not flaws.is_empty() else "none that show yet"])
	var scouted: Array[int] = Ageing.scouted_range(c.trainee.potential, c.career_seed)
	lines.append("[color=%s]Potential:[/color] %d–%d (scouted)" % [DIM.to_html(false), scouted[0], scouted[1]])
	if bg_name != "":
		lines.append("")
		lines.append("[i]%s[/i]" % String(BackgroundLibrary.shared().get_background(bg_id).hook))
	return "\n".join(lines)


## Every stat as a StatBars row, in its group.
static func stat_rows(trainee: TrainingCamp, groups: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for group in CampPlanner.GROUPS:
		rows.append({ "group": group })
		for id: String in TrainingCamp.STAT_NAMES:
			if String(groups.get(id, "")) == group:
				var now: float = trainee.stat(id)
				rows.append({ "name": TrainingCamp.STAT_NAMES[id], "value": now, "grade": TrainingCamp.grade(now) })
	return rows


## How he feels: fresh, a little tired or worn down, and hurt if he is.
static func feel_text(trainee: TrainingCamp) -> String:
	var out: String = TrainingCamp.freshness(trainee.fatigue)
	if trainee.injured_days > 0:
		out += ", hurt (%s, %d days to heal)" % [trainee.injury_area, trainee.injured_days]
	return out


## The style he's leaning toward (D88: a hint past ±30) and any named style traits, or "no clear style yet".
static func style_text(style: StyleLeanings) -> String:
	var bits: Array[String] = []
	for leaning in StyleLeanings.LEANINGS:
		var hint: String = style.hint(leaning)
		if hint != "":
			bits.append(hint)
	bits.append_array(style.traits())
	return ", ".join(bits) if not bits.is_empty() else "no clear style yet"


## What the week holds (an offer, a booked fight, hurt, suspended, free), his plan and savings, and what the last
## Run this week or Advance did.
static func week_text(c: Career, reports: Array = []) -> String:
	var lines: Array[String] = []
	if not c.offers.is_empty():
		lines.append("[color=%s]%d fight offer%s waiting.[/color]" % [WARN.to_html(false), c.offers.size(), "" if c.offers.size() == 1 else "s"])
	if not c.booked.is_empty():
		var weeks_to: int = int(c.booked.get("week", c.week)) - c.week
		lines.append("Booked to fight in %d week%s: the camp runs from the planner." % [weeks_to, "" if weeks_to == 1 else "s"])
	if c.trainee.injured_days > 0:
		lines.append("[color=%s]Hurt (%s): %d days to heal.[/color]" % [BAD.to_html(false), c.trainee.injury_area, c.trainee.injured_days])
	if c.suspended_days > 0:
		lines.append("Suspended: %d days until he can fight." % c.suspended_days)
	if c.offers.is_empty() and c.booked.is_empty() and c.trainee.injured_days == 0 and c.suspended_days == 0:
		lines.append("Free to fight. Fight offers come with the next piece of the career.")
	lines.append("This week: the %s plan." % String(TrainingLibrary.shared().plan(c.week_plan).get("name", c.week_plan)).to_lower())
	lines.append("Savings: $%d" % c.money)
	if not reports.is_empty():
		lines.append("")
		lines.append(last_text(c, reports))
	return "\n".join(lines)


## What the last Run this week or Advance did: how many weeks, the biggest gains and what happened.
static func last_text(c: Career, reports: Array) -> String:
	var gains: Dictionary = {}
	var events: Array[String] = []
	for report: Dictionary in reports:
		for id: String in report.get("gains", {}):
			gains[id] = float(gains.get(id, 0.0)) + float(report.gains[id])
		for event: Dictionary in report.get("events", []):
			events.append("%s (%s)" % [Career.event_text(event), c.short_date(int(report.get("week", 0)))])
	var head: String = "Last week" if reports.size() == 1 else "The last %d weeks" % reports.size()
	var out: String = "[color=%s]%s:[/color] %s" % [DIM.to_html(false), head, _gains_line(gains)]
	if not events.is_empty():
		out += "\n[color=%s]%s.[/color]" % [WARN.to_html(false), ". ".join(events)]
	return out


static func _gains_line(gains: Dictionary) -> String:
	var ids: Array = gains.keys().filter(func(id: Variant) -> bool: return float(gains[id]) >= 0.05)
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return float(gains[a]) > float(gains[b]))
	if ids.is_empty():
		return "a quiet week."
	var bits: Array[String] = []
	for id: Variant in ids.slice(0, 4):
		bits.append("%s +%.1f" % [TrainingCamp.STAT_NAMES.get(id, id), float(gains[id])])
	return ", ".join(bits)


## His fights, newest first: the result, who, how and when, and the date.
static func fights_text(c: Career) -> String:
	if c.fights.is_empty():
		return "[color=%s]No fights yet.[/color]" % DIM.to_html(false)
	var lines: Array[String] = []
	var shown: int = 0
	for i in range(c.fights.size() - 1, -1, -1):
		if shown >= FIGHTS_SHOWN:
			break
		shown += 1
		var f: Dictionary = c.fights[i]
		var mark: Array = RESULT_MARKS.get(String(f.get("result", "")), ["?", DIM])
		var opponent: String = String(c.opponents.get(String(f.get("opponent", "")), {}).get("name", f.get("opponent", "")))
		var how: String = String(f.get("method", ""))
		if f.has("round"):
			how += (", " if how != "" else "") + "R%d" % int(f.round)
		lines.append("[color=%s][b]%s[/b][/color] vs %s%s" % [(mark[1] as Color).to_html(false), mark[0], opponent, (" · " + how) if how != "" else ""])
		lines.append("[color=%s]%s · %s[/color]" % [DIM.to_html(false), c.date_text(5, int(f.get("week", 0))), "pro" if bool(f.get("pro", false)) else "amateur"])
	return "\n".join(lines)


func _show_calendar(weeks: Array[Dictionary]) -> void:
	for child in _calendar.get_children():
		_calendar.remove_child(child)
		child.queue_free()
	for i in weeks.size():
		var entry: Dictionary = weeks[i]
		var tile := PanelContainer.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.custom_minimum_size.y = 76.0
		var style: StyleBoxFlat = FightHud._panel_style(NOW if i == 0 else TILE)
		style.set_content_margin_all(10)
		tile.add_theme_stylebox_override("panel", style)
		var label := RichTextLabel.new()
		label.bbcode_enabled = true
		label.fit_content = true
		label.scroll_active = false
		label.add_theme_font_size_override("normal_font_size", 15)
		label.add_theme_color_override("default_color", TEXT)
		label.text = calendar_tile_text(entry, i == 0)
		tile.add_child(label)
		_calendar.add_child(tile)


## One calendar week: its Monday ("This week" for the first), then what happens in it.
static func calendar_tile_text(entry: Dictionary, now: bool) -> String:
	var lines: Array[String] = ["[b]%s[/b]" % ("This week" if now else "w/c " + String(entry.date))]
	for event: Dictionary in entry.events:
		var colour: Color = GOOD if String(event.kind) in [Career.HEALED, Career.CLEARED] else (RED_CORNER if String(event.kind) == Career.FIGHT_NIGHT else WARN)
		lines.append("[color=%s]%s[/color]" % [colour.to_html(false), Career.event_text(event)])
	return "\n".join(lines)


func text() -> String:
	var tiles: Array[String] = []
	for tile in _calendar.get_children():
		tiles.append((tile.get_child(0) as RichTextLabel).get_parsed_text())
	return "%s\n%s\n%s\n%s\n%s\n%s\n%s" % [_who.text, _line.text, _date.text, _card_text.get_parsed_text(), _week_text.get_parsed_text(),
		_fights_text.get_parsed_text(), " | ".join(tiles)]


func focus_first() -> void:
	FightHud.focus_later(_week)


func press_week() -> void:
	_week.pressed.emit()


func press_advance() -> void:
	_advance.pressed.emit()


func _rich() -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("normal_font_size", 18)
	label.add_theme_color_override("default_color", TEXT)
	return label


func _card(min_size: Vector2) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = min_size
	var style: StyleBoxFlat = FightHud._panel_style(CARD)
	style.set_content_margin_all(22)
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	return card


func _heading(text_in: String) -> Label:
	var label := FightNightCard._label(20, DIM)
	DisplayFont.apply(label, 20)
	label.text = text_in.to_upper()
	return label


static func _enum(id: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/enums/%s.json" % id))
	return parsed.get("values", {}) if parsed is Dictionary else {}
