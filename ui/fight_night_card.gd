class_name FightNightCard
extends PanelContainer
## Fight night (D171, docs/02 §3.11): the full-screen card the camp planner shows when the last week has run. It says
## how the camp sends the fighter in (TrainingCamp.fight_night, D135): the body figure with any healing injury, the
## gas tank, how tired he is, what the camp added, and the doctor's verdict as a stamp; then Fight! or Pull out.
## The opponent isn't here: the head-to-head is the fight setup's tale of the tape (Kyle's call).

signal fight_pressed
signal pull_out_pressed
signal back_pressed
## Sim the fight (a career's fight night, D305): the fight plays out at once and goes straight to the result.
signal sim_pressed

const BACKGROUND := Color(0.06, 0.07, 0.09)
const CARD := Color("#1b1f26")
const RED_CORNER := Color("#ff6b6b")
const TEXT := Color("#e9ecef")
const DIM := Color("#8a8f98")
const GOOD := Color("#51cf66")
const WARN := Color("#fcc419")
const BAD := Color("#ff6b6b")
## The doctor's stamp: what it says and its colour, by verdict (TrainingCamp.FIT …), and once he's pulled out.
const STAMPS := {
	TrainingCamp.FIT: ["CLEARED", GOOD],
	TrainingCamp.CLEARED_HURT: ["CLEARED TO FIGHT HURT", WARN],
	TrainingCamp.NOT_CLEARED: ["NOT CLEARED", BAD],
	"pulled_out": ["PULLED OUT", DIM],
}
## The stamp's tilt, in degrees.
const STAMP_TILT: float = -7.0
## How many of the camp's biggest gains it lists.
const GAINS_SHOWN: int = 6

var _title: Label
var _subtitle: Label
var _figure: BodyDamageFigure
var _who: Label
var _tank: Label
var _tank_bar: ProgressBar
var _tank_fill: StyleBoxFlat
var _tank_note: Label
var _fatigue: Label
var _fatigue_note: Label
var _injury: Label
var _injury_note: Label
var _stamp: Label
var _stamp_box: PanelContainer
var _verdict: Label
var _countdown: CampCountdown
var _gains: RichTextLabel
var _fight: Button
var _pull_out: Button
var _sim: Button
## Shows Sim the fight (a career's fight night, D305).
var sim_allowed: bool = false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override("panel", FightHud._panel_style(BACKGROUND))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	add_child(column)

	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 0)
	column.add_child(head)
	_title = Label.new()
	_title.text = "FIGHT NIGHT"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	DisplayFont.apply(_title, 84)
	_title.add_theme_color_override("font_color", RED_CORNER)
	head.add_child(_title)
	_subtitle = _label(20, DIM)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(_subtitle)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(body)
	body.add_child(_build_fighter_card())
	body.add_child(_build_condition_card())
	body.add_child(_build_camp_card())

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	var back := CampPlanner._button(buttons, "Back to the camp", func() -> void: back_pressed.emit())
	back.custom_minimum_size.x = 220.0
	_pull_out = CampPlanner._button(buttons, "Pull out of the fight", func() -> void: pull_out_pressed.emit())
	_pull_out.custom_minimum_size.x = 260.0
	_sim = CampPlanner._button(buttons, "Sim the fight", func() -> void: sim_pressed.emit())
	_sim.custom_minimum_size.x = 220.0
	_sim.tooltip_text = "Plays the fight out at once, without watching or calling it, and goes to the result"
	_sim.visible = false
	_fight = CampPlanner._button(buttons, "Fight!", func() -> void: fight_pressed.emit())
	_fight.custom_minimum_size = Vector2(280.0, 64.0)
	CampPlanner.style_fight_button(_fight, 38)


