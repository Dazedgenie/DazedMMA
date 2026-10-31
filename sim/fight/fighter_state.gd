class_name FighterState
extends RefCounted
## One fighter's live state inside FightSim.
##
## Fighters fight at their stats × their condition (docs/11-attributes-and-traits.md
## §3.2): effective_stat() lowers stats when tired, hurt in the head or legs, or
## panicking, and much harder while rocked. The numbers below are first guesses
## for the balance harness (#18) to tune.

const DEFAULT_STAT: int = 50
## Chance per free tick to lead with something (FighterAI.lead_rate): about one lead
## every 7 s, with combinations, counters and meeting advances on top.
const DEFAULT_WORK_RATE: float = 0.015

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
## Rocked (docs/01 §8: wobbly, huge counter vulnerability): Speed, Striking defense and Fight IQ a further −30%.
const ROCKED_PENALTY: float = 0.3

## Reaction time inside a primed read or a drilled rule (D93): 3 ticks at Speed 0,
## 2 at Speed 50, 1 at Speed 100, stretched by fatigue (up to +30%).
const REACTION_TICKS_AT_ZERO: float = 3.0
const REACTION_TICKS_PER_SPEED: float = 0.02

## Capacities and mental stats aren't worn down by fatigue (docs/11 §3.2: "physical and technique stats").
## Sets (stat id → true): effective_stat runs thousands of times a fight.
const FATIGUE_EXEMPT := { "cardio": true, "recovery": true, "durability": true, "chin": true, "fight_iq": true, "composure": true, "heart": true }
const HEAD_HURT_STATS := { "speed": true, "striking_defense": true, "fight_iq": true }
const LEG_HURT_STATS := { "footwork": true, "cage_cutting": true, "speed": true, "kicking": true }
## The two legs (D144): each is fully hurt at this share of the legs' damage scale (one leg kicked
## to pieces is a leg gone while the other is fresh). A buckled leg leaves him limping: these stats
## a further LIMP_PENALTY down (slower, weaker kicks, easier to take down).
const LEG_SHARE: float = 0.3
const LIMP_STATS := { "footwork": true, "cage_cutting": true, "speed": true, "kicking": true, "takedown_defense": true }
const LIMP_PENALTY: float = 0.2
const LEFT_LEG: int = 0
const RIGHT_LEG: int = 1
## Primed read calls take attention from the rest of the defense (docs/01 §6.1, D67).
const ATTENTION_STATS := { "striking_defense": true, "takedown_defense": true }
const PANIC_DEFENSE_STATS := { "fight_iq": true, "striking_defense": true, "takedown_defense": true, "submission_defense": true }

## The data/fighters id this fighter was made from ("" when built in code, e.g. in tests).
var id: String = ""
var name: String
var stats: Dictionary  # stat id → 0–100; missing stats count as DEFAULT_STAT
## Actions the AI picks from when nothing is queued (the profile's `techniques`).
var repertoire: Array[String]
## Chance per free tick that the AI leads with something, before style and the moment
## (FighterAI.lead_rate). 0 = never starts anything on their own.
var work_rate: float
## action id → how much more (or less) this fighter likes it than usual (1.0 = normal, docs/01 §7).
var tendencies: Dictionary = {}
var style: StyleLeanings
## Habits an opponent can scout (docs/01 §7, D11): [{trigger, action, chance, within_ms}].
## After the trigger, `chance` to throw `action` within `within_ms`. The AI follows them (#14).
var tells: Array = []
## Combinations this fighter has drilled (data/combos ids, the profile's `combos`, D133).
var combos: Array[String] = []
## The rest of the profile (docs/09 fighter@1): frame, stance, personality, gifts and
## flaws. Kept for the world and saves; the fight doesn't read them yet.
var profile: Dictionary = {}

