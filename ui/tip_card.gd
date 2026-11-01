class_name TipCard
extends PanelContainer
## Tip cards and the Coach's Notebook (docs/07 §2, docs/03 §11.6, D316). A tip is a small card of two sentences over
## whatever screen it's for, and the screen waits behind it until *Got it* (Kyle, 2026-11-01: "A card that waits for Got
## it"). Several due at once queue up, one after another. The Coach's Notebook (a button on the hub) lists every tip
## he's seen, to read again.
##
## Main owns one, over every screen: show_tips() for the tips due (Tutorial.due), show_notebook() for the Notebook.

signal closed

const SHADE := Color(0.0, 0.0, 0.0, 0.62)
const ACCENT := Color("#fcc419")

var _queue: Array[Dictionary] = []
var _title: Label
var _text: RichTextLabel
var _list: RichTextLabel
var _list_scroll: ScrollContainer
var _counter: Label
var _ok: Button


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override("panel", FightHud._panel_style(SHADE))
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var centre := CenterContainer.new()
	add_child(centre)
	var card := PanelContainer.new()
	var style: StyleBoxFlat = FightHud._panel_style(CareerHub.CARD)
	style.border_color = ACCENT
	style.set_border_width_all(2)
	style.set_content_margin_all(28)
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(620.0, 0.0)
	centre.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	card.add_child(box)
	_counter = FightNightCard._label(14, CareerHub.DIM)
	box.add_child(_counter)
	_title = Label.new()
	DisplayFont.apply(_title, 40)
	_title.add_theme_color_override("font_color", ACCENT)
	box.add_child(_title)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.add_theme_font_size_override("normal_font_size", 20)
	_text.custom_minimum_size.x = 560.0
	box.add_child(_text)
	_list_scroll = ScrollContainer.new()
	_list_scroll.custom_minimum_size = Vector2(560.0, 460.0)
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_list_scroll)
	_list = RichTextLabel.new()
	_list.bbcode_enabled = true
	_list.fit_content = true
	_list.scroll_active = false
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_font_size_override("normal_font_size", 18)
	_list_scroll.add_child(_list)
	_ok = CampPlanner._button(box, "Got it", _next)
	CampPlanner.style_fight_button(_ok, 24)


## Shows these tips one after another (tip@1 Dictionaries), each waiting for Got it. Nothing when there are none.
func show_tips(tips: Array[Dictionary]) -> void:
	_queue.append_array(tips)
	if not visible:
		_next()


## The Coach's Notebook: every tip in `tips`, to read again.
func show_notebook(tips: Array[Dictionary]) -> void:
	_queue.clear()
	_counter.text = "COACH'S NOTEBOOK"
	_title.text = "What you've learned"
	_text.visible = false
	_list_scroll.visible = true
	var lines: Array[String] = []
	for t: Dictionary in tips:
		lines.append("[b][color=#%s]%s[/color][/b]\n%s" % [ACCENT.to_html(false), String(t.get("title", "")), String(t.get("text", ""))])
	_list.text = "\n\n".join(lines) if not lines.is_empty() else "[color=#8a8f98]No tips yet.[/color]"
	_ok.text = "Close"
	visible = true
	_list_scroll.scroll_vertical = 0
	FightHud.focus_later(_ok)


func _next() -> void:
	if _queue.is_empty():
		visible = false
		closed.emit()
		return
	var t: Dictionary = _queue.pop_front()
	_counter.text = "COACH'S TIP" + (" · %d more" % _queue.size() if not _queue.is_empty() else "")
	_title.text = String(t.get("title", ""))
	_text.text = String(t.get("text", ""))
	_text.visible = true
	_list_scroll.visible = false
	_ok.text = "Got it"
	visible = true
	FightHud.focus_later(_ok)


## For tests: what the card says, and pressing its button.
func text() -> String:
	return "%s\n%s\n%s\n%s" % [_counter.text, _title.text, _text.get_parsed_text() if _text.visible else "", _list.get_parsed_text() if _list_scroll.visible else ""]


func press_ok() -> void:
	_ok.pressed.emit()


func waiting() -> int:
	return _queue.size() + (1 if visible else 0)
