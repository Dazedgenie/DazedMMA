class_name FighterAI
extends RefCounted
## The fighter's own choices when nobody is calling: a utility AI at the bottom of
## the DecisionLayer stack (docs/01 §7, §16 A2, issue #14). It reads the fight only
## through FightView and hears the fight's events, so it knows what a fighter in
## the cage could know, one reaction time late (D93).
##
## Each free tick, in this order:
##   1. Danger first (A2): rocked fighters cover up; a shot it read gets sprawled on.
##   2. What it is following through with: a tell (the profile's habits, docs/01 §7,
##      D11) or the next strike of a combination. Chained strikes that are the start of a
##      drilled combination (the profile's `combos`, D133) are thrown as it: each chain after
##      that is its next move. A combination called or commanded as a whole runs to its end
##      (next_in_combo, asked by DecisionLayer first).
##   3. An opening it read in time: a counter landing in the opponent's wind-up or
##      recovery, or a flag such as LEANING. Fight IQ decides how often it reads a
##      move; style decides how often it takes what it reads.
##   4. Meeting an opponent who walks in: one roll per advance, mostly outside fighters.
##   5. A lead: now and then (work rate × pace × the moment), its best move from here;
##      a shot that would be blind is set up with a feint first, sometimes (D131).
## Strikes are only thrown when they will still reach as they land: the fighter
## stops moving once committed, but a free opponent keeps walking.
## Every candidate move is scored
##   tendency × style × gameplan × commitment × stamina × what's working × opening
## and picked by weighted chance, sharper with Fight IQ, so fighters vary but stay in character.
##
## The feet follow a range plan: the band where the fighter's own weapons beat the
## opponent's, tilted by the Range and Pace leanings. Outside fighters step back
## from strikes they read and reset after combinations; pressure fighters walk them down.
##
## Tied up (clinch or ground, #15, docs/01 §21) there's no footwork and no range
## plan: now and then the fighter works from where they are. In the clinch, strikers
## look to break and grapplers knee or shoot; on the ground the fighter underneath
## works to get up or tie the top fighter up, the one on top grounds and pounds (D121),
## and in a scramble each goes for what they like: back to the feet, or the top.
##
## Every number is a first guess, tuned with the balance harness (tools/balance.gd).

const STRIKE := "strike"
const TAKEDOWN := "takedown"
const DEFENSE := "defense"
const CLINCH := "clinch"
const GROUND := "ground"
const SUBMISSION := "submission"
const TELL := "tell"
const COMBO := "combo"
## Far to close: the bands a standing fighter can plan to fight from.
const BANDS: Array[String] = [Octagon.BAND_LONG, Octagon.BAND_MID, Octagon.BAND_POCKET]
## Inside each band, where a fighter may stand (between the band's edges, a little in).
const BAND_SPOTS := {
	Octagon.BAND_LONG: [Octagon.MID_WITHIN + 0.05, Octagon.LONG_WITHIN - 0.05],
	Octagon.BAND_MID: [Octagon.POCKET_WITHIN + 0.05, Octagon.MID_WITHIN - 0.05],
	Octagon.BAND_POCKET: [Octagon.MIN_GAP, Octagon.POCKET_WITHIN - 0.05],
}
## Flags that come from how a fighter is or where they stand, not from a move: anyone sees them.
const STATE_FLAGS := { "HANDS_LOW": true, "BACK_TO_CAGE": true }
## The opponent knocked down (D141, D142): the chance a free tick of following him down, or of a
## soccer kick or a stomp where the rules allow them (× 0.5 to 1.5 from the Risk leaning).
const DOWNED_RATE: float = 0.3
## Following a knocked-down man to the ground (D142) is worth this much × its odds, against a
## soccer kick's expected damage (about 10 for an average fighter) where those are legal.
const FOLLOW_DOWN_VALUE: float = 10.0
## Whether he follows this knockdown down at all, decided once as the man drops: this × his
## tendency for it × (1 + Base / 100), so a grappler (Base 70) about 85%, a striker (0) half the time.
const FOLLOW_DOWN_CHANCE: float = 0.5

