class_name FightView
extends RefCounted
## What one fighter's decision step may look at (docs/12 §3 item 2): the fight
## as seen from fighter `me`, read through FightSim's queries. Decision sources
## read from here and never change the fight; the sim applies what they decide.
##
## roll() draws from the fight's seeded RNG, so decisions stay replayable.
##
## The sim keeps one view per fighter and updates `now` each tick. The view holds
## the sim weakly: a strong reference both ways would keep every finished fight
## in memory.

var index: int
## Read these, never change them: the sim owns the fight.
var me: FighterState
var opponent: FighterState
var actions: ActionLibrary
var positions: PositionLibrary
var combos: ComboLibrary
var ruleset: Ruleset
## The tick being decided.
var now: int = 0
var _sim_ref: WeakRef
## The fight's seeded RNG and its position state, held directly: roll() and band()
## run several times a tick, and neither points back at the sim, so holding them
## doesn't keep a finished fight alive.
var _rng: RandomNumberGenerator
var _situation: Situation


func _init(p_sim: FightSim, p_index: int) -> void:
	_sim_ref = weakref(p_sim)
	index = p_index
	me = p_sim.fighters[p_index]
	opponent = p_sim.fighters[1 - p_index]
	actions = p_sim.actions
	positions = p_sim.positions
	combos = p_sim.combos
	ruleset = p_sim.ruleset
	_rng = p_sim.rng_for_views()
	_situation = p_sim.situation


## True when fighter `actor` steps after this one this tick, so what they start this tick is
## first seen on the next (FightSim.steps_later; the two take turns stepping first, D253).
func steps_after_me(actor: int) -> bool:
	return _sim().steps_later(actor, index)


## The opponent's latest step on their feet (FightSim.last_stride).
func opponent_stride() -> Vector2:
	return _sim().last_stride(1 - index)


func band() -> String:
	# As FightSim.band(), without the trip through the sim.
	return Octagon.band(distance()) if _situation.is_standing() else Octagon.BAND_CLINCH


## How fast this fighter walks right now, in metres per tick (legs hurt = slower).
func step() -> float:
	return _sim_ref.get_ref().step_length(index)


## Whether the opponent's feet are cutting the cage off on this fighter right now (D230): their
## cut was working on their last step.
func opponent_cutting() -> bool:
	return _sim_ref.get_ref().is_cutting(1 - index)


## Whether this fighter's own cut is working (D230), and whether the opponent's last step
## circled (at least FightSim.CIRCLING_FROM of it round this fighter).
func cutting() -> bool:
	return _sim_ref.get_ref().is_cutting(index)


func opponent_circling() -> bool:
	return _sim_ref.get_ref().last_circling(1 - index) >= FightSim.CIRCLING_FROM


## Which way round the opponent this fighter last circled (±1, as FightSim.way_toward_middle).
func circle_way() -> int:
	return _sim_ref.get_ref().circle_sign(index)


## Being cut off (D233), as the cutter's last read of this fighter's escape routes has it: which
## way round him the best open route goes (±1, 0 = none), and whether every way out is shut.
func way_out() -> int:
	return _sim_ref.get_ref().way_out(index)


func shut_in() -> bool:
	return _sim_ref.get_ref().is_shut_in(index)


## Shut in, which way round the cutter to burst out (±1), and whether the opponent is bursting out (D234).
func burst_way() -> int:
	return _sim_ref.get_ref().burst_way(index)


func opponent_bursting() -> bool:
	return _sim_ref.get_ref().is_bursting(1 - index)


## A feint sold this fighter a door shut (D235), and whether the opponent turned back off one in
## the last `within` ticks.
func sold() -> bool:
	return _sim_ref.get_ref().is_sold(index)


## Cutting him off, whether the opponent has a way out open to sell shut (D235): this fighter's
## own read, true whatever the opponent's been sold.
func opponent_door_open() -> bool:
	return _sim_ref.get_ref().door_open(1 - index)


func opponent_turned_back(within: int) -> bool:
	return _sim_ref.get_ref().turned_back_at(1 - index) >= now - within


func distance() -> float:
	return me.pos.distance_to(opponent.pos)  # As FightSim.distance(), without the trip through the sim.


## The current position id (e.g. "standing", "full_guard"), its phase, and roles.
func position() -> String:
	return _situation.position


