class_name FightSim
extends RefCounted
## Headless fight simulation core (docs/01-fight-engine.md §2, issue #12).
##
## Each tick() is 100 ms of fight time: apply that tick's commands, then advance
## both fighters (action phases, fighter AI), emitting FightEvents. All
## randomness comes from one seeded RNG, so the same seed + command log always
## produces the same fight (see FightSim.replay).
##
## The standing game (#13, docs/01 §3, §5, §8): fighters move in a 2D octagon,
## distance bands decide which strikes reach, the fence pins whoever backs onto
## it, and clean head shots can rock, drop or finish. Rounds are scored 10-point
## must by three judges (Judging).
##
## Every contest uses Contest.chance on effective stats (docs/11 §3), and Speed
## and Kicking change how long telegraphs and wind-ups last (§3.3). Strike,
## takedown and sprawl events carry an OddsBreakdown saying where the odds came from.
##
## The sim owns time, movement and resolution; what each fighter tries comes from
## their DecisionLayer (commands → live calls → drilled rules → AI, docs/01 §6.0),
## which reads the fight through a FightView. The fight runs under a Ruleset.
##
## Positions (#34, docs/01 §4): one Situation both fighters share says where the
## fight is (phase, named position, each fighter's role). Moves between positions
## come from the position data (PositionLibrary), and the fighters' cage spot
## carries through, so a takedown on the fence lands on the fence.
##
## Clinch, takedowns and the trimmed ground game (#15, docs/01 §21): a takedown,
## clinch or ground move makes contact as its active phase starts (range, a
## required opening such as ONE_LEG, and its odds are fixed then) and is rolled as
## the active phase ends; in between the defender can sprawl on it or knee into it.
## A win moves the fight by the position data; a near miss can end in a scramble.
## Each position drains stamina, scores control for the judges and scales strikes.
##
## Submissions (D126, docs/01 §25): a guillotine, triangle or armbar locks in like any
## grapple (contact, then the roll). A hold that locks moves the fight to the submission
## position and is fought for in beats: a danger meter goes up or down each second of
## fight time until the defender taps (a submission win) or gets out.
signal event_emitted(event: FightEvent)

## Speed (and Kicking, for kick telegraphs) shortens or stretches telegraph and
## wind-up by up to 20% (docs/11 §3.3); being tired stretches them up to another
## 30% (docs/01 §8). Rounded to whole ticks.
const MAX_TIMING_SHIFT: float = 0.2
const TIMED_PHASES: Array[String] = ["telegraph", "windup"]

## Each fighter's corner at the bell: 3.5 m apart, out of range.
const START_POSITIONS: Array[Vector2] = [Vector2(-1.75, 0.0), Vector2(1.75, 0.0)]
## Walking speed in m/s: 0.8 + 1.2 × average of Footwork and Speed / 100 (50/50 → 1.4).
const MOVE_BASE: float = 0.8
const MOVE_PER_STAT: float = 1.2
## Moving costs stamina (D96): this much per second at full pace, × (share of full pace)²,
## so walking in is cheap and running all night isn't.
const MOVE_STAMINA_PER_S: float = 0.6
## Range and cage changes are announced once they've held this long (0.5 s), so
## shuffling across a line isn't news. Flags and odds always use the exact state.
const ANNOUNCE_AFTER_TICKS: int = 5
## A strike that `stops` a move (a knee into a shot) stops it in these phases, before it's done.
const STOPPABLE_PHASES: Array[String] = ["telegraph", "windup", "active"]
## Hitting someone mid-commitment (wind-up or recovery, docs/01 §5) is a counter.
const COUNTER_PHASES: Array[String] = ["windup", "recovery"]
const COUNTER_BONUS: float = 0.10
const COUNTER_DAMAGE: float = 1.3
## Striking defence (D180, docs/01 §38). A check or a slip has to be up (in its active phase) as
## the strike lands: one roll on its odds, and either way it's spent. A checked kick lands on the
## shin: the kicker's kicking leg (his rear leg) takes CHECK_KICKER_SHARE of the kick, the checker's
## lead leg CHECK_SHIN_SHARE, and the kicker is on one leg CHECK_STUCK_TICKS longer (ONE_LEG).
const CHECK_KICKER_SHARE: float = 0.6
const CHECK_SHIN_SHARE: float = 0.2
const CHECK_STUCK_TICKS: int = 2
## A slipped punch: for SLIP_COUNTER_TICKS the slipper's strikes get SLIP_COUNTER_BONUS ("off the slip").
const SLIP_COUNTER_TICKS: int = 6
const SLIP_COUNTER_BONUS: float = 0.15
## Below a quarter tank the hands drop (docs/01 §5: HANDS_LOW from fatigue).
const HANDS_LOW_BELOW: float = 0.25
## A clean shot stops the feet for a moment: 1 tick + 1 per 4 damage (a jab 2, a
## body kick 3, a head kick 4), so landing on someone who walks in stops the advance.
const STAGGER_BASE: int = 1
const STAGGER_PER_DAMAGE: float = 0.25

## Head shots: shock = damage × (1 + head hurt) / (6 + 0.12 × Chin).
## Rock chance = (shock − 0.6) × 0.5, up to 60%. Rocked again while rocked = knockdown.
const ROCK_THRESHOLD_BASE: float = 6.0
const ROCK_THRESHOLD_PER_CHIN: float = 0.12
const ROCK_FROM: float = 0.6
const ROCK_SLOPE: float = 0.5
const ROCK_MAX: float = 0.6
## Liver shots (D143): a body shot thrown standing or in the clinch. Shock = damage × (1 +
## body hurt) / (8 + 0.16 × Durability); liver chance = (shock − 0.8) × 0.2, up to 25%. It takes
## him LIVER_DELAY_TICKS later (frozen meanwhile): down LIVER_DOWN_TICKS (a knockdown, but his
## head is clear: not rocked), LIVER_STAMINA gone, then winded with his hands low for LIVER_WINDED_TICKS.
const LIVER_THRESHOLD_BASE: float = 8.0
const LIVER_THRESHOLD_PER_DURABILITY: float = 0.16
const LIVER_FROM: float = 0.8
const LIVER_SLOPE: float = 0.2
const LIVER_MAX: float = 0.25
const LIVER_DELAY_TICKS: int = 5
const LIVER_DOWN_TICKS: int = 30
const LIVER_STAMINA: float = 20.0
const LIVER_WINDED_TICKS: int = 50
## A leg giving out (D144): a low kick landing on a front leg already this hurt (FighterState.leg_hurt)
## can buckle it: chance (leg hurt − 0.4) × damage × 0.03, up to 30%. He drops for LEG_DOWN_TICKS (a
## knockdown, head clear) and limps on it for the rest of the fight. A front leg past SWITCH_FROM,
## worse than the back one by SWITCH_MARGIN, makes him switch stance to hide it.
const BUCKLE_FROM: float = 0.35
const BUCKLE_PER_DAMAGE: float = 0.03
const BUCKLE_MAX: float = 0.3
const LEG_DOWN_TICKS: int = 10
const SWITCH_FROM: float = 0.5
const SWITCH_MARGIN: float = 0.2
## Flash knockdowns (D145): a head shot that rocks a man who wasn't rocked drops him there and then
## when it was big enough: chance (shock − 1.2) × 0.4, up to 35%. A counter (×1.3 damage), a head kick or an
## overhand gets there; a jab never does.
const FLASH_FROM: float = 1.2
const FLASH_SLOPE: float = 0.4
const FLASH_MAX: float = 0.35
## Rocked lasts 4 s × (1.5 − Recovery / 100); a knockdown keeps them down 2 s, then rocked.
const ROCKED_TICKS: int = 40
const DOWN_TICKS: int = 20
## KO on a knockdown: 15% + (shock − 1) × 50%, 5–80%, × (1.5 − Heart / 100).
const KO_BASE: float = 0.15
const KO_SLOPE: float = 0.5
const KO_MIN: float = 0.05
const KO_MAX: float = 0.8
## The referee stops it (D120): three knockdowns in a round; health gone (head fully hurt);
## or a rocked fighter taking this many clean head shots without answering.
const TKO_KNOCKDOWNS: int = 3
const STOP_UNANSWERED: int = 2
## Underneath on the ground, a fighter who isn't answering the ground and pound is
## stopped too, sooner the more hurt they are: after STOP_UNANSWERED + GROUND_STOP_PER_HEALTH
## × health clean head shots in a row (16 fresh, 9 at half health, 5 at 20%).
const GROUND_STOP_PER_HEALTH: float = 14.0
## Amateur referees step in sooner: the health line rises by early_stoppage_bias × this
## (adult amateur 0.3 → at 15% health), and they wait for one shot fewer.
const STOP_BIAS_HEALTH: float = 0.5
## More ground and pound (D270, docs/01 §41). Covering up underneath (`ground_cover`) halves the
## head damage like the standing cover-up, but on the ground it isn't answering: the referee still
## counts the shots. A strike's `through_cover` is the share that gets through the gloves instead
## (the hammerfist's 0.8). A landed ground strike to the body with `hands_down_ms` brings his
## hands down (HANDS_LOW) that long. In mount, a clean head shot on a man covering up or rocked
## makes him turn away and give up his back on a chance of TURN_AWAY_BASE × (1.5 − Fight IQ / 100)
## × (1 + head hurt); the referee's count carries on.
const GROUND_COVER := "ground_cover"
const TURN_AWAY := "turn_away"
const TURN_AWAY_BASE: float = 0.12

## Tied up (clinch or ground), the fighters' centres are this close, on the spot
## where the one being taken down or tied up stood.
const TANGLED_GAP: float = 0.4
## Sprawled on, the shooter is stuck under the sprawl, head low, for this many ticks
## on top of the shot's recovery (D29: a stuffed shot gets punished).
const SPRAWL_STUCK_TICKS: int = 5
## Feints and blind shots (D131, docs/01 §29). The feint (everyone knows it) makes the
## opponent bite (BIT_ON_FEINT) on its own roll at the end of its active phase.
const FEINT := "feint"
## A strike or feint that ends sets the fighter up for this many ticks: a takedown started
## in that window isn't blind.
const SET_UP_TICKS: int = 5
## Each of the fighter's own feints in the last FEINT_MEMORY_TICKS makes the next one
## FEINT_REPEAT less likely to bite: the same feint over and over stops working.
const FEINT_MEMORY_TICKS: int = 300
const FEINT_REPEAT: float = 0.1
## A blind shot that gets sprawled on is stuck this many ticks longer (more knees, a
## guillotine), and a blind shot that's stuffed (sprawled on or defended) costs this much more stamina.
const BLIND_STUCK_TICKS: int = 5
const BLIND_STUFFED_STAMINA: float = 5.0
## Openings that don't set a shot up: the fence stops the sprawl going back, it doesn't hide the shot.
const NOT_A_SET_UP := { "BACK_TO_CAGE": true }
## Combinations (D133, docs/01 §31): a drilled run of strikes (data/combos). Each move after
## the first flows out of the last: its telegraph is COMBO_FLOW_TICKS shorter (harder to read),
## and it's LEVEL_CHANGE likelier to land when it goes to another target than the last one
## (head, then the legs: his eyes are up). Each time the opponent has already seen this
## combination in the fight, its follow-ups are COMBO_SEEN less likely to land (up to
## COMBO_SEEN_MAX times). The next move is due within COMBO_WINDOW_TICKS of the last one
## ending, or the combination is over; a clean shot taken mid-combination breaks it.
const COMBO_FLOW_TICKS: int = 1
const LEVEL_CHANGE: float = 0.2
const COMBO_SEEN: float = 0.05
const COMBO_SEEN_MAX: int = 3
const COMBO_WINDOW_TICKS: int = 2
## Takedowns, clinch and ground moves: they make contact when their active phase starts
## and are rolled when it ends.
const GRAPPLES := { "takedown": true, "clinch": true, "ground": true, "submission": true }
## The collar tie (D129, docs/01 §27): a clinch move whose `ties_up_ms` breaks the opponent's posture.
const COLLAR_TIE := "collar_tie"
## The cage clinch (D220, docs/01 §39). The drive to the fence (a clinch move whose `drives_m`
## walks the opponent back), and two ways off it whose `turns` swaps the two round: the spin-off
## (and away: the clinch position sends it to standing) and turning him onto the fence (the clinch goes on).
const FENCE_DRIVE := "fence_drive"
const SPIN_OFF := "spin_off"
const TURN_HIM := "turn_him"
## The flag of the man held with his back on the fence in the clinch (held_on_fence).
const HELD_ON_FENCE := "HELD_ON_FENCE"
## A drive that works walks the clinch back this fast (m/s), until the opponent's back is on
## the fence or the drive's `drives_m` is used up.
const DRIVE_SPEED: float = 1.5
## Held on the fence in the clinch, the man with his back to it carries the other's weight:
## this much more stamina a second than the clinch already costs (0.4, `clinch.json`).
const FENCE_HOLD_DRAIN_PER_S: float = 0.1
## A shot at a man on the fence that half works leaves the shooter on him, tied up against the
## fence, this often (the "pressed" transition); otherwise it's the scramble, as anywhere else.
const PRESSED_CHANCE: float = 0.25
const COVERED := "COVERED"
## A locked submission is fought for in beats, one every STRUGGLE_BEAT_TICKS (D126). Each beat
## the attacker wins with Contest.chance(STRUGGLE_BASE, the hold's offense stats, its defense
## stats, ± the corners' struggle calls) and the danger moves STRUGGLE_STEP up, or down.
## At SUB_TAP the defender taps; at 0, or after STRUGGLE_BEATS beats, they're out of it.
const STRUGGLE_BEAT_TICKS: int = 10
const STRUGGLE_BASE: float = 0.5
const STRUGGLE_STEP: float = 20.0
const STRUGGLE_BEATS: int = 5
const SUB_TAP: float = 100.0
## Danger at lock-in: the hold's start_danger + this × (attack − defense stats), kept within 10–90.
const START_DANGER_PER_EDGE: float = 0.5
const START_DANGER_MIN: float = 10.0
const START_DANGER_MAX: float = 90.0
## Each beat costs both fighters this much stamina (a struggle call adds its own).
const STRUGGLE_STAMINA: float = 2.0
## A hold that gets this close to the tap counts as impact for a 10-8 (D120), like a rock.
const NEAR_FINISH: float = 80.0
## In open space a circling fighter keeps their direction unless one way is clearly
## more open (by this much, in metres toward the middle).
const CIRCLE_SIDE_DEADBAND: float = 0.3
## Cutting off the cage (D107, D230): the cut fades in as the opponent goes from the cutter's
## reach to CUT_FULL metres out from the middle: it's the fence that traps them, so deep in
## open space there's no way out to shut. The reach is CUT_FROM at Cage cutting 50, CUT_EARLY
## closer to the middle at 100 (and further out below 50): good cutters start shutting the
## exits while the opponent still has room. On a Cut the cage! call (FeetPlan.anywhere) it's
## CUT_CALLED_FROM, or the cutter's own reach if that's closer in.
const CUT_FROM: float = 3.0
const CUT_EARLY: float = 0.5
const CUT_CALLED_FROM: float = 1.0
const CUT_FULL: float = 4.0
## Aiming at the exit, not the man (D230, D233): the cutter steps the way (one of CUT_TURNS,
## in degrees off straight at him) that leaves the opponent's best escape route worth least
## (EscapeRoutes), thought again every ROUTES_EVERY ticks. The routes the opponent has been
## drifting along are quicker for him; the cutter's read of that drift catches up with a change of
## direction by CUT_READ_BASE + CUT_READ_PER_SHARE × the cutter's Cage cutting share (vs
## the opponent's Footwork) of the gap each tick: a reversal fools a poor reader for longer.
## Bursting out (D234): shut in, an outside fighter sprints round the cutter, his walking pace
## and BURST_EXTRA more of it × his footwork edge (poor feet barely get any quicker), at
## BURST_STAMINA × what the steps would cost.
const BURST_EXTRA: float = 0.3
const BURST_STAMINA: float = 2.0
const CUT_TURNS: Array[float] = [0.0, 45.0, -45.0, 90.0, -90.0]
const ROUTES_EVERY: int = 5
## Holding the door shut (D230, D233): with every way out shut, the cutter mirrors him instead,
## stepping toward the spot between him and the middle, as far from him as now, led CUT_LEAD_TICKS
## ahead of his drift as the cutter reads it.
const CUT_LEAD_TICKS: float = 5.0
const CUT_READ_BASE: float = 0.1
const CUT_READ_PER_SHARE: float = 0.5
## A fighter who reaches the fence within CUT_OFF_TICKS of the opponent's cut working, after at
## least CUT_OFF_FROM_TICKS in the centre, was cut off onto it (FightSim.cut_offs): walked from
## open space onto the fence, not just stepping in and out by it.
const CUT_OFF_TICKS: int = 10
const CUT_OFF_FROM_TICKS: int = 30
## Bitten on a feint (D131), a fighter's feet move this share of a step: weight back and hands up,
## he plants for a beat, which is what a cutter herding him with a feint wants (D230).
const BIT_FEET: float = 0.4
## Selling a door shut (D235, docs/01 §20.7): a feint that bites while fighter k is cutting the
## opponent off and the man still has a way out sells that way shut. For SOLD_TICKS (the bite's
## 1 s and another second) he reads it as shut and the other way round as his way out
## (way_out, burst_way), so a reverse or a burst takes him back into the cut.
const SOLD_TICKS: int = 20
## A feinter stands still while he feints, so "cutting him off" means his cut was working within
## this many ticks of the feint biting (the feint's telegraph and wind-up, and a tick to spare).
const SOLD_CUT_TICKS: int = 5
## What counts as circling for the time reported after a fight (D119): a step where at
## least this much of it goes round the opponent (an outside fighter's everyday drift
## sideways, 0.25 × how far outside they lean, doesn't count).
const CIRCLING_FROM: float = 0.4
## Walking pace and the footwork contest are worked out again every this many ticks.
const FEET_EVERY: int = 5

