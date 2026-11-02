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
## The Coach's Notebook button (D316): every tip he's seen, to read again.
signal notebook_pressed
## The division list (D352): the men in his division this week.
signal division_pressed
signal promotions_pressed
## The rankings page (D355): each promotion's table in his division and its last moves.
signal rankings_pressed
## Asking the promotion a step up for a fight (D357, Climb.ask).
signal ask_pressed
## The history page (D358): each belt's champions in his division and the legends.
signal history_pressed

## Around his division (D353, news_text): at most NEWS_MAX lines; a winner who had under UPSET_CHANCE is an upset; a man
## averaging NEWS_BEST or more is one of the best.
const NEWS_MAX: int = 4
const UPSET_CHANCE: float = 0.35
## A fight between two ranked men, one of them in his table's top NEWS_TOP_RANK, is a bit more news (D355).
const NEWS_TOP_RANK: int = 5
const NEWS_BEST: float = 58.0

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
## Why the Coach's pick is the one to take, by lesson (D316, Tutorial.LESSONS).
const LESSON_TEXT: Array[String] = [
	"a good first fight: a bit easier than him, to learn the calls on",
	"a kicker: the fight to learn Catch the kick! on",
	"a man about his level, with every call open",
]
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
var _ask: Button
## The division he turns pro in (D351): his natural one or one either side.
var _pro_division: OptionButton
var _pro_division_ids: Array[String] = []
var _offers: VBoxContainer
var _offer_ids: Array[String] = []
var _fights_text: RichTextLabel
var _calendar: HBoxContainer
var _scrolls: Array[ScrollContainer] = []
var _notebook: Button
var _division: Button
var _promotions: Button
var _rankings: Button
var _history: Button
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
	var notebook := Button.new()
	notebook.text = "Coach's Notebook"
	notebook.tooltip_text = "Every tip you've seen, to read again"
	notebook.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	notebook.add_theme_font_size_override("font_size", 18)
	notebook.pressed.connect(func() -> void: notebook_pressed.emit())
	top.add_child(notebook)
	_notebook = notebook
	var division := Button.new()
	division.text = "His division"
	division.tooltip_text = "The men in his division this week"
	division.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	division.add_theme_font_size_override("font_size", 18)
	division.pressed.connect(func() -> void: division_pressed.emit())
	top.add_child(division)
	_division = division
	var promotions := Button.new()
	promotions.text = "Promotions"
	promotions.tooltip_text = "The world's promotions, their next cards and their last results"
	promotions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	promotions.add_theme_font_size_override("font_size", 18)
	promotions.pressed.connect(func() -> void: promotions_pressed.emit())
	top.add_child(promotions)
	_promotions = promotions
	var rankings := Button.new()
	rankings.text = "Rankings"
	rankings.tooltip_text = "Each promotion's rankings in his division, and who moved and why"
	rankings.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rankings.add_theme_font_size_override("font_size", 18)
	rankings.pressed.connect(func() -> void: rankings_pressed.emit())
	top.add_child(rankings)
	_rankings = rankings
	var history := Button.new()
	history.text = "History"
	history.tooltip_text = "Every promotion's champions in his division, and the legends"
	history.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	history.add_theme_font_size_override("font_size", 18)
	history.pressed.connect(func() -> void: history_pressed.emit())
	top.add_child(history)
	_history = history
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
	_ask = CampPlanner._button(week_box, "Ask for a step up", func() -> void: ask_pressed.emit())
	_pro_division = OptionButton.new()
	_pro_division.tooltip_text = "The division he turns pro in and stays in: his natural one, or one either side of it"
	week_box.add_child(_pro_division)
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
	_date.text = "%s\nWEEK %d" % [career.date_text(), career.week - career.start_week + 1]
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
	_pro_division.visible = _pro.visible
	_ask.visible = Climb.can_ask(career)
	if _ask.visible:
		var up: Dictionary = Climb.up(career.world())
		_ask.text = "Ask the %s for a step up" % String(up.short)
		_ask.tooltip_text = "A yes is a tryout on the %s's card: win it and they sign him. About %d%% at his ranking; a no means waiting 3 months to ask again" % [
			String(up.name), roundi(Climb.ask_chance(career.world()) * 100.0)]
	_pro_division_ids.clear()
	_pro_division.clear()
	if _pro.visible:
		var home: String = career.natural_division()
		for id: String in Weight.debut_choices(career.fighter.get("frame", {})):
			_pro_division_ids.append(id)
			var why: String = "his natural division" if id == home else ("a bigger cut" if Weight.ids().find(id) < Weight.ids().find(home) else "heavier than his natural one")
			_pro_division.add_item("%s: %s" % [Weight.label(id), why])
		_pro_division.select(_pro_division_ids.find(home))
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
	lines.append(weight_text(c))
	var ranked: String = his_rank_text(c)
	if ranked != "":
		lines.append(ranked)
	var ladder: String = Climb.ladder_text(c)
	if ladder != "":
		lines.append("[color=%s]Ladder:[/color] %s" % [DIM.to_html(false), ladder])
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
	if String(o.get("title", "")) != "":
		var w: World = c.world()
		var what: String = { "defence": "Title defence", "vacant": "For the vacant title", "shot": "Title shot" }.get(String(o.get("title_how", "")), "Title fight")
		lines.append("[color=%s][b]%s:[/b][/color] %s, 5 rounds, double pay" % [WARN.to_html(false), what, Titles.title_name(w, String(o.title))])
	var step_to: Dictionary = Promotions.by_id(c.world(), String(o.get("to", ""))) if c.pro else {}
	if String(o.get("step", "")) == Climb.CALL_UP and not step_to.is_empty():
		lines.append("[color=%s][b]Call-up:[/b][/color] the %s want to sign him. Take this fight and his fights are theirs from now%s; turn it down and he stays." % [
			GOOD.to_html(false), String(step_to.name), ", and his belt goes vacant" if Titles.held_by(c.world(), Career.FIGHTER_ID) != "" else ""])
	elif String(o.get("step", "")) == Climb.TRYOUT and not step_to.is_empty():
		lines.append("[color=%s][b]Tryout:[/b][/color] a fight on the %s's card. Win it and they sign him; lose it and he's back where he was." % [
			GOOD.to_html(false), String(step_to.name)])
	if String(o.get("eliminator", "")) != "":
		lines.append("[color=%s][b]Title eliminator:[/b][/color] win it and he's next in line for %s" % [WARN.to_html(false), Titles.title_name(c.world(), String(o.eliminator))])
	if int(o.get("lesson", 0)) > 0:
		lines.append("[color=%s][b]Coach's pick[/b][/color] · %s" % [GOOD.to_html(false), LESSON_TEXT[clampi(int(o.lesson) - 1, 0, LESSON_TEXT.size() - 1)]])
	var nick: String = String(about.get("nickname", ""))
	var record: String = String(about.get("record", ""))
	lines.append("[b]%s[/b]%s%s" % [String(p.get("name", "")), (" '%s'" % nick) if nick != "" else "",
		(" · %s %s" % [record, "pro" if bool(o.get("pro", false)) else "amateur"]) if record != "" else ""])
	lines.append("[color=%s]%s · %s[/color]" % [WARN.to_html(false), String(style.get("name", style_id)), DIFFICULTY_TEXT.get(String(o.get("difficulty", "")), "")])
	var ranked: String = opponent_rank_text(c, String(p.get("id", "")))
	if ranked != "":
		lines.append(ranked)
	var card: String = Matchmaker.card_text(o.get("card", {}) if o.get("card") is Dictionary else {})
	if card != "":
		lines.append("On %s" % card)
	var frame: Dictionary = p.get("frame", {})
	lines.append("From %s, %s · age %d · %d cm · %s · %s" % [String(about.get("hometown", "")), String(about.get("country", "")), int(p.get("age", 0)),
		int(frame.get("height_cm", 0)), Weight.kg_text(Weight.walk_kg(frame, float(p.get("age", 0)) + 0.5)), String(p.get("stance", "orthodox"))])
	if String(o.get("division", "")) != "":
		lines.append("A %s bout" % Weight.name_of(String(o.division)).to_lower())
	var scouting: Dictionary = style.get("scouting", {})
	if scouting.has("summary"):
		lines.append("[i]%s[/i]" % String(scouting.summary))
	var plan: Variant = style.get("gameplan", {})
	if plan is Dictionary and not plan.is_empty():
		lines.append("[color=%s]%s[/color]" % [WARN.to_html(false), GameplanPicker.expect_text(plan)])
	lines.append("[color=%s]Scouted:[/color] %s" % [DIM.to_html(false), scouted_grades(p.get("stats", {}), groups)])
	var fight_week: int = int(o.get("week", c.week))
	lines.append("Fight night %s · a %d-week camp · %s" % [c.date_text(5, fight_week), fight_week - c.week + 1, rules_name(String(o.get("ruleset", "")))])
	if not t.is_empty():
		lines.append("[color=%s]Win and he goes on that night against harder men who've had fights of their own; what each fight does to him carries into the next.[/color]" % DIM.to_html(false))
	lines.append(purse_text(o.get("purse", {})))
	if int(o.get("expires", c.week)) == c.week:
		lines.append("[color=%s]Last week to answer.[/color]" % BAD.to_html(false))
	return "\n".join(lines)


