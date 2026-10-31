# 04 — Tech & Production

> Related decisions: D3, D4, D46, D47, D48. Status: **draft for discussion**.

---

## 1. Constraints

- **About 20 hours/week** of your time (D46). Background: GTA V modding and web design/coding.
- **AI does most of the code and art** (D47). That changes how we work:
  - AI is fast but **inconsistent across sessions**, so the project needs strong written conventions, tests and docs.
  - Small, well-specified tasks work best. Every task should point at a design doc section.
  - You stay the **creative director and play-tester**. Your judgement on "does this feel right?" is the bottleneck, and that's on purpose.

---

## 2. Engine & architecture (Godot 4, D4)

### 2.1 Language
- **GDScript** (Python-like, quick to learn, and there's plenty of training data for AI help). Use typed GDScript (`var hp: int`) for safety.
- Revisit C# only if the headless simulation gets too slow (unlikely at this scale).
- **Renderer: Compatibility** (D101). Low-poly isometric needs nothing Forward+ offers, and Compatibility runs on far more playtest machines.

### 2.2 Layering

```
┌───────────────────────── Presentation (Godot scenes/nodes) ─────────────────────────┐
│  Isometric fight view · UI · minigames · menus · audio · animations                │
└───────────────▲─────────────────────────────────────────────────┬──────────────────┘
                │ reads state / events                              │ player commands
┌───────────────┴────────────────── Game layer ────────────────────▼──────────────────┐
│  Career calendar · camp planner · save/load · world sim scheduler                   │
└───────────────▲─────────────────────────────────────────────────┬──────────────────┘
                │                                                    │
┌───────────────┴──────────── Simulation core (pure GDScript) ───────▼──────────────────┐
│  FightSim (tick) · FighterState · ActionDefs · CallProcessor · AI · Judging          │
│  NO scene-tree dependencies → runs headless, deterministic, seeded RNG               │
└─────────────────────────────────────────────────────────────────────────────────────┘
          ▲
          │ loads
┌─────────┴─────────── Data (JSON or Godot .tres resources) ───────────────────────────┐
│  moves · positions · calls · backgrounds/vignettes · techniques · promotions · names │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

Key rules:
- The simulation **emits events** (`KickThrown`, `TakedownAttempt`, `CallIgnored`...). The presentation and commentary listen to them.
- The simulation never reads the clock or input directly. Commands come in through a queue.
- The **world and career simulation follow the same rules** (`sim/world/`, D100), so long-run world sims can run in CI. The game layer schedules; it never holds rules.
- **Seeded RNG** everywhere, so any fight can be replayed exactly from seed + command log (great for bug reports).

### 2.3 Tooling
- **Tests**: GUT (Godot Unit Test) for simulation-core unit tests.
- **Balance harness**: a headless script that runs N fights between stat profiles and writes CSV (win %, finish types, call efficacy).
  Target from D12: ~80% for the clearly better fighter, and coaching worth +10–20%.
  v1 (#18, D95) is `tools/balance.gd`: fighter pairs from `data/fighters/`, one CSV line per fight and a summary that marks
  each target as met or missed: draws under 2% and 10-10 on under 2% of judges' round cards (D97), Kicker vs Boxer within
  60/40 (#14's exit test, `12` §4, counted by fighter whichever corner they were in). Fatigue (D96), finish rate and how
  often the odds clamp bites are reported without a pass mark yet, and so is movement (D107): per pair, each fighter's
  share of standing time near the fence and pinned, who was nearer the centre, and how much of the fight was one fighter
  chasing the other; and how long each fighter circled and cut off the cage (D119, `01` §20.3). Grappling too (#15): per pair, takedowns landed and tried, time in the clinch, on the ground and on
  top, and the Wrestler's win share against the Kicker and the Boxer (D109, no pass mark until after the playtest).
  Coaching bots (ideal / spam / none) join with live calls (#16).
  Since D250 (`01` §2.4) the numbers carry 95% ranges, coaching and drilled rules are compared seed by seed against the
  same fights without them, each run writes `run.json` (commit, data hash, Godot version, speed a simulated tick), each row
  counts who chose the moves, and `tools/balance_compare.gd` compares two runs fight by fight.
- **CI**: GitHub Actions running headless Godot tests on every PR.
- **Debug overlay** in the fight view: raw stats, flags, action phases, AI scores.

### 2.4 Builds and platforms (D240)
- **Presets** (`export_presets.cfg`): *Windows Desktop* (the playtest build), *Linux* (CI's self-check fight) and *Web*.
  All three ship `data/*.json` with the build, because the game reads its data files at run time.
- **Web:** thread support is **off** (`variant/thread_support=false`). A threaded browser build needs the page served with
  cross-origin isolation headers, which GitHub Pages and most hosts don't send; without threads it runs anywhere. It uses
  the `web_nothreads_release` template. The strike sounds still build "in the background" through `WorkerThreadPool`,
  which on a no-threads build simply runs on the main thread.
- **Symbols in the browser:** a desktop borrows glyphs the game's fonts lack (→ ▶ ✔ …) from the system's fonts; a browser
  build can't, so they showed as boxes. `DisplayFont.add_symbols_fallback()` (called by `game/main.gd`) gives Godot's
  default font and Barlow Condensed a fallback, `ui/fonts/DejaVuSans.ttf` (Bitstream Vera licence, `ui/fonts/DejaVu-LICENSE.txt`).
  Any new symbol in a script or data file must be one some font draws: `tests/ui/test_display_font.gd` scans for them.
- **Building it:** the Playtest build workflow exports Windows, Linux and Web on every push to `main` and every PR
  (artifacts `ChinCheck-windows-<commit>` and `ChinCheck-web-<commit>`, kept 30 days). By hand, with Godot 4.7.2 and its
  export templates: `godot --headless --export-release "Web" build/export/web/index.html`. To try it, serve the folder
  (for example `python3 -m http.server` inside it) and open `index.html`; opening the file straight from disk doesn't work.
- **Hosted on GitHub Pages (D241):** the same workflow's `pages` job publishes the browser build to the repo's Pages
  address (`https://dazedgenie.github.io/DazedMMA/`) on every push to `main` (or **Run workflow** on `main`). It needs Pages
  switched on once: **Settings → Pages → Source: GitHub Actions**. Pages for a private repo needs a paid GitHub plan
  (Pro or above); the game page is public even though the code stays private. Until Pages is on, the job writes
  "The web build isn't on GitHub Pages yet" in the run's summary and stays green, so `main` doesn't go red over it.
- **Where it lives: itch.io (D242).** GitHub asked for an upgrade (Pages on a private repo needs Pro), so the game is on
  **https://dazedgenie.itch.io/chin-check** instead: free, and the code stays private. It's uploaded by hand, so a new
  version doesn't go up on its own. To update it: download `ChinCheck-web-<commit>` from the newest green Playtest build run
  on `main` (or export it yourself as above and zip the folder's contents), then on itch.io **Edit game → Uploads**, replace
  the zip, keep **This file will be played in the browser** ticked, and save. Embed: 1280 × 720, fullscreen button on,
  SharedArrayBuffer off (the build has no threads). The `pages` job above stays in the workflow, dormant, in case Pages is
  switched on later.
- **To change it:** the presets' options in `export_presets.cfg` (or Godot's **Project → Export**); the fallback font in
  `DisplayFont.SYMBOLS_PATH`; the workflow in `.github/workflows/playtest-build.yml`. Tests: `tests/game/test_export_presets.gd`,
  `tests/ui/test_display_font.gd`.

---

## 3. Art pipeline (low-poly 3D, isometric camera: D80)

The first playable local-fight-night art pass and the user-selected direction are in
[`13-visual-direction.md`](13-visual-direction.md). It explores a lower camera and faceted fighters.

The hard part of AI-assisted art is **consistency**. Real-time 3D with one shared rig fixes most of that.

1. **Style bible first**: low-poly shape language, palette, flat/toon shading, lighting, UI look. Locked before mass production.
2. **Fighters: one humanoid rig** (Blender) shared by every fighter. Looks come from swappable parts (heads, hair, tattoos,
   shorts, body-shape blend shapes), so customisation (D63) is cheap.
3. **Animations**: Mixamo-style library + Blender edits; later video-to-mocap. Retarget onto the one rig. Budget cleanup for
   foot sliding, contact and **paired interactions** (clinch, takedowns, ground), as in the Foundation doc checklist.
4. **Camera**: orthographic isometric by default. Smooth zoom/angle change for clinch and ground. The camera never affects outcomes.
5. **Readability features**: silhouette outlines, telegraph glow (D51), position overlay on the ground.
3. **Portraits, gyms, menus, vignette illustrations**: AI image generation with style references + manual cleanup.
4. **Placeholder first**: the prototype uses shapes/capsules. Art never blocks the simulation.

## 4. Audio
- Prototype: strike sounds are made in code (D190, `06` §6.8), so there are no sound licences to track; free SFX libraries for anything else. Later: AI/stock music and commentary voice (text-only commentary at launch is fine).

---

## 5. Workflow & process

- **Git**: `main` is always playable. Work on feature branches, then a PR + review into main.
- **One design-doc section → one task** for AI coding sessions. Every PR links its doc section.
- **Weekly loop** (20 h): ~2 h planning/review · ~14 h build (with AI) · ~4 h playtesting + notes.
- **Playtest log**: `docs/playtests/YYYY-MM-DD.md`, recording what felt good or bad. This drives design changes.
- **Direction over learning** (D59): no learning tasks. Each milestone ends with a playable build and a plain-language summary instead.

---

## 6. Roadmap with time estimates (at ~20 h/week)

> Rough estimates. AI help speeds up coding a lot, but playtesting and design iteration take the same time regardless.

| Phase | Content | Estimate |
|---|---|---|
| **0. Pre-production** | Finish the questions, lock design docs, style bible draft, Godot setup + learning | 2–4 weeks |
| **1. Fight prototype** | Headless sim + basic isometric shapes view. Standing + clinch + basic ground; 8 calls; voice meter; kick → takedown test (see `10-prototype-spec.md`) | 6–8 weeks |
| **2. Vertical slice** (D48) | Vignettes (short), gym walk-in, 1 camp with 3 minigames + planner, 3 fights, corner, cutman, save/load | 3–4 months |
| **3. Alpha** | All systems: full minigame set, world sim, promotions, contracts, injuries, submissions struggle, officials, commentary | 6–9 months |
| **4. Beta** | Content (vignettes, techniques, events), art production, balance, accessibility, Steam integration | 4–6 months |
| **5. Launch (1.0)** | Store page, trailer, demo (Steam Next Fest), release | 1–2 months |
| **6. Post-launch** | Women's divisions (D17), coach/next-generation mode, Heavyweight, mods | ongoing |

**Total to 1.0: about 1.5–2 years** at 20 h/week. The vertical slice (~5–6 months in) is the "is this worth finishing?" checkpoint
and a good moment for a public demo or Steam page.

---

## 7. Directing, not coding (D59)

You direct and AI writes the code. Your control comes from these tools instead of reading code:
- **Design docs** are the source of truth. Code that contradicts a doc is a bug in one of them.
- **Plain-language test names** you can read (e.g. `test_takedown_during_body_kick_gets_bonus`), plus a test report on every PR.
- **The balance harness report** (win rates, finish types, call effectiveness) as a readable summary.
- **A playable build after every milestone.** Your playtest notes drive the next tasks.
- **PR summaries** written for a non-programmer: what changed, how to try it, and what to look for.

## 8. Tools (D60)

| Need | Tool | Cost |
|---|---|---|
| Engine | Godot 4 | Free |
| Low-poly models + shared rig | **Blender** (you have it), exported as glTF into Godot | Free |
| Animations | Mixamo (free library), Blender for edits. Later: video-to-mocap tools | Free → low |
| Image generation (portraits, gyms, vignettes) | Pick one with style-reference support once the style bible exists | Subscription; decide in Beta |
| Sound | Free libraries (freesound etc.) for the prototype | Free |
| Playtest builds | Windows export + itch.io (private link) or a Discord file share | Free |
| Feedback | A simple form (e.g. Google Forms) linked from the build's title screen | Free |

## 9. Resolved & open questions
- P1 → **D59**: you direct; AI writes the code.
- P2 → **D60 → D80**: real-time low-poly 3D with an isometric camera.
- P4 → Blender now. Open to adding tools when they're needed (see §8).
- S3 → **D62**: friends + a small Discord.
- P3 → **D75**: GitHub issues + milestones after sign-off.
- P5 → **D76**: no budget for now; free tools only, art near the end.

## 10. Risk register (A12, from the Foundation doc + ours)

| # | Risk | Mitigation |
|---|---|---|
| R1 | Scope expansion | Prove the coaching loop first; gate every phase on its exit criteria |
| R2 | Animation bottleneck (paired MMA motion, ground) | Visual proof milestone right after the prototype; one rig; reuse + vary |
| R3 | Unclear AI ("my fighter ignored me") | Visible delay ring, ignore animation, explanations in the event log |
| R4 | Tactical exploits (one rule/call beats everyone) | Harness bots (ideal / spam / single-strategy) on varied seeds and opponents |
| R5 | Ground-game unreadable | Camera zoom + position overlays; compare options in the visual proof |
| R6 | World stagnation | Long-run world sims in CI (30 in-game years) |
| R7 | Management busywork | Auto-train, auto-resolve, "advance to next event"; track decisions per hour |
| R8 | Save corruption | Multiple slots, atomic write (temp file → rename), backup of last good save |
| R9 | AI-written code drifts from the design | Docs as source of truth, tests named in plain language, small PRs |
| R10 | Motivation/burnout (solo hobby) | Playable build every milestone, Discord playtests, visible progress |

## 11. Save system (A11)
- Multiple independent career slots. Each holds the fighter, world, calendar and event history.
- Autosave every week + before every fight. Atomic writes plus 1 backup save.
- Versioned save format with migrations (saves must survive updates).
- Combat replays (seed + command log) are separate from the career's RNG stream.
- **Built (D301, `03` §10.1):** three slots in `user://saves/` (`game/career_saves.gd`), each save written to a temporary
  file, checked, then swapped in, with the save before kept as a backup that loading falls back to; the format is
  versioned (`09` career@1) with `Career.migrate()` for older saves; the career's dice are apart from each fight's.
  Autosaving every week and before each fight comes with the career hub (D303).
