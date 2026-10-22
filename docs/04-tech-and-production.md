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
- **Seeded RNG** everywhere, so any fight can be replayed exactly from seed + command log (great for bug reports).

### 2.3 Tooling
- **Tests**: GUT (Godot Unit Test) for simulation-core unit tests.
- **Balance harness**: a headless script that runs N fights between stat profiles and writes CSV (win %, finish types, call efficacy).
  Target from D12: ~80% for the clearly better fighter, and coaching worth +10–20%.
- **CI**: GitHub Actions running headless Godot tests on every PR.
- **Debug overlay** in the fight view: raw stats, flags, action phases, AI scores.

---

## 3. Art pipeline (low-poly 3D, isometric camera: D80)

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
- Prototype: free SFX libraries. Later: AI/stock music and commentary voice (text-only commentary at launch is fine).

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
