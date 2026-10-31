class_name LoadScreen
extends PanelContainer
## Load career (docs/03 §10.2, D302): the three save slots (CareerSaves, D301) side by side, each with the fighter's
## name, age, record, the career's date and when it was saved; Load, and Delete (pressed twice, since it can't be
## undone). A slot that only its backup could read says so.

signal load_pressed(slot: int)
signal back_pressed

const BACKGROUND := Color(0.06, 0.07, 0.09)
const CARD := Color("#1b1f26")
const RED_CORNER := Color("#ff6b6b")
const TEXT := Color("#e9ecef")
const DIM := Color("#8a8f98")
const WARN := Color("#fcc419")
const SLOT_W: float = 380.0
const DELETE_SURE := "Really delete? Press again"

var save_dir: String = CareerSaves.DIR

var _slots: Array[Dictionary] = []  # per slot: { info, text (Label), load (Button), delete (Button) }
var _back: Button


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override("panel", FightHud._panel_style(BACKGROUND))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	add_child(column)
	var title := Label.new()
	title.text = "LOAD CAREER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	DisplayFont.apply(title, 64)
	title.add_theme_color_override("font_color", RED_CORNER)
	column.add_child(title)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	for slot in CareerSaves.SLOTS:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(SLOT_W, 300.0)
		var style: StyleBoxFlat = FightHud._panel_style(CARD)
		style.set_content_margin_all(22)
		card.add_theme_stylebox_override("panel", style)
		row.add_child(card)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 10)
		card.add_child(box)
		var heading := FightNightCard._label(20, DIM)
		DisplayFont.apply(heading, 20)
		heading.text = "SLOT %d" % (slot + 1)
		box.add_child(heading)
		var label := RichTextLabel.new()
		label.bbcode_enabled = true
		label.fit_content = true
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("normal_font_size", 18)
		label.add_theme_color_override("default_color", TEXT)
		box.add_child(label)
		var load_button: Button = CampPlanner._button(box, "Load", func() -> void: load_pressed.emit(slot))
		var delete_button: Button = CampPlanner._button(box, "Delete", func() -> void: _delete(slot))
		_slots.append({ "info": {}, "text": label, "load": load_button, "delete": delete_button })

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	_back = CampPlanner._button(buttons, "Back", func() -> void: back_pressed.emit())
	_back.custom_minimum_size.x = 220.0


## Reads every slot again.
func refresh() -> void:
	for slot in CareerSaves.SLOTS:
		var entry: Dictionary = _slots[slot]
		entry.info = CareerSaves.info(slot, save_dir)
		(entry.text as RichTextLabel).text = slot_text(entry.info)
		(entry.load as Button).disabled = entry.info.is_empty()
		(entry.delete as Button).visible = not entry.info.is_empty()
		(entry.delete as Button).text = "Delete"


func focus_first() -> void:
	for entry in _slots:
		if not (entry.load as Button).disabled:
			FightHud.focus_later(entry.load as Button)
			return
	FightHud.focus_later(_back)


## What a slot's card says, from CareerSaves.info().
static func slot_text(slot_info: Dictionary) -> String:
	if slot_info.is_empty():
		return "[color=%s]Empty[/color]" % DIM.to_html(false)
	var lines: Array[String] = []
	lines.append("[font_size=30][b]%s[/b][/font_size]" % String(slot_info.get("name", "")))
	if String(slot_info.get("nickname", "")) != "":
		lines.append("'%s'" % slot_info.nickname)
	lines.append("Age %d · %s" % [int(slot_info.get("age", 0)), String(slot_info.get("date", ""))])
	var record: String = "Pro %s" % slot_info.get("pro_record", "") if bool(slot_info.get("pro", false)) else "Amateur %s" % slot_info.get("amateur_record", "")
	lines.append(record)
	lines.append("[color=%s]Coach %s[/color]" % [DIM.to_html(false), String(slot_info.get("coach", ""))])
	lines.append("[color=%s]Saved %s[/color]" % [DIM.to_html(false), saved_text(String(slot_info.get("saved_at", "")))])
	if bool(slot_info.get("backup", false)):
		lines.append("[color=%s]The last save was damaged: this is the one before it.[/color]" % WARN.to_html(false))
	return "\n".join(lines)


## "2026-10-31T19:04:00" (as CareerSaves writes it, UTC) as "31 Oct 2026, 19:04 UTC".
static func saved_text(iso: String) -> String:
	var parts: PackedStringArray = iso.split("T")
	var day: PackedStringArray = parts[0].split("-")
	if day.size() != 3:
		return iso
	var time: String = parts[1].substr(0, 5) if parts.size() > 1 else ""
	return "%d %s %s%s" % [int(day[2]), Career.MONTHS[clampi(int(day[1]) - 1, 0, 11)], day[0], (", %s UTC" % time) if time != "" else ""]


func text() -> String:
	var out: Array[String] = []
	for entry in _slots:
		out.append((entry.text as RichTextLabel).get_parsed_text())
	return "\n---\n".join(out)


## Delete asks once: the first press turns the button into DELETE_SURE, the second deletes.
func _delete(slot: int) -> void:
	var button: Button = _slots[slot].delete
	if button.text != DELETE_SURE:
		button.text = DELETE_SURE
		return
	CareerSaves.delete(slot, save_dir)
	refresh()


## For tests: presses a slot's Delete button.
func press_delete(slot: int) -> void:
	_delete(slot)