const RESULT_KO := "ko"
const RESULT_TKO := "tko"
const RESULT_SUB := "submission"
## How a TKO came about when it wasn't the referee: the corner threw in the towel (D31).
const STOPPED_BY_TOWEL := "towel"
## Why the referee stopped it (FIGHT_ENDED `why`, D120).
const STOP_HEALTH := "health"
const STOP_SHOTS := "unanswered"
const STOP_KNOCKDOWNS := "knockdowns"

var fight_seed: int
var clock: FightClock
var actions: ActionLibrary
## The coach calls a live_call command can name (data/calls, #16).
var calls: CallLibrary
## The combinations fighters can throw (data/combos, D133).
var combos: ComboLibrary
var ruleset: Ruleset
var positions: PositionLibrary
## Where the fight is: phase, position and both roles (shared, docs/01 §4).
var situation := Situation.new()
var fighters: Array[FighterState]
## Each fighter's decision step, and the view of the fight it reads.
var decisions: Array[DecisionLayer] = []
var views: Array[FightView] = []
## Each fighter's corner when it makes its own calls (the AI corner, the harness's coaching
## bots); null for a corner that only passes on the player's calls (docs/01 §22.7).
var corners: Array[Corner] = [null, null]
## Ticks processed since the opening bell. The next tick() processes tick `now`.
var now: int = 0
var events: Array[FightEvent] = []
var command_log: Array[FightCommand] = []

## Per judge, per fighter: points so far, e.g. [[20, 18], [19, 19], [20, 18]].
var judge_totals: Array = []

var _rng := RandomNumberGenerator.new()
## Who steps first on the fight's first tick (0 = red). After that the two take turns, a tick
## each, so neither corner keeps the edge of stepping second (D253, docs/01 §2.5). Only the
## corner check sets it to 1, to play a fight's mirror.
var first_step: int = 0
## This tick's order: who steps first, then the other (set at the start of each tick).
var step_order: Array[int] = [0, 1]
var _pending: Array[FightCommand] = []
var _fight_over: bool = false
var _round_points: Array[float] = [0.0, 0.0]  # effective striking this round, by who scored it
var _round_knockdowns: Array[int] = [0, 0]  # knockdowns scored this round
var _round_impact: Array[int] = [0, 0]  # rocks and knockdowns scored this round (Judging: a 10-8 needs one)
var _round_aggression: Array[float] = [0.0, 0.0]  # attacks thrown + metres walked forward this round
var _round_control: Array[int] = [0, 0]  # ticks this round the opponent spent pinned on the fence
var _round_grappling: Array[float] = [0.0, 0.0]  # the part of _round_points from takedowns, positions and time on top
## The whole fight to the last bell, for PRIDE's judges (D141, Judging.whole_fight_pick):
## {finish: [red, blue], control: [...], aggression: [...]}.
var _fight_scores: Dictionary = { Judging.FINISH: [0.0, 0.0], Judging.CONTROL: [0.0, 0.0], Judging.AGGRESSION: [0.0, 0.0] }
## The submission being fought for (D126), or empty: {attacker, action_id, danger, beats,
## next_at (tick of the next beat), from and from_roles (where it was locked from), near}.
var _hold: Dictionary = {}
## A drive to the fence under way (D220), or empty: {by (the driver), dir (unit vector, the
## way he walks the other man), left (metres still to go)}.
var _drive: Dictionary = {}
## What the current position does to each fighter every tick (its data, worked out
## when the position changes): stamina drained, judges' control points, strike damage ×.
var _drain: Array[float] = [0.0, 0.0]
var _control: Array[float] = [0.0, 0.0]
var _damage_scale: Array[float] = [1.0, 1.0]
## Ticks each fighter's feints reached their active phase, oldest first (FEINT_REPEAT).
var _feints: Array[Array] = [[], []]
## Per fighter, combination id → times they've seen the opponent throw it this fight (COMBO_SEEN).
var _combos_seen: Array[Dictionary] = [{}, {}]
## Announced state for range (slot 0) and each fighter's cage proximity (slots 1
## and 2), see _announce: what was last announced, what it's turning into, and for
## how many ticks. Arrays rather than dictionaries: this runs every tick.
var _shown: Array[String] = ["", "", ""]
var _candidate: Array[String] = ["", "", ""]
var _held: Array[int] = [0, 0, 0]
## Each fighter's footwork the last time they moved: the distance they wanted, how
## much they circled (0–1) and which way (±1), and how hard they cut the cage off (0–1).
var _wants: Array[float] = [0.0, 0.0]
var _circling: Array[float] = [0.0, 0.0]
var _cutting: Array[float] = [0.0, 0.0]
var _circle_sign: Array[float] = [1.0, 1.0]
## Fight time (ticks) each fighter spent circling (a step at least CIRCLING_FROM round
## the opponent) and cutting off the cage (pressing or holding with the cut working: the
## opponent out past their reach), reported after the fight (D119). Read-only; never changes the fight.
var circling_ticks: Array[int] = [0, 0]
var cutting_ticks: Array[int] = [0, 0]
## Times each fighter cut the opponent off onto the fence (D230): the opponent got near the
## fence while this fighter's cut was working. Read-only.
var cut_offs: Array[int] = [0, 0]
## The last tick each fighter's cut was working (cut_offs), and the opponent's sideways
## drift as each fighter reads it (m per tick, CUT_READ_BASE).
var _cut_at: Array[int] = [-1000, -1000]
## The tick each fighter's cage proximity last turned to the centre (CUT_OFF_FROM_TICKS).
var _centre_since: Array[int] = [0, 0]
var _drift: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
## Escape routes (D233): each cutter's read of the opponent's ways out, when it was last walked,
## and the step it picked (degrees off straight at him, CUT_TURNS). For the fighter being cut
## off: which way round the cutter his best open route goes (±1, 0 = none) and whether every
## route that keeps room off the fence is shut, as of the cutter's last read.
var _routes: Array[EscapeRoutes] = [EscapeRoutes.new(), EscapeRoutes.new()]
var _routes_at: Array[int] = [-1000, -1000]
var _cut_turn: Array[float] = [0.0, 0.0]
var _way_out: Array[int] = [0, 0]
var _least_bad: Array[int] = [0, 0]
## The last tick each fighter burst out (D234).
var _burst_at: Array[int] = [-1000, -1000]
var _shut_in: Array[bool] = [false, false]
## Reported after the fight (D233), read-only: times each fighter got back to the middle after
## being cut off onto the fence (cage_escapes vs the opponent's cut_offs), ticks each spent shut in
## (every way out shut while being cut off), and damage each took while cutting the cage off.
var cage_escapes: Array[int] = [0, 0]
var shut_in_ticks: Array[int] = [0, 0]
var cut_damage_taken: Array[int] = [0, 0]
## Cut off onto the fence and not back in the middle yet (cage_escapes).
var _trapped: Array[bool] = [false, false]
## Selling a door shut (D235): for the man being cut off, the way he's been sold shut (±1, 0 =
## none), until when, and the tick it was sold; the tick he last turned back off a sold door
## and which sale that was (one turn counted a sale).
var _sold_way: Array[int] = [0, 0]
var _sold_until: Array[int] = [-1000, -1000]
var _sold_at: Array[int] = [-1000, -1000]
var _turned_at: Array[int] = [-1000, -1000]
var _turned_sale: Array[int] = [-1000, -1000]
## Reported after the fight (D235), read-only, by the cutter: doors each fighter sold shut with a
## feint, and how many times the man then turned back into the cut off one.
var doors_sold: Array[int] = [0, 0]
var turned_back: Array[int] = [0, 0]
## Resetting to the centre (D290), reported after the fight, read-only: walks back to the middle each
## fighter started, how many got there, and how many a cage cutter stopped by shutting him in.
var resets: Array[int] = [0, 0]
var resets_made: Array[int] = [0, 0]
var resets_cut: Array[int] = [0, 0]
## Whether each fighter was resetting on their last step (D290).
var _resetting: Array[bool] = [false, false]
## How far each fighter moved on their last tick (zero when they stood still).
var _strides: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
## Walking pace (m per tick), footwork-contest share and footwork edge per fighter, as of _feet_at.
var _feet_at: int = -FEET_EVERY
var _step: Array[float] = [0.0, 0.0]
var _share: Array[float] = [0.5, 0.5]
var _feet_edge: Array[float] = [1.0, 1.0]
## Cutting the cage (D230), as of _feet_at: the Cage cutting vs Footwork contest share, and
## how far out from the middle the cut starts working (CUT_FROM − CUT_EARLY × (Cage cutting − 50) / 50).
var _cut_share: Array[float] = [0.5, 0.5]
var _cut_reach: Array[float] = [CUT_FROM, CUT_FROM]


## `p_rules` is a Ruleset (null = pro rules), or a round count with
## `p_round_seconds` for a short pro-rules test fight.
func _init(p_seed: int, p_fighters: Array[FighterState], p_actions: ActionLibrary, p_rules: Variant = null, p_round_seconds: int = 300) -> void:
	assert(p_fighters.size() == 2, "a fight has two fighters")
	fight_seed = p_seed
	_rng.seed = p_seed
	fighters = p_fighters
	actions = p_actions
	positions = PositionLibrary.shared()
	calls = CallLibrary.shared()
	combos = ComboLibrary.shared()
	if p_rules is Ruleset:
		ruleset = p_rules
	elif p_rules is int:
		ruleset = Ruleset.pro_with(p_rules, p_round_seconds)
	else:
		ruleset = Ruleset.load_id()
	clock = FightClock.new(ruleset.rounds, ruleset.round_seconds, ruleset.round_lengths)
	for i in fighters.size():
		decisions.append(DecisionLayer.new())
		views.append(FightView.new(self, i))
	for j in Judging.JUDGES:
		judge_totals.append([0, 0])
	_to_corners()


## Rebuilds a fight from its seed and command log. Pass freshly made fighters set
## up the same way as in the original fight (FighterState is mutated by a fight);
## from_record() does that from fighter ids.
static func replay(p_seed: int, p_fighters: Array[FighterState], p_actions: ActionLibrary, commands: Array, p_rules: Variant = null, p_round_seconds: int = 300) -> FightSim:
	var sim := FightSim.new(p_seed, p_fighters, p_actions, p_rules, p_round_seconds)
	for entry: Variant in commands:
		sim.submit(entry if entry is FightCommand else FightCommand.from_dict(entry))
	sim.run_to_end()
	return sim


## Everything needed to replay this fight (docs/04 §2.2, #32): seed, the
## data/fighters ids, the rules and the command log. Plain data, safe to save as JSON.
func record() -> Dictionary:
	var ids: Array[String] = []
	for f in fighters:
		assert(f.id != "", "only fighters made from data/fighters can be recorded")
		ids.append(f.id)
	return { "seed": fight_seed, "fighters": ids, "ruleset": ruleset.id, "rounds": ruleset.rounds,
		"round_seconds": ruleset.round_seconds, "commands": command_log_as_dicts() }


## Replays a record() with fresh fighters made from the same profiles.
static func from_record(rec: Dictionary, roster: FighterLibrary, p_actions: ActionLibrary) -> FightSim:
	var rules: Ruleset = Ruleset.load_id(rec.ruleset)
	rules.rounds = int(rec.rounds)
	rules.round_seconds = int(rec.round_seconds)
	return replay(int(rec.seed), roster.make_pair(rec.fighters[0], rec.fighters[1]), p_actions, rec.commands, rules)


## Queues a command for its tick. Commands for ticks already processed are refused.
func submit(command: FightCommand) -> bool:
	if command.tick < now or _fight_over:
		return false
	# Keep pending sorted by tick, stable for equal ticks, so order is reproducible.
	var at: int = _pending.size()
	while at > 0 and _pending[at - 1].tick > command.tick:
		at -= 1
	_pending.insert(at, command)
	return true