## Reading a move: (0.15 + 0.5 × Fight IQ / 100) × telegraph factor, where a 2-tick
## telegraph is normal and each tick longer or shorter is ±20% (docs/11 §3.3: a shorter
## telegraph is harder to read). Rocked, half as likely.
const READ_BASE: float = 0.15
const READ_PER_IQ: float = 0.5
const READ_TELEGRAPH_NORMAL: int = 2
const READ_PER_TELEGRAPH_TICK: float = 0.2
const READ_FACTOR_MIN: float = 0.5
const READ_FACTOR_MAX: float = 1.5
const ROCKED_READ: float = 0.5
## Taking an opening it read: 75%, up to +20% for a patient fighter and −20% for an aggressive one.
const TAKE_BASE: float = 0.75
const TAKE_PER_PACE: float = 0.2
## Moves that only exist with an opening (the catch-kick needs a kick to catch) are
## left to the coach: the fighter's own weight for them is multiplied by this (Q1, #14).
const OWN_REQUIRED_OPENINGS: float = 0.0
## How much better odds pull the choice: weight × (odds now / plain odds)^2.
const OPENING_SHARPNESS: float = 2.0
## Sprawling on a shot it read: 60% + 30% × Takedown defense / 100.
const SPRAWL_BASE: float = 0.6
const SPRAWL_PER_TDD: float = 0.3
## Checking or slipping a strike it read (D180), when the defence will be up as it lands:
## 60% + 30% × Striking defense / 100. Then the defence's own roll decides it (FightSim).
const GUARD_BASE: float = 0.6
const GUARD_PER_SD: float = 0.3
## Covering up when rocked (D180): decided once each time he's rocked, 20% + 40% × Fight IQ / 100
## (40% for an average fighter), plus the Survive! call's cover_bonus (it makes him).
const COVER_BASE: float = 0.2
const COVER_PER_IQ: float = 0.4
## Outside fighters step back from a strike they read: up to 60% at Range −100, plus
## 30% × head hurt for anyone. They aim this much further away until it's past.
const EVADE_MAX: float = 0.6
const EVADE_WHEN_HURT: float = 0.3
const EVADE_STEP: float = 0.8
## Combinations: after a strike, another at (0.15 + 0.45 × skill / 100) × pace, at most 3 more.
## Skill is the move's technique stat (Boxing for punches, Kicking for kicks).
const COMBO_BASE: float = 0.15
const COMBO_PER_SKILL: float = 0.45
const COMBO_MAX: int = 3
const COMBO_WINDOW_TICKS: int = 2
const TIRED_COMBO_BELOW: float = 0.3
## Drilled combinations (D133): picked by the moves' tendencies (their average), × this for
## each time the fighter has already thrown it this fight, so they mix them up.
const COMBO_FRESH: float = 0.6
## Reading the next move of a combination already seen this fight: +0.1 for each time before (up to 3).
const COMBO_SEEN_READ: float = 0.1
## Resets: when a combination ends, outside fighters step out 0.6 m for 1–2 s (up to 70% at Range −100).
const RESET_MAX: float = 0.7
const RESET_TICKS_MIN: int = 10
const RESET_TICKS_MAX: int = 20
const RESET_STEP: float = 0.6
## The lead rate: work rate × (1 + Pace / 200), then × these for the moment.
const RESET_RATE: float = 0.35
const OFF_PLAN_RATE: float = 0.6
## Crowded: closer than they planned, in a band where the opponent out-threatens them
## (an outside fighter caught in the pocket). Getting out comes first, so leads × 0.35
## and combinations × 0.5. Closer than planned but not out-gunned, they fight from there.
## Grapplers less so (#15): the leads go back toward full rate with the Base leaning (all of it
## at +100), since a takedown or a tie-up is their way out.
const CROWDED_RATE: float = 0.35
const CROWDED_COMBO: float = 0.5
const ROCKED_RATE: float = 0.3
const TIRED_RATE_BELOW: float = 0.5
const TIRED_RATE_MIN: float = 0.6
## Style leanings (with the gameplan) are looked up again every this many ticks.
const LEAN_EVERY: int = 10
## However the moment stacks up, never more than 4 × the work rate.
const LEAD_RATE_CAP: float = 4.0
## The last 15 s of a round: everyone picks it up a bit.
const ROUND_END_TICKS: int = 150
const ROUND_END_RATE: float = 1.25
## Final round: behind on their own reckoning, 1.25× busier (± a quarter for Risk); ahead and Safe, they coast.
const BEHIND_RATE: float = 1.25
## A round counts as won or lost on their own reckoning when one side did 10% more.
const ROUND_SENSE: float = 1.1
## Commitment: strike weight × (ticks / 5)^−aversion, aversion (0.5 − 0.4 × Risk / 100)
## × danger / 0.5, so safe fighters throw quick shots and wild ones throw big ones, and
## everyone throws big ones more freely where the opponent can't punish them.
const COMMIT_REF_TICKS: float = 5.0
const COMMIT_AVERSION: float = 0.5
const COMMIT_PER_RISK: float = 0.4
const DANGER_EVEN: float = 0.5
## Head shots on a hurt opponent: × (1 + finish × (head hurt + 1 if rocked)), finish 0.5 + 0.5 × Risk / 100.
const FINISH_BASE: float = 0.5
## Low stamina: expensive moves fade (a move costing 8 or more fades fully at an empty tank).
const TIRED_COST_REF: float = 8.0
const TIRED_MIN_WEIGHT: float = 0.1
## What's working: each move's landing record (0–1, starting even) moves the weight by
## up to ±40% at Fight IQ 50, ±80% at Fight IQ 100.
const WORKING_START: float = 0.5
const WORKING_MEMORY: float = 0.2
const WORKING_PULL: float = 0.8
## The range plan, re-thought every 2 s: per band, my threat − caution × theirs, over my
## best threat; plus Range ±0.35 and Pace ±0.15 toward the pocket or long range. The
## band it already holds gets +0.1 so it doesn't flicker.
const PLAN_EVERY: int = 20
const PLAN_OTHERS: float = 0.25
const PLAN_CAUTION: float = 0.8
const PLAN_CAUTION_PER_LEANING: float = 0.3
const PLAN_RANGE_BIAS: float = 0.35
const PLAN_PACE_BIAS: float = 0.15
const PLAN_STICKY: float = 0.1
## A landed takedown counts like this much damage when planning where to stand (judges score them in #15),
## and a clinch entry this much × how much the fighter likes the clinch (D114: grapplers plan for the range they grapple from).
const TAKEDOWN_PLAN_VALUE: float = 16.0
const CLINCH_PLAN_VALUE: float = 8.0
## Walking into the opponent's weapons while the opponent is free, fighters stalk: at
## half pace (± a quarter for Pace) where only the opponent's weapons reach, scaled by
## the opponent's share of the threat in that band. They close at full speed while the
## opponent is committed to a move.
const STALK_BASE: float = 0.5
const STALK_PER_PACE: float = 0.25
## Losing the round or the fight on their own reckoning, they stalk in this much faster.
const STALK_WHEN_LOSING: float = 0.1
## Inside the band: Range +100 stands 0.25 m closer, Pace +100 another 0.15 m.
const RANGE_SHIFT: float = 0.25
const PACE_SHIFT: float = 0.15
## Meeting the advance: when the opponent walks in faster than 0.4 m/s, one roll at
## (0.2 + 0.5 for an outside fighter) × (0.5 + Fight IQ / 100) to meet them with a strike
## that lands as they arrive.
const INTERCEPT_CLOSING: float = 0.04
const INTERCEPT_BASE: float = 0.2
const INTERCEPT_OUTSIDE: float = 0.5
## Nothing takes longer than this to land, so a walk-in further off than this many ticks can't be met yet.
const REACH_LOOKAHEAD_TICKS: float = 12.0
## How fast the opponent's approach is tracked (share of the newest step).
const CLOSING_MEMORY: float = 0.5
## Circling: outside fighters circle (Range −100 = all of it) when the opponent is closer than
## they want, a little otherwise; rocked fighters circle away as hard as they can.
const CIRCLE_PRESSED: float = 0.8
const CIRCLE_FREE: float = 0.25
const PRESSED_BY: float = 0.1
## Backing up with the fence behind them, fighters circle off it instead: from this far
## out, the closer the fence the less they back up and the harder they circle.
const FENCE_SENSE: float = 1.5
## Closer to the centre than this, no fence is within FENCE_SENSE (Octagon.CLEAR_INSIDE).
const CLEAR_OF_FENCE: float = Octagon.APOTHEM - Octagon.BODY_MARGIN - FENCE_SENSE - 0.01
## Holding the centre (D107): pressed by an opponent who can't do much from where they
## stand (the opponent's share of the danger there under this), fighters hold their
## ground instead of backing up. Once the opponent gets into range of their own weapons
## they give ground, all the way back to their spot, and then hold again.
const HOLD_DANGER: float = 0.15
## Back toward the centre (D107): further from the middle than the opponent, outside
## fighters giving ground (or while the opponent is busy throwing) circle round them
## toward it, harder the further out they are (CENTRE_PULL × outside, all of it from
## CENTRE_PULL_OVER metres further out), and pivot more than they back off: that share
## (PIVOT × outside × how much further out) of the backing up goes.
const CENTRE_PULL: float = 1.0
const CENTRE_PULL_OVER: float = 1.0
const PIVOT: float = 1.0
## Cutting off the cage (D107): pressing, fighters step sideways to stay between the
## opponent and the middle (the sim scales it by the Footwork contest). Range 0 cuts this
## much, ± CUT_PER_RANGE at Range ±100.
const CUT_BASE: float = 0.6
const CUT_PER_RANGE: float = 0.4
## Getting off the fence (D107): backed onto it, outside fighters plant and fight, and
## try to circle out (all they can for ESCAPE_TICKS, toward the middle side, or either
## way at random when neither is clearly more open) the moment the opponent commits to
## a move, or on a chance of ESCAPE_RATE × outside a tick.
const ESCAPE_RATE: float = 0.5
const ESCAPE_TICKS: int = 15
## Tied up (#15): chance per free tick to work from the clinch (× the work rate), from
## underneath in full guard (× the work rate), and in a scramble (flat: it's over fast).
const CLINCH_RATE: float = 4.0
const GROUND_RATE: float = 2.0
const SCRAMBLE_RATE: float = 0.3
## Who likes the clinch: Base / 100 + Range / 200 (0–1), and only with something to do
## there (a strike or takedown that works from the clinch). Breaking it: weight
## 1 − Base / 100 − Range / 200, at least CLINCH_BREAK_MIN.
const CLINCH_BREAK_MIN: float = 0.05
## Ground and pound (D121): on top, a chance of GNP_RATE × work rate × (1 + Pace / 100)
## per free tick to throw a ground strike, more against a rocked fighter (as standing),
## less when tired. Tied up (posture broken) they hold until it wears off.
const GNP_RATE: float = 1.2
## Underneath: while the top fighter is throwing, works GROUND_UNDER_FIRE × as often.
## Tying up is weighted TIE_UP_CALM normally, TIE_UP_PRESSED under fire or rocked;
## a rocked fighter's get-ups are weighted ROCKED_GET_UP.
const GROUND_UNDER_FIRE: float = 3.0
const TIE_UP_CALM: float = 0.3
const TIE_UP_PRESSED: float = 1.5
const ROCKED_GET_UP: float = 0.3
## Submissions (D126): only on an opening their hold looks for (the top fighter postured up for
## the armbar, his posture broken for the triangle, a head stuck low under a sprawl for the
## guillotine), and not again for SUB_RETRY_TICKS after the last try. Underneath, a hold is
## weighted SUB_WEIGHT × how much they like submissions (Submissions / 50) × (1 + Risk / 200),
## next to getting up and tying up. Standing (or in the clinch), one look per sprawled shot: a
## guillotine on a chance of GUILLOTINE_CHANCE × the same liking × (the odds / 50%)².
const SUB_WEIGHT: float = 0.1
const SUB_RETRY_TICKS: int = 450
const GUILLOTINE_CHANCE: float = 0.35
## Throws and the guard game (D128): in the clinch, a guard pull is weighted GUARD_PULL_WEIGHT × how
## much they like submissions, next to their throws, knees and the break. A required opening the
## data marks `ai_takes` (the foot sweep on a lean) is taken when read, unlike the catch (D103).
const GUARD_PULL_WEIGHT: float = 0.5
## Working position on top (D130): on top, a chance of ADVANCE_RATE × work rate × how much they like
## position (0.5 + Base / 100, at least ADVANCE_MIN_LIKING) a free tick to go for a better position
## or a hold from here (a pass, the mount, the back, the arm-triangle), before the ground and pound.
## When the fighter underneath starts to escape (ESCAPING), one look per escape for the opening it
## gives (the back, the armbar, the arm-triangle), taken on a chance of ESCAPE_PUNISH × (the odds / 50%)²,
## and for a hold × ESCAPE_SUB × how much they like submissions.
const ADVANCE_RATE: float = 0.3
const ADVANCE_MIN_LIKING: float = 0.1
const ESCAPE_PUNISH: float = 0.2
const ESCAPE_SUB: float = 0.5
## The collar tie (D129): in the clinch, while either fighter's head is tied up the fighter works
## COLLAR_RATE × as often (the holder's knees come in a burst, the one tied up fights out), and
## the one tied up weights the break and a collar tie of his own COLLARED_ESCAPE × (he wants out).
## Nobody ties up a head that's already tied.
const COLLAR_RATE: float = 2.0
const COLLARED_ESCAPE: float = 3.0
## In a scramble: back to the feet × (1 − Base / 100), the top × (1 + Base / 100).
## Switching direction (D107): away from the fence (further than SWITCH_FENCE), circling
## fighters think again every SWITCH_EVERY ticks and change direction on a chance of
## SWITCH_CHANCE, so they don't circle the same way all fight. Closer to the fence they
## circle toward the middle.
const SWITCH_EVERY: int = 30
const SWITCH_CHANCE: float = 0.4
const SWITCH_FENCE: float = 0.8
## Closer to the centre than this, the fence is further than SWITCH_FENCE.
const CLEAR_OF_SWITCH: float = Octagon.APOTHEM - Octagon.BODY_MARGIN - SWITCH_FENCE - 0.01
## Caught (#18): each time the opponent catches one of the fighter's moves with a catch
## (a takedown that needs the opening that move gives, like the catch-kick single), the
## fighter throws that move this much less for the rest of the fight.
const CAUGHT_FADE: float = 0.7
## Wise to it (#18, Kyle's pick): every takedown or clinch entry the opponent started in
## the last WISE_TICKS adds WISE_READ to the chance to read the next one, up to WISE_MAX.
## The third shot in a minute is easier to see coming than the first.
const WISE_TICKS: int = 600
const WISE_READ: float = 0.15
const WISE_MAX: float = 0.45
## Feints and blind shots (D131, docs/01 §29). About to lead with a takedown that would be
## blind, the fighter feints first with chance SETUP_BASE + SETUP_PER_IQ × Fight IQ / 100
## and shoots off it (until FEINT_FOLLOW_TICKS after the feint is over). Reading a blind
## shot: + BLIND_READ; reading anything while bitten on a feint: × BIT_READ.
const SETUP_BASE: float = 0.1
const SETUP_PER_IQ: float = 0.6
const FEINT_FOLLOW_TICKS: int = 3
const BLIND_READ: float = 0.3
const BIT_READ: float = 0.5

var _triggers: TriggerLibrary
var _ready_for: FighterState
## The fighter's repertoire plus the moves everyone knows (ActionLibrary.basic_ids: get up,
## sprawl, clinch entry and break), and whether any of them works from the clinch.
var _moves: Array[String] = []
var _moves_for: FighterState
var _clinch_weapon: bool = false
## The profile's tells, by the event type that can set them off: type → [{trigger, action, chance, ticks, name}].
var _tells: Dictionary = {}
## action id → the move it is set up with (a tell set off by the fighter's own move).
var _setups: Dictionary = {}

## The opponent's current move as this fighter saw it:
## {id, category, at, notice (tick it registers), read, decided, evade_rolled}, or empty.
var _opp: Dictionary = {}
## A move to follow with: {kind: TELL or COMBO, id, until, reason, last}, or empty.
var _follow: Dictionary = {}
var _chain: int = 0
## The move of _follow's combination to go on with.
var _follow_step: int = 0
## Combination id → times this fighter has started it this fight (COMBO_FRESH).
var _combos_used: Dictionary = {}
var _reset_until: int = -1
var _evade_until: int = -1
var _plan_band: String = ""
var _plan_at: int = -PLAN_EVERY
## Per band at the last plan: (my threat − caution × theirs) / my best threat. Below 0 = out-gunned there.
var _band_scores: Dictionary = {}
## FighterState → the moves it threatens with in the range plan (_plan_moves).
var _plan_cache: Dictionary = {}
## Per band at the last plan: the opponent's share of the threat there (0 = only mine reaches, 1 = only theirs).
var _danger: Dictionary = {}
## The distance the feet were last told to keep.
var _last_want: float = 0.0
## How hard the feet were told to circle off the fence (0–1, _fence_behind).
var _off_fence: float = 0.0
## Giving ground until they're back at their spot (HOLD_DANGER).
var _giving_ground: bool = false
## Circling out off the fence until this tick, and which way (±1, as in FightSim.way_toward_middle).
var _escape_until: int = -1
var _escape_way: int = 0
## Which way they circle in open space (±1), thought again at _way_at + SWITCH_EVERY.
var _way: int = 1
var _way_at: int = -SWITCH_EVERY
## Scratch plan for circling(), circle_way() and cutting() asked on their own (tests).
var _feet := FeetPlan.new()
## What preferred_distance saw on tick _feet_at, for circling() on the same tick.
var _feet_at: int = -1
var _feet_gap: float = 0.0
var _feet_outside: float = 0.0
var _feet_cut: float = 0.0
## How fast the opponent walks toward this fighter (m per tick, negative = away),
## from where they were seen last; and whether this advance has been met already.
var _closing: float = 0.0
var _seen_at: int = -1
var _seen_pos: Vector2 = Vector2.ZERO
var _met_advance: bool = false
## action id → landing record (0–1).
var _working: Dictionary = {}
## This round on the fighter's own reckoning (judge-weighted damage), and rounds won − lost so far.
## Own move id → times the opponent caught it (CAUGHT_FADE), and the last move started.
var _caught: Dictionary = {}
var _last_move: String = ""
## Ticks the opponent started grappling moves (takedowns, clinch entries), oldest first.
var _grapples_seen: Array[int] = []
var _round_dealt: float = 0.0
var _round_taken: float = 0.0
var _rounds_up: int = 0
## The style leanings as the layer reads them (gameplan included), looked up once a second.
var _lean_tick: int = -LEAN_EVERY
var _leanings: Dictionary = {}
## Looked up once per choice (nothing changes while a fighter decides): the distance,
## the band, and per move whether it will reach, when it lands and the odds now.
var _gap: float = 0.0
var _band: String = ""
var _reach: Dictionary = {}
var _land: Dictionary = {}
var _odds_now: Dictionary = {}
var _choice_ready: bool = false
## The opponent's knockdown count when this fighter last decided whether to follow him down (D142),
## and what he decided.
var _follow_decided_at: int = 0
var _follows: bool = false
## Rolled each time this fighter is rocked (D180): he covers up while it's under the cover chance.
var _cover_roll: float = -1.0
## Submissions (D126): the tick of this fighter's last try, and whether they've already
## looked for a guillotine on the opponent's current stuck shot.
var _sub_at: int = -SUB_RETRY_TICKS
var _guillotine_looked: bool = false
var _escape_looked: bool = false


