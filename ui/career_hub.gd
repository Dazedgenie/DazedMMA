class_name CareerHub
extends PanelContainer
## The career hub (docs/03 §10.2–10.3, D302; D303 fills it in): the screen a career comes back to between fights. This
## first version has the top bar (who he is, his records, the date) and his fighter card (where he's from, his frame,
## gifts and flaws he knows about, his scouted potential and every stat as a bar and a grade), with Run this week (the
## lighter between-fights week, docs/02 §3.8) and Save and go to the title. The calendar, offers and his fights come
## with the next pieces (docs/03 §10.3).

signal week_pressed
signal title_pressed

const BACKGROUND := Color(0.06, 0.07, 0.09)
const CARD := Color("#1b1f26")
const RED_CORNER := Color("#ff6b6b")
const TEXT := Color("#e9ecef")
const DIM := Color("#8a8f98")
const GOOD := Color("#69db7c")
const BAD := Color("#ff8787")
## Flaws he only finds out about when they first matter (docs/11 §4.3, D90): not on his card until then.
const DISCOVERED_FLAWS: Array[String] = ["bleeder", "hard_cut"]

var career: Career

var _who: Label
var _line: Label
var _date: Label
var _card_text: RichTextLabel
var _bars: StatBars
var _week_text: RichTextLabel
var _week: Button
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
	column.add_theme_constant_override("separation", 16)
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
	body.add_theme_constant_override("separation", 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var fighter_card := _card(Vector2(420.0, 0.0))
	body.add_child(fighter_card)
	var fighter_box: VBoxContainer = fighter_card.get_child(0)
	fighter_box.add_child(_heading("The fighter"))
	_card_text = _rich()
	fighter_box.add_child(_card_text)

	var stats_card := _card(Vector2(520.0, 0.0))
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
	_week = CampPlanner._button(week_box, "Run this week", func() -> void: week_pressed.emit())
	CampPlanner.style_fight_button(_week, 30)
	var title: Button = CampPlanner._button(week_box, "Save and go to the title", func() -> void: title_pressed.emit())
	title.custom_minimum_size.y = 44.0


func show_career(p_career: Career, last_week: Dictionary = {}) -> void:
	career = p_career
	var nick: String = String(career.about.get("nickname", ""))
	_who.text = career.fighter_name().to_upper() + (" '%s'" % nick.to_upper() if nick != "" else "")
	var records: String = "Amateur %s" % career.record_text(false)
	if career.pro:
		records += " · Pro %s" % career.record_text(true)
	_line.text = "Age %d · %s · coached by %s" % [career.age(), records, career.coach_name]
	_date.text = "%s\nWEEK %d" % [career.date_text(), career.week + 1]
	_card_text.text = fighter_card_text(career, _gift_names, _flaw_names)
	_bars.show_rows(stat_rows(career.trainee, _groups))
	_week_text.text = week_text(career, last_week)


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


## What the week holds, and how last week went.
static func week_text(c: Career, last_week: Dictionary) -> String:
	var lines: Array[String] = []
	if c.trainee.injured_days > 0:
		lines.append("[color=%s]Hurt (%s): %d days to heal.[/color]" % [BAD.to_html(false), c.trainee.injury_area, c.trainee.injured_days])
	if c.suspended_days > 0:
		lines.append("Suspended: %d days until he can fight." % c.suspended_days)
	lines.append("No fights booked yet: fight offers come with the next piece of the career.")
	lines.append("This week he trains on the %s week (docs/02 §3.8)." % String(TrainingLibrary.shared().plan(c.week_plan).get("name", c.week_plan)).to_lower())
	lines.append("Savings: $%d" % c.money)
	if not last_week.is_empty():
		lines.append("")
		lines.append("[color=%s]Last week:[/color] %s" % [DIM.to_html(false), _gains_line(last_week)])
	return "\n".join(lines)


static func _gains_line(report: Dictionary) -> String:
	var gains: Dictionary = report.get("gains", {})
	var ids: Array = gains.keys().filter(func(id: Variant) -> bool: return float(gains[id]) >= 0.05)
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return float(gains[a]) > float(gains[b]))
	if ids.is_empty():
		return "a quiet week."
	var bits: Array[String] = []
	for id: Variant in ids.slice(0, 4):
		bits.append("%s +%.1f" % [TrainingCamp.STAT_NAMES.get(id, id), float(gains[id])])
	return ", ".join(bits)


func text() -> String:
	return "%s\n%s\n%s\n%s\n%s" % [_who.text, _line.text, _date.text, _card_text.get_parsed_text(), _week_text.get_parsed_text()]


func focus_first() -> void:
	FightHud.focus_later(_week)


func press_week() -> void:
	_week.pressed.emit()


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