## The offer's man in the rankings (D355): "Ranked #4 in the ICF's lightweight rankings" ("" when he isn't).
static func opponent_rank_text(c: Career, id: String) -> String:
	if not c.pro or id == "":
		return ""
	var w: World = c.world()
	var r: int = Rankings.rank_of(w, id)
	var m: Dictionary = w.man(id)
	var p: Dictionary = Promotions.of(w, m)
	var belt: String = Titles.held_by(w, id)
	if belt != "":
		return "[color=%s]Champion[/color]: holds %s" % [WARN.to_html(false), Titles.title_name(w, belt)]
	var former: String = History.former_tag(w, id)
	if r <= 0 or p.is_empty():
		return ("[color=%s]A %s[/color]" % [WARN.to_html(false), former]) if former != "" else ""
	return "[color=%s]Ranked #%d[/color] in the %s's %s rankings%s" % [GOOD.to_html(false), r, String(p.short),
		Weight.name_of(String(m.get("division", ""))).to_lower(), (" · a " + former) if former != "" else ""]


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
func press_notebook() -> void:
	_notebook.pressed.emit()


func press_division() -> void:
	_division.pressed.emit()


func press_promotions() -> void:
	_promotions.pressed.emit()


func press_rankings() -> void:
	_rankings.pressed.emit()


func press_history() -> void:
	_history.pressed.emit()


