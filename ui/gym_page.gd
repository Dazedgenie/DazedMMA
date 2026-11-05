class_name GymPage
extends PanelContainer
## Your gym's page (docs/03 §14.2, D442), opened from the hub's *Your gym* tab: the place drawn from above
## (FloorPlan) with its rooms on their squares, and down the side the room you clicked (its level, what it does now
## and at the next level, what that costs and how long the room's shut) with *Build* and *Tear it down*, or, with
## no room picked, every room you could build with its size and cost. The gym's money and month along the top.
## Building spends the gym's money straight away (Career.build_room). Close or Esc goes back to the hub. The *Coaches*
## tab (CoachesView, §14.3, D443) has the coaches you've hired and the men looking for work; the *Fighters* tab
## (LadsView, §14.4, D444) has him and the other lads who train at your gym.

signal closed
## Something was built or torn down: the career changed (main saves it).
signal changed

const SIDE_WIDTH: float = 460.0

const ROOMS := "rooms"
const COACHES := "coaches"
const FIGHTERS := "fighters"

var career: Career
var picked_room: String = ""
var plan: FloorPlan
## Which tab is showing: ROOMS, COACHES or FIGHTERS.
var tab: String = ROOMS
var rooms_tab: Button
var coaches_tab: Button
var fighters_tab: Button
var coaches: CoachesView
var fighters: LadsView
var _rooms_body: HBoxContainer

var _title: Label
var _subtitle: Label
var _money: RichTextLabel
var _side: VBoxContainer
var _room_title: Label
var _room_text: RichTextLabel
var _build: Button
var _tear: Button
var _why: Label
var _list: VBoxContainer
## The list's Build buttons: room id → Button.
var list_buttons: Dictionary = {}


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var style: StyleBoxFlat = OffCage.hall_panel(true)
	style.set_content_margin_all(24)
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	add_child(column)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	column.add_child(top)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(names)
	_title = Label.new()
	DisplayFont.apply(_title, 44)
	_title.add_theme_color_override("font_color", CareerHub.RED_CORNER)
	names.add_child(_title)
	_subtitle = Label.new()
	_subtitle.add_theme_font_size_override("font_size", 17)
	_subtitle.add_theme_color_override("font_color", CareerHub.DIM)
	names.add_child(_subtitle)
	var close := Button.new()
	close.text = "Back to the hub"
	close.tooltip_text = "Esc"
	close.custom_minimum_size = Vector2(0.0, 46.0)
	close.add_theme_font_size_override("font_size", 18)
	close.pressed.connect(close_page)
	top.add_child(close)
	_money = RichTextLabel.new()
	_money.bbcode_enabled = true
	_money.fit_content = true
	_money.scroll_active = false
	_money.add_theme_font_size_override("normal_font_size", 19)
	column.add_child(_money)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	column.add_child(tabs)
	var group := ButtonGroup.new()
	rooms_tab = _tab(tabs, "Rooms", group, ROOMS)
	coaches_tab = _tab(tabs, "Coaches", group, COACHES)
	fighters_tab = _tab(tabs, "Fighters", group, FIGHTERS)
	rooms_tab.set_pressed_no_signal(true)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	_rooms_body = body
	coaches = CoachesView.new()
	coaches.visible = false
	coaches.changed.connect(func() -> void: _money.text = money_text(career); changed.emit())
	column.add_child(coaches)
	fighters = LadsView.new()
	fighters.visible = false
	column.add_child(fighters)
	plan = FloorPlan.new()
	plan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plan.size_flags_vertical = Control.SIZE_EXPAND_FILL
	plan.picked.connect(pick)
	body.add_child(plan)

	var side_panel := PanelContainer.new()
	side_panel.custom_minimum_size.x = SIDE_WIDTH
	side_panel.add_theme_stylebox_override("panel", FightHud._panel_style(CareerHub.CARD))
	body.add_child(side_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_panel.add_child(scroll)
	_side = VBoxContainer.new()
	_side.add_theme_constant_override("separation", 10)
	_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_side)
	_room_title = Label.new()
	DisplayFont.apply(_room_title, 30)
	_side.add_child(_room_title)
	_room_text = RichTextLabel.new()
	_room_text.bbcode_enabled = true
	_room_text.fit_content = true
	_room_text.scroll_active = false
	_room_text.add_theme_font_size_override("normal_font_size", 17)
	_side.add_child(_room_text)
	_build = _button("Build", func() -> void: build(picked_room))
	CampPlanner.style_fight_button(_build, 22)
	_tear = _button("Tear it down", func() -> void: tear_down(picked_room))
	_why = Label.new()
	_why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_why.add_theme_font_size_override("font_size", 16)
	_why.add_theme_color_override("font_color", CareerHub.WARN)
	_side.add_child(_why)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	_side.add_child(_list)
	visible = false