func is_over() -> bool:
	return _fight_over


func tick() -> void:
	if _fight_over:
		return
	var first: int = first_at(now)
	step_order[0] = first
	step_order[1] = 1 - first
	for v in views:
		v.now = now
	for i in corners.size():
		if corners[i] != null:
			for id: String in corners[i].due(views[i], decisions[i].calls.voice(now)):
				submit(FightCommand.live_call(now, i, id))
	_apply_commands()
	if _fight_over:  # The towel came in.
		now += 1
		return
	for i in step_order:
		_advance_fighter(i)
		if _fight_over:
			now += 1
			return
	if not _hold.is_empty() and now >= int(_hold.next_at):
		_struggle_beat()
		if _fight_over:
			now += 1
			return
	if not situation.is_standing():
		for k in 2:
			_round_points[k] += _control[k]
			_round_grappling[k] += _control[k]
	_drive_step()
	_update_space()
	if clock.tick():
		_end_round()
	now += 1


## Who steps first on this tick: first_step on even ticks, the other on odd ones (D253).
func first_at(tick: int) -> int:
	return first_step if tick % 2 == 0 else 1 - first_step


## How many more turns fighter i takes before the other fighter's turn `ahead` ticks from now:
## `ahead`, one more if i still has this tick's turn to come, one fewer if on that tick i steps
## after the other (D253). Fighter i's phase and timers count down on i's own turns, so this is
## what the other fighter can count on seeing then.
func turns_before(i: int, ahead: int) -> int:
	var other: int = 1 - i
	return ahead + (1 if first_at(now) == other else 0) - (1 if first_at(now + ahead) == other else 0)


## True when fighter `a` steps after fighter `b` this tick (step_order): what `a` starts in it,
## `b` first sees on the next one.
func steps_later(a: int, b: int) -> bool:
	return step_order.find(a) > step_order.find(b)


## Fighter i's latest step on their feet (zero if their latest turn moved them nowhere): one
## step whichever of the two stepped first this tick (D253).
func last_stride(i: int) -> Vector2:
	return _strides[i]


func distance() -> float:
	return fighters[0].pos.distance_to(fighters[1].pos)


## "out", "long", "mid" or "pocket" (Octagon) standing; "clinch" once tied up.
func band() -> String:
	if not situation.is_standing():
		return Octagon.BAND_CLINCH
	return Octagon.band(distance())


## "centre", "near" or "pinned" for fighter i.
func cage_proximity(i: int) -> String:
	return Octagon.proximity(fighters[i].pos, distance())


## True while fighter i is held with his back on the fence in the clinch (D220, HELD_ON_FENCE):
## pinned, and nearer the fence than the man holding him. Tied up along the fence both can be
## pinned (BACK_TO_CAGE); only the one with his back to it is held.
func held_on_fence(i: int) -> bool:
	if situation.position != PositionLibrary.CLINCH:
		return false
	var gap: float = Octagon.distance_to_fence(fighters[i].pos)
	return gap - Octagon.BODY_MARGIN < Octagon.PINNED_WITHIN and gap < Octagon.distance_to_fence(fighters[1 - i].pos)


func run_to_end() -> void:
	while not _fight_over:
		tick()


func events_as_dicts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in events:
		out.append(e.to_dict())
	return out


func command_log_as_dicts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in command_log:
		out.append(c.to_dict())
	return out


func _apply_commands() -> void:
	while not _pending.is_empty() and _pending[0].tick == now:
		var command: FightCommand = _pending.pop_front()
		var reason: String = _reject_reason(command)
		if reason != "":
			_emit(FightEvent.COMMAND_REJECTED, command.fighter, { "command": command.type, "reason": reason })
		elif command.type == FightCommand.LIVE_CALL:
			var i: int = command.fighter
			_emit(FightEvent.CALL_HEARD, i, decisions[i].hear_call(views[i], call_for(command)))
			for n: Dictionary in decisions[i].take_notes():
				_emit(n.type, i, n.data)
		elif command.type == FightCommand.SET_RULE:
			var i: int = command.fighter
			decisions[i].set_rule(views[i], int(command.data.slot), String(command.data.rule_id), float(command.data.drilled))
			for n: Dictionary in decisions[i].take_notes():
				_emit(n.type, i, n.data)
		elif command.type == FightCommand.THROW_TOWEL:
			command_log.append(command)
			_finish(1 - command.fighter, RESULT_TKO, STOPPED_BY_TOWEL)
			return
		else:
			fighters[command.fighter].queued_action_id = command.data.action_id
			fighters[command.fighter].queued_combo = String(command.data.get("combo", ""))
		command_log.append(command)


func _reject_reason(command: FightCommand) -> String:
	if command.fighter < 0 or command.fighter >= fighters.size():
		return "unknown fighter"
	var id: String = command.data.get("action_id", "")
	match command.type:
		FightCommand.QUEUE_ACTION:
			return why_not(command.fighter, id)
		FightCommand.LIVE_CALL:
			var call: Dictionary = call_for(command)
			if call.is_empty():
				return "unknown call"
			if decisions[command.fighter].calls.voice(now) < float(call.voice_cost):
				return "no voice left"  # D28: every call costs voice; feasibility is checked once it's processed.
			return ""
		FightCommand.THROW_TOWEL:
			return ""
		FightCommand.SET_RULE:
			if clock.tick_in_round != 0:
				return "rules are set before a round"
			return decisions[command.fighter].rules.check(views[command.fighter], int(command.data.get("slot", 0)),
				String(command.data.get("rule_id", "")), float(command.data.get("drilled", -1.0)))
	return "unknown command"


## The call a live_call command names: a data/calls id, or a move from data/actions
## called straight (CallLibrary.bare: tests, the debug console). Empty when it's neither.
func call_for(command: FightCommand) -> Dictionary:
	var id: String = command.data.get("call_id", command.data.get("action_id", ""))
	if calls.has(id):
		return calls.get_call(id)
	if actions.has(id):
		return CallLibrary.bare(actions.get_action(id))
	return {}


## "" when fighter i could start this action now, else why not.
func why_not(i: int, id: String) -> String:
	if not actions.has(id):
		return "unknown action"
	var action: Dictionary = actions.get_action(id)
	if not ruleset.allows_action(action):
		return "not allowed under %s rules" % ruleset.name
	if not action.positions.has(situation.position):
		return "not possible from this position"
	if not ActionLibrary.allows_role(action, situation.role(i)) or not positions.leads_somewhere(situation.position, situation.role(i), action):
		return "not possible from the %s" % situation.role(i)
	return ""


## One draw from the fight's seeded RNG, for decision sources (through FightView).
func roll() -> float:
	return _rng.randf()


## The RNG behind roll(), for the fighters' views to draw from directly (FightView.roll).
func rng_for_views() -> RandomNumberGenerator:
	return _rng


func _advance_fighter(i: int) -> void:
	var f: FighterState = fighters[i]
	f.regen_tick()
	f.spend_stamina(_drain[i])
	_strides[i] = Vector2.ZERO
	if f.is_down():
		f.down_ticks -= 1
		if f.down_ticks == 0:
			_emit(FightEvent.GOT_UP, i)
		return
	if f.liver_ticks > 0:
		f.liver_ticks -= 1
		if f.liver_ticks == 0:
			_liver_fold(i)
		return  # Frozen: it's coming.
	if f.winded_ticks > 0:
		f.winded_ticks -= 1
	if f.is_rocked():
		f.rocked_ticks -= 1
		if f.rocked_ticks == 0:
			f.unanswered = 0
			_emit(FightEvent.RECOVERED, i)
	if f.tied_up_ticks > 0:
		f.tied_up_ticks -= 1
	if f.bit_ticks > 0:
		f.bit_ticks -= 1
	if f.stagger_ticks > 0:
		f.stagger_ticks -= 1
	var calls_here: LiveCalls = decisions[i].calls
	if calls_here.active:
		decisions[i].update_calls(views[i])
		f.attention = calls_here.attention
	if not f.is_free():
		f.phase_ticks_left -= 1
		if f.phase_ticks_left <= 0:
			_next_phase(i)
	if f.is_free() and _hold.is_empty():
		var seen: FightView = views[i]
		if situation.is_standing():
			var feet: FeetPlan = decisions[i].plan_feet(seen)
			_count_reset(i, feet)
			if f.stagger_ticks <= 0:
				_move(i, feet.want, feet.circle, feet.cut, feet.way, feet.anywhere, feet.burst, feet.home)
		var decision: Decision = decisions[i].decide(seen)
		if not decision.is_idle():
			_start_action(i, decision.action_id, decision)
			decisions[i].started(seen, decision)
			f.attention = calls_here.attention
	for n: Dictionary in decisions[i].take_notes():
		_emit(n.type, i, n.data)


# --- Space: moving, range and the cage (docs/01 §3) --------------------------

## Counts fighter i's resets to the centre (D290) and announces each one as it starts.
func _count_reset(i: int, feet: FeetPlan) -> void:
	if feet.reset_ended == FighterAI.ENDED_MADE:
		resets_made[i] += 1
	elif feet.reset_ended == FighterAI.ENDED_CUT:
		resets_cut[i] += 1
	if feet.resetting and not _resetting[i]:
		resets[i] += 1
		_emit(FightEvent.RESET, i, { "why": feet.reset_why })
	_resetting[i] = feet.resetting


## Whether fighter i was walking back to the middle to reset on their last step (D290).
func is_resetting(i: int) -> bool:
	return _resetting[i]


## How far apart fighter i wants to be (their decision step decides; the feet follow).
func preferred_distance(i: int) -> float:
	return decisions[i].preferred_distance(views[i])


## The distance fighter i was walking toward, how much they circled (0–1) and how hard
## they cut the cage off (0–1), the last time they moved. Read-only, for the debug cage
## view (docs/01 §20.1); 0 before the first step.
func last_wanted_distance(i: int) -> float:
	return _wants[i]


func last_circling(i: int) -> float:
	return _circling[i]


func last_cutting(i: int) -> float:
	return _cutting[i]


## Whether fighter i's cut was working on their last step (the opponent out past their reach, D230).
func is_cutting(i: int) -> bool:
	return _cut_at[i] >= now - 1


## Which way round the opponent fighter i last circled (±1).
func circle_sign(i: int) -> int:
	return 1 if _circle_sign[i] > 0.0 else -1


func move_speed(f: FighterState) -> float:
	return MOVE_BASE + MOVE_PER_STAT * (f.effective_stat("footwork") + f.effective_stat("speed")) / 200.0


## Share of the footwork battle fighter i wins (Footwork vs Footwork): pressing,
## how well they cut the cage off; on the move, how well they stop it being cut off.
func footwork_share(i: int) -> float:
	return Contest.chance(Contest.STRIKE_BASE, fighters[i].effective_stat("footwork"), fighters[1 - i].effective_stat("footwork"))


## Metres fighter i walks in one tick.
func step_length(i: int) -> float:
	_refresh_feet()
	return _step[i]


## How much of a chase or a cut a fighter's feet get done against the opponent's
## (D107), from their Footwork contest share: doubled and squared, at most 1. Even
## feet get all of it; 50 against 70 (a 30% share) gets 0.36, and 70 against 50 all of it.
static func footwork_edge(share: float) -> float:
	return minf(1.0, pow(2.0 * share, 2.0))


## Walking pace and the footwork contest change only with fatigue and damage, so
## they're worked out every FEET_EVERY ticks rather than every tick.
func _refresh_feet() -> void:
	if now < _feet_at + FEET_EVERY and now >= _feet_at:
		return
	_feet_at = now
	# As move_speed() and footwork_share(), with each fighter's Footwork worked out once.
	var footwork: Array[float] = [fighters[0].effective_stat("footwork"), fighters[1].effective_stat("footwork")]
	for i in fighters.size():
		_step[i] = (MOVE_BASE + MOVE_PER_STAT * (footwork[i] + fighters[i].effective_stat("speed")) / 200.0) / FightClock.TICKS_PER_SECOND
		_share[i] = Contest.chance(Contest.STRIKE_BASE, footwork[i], footwork[1 - i])
		_feet_edge[i] = footwork_edge(_share[i])
		var cutting: float = fighters[i].effective_stat("cage_cutting")
		_cut_share[i] = Contest.chance(Contest.STRIKE_BASE, cutting, footwork[1 - i])
		_cut_reach[i] = CUT_FROM - CUT_EARLY * (cutting - 50.0) / 50.0


