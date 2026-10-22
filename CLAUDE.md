# Chin Check — notes for AI coding sessions

- Design docs in `docs/` are the source of truth (decisions log: `docs/00-design-planning.md` §0).
  Every change should trace to a doc section or GitHub issue. If code and docs disagree, flag it.
- Engine: **Godot 4.7** (`project.godot`). Typed GDScript (`var x: int`, `:=`), tabs for indentation.
- Layers: `sim/` is pure logic with no Node/scene-tree use (see `sim/README.md`); `game/` and `ui/` are presentation.
- The user directs and doesn't read code: PR descriptions must be plain language (what changed, how to try it, what to look for).

## Commands
- Run tests (GUT 9.7, vendored in `addons/gut`): `mkdir -p build && godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json`
  Tests live in `tests/` (mirror `sim/` paths), extend `GutTest`, and are named as plain sentences (`test_round_ends_exactly_on_its_last_tick`).
  CI (`.github/workflows/tests.yml`) runs them on every PR and posts a readable table in the run summary.
- Run the headless sim: `godot --headless --script res://tools/run_sim.gd`
- Smoke-run the main scene: `godot --headless --quit-after 30`
- Import/refresh the project cache: `godot --headless --import`
