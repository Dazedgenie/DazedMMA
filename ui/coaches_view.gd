class_name CoachesView
extends HBoxContainer
## The *Coaches* tab of your gym's page (docs/03 §14.3, D443): your coaches down the left, one row a role (his face,
## name, role, level, personality and wage, where he's from, what he does now, *Let him go*), and down the side the men
## looking for work this month (Career.coaches_looking), each with *Hire* or why you can't. Hiring and letting go
## change the career at once (Career.hire_coach, Career.let_go_coach); `changed` tells the page to save and redraw.

signal changed

const FACE := Vector2(84.0, 98.0)
## A coach's frame for his face (drawn from his name and country, as the gym's old owner is, D434).
const FRAME := { "height_cm": 176, "reach_cm": 178, "build": "stocky" }
const UNPAID := Color("#fcc419")

var career: Career
## The Hire buttons, by their place in the looking list, and the Let go buttons by role.
var hire_buttons: Array[Button] = []
var let_go_buttons: Dictionary = {}

var _staff: VBoxContainer
var _looking: VBoxContainer
var _why: Label


func _init() -> void:
	add_theme_constant_override("separation", 20)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var staff_panel := _panel(true)
	add_child(staff_panel)
	_staff = _column(staff_panel)
	var side := _panel(false)
	side.custom_minimum_size.x = GymPage.SIDE_WIDTH
	add_child(side)
	_looking = _column(side)


func show_career(c: Career) -> void:
	career = c
	refresh()


func refresh() -> void:
	if career == null:
		return
	for box: VBoxContainer in [_staff, _looking]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	hire_buttons.clear()
	let_go_buttons.clear()
	_heading(_staff, "YOUR COACHES", "You're his head coach. These are the specialists you pay each week: $%d a week now." % Staff.wages(career.gym))
	for role_id: String in Staff.roles():
		var coach: Dictionary = Staff.in_role(career.gym, role_id)
		if coach.is_empty():
			var none := Label.new()
			none.text = "No %s yet" % Staff.role_words(role_id)
			none.add_theme_font_size_override("font_size", 17)
			none.add_theme_color_override("font_color", CareerHub.DIM)
			_staff.add_child(none)
			continue
		var b := Button.new()
		b.text = "Let him go"
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(func() -> void: let_go(role_id))
		let_go_buttons[role_id] = b
		_staff.add_child(_row(coach, b, coach_text(coach, true)))
	_heading(_looking, "LOOKING FOR WORK", "New faces on the first of every month. One coach a role; his first wage goes out next Monday.")
	_why = Label.new()
	_why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_why.add_theme_font_size_override("font_size", 16)
	_why.add_theme_color_override("font_color", CareerHub.WARN)
	_looking.add_child(_why)
	var list: Array = career.coaches_looking()
	if list.is_empty():
		var nobody := Label.new()
		nobody.text = "Nobody's looking this month."
		nobody.add_theme_color_override("font_color", CareerHub.DIM)
		_looking.add_child(nobody)
	for i in list.size():
		var coach: Dictionary = list[i]
		var why: String = Staff.cant_hire(career.gym, coach)
		var b := Button.new()
		b.text = "Hire him · $%d a week" % Staff.wage(coach) if why == "" else "You have one"
		b.tooltip_text = why
		b.disabled = why != ""
		b.add_theme_font_size_override("font_size", 16)
		var index: int = i
		b.pressed.connect(func() -> void: hire(index))
		hire_buttons.append(b)
		_looking.add_child(_row(coach, b, coach_text(coach, false)))


## Hires the man at `index` of the list; "" when he's hired, else why not.
func hire(index: int) -> String:
	if career == null:
		return "No career"
	var why: String = career.hire_coach(index)
	if why == "":
		changed.emit()
	refresh()
	_why.text = why
	return why


func let_go(role_id: String) -> String:
	if career == null:
		return "No career"
	var gone: Dictionary = career.let_go_coach(role_id)
	if gone.is_empty():
		return "Nobody to let go"
	changed.emit()
	refresh()
	return ""


## His words on a row: who he is, what he was, what he does (and, on your staff, whether he's owed).
static func coach_text(coach: Dictionary, on_staff: bool) -> String:
	var lines: Array[String] = []
	lines.append("[b]%s[/b], %d" % [String(coach.get("name", "")), int(coach.get("age", 40))])
	lines.append(Staff.title_line(coach))
	if String(coach.get("line", "")) != "":
		lines.append("[color=%s]%s[/color]" % [CareerHub.DIM.to_html(false), String(coach.line)])
	lines.append("[color=%s]%s[/color]" % [CareerHub.DIM.to_html(false), "; ".join(PackedStringArray(Staff.does_lines(coach)))])
	if on_staff and int(coach.get("unpaid", 0)) > 0:
		lines.append("[color=%s]Unpaid %d week%s: he walks after %d[/color]" % [UNPAID.to_html(false), int(coach.unpaid),
			"" if int(coach.unpaid) == 1 else "s", Staff.UNPAID_WEEKS])
	return "\n".join(lines)


## A coach's face profile for FighterPortrait.
static func face_profile(coach: Dictionary) -> Dictionary:
	var who: String = String(coach.get("name", ""))
	return { "id": "coach_%s" % who.to_snake_case(), "name": who, "stance": "orthodox",
		"look": FighterLook.roll(hash([who, "coach look"]), String(coach.get("country_id", ""))), "frame": FRAME.duplicate() }


func _row(coach: Dictionary, button: Button, text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var face := FighterPortrait.new(FighterPortrait.BUST, 1, 10.0)
	face.custom_minimum_size = FACE
	face.show_fighter(face_profile(coach))
	row.add_child(face)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.add_theme_font_size_override("normal_font_size", 16)
	label.add_theme_font_size_override("bold_font_size", 18)
	label.text = text
	words.add_child(label)
	words.add_child(button)
	return row


func _heading(box: VBoxContainer, title: String, about: String) -> void:
	var t := Label.new()
	t.text = title
	DisplayFont.apply(t, 30)
	box.add_child(t)
	var a := Label.new()
	a.text = about
	a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	a.add_theme_font_size_override("font_size", 16)
	a.add_theme_color_override("font_color", CareerHub.DIM)
	box.add_child(a)


func _panel(expand: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", FightHud._panel_style(CareerHub.CARD))
	if expand:
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return p


func _column(panel: PanelContainer) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	return box
