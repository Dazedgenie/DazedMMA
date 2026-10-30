class_name FightResultCard
extends PanelContainer
## The result screen (D173, docs/06 §6.8): the full-screen card when a fight is over. A big verdict (who won, how,
## and when), both body figures as they finished, the fight sheet face to face (strikes by head, body and legs,
## knockdowns, takedowns, control time, submission attempts, circling and cutting off), the judges' cards round by
## round, and a letter grade for your corner with what earned it. The buttons are main.gd's (fight again, the next
## playtest fight, change the setup, the saved fights).

const BACKGROUND := Color(0.06, 0.07, 0.09)
const CARD := Color("#1b1f26")
const TEXT := Color("#e9ecef")
const DIM := Color("#8a8f98")
const NOTE := Color("#adb5bd")
const CORNERS: Array[Color] = [TaleOfTheTape.RED, TaleOfTheTape.BLUE]
const AREAS: Array[String] = ["head", "body", "legs"]
## Results that end it inside the distance, so the verdict says when.
const FINISHES: Array[String] = [FightSim.RESULT_KO, FightSim.RESULT_TKO, FightSim.RESULT_SUB]
## The corner grade (D173): it starts here (a C, docs/11 §2.4) and each of these moves it, then TrainingCamp.grade
## reads it. A perfect call that was also a takedown counts both ways.
const CORNER_START: float = 50.0
const PER_PERFECT_CALL: float = 8.0
const PER_CALL_TAKEDOWN: float = 6.0
const PER_RULE_TAKEDOWN: float = 4.0
const PER_IGNORED_CALL: float = -5.0
const GRADE_COLOURS := { "A+": Color("#51cf66"), "A": Color("#51cf66"), "A−": Color("#94d82d"), "B": Color("#fcc419"),
	"C": Color("#ffa94d"), "D": Color("#ff8787"), "F": Color("#ff6b6b") }

var _title: Label
var _verdict: Label
var _figures: Array[BodyDamageFigure] = []
var _names: Array[Label] = []
var _readouts: Array[Label] = []
var _sheet: TaleOfTheTape
var _cards: RichTextLabel
var _grade: Label
var _corner: RichTextLabel
var _notes: RichTextLabel
var _buttons: HBoxContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel: StyleBoxFlat = FightHud._panel_style(BACKGROUND)
	panel.content_margin_bottom = 40.0
	add_theme_stylebox_override("panel", panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	add_child(column)

	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 0)
	column.add_child(head)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	DisplayFont.apply(_title, 84)
	head.add_child(_title)
	_verdict = _label(22, NOTE)
	_verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(_verdict)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	body.add_child(_build_fighter(0))
	var middle := _card()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(middle)
	var sheet_box: VBoxContainer = middle.get_child(0)
	sheet_box.add_child(_heading("The fight sheet"))
	_sheet = TaleOfTheTape.new()
	sheet_box.add_child(_sheet)
	body.add_child(_build_fighter(1))

	var lower := HBoxContainer.new()
	lower.add_theme_constant_override("separation", 18)
	column.add_child(lower)
	var corner := _card()
	corner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lower.add_child(corner)
	var corner_box: VBoxContainer = corner.get_child(0)
	corner_box.add_child(_heading("Your corner"))
	var corner_row := HBoxContainer.new()
	corner_row.add_theme_constant_override("separation", 22)
	corner_box.add_child(corner_row)
	_grade = Label.new()
	DisplayFont.apply(_grade, 96)
	_grade.custom_minimum_size.x = 110.0
	_grade.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	corner_row.add_child(_grade)
	_corner = _rich(19)
	_corner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corner_row.add_child(_corner)
	var judges := _card()
	judges.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lower.add_child(judges)
	var judges_box: VBoxContainer = judges.get_child(0)
	judges_box.add_child(_heading("The judges"))
	_cards = _rich(19)
	judges_box.add_child(_cards)

	_notes = _rich(15)
	_notes.add_theme_color_override("default_color", DIM)
	column.add_child(_notes)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 16)
	column.add_child(_buttons)