## The feet: step toward the preferred distance and circle as much as the fighter
## wants (0–1) and which `way` (0 = toward the middle, see way_toward_middle), never
## faster than their walking pace. The fence stops the part of a step that goes into
## it; the rest slides along it. Pressing someone who is on the move, they aim where
## that fighter is going: how far ahead is the presser's share of a Footwork contest.
## Chasing someone who's getting away, they keep up only as well as their footwork
## edge lets them. Cutting the cage off (`cut`, 0–1, D107, D230) they don't follow:
## they step across toward the spot between the opponent and the middle, ahead of the
## way the opponent is drifting, as much as their Cage cutting share against the
## opponent's Footwork lets them, and close the distance with what's left of the step
## (the diagonal step). Good cutters start further from the fence; `anywhere` (the
## Cut the cage! call) starts at CUT_CALLED_FROM.
func _move(i: int, want: float, circle: float, cut: float = 0.0, way: int = 0, anywhere: bool = false, burst: bool = false, home: bool = false) -> void:
	var f: FighterState = fighters[i]
	var o: FighterState = fighters[1 - i]
	var from: Vector2 = f.pos
	var gap: Vector2 = o.pos - f.pos
	var apart: float = gap.length()
	var toward: Vector2 = gap.normalized() if apart > 0.0 else Vector2.RIGHT
	var step: float = step_length(i)
	if burst:
		step *= 1.0 + BURST_EXTRA * _feet_edge[i]
		_burst_at[i] = now
	var radial: float = clampf(apart - want, -step, step)
	if radial > 0.0 and _strides[1 - i].dot(toward) > 0.0:
		radial *= _feet_edge[i]  # Chasing someone who's getting away.
	_wants[i] = want
	_circling[i] = circle
	_cutting[i] = cut
	_drift[i] = _drift[i].lerp(_strides[1 - i], CUT_READ_BASE + CUT_READ_PER_SHARE * _cut_share[i])
	var across: Vector2 = Vector2.ZERO
	if cut > 0.0:
		var out: float = o.pos.length()
		var reach: float = minf(_cut_reach[i], CUT_CALLED_FROM) if anywhere else _cut_reach[i]
		if out > reach:
			var fade: float = clampf((out - reach) / maxf(CUT_FULL - reach, 0.01), 0.0, 1.0)
			across = _cut_step(i, toward, apart, step) * cut * fade * _cut_share[i]
			cutting_ticks[i] += 1
			_cut_at[i] = now
			if _shut_in[1 - i]:
				shut_in_ticks[1 - i] += 1
	var stride: Vector2 = toward * radial
	if across == Vector2.ZERO and radial > 0.0 and _strides[1 - i] != Vector2.ZERO:
		var ahead: Vector2 = o.pos + _strides[1 - i] * (apart / step) * (1.0 - _share[1 - i])
		if ahead != f.pos:
			stride = (ahead - f.pos).normalized() * radial
	if across != Vector2.ZERO:
		# Shut the exit first, close the distance with what's left of the step.
		stride = stride.limit_length(sqrt(maxf(0.0, step * step - across.length_squared()))) + across
	if home:
		# Back to the middle to reset (D290): straight there, leaving out any of the step that goes at him.
		stride = (-f.pos).limit_length(step)
		var at_him: float = stride.dot(toward)
		if at_him > 0.0:
			stride -= toward * at_him
	if circle > 0.0:
		if circle >= CIRCLING_FROM and way != 0 and way == -_sold_way[i] and now < _sold_until[i] \
				and circle_sign(i) == _sold_way[i] and _turned_sale[i] != _sold_at[i]:
			_turned_sale[i] = _sold_at[i]  # Turned back off the door he was sold shut (D235).
			_turned_at[i] = now
			turned_back[1 - i] += 1
		stride += _circle_side(i, toward, way) * step * circle
		if circle >= CIRCLING_FROM:
			circling_ticks[i] += 1
	if stride.length() > step:
		stride = stride.normalized() * step
	if f.bit_ticks > 0:
		stride *= BIT_FEET
	# The fence stops the part of the step that goes into it; the rest slides along it.
	f.pos = Octagon.keep_inside(f.pos + stride)
	var effort: float = (f.pos - from).length() / step if step > 0.0 else 0.0
	f.spend_stamina(MOVE_STAMINA_PER_S * effort * effort * (BURST_STAMINA if burst else 1.0) / FightClock.TICKS_PER_SECOND)
	var after: Vector2 = f.pos - o.pos
	if after.length() < Octagon.MIN_GAP:
		f.pos = Octagon.keep_inside(o.pos + (after.normalized() if after.length() > 0.0 else -toward) * Octagon.MIN_GAP)
	_strides[i] = f.pos - from
	_round_aggression[i] += maxf(0.0, apart - (o.pos - f.pos).length()) * Judging.AGGRESSION_PER_METRE


## Shoves fighter k straight back from the opponent (a landed teep), up to the fence.
func _push(k: int, metres: float) -> void:
	var away: Vector2 = fighters[k].pos - fighters[1 - k].pos
	if away.length() > 0.0:
		fighters[k].pos = Octagon.keep_inside(fighters[k].pos + away.normalized() * metres)


## The sideways part of the step that shuts the opponent's best way out (D233): every
## ROUTES_EVERY ticks fighter k walks the opponent's escape routes, tries each of CUT_TURNS
## and keeps the one that leaves the best route worth least (straight at him when none is
## better), and reads for the opponent which way out is open. Once every way is shut, he holds
## it shut: mirroring him on the inside line (CUT_LEAD_TICKS). At most a step.
func _cut_step(k: int, toward_opponent: Vector2, apart: float, step: float) -> Vector2:
	var f: FighterState = fighters[k]
	if now >= _routes_at[k] + ROUTES_EVERY or now < _routes_at[k]:
		_routes_at[k] = now
		var o: FighterState = fighters[1 - k]
		var routes: EscapeRoutes = _routes[k]
		routes.walk(o.pos, _step[1 - k], _drift[k])
		var best: float = INF
		for turn in CUT_TURNS:
			var worth: float = routes.best_worth(Octagon.keep_inside(f.pos + toward_opponent.rotated(deg_to_rad(turn)) * step), step)
			if worth < best - 0.001:
				best = worth
				_cut_turn[k] = turn
		routes.read(f.pos, step, -toward_opponent)
		_way_out[1 - k] = routes.way
		_least_bad[1 - k] = routes.least_shut
		_shut_in[1 - k] = not routes.open
	var side := Vector2(-toward_opponent.y, toward_opponent.x)
	if _shut_in[1 - k]:
		var o: Vector2 = fighters[1 - k].pos
		var out: float = o.length()
		if out <= 0.01:
			return Vector2.ZERO
		var spot: Vector2 = o - o / out * apart + _drift[k] * CUT_LEAD_TICKS
		return side * clampf((spot - f.pos).dot(side), -step, step)
	return side * (toward_opponent.rotated(deg_to_rad(_cut_turn[k])).dot(side) * step)


## Which way out fighter i's best open escape route goes round the opponent (±1, as
## circle_sign), 0 when none is, and whether he's shut in (every way out shut), as of the
## opponent's last read while cutting him off (D233). Only meaningful while is_cutting(1 − i).
## While a door's sold shut (D235), the other way round is the way out as he sees it.
func way_out(i: int) -> int:
	return -_sold_way[i] if is_sold(i) else _way_out[i]


func is_shut_in(i: int) -> bool:
	return _shut_in[i] and is_cutting(1 - i)


## Shut in, which way round the cutter the least shut route goes (±1): where to burst out (D234).
func burst_way(i: int) -> int:
	if is_sold(i):
		return -_sold_way[i]
	return _least_bad[i] if _least_bad[i] != 0 else circle_sign(i)


## Whether fighter i has a way out open that a feint could sell shut (D235): the cutter's true read.
func door_open(i: int) -> bool:
	return _way_out[i] != 0 and not is_sold(i) and is_cutting(1 - i)


## Whether fighter i still thinks a way out is shut that a feint sold him (D235).
func is_sold(i: int) -> bool:
	return now < _sold_until[i]


## The last tick fighter i turned back off a door sold shut (D235).
func turned_back_at(i: int) -> int:
	return _turned_at[i]


## Whether fighter i burst out on their last step (D234).
func is_bursting(i: int) -> bool:
	return _burst_at[i] >= now - 1


## Which way fighter k circles: sideways (relative to the opponent), `way` if the
## fighter picked one, else toward the middle of the cage. In open space, where
## neither way is clearly better, they keep going the way they were, so they don't jitter.
func _circle_side(k: int, toward_opponent: Vector2, way: int = 0) -> Vector2:
	var side := Vector2(-toward_opponent.y, toward_opponent.x)
	if way != 0:
		_circle_sign[k] = float(way)
	else:
		var lean: float = side.dot(-fighters[k].pos)  # As in way_toward_middle.
		if absf(lean) > CIRCLE_SIDE_DEADBAND:
			_circle_sign[k] = 1.0 if lean > 0.0 else -1.0
	return side * _circle_sign[k]


## For someone at `me` facing along `toward_opponent`: +1 if sideways one way round
## the opponent (the left-hand perpendicular) heads toward the middle of the cage, −1 if
## the other way does, 0 if neither clearly does (by CIRCLE_SIDE_DEADBAND metres).
static func way_toward_middle(me: Vector2, toward_opponent: Vector2) -> int:
	var lean: float = Vector2(-toward_opponent.y, toward_opponent.x).dot(-me)
	if absf(lean) <= CIRCLE_SIDE_DEADBAND:
		return 0
	return 1 if lean > 0.0 else -1


func _update_space() -> void:
	var apart: float = distance()
	_announce(0, Octagon.band(apart) if situation.is_standing() else Octagon.BAND_CLINCH, FightEvent.RANGE_CHANGED, FightEvent.NO_ACTOR, "band")
	for i in fighters.size():
		var proximity: String = Octagon.proximity(fighters[i].pos, apart)
		var was: String = _shown[1 + i]
		_announce(1 + i, proximity, FightEvent.CAGE_CHANGED, i, "proximity")
		if _shown[1 + i] != was:
			if was == Octagon.CAGE_CENTRE and now - _centre_since[i] >= CUT_OFF_FROM_TICKS and now - _cut_at[1 - i] <= CUT_OFF_TICKS:
				cut_offs[1 - i] += 1
				_trapped[i] = true
			if _shown[1 + i] == Octagon.CAGE_CENTRE:
				_centre_since[i] = now
				if _trapped[i] and situation.is_standing():
					cage_escapes[i] += 1  # Back to the middle after being cut off (D233).
				_trapped[i] = false
		if not situation.is_standing():
			_trapped[i] = false  # Tied up or taken down: he didn't get out.
		if proximity == Octagon.CAGE_PINNED:
			_round_control[1 - i] += 1
			if held_on_fence(i):
				fighters[i].spend_stamina(FENCE_HOLD_DRAIN_PER_S / FightClock.TICKS_PER_SECOND)  # Carrying his weight (D220).


func _announce(slot: int, value: String, type: String, actor: int, field: String) -> void:
	if value == _shown[slot]:
		_held[slot] = 0
		return
	if value != _candidate[slot]:
		_candidate[slot] = value
		_held[slot] = 0
	_held[slot] += 1
	if _held[slot] >= ANNOUNCE_AFTER_TICKS:
		_shown[slot] = value
		_held[slot] = 0
		_emit(type, actor, { field: value })


func _to_corners() -> void:
	situation.reset()
	_hold = {}  # Saved by the bell.
	_drive = {}
	_position_effects()
	_wants = [0.0, 0.0]
	_circling = [0.0, 0.0]
	_cutting = [0.0, 0.0]
	_strides = [Vector2.ZERO, Vector2.ZERO]
	_drift = [Vector2.ZERO, Vector2.ZERO]
	_routes_at = [-1000, -1000]
	_shut_in = [false, false]
	_way_out = [0, 0]
	_least_bad = [0, 0]
	_burst_at = [-1000, -1000]
	_trapped = [false, false]
	_sold_way = [0, 0]
	_sold_until = [-1000, -1000]
	_sold_at = [-1000, -1000]
	_turned_at = [-1000, -1000]
	_turned_sale = [-1000, -1000]
	for i in fighters.size():
		fighters[i].pos = START_POSITIONS[i]
	_shown = [band(), cage_proximity(0), cage_proximity(1)]
	_centre_since = [now, now]
	_candidate = _shown.duplicate()
	_held = [0, 0, 0]


# --- Positions: standing, clinch and ground (docs/01 §4, #34) -----------------

## Fighter i's role in the current position ("neutral", "top", "bottom").
func role(i: int) -> String:
	return situation.role(i)


## The transition fighter i would make by landing this action from here (or half
## landing it, `result` "partial"), or {}.
func transition_for(i: int, action_id: String, result: String = PositionLibrary.SUCCESS) -> Dictionary:
	return positions.transition(situation.position, situation.role(i), action_id, result)


## Moves the fight to where fighter i's action takes it (from the position data).
## Returns false, changing nothing, when the action doesn't move the fight from
## here. The fight stays on the spot where the opponent stood, so the cage carries
## over: tied up on the fence stays on the fence, and getting up separates there.
## Whatever either fighter was in the middle of stops. Ending up on top scores a
## takedown with the judges (Judging.TAKEDOWN_POINTS): the actor, or the opponent when the
## actor's move failed into a position under them (not a guard pull, D128). Moving to a better
## position on top (D130: a pass, the mount, the back) scores the control gained
## (Judging.ADVANCE_POINTS_PER_CONTROL × the rise in the top's control score), and so does the
## fighter on top getting past the legs when a leg lock from underneath misses (D132). Grapple resolution
## calls this when a takedown, clinch move, get-up or submission works (or fails into a new
## position, `result` "failed").
func apply_transition(i: int, action_id: String, result: String = PositionLibrary.SUCCESS) -> bool:
	var t: Dictionary = transition_for(i, action_id, result)
	if t.is_empty():
		return false
	var was_top: Array[bool] = [situation.role(0) == PositionLibrary.TOP, situation.role(1) == PositionLibrary.TOP]
	var was_bottom: bool = situation.role(i) == PositionLibrary.BOTTOM
	var control_before: float = float(positions.get_position(situation.position).control_score.get(PositionLibrary.TOP, 0.0))
	var roles: Array[String] = ["", ""]
	roles[i] = t.roles.actor
	roles[1 - i] = t.roles.opponent
	situation.set_to(positions.get_position(t.to), roles)
	_drive = {}
	_position_effects()
	for f in fighters:
		f.clear_action()
		f.tied_up_ticks = 0
		if not situation.is_standing():
			f.down_ticks = 0  # Followed down after a knockdown (D142): on the ground now, still rocked.
		f.unanswered = 0
	_place_bodies(i)
	var changed := { "action_id": action_id, "position": situation.position, "phase": situation.phase, "roles": roles.duplicate() }
	if result == PositionLibrary.FAILED:
		changed.failed = true
	_emit(FightEvent.POSITION_CHANGED, i, changed)
	var gained: float = float(positions.get_position(t.to).control_score.get(PositionLibrary.TOP, 0.0)) - control_before
	if roles[i] == PositionLibrary.TOP and was_top[i]:
		if gained > 0.0:
			_round_points[i] += Judging.ADVANCE_POINTS_PER_CONTROL * gained
			_round_grappling[i] += Judging.ADVANCE_POINTS_PER_CONTROL * gained
			fighters[i].advances += 1
	elif result == PositionLibrary.FAILED:
		if roles[1 - i] == PositionLibrary.TOP and was_top[1 - i] and gained > 0.0:
			# A leg lock from underneath that misses lets him past the legs (D132): his better position scores.
			_round_points[1 - i] += Judging.ADVANCE_POINTS_PER_CONTROL * gained
			_round_grappling[1 - i] += Judging.ADVANCE_POINTS_PER_CONTROL * gained
			fighters[1 - i].advances += 1
	elif was_bottom and roles[i] != PositionLibrary.ATTACKER:
		fighters[i].escapes += 1  # Out from underneath: back to guard, up, or on top (not a hold, D130).
	if roles[i] == PositionLibrary.TOP and not was_top[i]:
		_round_points[i] += Judging.TAKEDOWN_POINTS
		_round_grappling[i] += Judging.TAKEDOWN_POINTS
		if actions.has(action_id) and actions.get_action(action_id).category == "takedown":
			fighters[i].takedowns_landed += 1
			if ActionLibrary.is_throw(actions.get_action(action_id)):
				fighters[i].throws_landed += 1
	if roles[1 - i] == PositionLibrary.TOP and not was_top[1 - i] and result == PositionLibrary.FAILED:
		# Ends up on top off the opponent's failed move (a guillotine, D126); pulling guard
		# on purpose (D128) gives the judges nothing.
		_round_points[1 - i] += Judging.TAKEDOWN_POINTS
		_round_grappling[1 - i] += Judging.TAKEDOWN_POINTS
	return true