func _init(p_triggers: TriggerLibrary = null) -> void:
	_triggers = p_triggers if p_triggers != null else TriggerLibrary.shared()


# --- Choosing what to start -----------------------------------------------------

## What to start this free tick, or DecisionLayer.IDLE to keep working the feet.
## A fighter with no moves or a work rate of 0 never starts anything (a statue for tests).
func choose(view: FightView, layer: DecisionLayer) -> Decision:
	var f: FighterState = view.me
	_prepare(f)
	if f.repertoire.is_empty() or f.work_rate <= 0.0:
		return DecisionLayer.IDLE
	if view.opponent.is_down():
		return _downed(view, layer)
	_choice_ready = false
	if not view.is_standing():
		return _tied(view, layer)
	if f.is_rocked():
		var cover: Decision = _cover(view, layer)
		if cover != null:
			return cover
		# Hurt: only the odd desperate shot.
		return _lead(view, layer) if _leads(view, layer) else DecisionLayer.IDLE
	var registered: bool = _registered(view)
	var d: Decision = null
	if registered and _opp.category == TAKEDOWN:
		d = _defend(view, layer)
	elif registered and _opp.category == STRIKE:
		d = _guard(view, layer)
	if d == null:
		d = _guillotine(view, layer)
	if d == null and not _follow.is_empty():
		d = _follow_up(view, layer)
	if d == null and registered and not _opp.decided:
		d = _opening(view, layer)
	if d == null:
		if _closing < INTERCEPT_CLOSING or not view.opponent.is_free():
			_met_advance = false
		elif not _met_advance:
			d = _meet_advance(view, layer)
	if d != null:
		return d
	if _leads(view, layer):
		return _lead(view, layer)
	return DecisionLayer.IDLE


## The opponent is down from a knockdown (D141, D142): follow him down to the ground and
## finish him there, or, where the rules allow it (PRIDE), kick or stomp him while he's there.
## Whether he'll follow him down is decided once as he drops (FOLLOW_DOWN_CHANCE: grapplers more).
## Then at DOWNED_RATE a free tick (× 0.5 to 1.5 from the Risk leaning), the move worth most that
## reaches: a downed strike by its expected damage, following him down FOLLOW_DOWN_VALUE × its odds.
func _downed(view: FightView, layer: DecisionLayer) -> Decision:
	if not view.is_standing() or view.me.is_rocked():
		return DecisionLayer.IDLE
	_choice_ready = false
	if view.opponent.knockdowns != _follow_decided_at:
		_follow_decided_at = view.opponent.knockdowns
		_follows = view.roll() < FOLLOW_DOWN_CHANCE * float(view.me.tendencies.get("follow_down", 1.0)) \
			* maxf(0.0, 1.0 + _lean(view, layer, StyleLeanings.BASE) / 100.0)
	var best: String = ""
	var best_value: float = 0.0
	for id in _all_moves(view):
		var action: Dictionary = view.actions.get_action(id)
		var value: float = 0.0
		if action.category == STRIKE and action.strike.get("downed", false) and _usable(view, action):
			value = view.strike_damage(id) * view.odds(id).chance
		elif _follows and action.category == GROUND and action.ground.get("downed", false) and _usable(view, action):
			value = FOLLOW_DOWN_VALUE * view.odds(id).chance
		if value > best_value:
			best_value = value
			best = id
	# No roll unless there's something to do, so a fighter who won't follow up plays as before.
	if best == "" or view.roll() >= DOWNED_RATE * (1.0 + _lean(view, layer, StyleLeanings.RISK) / 200.0):
		return DecisionLayer.IDLE
	return Decision.new(best, DecisionLayer.AI, "while he's down")


## One roll against the lead rate. Most ticks the roll is above any rate the moment
## could give, so the rate is only worked out when it might matter.
func _leads(view: FightView, layer: DecisionLayer) -> bool:
	var r: float = view.roll()
	return r < LEAD_RATE_CAP * view.me.work_rate and r < lead_rate(view, layer)


## Chance per free tick to lead with something: work rate × (1 + Pace / 200) × the moment,
## at most LEAD_RATE_CAP (4) × the work rate.
func lead_rate(view: FightView, layer: DecisionLayer) -> float:
	var f: FighterState = view.me
	var risk: float = _lean(view, layer, StyleLeanings.RISK)
	var rate: float = f.work_rate * (1.0 + _lean(view, layer, StyleLeanings.PACE) / 200.0)
	if f.is_panicking():
		rate *= 1.0 + FighterState.PANIC_WORK_RATE_BONUS
	if f.is_rocked():
		rate *= ROCKED_RATE
	elif view.opponent.is_rocked():
		rate *= 1.5 + risk / 200.0
	if view.now < _reset_until or view.now < _evade_until:
		rate *= RESET_RATE
	elif crowded(view) and not view.opponent.is_rocked():
		# A grappler caught in the pocket doesn't back out, he shoots or ties up (#15).
		rate *= lerpf(CROWDED_RATE, 1.0, clampf(_leanings[StyleLeanings.BASE] / 100.0, 0.0, 1.0))
	elif _plan_band != "" and BANDS.find(view.band()) < BANDS.find(_plan_band):
		rate *= OFF_PLAN_RATE  # Still walking in.
	var tank: float = f.stamina_fraction()
	if tank < TIRED_RATE_BELOW:
		rate *= lerpf(TIRED_RATE_MIN, 1.0, tank / TIRED_RATE_BELOW)
	if view.ticks_left_in_round() <= ROUND_END_TICKS:
		rate *= ROUND_END_RATE
	if view.round_number() == view.rounds():
		if _rounds_up < 0:
			rate *= BEHIND_RATE + 0.25 * risk / 100.0
		elif _rounds_up > 0 and risk < 0.0:
			rate *= 1.0 + 0.25 * risk / 100.0
	return minf(layer.lead_rate(view, rate), LEAD_RATE_CAP * f.work_rate)


## Danger first (A2): a shot it read gets sprawled on. When the sprawl roll fails
## (or there's no sprawl), the shot is treated like any other move it read: a knee into
## the lowered head, or backing off.
func _defend(view: FightView, layer: DecisionLayer) -> Decision:
	if not _registered(view) or _opp.category != TAKEDOWN or _opp.get("sprawl_rolled", false):
		return null
	if ActionLibrary.is_throw(view.actions.get_action(_opp.id)):
		return null  # Nothing to sprawl on (D128): it's read like any other move.
	_opp.sprawl_rolled = true
	for id in _all_moves(view):
		var action: Dictionary = view.actions.get_action(id)
		if action.category == DEFENSE and action.defense.get("against_categories", []).has(TAKEDOWN) and _usable(view, action):
			var chance: float = SPRAWL_BASE + SPRAWL_PER_TDD * view.me.effective_stat("takedown_defense") / 100.0
			if view.roll() < layer.sprawl_chance(view, chance):
				_opp.decided = true
				return Decision.new(id, DecisionLayer.AI, "sprawls on the shot")
			return null
	return null


## A strike it read (D180): check a low kick or slip a straight punch, if he has a defence
## against it that will be up as it lands. One roll a strike; when it fails (or there's no
## defence that fits), the strike is read like any other move: a counter, or backing off.
func _guard(view: FightView, layer: DecisionLayer) -> Decision:
	if _opp.get("guard_rolled", false):
		return null
	_opp.guard_rolled = true
	var lands: int = _ticks_until_active(view)
	for id in _all_moves(view):
		var action: Dictionary = view.actions.get_action(id)
		if action.category != DEFENSE or not action.defense.get("against_strikes", []).has(_opp.id) or not _usable(view, action):
			continue
		# Up in time and still up as it lands, whoever steps first this tick.
		var up: int = view.phase_ticks(id, "telegraph") + view.phase_ticks(id, "windup")
		if lands < maxi(1, up + 1) or lands > up + view.phase_ticks(id, "active") - 1:
			continue
		var chance: float = GUARD_BASE + GUARD_PER_SD * view.me.effective_stat("striking_defense") / 100.0
		if view.roll() < chance:
			_opp.decided = true
			return Decision.new(id, DecisionLayer.AI, "%s the %s" % [String(action.name).to_lower(), String(view.actions.get_action(_opp.id).name).to_lower()])
		return null
	return null


## Rocked (D180): cover up, if he decided to this time he was rocked (COVER_BASE, or the Survive!
## call), with a cover-up that works from here.
func _cover(view: FightView, layer: DecisionLayer) -> Decision:
	if _cover_roll < 0.0:
		return null
	var chance: float = COVER_BASE + COVER_PER_IQ * view.me.effective_stat("fight_iq") / 100.0
	if _cover_roll >= layer.cover_chance(view, chance):
		return null
	for id in _all_moves(view):
		var action: Dictionary = view.actions.get_action(id)
		if action.category == DEFENSE and action.defense.has("head_share") and _usable(view, action):
			return Decision.new(id, DecisionLayer.AI, "covers up")
	return null


## Ticks until the opponent's move reaches its active phase (when a strike lands), 0 once it has.
func _ticks_until_active(view: FightView) -> int:
	if view.opponent.phase == "active" or view.opponent.phase == "recovery":
		return 0
	for ahead in range(1, 30):
		var phase: String = view.opponent_phase_ahead(ahead)
		if phase == "" or phase == "recovery":
			return 0
		if phase == "active":
			return ahead
	return 0


## A tell or the next strike of a combination.
func _follow_up(view: FightView, layer: DecisionLayer) -> Decision:
	if view.now > _follow.until:
		_follow = {}
		_chain = 0
		return null
	if _follow.kind == TELL:
		var action: Dictionary = view.actions.get_action(_follow.id)
		if not _usable(view, action):
			return null  # Not in range yet: the feet are on their way (preferred_distance).
		var reason: String = _follow.reason
		_follow = {}
		return Decision.new(action.id, DecisionLayer.AI, reason)
	var last: String = _follow.last
	var combo: String = String(_follow.get("combo", ""))
	var why: String = String(_follow.get("why", "combination"))
	_follow = {}
	if combo != "":
		var next: String = view.combos.move(combo, int(_follow_step))
		if _usable(view, view.actions.get_action(next)):
			_chain += 1
			var drilled := Decision.new(next, DecisionLayer.AI, "combination")
			drilled.combo = combo
			drilled.combo_step = _follow_step
			return drilled
	var options: Array[String] = []
	var weights: Array[float] = []
	for id in view.me.repertoire:
		var action: Dictionary = view.actions.get_action(id)
		if action.category != STRIKE or not _usable(view, action):
			continue
		var b: OddsBreakdown = _odds(view, id)
		var w: float = _score(view, layer, action, _seen_chance(view, action, b), _plain_chance(b), false)
		if id == last and id != "jab":
			w *= 0.5  # Double jabs, yes; double hooks, rarely.
		if w > 0.0:
			options.append(id)
			weights.append(w)
	if options.is_empty():
		_chain = 0
		return null
	_chain += 1
	var d := Decision.new(options[_pick(view, weights)], DecisionLayer.AI, why)
	d.combo = _pick_combo(view, last, d.action_id)
	if d.combo != "":
		d.combo_step = 1
		_combos_used[d.combo] = int(_combos_used.get(d.combo, 0)) + 1
	return d