## Opens the page for this career's gym, with nothing picked, on the Rooms tab.
func show_gym(c: Career, p_picked: String = "") -> void:
	career = c
	picked_room = p_picked
	visible = true
	show_tab(ROOMS)


## Shows the Rooms, Coaches or Fighters tab.
func show_tab(id: String) -> void:
	tab = id
	for pair: Array in [[ROOMS, rooms_tab], [COACHES, coaches_tab], [FIGHTERS, fighters_tab]]:  # Set by hand: no signal unpresses the rest.
		(pair[1] as Button).set_pressed_no_signal(pair[0] == id)
	refresh()


func refresh() -> void:
	if career == null:
		return
	var gym: Dictionary = career.gym
	_title.text = String(gym.get("name", "Your gym")).to_upper()
	_subtitle.text = "%s · %s · %d of %d squares of floor used" % [String(Gym.place(String(gym.get("place", ""))).get("name", "")),
		Gym.kind_line(gym), Gym.floor_used(gym), Gym.floor_size(gym)]
	_money.text = money_text(career)
	_rooms_body.visible = tab == ROOMS
	coaches.visible = tab == COACHES
	fighters.visible = tab == FIGHTERS
	if tab == COACHES:
		coaches.show_career(career)
		return
	if tab == FIGHTERS:
		fighters.show_career(career)
		return
	plan.show_gym(gym, career.week, picked_room)
	_build.visible = false
	_tear.visible = false
	_why.text = ""
	for child in _list.get_children():
		child.queue_free()
	list_buttons.clear()
	if picked_room != "":
		_show_room(picked_room)
	else:
		_show_list()


## Picks a room on the plan ("" for none: the build list).
func pick(room_id: String) -> void:
	picked_room = room_id
	refresh()


## Builds the next level of a room with the gym's money; "" when it started, else why not.
func build(room_id: String) -> String:
	if career == null:
		return "No career"
	var why: String = career.build_room(room_id)
	if why == "":
		picked_room = room_id
		changed.emit()
	refresh()
	_why.text = why
	return why


func tear_down(room_id: String) -> String:
	if career == null:
		return "No career"
	var why: String = career.tear_down_room(room_id)
	if why == "":
		changed.emit()
	refresh()
	_why.text = why
	return why


## "The gym has $620 · +$100 a month · building the ring, open in 2 weeks"
static func money_text(c: Career) -> String:
	var bits: Array[String] = []
	var money: String = "[b]$%d[/b] in the gym's bank" % c.gym_money
	if c.gym_money < 0:
		money = "[color=%s][b]$%d[/b], behind on the rent[/color]" % [CareerHub.WARN.to_html(false), c.gym_money]
	bits.append(money)
	var net: int = Gym.month_net(c.gym)
	bits.append("%s$%d a month (%d members at $%d, rent $%d)" % ["+" if net >= 0 else "−", absi(net), int(c.gym.get("members", 0)),
		int(c.gym.get("dues", 0)), int(c.gym.get("rent", 0))])
	var building: Dictionary = c.gym.get("building", {})
	if not building.is_empty():
		var left: int = maxi(1, int(building.get("done", c.week)) - c.week)
		var name: String = String(Gym.room(String(building.room)).get("name", "")).to_lower()
		bits.append("%s the %s: %d week%s" % ["tearing out" if int(building.level) == 0 else "building", name, left, "" if left == 1 else "s"])
	if not Staff.coaches(c.gym).is_empty():  # The coaches' wages (D443).
		bits.append("wages $%d a week" % Staff.wages(c.gym))
	return " · ".join(bits)


## What a room does at its level and the next, for the side panel.
static func room_text(c: Career, room_id: String) -> String:
	var gym: Dictionary = c.gym
	var r: Dictionary = Gym.room(room_id)
	var lv: int = Gym.level(gym, room_id)
	var lines: Array[String] = []
	lines.append("[color=%s]%s Takes %d square%s of floor.[/color]" % [CareerHub.DIM.to_html(false), String(r.get("about", "")),
		int(r.get("size", 1)), "" if int(r.get("size", 1)) == 1 else "s"])
	var building: Dictionary = gym.get("building", {})
	if String(building.get("room", "")) == room_id:
		lines.append("[color=%s]Shut while the work's done: %d week%s left.[/color]" % [FloorPlan.STRIPE.to_html(false),
			maxi(1, int(building.done) - c.week), "" if int(building.done) - c.week <= 1 else "s"])
	var opens: Array[String] = opens_names(room_id)
	if lv > 0:
		lines.append("")
		lines.append("[b]Level %d of %d now[/b]" % [lv, Gym.ROOM_LEVELS])
		for line: String in Gym.effect_lines(room_id, lv):
			lines.append("• " + line)
		if not opens.is_empty():
			lines.append("• Lets him do %s" % " and ".join(PackedStringArray(opens)))
	if lv < Gym.ROOM_LEVELS:
		lines.append("")
		lines.append("[b]%s[/b]: $%d, %d week%s with the room shut" % ["Level %d" % (lv + 1) if lv > 0 else "Building it",
			Gym.build_cost(gym, room_id), Gym.build_weeks(room_id, lv + 1), "" if Gym.build_weeks(room_id, lv + 1) == 1 else "s"])
		for line: String in Gym.effect_lines(room_id, lv + 1):
			lines.append("• " + line)
		if lv == 0 and not opens.is_empty():
			lines.append("• Lets him do %s" % " and ".join(PackedStringArray(opens)))
		lines.append("• One more member")
	return "\n".join(lines)


