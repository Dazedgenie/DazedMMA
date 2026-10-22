# 05 — Review Pass & Reconciliation with "Game Design Foundation v1.0"

> Inputs: our docs `00`–`10` (decisions D1–D66) and the user's **MMA Career Simulator — Game Design
> Foundation v1.0** (22 Oct 2026, "the Foundation doc"). Also a quick look at **Glass Jaw** (reference game).
> Purpose: find overlaps, gaps and conflicts, adopt the best of both, and list the decisions still needed before sign-off.

---

## 1. Summary

The two plans agree on the core: **one fighter, coaching in real time, a career with consequences, and a
simulation kept separate from presentation, tested with seeds before art.** The Foundation doc is stronger on
**engineering discipline** (risks, acceptance tests, save integrity, world-sim tiers, difficulty split). Our docs
are stronger on **game feel and content** (voice meter, compliance, tells, submissions, corner, life, trips, generated promotions).

There are **three real conflicts** that need your decision (§4). Everything else merges cleanly.

---

## 2. Things the Foundation doc does better → adopted now

| # | Idea from the Foundation doc | Where it goes | Status |
|---|---|---|---|
| A1 | **Conditional standing rules** ("when opponent begins a body kick → attempt takedown if eligible") with priority, cooldown, fallback and a *visible explanation* | `01` §6: a third coaching layer between gameplan and live calls | **Proposed** (conflict C2) |
| A2 | **Fighter autonomy principles**: never silently replace the gameplan, never attempt impossible actions, no instant switching, always defend real danger | `01` §7 | Adopted |
| A3 | **Speed controls: Normal / Fast / Tactical slow-mo (10–20%)**: the simulation clock slows, not only the animation | `01` §2 | Adopted: we add **Fast** (4×) for quiet moments, and test slow-mo at 0.15–0.5× |
| A4 | **Difficulty split into 3 dimensions**: combat challenge / simulation realism / coaching assistance. Same rules underneath | `01` §16 | Adopted (matches your "Both" answer) |
| A5 | **Minigames are optional bonuses, not gates**: baseline progress comes from the plan, and minigames raise session *quality* | `02` §3 | Adopted. Same maths as D14, framed better |
| A6 | **Camp phases**: early (development), middle (matchup + sparring), late (taper/recovery) | `02` §4 | Adopted |
| A7 | **Conditional loss consequences**: a narrow loss to a top-ranked fighter can *raise* reputation; a sloppy loss to an underdog hurts more | `03` §3 | Adopted |
| A8 | **Retirement principle**: forced retirement is rare, foreshadowed and explained, with a career epilogue | `03` §6 | Adopted |
| A9 | **World-sim tiers**: player (full), important competitors (detailed), wider world (statistical) | `03` §2 | Adopted. Needed for performance with ~600 fighters (D55) |
| A10 | **Explainable rankings** (recent results, opponent quality, activity, title status) + **long-run validation** (no frozen divisions or runaway champions) | `03` §2 | Adopted |
| A11 | **Save integrity**: multiple career slots, safe checkpoint writes, recovery from interrupted saves | `04` §2 | Adopted |
| A12 | **Risk register** (scope, animation, AI clarity, exploits, ground readability, world stagnation, busywork, save corruption) | `04` §10 | Adopted |
| A13 | **Prototype acceptance tests** (timing, tactical value, fairness, slow-mo, rules, autonomy, readability, reproducibility) | `10` §2 | Merged with our success criteria |
| A14 | **Animation pipeline checklist** (one rig, retargeting, foot sliding, *paired interactions*) | `04` §3 | Adopted. Scheduled for after the prototype (D61) |
| A15 | **Scope guardrail**: "Don't build the whole sport before proving the coaching loop." | `00` pillars | Adopted as a production rule |
| A16 | **Event log explains rule decisions** (why a rule fired, was suppressed, or fell back) | `01` §12 | Adopted |

## 3. Things our docs have that the Foundation doc doesn't (kept)

Voice meter + call spam penalty · compliance/ignored calls · now calls vs read calls · tells + scouting + on-screen
cues · submission struggle sequences · cutman minigame + a corner with a time budget · referee/judge personalities ·
fouls · commentary · habits from calls · cage strategy · 12 backgrounds through vignettes · 10 minigames · training trips ·
gyms/coaches as a strategic layer · weight-cut mini-system · promotions generated per career · life/family events ·
customisable head coach with progression · ironman · titles/GOAT legacy.

The Foundation doc's open questions that we've **already answered**:
weight classes (emerge + can move: D35/D44) · judging detail (personalities: D20) · weight cutting (mini-system: D23) ·
career length (20–30 h: D16) · session design (D25) · auto-accelerate (auto slow-mo D53 + Fast speed A3) ·
appearance/customisation (fighter + coach: D63).

---

## 4. Conflicts that need your decision

### C1. Presentation: low-poly 3D (Foundation doc) vs isometric 2D sprites (D2/D60)
- The Foundation doc: **low-poly 3D fighters**, isometric camera that zooms in for clinch/ground.
- Our docs: **isometric 2D**, made by rendering 3D models to sprite sheets.
- **Recommendation: switch to real-time low-poly 3D in Godot with a fixed isometric (orthographic) camera.**
  - Our 3D→2D plan already needs a 3D rig and animations. Rendering them live skips the sprite-baking step
    (8 angles × every animation × every fighter look).
  - Camera zoom for clinch/ground (helps ground readability, risk R5) is free in 3D and expensive in 2D.
  - Customisable fighters (hair, tattoos, shorts) are much easier in 3D.
  - The game still *looks* isometric from above, so cage readability (D2) is unchanged.

