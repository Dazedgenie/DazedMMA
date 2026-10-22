# Chin Check — notes for AI coding sessions

- Design docs in `docs/` are the source of truth (decisions log: `docs/00-design-planning.md` §0).
  Every change should trace to a doc section or GitHub issue. If code and docs disagree, flag it.
- Engine: **Godot 4.7** (`project.godot`). Typed GDScript (`var x: int`, `:=`), tabs for indentation.
- Layers: `sim/` is pure logic with no Node/scene-tree use (see `sim/README.md`); `game/` and `ui/` are presentation.
- The user directs and doesn't read code: PR descriptions must be plain language (what changed, how to try it, what to look for).

## Commands
- Run the headless sim: `godot --headless --script res://tools/run_sim.gd`
- Smoke-run the main scene: `godot --headless --quit-after 30`
- Import/refresh the project cache: `godot --headless --import`
