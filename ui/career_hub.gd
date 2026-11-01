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
## Fight offers (D304) show under This week, each as a scouting card with Take the fight and Turn it down; once he's
## booked, Go to camp replaces the week's buttons, and Turn pro shows when he can.

signal week_pressed
signal advance_pressed
signal title_pressed
signal camp_pressed
signal accept_pressed(offer_id: String)
signal decline_pressed(offer_id: String)
signal turn_pro_pressed

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
## How an offer's kind reads (Matchmaker.DIFFICULTIES).
const DIFFICULTY_TEXT := { "easier": "a bit easier", "even": "about even", "harder": "a bit harder",
	"tournament": "his first round" }
## Medal colours on his card and fights list (D315).
const MEDAL_COLOURS := { "gold": Color("#ffd43b"), "silver": Color("#ced4da"), "bronze": Color("#e8a26a") }
## The attribute groups an offer's scouting grades show.
const SCOUTED_GROUPS: Array[String] = ["Striking", "Wrestling", "Grappling", "Physical"]

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
var _camp: Button
var _pro: Button
var _offers: VBoxContainer
var _offer_ids: Array[String] = []
var _fights_text: RichTextLabel
var _calendar: HBoxContainer
var _scrolls: Array[ScrollContainer] = []
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
	fighter_box.add_child(_scroll(fighter_row))
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
	_bars = StatBars.new()
	stats_box.add_child(_scroll(_bars))

	var week_card := _card(Vector2(0.0, 0.0))
	week_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(week_card)
	var week_box: VBoxContainer = week_card.get_child(0)
	week_box.add_child(_heading("This week"))
	# The week's news and the offers scroll together above the buttons, which stay put (D340).
	var news := VBoxContainer.new()
	news.add_theme_constant_override("separation", 12)
	_week_text = _rich()
	news.add_child(_week_text)
	_offers = VBoxContainer.new()
	_offers.add_theme_constant_override("separation", 8)
	news.add_child(_offers)
	week_box.add_child(_scroll(news))
	_camp = CampPlanner._button(week_box, "Go to camp", func() -> void: camp_pressed.emit())
	CampPlanner.style_fight_button(_camp, 30)
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
	_advance.tooltip_text = "Runs weeks on his plan until he's hurt or healed, cleared to fight, worn down, has a birthday, school breaks up or starts again, or offers come in (up to %d weeks)" % Career.ADVANCE_MAX_WEEKS
	_pro = CampPlanner._button(week_box, "Turn pro", func() -> void: turn_pro_pressed.emit())
	_pro.tooltip_text = "From now his fights count on his pro record, under pro rules, for a purse"
	var title: Button = CampPlanner._button(week_box, "Save and go to the title", func() -> void: title_pressed.emit())
	title.custom_minimum_size.y = 44.0

	var fights_card := _card(Vector2(340.0, 0.0))
	body.add_child(fights_card)
	var fights_box: VBoxContainer = fights_card.get_child(0)
	fights_box.add_child(_heading("His fights"))
	_fights_text = _rich()
	fights_box.add_child(_scroll(_fights_text))

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
	_line.text = "Age %d · %s · coached by %s" % [career.age(), records, coach_text(career)]
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
	var booked: bool = not career.booked.is_empty()
	_week.visible = not booked
	_advance.visible = not booked
	_plan.disabled = booked
	_camp.visible = booked
	if booked:
		var left: int = career.camp_weeks_left()
		_camp.text = "Go to camp: %d week%s to fight night" % [left, "" if left == 1 else "s"]
	_pro.visible = Matchmaker.can_turn_pro(career)
	_show_offers()
	_fights_text.text = fights_text(career)
	_show_calendar(career.calendar())
	for scroll in _scrolls:
		scroll.scroll_vertical = 0


## Sets the week plan he runs between fights (a data/week_plans id).
func pick_plan(id: String) -> void:
	if career == null or not id in _plan_ids:
		return
	career.week_plan = id
	_plan.select(_plan_ids.find(id))
	_week_text.text = week_text(career, [])


## Who coaches him, for the top bar: "Sam Reed (Tactician)", or the name alone for a career saved before D311.
static func coach_text(c: Career) -> String:
	var specialty: String = Coach.specialty_name(c.coach_specialty)
	return c.coach_name + (" (%s)" % specialty if specialty != "" else "")