## His place in the rankings for his card (D355): "Ranked #4 in the ICF's lightweight rankings", or that he isn't yet
## ("" while he's an amateur).
static func his_rank_text(c: Career) -> String:
	if not c.pro:
		return ""
	var w: World = c.world()
	var belt: String = Titles.held_by(w, Career.FIGHTER_ID)
	if belt != "":
		return "[color=%s][b]Champion:[/b][/color] %s, %d defence%s" % [WARN.to_html(false), Titles.title_name(w, belt).trim_prefix("the "),
			int(Titles.belt(w, belt).defences), "" if int(Titles.belt(w, belt).defences) == 1 else "s"]
	var r: int = Rankings.rank_of(w, Career.FIGHTER_ID)
	var p: Dictionary = Promotions.by_id(w, String(w.him.get("promotion", "")))
	if r > 0 and not p.is_empty():
		var k: String = Rankings.key(String(p.id), String(w.him.division))
		var next: String = ", next in line for the title" if String(Titles.belt(w, k).get("next", "")) == Career.FIGHTER_ID else ""
		return "[color=%s]Ranked #%d[/color] in the %s's %s rankings%s" % [GOOD.to_html(false), r, String(p.short),
			Weight.name_of(String(w.him.division)).to_lower(), next]
	return "[color=%s]Not ranked yet: a fight on a promotion's card puts him in its rankings[/color]" % DIM.to_html(false)


## His hometown's legend (D358): "The IML's best ever: Lewis Ward 'the Hammer', from Leeds, 3 reigns as welterweight
## champion (2016–2021), 2 defences; retired 2024." ("" when there's none, or for a career saved before D358 with none).
static func home_legend_text(c: Career) -> String:
	var w: World = c.world()
	if w.reigns.is_empty():
		return ""  # No history yet (a career saved before D358): nobody to look back on.
	var id: String = History.home_legend(w)
	if id == "":
		return ""
	var m: Dictionary = w.man(id)
	var home: Dictionary = Promotions.home(w)
	var reigns: Array = History.reigns_of(w, id).filter(func(r: Array) -> bool: return String(r[0]).get_slice(":", 0) == String(home.id))
	var defences: int = 0
	var first: int = 1 << 30
	var last: int = -(1 << 30)
	var divisions: Dictionary = {}
	for r: Array in reigns:
		defences += int(r[3])
		first = mini(first, int(r[1]))
		last = maxi(last, int(r[2]) if int(r[2]) >= 0 else c.week)
		divisions[Weight.name_of(String(r[0]).get_slice(":", 1)).to_lower()] = true
	var nick: String = String(m.get("nickname", ""))
	var now: String = "retired %d" % c.year_of(int(m.retired)) if not World.active(m) else "still fighting"
	return "[color=%s]The %s's best ever:[/color] %s%s, from %s, %s %s champion (%d–%d), %d defence%s; %s." % [WARN.to_html(false),
		String(home.short), String(m.get("name", "")), (" '%s'" % nick) if nick != "" else "", String(m.get("hometown", "")),
		("%d reigns as" % reigns.size()) if reigns.size() > 1 else "the", " and ".join(divisions.keys()),
		c.year_of(first), c.year_of(last), defences, "" if defences == 1 else "s", now]


## The history page's title (D358).
static func history_title(c: Career) -> String:
	return "History · %s" % Weight.name_of(c.division_now())


