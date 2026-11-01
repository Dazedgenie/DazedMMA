class_name Gameplan
extends DecisionSource
## The pre-fight plan (docs/01 §6.0 layer 1, §42): it never picks an action itself, it
## multiplies the AI's weights and shifts its style leanings. A plan is built from three
## parts (D320), each a file in data/gameplans/ (docs/09 gameplan@2) or left as his own game:
##   approach  how he fights: Pressure, Counter, Range, Conserve
##   target    where his strikes go: Head, Body, Legs
##   where     where he wants the fight: Keep it standing, Clinch work, Take him down
## The corner sets it before the fight and can change it at every round break
## (FightCommand.SET_GAMEPLAN). A focus call (Pressure!, Circle out! …, LiveCalls) tilts the
## fighter the same way for a while, on top of the plan.
##
## He doesn't always stick to it (D323): hurt, gassed or losing badly, the plan's pull drops
## for a fighter with a low Fight IQ or a big ego, and coach trust holds him to it.

const DEFAULT_DIR := "res://data/gameplans/"
const APPROACH := "approach"
const TARGET := "target"
const WHERE := "where"
## The three parts in the order a plan is written and shown.
const PARTS: Array[String] = [APPROACH, TARGET, WHERE]
## What a part left empty is called on the screens.
const OWN_GAME := "Own game"

## How much of the plan's pull is left when he's under pressure (hurt, gassed, losing),
## before Fight IQ, ego and trust (D323): stick = clamp(BASE + IQ × PER_IQ + trust bonus − ego × PER_EGO).
const STICK_BASE: float = 0.35
const STICK_PER_IQ: float = 0.006  # Fight IQ 100 adds 0.6
const STICK_PER_TRUST: float = 0.002  # trust 100 adds 0.1, trust 0 takes 0.1 off (around the 50 start)
const STICK_PER_EGO: float = 0.003  # ego 100 takes 0.3 off
const STICK_MIN: float = 0.2
## Under pressure: head or body at least this hurt (0–1, FighterState.hurt), stamina under
## this share, rocked, or taking at least LOSING_RATIO times what he lands (with LOSING_MIN landed on him).
const PRESSURE_HURT: float = 0.5
const PRESSURE_STAMINA: float = 0.25
const LOSING_RATIO: float = 2.0
const LOSING_MIN: int = 15
## A plan pulls a leaning this far at most (D321): it never pushes a fighter who already leans
## that way out to the ±100 extremes (a Kicker at Range −60 on the Range plan stops at −70, and
## −100 would stop him throwing anything but the jab), and a fighter already past it stays where he is.
const LEANING_CAP: float = 70.0
## How hard a built plan pulls (D322): its leanings × this, its multipliers to this power.
const STRENGTH: float = 0.5

## action id or category → weight multiplier, e.g. { "takedown": 2.0, "head_kick": 0.5 }.
## An action id beats its category.
var bias: Dictionary
## Style leaning → points added for this fight, e.g. { "pace": 40, "range": 30 }.
var leanings: Dictionary
## Strike target (head, body, legs) → weight multiplier for strikes that land there, on top of `bias`.
var targets: Dictionary
## The part ids this plan was built from: {approach, target, where} ("" = his own game).
var parts: Dictionary = {}
## The plan in words for the screens ("Pressure · Legs", Gameplan.describe), set when it's built.
var label: String = OWN_GAME
## Whether he can drift off it when under pressure (D323). Off for a plan built in code.
var drifts: bool = false
## His corner's calls, for the coach trust that holds him to the plan (DecisionLayer.set_gameplan sets it).
var corner: LiveCalls

var _stick: float = 1.0
var _stick_at: int = -1  # The tick the stick was last worked out (once a tick at most).


func _init(p_bias: Dictionary = {}, p_leanings: Dictionary = {}, p_targets: Dictionary = {}) -> void:
	layer = DecisionLayer.GAMEPLAN
	may_claim = false
	bias = p_bias
	leanings = p_leanings
	targets = p_targets


## One file from data/gameplans (e.g. "pressure"), as a plan of its own.
static func load_id(id: String, dir_path: String = DEFAULT_DIR) -> Gameplan:
	var data: Dictionary = read(id, dir_path)
	var plan := Gameplan.new(data.get("weights", {}), data.get("leanings", {}), data.get("targets", {}))
	plan.parts = { String(data.get("part", APPROACH)): id }
	return plan


## A file from data/gameplans as data.
static func read(id: String, dir_path: String = DEFAULT_DIR) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir_path.path_join(id + ".json")))
	assert(data is Dictionary, "no gameplan '%s' in %s" % [id, dir_path])
	return data


## A plan built from its parts ({approach, target, where} → data/gameplans id, "" or missing
## = his own game): the leanings add up and the multipliers multiply. Empty when every part is.
static func compose(p_parts: Dictionary, dir_path: String = DEFAULT_DIR) -> Gameplan:
	var plan := Gameplan.new({}, {}, {})
	plan.drifts = true
	for part: String in PARTS:
		var id: String = String(p_parts.get(part, ""))
		plan.parts[part] = id
		if id == "":
			continue
		var data: Dictionary = read(id, dir_path)
		assert(String(data.get("part", "")) == part, "gameplan '%s' is a %s, not a %s" % [id, data.get("part", "?"), part])
		for k: String in data.get("leanings", {}):
			plan.leanings[k] = float(plan.leanings.get(k, 0.0)) + float(data.leanings[k])
		for k: String in data.get("weights", {}):
			plan.bias[k] = float(plan.bias.get(k, 1.0)) * float(data.weights[k])
		for k: String in data.get("targets", {}):
			plan.targets[k] = float(plan.targets.get(k, 1.0)) * float(data.targets[k])
	plan.label = describe(plan.parts, dir_path)
	return plan


