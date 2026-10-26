# Playtest write-up: YYYY-MM-DD

> Copy this file to `docs/playtests/YYYY-MM-DD-<name>.md` and fill in every row. Every test from `10` §2 is here, each with
> where its answer comes from: the testers (the [feedback form](feedback-form.md) and the host's notes), the saved fights
> (`tools/playtest_report.gd`, [`README.md`](README.md) §3), or the balance harness and the tests. Rows from the harness and the
> tests are filled in with the numbers from before health and ground and pound (D120, D121), so re-run the harness
> (`01` §22.8) on the playtest build's commit and update them first.

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
| 3 | **Impact** | Good coaching (the ideal bot) beats no coaching by +10–20% in even matchups, and spam calling does worse than no calls | Balance harness (`01` §22.8, D113/D115): `--corners` with `--coach=ideal` / `spam` | As of D118: Wrestler vs Kicker (the playtest fight) **+13%** with good coaching, **−10%** with spam. Strikers' corners gain about nothing (they have few calls to time) | Pass for the playtest fighter; open for the strikers |
| 4 | **Punishment readability** | Testers can explain why a bad takedown failed (sprawl, knee, guillotine risk flagged) | Form B5 and B6, the host's §4 question 2 | __ of __ testers | |
| 5 | **Fun** | Testers want to play another fight | Form E14 (and E15), the host's §4 question 3, anyone who played again unasked | Yes __ · Maybe __ · No __ | |

## 3. Acceptance tests (`10` §2, A13)

| Test | Pass when | Where the answer comes from | Result | Pass? |
|---|---|---|---|---|
| **Timing** | A well-timed call or rule exploits a real opening without guaranteeing success | Report: perfect calls vs "Catch the kick!" calls made in fights 2–3 (`calls_by_id` in the CSV); form A4 | __ catches from __ calls; misses explained? | |
| **Tactical value** | Over many seeds, correct timing beats poor timing by a clear margin | Harness: the ideal bot vs the spam bot, same fights | As of D118: Wrestler vs Kicker **61% vs 38%** (ideal vs spam, `01` §22.8) | Pass |
| **Fairness** | Skilled opponents can defend, and the log explains why | Form B6 and C10; the host's notes on sprawls and knees; harness: the Kicker still wins 39% against good coaching | __ | |
| **Slow motion** | Slow-mo gives decision time without changing the simulation result | `tests/game/test_fight_driver.gd`: a fight played with random speed changes and pauses matches the headless run (D117); form D12 for "gives decision time" | Sim result: pass (in CI on every PR). Decision time: __ | |
| **Rules** | Rules fire only when eligible; conflicts resolve by priority, predictably | `tests/sim/fight/test_drilled_rules.gd` (slot 1 first, cooldown, eligibility, D116); the host's notes on fight 3 | Pass in tests. Testers noticed the rule firing: __ of __ | |
| **Autonomy** | With no calls, fighters still fight competently and in character | Harness with no corners: Kicker vs Boxer about 50/50, mirrors even, draws under 2% (`01` §20.2); form C9 | Harness: pass. Testers: __ | |
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
