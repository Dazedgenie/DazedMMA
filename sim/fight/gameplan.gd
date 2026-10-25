class_name Gameplan
extends DecisionSource
## The pre-fight plan (docs/01 §6.0 layer 1): it never picks an action itself, it
## multiplies the AI's weights and shifts its style leanings. The presets (Pressure,
## Counter, Range, Wrestle-heavy, Conserve) are data/gameplans/*.json (docs/09 gameplan@1).
## A focus call (Pressure!, Circle out! …, LiveCalls) tilts the fighter the same way for a while.

const DEFAULT_DIR := "res://data/gameplans/"

## action id or category → weight multiplier, e.g. { "takedown": 2.0, "head_kick": 0.5 }.
## An action id beats its category.
var bias: Dictionary
## Style leaning → points added for this fight, e.g. { "pace": 40, "range": 30 }.
var leanings: Dictionary


func _init(p_bias: Dictionary = {}, p_leanings: Dictionary = {}) -> void:
	layer = DecisionLayer.GAMEPLAN
	may_claim = false
	bias = p_bias
	leanings = p_leanings


## A preset from data/gameplans (e.g. "pressure").
static func load_id(id: String, dir_path: String = DEFAULT_DIR) -> Gameplan:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir_path.path_join(id + ".json")))
	assert(data is Dictionary, "no gameplan '%s' in %s" % [id, dir_path])
	return Gameplan.new(data.get("weights", {}), data.get("leanings", {}))


func adjust_weight(_view: FightView, action: Dictionary, weight: float) -> float:
	return scale_weight(bias, action, weight)


func adjust_leaning(_view: FightView, which: String, value: float) -> float:
	return value + float(leanings.get(which, 0.0))


## A weight × the table's multiplier for this action (its id first, then its category).
static func scale_weight(table: Dictionary, action: Dictionary, weight: float) -> float:
	if table.is_empty():
		return weight
	return weight * float(table.get(action.id, table.get(action.category, 1.0)))
