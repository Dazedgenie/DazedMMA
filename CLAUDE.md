# Chin Check — notes for AI coding sessions

- Design docs in `docs/` are the source of truth (decisions log: `docs/00-design-planning.md` §0).
  Every change should trace to a doc section or GitHub issue. If code and docs disagree, flag it.
- Engine: **Godot 4.7** (`project.godot`). Typed GDScript (`var x: int`, `:=`), tabs for indentation.
- Layers: `sim/` is pure logic with no Node/scene-tree use (see `sim/README.md`); `game/` and `ui/` are presentation.
- Content lives in `data/` as JSON, one file per item (`docs/09-data-formats.md`). New fields or types: update the doc and `tests/data/test_data_files.gd` together.
- The user directs and doesn't read code: PR descriptions must be plain language (what changed, how to try it, what to look for).

## Commands
- Run tests (GUT 9.7, vendored in `addons/gut`): `mkdir -p build && godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json`
  Tests live in `tests/` (mirror `sim/` paths), extend `GutTest`, and are named as plain sentences (`test_round_ends_exactly_on_its_last_tick`).
  CI (`.github/workflows/tests.yml`) runs them on every PR and posts a readable table in the run summary.
- Run the headless sim: `godot --headless --script res://tools/run_sim.gd`
- Run the balance harness: `godot --headless --script res://tools/balance.gd -- --fights=100 --pairs=kicker:boxer` (CSV + summary in `build/balance/`)
- How fighters move round the cage (holding the centre, cutting off, getting off the fence) and the numbers to tune it: `docs/01-fight-engine.md` §20.2 (D107).
- Smoke-run the main scene: `godot --headless --quit-after 30`
- Clinch, takedowns and the ground (how a shot resolves, sprawls, knees into shots, getting up, judges' grappling points, the AI tied up): `docs/01-fight-engine.md` §21 (D108).
- How live coaching calls work (voice, delay, compliance, attempts/focus/reads) and where their numbers live: `docs/01-fight-engine.md` §22 (D111, D112).
- Coaching bots and the AI corner (who calls what, the harness's `--corners`/`--coach`, the D12 coaching checks), what a call costs, and strikers' answers to grappling: `docs/01-fight-engine.md` §22.5–22.9 and §21.8 (D113–D115).
- Drilled rules (two slots, reliability, cooldown, opponents adapting, the presets, `--rules` in the harness): `docs/01-fight-engine.md` §23 (D116).
- Speed budget (1000× fight time), the timing checks and how to speed things up without changing fights: `docs/01-fight-engine.md` §2.1 (D105).
- Import/refresh the project cache: `godot --headless --import`
