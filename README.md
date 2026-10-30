# Chin Check

An MMA career and coaching game by **Lampsmoke Games**, inspired by *Boxing School*. Build one fighter through
training camps, then coach them live from the corner: the right call at the right moment wins fights.

**Status:** playable fight prototype (Phase 1 of the roadmap, [`docs/04`](docs/04-tech-and-production.md) §6). You can
plan a training camp week by week, then coach one fight against any of 15 opponent styles: striking, the clinch,
takedowns, ground positions and submissions, with the corner's calls on the keyboard. Career mode, saving and the
childhood vignettes come with the vertical slice (Phase 2).

- Start here: [`docs/00-design-planning.md`](docs/00-design-planning.md) (vision, decisions log, doc index)
- Engine: Godot 4.7 · low-poly 3D with an isometric camera · Windows first, with Linux and browser builds (D240)

## Playing it
- **In the browser:** `https://dazedgenie.github.io/DazedMMA/` once GitHub Pages is switched on (D241).
- **Download:** on GitHub, **Actions → Playtest build**, the newest green run on `main`, then under **Artifacts**
  `ChinCheck-windows-<commit>` (Windows) or `ChinCheck-web-<commit>` (the browser build: unzip it and serve the folder,
  or upload the zip to itch.io as an HTML game). More in [`docs/playtests/README.md`](docs/playtests/README.md) §1.
- **From the source:** install [Godot 4.7](https://godotengine.org/download) (standard build), open Godot → **Import** →
  this folder's `project.godot` → **Run** (F5). It opens on the fight setup's tale of the tape.
- **Controls:** keyboard and mouse. Keys 1–9 and Q / E make the corner's calls (the call bar is clickable too), Space
  slow-mo, F fast, P pause (Easy), T throw in the towel, M sound on/off, Esc menu, F3 debug overlay. No controller yet (D54).

## For developers
1. Tests (GUT): `mkdir -p build && godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json`
2. Headless simulation check: `godot --headless --script res://tools/run_sim.gd`
3. Balance harness (many fights, a CSV and a summary of the balance targets in `build/balance/`):
   `godot --headless --script res://tools/balance.gd -- --fights=100`

`CLAUDE.md` lists every system's doc section and the numbers to tune it.

## Layout
| Folder | What lives there |
|---|---|
| `sim/` | Simulation core: pure logic, no scenes (fight engine, AI, coaching, training camp) |
| `game/` | Godot scenes and the game layer |
| `ui/` | HUD, menus, minigame UI, fonts |
| `data/` | Content data (moves, calls, fighters, styles, rulesets, training sessions…) |
| `tests/` | Automated tests (GUT). Also runnable in the editor from the **GUT** panel at the bottom |
| `tools/` | Headless runners and dev scripts |
| `docs/` | Design docs (source of truth) |
| `addons/gut/` | The GUT test framework (third-party, MIT licence) |

## Credits
- Made by Lampsmoke Games. The code is written with AI help (Claude) under the studio's direction: the design docs
  are the source of truth and every change goes through a reviewed pull request ([`docs/04`](docs/04-tech-and-production.md) §7).
- [Godot Engine](https://godotengine.org) (MIT licence).
- [GUT](https://github.com/bitwes/Gut), the test framework (MIT licence, `addons/gut/`).
- [Barlow Condensed](https://fonts.google.com/specimen/Barlow+Condensed), the display font (SIL Open Font License 1.1, `ui/fonts/OFL.txt`).
- [DejaVu Sans](https://dejavu-fonts.github.io/), the fallback for symbols such as arrows (Bitstream Vera licence, `ui/fonts/DejaVu-LICENSE.txt`).
- The strike sounds are made in code; there are no recorded sounds.