## Fills the card from a finished fight. `player` is your corner; `coaching` is FightRecord.coaching_stats;
## `notes` are extra lines (BBCode) under it; `buttons` are [label, callable] pairs, the first one red.
func show_result(sim: FightSim, player: int, coaching: Dictionary, notes: Array[String], buttons: Array) -> void:
	var ended: Dictionary = {}
	if not sim.events.is_empty() and sim.events[-1].type == FightEvent.FIGHT_ENDED:
		ended = sim.events[-1].data
	var winner: int = int(ended.get("winner", -1))
	if winner >= 0:
		_title.text = "%s WINS" % sim.fighters[winner].name.to_upper()
		_title.add_theme_color_override("font_color", CORNERS[winner])
	else:
		_title.text = "DRAW"
		_title.add_theme_color_override("font_color", TEXT)
	_verdict.text = verdict_line(sim)
	for i in 2:
		var f: FighterState = sim.fighters[i]
		_names[i].text = f.name.to_upper()
		_figures[i].show_fighter(f)
		_figures[i].rocked = false  # A still picture: no pulse.
		_readouts[i].text = "   ".join(AREAS.map(func(area: String) -> String: return FightHud.area_text(f, area)))
	_sheet.show_rows(sheet_rows(sheet(sim)))
	_cards.text = judges_bbcode(sim)
	var graded: Dictionary = corner_grade(coaching)
	_grade.text = graded.grade
	_grade.add_theme_color_override("font_color", GRADE_COLOURS.get(graded.grade, DIM))
	_corner.text = "\n".join(graded.lines)
	_notes.text = "\n".join(notes)
	for c in _buttons.get_children():
		_buttons.remove_child(c)
		c.queue_free()
	for n in buttons.size():
		var b := CampPlanner._button(_buttons, String(buttons[n][0]), buttons[n][1])
		b.custom_minimum_size = Vector2(240.0, 60.0)
		if n == 0:
			CampPlanner.style_fight_button(b, 30)
			FightHud.focus_later(b)
	visible = true


## The card as text (tests read it).
func text() -> String:
	return "\n".join([_title.text, _verdict.text, _readouts[0].text, _readouts[1].text, _sheet.text(), _cards.get_parsed_text(),
		"Corner " + _grade.text, _corner.get_parsed_text(), _notes.get_parsed_text()])


func button_labels() -> Array[String]:
	var out: Array[String] = []
	for b: Button in _buttons.get_children():
		out.append(b.text)
	return out


func press(index: int) -> void:
	(_buttons.get_child(index) as Button).pressed.emit()


## How it ended and when, e.g. "by TKO (the referee stops it: nothing left) · Round 2, 3:41" or
## "by unanimous decision (29-28, 29-28, 30-27) · after 3 rounds".
static func verdict_line(sim: FightSim) -> String:
	var event: FightEvent = sim.events[-1]
	var full: String = FightLogFormatter.result_text(event, sim)
	var winner: int = int(event.data.get("winner", -1))
	var how: String = full
	if winner >= 0:
		how = "by " + full.substr(full.find(" wins by ") + " wins by ".length())
	var seconds: int = sim.clock.tick_in_round / FightClock.TICKS_PER_SECOND
	if String(event.data.result) in FINISHES or event.data.has("stopped_by"):
		return "%s · Round %d, %d:%02d" % [how, sim.clock.current_round, seconds / 60, seconds % 60]
	return "%s · after %d rounds" % [how, sim.clock.current_round]


## The fight sheet's numbers for both fighters, from the fight's events: strikes landed and thrown by target,
## knockdowns scored, takedowns, control time (seconds on top or holding a submission), submission attempts, and
## the circling and cutting off of D119 (seconds).
static func sheet(sim: FightSim) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in 2:
		var f: FighterState = sim.fighters[i]
		out.append({ "strikes": { "head": [0, 0], "body": [0, 0], "legs": [0, 0] }, "knockdowns": 0,
			"takedowns": [f.takedowns_landed, f.takedowns_tried], "control_s": 0.0,
			"subs": f.subs_tried + f.leg_locks_tried,
			"circled_s": float(sim.circling_ticks[i]) / FightClock.TICKS_PER_SECOND,
			"cut_off_s": float(sim.cutting_ticks[i]) / FightClock.TICKS_PER_SECOND })
	var roles: Array = ["neutral", "neutral"]
	var since: int = 0
	for e in sim.events:
		match e.type:
			FightEvent.STRIKE_LANDED, FightEvent.STRIKE_MISSED:
				if e.actor >= 0 and out[e.actor].strikes.has(e.data.get("target", "")):
					var pair: Array = out[e.actor].strikes[e.data.target]
					pair[1] += 1
					if e.type == FightEvent.STRIKE_LANDED:
						pair[0] += 1
			FightEvent.KNOCKDOWN:
				var by: int = int(e.data.get("by", 1 - e.actor))
				if by >= 0 and by < 2:
					out[by].knockdowns += 1
			FightEvent.POSITION_CHANGED, FightEvent.ROUND_ENDED, FightEvent.FIGHT_ENDED:
				_add_control(out, roles, e.tick - since)
				since = e.tick
				roles = e.data.get("roles", ["neutral", "neutral"]) if e.type == FightEvent.POSITION_CHANGED else ["neutral", "neutral"]
	return out


