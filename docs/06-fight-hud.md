# 06 — Fight Screen & HUD

> Related decisions: D1, D28, D49–D54, D67–D69, D80, D82, D117. Status: **v1 spec; HUD v0 built (#19), see §6**.
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

---

## 6. HUD v0 in the game (#19, D117)
The main scene (`game/main.tscn`, run it from the editor or `godot`) is the playable fight prototype. It opens on a setup
screen; **Start fight** plays three rounds with the player as the **red corner** and the AI corner calling for blue (D68).

### 6.1 The setup screen
| Setting | What it does |
|---|---|
| Playtest | Free fight, or one of the playtest's fights (D118, `docs/playtests/`): it sets the fight, the calls on the bar, the drilled rules and the tell cue, and opens on a tip |
| Your name | Saved with each fight for the playtest write-up (optional) |
| Fight | Wrestler vs Kicker (the playtest matchup, D112), Kicker vs Boxer, Wrestler vs Boxer, Boxer vs Kicker. You coach the first-named fighter |
| Speed | Normal is 2× fight time (D9), or 1× for the playtest's comparison (D91) |
| Difficulty | Normal, or Easy: P pauses the fight (D50) |
| Tell cue, Auto slow-mo, Perfect-call flourish | On/off, so the playtest can compare (D51–D53) |
| Drilled rules | Your fighter's two slots and the Drilled slider (`01` §23). Only rules whose move your fighter knows are offered |
| Seed | Blank for a random fight; type a number to get the same opening again (the result screen shows it) |

### 6.2 What's on screen (v0)
| Element | v0 | Code |
|---|---|---|
| Cage and fighters | Grey-box octagon and fence, orthographic isometric camera that follows the fighters and moves in for the clinch and closer still for the ground (D80). Fighters are capsule bodies with stick limbs that act out the move: punches reach out, kicks lift the leg (the rear one, the lead one for a teep), shots and sprawls drop the hips, the bottom fighter lies on their back, the top fighter postures up and drives down ground punches and elbows (pulled down flat while tied up), and the bottom fighter reaches up to tie up (D121). They slide between ticks | `game/arena_view.gd`, `game/fighter_figure.gd` |
| Over each fighter | The move's name, coloured by phase (telegraph yellow, wind-up orange, active red, recovery grey); the **delay ring** while a call is being processed, shrinking as the fighter gets to it; **nah** when a call is ignored; **READ** while a read call is primed; stars when rocked | `fighter_figure.gd` |
| Tell cue (D51) | When a scouted tell shows (the Kicker's jab blocked, the Wrestler's stance shift), the limb the move will come from glows and a **!** shows over the fighter, until the move starts or the tell's window runs out. Shape and colour, so it reads without colour | `arena_view.gd` `_on_event` |
| Ground tag | Under the fighters: the range standing (Out of range / Long / Mid / Pocket), the position tied up ("Full guard · Wrestler on top", "Submission · Kicker's triangle choke"). It grows when it changes, then settles | `ArenaView.tag_text` |
| Danger meter (D126) | While a submission is locked in: a red bar in the middle, 0 to 100, with the hold and the danger ("Kicker's TRIANGLE CHOKE on Wrestler · danger 60"). At 100 they tap, at 0 they're out. The fighters keep the pose of where it was locked from (a guillotine bends the defender over) | `FightHud.danger_text`, `fighter_figure.gd` |
| Top bar | Names; a big **health** bar per fighter (the head damage they can still take, D120: green, yellow under 60%, red under 30%, with the percentage and ROCKED when they are); stamina under it; small body and leg bars (same colours); round clock, speed, and the judges' rough estimate of the round so far ("≈ 10-9 Wrestler", from `FightSim.round_points()` with no judge noise). The damage pips of the first v0 became these bars | `ui/fight_hud.gd` |
| Plan panel | Each rule slot with how sharp it is right now (its reliability) and its cooldown, flashing green when it fires; the call being heard, the attempt in progress, the focus call with seconds left, primed reads with seconds left | `FightHud.plan_text` |
| Opponent corner | A speech bubble with the AI corner's call, 3 s | `fight_hud.gd` |
| Feed | Every event in words with the round clock; filter: All / Key moments / Explanations (why a takedown, call or rule didn't work, A16) | `ui/fight_feed.gd` |
| Voice meter | Your voice with the garbled zone (under 30) marked; it shakes when you repeat a call within 3 s (spam), and trust shows next to it | `ui/voice_meter.gd` |
| Call bar | 1–9 intent calls and Q/E read calls, clickable (key 1 is Pressure! standing, Ground and pound! on top and Finish it! in a submission; key 6 is Defend the shot! standing and Defend the sub! caught in one, D121, D126: the key makes whichever works from here); a call that can't be made from here is dimmed with the reason as its tooltip (no voice, not from this position, not learned). Pressing a dimmed call's key puts the reason in the feed. The call being acted on is tinted green | `fight_hud.gd` |
| Perfect call (D52) | A move your call started that works as a counter (a takedown that lands, a strike that lands in the opponent's wind-up or recovery): "PERFECT CALL" in the middle, a feed line and 1.2 s of slow-mo | `FightDriver.is_perfect_call` |
| Between rounds | The bell stops the fight: each judge's card for the round, the totals, both fighters' stamina and damage, and your rule slots to change for the next round | `game/main.gd` |
| Result | How it ended, the cards, strikes and takedowns, the seed, your corner's calls and where the fight was saved (D118); Next (in a playtest), Fight again, Change setup, Open saved fights | `game/main.gd` |
| Debug overlay (F3) | Seed, tick, fps, distance, range, position, and per fighter: the move and phase, flags, stamina, damage, hurt, wanted distance, circling, cutting off, cage, voice and trust. The 3D view adds the near-the-fence and pinned lines and each fighter's wanted-distance ring (what the old cage view showed, D106) | `ui/debug_overlay.gd` |
| Debug console (`) | The full log of the fight on screen with every odds breakdown, plus "Run test fight" | `ui/debug_console.gd` |

### 6.3 Speed (D9, D50, D52, D53, D91)
The fight screen feeds the sim whole ticks at the chosen speed (`game/fight_driver.gd`); it never changes what a tick does, so
the same seed and commands give the same fight at any speed (tested: a full fight played with random frame times, speed
changes and pauses against the same fight run headless).

| Speed | Fight seconds per real second | How |
|---|---|---|
| Normal | 2 (or 1, from the setup) | Default |
| Fast | 4 | F, or the button |
| Slow-mo | half of Normal | Space (toggle), or the button |
| Auto slow-mo | half of Normal for 1.5 s | A fighter rocked or knocked down, a scramble, or a submission locked in, through every beat of the struggle (D53, D126) |
| Flourish | half of Normal for 1.2 s | A perfect call (D52) |
| Pause | 0 | P on Easy only (D50). Calls still go in and land on the next tick |
| Held | 0 | The bell between rounds, the Esc menu, the towel question |

### 6.4 Keys (as built)
1–9 intent calls (1 is Pressure! standing, Ground and pound! on top, Finish it! in a submission; 6 is Defend the shot!, or Defend the sub! caught in one) · Q / E read calls (Q is Catch the kick!; E is empty until a second read call exists) · Space slow-mo ·
F fast · P pause (Easy) · T throw in the towel (asks first; a TKO loss, D31) · Esc menu (pauses on every difficulty) ·
Enter presses the dialog's first button · F3 debug overlay · ` debug console.

### 6.5 Not in v0 yet
- **Technique wheel (Tab, D6):** the only technique call is Catch the kick!, already on Q.
- **Gameplan picker:** live fights have no gameplan yet, so the plan panel says "own game".
- **Scouting grades (D24):** the opponent's numbers show exactly; **cuts** don't exist in the engine yet.
- **Judges' estimate on Hard / the coach's Reading skill:** there's no Hard and no coach skills yet; the estimate ignores judge noise and tie-breaks.
- **Sound** (the flourish's sting) and **colour-blind modes, text size, reduced flashing** (§5).
- **The corner screen (§4):** between rounds shows the cards and the rule slots only (no cutman, D30 is out of the prototype's scope, `10` §1).
- **Max 3 attention-grabbers (§5)** isn't enforced; the ground **position overlay** is the tag's text for now.

### 6.6 To change it, and the tests
- Speeds and slow-mo lengths: `FAST_RATE`, `NORMAL_RATES`, `SLOW_SHARE`, `AUTO_SLOW_SECONDS`, `FLOURISH_SECONDS` at the top of
  `game/fight_driver.gd`. What counts as a perfect call: `FightDriver.is_perfect_call`.
- Camera zoom and follow: `ZOOM_STANDING`, `ZOOM_CLINCH`, `ZOOM_GROUND`, `CAMERA_SPEED`, `FOLLOW_SHARE` in `game/arena_view.gd`.
- Body sizes, poses and phase colours: the constants and `pose_for` in `game/fighter_figure.gd`.
- Pip colours, bubble and flash times: the constants at the top of `ui/fight_hud.gd`. What the feed calls a key moment: `FightFeed.kind_of`.
- The matchups on the setup screen: `FightSetup.MATCHUPS`.
- Tests: `tests/game/test_fight_driver.gd` (speeds, pause, the bell, auto slow-mo, perfect calls, sliding, the towel, and
  speed never changing the fight), `tests/game/test_main_scene.gd` (a full three-round fight from setup to result, hotkeys,
  pause on Easy, the menu and the towel), `tests/game/test_arena_view.gd`, `tests/ui/test_fight_hud.gd`,
  `tests/ui/test_fight_feed.gd`, and the towel in `tests/sim/fight/test_fight_sim.gd`.