## An opening it read and registered in time: a counter or a flag to punish.
func _opening(view: FightView, layer: DecisionLayer) -> Decision:
	if not _registered(view):
		return null
	_ready_choice(view)
	var theirs: Dictionary = view.actions.get_action(_opp.id)
	if not bool(_opp.get("evade_rolled", false)):
		_opp.evade_rolled = true
		if (_opp.category == STRIKE or _opp.category == TAKEDOWN) and theirs.ranges.has(_band) \
				and view.roll() < _evade_chance(view, layer):
			_evade_until = view.now + _ticks_until_past(view)
			_opp.decided = true
			return null
	var options: Array[String] = []
	var weights: Array[float] = []
	var reasons: Array[String] = []
	for id in view.me.repertoire:
		var action: Dictionary = view.actions.get_action(id)
		if (action.category != STRIKE and action.category != TAKEDOWN) or not _usable(view, action):
			continue
		var b: OddsBreakdown = view.odds_ahead(id, _ticks_to_land(view, id))
		if b.chance <= 0.0:
			continue
		var counter: bool = false
		var flag: String = ""
		for bonus: Dictionary in b.bonuses:
			if bonus.name == "counter":
				counter = true
			elif not STATE_FLAGS.has(bonus.name) and float(bonus.value) > 0.0:
				flag = bonus.name
		if not counter and flag == "":
			continue
		var w: float = _score(view, layer, action, b.chance, _plain_chance(b), counter and action.category == STRIKE)
		if _needs_opening(action) and not _takes_opening(action):
			w *= OWN_REQUIRED_OPENINGS
		if w > 0.0:
			options.append(id)
			weights.append(w)
			reasons.append("opening: %s" % flag if flag != "" else "counters the %s" % String(theirs.name).to_lower())
	if options.is_empty():
		return null  # Nothing lands in time from here; their recovery may still give one.
	_opp.decided = true
	var take: float = clampf(TAKE_BASE - TAKE_PER_PACE * _lean(view, layer, StyleLeanings.PACE) / 100.0, 0.05, 0.95)
	if view.roll() >= take:
		return null
	var k: int = _pick(view, weights)
	return Decision.new(options[k], DecisionLayer.AI, reasons[k])


## The opponent is walking in: meet them with something that lands as they arrive.
func _meet_advance(view: FightView, layer: DecisionLayer) -> Decision:
	_ready_choice(view)
	if crowded(view, _band):
		return null  # One roll per advance, as they come into range, not once they're on top of you.
	if _gap - _closing * REACH_LOOKAHEAD_TICKS > Octagon.LONG_WITHIN:
		return null  # Still too far for anything to land.
	var options: Array[String] = []
	var weights: Array[float] = []
	for id in view.me.repertoire:
		var action: Dictionary = view.actions.get_action(id)
		if action.category != STRIKE or not _usable(view, action):
			continue
		var b: OddsBreakdown = _odds(view, id)
		var w: float = _score(view, layer, action, _seen_chance(view, action, b), _plain_chance(b), false)
		if w > 0.0:
			options.append(id)
			weights.append(w)
	if options.is_empty():
		return null  # Not in reach yet.
	_met_advance = true
	var outside: float = clampf(-_lean(view, layer, StyleLeanings.RANGE) / 100.0, 0.0, 1.0)
	var chance: float = (INTERCEPT_BASE + INTERCEPT_OUTSIDE * outside) * (0.5 + view.me.effective_stat("fight_iq") / 100.0)
	if view.roll() >= chance:
		return null
	return Decision.new(options[_pick(view, weights)], DecisionLayer.AI, "meets him coming in")


## Its best move from here, set up with a tell's move when it has one.
func _lead(view: FightView, layer: DecisionLayer) -> Decision:
	var options: Array[String] = []
	var weights: Array[float] = []
	for id in _all_moves(view):
		var action: Dictionary = view.actions.get_action(id)
		if (action.category != STRIKE and action.category != TAKEDOWN and action.category != CLINCH) or not _usable(view, action):
			continue
		var b: OddsBreakdown = _odds(view, id)
		var w: float = _score(view, layer, action, _seen_chance(view, action, b), _plain_chance(b), false)
		if w > 0.0:
			options.append(id)
			weights.append(w)
	if options.is_empty():
		return DecisionLayer.IDLE
	var id: String = options[_pick(view, weights)]
	if _feints_first(view, id):
		_follow = { "kind": TELL, "id": id, "until": view.now + _feint_ticks(view) + FEINT_FOLLOW_TICKS, "reason": "shoots off the feint" }
		return Decision.new(FightSim.FEINT, DecisionLayer.AI, "feints to set up the %s" % String(view.actions.get_action(id).name).to_lower())
	var setup: String = _setups.get(id, "")
	if setup != "" and view.me.repertoire.has(setup) and _usable(view, view.actions.get_action(setup)):
		return Decision.new(setup, DecisionLayer.AI, "sets up the %s" % String(view.actions.get_action(id).name).to_lower())
	return Decision.new(id, DecisionLayer.AI, "swarms" if view.opponent.is_rocked() else "leads")


## A takedown it's about to lead with would be blind (D131): does it feint first?
func _feints_first(view: FightView, id: String) -> bool:
	if not view.actions.has(FightSim.FEINT) or not _usable(view, view.actions.get_action(FightSim.FEINT)) or not view.would_be_blind(id):
		return false
	return view.roll() < setup_chance(view.me)


## Chance to feint before a shot that would be blind: SETUP_BASE + SETUP_PER_IQ × Fight IQ / 100.
static func setup_chance(f: FighterState) -> float:
	return clampf(SETUP_BASE + SETUP_PER_IQ * f.effective_stat("fight_iq") / 100.0, 0.0, 1.0)


## Ticks a feint takes this fighter from start to finish.
func _feint_ticks(view: FightView) -> int:
	var ticks: int = 0
	for phase: String in ActionLibrary.PHASES:
		ticks += view.phase_ticks(FightSim.FEINT, phase)
	return ticks


## Tied up (#15): now and then, work from here. In the clinch: knees, a takedown or throw,
## a guard pull (D128), a collar tie (D129) or a break, picked by weight (breaking by how little
## they like the clinch, and more when their head is tied up). Underneath in full guard: get up, tie up, sweep or a hold. On top: ground and
## pound. In a scramble: back to the feet or the top, by Base. A shot it read gets sprawled on first.
func _tied(view: FightView, layer: DecisionLayer) -> Decision:
	var f: FighterState = view.me
	var d: Decision = _defend(view, layer)
	if d == null:
		d = _guillotine(view, layer)
	if d != null:
		return d
	var position: String = view.position()
	var rate: float = SCRAMBLE_RATE
	var collared: bool = position == PositionLibrary.CLINCH and f.tied_up_ticks > 0
	var holding: bool = position == PositionLibrary.CLINCH and view.opponent.tied_up_ticks > 0
	if position == PositionLibrary.CLINCH:
		rate = CLINCH_RATE * f.work_rate
		if collared or holding:
			rate *= COLLAR_RATE
	elif view.my_role() == PositionLibrary.TOP:
		return _pound(view, layer)
	elif position != PositionLibrary.SCRAMBLE:
		rate = GROUND_RATE * f.work_rate
	var pressed: bool = f.is_rocked() or under_fire(view)
	if position != PositionLibrary.SCRAMBLE and position != PositionLibrary.CLINCH and pressed:
		rate *= GROUND_UNDER_FIRE
	if view.roll() >= rate:
		return DecisionLayer.IDLE
	var base: float = _lean(view, layer, StyleLeanings.BASE) / 100.0
	var range_leaning: float = _leanings[StyleLeanings.RANGE] / 100.0
	var options: Array[String] = []
	var weights: Array[float] = []
	var reasons: Array[String] = []
	for id in _all_moves(view):
		var action: Dictionary = view.actions.get_action(id)
		if action.category == DEFENSE or action.category == "movement" or not _usable(view, action):
			continue
		if f.is_rocked() and action.category == STRIKE:
			continue  # Rocked in the clinch: get out.
		var b: OddsBreakdown = _odds(view, id)
		var w: float = 0.0
		if action.category == SUBMISSION:
			if f.is_rocked() or view.now < _sub_at + SUB_RETRY_TICKS or (b.chance <= _plain_chance(b) and not _any_time(view, action)):
				continue  # Not hurt, not just tried one, and only on the opening the hold looks for.
			w = _score(view, layer, action, b.chance, _plain_chance(b), false) * SUB_WEIGHT * sub_liking(view, layer)
		else:
			w = _score(view, layer, action, _seen_chance(view, action, b), _plain_chance(b), false)
		var reason: String = "works in the clinch"
		match id:
			"clinch_break":
				w *= maxf(CLINCH_BREAK_MIN, 1.0 - base - range_leaning / 2.0)
				reason = "breaks the clinch"
				if collared:
					w *= COLLARED_ESCAPE
					reason = "fights out of the collar tie"
			FightSim.COLLAR_TIE:
				if holding:
					w = 0.0
				elif collared:
					w *= COLLARED_ESCAPE
					reason = "wins the tie back"
				else:
					reason = "ties up the head"
			"get_up":
				w *= maxf(0.0, 1.0 - base) if position == PositionLibrary.SCRAMBLE else 1.0
				if f.is_rocked():
					w *= ROCKED_GET_UP
				reason = "works back to the feet"
			"scramble":
				w *= 1.0 + base
				reason = "scrambles for the top"
			"tie_up":
				w *= TIE_UP_PRESSED if pressed else TIE_UP_CALM
				reason = "ties him up to stop the punches" if pressed else "ties him up"
			"guard_pull":
				w *= GUARD_PULL_WEIGHT * sub_liking(view, layer)
				reason = "pulls guard"
			"sweep":
				reason = "sweeps from the bottom"
			"recover_guard":
				reason = "works back to guard"
			"bridge":
				reason = "bridges to roll him off"
			"escape_back":
				reason = "turns out of the back"
			"take_back":
				reason = "goes for the back"
			_:
				if ActionLibrary.is_throw(action):
					reason = "goes for the %s" % String(action.name).to_lower()
				elif action.category == TAKEDOWN:
					reason = "takes it down from the clinch"
				elif action.category == SUBMISSION:
					reason = "goes for the %s" % String(action.name).to_lower()
				elif holding and action.category == STRIKE:
					reason = "knees from the collar tie"
		if w > 0.0:
			options.append(id)
			weights.append(w)
			reasons.append(reason)
	if options.is_empty():
		return DecisionLayer.IDLE
	var k: int = _pick(view, weights)
	if view.actions.get_action(options[k]).category == SUBMISSION:
		_sub_at = view.now
	return Decision.new(options[k], DecisionLayer.AI, reasons[k])


## A head stuck low in front of them (a shot sprawled on, D126): one look per stuck shot for a
## guillotine, on a chance of GUILLOTINE_CHANCE × sub_liking × (the odds / 50%)².
func _guillotine(view: FightView, layer: DecisionLayer) -> Decision:
	if not view.opponent.sprawled:
		_guillotine_looked = false
		return null
	if _guillotine_looked or view.me.is_rocked() or view.now < _sub_at + SUB_RETRY_TICKS:
		return null
	_guillotine_looked = true
	for id in _all_moves(view):
		var action: Dictionary = view.actions.get_action(id)
		if action.category != SUBMISSION or not _usable(view, action):
			continue
		var b: OddsBreakdown = view.odds_ahead(id, _ticks_to_land(view, id))
		if b.chance <= 0.0:
			continue  # The head is up again by the time it would land.
		var take: float = GUILLOTINE_CHANCE * sub_liking(view, layer) * pow(b.chance / 0.5, 2.0)
		if view.roll() < take:
			_sub_at = view.now
			return Decision.new(id, DecisionLayer.AI, "goes for the %s on the stuck head" % String(action.name).to_lower())
	return null


