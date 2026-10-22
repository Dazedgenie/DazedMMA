# sim/ — simulation core

Pure GDScript (`RefCounted` classes). The fight engine, AI, coaching and judging live here.

Rules (docs/04-tech-and-production.md §2.2):
- **No Node or scene-tree dependencies.** Nothing here may extend `Node` or use `get_tree()`, `$`, or autoloads.
- **Never read real time or input.** Time advances only by `tick()`; commands arrive through a queue.
- **Seeded randomness only**, so any fight can be replayed from seed + command log.
- Emit events for presentation and commentary to listen to. Never call into `game/` or `ui/`.