## Why a set_gameplan command's parts can't be used, or "" (FightSim._reject_reason).
static func check(p_parts: Dictionary, dir_path: String = DEFAULT_DIR) -> String:
	for part: String in PARTS:
		var id: String = String(p_parts.get(part, ""))
		if id == "":
			continue
		if not FileAccess.file_exists(dir_path.path_join(id + ".json")):
			return "no gameplan '%s'" % id
		if String(read(id, dir_path).get("part", "")) != part:
			return "'%s' isn't a %s" % [id, part]
	return ""


## Every file of one part ("approach", "target", "where"), as [[id, name], …] in file order.
static func options(part: String, dir_path: String = DEFAULT_DIR) -> Array:
	var out: Array = []
	var files: Array = Array(DirAccess.get_files_at(dir_path)).filter(func(f: String) -> bool: return f.ends_with(".json"))
	files.sort()
	for file: String in files:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir_path.path_join(file)))
		if data is Dictionary and String(data.get("part", "")) == part:
			out.append([String(data.id), String(data.name)])
	out.sort_custom(func(a: Array, b: Array) -> bool: return _order(a[0], dir_path) < _order(b[0], dir_path))
	return out


static func _order(id: String, dir_path: String) -> float:
	return float(read(id, dir_path).get("order", 0.0))


## A plan's parts as a line: "Pressure · Legs · Take him down", or "Own game".
static func describe(p_parts: Dictionary, dir_path: String = DEFAULT_DIR) -> String:
	var names: Array[String] = []
	for part: String in PARTS:
		var id: String = String(p_parts.get(part, ""))
		if id != "":
			names.append(String(read(id, dir_path).name))
	return OWN_GAME if names.is_empty() else " · ".join(names)


## True when every part is his own game.
func is_empty() -> bool:
	return bias.is_empty() and leanings.is_empty() and targets.is_empty()


func adjust_weight(view: FightView, action: Dictionary, weight: float) -> float:
	var m: float = float(bias.get(action.id, bias.get(action.category, 1.0))) if not bias.is_empty() else 1.0
	if not targets.is_empty() and action.has("strike"):
		m *= float(targets.get(String(action.strike.get("target", "")), 1.0))
	if m == 1.0:
		return weight
	var s: float = stick(view) * (STRENGTH if drifts else 1.0)
	return weight * (m if s == 1.0 else pow(m, s))


func adjust_leaning(view: FightView, which: String, value: float) -> float:
	if not leanings.has(which):
		return value
	var amount: float = float(leanings[which]) * stick(view) * (STRENGTH if drifts else 1.0)
	if not drifts:
		return value + amount  # A plan built in code (tests, LiveCalls-style tilts): no cap.
	if amount > 0.0:
		return maxf(value, minf(value + amount, LEANING_CAP))
	return minf(value, maxf(value + amount, -LEANING_CAP))


## The plan's pull as last worked out (1 = all of it): the HUD says when he's drifting off it.
func last_stick() -> float:
	return _stick


## How much of the plan's pull he's keeping right now, 0–1 (D323): all of it unless he's
## hurt, gassed or losing badly; then it depends on his Fight IQ, ego and how much he trusts the corner.
func stick(view: FightView) -> float:
	if not drifts or view == null:
		return 1.0
	if view.now == _stick_at:
		return _stick
	_stick_at = view.now
	_stick = 1.0
	if under_pressure(view.me, view.opponent):
		_stick = holds_it(view.me, corner.trust if corner != null else LiveCalls.TRUST_START)
	return _stick


## How much of the plan a fighter keeps when it's going badly (D323).
static func holds_it(f: FighterState, trust: float = 50.0) -> float:
	var ego: float = float(f.profile.get("personality", {}).get("ego", 0))
	var s: float = STICK_BASE + STICK_PER_IQ * f.stat("fight_iq") + STICK_PER_TRUST * (trust - 50.0) - STICK_PER_EGO * ego
	return clampf(s, STICK_MIN, 1.0)


## Hurt, gassed or losing badly: when a fighter may drift off the plan (D323).
static func under_pressure(me: FighterState, opp: FighterState) -> bool:
	if me.is_rocked() or me.stamina_fraction() < PRESSURE_STAMINA:
		return true
	if me.hurt("head") >= PRESSURE_HURT or me.hurt("body") >= PRESSURE_HURT:
		return true
	return opp.strikes_landed >= LOSING_MIN and float(opp.strikes_landed) >= LOSING_RATIO * float(maxi(1, me.strikes_landed))


## A weight × the table's multiplier for this action (its id first, then its category).
static func scale_weight(table: Dictionary, action: Dictionary, weight: float) -> float:
	if table.is_empty():
		return weight
	return weight * float(table.get(action.id, table.get(action.category, 1.0)))