## How much a fighter likes going for submissions: Submissions / 50 × (1 + Risk / 200).
func sub_liking(view: FightView, layer: DecisionLayer) -> float:
	return view.me.effective_stat("submissions") / 50.0 * maxf(0.0, 1.0 + _lean(view, layer, StyleLeanings.RISK) / 200.0)


## On top (D121): now and then a ground strike, picked like any strike; held while tied up.
## Before that (D130): the opening an escape gives, then now and then a better position or a hold.
func _pound(view: FightView, layer: DecisionLayer) -> Decision:
	var f: FighterState = view.me
	var d: Decision = _punish_escape(view, layer)
	if d == null:
		d = _work_position(view, layer)
	if d != null:
		return d
	if f.tied_up_ticks > 0:
		return DecisionLayer.IDLE
	var rate: float = GNP_RATE * f.work_rate * maxf(0.0, 1.0 + _lean(view, layer, StyleLeanings.PACE) / 100.0)
	if view.opponent.is_rocked():
		rate *= 1.5 + _lean(view, layer, StyleLeanings.RISK) / 200.0
	var tank: float = f.stamina_fraction()
	if tank < TIRED_RATE_BELOW:
		rate *= lerpf(TIRED_RATE_MIN, 1.0, tank / TIRED_RATE_BELOW)
	if view.roll() >= rate:
		return DecisionLayer.IDLE
	var options: Array[String] = []
	var weights: Array[float] = []
	for id in _all_moves(view):
		var action: Dictionary = view.actions.get_action(id)
		if action.category != STRIKE or not _usable(view, action):
			continue
		var b: OddsBreakdown = _odds(view, id)
		var w: float = _score(view, layer, action, _seen_chance(view, action, b), _plain_chance(b), false)
		if w > 0.0:
			options.append(id)
			weights.append(w)
	if options.is_empty():
		return DecisionLayer.IDLE
	var k: int = _pick(view, weights)
	return Decision.new(options[k], DecisionLayer.AI, "pounds the rocked fighter" if view.opponent.is_rocked() else "ground and pound")


## On top (D130): on a chance of ADVANCE_RATE × work rate × position liking, a pass, the mount, the
## back or a hold, picked by weight like the moves underneath (a hold only on its opening, unless it
## needs none: the rear-naked choke). Tied up, passing is harder (the pass's own POSTURE_BROKEN).
## Hunting a hold on *Go for the finish!* (D200): the chance is the call's `hunt.rate` instead, and
## until he has tried one hold since the call, a hold he knows from here is taken over anything
## else, without its opening and whenever he last tried one; with none from here he works to a
## position that has one. Once he has tried it, he's back to his own pace.
func _work_position(view: FightView, layer: DecisionLayer) -> Decision:
	var f: FighterState = view.me
	var liking: float = maxf(ADVANCE_MIN_LIKING, 0.5 + _lean(view, layer, StyleLeanings.BASE) / 100.0)
	var hunting: bool = _hunting(view, layer)
	var rate: float = float(layer.hunt(view).rate) if hunting else ADVANCE_RATE * f.work_rate * liking
	if f.is_rocked() or view.roll() >= rate:
		return null
	var options: Array[String] = []
	var weights: Array[float] = []
	var reasons: Array[String] = []
	var holds: bool = false
	for id in _all_moves(view):
		var action: Dictionary = view.actions.get_action(id)
		if (action.category != GROUND and action.category != SUBMISSION) or not _usable(view, action):
			continue
		var b: OddsBreakdown = _odds(view, id)
		var w: float = 0.0
		if action.category == SUBMISSION and hunting:
			w = _score(view, layer, action, b.chance, _plain_chance(b), false)
			if w > 0.0 and not holds:
				holds = true  # A hold from here: the hunt takes one of these, not a better position.
				options.clear()
				weights.clear()
				reasons.clear()
		elif holds:
			continue
		elif action.category == SUBMISSION:
			if view.now < _sub_at + SUB_RETRY_TICKS or (b.chance <= _plain_chance(b) and not _any_time(view, action)):
				continue
			w = _score(view, layer, action, b.chance, _plain_chance(b), false) * SUB_WEIGHT * sub_liking(view, layer)
		else:
			w = _score(view, layer, action, b.chance, _plain_chance(b), false)
		if w > 0.0:
			options.append(id)
			weights.append(w)
			reasons.append(("goes for the finish: the %s" if hunting else "goes for the %s") % String(action.name).to_lower() if action.category == SUBMISSION else _advance_reason(id))
	if options.is_empty():
		return null
	var k: int = _pick(view, weights)
	if view.actions.get_action(options[k]).category == SUBMISSION:
		_sub_at = view.now
	return Decision.new(options[k], DecisionLayer.AI, reasons[k])


static func _advance_reason(id: String) -> String:
	match id:
		"guard_pass":
			return "passes the guard"
		"take_mount":
			return "steps over to the mount"
		"take_back":
			return "takes the back"
	return "works for a better position"


## The fighter underneath starts to get out (ESCAPING, D130): one look per escape for what it gives
## away (the back, an arm), taken on a chance of ESCAPE_PUNISH × (the odds / 50%)² (a hold also
## × ESCAPE_SUB × sub_liking) if it would land while the opening is there.
func _punish_escape(view: FightView, layer: DecisionLayer) -> Decision:
	var o: FighterState = view.opponent
	if o.is_free() or not view.actions.get_action(o.action_id).flags_self.any(func(e: Dictionary) -> bool: return e.flag == "ESCAPING"):
		_escape_looked = false
		return null
	if _escape_looked or view.me.is_rocked():
		return null
	_escape_looked = true
	for id in _all_moves(view):
		var action: Dictionary = view.actions.get_action(id)
		if (action.category != GROUND and action.category != SUBMISSION) or not _usable(view, action):
			continue
		var hunted: bool = action.category == SUBMISSION and _hunting(view, layer)
		if action.category == SUBMISSION and view.now < _sub_at + SUB_RETRY_TICKS and not hunted:
			continue
		if not action.opportunities.any(func(opp: Dictionary) -> bool: return opp.get("opponent_flag", "") == "ESCAPING"):
			continue
		var b: OddsBreakdown = view.odds_ahead(id, _ticks_to_land(view, id))
		if not _has_bonus(b, "ESCAPING"):
			continue  # Over before it would land.
		var take: float = ESCAPE_PUNISH * pow(b.chance / 0.5, 2.0)
		if hunted:
			take = 1.0  # Hunting a hold (D200): an escape's opening is what he's waiting for.
		elif action.category == SUBMISSION:
			take *= ESCAPE_SUB * sub_liking(view, layer)
		if view.roll() < take:
			if action.category == SUBMISSION:
				_sub_at = view.now
			return Decision.new(id, DecisionLayer.AI, "catches the escape: %s" % String(action.name).to_lower())
	return null


## True while a *Go for the finish!* hunt is on (D200) and he hasn't tried a hold since it was called.
func _hunting(view: FightView, layer: DecisionLayer) -> bool:
	var hunt: Dictionary = layer.hunt(view)
	return not hunt.is_empty() and _sub_at < int(hunt.since)


static func _has_bonus(b: OddsBreakdown, bonus_name: String) -> bool:
	for x: Dictionary in b.bonuses:
		if x.name == bonus_name:
			return true
	return false


## A hold the AI goes for without waiting for an opening (`ai_without_opening`: the rear-naked
## choke, where being on the back is the opening, D130), or only in the positions it lists (the leg
## locks in a scramble, where legs are everywhere, D132).
static func _any_time(view: FightView, action: Dictionary) -> bool:
	var without: Variant = action.submission.get("ai_without_opening", false)
	if without is Array:
		return (without as Array).has(view.position())
	return bool(without)


## True while the opponent is throwing a strike at this fighter (on the ground: ground and pound).
static func under_fire(view: FightView) -> bool:
	var o: FighterState = view.opponent
	return not o.is_free() and view.actions.get_action(o.action_id).category == STRIKE


## The fighter's repertoire plus the moves everyone knows (basic), worked out once a fighter.
func _all_moves(view: FightView) -> Array[String]:
	if _moves_for == view.me:
		return _moves
	_moves_for = view.me
	_moves = view.me.repertoire.duplicate()
	for id in view.actions.basic_ids():
		if not _moves.has(id):
			_moves.append(id)
	_clinch_weapon = false
	for id in _moves:
		var action: Dictionary = view.actions.get_action(id)
		if (action.category == STRIKE or action.category == TAKEDOWN) and action.positions.has(PositionLibrary.CLINCH):
			_clinch_weapon = true
	return _moves


## How much the fighter wants this move right now (0 = not at all).
func _score(view: FightView, layer: DecisionLayer, action: Dictionary, chance: float, plain: float, counter: bool) -> float:
	if chance <= 0.0:
		return 0.0
	var f: FighterState = view.me
	var w: float = float(f.tendencies.get(action.id, 1.0)) * style_weight(_lean(view, layer, StyleLeanings.BASE), action)
	if action.category == STRIKE:
		w *= commitment(_lean(view, layer, StyleLeanings.RISK), view.actions.total_ticks(action.id), _danger.get(_band, DANGER_EVEN))
		w *= _finishing(view, layer, action)
	elif action.category == CLINCH and view.is_standing():
		w *= clinch_liking(_lean(view, layer, StyleLeanings.BASE), _lean(view, layer, StyleLeanings.RANGE)) if _clinch_weapon else 0.0
	w *= stamina_weight(f, action)
	w *= _working_weight(view, action.id)
	if not _caught.is_empty():
		w *= caught_fade(action.id)
	if plain > 0.0:
		w *= pow(chance / plain, OPENING_SHARPNESS)
	if counter:
		w *= FightSim.COUNTER_DAMAGE
	return layer.weight(view, action, w)


## The Base leaning: +100 doubles takedowns and halves strikes, −100 never shoots.
static func style_weight(base_leaning: float, action: Dictionary) -> float:
	var base: float = base_leaning / 100.0
	match action.category:
		TAKEDOWN:
			return maxf(0.0, 1.0 + base)
		STRIKE:
			return 1.0 - base / 2.0
	return 1.0


## How much a fighter likes tying up (0–1): Base / 100 + Range / 200. Grapplers and
## inside fighters clinch; outside strikers don't.
static func clinch_liking(base_leaning: float, range_leaning: float) -> float:
	return clampf(base_leaning / 100.0 + range_leaning / 200.0, 0.0, 1.0)


## Long, committed strikes are thrown less by safe fighters and more by wild ones,
## and less where the opponent's weapons can punish them (`danger`: the opponent's
## share of the threat in this band; 0.5 = even).
static func commitment(risk_leaning: float, ticks: int, danger: float = DANGER_EVEN) -> float:
	var aversion: float = (COMMIT_AVERSION - COMMIT_PER_RISK * risk_leaning / 100.0) * danger / DANGER_EVEN
	return pow(maxf(1.0, float(ticks)) / COMMIT_REF_TICKS, -aversion)


## Expensive moves fade as the tank empties below half.
static func stamina_weight(f: FighterState, action: Dictionary) -> float:
	var tank: float = f.stamina_fraction()
	if tank >= TIRED_RATE_BELOW:
		return 1.0
	var tired: float = (TIRED_RATE_BELOW - tank) / TIRED_RATE_BELOW
	return maxf(TIRED_MIN_WEIGHT, 1.0 - tired * minf(1.0, float(action.stamina_cost) / TIRED_COST_REF))


func _finishing(view: FightView, layer: DecisionLayer, action: Dictionary) -> float:
	if action.strike.target != "head":
		return 1.0
	var o: FighterState = view.opponent
	var hurt: float = o.hurt("head") + (1.0 if o.is_rocked() else 0.0)
	var finish: float = FINISH_BASE + FINISH_BASE * _lean(view, layer, StyleLeanings.RISK) / 100.0
	return 1.0 + finish * hurt