## The fighter card's text: background and hometown, stance and frame, gifts and flaws he knows of, scouted potential.
static func fighter_card_text(c: Career, gift_names: Dictionary = {}, flaw_names: Dictionary = {}) -> String:
	var p: Dictionary = c.fighter
	var lines: Array[String] = []
	var bg_id: String = String(c.about.get("background", ""))
	var bg_name: String = String(BackgroundLibrary.shared().get_background(bg_id).name) if BackgroundLibrary.shared().has(bg_id) else ""
	if bg_name != "":
		var second: String = String(c.childhood.get("second", ""))
		if second != "" and BackgroundLibrary.shared().has(second):
			bg_name += ", with a bit of %s" % String(BackgroundLibrary.shared().get_background(second).name).to_lower()
		lines.append("[b]%s[/b]" % bg_name)
	var town: String = ", ".join([c.about.get("hometown", ""), c.about.get("country", "")].filter(func(s: String) -> bool: return s != ""))
	if town != "":
		lines.append("From %s" % town)
	if not c.gym.is_empty():
		lines.append("Trains at %s (%s)" % [String(c.gym.get("name", "")), Gym.kind_line(c.gym)])
	var medals: String = medals_text(c)
	if medals != "":
		lines.append(medals)
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
	for person: Variant in c.childhood.get("people", []):
		if person is Dictionary:
			lines.append(Childhood.person_text(person))
	if c.coach_specialty != "":
		lines.append("[color=%s]Your specialty:[/color] %s. %s" % [DIM.to_html(false), Coach.specialty_name(c.coach_specialty),
			Coach.specialty_does(c.coach_specialty)])
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


## His tournament medals (D315) as his card shows them: "Medals: gold, Leeds Amateur Open 2027 · bronze, …", newest
## first. "" when he has none.
static func medals_text(c: Career) -> String:
	if c.medals.is_empty():
		return ""
	var bits: Array[String] = []
	for i in range(c.medals.size() - 1, -1, -1):
		var m: Dictionary = c.medals[i]
		bits.append("[color=%s]%s[/color], %s" % [(MEDAL_COLOURS.get(String(m.medal), WARN) as Color).to_html(false), String(m.medal), String(m.name)])
	return "Medals: " + " · ".join(bits)


## The style he's leaning toward (D88: a hint past ±30) and any named style traits, or "no clear style yet".
static func style_text(style: StyleLeanings) -> String:
	var bits: Array[String] = []
	for leaning in StyleLeanings.LEANINGS:
		var hint: String = style.hint(leaning)
		if hint != "":
			bits.append(hint)
	bits.append_array(style.traits())
	return ", ".join(bits) if not bits.is_empty() else "no clear style yet"


## An offer as its card reads: who, what style and how he compares, where from, the scouts' read, the grades, the date,
## camp and rules, and the money.
static func offer_text(c: Career, o: Dictionary, groups: Dictionary = {}) -> String:
	var p: Dictionary = o.get("profile", {})
	var about: Dictionary = o.get("about", {})
	var style_id: String = String(o.get("style", ""))
	var style: Dictionary = StyleLibrary.shared().get_style(style_id) if StyleLibrary.shared().has(style_id) else {}
	var lines: Array[String] = []
	var t: Dictionary = o.get("tournament", {}) if o.get("tournament") is Dictionary else {}
	if not t.is_empty():
		var size: int = int(t.get("size", 4))
		lines.append("[color=%s][b]One-day tournament: %d men[/b][/color], up to %d fights on the day, a medal for the top %d." % [
			GOOD.to_html(false), size, Tournament.rounds(size), 4 if size > Tournament.SIZES[0] else 2])
		lines.append("First up, in the %s:" % Tournament.stage_name(size, 0).to_lower())
	var nick: String = String(about.get("nickname", ""))
	lines.append("[b]%s[/b]%s" % [String(p.get("name", "")), (" '%s'" % nick) if nick != "" else ""])
	lines.append("[color=%s]%s · %s[/color]" % [WARN.to_html(false), String(style.get("name", style_id)), DIFFICULTY_TEXT.get(String(o.get("difficulty", "")), "")])
	var card: String = Matchmaker.card_text(o.get("card", {}) if o.get("card") is Dictionary else {})
	if card != "":
		lines.append("On %s" % card)
	var frame: Dictionary = p.get("frame", {})
	lines.append("From %s, %s · age %d · %d cm · %s" % [String(about.get("hometown", "")), String(about.get("country", "")), int(p.get("age", 0)),
		int(frame.get("height_cm", 0)), String(p.get("stance", "orthodox"))])
	var scouting: Dictionary = style.get("scouting", {})
	if scouting.has("summary"):
		lines.append("[i]%s[/i]" % String(scouting.summary))
	lines.append("[color=%s]Scouted:[/color] %s" % [DIM.to_html(false), scouted_grades(p.get("stats", {}), groups)])
	var fight_week: int = int(o.get("week", c.week))
	lines.append("Fight night %s · a %d-week camp · %s" % [c.date_text(5, fight_week), fight_week - c.week + 1, rules_name(String(o.get("ruleset", "")))])
	if not t.is_empty():
		lines.append("[color=%s]Win and he goes on that night against harder men who've had fights of their own; what each fight does to him carries into the next.[/color]" % DIM.to_html(false))
	lines.append(purse_text(o.get("purse", {})))
	if int(o.get("expires", c.week)) == c.week:
		lines.append("[color=%s]Last week to answer.[/color]" % BAD.to_html(false))
	return "\n".join(lines)


