class_name FighterState
extends RefCounted
## One fighter's live state inside FightSim.
##
## Fighters fight at their stats × their condition (docs/11-attributes-and-traits.md
## §3.2): effective_stat() lowers stats when tired, hurt in the head or legs, or
## panicking. The numbers below are first guesses for the balance harness (#18)
## to tune. Distance, knockdowns and the real damage model are the standing game (#13).

const DEFAULT_STAT: int = 50

## Stamina tank in points: 60 + 0.8 × Cardio (Cardio 50 → 100).
const TANK_BASE: float = 60.0
const TANK_PER_CARDIO: float = 0.8
## Refill per fight-second: 0.6 + 1.2 × Cardio / 100 (Cardio 50 → 1.2/s).
const REGEN_BASE: float = 0.6
const REGEN_PER_CARDIO: float = 1.2
## Share of missing stamina won back in the corner: 0.3 + Recovery / 200 (Recovery 50 → 55%).
const CORNER_BASE: float = 0.3
## Below half a tank, stats fall gradually, down to −30% when empty.
const TIRED_BELOW: float = 0.5
const MAX_TIRED_PENALTY: float = 0.3
## Damage that counts as fully hurt: 10 × (Chin + 50) for the head, 10 × (Durability + 50) for body and legs.
const HURT_SCALE: float = 10.0
const MAX_HURT_PENALTY: float = 0.3
## Body damage shrinks the tank, up to −30%.
const MAX_BODY_DRAIN: float = 0.3
## Panic when head hurt reaches 0.4 + Composure / 200 (Composure 50 → 65% hurt).
const PANIC_BASE: float = 0.4
const PANIC_DEFENSE_PENALTY: float = 0.2
const PANIC_POWER_BONUS: float = 0.15
const PANIC_WORK_RATE_BONUS: float = 0.2

## Capacities and mental stats aren't worn down by fatigue (docs/11 §3.2: "physical and technique stats").
const FATIGUE_EXEMPT: Array[String] = ["cardio", "recovery", "durability", "chin", "fight_iq", "composure", "heart"]
const HEAD_HURT_STATS: Array[String] = ["speed", "striking_defense", "fight_iq"]
const LEG_HURT_STATS: Array[String] = ["footwork", "speed", "kicking"]
const PANIC_DEFENSE_STATS: Array[String] = ["fight_iq", "striking_defense", "takedown_defense", "submission_defense"]

var name: String
var stats: Dictionary  # stat id → 0–100; missing stats count as DEFAULT_STAT
## Actions the placeholder AI picks from when nothing is queued.
var repertoire: Array[String]
## Chance per idle tick that the placeholder AI starts an action, before style and panic.
var work_rate: float
var style: StyleLeanings

var position: String = "standing"
var damage: Dictionary = { "head": 0, "body": 0, "legs": 0 }
var stamina: float
var strikes_landed: int = 0
var strikes_thrown: int = 0

var action_id: String = ""  # "" = free to act
var phase: String = ""
var phase_ticks_left: int = 0
var queued_action_id: String = ""


func _init(p_name: String, p_stats: Dictionary = {}, p_repertoire: Array[String] = ["jab"], p_work_rate: float = 0.08, p_style: StyleLeanings = null) -> void:
	name = p_name
	stats = p_stats
	repertoire = p_repertoire
	work_rate = p_work_rate
	style = p_style if p_style != null else StyleLeanings.new()
	stamina = max_stamina()


func is_free() -> bool:
	return action_id == ""


## The fighter's trained number, ignoring condition.
func stat(id: String) -> int:
	return int(stats.get(id, DEFAULT_STAT))


## The number they fight at right now: stat × condition.
func effective_stat(id: String) -> float:
	var value: float = stat(id)
	if id not in FATIGUE_EXEMPT:
		value *= 1.0 - tired()
	if id in HEAD_HURT_STATS:
		value *= 1.0 - MAX_HURT_PENALTY * hurt("head")
	if id in LEG_HURT_STATS:
		value *= 1.0 - MAX_HURT_PENALTY * hurt("legs")
	if is_panicking():
		if id in PANIC_DEFENSE_STATS:
			value *= 1.0 - PANIC_DEFENSE_PENALTY
		elif id == "power":
			value *= 1.0 + PANIC_POWER_BONUS
	return value


## Why effective_stat differs from stat, e.g. ["tired", "hurt"]. Empty when fresh.
func condition_reasons(id: String) -> Array[String]:
	var out: Array[String] = []
	if id not in FATIGUE_EXEMPT and tired() > 0.0:
		out.append("tired")
	if id in HEAD_HURT_STATS and hurt("head") > 0.0:
		out.append("hurt")
	if id in LEG_HURT_STATS and hurt("legs") > 0.0:
		out.append("legs hurt")
	if is_panicking() and (id in PANIC_DEFENSE_STATS or id == "power"):
		out.append("panicking")
	return out


func max_stamina() -> float:
	return (TANK_BASE + TANK_PER_CARDIO * stat("cardio")) * (1.0 - MAX_BODY_DRAIN * hurt("body"))


func stamina_fraction() -> float:
	return stamina / max_stamina()


## 0 at half a tank or more, rising to MAX_TIRED_PENALTY when empty.
func tired() -> float:
	var f: float = clampf(stamina_fraction(), 0.0, 1.0)
	if f >= TIRED_BELOW:
		return 0.0
	return MAX_TIRED_PENALTY * (TIRED_BELOW - f) / TIRED_BELOW


## 0 (fresh) to 1 (fully hurt) for "head", "body" or "legs".
func hurt(area: String) -> float:
	var toughness: float = stat("chin") if area == "head" else stat("durability")
	return clampf(damage[area] / (HURT_SCALE * (toughness + 50.0)), 0.0, 1.0)


## Composure broken: defense and Fight IQ drop, power and output go up (wild swings).
func is_panicking() -> bool:
	return hurt("head") >= PANIC_BASE + stat("composure") / 200.0


func spend_stamina(amount: float) -> void:
	stamina = maxf(stamina - amount, 0.0)


## One tick of breathing: Cardio decides how fast the tank refills.
func regen_tick() -> void:
	var per_second: float = REGEN_BASE + REGEN_PER_CARDIO * stat("cardio") / 100.0
	stamina = minf(stamina + per_second / FightClock.TICKS_PER_SECOND, max_stamina())


## The corner between rounds: Recovery decides how much of the missing tank comes back.
func recover_between_rounds() -> void:
	var missing: float = max_stamina() - stamina
	stamina = minf(stamina + missing * (CORNER_BASE + stat("recovery") / 200.0), max_stamina())


## Debug overlay text (docs/11 §3.2), e.g. "Boxing 70 → 52 (tired, hurt)".
func describe_stat(id: String) -> String:
	var label: String = id.capitalize().replace("Iq", "IQ")
	var effective: int = roundi(effective_stat(id))
	if effective == stat(id):
		return "%s %d" % [label, stat(id)]
	return "%s %d → %d (%s)" % [label, stat(id), effective, ", ".join(condition_reasons(id))]


func clear_action() -> void:
	action_id = ""
	phase = ""
	phase_ticks_left = 0