func _working_weight(view: FightView, id: String) -> float:
	var record: float = _working.get(id, WORKING_START)
	var iq: float = clampf(view.me.effective_stat("fight_iq") / 50.0, 0.0, 2.0)
	return maxf(0.1, 1.0 + WORKING_PULL * (record - WORKING_START) * iq)


## Weighted pick, sharper with Fight IQ: weights ^ (1 + Fight IQ / 100).
func _pick(view: FightView, weights: Array[float]) -> int:
	var sharp: float = 1.0 + view.me.effective_stat("fight_iq") / 100.0
	var total: float = 0.0
	var sharpened: Array[float] = []
	for w in weights:
		sharpened.append(pow(w, sharp))
		total += sharpened[-1]
	var roll: float = view.roll() * total
	for n in sharpened.size():
		roll -= sharpened[n]
		if roll < 0.0:
			return n
	return sharpened.size() - 1


## Odds with only what anyone can see (the opponent's state flags), no reads.
func _seen_chance(_view: FightView, action: Dictionary, b: OddsBreakdown) -> float:
	if _needs_opening(action):
		return 0.0
	var bonus: float = 0.0
	for x: Dictionary in b.bonuses:
		if STATE_FLAGS.has(x.name):
			bonus += x.value
	return Contest.chance(b.base, b.attack, b.defense, bonus)


static func _plain_chance(b: OddsBreakdown) -> float:
	return Contest.chance(b.base, b.attack, b.defense)


## True for moves that only work with an opening a read has to spot (the catch-kick).
static func _needs_opening(action: Dictionary) -> bool:
	for opp: Dictionary in action.opportunities:
		if opp.get("required", false) and not STATE_FLAGS.has(opp.get("opponent_flag", "")):
			return true
	return false


## True for a move whose required opening the AI takes on its own when it reads it (`ai_takes`:
## the foot sweep on a lean, D128). Moves without it wait for a call or a rule (the catch, D103).
static func _takes_opening(action: Dictionary) -> bool:
	for opp: Dictionary in action.opportunities:
		if opp.get("required", false) and opp.get("ai_takes", false):
			return true
	return false


## Looks up the distance and band for this choice the first time a step needs them
## (most free ticks need neither).
func _ready_choice(view: FightView) -> void:
	if _choice_ready:
		return
	_choice_ready = true
	_gap = view.distance()
	_band = view.band()
	_reach.clear()
	_land.clear()
	_odds_now.clear()


## The move is legal from this position (A2: never the impossible) and will reach
## when it lands: this fighter stops moving once committed, a free opponent doesn't.
## Only used while choosing (it reads that choice's distance and band).
func _usable(view: FightView, action: Dictionary) -> bool:
	_ready_choice(view)
	var id: String = action.id
	if _reach.has(id):
		return _reach[id]
	var ok: bool = action.positions.has(view.position()) and view.ruleset.allows_action(action) \
		and ActionLibrary.allows_role(action, view.my_role()) and view.positions.leads_somewhere(view.position(), view.my_role(), action)
	if ok:
		if view.position() != PositionLibrary.STANDING or (action.category != STRIKE and action.category != TAKEDOWN):
			ok = action.ranges.has(_band)
		else:
			var gap: float = _gap
			if view.opponent.is_free():
				gap = maxf(Octagon.MIN_GAP, gap - _closing * _ticks_to_land(view, id))
			ok = action.ranges.has(Octagon.band(gap))
	_reach[id] = ok
	return ok


func _ticks_to_land(view: FightView, id: String) -> int:
	_ready_choice(view)
	if not _land.has(id):
		_land[id] = view.ticks_to_land(id)
	return _land[id]


func _odds(view: FightView, id: String) -> OddsBreakdown:
	_ready_choice(view)
	if not _odds_now.has(id):
		_odds_now[id] = view.odds(id)
	return _odds_now[id]


## Keeps track of how fast the opponent is walking toward this fighter.
func _track(view: FightView) -> void:
	var o: FighterState = view.opponent
	if _seen_at >= 0 and view.now > _seen_at:
		var step: Vector2 = (o.pos - _seen_pos) / float(view.now - _seen_at)
		var to_me: Vector2 = view.me.pos - o.pos
		var toward: float = step.dot(to_me.normalized()) if to_me.length() > 0.0 else 0.0
		_closing = lerpf(_closing, toward, CLOSING_MEMORY)
	_seen_at = view.now
	_seen_pos = o.pos


## True once the opponent's current move has registered with this fighter (read, a
## reaction time after it started) and nothing has been decided about it yet.
func _registered(view: FightView) -> bool:
	if _opp.is_empty() or not _opp.read or _opp.decided or view.now < _opp.notice:
		return false
	if view.opponent.action_id != _opp.id:
		_opp = {}
		return false
	return true


func _evade_chance(view: FightView, layer: DecisionLayer) -> float:
	var outside: float = clampf(-_lean(view, layer, StyleLeanings.RANGE) / 100.0, 0.0, 1.0)
	return outside * EVADE_MAX + EVADE_WHEN_HURT * view.me.hurt("head")


## Ticks until the opponent's move is past its active phase (recovering or done).
func _ticks_until_past(view: FightView) -> int:
	for ahead in range(1, 30):
		var phase: String = view.opponent_phase_ahead(ahead)
		if phase == "" or phase == "recovery":
			return ahead
	return 30


## A style leaning as the layer reads it (the gameplan included), looked up again
## every second: leanings only move when the gameplan or a call changes them.
func _lean(view: FightView, layer: DecisionLayer, which: String) -> float:
	if view.now >= _lean_tick + LEAN_EVERY or view.now < _lean_tick:
		_lean_tick = view.now
		for leaning: String in StyleLeanings.LEANINGS:
			_leanings[leaning] = layer.leaning(view, leaning)
	return _leanings[which]


## A call changed how this fighter wants to fight (a focus started or ended): look at
## the leanings and the range plan again now instead of at their next refresh.
func rethink() -> void:
	_lean_tick = -LEAN_EVERY
	_plan_at = -PLAN_EVERY


# --- The feet: the range plan ---------------------------------------------------

## How far apart the fighter wants to be. Rocked fighters get out; a hurt opponent
## gets swarmed; otherwise the range plan, nudged by evasions and resets. Walking in
## through a band where the opponent out-guns them, they want only a little closer
## each tick: the feet stalk instead of charging.
func preferred_distance(view: FightView, layer: DecisionLayer) -> float:
	var f: FighterState = view.me
	_prepare(f)
	_track(view)
	if f.is_rocked():
		_last_want = Octagon.LONG_WITHIN + 1.0
		return _last_want
	var o: FighterState = view.opponent
	if o.is_rocked() or o.is_down():
		_last_want = Octagon.BAND_CENTRES[_swarm_band(view)]
		return _last_want
	var band: String = plan(view, layer)
	if _band_scores.is_empty():
		_last_want = view.distance()  # Nothing reaches from anywhere: hold ground.
		return _last_want
	if not _follow.is_empty() and _follow.kind == TELL:
		band = _nearest_band(view.actions.get_action(_follow.id).ranges, band)
	var range_leaning: float = _lean(view, layer, StyleLeanings.RANGE)
	var pace: float = _leanings[StyleLeanings.PACE]  # _lean just refreshed them all if due.
	var want: float = band_spot(band, range_leaning, pace)
	if view.now < _evade_until:
		want += EVADE_STEP
	elif view.now < _reset_until:
		want += RESET_STEP
	var gap: float = view.distance()
	_feet_at = view.now
	_feet_gap = gap
	_feet_outside = clampf(-range_leaning / 100.0, 0.0, 1.0)
	_feet_cut = clampf(CUT_BASE + CUT_PER_RANGE * range_leaning / 100.0, 0.0, 1.0)
	var here: String = Octagon.band(gap)
	if want < gap and o.is_free() and _danger.get(here, 0.0) > 0.0:
		# Walking into their weapons: stalk, the more carefully the more they out-gun me
		# here, and close fast when they commit.
		var stalk: float = STALK_BASE + STALK_PER_PACE * pace / 100.0
		if losing():
			stalk += STALK_WHEN_LOSING  # Has to take risks to get inside.
		stalk = clampf(stalk, 0.1, 1.0)
		want = maxf(want, gap - (1.0 - (1.0 - stalk) * _danger[here]) * view.step())
	if want > gap + PRESSED_BY and view.now >= _evade_until and view.now >= _reset_until:
		# Pressed. Out of the opponent's weapons, hold the ground; in them, give ground
		# all the way back to the spot before holding again.
		if _danger.get(here, 1.0) >= HOLD_DANGER:
			_giving_ground = true
		if not _giving_ground:
			want = gap
	else:
		_giving_ground = false
	_off_fence = 0.0
	if want > gap:
		_off_fence = _fence_behind(view)
		if _off_fence > 0.0 and _feet_outside > 0.0 and view.now >= _escape_until \
				and (not o.is_free() or view.roll() < ESCAPE_RATE * _feet_outside):
			_escape_until = view.now + ESCAPE_TICKS
			_escape_way = _way_out(view)
		var back: float = _off_fence
		if _feet_outside > 0.0:
			var further_out: float = view.me.pos.length() - o.pos.length()
			back = maxf(back, PIVOT * _feet_outside * clampf(further_out / CENTRE_PULL_OVER, 0.0, 1.0))
		want = gap if view.now < _escape_until and _off_fence > 0.0 else lerpf(want, gap, back)
	_last_want = clampf(want, Octagon.MIN_GAP, Octagon.LONG_WITHIN + 1.0)
	return _last_want


## How close the fence is behind this fighter as they back away: 0 in open space (or
## backing along it), 1 with their back on it.
func _fence_behind(view: FightView) -> float:
	var me: Vector2 = view.me.pos
	if me.length_squared() < CLEAR_OF_FENCE * CLEAR_OF_FENCE:
		return 0.0  # Open space: the fence is further than FENCE_SENSE whichever way they back up.
	var away: Vector2 = me - view.opponent.pos
	if away.length() <= 0.0:
		return 0.0
	var fence: float = Octagon.distance_to_fence(me) - Octagon.BODY_MARGIN
	if fence >= FENCE_SENSE:
		return 0.0
	var into: float = -away.normalized().dot(Octagon.inward(me))
	return clampf(1.0 - fence / FENCE_SENSE, 0.0, 1.0) * maxf(0.0, into)


## This tick's footwork, all in one go (DecisionLayer.plan_feet): the distance
## (preferred_distance), then circling, which way, and cutting off (_plan_steps).
func plan_feet(view: FightView, layer: DecisionLayer, out: FeetPlan) -> void:
	out.want = preferred_distance(view, layer)
	_plan_steps(view, layer, out)


## How much to circle while moving (0–1), as plan_feet works it out.
func circling(view: FightView, layer: DecisionLayer) -> float:
	_plan_steps(view, layer, _feet)
	return _feet.circle


## Which way to circle (±1, or 0 for the side toward the middle), as plan_feet works it out.
func circle_way(view: FightView, layer: DecisionLayer) -> int:
	_plan_steps(view, layer, _feet)
	return _feet.way


## How hard to cut the cage off (0–1), as plan_feet works it out.
func cutting(view: FightView, layer: DecisionLayer) -> float:
	_plan_steps(view, layer, _feet)
	return _feet.cut


