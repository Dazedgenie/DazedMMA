# 12 — Pre-coding Review (2026-10-24)

> Kyle asked for a review of the plan and the code structure before heavy coding begins. Status: **decided** (D91–D102).
> Related: `01` §6.2, §18 · `04` §2 · `09` · `10` §1 · `11` §2.2, §3.5 · issues #14–#20.

---

## 1. Summary

The foundation is in good shape and the plan is sound. Five structural changes are worth making before the next four
engine issues (AI #14, clinch and ground #15, live calls #16, drilled rules #17) land on top of it. None is a rewrite;
each is a few days at most, and each gets much more expensive after those issues ship.

What is solid and stays as it is:
- The design docs are complete for a pre-production project. Decisions are numbered, every number in the engine traces to a
  doc table, and "prove the coaching loop first" is the right guardrail.
- The simulation is pure, seeded and replayable, and a test fails the build if anyone breaks that. 98 tests pass in under
  6 seconds. CI posts a readable table.
- Content is JSON, one file per item, validated in CI. The stat and trait system (`11`) has one shared odds formula, which keeps
  the game explainable.

What to change first (details in §3):
1. Give fighters a data format now, before the AI, harness and world sim each invent their own.
2. Pull decision-making out of the fight loop into its own layer, so the AI, calls and drilled rules plug into one priority stack.
3. Make every outcome event carry its reasons, not only the final percentage.
4. Decide how positions work before #15, and keep the first ground game small.
5. Build a minimal balance harness before the AI.

---

## 2. Baseline numbers

Measured on `main` after PR #30 with Godot 4.7.2, headless.

| What | Result | Why it matters |
|---|---|---|
| Tests | 98 pass, 0 fail, 5.8 s | Safe to refactor on top of |
| One 3-round fight | ~0.43 s (200 fights in 87 s) | 2,000× faster than fight time: a 1,000-fight harness run is ~7 min. Fine for the prototype; tight for 30-year world sims |
| Events per fight | ~2,850, half of them phase changes | Event volume is the main cost; a quiet mode that keeps only totals would roughly halve it |
| Kicker vs Boxer, 200 fights | Boxer 83%, Kicker 11%, draws 6% | Known: the placeholder AI only walks forward. Draws are far too common |
| How fights end | 2 of 200 by KO, the rest decisions | Finishes are rare with these fighters |
| Stamina at the final bell (seed 7) | Kicker 83/100, Boxer 92/94 | Nobody ever gets tired, so Cardio, fatigue flags and longer telegraphs never show |
| Head damage at the final bell (seed 7) | Kicker 426, Boxer 150 | "Fully hurt" is 1,000 for an average chin, so damage TKOs almost never happen |

`tools/run_sim.gd --fights=N` already does seeded runs and win/method counts. It lacks stat-profile pairs from data, CSV output
and the coaching bots.

---

## 3. Structural changes, in priority order

Priority 1 lands before #14–#17. Priority 2 is cheap now and painful later. Priority 3 waits for the problem to show up.

### Priority 1
1. **A fighter data format (D94).** A fighter is built in code with a growing argument list (name, stats, moves, work rate,
   style); nothing describes one as data. The AI needs tendencies and tells per fighter, the harness needs stat profiles, the
   world needs ~600 generated fighters, saves and replays need "the same fighters set up the same way". Add `fighter@1` to `09`:
   stats, frame and stance, personality axes, style leanings, gifts and flaws, known techniques, tendencies and tells, optional
   archetype template. Put Kicker and Boxer in `data/fighters/` and make the showcase and runner load them. ~1–2 days.
2. **One decision layer with one priority stack.** `sim/fight_sim.gd` moves the fighters, picks actions, resolves strikes,
   scores rounds and tracks the cage in one file. `01` §6.0 describes coaching as four layers feeding the same choice: gameplan
   bias → drilled rules → live calls → the fighter's own AI. If the AI is written inside the fight loop, calls and rules become
   bolted-on special cases and "never silently replace the gameplan" (`01` §16) is hard to guarantee. Split it: the simulation
   owns time, positions and resolution; a decision step scores candidate actions each tick from a read-only view; gameplans,
   rules and calls add or override scores through that same step, with a tick delay and a compliance check in front of calls.
   ~2–3 days, mostly moving code the tests already cover.
3. **Reasons on every outcome event (A16).** Strike events carry the final percentage, not where it came from. The feed, the
   debug overlay, the harness report on call effectiveness and the playtest question "can testers explain why the catch-kick
   worked?" all need the breakdown: base odds, stat gap, each opening bonus by name, counter bonus, and later for calls: delay,
   ignored, infeasible. Add an `odds` breakdown now, while two event types need it rather than twelve. ~½ day.
4. **Decide the position model before #15 (D98).** Positions are relational (one fighter is on top), while each fighter holds
   their own position string today. Decide: a shared situation both fighters reference, with phase (standing / clinch / ground),
   the named position and each fighter's role; cage position carries into clinch and ground so wall-walking and cage takedowns
   work; transitions live in the position data files. Trim #15 for the playtest per D98.
5. **A minimal balance harness before the AI (D95).** Fighter pairs from data, CSV output, the summary from `04` §7. Then
   build the AI against it. Bots (ideal, spam, none) join when calls exist. ~1 day.

### Priority 2
6. **Typed action definitions.** Actions are raw dictionaries read by string key across the loop. With the AI, calls, rules and
   techniques reading them too, a typo becomes a crash mid-fight instead of a load error. Build an `ActionDef` once at load.
7. **One number for a fighter's own reaction time (D93).** Read calls, drilled rules and the AI all need "how many ticks after a
   trigger does this fighter act". Define it once in `FighterState`.
8. **One fight driver in the game layer.** The debug console runs its own tick loop at 2×. The HUD (#19), the career layer and
   the console all need the same thing: feed ticks at Normal, Fast or slow-mo, pause, pass commands in (D91). One `FightRunner`
   node keeps "slow-mo never changes the result" true in one place.
9. **Golden replay tests.** Pin three seeds' results and an event hash so any change to a balance constant or the AI shows up in
   the PR as a deliberate test update. Cheapest guard against AI-written code drifting silently (R9). Built with #35: D122, `01` §2.2.
10. **Pass the ruleset into the fight.** Rulesets are data but the sim takes round counts as numbers and ignores `allows`.
    Taking a ruleset object means #15 removes illegal actions from the same source the amateur fights (`08`) use.
11. **Split `sim/` into `fight/` and `world/` (D100).** Keep the career and world simulation pure, with the game layer only
    scheduling it. Free while there are ten files.

### Priority 3
12. **Quiet mode and parallel runs.** A flag that skips keeping events, and worker threads for harness fights. Measure first. Measured with #35: no quiet mode, harness fights in one process per core (D123, `01` §2.3).
13. **Export preset.** `export_presets.cfg` doesn't exist yet and `data/**/*.json` must be in its non-resource filter (`09` §1),
    or the first playtest build (#20) ships without content. *Done in #20 (D118): `export_presets.cfg`, and CI self-checks the exported game.*

---

## 4. Balance and feel risks (harness targets)

| Risk | What the numbers show | Target |
|---|---|---|
| Fatigue never matters | Fighters finish 15 minutes with 83–98% of the tank. A jab costs 2 and the tank refills 1.2/s | **D96**: a fighter who pushed the pace, had it pushed on them, or took heavy body damage ends round 3 at ~30–50%; a slow tit-for-tat fight can leave both fresh. Movement costs stamina |
| The catch-kick window is ~0.45 s real time | `ONE_LEG` lasts 0.9 s of fight time = 0.45 s at 2×. A now call's 0.6 s base delay can never hit it; only reads and rules can. At Speed 100 the kick telegraph is 0.2 s of fight time | **D91** speed control first, playtest 1× and 2×. **D93** reaction time 2 ticks at Speed 50 inside a primed read |
| Draws and 10-10 rounds | 12 of 200 fights drawn: a round within 5% is 10-10 on every card | **D97**: 10-10 very rare, draws under 2% |
| Finishes are rare | 2 KOs in 200 between a 55/60 Power pair; "fully hurt" is 1,000 head damage and a fight lands ~400 | Set a finish-rate target by stat gap (e.g. 30–40% of even regional-pro fights end inside the distance) |
| Stat gaps hit the clamp fast | Linear formula moves 1%/point; flag bonuses stack to +45% | Keep linear (`11` §3.1); harness reports how often an exchange hits the 95% clamp |
| Showcase pair is lopsided | Boxer 83% because the placeholder AI only walks forward and back | #14 is done when the pair is within 60/40 with no calls |

---

## 5. Decisions (Kyle, 2026-10-24)

| # | Question | Answer |
|---|---|---|
| D91 | Prototype fight speed | Build the speed control first; playtest at 1× and 2× |
| D92 | Call delay unit | Fight time |
| D93 | Reaction time inside a primed read | 2 ticks at Speed 50, 1 at Speed 100, 3 at Speed 0, stretched by fatigue |
| D94 | Fighter format | One schema for authored profiles and generated fighters (optional template) |
| D95 | Harness before AI | Yes |
| D96 | Fatigue | Earned: tired when the pace was pushed or heavy damage taken; a slow fight can leave both fresh |
| D97 | Even rounds | 10-10 very rare; draws under 2% |
| D98 | Ground scope for the playtest | Trimmed: clinch, takedowns, sprawl, full guard, get up, scramble |
| D99 | Between rounds | Rocked and panic clear; stamina recovers; head and leg damage do not |
| D100 | World sim | Pure, in `sim/world/` |
| D101 | Renderer | Compatibility: smooth on most machines first |
| D102 | This review | Filed here; priority items as GitHub issues |

## 6. Order for the open Phase 1 issues

1. Structure PR: fighter format, decision layer, odds breakdown, ruleset into the sim, folder split (Priority 1 items 1–4, Priority 2 items 10–11).
2. #18 minimal harness + golden replay tests. Bots later with #16.
3. #14 fighter AI, tuned against the harness until the showcase pair is close to even and fatigue shows when earned (D96).
4. #15 clinch, takedowns, sprawl and the trimmed ground game (D98).
5. #16 live calls and #17 drilled rules through the decision layer; ideal and spam bots join the harness here (D12's +10–20% is the real exit test).
6. #19 grey-box view on the shared fight driver (D91, D101), then #20 the playtest.

Nothing here changes the Phase 1 goal or its exit criteria. It front-loads about a week of structure so the next six weeks don't fight the code.
