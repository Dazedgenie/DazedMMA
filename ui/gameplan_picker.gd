class_name GameplanPicker
extends VBoxContainer
## The corner's gameplan as three pickers (D320, docs/01 §42): approach, target and where to
## fight, each "Own game" or one of its files in data/gameplans/, with what the plan says
## under them. The fight setup, the between-rounds panel and the career's fight night card show it.

const DIM := Color("#adb5bd")
const PART_NAMES := { Gameplan.APPROACH: "Approach", Gameplan.TARGET: "Target", Gameplan.WHERE: "Where" }

signal changed

var _pickers: Dictionary = {}  # part → OptionButton
var _ids: Dictionary = {}  # part → [id, …] in picker order after "Own game"
var _about: Label
var _compact: bool


## `compact`: the title sits in the pickers' row and what the plan says is one line (the crowded fight setup).
func _init(title: String = "Gameplan", compact: bool = false) -> void:
	_compact = compact
	add_theme_constant_override("separation", 4)
	var row := HFlowContainer.new()
	if title != "":
		var heading := Label.new()
		heading.text = title
		heading.add_theme_color_override("font_color", DIM)
		(row if compact else self as Node).add_child(heading)
	add_child(row)
	for part: String in Gameplan.PARTS:
		var label := Label.new()
		label.text = PART_NAMES[part]
		row.add_child(label)
		var picker := OptionButton.new()
		picker.add_item(Gameplan.OWN_GAME)
		var ids: Array[String] = []
		for option: Array in Gameplan.options(part):
			ids.append(String(option[0]))
			picker.add_item(String(option[1]))
		picker.item_selected.connect(func(_i: int) -> void:
			_show_about()
			changed.emit())
		row.add_child(picker)
		_pickers[part] = picker
		_ids[part] = ids
	_about = Label.new()
	_about.autowrap_mode = TextServer.AUTOWRAP_OFF  # Short lines; a wrapping label in a dialog can end up 0 tall.
	_about.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_about.clip_text = compact
	_about.add_theme_color_override("font_color", DIM)
	add_child(_about)
	_show_about()


## The plan as picked: {approach, target, where} → data/gameplans id ("" = his own game).
func picked() -> Dictionary:
	var out: Dictionary = {}
	for part: String in Gameplan.PARTS:
		var at: int = _pickers[part].selected
		out[part] = _ids[part][at - 1] if at > 0 else ""
	return out


## Shows this plan ({part: id}; a part left out or "" is his own game).
func show_plan(parts: Dictionary) -> void:
	for part: String in Gameplan.PARTS:
		_pickers[part].selected = maxi(0, _ids[part].find(String(parts.get(part, ""))) + 1)
	_show_about()


## Picks one part by id ("" = own game): tests, and the camp's instruction filling it in.
func pick(part: String, id: String) -> void:
	_pickers[part].selected = maxi(0, _ids[part].find(id) + 1)
	_show_about()


## The plan in words, one line a part picked: "Pressure: walk him down…".
func text() -> String:
	return _about.text


func _show_about() -> void:
	_about.text = about(picked()).replace("\n", "  ·  ") if _compact else about(picked())
	_about.tooltip_text = about(picked())


## What a plan tells the fighter, a line a part, or that he'll fight his own way.
static func about(parts: Dictionary) -> String:
	var lines: Array[String] = []
	for part: String in Gameplan.PARTS:
		var id: String = String(parts.get(part, ""))
		if id != "":
			var data: Dictionary = Gameplan.read(id)
			lines.append("%s: %s" % [data.name, data.get("summary", "")])
	return "\n".join(lines) if not lines.is_empty() else "No plan: he fights his own way."


## What scouting says his corner will tell him (D324): "Expect his corner's plan: Pressure · Head".
static func expect_text(plan: Dictionary) -> String:
	return "Expect his corner's plan: %s" % Gameplan.describe(plan)
