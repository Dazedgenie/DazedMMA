# sim/ — simulation core

Pure GDScript (`RefCounted` classes). The fight engine, AI, coaching and judging live in `fight/`; the career and world
simulation will live in `world/` under the same rules (D100).

Rules (docs/04-tech-and-production.md §2.2):
- **No Node or scene-tree dependencies.** Nothing here may extend `Node` or use `get_tree()`, `$`, or autoloads.
- **Never read real time or input.** Time advances only by `tick()`; commands arrive through a queue.
- **Seeded randomness only**, so any fight can be replayed from seed + command log.
- Emit events for presentation and commentary to listen to. Never call into `game/` or `ui/`.

## fight/
| File | Role |
|---|---|
| `fight_sim.gd` | The fight: `tick()` = 100 ms. Owns time, movement and resolution. Commands in (`submit`), events out (`events`, `event_emitted`). `FightSim.replay(seed, fighters, actions, command_log)` rebuilds a fight exactly |
| `decision_layer.gd` | What a free fighter starts: one priority stack, command → live call → drilled rule → AI (`docs/01` §19) |
| `fight_view.gd` | The read-only view of the fight a decision step sees |
| `decision.gd` / `decision_source.gd` | A decision (action, layer, reason) and the base for layers that claim or bias it |
| `live_calls.gd` | Live calls: delay in fight time, compliance and feasibility checks, `call_answered` events |
| `gameplan.gd` | Multiplies the AI's weights per action or category |
| `placeholder_ai.gd` | The fighter's own choices until the utility AI (#14): footwork target and what to throw |
| `odds_breakdown.gd` | Where an exchange's odds came from; strike events carry it as `odds` |
| `ruleset.gd` | Loads `data/rulesets/*.json`: rounds, round length, damage scaling, legal actions |
| `fight_clock.gd` | Rounds and ticks |
| `fight_command.gd` / `fight_event.gd` | What goes in / what comes out. Event types are snake_case to match `data/triggers` |
| `fighter_state.gd` | One fighter's live state: stamina, damage, effective stats (stat × condition, `docs/11` §3.2), reaction time (D93) |
| `octagon.gd` | The cage shape, distance bands and cage proximity (`docs/01` §3, §18) |
| `judging.gd` | 10-point must scoring with three judges (`docs/01` §11, §18) |
| `contest.gd` | The one odds formula every exchange uses (`docs/11` §3.1) |
| `style_leanings.gd` | Pace / Range / Base / Risk leanings, hints and named style traits (`docs/11` §4.2) |
| `action_library.gd` | Loads `data/actions/*.json` |

## world/
Empty for now: the career and world simulation (D100) starts here.