static func _add_control(out: Array[Dictionary], roles: Array, ticks: int) -> void:
	for i in 2:
		if String(roles[i]) in ["top", "attacker"]:
			out[i].control_s += float(ticks) / FightClock.TICKS_PER_SECOND


## The sheet as the tape's face-to-face rows, the better number lit in its corner's colour.
static func sheet_rows(numbers: Array[Dictionary]) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var landed: Array[int] = [0, 0]
	var thrown: Array[int] = [0, 0]
	for i in 2:
		for area: String in AREAS:
			landed[i] += int(numbers[i].strikes[area][0])
			thrown[i] += int(numbers[i].strikes[area][1])
	rows.append(_row("STRIKES LANDED", "%d of %d" % [landed[0], thrown[0]], "%d of %d" % [landed[1], thrown[1]], landed[1] - landed[0]))
	for area: String in AREAS:
		var r: Array = numbers[0].strikes[area]
		var b: Array = numbers[1].strikes[area]
		rows.append(_row("TO THE " + area.to_upper(), "%d of %d" % r, "%d of %d" % b, int(b[0]) - int(r[0])))
	rows.append(_row("KNOCKDOWNS", str(numbers[0].knockdowns), str(numbers[1].knockdowns), numbers[1].knockdowns - numbers[0].knockdowns))
	rows.append(_row("TAKEDOWNS", "%d of %d" % numbers[0].takedowns, "%d of %d" % numbers[1].takedowns,
		int(numbers[1].takedowns[0]) - int(numbers[0].takedowns[0])))
	rows.append(_row("CONTROL TIME", _clock(numbers[0].control_s), _clock(numbers[1].control_s),
		roundi(numbers[1].control_s) - roundi(numbers[0].control_s)))
	rows.append(_row("SUBMISSION TRIES", str(numbers[0].subs), str(numbers[1].subs), numbers[1].subs - numbers[0].subs))
	rows.append({ "divider": true })
	rows.append(_row("CIRCLED", _clock(numbers[0].circled_s), _clock(numbers[1].circled_s), 0))
	rows.append(_row("CUT OFF THE CAGE", _clock(numbers[0].cut_off_s), _clock(numbers[1].cut_off_s), 0))
	return rows


static func _row(label: String, red: String, blue: String, blue_minus_red: int) -> Dictionary:
	return { "label": label, "red": red, "blue": blue, "edge": signi(blue_minus_red) }


static func _clock(seconds: float) -> String:
	var s: int = roundi(seconds)
	return "%d:%02d" % [s / 60, s % 60]


## The judges' cards round by round (each round's winner in his colour), their totals, or what decided a
## whole-fight verdict (D141). A finish shows the rounds that were scored before it.
static func judges_bbcode(sim: FightSim) -> String:
	var ended: Dictionary = sim.events[-1].data
	if ended.has("judges"):
		var lines: Array[String] = ["Judged on the whole fight (PRIDE rules):"]
		var picks: Array = ended.judges
		var on: Array = ended.get("judged_on", [])
		for j in picks.size():
			var w: int = int(picks[j])
			var what: String = String(FightLogFormatter.JUDGED_ON.get(String(on[j]) if j < on.size() else "", ""))
			lines.append("Judge %d: %s" % [j + 1, "even" if w < 0 else "[color=%s]%s[/color]%s" % [CORNERS[w].to_html(false),
				sim.fighters[w].name, " on " + what if what != "" else ""]])
		return "\n".join(lines)
	var rounds: Array[Array] = []
	for e in sim.events:
		if e.type == FightEvent.ROUND_ENDED and e.data.has("cards"):
			rounds.append(e.data.cards)
	if rounds.is_empty():
		return "[color=%s]Over before the judges scored a round.[/color]" % DIM.to_html(false)
	var judges: int = rounds[0].size()
	var cells: Array[String] = [_cell("")]
	for j in judges:
		cells.append(_cell("[color=%s]Judge %d[/color]" % [DIM.to_html(false), j + 1]))
	for n in rounds.size():
		cells.append(_cell("Round %d" % (n + 1)))
		for card: Array in rounds[n]:
			cells.append(_cell(_score(card)))
	var after: String = ""
	if ended.has("cards"):
		cells.append(_cell("[b]Total[/b]"))
		for card: Array in ended.cards:
			cells.append(_cell("[b]%s[/b]" % _score(card)))
	else:
		after = "\n[color=%s]Stopped in round %d, so the cards didn't decide it.[/color]" % [DIM.to_html(false), sim.clock.current_round]
	return "[table=%d]%s[/table]%s" % [judges + 1, "".join(cells), after]


