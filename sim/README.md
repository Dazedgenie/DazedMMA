# sim/ — simulation core

Pure GDScript (`RefCounted` classes). The fight engine, AI, coaching and judging live in `fight/`; the balance harness's numbers in `balance/`; the career and world
simulation lives in `world/` under the same rules (D100), starting with the training camp.

Rules (docs/04-tech-and-production.md §2.2):
- **No Node or scene-tree dependencies.** Nothing here may extend `Node` or use `get_tree()`, `$`, or autoloads.
- **Never read real time or input.** Time advances only by `tick()`; commands arrive through a queue.
- **Seeded randomness only**, so any fight can be replayed from seed + command log.
- Emit events for presentation and commentary to listen to. Never call into `game/` or `ui/`.

## fight/
| File | Role |
|---|---|
| `fight_sim.gd` | The fight: `tick()` = 100 ms. Owns time, movement and resolution. Commands in (`submit`), events out (`events`, `event_emitted`). `record()` / `FightSim.from_record()` save and rebuild a fight from seed + fighter ids + commands |
| `decision_layer.gd` | What a free fighter starts: one priority stack, command → live call → drilled rule → AI (`docs/01` §19) |
| `fight_view.gd` | The read-only view of the fight a decision step sees |
| `decision.gd` / `decision_source.gd` | A decision (action, layer, reason) and the base for layers that claim or bias it |
| `live_calls.gd` | Live calls: delay in fight time, compliance and feasibility checks, `call_answered` events |
| `gameplan.gd` | Multiplies the AI's weights per action or category |
| `fighter_ai.gd` | The fighter's own choices with no calls (#14, `docs/01` §20): the range plan and footwork, reads, counters, combinations, tells and what to throw |
| `trigger_library.gd` | Loads `data/triggers/*.json` and matches an event against a trigger, as one fighter sees it (tells now; read calls and rules later) |
| `odds_breakdown.gd` | Where an exchange's odds came from; strike events carry it as `odds` |
| `ruleset.gd` | Loads `data/rulesets/*.json`: rounds, round length, damage scaling, legal actions |
| `fight_clock.gd` | Rounds and ticks |
| `fight_command.gd` / `fight_event.gd` | What goes in / what comes out. Event types are snake_case to match `data/triggers` |
| `fighter_state.gd` | One fighter's live state: stamina, damage, effective stats (stat × condition, `docs/11` §3.2), reaction time (D93) |
| `octagon.gd` | The cage shape, distance bands and cage proximity (`docs/01` §3, §18) |
| `judging.gd` | 10-point must scoring with three judges (`docs/01` §11, §18) |
| `contest.gd` | The one odds formula every exchange uses (`docs/11` §3.1) |
| `style_leanings.gd` | Pace / Range / Base / Risk leanings, hints and named style traits (`docs/11` §4.2) |
| `situation.gd` | Where the fight is, shared by both fighters: phase, position and each fighter's role (`docs/01` §4.1) |
| `position_library.gd` | Loads `data/positions/*.json`, including the transitions between positions |
| `action_library.gd` | Loads `data/actions/*.json` |
| `combo_library.gd` | Loads `data/combos/*.json`: the strikers' drilled combinations (D133, `docs/01` §31) |
| `fighter_library.gd` | Loads `data/fighters/*.json` (fighter@1), fills in templates, makes fresh `FighterState`s |

## balance/
| File | Role |
|---|---|
| `fight_summary.gd` | One finished fight as one row of numbers: result, method, knockdowns, strikes, damage, stamina at the end and its lowest, 10-10 cards, clamped odds |
| `balance_report.gd` | Rows in; CSV, a readable summary and the balance targets (met / missed / info) out. Run by `tools/balance.gd` (#18) |
| `golden_fights.gd` | The golden fights (#35, D122, `docs/01` §2.2): plays the fights pinned in `tests/golden/golden_fights.json` and says what changed. Run by `tests/sim/balance/test_golden_fights.gd` and `tools/golden.gd` |
| `harness_jobs.gd` | The harness's fights as a list, shared out between several Godot processes and put back in order (#35, D123, `docs/01` §2.3). Used by `tools/balance.gd` |

## world/
The career and world simulation (D100), starting with training (`docs/02` §3.5, D125).

| File | Role |
|---|---|
| `training_library.gd` | Loads `data/sessions/*.json` and `data/week_plans/*.json` |
| `training_camp.gd` | A fighter in training: runs week plans of sessions into attribute points, fatigue, style pushes, chin wear and camp injuries; `profile()` is the trained fighter@1 profile. Run by `tools/camp.gd` |
| `career.gd` | One fighter's career (docs/03 §10, D301–D304): the calendar, his record, money, offers and the booked fight, saved as career@1 |
| `matchmaker.gd` | Fight offers (docs/03 §10.4, D304): who's offered from the style sheets, how hard, when, under which rules and for what purse; local amateur cards and the word on turning pro (§11.4, D314) |
| `coach.gd` | The head coach (docs/03 §11.1, D311): his background and specialty, and what the specialty does to training and to calls |
| `childhood.gd` | His childhood (docs/03 §11.2, D312): the scenes in data/vignettes, the one per age a career draws, and what his choices make of him (background, flavour, stats, personality, height, people, money) |
| `gym.gd` | Your gym (docs/03 §11.3, D313): the kinds in data/gyms and the cultures, the three gyms a new career offers, and what a gym does to training |
| `school.gd` | School weeks (docs/03 §11.4, D314): until 18, term time takes his weekday mornings; the summer holidays and when he leaves |
| `tournament.gd` | The one-day amateur tournament (docs/03 §11.5, D315): the sizes, the rounds' names, the medals and what carries from one fight to the next |
| `tutorial.gd` | The story as the tutorial (docs/03 §11.6, D316): the three lesson fights and what each opens, and the tips in data/tips (when each is due, the Coach's Notebook) |
| `weight.gd` | Weight divisions (docs/03 §12.1, D351): the six divisions in data/divisions, a fighter's grown weight from his height and build, growing into it by 21, his division from his weight with a normal cut, the choices at his pro debut, and fitting a made-up opponent to a division |
| `world.gd` | The world's fighters (docs/03 §12.2, D352): about 100 named men a division in a pyramid of levels, local lads at home and the hotbeds at the top, each man's fighter made from his style, seed and level, his record, rematches, and saving them in the career |
| `aftermath.gd` | What a fight does to him afterwards (docs/03 §10.5, D305): the medical suspension and the Chin a knockout takes |