## Everything but the distance, after preferred_distance:
##  - Circling (0–1): outside fighters circle off the opponent's line, hard when giving
##    ground, and round the opponent back toward the middle when they're further out
##    (or the opponent is busy throwing); circling out off the fence, all they can;
##    rocked fighters circle away; everyone else walks straight.
##  - Which way: circling out off the fence, the way picked when the escape started;
##    close to the fence, the side toward the middle (0); in open space their own way,
##    thought again every SWITCH_EVERY ticks.
##  - Cutting off (0–1): pressing or holding, step sideways to stay between the opponent
##    and the middle. Not while giving ground, rocked, or swarming a hurt opponent.
func _plan_steps(view: FightView, layer: DecisionLayer, out: FeetPlan) -> void:
	var me: FighterState = view.me
	var o: FighterState = view.opponent
	out.way = 0
	out.cut = 0.0
	if me.is_rocked():
		out.circle = 1.0
		return
	if o.is_rocked() or o.is_down():
		out.circle = 0.0
		return
	if _feet_at != view.now:  # preferred_distance didn't get as far this tick.
		_feet_at = view.now
		_feet_gap = view.distance()
		var range_leaning: float = _lean(view, layer, StyleLeanings.RANGE)
		_feet_outside = clampf(-range_leaning / 100.0, 0.0, 1.0)
		_feet_cut = clampf(CUT_BASE + CUT_PER_RANGE * range_leaning / 100.0, 0.0, 1.0)
		_off_fence = 0.0
	if view.now < _escape_until and _off_fence > 0.0:
		out.circle = 1.0
		out.way = _escape_way
		return
	var pressed: bool = _feet_gap < _last_want - PRESSED_BY
	var free_to_move: bool = pressed and _off_fence <= 0.0
	out.circle = _feet_outside * (CIRCLE_PRESSED if free_to_move else CIRCLE_FREE)
	if out.circle > 0.0:
		var further_out: float = me.pos.length() - o.pos.length()
		if further_out > 0.0 and (free_to_move or not o.is_free()):
			out.circle = maxf(out.circle, _feet_outside * CENTRE_PULL * minf(further_out / CENTRE_PULL_OVER, 1.0))
		if view.now >= _way_at + SWITCH_EVERY or view.now < _way_at:
			_way_at = view.now
			if view.roll() < SWITCH_CHANCE:
				_way = -_way
		if me.pos.length_squared() < CLEAR_OF_SWITCH * CLEAR_OF_SWITCH \
				or Octagon.distance_to_fence(me.pos) - Octagon.BODY_MARGIN >= SWITCH_FENCE:
			out.way = _way  # Near the fence it stays 0: the feet take the side toward the middle.
	if not _giving_ground and not pressed:
		out.cut = _feet_cut


## The way out off the fence: toward the middle when one side clearly is, else a coin flip.
func _way_out(view: FightView) -> int:
	var gap: Vector2 = view.opponent.pos - view.me.pos
	var way: int = FightSim.way_toward_middle(view.me.pos, gap.normalized() if gap.length() > 0.0 else Vector2.RIGHT)
	if way != 0:
		return way
	return 1 if view.roll() < 0.5 else -1


## Where in a band to stand: its centre, Range +100 0.25 m closer and Pace +100 0.15 m
## closer, never outside the band.
static func band_spot(band: String, range_leaning: float, pace_leaning: float) -> float:
	var want: float = Octagon.BAND_CENTRES[band] - range_leaning / 100.0 * RANGE_SHIFT - pace_leaning / 100.0 * PACE_SHIFT
	return clampf(want, BAND_SPOTS[band][0], BAND_SPOTS[band][1])


## The band this fighter plans to fight from: where their weapons beat the
## opponent's (per band: mine − caution × theirs, over my best), tilted by Range and Pace.
## Thought again every 2 s.
func plan(view: FightView, layer: DecisionLayer) -> String:
	if _plan_band != "" and view.now < _plan_at + PLAN_EVERY:
		return _plan_band
	_plan_at = view.now
	var range_leaning: float = _lean(view, layer, StyleLeanings.RANGE)
	var pace: float = _lean(view, layer, StyleLeanings.PACE)
	var risk: float = _lean(view, layer, StyleLeanings.RISK)
	var caution: float = PLAN_CAUTION - PLAN_CAUTION_PER_LEANING * (pace + risk) / 100.0
	var mine: Array[float] = threats(view, view.me, true, layer)
	var theirs: Array[float] = threats(view, view.opponent, false, layer)
	var top: float = mine.max()
	if top <= 0.0:
		_plan_band = Octagon.BAND_MID
		_band_scores = {}
		_danger = {}
		return _plan_band
	var best: String = ""
	var best_score: float = -INF
	for n in BANDS.size():
		_band_scores[BANDS[n]] = (mine[n] - caution * theirs[n]) / top
		_danger[BANDS[n]] = theirs[n] / (mine[n] + theirs[n]) if mine[n] + theirs[n] > 0.0 else 0.0
		if mine[n] <= 0.0:
			continue  # Never plan to stand where nothing reaches.
		var lean: float = float(n - 1)  # long −1, mid 0, pocket +1
		var score: float = _band_scores[BANDS[n]] + lean * (PLAN_RANGE_BIAS * range_leaning + PLAN_PACE_BIAS * pace) / 100.0
		if BANDS[n] == _plan_band:
			score += PLAN_STICKY
		if score > best_score:
			best_score = score
			best = BANDS[n]
	_plan_band = best
	return _plan_band


## How dangerous `f` is from each band (in BANDS order): their best move's expected
## damage per second there (plain odds × damage × the judges' weight for the target,
## × how much they like it), plus a quarter of the rest. `mine` = f is this fighter.
func threats(view: FightView, f: FighterState, mine: bool, layer: DecisionLayer) -> Array[float]:
	var risk: float = _lean(view, layer, StyleLeanings.RISK) if mine else f.style.value(StyleLeanings.RISK)
	var base: float = _lean(view, layer, StyleLeanings.BASE) if mine else f.style.value(StyleLeanings.BASE)
	var other: FighterState = view.opponent if mine else view.me
	var power: float = view.strike_power(f)
	# Plain odds (FightSim.plain_odds) with each effective stat worked out once.
	var attack: Dictionary = {}
	var defense: Dictionary = {}
	var best: Array[float] = [0.0, 0.0, 0.0]
	var total: Array[float] = [0.0, 0.0, 0.0]
	for m: Dictionary in _plan_moves(view, f):
		var action: Dictionary = m.action
		var value: float = TAKEDOWN_PLAN_VALUE
		if action.category == CLINCH:
			value = CLINCH_PLAN_VALUE * clinch_liking(base, f.style.value(StyleLeanings.RANGE))
		elif action.category == STRIKE:
			value = m.damage * power * view.ruleset.damage_multiplier * m.weight * commitment(risk, m.ticks)
		var odds: float = Contest.chance(m.base, _average(f, m.offense, attack), _average(other, m.defense, defense))
		value *= odds * m.tendency * style_weight(base, action)
		value /= m.seconds
		for n: int in m.bands:
			best[n] = maxf(best[n], value)
			total[n] += value
	var out: Array[float] = []
	for n in BANDS.size():
		out.append(best[n] + PLAN_OTHERS * (total[n] - best[n]))
	return out


## The average of these effective stats (as FightSim averages them), remembering each in `seen`.
static func _average(f: FighterState, ids: Array, seen: Dictionary) -> float:
	if ids.is_empty():
		return FighterState.DEFAULT_STAT
	var sum: float = 0.0
	for id: String in ids:
		if not seen.has(id):
			seen[id] = f.effective_stat(id)
		sum += seen[id]
	return sum / ids.size()


## The moves a fighter could threaten with in the range plan (legal strikes and
## takedowns that don't need a read), with what doesn't change in a fight worked out once.
func _plan_moves(view: FightView, f: FighterState) -> Array:
	if _plan_cache.has(f):
		return _plan_cache[f]
	var out: Array = []
	var ids: Array[String] = f.repertoire.duplicate()
	var clinch_weapon: bool = false
	for id in f.repertoire:
		var a: Dictionary = view.actions.get_action(id)
		clinch_weapon = clinch_weapon or ((a.category == STRIKE or a.category == TAKEDOWN) and a.positions.has(PositionLibrary.CLINCH))
	if clinch_weapon:
		for id in view.actions.basic_ids():
			if view.actions.get_action(id).category == CLINCH and not ids.has(id):
				ids.append(id)
	for id in ids:
		var action: Dictionary = view.actions.get_action(id)
		if (action.category != STRIKE and action.category != TAKEDOWN and action.category != CLINCH) \
				or not view.ruleset.allows_action(action) or _needs_opening(action) or not action.positions.has(PositionLibrary.STANDING):
			continue
		var ticks: int = view.actions.total_ticks(id)
		var bands: Array[int] = []
		for n in BANDS.size():
			if action.ranges.has(BANDS[n]):
				bands.append(n)
		var strike: bool = action.category == STRIKE
		out.append({ "id": id, "action": action, "ticks": ticks, "bands": bands,
			"seconds": maxf(float(ticks) / FightClock.TICKS_PER_SECOND, 0.1),
			"weight": Judging.TARGET_WEIGHTS[action.strike.target] if strike else 1.0,
			"damage": float(action.strike.base_damage) if strike else 0.0,
			"base": Contest.base_for(action), "offense": action.stats.offense, "defense": action.stats.defense,
			"tendency": float(f.tendencies.get(id, 1.0)) })
	_plan_cache[f] = out
	return out


## Where to swarm a hurt opponent from: the closest band of the best head shot.
func _swarm_band(view: FightView) -> String:
	var best_id: String = ""
	var best: float = 0.0
	for id in view.me.repertoire:
		var action: Dictionary = view.actions.get_action(id)
		if action.category != STRIKE or action.strike.target != "head" or not view.ruleset.allows_action(action):
			continue
		var value: float = view.strike_damage(id) * view.plain_odds(id)
		if value > best:
			best = value
			best_id = id
	if best_id == "":
		return Octagon.BAND_POCKET
	return _nearest_band(view.actions.get_action(best_id).ranges, Octagon.BAND_POCKET)


## Of these ranges, the band closest to `band` (ties go to the closer-in band).
static func _nearest_band(ranges: Array, band: String) -> String:
	if ranges.has(band):
		return band
	var at: int = BANDS.find(band)
	var best: String = band
	var gap: int = 99
	for n in range(BANDS.size() - 1, -1, -1):
		if ranges.has(BANDS[n]) and absi(n - at) < gap:
			gap = absi(n - at)
			best = BANDS[n]
	return best


# --- What the fighter sees and remembers -----------------------------------------