## In mount, a man covering up or rocked under a clean head shot may turn away from it and give up
## his back (D270): on a chance of TURN_AWAY_BASE × (1.5 − Fight IQ / 100) × (1 + head hurt). It isn't
## an escape and doesn't answer the shots: the referee's count carries on. (The back scores no more
## control than the mount, so the judges see nothing new, as when he takes it.)
func _maybe_turn_away(k: int, covered: bool) -> void:
	if situation.position != "mount" or situation.role(k) != PositionLibrary.BOTTOM:
		return
	var d: FighterState = fighters[k]
	if not covered and not d.is_rocked():
		return
	var chance: float = TURN_AWAY_BASE * maxf(0.0, 1.5 - d.effective_stat("fight_iq") / 100.0) * (1.0 + d.hurt("head"))
	if _rng.randf() >= chance:
		return
	var unanswered: int = d.unanswered
	var escapes: int = d.escapes
	if not apply_transition(k, TURN_AWAY):
		return
	d.unanswered = unanswered
	d.escapes = escapes
	d.turned_away += 1


## Back to standing without anyone's move (a knockdown in the clinch): the fighters
## come apart where they are, a standing gap apart.
func _break_apart(i: int) -> void:
	situation.reset()
	_drive = {}
	for f in fighters:
		f.tied_up_ticks = 0
		f.unanswered = 0
	_position_effects()
	_place_bodies(i)
	_emit(FightEvent.POSITION_CHANGED, i, { "action_id": "", "position": situation.position, "phase": situation.phase, "roles": situation.roles.duplicate() })


## Reads what the current position does to each fighter per tick from its data.
func _position_effects() -> void:
	var def: Dictionary = positions.get_position(situation.position)
	for i in fighters.size():
		var r: String = situation.role(i)
		_drain[i] = float(def.stamina_drain_per_s.get(r, 0.0)) / FightClock.TICKS_PER_SECOND
		_control[i] = float(def.control_score.get(r, 0.0)) * Judging.CONTROL_POINTS_PER_S / FightClock.TICKS_PER_SECOND
		_damage_scale[i] = float(def.strike_damage_multiplier.get(r, 1.0))


## Puts fighter i next to the opponent: tangled when tied up, a standing gap apart otherwise.
## The opponent keeps their spot unless the fence is in the way.
func _place_bodies(i: int) -> void:
	var f: FighterState = fighters[i]
	var o: FighterState = fighters[1 - i]
	var from_o: Vector2 = f.pos - o.pos
	var side: Vector2 = from_o.normalized() if from_o.length() > 0.0 else Vector2.LEFT
	var gap: float = Octagon.MIN_GAP if situation.is_standing() else TANGLED_GAP
	f.pos = Octagon.keep_inside(o.pos + side * gap)
	o.pos = Octagon.keep_inside(f.pos - side * gap)  # Only moves them when the fence was in fighter i's way.


# --- Choosing and running actions ---------------------------------------------


## Starts an action. The telegraph event says which layer chose it and why
## (`by`, `why`), so the log can explain every move (docs/01 §16 A16).
func _start_action(i: int, id: String, decision: Decision = null) -> void:
	var f: FighterState = fighters[i]
	var blind: bool = would_be_blind(i, id)
	f.action_id = id
	f.blind_shot = blind
	var action: Dictionary = actions.get_action(id)
	f.spend_stamina(float(action.stamina_cost))
	if action.category == "strike":
		f.strikes_thrown += 1
	elif action.category == "takedown":
		f.takedowns_tried += 1
		if ActionLibrary.is_throw(action):
			f.throws_tried += 1
		if blind:
			f.blind_shots += 1
	elif action.category == FEINT:
		f.feints_tried += 1
	elif action.category == "submission":
		f.subs_tried += 1
		if ActionLibrary.is_leg_lock(action):
			f.leg_locks_tried += 1
	elif id == COLLAR_TIE:
		f.collar_ties_tried += 1
	elif id == FENCE_DRIVE:
		f.fence_drives_tried += 1
	elif id == SPIN_OFF or id == TURN_HIM:
		f.spin_offs_tried += 1
	elif id == GROUND_COVER:
		f.ground_covers += 1
	_start_combo(i, id, decision)
	if action.category == "strike" or action.category == "takedown" or action.category == "submission" or (action.category == "clinch" and situation.is_standing()):
		_round_aggression[i] += 1.0
	var why: Dictionary = {}
	if decision != null:
		why = { "by": decision.layer, "why": decision.reason }
		if decision.layer == DecisionLayer.AI:
			var part: String = decision.part if decision.part != "" else FighterAI.PART_LEAD
			f.ai_parts[part] = f.ai_parts.get(part, 0) + 1
	if blind:
		why.blind = true
	if f.combo_id != "":
		why.combo = f.combo_id
		why.step = f.combo_step
	_enter_phase(i, 0, why)


## Where this move sits in a combination (D133): the decision says which one and which move
## of it, and it has to be that move. The second move is when it counts as thrown, and when
## the opponent has seen it once more.
func _start_combo(i: int, id: String, decision: Decision) -> void:
	var f: FighterState = fighters[i]
	f.combo_next_until = -1
	f.combo_id = ""
	f.combo_step = 0
	f.combo_runs = false
	if decision == null or decision.combo == "" or not combos.has(decision.combo) or combos.move(decision.combo, decision.combo_step) != id:
		return
	f.combo_id = decision.combo
	f.combo_step = decision.combo_step
	f.combo_runs = decision.combo_runs
	if f.combo_step == 0:
		return
	f.combo_strikes += 1
	if f.combo_step == 1:
		f.combos_thrown += 1
		_combos_seen[1 - i][f.combo_id] = int(_combos_seen[1 - i].get(f.combo_id, 0)) + 1


## True when fighter i starting this move now would be a blind shot (D131): a takedown from
## standing (not a throw, D128) with none of the fighter's own strikes or feints just before it
## (SET_UP_TICKS), not a reaction to an opening the move needs (the catch), and nothing in the
## odds to shoot into when it arrives: no counter (timed into their wind-up or recovery) and no
## flag such as LEANING or BIT_ON_FEINT. An opponent on the fence doesn't count (NOT_A_SET_UP).
func would_be_blind(i: int, id: String) -> bool:
	var action: Dictionary = actions.get_action(id)
	if action.category != "takedown" or not situation.is_standing() or fighters[i].set_up_until >= now or ActionLibrary.is_throw(action):
		return false
	for opp: Dictionary in action.opportunities:
		if opp.get("required", false):
			return false
	var lands_in: int = phase_ticks(fighters[i], id, "telegraph") + phase_ticks(fighters[i], id, "windup")
	for bonus: Dictionary in odds_breakdown(i, id, lands_in).bonuses:
		if float(bonus.value) > 0.0 and not NOT_A_SET_UP.has(bonus.name):
			return false
	return true


func _next_phase(i: int) -> void:
	if fighters[i].grip != null and fighters[i].phase == "active" and _finish_grip(i):
		return  # It worked: the fight moved and both fighters' moves are over.
	var at: int = ActionLibrary.PHASES.find(fighters[i].phase) + 1
	if at >= ActionLibrary.PHASES.size():
		var id: String = fighters[i].action_id
		var category: String = actions.get_action(id).category
		if category == "strike" or category == FEINT:
			fighters[i].set_up_until = now + SET_UP_TICKS
		if fighters[i].combo_id != "" and fighters[i].combo_step + 1 < combos.length(fighters[i].combo_id):
			fighters[i].combo_next_until = now + COMBO_WINDOW_TICKS
		fighters[i].clear_action()
		_emit(FightEvent.ACTION_ENDED, i, { "action_id": id })
	else:
		_enter_phase(i, at)


## Enters phase `at`, skipping zero-length phases (each still emits its event).
## `why` (who chose the action and why) goes on the telegraph event.
func _enter_phase(i: int, at: int, why: Dictionary = {}) -> void:
	var f: FighterState = fighters[i]
	f.phase = ActionLibrary.PHASES[at]
	f.phase_ticks_left = phase_ticks(f, f.action_id, f.phase)
	var data := { "action_id": f.action_id, "phase": f.phase }
	data.merge(why)
	_emit(FightEvent.ACTION_PHASE, i, data)
	if f.phase == "active":
		_resolve_active(i)
		if f.action_id == "":
			return  # A knockdown on the ground or in the clinch broke them apart and ended the move.
	if f.phase_ticks_left <= 0:
		_next_phase(i)


## How long this fighter takes over one phase of an action, in whole ticks.
## A fresh 50-Speed fighter matches the data exactly; zero-length phases stay zero.
func phase_ticks(f: FighterState, id: String, phase: String) -> int:
	var ticks: int = actions.phase_ticks(id, phase)
	if ticks == 0 or phase not in TIMED_PHASES:
		return ticks
	var quickness: float = f.effective_stat("speed")
	if phase == "telegraph" and actions.get_action(id).stats.offense.has("kicking"):
		quickness = (quickness + f.effective_stat("kicking")) / 2.0
	var factor: float = 1.0 - MAX_TIMING_SHIFT * clampf((quickness - FighterState.DEFAULT_STAT) / 50.0, -1.0, 1.0)
	factor *= 1.0 + f.tired()
	var out: int = maxi(1, roundi(ticks * factor))
	if phase == "telegraph" and f.combo_step > 0 and f.action_id == id and f.combo_id != "":
		out = maxi(0, out - COMBO_FLOW_TICKS)  # It flows out of the last one (D133).
	return out


## Flags fighter i carries right now: from their current action's phase (docs/09
## flags_self), BACK_TO_CAGE when pinned (and HELD_ON_FENCE when it's his back the other man has
## on it in the clinch, D220), HANDS_LOW when exhausted or rocked,
## POSTURE_BROKEN while tied up from the bottom, HEAD_LOW while stuck under a sprawl,
## DOWN while knocked down (soccer kicks and stomps need it, D141).
func active_flags(i: int) -> Array[String]:
	var f: FighterState = fighters[i]
	var out: Array[String] = []
	if cage_proximity(i) == Octagon.CAGE_PINNED:
		out.append("BACK_TO_CAGE")
		if held_on_fence(i):
			out.append(HELD_ON_FENCE)
	if f.stamina_fraction() < HANDS_LOW_BELOW or f.is_rocked() or f.winded_ticks > 0 or f.liver_ticks > 0:
		out.append("HANDS_LOW")
	if f.tied_up_ticks > 0:
		out.append("POSTURE_BROKEN")
	if f.bit_ticks > 0:
		out.append("BIT_ON_FEINT")
	if f.is_down():
		out.append("DOWN")
	if f.is_free():
		return out
	if f.sprawled:
		out.append("HEAD_LOW")
	if f.blind_shot:
		out.append("BLIND_SHOT")
	var at: int = ActionLibrary.PHASES.find(f.phase)
	for entry: Dictionary in actions.get_action(f.action_id).flags_self:
		if ActionLibrary.PHASES.find(entry.from) <= at and at <= ActionLibrary.PHASES.find(entry.to):
			out.append(entry.flag)
	if out.has(COVERED):
		out.erase("HANDS_LOW")  # Hurt or tired, but his hands are up (D180).
	return out


## Fighter i's flags `ahead` ticks from now if they carry on with their action:
## the flags of the phase they'll be in, plus the ones that come from where they
## stand and how they are (pinned, exhausted, rocked), as they are now.
func flags_ahead(i: int, ahead: int) -> Array[String]:
	if ahead <= 0:
		return active_flags(i)
	var f: FighterState = fighters[i]
	var out: Array[String] = []
	var turns: int = turns_before(i, ahead)
	if cage_proximity(i) == Octagon.CAGE_PINNED:
		out.append("BACK_TO_CAGE")
		if held_on_fence(i):
			out.append(HELD_ON_FENCE)
	if f.stamina_fraction() < HANDS_LOW_BELOW or f.is_rocked() or f.winded_ticks > turns or f.liver_ticks > 0:
		out.append("HANDS_LOW")
	if f.tied_up_ticks > turns:
		out.append("POSTURE_BROKEN")
	if f.bit_ticks > turns:
		out.append("BIT_ON_FEINT")
	if f.down_ticks > turns:
		out.append("DOWN")
	var phase: String = phase_ahead(i, ahead)
	if phase == "":
		return out
	if f.sprawled:
		out.append("HEAD_LOW")
	if f.blind_shot:
		out.append("BLIND_SHOT")
	var at: int = ActionLibrary.PHASES.find(phase)
	for entry: Dictionary in actions.get_action(f.action_id).flags_self:
		if ActionLibrary.PHASES.find(entry.from) <= at and at <= ActionLibrary.PHASES.find(entry.to):
			out.append(entry.flag)
	return out


## Fighter i's phase `ahead` ticks from now if they carry on with their action
## ("" when they're free or will be done by then). Committed moves can't be
## cancelled, so this is what an opponent who read the move can count on.
func phase_ahead(i: int, ahead: int) -> String:
	var f: FighterState = fighters[i]
	if f.is_free():
		return ""
	var at: int = ActionLibrary.PHASES.find(f.phase)
	var left: int = f.phase_ticks_left - turns_before(i, ahead)
	while left <= 0:
		at += 1
		if at >= ActionLibrary.PHASES.size():
			return ""
		left += phase_ticks(f, f.action_id, ActionLibrary.PHASES[at])
	return ActionLibrary.PHASES[at]


## Fighter i's odds for this action against the opponent right now: the shared
## contest formula on effective stats, plus opportunity bonuses for flags the
## opponent carries and for catching them mid-commitment (a counter).
## 0 when a required opportunity is missing (catch-kick needs a kick).
func odds(i: int, id: String) -> float:
	return odds_breakdown(i, id).chance


## Fighter i's odds for this action on stats alone: no flags, no counter (the AI's
## range plan, #14). Cheaper than odds_breakdown.
func plain_odds(i: int, id: String) -> float:
	var action: Dictionary = actions.get_action(id)
	return Contest.chance(Contest.base_for(action), _average_stat(fighters[i], action.stats.offense), _average_stat(fighters[1 - i], action.stats.defense))


