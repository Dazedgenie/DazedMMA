class_name StableView
extends HBoxContainer
## The *Stable* tab of your gym's page (docs/03 §14.5, D445): down the left your stable, him first and then each man
## you've signed (his face, name and age, style, record, what he trains and how much faster the gym makes it, whether
## he's happy, his next fight or his offers waiting), with a focus picker, *Let him go* and *Turn the fight down* (§14.6); down the side the
## men you could sign this week (Career.stable_prospects: the gym's lads first, then his country's best local men), each
## with his chance of saying yes and *Offer him a place*, or why you can't. Signing, a focus and letting go change the career at once
## (Career.sign_fighter, Career.set_stable_focus, Career.release_fighter); `changed` tells the page to save and redraw.

signal changed
## *Plan his camp* (D451): main opens the camp planner on him.
signal camp_pressed(id: String)

const FACE := Vector2(84.0, 98.0)
const GOOD := Color("#69db7c")

var career: Career
## The focus pickers and Let go buttons by the man's id, and the Sign buttons in the prospects' order.
var focus_pickers: Dictionary = {}
var let_go_buttons: Dictionary = {}
var turn_down_buttons: Dictionary = {}
var camp_buttons: Dictionary = {}
var sign_buttons: Array[Button] = []
## The prospects shown, in order (each the world's man).
var shown_prospects: Array = []

var _list: VBoxContainer
var _side: VBoxContainer
var _why: Label


func _init() -> void:
	add_theme_constant_override("separation", 20)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var main := _panel(true)
	add_child(main)
	_list = _column(main)
	var side := _panel(false)
	side.custom_minimum_size.x = GymPage.SIDE_WIDTH
	add_child(side)
	_side = _column(side)


func show_career(c: Career) -> void:
	career = c
	refresh()


func refresh() -> void:
	if career == null:
		return
	for box: VBoxContainer in [_list, _side]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	focus_pickers.clear()
	let_go_buttons.clear()
	turn_down_buttons.clear()
	camp_buttons.clear()
	sign_buttons.clear()
	var gym: Dictionary = career.gym
	var w: World = career.world()
	_heading(_list, "YOUR STABLE", "%d of %d places: one for every %d members, %d to %d, his among them. They fight on the world's cards; the gym takes %d%% of a pro purse." % [
		Stable.fighters(gym).size() + 1, Stable.places(gym), Stable.PER_MEMBERS, Stable.MIN_PLACES, Stable.MAX_PLACES,
		roundi(Gym.PURSE_CUT * 100.0)])
	_list.add_child(_row(career.profile(), LadsView.him_text(career), []))
	if Stable.fighters(gym).is_empty():
		var none := Label.new()
		none.text = "Nobody's signed yet. Offer a man a place from the list on the right."
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.add_theme_color_override("font_color", CareerHub.DIM)
		_list.add_child(none)
	for e: Dictionary in Stable.fighters(gym):
		var id: String = String(e.get("id", ""))
		var picker := OptionButton.new()
		picker.add_theme_font_size_override("font_size", 16)
		var ids: Array = Stable.focuses().keys()
		for i in ids.size():
			picker.add_item("Trains: %s" % String(Stable.focus(String(ids[i])).get("name", ids[i])), i)
			if String(ids[i]) == String(e.get("focus", Stable.DEFAULT_FOCUS)):
				picker.select(i)
		picker.tooltip_text = String(Stable.focus(String(e.get("focus", ""))).get("about", ""))
		picker.item_selected.connect(func(i: int) -> void: set_focus(id, String(ids[i])))
		focus_pickers[id] = picker
		var b := Button.new()
		b.text = "Let him go"
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(func() -> void: let_go(id))
		let_go_buttons[id] = b
		var controls: Array = [picker, b]
		var next_line: String = ""
		var booked: Dictionary = Stable.booking(e)
		if not booked.is_empty():  # His next fight (D445's second piece, D450), with the chance to turn it down.
			next_line = "Next: %s, %s%s" % [String(booked.get("opponent_name", "")), career.short_date(int(booked.week), 5),
				" · %s" % String(booked.card) if String(booked.get("card", "")) != "" else ""]
			if Stable.can_camp(e, career.week):  # His camp for it (D451).
				var camp := Button.new()
				camp.add_theme_font_size_override("font_size", 16)
				camp.text = camp_label(career, e)
				camp.disabled = camp.text == WEEK_RUN
				camp.tooltip_text = "Plan his week's training and play the minigames, like your lad's camp"
				camp.pressed.connect(func() -> void: camp_pressed.emit(id))
				camp_buttons[id] = camp
				controls.append(camp)
				var c: Dictionary = Stable.camp_of(e)
				if not c.is_empty():
					var weeks: int = Stable.camp_weeks_left(e, career.week)
					next_line += " · his camp: %s, fatigue %d" % ["fight week" if weeks <= 1 else "%d weeks to go" % weeks,
						roundi(float(c.get("snap", {}).get("fatigue", 0.0)))]
			var no := Button.new()
			no.text = "Turn the fight down"
			no.tooltip_text = "He waits %d weeks for more offers" % Stable.TURN_DOWN_WEEKS
			no.add_theme_font_size_override("font_size", 16)
			no.pressed.connect(func() -> void: turn_down(id))
			turn_down_buttons[id] = no
			controls.append(no)
		elif not Stable.offers_of(e).is_empty():  # His offers (D450), taken on the hub or in your lad's camp.
			var n: int = Stable.offers_of(e).size()
			next_line = "%d fight offer%s waiting: pick one on the hub" % [n, "" if n == 1 else "s"]
		_list.add_child(_row(_face(w, e), fighter_text(gym, e, career.week, next_line), controls))

	_heading(_side, "SIGN A FIGHTER", "The lads who train here, then the best amateurs and local and regional pros from round here. Better rooms and coaches make a yes likelier; a man who says no won't be asked again for %d weeks." % Stable.ASK_AGAIN_WEEKS)
	_why = Label.new()
	_why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_why.add_theme_font_size_override("font_size", 16)
	_why.add_theme_color_override("font_color", CareerHub.WARN)
	_side.add_child(_why)
	shown_prospects = career.stable_prospects()
	if shown_prospects.is_empty():
		var nobody := Label.new()
		nobody.text = "Nobody round here to sign."
		nobody.add_theme_color_override("font_color", CareerHub.DIM)
		_side.add_child(nobody)
	for i in shown_prospects.size():
		var m: Dictionary = shown_prospects[i]
		var why: String = Stable.cant_sign(gym, m, career.week)
		var b := Button.new()
		b.text = "Offer him a place" if why == "" else why
		b.disabled = why != ""
		b.add_theme_font_size_override("font_size", 16)
		var index: int = i
		b.pressed.connect(func() -> void: offer_place(index))
		sign_buttons.append(b)
		_side.add_child(_row(_face(w, m), prospect_text(w, gym, m, career.week), [b]))