## Fills the card. `info`: name, age, weeks, opponent, night (TrainingCamp.fight_night), pulled_out, history (the
## countdown's weeks), gains (stat id → what the camp added), chin and chin_change.
func show_night(info: Dictionary) -> void:
	var night: Dictionary = info.night
	var against: String = " · vs %s" % info.opponent if String(info.get("opponent", "")) != "" else ""
	_subtitle.text = "Saturday evening%s · after a %d-week camp" % [against, int(info.weeks)]
	_who.text = "%s, %d" % [info.name, int(info.age)]
	for area: String in BodyDamageFigure.AREAS:
		_figure.hurt[area] = float(night.hurt.get(area, 0.0))
	var legs: float = float(night.hurt.get("legs", 0.0))
	_figure.leg_hurt = [legs, legs]
	_figure.queue_redraw()

	var tank: float = float(night.tank)
	_tank.text = "%d%%" % roundi(100.0 * tank)
	var tank_colour: Color = GOOD if tank >= 0.995 else (WARN if tank >= 0.85 else BAD)
	_tank.add_theme_color_override("font_color", tank_colour)
	_tank_fill.bg_color = tank_colour
	_tank_bar.value = tank
	_tank_note.text = "A full tank for the whole fight." if tank >= 0.995 else "The camp's fatigue shrinks the tank for the whole fight."
	var fatigue: float = float(night.fatigue)
	_fatigue.text = "%d" % roundi(fatigue)
	_fatigue.add_theme_color_override("font_color", GOOD if fatigue < TrainingCamp.FRESH_BELOW else (WARN if fatigue < TrainingCamp.FATIGUE_FREE else BAD))
	_fatigue_note.text = CampPlanner._sentence(TrainingCamp.freshness(fatigue))
	var days: int = int(night.injured_days)
	if days > 0:
		var area: String = night.injury_area
		_injury.text = "%s, %d days to heal" % [area.capitalize(), days]
		_injury.add_theme_color_override("font_color", BAD)
		_injury_note.text = "Starts the fight %d%% hurt there: %s." % [roundi(100.0 * float(night.hurt[area])), CampPlanner.HURT_EFFECTS.get(area, "")]
	else:
		_injury.text = "None"
		_injury.add_theme_color_override("font_color", GOOD)
		_injury_note.text = "Nothing healing."

	var verdict: String = "pulled_out" if bool(info.get("pulled_out", false)) else String(night.doctor)
	_stamp.text = STAMPS[verdict][0]
	_stamp_box.reset_size()  # Shrink to a shorter word.
	var colour: Color = STAMPS[verdict][1]
	_stamp.add_theme_color_override("font_color", colour)
	(_stamp_box.get_theme_stylebox("panel") as StyleBoxFlat).border_color = colour
	match verdict:
		"pulled_out":
			_verdict.text = "You pulled him out. The fight is off and the camp is wasted."
		TrainingCamp.NOT_CLEARED:
			_verdict.text = "More than %d days still to heal. The fight is off and the camp is wasted." % TrainingCamp.DOCTOR_MAX_DAYS
		TrainingCamp.CLEARED_HURT:
			_verdict.text = "He can fight hurt. Fighting on it has a %d%% chance of making it worse (a longer layoff after). You can pull out instead." % roundi(100.0 * float(night.worsen_chance))
		_:
			_verdict.text = "Fit to fight."
	_fight.disabled = verdict != TrainingCamp.FIT and verdict != TrainingCamp.CLEARED_HURT
	_pull_out.disabled = _fight.disabled
	_sim.visible = sim_allowed
	_sim.disabled = _fight.disabled
	if not _fight.disabled:
		FightHud.focus_later(_fight)

	var history: Array[Dictionary] = []
	history.assign(info.get("history", []))
	_countdown.show_camp(int(info.weeks), history, _fight.disabled)
	_gains.text = _gains_bbcode(info.get("gains", {}), float(info.get("chin_change", 0.0)), float(info.get("chin", 0.0)))


## The card as text (tests read it).
func text() -> String:
	return "\n".join([_subtitle.text, _who.text, "Gas tank " + _tank.text, _tank_note.text, "Fatigue " + _fatigue.text,
		_fatigue_note.text, "Injury " + _injury.text, _injury_note.text, _stamp.text, _verdict.text, _gains.get_parsed_text()])


func can_fight() -> bool:
	return not _fight.disabled


func press_fight() -> void:
	if not _fight.disabled:
		_fight.pressed.emit()


func press_sim() -> void:
	if _sim.visible and not _sim.disabled:
		_sim.pressed.emit()


# --- building it -----------------------------------------------------------------

func _build_fighter_card() -> Control:
	var card := _card(Vector2(360.0, 0.0))
	var box: VBoxContainer = card.get_child(0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_who = Label.new()
	DisplayFont.apply(_who, 40)
	_who.add_theme_color_override("font_color", RED_CORNER)
	_who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_who)
	var corner := _label(16, DIM)
	corner.text = "Your corner"
	corner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(corner)
	_figure = BodyDamageFigure.new()
	_figure.custom_minimum_size = Vector2(180.0, 300.0)
	_figure.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_figure.tooltip_text = "where he's hurt as he walks out: green is fresh, red is badly hurt"
	box.add_child(_figure)
	return card


