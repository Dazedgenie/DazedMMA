# 06 — Fight Screen & HUD

> Related decisions: D1, D28, D49–D54, D67–D69, D80, D82. Status: **v1 spec**.
> Goal: the player can read **range, position, current action, the opening, and their own resources** at a glance
> (Foundation doc readability test), without the screen feeling like a cockpit.

---

## 1. Layout (1920×1080 reference, scales to 16:10 and 1280×720)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [YOU: name  ▓▓▓▓▓▓░ stamina]   R2  3:41  ⏵2×   [OPP: name  ▓▓▓▓░░ stamina] │ ← Top bar
│ [head ● body ● legs ●]  [cut ▲]  JUDGES ≈ 10-9 you  [head ● body ● legs ●]  │
├──────────────────────────────────────────────────────────────────────────────┤
│ ┌Plan──────────┐                                            ┌Opp corner────┐ │
│ │ Pressure     │                                            │ "Shoot on    │ │ ← Opponent corner
│ │ Rules:       │           3D OCTAGON (isometric)           │  him!" 🔊    │ │   speech (D68)
│ │ ① Kick→Catch │       • fighters + delay ring overhead     └──────────────┘ │
│ │   72% ⏱ready │       • tell cue glow (scouted, D51)                        │
│ │ ② Shot→Sprawl│       • position/range tag under fighters                   │
│ │   55% ⏱4s    │                                                             │
│ │ Reads:       │                                                             │
│ │ 👁 Kick 6s   │                                         ┌Feed────────────┐ │
│ └──────────────┘                                         │ 3:44 Jab lands │ │ ← Event feed /
│                                                          │ 3:42 Rule ①    │ │   commentary
│                                                          │   fired: catch │ │
│                                                          └────────────────┘ │
├──────────────────────────────────────────────────────────────────────────────┤
│ VOICE ▓▓▓▓▓▓▓░░░  [1 Pressure][2 Circle][3 Range][4 TD][5 Clinch][6 Def][7 Up]│ ← Call bar
│                   [8 Survive][9 Safe]  [Q/E read calls] [Tab: techniques]    │
└──────────────────────────────────────────────────────────────────────────────┘
```

## 2. Elements

| Element | Shows | Notes |
|---|---|---|
| **Top bar** | Name, stamina bars, round, clock, speed, damage pips (head/body/legs), cuts | Damage pips go green → yellow → red. Opponent shows exact numbers only if scouted (D24 grades) |
| **Judges estimate** | Rough round score ("≈ 10-9 you") | Hidden on Hard realism. Coach *Reading* skill improves accuracy |
| **Fighter overhead** | **Delay ring** (call being processed, D5), ignore icon ("nah"), rocked stars, primed-read eye | Small, follows the fighter |
| **Ground tag** | Range band (Long / Mid / Pocket / Clinch) or position (Half guard – top) | Text + icon. Big when the position changes, then shrinks |
| **Tell cue** | Glow on the telegraphing limb (scouted tells only, D51) | Appears earlier with a higher *Reading* stat (D66). Colour-blind-safe shape + colour |
| **Perfect-call flourish** | Short slow-mo, flash ring, sound sting, feed line (D52) | Can be turned off in settings |
| **Plan panel** | Current gameplan, drilled rules (reliability %, cooldown), active reads with timers (max 2, D67) | Collapsible. Rules flash when they fire |
| **Opponent corner** | Speech bubble with the AI corner's call (D68) | Also logged in the feed |
| **Feed** | Play-by-play + commentary (D20) + explanations ("Takedown stuffed: opponent balanced, TDD A-") | Filter: all / key moments / explanations only |
| **Voice meter** | Current voice; garbled zone below 30 (D28) | Shakes when you spam |
| **Call bar** | Calls 1–9 (context-sensitive: unavailable calls are dimmed). Q/E = the two most recent read calls | **Tab** opens the technique wheel (unlocked specific moves, D6) |

## 3. Input map (keyboard + mouse, D54)

| Input | Action |
|---|---|
| 1–9 | Intent calls (context-sensitive) |
| Q / E | Read calls ("Catch the kick", "Watch the shot"…), the two slots you assigned before the fight |
| Tab (hold) | Technique wheel; mouse to select the specific move |
| Space | Slow-mo toggle (hold or toggle, set in settings) |
| F | Fast speed (4×) toggle |
| P | Active pause (**Easy only**, D50) |
| T | Throw in the towel (opens a confirmation) |
| Mouse | Everything on the call bar and panels is clickable |
| Esc | Menu (also pauses on every difficulty, but the corner doesn't count it as thinking time) |

## 4. Between-round corner screen (D30)
- 60 s countdown at the top. Each action shows its time cost.
- Left: **round review** (key moments, damage changes, judges' estimate).
- Centre: fighter close-up with cuts/swelling → **cutman minigame** button.
- Right: **adjustments**: change gameplan, swap/edit drilled rules, reveal a tell (if scouted), motivation tone.
- Bottom: "Next round orders" summary (Foundation doc §10.3) + **Throw in the towel**.

## 5. Readability rules
- Max **3 animated attention-grabbers** on screen at once (cue, flourish, rule fire). Everything else is static.
- Every outcome that matters gets a feed explanation line (A16).
- The ground camera zooms in and adds a **position overlay** (simple top/bottom silhouette diagram) for ground readability (R5).
- Colour-blind modes; text size scaling; flashing can be reduced.