## Grades by attribute group for a profile's stats, e.g. "Striking B · Wrestling C · Grappling D · Physical C".
static func scouted_grades(stats: Dictionary, groups: Dictionary) -> String:
	var bits: Array[String] = []
	for group in SCOUTED_GROUPS:
		var total: float = 0.0
		var n: int = 0
		for id: String in groups:
			if String(groups[id]) == group:
				total += float(stats.get(id, FighterState.DEFAULT_STAT))
				n += 1
		if n > 0:
			bits.append("%s %s" % [group, TrainingCamp.grade(total / n)])
	return " · ".join(bits)


## A ruleset's name, e.g. "Teen amateur MMA (16–17)".
static func rules_name(ruleset_id: String) -> String:
	if ruleset_id == "":
		return ""
	var r: Ruleset = Ruleset.load_id(ruleset_id)
	return r.name if r != null else ruleset_id


static func purse_text(purse: Dictionary) -> String:
	if purse.is_empty():
		return "Amateur: no purse"
	return "$%d to show, $%d more to win" % [int(purse.get("show", 0)), int(purse.get("win", 0))]


func _show_offers() -> void:
	for child in _offers.get_children():
		_offers.remove_child(child)
		child.queue_free()
	_offer_ids.clear()
	for o: Dictionary in career.offers:
		var id: String = String(o.id)
		_offer_ids.append(id)
		var tile := PanelContainer.new()
		var style: StyleBoxFlat = FightHud._panel_style(TILE)
		style.set_content_margin_all(12)
		tile.add_theme_stylebox_override("panel", style)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		tile.add_child(box)
		var label := RichTextLabel.new()
		label.bbcode_enabled = true
		label.fit_content = true
		label.scroll_active = false
		label.add_theme_font_size_override("normal_font_size", 16)
		label.add_theme_color_override("default_color", TEXT)
		label.text = offer_text(career, o, _groups)
		box.add_child(label)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		var take: Button = CampPlanner._button(row, "Take the fight", func() -> void: accept_pressed.emit(id))
		take.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var turn_down: Button = CampPlanner._button(row, "Turn it down", func() -> void: decline_pressed.emit(id))
		turn_down.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_offers.add_child(tile)


## The ids of the offers on screen, top to bottom.
func offer_ids() -> Array[String]:
	return _offer_ids.duplicate()


## For tests: presses an offer's Take the fight, Turn it down, Go to camp or Turn pro, as a click would.
func press_accept(offer_id: String) -> void:
	if offer_id in _offer_ids:
		accept_pressed.emit(offer_id)


func press_decline(offer_id: String) -> void:
	if offer_id in _offer_ids:
		decline_pressed.emit(offer_id)


func press_camp() -> void:
	if _camp.visible:
		_camp.pressed.emit()


func press_turn_pro() -> void:
	if _pro.visible:
		_pro.pressed.emit()


func can_turn_pro() -> bool:
	return _pro.visible