## The same odds with every part named (OddsBreakdown), as strike events carry them.
## With `ahead` > 0: the odds if the action lands that many ticks from now, with the
## opponent carrying on with their action (the AI uses it to time counters, #14).
## Opportunities can also come from fighter i's own flags (`own_flag`: getting up
## with your back on the fence is easier, wall-walking), as they are now.
func odds_breakdown(i: int, id: String, ahead: int = 0) -> OddsBreakdown:
	var action: Dictionary = actions.get_action(id)
	var b := OddsBreakdown.new(id)
	b.base = Contest.base_for(action)
	b.attack = _average_stat(fighters[i], action.stats.offense)
	b.defense = _average_stat(fighters[1 - i], action.stats.defense)
	var countering: bool = is_counter(i) if ahead <= 0 else phase_ahead(1 - i, ahead) in COUNTER_PHASES
	if countering:
		b.add_bonus("counter", COUNTER_BONUS)
	var opponent_flags: Array[String] = active_flags(1 - i) if ahead <= 0 else flags_ahead(1 - i, ahead)
	var own_flags: Array[String] = []
	for opp: Dictionary in action.opportunities:
		if opp.has("own_flag"):
			if own_flags.is_empty():
				own_flags = active_flags(i)
			if own_flags.has(opp.own_flag):
				b.add_bonus("own " + String(opp.own_flag), float(opp.success_bonus))
			elif opp.get("required", false) and b.missing == "":
				b.missing = "own " + String(opp.own_flag)  # The spin-off needs his own back on the fence (D220).
		elif opponent_flags.has(opp.opponent_flag):
			b.add_bonus(opp.opponent_flag, float(opp.success_bonus))
		elif opp.get("required", false) and b.missing == "":
			b.missing = opp.opponent_flag
	if action.category == "defense" and action.defense.has("hidden_by") and b.defense > FighterState.DEFAULT_STAT:
		# A good kicker hides his kicks (D180): his skill above average counts again against the check.
		b.add_bonus("hidden", -float(action.defense.hidden_by) * (b.defense - FighterState.DEFAULT_STAT) / 100.0)
	if action.category == "strike" and fighters[i].slip_counter_until >= now + maxi(ahead, 0):
		b.add_bonus("off the slip", SLIP_COUNTER_BONUS)
	if action.category == FEINT:
		var again: int = _recent_feints(i)
		if again > 0:
			b.add_bonus("feinted again", -FEINT_REPEAT * again)
	var f: FighterState = fighters[i]
	if f.combo_step > 0 and f.combo_id != "" and f.action_id == id and action.category == "strike":
		_combo_bonuses(i, action, b)
	return b.settle()


## A move after the first of a combination (D133): it may change levels, and the opponent
## may have seen it before.
func _combo_bonuses(i: int, action: Dictionary, b: OddsBreakdown) -> void:
	var f: FighterState = fighters[i]
	var before: Dictionary = actions.get_action(combos.move(f.combo_id, f.combo_step - 1))
	if before.strike.target != action.strike.target:
		b.add_bonus("changes levels", LEVEL_CHANGE)
	var seen: int = combo_seen_before(1 - i)
	if seen > 0:
		b.add_bonus("seen it", -COMBO_SEEN * seen)


## How many times fighter i had already seen the combination the opponent is in the middle of
## (its second move or later) before this one, up to COMBO_SEEN_MAX; 0 when there's none (D133).
func combo_seen_before(i: int) -> int:
	var opp: FighterState = fighters[1 - i]
	if opp.combo_id == "" or opp.combo_step == 0:
		return 0
	return mini(int(_combos_seen[i].get(opp.combo_id, 1)) - 1, COMBO_SEEN_MAX)


## How many of fighter i's feints reached their active phase in the last FEINT_MEMORY_TICKS.
func _recent_feints(i: int) -> int:
	var seen: Array = _feints[i]
	while not seen.is_empty() and int(seen[0]) < now - FEINT_MEMORY_TICKS:
		seen.pop_front()
	return seen.size()


## True when fighter i's opponent is committed (wind-up or recovery) right now.
func is_counter(i: int) -> bool:
	return fighters[1 - i].phase in COUNTER_PHASES


func _resolve_active(i: int) -> void:
	var action: Dictionary = actions.get_action(fighters[i].action_id)
	match action.category:
		"strike":
			_land_strike(i, action)
		"defense":
			_meet_shot(i)
		"takedown", "clinch", "ground", "submission":
			_make_contact(i, action)
		FEINT:
			_feint(i, action)


## A feint reaches its active phase (D131): one roll on its odds (the fighter's own recent
## feints count against it). If it bites, the opponent has their hands up and weight back for
## the feint's `bites_ms` (BIT_ON_FEINT): shots and clinch entries find them reacting. Cutting
## him off, it also sells the way he was getting out shut (SOLD_TICKS, D235).
func _feint(i: int, action: Dictionary) -> void:
	var data := { "action_id": action.id }
	if fighters[1 - i].is_down():
		data.reason = "opponent down"
	elif not action.ranges.has(band()):
		data.reason = "out of range"
	if data.has("reason"):
		data.bit = false
		_emit(FightEvent.FEINTED, i, data)
		return
	var b: OddsBreakdown = odds_breakdown(i, action.id)
	_feints[i].append(now)
	data.bit = _rng.randf() < b.chance
	data.chance = b.chance
	data.odds = b.to_dict()
	if data.bit:
		fighters[1 - i].bit_ticks = int(action.feint.bites_ms) / FightClock.TICK_MS
		fighters[i].feints_bit += 1
		if _cut_at[i] >= now - SOLD_CUT_TICKS and _way_out[1 - i] != 0 and not is_sold(1 - i):
			# Cutting him off: the feint at his way out sells it shut (D235).
			_sold_way[1 - i] = _way_out[1 - i]
			_sold_until[1 - i] = now + SOLD_TICKS
			_sold_at[1 - i] = now
			doors_sold[i] += 1
			data.sold = true
	_emit(FightEvent.FEINTED, i, data)


## Fighter i's strike meets the opponent's check or slip (D180), if it's up as the strike lands
## and it's a defence against this strike (`defense.against_strikes`). One roll on its odds, and
## either way the defence is spent. True when it worked: the strike misses, and a checked kick
## hurts the kicker's leg, or a slipped punch leaves the slipper a counter.
func _strike_defended(i: int, action: Dictionary) -> bool:
	var d: FighterState = fighters[1 - i]
	if d.phase != "active":
		return false
	var defense: Dictionary = actions.get_action(d.action_id)
	if defense.category != "defense" or not defense.defense.get("against_strikes", []).has(action.id):
		return false
	var b: OddsBreakdown = odds_breakdown(1 - i, defense.id)
	var worked: bool = _rng.randf() < b.chance
	var met := { "action_id": defense.id, "against": action.id, "worked": worked, "chance": b.chance, "odds": b.to_dict() }
	var kicker_leg: int = -1
	var kicker_hurt: int = 0
	if worked and action.strike.target == "legs":
		var kick: float = strike_damage(fighters[i], action.id) * _damage_scale[i]
		kicker_leg = 1 - fighters[i].lead_leg()  # He kicks with the back leg, into the shin.
		kicker_hurt = maxi(1, roundi(kick * CHECK_KICKER_SHARE))
		var shin: int = roundi(kick * CHECK_SHIN_SHARE)
		fighters[i].damage.legs += kicker_hurt
		fighters[i].leg_damage[kicker_leg] += kicker_hurt
		d.damage.legs += shin
		d.leg_damage[d.lead_leg()] += shin
		_round_points[1 - i] += kicker_hurt * Judging.TARGET_WEIGHTS.legs
		met.damage = kicker_hurt
		met.leg = kicker_leg
	elif worked:
		d.slip_counter_until = now + SLIP_COUNTER_TICKS
	_emit(FightEvent.STRIKE_DEFENDED, 1 - i, met)
	_to_recovery(1 - i)
	if not worked:
		return false
	_emit(FightEvent.STRIKE_MISSED, i, { "action_id": action.id, "target": action.strike.target, "chance": 0.0, "reason": "defended", "by_action": defense.id })
	if kicker_leg >= 0:
		fighters[i].phase_ticks_left += CHECK_STUCK_TICKS  # Still on one leg (ONE_LEG).
		if situation.is_standing():
			_leg_impact(1 - i, kicker_leg, kicker_hurt)
	return true


func _land_strike(i: int, action: Dictionary) -> void:
	var attacker: FighterState = fighters[i]
	var defender: FighterState = fighters[1 - i]
	var target: String = action.strike.target
	var miss := { "action_id": action.id, "target": target, "chance": 0.0 }
	if defender.is_down() and not action.strike.get("downed", false):
		miss.reason = "opponent down"  # Only a soccer kick or a stomp hits a downed man (D141).
		_emit(FightEvent.STRIKE_MISSED, i, miss)
		return
	if not action.ranges.has(band()):
		miss.reason = "out of range"
		_emit(FightEvent.STRIKE_MISSED, i, miss)
		return
	if attacker.tied_up_ticks > 0 and Ruleset.is_ground_strike(action):
		miss.reason = "tied up"
		_emit(FightEvent.STRIKE_MISSED, i, miss)
		return
	if not ruleset.allows_target(action, target):
		target = "body"  # Amateur rules: ground strikes to the body only (docs/08, D121).
	if _strike_defended(i, action):
		return
	var counter: bool = is_counter(i)
	var breakdown: OddsBreakdown = odds_breakdown(i, action.id)
	var chance: float = breakdown.chance
	if _rng.randf() >= chance:
		miss.chance = chance
		miss.odds = breakdown.to_dict()
		_emit(FightEvent.STRIKE_MISSED, i, miss)
		return
	# An opening can change what the strike does (D29: a knee into a shot goes to the
	# lowered head, harder, and stops the shot): `target`, `damage_multiplier`, `stops`.
	var scale: float = (COUNTER_DAMAGE if counter else 1.0) * _damage_scale[i]
	var stops: bool = false
	if not breakdown.bonuses.is_empty():
		for opp: Dictionary in action.opportunities:
			if not opp.has("opponent_flag") or not _has_bonus(breakdown, opp.opponent_flag):
				continue
			if opp.has("target") and ruleset.allows_target(action, opp.target):
				target = opp.target
			scale *= float(opp.get("damage_multiplier", 1.0))
			stops = stops or bool(opp.get("stops", false))
	var into: String = defender.action_id if stops and defender.phase in STOPPABLE_PHASES else ""
	var covered: bool = target == "head" and active_flags(1 - i).has(COVERED)
	if covered:
		var through: float = float(actions.get_action(defender.action_id).defense.head_share)  # Through the guard (D180).
		scale *= maxf(through, float(action.strike.get("through_cover", 0.0)))  # A hammerfist gets round it (D270).
	var dealt: int = maxi(1, roundi(strike_damage(attacker, action.id) * scale))
	var was_rocked: bool = defender.is_rocked()
	if is_cutting(1 - i):
		cut_damage_taken[1 - i] += dealt  # What walking him down cost (D233).
	defender.damage[target] += dealt
	var leg: int = -1
	if target == "legs":
		leg = defender.lead_leg()
		defender.leg_damage[leg] += dealt
	attacker.unanswered = 0  # Landing anything back answers (D120).
	defender.stagger_ticks = maxi(defender.stagger_ticks, STAGGER_BASE + roundi(dealt * STAGGER_PER_DAMAGE))
	var push: float = float(action.strike.get("push_m", 0.0))
	if push > 0.0:
		_push(1 - i, push)
	attacker.strikes_landed += 1
	if attacker.combo_step > 0 and attacker.combo_id != "":
		attacker.combo_landed += 1
	# A clean shot breaks the combination he was in the middle of (D133).
	defender.combo_id = ""
	defender.combo_next_until = -1
	if situation.position == PositionLibrary.CLINCH and action.id == "knee":
		attacker.clinch_knees_landed += 1
		if _has_bonus(breakdown, "POSTURE_BROKEN"):
			attacker.tied_knees_landed += 1
	_round_points[i] += dealt * Judging.TARGET_WEIGHTS[target]
	var landed := { "action_id": action.id, "target": target, "damage": dealt, "chance": chance, "counter": counter, "odds": breakdown.to_dict() }
	if into != "":
		landed.into = into
	if leg >= 0:
		landed.leg = leg
	if covered:
		landed.covered = true
	_emit(FightEvent.STRIKE_LANDED, i, landed)
	if into != "":
		_emit(FightEvent.GRAPPLE_STOPPED, 1 - i, { "action_id": into, "reason": "stopped", "by_action": action.id })
		_to_recovery(1 - i)
	if target == "head":
		_head_impact(i, dealt, into != "")
		var on_ground: bool = situation.phase == PositionLibrary.PHASE_GROUND
		_referee(i, was_rocked, covered and not on_ground)  # Covering up underneath isn't answering (D270).
		if on_ground and not _fight_over:
			_maybe_turn_away(1 - i, covered)
	elif target == "body" and situation.phase != PositionLibrary.PHASE_GROUND:
		_body_impact(i, dealt)
	elif target == "body" and action.strike.has("hands_down_ms"):
		defender.winded_ticks = maxi(defender.winded_ticks, int(action.strike.hands_down_ms) / FightClock.TICK_MS)  # His hands come down (D270).
	elif leg >= 0 and situation.is_standing():
		_leg_impact(i, leg, dealt)


static func _has_bonus(b: OddsBreakdown, bonus_name: String) -> bool:
	for x: Dictionary in b.bonuses:
		if x.name == bonus_name:
			return true
	return false


## Cuts fighter i's move short: straight into its recovery, nothing more to roll.
func _to_recovery(i: int) -> void:
	fighters[i].grip = null
	_enter_phase(i, ActionLibrary.PHASES.find("recovery"))


# --- Takedowns, clinch and ground moves (docs/01 §21, #15) ---------------------

## A takedown, clinch or ground move reaches its active phase: contact. It needs the
## range, and a required opening (the catch-kick needs the kick) has to be there now.
## Its odds are fixed here (the opening may be gone by the time it's rolled) and
## rolled as the active phase ends (_finish_grip); until then the defender can
## sprawl on it or knee into it.
func _make_contact(i: int, action: Dictionary) -> void:
	var stopped := { "action_id": action.id }
	if fighters[1 - i].is_down() and not action[action.category].get("downed", false):
		stopped.reason = "opponent down"
	elif not action.ranges.has(band()):
		stopped.reason = "out of range"
	else:
		var b: OddsBreakdown = odds_breakdown(i, action.id)
		if b.missing == "":
			fighters[i].grip = b
			_meet_shot(1 - i)  # Already sprawling as it arrives?
			return
		stopped.reason = "not on the fence" if b.missing == "own " + HELD_ON_FENCE else "nothing to catch"
		stopped.chance = 0.0
		stopped.odds = b.to_dict()
	_emit(FightEvent.GRAPPLE_STOPPED, i, stopped)
	_to_recovery(i)


## Fighter k's sprawl (a defense against the opponent's category of move) meets the
## opponent's shot, if the sprawl is in its active phase while the shot has contact.
## One roll: it works, and the shooter is stuck under it, head low, for longer; or
## it doesn't, and the shot goes on to its own roll. Either way the sprawl is spent.
## A throw or a trip (D128) has no shot to sprawl on: the sprawl does nothing to it.
func _meet_shot(k: int) -> void:
	var d: FighterState = fighters[k]
	var s: FighterState = fighters[1 - k]
	if d.phase != "active" or s.grip == null:
		return
	var sprawl: Dictionary = actions.get_action(d.action_id)
	var shot: Dictionary = actions.get_action(s.action_id)
	if sprawl.category != "defense" or not sprawl.defense.get("against_categories", []).has(shot.category) or ActionLibrary.is_throw(shot):
		return  # Nothing to sprawl on in a throw or a trip (D128).
	var b: OddsBreakdown = odds_breakdown(k, sprawl.id)
	var worked: bool = _rng.randf() < b.chance
	_emit(FightEvent.SPRAWLED, k, { "action_id": sprawl.id, "against": s.action_id, "worked": worked, "chance": b.chance, "odds": b.to_dict() })
	_to_recovery(k)
	if not worked:
		return
	_emit(FightEvent.GRAPPLE_STOPPED, 1 - k, { "action_id": s.action_id, "reason": "sprawled on", "chance": s.grip.chance, "odds": s.grip.to_dict() })
	_to_recovery(1 - k)
	s.phase_ticks_left += SPRAWL_STUCK_TICKS
	s.sprawled = true
	if s.blind_shot:
		s.phase_ticks_left += BLIND_STUCK_TICKS
		s.spend_stamina(BLIND_STUFFED_STAMINA)