## The history page (D358): his hometown's legend, then every promotion's champions in his division, biggest first,
## newest first (when, defences, how it ended), then the world's legends in every division.
static func history_text(c: Career) -> String:
	var w: World = c.world()
	var division: String = c.division_now()
	var parts: Array[String] = []
	var legend: String = home_legend_text(c)
	if legend != "":
		parts.append(legend)
	var ordered: Array = w.promotions.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.rank) < int(b.rank) if int(a.rank) != int(b.rank) else String(a.id) < String(b.id))
	for p: Dictionary in ordered:
		var k: String = Rankings.key(String(p.id), division)
		var lines: Array[String] = ["[color=%s][b]%s %s champions[/b][/color]" % [WARN.to_html(false), String(p.name), Weight.name_of(division).to_lower()]]
		for r: Array in History.line_of(w, k):
			lines.append(_reign_line(c, w, String(r[0]), r))
		if lines.size() == 1:
			lines.append("[color=%s]Nobody's held it yet.[/color]" % DIM.to_html(false))
		parts.append("
".join(lines))
	var legends: Array = History.legends(w)
	var lines: Array[String] = ["[color=%s][b]LEGENDS[/b][/color] · the world organisation's champions, and anyone who defended a belt %d times" % [
		WARN.to_html(false), History.LEGEND_DEFENCES]]
	for id: String in legends.slice(0, History.LEGENDS_SHOWN):
		var m: Dictionary = w.man(id)
		var name: String = c.fighter_name() if id == Career.FIGHTER_ID else String(m.get("name", ""))
		var belts: Array[String] = []
		for r: Array in History.reigns_of(w, id):
			belts.append("%s %s%s" % [String(Promotions.by_id(w, String(r[0]).get_slice(":", 0)).get("short", "")),
				Weight.name_of(String(r[0]).get_slice(":", 1)).to_lower(), (" (%d)" % int(r[3])) if int(r[3]) > 0 else ""])
		var record: String = c.record_text(true) if id == Career.FIGHTER_ID else World.record_text(m)
		var status: String = "still fighting" if id == Career.FIGHTER_ID or World.active(m) else "retired %d" % c.year_of(int(m.retired))
		lines.append("[b]%s[/b] · %s · %s · %s
[color=%s]%s[/color]" % [name, String(m.get("country", c.about.get("country", ""))), record, status,
			DIM.to_html(false), ", ".join(belts)])
	if legends.is_empty():
		lines.append("[color=%s]None yet.[/color]" % DIM.to_html(false))
	parts.append("
".join(lines))
	return "

".join(parts)


## One reign on a belt's line: "2019–2022 Lewis Ward (England) · 4 defences · lost it" (or "since 2026 …").
static func _reign_line(c: Career, w: World, id: String, r: Array) -> String:
	var name: String = c.fighter_name() if id == Career.FIGHTER_ID else String(w.man(id).get("name", ""))
	var country: String = String(c.about.get("country", "")) if id == Career.FIGHTER_ID else String(w.man(id).get("country", ""))
	var won: int = c.year_of(int(r[1]))
	var lost: int = c.year_of(int(r[2]))
	var when: String = ("since %d" % won) if int(r[2]) < 0 else (str(won) if lost == won else "%d–%d" % [won, lost])
	var how: String = { "lost": "lost it", "retired": "retired", "stripped": "stripped", "called up": "called up", "left": "moved on" }.get(String(r[4]), "")
	var defences: int = int(r[3])
	return "%s %s (%s) · %d defence%s%s" % [when, name, country, defences, "" if defences == 1 else "s", (" · " + how) if how != "" else ""]


## The rankings page's title (D355): "Lightweight rankings".
static func rankings_title(c: Career) -> String:
	return "%s rankings" % Weight.name_of(c.division_now())


## The rankings page (D355): each promotion's table in his division, biggest promotion first (#1 first: name, record,
## where he's from, him picked out), then its last moves and why: the men who fought, came on or went off (the shuffles
## on others' results counted, not listed).
static func rankings_text(c: Career) -> String:
	var w: World = c.world()
	var division: String = c.division_now()
	var ordered: Array = w.promotions.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.rank) < int(b.rank) if int(a.rank) != int(b.rank) else String(a.id) < String(b.id))
	var parts: Array[String] = []
	var his: String = his_rank_text(c)
	if his != "":
		parts.append(his)
	for p: Dictionary in ordered:
		var ids: Array = Rankings.table(w, String(p.id), division)
		var lines: Array[String] = ["[color=%s][b]%s[/b] (%s) · top %d[/color]" % [WARN.to_html(false), String(p.name), String(p.short),
			Rankings.size_for(p)]]
		lines.append(champion_line(c, w, Rankings.key(String(p.id), division)))
		if ids.is_empty():
			lines.append("[color=%s]Nobody ranked yet.[/color]" % DIM.to_html(false))
		for i in ids.size():
			var id: String = String(ids[i])
			if id == Career.FIGHTER_ID:
				lines.append("[color=%s][b]%d. %s[/b] (%s) · you[/color]" % [GOOD.to_html(false), i + 1, c.fighter_name(), c.record_text(true)])
				continue
			var m: Dictionary = w.man(id)
			var former: String = History.former_tag(w, id)
			lines.append("%d. %s (%s) · %s%s" % [i + 1, String(m.get("name", "")), World.record_text(m), String(m.get("country", "")),
				(" · [color=%s]%s[/color]" % [WARN.to_html(false), former]) if former != "" else ""])
		var note: Dictionary = w.ranking_moves.get(Rankings.key(String(p.id), division), {})
		if not (note.get("moves", []) as Array).is_empty():
			var week: int = int(note.week)
			var when: String = c.short_date(week, 5)
			if Promotions.has_card(p, week):
				when = "%s, %s" % [String(Promotions.card(w, p, week).short), when]
			var said: Array[String] = []
			var shuffled: int = 0
			for mv: Dictionary in note.moves:
				if String(mv.why).begins_with("others'"):
					shuffled += 1
					continue
				said.append(move_text(w, mv, c))
			if shuffled > 0:
				said.append("%d more moved on others' results" % shuffled)
			lines.append("[color=%s]Moves after %s:[/color]\n%s" % [DIM.to_html(false), when, "\n".join(said)])
		parts.append("\n".join(lines))
	return "\n\n".join(parts)


## A belt's line on the rankings page (D356): "Champion: Tom Hill (12-2-0), since Mar 2027, 2 defences" (him picked
## out), or that it's vacant.
static func champion_line(c: Career, w: World, k: String) -> String:
	var b: Dictionary = Titles.belt(w, k)
	var id: String = String(b.get("champion", ""))
	if id == "":
		return "[color=%s]Champion: vacant[/color]" % DIM.to_html(false)
	var name: String = c.fighter_name() if id == Career.FIGHTER_ID else String(w.man(id).get("name", ""))
	var record: String = c.record_text(true) if id == Career.FIGHTER_ID else World.record_text(w.man(id))
	var ymd: Array[int] = Career.civil_from_days(c.first_monday + int(b.won) * Career.DAYS_PER_WEEK)  # Before week 0 too.
	var when: String = "%s %d" % [Career.MONTHS[clampi(ymd[1] - 1, 0, 11)], ymd[0]]
	var defences: int = int(b.defences)
	return "[color=%s][b]Champion: %s[/b] (%s), since %s, %d defence%s%s[/color]" % [(GOOD if id == Career.FIGHTER_ID else WARN).to_html(false),
		name, record, when, defences, "" if defences == 1 else "s", " · you" if id == Career.FIGHTER_ID else ""]


