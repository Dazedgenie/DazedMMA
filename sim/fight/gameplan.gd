class_name Gameplan
extends DecisionSource
## The pre-fight plan (docs/01 §6.0 layer 1): it never picks an action itself, it
## multiplies the AI's weights. Presets (Pressure, Counter, Range, Wrestle-heavy,
## Conserve) arrive with the AI (#14); for now a plan is a table of multipliers.

## action id or category → weight multiplier, e.g. { "takedown": 2.0, "head_kick": 0.5 }.
## An action id beats its category.
var bias: Dictionary


func _init(p_bias: Dictionary = {}) -> void:
	layer = DecisionLayer.GAMEPLAN
	bias = p_bias


func adjust_weight(_view: FightView, action: Dictionary, weight: float) -> float:
	return weight * float(bias.get(action.id, bias.get(action.category, 1.0)))