## Where they stand in the cage, in metres from the centre (Octagon).
var pos: Vector2 = Vector2.ZERO
var damage: Dictionary = { "head": 0, "body": 0, "legs": 0 }
## The legs' damage by leg (D144), [left, right]: `damage.legs` is the two together. Low kicks land
## on the front leg (lead_leg()), so switching stance puts the other one in the way.
var leg_damage: Array[int] = [0, 0]
## Switched stance from his profile's (to hide a hurt front leg, D144).
var switched: bool = false
## The leg that buckled (LEFT_LEG or RIGHT_LEG), or -1: he limps on it for the rest of the fight.
var limping: int = -1
## Ticks left rocked, and ticks left on the canvas after a knockdown.
var rocked_ticks: int = 0
var down_ticks: int = 0
## A liver shot (D143): ticks until it takes him (he freezes, then folds), and ticks left
## winded after he's back up, guarding the body with his hands low.
var liver_ticks: int = 0
var liver_by: int = -1
var winded_ticks: int = 0
## Ticks left flinching from a clean shot: the feet stop (FightSim.STAGGER_*).
var stagger_ticks: int = 0
## Ticks left with their posture broken: tied up from the bottom, so no ground strikes (D121).
var tied_up_ticks: int = 0
## Clean head shots taken while rocked without answering (landing anything back):
## the referee steps in at FightSim.STOP_UNANSWERED (D120).
var unanswered: int = 0
var knockdowns: int = 0  # suffered this fight
var knockdowns_this_round: int = 0
var stamina: float
var strikes_landed: int = 0
var strikes_thrown: int = 0
var takedowns_tried: int = 0
var takedowns_landed: int = 0
## Submissions this fighter went for, and the ones that locked in (D126).
var subs_tried: int = 0
var subs_locked: int = 0
## Of those, the leg locks (the ankle lock, kneebar and heel hook, D132).
var leg_locks_tried: int = 0
var leg_locks_locked: int = 0
## Throws and trips this fighter went for, and the ones that put the opponent down (D128).
## They count as takedowns too.
var throws_tried: int = 0
var throws_landed: int = 0
## Collar ties this fighter went for and won, and knees they landed in the clinch, and how
## many of those went to the head from a collar tie (D129).
var collar_ties_tried: int = 0
var collar_ties_won: int = 0
var clinch_knees_landed: int = 0
var tied_knees_landed: int = 0
## The cage clinch (D220): drives to the fence this fighter went for and won, and spin-offs and
## turns (getting the other man's back onto the fence) went for and won.
var fence_drives_tried: int = 0
var fence_drives_won: int = 0
var spin_offs_tried: int = 0
var spin_offs_won: int = 0
## Grips in the clinch (D261): pummels (swimming an arm inside for an underhook) and strips (taking
## one of his underhooks off) this fighter went for and won.
var pummels_tried: int = 0
var pummels_won: int = 0
var strips_tried: int = 0
var strips_won: int = 0
## Turns on the fence (D262): turning him onto the fence (not the spin-off and away), went for and won.
var turns_tried: int = 0
var turns_won: int = 0
## Times this fighter moved to a better position on top (a pass, the mount, the back) and got
## out from underneath (back to guard, up, a reversal) (D130).
var advances: int = 0
var escapes: int = 0
## Feints thrown and how many the opponent bit on; takedowns shot blind (nothing set them
## up) and how many of those still worked (D131).
var feints_tried: int = 0
var feints_bit: int = 0
var blind_shots: int = 0
var blind_landed: int = 0
## Combinations thrown (counted as their second move starts), the strikes after the first in
## them, and how many of those landed (D133).
var combos_thrown: int = 0
var combo_strikes: int = 0
var combo_landed: int = 0

var action_id: String = ""  # "" = free to act
var phase: String = ""
var phase_ticks_left: int = 0
var queued_action_id: String = ""
## A takedown, clinch or ground move that has made contact: its odds, locked in when its
## active phase starts and rolled when it ends (FightSim, #15). null otherwise.
var grip: OddsBreakdown = null
## Sprawled on: stuck under the sprawl, head low, for the rest of this move's recovery.
var sprawled: bool = false
## Bit on a feint (D131): hands up and weight back for this many more ticks (BIT_ON_FEINT).
var bit_ticks: int = 0
## Slipped a punch (D180): his strikes up to this tick come off the slip (FightSim.SLIP_COUNTER_BONUS).
var slip_counter_until: int = -1
## Set up (D131): this fighter's last strike or feint ended recently enough that a shot
## started up to this tick isn't blind.
var set_up_until: int = -1
## The takedown under way was started blind (D131): no feint or strike just before it, no
## opening, standing. BLIND_SHOT for the rest of the move.
var blind_shot: bool = false
## The combination the current (or last) move is part of ("" for none) and which move of it
## this is (0 = the first), set as each move starts (D133).
var combo_id: String = ""
var combo_step: int = 0
## It runs to its end on its own (called or commanded as a whole, Decision.combo_runs).
var combo_runs: bool = false
## The combination has moves left: the next one is due by this tick (−1 = nothing due).
var combo_next_until: int = -1
## A combination queued from outside with queued_action_id (its first move), or "".
var queued_combo: String = ""
## Share of Striking and Takedown defense the primed read calls take away (0 = none, LiveCalls).
var attention: float = 0.0
## How much of the gas tank a camp left them (docs/02 §3.7, D135): 1 fresh, less when they come in tired.
var tank_share: float = 1.0