## One ranking move: "Up 4 to #3, Obinna Eze: beat #6 Ryan Baker on the cards", "Into the top 15 at #7", "Out (was
## #15)".
static func move_text(w: World, mv: Dictionary, c: Career = null) -> String:
	var name: String = c.fighter_name() if c != null and String(mv.id) == Career.FIGHTER_ID else Rankings.name_of(w, String(mv.id))
	var from: int = int(mv.from)
	var to: int = int(mv.to)
	var what: String
	if to == 0:
		what = "[color=%s]Out[/color] (was #%d)" % [BAD.to_html(false), from]
	elif from == 0:
		what = "[color=%s]In at #%d[/color]" % [GOOD.to_html(false), to]
	elif to < from:
		what = "[color=%s]Up %d to #%d[/color]" % [GOOD.to_html(false), from - to, to]
	else:
		what = "[color=%s]Down %d to #%d[/color]" % [BAD.to_html(false), to - from, to]
	return "%s, %s: %s" % [what, name, String(mv.why)]


## The promotions page (D354): each promotion, biggest first: its name, kind, home city and venue, what it pays, its
## next cards, and its last card's results in his division.
static func promotions_text(c: Career) -> String:
	var w: World = c.world()
	var division: String = c.division_now()
	var parts: Array[String] = []
	var ordered: Array = w.promotions.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.rank) < int(b.rank) if int(a.rank) != int(b.rank) else String(a.id) < String(b.id))
	for p: Dictionary in ordered:
		var men: int = 0
		var his: int = 0
		for m: Dictionary in w.men.values():
			if World.active(m) and String(m.get("promotion", "")) == String(p.id):
				men += 1
				his += 1 if World.division_of(m, c.week) == division else 0
		var lines: Array[String] = []
		lines.append("[color=%s][b]%s[/b] (%s)[/color]" % [WARN.to_html(false), String(p.name), String(p.short)])
		lines.append("%s · from %s, %s · the %s, %s seats" % [String(p.kind), String(p.city),
			NameLibrary.shared().country_name(String(p.country)), String(p.venue), _thousands(int(p.capacity))])
		lines.append("[color=%s]Pays $%s to show and $%s more to win · %d men, %d at %s · a card every %d weeks[/color]" % [
			DIM.to_html(false), _thousands(int(p.show)), _thousands(int(p.win)), men, his, Weight.name_of(division).to_lower(), int(p.every)])
		var next: Array[String] = []
		for week: int in Promotions.card_weeks(p, c.week, c.week + 12).slice(0, 2):
			var card: Dictionary = Promotions.card(w, p, week)
			var mine: String = ""
			if not c.booked.is_empty() and int(c.booked.get("week", -1)) == week and String(c.booked.get("card", {}).get("promotion", "")) == String(p.id):
				mine = " · [color=%s]his fight[/color]" % GOOD.to_html(false)
			next.append("%s, %s (%s)%s" % [String(card.short), c.short_date(week, 5), String(card.city), mine])
		if not next.is_empty():
			lines.append("Next: " + "; ".join(next))
		if String(p.id) == String(Promotions.home(w).get("id", "")):
			var legend: String = home_legend_text(c)
			if legend != "":
				lines.append(legend)
		var last: Array[String] = []
		var last_week: int = -1
		var last_card: String = ""
		for r: Dictionary in w.results:
			if String(r.get("kind", "fight")) == "fight" and String(r.get("promotion", "")) == String(p.id) and String(r.division) == division \
					and int(r.week) >= last_week:
				if int(r.week) > last_week:
					last.clear()
				last_week = int(r.week)
				last_card = String(r.get("card", ""))
				last.append(_result_line(w, r))
		if not last.is_empty():
			lines.append("[color=%s]Last %s card, %s:[/color] %s" % [DIM.to_html(false), Weight.name_of(division).to_lower(), last_card, " ".join(last)])
		parts.append("\n".join(lines))
	return "\n\n".join(parts) if not parts.is_empty() else "[color=%s]No promotions yet.[/color]" % DIM.to_html(false)


## One fight's result: "Ryan Clarke beat Harry Hall by knockout in round 1." (draws too).
static func _result_line(w: World, r: Dictionary) -> String:
	var a: Dictionary = w.man(String(r.a))
	var b: Dictionary = w.man(String(r.b))
	if String(r.winner) == "draw":
		return "%s and %s fought to a draw." % [String(a.get("name", "")), String(b.get("name", ""))]
	var winner: Dictionary = a if String(r.winner) == "a" else b
	var loser: Dictionary = b if String(r.winner) == "a" else a
	return "%s beat %s %s." % [String(winner.get("name", "")), String(loser.get("name", "")), _how(String(r.method), int(r.round))]


static func _thousands(n: int) -> String:
	var digits: String = str(absi(n))
	var out: String = ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out


## The division list's title (D352): "Lightweight · 103 men".
static func division_title(c: Career) -> String:
	var id: String = c.division_now()
	return "%s · %d men" % [Weight.name_of(id), c.world().in_division(id, c.week).size()]