## Every fight event, as this fighter sees it: the opponent's moves (read or not),
## how their own moves went, their tells' triggers, and the rounds.
func on_event(view: FightView, event: FightEvent, layer: DecisionLayer) -> void:
	_prepare(view.me)
	var me: int = view.index
	match event.type:
		FightEvent.ACTION_PHASE:
			if event.actor == me and (event.data.phase == "telegraph" or event.data.phase == "windup"):
				_last_move = event.data.action_id
			if event.data.phase == "telegraph":
				if event.actor == me:
					_chain = _chain if event.data.get("why", "") == "combination" else 0
				else:
					_saw_start(view, event, layer)
		FightEvent.ACTION_ENDED:
			if event.actor == me:
				_own_ended(view, event, layer)
			elif not _opp.is_empty() and _opp.id == event.data.action_id:
				_opp = {}
		FightEvent.STRIKE_LANDED, FightEvent.STRIKE_MISSED:
			_scored(event, me)
		FightEvent.GRAPPLE_WON, FightEvent.GRAPPLE_STOPPED:
			if event.actor != me and _last_move != "" and _timed_on_me(view, event):
				_caught[_last_move] = int(_caught.get(_last_move, 0)) + 1
				rethink()
		FightEvent.STRIKE_DEFENDED:
			if event.actor == me and event.data.worked and not view.me.is_rocked():
				# Off the slip, or while he's still on one leg from the check (D180).
				var off: String = "off the check" if event.data.has("leg") else "off the slip"
				_follow = { "kind": COMBO, "until": event.tick + FightSim.SLIP_COUNTER_TICKS, "last": "", "why": off }
		FightEvent.ROCKED, FightEvent.KNOCKDOWN:
			if event.actor == me:
				_follow = {}
				_chain = 0
				if event.type == FightEvent.ROCKED:
					_cover_roll = view.roll()  # Does he shell up this time (_cover)?
				_round_taken += Judging.KNOCKDOWN_POINTS if event.type == FightEvent.KNOCKDOWN else Judging.ROCKED_POINTS
			else:
				_round_dealt += Judging.KNOCKDOWN_POINTS if event.type == FightEvent.KNOCKDOWN else Judging.ROCKED_POINTS
		FightEvent.ROUND_ENDED:
			_new_round()
		FightEvent.POSITION_CHANGED:
			_moved_position()
			if event.actor >= 0 and event.data.roles[event.actor] == PositionLibrary.TOP:
				if event.actor == me:
					_round_dealt += Judging.TAKEDOWN_POINTS
				else:
					_round_taken += Judging.TAKEDOWN_POINTS
	if not _tells.has(event.type):
		return
	for tell: Dictionary in _tells[event.type]:
		if _triggers.matches(tell.trigger, event, me) and not view.me.is_rocked() and view.roll() < tell.chance * caught_fade(tell.action):
			_follow = { "kind": TELL, "id": tell.action, "until": event.tick + tell.ticks, "reason": "tell: %s" % tell.name }


## The opponent started a move: does this fighter read it, and when does it register?
func _saw_start(view: FightView, event: FightEvent, layer: DecisionLayer) -> void:
	var f: FighterState = view.me
	var id: String = event.data.action_id
	var action: Dictionary = view.actions.get_action(id)
	if action.category == FightSim.FEINT:
		return  # Nothing to read: whether it bites is the feint's own roll (D131).
	var telegraph: int = view.opponent.phase_ticks_left if view.opponent.phase == "telegraph" else 0
	var factor: float = clampf(1.0 + READ_PER_TELEGRAPH_TICK * (telegraph - READ_TELEGRAPH_NORMAL), READ_FACTOR_MIN, READ_FACTOR_MAX)
	var chance: float = layer.read_chance(view, action, (READ_BASE + READ_PER_IQ * f.effective_stat("fight_iq") / 100.0) * factor)
	if action.category == TAKEDOWN or action.category == CLINCH:
		chance += wise_bonus(event.tick)
		_grapples_seen.append(event.tick)
	if view.opponent.blind_shot:
		chance += BLIND_READ  # Nothing to hide it (D131).
	if view.opponent.combo_step > 0:
		chance += COMBO_SEEN_READ * view.combo_seen_before()  # He's seen this one before (D133).
	if f.bit_ticks > 0:
		chance *= BIT_READ  # Still reacting to the feint (D131).
	if f.is_rocked():
		chance *= ROCKED_READ
	# Fighters step in turn each tick: a move started after this fighter's step is
	# first seen next tick, so the reaction time counts from then (fair to both corners).
	var seen: int = event.tick + (1 if event.actor > view.index else 0)
	_opp = { "id": id, "category": action.category, "at": event.tick,
		"notice": seen + f.reaction_ticks(), "read": view.roll() < chance, "decided": false }


## How keen the fighter still is on this move after the opponent kept timing shots on it (CAUGHT_FADE).
func caught_fade(id: String) -> float:
	return pow(CAUGHT_FADE, int(_caught.get(id, 0))) if not _caught.is_empty() else 1.0


## A takedown that worked because of the move this fighter was in: a catch (it needed the
## opening that move gives) or a shot timed into its wind-up or recovery (a counter).
func _timed_on_me(view: FightView, event: FightEvent) -> bool:
	var action: Dictionary = view.actions.get_action(event.data.action_id)
	if action.category != TAKEDOWN:
		return false
	if _needs_opening(action):
		return true
	for bonus: Dictionary in event.data.get("odds", {}).get("bonuses", []):
		if bonus.name == "counter":
			return true
	return false


## The extra chance to read a grappling move started at `tick`, from the ones seen before it.
func wise_bonus(tick: int) -> float:
	while not _grapples_seen.is_empty() and _grapples_seen[0] < tick - WISE_TICKS:
		_grapples_seen.pop_front()
	return minf(WISE_MAX, WISE_READ * _grapples_seen.size())


## One of its own moves finished: maybe the next strike of a combination, maybe a reset.
func _own_ended(view: FightView, event: FightEvent, layer: DecisionLayer) -> void:
	var f: FighterState = view.me
	var action: Dictionary = view.actions.get_action(event.data.action_id)
	if not _follow.is_empty() or action.category != STRIKE or f.is_rocked() or f.work_rate <= 0.0:
		return
	var more: bool = f.combo_next_until >= event.tick
	if more and f.combo_runs:
		return  # Called as a whole: it runs on (next_in_combo).
	if _chain < COMBO_MAX and view.roll() < combo_chance(view, layer, action):
		# Inside a drilled combination, going on means its next move (if it still reaches then).
		_follow = { "kind": COMBO, "until": event.tick + COMBO_WINDOW_TICKS, "last": action.id, "combo": f.combo_id if more else "" }
		_follow_step = f.combo_step + 1
		return
	_chain = 0
	var outside: float = clampf(-_lean(view, layer, StyleLeanings.RANGE) / 100.0, 0.0, 1.0)
	if view.roll() < outside * RESET_MAX:
		_reset_until = event.tick + RESET_TICKS_MIN + int(view.roll() * (RESET_TICKS_MAX - RESET_TICKS_MIN + 1))


## The drilled combination (the profile's `combos`, D133) these two strikes are the start of,
## when the fighter knows one: the 1-2 when the cross follows the jab. Of several (the 1-2
## and the 1-2-3), weighted by their moves' tendencies and how often each has been thrown
## already (COMBO_FRESH). "" when the fighter knows none that starts this way.
func _pick_combo(view: FightView, first: String, second: String) -> String:
	var f: FighterState = view.me
	if f.combos.is_empty():
		return ""
	var options: Array[String] = []
	var weights: Array[float] = []
	for id in f.combos:
		if not view.combos.has(id) or view.combos.move(id, 0) != first or view.combos.move(id, 1) != second:
			continue
		var moves: Array = view.combos.get_combo(id).moves
		var w: float = 0.0
		for move: String in moves:
			w += float(f.tendencies.get(move, 1.0))
		w = w / moves.size() * pow(COMBO_FRESH, int(_combos_used.get(id, 0)))
		if w > 0.0:
			options.append(id)
			weights.append(w)
	if options.is_empty():
		return ""
	return options[0] if options.size() == 1 else options[_pick(view, weights)]


## The next move of a combination called or commanded as a whole (D133): it runs on while the
## next move still reaches and the fighter isn't hurt or tied up. null when it's over or it
## can't go on.
func next_in_combo(view: FightView) -> Decision:
	var f: FighterState = view.me
	if f.combo_id == "" or f.is_rocked() or not view.is_standing() or view.opponent.is_down():
		return null
	var id: String = view.combos.move(f.combo_id, f.combo_step + 1)
	if id == "":
		return null
	_choice_ready = false
	if not _usable(view, view.actions.get_action(id)):
		return null
	_chain += 1
	var d := Decision.new(id, DecisionLayer.AI, "combination")
	d.combo = f.combo_id
	d.combo_step = f.combo_step + 1
	d.combo_runs = true
	return d


## Chance to chain another strike after this one: (0.15 + 0.45 × skill / 100) × (1 + Pace / 200).
func combo_chance(view: FightView, layer: DecisionLayer, action: Dictionary) -> float:
	var f: FighterState = view.me
	var skill: float = 0.0
	var count: int = 0
	for stat: String in action.stats.offense:
		if stat != "power" and stat != "speed":
			skill += f.effective_stat(stat)
			count += 1
	skill = skill / count if count > 0 else float(FighterState.DEFAULT_STAT)
	var chance: float = (COMBO_BASE + COMBO_PER_SKILL * skill / 100.0) * (1.0 + _lean(view, layer, StyleLeanings.PACE) / 200.0)
	if f.stamina_fraction() < TIRED_COMBO_BELOW:
		chance *= 0.5
	if crowded(view) and not view.opponent.is_rocked():
		chance *= CROWDED_COMBO
	return chance


## True when the fighter thinks they're losing: this round is going the other way, or
## they're behind on the rounds so far.
func losing() -> bool:
	return _rounds_up < 0 or _round_taken > _round_dealt * ROUND_SENSE


## True when the fighter is closer in than they plan to be, in a band where the
## opponent's weapons beat theirs.
func crowded(view: FightView, band: String = "") -> bool:
	if band == "":
		band = view.band()
	return _plan_band != "" and BANDS.find(band) > BANDS.find(_plan_band) and _band_scores.get(band, 0.0) < 0.0


## A strike landed or was defended: remember what's working, and keep score.
func _scored(event: FightEvent, me: int) -> void:
	if event.data.has("reason") and event.data.reason != "defended":
		return  # Fell short or nobody to hit: says nothing about the move. Checked or slipped (D180) is a miss.
	var landed: bool = event.type == FightEvent.STRIKE_LANDED
	var points: float = float(event.data.get("damage", 0)) * Judging.TARGET_WEIGHTS.get(event.data.target, 1.0)
	if event.actor == me:
		var record: float = _working.get(event.data.action_id, WORKING_START)
		_working[event.data.action_id] = record + WORKING_MEMORY * ((1.0 if landed else 0.0) - record)
		_round_dealt += points
	else:
		_round_taken += points


## The fight moved (a takedown, a clinch, getting up): whatever was being read or
## followed up is gone, and the feet start fresh.
func _moved_position() -> void:
	_opp = {}
	_follow = {}
	_chain = 0
	_reset_until = -1
	_evade_until = -1
	_giving_ground = false
	_escape_until = -1
	_closing = 0.0
	_seen_at = -1
	_met_advance = false


## Between rounds: score the round on their own reckoning and start fresh.
func _new_round() -> void:
	if _round_dealt > _round_taken * ROUND_SENSE:
		_rounds_up += 1
	elif _round_taken > _round_dealt * ROUND_SENSE:
		_rounds_up -= 1
	_round_dealt = 0.0
	_round_taken = 0.0
	_opp = {}
	_follow = {}
	_chain = 0
	_reset_until = -1
	_evade_until = -1
	_giving_ground = false
	_escape_until = -1
	_plan_band = ""
	_band_scores = {}
	_danger = {}
	_closing = 0.0
	_seen_at = -1
	_met_advance = false


## Reads the fighter's tells once: which events can set them off, and which moves they set up.
func _prepare(f: FighterState) -> void:
	if _ready_for == f:
		return
	_ready_for = f
	_tells = {}
	_setups = {}
	_plan_cache = {}
	for t: Dictionary in f.tells:
		if not _triggers.has(t.trigger):
			continue
		var trigger: Dictionary = _triggers.get_trigger(t.trigger)
		if trigger.type != TriggerLibrary.EVENT:
			continue
		var entry := { "trigger": t.trigger, "action": t.action, "chance": float(t.chance),
			"ticks": int(t.within_ms) / FightClock.TICK_MS, "name": String(trigger.name).to_lower() }
		if not _tells.has(trigger.event):
			_tells[trigger.event] = []
		_tells[trigger.event].append(entry)
		var setup: String = _triggers.own_start_action(t.trigger)
		if setup != "":
			_setups[t.action] = setup
