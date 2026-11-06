class_name StableFightsBox
extends VBoxContainer
## Your stable's fights this week (docs/03 §14.6, D450), on the hub under his next fight and in his camp planner: the
## men with offers in, each offer with Take it and Turn it down (Career.take_stable_offer, decline_stable_offer), then
## the men fighting this Saturday with Play it, Sim it and Turn it down. Hidden when there's neither. The buttons only
## signal: the hub's and the planner's owner (game/main.gd) does the rest and calls show_career() again.

signal play_pressed(id: String)
signal sim_pressed(id: String)
signal turn_down_pressed(id: String)
signal take_pressed(id: String, index: int)
signal decline_pressed(id: String, index: int)

const FONT_SIZE: int = 18
const BUTTON_HEIGHT: float = 40.0

## This Saturday's men's buttons by id: { play, sim, turn_down }.
var fight_buttons: Dictionary = {}
## The offers' buttons by the man's id, in his offers' order: [{ take, decline }].
var offer_buttons: Dictionary = {}
## What it says, as plain lines (for the hub's and the planner's text()).
var lines: Array[String] = []


func _init() -> void:
	add_theme_constant_override("separation", 8)
	visible = false


func show_career(c: Career) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	fight_buttons.clear()
	offer_buttons.clear()
	lines.clear()
	if c == null:
		visible = false
		return
	var offered: Array = Stable.offered(c.gym)
	var due: Array = Stable.due(c.gym, c.week)
	visible = not offered.is_empty() or not due.is_empty()
	if not offered.is_empty():
		_heading("Offers for your stable")
		for d: Dictionary in offered:
			var id: String = String(d.id)
			var who := _rich()
			who.text = "[b]%s[/b] (%s)" % [String(d.entry.get("name", "")), String(d.entry.get("record", ""))]
			lines.append(CareerHub._plain(who.text))
			add_child(who)
			var buttons: Array = []
			for i in (d.offers as Array).size():
				var index: int = i
				var row := _row(offer_text(c, d.offers[i]))
				var take: Button = _button(row, "Take it", func() -> void: take_pressed.emit(id, index),
					"He's booked for it and his other offers go")
				var no: Button = _button(row, "Turn it down", func() -> void: decline_pressed.emit(id, index),
					"This one goes; his others stay")
				buttons.append({ "take": take, "decline": no })
			offer_buttons[id] = buttons
	if not due.is_empty():
		_heading("Your stable fights this Saturday")
		for d: Dictionary in due:
			var id: String = String(d.id)
			var row := _row(fight_text(c, d))
			var play: Button = _button(row, "Play it", func() -> void: play_pressed.emit(id), "The fight screen, with you in his corner")
			var sim: Button = _button(row, "Sim it", func() -> void: sim_pressed.emit(id), "The whole fight at once, straight to the result")
			var no: Button = _button(row, "Turn it down", func() -> void: turn_down_pressed.emit(id),
				"He waits %d weeks for more offers" % Stable.TURN_DOWN_WEEKS)
			fight_buttons[id] = { "play": play, "sim": sim, "turn_down": no }


## One offer's words: "vs Tom Reid (5-2-0)", then "About even · NCC 14, Sat 6 Feb · Professional MMA · 54% he wins".
static func offer_text(c: Career, o: Dictionary) -> String:
	var opp: Dictionary = c.world().man(String(o.get("opponent", "")))
	var bits: Array[String] = []
	var level: String = String({ "much_easier": "Much easier", "easier": "A bit easier", "even": "About even",
		"harder": "A bit harder", "much_harder": "Much harder" }.get(String(o.get("difficulty", "")), ""))
	if level != "":
		bits.append(level)
	var when: String = c.short_date(int(o.get("week", c.week)), 5)
	bits.append("%s, %s" % [String(o.card), when] if String(o.get("card", "")) != "" else when)
	bits.append(CareerHub.rules_name(String(o.get("ruleset", ""))))
	return "vs %s (%s)\n[color=%s]%s · %d%% he wins[/color]" % [String(opp.get("name", o.get("opponent_name", ""))),
		World.record_text(opp) if not opp.is_empty() else "", CareerHub.DIM.to_html(false), " · ".join(PackedStringArray(bits)),
		roundi(float(o.get("chance", 0.5)) * 100.0)]


## A stable man's fight this Saturday: "[b]Harry Wright[/b] (3-1-0) vs Tom Reid (4-2-0)", then the card and rules.
static func fight_text(c: Career, d: Dictionary) -> String:
	var b: Dictionary = d.booking
	var opp: Dictionary = c.world().man(String(b.get("opponent", "")))
	var bits: Array[String] = []
	if String(b.get("card", "")) != "":
		bits.append(String(b.card))
	bits.append(CareerHub.rules_name(String(b.get("ruleset", ""))))
	return "[b]%s[/b] (%s) vs %s (%s)\n[color=%s]%s[/color]" % [String(d.entry.get("name", "")), String(d.entry.get("record", "")),
		String(opp.get("name", b.get("opponent_name", ""))), World.record_text(opp) if not opp.is_empty() else "",
		CareerHub.DIM.to_html(false), " · ".join(PackedStringArray(bits))]


func _heading(text_in: String) -> void:
	var label := FightNightCard._label(20, CareerHub.DIM)
	DisplayFont.apply(label, 20)
	label.text = text_in.to_upper()
	add_child(label)
	lines.append(label.text)


func _button(row: HBoxContainer, text_in: String, pressed: Callable, tip: String) -> Button:
	var b: Button = CampPlanner._button(row, text_in, pressed)
	b.custom_minimum_size.y = BUTTON_HEIGHT
	b.tooltip_text = tip
	return b


func _row(words_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var words := _rich()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.text = words_text
	lines.append(CareerHub._plain(words_text))
	row.add_child(words)
	add_child(row)
	return row


func _rich() -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	label.add_theme_font_size_override("bold_font_size", FONT_SIZE)
	label.add_theme_color_override("default_color", CareerHub.TEXT)
	return label