## The division list (D352): every man in his division this week, the ones he can be offered (amateurs while he's
## one, pros once he's pro) first, each part best first by what the scouts make of him, one line each: name and
## nickname, age, where he's from, his level, record and style, and how it went if he's fought him.
static func division_text(c: Career) -> String:
	var w: World = c.world()
	var men: Array[Dictionary] = w.in_division(c.division_now(), c.week)
	men.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var x: float = w.average(a)
		var y: float = w.average(b)
		return x > y if x != y else String(a.name) < String(b.name))
	var met: Dictionary = {}
	for f: Dictionary in c.fights:
		met[String(f.get("opponent", ""))] = String(f.get("result", ""))
	var parts: Array[String] = []
	for pros: bool in ([true, false] if c.pro else [false, true]):
		var lines: Array[String] = []
		for m: Dictionary in men:
			if bool(m.pro) == pros:
				lines.append(_division_line(c, w, m, met))
		if not lines.is_empty():
			parts.append("[color=%s][b]%s (%d)[/b][/color]\n%s" % [WARN.to_html(false), "PROS" if pros else "AMATEURS", lines.size(), "\n".join(lines)])
	return "\n\n".join(parts) if not parts.is_empty() else "[color=%s]Nobody yet.[/color]" % DIM.to_html(false)


static func _division_line(c: Career, w: World, m: Dictionary, met: Dictionary) -> String:
	var style_id: String = String(m.style)
	var style_name: String = String(StyleLibrary.shared().get_style(style_id).get("name", style_id)) if StyleLibrary.shared().has(style_id) else style_id
	var nick: String = String(m.get("nickname", ""))
	var line: String = "[b]%s[/b]%s · %d · %s, %s" % [String(m.name), (" '%s'" % nick) if nick != "" else "",
		int(floor(World.age_of(m, c.week))), String(m.hometown), String(m.country)]
	var promotion: Dictionary = Promotions.of(w, m)
	line += "\n[color=%s]%s%s · %s · %s · grade %s[/color]" % [DIM.to_html(false), World.level_name(m),
		(" · %s%s" % [("champion, " if Titles.held_by(w, String(m.id)) != "" else (Rankings.rank_text(w, String(m.id)) + " ") if Rankings.rank_of(w, String(m.id)) > 0 else ""), String(promotion.short)])
			if not promotion.is_empty() else "", World.record_text(m), style_name, TrainingCamp.grade(w.average(m))]
	var former: String = History.former_tag(w, String(m.id))
	if former != "":
		line += " · [color=%s]%s[/color]" % [WARN.to_html(false), former]
	if met.has(String(m.id)):
		var result: String = String(met[String(m.id)])
		line += " · [color=%s]you %s[/color]" % [(GOOD if result == "win" else BAD if result == "loss" else WARN).to_html(false),
			{ "win": "beat him", "loss": "lost to him", "draw": "drew with him" }.get(result, "fought him")]
	return line


func press_accept(offer_id: String) -> void:
	if offer_id in _offer_ids:
		accept_pressed.emit(offer_id)


func press_decline(offer_id: String) -> void:
	if offer_id in _offer_ids:
		decline_pressed.emit(offer_id)


func press_camp() -> void:
	if _camp.visible:
		_camp.pressed.emit()


## For tests: Ask for a step up, as a click would (D357).
func press_ask() -> void:
	if _ask.visible:
		_ask.pressed.emit()


func can_ask() -> bool:
	return _ask.visible


func press_turn_pro() -> void:
	if _pro.visible:
		_pro.pressed.emit()


func can_turn_pro() -> bool:
	return _pro.visible


## The division picked beside Turn pro ("" when it isn't showing).
func pro_division() -> String:
	var at: int = _pro_division.selected
	return _pro_division_ids[at] if _pro.visible and at >= 0 and at < _pro_division_ids.size() else ""


## For tests: the divisions beside Turn pro, and picking one, as a click would.
func pro_divisions() -> Array[String]:
	return _pro_division_ids.duplicate()


func pick_pro_division(id: String) -> void:
	var at: int = _pro_division_ids.find(id)
	if at >= 0:
		_pro_division.select(at)


## His weight line (D351): what he walks around at, the division he fights at, and, while he's growing, the one he's
## growing into. "Walks around at 66.1 kg · fights at Featherweight (65.8 kg, 145 lb) · growing into Lightweight by 21".
static func weight_text(c: Career) -> String:
	var now: String = c.division_now()
	var line: String = "Walks around at %s · fights at %s" % [Weight.kg_text(c.weight_kg()), Weight.label(now)]
	if c.division != "":
		return line + " since his pro debut"
	var home: String = c.natural_division()
	if c.trainee.age_years < Weight.GROWN_AT and home != now:
		line += " · growing into %s by %d" % [Weight.name_of(home), int(Weight.GROWN_AT)]
	return line


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
	var belt: String = Titles.held_by(c.world(), Career.FIGHTER_ID) if c.pro else ""
	if c.offers.is_empty() and c.booked.is_empty() and belt != "":
		var due: int = int(Titles.belt(c.world(), belt).last) + Titles.DEFENCE_WEEKS
		lines.append("The champion: he fights only to defend %s, due from %s." % [Titles.title_name(c.world(), belt), c.date_text(5, maxi(due, c.week))])
	elif c.offers.is_empty() and c.booked.is_empty() and c.trainee.injured_days == 0 and c.suspended_days == 0:
		lines.append("Free to fight: offers come in every few weeks.")
	if c.booked.is_empty():
		lines.append("This week: the %s plan." % String(TrainingLibrary.shared().plan(c.week_plan).get("name", c.week_plan)).to_lower())
	if c.pro and c.record_text(true) == "0-0-0":
		var legend: String = home_legend_text(c)
		if legend != "":
			lines.append(legend)
	var answer: String = Climb.answer_text(c)
	if answer != "":
		lines.append(answer)
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
	var news: String = news_text(c, maxi(1, reports.size()))
	if news != "":
		lines.append("")
		lines.append(news)
	return "\n".join(lines)