## The roll at the end of a grapple's active phase, on the odds fixed at contact.
## Under the odds it works; within the move's `partial_within` above them it half
## works, if the position data says where that goes (a scramble). Returns true when
## the fight moved.
func _finish_grip(i: int) -> bool:
	var f: FighterState = fighters[i]
	var b: OddsBreakdown = f.grip
	f.grip = null
	var action: Dictionary = actions.get_action(f.action_id)
	var roll: float = _rng.randf()
	var result: String = ""
	if roll < b.chance:
		result = PositionLibrary.SUCCESS
	elif roll < b.chance + float(action[action.category].get("partial_within", 0.0)) \
			and not transition_for(i, action.id, PositionLibrary.PARTIAL).is_empty():
		result = PositionLibrary.PARTIAL
	if result != PositionLibrary.SUCCESS and _pressed_on_fence(i, action, b, result):
		return true
	if result == PositionLibrary.SUCCESS and action[action.category].has("ties_up_ms"):
		_tie_up(i, action, b)
		return false  # The fight stays where it is; the move goes on to its recovery.
	if result == PositionLibrary.SUCCESS and action[action.category].has("drives_m"):
		_start_drive(i, action, b)
		return false  # Still the clinch, walking back to the fence (D220).
	if result == PositionLibrary.SUCCESS and action[action.category].get("turns", false):
		_turn(i, action, b)
		return apply_transition(i, action.id)  # The spin-off comes away; turning him onto it stays tied up.
	if result == "" or transition_for(i, action.id, result).is_empty():
		if f.blind_shot:
			f.spend_stamina(BLIND_STUFFED_STAMINA)
		_emit(FightEvent.GRAPPLE_STOPPED, i, { "action_id": action.id, "reason": "defended", "chance": b.chance, "odds": b.to_dict() })
		# Some moves cost a position when they fail (a guillotine pulls the attacker onto their back).
		return result == "" and apply_transition(i, action.id, PositionLibrary.FAILED)
	if result == PositionLibrary.SUCCESS and action.category == "submission":
		_emit(FightEvent.GRAPPLE_WON, i, { "action_id": action.id, "result": result, "chance": b.chance, "odds": b.to_dict() })
		return _lock_in(i, action)
	var won := { "action_id": action.id, "result": result, "chance": b.chance, "odds": b.to_dict() }
	if result == PositionLibrary.SUCCESS and f.blind_shot:
		f.blind_landed += 1
	if result == PositionLibrary.PARTIAL:
		won.to = transition_for(i, action.id, result).to  # A scramble, or half a pass (half guard, D130).
	var slam: int = landing_damage(i, action.id) if result == PositionLibrary.SUCCESS else 0
	if slam > 0:
		won.landing_damage = slam
	_emit(FightEvent.GRAPPLE_WON, i, won)
	if slam > 0:
		# A big throw lands hard (D128): body damage, scored like a body shot.
		fighters[1 - i].damage.body += slam
		_round_points[i] += slam * Judging.TARGET_WEIGHTS.body
	return apply_transition(i, action.id, result)


## How hard fighter i's throw lands the opponent (D128): the throw's `landing_damage` × (0.5 +
## Strength / 100) × the rules' damage scale, whole points; 0 for moves that don't, and where
## slams are banned (amateur rules, docs/08).
func landing_damage(i: int, id: String) -> int:
	var action: Dictionary = actions.get_action(id)
	if action.category != "takedown" or not bool(ruleset.allows.get("slams", true)):
		return 0
	var base: float = float(action.takedown.get("landing_damage", 0.0))
	if base <= 0.0:
		return 0
	return maxi(1, roundi(base * (0.5 + fighters[i].effective_stat("strength") / 100.0) * ruleset.damage_multiplier))


## A tie-up from the bottom works (D121): the top fighter's posture is broken, the ground
## strike they were throwing is smothered, and they can't throw another until it wears off.
## A collar tie in the clinch (D129) breaks the opponent's posture the same way: his head is
## pulled down for the knees. Winning the tie also frees the winner from the opponent's.
func _tie_up(i: int, action: Dictionary, b: OddsBreakdown) -> void:
	var o: FighterState = fighters[1 - i]
	o.tied_up_ticks = int(action[action.category].ties_up_ms) / FightClock.TICK_MS
	fighters[i].tied_up_ticks = 0
	fighters[i].unanswered = 0
	if action.id == COLLAR_TIE:
		fighters[i].collar_ties_won += 1
	if not o.is_free() and actions.get_action(o.action_id).category == "strike":
		o.clear_action()
	_emit(FightEvent.GRAPPLE_WON, i, { "action_id": action.id, "result": "tied_up", "chance": b.chance, "odds": b.to_dict() })


# --- The cage clinch (D220, docs/01 §39) --------------------------------------

## A shot at a man whose back was on the fence at contact that half works (D220): on a chance of
## PRESSED_CHANCE the shooter stays on him, tied up against the fence (the clinch), instead of
## the scramble. True when the fight moved to the clinch.
func _pressed_on_fence(i: int, action: Dictionary, b: OddsBreakdown, result: String) -> bool:
	if result != PositionLibrary.PARTIAL or not situation.is_standing() or not _has_bonus(b, "BACK_TO_CAGE") \
			or transition_for(i, action.id, PositionLibrary.PRESSED).is_empty():
		return false
	if _rng.randf() >= PRESSED_CHANCE:
		return false
	_emit(FightEvent.GRAPPLE_WON, i, { "action_id": action.id, "result": PositionLibrary.PRESSED, "chance": b.chance, "odds": b.to_dict() })
	return apply_transition(i, action.id, PositionLibrary.PRESSED)


## A drive to the fence works: fighter i walks the opponent straight back, DRIVE_SPEED a second,
## until his back is on the fence (pinned) or the move's `drives_m` is used up (_drive_step).
func _start_drive(i: int, action: Dictionary, b: OddsBreakdown) -> void:
	var dir: Vector2 = fighters[1 - i].pos - fighters[i].pos
	_drive = { "by": i, "dir": dir.normalized() if dir.length() > 0.0 else Vector2.RIGHT, "left": float(action.clinch.drives_m) }
	fighters[i].fence_drives_won += 1
	_emit(FightEvent.GRAPPLE_WON, i, { "action_id": action.id, "result": "driven", "chance": b.chance, "odds": b.to_dict() })


## One tick of a drive under way: the opponent goes back (the fence stops the part of the step
## that goes into it, so he slides along it onto it), and the driver stays chest to chest.
func _drive_step() -> void:
	if _drive.is_empty():
		return
	var k: int = _drive.by
	if situation.position != PositionLibrary.CLINCH or float(_drive.left) <= 0.0 or held_on_fence(1 - k):
		_drive = {}
		return
	var step: float = minf(float(_drive.left), DRIVE_SPEED / FightClock.TICKS_PER_SECOND)
	var o: FighterState = fighters[1 - k]
	o.pos = Octagon.keep_inside(o.pos + _drive.dir * step)
	fighters[k].pos = Octagon.keep_inside(o.pos - _drive.dir * TANGLED_GAP)
	_drive.left = float(_drive.left) - step


## A drive to the fence under way (D220): {by, dir, left}, or empty. Read-only.
func drive() -> Dictionary:
	return _drive


## A spin-off or a turn works: fighter i, his back on the fence, turns the two of them round, so
## the other man's back is on it now. Any drive stops. Spinning off he then comes away (standing,
## a step off the man now on the fence); turning him, he holds him there.
func _turn(i: int, action: Dictionary, b: OddsBreakdown) -> void:
	var spot: Vector2 = fighters[i].pos
	fighters[i].pos = fighters[1 - i].pos
	fighters[1 - i].pos = spot
	_drive = {}
	fighters[i].spin_offs_won += 1
	_emit(FightEvent.GRAPPLE_WON, i, { "action_id": action.id, "result": "turned", "chance": b.chance, "odds": b.to_dict() })


# --- Submissions (D126, docs/01 §25) ------------------------------------------

## A submission locks in: the fight moves to the submission position (the position data says
## so), the judges score the lock, and the struggle starts with the hold's starting danger,
## nudged by how the attacker's stats compare with the defender's. False (nothing changed)
## when the position data has nowhere for the hold to go from here.
func _lock_in(i: int, action: Dictionary) -> bool:
	var from: String = situation.position
	var from_roles: Array[String] = situation.roles.duplicate()
	if not apply_transition(i, action.id):
		return false
	var edge: float = _average_stat(fighters[i], action.stats.offense) - _average_stat(fighters[1 - i], action.stats.defense)
	var danger: float = clampf(float(action.submission.get("start_danger", 40.0)) + START_DANGER_PER_EDGE * edge, START_DANGER_MIN, START_DANGER_MAX)
	_hold = { "attacker": i, "action_id": action.id, "danger": danger, "beats": 0, "next_at": now + STRUGGLE_BEAT_TICKS,
		"from": from, "from_roles": from_roles, "near": false }
	fighters[i].subs_locked += 1
	if ActionLibrary.is_leg_lock(action):
		fighters[i].leg_locks_locked += 1
	_round_points[i] += Judging.SUB_LOCK_POINTS
	_emit(FightEvent.SUBMISSION_LOCKED, i, { "action_id": action.id, "danger": roundi(danger) })
	return true


## The submission being fought for: {attacker, action_id, danger, beats, …}, or empty. Read-only.
func hold() -> Dictionary:
	return _hold


## The attacker's chance to win the next beat of the hold: the hold's offense stats against its
## defense stats (effective, so a tired or hurt defender loses more beats), plus the attacker's
## Finish it! and minus the defender's Defend the sub! while those calls are on.
func struggle_share() -> float:
	var a: int = _hold.attacker
	var action: Dictionary = actions.get_action(_hold.action_id)
	var bonus: float = decisions[a].calls.struggle_bonus() - decisions[1 - a].calls.struggle_bonus()
	return Contest.chance(STRUGGLE_BASE, _average_stat(fighters[a], action.stats.offense), _average_stat(fighters[1 - a], action.stats.defense), bonus)


## How far one beat moves a hold's danger: its own `step` (the heel hook's 30, D132), or STRUGGLE_STEP.
func struggle_step(action_id: String) -> float:
	return float(actions.get_action(action_id).submission.get("step", STRUGGLE_STEP))


## One beat of the struggle: the danger goes up or down, both fighters pay for it, and the hold
## ends in a tap at SUB_TAP or an escape at 0 or after the last beat.
func _struggle_beat() -> void:
	var a: int = _hold.attacker
	var share: float = struggle_share()
	var gained: bool = _rng.randf() < share
	var step: float = struggle_step(_hold.action_id)
	_hold.danger = float(_hold.danger) + (step if gained else -step)
	_hold.beats = int(_hold.beats) + 1
	_hold.next_at = now + STRUGGLE_BEAT_TICKS
	for k in fighters.size():
		fighters[k].spend_stamina(STRUGGLE_STAMINA + decisions[k].calls.struggle_stamina())
	_emit(FightEvent.SUBMISSION_BEAT, a, { "action_id": _hold.action_id, "danger": roundi(maxf(0.0, _hold.danger)), "gained": gained, "chance": share })
	if _hold.danger >= NEAR_FINISH and not _hold.near:
		_hold.near = true
		_round_impact[a] += 1
	if _hold.danger >= SUB_TAP:
		var id: String = _hold.action_id
		_hold = {}
		_finish(a, RESULT_SUB, "", id)
	elif _hold.danger <= 0.0 or _hold.beats >= STRUGGLE_BEATS:
		_escape()


## The defender gets out of the hold: back to where it was locked from, or into a scramble
## (the hold's `escape_to`). Getting out answers the referee's count, as any change of position.
func _escape() -> void:
	var a: int = _hold.attacker
	var action: Dictionary = actions.get_action(_hold.action_id)
	_emit(FightEvent.SUBMISSION_ESCAPED, 1 - a, { "action_id": action.id, "danger": roundi(maxf(0.0, _hold.danger)), "beats": _hold.beats })
	if String(action.submission.get("escape_to", "back")) == PositionLibrary.SCRAMBLE:
		var neutral: Array[String] = [PositionLibrary.NEUTRAL, PositionLibrary.NEUTRAL]
		situation.set_to(positions.get_position(PositionLibrary.SCRAMBLE), neutral)
	else:
		var back: Array[String] = _hold.from_roles
		situation.set_to(positions.get_position(_hold.from), back)
	_hold = {}
	_position_effects()
	for f in fighters:
		f.clear_action()
		f.tied_up_ticks = 0
		f.unanswered = 0
	_place_bodies(1 - a)
	_emit(FightEvent.POSITION_CHANGED, 1 - a, { "action_id": action.id, "escaped": true, "position": situation.position, "phase": situation.phase, "roles": situation.roles.duplicate() })


## Damage multiplier from Power: 0.5 + Power / 100 (Power 50 → ×1).
func strike_power(f: FighterState) -> float:
	return 0.5 + f.effective_stat("power") / 100.0


## What this strike does when it lands clean (before the counter bonus and rounding).
func strike_damage(f: FighterState, id: String) -> float:
	return float(actions.get_action(id).strike.base_damage) * strike_power(f) * ruleset.damage_multiplier


## How hard a head shot landed relative to what fighter i's opponent can take.
func head_shock(i: int, dealt: float) -> float:
	var d: FighterState = fighters[1 - i]
	return dealt * (1.0 + d.hurt("head")) / (ROCK_THRESHOLD_BASE + ROCK_THRESHOLD_PER_CHIN * d.stat("chin"))


func rock_chance(shock: float) -> float:
	return clampf((shock - ROCK_FROM) * ROCK_SLOPE, 0.0, ROCK_MAX)


func ko_chance(shock: float, f: FighterState) -> float:
	var heart: float = 1.5 - f.effective_stat("heart") / 100.0
	return clampf(KO_BASE + (shock - 1.0) * KO_SLOPE, KO_MIN, KO_MAX) * heart


