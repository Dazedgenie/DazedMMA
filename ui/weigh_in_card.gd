class_name WeighInCard
extends PanelContainer
## The weigh-in (D405, docs/03 §13.9): the full-screen card a pro camp shows when its last week has run, before the fight
## night card. Both men on the scale the day before: what each weighed, made or missed, his cut and how drained it left
## him, what he'll weigh on fight night, and who's the bigger man (WeightCut.of).

signal continue_pressed

const RED_CORNER := Color("#ff6b6b")
const BLUE_CORNER := Color("#4dabf7")
const TEXT := Color("#e9ecef")
const DIM := Color("#8a8f98")
const GOOD := Color("#51cf66")
const BAD := Color("#ff6b6b")
const CARD := Color("#1b1f26")

var _subtitle: Label
var _sides: Array[Dictionary] = []
var _edge: Label
var _missed: Label
var _continue: Button


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override("panel", OffCage.hall_panel(true))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	add_child(column)
	var title := Label.new()
	title.text = "THE WEIGH-IN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	DisplayFont.apply(title, 84)
	title.add_theme_color_override("font_color", TEXT)
	column.add_child(title)
	_subtitle = FightNightCard._label(20, DIM)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_subtitle)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	row.add_child(_side_card(0))
	var vs := Label.new()
	vs.text = "VS"
	DisplayFont.apply(vs, 64)
	vs.add_theme_color_override("font_color", DIM)
	vs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(vs)
	row.add_child(_side_card(1))

	_edge = FightNightCard._label(24, TEXT)
	_edge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_edge)
	_missed = FightNightCard._label(20, BAD)
	_missed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_missed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_missed)
	var buttons := CenterContainer.new()
	column.add_child(buttons)
	_continue = Button.new()
	_continue.text = "On to fight night"
	_continue.custom_minimum_size = Vector2(320.0, 64.0)
	CampPlanner.style_fight_button(_continue, 30)
	_continue.pressed.connect(func() -> void: continue_pressed.emit())
	buttons.add_child(_continue)


## Fills the card: `w` is WeightCut.of, `profiles` the two men (his first), `names` theirs, `division` its label.
func show_weigh_in(w: Dictionary, profiles: Array, names: Array, division: String, title: bool) -> void:
	var limit: float = float(w.him.limit_kg)
	_subtitle.text = "Friday, the day before the fight · %s · the limit is %s (%d lb)" % [division, Weight.kg_text(limit), Weight.lb(limit)]
	var bigger: int = 0 if float(w.edge) > 0.0 else (1 if float(w.opp_edge) > 0.0 else -1)
	var kept: Array[String] = []
	for i in 2:
		var s: Dictionary = w.him if i == 0 else w.opp
		var ui: Dictionary = _sides[i]
		ui.name.text = String(names[i])
		if profiles[i] is Dictionary:
			(ui.portrait as FighterPortrait).show_fighter(profiles[i])
		ui.scale.text = "%s" % Weight.kg_text(float(s.scale_kg))
		ui.lb.text = "%d lb" % Weight.lb(float(s.scale_kg))
		ui.stamp.text = "MADE WEIGHT" if s.made else "MISSED WEIGHT"
		ui.stamp.add_theme_color_override("font_color", GOOD if s.made else BAD)
		ui.cut.text = "%s cut · %s" % [WeightCut.NAMES[s.cut], WeightCut.cost_text(s)]
		ui.night.text = "Fight night: about %s" % Weight.kg_text(float(s.night_kg))
		if not s.made:
			kept.append("%s missed by %s: %d%% of his purse goes to the other man%s." % [names[i],
				Weight.kg_text(float(s.scale_kg) - limit), roundi(100.0 * WeightCut.FINE),
				", and he can't win the belt" if title else ""])
	_edge.text = "Even on the night: no size edge." if bigger < 0 else "%s is the bigger man on the night: +%s Strength." % [
		names[bigger], WeightCut._num(float(w.edge if bigger == 0 else w.opp_edge))]
	_missed.text = " ".join(kept) + (" The fight goes ahead." if not kept.is_empty() else "")
	_missed.visible = not kept.is_empty()
	FightHud.focus_later(_continue)


## The card as text (tests read it).
func text() -> String:
	var out: Array[String] = [_subtitle.text]
	for ui: Dictionary in _sides:
		out.append_array([ui.name.text, ui.scale.text, ui.stamp.text, ui.cut.text, ui.night.text])
	out.append_array([_edge.text, _missed.text])
	return "\n".join(out)


func press_continue() -> void:
	_continue.pressed.emit()


func _side_card(corner: int) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(560.0, 0.0)
	var style: StyleBoxFlat = FightHud._panel_style(CARD)
	style.set_content_margin_all(22)
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var colour: Color = RED_CORNER if corner == 0 else BLUE_CORNER
	var ui: Dictionary = {}
	ui.name = Label.new()
	DisplayFont.apply(ui.name, 40)
	ui.name.add_theme_color_override("font_color", colour)
	ui.name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(ui.name)
	ui.portrait = FighterPortrait.new(FighterPortrait.FULL, corner, 12.0 if corner == 0 else -12.0)
	ui.portrait.custom_minimum_size = Vector2(300.0, 360.0)
	ui.portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(ui.portrait)
	ui.scale = Label.new()
	DisplayFont.apply(ui.scale, 64)
	ui.scale.add_theme_color_override("font_color", TEXT)
	ui.scale.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(ui.scale)
	ui.lb = FightNightCard._label(18, DIM)
	ui.lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(ui.lb)
	ui.stamp = Label.new()
	DisplayFont.apply(ui.stamp, 34)
	ui.stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(ui.stamp)
	for key: String in ["cut", "night"]:
		var l: Label = FightNightCard._label(18, Color("#adb5bd"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l)
		ui[key] = l
	_sides.append(ui)
	return card