## Around his division (D353): the notable things from the world's last `weeks` weeks in his division, at most
## NEWS_MAX: men he's fought first, then upsets (the winner had under UPSET_CHANCE beforehand), first-round finishes,
## the best men, and men of his kind; and men he's fought turning pro or retiring.
static func news_text(c: Career, weeks: int = 1) -> String:
	var w: World = c.world()
	var division: String = c.division_now()
	var met: Dictionary = {}
	for f: Dictionary in c.fights:
		met[String(f.get("opponent", ""))] = String(f.get("result", ""))
	var scored: Array = []
	var new_top: Dictionary = {}  # A man a fight made a table's #1 (D355): said on that fight's line.
	for r: Dictionary in w.results:
		if String(r.get("kind", "")) == "ranked" and int(r.get("to", 0)) == 1 and String(r.get("why", "")).begins_with("beat ") \
				and String(r.id) != Career.FIGHTER_ID and int(r.get("week", -1)) >= c.week - weeks:
			new_top[String(r.id)] = int(r.week)
	for r: Dictionary in w.results:
		if int(r.get("week", -1)) < c.week - weeks or String(r.get("division", "")) != division:
			continue
		var kind: String = String(r.get("kind", "fight"))
		if kind == "moved" and String(r.id) == Career.FIGHTER_ID:
			var his_to: Dictionary = Promotions.by_id(w, String(r.get("to", "")))
			var his_from: Dictionary = Promotions.by_id(w, String(r.get("from", "")))
			if bool(r.get("up", false)):
				scored.append([9.0, "%s has signed with the %s%s." % [c.fighter_name(), String(his_to.get("name", "")),
					" after winning his tryout" if String(r.get("how", "")) == Climb.TRYOUT else ""]])
			else:
				scored.append([9.0, "The %s have let %s go: back to the %s." % [String(his_from.get("name", "")), c.fighter_name(),
					String(his_to.get("name", ""))]])
			continue
		if kind == "moved":
			var mm: Dictionary = w.man(String(r.id))
			var to: Dictionary = Promotions.by_id(w, String(r.get("to", "")))
			var moved_score: float = (4.0 if met.has(String(r.id)) else 0.0) + (1.0 if bool(r.get("up", false)) else 0.0) \
				+ (1.0 if c.pro else 0.0) + (1.0 if not to.is_empty() and int(to.rank) == Promotions.MAJOR else 0.0)
			if moved_score >= 2.0 and not to.is_empty():
				var said_move: String = "has been called up to the %s" % String(to.name) if bool(r.get("up", false)) \
					else "has been let go to the %s" % String(to.name)
				scored.append([moved_score, "%s%s %s." % [String(mm.get("name", "")),
					(", " + _met_words(String(met[String(r.id)])) + ",") if met.has(String(r.id)) else "", said_move]])
			continue
		if kind == "title":
			var said: Array = _title_news(c, w, r, met)
			if not said.is_empty():
				scored.append(said)
			continue
		if kind == "ranked":
			if new_top.get(String(r.id), -1) == int(r.week):
				continue
			var ranked: Array = _ranked_news(c, w, r, met)
			if not ranked.is_empty():
				scored.append(ranked)
			continue
		if kind != "fight":
			if met.has(String(r.id)):
				var m: Dictionary = w.man(String(r.id))
				var said: String = "has turned pro" if kind == "pro" else "has retired"
				scored.append([5.0, "%s, %s, %s." % [String(m.get("name", "")), _met_words(String(met[String(r.id)])), said]])
			continue
		var a: Dictionary = w.man(String(r.a))
		var b: Dictionary = w.man(String(r.b))
		var a_won: bool = String(r.winner) == "a"
		var winner: Dictionary = a if a_won else b
		var loser: Dictionary = b if a_won else a
		var score: float = 0.0
		var upset: bool = String(r.winner) != "draw" and (float(r.chance) if a_won else 1.0 - float(r.chance)) < UPSET_CHANCE
		if met.has(String(a.id)) or met.has(String(b.id)):
			score += 4.0
		if upset:
			score += 2.0
		if String(r.method) != "decision" and int(r.round) == 1:
			score += 1.0
		if maxf(w.average(a), w.average(b)) >= NEWS_BEST:
			score += 1.0
		var ranks: Array = r.get("ranks", [0, 0]) if r.get("ranks") is Array else [0, 0]
		if int(ranks[0]) > 0 and int(ranks[1]) > 0 and mini(int(ranks[0]), int(ranks[1])) <= NEWS_TOP_RANK:
			score += 1.0
		if bool(r.get("pro", false)) == c.pro:
			score += 1.0
		var top: bool = String(r.winner) != "draw" and new_top.get(String(winner.id), -1) == int(r.week)
		if top:
			score += 2.0
		var belt: String = String(r.get("title", ""))
		if belt != "":
			score += 3.0 + (1.0 if belt.begins_with("org_0") else 0.0)
			top = false
		var eliminator: String = String(r.get("eliminator", ""))
		if eliminator != "":
			score += 2.0 + (1.0 if eliminator.begins_with("org_0") else 0.0)
			top = false
		if score < 2.0:
			continue
		var named: Dictionary = {}
		for i in 2:
			var m: Dictionary = [a, b][i]
			var former: String = History.former_tag(w, String(m.id))
			named[String(m.id)] = ("#%d " % int(ranks[i]) if int(ranks[i]) > 0 else "") + String(m.name) + ((" (%s)" % former) if former != "" else "")
		var line: String
		if String(r.winner) == "draw":
			line = "%s and %s fought to a draw." % [named[String(a.id)], named[String(b.id)]]
		else:
			line = "%s beat %s %s%s%s%s." % [named[String(winner.id)], named[String(loser.id)], _how(String(r.method), int(r.round)),
				(" at " + String(r.card)) if String(r.get("card", "")) != "" else "", " (an upset)" if upset else "",
				(" and is the %s's new #1" % String(Promotions.by_id(w, String(r.get("promotion", ""))).get("short", ""))) if top else ""]
			if belt != "" and String(r.get("title_how", "")) in ["won", "defended"]:
				line = line.trim_suffix(".") + (" to win %s." if String(r.get("title_how", "")) == "won" else " to keep %s.") % Titles.title_name(w, belt)
			elif eliminator != "":
				line = line.trim_suffix(".") + " in an eliminator and is next in line for %s." % Titles.title_name(w, eliminator)
		for m: Dictionary in [a, b]:
			if met.has(String(m.id)):
				line += " %s %s." % [String(m.name).get_slice(" ", 0), _met_words(String(met[String(m.id)]), true)]
		scored.append([score, line])
	if scored.is_empty():
		return ""
	scored.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
	var out: Array[String] = ["[color=%s]AROUND THE %s[/color]" % [DIM.to_html(false), Weight.name_of(division).to_upper()]]
	for i in mini(NEWS_MAX, scored.size()):
		out.append(String(scored[i][1]))
	return "\n".join(out)