## What the week holds (an offer, a booked fight, hurt, suspended, free), his plan and savings, and what the last
## Run this week or Advance did.
static func week_text(c: Career, reports: Array = []) -> String:
	var lines: Array[String] = []
	if not c.offers.is_empty():
		lines.append("[color=%s]%d fight offer%s waiting: take one, or let them go.[/color]" % [WARN.to_html(false), c.offers.size(), "" if c.offers.size() == 1 else "s"])
	if not c.booked.is_empty():
		var who: Dictionary = c.booked_opponent()
		var on: String = String(c.booked.get("card", {}).get("name", "")) if c.booked.get("card") is Dictionary else ""
		if c.tournament_stage() >= 0:
			var size: int = int(c.booked.tournament.size)
			var stage: String = Tournament.stage_name(size, c.tournament_stage()).to_lower()
			if c.tournament_stage() > 0:
				lines.append("[color=%s]Booked:[/color] the %s of the %s, vs %s, today. Go to camp to fight it, or pull out from there." % [
					RED_CORNER.to_html(false), stage, on, String(who.get("name", ""))])
			else:
				lines.append("[color=%s]Booked:[/color] the %s, a one-day tournament for %d, %s (%s). First up, in the %s: %s. His camp runs from Go to camp." % [
					RED_CORNER.to_html(false), on, size, c.date_text(5, int(c.booked.get("week", c.week))),
					rules_name(String(c.booked.get("ruleset", ""))), stage, String(who.get("name", ""))])
		else:
			lines.append("[color=%s]Booked:[/color] vs %s, %s%s (%s). His camp runs from Go to camp." % [RED_CORNER.to_html(false),
				String(who.get("name", "")), c.date_text(5, int(c.booked.get("week", c.week))), (" on " + on) if on != "" else "",
				rules_name(String(c.booked.get("ruleset", "")))])
	if c.trainee.injured_days > 0:
		lines.append("[color=%s]Hurt (%s): %d days to heal.[/color]" % [BAD.to_html(false), c.trainee.injury_area, c.trainee.injured_days])
	if c.suspended_days > 0:
		lines.append("Suspended: %d days until he can fight." % c.suspended_days)
	if c.offers.is_empty() and c.booked.is_empty() and c.trainee.injured_days == 0 and c.suspended_days == 0:
		lines.append("Free to fight: offers come in every few weeks.")
	if c.booked.is_empty():
		lines.append("This week: the %s plan." % String(TrainingLibrary.shared().plan(c.week_plan).get("name", c.week_plan)).to_lower())
	var school: String = School.week_line(c)
	if school != "":
		lines.append(school)
	var advice: Dictionary = Matchmaker.pro_advice(c)
	if not advice.is_empty():
		var colour: Color = GOOD if String(advice.word) in [Matchmaker.PRO_WISE, Matchmaker.PRO_LATE] else (WARN if String(advice.word) == Matchmaker.PRO_RISKY else DIM)
		lines.append("[color=%s]%s[/color]" % [colour.to_html(false), String(advice.text)])
	if c.gym_owed > 0:
		lines.append("[color=%s]Owes the gym $%d: he works Saturdays there ($%d a week) until it's paid.[/color]" % [WARN.to_html(false), c.gym_owed, Gym.shift_week_pay()])
	lines.append("Savings: $%d" % c.money + (" · the gym is $%d a month" % int(c.gym.get("fee", 0)) if not c.gym.is_empty() else ""))
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
	var fees: int = 0
	for report: Dictionary in reports:
		fees += int(report.get("gym_fee", 0))
	var worked: int = 0
	for report: Dictionary in reports:
		worked += int(report.get("gym_worked", 0))
	if fees > 0:
		out += ("" if out.ends_with(".") else ".") + " Paid the gym $%d." % fees
	if worked > 0:
		out += ("" if out.ends_with(".") else ".") + " Worked $%d off at the gym." % worked
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
		var on: String = String(f.get("card", {}).get("name", "")) if f.get("card") is Dictionary else ""
		if f.get("tournament") is Dictionary:
			on += ", %s" % Tournament.stage_name(int(f.tournament.size), int(f.tournament.stage)).to_lower()
			if String(f.get("medal", "")) != "":
				on += " · [color=%s]%s[/color]" % [(MEDAL_COLOURS.get(String(f.medal), WARN) as Color).to_html(false), String(f.medal)]
		lines.append("[color=%s]%s · %s%s[/color]" % [DIM.to_html(false), c.date_text(5, int(f.get("week", 0))), "pro" if bool(f.get("pro", false)) else "amateur",
			(" · " + on) if on != "" else ""])
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
	var offer_cards: Array[String] = []
	for tile in _offers.get_children():
		offer_cards.append((tile.get_child(0).get_child(0) as RichTextLabel).get_parsed_text())
	return "%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s" % [_who.text, _line.text, _date.text, _card_text.get_parsed_text(), _week_text.get_parsed_text(),
		"\n".join(offer_cards), _camp.text if _camp.visible else "", _fights_text.get_parsed_text(), " | ".join(tiles)]


## For tests: the scrolling parts, top to bottom of each card left to right (the fighter, his stats, this week's news
## and offers, his fights; D340).
func scrolls() -> Array[ScrollContainer]:
	return _scrolls.duplicate()


func focus_first() -> void:
	FightHud.focus_later(_camp if _camp.visible else _week)


func press_week() -> void:
	_week.pressed.emit()


func press_advance() -> void:
	_advance.pressed.emit()


func _rich() -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.add_theme_font_size_override("normal_font_size", 18)
	label.add_theme_color_override("default_color", TEXT)
	return label


## Wraps a card's long part so it scrolls inside the card (mouse wheel or drag) instead of pushing the hub past the bottom
## of the screen (D340). The card's buttons and headings sit outside it and stay put.
func _scroll(content: Control) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	_scrolls.append(scroll)
	return scroll


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
