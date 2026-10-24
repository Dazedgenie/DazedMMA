# sim/ — simulation core

Pure GDScript (`RefCounted` classes). The fight engine, AI, coaching and judging live here.

Rules (docs/04-tech-and-production.md §2.2):
- **No Node or scene-tree dependencies.** Nothing here may extend `Node` or use `get_tree()`, `$`, or autoloads.
- **Never read real time or input.** Time advances only by `tick()`; commands arrive through a queue.
- **Seeded randomness only**, so any fight can be replayed from seed + command log.
- Emit events for presentation and commentary to listen to. Never call into `game/` or `ui/`.

## What's here
| File | Role |
|---|---|
| `fight_sim.gd` | The fight: `tick()` = 100 ms. Commands in (`submit`), events out (`events`, `event_emitted`). `FightSim.replay(seed, fighters, actions, command_log)` rebuilds a fight exactly |
| `fight_clock.gd` | Rounds and ticks |
| `fight_command.gd` / `fight_event.gd` | What goes in / what comes out. Event types are snake_case to match `data/triggers` |
| `fighter_state.gd` | One fighter's live state: stamina, damage, and effective stats (stat × condition, `docs/11` §3.2) |
| `octagon.gd` | The cage shape, distance bands and cage proximity (`docs/01` §3, §18) |
| `judging.gd` | 10-point must scoring with three judges (`docs/01` §11, §18) |
| `contest.gd` | The one odds formula every exchange uses (`docs/11` §3.1) |
| `style_leanings.gd` | Pace / Range / Base / Risk leanings, hints and named style traits (`docs/11` §4.2) |
| `action_library.gd` | Loads `data/actions/*.json` |