## A belt's news (D356, a "title" result): his own title won always; a belt gone vacant (retired, called up, stripped,
## left), more so in a bigger promotion or when he's fought the man. [score, line], [] when it's not worth saying.
static func _title_news(c: Career, w: World, r: Dictionary, met: Dictionary) -> Array:
	var k: String = Rankings.key(String(r.get("promotion", "")), String(r.get("division", "")))
	var id: String = String(r.get("id", ""))
	var name: String = c.fighter_name() if id == Career.FIGHTER_ID else String(w.man(id).get("name", ""))
	var how: String = String(r.get("how", ""))
	if how == "won":
		if id == Career.FIGHTER_ID:
			return [8.0, "%s has won %s!" % [name, Titles.title_name(w, k)]]
		return []  # The world's title wins are on their fights' lines.
	var why: String = { "retired": "%s has retired", "called up": "%s has been called up", "stripped": "%s has been stripped of it after a year without a defence",
		"left": "%s has moved on" }.get(how, "%s has gone") % name
	var score: float = 2.0 + (1.0 if k.begins_with("org_0") else 0.0) + (4.0 if met.has(id) else 0.0) + (4.0 if id == Career.FIGHTER_ID else 0.0)
	return [score, "%s is vacant: %s." % [Titles.title_name(w, k).capitalize().substr(0, 1) + Titles.title_name(w, k).substr(1), why]]


## A ranking move as news (D355): his own moves always ([score, line]); a new #1, more so in a bigger promotion or when
## he's fought the man. [] when it's not worth saying.
static func _ranked_news(c: Career, w: World, r: Dictionary, met: Dictionary) -> Array:
	var p: Dictionary = Promotions.by_id(w, String(r.get("promotion", "")))
	if p.is_empty():
		return []
	var id: String = String(r.id)
	var from: int = int(r.get("from", 0))
	var to: int = int(r.get("to", 0))
	if id == Career.FIGHTER_ID:
		var said: String
		if to == 0:
			said = "is out of the %s's rankings" % String(p.short)
		elif from == 0:
			said = "is into the %s's rankings at #%d" % [String(p.short), to]
		else:
			said = "is %s to #%d in the %s's rankings" % ["up" if to < from else "down", to, String(p.short)]
		return [6.0, "%s %s: %s." % [c.fighter_name(), said, String(r.why)]]
	if to != 1:
		return []
	var score: float = 2.0 + (1.0 if int(p.rank) == Promotions.MAJOR else 0.0) + (4.0 if met.has(id) else 0.0) + (1.0 if c.pro else 0.0)
	var m: Dictionary = w.man(id)
	return [score, "%s%s is the new #1 in the %s: %s." % [String(m.get("name", "")),
		(", " + _met_words(String(met[id])) + ",") if met.has(id) else "", String(p.name), String(r.why)]]


static func _how(method: String, round_number: int) -> String:
	match method:
		"ko":
			return "by knockout in round %d" % round_number
		"submission":
			return "by submission in round %d" % round_number
	return "on the judges' cards"


static func _met_words(result: String, after_name: bool = false) -> String:
	var words: String = { "win": "who you beat", "loss": "who beat you", "draw": "who you drew with" }.get(result, "who you fought")
	return ("is the man " + words) if after_name else words


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
		if String(f.get("title", "")) != "":
			on += " · [color=%s]title fight[/color]" % WARN.to_html(false)
		if String(f.get("eliminator", "")) != "":
			on += " · [color=%s]title eliminator[/color]" % WARN.to_html(false)
		if String(f.get("step", "")) == Climb.TRYOUT:
			on += " · [color=%s]tryout[/color]" % GOOD.to_html(false)
		match String(f.get("moved", "")):
			"up":
				on += " · [color=%s]signed up[/color]" % GOOD.to_html(false)
			"down":
				on += " · [color=%s]let go[/color]" % BAD.to_html(false)
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