## Offers the prospect at `index` a place; "" when he signs, else why not (shown under the heading).
func offer_place(index: int) -> String:
	if career == null or index < 0 or index >= shown_prospects.size():
		return "Nobody there"
	var why: String = career.sign_fighter(String(shown_prospects[index].get("id", "")))
	changed.emit()
	refresh()
	_why.text = why
	return why


func set_focus(id: String, focus_id: String) -> bool:
	if career == null or not career.set_stable_focus(id, focus_id):
		return false
	changed.emit()
	refresh()
	return true


func turn_down(id: String) -> bool:
	if career == null or not career.turn_down_stable_fight(id):
		return false
	changed.emit()
	refresh()
	return true


func let_go(id: String) -> String:
	if career == null or career.release_fighter(id).is_empty():
		return "Nobody to let go"
	changed.emit()
	refresh()
	return ""


const WEEK_RUN := "This week's camp is run"


## His camp button's words (D451): *Plan his camp* until it's opened, then this week's, fight night, or run already.
static func camp_label(c: Career, e: Dictionary) -> String:
	var id: String = String(e.get("id", ""))
	if Stable.camp_of(e).is_empty():
		return "Plan his camp"
	if c.stable_camp_ran(id):
		return "His fight night" if Stable.camp_weeks_left(e, c.week) <= 1 else WEEK_RUN
	return "His fight week" if Stable.camp_weeks_left(e, c.week) <= 1 else "His camp this week"


## A signed man's words: who he is, his style and record, what he trains and how much faster, how he feels, and his
## next fight (`next_line`, "" for none).
static func fighter_text(gym: Dictionary, e: Dictionary, week: int, next_line: String = "") -> String:
	var age: int = int(floor(World.age_of(e, week))) if e.has("born") else 0
	var record: String = "%s %s" % [String(e.get("record", "0-0-0")), "pro" if bool(e.get("pro", false)) else "amateur"]
	var focus_id: String = String(e.get("focus", Stable.DEFAULT_FOCUS))
	var faster: int = roundi(Stable.boost(gym, focus_id) * 100.0)
	var mood: String = "[color=%s]Happy here[/color]" % GOOD.to_html(false)
	if int(e.get("unhappy", 0)) > 0:
		mood = "[color=%s]Unhappy: %s. He leaves next month if it isn't put right.[/color]" % [CareerHub.WARN.to_html(false), String(e.get("why", ""))]
	return "[b]%s[/b]%s\n%s · %s · average stat %d\n[color=%s]%s: he learns %d%% faster than on his own[/color]\n%s" % [
		String(e.get("name", "")), ", %d" % age if age > 0 else "", LadsView._style_name(String(e.get("style", ""))), record,
		roundi(float(e.get("avg", 0.0))), CareerHub.DIM.to_html(false), String(Stable.focus(focus_id).get("name", "")), faster, mood] \
		+ ("\n[color=%s]%s[/color]" % [Color("#cc5de8").to_html(false), next_line] if next_line != "" else "")


## A prospect's words: who he is, what he is, and his chance of saying yes.
static func prospect_text(w: World, gym: Dictionary, m: Dictionary, week: int) -> String:
	var what: String = "Trains here" if Lads.lads(gym).any(func(l: Dictionary) -> bool: return String(l.get("id", "")) == String(m.get("id", ""))) else ""
	for level: Dictionary in World.LEVELS:
		if what == "" and String(level.id) == String(m.get("tier", "")):
			what = String(level.name)
	return "[b]%s[/b], %d\n%s · %s · average stat %d\n[color=%s]%s · %d%% he says yes[/color]" % [String(m.get("name", "")),
		int(floor(World.age_of(m, week))), LadsView._style_name(String(m.get("style", ""))), World.record_text(m),
		roundi(w.average(m)), CareerHub.DIM.to_html(false), what, roundi(Stable.yes_chance(gym, m) * 100.0)]


func _face(w: World, m: Dictionary) -> Dictionary:
	var face: Dictionary = w.profile(String(m.get("id", "")), career.week)
	if face.is_empty():
		face = { "id": String(m.get("id", "")), "name": String(m.get("name", "")), "stance": "orthodox",
			"home": NameLibrary.shared().country_id_of(String(m.get("country", ""))) }
	return face


func _row(profile: Dictionary, text: String, controls: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var face := FighterPortrait.new(FighterPortrait.BUST, 1, 10.0)
	face.custom_minimum_size = FACE
	face.show_fighter(profile)
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
	if not controls.is_empty():
		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 8)
		for c: Control in controls:
			buttons.add_child(c)
		words.add_child(buttons)
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