func _init(p_name: String, p_stats: Dictionary = {}, p_repertoire: Array[String] = ["jab"], p_work_rate: float = DEFAULT_WORK_RATE, p_style: StyleLeanings = null) -> void:
	name = p_name
	stats = p_stats
	repertoire = p_repertoire
	work_rate = p_work_rate
	style = p_style if p_style != null else StyleLeanings.new()
	stamina = max_stamina()


## Builds a fighter from a fighter@1 profile (FighterLibrary.profile fills in its template).
static func from_profile(p: Dictionary) -> FighterState:
	var reps: Array[String] = []
	reps.assign(p.get("techniques", []))
	var tend: Dictionary = p.get("tendencies", {})
	# A trained fighter keeps fractions of a point (docs/02 §3.5); fights read the nearest whole point.
	var whole: Dictionary = {}
	for id: String in p.get("stats", {}):
		whole[id] = float(roundi(float(p.stats[id])))
	var f := FighterState.new(p.name, whole, reps, float(tend.get("work_rate", DEFAULT_WORK_RATE)), StyleLeanings.new(p.get("style", {})))
	f.id = p.get("id", "")
	f.tendencies = tend.get("actions", {}).duplicate()
	f.tells = p.get("tells", []).duplicate(true)
	f.combos.assign(p.get("combos", []))
	f.profile = p
	if p.get("condition") is Dictionary:
		f.start_condition(p.condition)
	return f


## How a training camp sends the fighter in (fighter@1 `condition`, docs/02 §3.7, D135): `tank` is the share of
## the gas tank they have all fight (a tired camp shrinks it), `hurt` how hurt an area already is (0–1, as hurt() reads it).
func start_condition(condition: Dictionary) -> void:
	tank_share = clampf(float(condition.get("tank", 1.0)), 0.0, 1.0)
	var start_hurt: Dictionary = condition.get("hurt", {})
	for area: String in start_hurt:
		var toughness: float = int(stats.get("chin" if area == "head" else "durability", DEFAULT_STAT))
		damage[area] = roundi(clampf(float(start_hurt[area]), 0.0, 1.0) * HURT_SCALE * (toughness + 50.0))
	stamina = max_stamina()


func is_free() -> bool:
	return action_id == ""


## The fighter's trained number, ignoring condition.
func stat(id: String) -> int:
	return int(stats.get(id, DEFAULT_STAT))


## The number they fight at right now: stat × condition. This and the stamina
## maths run tens of thousands of times a fight, so they read `stats` directly
## and work head hurt out once (is_panicking() is the same test).
func effective_stat(id: String) -> float:
	var value: float = int(stats.get(id, DEFAULT_STAT))
	if not FATIGUE_EXEMPT.has(id):
		value *= 1.0 - tired()
	var head: float = -1.0
	if HEAD_HURT_STATS.has(id):
		head = hurt("head")
		value *= 1.0 - MAX_HURT_PENALTY * head
		if rocked_ticks > 0:
			value *= 1.0 - ROCKED_PENALTY
	if LEG_HURT_STATS.has(id):
		value *= 1.0 - MAX_HURT_PENALTY * hurt("legs")
	if limping >= 0 and LIMP_STATS.has(id):
		value *= 1.0 - LIMP_PENALTY
	if attention > 0.0 and ATTENTION_STATS.has(id):
		value *= 1.0 - attention
	var defense: bool = PANIC_DEFENSE_STATS.has(id)
	if defense or id == "power":
		if head < 0.0:
			head = hurt("head")
		if head >= PANIC_BASE + int(stats.get("composure", DEFAULT_STAT)) / 200.0:
			value *= (1.0 - PANIC_DEFENSE_PENALTY) if defense else (1.0 + PANIC_POWER_BONUS)
	return value


