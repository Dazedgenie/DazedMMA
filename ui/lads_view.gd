class_name LadsView
extends HBoxContainer
## The *Fighters* tab of your gym's page (docs/03 §14.4, D444): him first, then the other lads who train at your gym,
## one row each (his face, name and age, style, record, how he compares with your lad, how long he's trained here),
## and down the side what they do for him: the sparring partner his best lad makes and what that does to his
## partner sessions (Lads.partner_share), how many lads the gym has room for, and the lads who've left.

const FACE := Vector2(84.0, 98.0)
const GOOD := Color("#69db7c")

var career: Career
## One row a lad, in the gym's order (him not counted).
var lad_rows: Array[Control] = []

var _list: VBoxContainer
var _side: VBoxContainer
var _effect: RichTextLabel


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
	lad_rows.clear()
	var lads: Array = career.gym_lads()
	var me: Dictionary = career.profile()
	var his: float = Matchmaker.average_stat(me.get("stats", {}))
	_heading(_list, "WHO TRAINS HERE", "Real fighters from round here. They keep fighting on the world's cards; a gym-mate is never offered against him.")
	_list.add_child(_row(me, him_text(career)))
	if lads.is_empty():
		var none := Label.new()
		none.text = "Nobody else trains here yet."
		none.add_theme_color_override("font_color", CareerHub.DIM)
		_list.add_child(none)
	var w: World = career.world()
	for lad: Dictionary in lads:
		var face: Dictionary = w.profile(String(lad.get("id", "")), career.week)
		if face.is_empty():
			face = { "id": String(lad.get("id", "")), "name": String(lad.get("name", "")), "stance": "orthodox",
				"home": NameLibrary.shared().country_id_of(String(lad.get("country", ""))) }
		var row: Control = _row(face, lad_text(lad, his, career.week))
		lad_rows.append(row)
		_list.add_child(row)
	_heading(_side, "SPARRING PARTNERS", "Sparring, rolling, wrestling, the clinch and the Shark tank go better with a good partner.")
	_effect = RichTextLabel.new()
	_effect.bbcode_enabled = true
	_effect.fit_content = true
	_effect.scroll_active = false
	_effect.add_theme_font_size_override("normal_font_size", 17)
	_effect.text = side_text(career)
	_side.add_child(_effect)


## His own row's words: "Danny Shaw, 16 · your lad", his record and his average stat.
static func him_text(c: Career) -> String:
	var p: Dictionary = c.profile()
	return "[b]%s[/b], %d · [color=%s]your lad[/color]\n%s %s\n[color=%s]Average stat %d[/color]" % [String(p.get("name", "")),
		int(p.get("age", 16)), CareerHub.RED_CORNER.to_html(false), c.record_text(c.pro), "pro" if c.pro else "amateur",
		CareerHub.DIM.to_html(false), roundi(Matchmaker.average_stat(p.get("stats", {})))]


## A lad's words: who he is, his style and record, how he compares, how long he's been here.
static func lad_text(lad: Dictionary, his: float, week: int) -> String:
	var age: int = int(floor(World.age_of(lad, week))) if lad.has("born") else 0
	var record: String = "%s %s" % [String(lad.get("record", "0-0-0")), "pro" if bool(lad.get("pro", false)) else "amateur"]
	var months: int = int(float(maxi(0, week - int(lad.get("since", week)))) / (Career.WEEKS_PER_YEAR / 12.0))
	var here: String = "Just walked in" if months < 1 else "Trains here %d month%s" % [months, "" if months == 1 else "s"]
	var compare: String = Lads.compare_text(lad, his)
	var colour: Color = GOOD if float(lad.get("avg", 0.0)) - his >= 3.0 else CareerHub.DIM
	return "[b]%s[/b]%s\n%s · %s\n[color=%s]%s[/color] · [color=%s]%s[/color]" % [String(lad.get("name", "")),
		", %d" % age if age > 0 else "", _style_name(String(lad.get("style", ""))), record, colour.to_html(false), compare,
		CareerHub.DIM.to_html(false), here]


## The side's words: his partner sessions' share, the room, the lads who've left.
static func side_text(c: Career) -> String:
	var lines: Array[String] = []
	var his: float = Matchmaker.average_stat(c.profile().get("stats", {}))
	var share: float = Lads.partner_share(c.gym, his, { "partner": true })
	var pct: int = roundi(absf(share - 1.0) * 100.0)
	var best: String = CareerHub.best_partner_text(c)
	if Lads.lads(c.gym).is_empty():
		lines.append("[color=%s]Nobody to spar with: his partner sessions learn %d%% slower.[/color]" % [CareerHub.WARN.to_html(false), pct])
	elif share >= 1.0:
		lines.append("[b]Best partner: %s[/b]" % best)
		lines.append("[color=%s]His partner sessions learn %d%% faster.[/color]" % [GOOD.to_html(false), pct] if pct > 0
			else "His partner sessions learn as normal.")
	else:
		lines.append("[b]Best partner: %s[/b]" % best)
		lines.append("[color=%s]Nobody here's as good as him: his partner sessions learn %d%% slower.[/color]" % [CareerHub.WARN.to_html(false), pct])
	lines.append("[color=%s]Up to %d%% faster when the best lad is %d points of average stat better than him; up to %d%% slower when he's that much worse.[/color]" % [
		CareerHub.DIM.to_html(false), roundi(Lads.PARTNER_UP * 100.0), roundi(Lads.PARTNER_SPREAD), roundi(Lads.PARTNER_DOWN * 100.0)])
	lines.append("")
	lines.append("[b]Room for %d lads[/b]" % Lads.room(c.gym))
	lines.append("[color=%s]One for every %d members, %d to %d. A new lad may walk in each month while there's room; now and then one leaves to train somewhere else.[/color]" % [
		CareerHub.DIM.to_html(false), Lads.MEMBERS_PER_LAD, Lads.MIN_LADS, Lads.MAX_LADS])
	var former: Array = c.gym.get("former", []) if c.gym.get("former") is Array else []
	if not former.is_empty():
		var names: Array[String] = []
		for id: String in former:
			var m: Dictionary = c.world().man(id)
			if not m.is_empty():
				names.append(String(m.get("name", "")))
		if not names.is_empty():
			lines.append("")
			lines.append("[b]Used to train here[/b]")
			lines.append("[color=%s]%s. They can be offered against him now.[/color]" % [CareerHub.DIM.to_html(false), ", ".join(PackedStringArray(names))])
	return "\n".join(lines)


static func _style_name(style_id: String) -> String:
	if StyleLibrary.shared().has(style_id):
		return String(StyleLibrary.shared().get_style(style_id).get("name", style_id))
	return style_id.capitalize()


func _row(profile: Dictionary, text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var face := FighterPortrait.new(FighterPortrait.BUST, 1, 10.0)
	face.custom_minimum_size = FACE
	face.show_fighter(profile)
	row.add_child(face)
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("normal_font_size", 16)
	label.add_theme_font_size_override("bold_font_size", 18)
	label.text = text
	row.add_child(label)
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
