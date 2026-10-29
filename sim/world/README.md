# sim/world/ — career and world simulation

The career and world simulation (D100): pure logic under the same rules as `sim/fight/` (no scene tree, no real time,
seeded randomness), so 30-year world sims can run headless in CI. The game layer only schedules it.

So far: the training camp (`training_camp.gd`, `training_library.gd`; `docs/02` §3.5, D125). Try it with `tools/camp.gd`,
or on screen with the camp planner (`ui/camp_planner.gd`, `docs/02` §3.6, D134), which shows `TrainingCamp.forecast`.
Ageing and the prime (`ageing.gd`, `docs/02` §3.8, D136): each week a camp runs ages the fighter; check it over a career
with `tools/career_curve.gd`. The mitt work minigame's round and judging (`mitt_work.gd`, `docs/02` §3.9, D137).
