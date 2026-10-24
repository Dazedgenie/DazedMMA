# Chin Check *(working title)*

An MMA career simulation inspired by *Boxing School*. Create one fighter, shape them from childhood
through training camps, and coach them live from the corner. The right call at the right moment
wins fights.

**Status:** pre-production. The design is at v1; the Phase 1 fight prototype is next.

- Start here: [`docs/00-design-planning.md`](docs/00-design-planning.md) (vision, decisions log D1–D84, doc index)
- Engine: Godot 4.7 · low-poly 3D with an isometric camera · Windows PC first

## Running it
1. Install [Godot 4.7](https://godotengine.org/download) (standard build).
2. Open Godot → **Import** → select this folder's `project.godot` → **Run** (F5).
   Right now it shows an empty octagon from the isometric camera.
3. Headless simulation check (from a terminal in this folder):
   `godot --headless --script res://tools/run_sim.gd`
4. Balance harness (many fights, a CSV and a summary of the balance targets in `build/balance/`):
   `godot --headless --script res://tools/balance.gd -- --fights=100`

## Layout
| Folder | What lives there |
|---|---|
| `sim/` | Simulation core: pure logic, no scenes (fight engine, AI, coaching) |
| `game/` | Godot scenes and the game layer |
| `ui/` | HUD, menus, minigame UI |
| `data/` | Content data (moves, calls, rules, rulesets…) |
| `tests/` | Automated tests (GUT). Also runnable in the editor from the **GUT** panel at the bottom |
| `tools/` | Headless runners and dev scripts |
| `docs/` | Design docs (source of truth) |
| `addons/gut/` | The GUT test framework (third-party, MIT licence) |
