class_name FightPoster
extends PanelContainer
## A fight on the hub as a poster (docs/06 §6.13, D433; Kyle's picks on the D433 cards): an offer, or the fight he's
## booked for. Along the top, the card in its promotion's colour with its badge (a local or amateur card in grey) and
## fight night's date; the ribbons that matter (Coach's pick, title fight, call-up, tryout, eliminator, tournament, last
## week to answer); both men face to face, his head and chest on the left in red, the other man's on the right in blue,
## each with his name and record. Under them, an offer's Take the fight and Turn it down, then its full scouting card
## (CareerHub.offer_text); a booked fight's countdown in weeks to fight night and the camp's phase.

signal take_pressed
signal turn_down_pressed

const WIDTH: float = 460.0
const FACE := Vector2(150.0, 170.0)
const AMATEUR := Color("#6c7480")
const BAND_TEXT := Color("#0f1217")
## Ribbon colours.
const PICK := Color("#69db7c")
const TITLE := Color("#fcc419")
const STEP := Color("#4dabf7")
const URGENT := Color("#ff8787")

var offer_id: String = ""
var booked: bool = false
var colour: Color = AMATEUR
var his_face: FighterPortrait
var their_face: FighterPortrait
var badge: PromotionBadge
var details: RichTextLabel
var countdown: Label
var take: Button
var turn_down: Button
var _band: PanelContainer
var _card_name: Label
var _date: Label
var _ribbons: HFlowContainer
var _names: Array[Label] = []
var _records: Array[Label] = []
var _countdown_box: VBoxContainer
var _countdown_line: Label
var _buttons: HBoxContainer
var _style: StyleBoxFlat