## The sessions that need this room ("hard sparring"), by name.
static func opens_names(room_id: String) -> Array[String]:
	var out: Array[String] = []
	var lib: TrainingLibrary = TrainingLibrary.shared()
	for id: String in lib.session_ids():
		if room_id in lib.session(id).get("needs", []):
			out.append(String(lib.session(id).get("name", id)).to_lower())
	return out


func _show_room(room_id: String) -> void:
	var gym: Dictionary = career.gym
	var lv: int = Gym.level(gym, room_id)
	_room_title.text = String(Gym.room(room_id).get("name", room_id)).to_upper()
	_room_text.text = room_text(career, room_id)
	_build.visible = lv < Gym.ROOM_LEVELS
	_build.text = ("Build level %d · $%d" % [lv + 1, Gym.build_cost(gym, room_id)]) if lv > 0 else "Build it · $%d" % Gym.build_cost(gym, room_id)
	var why: String = Gym.cant_build(gym, room_id, career.gym_money)
	_build.disabled = why != ""
	_build.tooltip_text = why
	_tear.visible = lv > 0
	_tear.text = "Tear it down · $%d back" % Gym.tear_down_back(gym, room_id)
	_tear.disabled = Gym.cant_tear_down(gym, room_id) != ""
	_tear.tooltip_text = Gym.cant_tear_down(gym, room_id)
	_why.text = why if lv < Gym.ROOM_LEVELS else ""
	if String(gym.get("building", {}).get("room", "")) == room_id:  # The work's on it now: nothing to press.
		_build.visible = false
		_tear.visible = false
		_why.text = ""
	var back := Button.new()
	back.text = "Every room you could build"
	back.add_theme_font_size_override("font_size", 16)
	back.pressed.connect(func() -> void: pick(""))
	_list.add_child(back)


func _show_list() -> void:
	var gym: Dictionary = career.gym
	_room_title.text = "BUILD A ROOM"
	_room_text.text = "[color=%s]Click a room on the plan to upgrade it. Each room you build or upgrade brings a member in; one job at a time.[/color]" % CareerHub.DIM.to_html(false)
	for id: String in Gym.rooms():
		if Gym.level(gym, id) > 0:
			continue
		var r: Dictionary = Gym.room(id)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		_list.add_child(box)
		var head := Label.new()
		head.text = "%s · %d square%s · $%d · %d week%s" % [String(r.name), int(r.size), "" if int(r.size) == 1 else "s", Gym.build_cost(gym, id),
			Gym.build_weeks(id, 1), "" if Gym.build_weeks(id, 1) == 1 else "s"]
		head.add_theme_font_size_override("font_size", 18)
		box.add_child(head)
		var what := Label.new()
		var effects: Array[String] = Gym.effect_lines(id, 1)
		var opens: Array[String] = opens_names(id)
		if not opens.is_empty():
			effects.append("lets him do %s" % " and ".join(PackedStringArray(opens)))
		what.text = "; ".join(PackedStringArray(effects)) + "."
		what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		what.add_theme_font_size_override("font_size", 15)
		what.add_theme_color_override("font_color", CareerHub.DIM)
		box.add_child(what)
		var b := Button.new()
		var why: String = Gym.cant_build(gym, id, career.gym_money)
		b.text = "Build it" if why == "" else why
		b.disabled = why != ""
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(func() -> void: build(id))
		box.add_child(b)
		list_buttons[id] = b


func _tab(parent: Control, label: String, group: ButtonGroup, id: String) -> Button:
	var b := Button.new()
	b.text = label
	b.toggle_mode = true
	b.button_group = group
	DisplayFont.apply(b, 22)
	b.custom_minimum_size = Vector2(140.0, 42.0)
	b.pressed.connect(func() -> void: show_tab(id))
	parent.add_child(b)
	return b


func _button(label: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(0.0, 44.0)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(action)
	_side.add_child(b)
	return b


func close_page() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_page()
		get_viewport().set_input_as_handled()
