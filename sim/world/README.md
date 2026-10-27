# sim/world/ — career and world simulation

The career and world simulation (D100): pure logic under the same rules as `sim/fight/` (no scene tree, no real time,
seeded randomness), so 30-year world sims can run headless in CI. The game layer only schedules it.

So far: the training camp (`training_camp.gd`, `training_library.gd`; `docs/02` §3.5, D125). Try it with `tools/camp.gd`.