func _init() -> void:
	custom_minimum_size.x = WIDTH
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style = FightHud._panel_style(CareerHub.TILE)
	_style.set_content_margin_all(0)
	_style.border_width_top = 0
	_style.set_border_width_all(1)
	add_theme_stylebox_override("panel", _style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)

	_band = PanelContainer.new()
	column.add_child(_band)
	var band := HBoxContainer.new()
	band.add_theme_constant_override("separation", 10)
	_band.add_child(band)
	badge = PromotionBadge.new(Vector2(36.0, 36.0))
	band.add_child(badge)
	_card_name = Label.new()
	DisplayFont.apply(_card_name, 26)
	_card_name.add_theme_color_override("font_color", BAND_TEXT)
	_card_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_name.clip_text = true
	band.add_child(_card_name)
	_date = Label.new()
	DisplayFont.apply(_date, 20)
	_date.add_theme_color_override("font_color", BAND_TEXT)
	band.add_child(_date)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	margin.add_child(inner)
	column.add_child(margin)
	_ribbons = HFlowContainer.new()
	_ribbons.add_theme_constant_override("h_separation", 6)
	_ribbons.add_theme_constant_override("v_separation", 6)
	inner.add_child(_ribbons)

	var faces := HBoxContainer.new()
	faces.add_theme_constant_override("separation", 6)
	inner.add_child(faces)
	for corner in 2:
		var side := VBoxContainer.new()
		side.add_theme_constant_override("separation", 0)
		side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var face := FighterPortrait.new(FighterPortrait.BUST, corner, 30.0 if corner == 0 else -30.0)
		face.custom_minimum_size = FACE
		face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		side.add_child(face)
		var name := Label.new()
		DisplayFont.apply(name, 24)
		name.add_theme_color_override("font_color", CareerHub.RED_CORNER if corner == 0 else Color("#74c0fc"))
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		side.add_child(name)
		var record := FightNightCard._label(15, CareerHub.DIM)
		record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		side.add_child(record)
		_names.append(name)
		_records.append(record)
		if corner == 0:
			his_face = face
			faces.add_child(side)
			var vs := Label.new()
			DisplayFont.apply(vs, 34)
			vs.text = "VS"
			vs.add_theme_color_override("font_color", CareerHub.DIM)
			vs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			faces.add_child(vs)
		else:
			their_face = face
			faces.add_child(side)

	_countdown_box = VBoxContainer.new()
	_countdown_box.add_theme_constant_override("separation", 0)
	inner.add_child(_countdown_box)
	countdown = Label.new()
	DisplayFont.apply(countdown, 64)
	countdown.add_theme_color_override("font_color", CareerHub.TEXT)
	countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_box.add_child(countdown)
	_countdown_line = FightNightCard._label(16, CareerHub.DIM)
	_countdown_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_countdown_box.add_child(_countdown_line)

	_buttons = HBoxContainer.new()  # Under the faces, so the scouting card's length never hides them.
	_buttons.add_theme_constant_override("separation", 8)
	inner.add_child(_buttons)
	details = RichTextLabel.new()
	details.bbcode_enabled = true
	details.fit_content = true
	details.scroll_active = false
	details.mouse_filter = Control.MOUSE_FILTER_PASS
	details.add_theme_font_size_override("normal_font_size", 15)
	details.add_theme_font_size_override("bold_font_size", 15)
	details.add_theme_color_override("default_color", CareerHub.TEXT)
	inner.add_child(details)
	take = CampPlanner._button(_buttons, "Take the fight", func() -> void: take_pressed.emit())
	take.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	CampPlanner.style_fight_button(take, 22)
	turn_down = CampPlanner._button(_buttons, "Turn it down", func() -> void: turn_down_pressed.emit())
	turn_down.size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Shows an offer (Career.offers' entry).
func show_offer(c: Career, o: Dictionary, groups: Dictionary) -> void:
	offer_id = String(o.get("id", ""))
	booked = false
	var p: Dictionary = o.get("profile", {})
	var about: Dictionary = o.get("about", {})
	var card: Dictionary = o.get("card", {}) if o.get("card") is Dictionary else {}
	_show_card(c, card, int(o.get("week", c.week)), bool(o.get("pro", false)))
	_show_men(c, p, String(about.get("record", "")), bool(o.get("pro", false)))
	_clear_ribbons()
	if int(o.get("lesson", 0)) > 0:
		_ribbon("COACH'S PICK", PICK)
	if String(o.get("title", "")) != "":
		_ribbon({ "defence": "TITLE DEFENCE", "vacant": "VACANT TITLE", "shot": "TITLE SHOT" }.get(String(o.get("title_how", "")), "TITLE FIGHT"), TITLE)
	if String(o.get("eliminator", "")) != "":
		_ribbon("ELIMINATOR", TITLE)
	if String(o.get("step", "")) == Climb.CALL_UP:
		_ribbon("CALL-UP", STEP)
	elif String(o.get("step", "")) == Climb.TRYOUT:
		_ribbon("TRYOUT", STEP)
	if o.get("tournament") is Dictionary and not (o.tournament as Dictionary).is_empty():
		_ribbon("TOURNAMENT · %d MEN" % int(o.tournament.get("size", 4)), STEP)
	_ribbon(String(CareerHub.DIFFICULTY_TEXT.get(String(o.get("difficulty", "")), "")).to_upper(), CareerHub.DIM)
	if int(o.get("expires", c.week)) == c.week:
		_ribbon("LAST WEEK TO ANSWER", URGENT)
	_countdown_box.visible = false
	details.text = CareerHub.offer_text(c, o, groups)
	_buttons.visible = true


## Shows the fight he's booked for, counting down to fight night.
func show_booked(c: Career) -> void:
	offer_id = ""
	booked = true
	var who: Dictionary = c.booked_opponent()
	var card: Dictionary = c.booked.get("card", {}) if c.booked.get("card") is Dictionary else {}
	var week: int = int(c.booked.get("week", c.week))
	var pro: bool = bool(c.booked.get("pro", c.pro))
	_show_card(c, card, week, pro)
	var opponent_id: String = String(c.booked.get("opponent", ""))
	var record: String = World.record_text(c.world().man(opponent_id)) if not c.world().man(opponent_id).is_empty() else ""
	_show_men(c, who, record, pro)
	_clear_ribbons()
	if String(c.booked.get("title", "")) != "":
		_ribbon("TITLE FIGHT", TITLE)
	if String(c.booked.get("eliminator", "")) != "":
		_ribbon("ELIMINATOR", TITLE)
	if String(c.booked.get("step", "")) == Climb.TRYOUT:
		_ribbon("TRYOUT", STEP)
	if c.tournament_stage() >= 0:
		_ribbon("TOURNAMENT · %s" % Tournament.stage_name(int(c.booked.tournament.size), c.tournament_stage()).to_upper(), STEP)
	var left: int = c.camp_weeks_left()
	_countdown_box.visible = true
	if c.tournament_stage() > 0 or left <= 0:
		countdown.text = "TODAY"
	else:
		countdown.text = "%d WEEK%s" % [left, "" if left == 1 else "S"]
	var phase: String = { Career.CAMP_EARLY: "early in his camp", Career.CAMP_MIDDLE: "the middle of his camp",
		Career.CAMP_TAPER: "his taper week" }.get(c.camp_phase(), "")
	_countdown_line.text = "to fight night, %s%s · %s" % [c.date_text(5, week), (" · " + phase) if phase != "" else "",
		CareerHub.rules_name(String(c.booked.get("ruleset", "")))]
	details.text = ""
	details.visible = false
	_buttons.visible = false


func _show_card(c: Career, card: Dictionary, week: int, pro: bool) -> void:
	var w: World = c.world()
	var p: Dictionary = Promotions.by_id(w, String(card.get("promotion", "")))
	badge.visible = not p.is_empty()
	if not p.is_empty():
		badge.show_promotion(w, p)
		colour = PromotionBadge.colour_of(w, p)
	else:
		colour = AMATEUR
	var name: String = String(card.get("name", ""))
	_card_name.text = (name if name != "" else ("A PRO FIGHT" if pro else "AN AMATEUR BOUT")).to_upper()
	_date.text = c.short_date(week, 5).to_upper()
	var band := StyleBoxFlat.new()
	band.bg_color = colour
	band.set_content_margin_all(10)
	band.content_margin_left = 14
	band.content_margin_right = 14
	_band.add_theme_stylebox_override("panel", band)
	_style.border_color = colour.darkened(0.2)


func _show_men(c: Career, p: Dictionary, record: String, pro: bool) -> void:
	his_face.show_fighter(c.profile())
	their_face.show_fighter(p)
	_names[0].text = c.fighter_name()
	_records[0].text = c.record_text(pro) + (" pro" if pro else " amateur")
	_names[1].text = String(p.get("name", ""))
	_records[1].text = record + ((" pro" if pro else " amateur") if record != "" else "")
	details.visible = true


func _clear_ribbons() -> void:
	for child in _ribbons.get_children():
		_ribbons.remove_child(child)
		child.queue_free()


func _ribbon(text: String, ribbon_colour: Color) -> void:
	if text == "":
		return
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = ribbon_colour.darkened(0.55)
	style.border_color = ribbon_colour
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	DisplayFont.apply(label, 16)
	label.text = text
	label.add_theme_color_override("font_color", ribbon_colour.lightened(0.2))
	chip.add_child(label)
	_ribbons.add_child(chip)


## The ribbons' words, for tests.
func ribbons() -> Array[String]:
	var out: Array[String] = []
	for chip in _ribbons.get_children():
		out.append((chip.get_child(0) as Label).text)
	return out