### C2. Coaching layers: rule builder (Foundation doc) vs live calls only (ours)
- The Foundation doc: **strategic preset + conditional rules + advanced rule builder**, set before the fight and between rounds.
- Our docs: **gameplan + live now/read calls + corner**.
- **Recommendation: combine them into four layers**, with the rules tied to training:

| Layer | When | Source |
|---|---|---|
| 1. Gameplan preset | Pre-fight | Both docs |
| 2. **Drilled rules** ("When he kicks → catch & shoot"): limited slots | Set pre-fight / between rounds | Foundation doc, **but** each rule must be **drilled in camp** (training → rule reliability) |
| 3. Live calls (now + read, voice meter) | During the round | Ours |
| 4. Corner | Between rounds | Ours |

  Drilled rules run automatically with the fighter's own reaction time and reliability (based on how well
  they were drilled + Fight IQ). Live calls handle what the plan didn't predict. This also ties training to fight night (pillar 4).
  **Rule-builder complexity**: start with simple *trigger → action* rules (2–3 slots); advanced conditions/cooldowns are a later unlock.

### C3. Career start age: teenage development + amateur (Foundation doc) vs vignettes + gym walk-in at ~19 (D8/D37)
- **Recommendation:** vignettes at ~8 / ~12 / ~15, then the **gym walk-in at ~16** with a short teen amateur phase
  (amateur rules: shorter rounds, shin guards, no elbows). Turning pro is possible at 18+.
  This keeps the vignettes as summaries and makes the teenage/amateur stage *playable but short*.

### Smaller differences (resolved by default unless you object)
- **Engine**: the Foundation doc keeps Unity open, while we locked Godot (D4). Godot handles low-poly 3D fine. We keep Godot,
  and the prototype acts as the workflow proof.
- **World**: Foundation doc "entirely fictional MMA world" + D57 "real places, fictional promotions": compatible.
- **Ironman**: Foundation doc "later", ours yes (D45). We keep it but it isn't needed until Beta.
- **Prototype art**: the Foundation doc has low-poly fighters in the Fight Lab, while D61 says no art. We keep capsules for the
  prototype, and the animation/visual proof becomes its own milestone (Foundation doc milestone 4).

---

## 5. Glass Jaw (reference)
Couldn't load playglassjaw.com from the dev environment. Public info: a retro MMA career sim where you
**manage** a fighter in a **shared online world**, with **live fight cards several times a day**, and you adjust
**game plan and aggression between rounds**.
- **Take:** the excitement of **watching a whole card play out** (supports D73), and simple, clear between-round adjustments.
- **Leave:** online/shared world: we're single-player offline.

---

## 6. Review pass on our own docs: issues found & fixes

| # | Issue | Fix |
|---|---|---|
| R1 | `00` §3.2 still shows pre-decision "[ASSUMPTION]" coaching text | Marked as superseded by `01` |
| R2 | `00` §7 question list looks unanswered | Banner added: answered, see decisions log |
| R3 | `00` §5 roadmap duplicates `04` §6 with no estimates | `04` is the source of truth; `00` links to it |
| R4 | D18 says "2–3 major leagues" but D41 says 2 pro orgs | D18 marked as refined by D41 |
| R5 | `02` §3.1 "1–3 sessions" didn't say who picks | You pick (D70) |
| R6 | No save-system spec | Added (A11) |
| R7 | No risk register | Added (A12) |
| R8 | No HUD / UI spec for the fight screen | **Gap**: added to the backlog for Phase 0 wrap-up (`01` §17) |
| R9 | No tutorial / onboarding plan, even though the coaching system is complex | **Gap**: added to the backlog. The first amateur fights double as the tutorial |
| R10 | Amateur vs pro rules not defined | Added with C3 |
| R11 | Fight speed: one 2× time scale only | Normal 2× / Fast 4× / slow-mo (A3) |
| R12 | Prototype acceptance tests lacked "autonomy" and "reproducibility" | Merged (A13) |

---

## 7. Title ideas (D77: still open)
Avoid: *Corner King* (existing game), *Glass Jaw* (existing game), *Octagon* (trademarked by the UFC).

| Name | Why |
|---|---|
| **In Your Corner** | The player *is* the corner. Warm tone |
| **Corner Call** | The core mechanic in two words |
| **Between Rounds** | The corner + the life between fights |
| **Bangkok Ready** | Fun, memorable, from your own words. Maybe a subtitle or an achievement |
| **Fight Camp** | Clear genre signal (check existing titles) |
| **Chin Check** | Punchy, MMA slang |
| **Read the Kick** | The "perfect call" moment as the title |
| **Dazed** (e.g. *Dazed: Corner Call*) | Keeps your repo/brand name |
| **Path of the Belt** / **Road to the Belt** | Career-journey framing |
| **Cagewise** | Fight IQ + cage |

Before committing: search Steam and do a basic trademark search for any finalist.