## Why effective_stat differs from stat, e.g. ["tired", "hurt"]. Empty when fresh.
func condition_reasons(id: String) -> Array[String]:
	var out: Array[String] = []
	if id not in FATIGUE_EXEMPT and tired() > 0.0:
		out.append("tired")
	if id in HEAD_HURT_STATS and hurt("head") > 0.0:
		out.append("hurt")
	if id in HEAD_HURT_STATS and is_rocked():
		out.append("rocked")
	if id in LEG_HURT_STATS and hurt("legs") > 0.0:
		out.append("legs hurt")
	if limping >= 0 and id in LIMP_STATS:
		out.append("limping")
	if attention > 0.0 and id in ATTENTION_STATS:
		out.append("watching for a read")
	if is_panicking() and (id in PANIC_DEFENSE_STATS or id == "power"):
		out.append("panicking")
	return out


func max_stamina() -> float:
	return (TANK_BASE + TANK_PER_CARDIO * int(stats.get("cardio", DEFAULT_STAT))) * tank_share * (1.0 - MAX_BODY_DRAIN * hurt("body"))


func stamina_fraction() -> float:
	return stamina / max_stamina()


## 0 at half a tank or more, rising to MAX_TIRED_PENALTY when empty.
func tired() -> float:
	var tank: float = (TANK_BASE + TANK_PER_CARDIO * int(stats.get("cardio", DEFAULT_STAT))) * tank_share
	if stamina >= tank:
		return 0.0  # A full fresh tank: skip the maths.
	var f: float = clampf(stamina / (tank * (1.0 - MAX_BODY_DRAIN * hurt("body"))), 0.0, 1.0)
	if f >= TIRED_BELOW:
		return 0.0
	return MAX_TIRED_PENALTY * (TIRED_BELOW - f) / TIRED_BELOW


## 0 (fresh) to 1 (fully hurt) for "head", "body" or "legs".
func hurt(area: String) -> float:
	var toughness: float = int(stats.get("chin" if area == "head" else "durability", DEFAULT_STAT))
	return clampf(damage[area] / (HURT_SCALE * (toughness + 50.0)), 0.0, 1.0)


## 0 (fresh) to 1 (gone) for one leg (D144): LEFT_LEG or RIGHT_LEG.
func leg_hurt(side: int) -> float:
	var toughness: float = int(stats.get("durability", DEFAULT_STAT))
	return clampf(leg_damage[side] / (HURT_SCALE * LEG_SHARE * (toughness + 50.0)), 0.0, 1.0)


## The leg in front, where low kicks land: the left for an orthodox fighter (and anyone whose
## profile gives no stance), the right for a southpaw; the other one once he's switched.
func lead_leg() -> int:
	var lead: int = RIGHT_LEG if String(profile.get("stance", "orthodox")) == "southpaw" else LEFT_LEG
	return 1 - lead if switched else lead


## What's left before the referee stops it, 1 (fresh) to 0 (finished): the head
## damage they can still take, as the HUD's health bar shows it (D120).
func health() -> float:
	return 1.0 - hurt("head")


## Composure broken: defense and Fight IQ drop, power and output go up (wild swings).
func is_panicking() -> bool:
	return hurt("head") >= PANIC_BASE + stat("composure") / 200.0


func is_rocked() -> bool:
	return rocked_ticks > 0


func is_down() -> bool:
	return down_ticks > 0


## Ticks between a trigger and this fighter's own reaction to it. One number
## shared by read calls, drilled rules and the AI (D93).
func reaction_ticks() -> int:
	return maxi(1, roundi((REACTION_TICKS_AT_ZERO - REACTION_TICKS_PER_SPEED * stat("speed")) * (1.0 + tired())))


func spend_stamina(amount: float) -> void:
	stamina = maxf(stamina - amount, 0.0)


## One tick of breathing: Cardio decides how fast the tank refills.
func regen_tick() -> void:
	var cardio: int = int(stats.get("cardio", DEFAULT_STAT))
	var per_second: float = REGEN_BASE + REGEN_PER_CARDIO * cardio / 100.0
	var tank: float = (TANK_BASE + TANK_PER_CARDIO * cardio) * tank_share * (1.0 - MAX_BODY_DRAIN * hurt("body"))
	stamina = minf(stamina + per_second / FightClock.TICKS_PER_SECOND, tank)


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
	grip = null
	sprawled = false
	blind_shot = false
