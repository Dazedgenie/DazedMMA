# 07 — Onboarding & Tutorial

> Related decisions: D8, D37, D49, D82, D83. Status: **v1 spec**.
> Principle: **the story is the tutorial.** There's no separate tutorial mode. The childhood scenes, the gym walk-in and the first
> amateur fights introduce one system at a time, in context. Players who already know the game can skip it all.

---

## 1. Sequence

| Step | In-story moment | Teaches | New UI unlocked |
|---|---|---|---|
| 0 | Create the head coach (D63) | Who you are | — |
| 1 | Childhood vignettes (~8/12/15) | Choices shape stats, traits, frame, relationships | Fighter profile (grades + tags) |
| 2 | **Gym walk-in (~16)** | Gyms, coaches, money | Hub, calendar |
| 3 | First week of training | Weekly planner, fatigue, **1 minigame** (mitt work), auto-resolve | Planner, minigame |
| 4 | **Amateur fight 1** (easy opponent) | Watching the fight; speed controls; **3 calls only** (Pressure, Circle out, Takedown); voice meter | Call bar (3), voice |
| 5 | Corner after round 1 | Water, one adjustment, motivation | Corner screen (simplified) |
| 6 | Training block 2 | Film study → **first tell**; slow-mo | Scouting, tell cues |
| 7 | **Amateur fight 2** (the "Kicker" opponent) | **Read call "Catch the kick!"** + the perfect-call flourish. *The moment the game is built around* | Read slot Q |
| 8 | Training block 3 | **Rule drilling** → first drilled rule | Plan panel, rules |
| 9 | **Amateur fight 3** | Gameplan presets, drilled rule firing, full call bar, ground basics (Get up / Survive) | Full call bar, technique wheel |
| 10 | After fight 3 | Weight cut basics, offers, contracts | Offers screen |
| — | Later, as encountered | Cuts/cutman, submissions struggle, fouls, opponent corner calls, trips, life events | Introduced when they first happen, with a one-time tip card |

Each step takes about **2–5 minutes**. Steps 0–7 should get a new player to the **first "perfect catch-kick" moment within ~25 minutes**.

## 2. Rules
- **One new idea per screen.** Tip cards are short (≤ 2 sentences) and can be revisited in a **Coach's Notebook** glossary.
- **No fail states in steps 1–5**, but you *can* lose amateur fight 2 or 3. A loss gets a gentle "here's what happened"
  review using the feed explanations.
- **Skip options:** "I know the game" at coach creation skips the tips and unlocks everything (vignettes still play, but can be fast-forwarded).
- **Difficulty assistance (D69)**: on Easy, auto slow-mo is stronger, a "suggested call" hint appears, and active pause is available.

## 3. Prototype tie-in
The Phase 1 prototype (`10`) uses a **mini version of steps 4–9** as its playtest script, so testers learn the calls in the same order.

As built (D118): three fights in `data/playtest/` (`playtest@1`, `09` §3), picked from the setup screen's **Playtest** list,
each opening on a tip card of two sentences (§2):

| Playtest fight | Step | Calls open | Also |
|---|---|---|---|
| 1: your first calls (Wrestler vs Boxer) | 4 | Pressure, Circle out, Takedown | Voice meter, speed controls |
| 2: catch the kick (Wrestler vs Kicker) | 6–7 | + Catch the kick! (Q) | Tell cue on; the perfect-call flourish |
| 3: a drilled rule (Wrestler vs Kicker) | 8–9 | Every call, Get up and Survive for the ground | Catch & shoot drilled at 80% |

The corner screen (step 5) is the between-rounds panel with the rule slots; there's no film study yet, so the tell is
shown by the cue from fight 2. The host's script: `docs/playtests/script.md`. To change a fight, edit its JSON file.