func phase() -> String:
	return _situation.phase


func is_standing() -> bool:
	return _situation.is_standing()


func my_role() -> String:
	return _situation.role(index)


func opponent_role() -> String:
	return _situation.role(1 - index)


func my_flags() -> Array[String]:
	return _sim().active_flags(index)


func opponent_flags() -> Array[String]:
	return _sim().active_flags(1 - index)


func my_cage_proximity() -> String:
	return _sim().cage_proximity(index)


func opponent_cage_proximity() -> String:
	return _sim().cage_proximity(1 - index)


## Held with his back on the fence in the clinch (D220), this fighter or the opponent.
func held_on_fence() -> bool:
	return _sim().held_on_fence(index)


func opponent_held_on_fence() -> bool:
	return _sim().held_on_fence(1 - index)


## My underhooks in the clinch (D261): 0, 1 or 2 (the body lock).
func underhooks() -> int:
	return _sim().underhooks(index)


## His underhooks on me in the clinch (D261): my overhooks.
func opponent_underhooks() -> int:
	return _sim().underhooks(1 - index)


## A drive to the fence under way in the clinch (D220): {by, dir, left}, or empty.
func drive() -> Dictionary:
	return _sim().drive()


func odds(action_id: String) -> OddsBreakdown:
	return _sim().odds_breakdown(index, action_id)


## My odds for this action if it lands `ahead` ticks from now, with the opponent
## carrying on with what they're committed to (a counter into their recovery).
func odds_ahead(action_id: String, ahead: int) -> OddsBreakdown:
	return _sim().odds_breakdown(index, action_id, ahead)


## The opponent's odds for one of their actions against me right now.
## Odds on stats alone (no flags or counter): mine, or the opponent's against me.
func plain_odds(action_id: String) -> float:
	return _sim().plain_odds(index, action_id)


func opponent_plain_odds(action_id: String) -> float:
	return _sim().plain_odds(1 - index, action_id)


func opponent_odds(action_id: String) -> OddsBreakdown:
	return _sim().odds_breakdown(1 - index, action_id)


## True when starting this takedown now would be a blind shot (D131, FightSim.would_be_blind).
func would_be_blind(action_id: String) -> bool:
	return _sim().would_be_blind(index, action_id)


## Ticks one phase of an action takes me (or the opponent) right now (Speed, fatigue).
func phase_ticks(action_id: String, phase: String) -> int:
	return _sim().phase_ticks(me, action_id, phase)


func opponent_phase_ticks(action_id: String, phase: String) -> int:
	return _sim().phase_ticks(opponent, action_id, phase)


## Ticks from starting this action to its active phase (when it lands or not).
## How many times I'd already seen the combination the opponent is in the middle of (D133).
func combo_seen_before() -> int:
	return _sim().combo_seen_before(index)


func ticks_to_land(action_id: String) -> int:
	return phase_ticks(action_id, "telegraph") + phase_ticks(action_id, "windup")


## The opponent's phase `ahead` ticks from now if they carry on ("" once done).
func opponent_phase_ahead(ahead: int) -> String:
	return _sim().phase_ahead(1 - index, ahead)


## What a fighter's (default: my) clean strikes multiply their base damage by (Power).
func strike_power(fighter: FighterState = null) -> float:
	return _sim().strike_power(fighter if fighter != null else me)


## Damage this strike would do to the opponent if it landed clean (no counter).
func strike_damage(action_id: String, fighter: FighterState = null) -> float:
	return _sim().strike_damage(fighter if fighter != null else me, action_id)


func round_number() -> int:
	return _sim().clock.current_round


func rounds() -> int:
	return _sim().clock.rounds


func ticks_left_in_round() -> int:
	var c: FightClock = _sim().clock
	return c.ticks_per_round() - c.tick_in_round


## "" when I could start this action right now, else why not (unknown, illegal, wrong position).
func why_not(action_id: String) -> String:
	return _sim().why_not(index, action_id)


func roll() -> float:
	return _rng.randf()  # The same draw as FightSim.roll().


## step() runs every tick, so it reads _sim_ref directly; band(), distance() and
## roll() skip the sim altogether.
func _sim() -> FightSim:
	return _sim_ref.get_ref()