func _build_condition_card() -> Control:
	var card := _card(Vector2(520.0, 0.0))
	var box: VBoxContainer = card.get_child(0)
	box.add_theme_constant_override("separation", 6)
	box.add_child(_heading("Gas tank"))
	_tank = _big()
	box.add_child(_tank)
	_tank_bar = ProgressBar.new()
	_tank_bar.show_percentage = false
	_tank_bar.max_value = 1.0
	_tank_bar.custom_minimum_size.y = 12.0
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#2b3038")
	track.set_corner_radius_all(6)
	_tank_bar.add_theme_stylebox_override("background", track)
	_tank_fill = StyleBoxFlat.new()
	_tank_fill.set_corner_radius_all(6)
	_tank_bar.add_theme_stylebox_override("fill", _tank_fill)
	box.add_child(_tank_bar)
	_tank_note = _note()
	box.add_child(_tank_note)
	box.add_child(_spacer())
	box.add_child(_heading("Fatigue"))
	var fatigue_row := HBoxContainer.new()
	fatigue_row.add_theme_constant_override("separation", 14)
	box.add_child(fatigue_row)
	_fatigue = _big()
	fatigue_row.add_child(_fatigue)
	_fatigue_note = _label(22, TEXT)
	_fatigue_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fatigue_row.add_child(_fatigue_note)
	box.add_child(_spacer())
	box.add_child(_heading("Injury"))
	_injury = Label.new()
	DisplayFont.apply(_injury, 40)
	box.add_child(_injury)
	_injury_note = _note()
	box.add_child(_injury_note)
	box.add_child(_spacer())
	box.add_child(_heading("The doctor"))
	_stamp_box = PanelContainer.new()
	var stamp_style := StyleBoxFlat.new()
	stamp_style.draw_center = false
	stamp_style.set_border_width_all(5)
	stamp_style.set_corner_radius_all(8)
	stamp_style.set_content_margin_all(10)
	stamp_style.content_margin_left = 22.0
	stamp_style.content_margin_right = 22.0
	_stamp_box.add_theme_stylebox_override("panel", stamp_style)
	_stamp_box.rotation_degrees = STAMP_TILT
	# A container would undo the tilt, so the stamp sits in a plain Control that it sizes.
	var holder := Control.new()
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.add_child(_stamp_box)
	_stamp_box.resized.connect(func() -> void:
		_stamp_box.pivot_offset = _stamp_box.size * 0.5
		var lift: float = absf(sin(deg_to_rad(STAMP_TILT))) * _stamp_box.size.x * 0.5  # How far the tilt raises one end.
		holder.custom_minimum_size = _stamp_box.size + Vector2(0.0, 2.0 * lift)
		_stamp_box.position = Vector2(0.0, lift))
	_stamp = Label.new()
	DisplayFont.apply(_stamp, 46)
	_stamp_box.add_child(_stamp)
	box.add_child(holder)
	_verdict = _note()
	box.add_child(_verdict)
	return card


func _build_camp_card() -> Control:
	var card := _card(Vector2(560.0, 0.0))
	var box: VBoxContainer = card.get_child(0)
	box.add_child(_heading("The camp"))
	_countdown = CampCountdown.new()
	box.add_child(_countdown)
	box.add_child(_spacer())
	box.add_child(_heading("What it added"))
	_gains = RichTextLabel.new()
	_gains.bbcode_enabled = true
	_gains.fit_content = true
	_gains.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_gains.add_theme_font_size_override("normal_font_size", 20)
	_gains.add_theme_color_override("default_color", TEXT)
	box.add_child(_gains)
	return card


func _gains_bbcode(gains: Dictionary, chin_change: float, chin: float) -> String:
	var ids: Array = gains.keys().filter(func(id: String) -> bool: return float(gains[id]) >= CampPlanner.SHOWN_GAIN)
	ids.sort_custom(func(a: String, b: String) -> bool: return gains[a] > gains[b])
	var lines: Array[String] = []
	for id: String in ids.slice(0, GAINS_SHOWN):
		lines.append("%s [color=%s]+%.2f[/color]" % [TrainingCamp.STAT_NAMES.get(id, id), CampPlanner.GAIN, gains[id]])
	if lines.is_empty():
		lines.append("[color=%s]Nothing yet.[/color]" % CampPlanner.DIM)
	if chin_change <= -CampPlanner.SHOWN_GAIN:
		lines.append("Chin [color=%s]%.2f[/color] (hard sparring), now %d" % [CampPlanner.LOSS, chin_change, roundi(chin)])
	lines.append("[color=%s]Fights use each stat to the nearest point.[/color]" % CampPlanner.DIM)
	return "\n".join(lines)


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
	var label := _label(20, DIM)
	DisplayFont.apply(label, 20)
	label.text = text_in.to_upper()
	return label


func _big() -> Label:
	var label := Label.new()
	DisplayFont.apply(label, 64)
	return label


func _note() -> Label:
	var label := _label(17, Color("#adb5bd"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _spacer() -> Control:
	var gap := Control.new()
	gap.custom_minimum_size.y = 8.0
	return gap


static func _label(font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	return label