## A head shot's rock roll. `flash`: it caught them coming in (a knee into a shot,
## D29), so a rock drops them straight away.
func _head_impact(i: int, dealt: int, flash: bool = false) -> void:
	var shock: float = head_shock(i, dealt)
	var chance: float = rock_chance(shock)
	if chance <= 0.0 or _rng.randf() >= chance:
		return
	var d: FighterState = fighters[1 - i]
	if d.is_down():
		# Kicked or stomped while down (D141): he's already on the floor, so it's the KO roll.
		_round_points[i] += Judging.ROCKED_POINTS
		_round_impact[i] += 1
		if _rng.randf() < ko_chance(shock, d):
			_finish(i, RESULT_KO)
		return
	var grounded: bool = situation.phase == PositionLibrary.PHASE_GROUND
	if (d.is_rocked() or flash) and not grounded:
		_knockdown(i, shock)
		return
	var flash_odds: float = 0.0 if grounded else flash_chance(shock)
	if flash_odds > 0.0 and _rng.randf() < flash_odds:
		_knockdown(i, shock, true)  # One clean shot, and a fresh man goes down (D145).
		return
	var again: bool = d.is_rocked()
	d.rocked_ticks = rocked_duration(d)
	d.clear_action()
	_round_points[i] += Judging.ROCKED_POINTS
	_round_impact[i] += 1
	_emit(FightEvent.ROCKED, 1 - i, { "by": i, "again": again } if again else { "by": i })
	if again and _rng.randf() < ko_chance(shock, d):
		_finish(i, RESULT_KO)  # Rocked again on the ground: nowhere to fall, so it's the KO roll (D121).


## The referee watches every clean head shot (D120): health gone, or a rocked
## fighter taking STOP_UNANSWERED of them (counted from the second, `was_rocked`)
## without answering, and it's stopped. Pinned underneath, it's more shots the healthier
## they are (GROUND_STOP_PER_HEALTH). Answering is landing anything,
## tying the top fighter up or getting out from under (any change of position).
## Amateur referees are quicker.
func _referee(i: int, was_rocked: bool, covered: bool = false) -> void:
	if _fight_over:
		return
	var d: FighterState = fighters[1 - i]
	if d.health() <= stop_health():
		_finish(i, RESULT_TKO, "", STOP_HEALTH)
		return
	var limit: int = stop_unanswered()
	if covered:
		return  # On the gloves: he's defending himself, so it doesn't count toward stopping it (D180).
	if was_rocked and d.is_rocked():
		d.unanswered += 1
	elif situation.role(1 - i) == PositionLibrary.BOTTOM:
		d.unanswered += 1
		limit += roundi(GROUND_STOP_PER_HEALTH * d.health())
	else:
		return
	if d.unanswered >= limit:
		_finish(i, RESULT_TKO, "", STOP_SHOTS)


## The health at or under which the referee stops it: 0 in the pros.
func stop_health() -> float:
	return STOP_BIAS_HEALTH * ruleset.early_stoppage_bias


## Clean head shots a rocked fighter may take unanswered before the referee steps in.
func stop_unanswered() -> int:
	return maxi(1, STOP_UNANSWERED - roundi(2.0 * ruleset.early_stoppage_bias))


func body_shock(i: int, dealt: float) -> float:
	var d: FighterState = fighters[1 - i]
	return dealt * (1.0 + d.hurt("body")) / (LIVER_THRESHOLD_BASE + LIVER_THRESHOLD_PER_DURABILITY * d.stat("durability"))


func liver_chance(shock: float) -> float:
	return clampf((shock - LIVER_FROM) * LIVER_SLOPE, 0.0, LIVER_MAX)


## A body shot's liver roll (D143): it doesn't drop him there and then. He freezes, and
## LIVER_DELAY_TICKS later he folds (_liver_fold). A man already going, or down, has nothing more to find.
func _body_impact(i: int, dealt: int) -> void:
	var d: FighterState = fighters[1 - i]
	if d.liver_ticks > 0 or d.is_down():
		return
	var chance: float = liver_chance(body_shock(i, dealt))
	if chance <= 0.0 or _rng.randf() >= chance:
		return
	d.clear_action()
	d.grip = null
	d.liver_ticks = LIVER_DELAY_TICKS
	d.liver_by = i
	_emit(FightEvent.LIVER_SHOT, 1 - i, { "by": i })


## The liver shot takes him: he folds and goes down (a knockdown for the judges and the
## referee, but his head is clear, so not rocked), loses LIVER_STAMINA, and gets up winded.
func _liver_fold(k: int) -> void:
	var d: FighterState = fighters[k]
	var by: int = d.liver_by
	d.spend_stamina(LIVER_STAMINA)
	if situation.phase == PositionLibrary.PHASE_GROUND:
		d.winded_ticks = LIVER_WINDED_TICKS  # Taken down meanwhile: nowhere to fold to, but it still takes his wind.
		return
	d.knockdowns += 1
	d.knockdowns_this_round += 1
	d.unanswered = 0
	d.clear_action()
	d.down_ticks = LIVER_DOWN_TICKS
	d.winded_ticks = LIVER_WINDED_TICKS  # Counted from when he's back up.
	_round_points[by] += Judging.KNOCKDOWN_POINTS
	_round_knockdowns[by] += 1
	_round_impact[by] += 1
	_emit(FightEvent.KNOCKDOWN, k, { "by": by, "liver": true })
	if not situation.is_standing():
		fighters[by].clear_action()
		_break_apart(by)
	if d.knockdowns_this_round >= TKO_KNOCKDOWNS:
		_finish(by, RESULT_TKO, "", STOP_KNOCKDOWNS)


func buckle_chance(leg_hurt: float, dealt: float) -> float:
	return clampf((leg_hurt - BUCKLE_FROM) * dealt * BUCKLE_PER_DAMAGE, 0.0, BUCKLE_MAX)


## A low kick on fighter i's opponent's front leg (D144): it can buckle a badly hurt one, and a
## front leg that's gone makes him switch stance to put the other one in the way.
func _leg_impact(i: int, leg: int, dealt: int) -> void:
	var d: FighterState = fighters[1 - i]
	if d.is_down() or d.liver_ticks > 0:
		return
	var hurt: float = d.leg_hurt(leg)
	var chance: float = buckle_chance(hurt, dealt)
	if chance > 0.0 and _rng.randf() < chance:
		d.knockdowns += 1
		d.knockdowns_this_round += 1
		d.unanswered = 0
		d.clear_action()
		d.grip = null
		d.down_ticks = LEG_DOWN_TICKS
		d.limping = leg
		_round_points[i] += Judging.KNOCKDOWN_POINTS
		_round_knockdowns[i] += 1
		_round_impact[i] += 1
		_emit(FightEvent.KNOCKDOWN, 1 - i, { "by": i, "leg": leg })
		if d.knockdowns_this_round >= TKO_KNOCKDOWNS:
			_finish(i, RESULT_TKO, "", STOP_KNOCKDOWNS)
			return
	if hurt >= SWITCH_FROM and hurt - d.leg_hurt(1 - leg) >= SWITCH_MARGIN:
		d.switched = not d.switched
		_emit(FightEvent.STANCE_SWITCHED, 1 - i, { "hiding": leg })


func flash_chance(shock: float) -> float:
	return clampf((shock - FLASH_FROM) * FLASH_SLOPE, 0.0, FLASH_MAX)


func rocked_duration(f: FighterState) -> int:
	return roundi(ROCKED_TICKS * (1.5 - f.effective_stat("recovery") / 100.0))


func _knockdown(i: int, shock: float, flash: bool = false) -> void:
	var d: FighterState = fighters[1 - i]
	d.knockdowns += 1
	d.knockdowns_this_round += 1
	d.unanswered = 0
	d.clear_action()
	if d.liver_ticks > 0:
		d.liver_ticks = 0  # Dropped while the liver shot was coming: it's the same fall.
		d.winded_ticks = LIVER_WINDED_TICKS
	d.down_ticks = DOWN_TICKS
	d.rocked_ticks = rocked_duration(d)
	_round_points[i] += Judging.KNOCKDOWN_POINTS
	_round_knockdowns[i] += 1
	_round_impact[i] += 1
	_emit(FightEvent.KNOCKDOWN, 1 - i, { "by": i, "flash": true } if flash else { "by": i })
	if not situation.is_standing():
		fighters[i].clear_action()
		_break_apart(i)
	if _rng.randf() < ko_chance(shock, d):
		_finish(i, RESULT_KO)
	elif d.knockdowns_this_round >= TKO_KNOCKDOWNS:
		_finish(i, RESULT_TKO, "", STOP_KNOCKDOWNS)


# --- Rounds, judges and the result --------------------------------------------

func _end_round() -> void:
	var round_scores: Dictionary = _round_scores()
	for what: String in _fight_scores:
		for i in 2:
			_fight_scores[what][i] += round_scores[what][i]
	if ruleset.judging == Ruleset.WHOLE_FIGHT:
		_emit(FightEvent.ROUND_ENDED, FightEvent.NO_ACTOR, {})
		if clock.is_fight_over():
			_whole_fight_verdict()
			return
		_next_round()
		return
	var cards: Array = []
	for j in Judging.JUDGES:
		var seen: Array[float] = [0.0, 0.0]
		var aggression: Array[float] = [0.0, 0.0]
		for i in step_order:  # In step order, so a fight with blue stepping first is the mirror of red first (D252).
			seen[i] = _round_points[i] * (1.0 + _rng.randf_range(-Judging.JUDGE_NOISE, Judging.JUDGE_NOISE))
			aggression[i] = _round_aggression[i] * (1.0 + _rng.randf_range(-Judging.JUDGE_NOISE, Judging.JUDGE_NOISE))
		var card: Array[int] = Judging.round_card(seen, _round_knockdowns, [aggression, _round_control], _round_impact)
		judge_totals[j][0] += card[0]
		judge_totals[j][1] += card[1]
		cards.append(card)
	_emit(FightEvent.ROUND_ENDED, FightEvent.NO_ACTOR, { "cards": cards })
	if clock.is_fight_over():
		var verdict: Dictionary = Judging.decision(judge_totals)
		_fight_over = true
		_emit(FightEvent.FIGHT_ENDED, FightEvent.NO_ACTOR, { "result": verdict.result, "winner": verdict.winner, "cards": judge_totals.duplicate(true) })
		return
	_next_round()


## Between rounds: both fighters back to their corners, recovered, with the round's tallies cleared.
func _next_round() -> void:
	for f in fighters:
		f.clear_action()
		f.recover_between_rounds()
		f.rocked_ticks = 0
		f.down_ticks = 0
		f.liver_ticks = 0
		f.winded_ticks = 0
		f.stagger_ticks = 0
		f.tied_up_ticks = 0
		f.bit_ticks = 0
		f.set_up_until = -1
		f.unanswered = 0
		f.knockdowns_this_round = 0
	_feints = [[], []]
	_round_points = [0.0, 0.0]
	_round_knockdowns = [0, 0]
	_round_impact = [0, 0]
	_round_aggression = [0.0, 0.0]
	_round_control = [0, 0]
	_round_grappling = [0.0, 0.0]
	clock.start_next_round()
	_to_corners()


## This round's points split the way PRIDE's judges look at them (D141): the effort to finish,
## control (grappling, and pinning him on the fence), and aggression.
func _round_scores() -> Dictionary:
	var out: Dictionary = { Judging.FINISH: [0.0, 0.0], Judging.CONTROL: [0.0, 0.0], Judging.AGGRESSION: [0.0, 0.0] }
	for i in 2:
		out[Judging.FINISH][i] = _round_points[i] - _round_grappling[i]
		out[Judging.CONTROL][i] = _round_grappling[i] + _round_control[i] * Judging.FENCE_CONTROL_PER_S / FightClock.TICKS_PER_SECOND
		out[Judging.AGGRESSION][i] = _round_aggression[i]
	return out


## The fight went the distance under whole-fight judging: each judge, seeing it a little
## differently, gives it to whoever did more to finish it, then controlled it, then pushed it.
func _whole_fight_verdict() -> void:
	var picks: Array[int] = []
	var on: Array[String] = []
	for j in Judging.JUDGES:
		var seen: Dictionary = {}
		for what: String in Judging.WHOLE_FIGHT_ORDER:
			seen[what] = [0.0, 0.0]
			for i in step_order:  # As the round cards (D252).
				seen[what][i] = float(_fight_scores[what][i]) * (1.0 + _rng.randf_range(-Judging.JUDGE_NOISE, Judging.JUDGE_NOISE))
		var pick: Dictionary = Judging.whole_fight_pick(seen)
		picks.append(int(pick.winner))
		on.append(String(pick.on))
	var verdict: Dictionary = Judging.whole_fight_decision(picks)
	_fight_over = true
	_emit(FightEvent.FIGHT_ENDED, FightEvent.NO_ACTOR, { "result": verdict.result, "winner": verdict.winner, "judges": picks, "judged_on": on })


## The whole fight so far as PRIDE's judges add it up, before their own noise, including the
## round in progress (D141): {finish: [red, blue], control: [...], aggression: [...]}.
func fight_scores() -> Dictionary:
	var out: Dictionary = _fight_scores.duplicate(true)
	if clock.is_fight_over():
		return out  # the last round is already in
	var now_scores: Dictionary = _round_scores()
	for what: String in out:
		for i in 2:
			out[what][i] += now_scores[what][i]
	return out


func _finish(winner: int, result: String, stopped_by: String = "", why: String = "") -> void:
	_fight_over = true
	var data := { "result": result, "winner": winner }
	if stopped_by != "":
		data.stopped_by = stopped_by
	if why != "":
		data.why = why
	_emit(FightEvent.FIGHT_ENDED, FightEvent.NO_ACTOR, data)


## Each fighter's effective striking and grappling points so far this round, as the
## judges add them up before their own noise (Judging): for the HUD's rough estimate.
func round_points() -> Array[float]:
	return _round_points.duplicate()


## Each fighter's rocks and knockdowns scored this round (a 10-8 for out-landing needs one, D120).
func round_impact() -> Array[int]:
	return _round_impact.duplicate()


func _average_stat(f: FighterState, ids: Array) -> float:
	if ids.is_empty():
		return FighterState.DEFAULT_STAT
	var total: float = 0.0
	for id: String in ids:
		total += f.effective_stat(id)
	return total / ids.size()


## Records an event, lets both fighters' decision steps hear it (tells, reads,
## and later read calls and drilled rules), then tells listeners.
func _emit(type: String, actor: int = FightEvent.NO_ACTOR, data: Dictionary = {}) -> void:
	if _fight_over and type != FightEvent.FIGHT_ENDED:
		return  # Nothing happens after the end, even later in the same tick (a call answered as the KO lands).
	var event := FightEvent.new(now, clock.current_round, type, actor, data)
	events.append(event)
	for k in step_order:  # Both see it in step order, as they roll their reactions (D252).
		decisions[k].on_event(views[k], event)
		if corners[k] != null:
			corners[k].on_event(views[k], event)
	event_emitted.emit(event)
