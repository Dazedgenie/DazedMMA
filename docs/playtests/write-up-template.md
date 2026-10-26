# Playtest write-up: YYYY-MM-DD

> Copy this file to `docs/playtests/YYYY-MM-DD-<name>.md` and fill in every row. Every test from `10` §2 is here, each with
> where its answer comes from: the testers (the [feedback form](feedback-form.md) and the host's notes), the saved fights
> (`tools/playtest_report.gd`, [`README.md`](README.md) §3), or the balance harness and the tests. Rows from the harness are
> filled in from the **Playtest numbers** run of 2026-10-26 (with health and ground and pound, D120/D121; 100 fights a
> pairing and corner, D124). If fights have changed since (a golden-fight re-pin, D122), re-run it on the playtest build's
> commit first ([`README.md`](README.md) §4) and update them.

**Build:** `ChinCheck-windows-<commit>`  **Host:** ______  **Testers:** __ (T1 … T5; who started fight 2 at 2×: T1, T3, T5)
**Report:** `build/playtest/summary.txt` from __ saved fights (paste it under §3)

## 1. The decision

**Go / Adjust / Rethink:** ______

- **Go**: tests 1, 2 and 5 pass, and nothing else fails badly. The core feels right; move on to the next phase.
- **Adjust**: the catch feels right to most testers but something gets in the way (it's too hard to time, the tell is missed,
  failures don't explain themselves, a speed is wrong). Name each fix and the issue for it, then playtest again.
- **Rethink**: testers can't say why the catch worked, or don't want another fight. The core idea needs changing before more is built on it.

Why: ______ (two or three sentences, pointing at the rows below)

Then add the decision to `00` §0 as its own row, and record the D91 speed choice there too (§2 below).

## 2. Success criteria (`10` §2)

| # | Test | Pass when | Where the answer comes from | Result | Pass? |
|---|---|---|---|---|---|
| 1 | **Feel** | At least 4 of 5 testers can explain *why* a successful catch-kick takedown worked | Form A1, the host's §4 question 1. Count a tester when they name the kick and the catch (the leg was up / he was on one leg / I called it as he kicked) | __ of __ testers | |
| 2 | **Learnability** | By fight 3 against the Kicker, testers land at least 2 well-timed takedowns a fight | Report: "Playtest 3" row, the *well-timed* and *2+ timed* columns | __ a fight; __ of __ fights had 2+ | |
| 3 | **Impact** | Good coaching (the ideal bot) beats no coaching by +10–20% in even matchups, and spam calling does worse than no calls | Balance harness (`01` §22.8, D113/D115): `--corners` with `--coach=ideal` / `spam` | 2026-10-26: Wrestler vs Kicker (fights 2–3) **+15%** with good coaching (67% → 82%; +19.5 and +11 on two seed sets), **−5%** with spam (−2 and −8.5). Wrestler vs Boxer (fight 1) **+10%** (52% → 62%), spam −2.5%. The AI corner: +10% and +8%. Strikers' corners gain about nothing (Kicker −3%, Boxer +3.5%; they have few calls to time) | Pass for the playtest fighter, though spam now only just loses (it was −10% before health); open for the strikers |
| 4 | **Punishment readability** | Testers can explain why a bad takedown failed (sprawl, knee, guillotine risk flagged) | Form B5 and B6, the host's §4 question 2 | __ of __ testers | |
| 5 | **Fun** | Testers want to play another fight | Form E14 (and E15), the host's §4 question 3, anyone who played again unasked | Yes __ · Maybe __ · No __ | |

## 2b. Health and finishes (D120, D121)

Not one of `10` §2's tests, but health and ground and pound came in after the kit (Kyle: "kind of pointless with no health
system"), so check they read and feel right. The harness says how often each playtest fight should end early:

| Playtest fight | Ends early: no calls | Ends early: good coaching | Testers' fights that ended early (`playtest.csv`, the *result* column) | Saw it coming (form F18) | Too often / about right / too rarely (form F20) |
|---|---|---|---|---|---|
| 1: Wrestler vs Boxer | 57% (almost all referee stoppages) | 71% | __ of __ | | |
| 2 and 3: Wrestler vs Kicker | 17.5% | 44% | __ of __ | | |

Ground and pound: testers who called it (form F19): __ of __. Did it seem to do anything? __

D120 aimed for about a third of fights ending early. Fight 1 runs well above that (the Boxer has no answer on the ground,
`01` §24.5): if testers say fights end too often, lower `FighterAI.GNP_RATE` or raise `FightSim.GROUND_STOP_PER_HEALTH`
(`01` §24.6) and name the issue in §6.

## 3. Acceptance tests (`10` §2, A13)

| Test | Pass when | Where the answer comes from | Result | Pass? |
|---|---|---|---|---|
| **Timing** | A well-timed call or rule exploits a real opening without guaranteeing success | Report: perfect calls vs "Catch the kick!" calls made in fights 2–3 (`calls_by_id` in the CSV); form A4 | __ catches from __ calls; misses explained? | |
| **Tactical value** | Over many seeds, correct timing beats poor timing by a clear margin | Harness: the ideal bot vs the spam bot, same fights | 2026-10-26: Wrestler vs Kicker **82% vs 61.5%** (ideal vs spam, both seed sets; was 61% vs 38% before health) | Pass |
| **Fairness** | Skilled opponents can defend, and the log explains why | Form B6 and C10; the host's notes on sprawls and knees; harness: the Kicker still wins about 18% against good coaching (was 39% before health; about 31% without calls) | __ | |
| **Slow motion** | Slow-mo gives decision time without changing the simulation result | `tests/game/test_fight_driver.gd`: a fight played with random speed changes and pauses matches the headless run (D117); form D12 for "gives decision time" | Sim result: pass (in CI on every PR). Decision time: __ | |
| **Rules** | Rules fire only when eligible; conflicts resolve by priority, predictably | `tests/sim/fight/test_drilled_rules.gd` (slot 1 first, cooldown, eligibility, D116); the host's notes on fight 3 | Pass in tests. Harness: the 80% catch rule fires 9 times a fight but changes the Wrestler's wins by −0.5% (62% → 61.5%), so it shows the rule working, not winning. Testers noticed the rule firing: __ of __ | |
| **Autonomy** | With no calls, fighters still fight competently and in character | Harness with no corners: Kicker vs Boxer about 50/50, mirrors even, draws under 2% (`01` §20.2); form C9 | Harness (2026-10-26): pass. Kicker vs Boxer 45/55, mirrors 40/60 (Kicker), 50/50 (Boxer), 51/49 (Wrestler), draws 0.7% over 900 fights (2.5% in Wrestler vs Kicker alone), no 10-10 cards. Testers: __ | |
| **Readability** | Testers can name range, position, current action and the opening | Form C8 and A2; the host's notes of what testers named out loud | Range __/__ · Position __/__ · Action __/__ · Opening __/__ | |
| **Reproducibility** | Same seed + same commands → identical fight | `tests/sim/fight/test_fight_sim.gd` replay tests; the report's *replays* column (every playtest fight re-run from its saved file) | __ of __ saved fights replay | |

## 4. Speed (D91)

Fight 2 was played at both speeds, half the testers starting at 2×.

| | 2× | 1× |
|---|---|---|
| Well-timed takedowns a fight (report, "Playtest 2 at …") | | |
| Perfect calls a fight | | |
| Testers who preferred it (form D11) | | |
| Testers who picked it for fight 3 | | |

**Normal speed from now on:** 2× / 1× (this confirms or changes D9's 2×).

## 5. What testers said

The best quotes, word for word, grouped: why the catch worked · why takedowns failed · confusion · requests.

## 6. Problems found

| Problem | How many testers | Fix | Issue |
|---|---|---|---|
| | | | |

## 7. The numbers

Paste `build/playtest/summary.txt` here, and attach or link `playtest.csv`.
