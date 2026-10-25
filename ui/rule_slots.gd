class_name RuleSlots
extends HFlowContainer
## The two drilled-rule slots and the Drilled slider (docs/01 §23), as the fight
## setup and the between-rounds panel show them. Only rules whose move the fighter
## knows are offered (the Kicker never learned the catch, D112).

var _pickers: Array[OptionButton] = []
var _drilled: HSlider
var _drilled_label: Label
var _ids: Array[String] = []


func _init(fighter_profile: Dictionary = {}, actions: ActionLibrary = null) -> void:
	var library: RuleLibrary = RuleLibrary.shared()
	var techniques: Array = fighter_profile.get("techniques", [])
	for id in library.ids():
		var move: String = String(library.get_rule(id).action)
		var basic: bool = actions != null and actions.has(move) and actions.get_action(move).get("basic", false)
		if fighter_profile.is_empty() or basic or techniques.has(move):
			_ids.append(id)
	for slot in DrilledRules.MAX_SLOTS:
		var label := Label.new()
		label.text = "Rule %d" % (slot + 1)
		add_child(label)
		var picker := OptionButton.new()
		picker.add_item("none")
		for id in _ids:
			picker.add_item(String(library.get_rule(id).name))
		add_child(picker)
		_pickers.append(picker)
	_drilled_label = Label.new()
	add_child(_drilled_label)
	_drilled = HSlider.new()
	_drilled.min_value = 0.0
	_drilled.max_value = 100.0
	_drilled.step = 5.0
	_drilled.value = 80.0
	_drilled.custom_minimum_size = Vector2(160.0, 0.0)
	_drilled.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_drilled.value_changed.connect(func(_v: float) -> void: _show_drilled())
	add_child(_drilled)
	_show_drilled()


## The rules as picked: [slot (1 or 2), rule id ("" = empty), drilled 0–100] for each slot.
func picked() -> Array:
	var out: Array = []
	for slot in _pickers.size():
		var at: int = _pickers[slot].selected
		out.append([slot + 1, _ids[at - 1] if at > 0 else "", _drilled.value])
	return out


## Shows these rules ([[slot, rule id, drilled], …], as picked() gives them).
func show_rules(rules: Array) -> void:
	for entry: Array in rules:
		var slot: int = int(entry[0]) - 1
		if slot >= 0 and slot < _pickers.size():
			_pickers[slot].selected = maxi(0, _ids.find(String(entry[1])) + 1)
		if String(entry[1]) != "":
			_drilled.value = float(entry[2])


## Picks the rule in a slot by id (tests, and remembering the last fight's rules).
func pick(slot: int, rule_id: String) -> void:
	_pickers[slot - 1].selected = _ids.find(rule_id) + 1


func set_drilled(value: float) -> void:
	_drilled.value = value


func _show_drilled() -> void:
	_drilled_label.text = "Drilled %d%%" % roundi(_drilled.value)