static func _cell(content: String) -> String:
	return "[cell padding=0,2,28,2]%s[/cell]" % content


static func _score(card: Array) -> String:
	var r: int = int(card[0])
	var b: int = int(card[1])
	var colour: Color = CORNERS[0] if r > b else (CORNERS[1] if b > r else DIM)
	return "[color=%s]%d-%d[/color]" % [colour.to_html(false), r, b]


## Your corner's letter grade and what earned it (D173), from FightRecord.coaching_stats. No calls at all is no grade.
static func corner_grade(stats: Dictionary) -> Dictionary:
	var made: int = int(stats.get("calls_made", 0))
	var perfect: int = int(stats.get("perfect_calls", 0))
	var ignored: int = int(stats.get("calls_ignored", 0))
	var by_call: int = int(stats.get("takedowns_by_call", 0))
	var by_rule: int = int(stats.get("takedowns_by_rule", 0))
	var lines: Array[String] = [
		"%d calls made · [color=#51cf66]%d perfect[/color] · [color=#ff8787]%d ignored[/color]" % [made, perfect, ignored],
		"Takedowns from your calls %d · from your drilled rules %d" % [by_call, by_rule],
		"Your rules fired %d times" % int(stats.get("rules_fired", 0)),
	]
	if made == 0 and by_rule == 0:
		lines.append("[color=%s]No calls and nothing from your rules, so nothing to grade.[/color]" % DIM.to_html(false))
		return { "grade": "–", "points": -1.0, "lines": lines }
	var points: float = clampf(CORNER_START + PER_PERFECT_CALL * perfect + PER_CALL_TAKEDOWN * by_call + PER_RULE_TAKEDOWN * by_rule
		+ PER_IGNORED_CALL * ignored, 0.0, 100.0)
	lines.append("[color=%s]Perfect calls and takedowns you set up raise it; calls he ignored lower it.[/color]" % DIM.to_html(false))
	return { "grade": TrainingCamp.grade(points), "points": points, "lines": lines }


# --- building it -----------------------------------------------------------------

func _build_fighter(corner: int) -> Control:
	var card := _card()
	card.custom_minimum_size.x = 380.0
	var box: VBoxContainer = card.get_child(0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var whose := _heading("Your corner" if corner == 0 else "The opponent")
	whose.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(whose)
	var fighter_name := Label.new()
	DisplayFont.apply(fighter_name, 40)
	fighter_name.add_theme_color_override("font_color", CORNERS[corner])
	fighter_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fighter_name.clip_text = true
	box.add_child(fighter_name)
	_names.append(fighter_name)
	var figure := BodyDamageFigure.new()
	figure.custom_minimum_size = Vector2(170.0, 280.0)
	figure.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	figure.tooltip_text = "how he finished: green is fresh, red is badly hurt"
	box.add_child(figure)
	_figures.append(figure)
	var readout := Label.new()
	DisplayFont.apply(readout, 22)
	readout.add_theme_color_override("font_color", TEXT)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(readout)
	_readouts.append(readout)
	return card


func _card() -> PanelContainer:
	var card := PanelContainer.new()
	var style: StyleBoxFlat = FightHud._panel_style(CARD)
	style.set_content_margin_all(20)
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	return card


func _heading(text_in: String) -> Label:
	var label := _label(20, DIM)
	DisplayFont.apply(label, 20)
	label.text = text_in.to_upper()
	return label


func _rich(font_size: int) -> RichTextLabel:
	var box := RichTextLabel.new()
	box.bbcode_enabled = true
	box.fit_content = true
	box.scroll_active = false
	box.add_theme_font_size_override("normal_font_size", font_size)
	box.add_theme_font_size_override("bold_font_size", font_size)
	box.add_theme_color_override("default_color", TEXT)
	return box


static func _label(font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	return label
