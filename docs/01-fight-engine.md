# 01 — Fight Engine & Coaching

> The heart of the game. Related decisions: D1, D5, D6, D9–D12, D20, D27–D33.
> Status: **design draft**. Numbers are starting points for the prototype, not final balance.

---

## 1. Goals

1. A call made at the right moment **visibly wins exchanges**. A call made at the wrong moment
   **visibly loses them**.
2. The player can always answer **"why did that work / fail?"** from what was on screen.
3. Fighters behave like *themselves*. A wrestler with a big ego and a striker with a calm
   counter style should feel different even with no calls at all.
4. The simulation runs **headless and deterministically** (seeded) so we can balance it with thousands of
   auto-fights.

---

## 2. Time model

| Concept | Value (draft) | Notes |
|---|---|---|
| Fight time per round | 5:00 | Standard MMA |
| Real time per round | ~2:30 | Time scale **2×** (D9) |
| Simulation tick | **100 ms of fight time** | 10 ticks per fight-second, 20 ticks per real second at 2× |
| Slow-mo | 0.5× real (= 1× fight time) | Costs nothing. Accessibility setting: unlimited |
| Active pause | Optional setting | Calls can be queued while paused; opponent AI is frozen too, so it's fair |

The simulation never reads frame time. Presentation interpolates between ticks. That keeps the simulation
deterministic and lets it run headless at 1000× for balance tests. In the game, `game/fight_driver.gd` feeds the ticks at the
chosen speed (Normal, Fast, slow-mo, auto slow-mo, pause): `06` §6.3 (D117).

### 2.1 Speed budget and how it's checked (D105)

A fight must simulate at least **1000× faster than fight time**: a 3 × 5:00 fight in under 900 ms, the 60-second self-check
fight in under 60 ms. Two checks enforce it:

| Check | Where | Budget |
|---|---|---|
| Full fight | `tests/sim/fight/test_fight_sim.gd`, `test_a_full_fight_runs_over_1000x_faster_than_fight_time` | 900 ms |
| Self-check fight ("Runs over 1000x faster than fight time") | `game/sim_check.gd`: the debug console's **Run test fight**, also run in CI by `tests/game/test_sim_check.gd` (5 seeds) | 60 ms (`ROUND_SECONDS`) |

**The rule (D105):** a timed fight that comes in over budget is simulated again, up to 3 runs in all, and the fastest run
counts. A fight under budget on its first run is timed once. GitHub's shared test machines vary about 1.6× in speed and
sometimes stall for a moment: on 2026-10-25 the same code ran the full fight in 967 ms on one machine and 380 ms on another.
A sim that is really too slow is slow on every run, so it still fails. To change the number of runs, edit `TIMING_TRIES` in
`game/sim_check.gd` and the `3` in the full-fight test; keep them the same.

**The CI margin (D105, added with #19):** even the fastest of 3 runs can miss on a slow machine: two runs of PR #47 took
60–66 ms, and the same balance fights took 120 s on those machines against 76 s on a green run. So on CI (where the `CI`
environment variable is `true`, as on GitHub Actions) both budgets are 1.5× longer: 90 ms and 1350 ms. A sim that really got
50% slower still fails; local runs and the in-game **Run test fight** keep the 1000× budget. The time is printed on every run
(the full-fight test's line in the test log, the self-check's detail), so a creeping slowdown shows before it fails. To change
the margin, edit `CI_MARGIN` in `game/sim_check.gd` (both checks use `SimCheck.budget_ms`).

**Where the time goes** (profile of a full fight, 2026-10-25, about 0.6 s here): the AI's feet (`preferred_distance`) and
choice (`choose`) each tick, `FighterState.effective_stat` (2–4 µs a call, about 30,000 calls a fight), walking (`_move`) and
the cage checks. Speed-ups made with #14 (PR #40), about 20%, none of which changed a single fight:

- `effective_stat`, `tired`, `hurt`, `max_stamina` and `regen_tick` read `stats` directly, and head hurt is worked out once
  per `effective_stat` call (`is_panicking()` is the same test).
- `Octagon.keep_inside` and `Octagon.proximity`, and the AI's fence check (`_fence_behind`), skip the eight fence-panel
  checks for points well inside the cage (`Octagon.CLEAR_INSIDE`, `CLEAR_OF_NEAR`, `FighterAI.CLEAR_OF_FENCE`).
- The sim works out the fighters' distance once per step and once per space update.
- `FightView.band()`, `step()`, `distance()` and `roll()` read the sim reference directly.
- The AI looks up all four style leanings once a second (`LEAN_EVERY`), and walking pace, the footwork contest and the
  range plan are cached too (`FightSim.FEET_EVERY`, `FighterAI.PLAN_EVERY`).

More with D107 (PR #42), which first made a fight about 4% slower and then ended up about 5% faster than before it, again
without changing a fight (event hashes checked on 60 fights across every data/fighters pair):

- Each tick's footwork is one call that fills one reused `FeetPlan` instead of separate calls for distance and circling.
- `FightView.distance()`, `band()` and `roll()` work from the fighters, the position state and the RNG the view holds,
  instead of going through the sim.
- The sim's announce state for range and cage proximity is three small arrays instead of nested dictionaries.
- The footwork refresh works out each fighter's Footwork once instead of three times.

**Speed work must not change fights.** Run the same fights (same seeds and fighters) before and after, and compare a hash of
each fight's event list (`JSON.stringify(sim.events_as_dicts()).md5_text()`). If any hash differs, the change altered
behaviour: re-run the balance harness and treat it as a design change. The golden fights (§2.2) make the same check on every
PR for four fights.

### 2.2 Golden fights (D122, #35)

A few whole fights are pinned so that a change which alters fights can't slip through unnoticed (risk R9 in `04`): a
balance number, the AI, a coaching bot or a drilled rule that changes any of them fails the tests until the new results are
pinned on purpose, and the PR then shows the old and new numbers side by side.

| Fight | Covers |
|---|---|
| Kicker vs Boxer, no corners (seed 35005; 35003 until D235 and 35002 until D253, each time it became a decision) | The striking engine and judges on their own: a KO for the Kicker in round 1 (since D236; a KO for the Boxer in round 2 after D235) |
| Wrestler vs Kicker, ideal corner vs AI corner, Wrestler drilled on catch-kick-and-shoot at 80% (seed 35006) | Calls, a drilled rule firing, takedowns, ground and pound, feints (D131): a decision for the Wrestler (since D257's corner; a TKO in round 3 after the ground grips, D263–D264; a decision since D236 with D255 and the ground-and-pound variety; a TKO in round 1 with D236 alone; a decision after D233; a TKO for the Wrestler in round 2 after D131) |
| Wrestler vs Boxer, AI corner for the Boxer, Boxer drilled on sprawl-on-the-shot at 80% (seed 35011; 35007 until D130, when it became a decision) | Sprawls, the opponent's corner and rules, passes, side control and the back (D130), blind shots (D131): a submission for the Wrestler in round 2 (since D236 with D255 and the ground-and-pound variety; a TKO in round 3 with D236 alone; a submission in round 2 after D253; a decision after D131, a TKO in round 3 after D130) |
| The check fighters, amateur adult rules (seed 35001) | A ruleset other than pro: 3 × 3:00, a split decision |

**What's pinned:** each fight's winner, result, the round and second it ended, the number of events, knockdowns, strikes
thrown and landed, takedowns, calls made and drilled rules fired, and a hash of the whole event list (the same hash as §2.1).
The numbers are there so a failure reads in plain words ("landed_red was 111, now 92"); the hash catches everything else.

**The checks** (`tests/sim/balance/test_golden_fights.gd`):
- Every golden fight plays out exactly as pinned.
- Every golden fight replays from its saved seed and command log (`FightSim.record()`) to the same event hash, coaching bots
  and drilled rules included.
- Between them the golden fights still have live calls, a drilled rule firing, takedowns, a KO or TKO, a decision and a
  non-pro ruleset; if a re-pin loses one, pick another seed.

**When a change is meant to change fights:** run

    godot --headless --script res://tools/golden.gd -- --update

commit `tests/golden/golden_fights.json`, and say in the PR what changed and why. Without `--update` the tool only prints which
fights changed and how. If two PRs both re-pin, the second one to merge re-runs the update after merging main instead of
merging the file by hand. Without Godot to hand (a cloud session), CI's Tests job has a **Golden fights re-pin preview** step that
prints the file as `--update` would write it whenever a fight changed; copy that into `tests/golden/golden_fights.json` (D126). Speed work (§2.1) must leave the pins alone.

**To change the set:** edit the setup of an entry (`name`, `seed`, `red`, `blue`, `ruleset`, `corners` as `[red, blue]` bot
styles, `rules` as `[red, blue]` lists of `"rule_id@drilled"`) or add one in the same shape, then run the update. Never edit the
`pinned` numbers by hand. The pinned columns are `PINNED` in `sim/balance/golden_fights.gd`; the fights are set up the way the
balance harness sets them up (`FightSummary.setup`). The four fights take about 3 s to play, run twice in the test (once
played, once replayed).

### 2.3 Running the harness on every core (D123, #35)

The balance harness (`tools/balance.gd`) plays its fights in several Godot processes at once: by default one per CPU core,
or `--jobs=N` for N (`--jobs=1` plays them all in one process, as before). The first process starts the others with the
same arguments plus `--worker=k`; process k plays fights k, k+N, k+2N… of the run's list, so every process gets some of every
pair and corner, writes its rows to a file in the output folder, and the first process puts them back in the run's order.
The CSV and summary are byte for byte the same whatever N is (checked with 1, 3 and 4 processes against the harness before
this change). The list and the sharing out are `sim/balance/harness_jobs.gd`, with tests in
`tests/sim/balance/test_harness_jobs.gd`.

**What was measured first** (2026-10-26, 4 cores, Kicker vs Boxer, about 0.85 s a fight on one core):

| Idea | Result | Kept? |
|---|---|---|
| Quiet mode: don't keep the fight's event list | Under 2% faster, within run-to-run noise. Events are still made for the AI and corners, so only the list is saved | No |
| Threads inside one Godot process | 1.6× on 4 cores (32 fights: 29.6 s → 18.2 s), the same with a copy of the data per thread | No |
| Separate Godot processes | 3.9× on 4 cores; a 35-fight run with corners and rules went from 31 s to 10 s | Yes |

**Exact numbers:** rows come back from the other processes as Godot's binary format (`FileAccess.store_var`), not as text:
as text some values lose their last digit (21.900000000000002 came back as 21.9), which could tip a summary figure.

**To change it:** the default number of processes is `OS.get_processor_count()` in `tools/balance.gd`; how fights are shared
out is `HarnessJobs.share`. If a process fails, the harness says which one and writes nothing. CI's balance snapshot uses
the default, so it runs on all of the test machine's cores.


### 2.4 How sure a balance number is (D250)

A balance number is a handful of fights' luck as well as the engine. Near 50%, 100 fights pin a win share to about ±10
points either way, 300 fights to about ±6 and 1,000 to about ±3. So the harness says how sure each number is, and how to
compare two versions of the engine without the dice deciding.

**Ranges.** The summary gives each corner's win share with its 95% range, e.g. `Kicker (red) 55.0% (45.3–64.4%)`: the true
share is very likely inside it. It's the Wilson score range (`BalanceStats.wilson`), which stays inside 0–100% and behaves
with few fights. The draws check and the Kicker vs Boxer exit test (60/40) show one too; when the exit test's range still
crosses 60%, it adds "too close to 60% to tell at this many fights". MET and MISSED still go by the number itself.

**Paired comparisons.** The harness plays a pair's coached fights, rules fights and plain fights on the same seeds (D123),
and a fight's coaching bot gets its own random numbers (`FightSummary.corner_seed`), so a coached fight and its plain twin
start from the same dice. The coaching and drilled-rule lines compare each fight with its twin: one difference per seed,
then the mean and its 95% range (`BalanceStats.paired`). Luck that hits both fights alike cancels out. For example,
`+15.0% (-1.1 to +31.1), 50.0% → 65.0%, 20 fights paired by seed`. If the seeds don't match up (an old CSV, or runs put
together by hand), the line falls back to comparing the two win shares, says "not paired", and the range is wider.

**Comparing two runs.** To see what a change did, run the harness before and after it with the same `--seed` and `--fights`,
then:

    godot --headless --script res://tools/balance_compare.gd -- --before=build/before/balance.csv --after=build/balance/balance.csv --columns=shots_red,shots_blue

Per pairing it gives how many fights played out differently (another winner, result, ending or number of events), each
corner's win share, draws and finishes before and after, and the seed-by-seed change with its range; `--columns` adds any
numeric CSV column. A range that doesn't cross 0 is a real change. The logic is `sim/balance/balance_compare.gd`.

**What a run was made from.** Each run writes `run.json` next to the CSV: the arguments, the commit (with `+changes` when
files differ from it), a short hash of every file in `data/`, the Godot version, the seeds, how long it took and how much
computer time one simulated tick took. The summary starts with the commit, the data hash and the Godot version. Two runs
with different data hashes used different fighters, moves or numbers.

**Speed.** The harness prints `Speed: N µs of computer time a simulated tick`. D105's budget is 100 µs (900 ms for 9,000
ticks). The figure includes the harness's own counting each tick (movement shares, stamina lows), and with several processes
on one machine they slow each other a little, so it reads a bit higher than the full-fight test. It's printed, not written
to `summary.txt`, which must be the same whatever `--jobs` is (D123); `run.json` keeps it. On 2026-10-30, in a cloud
session with 4 cores, Kicker vs Boxer and Wrestler vs Kicker came to about 120 µs a tick with one process or four.

**Who chose the moves.** Each row counts the moves each fighter started by the layer that chose them (`chosen_ai_*`,
`chosen_call_*`, `chosen_rule_*`, `chosen_command_*`, from the `by` on each move's first event, `DecisionLayer`), and the
summary's *Chosen by* line gives the shares. A call that only tilts the AI (a focus, a read) counts as the AI's, and so do a
combination's follow-ups; only calls and rules that pick the move themselves count as theirs. With the ideal corner the
Wrestler's calls chose about 17% of his moves against the Kicker (12 fights).

**To change it:** the 95% (`BalanceStats.Z`), the exit test's warning (`BalanceReport.checks`), how fights are paired
(`BalanceReport._change`, `BalanceCompare.report`) and what `run.json` holds (`tools/balance.gd`). Tests:
`tests/sim/balance/test_balance_stats.gd`, `test_balance_report.gd`, `test_balance_compare.gd`, `test_fight_summary.gd`.

### 2.5 Neither corner has an edge (D252, D253)

The two fighters step one after the other inside each tick: one decides, moves, starts and lands his move, then the other
(`FightSim.step_order`). Until D253 red always stepped first; now they take turns, a tick each (below). That order is the
only difference between the corners. Everything that used to go by a fighter's number now goes by the step order instead: when a move started this tick is first seen (the
other fighter sees it next tick if it started after his own step: `FightView.steps_after_me`, used by the AI's reads, the
drilled rules and the live calls' reads), which fighter rolls first when an event comes in (`FightSim._emit`), and the
judges' noise (round cards and PRIDE's whole-fight judging). None of that changed a fight on its own
(D252 kept red stepping first).

**What the step order is worth** (2026-10-30, 400 fights each of Kicker, Boxer and Wrestler against themselves, played once
with red stepping first and once with blue): whoever stepped second won about 51% and whoever stepped first about 48%
(2,400 fights; the gap is about the size of the noise, but it leaned the same way in 5 of the 6 runs). The first to step holds
the centre more, because he moves first each tick: nearer the centre 60% of standing time against 38% in the Boxer mirror,
56% against 45% in the Wrestler mirror. Strikes, damage and takedowns came out even. In real fights red always steps first,
so this is the blue-corner lean.

**The check:** `tests/sim/fight/test_corner_symmetry.gd` plays fights (two Boxers, two Wrestlers, a Kicker and a Boxer, a
BJJ fighter and a Kicker, a Judoka and a Boxer) and the same two fighters in the other corners with blue stepping first, and
checks they're the same fight mirrored through the cage's centre, tick by tick (`MirrorCheck`). By hand:

    godot --headless --script res://tools/mirror_check.gd -- --red=kicker --blue=boxer --seed=1

prints the tick where the two part, with each fight's last events. The harness's `--blue-first` plays a whole run with blue
stepping first (its summary says so at the top), so `tools/balance_compare.gd` can set it against the usual run.

**One known hair's-breadth difference:** a fighter squeezed into a corner of the cage is pushed off the two panels one after
the other, in a fixed order (`Octagon.keep_inside`), so the mirror of that spot can come out a few millimetres different and
the two fights part from there. It favours no corner (both fighters use every part of the cage); the test's seeds avoid it.

**Taking turns (D253, Kyle picked it 2026-10-30).** Red steps first on even ticks and blue on odd ticks
(`FightSim.first_at`; `first_step` says who has the fight's first tick, 0 = red, and only the corner check sets it to 1). At
10 ticks a second the two swap ten times a second, so neither keeps the edge of stepping second. Three parts of the AI had
quietly assumed the old order and had to change with it:

- **How fast the opponent is walking in.** The AI's tracking (`FighterAI._track`) used to measure it from where the
  opponent stood when it last looked. With a fixed order that gap was always exactly one of his steps; with turns it is
  sometimes two steps and sometimes none, so the Kicker read the Boxer as charging one tick and standing still the next and
  stopped keeping his range (Kicker vs Boxer fell to 5%, Wrestler vs Kicker rose to 97%). It now reads the opponent's
  latest step itself (`FightView.opponent_stride`), which is the same whatever the order.
- **When his move lands.** The AI's look ahead ("his move hits in 3 ticks", "he's winded for 4 more") counts ticks from
  where it stands. Whether the other fighter's counters have already ticked down this tick depends on who stepped first,
  and that now changes tick to tick, so the look ahead counts the other fighter's turns instead
  (`FightSim.turns_before`, used by `phase_ahead` and `flags_ahead`).
- **A quick kick landing between two of his turns.** Taking turns, a fighter sometimes takes two turns in a row (second on
  one tick, first on the next), so a move whose active part lasts one tick, like the calf kick, can land and be over between
  two of the other fighter's turns. The look ahead never saw it "active" and the AI never tried to check it (the Boxer's checks
  fell from 8 to under 3 a fight). It now counts a move it first sees already past its active part as landing just before
  that turn (`FighterAI._ticks_until_active`), and the check's timing window is the exact one (`_guard`).

**What it did** (2026-10-30, 100 fights a pairing, seed 1, main at D234 → taking turns): Kicker vs Boxer 40 → 40% (Kicker;
at 400 fights 45.0 → 44.5%), Wrestler vs Kicker 62 → 74%, Wrestler vs Boxer 83 → 80%, Judoka vs Kicker 25 → 31%, Judoka vs
Boxer 73 → 76%, Judoka vs Wrestler 96 → 97%, BJJ vs Kicker 10 → 17%, BJJ vs Boxer 90 → 82%, BJJ vs Wrestler 44 → 60%, Muay
Thai vs Kicker 88 → 85%, vs Boxer 64 → 68%, vs Wrestler 63 → 68%, the check fighters 74 → 70%, Pressure wrestler vs Kicker
95 → 93%, Brawler vs Kicker 77 → 79%, Boxer vs Counter-striker 76 → 78% (the first fighter named wins). At 100 fights a
pairing the 95% range is about ±10 points, so most of these are the dice; Wrestler vs Kicker and BJJ vs Wrestler moved more.

**The mirrors after it** (400 fights each, seed 1): Kicker mirror red 50.5% blue 49.0%, Boxer mirror 47.0% against 53.0%,
Wrestler mirror 51.2% against 47.5%: about 49.6% each corner over the three, even within the dice. One thing still leans: in
the Boxer and Wrestler mirrors the fighter who steps second on the first tick is "nearer the centre" more often (Boxer mirror
61% of standing time against 38%, the same the other way round with `--blue-first`; Wrestler mirror 54% against 46%; Kicker
mirror 52/48). It is the same on the ticks where red steps first and the ticks where blue does, and the two stand on average
within 6 cm of the same distance from the centre (40 Boxer mirrors: 1.56 m and 1.62 m), so it's which of the two is a hair
further inside, set early and kept, rather than an edge in the fight. Worth watching if a later change makes holding the
centre count for more.

**Cutting the cage at close quarters.** The two turns in a row help a fighter slipping out past a cutter on the fence: in the
toy test (`test_standing_game.gd`, a Footwork 20 mover against a Footwork 50 presser, 300 ticks from pinned) he used to stay
pinned about 280 ticks in most fights whoever stepped first, and now about 80 (16 seeds; swapping only every 10 or 20 ticks
instead of every tick still lets him out more). Better feet still get out much faster (25 and 17 ticks over four fights
against 259). In whole fights it barely shows: the Kicker against the Boxer is shut in 1:38 a fight against 1:41, gets back
to the middle 98% of the time either way, and the cutters' pairings above are within the dice.

Every fight is different from before, so the golden fights were re-pinned (the Kicker vs Boxer fight moved to seed 35003 to
keep a KO among them, §2.2), and eight tests that had counted on red stepping first were changed: two toy fights in
`test_fighter_ai.gd` and the replay test in `test_fighter_library.gd` use seed 1 (on the old seeds the toy Kicker barely
kicks and the replayed fight ends inside a minute), *Fire back!*'s timing allows for which fighter stepped first on the tick
of the miss, the self-check test uses seed 4 for seed 2 (which now ends in a guillotine before the bell), the fight screen's
between-rounds test uses a fight that reaches round 2 (and can no longer wait forever on one that doesn't), the cage-cutting
count lets the Kicker shut the Boxer in for a moment (2 ticks in three fights) as long as it's a twentieth of the other way,
and the footwork test above runs four fights each and asks for the poor mover to stay pinned a good while (over 150 of
1,200 ticks) and five times as long as even feet, not two-thirds of the time.

**To change it:** `FightSim.first_at` is the whole rule. Making both fighters move at once from where they stood at the start
of the tick would be the other way to remove the edge; it is a bigger change (every move would need resolving in pairs).

### 2.6 Behaviour contracts and the AI's parts (D254)

The golden fights (§2.2) catch a change; they can't tell a good one from a bad one. The outside review's sixth point was to
add contracts: things that must hold in every fight whoever wins it. `tests/sim/fight/test_behaviour_contracts.gd` plays 13
whole fights (every style in `data/fighters`, pro, PRIDE and amateur rules, the AI corner calling for both men, outside
fighters walked down by cage cutters), watches each one as it goes, and checks:

| Contract | How it's checked | The number |
|---|---|---|
| No fighter answers a move before he could have seen it | Every sprawl, check or slip the AI picks starts no sooner than the opponent's move started, plus a tick if it started after his turn, plus his reaction time fresh (`FighterState.reaction_ticks`; tired, it's only longer) | Over 50 answers looked at |
| A stuffed shot never counts as a takedown | A fighter's takedowns are exactly the takedowns that put him on top (not a failed one that put him underneath), and never more than his shots | Over 20 takedowns |
| Every move a fighter starts is legal where he is | Its `positions`, `roles` and the ruleset allow it at the moment it starts, whoever picked it (AI, call, rule or command) | Over 2,000 moves |
| Nearly every strike the AI picks is still in range when it lands | Under `OUT_OF_RANGE_UNDER` 15% of a fighter's AI strikes miss "out of range" (the opponent stepped out of it on its way), for fighters with 30 or more | The Kicker against the Boxer: about 10% |
| Every move the AI picks says which part of it chose it | The parts add up to the AI's moves, and are all ones the harness reports | |
| Defences never crowd out the rest of the AI | Under `DEFENCE_UNDER` 25% of a fighter's own moves are defences (for 50 moves or more), and the Kicker and the Boxer still throw their combinations | The Counter-striker defends most: about 16% |
| An outside fighter cut off onto the fence gets back to the middle | Fighters with Range under 0, across the fights: back in the middle after at least `ESCAPES_AT_LEAST` 80% of the times they were cut off | About 95% (117 of 123 in a first look) |

The contracts were checked by breaking one on purpose (the AI noticing a move with no reaction time): the first contract
failed in every fight with sprawls or checks in it.

**The AI's parts.** Every move the fighter's own AI picks now says which part of it chose it (`Decision.part`,
`FighterAI.PARTS`, counted in `FighterState.ai_parts` when the move starts, not on the fight's events, so no fight changes):
**defence** (a sprawl, check or slip on a move it read, or covering up rocked), **counter** (an opening it read, meeting an
advance, a guillotine on a shot, catching a burst), **combination** (the next strike of one), **set-up** (a tell it spotted,
the shot off its own feint), **lead** (a move of its own), **cage** (herding feints, tying him up when shut in), **tied up**
(the clinch and the ground) and **downed** (the opponent down). The harness adds the `ai_<part>_red`/`_blue` columns and an
*AI parts* line under *Chosen by*. A first look, 40 fights a pairing: the Kicker against the Boxer leads 43%, counters 31%,
combinations 20%, defence 3%; the Boxer combinations 36%, leads 28%, counters 25%, defence 6%; a Counter-striker against a
Pressure wrestler defends 16% and counters 24%; grapplers pick about 70% of their moves tied up.

**Found on the way:** a striker who isn't an outside fighter (the Leg-kick specialist, Range +10) plants his feet and fights
when he's shut in (D234), so against a Dirty boxer he got back to the middle 0 times of 20 cut-offs and was shut in for over
6 minutes of the fight. That's the style answer Kyle picked; the last contract leaves those fighters out.

**To change it:** the three numbers at the top of the test file, the fights in `FIGHTS`, the parts in `FighterAI.choose`
(`_part`) and their names in `BalanceReport.PART_NAMES`.
---

## 3. Spatial model (D2, D33)

- The **octagon** is a 2D polygon (the isometric view is only for display). Fighters have positions
  and facing in cage space.
- **Distance bands:** Out of range → Long (kicks) → Mid (punches) → Pocket (hooks/uppercuts, knees) → Clinch.
- **Cage proximity:** Centre / Near cage / Pinned. This affects:
  - takedown odds (easier to finish against the cage, but cage-walking lets the defender get up),
  - escape odds (circling out is harder when cut off),
  - strike options (fence grab = foul, D20).
- **Cutting off the cage (D107):** a pressure fighter steps sideways to stay between the opponent and the middle of the
  cage, so the opponent's way out along the fence shuts. It only bites once the opponent is near the fence (in open space
  there's no way out to shut), and how much of it gets done is a Footwork contest. This replaces the earlier idea of a
  "space" value that drops while you're pressed without circling: the space is now the fighters' real positions. Built as
  §20.2.

---

## 4. Position state machine (MMA phases)

```
STANDING ──(clinch entry)──► CLINCH (open / cage / plum / body lock)
   ▲  │                         │  ▲
   │  └──(takedown / trip)──────┼──┼──► GROUND
   │                            │  │    ├─ Full guard (top/bottom)
   └──────(stand-up / break)────┴──┘    ├─ Half guard
                                        ├─ Butterfly / open guard
                                        ├─ Side control
                                        ├─ Mount
                                        ├─ Back mount / back control (seated)
                                        ├─ North-south
                                        ├─ Turtle / front headlock
                                        └─ SCRAMBLE (transitional, contested)
```

Every position defines its **available actions**, its **available calls**, its stamina drain, how much
control it scores for the judges, and its striking damage multipliers.

In the engine so far: standing, the clinch (one position), full guard, half guard, side control, mount, back control and the
scramble (D130, §28), plus the submission position a hold is fought in (D126). Butterfly/open guard, north-south and
turtle/front headlock are still to come.

### 4.1 The model in the engine (#34, `12` §3 item 4)
- **One shared situation.** Positions are relational (one fighter is on top), so the fight holds a single **situation** both
  fighters read (`sim/fight/situation.gd`): the phase (standing / clinch / ground), the named position (`standing`,
  `full_guard`, …) and each fighter's **role** in it (`neutral` standing, in the clinch and in a scramble, `top` / `bottom` in
  full guard). Fighters no longer carry their own position. Every round starts standing.
- **Transitions are data.** Each position file lists how the fight leaves it: *this action, landed by the fighter in this role,
  takes the fight to that position with these roles* (`09` position@2), and optionally where it goes when the move only half
  works (a scramble). The code only applies what the data says (`FightSim.apply_transition`); resolution calls it when a
  takedown, clinch move or get-up works (§21). Adding a position is a content change, not a code change.
- **The cage carries through.** Where the fight is in the cage stays with the fighters' own spots. Tying up or taking someone
  down happens on the spot where the opponent stood, so a takedown on the fence stays on the fence, the bottom fighter keeps
  `BACK_TO_CAGE` (wall-walking), and getting up separates the fighters right there, a standing gap apart.
- While tied up (clinch or ground) nobody walks, and the range reads `clinch` whatever the distance.
- **Done with #15 (§21):** actions say which roles may use them (only the bottom fighter gets up), clinch entry, clinch break,
  get up and scramble are actions with their transitions in the data, and each position's stamina drain, control score and
  strike damage multipliers are applied. The standing minimum gap (`Octagon.MIN_GAP`) stays: see §21.6.

### 4.2 Playtest scope (D98)
The Phase 1 playtest ships a trimmed ground game (#15):

| In the playtest | After the playtest |
|---|---|
| Clinch (one clinch position), double leg, catch-kick single, sprawl, full guard top/bottom, get up, scramble; ground-and-pound and tie-ups from full guard (added early, D121, §24); the guillotine, triangle and armbar with a simple struggle (added early, D126, §25); throws, the guard pull and the sweep (D128, §26); half guard, side control, mount and the back with passes, escapes, the rear-naked choke and the arm-triangle (added early, D130, §28); the ankle lock, kneebar and heel hook (added early, D132, §30) | North-south, turtle, butterfly guard, the per-beat struggle calls (§9) |

---

## 5. Actions: the commitment model (the core idea)

Every action has four phases:

| Phase | Meaning | Vulnerability |
|---|---|---|
| **Telegraph** | Readable pre-movement (weight shift, dipped shoulder, hand drop). Length depends on technique skill; elite fighters telegraph less | Low |
| **Wind-up** | Committed; can't cancel cheaply | **Counter window opens** |
| **Active** | The strike/shot lands or gets defended | Depends |
| **Recovery** | Rebalancing. Off-balance flags apply (e.g. *on one leg*, *head off-centre*, *hands low*) | **Counter window** |

Each phase can set **state flags** that counters look for:

| Flag | Set by | Exploited by |
|---|---|---|
| `ONE_LEG` | Body/head kick, teep, knee | Catch-kick single leg, sweep, counter cross |
| `HANDS_LOW` | Lazy jab return, shot attempt, fatigue, a liver shot (D143) | Overhand, head kick, knee |
| `HEAD_LOW` | Level change, shot | Knee, guillotine, front headlock, uppercut |
| `COMING_IN` | Clinch entry (until it ties up), the first step of a double leg | Jab, cross, teep, knee: a strike that lands into it stops the entry (D114) |
| `LEANING` | Overcommitted hook/overhand | Counter hook, trip, level change |
| `BACK_TO_CAGE` | Pinned position | Double leg against the cage, knees in the clinch |
| `POSTURE_BROKEN` | Clinch control, being pulled into guard | Subs from the bottom, sweeps |
| `DOWN` | Knocked down, for the 2 s he's on the floor (D141) | Soccer kick, stomp (PRIDE rules only, §33) |

### 5.1 The example the whole game is built around: kick → takedown
- Opponent throws a **body kick**: telegraph 0.3 s, wind-up 0.3 s, active 0.2 s, recovery 0.4 s
  (fight time). `ONE_LEG` is set from wind-up through recovery, about **0.9 s of fight time ≈ 0.45 s real time** (all timings are whole 100 ms ticks; source: `data/actions/body_kick.json`).
- A takedown that *starts* while `ONE_LEG` is active gets a large bonus (e.g. +35% success) and turns into a
  **catch-kick single leg**.
- The same shot against a balanced opponent with good TDD is likely to get sprawled on (D29), and shooting
  into a knee (`HEAD_LOW` against a knee in active frames) risks a **flash KO**.

Even counting the fighter's reaction delay (§6.2), a 0.45 s real-time window is too short for pure reaction. Players
hit it in two ways:
1. **Anticipation**: the player knows (from tells/scouting) *when* the kick is coming and calls just before it.
2. **Read calls**: see §6.1. These are the core skill, and they make "perfect timing" achievable without twitch reflexes.

---

## 6. Coaching

### 6.0 The four coaching layers (D82)

| Layer | When set | What it does |
|---|---|---|
| 1. **Gameplan** | Pre-fight (adjustable in the corner) | Strategic preset (Pressure / Counter / Range / Wrestle-heavy / Conserve) that biases the AI's action weights |
| 2. **Drilled rules** | Pre-fight / between rounds; must be **drilled in camp** | 2–3 slots of *trigger → action* ("Opponent body kick → catch-kick single"). Fire automatically with the fighter's own reaction time |
| 3. **Live calls** | During the round | Now calls + read calls (§6.1), with delay, compliance and the voice meter |
| 4. **Corner** | Between rounds | Recovery, cutman, adjustments, motivation (§10) |

**Drilled rules in detail:**
- A rule = **trigger** (an opponent event like *body kick telegraph*, *level change*, *back to cage*; or a state like
  *opponent stamina < 30%*) + **action** (a technique the fighter knows) + **priority**.
- **Reliability (0–100%)** = how many reps it got in camp (the "Rule drilling" session in the middle-camp phase) ×
  Fight IQ × technique proficiency. Each fire also gets fatigue/damage penalties.
- A rule fires only if it's eligible (range, position, stamina, not committed) and passes the reliability roll. Otherwise
  the log says why (*"Catch-kick rule: too tired to fire"*).
- **Cooldown** after each fire, so rules can't be farmed. Opponents with high Fight IQ **adapt** to a rule that fires
  repeatedly: they telegraph less or bait it (counter-play, risk R4).
- **Slots:** 2 at the start, a 3rd from the coach's *Tactician* skill / experience. Advanced conditions
  (AND filters, stamina thresholds, fallbacks) are a later unlock (Foundation doc "advanced rule builder").
- Rules and read calls work together: a rule is the **pre-planned** answer, and a read call is the **improvised** one.
- In the engine (the slots, reliability, cooldown, adapting, the presets, and how to try them): §23.

### 6.1 Two kinds of live call (D49)

| Kind | Example | Behaviour |
|---|---|---|
| **Now call** | "SHOOT!", "Clinch!", "Get up!" | The fighter attempts the action as soon as they've processed the call. Pure timing. |
| **Read call** (primed) | "Catch the kick!", "Counter the jab!", "Watch the shot!" | The fighter stays primed for N seconds. If the trigger happens, they react with *their own* reaction time, which is much faster than call delay. Priming has a cost: e.g. watching for kicks makes them slightly slower to defend punches. |

Read calls reward **knowing the opponent** (tells, scouting). Now calls reward **timing**. The best
players combine them: prime the read, then follow up with a now call.

### 6.2 Call processing pipeline

```
Player presses call
   └─► Voice check (D28): costs voice; low voice = garbled call
        └─► Delay = base 0.6 s of fight time (6 ticks, D92)
                    × (1 - FightIQ bonus)
                    × (1 - CoachTrust bonus)
                    × (1 + fatigue + damage + crowd noise penalties)
                    × (coach level bonus, D15)
             └─► Compliance roll (D5): ego, trust, panic, personality conflicts
                  ├─ Ignored  → fighter shakes head / visible "nah" indicator
                  └─ Accepted → becomes high-priority intent for the AI
                         └─► Feasibility check (position, stamina, distance)
                              └─► Action executes with modifiers from timing, flags, skills
```

**Visible to the player:** a small "processing" ring above the fighter fills over the delay, and the
voice meter. Ignored calls get a clear animation and a text feed line.

### 6.3 Voice meter (D28)
- Maximum 100. A call costs 15–30 (big calls cost more). Regenerates about 8/s of fight time.
- Below 30, calls are *garbled*: +50% delay and −20% compliance.
- Spamming the same call within 3 s also drains **Coach Trust** a little.
- Crowd noise (venue size, hometown, big moment) increases delay, not voice cost.

### 6.4 Call catalogue (start, D27)

| Intent (starts unlocked) | Unlocks into (via techniques, D6/D13) |
|---|---|
| **Pressure** | Cut the cage, Body work, Walk him to the fence |
| **Circle out** | Pivot off the cage, Angle out, Lateral stick-and-move |
| **Work the range** | Jab to the body, Calf kicks, Teep the advance |
| **Takedown** | Double leg, Single leg, *Catch-kick single*, Trip from clinch, Body-lock throw |
| **Clinch** | Collar tie, Thai plum knees, Underhooks against the cage |
| **Defend the shot** | Sprawl, Guillotine on the shot, Whizzer |
| **Get up** | Wall-walk, Technical stand-up, Hip escape to guard |
| **Survive** | Tie up, Hold on, Cover up |
| **Stay safe** (D31) | Coast mode: lower output, high defense, no risks |
| *Ground (context)* | Pass guard, Ground-and-pound, Posture up, Sweep, Hunt the sub (Kimura, RNC, Arm-triangle...) |

Context-sensitivity: only calls that are possible in the current position appear prominently, and the rest are dimmed.

In the engine (what each call does, the numbers, and how to try them): §22.

### 6.5 Habits from calls (D32)
- Track how often the player calls an intent in a given situation (e.g. "Takedown after opponent kicks").
- A fighter with **Adaptive** or **Coachable** traits gradually adds a small AI weight toward that response, up to a cap.
- **Stubborn** fighters don't absorb habits. **Ego** fighters absorb only calls that *worked*.

---

## 7. Fighter AI (without calls)

A **utility AI**: each tick the fighter scores the available actions:

`score = base_tendency × gameplan_bias × situation_modifiers × stamina_factor × personality × habits`

- **Tendencies** are part of the fighter data (e.g. jab 0.8, leg kick 0.6, shot 0.2).
- **Tells** (D11) are *patterns written into tendencies*: conditional rules such as
  "after a blocked double jab → 70% throw a right body kick within 1.5 s" or
  "when down on the scorecards → shoot more often, with a longer telegraph".
- Calls temporarily override or boost scores for one intent.

In the engine: §20.

---

## 8. Damage, stamina, state

| Resource | Effect |
|---|---|
| **Stamina** (short-term) | Every action costs stamina. Low stamina → longer telegraphs, slower recovery, bigger flags (hands drop) |
| **Cardio** (attribute) | Regen rate; how deep the tank is across rounds |
| **Head damage** | Chin threshold. Rocked state (wobbly; huge counter vulnerability), knockdowns, KO |
| **Body damage** | Drains max stamina; liver-shot fold possible |
| **Leg damage** | Slower movement, stance switch forced, eventually the leg gives out |
| **Cuts/swelling** | Vision penalty on one side (more tells missed, punches from that side land more), doctor-check risk |
| **Composure/Momentum** | Panic → more ignored calls, wild swings. Momentum → more accuracy and willingness |

Lucky punches (D12) come from: a clean counter on a rocked/`LEANING` fighter + a chin roll. They're rare,
but happen often enough that an underdog always has a chance.

---

## 9. Submissions: coach-driven struggle (D10)

1. A sub attempt starts from position + flags (e.g. back mount + `HANDS_LOW` from fatigue → RNC).
2. **Lock-in phase**: the defender's stats contest the attacker's. If it locks, play moves to the **struggle sequence**.
3. The struggle is 3–5 beats (~1–2 s real time each, auto slow-mo). Each beat shows the **danger meter** and
   2–4 coach calls: e.g. *Hand-fight! / Tuck the chin! / Turn into him! / Stack! / Tap!*
4. Each beat has a *correct* response determined by the hold's stage (each sub type has a script) plus the
   fighter's skills. The right call drops danger; the wrong call raises it; no call = fighter's own AI choice.
5. Danger hits 100 → tap (or a "go to sleep" stoppage). Escape → reversal or scramble.
6. **On offence** it's mirrored: "Get the hooks in! Flatten him! Switch to the arm-triangle!"

In the engine so far (D126, §25): three holds and a simpler struggle, a danger meter moved by stats each beat with one call a
corner (*Finish it!* / *Defend the sub!*). The per-beat menu of calls with one right answer (steps 3–4) is still to come.

---

## 10. Between rounds: the corner (D30)

- A **60-second real-time budget** (the clock is visible). Each action uses time:
  - **Cutman minigame** (D20): ~15–25 s. Pressure + Vaseline/adrenaline on a cut. Success lowers bleeding and doctor risk.
  - **Ice / enswell** on swelling: ~10 s
  - **Water / breathing**: recovers stamina; skipping it costs cardio
  - **Tactical instruction** (pick up to 2): gives a next-round bias, e.g. "He drops his hand after the jab" (reveals a tell
    and adds a read-call bonus), "Go to the body", "Take him down early", "Win this round: you're down"
  - **Motivation** (pick 1 tone): Calm / Fire up / Tough love. The effect depends on personality and trust
- **Throw in the towel** (D31): available any time, and at the corner as a dedicated button with a confirmation. In the engine
  it's a `throw_towel` command: the fight ends on that tick as a TKO for the other corner (`stopped_by: "towel"`), so it replays (D117).

---

## 11. Officials, fouls, scoring (D20)

- **Judges**: 10-point must system. Each round is scored on effective striking/grappling > aggression > cage control.
  Under PRIDE rules the judges score the whole fight instead: the effort to finish, then control, then aggression (§33.4, D141).
  Judges have personality weights (e.g. *loves takedowns*, *volume-striking fan*, *damage-first*). The player can
  learn their reputations over a career.
- **Referees**: stoppage threshold (early vs late), stand-up impatience, foul strictness.
- **Fouls**: eye poke, groin strike, illegal knee to a grounded opponent, fence grab, strike to the back of the head.
  Fouls come from personality (dirty/reckless), fatigue and position. Outcomes: warning → point deduction → DQ,
  plus a pause for the fouled fighter's recovery.
- **Doctor checks** for cuts and swelling between rounds or after a ref pause.

---

## 12. Commentary feed (D20)

- Template-based play-by-play driven by simulation events (`KICK_CAUGHT`, `TAKEDOWN_SUCCESS`, `ROCKED`...).
- Two commentator personalities (play-by-play + colour), with spikes for big moments.
- Also a teaching tool: *"He's been dropping that left after every jab, and his corner has spotted it!"*

---

## 13. Fight end and stats

- Finishes: KO, TKO (ref), TKO (doctor), TKO (corner/towel), Submission, Decision (unanimous / split / majority), Draw,
  DQ, No contest (accidental foul).
- Post-fight stats (FightMetric style): significant strikes by target, takedowns landed/attempted, control time,
  sub attempts, knockdowns, **call success rate** and **perfect-timing calls**.

---

## 14. Resolved questions
- F1 → **D49**: now calls + read calls are both in.
- F2 → **D50**: active pause on Easy difficulty only.
- F3 → **D51/D66**: scouted tells show an on-screen cue. The head coach's *Reading* stat makes it appear earlier.
- F4 → **D52**: perfect-call flourish (slow-mo + sound + feed line).
- F5 → **D53**: auto slow-mo on big moments (can be switched off in settings).
- F6 → **D54**: keyboard + mouse at launch (hotkeys 1–9 + clickable call bar). Controller later.

## 15. Resolved (round 2)
- F7 → **D67**: up to 2 read calls stacked, with a bigger attention cost.
- F8 → **D68**: the opponent's corner calls are audible/visible, so you can counter-call.
- F9 → **D69**: difficulty affects both opponent AI and assistance.

## 16. Merged from the Foundation doc (see `05`)
- **Speed controls (A3):** Normal (2× fight time) / Fast (4×, quiet moments) / Tactical slow-mo (test 0.15–0.5×). The simulation clock slows, not only the animation.
- **Autonomy principles (A2):** the fighter never silently replaces the gameplan, never attempts impossible actions,
  never switches instantly between incompatible actions, and always defends against immediate danger.
- **Difficulty dimensions (A4):** *Combat challenge* (opponent AI quality, adaptation) · *Simulation realism*
  (stamina/injury/weight-cut strictness) · *Coaching assistance* (cues, auto slow-mo, pause on Easy, explanation detail).
  Same core rules on every difficulty.
- **Explanations in the event log (A16):** every call/rule logs why it fired, was ignored, suppressed, or fell back.
- **Drilled rules (proposal C2, pending):** see `05` §4.

## 17. Gaps to spec before sign-off
- **Fight HUD layout** (round/clock, both fighters' condition, position/range, active plan/rules/reads, voice meter, call bar, feed).
- **Onboarding**: the first amateur fights double as a tutorial that introduces calls one at a time.
- **Amateur ruleset**: 3×3 min rounds, shin guards, no elbows / no strikes to a grounded head (with C3).

## 18. Standing game v1 in the engine (#13)
What `sim/` does today for §3, §5, §8 and §11. Every number is a first guess for the balance harness (#18); they are named
constants in `sim/fight/octagon.gd`, `sim/fight/fight_sim.gd`, `sim/fight/fighter_ai.gd` (§20) and `sim/fight/judging.gd`. Stat effects are in `11` §3.5.

| Piece | Rule |
|---|---|
| Cage | Regular octagon, 4.5 m from the centre to each panel (30 ft across). Fighters start 3.5 m apart and go back to their corners each round |
| Distance bands | Out > 3.0 m · Long 2.2–3.0 · Mid 1.5–2.2 · Pocket < 1.5. Standing fighters can't get closer than 0.9 m: closer than that is the clinch, which takes a clinch entry (§21.6) |
| Reach | A strike only lands from the bands in its data. The AI only starts moves that reach; a commanded or interrupted move that no longer reaches *falls short* ("out of range") |
| Movement | Walk at 0.8 + 1.2 × (Footwork + Speed)/200 m/s toward the distance the fighter's range plan wants (§20). Committed fighters don't move. Walking costs stamina (D96): 0.6 a second at full pace × (share of full pace)², so walking in is cheap and running all night isn't. A clean shot stops the feet for 1 tick + 1 per 4 damage; a landed teep shoves the opponent 0.5 m back (`push_m`) |
| Cage | Near = within 1.5 m of the fence; pinned = within 0.5 m with the opponent in mid range or closer (`BACK_TO_CAGE`). The fence stops the part of a step that goes into it and the rest slides along it, so backing straight into the fence gets a fighter nowhere (D107). A presser aims where a moving opponent is going: how far ahead is the presser's share of a Footwork contest. Chasing someone who's getting away and cutting the cage off both depend on Footwork too (§20.2), so good feet get out and bad feet get trapped |
| Flags | From action phases (data `flags_self`), plus `BACK_TO_CAGE` when pinned and `HANDS_LOW` below a quarter tank or while rocked |
| Counters | Hitting a fighter in wind-up or recovery: +10% to land and ×1.3 damage |
| Damage | Base damage × (0.5 + Power/100), at least 1 |
| Rocked | Head shots only. Shock = damage × (1 + head hurt) / (6 + 0.12 × Chin). Rock chance = (shock − 0.6) × 0.5, up to 60%: a jab never rocks a fresh fighter, a clean hook or head kick can. Rocked lasts 4 s × (1.5 − Recovery/100): Speed, Striking defense, Fight IQ −30% more, hands drop, they back off and mostly cover up, and the opponent swarms (more with a Wild Risk leaning) |
| Knockdown | Rocked again while rocked (or rocked by a knee into a shot, §21.2). Down for 2 s, then up and rocked, unless the other man follows him down to the ground first (§34, D142). A liver shot (§35, D143) drops him too, a moment later, for 3 s, with his head clear. Under unified rules nobody hits a downed fighter; under PRIDE rules a soccer kick or a stomp can (§33). A knockdown in the clinch separates the fighters |
| KO / TKO | KO roll on each knockdown: 15% + (shock − 1) × 50%, 5–80%, × (1.5 − Heart/100). TKO on a third knockdown in a round, or a rock with the head fully hurt |
| Judges | Three judges, 10-point must. A round's points = damage landed (head ×1, body ×0.8, legs ×0.6) + 8 per rock + 20 per knockdown + grappling (a takedown and control time, §21.4); each judge sees each fighter's points ±15%. Within 5%, the round goes to the busier fighter (aggression: strikes and takedowns started plus metres walked forward, each judge seeing it ±15%), then to whoever held the other on the fence longer (cage control); only a round where nothing separates them is 10-10 (D97). 10-8 for two more knockdowns or out-landing 4 to 1 in a busy round (D110; `Judging.DOMINANT_SHARE` 0.25). Decision: unanimous / split / majority / draw |
| Events | `range_changed`, `cage_changed` (announced once held for 0.5 s), `rocked`, `knockdown`, `got_up`, `recovered`; strikes carry `counter`, the `odds` breakdown (§19) and, when they fall short, a `reason` |

Not yet: leg damage giving out, liver shots, cuts, judge personalities and fouls (D20). The clinch and the ground are §21.

## 19. Decision layer in the engine (#33)
How §6.0 and §7 plug into the code (`12` §3 item 2). The fight loop (`sim/fight/fight_sim.gd`) owns time, movement and
resolution. What a free fighter starts each tick comes from their **decision layer** (`sim/fight/decision_layer.gd`), which reads
the fight through a read-only **view** and walks one priority stack. The first layer that claims the choice wins:

| Priority | Layer | Today |
|---|---|---|
| 1 | **Command** | An action queued from outside (tests, bots, the debug console). Always obeyed if possible |
| 2 | **Live call** | A `live_call` command costs voice, waits out the call delay in fight time (base 0.6 s = 6 ticks, D92), then a compliance roll (D5) and a feasibility check (legal, possible from this position, a move the fighter knows). Attempts, focus calls and read calls: §22. Every outcome is logged as `call_answered` with the reason (A16) |
| 3 | **Drilled rule** | Two slots of trigger → move, set before a round, firing with the fighter's own reaction time when eligible and reliable; slot 1 first, a cooldown, and opponents who learn to disguise what a rule keeps catching. Every outcome is logged as `rule_answered` with the reason (A16): §23 |
| 4 | **Fighter AI** | The fighter AI (`sim/fight/fighter_ai.gd`, §20). Gameplans only multiply its weights per action or category and shift its style leanings, so the fighter never silently replaces the gameplan (§16 A2) |

- **Reaction time** (D93) is one number on the fighter, shared by read calls, rules and the AI: 3 − 0.02 × Speed ticks
  (3 at Speed 0, 2 at 50, 1 at 100), stretched by fatigue up to +30%, at least 1 tick.
- **Odds breakdown** (A16): every rolled strike event carries `odds` = base, the stat gap on effective stats, and each bonus by
  name (`counter`, the opponent's flag such as `ONE_LEG`), plus `clamped` when the 5–95% cap cut it. The debug console prints it:
  *"Jab LANDS (head, 3 damage) 65% (base 50 · stats +5 · counter +10)"*. Takedowns, clinch and ground moves and sprawls carry the
  same breakdown (§21).
- **Rulesets** (`08`): the fight takes a ruleset (pro by default) for rounds, round length, damage scaling from gear and which
  actions are legal. Banned actions are refused as commands and calls and never picked by the AI. Today only `takedowns` maps to
  actions, plus `knees_to_head_standing`: where it's off (teen amateurs), a knee into a shot stays on the body (§21.2). Elbows (the
  ground elbow, and the standing elbow since D140, §32) map to `elbows`; knees to a grounded opponent, ground strikes to the head
  and slams map as those actions arrive.

## 20. Fighter AI in the engine (#14)
What a fighter does when nobody is calling (`sim/fight/fighter_ai.gd`), the bottom of the §19 stack. It sees the fight only
through the read-only view and the fight's events, so it knows what a fighter in the cage could know, one reaction time late
(D93). The aim is §7: believable, varied and true to style with no calls at all. Every number is a named constant and a first
guess for the balance harness; stat effects are in `11` §3.5.

| Piece | Rule |
|---|---|
| Each free tick | In order: (1) danger first (A2): a rocked fighter covers up and gets out; a shot it read gets sprawled on (60% + 30% × Takedown defense). (2) Follow through: a tell, or the next strike of a combination. (3) An opening it read in time. (4) Meeting an opponent who walks in. (5) Now and then, a lead |
| Reads | A move registers one reaction time after the fighter first sees it start. Read chance = (0.15 + 0.5 × Fight IQ/100) × a telegraph factor (a 2-tick telegraph is normal, each tick longer or shorter ±20%, 0.5–1.5×); half when rocked. A read gets used 75% of the time, ±20% for Pace (patient fighters take more). Fighters step in turn each tick, so a move that starts after your step is first seen next tick (fair to both corners) |
| Counters and openings | A counter is timed to land in the opponent's wind-up or recovery (+10%, ×1.3 damage, §18); an opening is timed to land while the opponent's flag is up (`ONE_LEG` during a kick, `LEANING` after a hook). Outside fighters may step back instead: up to 60% at Range −100, plus 30% × head hurt for anyone |
| Catch-kicks | Never on their own (D103): a move that needs an opening (`required`) gets no weight from the AI. Only a call or a drilled rule throws it |
| Leads | Per tick: work rate (0.015, about one lead every 7 s) × (1 + Pace/200); × (1.5 + Risk/200) against a rocked opponent; × 0.35 while resetting or crowded; × 0.6 while still walking in; fading below half a tank; × 1.25 in the last 15 s of a round and when behind going into the final round. Never more than 4× the work rate |
| Picking a move | Only moves that will still reach as they land. Weight = tendency × style (Base +100: takedowns ×2, strikes ×½; −100 never shoots) × gameplan × commitment × stamina × what's working × (odds now / plain odds)², picked by weighted chance that is sharper with Fight IQ (weights to the power 1 + IQ/100) |
| Commitment | Strike weight × (ticks / 5)^−aversion, aversion = (0.5 − 0.4 × Risk/100) × danger/0.5: safe fighters throw quick shots, wild ones throw big ones, and everyone throws big ones more freely where the opponent can't punish them |
| What's working | Each move's landing record moves its weight by up to ±40% at Fight IQ 50, ±80% at 100 |
| Combinations | After a strike, another at (0.15 + 0.45 × the move's technique stat/100) × (1 + Pace/200), up to 3 more. Outside fighters then often reset: step out 0.6 m for 1–2 s (up to 70% at Range −100) |
| Range plan | Every 2 s, per band: my threat − caution × theirs, over my best threat (threat = the best move's expected damage per second from there, plus a quarter of the rest); caution = 0.8 − 0.3 × (Pace + Risk)/100. Range ±0.35 and Pace ±0.15 tilt it toward the pocket or long range; the band it holds gets +0.1 so it doesn't flicker. It never plans to stand where none of its own moves reach |
| Feet | Stand in the planned band (Range +100 0.25 m closer, Pace +100 another 0.15 m). Walking into the opponent's weapons while they're free, stalk: half pace (± a quarter for Pace, a tenth faster when losing on their own reckoning), scaled by the opponent's share of the threat there; full speed while the opponent is committed to a move. Pressed by an opponent who can't do much from where they stand, they hold their ground; once the opponent is in range of their own weapons, they give ground back to their spot (D107). Outside fighters circle when giving ground (0.8 of their pace at Range −100, 0.25 when not), and pivot back toward the middle when they're further out than the opponent. Backing up with the fence within 1.5 m behind them, they back up less (none at the fence), and outside fighters circle out off it. Pressing, they cut the cage off. The details of all of this are in §20.2. A fighter with nothing that reaches from anywhere holds their ground |
| Crowded | Closer than planned in a band where the opponent out-guns them (the Kicker caught in the pocket): getting out comes first, so leads × 0.35 and combinations × 0.5 |
| Meeting the advance | When the opponent walks in faster than 0.4 m/s: one roll per advance at (0.2 + 0.5 for an outside fighter) × (0.5 + Fight IQ/100) to land a strike as they arrive |
| Hurt | Rocked: cover up, get out and circle away; reads halved, leads × 0.3. Opponent rocked: swarm from the band of the best head shot, head shots weighted up by (0.5 + 0.5 × Risk/100) × (head hurt + 1) |
| Tells and set-ups | From the profile's `tells` (`09`): when the trigger's event happens, follow with the action within the window, at the given chance. The Kicker: jab blocked → body kick, 70% within 1.5 s. A set-up is a tell set off by the fighter's own move: the Wrestler shifts his stance (a 0.2 s telegraph, the tell to watch for) and shoots a double-leg within 1 s, 90% |
| Why | Every move the fighter starts says why (`why` on the telegraph event: leads, combination, counters the jab, opening: ONE_LEG, meets him coming in, swarms, tell: jab blocked); the fight log prints it |

Balance on 2026-10-25 before the movement work (harness, 100 fights a pairing): the Kicker beats the Boxer 46% of the time, 44% with the corners swapped
(the #14 exit test is within 60/40); one draw in 500 fights and no 10-10 cards (D97); in Kicker vs Boxer someone ends up under half
a tank in 82% of fights (D96). Mirror matches come out even (Kicker 53/47, Boxer 49/51). The Wrestler is tested but stays out of
the targets until #15 (D104).

After the movement work (D107, §20.2), same harness: the Kicker beats the Boxer 53% of the time, 48% with the corners swapped;
one draw in 500 fights and no 10-10 cards; someone under half a tank in 87–94% of Kicker vs Boxer fights. Mirrors: Boxer 53/47,
Kicker 41/59 on seeds 1–100 and 46/54 on seeds 101–200. The two Kickers are identical, so that's most likely seed noise
(100 fights swing about ±10%), but blue was ahead both times: if it holds over more fights, look for a corner bias in the feet.

To watch in the playtest: the Kicker is near the fence for a bit over half the fight (it was nearly all of it) and almost never
pinned, but the Boxer still holds the centre (nearer it 98% of the time) and the Kicker mostly circles round him at range; the
Boxer's hook is rare because the Kicker seldom stays in the pocket when it would land; the Kicker works harder for it (lowest
stamina about 30% of the tank, was 37%); and two Boxers stand in the pocket and trade until one is stopped (every Boxer mirror
ends inside the distance), which is as much the damage numbers (§18) as the AI. Since D107 they do it on the fence more often
(near it 36% of the time, was 26%): a fighter who doesn't lean outside plants on the fence and fights instead of circling off.

Speed: the AI made a full fight about 1.65× slower; the speed-ups in §2.1 won back about 20%, and D107's came out about 5%
faster again. The speed budget and the timing checks are in §2.1 (D105).

### 20.1 Watching the AI move (D106, replaced by D117)
The temporary top-down cage view (D106) was removed when the grey-box fight view landed (#19). To judge the AI's movement now,
play a fight and press **F3**: the debug overlay prints each fighter's wanted distance, how much they're circling, how hard
they're cutting the cage off, their cage proximity and pace, and the 3D view draws the near-the-fence (1.5 m) and pinned
(0.5 m) lines and each fighter's wanted-distance ring around the opponent (`06` §6.2). The sim still gives the three
read-only numbers it needs, `FightSim.last_wanted_distance()`, `last_circling()` and `last_cutting()`.

The engine still has no separate facing (§3 says fighters have one): both fighters always face each other.

### 20.2 Moving round the cage (D107)
Until D107 each fighter had one idea about movement: walk to the distance the range plan wants. The Kicker wants long range
and the Boxer the pocket, so the Boxer walked forward, the Kicker walked back until the fence stopped him, and then slid
along it at full pace. Watched in the cage view (§20.1), the Kicker just circled away and the Boxer just chased. The harness
said the same: the Kicker was near the fence 97% of the fight and pinned 45%, the Boxer was nearer the centre 99% of the time,
and one of them was chasing the other 80% of the time. Fighters now also care where they are in the cage.

Each tick a free standing fighter makes one footwork plan, a `FeetPlan` (`sim/fight/feet_plan.gd`): how far apart they want
to be, how much to circle and which way, and how hard to cut the cage off. `FighterAI.plan_feet` fills it and
`FightSim._move` carries it out.

| Behaviour | What the fighter does | To change it |
|---|---|---|
| Holding the centre | Pressed (the opponent is closer than they want), a fighter holds their ground while the opponent can do little from there: the opponent's share of the threat at this distance (the range plan, §20) is under 15%. Once it isn't, they give ground all the way back to their spot, then hold again. Stepping back from a strike and resetting after a combination work as before | `HOLD_DANGER` 0.15 in `sim/fight/fighter_ai.gd` |
| Back toward the centre | An outside fighter (Range below 0) who is further from the middle than the opponent circles round the opponent toward it while giving ground or while the opponent is busy throwing, and pivots instead of backing off. Both grow with how much further out they are (all of it from 1 m further out) and with how far outside they lean (all of it at Range −100) | `CENTRE_PULL` 1.0, `CENTRE_PULL_OVER` 1.0 m and `PIVOT` 1.0 in `fighter_ai.gd` |
| Off the fence | With the fence within 1.5 m behind them, everyone backs up less (not at all at the fence), so a pressure fighter who gets backed up plants and fights. Outside fighters also circle out: all they can for 1.5 s, toward the side nearer the middle (a coin flip when neither side is clearly more open), the moment the opponent commits to a move, or else on a chance of 50% × how far outside they lean, each tick | `FENCE_SENSE` 1.5 m, `ESCAPE_TICKS` 15 and `ESCAPE_RATE` 0.5 in `fighter_ai.gd` |
| Changing direction | In open space (the fence more than 0.8 m away), circling fighters think again every 3 s and switch direction 40% of the time, so they don't circle the same way all fight. Closer to the fence they circle toward the middle | `SWITCH_EVERY` 30 ticks, `SWITCH_CHANCE` 0.4 and `SWITCH_FENCE` 0.8 m in `fighter_ai.gd` |
| Cutting off the cage | Pressing or holding (not while giving ground, rocked, or swarming a hurt opponent), a fighter steps sideways toward the spot between the opponent and the middle, as far from the opponent as now. How hard: 0.6 at Range 0, ±0.4 at Range ±100. It fades in as the opponent goes from 3 m to 4 m out from the middle, because it's the fence that traps: in open space there's no way out to shut. The sideways step is × the presser's Footwork contest share. **Since D230 (§20.5)** the reach depends on the Cage cutting stat, the step leads the opponent's drift, comes before closing in, and is × Cage cutting against the opponent's Footwork | `CUT_BASE` 0.6 and `CUT_PER_RANGE` 0.4 in `fighter_ai.gd`; `CUT_FROM` 3.0 m and `CUT_FULL` 4.0 m in `sim/fight/fight_sim.gd` |
| Chasing | Walking in on someone whose last step was away, a fighter keeps up only by their footwork edge = (2 × Footwork contest share)², at most 1. Even feet get all of the chase; the Boxer's 50 against the Kicker's 70 (a 30% share) gets about a third | `FightSim.footwork_edge()` in `fight_sim.gd` |
| The fence | The fence stops the part of a step that goes into it, and the rest slides along it. Before D107 a fighter who walked into the fence slid along it at full pace, so backing straight up turned into a sprint along the fence. Walking costs stamina for the distance actually covered | `FightSim._move()` in `fight_sim.gd` |

The harness reports movement for every pair (the **Feet** line: time near the fence and pinned, who was nearer the centre,
how much of the fight was a chase) and two INFO lines for the whole run (`04` §2.3). Before and after D107, 100 fights a
pairing:

| | Before | After |
|---|---|---|
| Kicker vs Boxer: Kicker wins (Kicker red / Kicker blue) | 46% / 44% | 53% / 48% |
| Kicker near the fence (pinned) | 97% (45%) | 59% (1%) |
| Boxer near the fence (pinned) | 85% (12%) | 1% (0%) |
| Nearer the centre: Kicker / Boxer | 1% / 99% | 2% / 98% |
| One chasing the other | 80% | 36% |
| Kicker mirror: near the fence, chasing | 31%, 10% | 33%, 9% |
| Boxer mirror: near the fence (pinned), chasing | 26% (1%), 10% | 36% (9%), 10% |

The harness had a bug that this work found: the 60/40 check counted wins by corner, so a pair run both ways round
(`kicker:boxer,boxer:kicker`) always looked about 50/50, even when one fighter won 95% of the time. It now counts wins by
fighter, whichever corner they were in (`BalanceReport.fighter_win_share`). The earlier numbers in §20 come from the per-pair
lines, so they stand; the check itself said 50.5% before D107, when the real favourite (the Boxer) won 54.5%.

Tested in `tests/sim/fight/test_fighter_ai.gd` (holds ground out of reach, circles out off the fence when the opponent commits,
steps across to cut off, changes direction), `tests/sim/fight/test_standing_game.gd` (better footwork gets off the fence
sooner, the footwork edge) and `tests/sim/balance/` (the movement numbers, the by-fighter check). After changing any of the
numbers above, run the harness with both corners and the mirrors
(`--pairs=kicker:boxer,boxer:kicker,kicker:kicker,boxer:boxer`), read the **Feet** lines next to the wins, and watch a few
fights in the cage view, which shows how hard each fighter is cutting off.

Tuning notes, so nobody walks the same dead ends: cutting off in open space, or at full strength whatever the Footwork,
left the Kicker winning 2–20% of fights against the Boxer, and slowing the chaser with no cut at all had him winning about
73%. The cut only near the fence and × the presser's share, plus the squared footwork edge on chases, is what landed near
50%.

### 20.3 How long each fighter circled and cut off the cage (D119)
When a fight ends, each fighter's time circling and cutting off the cage is reported as fight time and a share of the fight,
e.g. `Kicker circled 8:22 (56% of the fight) · cut off the cage 0:00 (0% of the fight)`. It counts what the feet in §20.2
already do and changes nothing in the fight: the balance CSV of 160 fights was identical, number for number, before and after.

| Counted as | When a tick counts | To change it |
|---|---|---|
| Circling | The fighter steps, and at least 40% of the step goes round the opponent: circling off a fighter in their face, back toward the middle, out off the fence, or away while rocked. An outside fighter's everyday drift sideways (0.25 × how far outside they lean, 0.15 of a step for the Kicker) doesn't count | `CIRCLING_FROM` 0.4 in `sim/fight/fight_sim.gd` |
| Cutting off the cage | The fighter steps while pressing or holding, with the cut working: the opponent further out from the middle than the cutter's reach (3 m at Cage cutting 50, §20.5; it was 3 m for everyone before D230). It counts while they're already in the way and don't need to step across | The `cut > 0.0` branch in `FightSim._move()` |

Both are counted in `FightSim._move()` into `FightSim.circling_ticks` and `cutting_ticks` (one per fighter, ticks of fight
time). Ticks a fighter doesn't move (throwing, staggered, tied up, down) count as neither.

Where it shows:
- **Debug console**: under each fighter's summary at the end of the test fight and of the fight on screen
  (`FightLogFormatter.movement_line`).
- **Headless sim** (`tools/run_sim.gd`): the same lines at the end of a single fight.
- **Balance harness**: a **Circling** line per pair (average m:ss a fight and the share of all fight time), and CSV columns
  `circling_red`, `cutting_red`, `circling_blue`, `cutting_blue` (fight seconds) with `fight_seconds` (how long the fight
  lasted).
- **Fight screen** (#19): on the result screen, under each fighter's strikes and takedowns (`game/main.gd` `_on_fight_over`).

Measured on 40 fights a pairing (pro rules):

| Pairing | Circling | Cutting off the cage |
|---|---|---|
| Kicker vs Boxer | Kicker 7:20 a fight (51%), Boxer 0:11 (1%) | Kicker 0:00 (0%), Boxer 2:42 (19%) |
| Wrestler vs Kicker | Wrestler 0:06 (1%), Kicker 4:50 (32%) | Wrestler 1:48 (12%), Kicker 0:00 (0%) |
| Wrestler vs Boxer | Wrestler 0:06 (1%), Boxer 0:00 (0%) | Wrestler 2:49 (19%), Boxer 4:07 (28%) |

Only outside fighters (Range below 0) circle unless they're rocked, so the Boxer and the Wrestler circle only when hurt.
The Kicker never cuts off: he cuts only while pressing or holding with the opponent out by the fence, and the Boxer holds
the centre (§20.2). Tested in `tests/sim/fight/test_fighter_ai.gd`, `tests/sim/balance/` and `tests/ui/`.

### 20.4 Improving the AI: the plan (D250, D251)

On 2026-10-30 a write-up of how the AI decides went out for an outside review, which said to keep the utility AI at the core
but fix how it's measured first, then give failed moves costs of their own, intents that last, one memory of the opponent
and a joined-up cage game. Kyle took the plan in seven phases, starting with the first:

1. **Measure properly** (D250, §2.4): ranges on the numbers, paired comparisons, a record of each run, who chose the moves.
2. **Outcome costs and one answer per threat:** a stuffed shot or a bitten-on feint costs the fighter something, and each
   threat has one answer the AI weighs.
3. **Intents that last:** a plan held for a few seconds instead of a fresh pick each tick.
4. **Cage work joined up:** with the cage threads (D220s, D230s).
5. **One memory of the opponent:** what he's seen, shared by the reads, the combinations and the gameplan.
6. **The fight's arc and coaching:** rounds won and lost change the plan; coaching measured call by call.
7. **Offline tuning and variety.**

**Kyle's answers (D251):** bring takedown volume closer to real fights (the grapplers try 24–42 shots a fight in the harness,
about 4 per 15 minutes in the UFC); catch-kicks stay a coached move (D103); test switching off the blanket call costs (D115)
after phase 2; replace D12's flat +10–20% coaching target with how often a called move wins the exchange it was called for.

### 20.5 Cutting the cage (D230–D232)
Kyle (2026-10-30): "we also need to work on a cut the cage call and the ai around that. currently the ai just kind of circles
following. we can make cage cutting its own stat if needed as thats something some fighters can become well known for." He
sent two guides as the source: [the art of cutting the cage](https://mmaguidr.com/art-of-cutting-the-cage-ring-generalship-101/)
and [MMA cage cutting](https://middleeasy.com/guides/mma-cage-cutting/). Their main points: take away the next exit instead
of following the man ("chasing his shadow"), step diagonally to cut off his path and mirror his escape, hold the inside line
(you cover less ground than he does going round you), don't crowd him, and use feints to make the exit predictable. The man
being cut off reverses direction, plants and counters (the check hook), or bursts through the open side. Cage control alone
isn't offence. Before D230 the cut only worked once the opponent was 3 m out from the middle, so most pressing was a chase
with the presser aiming a little ahead.

Kyle's picks on the decision cards: a new **Cage cutting** stat (D230), the call as a **15-second focus on key R** (D231),
and **herding with feints now, strikes aimed at the escape side later** (D232).

| Behaviour | What the fighter does | To change it |
|---|---|---|
| The Cage cutting stat | The 24th stat (`data/enums/stats.json`, Striking group, `11` §2.2). The cut's sideways step is × the cutter's Cage cutting contest share against the opponent's **Footwork** (it was Footwork against Footwork), and the stat sets the reach below. Tired, a hurt leg or a limp lower it, like Footwork. Missing from a fighter file = 50 | `FightSim._refresh_feet()`; `LEG_HURT_STATS` and `LIMP_STATS` in `sim/fight/fighter_state.gd` |
| Starting earlier | The cut fades in as the opponent goes from the cutter's reach to 4 m out from the middle. Reach = 3 m at Cage cutting 50, 0.5 m closer to the middle at 100 and 0.5 m further out at 0: a great cutter starts shutting the exits while there's still room | `CUT_FROM` 3.0, `CUT_EARLY` 0.5 and `CUT_FULL` 4.0 m in `sim/fight/fight_sim.gd` |
| Aiming at the exit | Cutting, the presser doesn't aim ahead of the man the way a chase does: he steps toward the spot between the opponent and the middle, led by where the opponent is drifting (half a second of his sideways steps). His read of that drift catches up with a change of direction by 10% + 50% × his Cage cutting share of the gap a tick, so a good reader is fooled by a reversal for less time. **Since D233** he picks the step that shuts the man's best escape route, and keeps this aim for holding the door shut once every route is (§20.6) | `CUT_LEAD_TICKS` 5, `CUT_READ_BASE` 0.1, `CUT_READ_PER_SHARE` 0.5 in `fight_sim.gd`; `FightSim._cut_step()` |
| The diagonal step | The step across comes first and the step in gets what's left of his walking pace, so cutting off he closes the distance more slowly and doesn't run past the exit | `FightSim._move()` |
| Reversing (the man being cut off) | An outside fighter circling by the fence (within 0.8 m) with the opponent cutting from the inside turns back the other way, all he can for 0.8 s, on a chance of 6% × how far outside he leans × Fight IQ / 100 a tick. **Since D233** only when the way he's going is shut and the other way is open (§20.6) | `REVERSE_RATE` 0.06, `REVERSE_TICKS` 8 in `sim/fight/fighter_ai.gd` |
| Plant and counter | Being cut off, the chance to meet the cutter with a strike as he steps in (§20) goes up by 0.2 | `INTERCEPT_CUT_OFF` 0.2 in `fighter_ai.gd` |
| Herding with a feint | Cutting the cage off with the opponent circling within 1.5 m of the fence, the cutter feints (D131) on a chance of 1.5% × Cage cutting / 100 a free tick. A feint that bites now also plants the feet: a bitten fighter's feet move 40% of a step while it lasts (D131's 1 s), so the cut closes the door. This works for every feint, the ones before a shot too. **Since D235** a herding feint at an open way out comes 3× as often and sells it shut (§20.7) | `HERD_RATE` 0.015, `HERD_FENCE` 1.5 m in `fighter_ai.gd`; `BIT_FEET` 0.4 in `fight_sim.gd` |
| *Cut the cage!* (key **R**) | A 15 s focus call (`data/calls/cut_the_cage.json`, voice 20): Range +30, Pace +20, he cuts all his stat allows (`cut` 1.0) from anywhere in the cage (reach 1 m, or his own if that's closer in) and doesn't circle. Number keys 0–9 are all taken standing, so it's the first call on a letter key; the call bar shows it as *R Cut the cage* | the call's file; `CUT_CALLED_FROM` 1.0 m in `fight_sim.gd`; `FighterAI._plan_steps()` |
| Cut off onto the fence | Reported after the fight next to the cutting time: how many times the opponent was walked from open space onto the fence: his cage proximity changed from the centre (after at least 3 s there) to near the fence within 1 s of this fighter's cut working. The result screen and debug console add *trapped him on the fence N times* to the movement line (§20.3); the harness adds it to the **Circling** line and the CSV (`cut_offs_red`, `cut_offs_blue`) | `CUT_OFF_TICKS` 10 and `CUT_OFF_FROM_TICKS` 30 in `fight_sim.gd`; `FightSim.cut_offs` |

Who is good at it (the test fighters in `data/fighters/`, which the opponent style sheets build on, D160). Kyle was asked which styles
should be known for it; these are the first guesses: Pressure wrestler 75; Pressure boxer, Brawler, Dirty boxer and
Ground-and-pound wrestler 65; Wrestle-boxer and Sprawl-and-brawl 60; Muay Thai and Sambo 55; Leg-kick specialist and Judoka 50;
Submission grappler and Counter-striker 40; Range kicker and Karate 35. The escape artists keep their high Footwork, which
is what stops them being cut off.

Training it: the **Shark tank** session (`data/sessions/shark_tank.json`, `02` §3.5): Cage cutting 60%, Footwork 20%, Fight IQ
20%. On the fight setup, a key to the fight says when one fighter's Cage cutting is two grades or more above the other's
Footwork (`TaleOfTheTape.keys`).

Measured (100 fights a pairing, pro rules; main before D230 for comparison, 60 fights a pairing):

| | Before D230 | After |
|---|---|---|
| Kicker vs Boxer (Kicker red / Kicker blue) | 38% / 45% | 47% / 40% (inside the 60/40 test: 56.5%) |
| Boxer cutting off the Kicker | 18–19% of the fight | 33% |
| One fighter chasing the other (the INFO line) | 30–35% of standing time | 30% |
| Wrestler vs Kicker: the Wrestler wins | 50% | 67% |
| Brawler vs Kicker: the Brawler wins | 60% | 71% |
| Pressure wrestler vs Counter-striker: the Pressure wrestler wins | 62% | 72% |

Good cutters now beat the outside fighters clearly more often. Kyle was asked how hard that should be (tone it down so every
style stays in 37–63%, keep it, or keep it and give the kickers more Footwork) and picked **keep it as built** (2026-10-30):
cage cutters really are a nightmare for kickers, and an outside fighter answers with Footwork training and *Circle out!*. A
toned-down try (Pressure boxer 60, Brawler 50 …) kept every style between 38% and 65% on the style table. As built, on the style table (`tools/style_sheets.gd --fights=60`, D160), every style
wins between 38% and 67% (main: 37–65%). The biggest moves: Brawler 43% → 53%, Sprawl-and-brawl 57% → 65%, Judo thrower 57% → 65%,
Counter-striker 47% → 38%, Wrestle-boxer 52% → 42%, Range kicker 47% → 40%, and the Leg-kick specialist 48% → 40% (Kyle asked for
at least 36%). The first 30-fights-a-style table had him at 33%, but that was noise.

Not yet: strikes thrown at the side the man circles toward, so circling into the power hand gets hit (Kyle: later, D232); the
AI corner and the coaching bots making the call; what happens once he's pinned on the fence is the cage pressure work (§39).
Tested in `tests/sim/fight/test_cage_cutting.gd`. Since D233 the cutter picks his step from the opponent's escape routes (§20.6).

### 20.6 Escape routes and being shut in (D233, D234)
An outside review of the AI (2026-10-30, `fighter-ai-doc/ai-research-review.md` §3 in the project files) said cage cutting
should be about the ways out the man still has, not the distance to him: sample his escape paths, score them by who gets
where first, step to make his best one worse, and give the man being cut off real choices. Kyle picked "Merge #81, escape
routes next" (D233), and when asked what a fighter does with every way out shut, "Pick by style" (D234).

| Behaviour | What the fighter does | To change it |
|---|---|---|
| Escape routes | From where the man being cut off stands, 8 straight routes (the first toward the middle, the rest round from it, 45° apart), each walked 2 steps of 1.2 m and slid along the fence where they meet it. Routes heading back into the fence don't count. A route's **margin** is, at its worst point, the cutter's time to get within punching reach (1.5 m, the pocket) plus 0.2 s to react, less the man's time to get there plus up to 0.4 s to turn off the way he's drifting (all of it straight back, half turning square). Positive: he gets along it clear. A route is **worth** its margin (at most 1 s) plus 0.4 s for every metre further off the fence it ends | `HEADINGS` 8, `SAMPLES` 2, `SAMPLE_M` 1.2, `THREAT_REACH` 1.5 m, `CHASER_LAG_TICKS` 2, `TURN_TICKS` 4, `MARGIN_CAP` 10, `SPACE_TICKS_PER_M` 4, `BACK_INTO` 0.2 in `sim/fight/escape_routes.gd` |
| Aiming at the exit | Cutting (§20.5), every 0.5 s the cutter walks the man's routes and tries five steps: straight at him, 45° either way and straight across either way. He takes the one that leaves the man's best route worth least (straight at him when nothing is better). The drift he reads (§20.5's read) makes the routes the man was already going along quicker for him, so a good reader shuts those first. The step across is still × his Cage cutting share and fades in with the reach, as before | `CUT_TURNS` and `ROUTES_EVERY` 5 in `fight_sim.gd`; `FightSim._cut_step()` |
| Holding the door shut | With every way out shut, the cutter mirrors him instead: he steps toward the spot between the man and the middle, half a second ahead of his drift (D230's old aim), so a man sliding along the fence stays in front of him | `CUT_LEAD_TICKS` 5 in `fight_sim.gd` |
| Seeing the open door (the man being cut off) | The cutter's read also says, for the man, which way round the cutter his best open route goes. D230's reverse now only happens when the way he's circling is shut and the other way is open, and he turns toward it: same chance, 6% × how far outside he leans × Fight IQ / 100 a tick | `REVERSE_RATE` 0.06 in `fighter_ai.gd`; `FightView.way_out()` |
| Shut in: bursting out (outside fighters, Range below 0: Range kicker, Karate, Counter-striker) | He sprints round the cutter along the least shut way, all he can for 0.6 s: his walking pace and up to 30% more × his footwork edge (§20.2: even feet get all 30%, Footwork 20 against 50 about 5%), at twice the stamina a step costs. A chance of 10% × Fight IQ / 100 a tick, at most once every 3 s. It comes before D107's circling off the fence | `BURST_TICKS` 6, `BURST_RATE` 0.1, `BURST_EVERY` 30 in `fighter_ai.gd`; `BURST_EXTRA` 0.3, `BURST_STAMINA` 2.0 in `fight_sim.gd` |
| Catching the burst (the cutter) | Once a burst, the cutter throws his best strike at the man going past on a chance of 30% × Cage cutting / 100 | `CATCH_RATE` 0.3 in `fighter_ai.gd`; `FighterAI._catch_burst()` |
| Shut in: tying him up (grapplers: clinch liking at least 0.4 and something to do in the clinch: the wrestlers, Judoka, Sambo, BJJ, Muay Thai, Dirty boxer) | A clinch entry on a chance of 10% a free tick once the cutter is in reach. What happens on the fence after that is §39 | `TIE_UP_FROM` 0.4, `TIE_UP_RATE` 0.1 in `fighter_ai.gd` |
| Shut in: planting and countering (everyone else: Boxer, Brawler, Leg-kick specialist, Sprawl-and-brawl) | He stops circling and stands his ground, and the chance to meet the cutter with a strike as he steps in goes up another 0.2 on top of D230's 0.2 | `INTERCEPT_SHUT_IN` 0.2 in `fighter_ai.gd` |
| Reported after the fight | Next to D230's cut-offs: how many times a fighter cut off onto the fence got back to the middle (his cage proximity back to the centre while still standing), how long he was shut in (every way out shut while being cut off), and the damage the cutter took while cutting him off. The harness adds a **Cut off** line and the CSV columns `cage_escapes_*`, `shut_in_*` and `cut_hurt_*`; the result screen and debug console add *got back to the middle N of M times he was trapped* to the movement line | `FightSim.cage_escapes`, `shut_in_ticks`, `cut_damage_taken`; `BalanceReport._cut_off_line()`; `FightLogFormatter.movement_line()` |

The review's other numbers: the man's time with every way out shut is the *shut in* time; "interception rate" is the catch
above and the counters as the cutter steps in; clinch conversions per pin are §39's.

Measured (200 fights a pairing, pro rules, same seeds as main):

| | Main (D230) | With D233–D234 |
|---|---|---|
| Kicker vs Boxer: the Boxer wins | 57.5% | 57.5% |
| Pressure wrestler vs Counter-striker: the Pressure wrestler wins | 68% | 67% |
| Brawler vs Kicker: the Brawler wins | 69% | 74% |
| Wrestler vs Kicker: the Wrestler wins | 60.5% | 62.5% |
| Karate vs Boxer: Karate wins | 92.5% | 91% |
| Kicker cut off by the Boxer (a fight) | | 27 times, back to the middle 98% of them, shut in 1:42, 143 damage to the Boxer |
| Counter-striker cut off by the Pressure wrestler (a fight) | | 19 times, back to the middle 90%, shut in 1:15, 76 damage to the cutter |

On the 15-style table (`tools/style_sheets.gd --fights=60`, D160) every style wins between 32% and 78% (main before D233: 37–65%),
but at 60 fights a style that's mostly noise: the two that moved most, measured again at 180 fights a style, barely moved.
Karate point fighter 66% → 64%, Range kicker 44% → 39%. At 60 fights: Submission grappler 47% → 58%, Pressure boxer 40% → 35%,
Brawler 47% → 52%, Counter-striker 37% → 43%, Dirty boxer 57% → 57%, Ground-and-pound wrestler 58% → 53%, Judo thrower 58% → 67%,
Leg-kick specialist 40% → 47% (Kyle asked for at least 36%), Muay Thai 47% → 45%, Pressure wrestler 45% → 55%, Sambo 42% → 55%,
Sprawl-and-brawl 65% → 60%, Wrestle-boxer 37% → 45%.

What the numbers say: being walked onto the fence is common (the Kicker 27 times a fight) but short, because nearly every
time he gets back to the middle; the cutter wins by what he lands while he's there, not by keeping him there. Speed: the route
check costs about 5 µs a simulated tick on the cloud machines, and fights with D233–D234 run about 9% slower than main (125 →
136 µs a tick; D105's 100 µs budget was already passed, §2.4's speed line).

Not yet: the route check for the man himself away from a cutter; the AI corner calling *Cut the cage!*. Feints that change
which route the man thinks is shut came next (D235, §20.7). Tested in `tests/sim/fight/test_cage_cutting.gd`.

### 20.7 Selling a door shut (D235)
Kyle (2026-10-31): "lets work on feints". The outside review and both guides say a cutter's feints make the exit
predictable: he shows the man a door closing so the man turns back the way the cutter wants. D232's herding feint only
planted his feet. Now a feint that bites while cutting him off also changes what he believes about his ways out. Only his
belief changes: the routes (§20.6) and the cutter's own read of them stay true.

| Behaviour | What the fighter does | To change it |
|---|---|---|
| Feinting at the door (the cutter) | D232's herding feint, with the man by the fence and a way out still open to sell shut, comes 3× as often: 4.5% × Cage cutting / 100 a free tick. The feed reads "feints at his way out" | `DOOR_HERD` 3.0 (× `HERD_RATE` 0.015) in `sim/fight/fighter_ai.gd`; `FighterAI._herd()` |
| Selling the door | A feint that bites (D131's roll) while the feinter is cutting the man off (§20.5: his cut working within the last 0.5 s, since he stands still to feint), with a way out still open (§20.6), sells that way shut. Any feint does it, herding ones and the ones before a shot. For 2 s (the bite's 1 s and another second) the man reads it as shut and the other way round the cutter as his way out, and a burst goes that way too. One sale at a time | `SOLD_TICKS` 20, `SOLD_CUT_TICKS` 5 in `sim/fight/fight_sim.gd`; `FightSim.way_out()`, `burst_way()` |
| Turning back into it (the man) | D230's reverse now fires on what he believes, so sold a door shut he turns back the other way: into the side the cutter really has shut. Sure his way's shut, he does it 3× as readily: 18% × how far outside he leans × Fight IQ / 100 a tick | `SOLD_REVERSE` 3.0 in `sim/fight/fighter_ai.gd` |
| Catching the turn (the cutter) | As he turns back, the cutter can throw his best strike at him, as he does at a burst (§20.6): 30% × Cage cutting / 100, once a turn, for 0.3 s after it | `CATCH_RATE` 0.3, `TURN_CATCH_TICKS` 3 in `fighter_ai.gd`; `FighterAI._catch_burst()` |
| The feed | "Boxer feints at the way out and Kicker BITES: he thinks it's shut", then "Boxer … catches him turning back into it" | `FightLogFormatter` (`FEINTED` with `sold`) |
| Reported after the fight | Doors each fighter sold shut and how many times the man turned back into one: the movement line adds *sold him a way out shut N times (he turned back into it M)*, the harness's **Cut off** line adds *sold N doors shut (turned back into M)*, CSV columns `doors_sold_*`, `turned_back_*` (by the cutter) | `FightSim.doors_sold`, `turned_back` |

Measured (200 fights a pairing, pro rules, the same seeds as main, compared fight by fight with `tools/balance_compare.gd`, §2.4):

| Pairing | The cutter wins: main → with D235 (change, 95% range) | Doors sold a fight (he turned back into) | The cutter's feints a fight (bitten), main → now |
|---|---|---|---|
| Kicker vs Boxer | Boxer 55.5% → 61.5% (+6.0, −2.9 to +14.9) | 1.9 (1.3) | 4.6 (1.6) → 8.3 (3.0) |
| Brawler vs Kicker | Brawler 73.0% → 71.5% (−1.5, −9.5 to +6.5) | 1.0 (0.7) | 2.1 (0.8) → 4.0 (1.5) |
| Pressure wrestler vs Counter-striker | Pressure wrestler 69.5% → 71.0% (+1.5, −7.0 to +10.0) | 1.3 (0.1) | 16.5 (3.1) → 19.2 (3.5) |
| Wrestler vs Kicker | Wrestler 73.0% → 71.5% (−1.5, −9.0 to +6.0) | 1.4 (0.9) | 7.9 (2.9) → 9.6 (3.5) |
| Karate vs Boxer | Karate 89.5% → 92.0% (+2.5, −2.4 to +7.4) | 0.9 (0.7) | 2.7 (0.7) → 5.3 (1.3) |

Every range crosses 0, so none of the win changes is clearly more than luck at this many fights; the Boxer's +6 against
the Kicker is the one to watch. A good cutter sells one or two doors a fight and the man turns back into most of them;
the Counter-striker hardly ever does (he plants rather than circles, §20.6). The first try, before `SOLD_CUT_TICKS`, sold
none at all: the cutter stands still while he feints, so his cut had always stopped by the time it bit.

Tested in `tests/sim/fight/test_cage_cutting.gd` (a feint that bites while cutting sells the door and wears off, one in open
space sells nothing, turning back more readily, counting a turn once a sale, catching the turn).

### 20.8 Resetting to the centre (D290–D294)
Kyle (2026-10-31): "Fighters should reset to the center of the cage occasionally when not having much success". Before this
only outside fighters (Range below 0) ever headed back to the middle, and only while further out than the opponent (§20.2).
Everyone else never did: a Boxer backed onto the fence by a wrestler stayed there, and a chaser landing nothing kept chasing.
Now a fighter who's been getting the worse of it lately walks back to the middle of the cage now and then, the patient
thinkers most. Built on the recommended answer to each of the four questions while Kyle's cards were open; he picked all four (the rows D291–D294
say which).

| Behaviour | What the fighter does | To change it |
|---|---|---|
| How it's going lately | Running totals that halve every 10 s, so about the last 20 s count: points dealt and taken (strikes by the judges' weights, plus knockdowns, being rocked and takedowns, as the fighter's own round scoring), and strikes thrown (ones that fell short too: hitting air is the point) and landed | `STRUGGLE_HALF_LIFE` 100 ticks in `sim/fight/fighter_ai.gd`; `FighterAI.struggling()` |
| Not having much success (D291) | Losing the exchanges: taken at least 15 points and at least twice what he dealt. Or nothing landing: 3 or more thrown and under a quarter of them landed, even if he isn't getting hit | `STRUGGLE_TAKEN` 15, `STRUGGLE_OUTDONE` 2.0, `STRUGGLE_THROWN` 3, `STRUGGLE_LANDED` 0.25 |
| Deciding to reset (D293) | Checked once a second while he's free, standing and more than 2 m from the middle (and not on a *Cut the cage!* call): a chance of 25% × patience × Fight IQ / 100, patience = 0.5 − (Pace + Risk) / 200, from 0 to 1. The table below has each fighter's chance | `HOME_CHECK_EVERY` 10, `HOME_FROM` 2.0 m, `HOME_RATE` 0.25; the Pace and Risk leanings in `data/fighters/` |
| Walking back | Straight to the middle when the way is clear, never stepping toward the opponent; when the opponent stands between him and the middle (closer to it, within about 45° of the way there) he circles round him toward the middle side instead. He wants to be out at long range, less the fence behind him, and leads at a fifth of his usual rate (the odd shot; counters and defence as usual). It ends when he's within 1 m of the middle or after 5 s | `HOME_IN_THE_WAY` 0.7, `HOME_LEAD_RATE` 0.2, `HOME_DONE` 1.0 m, `HOME_TICKS` 50; `FightSim._move()` (`home`) |
| A cutter can stop it (D294) | The walk back is like any escape: the opponent's cut (§20.5, §20.6) still works on him, and once every way out is shut the reset is over (counted as cut off) and he answers being shut in by style as before | `FighterAI._homing()` |
| How often (D292) | After a reset, not again for 45 s, and how it's been going starts again from nothing. A takedown, a clinch or a new round ends a reset without counting it | `HOME_EVERY` 450 ticks |
| The feed | "Kicker walks back to the middle to reset: nothing's landing" (or "he's getting the worse of it") | `FightLogFormatter` (`FightEvent.RESET`) |
| Reported after the fight | The movement line adds *reset to the middle N times (made it M, cut off K)*; the harness has a **Resets** line, CSV columns `resets_*`, `resets_made_*`, `resets_cut_*` | `FightSim.resets`, `resets_made`, `resets_cut` |

Each fighter's chance a second to reset while struggling away from the middle:

| Fighter | Pace, Risk | Fight IQ | Patience | Chance a second |
|---|---|---|---|---|
| Counter-striker | −70, −30 | 65 | 1.00 | 16% |
| Karate point fighter | −20, −10 | 60 | 0.65 | 10% |
| Kicker | −30, 0 | 50 | 0.65 | 8% |
| Muay Thai, Judoka, BJJ | about +10, +10 | 50 | 0.40 | 5% |
| Wrestler, Sprawl-and-brawl | +30, 0 / +20, +10 | 50 | 0.35 | 4% |
| Boxer, Dirty boxer, Sambo | +40, 0 / +10, +30 | 50 | 0.30 | 4% |
| Leg-kick specialist, Ground-and-pound wrestler | +40, +10 / +30, +20 | 50 | 0.25 | 3% |
| Pressure wrestler | +80, 0 | 50 | 0.10 | 1% |
| Brawler | +70, +70 | 40 | 0 | never |

Measured against main at #96 (striker feints, D236) and #97: 100 fights a pairing, pro rules, the same seeds as main,
compared fight by fight with `tools/balance_compare.gd` (§2.4):

| Pairing | Red wins: main → with D290 (change, 95% range) | Resets a fight, red (made it, cut off) · blue |
|---|---|---|
| Kicker vs Boxer | 44% → 38% (−6, −20 to +8) | 2.7 (1.2, 0.8) · 0.7 (0.6, 0.0) |
| Leg-kick specialist vs Dirty boxer | 18% → 19% (+1, −9 to +11) | 1.6 (0.1, 1.4) · 1.2 (1.1, 0.1) |
| Boxer vs Pressure wrestler | 8% → 11% (+3, −5 to +11) | 0.1 (0.0, 0.1) · 0.1 (0.0, 0.1) |
| Counter-striker vs Brawler | 12% → 14% (+2, −8 to +12) | 3.8 (1.3, 1.3) · 0.0 |
| Wrestler vs Kicker | 70% → 69% (−1, −14 to +12) | 0.5 (0.5, 0.0) · 0.7 (0.4, 0.2) |
| Karate vs Boxer | 96% → 88% (−8, −16 to −0.3) | 1.7 (0.8, 0.5) · 1.0 (0.8, 0.0) |
| Muay Thai vs Boxer | 66% → 66% (0, −13 to +13) | 0.9 (0.2, 0.7) · 0.7 (0.3, 0.3) |
| BJJ vs Boxer | 79% → 84% (+5, −6 to +16) | 0.6 (0.0, 0.6) · 0.1 (0.0, 0.0) |
| Kicker vs Pressure wrestler | 5% → 4% (−1, −6 to +4) | 0.6 (0.3, 0.3) · 0.1 (0.1, 0.0) |
| Leg-kick specialist vs Boxer | 40% → 40% (0, −14 to +14) | 0.6 (0.0, 0.6) · 0.9 (0.9, 0.0) |

Only Karate vs Boxer's range misses 0, just, so it was played again on 300 other seeds (from 101): 92.0% → 92.3% (+0.3,
−3.8 to +4.4), so that was luck. Kicker vs Boxer on the same 300 seeds: 35.3% → 41.0% (+5.7, −2.1 to +13.5), the other way
from the 100. Before #96, Wrestler vs Kicker moved most (70% → 59% on 100 fights) and came back to 71.7% → 68.7% on 300
others. Whole-run draws stay under 2% (0.1% both). The Leg-kick specialist, who plants on the fence (§20.6, D255), mostly
gets cut off when he tries. The sim is about 2–3% slower (93 → 95 µs a tick on 2 processes).

Tested in `tests/sim/fight/test_reset_to_centre.gd` (what counts as struggling and how it fades, walking straight back and
never closer, circling round the opponent in the way, the Brawler never resetting, nothing to reset to in the middle, the
wait before the next one, resets counted and some cut off over whole fights, the feed and the movement line). The mirror
check (§2.5) now compares one tick's events in any order: two cage notices on the same tick come out red first in both
fights, which isn't a corner's edge.

## 21. Clinch, takedowns and the ground in the engine (#15, D98, D108, D109)
What `sim/` does for §4, §5.1 and D29 in the Phase 1 playtest. The scope is the trimmed one (D98): one clinch position, the
double leg, the catch-kick single, the sprawl, full guard top and bottom, getting up and the scramble. Ground-and-pound came
in after this (D121, §24): the fighter on top of full guard strikes and the one underneath ties up or gets up; where this
section and §24 differ, §24 is current. Throws, the guard pull and the sweep came later still (D128, §26). The collar tie and knees to the head from it came after that (D129, §27). Half guard, side control, mount and the back came next (D130, §28): where this section says full guard, the ground now has four more positions. Then feints and blind shots (D131, §29): the double leg's base is 35% now, and a shot with nothing setting it up is worse. Every number is a first guess for the balance harness; each one is a named constant
or a field in `data/`, listed under "To change it".

### 21.1 Positions and the moves between them
Where the fight can go, all from `data/positions/` (§4.1). Roles: `neutral` standing, in the clinch and in a scramble; `top`
and `bottom` in full guard.

| Position | Ways out (the transitions in its file) | Each second (stamina drain · judges' control score) |
|---|---|---|
| Standing | Double leg → full guard, shooter on top; half working → scramble. Catch-kick single → full guard. Clinch entry → clinch | Nothing extra (0 · 0): moves and walking already cost stamina (D96) |
| Clinch | Clinch break → standing. Double leg → full guard, or half working → scramble. Knees work here; punches and kicks don't. A collar tie pulls the head down for knees to the head (D129, §27) | 0.4 each · 0 (cage control still counts, §18) |
| Full guard | Get up (bottom only) → standing, or half working → scramble. The top fighter grounds and pounds; the bottom fighter can tie him up (§24) | top 0.2, bottom 0.3 · top 1.0, bottom 0.2 |
| Scramble | Get up → standing. Scramble for the top → full guard, whoever wins it on top | 0.8 each · 0 |

The moves (`data/actions/`). The ones marked *everyone* are `basic`: every fighter knows them whatever their techniques, so
nobody is ever stuck on the bottom with no way up.

| Move | Timing (telegraph · wind-up · active · recovery) | Odds (base + attack − defense stats) | Notes |
|---|---|---|---|
| Double leg | 0.3 · 0.2 · 0.5 · 0.4 s | 35% (45% until D131, §29) + (Takedowns, Speed) − Takedown defense | From standing (mid or pocket) or the clinch. +15% on someone pinned on the fence, +10% on someone `LEANING`. `COMING_IN` during the telegraph (§21.8), head low from wind-up to the end of the drive. Within 10% past the odds it half works: a scramble |
| Catch-kick single | 0 · 0.1 · 0.4 · 0.3 s | 10% + (Takedowns, Speed) − (Takedown defense, Kicking), +15% for `ONE_LEG` | Only possible while the opponent is on one leg (`required`). Never thrown by the AI on its own (D103) |
| Sprawl (*everyone*) | 0 · 0.1 · 0.3 · 0.3 s | 45% + (Takedown defense, Speed) − Takedowns, +10% against a head-low shot | §21.2 |
| Clinch entry (*everyone*) | 0.2 · 0.2 · 0.2 · 0.3 s | 50% + (Clinch control, Strength) − (Clinch control, Footwork) | From the pocket. +15% on someone pinned, +10% on someone `LEANING`. `COMING_IN` until it ties up (§21.8) |
| Clinch break (*everyone*) | 0 · 0.2 · 0.2 · 0.2 s | 35% + (Clinch control, Strength, Footwork) − Clinch control | −15% with your own back on the fence |
| Get up (*everyone*) | 0.2 · 0.3 · 0.5 · 0.3 s | 25% + (Scrambles, Takedown defense) − Top control | Bottom of full guard, or a scramble. +15% with your own back on the fence (wall-walking). Within 10% past the odds: a scramble |
| Scramble for the top (*everyone*) | 0 · 0.2 · 0.3 · 0.2 s | 45% + (Scrambles, Strength) − Scrambles | Only in a scramble |
| Knee | 0.2 · 0.2 · 0.1 · 0.3 s | as any strike | Now also in the clinch. Into a head-low shot: +25%, to the head, ×1.5 damage, and it stops the shot (§21.2). Into someone `COMING_IN`: +15% and it stops the entry (§21.8) |

### 21.2 How a takedown resolves
Takedowns, clinch moves and ground moves all work the same way, so the log can explain every one (A16):

1. **Contact** when the move's active phase starts. It needs the range (a double leg from long range comes up short), and a
   required opening has to be there right then: a catch-kick that arrives before the kick leaves the ground, or after the foot
   is back down, *finds nothing to catch*. The odds are fixed at contact, with every bonus the opponent shows then (`ONE_LEG`,
   pinned, `LEANING`, a counter into their wind-up or recovery).
2. **The drive**: the active phase (half a second for a double leg). Now the defender can answer it:
   - **Sprawl.** A sprawl whose active phase overlaps contact gets one roll (it's then spent). If it works, the shot is
     *sprawled on*: the shooter goes straight to recovery, stuck under the sprawl 0.5 s longer with the head low, which is what
     knees look for. If it fails, the shot goes on to its own roll. A sprawl that's over before the shot arrives does nothing.
   - **A knee into the shot (D29).** A knee that lands while the shooter's head is low goes to the head for 1.5× damage, and
     stops the shot. If that head shot would rock them, it drops them on the spot (a flash knockdown, with the usual KO roll).
     Where knees to the head are banned (teen amateur rules), it stays on the body.
3. **The roll** as the active phase ends, on the odds from contact. Under them it works and the fight moves (the position
   data says where); within the move's `partial_within` past them it half works and goes to a scramble; otherwise it's
   *defended*. Whatever either fighter was doing stops when the fight moves.

The catch-kick window: the body kick is on one leg from its wind-up to the end of its recovery, 0.9 s of fight time
(`data/actions/body_kick.json`), and the catch makes contact 0.1 s after it starts. So a catch started from the kick's
first instant on one leg to 0.1 s before the foot comes down works through the window; one started during the kick's
telegraph, or late, finds nothing. A *Takedown!* call arrives after the 0.6 s call delay (§19), so the coach has to call it as
the kick starts, or read it coming.

Events, all with the odds breakdown where there was a roll: `grapple_won` (`result` success or partial), `grapple_stopped`
(`reason`: out of range, nothing to catch, defended, sprawled on, stopped by a strike), `sprawled` (`worked`), and a
`strike_landed` that stopped a shot says so (`into`). The debug console prints them, e.g. *"Wrestler's Double-leg takedown is
SPRAWLED ON, stuck with the head low · the shot was 55% (base 45 · stats +10)"* or *"Kicker's Knee LANDS into the double-leg
takedown (head, 14 damage)"*.

### 21.3 What the positions do each tick
Each position's file gives, per role, a stamina drain per second, a control score for the judges and a strike damage multiplier
(`09` position@2), and the sim applies all three while the fight is there. Standing drains nothing (it used to say 0.1 a
second, never applied; setting it to 0 kept standing fights exactly as they were). The clinch costs both fighters 0.4 a second,
the bottom of full guard 0.3 and the top 0.2, a scramble 0.8. The strike multipliers are 1.0 standing and in the clinch;
in full guard the top fighter's ground strikes do × 0.8 (the guard takes some sting out, D121) and the bottom's 0.4 waits
for strikes from the bottom.

### 21.4 Judges
Grappling counts in the same round points as striking (§11: "effective striking/grappling"): 6 points for ending up on top
(a takedown, or winning a scramble), plus 0.15 points a second × the position's control score (full guard top 1.0, bottom
0.2). They were 10 and 0.3 until ground strikes scored on their own (D120, §24.4). For scale, a clean cross from a 60-Power
fighter is about 7 points; a takedown and 20 seconds on top is 9, before any ground strikes.

### 21.5 The fighter AI tied up
Standing, the AI works as in §20, with three additions: everyone sprawls on a shot they read (sprawl is basic now), and if the
sprawl roll fails they may still take the opening (a knee into the lowered head); fighters who like the clinch lead with clinch
entries; and a grappler crowded in the pocket doesn't slow down to get out, he shoots or ties up instead. Tied up there's no
footwork and no range plan:

| Where | What the fighter does | To change it |
|---|---|---|
| Clinch entry (standing) | Weight × how much they like the clinch: Base/100 + Range/200, 0 to 1, and only if they have something to do there (a strike or takedown that works from the clinch). The Wrestler likes it (0.9); the Kicker (Range −60) never clinches; the Boxer has nothing to do there, so he doesn't either | `FighterAI.clinch_liking()` in `sim/fight/fighter_ai.gd` |
| Crowded grappler | The leads slow-down for being crowded (× 0.35, §20) fades with the Base leaning: × 0.35 at Base 0, nothing at +100 | `lead_rate()` in `fighter_ai.gd` |
| In the clinch | A chance of 4 × work rate per tick (about every 1.7 s) to do something: knees, a double leg, or a break. Break weight = 1 − Base/100 − Range/200 (at least 0.05), so the Kicker wants out and the Wrestler stays to shoot. Rocked, they only look to break | `CLINCH_RATE` 4.0, `CLINCH_BREAK_MIN` 0.05 |
| Planning where to stand (§20.2) | A landed takedown counts as 16 damage, a clinch entry as 8 × how much they like the clinch, so a grappler wants the range he can grapple from. The Wrestler's `double_leg` tendency is 1.2 | `TAKEDOWN_PLAN_VALUE`, `CLINCH_PLAN_VALUE`; `data/fighters/wrestler.json` |
| Full guard, bottom | A chance of 2 × work rate per tick (about every 3.3 s) to try to get up or tie up; 3 × as often while the top fighter is throwing or they're rocked (§24.3) | `GROUND_RATE` 2.0, `GROUND_UNDER_FIRE` 3.0 |
| Full guard, top | Grounds and pounds (D121, §24.3); was holding (D108) | `_pound()` in `fighter_ai.gd` |
| Scramble | 30% a tick, so it's over fast. Get up × (1 − Base/100), go for the top × (1 + Base/100) | `SCRAMBLE_RATE` 0.3 |

### 21.6 The standing gap stays (a note on #15)
Issue #15 (and §4.1 before it) said to remove the standing minimum gap (`Octagon.MIN_GAP`, 0.9 m) once the clinch existed. It
stays, with a new meaning: it's as close as two standing fighters get, and closer than that is the clinch, which takes a clinch
entry. Removing it would let fighters walk through each other, and lowering it would change every standing fight (the Boxer's
pocket is built on it). If the playtest wants a fighter who walks onto the opponent to tie up on contact, that's a new decision.

### 21.7 Balance
The Wrestler's pairings are reported in the harness with no pass mark until after the playtest (D109); Kicker vs Boxer within
60/40 is still the only win check. Numbers from the harness without calls, 100 fights a pairing, after the strikers'
answers to grappling (D114, §21.8; the Wrestler vs Kicker rows are 200 fights, seeds 1 and 101):

| Pairing (red vs blue) | Red wins · draws | Shots (takedowns) a fight | Clinch · ground (share of the fight) |
|---|---|---|---|
| Kicker vs Boxer | 51% · 0% | – | – |
| Boxer vs Kicker | 50% · 0% | – | – |
| Wrestler vs Kicker | 48.5% · 2% | 24.9 (9.5) | 0.3% · 37% |
| Kicker vs Wrestler | 51% · 1% | 24.1 (9.6) | 0.3% · 35% |
| Wrestler vs Boxer | 59% · 1% | 37.3 (14.6) | 2% · 57% |
| Boxer vs Wrestler | 40% · 1% | 37.6 (14.7) | 2% · 57% |

The Wrestler wins 48% against the Kicker (was 50.5%) and **59% against the Boxer (was 47%)**: he shoots more since D114
(about 25 shots a fight against the Kicker, was 19; 37 against the Boxer, was 30), and the Boxer, with only his jab and
cross to stop an entry, gets taken down about as often as before but sees more shots. That's
reported, not a pass mark (D109); bring it back if the playtest finds the Wrestler too strong against the Boxer (the
Wrestler's `double_leg` tendency, then `TAKEDOWN_PLAN_VALUE`). Kicker vs Boxer is unchanged (51% and 50%), the Wrestler mirror
56/43. Draws 0.9% over the 1,000 fights without calls. Before D114: the Wrestler won 50.5% against the Kicker and 47% against
the Boxer (after D110, below). Striker fights are unchanged: with the Kicker's new knee
taken out, Kicker vs Boxer plays out event for event as it did before this work. The knee itself costs the Kicker a little
(56/44 for the Boxer at tendency 0.6), so it sits at 0.2 in `data/fighters/kicker.json`: there for the clinch and for a shot that
comes in, but rarely thrown in the open. Mirrors as in §20 (Boxer 53/47, Kicker 40/60, the known blue lean). No 10-10 cards.
Draws 0.5% over all 800 fights.

**Draws** were 2.0% over the 800 fights at first (target: under 2%, D97), all but one in Wrestler fights: a striker who stuffs
every shot in a round won it 10-8 (the Wrestler landed almost nothing, under a third of the striker's points) and lost the other
two 10-9, so the cards finished 28-28. A 10-8 now needs out-landing 4 to 1, not 3 to 1 (D110): draws 0.5%, the fights
themselves unchanged (judging doesn't move the dice), Kicker vs Boxer 50.5%, the Wrestler 50.5% against the Kicker and 47% against
the Boxer. To change it: `Judging.DOMINANT_SHARE` (the loser's share of the winner's points under which a round is 10-8), then
re-run the harness and read the draws line.

One thing to look at next: **the Wrestler against the Boxer** stands with their back on the fence 95% of the standing
time; it was the same before this work (90% on main), so it comes from the movement rules (§20.2), not from the grappling.

### 21.8 Strikers' answers to grappling (D114)
With coaching bots in the harness (§22.7), the extra shots good calls bring decided every Wrestler vs Kicker fight: the Kicker
had no way to make grappling cost the Wrestler anything. Kyle chose to give strikers real answers in the same PR (2026-10-25):

| Answer | How it works | To change it |
|---|---|---|
| **Strikes into the entry** | A clinch entry (until it ties up) and the first step of a double leg (its telegraph) set `COMING_IN`. A jab or cross (+10%), teep or knee (+15%) that lands into it **stops** the entry, like the knee into a head-low shot (§21.2); a head shot that would rock them drops them, as there. The AI's counters already look for it | the `COMING_IN` opportunity in `data/actions/{jab,cross,teep,knee}.json`; the flag spans in `clinch_entry.json`, `double_leg.json` |
| **Footwork breaks** | Footwork counts toward breaking the clinch, as it already did toward stopping the entry | `stats.offense` in `data/actions/clinch_break.json` |
| **Wises up** (Kyle's pick) | Every takedown or clinch entry the opponent started in the last 60 s adds +15% to the chance to read the next one (up to +45%), so the third shot in a minute is easier to see coming than the first | `FighterAI.WISE_TICKS` 600, `WISE_READ` 0.15, `WISE_MAX` 0.45 |
| **Kicks less after being caught** | Each time the opponent times a takedown on one of the fighter's moves (a catch that needed its opening, or a shot timed into its wind-up or recovery), the fighter throws that move ×0.7 as often for the rest of the fight, and its tells fire ×0.7 as often | `FighterAI.CAUGHT_FADE` 0.7 |
| **The catch is harder** | The catch-kick single is 10% + 15% for `ONE_LEG` (was 20% + 35%) | `data/actions/catch_kick_single.json` |

The Wrestler grapples more on his own to make up for the Kicker's answers: he plans his range around takedowns and the clinch
(§21.5) and his double-leg tendency is 1.2 (was 0.6). Without calls the matchup stays about even (§21.7).

### 21.9 To change it, and the tests
- Move timings, odds, opportunities and `partial_within`: the move's file in `data/actions/` (`09` action@2).
- Where a move takes the fight, stamina drain, control score, strike multipliers: the position's file in `data/positions/`.
- Sprawl stuck time: `FightSim.SPRAWL_STUCK_TICKS` (5 ticks); the knee into a shot: the HEAD_LOW opportunity in
  `data/actions/knee.json` (`target`, `damage_multiplier`, `stops`).
- Judges: `Judging.TAKEDOWN_POINTS` (10) and `Judging.CONTROL_POINTS_PER_S` (0.3) in `sim/fight/judging.gd`.
- The AI: the constants in §21.5 and §21.8, at the top of `sim/fight/fighter_ai.gd`.

Tested in `tests/sim/fight/test_grappling.gd` (the catch-kick in and out of the `ONE_LEG` window, contact and roll, sprawls in
time and too early, the knee into the shot and the flash knockdown, teen rules, only the bottom fighter gets up, wall-walking,
scrambles, position drain and control, the judges, the clinch, and the AI tied up), `tests/sim/fight/test_positions.gd` and
`tests/ui/test_fight_log_formatter.gd`. The answers to grappling (§21.8): the jab into an entry in `test_grappling.gd`, wising up and
kicking less after being caught in `tests/sim/fight/test_fighter_ai.gd`. After changing any number, run the harness with the Wrestler both ways round
(`--pairs=wrestler:kicker,kicker:wrestler,wrestler:boxer,boxer:wrestler`) and the Kicker vs Boxer pairs, and read the
**Grappling** lines next to the wins.

## 22. Live calls in the engine (#16, D111, D112)
How §6.1–6.4 work in the code (`sim/fight/live_calls.gd`, one per fighter's corner, second in the §19 stack). The corner's
calls are data in `data/calls/` (`09` call@2); a call arrives as a `live_call` command, so a fight with calls still replays
exactly from its seed and command log. A fight with no calls never wakes any of this: fights without calls are identical to
before #16 (event hashes checked on 60 fights across every data/fighters pair).

### 22.1 The pipeline
| Step | Rule |
|---|---|
| Voice (D28) | 100 at the bell, refills 8 a fight-second. Each call costs its `voice_cost` (15–25), and a call needs that much voice left: with less, it isn't heard at all (the command is refused, *"no voice left"*, D115). A call made with under 30 left is **garbled**: 50% longer delay, 50 points more likely to be ignored, and it costs trust like spam |
| Spam | The same call again within 3 s of fight time, or any garbled call, costs 2 points of coach trust |
| Coach trust | 0–100, 50 at the bell until the career relationship exists (D15) |
| Delay (D92) | 6 ticks × (1 ∓ 25% for Fight IQ 100 / 0) × (1 ∓ 20% for trust 100 / 0) × (1 + the tired penalty, up to 30%, + 30% × head hurt) × crowd noise × coach level (both 1 for now) × 1.5 if garbled; never shorter than the fighter's reaction time (D93). A neutral fighter acts 0.6 s after the call |
| Compliance (D5) | Chance to ignore: 3% + 10% × Ego/100 − 5% × Coachable/100 + 40% × (50 − trust)/50 + 25% panicking or rocked + 50% garbled, 0–90%. At the starting trust (50) with a clear voice, ignores stay rare; a coach who shouts through a spent voice loses the fighter fast (D115). An ignored call says the biggest reason (*"ignores the Takedown! call (panicking)"*) |
| Feasibility | Right position and role (Get up only from underneath), allowed by the rules, a move the fighter knows (their techniques, or a `basic` move), and for a read call, its technique learned |

A new call replaces one of the same kind still being processed (logged as `replaced`).

### 22.2 Three kinds of call
| Kind | Calls | What the fighter does |
|---|---|---|
| **Attempt** | Takedown!, Clinch!, Get up!, Feint! | Goes for the first of the call's moves that would work right now: in range, the stamina for it, and the opening it needs there when it lands. *Takedown!* lists following a knocked-down man down first (D142, §34), then the catch-kick single, so a Takedown! call that lands while the opponent's leg is up (or will be as the catch lands) becomes the catch-kick (§5.1); otherwise the double-leg. Out of range, the fighter steps straight in to the nearest band one of the moves reaches from, for up to **2 s**, then gives up (`infeasible`, *"couldn't get in range"*). An attempt with a `then` list (*Feint!*, §29.3a) goes on once its first move is over: straight into the first of the `then` moves that would work |
| **Focus** | Pressure!, Circle out!, Work the range!, Defend the shot!, Survive!, Stay safe! | For **15 s** the fighter's style leanings and move weights tilt, like a short gameplan, then it's back to the gameplan (`expired`). Calling it again starts the 15 s again; a different focus replaces it. The AI looks at its leanings and range plan again straight away when a focus starts or ends. *Go for the finish!* (D200, §25.7) is a 10 s focus that sends the fighter on top after a hold |
| **Read** (D49) | Catch the kick! | Primed for 6 s. When the trigger comes (`opp_kick_starts`: the opponent starts a body kick or teep), the fighter reacts with their own reaction time (D93) and catches as the leg comes up (a quick fighter waits for it). It fires once (`fired`), and comes back as `missed` if the kick was over first. While primed it costs attention: Striking and Takedown defense −15% (`attention_cost`). Up to 2 reads at once (D67), costs added; a third replaces the oldest |

What each focus does (`focus` in each call's file): **Pressure** Pace +60, Range +50 (walks the opponent down, cuts the cage).
**Circle out** Range −80, Pace −20 (gets out and circles off the fence). **Work the range** Range −50, Pace +30 (busy at
distance). **Defend the shot** Range −20, takedowns ×0.5, shots 50 points easier to read and 30 points more likely to be
sprawled on. **Survive** Risk −80, Pace −50, Range −30, strikes ×0.6, clinching ×2 (tie up and hold on). **Stay safe** (D31)
Risk −60, Pace −30, takedowns ×0.5 (coast, no risks).

The fighter AI still never catches a kick on its own (D103): only "Catch the kick!", a Takedown! call during the kick, or a
drilled rule (#17) throws the catch-kick single.

Every outcome is a `call_answered` event with a reason (A16): `accepted`, `ignored`, `infeasible`, `fired`, `missed`,
`expired`, `replaced`. Each call itself is a `call_heard` event (voice left, garbled, delay, trust, spam). The debug console
prints both: *"Wrestler's corner: Takedown! (voice 80 left · acts in 0.6 s)"*, *"Wrestler takes the Takedown! call:
Catch-kick single leg (call after 6 ticks)"*.

### 22.3 The playtest fighter (D112)
The player coaches the **Wrestler** against the Kicker (Kyle, 2026-10-25). The Wrestler now knows the catch-kick single
(`techniques` in `data/fighters/wrestler.json`), which only a call or a drilled rule can make him throw (D103), so fights with
no calls are unchanged: Wrestler vs Kicker stays about even without calls (48% over 400 fights since D114, §21.7). He is still one
of the two authored opponents (`10` §1) when the Kicker is the one being coached.

**To try it:** run the game, pick **Wrestler vs Kicker** on the setup screen, press **Start fight**, and call with the call bar
or keys 1–9 (Q = Catch the kick!; 0 still works too). Calls work while paused (Easy) and land on the next tick (`06` §6).

### 22.4 Gameplans
The five presets in `data/gameplans/` (`09` gameplan@1) shift the style leanings for the whole fight and can scale move
weights: **Pressure** Pace +40, Range +30; **Counter** Pace −40, Risk −20; **Range** Range −50; **Wrestle-heavy** Base +60,
takedowns ×1.5; **Conserve** Pace −50, Risk −40. `Gameplan.load_id("pressure")`, added to a fighter's decision layer
(`sim.decisions[i].add_source(...)`). Since D320 they are parts of a plan the corner builds from three pickers, at half strength: §42.

### 22.5 What a call costs (D115)
A call should pick the moment, not add work: the coach chooses *when* the fighter shoots, the fighter doesn't shoot twice as
often. Before these rules any call won (the Wrestler beat the Kicker 77–80% with good calls and 84–87% with random calls every
1.5 s, 97–100% with Takedown! or Clinch! spammed), because each called move came on top of the AI's own tries. Now:

| Rule | What it does | Number |
|---|---|---|
| **Spent** | A takedown or clinch entry started on a call takes the place of one the fighter would have tried: their own tries of that kind of move from standing wait 45 s of fight time. Moves off the feet (getting up, breaking the clinch) are never held back | `LiveCalls.SPENT_TICKS` 450 |
| **Heard** | Every call heard takes the fighter's eyes off the opponent: Striking and Takedown defense −20% for half a second (counted with a primed read's attention, D67) | `HEARD_ATTENTION` 0.2, `HEARD_TICKS` 5 |
| **No voice, no call** | A call needs the voice it costs (D28). Shouting all fight leaves the voice spent, so most calls never arrive | `FightSim._reject_reason` |
| **Garbled and distrust** | A garbled call is 50 points more likely to be ignored and costs trust like spam; distrust adds up to 40 points | `IGNORE_GARBLED` 0.5, `IGNORE_PER_DISTRUST` 0.4, `SPAM_TRUST_COST` 2 |

Fights with no calls are untouched by all four. A call answered on the tick the fight ends isn't logged after the end (nothing
is: `FightSim._emit`).

### 22.6 Not yet
Habits from calls (D32) and leanings moved by accepted calls (`11` §4.2) come with the career. Crowd noise and coach level are
fixed at 1, and the AI corner's coaching level (D15, D68) is one fixed setting. A **Watch the shot!** read call (primed for the
Wrestler's shot, the counterpart of Catch the kick!) would give the striker's corner a real answer to the Wrestler: the
Defend the shot! focus mostly comes too late for a shot that follows its tell within a second (§22.8).

### 22.7 Corners that call on their own: the AI corner and the coaching bots (D113)
`sim/fight/corner.gd`. A `Corner` sits in `FightSim.corners[i]`, watches the fight's events like a coach at the cage, and
shouts calls as `live_call` commands, so they go through the fighter's whole pipeline (voice, delay, compliance) and the fight
replays from its command log without the corner. It draws from its own seeded RNG, never the fight's: a corner that never
calls leaves the fight as it was.

| Style | Who | What it does |
|---|---|---|
| `none` | The engine on its own | Never calls |
| `ideal` | The "good coaching" bot (D12): a good player | Sees every moment, calls 0.3 s after it, never on a spent voice (it waits rather than garble) |
| `ai` | The opponent's corner (D68) | The same calls, 0.5 s after the moment, and it notices half of them (its coaching level, later D15) |
| `spam` | The "spam" bot (D12) | A random call every 1.5 s, whatever is happening, whatever voice is left |
| `mash:<call>` | The key masher (D257) | One call (`mash:pressure`), again the moment it's over, wherever it can be done, never on a spent voice |

What the ideal and AI corners call (only calls their fighter can act on: a known move or a learned technique):
- the opponent starts a move one of the fighter's read calls is for (a kick, for Catch the kick!): **Takedown!** at once, so it
  lands while the leg is up (§22.2);
- the opponent's scouted tell fires (the Kicker's jab gets blocked: a body kick is coming): the read call for that move,
  **Catch the kick!**, so the fighter is primed before the kick;
- their fighter rocked: **Survive!**; the opponent rocked: **Pressure!** (**Ground and pound!** on top);
- since D257, a moment for most of the other calls: Fire back!, Cut the cage!, Get up!, Collar tie!, following a knocked-down
  man down and keeping up the pressure while winning on the feet (§22.10).

They don't call Defend the shot! on the Wrestler's stance shift (the shot follows within a second, before the call lands; the
fighter reads repeated shots better on their own, §21.8). Five calls have a moment written for them that lost fights when
tried (Circle out!, Defend the shot!, Pass!, Feint!, Go for the finish!), so a plain corner leaves them out (§22.10), and
Hand fight! (D265) has one that came out even, so it's left out too.

**In the game:** the fight screen puts the AI corner in blue's corner; its calls show in a speech bubble and in the feed
(*"Kicker's corner: Survive!"*), and the F3 overlay shows its voice and trust (`06` §6.2).

**In the harness:** `--corners=none,ideal,spam,ai` runs every pair once per bot, with the bot in red's corner and then in
blue's (`--coach=red|blue|both`). The CSV says who was in each corner and how many calls they made (`corner_red`,
`calls_red`…) and what each call did (`call_outcomes_red`…, §22.10). The summary checks, for each coached fighter and opponent, pooled over both corners and both orders: good
coaching adds +10–20% wins over the same fights without calls, and spam wins less than no calls (D12); the AI corner is
reported (INFO). The engine checks (draws, 10-10s, Kicker vs Boxer) only read the fights without calls.

### 22.8 Balance with calls (D12, 2026-10-25)
From the harness, 100 fights a pairing per corner, seeds 1–100 (and 101–200 for Wrestler vs Kicker); each line pools the coached
fighter's wins over both corners and both orders, against the same fights without calls.

| Coached fighter vs opponent | No calls | Good coaching (ideal) | AI corner | Spam |
|---|---|---|---|---|
| **Wrestler vs Kicker** (the playtest, D112) | 48% | **61%: +13%** (+9 and +17 on the two seed sets) | 58%: +7% (seeds 1–100) | 38%: −10% |
| Kicker vs Wrestler | 50% | 54%: +4% | 49.5%: +2% (seeds 1–100) | 23%: −27% |
| Wrestler vs Boxer | 59% | 55.5%: −3.5% | – | 40.5%: −18.5% |
| Boxer vs Wrestler | 40% | 41.5%: +1.5% | – | 18.5%: −21.5% |
| Kicker vs Boxer | 50.5% | 47%: −3.5% | – | 18.5%: −32% |
| Boxer vs Kicker | 49.5% | 52%: +2.5% | – | 51%: +1.5% |
| Mirrors (Kicker, Boxer, Wrestler) | 50% | 50%, 46.5%, 50% | – | 16.5%, 39.5%, 33.5% |

**What it says.** Good coaching of the playtest fighter is worth +13% (the D12 band is +10–20%), and the AI corner about half
of that. Spam loses everywhere except Boxer vs Kicker, where it's even (+1.5%, within
the noise). Strikers' good coaching is worth about nothing: their corners only have Survive! and Pressure!
(about 2 calls a fight), so the ideal bot has nothing to time. That's the next gap: give the striker's corner a read on the
shot (a **Watch the shot!** read call, §22.6) and calls that move the fight (Circle out! off the fence), then hold every
fighter to D12, not just the Wrestler.

**Noise.** The same fights coached from the red corner or the blue corner differ a lot (the Wrestler with good coaching: +7
red, +19 blue), and the Kicker's corner, making 2–3 calls a fight, moved his wins anywhere from −3 to +16 on 100 fights. A call shifts everything
after it in the fight's random stream, so 100 fights is about ±5% each way; pool both corners and two seed sets before reading a
number.

**Before the call costs (§22.5) and the strikers' answers (§21.8)**, with the first bots: the Wrestler beat the Kicker 77–80%
with good coaching, 71–74% with the AI corner and 84–87% with random calls every 1.5 s (Clinch! spammed: 100%).

**After health and ground and pound** (D120/D121; the Playtest numbers run of 2026-10-26, D124, seeds 1–100 and 101–200 for
Wrestler vs Kicker, pooled as above):

| Coached fighter vs opponent | No calls | Good coaching (ideal) | AI corner | Spam |
|---|---|---|---|---|
| **Wrestler vs Kicker** (the playtest) | 67% | **82%: +15%** (+19.5 and +11) | 72%: +10% (seeds 1–100) | 61.5%: −5% (−2 and −8.5) |
| Kicker vs Wrestler | 32% | 28.5%: −3% | 33%: −2.5% | 13%: −19% |
| Wrestler vs Boxer | 52% | 62%: +10% | 60%: +8% | 49.5%: −2.5% |
| Boxer vs Wrestler | 47.5% | 51%: +3.5% | 48%: +0.5% | 27%: −20.5% |

Good coaching still pays the Wrestler (D12 met against both), but spam calling the Wrestler costs much less than before (it
was −10%). A likely reason, not yet checked: his spammed calls now include Ground and pound!, which helps whenever he's on
top. Worth watching if testers find mashing the keys works.

### 22.9 To change it, and the tests
- What a call does, its voice cost, hotkey, positions, focus tilt and read timing: its file in `data/calls/`.
- What sets off Catch the kick!: `data/triggers/opp_kick_starts.json`.
- Voice, trust, delay, compliance, the 2 s attempt window and the 2-read limit: the constants at the top of
  `sim/fight/live_calls.gd` (`BASE_DELAY_TICKS`, `DELAY_PER_*`, `VOICE_*`, `GARBLED_*`, `TRUST_START`, `SPAM_*`, `IGNORE_*`,
  `ATTEMPT_TICKS`, `MAX_READS`).
- Which stats a primed read lowers: `FighterState.ATTENTION_STATS`.
- What a call costs (§22.5): `SPENT_TICKS`, `HEARD_ATTENTION`, `HEARD_TICKS`, `IGNORE_GARBLED`, `IGNORE_PER_DISTRUST` in
  `sim/fight/live_calls.gd`; the no-voice rule in `FightSim._reject_reason`.
- The corners (§22.7): `IDEAL_REACTION` (3 ticks), `AI_REACTION` (5), `AI_NOTICE` (0.5), `SPAM_EVERY` (15), `SAVE_VOICE` and
  what each one watches for (`on_event`, and `_watch` for the moments read off the fight as it stands) at the top of
  `sim/fight/corner.gd`; which D257 moments a plain corner uses (`DEFAULT_MOMENTS`), `URGENT`, `FINISH_FROM`, `STUFFED`,
  `PRESSING_LEAD` and `PRESSING_TICKS` (§22.10); what each call's exchange is and what winning it means:
  `sim/balance/call_outcomes.gd` (`ATTEMPT_WINDOW`, `READ_WINDOW`); the D12 band in `BalanceReport.COACHING_GAIN_MIN`
  and `COACHING_GAIN_MAX` (`sim/balance/balance_report.gd`).

Tested in `tests/sim/fight/test_live_calls.gd` (voice and garbling, spam and trust, the delay modifiers, compliance, every
kind of call and outcome, the catch-kick from a Takedown! call in and out of the kick, the read with slow and quick fighters,
attention, two reads at most, replays, and what a call costs), `tests/sim/fight/test_corner.gd` (what each corner calls and
when, every D257 moment, the focus it won't cut short, the key masher, the voice it saves, replays without it),
`tests/sim/balance/test_call_outcomes.gd` (what counts as winning each kind of call's exchange), `tests/sim/balance/` (the corner columns and the coaching checks),
`tests/sim/fight/test_decision_layer.gd`, `tests/data/test_data_files.gd` (call@2,
gameplan@1) and `tests/ui/` (the log lines, the call bar).

After changing any of it, run the harness with the bots on the Wrestler both ways round and read the **Coaching** lines:
`--fights=100 --pairs=wrestler:kicker,kicker:wrestler --corners=none,ideal,spam,ai`. Coaching is noisy: 100 fights a side is
about ±5% on each corner, so pool both corners and a second seed (`--seed=101`) before moving a number.

### 22.10 A corner that uses every call (D257)
The outside review of the AI (§20.4): *"stop treating the current ideal corner as an upper bound. It omits Fire back, Defend
the shot, Get up, Pass, Feint, and Collar tie"*, and random calls every 1.5 s don't show that repeating the strongest call
can't beat good coaching. Kyle: "you can start the corner now" (2026-10-31), and the opponent's AI corner gets the same calls
("Yes, the same calls"): slower and noticing half of them, as before.

**The moments** (`Corner.MOMENTS`). Each is a moment a good corner would call, written once and tried on its own:

| Moment | When | The call | In a plain corner? |
|---|---|---|---|
| `fire_back` | The opponent's strike runs on into a combination (its second move starts); not for a fighter who shoots, since a fired Fire back! holds his own leads, his shots too, for 10 s (`LEADS_HELD_TICKS`) | Fire back! | Yes |
| `cut_the_cage` | Standing, the opponent circles away and this fighter leans further in (higher Range) and isn't cutting already | Cut the cage! | Yes |
| `keep_pressing` | Standing, he isn't an outside fighter (Range 0 or more), he's landed 10 more damage than he's taken in the last 20 s (`PRESSING_LEAD`, `PRESSING_TICKS`) and no other focus is on | Pressure! | Yes |
| `get_up` | Underneath, the man on top is rocked (it used to shout Pressure!, which can't be done there) | Get up! | Yes |
| `collar_tie` | The clinch starts, he knows the collar tie (D129) and the opponent doesn't shoot (tied up with a grappler, he trips or takes him down) | Collar tie! | Yes |
| `follow_down` | The opponent is knocked down and this fighter knows a takedown of his own (D142) | Takedown! | Yes |
| `defend_the_shot` | The opponent starts a takedown | Defend the shot! | No |
| `feint` | His own shot is stuffed (defended, sprawled on or stopped) | Feint! | No |
| `pass` | On top, the man underneath covers up (D270) | Pass! | No |
| `go_for_the_finish` | On top in side control, mount or on the back with a hold he knows there (the rear-naked choke is everyone's) | Go for the finish! | No |
| `circle_out` | An outside fighter (Range below 0) off the centre with the opponent cutting him off | Circle out! | No |
| `hand_fight` | In the clinch or on the ground, the opponent wins a grip, and he has 90 voice or more (D265, §40.13) | Hand fight! | No (even) |

No moment is called again while its last call is still on (its focus, read or the attempt's 2 s, never under the 3 s that
makes it spam), and a focus call never replaces a more urgent one still running (Survive!, Pressure!, Ground and pound!,
Finish it!, Defend the sub!, `URGENT`). The moments that lost fights stay written: the harness tries any of them with
`--corners=ideal:pass+feint` (only those D257 moments, with the old ones always on) and `ideal:` is the corner as it was.

**The key masher** (`mash:<call id>`): the review's "repeating the strongest call at its optimal interval". It shouts one call
the moment its last one is over, wherever the call can be done, and never on a spent voice.

**What each call did** (`CallOutcomes`, Kyle's D251 answer): for every call, heard, taken, and whether the exchange it was called
for was won. A move (Takedown!, Get up!, Collar tie!...) wins when the move started on the call works within 4 s; a read when it
goes off and its move works (Fire back!: he lands more than he takes in the 2 s after); a focus over its time: Survive! not
knocked down or stopped, Defend the shot! no takedown landed (counted only if he shoots), Finish it! the tap, Defend the sub!
out, Go for the finish! a hold locked, Cut the cage! the man pinned on the fence, Circle out! back to the centre, and the rest
(Pressure!, Ground and pound!...) landing more than he takes. Each pairing's block in the summary has a **Calls** line per
coached side; the CSV has `call_outcomes_red` and `_blue` (`id:heard/taken/judged/won;...`). The D12 band check still runs
next to it; it isn't replaced yet.

**Measured** (on main at #101, before the ground grips D263–D264; 100 fights a pairing per corner, both corners pooled, change in the coached fighter's wins against the same
fights without calls; paired 95% ranges are about ±10 on each line):

| Coached vs opponent | Old ideal (seeds 101–200) | New ideal (seeds 101–200) | New ideal (seeds 1–100) | New AI corner (101–200) | `mash:pressure` (101–200) |
|---|---|---|---|---|---|
| Wrestler vs Kicker | +20 | +23 | +32 | +19 | +21 |
| Kicker vs Wrestler | +8 | +8 | −15 | −4 | −9 |
| Wrestler vs Boxer | −3 | +2 | +2 | +5 | −3 |
| Boxer vs Wrestler | −4 | −1 | −5 | −8 | −4 |
| Kicker vs Boxer | −5 | +4 | −20 | +1 | −28 |
| Boxer vs Kicker | +3 | **+34** | +31 | +28 | +21 |
| Muay Thai vs BJJ | +1 | +5 | +11 | +1 | +14 |
| BJJ vs Muay Thai | +9 | +5 | +8 | −3 | +17 |
| Pressure wrestler vs Counter-striker | −3 | **+18** | +2 | +6 | +4 |
| Counter-striker vs Pressure wrestler | +1 | +1 | +16 | +0 | +13 |
| Dirty boxer vs Leg-kick specialist | +15 | +11 | −2 | +3 | +0 |
| Leg-kick specialist vs Dirty boxer | +9 | +9 | +4 | +3 | −8 |
| Muay Thai vs Boxer | +1 | +4 | +4 | −3 | +14 |
| Boxer vs Muay Thai | +8 | **+18** | +3 | +4 | +7 |
| Karate vs Brawler | +2 | +3 | −8 | +10 | −5 |
| Brawler vs Karate | −4 | **+16** | +25 | +3 | −9 |
| Sambo vs Sprawl-and-brawl | −7 | −11 | −25 | +0 | −24 |
| Sprawl-and-brawl vs Sambo | +8 | +0 | +0 | +3 | −17 |
| **Average** | **+3.3** | **+8.3** | | | |

(The seeds 1–100 column is the run before `keep_pressing` was kept off outside fighters: the Kicker's −15 and −20 came from it.)

Pooled over every coached side in the second run, a fight with the new ideal corner hears about 26 calls; what they did:

| Call | Heard a fight | Won its exchange |
|---|---|---|
| Pressure! | 6.9 | 62% |
| Cut the cage! | 5.9 | 22% (the man pinned on the fence) |
| Ground and pound! | 5.1 | 77% |
| Fire back! | 2.2 | 66% of the 8% that went off |
| Survive! | 2.2 | 94% |
| Takedown! | 1.2 | 26% |
| Collar tie! | 1.2 | 72% |
| Defend the sub! / Finish it! | 0.4 / 0.3 | 90% / 27% |

**Trying each one on its own** (seeds 1–100, leaving one moment out of all ten): Cut the cage! is the big one (Boxer vs Kicker
+33 with it, +6 without); Fire back! carries the Leg-kick specialist (+15 with, +3 without) but cost the Wrestler against the
Boxer until it was kept off fighters who shoot (−20 with, −4 without); Circle out! cost the Kicker against the Boxer 26 points
(it was called 45 times a fight; he got off the fence 85% of the time and lost anyway); Pass! (−20 to −3 for the Wrestler
against the Boxer: passing instead of punching a man covering up), Feint! (−20 to −9, and it spends his own shots for 45 s,
D115), Defend the shot! (Muay Thai against BJJ −13 to +2) and Go for the finish! (a few points worse everywhere) all lost
wins, as did Collar tie! against a grappler (−13 to 0).

**What it says.** The corner is a better upper bound now: +8 points on average, against +3 before, and no line clearly worse.
Calls that keep the fight where a fighter wants it (Cut the cage!, Pressure!, Fire back!) are where coaching pays; calls that
change what he does on the ground mostly cost him. Only 4 of the 18 lines are in D12's +10–20% band. And mashing Pressure!
beats good coaching for several fighters (BJJ +17, Muay Thai +14, the Counter-striker +13), so repeating it had no cost: §22.11 (D258) makes repeats wear off.

### 22.11 Calling Pressure! again and again (D258)
The key masher (§22.10) showed that shouting Pressure! the moment the last one ends beat good coaching for several fighters.
Kyle picked "Opponent reads it" (2026-10-31): a man who keeps coming the same way gets timed. The read alone barely changed
it, so Kyle then picked "Add repeats wearing off" (2026-11-01): each Pressure! called soon after the last one tilts him less.

**What changed.**

| Part | Rule | Number (`sim/fight/`) |
|---|---|---|
| **Repeats wear off** | A focus call taken again pushes his leanings less for each time the same call started in the last minute: the second in a minute pushes 70% as hard, the third 49%. A minute after the last one it's fresh. Every focus call works this way, not just Pressure!; the fighter says so when he answers (*"for 15 s, 70% as hard: called again"*) | `LiveCalls.REPEAT_TICKS` 600 (60 s), `REPEAT_WEAR` 0.7 |
| **A repeat costs stamina** | Built, switched off: each repeat would cost this much stamina as it starts. At 2 it cost good coaching as much as mashing (Pressure wrestler vs Counter-striker +6 → −14, Muay Thai vs Boxer +3 → −7) | `LiveCalls.REPEAT_STAMINA` 0 |
| **He reads the pressure** | A fighter is *pressing* while a focus call pushes his Range up at least 30 (Pressure!, Cut the cage!). Once he has pressed more than half of the last minute, the other man reads his moves better and meets him on the way in more often: up to +30% to both, all of it once he's pressed the whole minute. His own style's leaning in never counts, only a call's | `LiveCalls.PRESSING_RANGE` 30, `FightSim.PRESS_SECONDS` 60, `FighterAI.PRESS_READ_FROM` 0.5, `PRESS_READ` 0.3 |

**Measured** (seeds 101–200, 100 fights a pairing per corner, both corners pooled, change in the coached fighter's wins against
the same fights without calls; paired 95% ranges are about ±12 on each line):

| Coached vs opponent | Ideal before | Ideal after | `mash:pressure` before | `mash:pressure` after |
|---|---|---|---|---|
| Muay Thai vs BJJ | −1 | +1 | +3 | −1 |
| BJJ vs Muay Thai | +16 | +11 | +25 | +25 |
| Pressure wrestler vs Counter-striker | +6 | +4 | −1 | +8 |
| Counter-striker vs Pressure wrestler | +1 | +2 | +7 | +3 |
| Muay Thai vs Boxer | +3 | +3 | **+13** | **+2** |
| Boxer vs Muay Thai | +14 | +17 | +9 | +7 |
| Boxer vs Kicker | +32 | +36 | +27 | +25 |
| Kicker vs Boxer | +4 | −1 | −34 | −27 |
| Wrestler vs Kicker | +24 | +26 | +20 | +19 |
| Kicker vs Wrestler | −1 | −6 | −14 | −13 |
| Brawler vs Karate | +16 | +17 | −1 | +8 |
| Karate vs Brawler | +2 | +3 | −13 | −23 |
| **Average** | **+9.7** | **+9.4** | **+3.4** | **+2.8** |

**What it says.** Good coaching is unchanged, and mashing loses its clearest win (Muay Thai against the Boxer, +13 → +2); the
Counter-striker's goes from +7 to +3. BJJ against Muay Thai is still +25 mashed, more than the ideal corner's +11: his gain
isn't the repeats, it's pressing whenever he's standing, which closes the distance and gets him to the ground. That is good
advice for him rather than abuse; a later step could have the ideal corner call Pressure! for a grappler who wants the ground.

**To change it.** Make repeats wear off faster or slower with `REPEAT_WEAR` (1.0 turns it off) and `REPEAT_TICKS`; turn the
stamina cost on with `REPEAT_STAMINA` (a heavy punch costs about 6); make the read stronger with `PRESS_READ` or start it
sooner with `PRESS_READ_FROM`. Tests: `tests/sim/fight/test_pressure_read.gd`. Compare with
`tools/balance.gd -- --fights=100 --seed=101 --pairs=muay_thai:bjj,pressure_wrestler:counter_striker,muay_thai:boxer,boxer:kicker,wrestler:kicker,brawler:karate --corners=none,ideal,mash:pressure`.

## 23. Drilled rules in the engine (#17, D82, D116)
How §6.0's second layer works in the code (`sim/fight/drilled_rules.gd`, one per fighter, third in the §19 stack: under live
calls, over the fighter's own AI). A rule is a preset in `data/rules/` (`09` rule@2): a trigger from `data/triggers/` and a
move. It goes in one of the fighter's two slots before a round as a `set_rule` command, with how well it was drilled (0–100%,
the playtest's stand-in for camp drilling), so a fight with rules replays from its seed and command log. A fighter with no
rules never wakes any of this.

### 23.1 What happens when the trigger comes
| Step | Rule |
|---|---|
| **Slot order** (D116) | Slot 1 goes first. Both slots answering the same moment: slot 1 is tried first; if it's cooling down or too slow, slot 2 gets its turn; once one is on its way, the other is `outranked`. A slot 1 rule set off while a slot 2 rule waits takes over |
| **Cooldown** | A rule that fired sits out `cooldown_ms` of fight time (15 s for both presets), logged as `cooling` |
| **Reliability** | drilled × (1 ± 20% for Fight IQ 100 / 0) × (1 − the tired penalty, up to 30%) × (1 − 50% × head hurt) × (1 − how wise the opponent is to it). Missed rolls are logged as `slow` with the chance: *"didn't see it in time: 64% sharp"* |
| **Reaction** | The fighter acts their own reaction time after first seeing the move (D93, 2 ticks at Speed 50), like a read call |
| **Eligible** | Allowed by the rules, possible from here, in range, the stamina for it, and not rocked; otherwise `not_eligible` with the reason. A move that needs an opening waits for it while the opponent's move goes on (a catch waits for the leg). Busy until the moment has gone: `missed` |
| **Adapting** (§6.0, R4) | Each time a rule fires on the opponent's move, they disguise it a little more: 10% off its reliability per fire at the opponent's Fight IQ 100 (5% at 50), at most half. It carries over when the same rule stays in the slot between rounds |

Live calls still outrank rules: a call the fighter is acting on goes first. Rules take no voice and cost no attention.

Every outcome is a `rule_answered` event (A16): `set`, `fired`, `cooling`, `slow`, `outranked`, `not_eligible`, `missed`. The
debug console prints them: *"Wrestler goes on the rule "When he kicks → catch & shoot": Catch-kick single leg (3 ticks after the
body kick started)"*, *"Wrestler holds the rule "When he kicks → catch & shoot" (fired 4 s ago)"*.

### 23.2 The presets
| Rule | Trigger | Move | Who can use it |
|---|---|---|---|
| When he kicks → catch & shoot | The opponent starts a body kick or teep | Catch-kick single | Fighters who learned the catch (the Wrestler, D112). The only way besides a call that the catch is ever thrown (D103) |
| When he shoots → sprawl | The opponent starts a double leg | Sprawl | Everyone (the sprawl is basic) |

**To try it:** on the setup screen, pick your fighter's rules under *Rule 1* / *Rule 2*, set *Drilled*, then press **Start fight**;
they can be changed at the bell between rounds, and the plan panel shows how sharp each one is and its cooldown (`06` §6).

### 23.3 Balance (2026-10-25)
From the harness, Wrestler vs Kicker both ways round, 100 fights a side per seed set, against the same fights without rules:

| Rule | Drilled | Fires a fight | Wins | What changes |
|---|---|---|---|---|
| Wrestler: When he kicks → catch & shoot | 50% | 8 | −2% (seeds 1–100) | |
| Wrestler: When he kicks → catch & shoot | 80% | 9–11 | **−1%** (both seed sets) | Takedowns 9.5 → 11.4 a fight, time on top 34% → 40%, but head damage taken 150 → 235 and KOs 1–4% → 6–10% |
| Wrestler: When he kicks → catch & shoot | 100% | 10 | −5.5% (seeds 1–100) | |
| Kicker: When he shoots → sprawl | 80% | 9 | **−8%** (−5 and −11) | Shots sprawled on 3.7 → 6.3 a fight, takedowns −1, but the Kicker's lowest stamina 17% → 10% |
| Boxer: When he shoots → sprawl, against the Kicker | 80% | 0 | 0 | Never set off: the fight is the same |

**Why the rules don't pay yet.** The catch rule works as a catch (two more takedowns a fight), but each catch also makes the
Kicker throw body kicks and teeps less (×0.7 each, §21.8), so he goes upstairs: head kicks on a Wrestler standing in front of
him double, and that costs what the takedowns win. A floor on that fade (never below a third as keen) took the head damage
from 235 to 200 without changing the wins, and pushed good coaching (§22.8) to +18.5%, near the top of the D12 band, so it
was left out. The sprawl rule sprawls on top of the sprawls the Kicker already makes when he reads the shot (about 10 a fight)
and the extra stamina leaves him gassed. Both are the counter-play §6.0 asks for (opponents adapt, rules cost something), but
a drilled rule should be worth having. Next to try: rules that only fire while the fighter is fresh enough (the "stamina
threshold" condition §6.0 saves for later), a rule that stands in for the fighter's own read instead of adding to it, and
the opponent's adaptation leaning on the rule's reliability (already in) more than on dropping the move.

### 23.4 To change it, and the tests
- A rule's trigger, move and cooldown: its file in `data/rules/`; what sets a trigger off: `data/triggers/`.
- Reliability, adaptation and the slot count: `RELIABILITY_PER_IQ`, `RELIABILITY_PER_HEAD_HURT`, `ADAPT_PER_FIRE`, `ADAPT_MAX`,
  `MAX_SLOTS` at the top of `sim/fight/drilled_rules.gd`.
- How far a caught move fades: `FighterAI.CAUGHT_FADE` (§21.8).
- In the harness: `--rules=wrestler:catch_kick_and_shoot@80` (fighter:rule@drilled, a fighter's rules fill slots 1 and 2 in
  order) runs every pair once more with those rules and reports what they did to that fighter's wins.

Tested in `tests/sim/fight/test_drilled_rules.gd` (firing with reaction time, reliability, cooldown, slot order, out of range,
rocked, busy, setting rules, adaptation, untouched fights, replays), `tests/sim/balance/` (the rules columns and lines) and
`tests/ui/test_fight_log_formatter.gd`.

---

## 24. Health, the referee and ground and pound (D120, D121)
Kyle tried the playtest build (2026-10-26): "kind of pointless with no health system and no ground and pound". The engine
already tracked head, body and leg damage, but it hardly showed: only 3% of fights ended early, and the Wrestler spent 35–55%
of his fights on top doing nothing but holding (D108). Kyle picked **about 30% of fights ending early, like real MMA**. Every
number below is a first guess for the harness; each is a named constant or a data field, listed in §24.6.

### 24.1 Health (D120)
A fighter's **health** is the head damage they can still take: `1 − head hurt`, where 10 × (Chin + 50) of head damage is all of
it (Chin 50: 1,000). It doesn't come back between rounds (D99). It was always there underneath (hurt fighters are slower, defend
worse and get rocked more easily, §8, `11` §3.2); now it has a bar and an end. The HUD's top bar shows it as the head of a body figure
(D150, `06` §6.2): head, body and legs run green → yellow → red, with what's left of each beside it and ROCKED when they are
(body damage shrinks the tank, leg damage slows the feet). `FighterState.health()`.

### 24.2 The referee (D120)
The referee watches every clean head shot and stops the fight (a TKO, with the reason on the result) when:

| Stoppage | When | Feed |
|---|---|---|
| **Nothing left** | Health reaches 0 | "the referee stops it: nothing left" |
| **Taking shots, standing or down** | A rocked fighter takes 2 more clean head shots (counted after the one that rocked them) without answering | "taking shots and not answering" |
| **Taking shots underneath** | A fighter on the bottom takes 2 + 14 × health clean head shots in a row without answering: 16 fresh, 9 at half health, 5 at 20% | the same |
| **Three knockdowns** | Three knockdowns in a round (as before) | "three knockdowns in a round" |

**Answering** is landing anything back, tying the top fighter up, or getting out from under (any change of position); the count
also clears when a rock wears off, at a knockdown, and between rounds. Before, a TKO only came from three knockdowns or a head
fully hurt while rocked. Amateur referees step in sooner (the ruleset's `early_stoppage_bias`, `08`): the health line moves up by
bias × 0.5 (adult amateur 15%, teen 25%) and they stop after one shot fewer.

### 24.3 Ground and pound (D121)
In full guard the fighter on top strikes and the fighter underneath answers (since D130 the same strikes work from the top of
half guard, side control, mount and the back, harder or softer by the position, §28; since D270 there are hammerfists, body
punches and the posture-up bomb as well, and the man underneath can cover up, §41):

| Move | Who | Timing (telegraph · wind-up · active · recovery) | Odds and damage | Notes |
|---|---|---|---|---|
| Ground punch (*everyone*) | Top | 0.1 · 0.2 · 0.1 · 0.3 s | 50% + (Top control, Boxing) − Guard, +10% on `HANDS_LOW`; 4 to the head × Power × 0.8 (full guard top) | `POSTURED_UP` from wind-up to the end |
| Ground elbow | Top, a technique (the Wrestler has it) | 0.2 · 0.3 · 0.1 · 0.4 s | 50% + (Top control, Power) − Guard; 7 to the head | Not where elbows are banned (amateur rules) |
| Tie up (*everyone*) | Bottom | 0 · 0.2 · 0.3 · 0.2 s | 45% + (Guard, Strength) − Top control, +15% on `POSTURED_UP` | Works: the top fighter's posture is broken (`POSTURE_BROKEN`), the strike he was winding up is smothered, and no ground strikes. The fight stays in full guard. Until D263 it wore off after 3 s; now it's the collar tie, held until he postures up, next to wrist control (§40.11) |
| Get up (as §21.1) | Bottom | | +20% on `POSTURED_UP` | Posturing up to strike gives the space to get up |

- **Rocked again on the ground** is the KO roll (§8) instead of a knockdown: there's nowhere to fall. The feed says "ROCKED again
  underneath".
- **Amateur rules** (`08`: no head strikes on the ground) send ground strikes to the body; elbows aren't allowed at all.
- **The AI on top** (`FighterAI._pound`): a chance of 1.2 × work rate × (1 + Pace / 100) a tick to throw a ground strike (the
  Wrestler: one about every 2.5 s), × (1.5 + Risk / 200) against a rocked fighter, less when tired; tied up, it holds until the
  posture is back. Punch or elbow is picked like any strike (tendency, commitment, the finish).
- **The AI underneath**: tries 3 × as often while the top fighter is throwing or they're rocked; tying up is weighted 1.5 then
  (0.3 otherwise), and a rocked fighter's get-ups 0.3.
- **The call**: *Ground and pound!* (key 1, voice 20) is a focus call from the top of full guard: Pace +80 and Risk +40 for
  15 s, so the fighter throws about twice as often. It shares key 1 with *Pressure!*, which is only for standing; the key makes
  whichever works from where the fight is (`data/calls/`: two calls may share a key only if they're never possible in the same
  position). The AI corner (and the harness's coaching bots) call it when their fighter lands on top, and when the opponent is
  rocked underneath (instead of *Pressure!*).

### 24.4 Judges (D120)
Ground strikes score like any strike. With them scoring, ending up on top dropped to 6 points (was 10) and control to 0.15 a
second (was 0.3), or the Wrestler won 75–85% of fights on points. And a **10-8 for out-landing** (4 to 1 in a busy round, D110)
now also needs the winner to have rocked or dropped the loser that round: a striker who stuffed every shot, or a Wrestler who
held and tapped, was getting 10-8s and 28-28 draws (4% of Wrestler vs Kicker fights). Two more knockdowns is still a 10-8. The
HUD's estimate uses the same rule (`FightSim.round_impact()`).

### 24.5 Balance (2026-10-26)
The harness without calls, 100 fights a pairing (seed 1, pro rules), and with the ideal coaching bot in the Wrestler's corner:

| Pairing (red vs blue) | Red wins · draws | Finished early (KO · TKO) | Ground (Wrestler on top) | Before (main) |
|---|---|---|---|---|
| Kicker vs Boxer | 44% · 0% | 25% (4 · 21) | – | 51% · 3% finished |
| Boxer vs Kicker | 55% · 0% | 33% (9 · 24) | – | 50% |
| Wrestler vs Kicker | 60% · 3% | 20% (2 · 18) | 35% (33%) | 50% · 1% finished |
| Kicker vs Wrestler | 34% · 2% | 15% (2 · 13) | 38% (35%) | 51% |
| Wrestler vs Boxer | 49% · 0% | 60% (2 · 58) | 52% (49%) | 59% · 5% finished |
| Boxer vs Wrestler | 44% · 1% | 54% (0 · 54) | 54% (51%) | 40% |
| Wrestler (coached) vs Kicker | 78% · 0% | 47% | 44% | +18% for coaching (D12 met) |
| Wrestler (coached) vs Boxer | 60% · 0% | 74% | 53% | +11% (D12 met) |

- **Finishes**: about a third of the cross-style fights end early (26% striker vs striker, 18% Wrestler vs Kicker, 57%
  Wrestler vs Boxer; average 34%), against 3% before. Mirrors: Kicker 14%, Wrestler 4%; the Boxer mirror was already all
  finishes (100%, unchanged).
- **Targets**: draws 1% (under 2%, D97), no 10-10 cards, Kicker vs Boxer 55/45 (within 60/40). The Wrestler wins 60–64% against
  the Kicker and 49–55% against the Boxer (report only, D109).
- **What to watch in the playtest**: Wrestler vs Boxer finishes a lot (the Boxer has nothing for the clinch and tires under
  ground and pound; he also stops the Wrestler standing more than before). If ground and pound feels too strong, lower
  `FighterAI.GNP_RATE`, then the full guard top `strike_damage_multiplier`; if fights end too often, raise
  `FightSim.GROUND_STOP_PER_HEALTH` or `STOP_UNANSWERED`.
- Speed: the timing checks (§2.1) pass; ground strikes add a few events a second on the ground.

### 24.6 To change it, and the tests
- Health: `FighterState.HURT_SCALE` (10; it also sets how fast damage slows a fighter down, so it moves every fight).
- The referee: `FightSim.STOP_UNANSWERED` (2), `GROUND_STOP_PER_HEALTH` (14), `STOP_BIAS_HEALTH` (0.5) and each ruleset's
  `early_stoppage_bias`.
- Ground strikes and the tie-up: `data/actions/ground_punch.json`, `ground_elbow.json`, `tie_up.json` (held until he postures up since D263: `ground.grip`, `09`, §40.11);
  the get-up bonus: the `POSTURED_UP` opportunity in `get_up.json`; the full guard top multiplier: `data/positions/full_guard.json`.
- The AI: `FighterAI.GNP_RATE` (1.2), `GROUND_UNDER_FIRE` (3.0), `TIE_UP_CALM` (0.3), `TIE_UP_PRESSED` (1.5), `ROCKED_GET_UP` (0.3).
- The call: `data/calls/ground_and_pound.json`. Judges: `Judging.TAKEDOWN_POINTS`, `CONTROL_POINTS_PER_S`, and `round_card`'s
  impact rule.
- The HUD: `HEALTH_STEPS` and the colours at the top of `ui/fight_hud.gd`.

Tested in `tests/sim/fight/test_ground_and_pound.gd` (health, every stoppage and what answers it, amateur referees, the ground
punch, who can strike, amateur rules, posturing up, the tie-up, the KO roll on the ground, the AI on top and underneath, the
10-8 impact rule), `tests/sim/fight/test_corner.gd` (the corner's call on top), `tests/ui/test_fight_hud.gd` (the health
bars), `tests/ui/test_fight_log_formatter.gd` (the feed lines) and `tests/data/test_data_files.gd` (`ties_up_ms`, shared keys).
After changing a number, run the harness with all six cross-style pairings
(`--pairs=kicker:boxer,boxer:kicker,wrestler:kicker,kicker:wrestler,wrestler:boxer,boxer:wrestler`) and read the **How** lines
(finishes) next to the wins and draws.

## 25. Submissions (D126)
Kyle asked for submissions (2026-10-27: "can we add in submissions?") and picked the simple struggle: three holds from the
positions the game already has, each locking in like any grapple and then fought for in a short struggle with a danger meter,
with one call a corner. It's the first step of §9 (D10): the per-beat menu of calls with one right answer, auto slow-mo
tuned to it and the holds that need other positions (the back, mount, side control) come later. (They came with D130, §28:
the rear-naked choke from the back, the arm-triangle from side control and mount, and the armbar from mount; the leg locks came with D132, §30.) Every number is a first
guess for the harness; each is a named constant or a data field, listed in §25.6.

### 25.1 The holds
| Hold | Who, from where | Timing (telegraph · wind-up · active · recovery) | Lock-in odds (base + attack − defense stats) | If it doesn't lock | Getting out |
|---|---|---|---|---|---|
| Guillotine (*everyone*) | Standing or in the clinch | 0 · 0.1 · 0.3 · 0.4 s | 35% + (Submissions, Strength) − (Submission defense, Scrambles), +10% on `HEAD_LOW` (required: the head has to be low, a shot in its drive or stuck under a sprawl) | The attacker is pulled onto their back: full guard, the shooter on top (who scores it like a takedown) | Back where it was locked from |
| Triangle choke (a technique; the Kicker has it) | Bottom of full guard | 0 · 0.3 · 0.4 · 0.6 s | 25% + (Submissions, Guard) − (Submission defense, Top control), +15% on `POSTURE_BROKEN` (after a tie-up) | The top fighter stays on top; the long recovery is a free window for his punches | Back to full guard, same roles |
| Armbar (a technique; the Kicker has it) | Bottom of full guard | 0 · 0.2 · 0.3 · 0.4 s | 25% + (Submissions, Guard) − (Submission defense, Strength), +20% on `POSTURED_UP` (the top fighter's arm out on a ground punch) | Within 15% of the odds it half works: a scramble. Otherwise the top fighter stays on top | A scramble |

A hold resolves like a takedown (§21.2): contact at the start of its active phase (the range, the opening a guillotine needs,
odds fixed then), the roll as it ends. When it locks the fight moves to the **submission** position (`data/positions/`,
roles `attacker` and `defender`): nobody walks, nobody starts a move, it drains 1.0 a second from the attacker and 1.2 from the
defender, and the attacker scores control (1.0) as from the top of full guard.

### 25.2 The struggle
1. **The danger meter starts** at the hold's `start_danger` (40) plus half the gap between the attacker's and the defender's
   stats for that hold, kept within 10–90: Submissions 100 against Submission defense 80 starts at 50.
2. **Every second of fight time is a beat.** The attacker wins it on a chance of 50% + (attack − defense stats) / 100, the
   same stats as the lock-in, effective (a tired or hurt defender loses more beats), plus or minus the calls (§25.3). A beat
   won moves the danger up 20, a beat lost down 20, and each costs both fighters 2 stamina.
3. **At 100 the defender taps**: a submission win, "Kicker wins by submission (triangle choke)". **At 0 they're out**, and
   after 5 beats with no tap they're out too: back where it was locked from, or into a scramble (`escape_to`). Getting out
   answers the referee's count (§24.2), like any change of position.
4. **The bell saves them**: a round that ends mid-hold sends both to their corners.

Between equal fighters a locked hold taps about 22% of the time (start 40, 20 a beat, 5 beats); at 45% a beat about 16%, at 65%
about 46%. A hold that gets to 80 counts as impact for a 10-8, like a rock (D120), and the lock itself scores 4 points with the
judges (`Judging.SUB_LOCK_POINTS`).

### 25.3 The calls
| Call | Key | Who | What it does |
|---|---|---|---|
| *Finish it!* | 1 (Pressure! standing, Ground and pound! on top) | The attacker's corner | +15% to win each beat for 5 s; each beat costs the attacker 2 more stamina |
| *Defend the sub!* | 6 (Defend the shot! standing) | The defender's corner | −15% to the attacker's chance each beat for 5 s; each beat costs the defender 2 more stamina |
| *Go for the finish!* (D200, §25.7) | 2 (Circle out! standing) | The top fighter's corner, before there's a hold | For 10 s he hunts a hold: one he knows from where he is, or the position that has one |

Both are focus calls in `data/calls/` (`focus.struggle`, `focus.struggle_stamina`, `09` call@2) and only work in the submission
position, from their own side. They come through the normal pipeline (voice 15, delay, compliance, §22), so a call made the
moment the hold locks is acted on about a second in, from the second beat. The AI corner and the harness's coaching bots
call them when a hold locks (`Corner`). The two calls cancel each other out.

### 25.4 The fighter AI
| Where | What the fighter does | To change it |
|---|---|---|
| Bottom of full guard | Only on the opening its hold looks for (the top fighter postured up for the armbar, his posture broken for the triangle), never rocked, and not again for 45 s after a try. Then a hold is weighted 0.1 × how much they like subs (Submissions / 50 × (1 + Risk / 200)) × the odds against the plain odds, squared, next to getting up and tying up | `FighterAI.SUB_WEIGHT`, `SUB_RETRY_TICKS`, `sub_liking()` |
| Standing or in the clinch | One look per shot stuck under their sprawl: a guillotine on a chance of 0.35 × the same liking × (the odds / 50%)², and not within 45 s of their last try | `GUILLOTINE_CHANCE` |
| In a hold | Nothing to decide: the beats play out on the stats and the calls | `FightSim.STRUGGLE_*` |

The fighters (all were 50): the Kicker has Submissions 65 and knows the triangle and the armbar (long legs); the Wrestler has
Submissions 45 and Submission defense 65; the Boxer Submissions 35 and Submission defense 40. Guard stays 50 for everyone,
since it also defends ground punches and ties up (§24.3).

### 25.5 Balance
CI's balance snapshot on PR #56 (40 fights a pairing, seed 1, pro rules; small samples, so read them as rough):

| Pairing | Subs tried / locked a fight | Ended by submission | Finishes | Wins |
|---|---|---|---|---|
| Kicker vs Boxer | 0 / 0 | 0% | 35% | Boxer 57.5% (unchanged: its golden fight plays out exactly as before) |
| Wrestler vs Kicker | Kicker 5.4 / 1.6 | 5.0% | 30% | Wrestler 67.5%, draw 2.5% |
| Wrestler vs Boxer | Boxer 0.8 / 0.2 | 0% | 60% | Wrestler 52.5% |

Across all 160 fights: draws 0.6%, 10-10 cards 0%, 31.3% finished inside the distance (D121 target about 30%).
Submissions end 5% of Wrestler vs Kicker fights, the bottom of the 5–10% aim. The Kicker locks a hold most fights but
the Wrestler (Submission defense 65, Top control 60) usually fights out of it: only about one lock in thirty taps. To make
holds more dangerous, raise `start_danger` in the holds' files or `FightSim.STRUGGLE_BASE` (the attacker's share of
each beat before stats, §25.6), then re-pin the golden fights (§2.2).

### 25.6 To change it, and the tests
- The holds: `data/actions/guillotine.json`, `triangle.json`, `armbar.json` (`submission.base_success`, `partial_within`,
  `start_danger`, `escape_to`, `09` action@2); where they lock and where a missed guillotine goes: the transitions in
  `data/positions/standing.json`, `clinch.json`, `full_guard.json` (`result` `failed`); the hold itself:
  `data/positions/submission.json`.
- The struggle: `FightSim.STRUGGLE_BEAT_TICKS` (10), `STRUGGLE_BASE` (0.5), `STRUGGLE_STEP` (20), `STRUGGLE_BEATS` (5),
  `SUB_TAP` (100), `START_DANGER_PER_EDGE` (0.5), `START_DANGER_MIN`/`MAX` (10/90), `STRUGGLE_STAMINA` (2), `NEAR_FINISH` (80).
- The calls: `data/calls/finish_it.json`, `defend_the_sub.json`. Judges: `Judging.SUB_LOCK_POINTS` (4).
- The AI: `FighterAI.SUB_WEIGHT` (0.1), `SUB_RETRY_TICKS` (450), `GUILLOTINE_CHANCE` (0.35). The fighters' Submissions and
  Submission defense: `data/fighters/`.
- The screen: the danger meter in `ui/fight_hud.gd`, the feed lines in `ui/fight_log_formatter.gd`.

Tested in `tests/sim/fight/test_submissions.gd` (locking in from every position, the starting danger, the judges' points, no
moves during a hold, the guillotine's opening and what a miss costs, taps and escapes, the last beat, near-finish impact, the
bell, both calls, the corner's calls, the AI's openings and its wait between tries), `tests/ui/test_fight_hud.gd` (the danger
meter), `tests/ui/test_fight_log_formatter.gd` (the feed lines and "wins by submission"), `tests/sim/balance/` (submissions
count as finishes) and `tests/data/test_data_files.gd` (the `submission` block, `failed` transitions, the new roles and focus
keys). After changing a number, run the harness with all six cross-style pairings and read the **How** (submission share) and
**Subs** (tried and locked a fight) lines.

### 25.7 *Go for the finish!* (D200)
Kyle asked for it (2026-10-30: "wrestler needs a go for the finish call to go for a submission on the ground") and picked the
10 s hunt, for anyone on top. *Finish it!* only pushes a hold that's already locked; nothing told a fighter to go for one, and
on his own the Wrestler looks for a better position or a hold about every 20 s, and from the top of full guard (where he spends
most of his time on the ground) he knows no hold at all.

| | |
|---|---|
| Key, voice | **2** on top of full guard, half guard, side control, mount or the back (key 2 is *Circle out!* standing); voice 20; a focus call through the normal pipeline (delay, compliance, §22) |
| What he does for 10 s | Works for the finish instead of the ground and pound: on a chance of 0.5 a free tick (`focus.hunt.rate`, against about 0.006 on his own), **a hold he knows from where he is**, over anything else, without waiting for its opening and however recently he tried one (on his own, 45 s, §25.4). The Wrestler: the arm-triangle from side control and mount, the rear-naked choke from the back. **With none from here he works to a position that has one**: the guard pass from full guard and half guard, the mount or the back. An escape underneath (`ESCAPING`) that the hold's opening is for is taken every time |
| When it's over | **One hold a call**: once he has tried a hold (locked or not), he's back to his own pace; or after 10 s. If it locks, *Finish it!* (key 1) still pushes the struggle: it's a second call, so the player picks when to push |
| Who | Anyone on top. Everyone knows the rear-naked choke, so anyone can take the call: the more holds a fighter knows on top, the sooner he gets to one (the Wrestler, BJJ and Judoka know the arm-triangle; BJJ and the Judoka the armbar from mount; the Sambo fighter the kneebar from half guard) |
| The AI corner | Doesn't call it, so fights without the player's calls are as before (the golden fights are unchanged) |

**What it does to fights** (a scratch bot in red's corner, 100 fights a pairing, seeds 1–100, pro rules, no other corners; the
bot calls it once each time the Wrestler gets on top, about 10 calls a fight, or every time the last one is over and it has 50
voice, about 25–30):

| Wrestler against | No calls: wins · by submission | Once each time on top | Every time it can |
|---|---|---|---|
| Boxer | 64% · 15% | 60% · 31% | 46% · 33% |
| Kicker | 51% · 11% | 80% · 24% | 64% · 32% |

The call doubles the Wrestler's submissions, but whether it wins him fights depends on who's underneath. Against the Kicker it's
worth about +25%: he gives up holds. Against the Boxer, the ground and pound finishes him anyway, and a missed hold costs the
position (the arm-triangle's escape is to the back, §28.2), so the call loses a few percent, and spamming it costs a lot. Pick
the call for the man underneath. A gentler hunt (a rate of 0.2 or 0.08 a tick) changed these by no more than the noise of 100
fights: what the call is worth comes from the hold it buys, not how fast he goes for it.

**To change it:** `data/calls/go_for_the_finish.json` (the key, voice, `focus.duration_ms`, `focus.hunt.rate`, `09` call@2);
what a hunt does: `FighterAI._work_position()` and `_punish_escape()` (`_hunting()`); the hook: `DecisionSource.hunt()`,
`LiveCalls.hunt()`. Tested in `tests/sim/fight/test_go_for_the_finish.gd` (the key and positions, a hold within a couple of
seconds from side control, mount and the back, passing first from the guard, the call overriding his own wait, one hold a call,
the 10 s, nothing from underneath, the AI corner never calling it), `tests/sim/fight/test_live_calls.gd` (the catalogue) and
`tests/data/test_data_files.gd` (the `hunt` block).

## 26. Throws and the guard game (D128)
Kyle asked for throws so judo and BJJ fighters become possible (2026-10-28, after the fight-styles overview flagged "no
throws, no subs" as the biggest gap; subs came in D126). This adds three throws and two guard moves that use the positions the
game already has (D98's trim stays: no side control, mount or back yet), and two fighters built on them. A clean throw lands
in full guard like any takedown; side control, where a big throw would really land, is a later decision. (Decided in D130,
§28: the hip throw now lands in side control.) Every number is a
first guess for the harness; each is a named constant or a data field, listed in §26.5.

### 26.1 The moves
| Move | Who, from where | Timing (telegraph · wind-up · active · recovery) | Odds (base + attack − defense stats) | What it does |
|---|---|---|---|---|
| Outside trip (a technique: Judoka, BJJ) | Clinch | 0.1 · 0.2 · 0.3 · 0.4 s | 40% + (Takedowns, Clinch control) − (Takedown defense, Clinch control). +15% on someone pinned on the fence, +10% on someone `LEANING` | Full guard, the tripper on top; within 10% past the odds it half works: a scramble |
| Hip throw (a technique: Judoka) | Clinch | 0.2 · 0.3 · 0.3 · 0.5 s | 35% + (Takedowns, Strength) − (Takedown defense, Clinch control). −10% on someone pinned (no room to turn him over), +15% on someone `LEANING` | Full guard, the thrower on top, and he lands hard: 8 × (0.5 + Strength / 100) body damage, scored as a body shot. A miss leaves the thrower turned the wrong way, `LEANING` through his recovery, so a trip or a shot gets in easier |
| Foot sweep (a technique: Judoka) | Standing, in the pocket | 0 · 0.1 · 0.2 · 0.3 s | 15% + (Takedowns, Speed) − (Takedown defense, Footwork), +25% for `LEANING` (required: only on someone overcommitted, a hook from its wind-up to the end of its recovery) | Full guard, the sweeper on top; within 10%: a scramble |
| Guard pull (a technique: BJJ) | Clinch | 0 · 0.2 · 0.2 · 0.3 s | 60% + (Guard, Clinch control) − (Clinch control, Strength) | Full guard with the puller on the **bottom**, where their holds are. The judges score nothing for it, either side |
| Sweep (a technique: BJJ) | Bottom of full guard | 0 · 0.3 · 0.3 · 0.4 s | 25% + (Guard, Scrambles) − Top control, +15% on someone `POSTURED_UP` (throwing a ground strike) | The sweeper ends up on top: scored like a takedown. Within 10%: a scramble. A miss leaves him underneath, with a long recovery to punch into |

All three throws are `takedown` moves (they count as takedowns in the harness and with the judges, and amateur rules that ban
takedowns ban them) marked `throw`: **a sprawl does nothing to a throw**, there's no shot to sprawl on, and the AI doesn't
try. They resolve like any grapple otherwise (§21.2): contact at the start of the active phase (the range, the opening the
foot sweep needs, odds fixed then), the roll as it ends. The hip throw's landing damage is a slam: none under amateur rules,
which ban slams (`08`). The *Takedown!* call now lists the throws after the double leg and the catch, so a coach can call a
throw in the clinch for a fighter who knows one; there's no *Pull guard!* or *Sweep!* call yet.

### 26.2 The fighter AI
| Where | What the fighter does | To change it |
|---|---|---|
| In the clinch | Throws are picked like the double leg (§21.5): tendency × Base. The trip's fence bonus and the hip throw's fence penalty sway the pick, so a Judoka trips on the fence and hip-throws in open space. A guard pull is weighted 0.5 × how much they like submissions (§25.4) | `FighterAI.GUARD_PULL_WEIGHT`; tendencies in `data/fighters/` |
| Standing | A foot sweep only on a hook it reads coming (`ai_takes` on its opening): unlike the catch-kick (D103), the AI takes this one on its own. A Boxer who gets swept throws hooks ×0.7 as often afterwards (§21.8 "kicks less after being caught") | `ai_takes` in `data/actions/foot_sweep.json` |
| A throw coming | No sprawl; read like any other move (a counter, or stepping off) | |
| Bottom of full guard | The sweep sits next to getting up, tying up and the holds (§24.3, §25.4); the BJJ fighter's tendencies lean on it (sweep 1.5, get up 0.4) | `data/fighters/bjj.json` |

### 26.3 The fighters
Two new test fighters in `data/fighters/`, on the setup screen as Judoka vs Boxer, Judoka vs Wrestler, BJJ vs Wrestler and
BJJ vs Kicker:

| Fighter | Stats | Style (pace · range · base · risk) | Moves |
|---|---|---|---|
| **Judoka** | Takedowns 70, Clinch control 75, Strength and Cardio 65, Takedown defense 60, Chin 60; Boxing 50 | 10 · 50 · 70 · 10 | Jab, cross, knee, outside trip, hip throw, foot sweep. No double leg: he has to get to the clinch, so his clinch entry tendency is 2.0 |
| **BJJ** | Guard 75, Submission defense 70, Submissions 65, Scrambles, Top control and Chin 60; Takedowns and Takedown defense 45, Boxing 45 | 0 · 30 · 60 · 20 | Jab, cross, outside trip, guard pull, sweep, triangle, armbar (and the guillotine everyone has). Clinch entry 2.0, guard pull 2.0, trip 0.5, get up 0.4 |

### 26.4 Balance
Reported, no pass marks, like the Wrestler (D109): the harness prints a "Judoka vs …" and "BJJ fighter vs …" line against the
Kicker, the Boxer and the Wrestler, and a **Throws** line (tried and landed a fight) for every pairing. CI's balance snapshot
runs all six. The striker pairings and the Wrestler's don't change: nobody who fought before knows a new move, a sprawl only
skips throws, and the judges' one change (no points for landing on top of a guard pull) touches only the guard pull. The four
golden fights (§2.2) play out exactly as before.

Harness, no calls, 100 fights a pairing (50 each way round, seed 1, pro rules):

| Pairing | Wins | How it ends | Grappling a fight |
|---|---|---|---|
| Judoka vs Kicker | Judoka 26% | 87% decisions | Judoka throws 4 of 7; clinch 2% of the fight |
| Judoka vs Boxer | Judoka 69% | 31% TKO (mostly the Judoka on top), the rest decisions | Judoka throws 21 of 30; on top 36% of the fight |
| Judoka vs Wrestler | Judoka 52% | Subs 15% (the Judoka's guillotines on the Wrestler's shots) | Judoka throws 14 of 26, Wrestler shoots 45 and lands 12 |
| BJJ vs Kicker | BJJ 5% | 88% decisions | BJJ in the clinch under 1% of the fight |
| BJJ vs Boxer | BJJ 23% | Subs 22%, TKO 59% | BJJ trips 4 of 8 and pulls guard; on the ground 37% |
| BJJ vs Wrestler | BJJ 73% | Subs 38% | Wrestler lands 13 takedowns of 30, the BJJ fighter locks 2 holds a fight |

Across all 600 fights: draws 0%, no 10-10 cards. What it says: the throwers' way in is the clinch, and **the Kicker keeps
both of them out** (the clinch is 1–2% of those fights; the Wrestler gets in with the double leg from mid range, the throwers
only from the pocket). The Judoka beats the Boxer, who stands in the pocket, and is even with the Wrestler. The BJJ fighter
loses on the feet to both strikers and beats the Wrestler, who keeps taking him down into his guard. First tuning was only
the two fighters' own data (their striking, Submissions and tendencies); the first draft had both near 5% against strikers
and the BJJ fighter at 90% against the Wrestler with Submissions 75. Next steps if the playtest wants them closer: a way into
the clinch from mid range (a body-lock entry, or the Judoka's foot sweep on kicks), or a lower BJJ guard. To read it again,
run the harness with the pairings above and read the **Throws** and **Subs** lines.

### 26.5 To change it, and the tests
- The moves: `data/actions/outside_trip.json`, `hip_throw.json`, `foot_sweep.json`, `guard_pull.json`, `sweep.json` (`09`
  action@2: `takedown.throw`, `takedown.landing_damage`, an opportunity's `ai_takes`); where they take the fight: the
  transitions in `data/positions/standing.json`, `clinch.json`, `full_guard.json`.
- The slam: `FightSim.landing_damage()` (the 0.5 + Strength / 100 scale; amateur rules through `slams`).
- No points for a guard pull: `FightSim.apply_transition()` (the opponent scores ending up on top only when the actor's move failed into it).
- The AI: `FighterAI.GUARD_PULL_WEIGHT` (0.5), `_takes_opening()`. The fighters: `data/fighters/judoka.json`, `bjj.json`.
- The call: `data/calls/takedown.json`.

Tested in `tests/sim/fight/test_throws.gd` (each throw lands on top, a trip counts as a takedown, a sprawl does nothing, the
fence for and against, the slam and amateur rules, a failed hip throw leaning, the foot sweep's opening, the guard pull scoring
nothing, the sweep, the AI not sprawling, taking the foot sweep, the Judoka throwing and the BJJ fighter pulling guard and
sweeping, the *Takedown!* call, and both fighters in real fights), `tests/sim/balance/test_balance_report.gd` (the report
lines), `tests/ui/test_fight_log_formatter.gd` ("slammed down") and `tests/data/test_data_files.gd` (the new fields).

## 27. Clinch knees and the collar tie (D129)
Kyle asked for clinch knees and collar ties for Muay Thai (2026-10-28). The clinch stays one position (D98's trim): the collar
tie is a grip *inside* it, not a new position, so it uses the posture-broken timer the tie-up from the bottom already has
(D121, §24.3). A Muay Thai test fighter comes with it. It's the first of the *Clinch* call's unlocks in §6.4 ("Collar tie, Thai
plum knees"). Every number is a first guess for the harness; each is a named constant or a data field, listed in §27.5.

### 27.1 The move and what it does
| Move | Who, from where | Timing (telegraph · wind-up · active · recovery) | Odds (base + attack − defense stats) | What it does |
|---|---|---|---|---|
| Collar tie (a technique: the Muay Thai fighter) | Clinch | 0 · 0.2 · 0.2 · 0.2 s | 45% + (Clinch control, Strength) − (Clinch control, Strength). +10% on someone with their hands low; −15% with your own head tied | The opponent's posture is broken (`POSTURE_BROKEN`) for **4 s**: his head is pulled down. The fight stays in the clinch. A knee he was throwing is smothered |

While the tie is on:

| | What changes | Where it lives |
|---|---|---|
| **Knees from the tie** | The holder's knee is +15%, goes **to the head** and does **×1.2** damage, so a few in a row can rock him. Where knees to the head are banned (teen amateur rules, `08`) it stays on the body | the `POSTURE_BROKEN` opportunity in `data/actions/knee.json` |
| **Getting out is harder** | The one tied up breaks the clinch at −10% and knees back at −15% | the `own_flag` `POSTURE_BROKEN` opportunities in `clinch_break.json` and `knee.json` |
| **Winning the tie back** | A collar tie of his own (at −15%) frees his head and ties up the other one's; it's the only way out other than the break or waiting out the 4 s | `FightSim._tie_up()`; `collar_tie.json` |
| **The clinch ends** | Any change of position (a break, a takedown, a knockdown) takes the tie off | `FightSim.apply_transition()`, `_break_apart()` |

The judges score nothing for the tie itself; the knees score as strikes (a head knee counts more than a body one, §11), and
cage control still counts as before. In the 3D view the fighter whose head is tied bends over and the holder's hands go up
behind his head. The log says *"Muay Thai gets the COLLAR TIE: his head is pulled down for the knees"*.

### 27.2 The call
A new *Collar tie!* call (voice 15) on **key 5**, which it shares with *Clinch!*: Clinch! standing, Collar tie! in the clinch (as
Pressure! and Ground and pound! share key 1). It only lights up for a fighter who knows the collar tie, so the playtest fights
(the Wrestler, D112) don't change: none of them has it. The AI corner and the coaching bots don't call it yet; the random caller
(the spam bot) can, so its harness numbers shift a little.

### 27.3 The fighter AI
| Where | What the fighter does | To change it |
|---|---|---|
| In the clinch, holding the tie | Works twice as often while it's on, so the knees come in a burst; the knee's +15% sways the pick toward knees (the usual opening weighting, §20). Never ties up a head that's already tied | `FighterAI.COLLAR_RATE` (2.0) |
| In the clinch, head tied | Also works twice as often, and weights the break and a collar tie of his own ×3: he wants out. His knees are weighted down by their −15% | `FighterAI.COLLARED_ESCAPE` (3.0) |
| In the clinch, free | The collar tie is picked like any clinch move, by its tendency and odds | `collar_tie` in a fighter's `tendencies` |

### 27.4 The Muay Thai fighter and balance
A new test fighter in `data/fighters/muay_thai.json`, on the setup screen as Muay Thai vs Boxer, vs Wrestler and vs Kicker:

| Fighter | Stats | Style (pace · range · base · risk) | Moves |
|---|---|---|---|
| **Muay Thai** | Clinch striking 75, Clinch control 70, Strength and Chin 60; Power, Striking defense, Cardio and Takedown defense 55; Kicking, Boxing and Footwork 50 | 10 · 20 · 30 · 10 | Jab, cross, teep, leg kick, body kick, knee, collar tie. He wants the clinch: clinch entry 2.5, knee 1.5, collar tie 1.5, and his kicks sit low (teep 0.5, leg and body kick 0.6) |

Reported with no pass mark, like the Wrestler and the throwers (D109, D128): the harness prints "Muay Thai fighter vs …" against
the Kicker, the Boxer and the Wrestler, and a **Clinch** line for every pairing (collar ties tried and won, knees landed in the
clinch and how many of those came from the tie). CI's balance snapshot runs all three. Nobody who fought before knows the collar
tie, and nothing else changes for them (a broken posture never came up in the clinch until now), so every other pairing and the
four golden fights (§2.2) play out exactly as before; only the random caller's numbers move (the new call is in its pool).

Harness, no calls, 100 fights each way round (seed 1, pro rules):

| Pairing | Wins | How it ends | Clinch and grappling a fight |
|---|---|---|---|
| Muay Thai vs Kicker | Muay Thai 79% | 81% decisions | Clinch 3% of the fight; 3.4 collar ties won of 4.4, 6 knees landed (4 from the tie) |
| Muay Thai vs Boxer | Muay Thai 56.5% | 76% TKO, 16% KO | Clinch 27% of the fight; 13.6 collar ties won of 21, 26 knees landed (16 from the tie) |
| Muay Thai vs Wrestler | Muay Thai 56.5% | 38% KO (knees into the Wrestler's shots, §21.2), 7.5% subs (guillotines), draws 2.5% | The Wrestler lands 15 takedowns of 43 and is on top 41% of the fight; 3.2 collar ties won of 6.7 |

Across all 600 fights: draws 0.8%, no 10-10 cards.

What it says: **against the Boxer the clinch is the Muay Thai fighter's fight** (about a quarter of the fight in the clinch,
some 13 collar ties a fight and 25 knees, more than half of them from the tie), and it's about even. The Wrestler is about
even too: he spends 40% of the fight on top, but his shots walk into the Muay Thai fighter's knees (most of those fights
that finish are knockouts) and the odd guillotine. **The Kicker loses most of his fights to him**, and not in the clinch (the Kicker keeps it to 3% of the fight):
a fighter who also kicks takes away the Kicker's range, which is how he beats the Boxer. With no kicks at all the Muay Thai
fighter wins 35% of those; first tuning stopped with his kicks thrown about half as often. If the playtest wants it closer, the
levers are his kick tendencies and his Kicking, then `COLLAR_RATE`. To read it again, run the harness with
`--pairs=muay_thai:kicker,kicker:muay_thai,muay_thai:boxer,boxer:muay_thai,muay_thai:wrestler,wrestler:muay_thai` and read
the **Clinch** lines.

### 27.5 To change it, and the tests
- The tie: `data/actions/collar_tie.json` (`clinch.ties_up_ms` is how long the head stays tied, 4000; `09` action@2).
- Knees from the tie and getting out: the `POSTURE_BROKEN` opportunities in `data/actions/knee.json` and `clinch_break.json`.
- Winning the tie back: `FightSim._tie_up()`. The call: `data/calls/collar_tie.json`.
- The AI: `FighterAI.COLLAR_RATE` (2.0), `COLLARED_ESCAPE` (3.0). The fighter: `data/fighters/muay_thai.json`.
- The harness: `BalanceReport.CLINCH_FIGHTERS`, the `collar_ties_*`, `clinch_knees_*` and `tied_knees_*` columns in `FightSummary`.

Tested in `tests/sim/fight/test_collar_tie.gd` (the tie breaks his posture for 4 s and stays in the clinch, knees from it go
to the head harder, teen rules keep them on the body, breaking, kneeing back and tying back are harder, winning a tie of your
own frees your head, the tie comes off with the clinch, the AI knees from the tie and never ties twice, the AI wants out when
tied, the call only in the clinch and only for a fighter who knows it, the Muay Thai fighter in real fights, and nobody else
knowing it), `tests/sim/balance/test_balance_report.gd` (the report lines), `tests/ui/test_fight_log_formatter.gd` ("COLLAR
TIE"), `tests/game/test_arena_view.gd` (the pose), `tests/sim/fight/test_live_calls.gd` (the call catalogue) and
`tests/data/test_data_files.gd` (`ties_up_ms` on a clinch move).

## 28. Ground positions: half guard, side control, mount and the back (D130)
Kyle asked for more positions on the ground (2026-10-28: "I feel like that opens up the most for wrestling BJJ and judo and
sambo"). Until now the ground was full guard and a scramble (D98's trim). This adds four positions from §4's diagram, the moves
between them, and what each one allows: who can strike and how hard, which holds work there, and what the judges score. It's
the first of three scopes put to Kyle (four positions with passes and escapes; the others were half guard and side control
only, or this plus leg locks and a Sambo fighter, which build on it). North-south, turtle and butterfly guard stay on the list in §4. Every number is a first guess for the harness; each
is a named constant or a data field, listed in §28.7.

### 28.1 The positions
All four have the roles `top` and `bottom`, like full guard, so ground and pound, the referee's count underneath, the judges'
takedown points and the 3D view's lying down all carry over. On the back, `top` is the fighter who has the back.

| Position | Each second (stamina drain · judges' control score · strike damage ×), top / bottom | Ways out (the transitions in its file) |
|---|---|---|
| Full guard (as before) | 0.2 / 0.3 · 1.0 / 0.2 · 0.8 / 0.4 | New: the top fighter's **guard pass** → side control; half working → half guard |
| **Half guard** | 0.2 / 0.3 · 1.2 / 0.1 · 0.9 / 0.4 | Top: guard pass → side control. Bottom: **recover guard** → full guard; get up → standing (half: a scramble); sweep → half guard with the roles swapped (half: a scramble) |
| **Side control** | 0.2 / 0.4 · 1.5 / 0 · 1.0 / 0.4 | Top: **take the mount** → mount; **take the back** → back; the **arm-triangle**. Bottom: recover guard → full guard (half working: half guard). No getting straight up |
| **Mount** | 0.2 / 0.5 · 2.0 / 0 · **1.3** / 0.4 | Top: take the back; the **armbar**; the arm-triangle. Bottom: **bridge and roll** → full guard with the bridger on top (a reversal); half working → half guard underneath |
| **Back control** | 0.3 / 0.5 · 2.0 / 0 · 0.7 / 0 | Top: the **rear-naked choke**. Bottom: **escape the back** → full guard with the escaper on top (turning into his guard); half working → a scramble |
| **Crucifix** (D264, §40.12) | 0.2 / 0.5 · 1.75 / 0 · 1.2 / 0 | Top: take the back. Bottom: **free the arm** → side control; half working → a scramble. In from the top of side control (*take the crucifix*) |
| Scramble (as before) | 0.8 each · 0 · 0 | New: take the back (a technique) → back control |

Where the fight lands from the feet: the double leg, the catch, the outside trip, the foot sweep and winning a scramble still
land in full guard. **The hip throw lands in side control** (§26 said side control was where a big throw really lands): the
thrower is past the guard as he lands.

### 28.2 The moves
| Move | Who, from where | Timing (telegraph · wind-up · active · recovery) | Odds (base + attack − defense stats) | Notes |
|---|---|---|---|---|
| Guard pass (*everyone*) | Top of full guard or half guard | 0.2 · 0.3 · 0.4 · 0.3 s | 15% + (Top control, Strength) − Guard, +10% on `HANDS_LOW`, −10% while his own posture is broken (tied up) | From full guard, within 15% past the odds it half works: half guard |
| Take the mount (*everyone*) | Top of side control | 0.1 · 0.3 · 0.3 · 0.3 s | 30% + (Top control, Scrambles) − (Guard, Scrambles), +10% on `HANDS_LOW` | |
| Take the back (a technique: Wrestler, BJJ, Judoka) | Top of side control or mount, or a scramble | 0 · 0.2 · 0.3 · 0.3 s | 10% + (Scrambles, Top control) − Scrambles, **+15% on someone `ESCAPING`** | Turning away to get out shows the back |
| Recover guard (*everyone*) | Bottom of side control or half guard | 0.2 · 0.3 · 0.4 · 0.3 s | 30% + (Guard, Scrambles) − Top control, +15% on `POSTURED_UP` | `ESCAPING` from wind-up to the end of active. From side control, within 15%: half guard |
| Bridge and roll (*everyone*) | Bottom of mount | 0.2 · 0.3 · 0.3 · 0.3 s | 15% + (Strength, Scrambles) − Top control, +15% on `POSTURED_UP` | `ESCAPING`. Works: a reversal, scored like a takedown. Within 20%: half guard |
| Escape the back (*everyone*) | Bottom of back control | 0.2 · 0.3 · 0.4 · 0.3 s | 25% + (Scrambles, Strength) − Top control, +10% on `POSTURED_UP` | `ESCAPING`. Works: on top in his guard, scored like a takedown. Within 15%: a scramble |
| Rear-naked choke (*everyone*, like the guillotine) | Top of back control | 0 · 0.3 · 0.4 · 0.5 s | 15% + (Submissions, Strength) − (Submission defense, Scrambles), +15% on `HANDS_LOW` | A hold (§25): danger starts at 25. Getting out: back to back control |
| Arm-triangle choke (a technique: Wrestler, BJJ, Judoka) | Top of side control or mount | 0 · 0.3 · 0.4 · 0.5 s | 10% + (Submissions, Top control) − (Submission defense, Guard), +15% on `ESCAPING` | A hold: danger starts at 25. Getting out: back where it was locked |
| Armbar (now also from mount; the Kicker, BJJ and the Judoka know it) | Bottom of full guard (as §25), or top of mount | as §25 | as §25, plus +20% on someone `ESCAPING` (an arm out as he pushes) | From mount, within 15%: a scramble |
| Ground punch, ground elbow | Top of every ground position (no elbows from the back) | as §24.3 | as §24.3 | Damage × the position's multiplier: hardest from mount, softest from the back |
| Tie up | Bottom of full guard, half guard and mount | as §24.3 | as §24.3 | Not from under side control or the back: there the answer is to get out |
| Sweep | Bottom of full guard or half guard | as §26 | as §26 | From half guard he ends on top in half guard |

**One move, different roles in different positions.** A move that moves the fight (a takedown, clinch move, ground move or
hold) is only possible where its position file says where it goes for that role (`PositionLibrary.leads_somewhere()`), so the
armbar works from the bottom of full guard and the top of mount but not from the top of full guard. Strikes, defenses and
tie-ups don't move the fight, so this changes nothing for them, and nothing that was possible before stops being possible.

### 28.3 The judges
- **A better position scores**: 6 points per point of control score gained on top (`Judging.ADVANCE_POINTS_PER_CONTROL`), so
  full guard to side control is 3, side control to mount 3, full guard to half guard 1.2, and mount to the back nothing (both
  are 2.0). A takedown is still 6 (getting from no control to full guard's 1.0).
- Every second there scores 0.15 × the control score, as before (§21.4): 20 s in mount is 6 points.
- Getting out from underneath scores nothing on its own; a reversal (the bridge, escaping the back into his guard) scores like a
  takedown, as the sweep does (§26).

### 28.4 The fighter AI
| Where | What the fighter does | To change it |
|---|---|---|
| On top, every position | Before the ground and pound (§24.3), a chance of 0.3 × work rate × (0.5 + Base / 100, at least 0.1) a tick to work for something better: a pass, the mount, the back or a hold, picked by weight like the moves underneath (a hold only on its opening, as §25.4, except the rear-naked choke, which needs none: being on the back is the opening). The Wrestler goes for it about every 20 s. Tied up, he can still pass, at −10% | `FighterAI.ADVANCE_RATE` (0.3), `ADVANCE_MIN_LIKING` (0.1); the hold's `ai_without_opening` |
| On top, the fighter underneath starts to escape | One look per escape for what it gives away: the back, the armbar from mount, the arm-triangle. Taken on a chance of 0.2 × (the odds / 50%)², a hold also × 0.5 × how much they like subs (§25.4), and only if it would land while he's still `ESCAPING` | `ESCAPE_PUNISH` (0.2), `ESCAPE_SUB` (0.5) |
| Underneath | As in full guard (§21.5, §24.3): about every 3.3 s, 3 × as often under fire, picking from what works there: recovering guard, the bridge, escaping the back, tying up, getting up from half guard, the sweep and the holds | `GROUND_RATE`, `GROUND_UNDER_FIRE` |
| The corner | Calls *Ground and pound!* when its fighter lands on top, once: not again after every pass | `Corner.on_event()` |

### 28.5 The calls
- **Pass!** (new, key 4, voice 20, an attempt): from the top of full guard, half guard, side control or mount the fighter
  goes for the next position up (the guard pass, the mount, then the back for a fighter who knows it). It shares key 4 with
  *Takedown!*, which is only standing and in the clinch (`data/calls/pass.json`). The AI corner doesn't call it yet.
- *Get up!* (key 7) now works from under every position and calls the way out from there: up from full guard or half guard,
  back to guard from side control, the bridge from mount, turning out of the back.
- *Ground and pound!* and *Survive!* work in every ground position.
- *Go for the finish!* (D200, key 2, §25.7) sends the top fighter after a hold for 10 s, passing to get to one.

### 28.6 On screen and in the harness
- The tag under the fighters names the position and who's on top, "Back control · Wrestler has the back" (a position's
  `top_label`); the feed says the same, and "Wrestler's Guard pass half works: half guard".
- In the 3D view the top fighter sits up in mount, lies flat across in side control, and sits behind on the back with the one
  underneath sat up in front.
- The harness's **Positions** line: the share of the fight in each ground position, how many better positions each fighter got
  to on top, and how many times each got out from underneath (CSV columns `full_guard` … `back_control`, `advances_*`, `escapes_*`).

### 28.7 Balance
Reported, no pass marks, like the Wrestler and the throwers (D109, D128). Harness, no calls, 100 fights each way round (seed 1,
pro rules), this change against main just before it:

| Pairing | Wins before → now | Ended by submission before → now | Ground now: full guard · half guard · side control · mount · back (share of the fight) |
|---|---|---|---|
| Kicker vs Boxer | Kicker 44.5% → 44.5% (event for event the same) | 0% → 0% | – |
| Wrestler vs Kicker | Wrestler 67.5% → 76% | 4% → 14% | 29% · 6% · 5% · 1% · 3% |
| Wrestler vs Boxer | Wrestler 57% → 72.5% | 0% → 14.5% | 39% · 8% · 6% · 1% · 4% |
| Judoka vs Kicker | Judoka 25% → 28% | 4% → 5% | 8% · 3% · 3% · 1% · 1% |
| Judoka vs Boxer | Judoka 72% → 78% | 0% → 10% | 32% · 4% · 5% · 0% · 2% |
| Judoka vs Wrestler | Judoka 52% → 71% | 9% → 18% | 40% · 5% · 6% · 1% · 2% |
| BJJ vs Kicker | BJJ 4% → 11% | 6% → 6% | 7% · 1% · 1% · 0% · 1% |
| BJJ vs Boxer | BJJ 27% → 35% | 26% → 30% | 31% · 3% · 2% · 1% · 2% |
| BJJ vs Wrestler | BJJ 63% → 76% | 28% → 34% | 56% · 6% · 3% · 1% · 3% |
| Muay Thai vs Wrestler | Muay Thai 56.5% → 51.5% | 7.5% → 8.5% | 37% · 6% · 4% · 1% · 2% |

Across all 1,400 fights: draws 0.8% (was 0.8%), no 10-10 cards, 42% finished inside the distance (was 36.5%).

What it says: **the grapplers got better on the ground, and the fighters who know the new moves most of all.** Full guard is
still where most ground time is spent (passing is 15% + stats a try, and the one underneath gets back to guard about as
often), but a few times a fight the top fighter gets past it, and from side control, mount and the back the Wrestler and the
Judoka now finish fights: the rear-naked choke and the arm-triangle end 10–18% of their fights against strikers, where only the
Kicker's triangles did before. The Judoka gains most against the Wrestler (his arm-triangle and armbar, and the Wrestler gives
his back getting out). Striker fights don't change at all: nobody there goes to the ground.

The first draft was much stronger: the chokes from the back and the arm-triangle ended 40–65% of grappler-vs-striker fights,
because a striker who has spent the fight underneath is tired, and tired fighters lose the struggle's beats (§25.2). Tuning
since: lower lock-in odds and starting danger for both chokes, a harder back take, the AI taking an escape's opening less often,
cheaper positions underneath, a harder pass, and side control's escape going straight back to full guard. If the playtest
finds grapplers too strong on the ground, the levers in order: `guard_pass.json`'s `base_success`, `FighterAI.ADVANCE_RATE`,
the holds' `start_danger`, then `ESCAPE_PUNISH`. To read it again, run the harness with the grapplers' pairings and read the
**Positions**, **Subs** and **How** lines.

### 28.8 To change it, and the tests
- The positions: `data/positions/half_guard.json`, `side_control.json`, `mount.json`, `back_control.json` (stamina drain,
  control score, strike multiplier, where each move goes; `top_label`, `09`); the pass from full guard and the back take from a
  scramble: `full_guard.json`, `scramble.json`; the hip throw's landing: `clinch.json`.
- The moves: `data/actions/guard_pass.json`, `take_mount.json`, `take_back.json`, `recover_guard.json`, `bridge.json`,
  `escape_back.json`, `rear_naked_choke.json`, `arm_triangle.json` (and `armbar.json` from mount); the opening an escape gives:
  the `ESCAPING` flag (`data/enums/flags.json`) in the escapes' `flags_self` and the moves' opportunities.
- Who knows what: `techniques` in `data/fighters/` (the Wrestler, BJJ and Judoka have the back take and the arm-triangle; the
  Judoka the armbar too).
- Judges: `Judging.ADVANCE_POINTS_PER_CONTROL` (6). The AI: `FighterAI.ADVANCE_RATE`, `ADVANCE_MIN_LIKING`, `ESCAPE_PUNISH`,
  `ESCAPE_SUB`. The calls: `data/calls/pass.json`, `get_up.json`.
- The harness: the `GROUND_POSITIONS` columns in `FightSummary`, the Positions line in `BalanceReport`.

Tested in `tests/sim/fight/test_ground_positions.gd` (every new position has a way out everyone knows, control and damage go up
past the guard, the pass and half a pass, the judges' points for a better position, the armbar from mount but not the top of
full guard, getting out of each position, an escape showing the back, the rear-naked choke locking and its escape, punches from
mount, the AI passing and climbing, taking the back on an escape and choking from it, the AI's escapes underneath, *Pass!* and
*Get up!*, the corner's one Ground and pound!, the feed and the harness columns), `tests/sim/fight/test_throws.gd` (the hip
throw lands in side control), `tests/sim/fight/test_submissions.gd` (every hold locks from every position it's done from),
`tests/game/test_arena_view.gd` (the poses and the tag), `tests/sim/fight/test_live_calls.gd` (the catalogue) and
`tests/data/test_data_files.gd` (`top_label`, `ai_without_opening`). After changing a number, run the harness with the
grapplers' pairings and read the **Positions**, **Subs** and **How** lines next to the wins.

## 29. Feints and blind shots (D131)
Kyle asked for feints to fix the wrestling vs striking problem (2026-10-28: "Grapplers should be punished for not feinting or
for shooting blind takedowns"). After D130 the grapplers beat the strikers 72–78% of the time, mostly by shooting whenever
they liked. Now a shot needs setting up: a feint the opponent bites on, a strike just before it, or an opening to shoot into.
A shot with none of those is a **blind shot**, and it's punished. Kyle picked the second of three scopes (the feint and the blind-shot
penalty; **that plus a *Feint!* call for the player**; the blind-shot penalty with no feint move), 2026-10-28. Every number is a first guess for the harness; each
is a named constant or a data field, listed in §29.6.

### 29.1 The feint
| | |
|---|---|
| Who | Everyone (`basic`), standing, from mid range or the pocket (`data/actions/feint.json`, category `feint`) |
| Timing | 0.1 · 0.1 · 0.1 · 0.1 s (telegraph · wind-up · active · recovery), 1 stamina |
| The bite | One roll as its active phase starts: 40% + (Fight IQ, Speed) − Fight IQ. Feinting again within 30 s bites 10% less for each feint in that time ("feinted again" in the odds), so the same feint over and over stops working. Out of range it fools nobody (no roll) |
| Bitten | For the next second (`bites_ms` 1000) the opponent has his hands up and his weight back (`BIT_ON_FEINT`): a double leg gets **+10%** and a clinch entry +10% on him, his own sprawl is **−10%**, and he reads the next move half as well (§29.3) |
| Not bitten | Nothing happens to him, but the feint still counts as setting a shot up (§29.2): he had to watch it |

### 29.2 Blind shots
A takedown from standing is **blind** when, as it starts:
- none of the shooter's own strikes or feints ended in the last 0.5 s (`FightSim.SET_UP_TICKS`, 5 ticks), and
- there's nothing to shoot into when it arrives: no counter (timed into his wind-up or recovery), no `LEANING`, no bite. **An
  opponent on the fence doesn't count** (`FightSim.NOT_A_SET_UP`): the fence stops the sprawl going back, it doesn't hide the shot.

Never blind: the catch-kick single (it needs a kick to catch: a reaction, not a guess), throws and trips (D128), and anything
from the clinch (the clinch is the set-up). Clinch entries aren't blind shots: they were at first, but that cost the Muay Thai
fighter 17 points against the Boxer, a striker fight.

What a blind shot costs (it carries `BLIND_SHOT` from its start to its end):

| | How much | To change it |
|---|---|---|
| A worse shot | −20% on its own odds | the `own_flag: BLIND_SHOT` opportunity in `data/actions/double_leg.json` |
| Easier to read | +30% to the defender's chance to read it (§20) | `FighterAI.BLIND_READ` |
| Easier to sprawl on | +20% to the sprawl's odds | the `BLIND_SHOT` opportunity in `data/actions/sprawl.json` |
| Stuck longer | Sprawled on, 0.5 s more with the head low than a set-up shot (more time for knees and the guillotine) | `FightSim.BLIND_STUCK_TICKS` (5) |
| Costs more | 5 more stamina when it's stuffed (sprawled on or defended) | `FightSim.BLIND_STUFFED_STAMINA` |

**The double leg's base odds drop from 45% to 35%** (`data/actions/double_leg.json`): a shot that's set up by a strike or an
opening is a little worse than before, one off a feint that bit is back where it was, and a blind one is 20% worse again.
Where the shot came from: against the Kicker about a third of the Wrestler's shots are blind, a quarter come off a feint, and
most of the rest are timed into the Kicker's kicks, which is a set-up.

### 29.3 The fighter AI
| Where | What the fighter does | To change it |
|---|---|---|
| About to lead with a takedown that would be blind | Feints first on a chance of 10% + 60% × Fight IQ / 100 (40% at Fight IQ 50), then shoots off the feint as soon as it's over, if it still reaches (up to 0.3 s after). The feed reads "feints to set up the double-leg takedown", then "shoots off the feint". The rest of the time he shoots blind anyway | `FighterAI.SETUP_BASE` (0.1), `SETUP_PER_IQ` (0.6), `FEINT_FOLLOW_TICKS` (3) |
| Reading the opponent's moves | A blind shot is read +30%; while bitten on a feint, every move is read × 0.5. A feint itself isn't read: whether it bites is its own roll | `BLIND_READ` (0.3), `BIT_READ` (0.5) |
| Strikers | Until D236 they never feinted on their own: the AI only feinted before a shot, and strikers don't shoot. **Since D236** strikers feint by style: to set up their strikes or to bait the counter (§29.7) | |
| Habits | A tell that leads straight into a shot (the Wrestler's stance shift, then the double leg) isn't a set-up: that shot is blind | the fighter's `tells` |

The player's *Takedown!* call shoots straight away, as before: a called shot with nothing before it is blind too. Call it off
your fighter's jab or into a kick, or call *Feint!* instead (§29.4).

### 29.3a The *Feint!* call
*Feint!* (key **7** standing; 7 is *Get up!* on the ground) sets a shot up for you: the fighter feints, then goes straight into a
shot off it, one call. It's an attempt (§22.2) with a `then` list (`data/calls/feint.json`): `actions: ["feint"]` first, and once
the feint is over the first of `then: ["double_leg", "clinch_entry"]` that would work right now, within 0.3 s
(`LiveCalls.THEN_TICKS`, 3 ticks, inside the feint's 0.5 s set-up), so **the shot is never blind**, and if he bit it gets his +10%.
A fighter who knows no double leg ties up instead (everyone knows the clinch entry). Two separate calls (*Feint!* then
*Takedown!*) wouldn't work: the second would land 0.6 s later, after the bite and the set-up were over. It costs 20 voice, like
*Takedown!*, and holds back the fighter's own feints and shots for 45 s like any called move (`SPENT_TICKS`, §22.5).

The feed reads "Wrestler takes the Feint! call: Feint (call after 6 ticks)", then "Wrestler takes the Feint! call: Double-leg
takedown (off the feint)". If the shot no longer reaches when the feint ends, the call ends `infeasible` (*"couldn't get in
range"*). No corner bot calls it yet: the ideal and AI corners (§22.7) call moments, and a shot set up is the player's call.

What it's worth (scratch check, 60 fights, Wrestler vs Boxer, the Wrestler's corner calling once every 10 s while standing at mid
range or closer): no calls 29 wins; *Takedown!* every time 5 wins (15% of shots land, nearly all of them blind); *Feint!*
every time **40 wins** (35% land, almost none blind). Called at random it's the better call by far; *Takedown!* is for the
kick (the catch) and the moment after a jab.

### 29.4 On screen and in the harness
- The feed: "Wrestler feints and Boxer BITES: hands up, weight back 42% (base 40 · stats +2)", "Wrestler feints; Boxer doesn't
  bite", and a blind shot starts "Wrestler starts a Double-leg takedown **blind**". Its odds show "own BLIND_SHOT −20" and the
  sprawl's "BLIND_SHOT +20". A feint from out of range isn't shown.
- In the 3D view a feint is half a jab and a dip of the level; a fighter who bit has his hands up and leans back.
- The harness's **Feints** line: feints a fight and how many were bitten on, and blind shots a fight and how many still worked
  (CSV columns `feints_*`, `feints_bit_*`, `blind_*`, `blind_landed_*`).

### 29.5 Balance
Reported, no pass marks, like the grapplers before (D109, D128). Harness, no calls, 100 fights one way round (seed 1, pro rules),
this change against D130 just before it:

| Pairing (red vs blue) | Red wins before → now | Takedowns landed of tried a fight, before → now | Feints a fight (bitten) · blind shots (worked) |
|---|---|---|---|
| Kicker vs Boxer | Kicker 44% → 44% (event for event the same) | – | – |
| Wrestler vs Kicker | Wrestler 77% → 72% | 6.9 of 16.5 → 6.3 of 20.9 | 4.9 (1.8) · 6.9 (1.1) |
| Wrestler vs Boxer | Wrestler 75% → 60% | 9.3 of 22.3 → 7.4 of 26.4 | 7.6 (2.6) · 11.1 (1.6) |
| Judoka vs Kicker | Judoka 28% → 28% | unchanged (throws, from the clinch) | – |
| Judoka vs Boxer | Judoka 78% → 78% | unchanged | – |
| Judoka vs Wrestler | Judoka 71% → 79% | the Wrestler's 10.5 of 39.9 → 7.7 of 38.6 | the Wrestler's 5.0 (1.8) · 5.5 (0.3) |
| BJJ vs Kicker | BJJ 11% → 11% | unchanged (guard pulls and throws) | – |
| BJJ vs Boxer | BJJ 35% → 35% | unchanged | – |
| BJJ vs Wrestler | BJJ 76% → 84% | the Wrestler's 11.7 of 25.8 → 9.3 of 28.1 | the Wrestler's 6.3 (2.4) · 8.2 (1.7) |
| Muay Thai vs Wrestler | Muay Thai 54% → 62% | the Wrestler's 14.5 of 39.9 → 11.1 of 45.0 | the Wrestler's 8.0 (2.8) · 11.8 (1.4) |
| Muay Thai vs Boxer, vs Kicker | 57% → 57%, 74% → 74% | – | – |

Across all 1,200 fights: draws 0.4% (was 0.5%), no 10-10 cards, 41.5% finished inside the distance (was 41%).

What it says: **the Wrestler can't just shoot any more.** Blind shots work about one time in six, and against the Boxer, who
has nothing to catch, that's most of his shots: he still lands 7 a fight, but he takes more stuffed shots and pays for
them, and wins 60% instead of 75%. Against the Kicker he wins 72% (was 77%): most of his takedowns there are timed into the
Kicker's kicks, and those are set up. The other grapplers barely shoot (the Judoka and BJJ fighter go through the clinch), so
only their fights with the Wrestler move. Fighters who shot more after D130 now shoot about as often but land less.

If the Wrestler is still too strong against the Kicker, the lever is the shot timed into a kick (the counter bonus on a shot,
or the Kicker kicking less after being taken down, §21.8); a blind clinch entry (§29.2) is the lever for the Judoka. If he's now
too weak, the levers in order: the double leg's `base_success`, `BLIND_SHOT` in `double_leg.json`, then `SETUP_PER_IQ`.

### 29.6 To change it, and the tests
- The feint: `data/actions/feint.json` (timing, `feint.base_success`, `feint.bites_ms`, the stats); feinting again:
  `FightSim.FEINT_REPEAT` (0.1), `FEINT_MEMORY_TICKS` (300). What a bite gives: the `BIT_ON_FEINT` opportunities in
  `double_leg.json`, `clinch_entry.json` and `sprawl.json`.
- Blind shots: `FightSim.would_be_blind()`, `SET_UP_TICKS` (5), `NOT_A_SET_UP`, `BLIND_STUCK_TICKS` (5), `BLIND_STUFFED_STAMINA`
  (5); the `BLIND_SHOT` opportunities in `double_leg.json` and `sprawl.json`; the double leg's `base_success` (0.35).
- The flags: `BIT_ON_FEINT` and `BLIND_SHOT` in `data/enums/flags.json`.
- The AI: `FighterAI.SETUP_BASE`, `SETUP_PER_IQ`, `FEINT_FOLLOW_TICKS`, `BLIND_READ`, `BIT_READ`.
- The *Feint!* call: `data/calls/feint.json` (`then`, `voice_cost`, `hotkey`), `LiveCalls.THEN_TICKS` (3). If it's too strong
  for the player, raise its `voice_cost` or lower the bite's +10% on the double leg.
- The harness: the `feints_*` and `blind_*` columns in `FightSummary`, the Feints line in `BalanceReport`.

Tested in `tests/sim/fight/test_feints.gd` (everyone can feint, the bite and how long it lasts, out of range, feinting again,
a blind double leg and its odds, a jab just before and long before, a shot off a bite, a feint that didn't bite still sets the
shot up, a shot timed into a kick and one at a fighter on the fence, catches, throws and the clinch never blind, clinch entries
never blind but finding a bitten opponent, a blind shot sprawled on and defended costing more, the Wrestler feinting and
shooting off it, Fight IQ, strikers feinting by style (D236, §29.7), reading a blind shot and reading while bitten),
`tests/sim/fight/test_live_calls.gd` (*Feint!*: the feint then the shot inside the set-up, never blind; the clinch entry for a
fighter with no takedown; the shot held back afterwards), `tests/game/test_main_scene.gd` (key 7),
`tests/ui/test_fight_log_formatter.gd` (the feed lines), `tests/game/test_arena_view.gd` (the poses) and
`tests/data/test_data_files.gd` (the `feint` block). After changing a number, run the harness with the Wrestler's pairings
(`--pairs=wrestler:kicker,wrestler:boxer,muay_thai:wrestler`) and read the **Feints** and **Grappling** lines next to the wins.

### 29.7 Striker feints by style (D236)
Kyle (2026-10-31): "lets work on feints". Asked what a striker's feint should be for (set up his own strikes, bait the
counter, or both by style), he picked **both, by style**; asked how often, **keep it light** (a few a fight, as built). Before this a striker never feinted except to herd a man he was
cutting off (D232, §20.5).

| Behaviour | What the fighter does | To change it |
|---|---|---|
| Setting up his strikes (fighters who don't lean outside: Range 0 or more, so the Boxer, Brawler, Dirty boxer, Muay Thai and the grapplers) | About to lead with any strike but a jab (the jab is the set-up), he feints first on a chance of 5% + 20% × Fight IQ / 100 (15% at Fight IQ 50), then throws the strike he'd picked as soon as the feint is over, if it still reaches (up to 0.3 s after). The feed reads "feints to set up the cross", then "throws off the feint" | `FighterAI.STRIKE_SETUP_BASE` (0.05), `STRIKE_SETUP_PER_IQ` (0.2), `FEINT_FOLLOW_TICKS` (3) |
| Baiting the counter (outside fighters, Range below 0: the Kicker, Karate, the Counter-striker, the Range kicker) | In range of a free opponent, he feints on a chance of 0.3% × Fight IQ / 100 a free tick ("feints to draw him"). If the man bites, he fires into it: strikes for the next 0.6 s, as off a slip (D180), "off the bait". If not, nothing | `FighterAI.BAIT_RATE` (0.003), `BAIT_COUNTER_TICKS` (6); `FighterAI._bait()` |
| What a bite gives a striker | A strike that lands on a man still bitten (hands up, weight back) gets +10% ("off the feint"), on top of D131's: he reads it half as often, and his check and slip are 10% worse | `FightSim.FEINT_STRIKE_BONUS` (0.1) |
| Who bites | A patient man sitting back to counter bites more on every feint: +10% × how far his Pace leans below 0 (the Counter-striker, Pace −70: +7%; "waiting to counter" in the odds). It's why the bait is mostly a weapon against counter-strikers | `FightSim.FEINT_PATIENT` (0.1) |
| Reported after the fight | The harness's **Feints** line adds the strikes that arrived while the man was bitten and how many landed (CSV `off_feint_*`, `off_feint_landed_*`) | `FighterState.off_feint_thrown`, `off_feint_landed` |

Measured (200 fights a pairing, pro rules, the same seeds as the D235 build before it, compared fight by fight, §2.4):

| Pairing (red vs blue) | Red wins before → after (change, 95% range) | Feints a fight (bitten) · strikes off a bite (landed), red / blue |
|---|---|---|
| Kicker vs Boxer | 38.5% → 37.5% (−1.0, −10.1 to +8.1) | 2.2 (0.8) · 0.8 (0.6) / 10.9 (4.4) · 1.4 (1.1) |
| Counter-striker vs Boxer | 24.5% → 18.0% (−6.5, −14.2 to +1.2) | 7.3 (3.6) · 3.6 (2.5) / 18.0 (4.7) · 1.7 (1.1) |
| Brawler vs Kicker | 71.5% → 71.0% (−0.5, −9.6 to +8.6) | 6.9 (2.5) · 1.2 (0.9) / 0.9 (0.5) · 0.4 (0.3) |
| Pressure wrestler vs Counter-striker | 71.0% → 74.5% (+3.5, −5.2 to +12.2) | 20.2 (4.4) · 0.3 (0.1) / 5.0 (2.5) · 2.6 (2.0) |
| Karate vs Boxer | 92.0% → 94.0% (+2.0, −3.2 to +7.2) | 1.7 (0.9) · 0.9 (0.6) / 7.0 (2.0) · 0.7 (0.4) |
| Wrestler vs Kicker | 71.5% → 74.5% (+3.0, −6.0 to +12.0) | 10.9 (4.2) · 0.4 (0.3) / 2.2 (0.8) · 0.9 (0.6) |
| Boxer vs Brawler | 39.0% → 40.5% (+1.5, −7.6 to +10.6) | 1.9 (0.9) · 0.9 (0.8) / 3.2 (0.9) · 0.8 (0.6) |

Every range crosses 0. The Counter-striker's −6.5 against the Boxer is the one to watch: he bites more on the Boxer's
feints than he gains from his own bait. On the 15-style table (`tools/style_sheets.gd --fights=60`, D160) every style
wins between 33% and 65% (the D235 build: 32–73%). Most moves at 60 fights are noise; the two that moved most, measured
again at 180 fights a style: Leg-kick specialist 49% → 47% (60 fights said 60% → 38%) and Karate point fighter 69% → 61%,
which may be real: he's patient, so he bites more on the field's new feints.

Tested in `tests/sim/fight/test_feints.gd` (the Kicker baits and the Boxer sets up, a strike on a bitten man, a patient
counter-striker biting more, a bitten bait opening a counter and a plain feint not).

## 30. Leg locks and the Sambo fighter (D132)
Kyle started the third ground scope from D130's card (2026-10-29: "alright lets start on that"): leg locks and a Sambo test
fighter, built on the positions in §28. A leg lock is a hold like the others (§25: it locks in on a roll, then the danger meter
and the struggle's beats), with two differences: it can come from places a choke can't (underneath, on top of half guard, in a
scramble), and **missing one costs the position**, because the attacker lets go of everything else to dive on a leg. Every
number is a first guess for the harness; each is a named constant or a data field, listed in §30.6.

### 30.1 The holds
| Hold | Who, from where | Timing (telegraph · wind-up · active · recovery) | Lock-in odds (base + attack − defense stats) | Danger | If it misses |
|---|---|---|---|---|---|
| Ankle lock (a technique: Sambo, BJJ) | Bottom of full guard or half guard; a scramble | 0 · 0.2 · 0.3 · 0.4 s | 15% + (Submissions, Scrambles) − (Submission defense, Scrambles), +15% on `POSTURED_UP` (sat up to punch, a foot left behind) | Starts at 25, 20 a beat | From underneath: he walks past the legs, **side control**. From a scramble: the attacker ends up on the bottom of full guard. Within 15% of the odds it half works: a scramble |
| Kneebar (a technique: Sambo) | Top of half guard; a scramble | 0 · 0.3 · 0.3 · 0.5 s | 5% + (Submissions, Strength) − (Submission defense, Strength), +10% on `ESCAPING` (getting his guard back leaves the trapped leg out) | Starts at 25, 20 a beat | He rolled for the leg and lost the top: **the attacker on the bottom of full guard**, the other scores a reversal. Within 15%: a scramble |
| Heel hook (a technique: BJJ) | As the ankle lock | 0 · 0.3 · 0.3 · 0.4 s | 10% + (Submissions, Scrambles) − (Submission defense, Scrambles), +15% on `POSTURED_UP` | Starts at 35, **30 a beat** (`step`): it's over fast, a tap in three beats or out in two | As the ankle lock. **Banned under both amateur rulesets** (`heel_hooks`, `08`) |

All three: getting out goes to a **scramble** (the legs come apart, nobody on top), the lock scores with the judges like any
hold (`Judging.SUB_LOCK_POINTS`), and *Finish it!* and *Defend the sub!* work on them as on any hold (§25.3). A win reads "Sambo
wins by submission (kneebar)". Between equal fighters a locked ankle lock or kneebar taps about 6% of the time (from 25 it takes four
beats won in a row), 18% when the attacker wins 65% of the beats (a tired striker underneath); the heel hook about 22%, and 46%
at 65% (three beats won before two lost). The holds of §25 tap about 22% between equal fighters.

### 30.2 What a miss costs
A leg lock that doesn't lock at all (not half working) moves the fight (the `failed` transitions in the position files):

| From | Where it goes | The judges |
|---|---|---|
| Underneath (full guard, half guard) | Side control, the other fighter still on top | He scores the pass he got for free: 6 × the control gained (§28.3), 3 points from full guard. It doesn't count as an escape for anyone |
| On top of half guard (the kneebar) | Full guard, the attacker now underneath | The other scores a reversal, like a takedown (6) |
| A scramble | Full guard, the attacker underneath | As above |

The feed says "Sambo's ankle lock misses and costs the position → Side control". The guillotine's miss (§25.1, pulled onto his
back) now reads the same way.

### 30.3 The fighter AI
| Where | What the fighter does | To change it |
|---|---|---|
| Underneath | The ankle lock and heel hook are holds like the triangle (§25.4): only when the top fighter postures up to punch, weighted 0.1 × how much they like subs, not again for 45 s | `FighterAI.SUB_WEIGHT`, `SUB_RETRY_TICKS` |
| On top of half guard | The kneebar only on an escape (§28.4): one look as the one underneath works back to guard, on a chance of 0.2 × (the odds / 50%)² × 0.5 × how much they like subs. He doesn't weigh what a miss costs | `ESCAPE_PUNISH`, `ESCAPE_SUB` |
| A scramble | Any of the three without waiting for an opening (`ai_without_opening` lists `scramble`: legs everywhere), next to scrambling for the top and getting up | `ai_without_opening` in the holds' files |

### 30.4 The Sambo fighter
A new test fighter in `data/fighters/sambo.json`, on the setup screen as Sambo vs Wrestler, vs BJJ and vs Boxer:

| Fighter | Stats | Style (pace · range · base · risk) | Moves |
|---|---|---|---|
| **Sambo** | Clinch control, Strength, Scrambles, Submissions, Takedowns and Cardio 65; Takedown defense, Submission defense and Chin 60; Top control and Power 55; Boxing and Kicking 50 | 10 · 40 · 50 · 30 | Jab, cross, leg kick, double leg, outside trip, hip throw, ankle lock, kneebar, armbar, take the back. Leans on the clinch (entry 1.5), the trip and the leg locks (1.5 each). No heel hook: sport sambo bans it |

The BJJ fighter learns the ankle lock and the heel hook (modern no-gi), so his fights change a little. Nobody else knows a leg
lock, so the strikers' and the Wrestler's fights, and the four golden fights (§2.2), play out as before. (One golden fight was
re-pinned: Wrestler vs Boxer is the same fight, but the event for its missed guillotine now says it failed, which changes the
event hash.)

### 30.5 Balance
Reported, no pass marks (D109). The harness prints "Sambo fighter vs …" against the Kicker, the Boxer, the Wrestler and the BJJ
fighter, and a **Leg locks** line for every pairing (tried and locked a fight, and the share of fights a leg lock ended). Harness,
no calls, 100 fights a pairing (50 each way round, seed 1, pro rules):

| Pairing | Wins | Ended by submission · by a leg lock | Leg locks a fight (tried / locked) |
|---|---|---|---|
| Sambo vs Kicker | Sambo 52% | 20% · 11% | 0.7 / 0.3 |
| Sambo vs Boxer | Sambo 43% | 26% · 12% (and 52% TKO, mostly the Boxer's hands) | 0.9 / 0.3 |
| Sambo vs Wrestler | Sambo 75% | 57% · 5% (mostly guillotines on the Wrestler's shots) | 1.8 / 0.3 |
| Sambo vs BJJ | Sambo 26% | 40% · 14% | Sambo 4.0 / 0.7, BJJ 3.7 / 0.9 |
| BJJ vs Kicker (before → now) | BJJ 12% → 14% | 9% → 11% · 4% | 0.2 / 0.1 |
| BJJ vs Boxer | BJJ 34% → 44% | 28% → 40% · 16% | 0.7 / 0.3 |
| BJJ vs Wrestler | BJJ 83% → 80% | 43% → 45% · 15% | 3.5 / 0.7 |

Across all 700 fights: draws 0.1%, no 10-10 cards. Noise at 100 fights is about ±5.

What it says: **the Sambo fighter sits between the Wrestler and the BJJ fighter.** He's about even with the strikers (closer
than the Wrestler or the Judoka, D131, §26.4), beats the Wrestler (who keeps shooting into his guillotine and scrambles) and loses
to the BJJ fighter, the better guard and submission defender. Leg locks are his signature finish, not his only one: they end about
one fight in nine against the strikers. They come mostly from scrambles and from the kneebar as a striker works back to guard;
against good submission defense (the Wrestler, 65) they rarely tap. The first draft locked the kneebar three times in four on a
tired striker escaping half guard and ended about 40% of the Sambo fighter's fights with leg locks; tuning since lowered all three
holds' lock-in odds and starting danger and the kneebar's escape bonus, and the Sambo fighter's Submissions and Scrambles (70 →
65). If the playtest wants leg locks rarer or deadlier, the levers in order: the holds' `base_success`, `start_danger`, the heel
hook's `step`, then the Sambo fighter's leg-lock tendencies. To read it again, run the harness with
`--pairs=sambo:kicker,kicker:sambo,sambo:boxer,boxer:sambo,sambo:wrestler,wrestler:sambo,sambo:bjj,bjj:sambo` and read the
**Leg locks** and **Subs** lines.

### 30.6 To change it, and the tests
- The holds: `data/actions/ankle_lock.json`, `kneebar.json`, `heel_hook.json` (`submission.base_success`, `partial_within`,
  `start_danger`, `step`, `leg_lock`, `ai_without_opening`, `09` action@2); where they lock and what a miss costs: the
  transitions in `data/positions/full_guard.json`, `half_guard.json`, `scramble.json` (`result` `failed`).
- The struggle step: a hold's `submission.step`, else `FightSim.STRUGGLE_STEP` (20); `FightSim.struggle_step()`.
- The judges for a miss: `FightSim.apply_transition()` (the fighter left on top scores the control gained, `Judging.ADVANCE_POINTS_PER_CONTROL`).
- The amateur ban: `Ruleset.allows_action()` and `heel_hooks` in `data/rulesets/`.
- The AI: `FighterAI._any_time()` (`ai_without_opening` as a list of positions), and §25.4/§28.4's constants. The fighters:
  `data/fighters/sambo.json`, `bjj.json`.
- The harness: `BalanceReport.LEG_LOCKERS`, the `leg_locks_*`, `leg_locked_*` and `leg_lock_finish` columns in `FightSummary`.
- The screen: the leg-lock pose in `game/fighter_figure.gd`, the miss's feed line in `ui/fight_log_formatter.gd`, the matchups
  in `ui/fight_setup.gd`.

Tested in `tests/sim/fight/test_leg_locks.gd` (where each is done from and by whom, locking in, what a miss costs and scores, the
half-working scramble, getting out to a scramble, the heel hook's step, a tap counted by the harness, the amateur ban, the AI in a
scramble, waiting for its opening underneath and taking the kneebar on an escape, who knows them, and the Sambo fighter in real
fights), `tests/sim/fight/test_submissions.gd` (every hold locks from every position it's done from),
`tests/sim/balance/test_balance_report.gd` (the report lines), `tests/game/test_arena_view.gd` (the pose) and
`tests/data/test_data_files.gd` (`leg_lock`, `step`, `ai_without_opening` as a list).

## 31. Striker combinations and *Fire back!* (D133)
Kyle asked for striker combinations after the leg locks (2026-10-29: "after that I want to work on strikers combinations").
Before this, a "combination" was the AI throwing another strike straight after the last one, picked fresh each time, with
nothing gained from throwing them together (§20). Now strikers have **drilled combinations**: named runs of strikes in their
profile (the Boxer's 1-2 and 1-2-3, the Kicker's teep into a body kick, the Muay Thai fighter's 1-2 into a body kick). The moves
after the first flow out of the one before, so they're harder to see coming; going to another target catches the opponent looking
the wrong way; and a combination he has seen a few times stops working as well. Kyle picked the second of three scopes on the
card (no new call; **a *Fire back!* read call on E**; a *Combo!* call that throws right away), 2026-10-29. Every number is a
first guess for the harness; each is a named constant or a data field, listed in §31.6.

### 31.1 The combinations
Each is a file in `data/combos/` (`09` combo@1). A fighter throws the ones in their profile's `combos`; grapplers have none, so
their strikes chain one at a time as before.

| Fighter | Combinations (`combos` in `data/fighters/`) |
|---|---|
| Boxer | 1-2 (jab, cross) · 1-2-3 (jab, cross, hook) · 1-1-2 (jab, jab, cross) · 2-3 (cross, hook) |
| Kicker | Jab, low kick · Jab, body kick · Teep, body kick · Teep, high kick · Body kick, high kick |
| Muay Thai | 1-2 · 1-2, body kick · 1-2, knee · Jab, low kick |

Tried and dropped: the Kicker's low kick into a high kick. Two slow kicks back to back give a pressing Boxer time to walk inside
the second one, which fell short about half the time. A teep first pushes him back to where the kick lands. The body kick into a
high kick was meant to go too but stayed in his profile, and every number in §31.5 was measured with it in (corrected here
with D140, 2026-10-29).

### 31.2 What a combination does
| | What happens | To change it |
|---|---|---|
| Flows | Each move after the first starts the tick the last one ends, and its telegraph is **0.1 s shorter** (a cross's 0.2 s is 0.1 s), so the opponent reads it less often (§20: each tick shorter is −20%) | `FightSim.COMBO_FLOW_TICKS` (1) |
| Changes levels | A move that goes to a different target from the one before (head, then the body or the legs, or the other way round) is **+20%** to land: his eyes are up. The 1-2's cross gets nothing (both go to the head); the jab, low kick's kick does | `FightSim.LEVEL_CHANGE` (0.2) |
| He's seen it | Each time the opponent has already seen this combination this fight (counted as its second move starts), its follow-ups are **−5%** to land, up to −15% from the fourth time on, and he's **+10%** likelier to read each of them (up to +30%) | `FightSim.COMBO_SEEN` (0.05), `COMBO_SEEN_MAX` (3), `FighterAI.COMBO_SEEN_READ` (0.1) |
| Breaks | A clean shot landed on a fighter in the middle of a combination ends it. So does the next move not reaching any more (the 1-2-3 from mid range is a 1-2: the hook only works in the pocket), being rocked, or the fight leaving the feet | `FightSim._land_strike`, `FighterAI.next_in_combo` |
| Window | The next move has to start within 0.2 s of the last one ending, or the combination is over | `FightSim.COMBO_WINDOW_TICKS` (2) |

The feed says "Boxer starts a Cross **in a 1-2-3** (2 of 3)", and a follow-up's odds show "changes levels +20" and "seen it −10".

### 31.3 The fighter AI
| Where | What the fighter does | To change it |
|---|---|---|
| Chaining | Unchanged: after a strike, another at (0.15 + 0.45 × skill / 100) × pace (§20), picked fresh. When the two make the start of one of their combinations (a cross after the jab), it's thrown as that combination | `FighterAI._pick_combo` |
| Going on | Each further move of it takes the same chance to chain, and if it passes it's the combination's next move (if it reaches; if not, a fresh pick). So the fighter doesn't throw more, he throws them better | `FighterAI._own_ended`, `_follow_up` |
| Which one | Of several that fit (the 1-2 and the 1-2-3 both start jab, cross), by their moves' tendencies, × 0.6 for each time it's been thrown already this fight, so they mix them up | `FighterAI.COMBO_FRESH` (0.6) |

The first version threw every combination to its end once started. The Boxer then threw a cross or a hook where he used to throw
another jab, and beat the Kicker 65% of the time (the #14 exit test is within 60/40). Making each move take the usual chain chance
fixed it. Only a combination called as a whole (*Fire back!*, §31.4) runs to its end on its own.

### 31.4 The *Fire back!* call
*Fire back!* (key **E**, the second read call; Q is *Catch the kick!*) is a read call (§22.2, `data/calls/fire_back.json`):

| | |
|---|---|
| Primed | For **3 s**. When the opponent's strike is defended (not one that falls short: `data/triggers/opp_strike_misses.json`), the fighter reacts with their own reaction time (D93) and answers with the first of their combinations, in their profile's order, whose first move reaches from there, thrown whole, into his recovery (a counter: +10% and ×1.3 damage on the first strike, §18). With no combination that works, a single cross or jab. If his recovery is over first, it's *missed* ("too late") and stays primed |
| Costs | **30 voice**. While primed, Striking and Takedown defense **−25%** (watching for the miss). After it fires, the fighter **leads with nothing of their own for 10 s** (counters and their own reads still go), as a called takedown stands in for their own (D115). Called strikes never hold back the fighter's own strikes otherwise |
| The feed | "Boxer goes on the read of the Fire back! call: Jab (fires back after the body kick, 3 ticks after the body kick started)", then "Boxer starts a Cross in a 1-2 (2 of 2)" |

No corner bot calls it, so the golden fights (§2.2) don't see it. It's open in playtest fight 3 and free fights, not fights 1–2
(`docs/07`: the first fight teaches three keys).

What it's worth (scratch check, 300 fights a line, seed 1, the corner calling it with nothing else): Boxer vs Kicker with no calls,
the Boxer wins 56%; *Fire back!* each time the Kicker's jab is blocked (his tell: a body kick is coming, §20) **62%**; kept primed
all fight (called every 3.1 s, which drains the voice) 65%. Kicker vs Boxer the other way: no calls 44%, kept primed all fight
**35%**: the Boxer doesn't miss enough to fire back at, and the Kicker spends the fight with his defense down. So it pays to call it
against someone who throws a lot and misses, best when you know a miss is coming, and it costs you against a sharp puncher. The
first draft (6 s, 20 voice, −10% defense, no held-back leads) took the Boxer from 61% to 86% kept primed, and every limit above
came from that.

### 31.5 Balance
The #14 exit test (Kicker vs Boxer within 60/40) still passes, and the rest is reported (D109). The harness prints a **Combos**
line for every pairing: each fighter's combinations a fight and the share of their follow-ups that land. Harness, no calls,
100 fights a pairing (seed 1, pro rules), before → now:

| Pairing | Wins before → now | Combinations a fight (follow-ups landing) |
|---|---|---|
| Kicker vs Boxer | Kicker 44% → 42% | Kicker 4.4 (40%), Boxer 22 (51%) |
| Boxer vs Kicker | Boxer 55% → 61% | as above |
| Boxer vs Boxer | 50/50 → 57/43 | about 20 each |
| Muay Thai vs Boxer | Muay Thai 57% → 61% | Muay Thai 1.9 |
| Muay Thai vs Kicker | Muay Thai 74% → 77% | Muay Thai 4.3 |
| Wrestler vs Boxer | Wrestler 60% → 56% | Boxer 14 |
| Wrestler vs Kicker | Wrestler 72% → 75% | |
| Judoka vs Boxer | Judoka 78% → 70% | Boxer 7 |
| BJJ vs Boxer | BJJ 43% → 46% | |
| Sambo vs Boxer | Sambo 38% → 55% (noise: seeds from 1001 give 39% → 37%) | |

Across every pairing: finished 56.5% → 59.8%, draws 0.1% → 0%, no 10-10 cards. The exit test's run: the Kicker within 59.5%
of the Boxer. Noise at 100 fights is about ±5–9 (a call that did nothing moved one line from 61% to 70%), so the *Fire back!*
numbers in §31.4 are 300 fights a line.

What it says: **combinations make the Boxer a little better at what he already did**, about 5 points against most, and he throws
fewest against the grapplers (14 a fight with the Wrestler, 7 with the Judoka), who close the distance before a 1-2-3 comes. The Kicker
throws few (his kicks chain less often than the Boxer's hands), and his follow-ups land less: kicks are slower to read and to
reach. If the playtest wants combinations to matter more or less, the levers in order: `FightSim.LEVEL_CHANGE`, `COMBO_FLOW_TICKS`,
`COMBO_SEEN`, then the combinations in each fighter's profile. To read it again, run the harness with
`--pairs=kicker:boxer,boxer:kicker,muay_thai:boxer,muay_thai:kicker` and read the **Combos** line.

### 31.6 To change it, and the tests
- The combinations: `data/combos/*.json` (`09` combo@1: `name`, `moves`); who throws which: `combos` in `data/fighters/`.
- What a combination does: `FightSim.COMBO_FLOW_TICKS`, `LEVEL_CHANGE`, `COMBO_SEEN`, `COMBO_SEEN_MAX`, `COMBO_WINDOW_TICKS`
  (`FightSim._start_combo()`, `phase_ticks()`, `_combo_bonuses()`, `_land_strike()`); the loader is `sim/fight/combo_library.gd`.
- The AI: `FighterAI.COMBO_FRESH`, `COMBO_SEEN_READ`, `_pick_combo()`, `_own_ended()`, `_follow_up()`, `next_in_combo()`; the
  decision layer goes on with a called combination before anything else of the fighter's own (`DecisionLayer.decide()`).
- *Fire back!*: `data/calls/fire_back.json` (`combo: true`, `read.duration_ms`, `read.attention_cost`, `voice_cost`, `09`
  call@2), its trigger `data/triggers/opp_strike_misses.json`, and `LiveCalls.LEADS_HELD_TICKS` (100), `_first_combo()`,
  `adjust_lead_rate()` (a `DecisionSource` hook any source can use to hold back the fighter's own leads).
- The harness: the `combos_*`, `combo_strikes_*` and `combo_landed_*` columns in `FightSummary`, the **Combos** line in
  `BalanceReport`. The screen: the "in a 1-2 (2 of 2)" feed line in `ui/fight_log_formatter.gd`, the E key in `ui/fight_hud.gd`.
- A command can queue a whole combination: `FightCommand.queue_combo()`.

Tested in `tests/sim/fight/test_combos.gd` (thrown move after move, the shorter telegraph, changing levels, seen it up to three
times, what breaks one, a wrong move is no part of it, the AI throwing only its own combinations in order and mixing them up,
grapplers throwing none), `tests/sim/fight/test_live_calls.gd` (*Fire back!* answering a blocked strike with a combination, and
too late), `tests/data/test_data_files.gd` (combo@1, a fighter's `combos`, combinations are runs of standing strikes their fighters
know), `tests/ui/test_fight_log_formatter.gd`, `tests/sim/balance/test_balance_report.gd`, `tests/ui/test_fight_hud.gd` and
`tests/game/test_main_scene.gd` (E is *Fire back!*). The golden fights were re-pinned (§2.2): the Boxer and the Kicker now throw
combinations, so Kicker vs Boxer and Wrestler vs Boxer play out differently. The other two (Wrestler vs Kicker, and the
check fighters) came out the same: the Kicker never strung one together in that fight, and the check fighters have none.

## 32. More strikes: the uppercut, overhand, hook to the body, calf kick, elbow and dirty boxing (D140)
Kyle asked to expand the strikes after the combinations (2026-10-29: "alright lets start expanding on that now") and picked
the core set plus dirty boxing in the clinch on the scope card (the other options were the core set alone, the core set plus
spinning moves, and punches only). Before this there were ten strikes: the jab, cross, hook, teep, body kick, head kick, leg kick
and knee standing, and the ground punch and elbow on the ground. The new ones fill the gaps every striker uses, and each punishes
an opening the engine already had (§5): the uppercut a lowered head, the overhand dropped hands, the hook to the body a leg in the
air, the short uppercut a head pulled down in the clinch. Soccer kicks, stomps and knees to a grounded opponent come next, under a
PRIDE ruleset (Kyle's pick on the second card, 2026-10-29). Every number is a first guess for the harness, and each is a field in
the move's file in `data/actions/` (`09` action@2), listed in §32.4.

### 32.1 The moves
| Move | Reach | Timing (telegraph · wind-up · active · recovery) | Lands on | What it's for | What it leaves |
|---|---|---|---|---|---|
| Uppercut (`uppercut.json`) | Pocket | 0.2 · 0.2 · 0.1 · 0.3 s | Head, 7 | **+25% on a lowered head** (`HEAD_LOW`: a shot, stuck under a sprawl), ×1.4 damage and it **stops the shot**, like a knee into one (§21.2); +10% into someone walking in (`COMING_IN`), and stops it | **`HANDS_LOW`** from wind-up to active: the rear hand leaves the chin, so the overhand and the head kick are +20% on him |
| Overhand (`overhand.json`) | Mid, pocket | 0.3 · 0.2 · 0.1 · 0.4 s | Head, 10 | **+20% over dropped hands** (`HANDS_LOW`: tired, rocked, or in an uppercut), +10% on a leg in the air | **`LEANING`** from wind-up to recovery: the counter hook is +15% on him (§5) |
| Hook to the body (`body_hook.json`) | Pocket | 0.2 · 0.2 · 0.1 · 0.3 s | Body, 7 (drains the tank, §8) | **+15% on a leg in the air** (into a kick or a knee), +10% on a lean | Nothing extra |
| Calf kick (`calf_kick.json`) | Mid, pocket | 0.1 · 0.2 · 0.1 · 0.3 s | Legs, 5 (slows the feet, §8) | Quicker to come than the leg kick (0.1 s to read, not 0.2 s) and short enough to throw in the pocket. Kicking and Speed, where the leg kick is Kicking and Power | **`ONE_LEG`** from wind-up to active: it can be caught, like the leg kick |
| Elbow (`elbow.json`) | Pocket, and inside the clinch | 0.1 · 0.2 · 0.1 · 0.3 s | Head, 9 | Clinch striking and Power. **+15% and ×1.2 on a head pulled down** (`POSTURE_BROKEN`: the collar tie, §27); +10% into someone walking in, and stops it | −15% with his own head pulled down. **Banned under both amateur rulesets** (`elbows`, `08`), like the ground elbow |
| Short uppercut (`short_uppercut.json`) | Inside the clinch only | 0.1 · 0.2 · 0.1 · 0.3 s | Head, 6 | Dirty boxing: Boxing and Clinch striking. **+15% and ×1.2 on a head pulled down** | −15% with his own head pulled down |
| Short hook (`short_hook.json`) | Inside the clinch only | 0.1 · 0.2 · 0.1 · 0.3 s | Head, 6 | Dirty boxing: Boxing and Clinch striking | −15% with his own head pulled down |

The figure has a pose for each and lights the right limb for a scouted tell (`game/fighter_figure.gd`).

### 32.2 Who throws them
| Fighter | New moves (`techniques`, tendency) | New combinations (`data/combos/`) |
|---|---|---|
| Boxer | Uppercut 0.7, overhand 0.5, hook to the body 0.8, short uppercut 1.0, short hook 1.0. His `clinch_entry` tendency is **0**: he fights when he's tied up but never goes looking for the clinch | 1-2, hook to the body · Body hook, head hook · Uppercut, hook |
| Kicker | Calf kick 1.0 | Jab, calf kick |
| Muay Thai | Elbow 0.5 (standing and in the clinch); his `clinch_entry` tendency goes from 2.5 to **3.25** | None yet: the elbow is a pocket weapon, and a 1-2 from mid range seldom gets there |
| Wrestler | Overhand 0.6 (the wrestler's punch: it comes over the top while the other man watches for the shot) | None |

The AI needs nothing new: it picks them by the same weights as any strike (§20), so a move that punishes an opening gets thrown
more when the opening is there. Two things it does on its own that the profiles had to answer:
- **A fighter with any clinch strike goes looking for the clinch.** The range plan (§20) counts clinch entries as a threat for
  a fighter who can strike in the clinch, so giving the Boxer dirty boxing made him walk into the Wrestler's shots: the Wrestler
  went to 71%. A `clinch_entry` tendency of 0 keeps him from starting one, and the range plan from counting it.
- **The Muay Thai fighter sits on a knife edge.** Whether he walks the Boxer to the fence and clinches, or plans to stand at mid
  range and gets walked down himself, flips on small changes to how dangerous the Boxer is in the pocket. With the uppercut in,
  the Boxer pinned him on the fence 75% of the time (it was the other way round, 90%) and he won 37%. A `clinch_entry` of 3.0 left
  it flipped (49%), 3.5 over-corrected (69%), and 3.25 has him back walking the Boxer down. His elbow tendency is 0.5, not 1.0,
  because at 1.0 he threw elbows instead of knees (knees 56 → 19 a fight).

How often each gets thrown (30 fights, seed 1, a fight): against the Kicker the Boxer throws about 9 overhands (6 land), 3 uppercuts and 4 hooks to the
body, and still about 43 crosses and 52 jabs (it was 54 and 64). Against the Wrestler he throws about 6 uppercuts, two in three
landing, mostly into the shots. Against the Muay Thai fighter, who ties him up, about 25 short uppercuts and short hooks, under
half landing. The Kicker throws about 31 calf kicks, two in three landing, mostly in place of jabs (49 → 25) and a few leg kicks
(14 → 10). The Muay Thai fighter throws about 10 elbows and 34 knees against the Boxer. The Wrestler throws 3–4 overhands.

### 32.3 Balance
The #14 exit test (Kicker vs Boxer within 60/40) still passes; the rest is reported (D109). Harness, no calls, 300 fights a
pairing, seed 1, pro rules, main (D133) → now:

| Pairing | Wins before → now | Finished inside the distance |
|---|---|---|
| Kicker vs Boxer | Kicker 44% → 44% | 29% → 26% |
| Boxer vs Kicker | Boxer 56% → 53% | 29% → 23% |
| Muay Thai vs Boxer | Muay Thai 54% → 60% | 92% → 99% |
| Muay Thai vs Kicker | Muay Thai 78% → 82% | 22% → 40% |
| Muay Thai vs Wrestler | Muay Thai 68% → 64% | 63% → 64% |
| Wrestler vs Boxer | Wrestler 57% → 61% | 68% → 74% |
| Wrestler vs Kicker | Wrestler 72% → 63% (draws 1.7% → 2.7%) | 41% → 39% |
| Judoka vs Boxer | Judoka 72% → 63% | 35% → 53% |
| BJJ vs Boxer | BJJ 44% → 46% | 82% → 85% |
| Sambo vs Boxer | Sambo 50% → 53% | 76% → 78% |
| Boxer vs Boxer | 52/48 → 49/51 | all of them, both |

Across the 3,300 fights: draws 0.4% → 0.5%, no 10-10 cards, finished inside the distance 58% → 62% (the average of the
pairings). Noise at 300 fights is about ±3 points.

What it says:
- **Kicker vs Boxer hardly moves.** The Boxer's new punches are pocket punches and the Kicker keeps him out of the pocket; the
  overhand is the one he lands from range.
- **The calf kicks hurt the Wrestler** most: they slow his feet, and he loses about 10 points against the Kicker.
- **The Boxer does better against the Judoka** (9 points, and more fights finished). The Judoka has to get close to throw
  him, and that's where the uppercut and the dirty boxing are; which of them does most of it isn't measured yet.
- **The Muay Thai fighter is a little ahead of where he was against the Boxer** (60%, was 54%) after the `clinch_entry` change,
  and nearly every fight between them is finished now: knees and elbows one way, short uppercuts and hooks the other.
- **The Wrestler does a little better against the Boxer** (+3): the overhand, and the uppercut's dropped hand.
- The Boxer's combinations come down (about 15 a fight against the Kicker, was 22): more of his strikes are single overhands,
  uppercuts and body shots now.

If the playtest wants a move rarer or stronger, the levers in order: the fighter's tendency for it, its opening's
`success_bonus`, its `base_damage`, then its telegraph. Watch the Muay Thai fighter's `clinch_entry` first if he starts getting
walked down again (§32.2). To read it again, run the harness with
`--fights=300 --pairs=kicker:boxer,boxer:kicker,muay_thai:boxer,muay_thai:kicker,muay_thai:wrestler,wrestler:boxer,wrestler:kicker,judoka:boxer,bjj:boxer,sambo:boxer,boxer:boxer`.

### 32.4 To change it, and the tests
- The moves: `data/actions/uppercut.json`, `overhand.json`, `body_hook.json`, `calf_kick.json`, `elbow.json`,
  `short_uppercut.json`, `short_hook.json` (`phases_ms`, `strike.base_damage`, `opportunities`, `flags_self`, `09` action@2). The
  elbow ban: `elbows` in `data/rulesets/` (`Ruleset.allows_action()`: any move whose id has "elbow" in it).
- Who throws them: `techniques`, `tendencies` and `combos` in `data/fighters/boxer.json`, `kicker.json`, `muay_thai.json`,
  `wrestler.json`; the new combinations in `data/combos/one_two_body_hook.json`, `body_hook_hook.json`, `uppercut_hook.json`,
  `jab_calf_kick.json`.
- The screen: the poses and tell limbs in `game/fighter_figure.gd`.

Tested in `tests/sim/fight/test_strikes.gd` (each move's opening, the uppercut's dropped hand and the overhand's lean, the
uppercut into a shot, the elbow and short uppercut on a broken posture, where each reaches, the clinch-only dirty boxing, the
amateur elbow ban, every fighter throwing their new moves, elbows in the clinch, and the Boxer never starting a clinch entry).
`tests/sim/fight/test_fighter_library.gd` has the Kicker's new list, and `tests/sim/fight/test_combos.gd` checks the Muay Thai
fighter's combinations against the Kicker now: against the Boxer he mostly knees and elbows in the clinch and some fights have
none. The golden fights were re-pinned (§2.2): the Boxer, the Kicker and the Wrestler throw the new moves, so three of the four
play out differently; the check fighters don't know any.

## 33. PRIDE rules: soccer kicks, stomps, knees on the ground and whole-fight judging (D141)
Kyle asked for soccer kicks on a downed opponent and knees to a grounded one (2026-10-29: "pride never die"), and picked a new
PRIDE ruleset for them on a decision card, with a 10-minute first round; pro and amateur fights stay on unified rules. On a
second card he picked PRIDE's judging: the whole fight, not round by round, looking at the effort to finish first, then control,
then aggression. The rules are `data/rulesets/pride.json` (`08` §1.1); pick them on the fight setup's *Rules* (`06` §6.1).

### 33.1 The rounds
A 10-minute first round, then two of 5 minutes (`round_lengths: [600, 300, 300]`, `09` ruleset@1). The clock, the bell, the feed's
times and the round breaks follow each round's own length (`FightClock.ticks_in_round`, `round_start_tick`). No more title rounds:
PRIDE's title fights were the same three.

### 33.2 Soccer kicks and stomps
A knocked-down fighter (§18: down for 2 s) carries the **`DOWN`** flag. Under unified rules nobody hits him, as before: a punch
or kick thrown at him misses ("opponent down"). Under PRIDE rules two moves can, and only these two (`strike.downed`):

| Move | Reach | Timing (telegraph · wind-up · active · recovery) | Lands on | Notes |
|---|---|---|---|---|
| Soccer kick (`soccer_kick.json`) | Mid, pocket | 0.2 · 0.2 · 0.1 · 0.4 s | Head, 12 | Kicking and Power. Everyone knows it (`basic`). Only on `DOWN`, +20% on him. `ONE_LEG` from wind-up to recovery |
| Stomp (`stomp.json`) | Pocket | 0.1 · 0.2 · 0.1 · 0.3 s | Head, 9 | Power and Speed. Everyone knows it. Only on `DOWN`, +20% |

He's already down, so a kick on him scores no second knockdown: it counts as a rock for the judges, hurts like any head shot,
and can knock him out or have the referee stop it (§24). The fighter AI follows a knockdown up under PRIDE rules: each free tick
while the man is down it throws the downed strike with the most expected damage that reaches, at 30% a tick (`DOWNED_RATE`, ×0.5
to 1.5 from the Risk leaning). Where they're illegal it waits for him to get up, as before.

How often (100 fights a pairing, PRIDE rules): about 0.2 soccer kicks a fight in most pairings, because knockdowns are rare
(0.1–0.3 a fight); the Muay Thai fighter against the Wrestler, who gets knocked down about once a fight, throws about 1.3 and lands
1. Stomps hardly happen: the soccer kick does more and reaches from further.

### 33.3 Knees on the ground
A **knee on the ground** (`ground_knee.json`) from the top of side control: 0.2 · 0.2 · 0.1 · 0.4 s, 9 damage, Top control and
Power against Guard, postured up from the wind-up to the end (so the bottom fighter can tie him up, §24). Under PRIDE rules it goes
to the head (`knees_to_head_grounded`); under unified and amateur rules to the body, like every illegal ground head strike (§24).
The Wrestler and the Judoka know it: about 3 a fight, two landing, against the Boxer. Because they know it in pro fights too
(to the body), pro fights with them changed a little (§33.5).

### 33.4 Whole-fight judging
Under PRIDE rules nobody scores rounds: the bell says "the judges score the whole fight", and if it goes the distance each
of the three judges gives the whole fight to one fighter (`judging: whole_fight`, `Judging.whole_fight_pick`), looking at:
1. **The effort to finish:** damage landed (head counts most), rocks, knockdowns, slams and submissions locked in. The same
   points that make up effective striking in a round (§11, D120), minus the grappling.
2. **Control,** only when the effort to finish is within 10%: takedowns, getting to a better position, time on top (the same
   points as D108 and D130), and time pinning him on the fence (0.15 a second).
3. **Aggression,** only when control is within 10% too: attacks thrown and ground walked forward.

Each judge sees every number ×(1 ± up to 15%), as in a round. Three judges for one fighter is a unanimous decision, two to one a
split; a judge sees it even only when nothing at all separates them, so draws are close to none (0 in 3,300 fights). The result
says why: "Boxer wins by split decision (Boxer on the effort to finish, Kicker on control, Boxer on the effort to finish)". The
HUD's judges' estimate shows who they'd give it to so far and why (`FightSim.fight_scores()`, no noise), and the round break
says the same. Most verdicts are on the effort to finish (about three in four judges' picks, 100 fights each of four pairings); control decides the rest.

### 33.5 Balance
Harness, no calls, 300 fights a pairing, seed 1. The pro column is after D140 with the knee on the ground in (to the body):

| Pairing | Pro, D140 → now | PRIDE rules | Finished inside the distance, pro → PRIDE |
|---|---|---|---|
| Kicker vs Boxer | Kicker 44% → 44% | Kicker 34% | 26% → 45% |
| Boxer vs Kicker | Boxer 53% → 53% | Boxer 63% | 23% → 45% |
| Muay Thai vs Boxer | Muay Thai 60% → 60% | Muay Thai 71% | 99% → 100% |
| Muay Thai vs Kicker | Muay Thai 82% → 82% | Muay Thai 93% | 40% → 63% |
| Muay Thai vs Wrestler | Muay Thai 64% → 69% | Muay Thai 83% | 66% → 87% |
| Wrestler vs Boxer | Wrestler 61% → 64% | Wrestler 62% | 71% → 93% |
| Wrestler vs Kicker | Wrestler 63% → 63% (draws 2.7% → 2.3%) | Wrestler 69% | 35% → 64% |
| Judoka vs Boxer | Judoka 63% → 62% | Judoka 51% | 50% → 76% |
| BJJ vs Boxer | BJJ 46% → 46% | BJJ 57% | 85% → 98% |
| Sambo vs Boxer | Sambo 53% → 53% | Sambo 61% | 78% → 93% |
| Boxer vs Boxer | 49/51 → 49/51 | 50/50 | all of them, both |

Across the 3,300 fights: pro draws 0.4%, finished 61%; PRIDE draws 0%, finished 79%, over half of all fights (54%) inside the
10-minute first round. Noise at 300 fights is about ±3 points. The #14 exit test (Kicker vs Boxer within 60/40) is a pro test and still
passes; under PRIDE rules the Boxer wins 65% (reported only).

What it says:
- **The 10-minute first round finishes fights.** With no bell at five minutes, damage and tiredness build up: the Boxer stops the
  Kicker twice as often (TKOs 20% → 30% of fights), and the submission fighters get there more (BJJ, Sambo +8 to +11).
- **Finish-first judging helps whoever does damage, not whoever holds.** The Judoka wins half his pro fights on decisions built on
  throws and time on top; under PRIDE the Boxer's damage outweighs them (63% → 51%). The Boxer out-damages the Kicker over a
  whole fight too.
- **Elbows stay legal** (Kyle's pick, 2026-10-29, though PRIDE banned elbows to the head). With them banned in a first run the
  Muay Thai fighter lost his elbows and dropped against the Boxer (60% → 47%), and the Wrestler lost his ground elbows. With them
  the Muay Thai fighter beats the Boxer 71% (elbows and knees in the clinch for ten minutes) and the Wrestler finishes far more
  of his fights (Boxer 93%, Kicker 64%) with ground elbows and knees to the head together.
- In pro fights the knee on the ground to the body changes little: the Wrestler +3 against the Boxer, and the Muay Thai fighter
  +5 against the Wrestler (about the noise; the Wrestler spends some of his top time kneeing the body instead of punching).

To read it again, run the harness with `--ruleset=pride` and the pairings of §32.3.

### 33.6 To change it, and the tests
- The rules: `data/rulesets/pride.json` (`round_lengths`, `judging`, `allows`: `soccer_kicks`, `stomps`, `knees_to_head_grounded`,
  `elbows`, true under PRIDE by Kyle's pick; `09` ruleset@1). Which moves the `soccer_kicks` and `stomps` keys cover, and the ground knee's target:
  `Ruleset.allows_action()`, `Ruleset.allows_target()`.
- The moves: `data/actions/soccer_kick.json`, `stomp.json`, `ground_knee.json`; who knows the ground knee: `techniques` in
  `data/fighters/wrestler.json` and `judoka.json`. What lands on a downed man: `strike.downed` (`FightSim._land_strike`), and a kick
  on him scoring no second knockdown: `FightSim._head_impact`.
- The AI following a knockdown up: `DOWNED_RATE` in `sim/fight/fighter_ai.gd` (`_downed`).
- The judges: `WHOLE_FIGHT_ORDER`, `WHOLE_FIGHT_EVEN_WITHIN` and `FENCE_CONTROL_PER_S` in `sim/fight/judging.gd`; what counts as
  control and what as the effort to finish: `FightSim._round_scores` (`_round_grappling` holds the grappling share of a round's
  points).
- The screen: the *Rules* picker (`FightSetup.RULESETS`), the poses for the three moves in `game/fighter_figure.gd`, the verdict's
  words in `FightLogFormatter.JUDGED_ON`.

Tested in `tests/sim/fight/test_pride.gd` (the round lengths and the clock, the feed's times, which rules allow soccer kicks and
stomps, a soccer kick needing him down, only downed strikes landing on a downed man, no second knockdown, the ground knee's
target under each ruleset, the AI kicking a downed man under PRIDE and never under pro, each step of a judge's pick, the verdict
from three picks, a takedown counting as control, a PRIDE fight with no round scores, pro fights still scored by round) and
`tests/data/test_data_files.gd` (the new `allows` keys, `round_lengths` and `judging`, a downed strike being a standing move that
needs `DOWN`). The golden fights were re-pinned (§2.2): the Wrestler knows the knee on the ground, so his two golden fights play
out differently; the Kicker vs Boxer and check-fighter fights don't change.

## 34. Following a knockdown down to the ground (D142)
Kyle asked whether fighters can get rocked or dropped (2026-10-29). They could (§18, §24), but a knockdown led nowhere: the man
was down for 2 s and nobody could touch him, then he got up. Kyle picked all three follow-ups on a decision card, one after
another: following a knockdown down to the ground (this section), then liver shots and a leg giving out, then flash knockdowns.
On a second card he picked the call: *Takedown!* on key 4 does it, no new key.

### 34.1 The move
**Follow him down** (`follow_down.json`): everyone knows it (`basic`), from standing at mid or pocket range, only on a knocked-down
man (`DOWN`, required; `ground.downed`). 0.1 · 0.2 · 0.3 · 0.3 s. 35% + 20% on him down + (Scrambles, Top control) − his
Scrambles. A rocked man can't do much about it, so it usually works:

| Roll | Where it goes |
|---|---|
| Under the odds | **Half guard, on top** (`standing.json`): straight past most of his legs |
| Within 25% over them | **Full guard, on top**: a scrappy landing, he gets his legs round |
| Worse | He scrambles up; the fight stays standing and the man who tried it is in his recovery |

Landing on top scores like a takedown (D108). The downed man is in a ground position now, so he's no longer down, but he's still
rocked for the rest of his rocked time: ground and pound on a rocked man (§24) is where the referee steps in. Any other grapple
at a downed man (a double-leg, a clinch entry) still finds nobody standing to shoot on ("opponent down"), and under unified rules
nothing else hits him (PRIDE's soccer kicks and stomps, §33).

### 34.2 Who does it
The fighter AI decides once, as the man drops, whether it will follow him down: 50% × its `follow_down` tendency × (1 + Base /
100), so a grappler (the Wrestler and the Judoka, Base 70) about 85% of the time, a striker (the Boxer and the Kicker, Base 0)
half the time (`FOLLOW_DOWN_CHANCE`). If it will, it goes at 30% a free tick while he's down (`DOWNED_RATE`), as for a soccer kick.
Under PRIDE rules it weighs following him down (10 × its odds, `FOLLOW_DOWN_VALUE`) against a soccer kick's expected damage and
takes the bigger. No fighter's profile sets the tendency yet: it's there to make one keener or less keen.

The player calls it with *Takedown!* (key 4): it's the first move on that call's list, so when he's down the call follows him
down, and otherwise goes on to the catch-kick and the double-leg as before (§22.2). While he's on his feet the call skips it
(`LiveCalls._moves`), so a fighter who knows no takedown still can't take a Takedown! call.

### 34.3 Balance
How often (100 fights a pairing, pro rules): the Kicker and the Boxer drop each other about 0.25 times a fight and follow up after
about 3 in 5 of those knockdowns (some knockdowns end the fight there and then, and a fighter who is rocked himself doesn't follow);
three in four follow-ups land. The Muay Thai fighter drops the Wrestler about 1.2 times a fight and follows 52 of those 119 times
down; 15 of the 34 fights where he did ended inside the distance.

Harness, no calls, 300 fights a pairing, seed 1, pro rules, D141 → now: fights finished inside the distance 61% → 61%, draws
0.4% → 0.4%. Kicker vs Boxer 44/56 → 46/54, Boxer vs Kicker 53 → 53, Muay Thai vs Boxer 60 → 56, Muay Thai vs Kicker 82 → 80,
Muay Thai vs Wrestler 69 → 69, Wrestler vs Boxer 64 → 66, Wrestler vs Kicker 63 → 64, Judoka vs Boxer 62 → 60, BJJ vs Boxer
46 → 48, Sambo vs Boxer 53 → 55, Boxer mirror 49/51 → 50/50: all within the noise (±3) but the Muay Thai fighter against the
Boxer. Knockdowns are rare, and a man who's been dropped was usually going to be stopped anyway; what changes is how: more of
those fights end on the ground. Flash knockdowns (next) will make knockdowns, and so this, more common. The golden fights don't
change: none of them has a knockdown that gets followed up.

### 34.4 To change it, and the tests
- The move: `data/actions/follow_down.json` (`phases_ms`, `ground.base_success`, `partial_within`, the `DOWN` opening's bonus,
  `stats`); where it lands: the two `follow_down` transitions in `data/positions/standing.json`.
- Who follows up: `FOLLOW_DOWN_CHANCE`, `FOLLOW_DOWN_VALUE` and `DOWNED_RATE` in `sim/fight/fighter_ai.gd` (`_downed`), and a
  `follow_down` tendency in a fighter's profile.
- The call: `follow_down` first in `actions` of `data/calls/takedown.json`; skipped while he's standing: `LiveCalls._moves`.
- The downed man coming off the floor into the ground position: `FightSim.apply_transition`; a downed grapple reaching him:
  `FightSim._make_contact`.

Tested in `tests/sim/fight/test_follow_down.gd` (it needs him down, a clean one lands in half guard with him still rocked, a
scrappy one in full guard and a miss lets him up, a double-leg at a downed man still finds nobody, the AI following up with the
Wrestler keener than the Boxer, the Takedown! call following him down) and `tests/data/test_data_files.gd` (a move at a downed
man is used standing and needs `DOWN`).

## 35. Liver shots (D143)
The second of Kyle's three rocked-and-dropped follow-ups (§34). Body shots used to wear the tank down (§8) and do nothing in the
moment. Now a hard one can find the liver: he freezes, folds a moment later and goes down.

### 35.1 How it works
Any clean body shot thrown standing or in the clinch (the hook to the body, the body kick, the knee, the teep) rolls for it, like
a head shot rolls to rock (§18):
- **Shock** = damage × (1 + his body hurt) / (8 + 0.16 × Durability). An average fighter's body is 16 to a head's 12, so a liver
  shot takes more than a rock; a body that's been hit already goes easier.
- **Chance** = (shock − 0.8) × 0.2, up to 25%. Nothing under a shock of 0.8.
- It doesn't drop him on the spot. **He freezes for 0.5 s** (`LIVER_DELAY_TICKS`), bent over it with his hands dropped
  (`HANDS_LOW`): he can't start anything, and anything thrown at him finds him open. The feed says *"freezes: that one found the
  LIVER"*.
- **Then he folds and goes down for 3 s** (2 s for a knockdown). It is a knockdown for the judges and the referee (three in a
  round stops it), but his head is clear, so he isn't rocked. It takes 20 stamina (`LIVER_STAMINA`).
- While he's down he can be followed down (§34), and under PRIDE rules soccer kicked (§33).
- **He gets up winded:** his hands stay low for 5 s more (`LIVER_WINDED_TICKS`), so the overhand, the head kick and the guard pass
  find him easier.
- A head shot that drops him while it's coming is the same fall: one knockdown, not two. Taken down before it takes him, there's
  nowhere to fold to: he loses the stamina and is winded on the ground. Ground strikes never find the liver.

### 35.2 How often
100 fights a pairing, pro rules: about 2 liver shots in 100 Kicker vs Boxer fights, the Kicker's body kicks, and 3 in 100 Muay Thai
vs Boxer fights, knees. A body-shot war finds it most: the Muay Thai fighter and the Kicker fold each other about 23 times in 100
fights, knees and body kicks on bodies already worn down. The Wrestler, who doesn't throw to the body, never finds one. Against
head knockdowns (27 and 72 in the first two) they're the rarer way down, as in real fights. A first draft (from a shock of 0.7)
folded the Kicker about once every two fights against the Muay Thai fighter; 0.8 keeps it a moment.

What the four rocked-and-dropped changes do to fights together is in §37.3.

### 35.3 To change it, and the tests
- How hard a shot has to be, and how often: `LIVER_THRESHOLD_BASE`, `LIVER_THRESHOLD_PER_DURABILITY`, `LIVER_FROM`, `LIVER_SLOPE`,
  `LIVER_MAX` at the top of `sim/fight/fight_sim.gd` (`body_shock`, `liver_chance`).
- What it does: `LIVER_DELAY_TICKS`, `LIVER_DOWN_TICKS`, `LIVER_STAMINA`, `LIVER_WINDED_TICKS` (`FightSim._body_impact`,
  `_liver_fold`); the hands dropping: `active_flags`, `flags_ahead`.
- The screen: the bent-over pose in `game/fighter_figure.gd`, the feed lines in `ui/fight_log_formatter.gd`; the feed counts a liver
  shot as a key moment and the fight slows for it, like a knockdown (`FightFeed.kind_of`, `FightDriver`).

Tested in `tests/sim/fight/test_liver_shots.gd` (a hard body kick on a hurt body finds it and he folds a moment later, the odds,
folding as a knockdown with his head clear, getting up winded, frozen while it's coming, head and ground shots never finding it,
one fall not two).

## 36. A leg giving out (D144)
The third of Kyle's rocked-and-dropped follow-ups (§34). Kyle picked "It buckles, then he limps" on a decision card (the others
were a limp with no fall, and a referee stoppage after two buckles).

### 36.1 Two legs
Leg damage used to be one area that slowed the feet (§8). Now each leg keeps its own (`FighterState.leg_damage`, [left, right];
`damage.legs` is still the two together, for the judges, the tank and the feet as before):
- **Low kicks land on the front leg** (`lead_leg()`): the left for an orthodox fighter and anyone whose profile gives no stance,
  the right for a southpaw.
- **Each leg is fully hurt at 0.3 of the legs' scale** (`LEG_SHARE`; 3 × (Durability + 50) damage, 300 for an average fighter),
  so one leg kicked to pieces is a leg gone while the other is fresh. The Boxer takes about 145 to his front leg from the Kicker in a
  fight (about half gone by the end), up to 240.
- **He switches stance to hide it:** a front leg past half gone (`SWITCH_FROM`) and worse than the back one by 0.2
  (`SWITCH_MARGIN`) makes him switch, and the kicks find the other leg. The feed says *"switches stance to hide the left leg"*. The
  Boxer switches in about 2 fights in 5 against the Kicker.
- The body figure on the top bar (D150, `06` §6.2) shows each leg in its own colour now, drawn facing you: his left leg on your
  right; a low kick flashes the leg it landed on.

### 36.2 The buckle and the limp
A low kick that lands on a front leg already past 0.35 hurt (`BUCKLE_FROM`) can buckle it: chance (leg hurt − 0.35) × damage ×
0.03, up to 30% (`buckle_chance`). He drops for 1 s (`LEG_DOWN_TICKS`): a knockdown for the judges and the referee, his head clear,
and he can be followed down (§34). After that **he limps on it for the rest of the fight** (`limping`): Footwork, Speed, Kicking
and Takedown defense a further 20% down (`LIMP_STATS`, `LIMP_PENALTY`), so he's slower, his kicks are weaker and he's easier to
take down. The feed says *"'s left leg BUCKLES and he goes DOWN!"*.

How often (100 fights a pairing, pro rules): the Boxer's leg buckles in about 7 fights in 100 against the Kicker, the Kicker's in
about 3 against the Muay Thai fighter. No one else kicks the legs enough.

### 36.3 To change it, and the tests
- The legs: `LEG_SHARE`, `LIMP_STATS`, `LIMP_PENALTY` in `sim/fight/fighter_state.gd` (`leg_hurt`, `lead_leg`); the stance from
  the profile's `stance` (`09` fighter@1).
- The buckle and the switch: `BUCKLE_FROM`, `BUCKLE_PER_DAMAGE`, `BUCKLE_MAX`, `LEG_DOWN_TICKS`, `SWITCH_FROM`, `SWITCH_MARGIN` at
  the top of `sim/fight/fight_sim.gd` (`_leg_impact`).
- The screen: each leg's colour and the leg flash in `ui/body_damage_figure.gd` (`leg_colour`); the feed lines in
  `ui/fight_log_formatter.gd`.

Tested in `tests/sim/fight/test_legs.gd` (low kicks land on the front leg, a southpaw's and a switched fighter's front leg, one
leg gone while the other is fresh, switching stance to hide it, a gone leg buckling and the limp, a fresh leg never buckling,
the figure showing each leg).

## 37. Flash knockdowns (D145)
The last of the three. Before this a fighter only went down when he was hit while already rocked, or rocked by a knee into his
shot (§21.2): one punch, however hard, never dropped a fresh man.

### 37.1 How it works
A head shot that rocks a man who isn't rocked (§18) can drop him there and then if it was big enough: chance (shock − 1.2) × 0.4, up
to 35% (`flash_chance`). Shock is the same as for a rock (damage × (1 + head hurt) / (6 + 0.12 × Chin)), so for an average chin a
flash needs about 15 damage: a counter (×1.3), a head kick or an overhand gets there, a jab never does. It's a knockdown like any
other: the KO roll (§18), 2 s down, up rocked, followed down (§34) or soccer kicked under PRIDE rules (§33). The feed says
*"is DROPPED by one shot!"*. On the ground there's nowhere to fall: a big shot there rocks, as before.

How often (100 fights a pairing, pro rules): about 22 in 100 Kicker vs Boxer fights have one, nearly all the Boxer's counter
overhands and the Kicker's counter head kicks; 1 to 4 in 100 in the other pairings with the Boxer.

### 37.2 What Kyle was asked
How often one clean shot should drop a fresh fighter: rarely, about one fight in ten (recommended, built while the card was
open); commonly, one in four; or only off a counter.

### 37.3 The four together: balance
Harness, no calls, 300 fights a pairing, seed 1, D141 (PRIDE) → now, with following up (§34), liver shots (§35), the legs (§36)
and flash knockdowns together:

| Pairing | Wins, pro rules | Finished inside the distance | Fights with a knockdown |
|---|---|---|---|
| Kicker vs Boxer | Kicker 44% → 45% | 26% → 34% | 19% → 38% |
| Boxer vs Kicker | Boxer 53% → 57% | 23% → 36% | 18% → 40% |
| Muay Thai vs Boxer | Muay Thai 60% → 56% | 99% → 98% | 46% → 51% |
| Muay Thai vs Kicker | Muay Thai 82% → 76% | 40% → 38% | 31% → 54% |
| Muay Thai vs Wrestler | Muay Thai 69% → 69% | 66% → 66% | 78% → 77% |
| Wrestler vs Boxer | Wrestler 64% → 64% | 71% → 72% | 21% → 20% |
| Wrestler vs Kicker | Wrestler 63% → 61% | 35% → 34% | 8% → 11% |
| Judoka vs Boxer | Judoka 62% → 58% | 50% → 54% | 10% → 11% |
| BJJ vs Boxer | BJJ 46% → 48% | 85% → 85% | 9% → 11% |
| Sambo vs Boxer | Sambo 53% → 53% | 78% → 80% | 18% → 19% |
| Boxer vs Boxer | 49/51 → 47/53 | all of them | 13% → 15% |

Across the 3,300 fights: finished 61% → 63%, fights with a knockdown 25% → 32%, draws 0.4% → 0.5%. The #14 exit test still passes
(the Boxer 56% over both corners). Under PRIDE rules: finished 79% → 84%, fights with a knockdown 26% → 36%, no draws; Kicker vs
Boxer is finished 62% of the time (45%).

What it says:
- **The striker fights changed most:** Kicker vs Boxer has twice the knockdowns (about two fights in five) and a third more
  finishes. It's the Boxer's counters and the Kicker's leg kicks: the Boxer drops the Kicker on counters, the Kicker buckles the
  Boxer's leg.
- **The Muay Thai fighter drops a little** against the Boxer and the Kicker (−4, −6): both drop him with flash counters now, and
  the Kicker's body kicks find his liver.
- **Grappling fights hardly move.** Knockdowns there are rare, and a fighter on top was already finishing on the ground.

Two golden fights were re-pinned (§2.2): Kicker vs Boxer goes the distance now (the body shots' liver rolls change what follows),
and the Wrestler vs Kicker fight plays out the same but its landed low kicks now say which leg they hit. The other two don't change.

### 37.4 To change it, and the tests
- How big a shot it takes, and how often: `FLASH_FROM`, `FLASH_SLOPE`, `FLASH_MAX` at the top of `sim/fight/fight_sim.gd`
  (`flash_chance`, in `_head_impact`).
- The feed line: `ui/fight_log_formatter.gd`.

Tested in `tests/sim/fight/test_flash_knockdowns.gd` (only a big shot can, a jab never drops a fresh man, a big head kick drops one
with no rock first, nowhere to fall on the ground).

## 38. Striking defence: checking kicks, slipping punches and covering up (D180)
Before this, the only defence against a strike was not being there (stepping back from a strike he read, §20) or hitting first
(a counter, §5). Kyle asked for the first batch of the moveset expansions: checking a kick, slipping a punch, covering up. On
three decision cards he picked: check and cover up for everyone and the slip as a technique; a rocked fighter covering up
sometimes on his own and always on *Survive!*; and a checked kick sending 60% of it back into the kicker's leg. On a fourth,
when the checks put Kicker vs Boxer at 41/59, he picked "Kicker hides kicks better" (§38.3).

### 38.1 The three moves
They're `defense` moves (`09` action@2), like the sprawl.
- **Check** (`check_kick`, everyone): he lifts his front shin. It's up at once (no wind-up) for 0.4 s and stops the **leg kick
  and the calf kick** (`against_strikes`). Odds: 60% + (Striking defense and Kicking − the kicker's Kicking) / 100, and a good
  kicker hides his kicks: his Kicking above 50 counts again at half (`hidden_by` 0.5, *hidden*), so the Kicker (70) is checked
  10% less on top of the usual edge. When it
  works the kick misses and lands on his shin: the kicker's kicking leg (his back leg) takes 60% of the kick (`CHECK_KICKER_SHARE`),
  scored for the checker as leg damage, and it can buckle that leg (§36); the checker's front leg takes 20% (`CHECK_SHIN_SHARE`);
  and the kicker is stuck on one leg 0.2 s longer (`ONE_LEG`, `CHECK_STUCK_TICKS`), where a cross finds him.
- **Slip** (`slip`, a technique: the Boxer, Counter-striker, Dirty boxer and Muay Thai fighter): he moves his head off the line,
  at once, for 0.4 s. It stops **the jab, the cross and the overhand**, not hooks or uppercuts, and the uppercut is +20% into a
  man slipping (`SLIPPING`). Odds: 50% + (Striking defense and Speed − the puncher's Boxing) / 100. When it works the punch misses
  and for 0.6 s his own strikes are +15% (*off the slip*, `SLIP_COUNTER_TICKS`, `SLIP_COUNTER_BONUS`), on top of the counter
  bonus for catching the puncher in his recovery.
- **Cover up** (`cover_up`, everyone, standing or in the clinch): hands high, elbows in, for 1.5 s (`COVERED` from its 0.1 s
  wind-up). Half the head damage gets through (`head_share` 0.5), rolled as usual; the body hook, body kick and knee are +15%
  into him; he can't throw while he's covered; and he isn't *hands low* while he's covered, rocked or tired. **The referee
  doesn't count shots on the guard** toward stopping it (§24): he's defending himself. Without that, covering up made stoppages
  far more common (Kicker vs Boxer TKOs went from 20% to 59%), the opposite of what covering up is for.

A check or a slip has to be **up as the strike lands**: then it's one roll, and either way it's spent. Too early and it's over
before the strike arrives; too late and the strike has landed. The feed says *"CHECKS the leg kick: it lands on his shin (4
damage to the kicker's leg)"*, *"SLIPS the cross"*, and *"through the guard"* on a shot into a man covering up. A checked or
slipped strike is a miss for the striker (`strike_missed`, reason `defended`): it counts as defended for tells, rules and
*Fire back!* (`09` trigger@1), and the AI learns from it (§38.2).

### 38.2 The AI
- **Checking and slipping what he reads.** When a strike he's read registers (§7: a reaction time after it starts) and he has a
  defence against it that will be up as it lands, he uses it: 60% + 30% × Striking defense / 100 (`GUARD_BASE`, `GUARD_PER_SD`).
  If not, it's read like any other move (a counter or stepping back). So the jab is too quick to slip after a read, the cross
  sometimes, the overhand and the low kicks most often.
- **Off the slip, off the check.** A slip or a check that worked is followed by a strike within 0.6 s (*off the slip*, *off the
  check*).
- **Learning.** A checked or slipped strike counts as a miss on that move's record (`_working`, §20), so a kicker who keeps
  getting checked throws fewer low kicks.
- **Covering up.** Each time he's rocked he decides whether he covers up this time: 20% + 40% × Fight IQ / 100 (`COVER_BASE`,
  `COVER_PER_IQ`, 40% for an average fighter), and while he's rocked and in range he covers up again as each one ends. *Survive!*
  (key 8) makes him: its `cover_bonus` 1 (`09` call@2), so the AI corner's *Survive!* on a rock (§22.5) shells him up.

### 38.3 Balance
Harness, no calls, 300 fights a pairing, seed 1, main before this → now:

| Pairing | Wins | Finished inside the distance | Checks a fight (worked) | Slips a fight (worked) |
|---|---|---|---|---|
| Kicker vs Boxer | Kicker 45% → 46% | 34% → 26% | the Boxer 7.8 (2.4) | none |
| Muay Thai vs Kicker | Muay Thai 76% → 77% | 38% → 32% | Muay Thai 8.2 (3.4), the Kicker 0.8 (0.6) | none |
| Boxer vs Counter-striker | Boxer 71% → 70% | 70% → 64% | the Boxer 0.8 (0.4) | the Boxer 11.0 (4.0), the Counter-striker 13.9 (5.7) |
| Wrestler vs Boxer | Wrestler 64% → 68% | 72% → 65% | none | the Boxer 2.0 (1.0) |
| Muay Thai vs Boxer | Muay Thai 56% → 58% | 98% → 99% | none | Muay Thai 3.8 (1.4), the Boxer 1.7 (0.7) |

Across the 1,500 fights: finished 62% → 57%, draws 0.1% → 0.2%, 10-10 rounds 0%. The #14 exit test still passes: the Boxer wins
54% against the Kicker (main 55%). Before the Kicker could hide his kicks it was 59%: the Boxer checked 3.3 of 7.9 kicks a fight
and the Kicker, learning, threw fewer. Kyle was asked whether to keep that and picked "Kicker hides kicks better"; `hidden_by` 1.0
overshot (52% the Kicker), 0.5 gives 46/54.

What it says:
- **Fewer finishes, as covering up should give.** A rocked man covers up two times in five (an average Fight IQ), and shots on his guard do half
  the damage and don't count for the referee.
- **The check is the Muay Thai fighter's and the Boxer's answer to the Kicker:** they check about 8 low kicks a fight; 2 to 3 in
  10 of the Boxer's work and 4 in 10 of the Muay Thai fighter's (his Kicking is the edge).
- **The slip makes the Boxer and Counter-striker fights cagier,** with a handful of slips a fight each.
- **The Muay Thai fighter needed retuning.** The Boxer covering up and slipping put Muay Thai vs Boxer at 70% (from 56%); his
  `clinch_entry` tendency is 3.0 now (was 3.25), which brings it to 58% and leaves Muay Thai vs Kicker at 77%.

The golden fights (§2.2) were re-pinned: three of the four change (the Boxer checks and slips, rocked fighters cover up).

### 38.4 To change it, and the tests
- The moves: `data/actions/check_kick.json`, `slip.json`, `cover_up.json` (timing, odds, `against_strikes`, `hidden_by`, `head_share`, who has
  it: `basic`, or the fighters' `techniques`). The openings they leave: `SLIPPING` on the uppercut, `COVERED` on the body hook,
  body kick and knee.
- The check's damage and the slip's counter: `CHECK_KICKER_SHARE`, `CHECK_SHIN_SHARE`, `CHECK_STUCK_TICKS`, `SLIP_COUNTER_TICKS`,
  `SLIP_COUNTER_BONUS` at the top of `sim/fight/fight_sim.gd` (`_strike_defended`); the guard and the referee in `_land_strike`
  and `_referee`.
- The AI: `GUARD_BASE`, `GUARD_PER_SD`, `COVER_BASE`, `COVER_PER_IQ` in `sim/fight/fighter_ai.gd` (`_guard`, `_cover`);
  *Survive!*'s `cover_bonus` in `data/calls/survive.json`.
- The harness's *Defence* line (checks and slips tried and worked, hits on the guard) and its CSV columns: `sim/balance/`.
- The feed lines: `ui/fight_log_formatter.gd`.

Tested in `tests/sim/fight/test_striking_defence.gd` (who has which; a check in time stops a low kick and hurts the kicker's leg,
a good kicker hides his kicks from it, too early does nothing, it doesn't stop punches or body kicks; a slip in time makes a punch miss and leaves a counter, it's for
straight punches and the uppercut punishes it; through the guard half the head damage and the body open; a covered rocked man
has his hands up and the referee lets it go on; the AI checks what it reads, only a fighter who knows the slip slips and counters
off it, and covers up when rocked, always on *Survive!*).

## 39. The cage clinch: driving him to the fence, holding him there and getting off it (D220)
Kyle asked for fighters to be "pushed and held up against the cage more", leaning into the grapplers and dirty boxers
(2026-10-30). Before this the fence only mattered on the feet: fighters were backed onto it a lot (the Boxer was pinned 86% of
his standing time against the Pressure wrestler), but nobody walked anyone onto it in the clinch, and two fighters tied up along
the fence were both "pinned", so it changed nothing between them. Kyle picked who leans in (the Wrestler, Pressure wrestler,
Ground-and-pound wrestler, Dirty boxer and Muay Thai fighter), how much (about a fifth of their fights on the fence, a real part
of their game) and the balance rule (matchups inside 60/40 stay inside, and the ones already outside don't move further out). The
walk-up to the fence on the feet (cutting the cage off) is the *Cut the cage* work (D230–D239, §20.2); this section starts once
they're tied up. Every number is a first guess for the harness; each is a named constant or a data field, listed in §39.6. Planned next (not built): grips that decide these turns, so the man with the underhook turns the other round and it can go back and forth (D260, §40.4).

### 39.1 The moves
All three are *everyone*'s (`basic`), clinch moves, and don't change the position on their own.

| Move | Timing (telegraph · wind-up · active · recovery) | Odds (base + attack − defense stats) | What it does |
|---|---|---|---|
| Drive to the fence (`fence_drive.json`) | 0 · 0.2 · 0.3 · 0.2 s | 50% + (Clinch control, Strength) − (Clinch control, Strength). +10% on a head pulled down (the collar tie), −15% with his own pulled down | Walks the other man straight back, **1.5 m a second**, until his back is on the fence (or 4 m are used up). Still the clinch, chest to chest. The log says *"Dirty boxer DRIVES HIM TO THE FENCE"* |
| Spin off the fence (`spin_off.json`) | 0 · 0.2 · 0.2 · 0.2 s | 55% + (Clinch control, Footwork) − (Clinch control, Strength). −15% with his own head pulled down | **Only for the man held on the fence.** Turns the two of them round and comes away: they're standing, and it's the other man's back on the fence now |
| Turn him onto the fence (`turn_him.json`) | 0 · 0.2 · 0.3 · 0.2 s | 40% + (Clinch control, Strength) − (Clinch control, Strength). −15% with his own head pulled down | **Only for the man held on the fence, and only with an underhook** (D261, §40.9; +10% with both). Turns them round and keeps hold: still the clinch, the other man's back on it, the grips as they were |

### 39.2 Held on the fence
In the clinch, the man whose back is on the fence (within 0.5 m of it, and nearer it than the other man) is **held on the fence**
(the flag `HELD_ON_FENCE`). Tied up along the fence both can be within half a metre of it (`BACK_TO_CAGE` both, as before); only
the one with his back to it is held. On the feet nobody is held: that's still `BACK_TO_CAGE` (§18).

| | What changes | Where it lives |
|---|---|---|
| **He carries the weight** | 0.1 stamina a second more than the clinch already costs (0.4) | `FightSim.FENCE_HOLD_DRAIN_PER_S` |
| **Knees and short punches** | The holder's knee, short uppercut and short hook are +5% on him | the `HELD_ON_FENCE` opportunity in `knee.json`, `short_uppercut.json`, `short_hook.json` |
| **Getting out** | He breaks at −10% (−15% until D220, when it counted for both men along the fence); or spins off, or turns him (§39.1) | the `own_flag` `BACK_TO_CAGE` opportunity in `clinch_break.json` |
| **The judges** | Time with the other man pinned on the fence scores control, as it already did (§11, `Judging.FENCE_CONTROL_PER_S`) | unchanged |
| **A level change off it** | His own double leg from the clinch is +15% with his back on the fence (the fence holds him up for the shot). Without it the Wrestler held there by the clinch fighters lost 11–12 points of wins against each of them | the `own_flag` `HELD_ON_FENCE` opportunity in `double_leg.json` |

Takedowns from the clinch on a man on the fence keep their +15% (§21.1).

### 39.3 A shot on the fence
A double leg at a man whose back was on the fence as it made contact, that **half works**, leaves the shooter on him, tied up
against the fence (the clinch) one time in four, instead of the scramble: *"Wrestler's Double-leg takedown doesn't get him down,
but he PRESSES HIM ON THE FENCE"*. No takedown points. It's the `pressed` transition in `data/positions/standing.json`
(`09`), on a chance of `FightSim.PRESSED_CHANCE` (0.25). At 0.5, and with stuffed shots pressing him too, it put the Pressure
wrestler at 90% against the Boxer (from 76%).

### 39.4 The fighter AI and who leans in
How much a fighter likes fighting on the fence is his **`fence_drive` tendency** (1 when it isn't set): it's how often he picks
the drive, like any move's tendency, and how long he stays once he has the other man there.

| Where | What the fighter does | To change it |
|---|---|---|
| In the clinch, in open space | Picks the drive by its tendency and odds. Never drives a man already held on the fence, or while a drive is under way | `fence_drive` in a fighter's `tendencies` |
| Holding him on the fence | Breaks only 1 / `fence_drive` as often (he stays), and works his knees, short punches and shots from there | `FighterAI.fence_liking()`; `FENCE_WORK` (1.0: no extra work rate, see §39.5) |
| Held on the fence himself | Spins off by how little he likes the clinch (the break's weight, 1 − Base/100 − Range/200), turns him by how much he likes it (`clinch_liking`) | `_tied()` in `sim/fight/fighter_ai.gd` |

Who leans in (Kyle's pick): the Ground-and-pound wrestler at `fence_drive` 3, the Pressure wrestler at 2, the Wrestler, the
Dirty boxer and the Muay Thai fighter at 1.5. Everyone else is at 1. Two things tried and taken out: tying up an opponent already pinned on
the feet × `fence_drive` more often (it doubled the Dirty boxer's clinches against a Boxer he has on the fence 86% of the time,
and put him at 78%), and holders working 1.25 × as often. The Dirty boxer's Clinch striking is **60 (was 65)**, to keep him
near his old 65% against the Boxer now that he can hold him there.

### 39.5 Balance
Harness, no calls, 200 fights a pairing, seed 1, pro rules: main (D180) → now. Wins are the first-named fighter's; *held* is
the share of the fight he had the other man on the fence in the clinch (the **Cage** line).

| Pairing | Wins: main → now | Held on the fence now | Inside 60/40? |
|---|---|---|---|
| Kicker vs Boxer | 45% → 45% | – | yes, unchanged |
| Wrestler vs Kicker | 51.5% → 51.5% | 0% | yes, unchanged |
| Wrestler vs Boxer | 65% → 65.5% | 0.3% | outside, unchanged |
| Pressure wrestler vs Kicker | 95% → 96.5% | 0.1% | outside, about the same |
| Pressure wrestler vs Boxer | 73.5% → 77% | 2.8% | outside, **3.5 points further** |
| Ground-and-pound wrestler vs Kicker / Boxer | 81% / 85% → 80.5% / 83.5% | 0.1% / 0.2% | outside, unchanged |
| Dirty boxer vs Kicker | 12.5% → 12.5% | 1.4% | outside, unchanged |
| Dirty boxer vs Boxer | 62% → 67.5% | **40%** | outside, **5.5 points further** |
| Dirty boxer vs Wrestler | 59% → 59% | 11.5% | yes, unchanged |
| Dirty boxer vs Muay Thai | 19% → 54% | 34% | **now inside** |
| Muay Thai vs Kicker | 79% → 75.5% | 1.6% | outside, closer |
| Muay Thai vs Boxer | 53% → 55% | 9.4% | yes |
| Muay Thai vs Wrestler | 66.5% → 70.5% | 7.1% | outside, **4 points further** |
| Judoka vs Boxer | 69.5% → 73% | 6.8% (he doesn't lean in: these start on the fence) | outside, **3.5 points further** |
| Judoka vs Wrestler | 77% → 85.5% | 6% | outside, **8.5 points further** |
| BJJ vs Boxer | 56.5% → 57.5% | 0.4% | yes |
| Sambo vs Boxer | 68.5% → 63% | 0% | outside, closer |

What it says:
- **The clinch fighters live on the fence now.** The Dirty boxer has the Boxer's back on the fence for 40% of the fight and the
  Muay Thai fighter's for a third; the Muay Thai fighter holds the Boxer there about a tenth of the fight (with about 5 drives).
- **The wrestlers hardly get there yet (0–3%).** They shoot from where they stand rather than tie up, and against the Kicker
  and the Boxer the opponent is seldom pinned in reach of a clinch: getting him there is the walk-up (*Cut the cage*, D230–D239).
  Weighting their clinch entries on a pinned man by their liking for the fence didn't move it (and put the Dirty boxer at 78%
  against the Boxer when it applied to him), so it was taken out.
- **Inside 60/40 stays inside**, and Dirty boxer vs Muay Thai comes in from 19/81. **Five matchups that were already outside moved
  3.5–8.5 points further out** (the Dirty boxer and the Pressure wrestler against the Boxer, Muay Thai and the Judoka against the
  Wrestler, the Judoka against the Boxer); Kyle's rule said they shouldn't; shown the five, he kept them as they are (2026-10-30, "Fine as it is"). 100-fight runs
  swing ±5 points, so read these at 200 fights or more.
- Tuning tried, so nobody walks the same dead ends: the man on the fence tiring 0.4 a second and the holder's knees +10% (the Dirty
  boxer at 86–92% against the Boxer); spin-offs that only turned him round, so the striker never got out (the same); a stuffed shot
  on the fence pressing him there half the time (the Pressure wrestler at 90% against the Boxer).

Golden fights (§2.2): one of the four changes (Wrestler vs Boxer with the sprawl rule: the Boxer holds the Wrestler on the fence
now and then and spins off it), re-pinned.

### 39.6 To change it, and the tests
- The moves: `data/actions/fence_drive.json` (`clinch.drives_m`, 4), `spin_off.json`, `turn_him.json` (`clinch.turns`; `09`
  action@2); the spin-off comes away because `data/positions/clinch.json` sends it to standing.
- Held on the fence: `FightSim.held_on_fence()`, `HELD_ON_FENCE`, `FENCE_HOLD_DRAIN_PER_S` (0.1), `DRIVE_SPEED` (1.5 m/s),
  `_drive_step()`, `_turn()`; the knee and short-punch bonuses in their files; the break in `clinch_break.json`.
- A shot on the fence: `FightSim.PRESSED_CHANCE` (0.25), `_pressed_on_fence()`, the `pressed` transition in `standing.json`.
- The AI: `FighterAI.fence_liking()`, `FENCE_WORK`, the `clinch_break`, `fence_drive`, `spin_off` and `turn_him` cases in `_tied()`;
  who leans in: `fence_drive` in `data/fighters/*.json`.
- The harness: a **Cage** line for every pairing (time each fighter held the other on the fence, drives and spin-offs tried and
  won) and CSV columns `fence_hold_*`, `fence_drives_*`, `fence_drives_won_*`, `spin_offs_*`, `spin_offs_won_*` (spin-offs
  count turning him too).
- The feed lines: `ui/fight_log_formatter.gd`.

Tested in `tests/sim/fight/test_cage_clinch.gd` (who is held, along the fence only the one nearer it, not on the feet; he tires
faster; the knees and short punches; the judges; a drive walks him back at its pace onto the fence and stops when the clinch
does; spinning off comes away with the other man on the fence, turning him keeps the clinch, only the man on the fence can do
either; a shot on the fence that half works presses him there about a quarter of the time, never in open space; the AI drives
by its liking, never a man already there, stays when it likes it, works to get off it; who leans in; the Dirty boxer holds
the Boxer on the fence in real fights), `tests/sim/balance/test_balance_report.gd` (the Cage line), `tests/ui/test_fight_log_formatter.gd`
and `tests/data/test_data_files.gd` (`drives_m`, `turns`, a required `HELD_ON_FENCE`, the `pressed` result).

## 40. Grips and hand fighting (D260 the plan; built: D261 the clinch grips, D262 turning each other on the fence, D263 grips in the guard and half guard, D264 frames, the crucifix and two hands on the choke, D265 the Hand fight! call)
Kyle asked for it (2026-10-31): "clinch fighting improvements: fighters should be hand fighting, trying to get underhooks,
overhooks, they should be spinning each other around when up against the cage", with research on real clinch and cage
fighting, and then: "this isn't clinch specific, this will be used for grappling in general, so hand fighting on the ground
and fighting in the clinch". §40.1–§40.8 are the plan (Kyle's answers at the top of §40.8); §40.9 is the first part as built,
the grips in the clinch (D261); §40.10 the second, turning each other round on the fence (D262); §40.11 and §40.12 the ground
(§40.5: D263 the guard and half guard, D264 frames, the crucifix and two hands on the choke); §40.13 the call (§40.7, D265). Every number is a first guess for the harness.

### 40.1 What real fighters do
From MMA and grappling coaching write-ups (sources at the end of §40):

- **The clinch is a fight for the inside.** An *underhook* is an arm under his arm with the hand on his back or shoulder. It
  controls his upper body and his level: it sets up the double and single leg, trips and throws, knees and short punches, and
  it walks him to the fence. The double underhook (or a body lock, the hands joined behind him) is the best grip there is.
- **The overhook is the answer to the underhook.** The man whose arm is underhooked clamps over the top of it (the *whizzer*):
  it stops the level change on that side, sets up throws (Khabib threw Dos Anjos off the fence from a whizzer and the far
  wrist), and is the side he turns away on to get free. It's the weaker grip, but it keeps the other man honest.
- **Pummeling** is how the inside changes hands: the man with the overhook swims that arm inside to an underhook, which gives
  the other man the outside on that side, and he swims back. It goes on until one of them has the inside and does something
  with it. What wins a pummel: head position (forehead in his jaw or chest so his posture stays tall), the hips close,
  changing level, and pressure forward.
- **On the fence it goes both ways.** The man held there wants an underhook (both if he can) and his head position, and with
  them he turns the other man round onto the fence; without them he circles toward the overhook side to get off. The man
  holding him keeps his head under the chin, blocks the leg or reaches across to stop the turn, re-pummels, or changes level
  for a shot (the fence stops him getting his hips behind the defender, but it also stops the defender sprawling). That is the
  "spinning each other round" Kyle asked for: a reversal is a won underhook, and the man just turned can win one back.
- **Hand fighting is grips against grips.** Before and between attacks, each fighter strips the other's grips and takes his
  own: wrist control and the two-on-one (both hands on one wrist), posting on the biceps, forearm frames, the collar tie and
  breaking it. The first good grip leads the attack. Strikers in the clinch use frames, bicep pushes and the collar tie to
  turn the other man side-on and open a way out.
- **The ground is the same fight.** Underneath, a fighter controls the wrists and biceps to stop ground and pound, breaks the
  top man's posture (a collar tie, pulling the head down) to set up holds, frames to make space to get up or put the guard
  back, and fights for the underhook in half guard (it lets him come up, take the back or sweep). On top, a fighter postures
  up and strips the wrists to strike, pins a wrist (a crucifix) to hit an arm that can't defend, and takes his own underhook
  and a crossface to flatten him and pass.
- **What gets counted in real fights.** UFC Stats counts clinch strikes, control time and reversals (bottom to top on the
  ground), but not grips, pummels or turns on the fence, so how often these happen in the game is our call, not a number to
  copy.

### 40.2 What the game does now
- **The clinch is one position** (D98's trim, §21). Inside it, one grip is held from one move to the next: the collar tie
  (D129, §27), the head pulled down for 4 s. The rest are single rolls: knees, short punches, the break, the double leg, the
  throws (§26), the drive to the fence, and, for the man held on the fence only, spinning off or turning him (D220, §39).
  Nothing says who has the underhooks, so a turn on the fence doesn't need one and doesn't change one.
- **The ground has one hand fight**: the tie-up from the bottom (D121, §24.3), which breaks the top man's posture for 3 s and
  stops his ground strikes. Passes, escapes, sweeps and getting up are rolls on stats; no grip helps or hurts them.
- So "who is winning the clinch" is only "whose back is on the fence", and two grapplers tied up look the same whoever is
  better at it.

### 40.3 The idea: two sides, and who has the inside on each
The proposal keeps the clinch as one position and adds **grips** to it, the way the collar tie added a grip to it. Two fighters
chest to chest have two *sides* (his left arm meets your right, his right meets your left), and on each side one of them has
the inside:

| On a side | It's called | What it gives the man with it |
|---|---|---|
| Your arm under his | an **underhook** (and his is an overhook) | Drives and turns on the fence, the double leg and body-lock trips, knees to the body; he can't change level on that side |
| Your arm over his | an **overhook**, the whizzer | Stops his shot from that side (the sprawl and the shot's odds), overhook throws, the side you turn away on to get off the fence |
| Neither (hands fighting, no grip yet) | **hand fighting** | The free hand punches (dirty boxing) and frames; it's where the clinch starts |
| Your hand on his wrist (or both, a two-on-one) | **wrist control** | That arm of his can't punch or pummel; it opens the break, and on the ground it stops his strikes |
| Your hand behind his head | the **collar tie** (D129) | As now: his head pulled down, knees to the head |

Both underhooks is the **body lock**: the best place for a trip, a throw, a double leg or a drive, and he can barely punch.
One each is **over-under**, the even standoff of wrestling. The grips last until stripped or until the position changes, so
the clinch has a state worth fighting over, which is what makes hand fighting a thing to watch and to coach.

**Pummeling** is one quick clinch move (*everyone*'s): swim one arm inside. Its odds are Clinch control and Strength against
the same, with head position (whoever has more underhooks already) and being tired or hurt swaying it. It works: you have the
inside on that side and he has the overhook. It fails: you're a touch late on everything for a moment (an opening for a knee
or a short punch). A *strip* (*everyone*'s) takes one of his grips off, wrist control or the collar tie included, and is how a
striker gets back to hand fighting so he can break or punch.

### 40.4 On the fence: spinning each other round (builds on D220, §39)
- **Turning him needs an underhook.** *Turn him onto the fence* (§39.1) only works with an underhook (better with two); the
  overhook side is where *spin off* goes, as in the real fight. Today they need nothing.
- **The holder fights the turn.** His own underhook on that side, his head position (more underhooks), and blocking the turn
  (a new answer: reading it coming, like a sprawl reads a shot) make the turn harder; failing gives the other man a moment.
- **It goes back and forth.** The man just turned is now the man held, with the same chances: if he wins the underhook back,
  he turns it again. The harness counts turns per minute on the fence, so we can see whether the clinch fighters spin each
  other round or just lean.
- **The level change.** The double leg on the fence gets the body lock's and the underhook's bonus; the overhook (whizzer) is
  the held man's answer to it.

### 40.5 On the ground: the same grips, different jobs
| Where | Underneath | On top |
|---|---|---|
| Full guard | **Wrist control** stops the top man's punches from that hand; the **collar tie** breaks his posture (it replaces the blanket tie-up, D121, with two real grips) and helps the triangle and armbar | **Posture up** strips a grip; with both hands free he grounds and pounds as now |
| Half guard | **His underhook** helps him come up, take the back and sweep; **frames** help him put the guard back | **His underhook and crossface** flatten the bottom man and help the pass; without them the pass is harder |
| Side control and mount | **Frames** help every escape (recover guard, bridge and roll) | **Pinning a wrist** (the crucifix) means that arm can't defend his ground strikes or frame |
| The back | **Two hands on the choking arm** (a two-on-one) defend the rear-naked choke | **Hand fighting the defending hands** away sets up the choke |

The ground grips use the same idea (held until stripped or the position changes) and the same few moves, so the AI, the feed
and the harness read the same way standing and down.

### 40.6 Who fights for which grip
| Fighter (or style) | What he wants | Why |
|---|---|---|
| Wrestler, Pressure wrestler, Ground-and-pound wrestler | Underhooks, the body lock | Drives, turns and shots on the fence; the pass on the ground |
| Dirty boxer | One underhook or overhook and a free hand | Short punches from over-under, without having to win the body lock |
| Muay Thai | The collar tie (the plum) | Knees to the head; against a wrestler he strips underhooks to get back to it |
| Judoka | An overhook and a wrist, or the body lock | Throws and trips |
| BJJ | From underneath: wrists and the collar tie | Breaks posture for holds; standing he pulls guard |
| Boxer, Kicker, Karate, Counter-striker | Wrist control, frames, strips | Get back to hand fighting and out of the clinch; on the ground, wrists to stop the punches and frames to get up |
| Sambo | Underhook, then the level change | Trips, then the legs |

Each fighter's liking for each grip would be a tendency in his file (like `fence_drive`), and the style sheets (D160, `03`
§7.1) would carry it to generated opponents.

### 40.7 The rest: calls, stats, screen, harness, camp
- **Calls.** The catalogue already lists *Underhooks against the cage* under *Clinch* and *Whizzer* under *Defend the shot*
  (§6.4). Key 5 in the clinch is *Collar tie!* today; a grip call needs a key (§40.8, question 4).
- **Stats.** Clinch control already means "winning clinch position, pinning to the cage, breaking free" (`11` §2.2), and Top
  control and Guard have the ground. A separate *Hand fighting* stat, like Cage cutting (D230), is the other way (question 3).
- **On screen.** First the feed: *"Wrestler WINS THE UNDERHOOK on the left: he has both now"*, *"Boxer STRIPS THE WRIST and
  frames off"*. Then a small grip readout on the HUD's position diagram (`06` §6.10). Grips on the fighters' hands in the 3D
  view wait for the work on separate arms and legs, which this plan doesn't touch.
- **Harness.** A **Grips** line per pairing: the share of clinch time each fighter had each grip, pummels tried and won,
  strips, turns on the fence per minute there, and on the ground the share of top time with a hand free to strike.
- **Camp.** A *Pummeling* session (drill: clinch control and strength) and later a minigame; for the camp thread to pick up.
- **Balance.** As D220 unless Kyle says otherwise: matchups inside 60/40 stay inside, the ones outside don't move further out,
  golden fights re-pinned with a reason, read at 200 fights or more.

### 40.8 The plan and the questions for Kyle
The work splits into pull requests, each with its harness numbers and its own decision row (D261 on; this thread has D260–D269):

1. **Clinch grips**: the two sides, underhooks, overhooks, hand fighting, wrist control; pummel and strip; the grips feed the
   clinch moves already there (drive, knees, short punches, double leg, throws, break); the collar tie folds in.
2. **The fence**: turning him by the underhook both ways, spinning off on the overhook side, the holder's answers, the whizzer
   against the shot on the fence.
3. **Ground grips**: wrist control and posture in the guard, the half-guard underhook and crossface, frames, the wrist pin, the
   hands against the choke.
4. **Calls and the screen**: the grip call(s), the AI corner using them, the HUD readout; the hands in 3D after the limbs work.

**Kyle's answers (2026-10-31, D260):** 1 the two sides (a); 2 the clinch and the fence first; 3 no new stat; 4 one
*Hand fight!* call. Questions 5–7 went with the recommendation unless he says otherwise: turns on the fence come out of the
odds and are reported, D220's balance rule stands, and the collar tie stays its own grip with its timer.

The questions as they were asked:

1. **How deep?** (a) the two sides as above (recommended); (b) one "who's winning the clinch" meter, simpler but nothing to
   see change hands; (c) each hand separately with its own grip, the most detail and closest to the separate-limbs work, but
   about twice the moves and much harder to read and balance.
2. **What first?** The clinch and the fence (recommended, it's the ask and builds on D220), the ground first, or all of it in
   one big pull request.
3. **A new stat?** Use Clinch control on the feet and Top control and Guard on the ground (recommended: no new stat to train
   or scout), or a new *Hand fighting* stat some fighters are known for.
4. **What does the player call?** One *Hand fight!* call that goes for whatever grip the fighter's style wants (recommended:
   one key, his own game), or separate *Underhooks!*, *Whizzer!* and *Wrists!* calls (more control, more keys).
5. **How often should they spin round on the fence?** Let it come out of the odds and report it, or aim for a number (for
   example the held man turning it about once every 30 s on the fence).
6. **The balance rule**: keep D220's (inside 60/40 stay inside, outliers don't get worse)?
7. **Does the collar tie stay as it is** (a grip with its own timer) or become one of the grips (held until stripped)?

### 40.9 Built: grips in the clinch (D261)
The first pull request of §40.8's plan: the two sides, the pummel and the strip, and what the grips do to the clinch moves that
were already there. Wrist control moved to the ground part (PR 3), where it does most of its work (stopping ground and pound);
in the clinch the strip is the striker's way back to hand fighting for now.

**The state.** The clinch has two sides; on each, one fighter has the inside (an underhook) or neither does. A new clinch starts
with neither (hand fighting). The grips stay through drives and turns on the fence and go when the clinch ends (a break, a
takedown, a knockdown, the bell). A double leg that half works on the fence and presses him there (D220, §39.3) comes up with
an underhook. Fighters carry three flags from it: `UNDERHOOK` (at least one), `BODY_LOCK` (both) and `OVERHOOK` (the other man
has an underhook on him: his whizzer).

| Move (*everyone*'s) | Timing (telegraph · wind-up · active · recovery) | Odds (base + attack − defense stats) | What it does |
|---|---|---|---|
| Pummel for the underhook (`pummel.json`) | 0 · 0.1 · 0.2 · 0.2 s | 45% + (Clinch control, Strength) − (Clinch control, Strength). +5% with an underhook already (head position), +10% on someone `HANDS_LOW`, −15% with his own head pulled down | Swims an arm inside: on the side where the other man has the inside if he has one (his underhook becomes the overhook), otherwise on a free side. Two is the body lock. *"Wrestler WINS THE UNDERHOOK: he has both now, the BODY LOCK"* |
| Strip the underhook (`strip_grip.json`) | 0 · 0.1 · 0.2 · 0.2 s | 50% + (Clinch control, Footwork) − (Clinch control, Strength). Only with an underhook on him; −10% against the body lock, −15% with his head pulled down | Takes one of his underhooks off: that side is back to hand fighting. *"Boxer STRIPS THE UNDERHOOK: back to hand fighting"* |

What the grips do to the other clinch moves:

| Move | With your underhook · body lock (on top of it) | With his grip on you | Why |
|---|---|---|---|
| Drive to the fence | +10% · +10% more | his underhook: −10% | The underhook walks him back; his stops you |
| Turn him onto the fence | **needs an underhook** · +10% more | – | Turning the corner off the underhook (*"can't: he needs an underhook first"*) |
| Spin off the fence | your overhook: +10% | his body lock: −20% | You turn away on the whizzer side; the body lock holds you there |
| Double leg (from the clinch) | +5% · +10% more | his body lock: −15% | The level change off the underhook; you can't change level in his body lock |
| Outside trip | +5% · +10% more | his body lock: −10% | |
| Hip throw | +5%; your overhook: +10% | – | The overhook throw |
| Knee | +5% | – | Knees off the underhook |
| Short hook, short uppercut | your body lock: −10% (both hands round him); your overhook: +5% (a free hand) | his body lock: −10% | Smothered in a body lock; dirty boxing off the whizzer |
| Clinch break | +5% | his body lock: −15% | |
| Collar tie | your body lock: −10% | his body lock: −10% | Your hands are round his body, or his are round yours |

**The fighter AI.** The grips are there to see (the AI counts them in its odds, like the fence). It pummels by how much it likes
the clinch (`clinch_liking`, at least 0.2), more for each underhook the other man has, and never with the body lock already;
it strips by how much it wants out (the break's weight), more for each underhook on it. Held on the fence it pummels 1.5 × as
often (the underhook is how it turns him), and turns him (1 + its underhooks) × as often. The Muay Thai fighter would rather have
the collar tie: `pummel` 0.5 and `strip_grip` 1.5 in his file. Everyone else is at 1 for both.

**Balance.** Harness, no calls, 200 fights a pairing, seed 1, pro rules: main (D253, 630b0e5) → with D261 (before D262's
changes; the numbers with both are in §40.10). *Grips* is the share of the
clinch each fighter had at least one underhook (both in brackets), red · blue; *turns* are spin-offs and turns on the fence a
fight, both fighters. Kicker vs Boxer never clinches, so it plays out exactly as before.

| Pairing | Wins (first-named): main → now | Finishes | Grips (red · blue) | Turns on the fence |
|---|---|---|---|---|
| Kicker vs Boxer | 44.5% → 44.5% | 35% → 35% | – | – |
| Wrestler vs Kicker | 73% → 73% | 40% → 40% | 4.9% · 0.2% | 0 → 0 |
| Wrestler vs Boxer | 77.5% → **68%** | 52% → 52% | 33.9% (10.7%) · 5.0% | 0.4 → 0.8 |
| Pressure wrestler vs Kicker | 93.5% → 94.5% | 68% → 68% | 6.4% · 0.9% | 0.1 → 0.1 |
| Pressure wrestler vs Boxer | 87% → 83% | 32% → 36% | 38.0% (13.8%) · 6.8% | 2.8 → 3.2 |
| Ground-and-pound wrestler vs Kicker | 89.5% → 89.5% | 92% → 94% | 3.6% · 0.3% | 0.1 → 0 |
| Ground-and-pound wrestler vs Boxer | 86.5% → 80% | 83% → 78% | 19.6% (5.3%) · 3.8% | 0.3 → 0.4 |
| Dirty boxer vs Kicker | 19% → 18% | 17% → 14% | 12.1% · 2.3% | 1.4 → 1.5 |
| Dirty boxer vs Boxer | 67% → 70% | 99% → 93% | 26.8% (7.5%) · 12.0% | 7.0 → 6.9 |
| Dirty boxer vs Wrestler | 72% → 76% | 26% → 26% | 21.0% (3.7%) · 47.5% (17.2%) | 3.6 → 4.3 |
| Dirty boxer vs Muay Thai | 38.5% → **49%** | 82% → **55%** | 30.0% (8.3%) · 16.8% (2.0%) | 8.4 → 9.6 |
| Muay Thai vs Kicker | 87.5% → 90% | 32% → 27% | 7.7% · 2.0% | 1.0 → 1.1 |
| Muay Thai vs Boxer | 64.5% → 65.5% | 89% → 78% | 11.1% · 9.7% | 4.0 → 4.3 |
| Muay Thai vs Wrestler | 70% → 66.5% | 58% → 46% | 6.7% · 40.6% (14.8%) | 1.9 → 2.4 |
| Judoka vs Boxer | 69.5% → 64.5% | 48% → 50% | 10.8% · 1.6% | 1.3 → 1.4 |
| Judoka vs Wrestler | 96.5% → 97% | 28% → 22% | 21.2% (4.6%) · 21.7% (4.7%) | 1.1 → 0.7 |
| BJJ vs Boxer | 81% → 80% | 72% → 70% | 16.0% · 2.7% | 0.4 → 0.4 |
| Sambo vs Boxer | 86.5% → 88% | 70% → 68% | 15.9% · 2.9% | 0.2 → 0.3 |

What it says:
- **The grapplers win the inside**: the Wrestler and the Pressure wrestler have an underhook about a third of their clinch time
  against the Boxer, the body lock a tenth; strikers seldom do. The Wrestler against the Dirty boxer and the Muay Thai fighter
  has the underhooks over 40% of the time, and the Muay Thai fighter, who goes for the collar instead, hardly ever does.
- **Kyle's balance rule (D220's) holds within the dice.** Kicker vs Boxer is unchanged. Dirty boxer vs Muay Thai comes inside
  60/40 (38.5 → 49%, a real change seed by seed). Six outliers come closer to even (the Wrestler, the Ground-and-pound wrestler,
  the Pressure wrestler and the Judoka against the Boxer, Muay Thai against the Wrestler); a few move 1–4 points further out
  (the Dirty boxer against the Boxer and the Wrestler, Muay Thai against the Kicker), and seed by seed those are inside the
  dice (the Dirty boxer's +3 and +4 both have ranges that cross 0, `tools/balance_compare.gd`).
- **Fewer finishes in the clinch fights**: a body lock smothers the short punches and the collar tie is harder against it, so the
  Muay Thai and Dirty boxer fights go to the cards more (Dirty boxer vs Muay Thai 82 → 55% finished).
- **Turns on the fence happen about as often as before**, but now they come off the underhook, and the man just turned can win
  one and turn it back. Shown that, Kyle asked for about twice as many (D262, §40.10).
- The sim is about 7% slower a tick in the harness (121 → 129 µs, D105) in these clinch-heavy pairings.

Golden fights (§2.2): one of the four changes (Wrestler vs Boxer with the sprawl rule and the AI corner: a decision now, was a
submission in round 2), re-pinned.

**To change it.**
- The moves: `data/actions/pummel.json`, `strip_grip.json` (`clinch.grip`: `"inside"` or `"strip"`, `09` action@2); what the
  grips do to the other moves: the `UNDERHOOK`, `BODY_LOCK` and `OVERHOOK` opportunities in their files (`fence_drive`,
  `turn_him`, `spin_off`, `double_leg`, `outside_trip`, `hip_throw`, `knee`, `short_hook`, `short_uppercut`, `clinch_break`,
  `collar_tie`); the flags in `data/enums/flags.json`.
- The state: `FightSim._grips`, `underhooks()`, `grips()`, `set_grips()`, `_take_grip()`, `_grip_flags()`; the pressed shot's
  underhook in `_pressed_on_fence()`.
- The AI: `FighterAI.GRIP_MIN` (0.2), `GRIP_PER_HIS` (1.0), `FENCE_PUMMEL` (1.5), `FENCE_TURN` (3.0, D262), the `pummel`, `strip_grip` and `turn_him` cases
  in `_tied()`; who wants which: `pummel` and `strip_grip` in a fighter's `tendencies`.
- The harness: a **Grips** line for every pairing and CSV columns `underhook_*`, `body_lock_*`, `pummels_*`, `pummels_won_*`,
  `strips_*`, `strips_won_*`. The feed lines: `ui/fight_log_formatter.gd`.

Tested in `tests/sim/fight/test_grips.gd` (a new clinch starts hand fighting; the underhook, the overhook and the body lock;
grips only in the clinch and gone when it ends; the pummel takes his side first, then a free side, and nothing with the body
lock; the strip, and nothing to strip without an underhook on you; what the grips do to the drive, the turn, the spin-off, the
takedowns and throws, the short punches, knees and the break; turning him needs an underhook and keeps the grips so he can turn it
back; the pressed shot's underhook; the AI pummels by its liking and never with the body lock, a striker strips more; the
Wrestler wins underhooks against the Boxer in real fights), `tests/sim/fight/test_cage_clinch.gd` (turning him now with an
underhook), `tests/sim/balance/test_balance_report.gd` (the Grips line), `tests/ui/test_fight_log_formatter.gd` and
`tests/data/test_data_files.gd` (`clinch.grip`, a required `UNDERHOOK` or `OVERHOOK`).

### 40.10 Built: turning each other round on the fence (D262)
Shown D261's numbers (turns on the fence about as often as before), Kyle picked "about twice as often" (2026-10-31). What
changed, on top of §40.9:

| | What it does | Where it lives |
|---|---|---|
| **He turns it more off the underhook** | Held on the fence with an underhook, a fighter turns him 3 × as often as in D261, liking the clinch or not (at least 0.2, so a striker with an underhook turns too). Without one he pummels for it 1.5 × as often (D261) | `FighterAI.FENCE_TURN` (3.0), `GRIP_MIN`; the `turn_him` case in `_tied()` |
| **The holder's answers** | His own underhook on the other side (over-under) makes the turn −10%. Holding a man who has an underhook, he re-pummels 1.5 × as often to take it away before it's turned on him; a strip does the same for a striker | the `UNDERHOOK` opponent opportunity in `turn_him.json`; the `pummel` case in `_tied()` (`FENCE_PUMMEL`) |
| **The underhook leads to the shot** | The double leg off an underhook is +10% (was +5%), +20% off the body lock: a wrestler who wins the inside shoots off it, instead of only pummelling. Without it the Wrestler lost 6–10 points against the Dirty boxer once turns went up | the `UNDERHOOK` own opportunity in `double_leg.json` |
| **Counted** | Turns on the fence (turning him and keeping hold) apart from spin-offs (turning and coming away): the **Grips** line's "turns him on the fence", CSV `turns_*`, `turns_won_*` | `FighterState.turns_tried`, `turns_won` |

Harness, no calls, 200 fights a pairing, seed 1, pro rules: main (D253) → with D261 and D262. *Turns* are turns on the fence
that keep the clinch, both fighters, a fight: with D261 alone (where measured) → now.

| Pairing | Wins (first-named): main → now | Finishes | Grips now (red · blue) | Turns: D261 → now |
|---|---|---|---|---|
| Kicker vs Boxer | 44.5% → 44.5% | 35% → 35% | – | – |
| Wrestler vs Kicker | 73% → 72.5% | 40% → 40% | 5.1% · 0.2% | 0 |
| Wrestler vs Boxer | 77.5% → 74% | 52% → 44% | 33.4% (9.7%) · 5.6% | → 0.6 |
| Pressure wrestler vs Kicker | 93.5% → 95% | 68% → 66% | 6.1% · 0.9% | 0 |
| Pressure wrestler vs Boxer | 87% → 79.5% | 32% → 36% | 37.6% (12.4%) · 6.4% | 0.2 → 0.4 |
| Ground-and-pound wrestler vs Kicker | 89.5% → 89% | 92% → 94% | 3.5% · 0.3% | 0 |
| Ground-and-pound wrestler vs Boxer | 86.5% → 83.5% | 83% → 80% | 19.6% (5.0%) · 3.6% | → 0.2 |
| Dirty boxer vs Kicker | 19% → 17% | 17% → 13% | 12.0% · 2.7% | → 0.1 |
| Dirty boxer vs Boxer | 67% → 68.5% | 99% → 96% | 29.9% (9.2%) · 11.6% | 0.4 → 1.1 |
| Dirty boxer vs Wrestler | 72% → 74% | 26% → 24% | 22.8% (4.1%) · 45.4% (13.8%) | 3.7 → 5.1 |
| Dirty boxer vs Muay Thai | 38.5% → **56.5%** | 82% → 50% | 32.0% (8.3%) · 17.2% (1.7%) | 2.6 → **5.2** |
| Muay Thai vs Kicker | 87.5% → 91% | 32% → 26% | 7.9% · 2.5% | 0 |
| Muay Thai vs Boxer | 64.5% → 70% | 89% → 84% | 12.5% · 10.1% | 0.4 → 0.8 |
| Muay Thai vs Wrestler | 70% → 65.5% | 58% → 44% | 7.4% · 40.0% (12.3%) | 2.0 → 2.8 |
| Judoka vs Boxer | 69.5% → 64% | 48% → 50% | 10.7% · 1.6% | 0 |
| Judoka vs Wrestler | 96.5% → 97.5% | 28% → 28% | 20.9% (4.3%) · 20.6% (3.8%) | → 0.9 |
| BJJ vs Boxer | 81% → 76.5% | 72% → 69% | 16.4% · 2.8% | → 0.2 |
| Sambo vs Boxer | 86.5% → 89% | 70% → 70% | 16.1% · 3.3% | → 0.3 |

What it says:
- **Turns that keep the clinch about doubled** where there's fence clinching to turn: Dirty boxer vs Muay Thai 2.6 → 5.2 a fight,
  the Dirty boxer vs the Boxer 0.4 → 1.1, Muay Thai vs the Boxer 0.4 → 0.8, the Pressure wrestler vs the Boxer 0.2 → 0.4. The
  Dirty boxer and the Wrestler 3.7 → 5.1 (the Wrestler turns most: he has the underhooks). Spin-offs (turning and away) are as
  they were.
- **Kyle's balance rule (D220's)**: Kicker vs Boxer unchanged; Dirty boxer vs Muay Thai is inside 60/40 both ways now (38.5% →
  56.5%); six outliers closer to even (the Wrestler, Pressure wrestler, Ground-and-pound wrestler, Judoka and BJJ fighter
  against the Boxer by 3–7.5 points, and Muay Thai against the Wrestler). Further out: **Muay Thai against the Boxer 64.5 →
  70%** (5.5 points; seed by seed the range crosses 0, so it may be the dice) and Muay Thai against the Kicker, the Sambo
  fighter, the Dirty boxer against the Kicker, the Boxer and the Wrestler, the Pressure wrestler against the Kicker and the
  Judoka against the Wrestler by 1–3.5 points, inside the dice.
- **Fewer finishes** in the clinch fights, as with D261 (Dirty boxer vs Muay Thai 82 → 50% finished, Muay Thai vs the Wrestler
  58 → 44%).
- The sim is about 5% slower a tick than main in the harness (121 → 127 µs, D105).

Golden fights (§2.2): the same one changes again (Wrestler vs Boxer with the sprawl rule and the AI corner: the Boxer by decision
now), re-pinned.

Tested in `tests/sim/fight/test_grips.gd` (his own underhook makes the turn harder; held on the fence with an underhook the AI
turns him, without one it fights for it; holding him there the AI re-pummels when he has one; the double leg off the underhook
and the body lock) and `tests/sim/balance/test_balance_report.gd` (turns on the Grips line).

Sources: [Evolve MMA, underhooks and overhooks](https://evolve-mma.com/blog/understanding-underhooks-and-overhooks-in-mma/),
[Evolve MMA, pummeling](https://evolve-mma.com/blog/what-is-pummeling-and-how-to-do-it-correctly-for-mma-training/),
[Evolve MMA, using the cage wall to escape](https://evolve-mma.com/blog/how-to-use-the-cage-wall-to-escape-takedowns-in-mma/),
[Fanatic Wrestling, getting off the wall with Zack Esposito](https://fanaticwrestling.com/blogs/news/get-off-the-wall-with-zack-esposito),
[Bloody Elbow, Gavin Tucker's clinch work](https://bloodyelbow.com/2020/12/17/mma-news-wrestling-breakdown-gavin-tucker-clinchwork-ufc-256),
[Evolve MMA, grip fighting in no-gi](https://evolve-mma.com/blog/heres-what-you-need-to-know-about-grip-fighting-in-no-gi-bjj/),
[Evolve MMA, ground and pound](https://evolve-mma.com/blog/the-complete-guide-to-ground-and-pound/),
[AgentMMA, what a reversal is in UFC stats](https://agentmma.com/mma-lab/ufc-reversal-stat-explained).

### 40.11 Built: grips on the ground, guard and half guard (D263)
The third pull request of §40.8's plan, the first half of the ground part. Kyle's picks (2026-10-31): the tie-up from the
bottom becomes real grips ("Replace it with grips"), ground finishes stay about where they are (he asked for the
recommendation over more ground and pound), and the guard and half guard come first ("Guard and half guard first"); frames,
the crucifix wrist pin and the two hands against the choke are next (§40.5's last two rows).

| | What it does | Where it lives |
|---|---|---|
| **The collar tie from underneath** | The tie-up (D121) is now held: his head is pulled down (`POSTURE_BROKEN`: the pass −10%, the triangle +15% as before), the punch he was winding up is smothered and he can't strike at all until he postures up or the position changes. Before, it wore off after 3 s. 45% + (Guard, Strength) − Top control, +15% when he's postured up, +10% with one of his wrists held. Taking it again while it's held is refused | `tie_up.json` (`ground.grip` `"collar"`) |
| **Wrist control** | Everyone underneath has it, in full guard, half guard and mount. One wrist held (`WRIST_HELD`): his ground strikes are −10% (the hammerfist −5%: it comes round the grip), the armbar +10%, the tie-up +10%. Both held (`WRISTS_HELD`): no ground strikes, as with the collar tie. 50% + (Guard, Strength) − Top control, +10% when he's postured up, −10% for the second wrist | `wrist_control.json` (`"wrist"`) |
| **Posturing up** | On top, everyone can posture up to strip a grip: the collar tie first, then a wrist. 60% + (Top control, Strength) − Guard, +10% when his hands are down or he's covering up. While he does it he's postured up (`POSTURED_UP`), so it opens the get-up, the tie-up and the armbar, as a ground punch does. Refused with nothing to strip | `posture_up.json` (`"posture"`) |
| **The half-guard underhook** | In half guard one man has the near-side underhook (`UNDERHOOK`), or neither. Underneath he digs for it (45% + (Guard, Strength) − (Top control, Strength), +10% when the top man is postured up); on top the crossface takes it (45% the other way, +10% when he's covering up, −10% with a wrist held). With it underneath: the get-up +10%, the sweep +15%, back to guard +10%, and the pass against him −15%. With it on top: the pass +15%, his get-up −10%, his sweep −10% | `dig_underhook.json`, `crossface.json`; the `UNDERHOOK` openings in `guard_pass`, `get_up`, `sweep`, `recover_guard` |
| **When they go** | Every ground grip goes when the position changes (a pass, a sweep, a get-up, the back), and with a new clinch | `FightSim._clear_grips()` |
| **The AI underneath** | Ties up as before (more when he's being hit, `TIE_UP_PRESSED`), grabs a wrist half as often as that (`FighterAI.WRIST_WEIGHT` 0.5), and in half guard digs for the underhook, more the more he likes being on top (`HALF_UNDERHOOK` × (1 + Base / 100)) | the `wrist_control` and `dig_underhook` cases in `_tied()` |
| **The AI on top** | Posturing up and the crossface are two of the ways he works position (`_work_position`, at its own pace, like a pass). Held by the head or both wrists he throws nothing until he's out; one wrist held he keeps punching with the other hand | `_pound()`, `_advance_reason()` |
| **The referee** | Tying him up so he can't punch counts as answering him, as the tie-up did (D121); one wrist or the half-guard underhook doesn't | `FightSim._take_ground_grip()` |
| **How they look** | Simple poses so each move shows (D282's rule: every move has a pose): both hands to his wrist, onto the side swimming the near arm in for the underhook, sitting up tall with the hands on his body, the forearm across his face | the `wrist_control`, `dig_underhook`, `posture_up` and `crossface` cases in `game/fighter_figure.gd` |
| **The feed and the harness** | "TIES HIM UP from the bottom", "CONTROLS A WRIST", "POSTURES UP out of the tie-up", "CROSSFACES HIM", "DIGS THE UNDERHOOK". The harness's **Ground grip** line: ties up and wrists won of tried, how much of the time on top he was held and how much with no punches, postures up, and the share of half guard each had the underhook; CSV `ground_ties_*`, `wrists_*`, `postures_*`, `half_uhs_*`, `held_top_*`, `tied_top_*`, `half_uh_*` | `ui/fight_log_formatter.gd`, `sim/balance/` |

**Finding the cause of fewer finishes.** The first version also had the man on top posture up on his own roll before he
punched. That cost the wrestlers 10–12 points of ground finishes (the Pressure wrestler against the Kicker 74 → 62%, the
Sambo fighter against the Boxer 77 → 66%), and pushed the Wrestler further out against the Dirty boxer and the Muay Thai
fighter (to 83.5% and 66.5% for them). Taking things out one at a time showed it wasn't the grips underneath (no wrist control,
no half-guard underhook, or no tie-up at all changed little): it was the turns the man on top spent posturing up instead of
punching. Posturing up as one of his position moves instead put the finishes back where they were. Two clinch tweaks tried
on the way (pummelling less) did nothing for the Wrestler, and were left out.

Harness, no calls, 200 fights a pairing, seed 1, pro rules: main (at #101: with the clinch grips, reset to the centre and
the career saves) → with D263. *Held on top* is the share of the grappler's time on top (the first-named, or the Wrestler)
that a grip held him, and in brackets with no punches at all; *ties* are collar ties won by the man underneath him a fight.
(The tuning above was measured against main at #91; the numbers below were run again on the latest main.)

| Pairing | Wins (first-named): main → now | Finishes | Held on top (no punches) | Ties |
|---|---|---|---|---|
| Kicker vs Boxer | 38% → 38.5% | 29% → 27.5% | – | – |
| Wrestler vs Kicker | 69% → 70.5% | 34% → 34% | 21.1% (16.4%) | 3.8 |
| Wrestler vs Boxer | 79% → 79.5% | 42% → 44.5% | 21.9% (17.5%) | 6.1 |
| Pressure wrestler vs Kicker | 95% → 93.5% | 68.5% → 74.5% | 20.8% (15.5%) | 5.3 |
| Pressure wrestler vs Boxer | 88% → 88% | 35% → 44.5% | 22.2% (17.5%) | 8.2 |
| Ground-and-pound wrestler vs Kicker | 87.5% → 84.5% | 87% → **74%** | 21.2% (16.7%) | 4.0 |
| Ground-and-pound wrestler vs Boxer | 86.5% → 84% | 75.5% → 77% | 22.7% (17.3%) | 5.3 |
| Dirty boxer vs Kicker | 26.5% → 25.5% | 15.5% → 14.5% | – | – |
| Dirty boxer vs Boxer | 72.5% → 73.5% | 92.5% → 92.5% | – | – |
| Dirty boxer vs Wrestler | 69% → 68.5% | 22% → 19.5% | Wrestler 23.8% (18.7%) | 6.2 |
| Dirty boxer vs Muay Thai | 54.5% → 53% | 53% → 53% | – | – |
| Muay Thai vs Kicker | 91.5% → 88% | 32.5% → 32% | – | – |
| Muay Thai vs Boxer | 66.5% → 68.5% | 78% → 78.5% | – | – |
| Muay Thai vs Wrestler | 60% → 55% | 49.5% → 51% | Wrestler 22.9% (17.2%) | 5.0 |
| Judoka vs Boxer | 77% → **64%** | 51% → 53% | 16.3% (12.6%) | 4.6 |
| Judoka vs Wrestler | 93% → 94% | 29.5% → 26.5% | 20.6% (15.4%) | 5.4 |
| BJJ vs Boxer | 78% → 74% | 74% → 69% | 22.6% (18.2%) | 3.9 |
| Sambo vs Boxer | 89.5% → 86% | 76% → 73% | 22.4% (17.4%) | 4.8 |

What it says:
- **Ground finishes about the same**, as Kyle asked: 52.5% of all these fights finished on main, 52.1% now. Most ground
  pairings move a few points either way; the most are the Ground-and-pound wrestler against the Kicker, 87 → 74% (the Kicker
  ties him up and grabs his wrists from underneath, and he can't punch until he postures up), and the Pressure wrestler against
  the Boxer, 35 → 44.5% the other way.
- **The grips are busy**: a man on top is held about a fifth of his time there, and can't punch for about a sixth; he postures up
  2–4 times a fight. Strikers underneath tie up 4–8 times a fight; the half-guard underhook goes back and forth a few times a
  fight.
- **Kyle's balance rule (D220's)**: nothing inside 60/40 left it, and Muay Thai against the Wrestler came inside (60 → 55%).
  Closer to even: the Judoka against the Boxer (77 → 64%), the BJJ fighter, the Sambo fighter and the Ground-and-pound
  wrestler against the Boxer, the Muay Thai fighter against the Kicker, the Pressure wrestler and the Ground-and-pound
  wrestler against the Kicker. Further out by 0.5–2 points, inside the dice: the Wrestler against the Kicker and the Boxer,
  the Dirty boxer and the Muay Thai fighter against the Boxer, the Judoka against the Wrestler.

Golden fights (§2.2): re-pinned (the ground fights play out differently with the grips).

Tested in `tests/sim/fight/test_ground_grips.gd` (one wrist then both; one wrist makes his strikes harder and both stop them;
the collar tie stops them, makes the pass harder and opens the triangle; a held wrist opens the armbar and the tie-up; a grip he
already has is refused; posturing up frees the head first, then a wrist; nothing to strip is refused; posturing up opens the
armbar and the get-up; the grips go when the position changes; the half-guard underhook's openings, and the crossface taking it
back; the half-guard moves only in half guard; the AI ties up, grabs wrists and postures up; both fight for the half-guard
underhook) and `tests/sim/fight/test_ground_and_pound.gd` (the tie-up is the collar tie now).

Sources: [Evolve MMA, grip fighting in no-gi](https://evolve-mma.com/blog/heres-what-you-need-to-know-about-grip-fighting-in-no-gi-bjj/),
[Evolve MMA, ground and pound](https://evolve-mma.com/blog/the-complete-guide-to-ground-and-pound/), as §40.1.

### 40.12 Built: the rest of the ground: frames, the crucifix and two hands on the choke (D264)
The fourth pull request of §40.8's plan, the second half of the ground part (§40.5's last two rows). Kyle's picks
(2026-10-31): "Rest of the ground first" (before the call), "A frame you hold" (a grip held until it's taken away, like the
collar tie, not a one-off push), the crucifix as "Its own position" (between side control and the back, with its own strikes,
escapes and look, not just a grip in side control), "Two hands on the arm" against the rear-naked choke, and ground finishes
kept about where they are, as for D263.

| | What it does | Where it lives |
|---|---|---|
| **The frame** | Underneath side control or mount, everyone can set a forearm frame and hold it (`FRAMED`): getting back to guard +15%, the bridge +10%, and the mount and the crucifix −10% each against him. 45% + (Guard, Strength) − Top control, +10% when he's postured up. Setting one he already has is refused | `frame.json` (`ground.grip` `"frame"`) |
| **Flattening it** | On top, everyone can drive the frame down: 50% + (Top control, Strength) − (Guard, Strength), +10% when he's covering up. Refused with no frame to flatten | `flatten.json` (`"flatten"`) |
| **The crucifix** | A new ground position (`crucifix.json`), between side control and the back. The man on top traps the near arm between his legs and the far one under his arm (`ARM_PINNED` on the man underneath). Taking it from side control: 20% + (Top control, Scrambles) − (Guard, Scrambles), +10% when he's covering up or getting out, −10% against a frame. In it: stamina 0.2 / 0.5 a second, the judges' control 1.75 (between side control's 1.5 and the mount's 2.0, so taking it scores 1.5 points), his punches, hammerfists and elbows ×1.2 and +10% to land, and nothing back from underneath. His cover-up barely helps: at least 75% of the head damage gets through (`FightSim.PINNED_COVER_SHARE`; 50% normally). From it the man on top can take the back (if he knows it) | `take_crucifix.json`; the `crucifix` position file; `side_control.json`'s new transition |
| **Freeing the arm** | Underneath, the only way out of the crucifix: back to side control. 25% + (Scrambles, Strength) − Top control, +10% when he's postured up; within 10%: a scramble. It's an escape, so it shows `ESCAPING` (the back is there to take) and counts in the harness's *out from under* | `escape_crucifix.json` |
| **Two hands on the choking arm** | With his back taken, everyone can grab the choking arm with both hands and hold it (`TWO_ON_ONE`): the rear-naked choke −20% and escaping the back +10%. 50% + (Submission defense, Strength) − Submissions, +10% when he's postured up | `two_on_one.json` (`"two_on_one"`) |
| **Stripping the hands** | On the back, the man behind peels them off: 45% + (Submissions, Strength) − (Submission defense, Strength), +10% when he's covering up or getting out. Refused with no hands on the arm | `strip_hands.json` (`"strip_hands"`) |
| **The referee** | Winning a frame or two hands on the arm counts as answering him (it's defending), as tying him up does (D121, D263) | `FightSim._take_ground_grip()` |
| **When they go** | Like every ground grip, the frame and the two-on-one go when the position changes | `FightSim._clear_grips()` |
| **The AI underneath** | Frames under side control and mount weighted `FighterAI.FRAME_WEIGHT` (0.6) against his other moves, and grabs the choking arm weighted `TWO_ON_ONE_WEIGHT` (0.75); in the crucifix he works to free the arm like any escape | the `frame`, `two_on_one` and `escape_crucifix` cases in `_tied()` |
| **The AI on top** | Flattening the frame, taking the crucifix and stripping the hands are position moves (`_work_position`, at its pace, like the pass), as D263 found works best | `_work_position()`, `_advance_reason()` |
| **How they look** | The crucifix is drawn across him from the head side in the 3D view and on the HUD's position diagram, the man underneath flat with both arms stretched out; poses for the frame, flattening it, taking the crucifix, freeing the arm, two hands on the arm and stripping them | `game/arena_view.gd` `GROUND_LAYOUTS`, `ui/position_diagram.gd` `POSES`, `game/fighter_figure.gd` |
| **The feed and the harness** | "SETS A FRAME", "FLATTENS HIM", "gets TWO HANDS ON THE CHOKING ARM", "STRIPS THE HANDS"; the crucifix moves read as position changes. The harness's **Frames** line: frames, crucifixes and two-on-ones won of tried; the **Positions** line has the crucifix's share; CSV `frames_*`, `crucifixes_*`, `two_on_ones_*`, `crucifix` | `ui/fight_log_formatter.gd`, `sim/balance/` |

**Finding the cause of more finishes.** The first full run finished 54.3% of fights (52.1% on main): the Pressure wrestler
finished the Boxer 57.5% of the time (44.5% on main) and the Kicker 87% (74.5%). It wasn't the crucifix (taking it out changed
little). It was the man underneath spending his turns framing and grabbing the arm, which didn't count for the referee, so his
count ran on while he was defending. Counting a won frame or two-on-one as answering him put the finishes back. Two smaller
changes on the way: the two-on-one first also opened his face to punches (+10%), which added finishes and was dropped; and
with the crucifix's strikes at ×1.0 the Ground-and-pound wrestler, who can't take the back, sat in a crucifix that led nowhere
instead of the mount, so its strikes went to ×1.2 (between side control's 1.0 and the mount's 1.3) and freeing the arm from
30% to 25%. Grabbing the arm half as often (`TWO_ON_ONE_WEIGHT` 1.5 → 0.75) took a few points off the BJJ fighter against the
Boxer.

Harness, no calls, 200 fights a pairing, seed 1, pro rules: main (at #103, with D263) → with D264. *Crucifix* is the share
of the fight spent in it; *frames* and *two on one* are the man underneath's won of tried a fight (the second-named, or the
striker against the Wrestler); *crucifixes* the man on top's.

| Pairing | Wins (first-named): main → now | Finishes | Crucifix | Frames | Crucifixes | Two on one |
|---|---|---|---|---|---|---|
| Kicker vs Boxer | 38.5% → 38% | 27.5% → 27.5% | – | – | – | – |
| Wrestler vs Kicker | 70.5% → 70.5% | 34% → 34.5% | 0.8% | 0.7 of 3.1 | 0.4 of 1.0 | 1.9 of 5.3 |
| Wrestler vs Boxer | 79.5% → 75% | 44.5% → 46% | 1.3% | 1.6 of 6.5 | 0.7 of 1.6 | 2.4 of 7.3 |
| Pressure wrestler vs Kicker | 93.5% → 93% | 74.5% → 69.5% | 1.9% | 1.3 of 5.8 | 0.9 of 1.9 | 3.3 of 8.8 |
| Pressure wrestler vs Boxer | 88% → 88% | 44.5% → 40% | 2% | 2.2 of 8.0 | 1.0 of 2.5 | 3.3 of 8.6 |
| Ground-and-pound wrestler vs Kicker | 84.5% → 86% | 74% → 81.5% | 6.9% | 0.9 of 5.7 | 1.2 of 2.8 | 0.0 of 0.1 |
| Ground-and-pound wrestler vs Boxer | 84% → 81% | 77% → 76.5% | 7% | 1.5 of 7.3 | 1.3 of 2.9 | 0.1 of 0.5 |
| Dirty boxer vs Kicker | 25.5% → 25.5% | 14.5% → 14.5% | – | – | – | – |
| Dirty boxer vs Boxer | 73.5% → 73% | 92.5% → 93% | – | – | – | – |
| Dirty boxer vs Wrestler | 68.5% → 70.5% | 19.5% → 23.5% | 0.8% | 1.4 of 3.8 | 0.4 of 1.1 | 1.0 of 2.4 |
| Dirty boxer vs Muay Thai | 53% → 53.5% | 53% → 55.5% | – | – | – | – |
| Muay Thai vs Kicker | 88% → 88.5% | 32% → 32% | – | – | – | – |
| Muay Thai vs Boxer | 68.5% → 69% | 78.5% → 78% | – | – | – | – |
| Muay Thai vs Wrestler | 55% → 53.5% | 51% → 44% | 0.8% | 1.3 of 4.2 | 0.5 of 1.2 | 1.4 of 3.3 |
| Judoka vs Boxer | 64% → 67.5% | 53% → 52% | 1.3% | 1.7 of 5.4 | 0.7 of 1.7 | 1.6 of 4.6 |
| Judoka vs Wrestler | 94% → 94.5% | 26.5% → 29% | 1.4% | 2.9 of 8.9 | 0.8 of 2.2 | 1.2 of 3.4 |
| BJJ vs Boxer | 74% → 81% | 69% → 69% | 0.9% | 0.8 of 3.1 | 0.4 of 0.9 | 1.3 of 6.1 |
| Sambo vs Boxer | 86% → 88% | 73% → 78% | 2.3% | 2.0 of 6.8 | 0.8 of 1.9 | 1.3 of 6.4 |

What it says:
- **Ground finishes about the same**, as Kyle asked: 52.1% of these fights finished on main, 52.4% now. The most: the
  Ground-and-pound wrestler finishes the Kicker more (74 → 81.5%: the crucifix, 7% of those fights, hits hard and the cover-up
  barely helps), the Pressure wrestler a few points less (the frames and the two-on-one keep the referee out longer), the
  Muay Thai fighter against the Wrestler 51 → 44%.
- **It's all in use**: the man underneath frames 3–9 times a fight and wins about a third, grabs the choking arm 2–9 times and
  wins about a third; the man on top takes the crucifix about once a fight, and the fight spends 1–2% of its time there (7%
  for the Ground-and-pound wrestler, who has no back take to move on with).
- **Kyle's balance rule (D220's)**: nothing inside 60/40 left it (Muay Thai against the Wrestler 55 → 53.5%, closer).
  Closer to even: the Wrestler and the Ground-and-pound wrestler against the Boxer (79.5 → 75%, 84 → 81%). Further out: the BJJ
  fighter against the Boxer, 74 → 81% (+7, with a paired range of +0.1 to +13.9; on a second seed, 400 fights, +3.2, −1.2 to
  +7.7, so a small lean, mostly from more time on the back and more decisions), the Judoka against the Boxer 64 → 67.5% (on
  the second seed 68.8 → 64%, closer), the Sambo fighter against the Boxer 86 → 88%, the Dirty boxer against the Wrestler
  68.5 → 70.5% and the Ground-and-pound wrestler against the Kicker 84.5 → 86%, all inside the dice.


Golden fights (§2.2): re-pinned (the ground fights play out differently).

Tested in `tests/sim/fight/test_ground_grips.gd` (a frame helps him out and makes the mount harder; flattening takes it away;
the crucifix traps his arms and opens his face, with no frame and no guard to recover; taking the crucifix from side control,
and a frame making it harder; freeing the arm back to side control; in the crucifix the cover-up barely helps; two hands on the
choking arm stop the choke and help him out, and stripping them; a frame or two hands on the arm answer the referee; the AI
frames underneath and flattens or takes the crucifix on top; the AI fights the hands on the back).

To change it: the odds and openings are in the six move files and `crucifix.json`; the cover-up through the crucifix is
`FightSim.PINNED_COVER_SHARE`; how often the AI frames and grabs the arm is `FighterAI.FRAME_WEIGHT` and `TWO_ON_ONE_WEIGHT`.

Sources: as §40.1 and §40.5.

### 40.13 Built: the *Hand fight!* call (D265)
The last pull request of §40.8's plan (step 4). Kyle's picks (2026-10-31): the call has him "Fight for the grip that fits"
where he is, for about 10 s, and it goes on key **H**.

| | What it does | Where it lives |
|---|---|---|
| **The call** | *Hand fight!* on **H**, in the clinch and on every ground position (not standing or in a scramble). A 10 s focus, voice 15. While it's on, every grip move he goes for is **+15%** to work: the pummel and the strip in the clinch; the wrist, the collar tie, the half-guard underhook, the frame and two hands on the choking arm underneath; posturing up, the crossface, flattening the frame and stripping the hands on top. Which grip is still his own pick for where he is, so it's always the one that fits. Standing it's refused as impossible | `data/calls/hand_fight.json` (`focus.grip_bonus` 0.15); `LiveCalls.grip_bonus()`; the "hand fight" bonus in `FightSim.odds_breakdown()` |
| **The AI corner** | The `hand_fight` moment (§22.10): when the other man wins a grip (any move whose `clinch` or `ground` block has a `grip`), but only with voice to spare (90 or more), so it never costs the calls that win fights (*Ground and pound!*, *Survive!*, the reads) their voice. Like every D257 moment, not again while the last call is still on, and never over a more urgent focus. **Not in a plain corner yet**: on the D257 corner it came out even (below), and a plain corner only uses the moments that won fights; `--corners=ideal:...+hand_fight` tries it | `Corner.on_event()`, `Corner.SPARE_VOICE`, `Corner.MOMENTS` |
| **The HUD** | A yellow grips line under the position caption: who holds what in the clinch ("WRESTLER: BODY LOCK · BOXER: OVERHOOK", the panel now shows in the clinch too, as just "CLINCH" and the line) and on the ground ("BOXER HOLDS A WRIST, FRAMES", "BOXER'S ARMS TRAPPED"); hidden when nobody holds anything (`06` §6.10) | `FightHud.grips_text()` |
| **The key** | H is handled with R as a letter call; the call bar shows *H Hand fight!* | `game/main.gd` |

**What was tried first.** The first version had him go for grips twice as often for the 10 s, with the grip moves picked three
times as readily. With the good-coaching bot (D12) calling it, the coached fighters won *less* (55.2% → 52.8% on average): the
grapplers stopped doing their own game (the top man posturing up instead of punching, the clinch fighter pummelling instead of
shooting). Adding the grip tries on top of his own game instead of in their place was worse (51.5%), and holding the call back
for spare voice didn't fix it (52.0%). Making the grips he already goes for easier to win did (56.0%); adding half as many
tries again on top of that took it back down (54.3%). So the call sharpens his hand fighting instead of adding more of it.

Harness, 200 fights a pairing, seed 1, pro rules, the good-coaching bot (`--corners=ideal`) in one corner at a time: main (at
#110, the corner before D257) → with *Hand fight!*. The coached fighter's wins:

| Pairing | First-named coached: main → now | Second-named coached: main → now |
|---|---|---|
| Wrestler vs Boxer | 84% → 86.5% | 19.5% → 23.5% |
| Wrestler vs Kicker | 88% → 89.5% | 31% → 39% |
| Dirty boxer vs Wrestler | 68.5% → 72.5% | 33.5% → 36.5% |
| Muay Thai vs Wrestler | 59.5% → 56% | 57% → 52.5% |
| BJJ vs Boxer | 91% → 86% | 22.5% → 21.5% |
| Judoka vs Boxer | 82% → 85% | 32.5% → 28.5% |
| Pressure wrestler vs Boxer | 91.5% → 94% | 12.5% → 14.5% |
| Sambo vs Boxer | 93.5% → 93.5% | 16.5% → 17.5% |

What it says:
- **Good coaching is worth a little more**: coached fighters won 55.2% of these fights on main and 56.0% with the call. It
  helps most where the grips matter on the feet and against the cage (the Wrestler, the Kicker and the Dirty boxer coached),
  and isn't worth it for the Muay Thai fighter against the Wrestler and the BJJ fighter against the Boxer (3.5–5 points down,
  inside the dice on 200 fights, but on both sides for Muay Thai vs the Wrestler).
- **Fights with no calls don't change**: nothing rolls unless the call is on.

**On the D257 corner** (main at #111, which calls more of the other calls: §22.10). The same eight pairings and fights, the plain
ideal corner against the same corner with the `hand_fight` moment added
(`--corners=ideal:fire_back+get_up+collar_tie+cut_the_cage+follow_down+keep_pressing+hand_fight`):

| Pairing | First-named coached: plain → with Hand fight! | Second-named coached: plain → with Hand fight! |
|---|---|---|
| Wrestler vs Boxer | 85% → 84% | 23% → 20.5% |
| Wrestler vs Kicker | 95% → 95.5% | 31% → 38% |
| Dirty boxer vs Wrestler | 76% → 75% | 36.5% → 34% |
| Muay Thai vs Wrestler | 62% → 53% | 54% → 58.5% |
| BJJ vs Boxer | 89% → 92% | 17.5% → 21.5% |
| Judoka vs Boxer | 87.5% → 84.5% | 14.5% → 17.5% |
| Pressure wrestler vs Boxer | 94.5% → 93% | 14% → 12.5% |
| Sambo vs Boxer | 92.5% → 92.5% | 11% → 11% |

Coached fighters won 55.19% both ways: the new corner already spends its voice on calls that pay, and the man it would call
*Hand fight!* for is often a striker losing the grips anyway (the Boxer's calls won their exchange 31% of the time, the
Wrestler's 76%). So it stays out of a plain corner, with the moments that didn't win fights, and is the player's call on H.
Golden fights (§2.2) play out as on main.

Tested in `tests/sim/fight/test_hand_fight_call.gd` (H in the clinch and on the ground only; on the call his grips are easier
to win for 10 s, in the clinch, in the guard and under side control; it does nothing for his other moves; standing it's
refused; the AI corner calls it when the other man wins a grip, not for his own or for a takedown, and not without voice to
spare; the HUD's grips line).

To change it: how much it helps, `focus.grip_bonus` in `hand_fight.json`; how long, `focus.duration_ms`; when the AI corner
calls it, `Corner.SPARE_VOICE` and `Corner.on_event()`.

## 41. More ground and pound: hammerfists, body punches, the posture-up bomb, covering up and turning away (D270)
Kyle asked to "increase ground and pound variety" (2026-10-31). Before this the man on top had one strike everyone knew (the
ground punch, to the head), the ground elbow for the fighters who know it, the knee from side control (to the body; the head
under PRIDE) and PRIDE's soccer kicks and stomps; the man underneath could only tie up, get up or go for a hold, and a ground
strike only ever did damage. Now there are three more strikes on top, the man underneath can cover up, and what he does under
the punches opens the pass, the back and the choke. Every number is a first guess for the harness, each a named constant or a
data field listed in §41.6. Strikes from the bottom (elbows and heel kicks from guard) and wrist control are left for later:
the grips plan (D260, §40.5) gives the man underneath his hands to fight with.

### 41.1 The new strikes (everyone's)
| Move | Where (top) | Timing (telegraph · wind-up · active · recovery) | Odds and damage | What it's for |
|---|---|---|---|---|
| **Hammerfist** | Every top position, the back too | 0.1 · 0.2 · 0.1 · 0.3 s, 2 stamina | Top control, Power against Guard; 3 to the head; +10% on `COVERED` and on `HANDS_LOW` | Quick and small, and it comes round the gloves: 80% of it gets through a cover-up (`through_cover` 0.8, against 50% for anything else). Best from mount (× 1.3) |
| **Body punch** | Full guard, half guard, side control, mount | 0.1 · 0.2 · 0.1 · 0.3 s, 3 stamina | Top control, Boxing against Guard; 5 to the body; +15% on `COVERED` | Drains the tank (body damage, §8), and **his hands come down** to the ribs: `HANDS_LOW` for 1 s (`hands_down_ms`), so the next head shot is +10% and so is the pass. No liver shot on the ground (§35) |
| **Posture-up bomb** | Full guard, half guard | 0.3 · 0.4 · 0.1 · 0.5 s, 7 stamina | Top control, Power against Guard; 8 to the head (the ground punch is 4, the elbow 7); +10% on `HANDS_LOW` (tired, rocked or just hit in the body) | The big one: he sits up from the start (`POSTURED_UP` from the telegraph to the end), so the tie-up (+15%), the get-up (+20%) and the armbar's opening are there for 1.3 s. The AI's commitment (Risk against a long move) decides who throws it |

The knee from side control now brings the hands down too when it goes to the body. Under amateur rules every ground strike goes
to the body (`08`, D121), so there they all drain and drop the hands.

### 41.2 Covering up underneath
**Cover up underneath** (`ground_cover`, *everyone*'s, from the bottom of every ground position): the gloves over the face for 2 s
(`COVERED`). Head shots do half (a hammerfist 80%). But on the ground it **isn't answering**: the referee still counts the shots
(D120, §24.2), unlike the cover-up on the feet (D180, §38). And it gives things away:

| While he covers up | For the man on top |
|---|---|
| The body is open | Body punch +15%, hammerfist +10% |
| His hands aren't on the legs and hips | Guard pass +15% |
| His hands aren't on the arms | Taking the back (from side control and mount) +15% |
| On the back, his hands are on his face, not the choking arm | Rear-naked choke +15% |

The AI underneath covers up when he's under fire or rocked, weighted 1.0 × (1.5 − Guard / 100), twice that when rocked, next to
the tie-up and the get-up (§24.3): a striker with a low Guard covers, a guard player ties up. On top, while the man underneath
covers up, the AI works for a better position three times as often (`COVERED_WORK`).

### 41.3 Turning away from mount
In mount, a clean head shot on a man who's covering up or rocked can make him **turn away and give up his back**, on a chance of
12% × (1.5 − Fight IQ / 100) × (1 + head hurt): 12% a shot for a Fight IQ 50 fighter who hasn't been hurt, 27% at half
health with Fight IQ 0. The fight goes to back control with the same man on top. It isn't getting out: it doesn't answer the
shots (the referee's count carries on) and it doesn't count as an escape. The back scores no more control than mount, so the
judges see nothing new, as when he takes it himself. The feed says *"Boxer TURNS AWAY from the punches and GIVES UP HIS BACK →
Back control (Wrestler has the back)"*. It isn't a move anyone chooses (`turn_away` is no one's technique): the sim does it.

### 41.4 Feed, sound, screen and the harness
- **Feed**: a body punch that lands adds *": his hands come down"*; shots on the gloves say *"through the guard"* as standing;
  the cover-up starts as *"Boxer starts a Cover up underneath (covers up under the punches)"*.
- **Sound**: each new strike has its own line in `StrikeSounds.RECIPES` (`06` §6.8): the hammerfist a short dull thud, the body
  punch a low one, the bomb a heavy crack with a long swish. A shot on the gloves plays the blocked version.
- **Screen**: the 3D figures throw the new strikes with the generic punch pose for now; their own poses wait for the work on
  separate arms and legs (`game/fighter_figure.gd` isn't touched).
- **Harness**: a **GnP** line per pairing: ground strikes landed a fight, the share that were hammerfists, body punches and bombs,
  how often the other man covered up and how many shots hit his gloves, and how often he turned away from mount (CSV columns
  `gnp_landed_*`, `gnp_hammer_*`, `gnp_body_*`, `gnp_bomb_*`, `gnp_covered_*`, `ground_covers_*`, `turned_away_*`). The
  *Defence* line's hits on the guard (D180) are standing strikes only now.

### 41.5 Balance (2026-10-31)
Kyle's goal for this was variety without more finishes. The first numbers (hammerfist 0.5 s, bomb 10 damage with +15% on
`HANDS_LOW`, hands down for 1.5 s) finished about 4 points more fights, nearly all with fighters who had no elbows before (Judoka,
Sambo, Pressure wrestler: the bomb was a bigger elbow everyone had). The numbers above are the second try. 200 fights a pairing,
seed 1, pro rules, main (630b0e5) against this:

| Pairing (red vs blue) | Red wins | Finished early | Red's ground strikes landed a fight (hammerfists · body · bombs) | Blue covers up (on the gloves) |
|---|---|---|---|---|
| Kicker vs Boxer | 44.5 → 45.5% | 35.0 → 35.5% | – | – |
| Wrestler vs Kicker | 73.0 → 66.5% | 39.5 → 34.5% | 30.0 (31% · 14% · 10%) | 8.1 (3.4) |
| Wrestler vs Boxer | 77.5 → 75.0% | 52.5 → 51.0% | 46.9 (33% · 14% · 9%) | 13.9 (5.9) |
| Ground-and-pound wrestler vs Boxer | 86.5 → 86.0% | 83.0 → 78.0% | 52.6 (15% · 9% · 5%) | 13.0 (6.4) |
| BJJ vs Boxer | 81.0 → 80.5% | 72.0 → 74.0% | 26.1 (35% · 20% · 12%) | 6.8 (2.6) |
| Judoka vs Boxer | 69.5 → 63.5% | 47.5 → 53.5% | 31.3 (34% · 19% · 12%) | 8.3 (3.0) |
| Sambo vs Kicker | 41.5 → 37.0% | 22.0 → 29.5% | 16.3 (32% · 19% · 15%) | 3.9 (1.5) |
| Pressure wrestler vs Kicker | 93.5 → 93.0% | 67.5 → 68.5% | 70.5 (34% · 14% · 8%) | 20.3 (11.0) |
| BJJ vs Wrestler | 54.0 → 52.0% | 42.0 → 34.0% | 18.7 (34% · 22% · 12%) | 4.8 (1.7) |
| Muay Thai vs Wrestler | 70.0 → 59.5% | 58.0 → 53.5% | (Wrestler on top) | – |

- **Finishes**: 51.9% → 51.2% across the ten pairings. Judoka and Sambo finish a few more (more TKOs), Wrestler vs Kicker and
  BJJ vs Wrestler a few fewer.
- **Wins**: Kicker vs Boxer is unchanged (inside 60/40). Muay Thai vs Wrestler comes inside 60/40 (70 → 59.5%: the Wrestler's
  ground and pound is better), and Wrestler vs Kicker and Judoka vs Boxer come closer to even. Nothing moves further out by more
  than the dice.
- **Mix**: about a third of what lands on top is hammerfists, a sixth body punches and a tenth bombs; the rest are ground punches,
  elbows and knees. The Ground-and-pound wrestler still throws mostly punches and elbows (his tendencies).
- **Turning away** is rare: 0.2 a fight for the Ground-and-pound wrestler (the one who gets to mount), about 1 in 100 fights for
  the others, because mount is only 1–9% of a fight.
- Speed: within the timing checks (§2.1).

### 41.6 To change it, and the tests
- The strikes: `data/actions/hammerfist.json`, `ground_body_punch.json`, `posture_bomb.json` (`through_cover`, `hands_down_ms`,
  `09`); the cover-up: `ground_cover.json` (its `head_share`); the openings: the `COVERED` lines in `guard_pass.json`,
  `take_back.json` and `rear_naked_choke.json`.
- Turning away: `FightSim.TURN_AWAY_BASE` (0.12) and the `turn_away` transition in `data/positions/mount.json`.
- The AI: `FighterAI.COVER_GROUND` (1.0), `COVER_GROUND_ROCKED` (2.0), `COVERED_WORK` (3.0); who throws which ground strike is
  each fighter's `tendencies` (the `gnp_wrestler` leans on them) and his Risk leaning for the bomb.

Tested in `tests/sim/fight/test_ground_strike_variety.gd` (who can throw which from where, the hammerfist's and the bomb's damage,
the bomb's posture, the body punch dropping the hands, amateur rules, covering up and what gets through it, the referee still
counting, what covering up opens, turning away and when it can't happen, the AI's mix on top and covering up underneath, the feed
lines), `tests/game/test_strike_sounds.gd` (every strike has a sound) and `tests/data/test_data_files.gd` (`through_cover`,
`hands_down_ms`).

---

## 42. The pre-fight gameplan (D320–D324)

Kyle (2026-11-01): "fight gameplan". Before this the engine had five plans (§22.4) that nothing in the game used: the setup,
the career's fight night and the corner didn't offer them, and nobody had measured them. Now the corner builds a plan from three
parts before the fight, can change it at every round break, and the opponent's corner gives him his style's plan.

### 42.1 Three parts (D320; Kyle picked "Build a plan from three parts")
Each part is one picker with *Own game* first; each option is a file in `data/gameplans/` (`09` gameplan@2):

| Part | Options | What it does |
|---|---|---|
| **Approach** (how he fights) | Pressure (Pace +40, Range +30), Counter (Pace −40, Risk −20), Range (Range −35), Conserve (Pace −50, Risk −40) | Shifts his style leanings for the fight |
| **Target** (where his strikes go) | Head (head ×1.6, body ×0.7, legs ×0.6), Body (body ×2, the rest ×0.75), Legs (legs ×2, the rest ×0.75) | Multiplies the weight of every strike that lands there, standing or on the ground |
| **Where** (where he wants the fight) | Keep it standing (Base −50, takedowns ×0.3, clinch entries ×0.5, no guard pulls), Clinch work (Range +40, clinch entries ×2.5, collar ties and fence drives ×1.5), Take him down (Base +60, takedowns ×1.5; was *Wrestle-heavy*) | Leanings and move weights |

The parts add up: the leanings add, the multipliers multiply (`Gameplan.compose`). A plan never picks a move itself: it only tilts the
fighter's own AI (§16 A2). It goes in as a `set_gameplan` command (`FightCommand.SET_GAMEPLAN`) on a round's first tick, so a saved
fight replays with it; a plan sent mid-round is refused (*"gameplans are set before a round"*). A new plan replaces the old one.

### 42.2 How hard a plan pulls (D321, D322)
- **Capped at ±70 (D321).** A plan never pushes a leaning past ±70 and never pulls back one that's already past it. Without the cap the
  Range plan put the Kicker (Range −60) at −100, where he stops throwing anything but the jab: he went from 38% to 0% against the Boxer.
- **Half strength (D322; Kyle picked "Half strength" over full and gentle).** A built plan's leanings count half and its multipliers
  pull as their square root (×2 works as ×1.41). `Gameplan.STRENGTH` 0.5.

### 42.3 Drifting off the plan (D323)
When it goes badly he keeps less of the plan: rocked, under 25% of his stamina, head or body at least half gone, or taking at least
twice what he lands (with 15 or more landed on him). Then he keeps `0.35 + 0.006 × Fight IQ + 0.002 × (trust − 50) − 0.003 × ego`
of its pull (at least 0.2): Fight IQ 90 keeps 89%, Fight IQ 30 with ego 80 keeps 29%. The plan panel says *drifting off the plan (N%)*.
Fresh and even, he follows all of it.

### 42.4 The opponent's corner and scouting (D324)
A style sheet (`09` style@1) can carry a `gameplan`: generated opponents and the authored fighter the sheet is built on fight to it
(`StyleLibrary.gameplan_of`), in quick fights and the career. Scouting cards (the tale of the tape, fight offers on the hub) say
*Expect his corner's plan: Pressure · Head · Keep it standing*. The plans fit how each style fights: the Pressure boxer Pressure ·
Head · Keep it standing, the wrestlers Take him down, the Kicker and the Leg-kick specialist Legs, the Muay Thai fighter Body · Clinch
work, and so on. The opponent's corner doesn't change its plan between rounds yet.

### 42.5 On the screens
- **Fight setup:** *Gameplan for your fighter* under the drilled rules, with a line a part saying what it tells him.
- **Between rounds:** the bell's panel has the pickers under the rule slots, showing the plan as it stands.
- **Career fight night card:** *GAMEPLAN: how he fights tonight*, filled in from the setup's plan (quick fights) and the camp's last
  instruction (*Told to: Take him down* fills Where). *Sim the fight* uses it too.
- **The plan panel** (top left of the fight) shows the plan instead of *own game*.

### 42.6 Balance (2026-11-01, 40 fights a plan, paired by seed, the plan on the first-named fighter)
Full strength first, then half (what's in the game):

| Fighter vs opponent (own game) | Best part, full → half | Worst part, full → half |
|---|---|---|
| Kicker vs Boxer (38%) | Counter +38 → +30 | Pressure −33 → −25 |
| Wrestler vs Kicker (68%) | Body +13 → Pressure, Range +8 | Keep it standing −43 → −20 |
| BJJ vs Boxer (83%) | Legs +5 → Conserve +5 | Keep it standing −70 → −38 |
| Leg-kick specialist vs Pressure wrestler (65%) | Head +18 → +10 | Take him down −53 → Range −45 (at the softened Range −35) |
| Muay Thai vs Wrestler (60%) | none → Pressure, Head +5 | Range −45 → Body −13 |

Wrong plans cost more than right ones help, because every fighter is already built around his own game. Each style's own plan
(§42.4), against the same fights on his own game: Boxer vs Kicker +7.5, Boxer vs Karate +15, Karate vs Wrestler +5, Wrestler vs
Counter-striker +5, Wrestler vs BJJ +2.5, BJJ vs Sambo −10 (all inside the noise at 40 fights except the Boxer vs Karate). The Leg-kick
specialist's first pick (Legs · Keep it standing) cost him 15 against the Pressure wrestler, so his plan is Legs alone.

To re-run: `godot --headless --script res://tools/balance.gd -- --fights=40 --pairs=kicker:boxer --gameplans=counter,legs,counter+legs --coach=red`
(`--gameplans=style` gives each fighter his style sheet's plan). Plan fights are kept out of the engine's own targets and reported as
*Kicker on counter+legs against the Boxer* lines (D320).

### 42.7 To change it, and the tests
- The parts: `data/gameplans/*.json` (`leanings`, `weights`, `targets`, `summary`, `order`; a new file shows up in its picker).
- How hard: `Gameplan.STRENGTH` (0.5), `LEANING_CAP` (70).
- Drifting: `Gameplan.STICK_*`, `PRESSURE_HURT` (0.5), `PRESSURE_STAMINA` (0.25), `LOSING_RATIO` (2), `LOSING_MIN` (15).
- The opponents' plans: each style sheet's `gameplan`.
- The camp's instruction list only offers parts with leanings (a target part pushes no style).

Tested in `tests/sim/fight/test_gameplan.gd` (the parts, composing, targets, the cap, the command before a round and not during, a
new plan replacing the old, refusals, replays, the Legs plan sending more strikes low, drifting off it), `tests/ui/test_gameplan_picker.gd`
(the pickers, scouting's line, the camp filling it in), `tests/game/test_main_scene.gd` (the setup's plan in the fight, the opponent's,
changing it at the break, the career's fight night plan), `tests/sim/balance/` (the harness's `--gameplans` and report lines) and
`tests/data/test_data_files.gd` (gameplan@2, style sheets' plans).
