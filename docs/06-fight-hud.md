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
| **Top bar** | Name, stamina bars, round, clock, speed, damage pips (head/body/legs), cuts | Damage pips go green → yellow → red (built as the body figure, D150, §6.2). Opponent shows exact numbers only if scouted (D24 grades) |
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
| The fighters | ◀ ▶ on each side of the tale of the tape (§6.7, D172): any two fighters with a style sheet, a mirror too. It opens on Wrestler vs Kicker (the playtest matchup, D112). You coach the red corner, on the left |
| Rules | Pro (unified rules, the default), PRIDE rules (D141, `01` §33: a 10-minute first round, soccer kicks and stomps on a downed man, knees on the ground, the whole fight judged), Amateur 18+ or Amateur 16–17 (`08`). A playtest fight is always pro |
| Speed | Normal is 2× fight time (D9), or 1× for the playtest's comparison (D91) |
| Difficulty | Normal, or Easy: P pauses the fight (D50) |
| Tell cue, Auto slow-mo, Perfect-call flourish | On/off, so the playtest can compare (D51–D53) |
| Sound | The strike sounds' volume, 0–100% (§6.8, D190); M mutes them during a fight |
| Drilled rules | Your fighter's two slots and the Drilled slider (`01` §23). Only rules whose move your fighter knows are offered |
| Seed | Blank for a random fight; type a number to get the same opening again (the result screen shows it) |
| Training camp first | Opens the camp planner for your fighter (`02` §3.6, D134); its *Fight!* starts this fight with the fighter as the camp left them. *Start fight* skips the camp |

### 6.2 What's on screen (v0)
| Element | v0 | Code |
|---|---|---|
| Cage and fighters | Grey-box octagon and fence, orthographic isometric camera that follows the fighters and moves in for the clinch and closer still for the ground (D80). Fighters are capsule bodies with stick limbs that act out the move: punches reach out, kicks lift the leg (the rear one, the lead one for a teep), shots and sprawls drop the hips, the bottom fighter lies on their back, the top fighter postures up and drives down ground punches and elbows (pulled down flat while tied up), and the bottom fighter reaches up to tie up (D121). On the ground the two are laid out by the position: guard, half guard, side control, mount and the back each look different (D210, §6.10). They slide between ticks | `game/arena_view.gd`, `game/fighter_figure.gd` |
| Over each fighter | The move's name, coloured by phase (telegraph yellow, wind-up orange, active red, recovery grey); the **delay ring** while a call is being processed, shrinking as the fighter gets to it; **nah** when a call is ignored; **READ** while a read call is primed; stars when rocked | `fighter_figure.gd` |
| Tell cue (D51) | When a scouted tell shows (the Kicker's jab blocked, the Wrestler's stance shift), the limb the move will come from glows and a **!** shows over the fighter, until the move starts or the tell's window runs out. Shape and colour, so it reads without colour | `arena_view.gd` `_on_event` |
| Ground tag | Under the fighters: the range standing (Out of range / Long / Mid / Pocket), the position tied up ("Full guard · Wrestler on top", "Submission · Kicker's triangle choke"). It grows when it changes, then settles | `ArenaView.tag_text` |
| Position diagram (D210) | On the left above the call bar while the fight is on the ground: a top-down stick drawing of the position in the corners' colours and its name ("MOUNT · WRESTLER ON TOP"; in a hold, "TRIANGLE CHOKE FROM FULL GUARD"). §6.10 | `ui/position_diagram.gd`, `FightHud.position_text` |
| Danger meter (D126) | While a submission is locked in: a red bar in the middle, 0 to 100, with the hold and the danger ("Kicker's TRIANGLE CHOKE on Wrestler · danger 60"). At 100 they tap, at 0 they're out. The fighters keep the pose of where it was locked from (a guillotine bends the defender over) | `FightHud.danger_text`, `fighter_figure.gd` |
| Top bar | Names; a **body figure** per fighter (D150) whose head, body and legs run green → yellow → red with that area's damage, a readout beside it (HEAD 65% · BODY 94% · LEGS 100%: what's left of each, in the same colour; the head is health, D120, and at 0 the referee stops it) and ROCKED under it while they are. A part flashes white when a clean shot lands on it and a rocked head pulses. Each leg shows its own damage (D144), drawn facing you, and a low kick flashes the leg it hit. Stamina is a thin bar underneath. Then the round clock, speed, and the judges' rough estimate of the round so far ("≈ 10-9 Wrestler", from `FightSim.round_points()` with no judge noise; under PRIDE rules who they'd give the whole fight to and why, "≈ Wrestler (control)", from `FightSim.fight_scores()`, D141). The figure replaced the health bar and small body and leg bars of D120. The names, round clock, round banner and ROCKED are in the display font (Barlow Condensed, D171) | `ui/fight_hud.gd`, `ui/body_damage_figure.gd` |
| Plan panel | The corner's gameplan (or *own game*), and *drifting off the plan* when it's going badly (D320, D323, `01` §42); each rule slot with how sharp it is right now (its reliability) and its cooldown, flashing green when it fires; the call being heard, the attempt in progress, the focus call with seconds left, primed reads with seconds left | `FightHud.plan_text` |
| Opponent corner | A speech bubble with the AI corner's call, 3 s | `fight_hud.gd` |
| Feed | Every event in words with the round clock; filter: All / Key moments / Explanations (why a takedown, call or rule didn't work, A16). A feint says whether the opponent bit, and a shot with nothing setting it up starts "blind" (D131, `01` §29.4) | `ui/fight_feed.gd` |
| Voice meter | Your voice with the garbled zone (under 30) marked; it shakes when you repeat a call within 3 s (spam), and trust shows next to it | `ui/voice_meter.gd` |
| Call bar | 1–9 intent calls and Q/E read calls, clickable (key 1 is Pressure! standing, Ground and pound! on top and Finish it! in a submission; key 6 is Defend the shot! standing and Defend the sub! caught in one; key 5 is Clinch! standing and Collar tie! in the clinch; key 4 is Takedown! standing and in the clinch and Pass! on top on the ground; key 7 is Feint! standing and Get up! on the ground; key 2 is Circle out! standing and Go for the finish! on top, D121, D126, D129, D130, D131, D200: the key makes whichever works from here); a call that can't be made from here is dimmed with the reason as its tooltip (no voice, not from this position, not learned). Pressing a dimmed call's key puts the reason in the feed. The call being acted on is tinted green | `fight_hud.gd` |
| Perfect call (D52) | A move your call started that works as a counter (a takedown that lands, a strike that lands in the opponent's wind-up or recovery): "PERFECT CALL" in the middle, a feed line and 1.2 s of slow-mo | `FightDriver.is_perfect_call` |
| Between rounds | The bell stops the fight: each judge's card for the round, the totals, both fighters' stamina and damage, and your rule slots to change for the next round | `game/main.gd` |
| Result | The result screen (§6.9, D173): a full-screen card with the verdict, both figures as they finished, the fight sheet, the judges' cards round by round and your corner's grade; the seed and where the fight was saved (D118); Next (in a playtest), Fight again, Change setup, Open saved fights | `ui/result_card.gd`, `game/main.gd` |
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
1–9 intent calls (1 is Pressure! standing, Ground and pound! on top, Finish it! in a submission; 6 is Defend the shot!, or Defend the sub! caught in one; 5 is Clinch!, or Collar tie! in the clinch; 4 is Takedown!, or Pass! on top on the ground; 2 is Circle out!, or Go for the finish! on top, D200) · Q / E read calls (Q is Catch the kick!; E is Fire back!, D133: answer a defended strike with a combination, `01` §31.4) · R Cut the cage! (D230: 15 s of cutting off the exits instead of following, `01` §20.5) · H Hand fight! (D265: in the clinch and on the ground, 10 s of every grip he goes for 15% likelier to work, `01` §40.13) · Space slow-mo ·
F fast · P pause (Easy) · T throw in the towel (asks first; a TKO loss, D31) · M strike sounds on/off (D190) · Esc menu (pauses on every difficulty) ·
Enter presses the dialog's first button · F3 debug overlay · ` debug console.

### 6.5 Not in v0 yet
- **Technique wheel (Tab, D6):** the only technique call is Catch the kick!, already on Q.
- **Scouting grades (D24) everywhere:** the setup's tale of the tape scouts the opponent as grades (§6.7); anywhere else that shows his stats still shows them exactly; **cuts** don't exist in the engine yet.
- **Judges' estimate on Hard / the coach's Reading skill:** there's no Hard and no coach skills yet; the estimate ignores judge noise and tie-breaks.
- **Sound** beyond the strikes (§6.8): the flourish's sting, the bell, the crowd, music; and **colour-blind modes, text size, reduced flashing** (§5).
- **The corner screen (§4):** between rounds shows the cards and the rule slots only (no cutman, D30 is out of the prototype's scope, `10` §1).
- **Max 3 attention-grabbers (§5)** isn't enforced. The ground **position overlay** is the diagram on the left (D210, §6.10),
  not drawn over the cage; leg locks have no drawing yet.

### 6.6 To change it, and the tests
- Speeds and slow-mo lengths: `FAST_RATE`, `NORMAL_RATES`, `SLOW_SHARE`, `AUTO_SLOW_SECONDS`, `FLOURISH_SECONDS` at the top of
  `game/fight_driver.gd`. What counts as a perfect call: `FightDriver.is_perfect_call`.
- Camera zoom and follow: `ZOOM_STANDING`, `ZOOM_CLINCH`, `ZOOM_GROUND`, `CAMERA_SPEED`, `FOLLOW_SHARE` in `game/arena_view.gd`.
- Body sizes, poses and phase colours: the constants and `pose_for` in `game/fighter_figure.gd`.
- Bubble and flash times, the figure's size on the top bar (`FIGURE_SIZE`): the constants at the top of `ui/fight_hud.gd`.
  The body figure's colours (`FRESH`, `HALF`, `DONE`), hit flash (`FLASH_SECONDS`), rocked pulse (`PULSE_SECONDS`,
  `PULSE_LOW`) and shape (`_draw`): `ui/body_damage_figure.gd` (D150). What the feed calls a key moment: `FightFeed.kind_of`.
- The fighters the setup offers and their order: `FightSetup.FIRST` (then every other fighter with a style sheet); who it opens on: `DEFAULT_RED`, `DEFAULT_BLUE`; the rules it offers: `FightSetup.RULESETS`. The tale of the tape: §6.7.
- Tests: `tests/game/test_fight_driver.gd` (speeds, pause, the bell, auto slow-mo, perfect calls, sliding, the towel, and
  speed never changing the fight), `tests/game/test_main_scene.gd` (a full three-round fight from setup to result, hotkeys,
  pause on Easy, the menu and the towel), `tests/game/test_arena_view.gd`, `tests/ui/test_fight_hud.gd`,
  `tests/ui/test_body_damage_figure.gd`, `tests/ui/test_fight_feed.gd`, and the towel in `tests/sim/fight/test_fight_sim.gd`.

### 6.7 The tale of the tape (D172)
The setup screen (§6.1) is laid out like a broadcast's tale of the tape, in the camp screens' corner-board look (D170).

- **The two fighters:** your corner (red) on the left, the opponent (blue) on the right. Each has ◀ ▶ around his name to
  step through every fighter that has a style sheet (`data/styles`, D160), so any two can meet. Under the name: his style,
  a body figure (fresh) drawn to his height, and his style sheet's scouting card: the summary, then strengths (+) and
  weaknesses (−).
- **The tape, in the middle:** height, reach, stance and build face to face; the taller and longer-armed man's number is in
  his corner's colour. Then ten headline stats (speed, cardio, chin, boxing, kicking, power, takedowns, takedown
  defense, top control, submissions) as bars growing out from the middle. **Yours are exact** (the number and its
  grade). **His are scouted** (D24): only the grade, and his bar is solid to the grade's floor and faint across the
  rest of the band that grade covers (a B is somewhere from 50 to 64).
- **Keys to the fight**, under the tape, for the red corner: a reach edge of 5 cm or more (or, if reach is close, a
  height edge), a southpaw on either side, the stat where you're furthest ahead and the one where he is (two grades or
  more apart), and the scouting card's how-to-beat. No keys reads "An even match on paper".
- **The options** sit in a panel underneath: the playtest picker, rules, speed, your name, difficulty, seed, the three
  toggles, the drilled rules and the keys line, with a big red **Start fight** and **Training camp first** on the right.
  The subtitle under the title names the playtest fight and the rules.

**To change it:** the stats on the tape and their order: `TaleOfTheTape.TAPE_STATS`; how big a frame or stat gap must be
to make a key: `FRAME_EDGE_CM`, `STAT_EDGE_STEPS`; the keys' wording: `TaleOfTheTape.keys`; row heights, colours and
the bar drawing: the constants and `_draw` in `ui/tale_of_the_tape.gd`. The fighter order and the opening matchup:
`FIRST`, `DEFAULT_RED`, `DEFAULT_BLUE`; the figure's size (`FIGURE_H`, `FIGURE_TALLEST_CM`) and how far a long name
shrinks (`NAME_SIZE`, `NAME_MIN_SIZE`, `NAME_W`): `ui/fight_setup.gd`. The grades themselves: `TrainingCamp.GRADES`
(docs/11 §2.4). Tests: `tests/ui/test_fight_setup.gd`.

### 6.8 Strike sounds (D190)
Every strike has one sound of its own in three versions, **connected**, **missed** and **blocked**, made in code when the
game opens (`game/strike_sounds.gd`, about half a second on another thread; no audio files). Each is built from three layers:

| Layer | What it is | How it differs by strike |
|---|---|---|
| Swish | the arm or leg moving through the air: noise swept up and down a band | short and high for a jab, long and low for a head kick |
| Thump | the weight landing: a low tone that drops in pitch | ~150 Hz for a jab, ~55–85 Hz for kicks, knees and the stomp |
| Snap | the skin and glove: a short burst of bright noise | sharpest for elbows and leg kicks, a dull thud for body shots and the teep |

- **Connected** is all three. **Missed** is the same swish on its own, longer and louder, as the limb carries on past.
  **Blocked** is the same swish and thump with everything muffled (on the guard, the forearms or a shin). The swish and the
  thump's pitch never change between versions, which is what keeps them the same strike.
- **Which version plays** (`StrikeSounds.outcome_for`, from the fight's events): a landed strike is connected, unless it
  landed through a fighter covering up (`covered`, D180), which is blocked. A checked kick is blocked. A slipped punch is
  missed (it whooshes past his head; `SLIP_OUTCOME`). Any other miss, out of range or a lost roll, is missed. Only strikes
  make sounds; takedowns, grappling and the defences themselves are silent.
- **How loud:** a landed shot is louder (up to 7 dB) and a little deeper the more damage it does, from 2 damage (lightest)
  to 14 (heaviest). Every sound plays at a random pitch within ±4% so repeats don't sound the same. Both fighters' strikes
  sound the same.
- **Volume:** the setup's **Sound** slider (0–100%) and **M** during a fight (mute/unmute, said in the feed).
- **Listen without the game:** `godot --headless --script res://tools/strike_sounds.gd` writes `build/strike_sounds/<strike>.wav`
  (connected, missed, blocked with a pause between) and `all_strikes.wav` (every strike in turn).

**To change it:** a strike's sound is its line in `StrikeSounds.RECIPES` (`thump` pitch in Hz, `decay` how long it rings,
`snap` and `bright` the slap's loudness and sharpness, `swish` the whoosh's length, `tone` how high it sits, `gain`
loudness; each is explained above the table). A new strike needs a line (the test below fails until it has one): the hammerfist, body punch and posture-up bomb on the ground got theirs with D270 (`01` §41). The elbow and the punch from the bottom got theirs with D271 (`01` §45): the punch light and short, the elbow a sharp crack like the top man's. The
versions' loudness against each other: `OUTCOME_DB`; damage to loudness: `LIGHT_DAMAGE`, `HEAVY_DAMAGE`, `LIGHT_DB`,
`LIGHT_PITCH`, `HEAVY_PITCH`; random pitch: `PITCH_JITTER`; the overall level: `BASE_DB`; how many play at once: `VOICES`.
How each layer is shaped is `StrikeSounds.render`. To use recorded sounds later, `stream()` is the one place that hands
out a strike's version. Tests: `tests/game/test_strike_sounds.gd`.

**Not yet:** sounds for anything but strikes (the bell, the crowd, the referee, the flourish's sting, a knockdown hitting
the canvas, grappling), sounds placed left/right by where the fighters stand, and a sound settings menu.

### 6.9 The result screen (D173)
When the fight ends (the bell after the last round, a stoppage, a tap or the towel), a full-screen card opens over the
cage in the same corner-board look as the camp screens and the setup (D170, D172).

- **The verdict:** the winner's name and WINS in his corner's colour (DRAW in grey), and under it how and when: "by
  TKO (the referee stops it: nothing left) · Round 2, 3:41" (the time is how far into the round it ended), or "by
  unanimous decision (29-28, 29-28, 30-27) · after 3 rounds".
- **Both fighters as they finished:** the body figure (D150) and the HEAD · BODY · LEGS readout for each.
- **The fight sheet**, face to face like the tale of the tape (the better number lit in its corner's colour): strikes
  landed of thrown, then to the head, body and legs; knockdowns scored; takedowns landed of tried; control time (time
  on top in any ground position, or holding a submission); submission tries (leg locks too); and, under a line, how
  long each man circled and cut off the cage (D119).
- **The judges:** each judge's card round by round, each round's score in the colour of the man who won it, and the
  totals in bold. A finish shows the rounds scored before it and says the cards didn't decide it; under PRIDE rules
  (D141) each judge's pick and what decided it.
- **Your corner's grade:** a letter (docs/11 §2.4) with the calls made, perfect and ignored, the takedowns from your
  calls and from your drilled rules, and how often your rules fired. It starts at 50 (a C) and goes up 8 for each
  perfect call, 6 for each takedown from your call and 4 for each from a drilled rule, and down 5 for each call he
  ignored (0 to 100; a perfect call that was also a takedown counts both ways). With no calls and nothing from your
  rules there's no grade.
- Under it: a hurt fighter's injury after the fight (D135), the seed and where the fight was saved, then the buttons:
  Next (in a playtest) or Fight again in red, Change setup, Open saved fights.

**To change it:** the corner grade's numbers: `CORNER_START`, `PER_PERFECT_CALL`, `PER_CALL_TAKEDOWN`,
`PER_RULE_TAKEDOWN`, `PER_IGNORED_CALL`, and its colours `GRADE_COLOURS`; what's on the sheet and what counts as control:
`FightResultCard.sheet` and `sheet_rows`; the judges' table: `judges_bbcode`; the layout: `_init` and `_build_fighter`,
all in `ui/result_card.gd`. The notes and buttons: `_on_fight_over` in `game/main.gd`. Tests:
`tests/ui/test_result_card.gd` and the result in `tests/game/test_main_scene.gd`.

### 6.10 Ground positions you can tell apart (D210)
Kyle, 2026-10-30: "lets try to visually begin differentiating the different positions on the ground instead of all
looking like closed guard". He picked the grey-box bodies laid out per position plus a small diagram on the HUD (the
position overlay §5 planned), over the bodies alone or proper 3D models first.

**Why every position looked like closed guard.** The sim puts tangled-up fighters 0.4 m apart (`FightSim.TANGLED_GAP`)
and knows nothing about where their bodies are; the view drew them face to face, the man underneath on his back with his
feet toward the man on top. Only the top man's lean changed with the position. Now the view lays them out (presentation
only: `ArenaView.ground_spots`, it never changes the fight).

**The 3D view.** The man underneath stays on his sim spot and lies across the screen (his feet toward whichever side the
sim has the top man on), turned `LIE_TURN` (0.45 rad) so his feet point a little away from the camera: a man lying across
him then isn't seen end-on, and neither hides the other. The man on top goes to his spot in the position, measured from
the other man's hips (`ArenaView.GROUND_LAYOUTS`):

| Position | Where the top man is | The top man | The man underneath |
|---|---|---|---|
| Full guard | 0.55 m toward his feet, facing him | On his knees, leaning in | Legs up and spread round the waist |
| Half guard | 0.2 m toward his feet, 0.25 m to the far side, angled | Chest low on his, free leg back, the other caught | One leg hooked over, the other flat |
| Side control | 0.35 m up by his chest, 0.55 m to the far side, across him | Lying across his chest, knees by his hip | Knees bent, hands framing |
| Mount | On his belly (0.2 m up from the hips), facing his head | Sat up, knees spread either side | Flat, hands pushing on the hips |
| Back control | 0.5 m behind him, facing the same way | Sat behind, legs round the waist, arms round the neck | Sat up facing the camera (`facing_camera`), legs out |
| Crucifix (D264, `01` §40.12) | 0.55 m up by his head, 0.45 m to the far side, across him from the head side | Lying across his chest, his near arm trapped between the knees | Flat, both arms stretched out and trapped |

A kneeling leg shows just the thigh (`kneel`, `KNEEL_LENGTH` 0.65 of the leg); `spread` opens the legs sideways. When the
position changes, the top man slides and turns to his new spot (`LAYOUT_SPEED` 6 per second: most of the way in half a
second), so a pass or taking the mount is something you see happen. In a submission they keep the layout of where it was
locked from (an armbar from mount looks like mount); leg locks and the scramble stay face to face as before.

**The diagram.** While the fight is on the ground, a panel on the left above the call bar shows a top-down stick drawing
of the position: the man underneath with his head to the left, the man on top drawn over him, each in his corner's colour,
outlined so where they cross reads as over and under (on the back the man with the back is drawn underneath, his arms over
the other's neck). The caption is the position and who's on top in the display font ("SIDE CONTROL · WRESTLER ON TOP"),
or the hold and where it was locked from ("TRIANGLE CHOKE FROM FULL GUARD"). The scramble draws both up on their knees.
Standing and in a leg lock the panel is hidden. **The grips line (D265, `01` §40.13)**: under the caption, in yellow, who
holds what: "WRESTLER: BODY LOCK · BOXER: OVERHOOK" in the clinch (where the panel shows just "CLINCH" and the line, with no
drawing), "BOXER HOLDS A WRIST, FRAMES" or "BOXER'S ARMS TRAPPED" on the ground; hidden when nobody holds anything
(`FightHud.grips_text`).

**Front and back (D211).** Kyle, after the first screenshots: "Are we able to do something with the models so we can
differentiate between their front and back?" He picked a face, shorts and gloves (over a two-tone body, or a face alone).
Each fighter now has a skin-coloured face with two eyes on the front of the head, dark fight shorts (a band round the hips
and over the top of each thigh) with a white stripe down the front of the waistband, dark gloves on the ends of the arms,
and skin-coloured feet with the toes pointing forward. Gloves and feet ride the ends of the arms and legs as they stretch
but keep their own shape; a kneeling leg (only the thigh shows) hides its foot. It reads standing and on the ground: you
can see which way the man underneath is lying from his face and toes, and that the man on the back is facing his back.

**To change it:** where the top man goes and which way he faces: `ArenaView.GROUND_LAYOUTS` (`at` is metres toward the
other man's feet and to his far side; `face` is the way he faces in the same frame; `facing_camera` sits the man
underneath up facing you); the turn: `LIE_TURN`; how fast he slides: `LAYOUT_SPEED`, all in `game/arena_view.gd`. The
poses: the `match where` blocks in `FighterFigure.pose_for` (`game/fighter_figure.gd`), with `KNEEL_LENGTH`. The
drawings: `PositionDiagram.POSES` (head, hips, hands, knees and feet in a 100 × 80 box; `top_under` draws the top man
first), line widths and the outline at the top of `ui/position_diagram.gd`; the face, shorts, gloves and feet: their
colours (`FACE_COLOUR`, `GEAR_COLOUR`) and sizes (`GLOVE_RADIUS`, `FOOT_LENGTH`, `SHORTS_HEIGHT`) at the top of
`game/fighter_figure.gd`, built in `_build`; the panel's height `FightHud.DIAGRAM_HEIGHT`
and its caption `FightHud.position_text`. A new position needs a layout, a pose and a drawing (the diagram test checks
every position has one). Tests: `tests/game/test_arena_view.gd` (each position's layout, holds and leg locks, the slide,
the poses) and `tests/ui/test_fight_hud.gd` (the diagram, its caption, the panel only on the ground).

### 6.11 Fighter portraits off the fight screen (D430, D431)

Kyle, 2026-11-03: "lets work on visuals outside of the fight". A survey of every screen a career passes through (the
review page with screenshots of each: https://claude.ai/artifact/DnbNi6dCeeibuhXWDFVYSe) put them in this order, and Kyle
picked the first: **his own figure everywhere**, then the world pages as real pages, the hub rebuilt round the next fight,
the front door (title, gyms, childhood), one look for every screen, and the result as a moment (D430).

**What it is (D431).** Off the fight screen a fighter was the green capsule man (the body figure, D150). Now he's drawn as
himself (`ui/fighter_portrait.gd`, `FighterPortrait`): the skinned body (D284) with his height, build and reach and his
skin, hair and beard (D364), in his corner's shorts, standing in his stance (D362) and lit like the hall, on a see-through
background so the card shows behind him. Kyle's picks on the cards:

- **Framing, both by place:** full body (head to feet) on the big cards (fight night, the tale of the tape, the result and
  the new-career preview); head and chest on the small spots (the hub's fighter card now; offers and the world pages'
  tables later). Full body is drawn at one scale for everyone, feet on the bottom edge, so a taller man stands taller:
  the tape compares them by eye.
- **Breathe and bounce:** he shifts his weight slowly side to side and bounces a little, as if waiting for the bell, and
  breathes (the fight's own breathing).
- **The body figure stays small beside him:** a small capsule badge in the portrait's bottom corner shows where he's hurt,
  only once an area is 5% hurt (always on the result, where how they finished matters).

Where: the hub's fighter card (his bust beside his card text), the fight night card (full body, turned a little toward
the fight), the tale of the tape (both men full body, each turned toward the other), the result screen (both, with how
they finished), and the new-career screen (him as you pick his skin, hair, beard and stance, at an average 16-year-old's
frame until his background or childhood sets his own). The camp planner's condition card and the fight screen's top bar
keep the body figure as before.

The 3D is built the first time a portrait is drawn, so a screen that's never shown costs nothing; each portrait is a
small view of its own (one man, three lights).

**Riding along:** the version line ("Chin Check · fight prototype · Godot …") shows only on the title and load screens; on
the others it sat on top of the calendar, the camp's buttons and the setup's keys line.

**To change it:** the framing (`FULL_VIEW_HEIGHT`, `FULL_FLOOR_SHARE`, `BUST_VIEW_HEIGHT`, `BUST_CENTRE_DROP`), the lens
and how far round the camera looks (`LENS_FOV`, `THREE_QUARTER`), the idle (`SHIFT_SIDE`, `SHIFT_SECONDS`, `BOUNCE`,
`BOUNCE_SECONDS`), the badge (`BADGE_FROM`, `BADGE_SIZE`) and the lights (`KEY`, `FILL`, `RIM`) at the top of
`ui/fighter_portrait.gd`; each screen's size and turn where it makes its portrait (`CareerHub._init`,
`FightNightCard._build_fighter_card`, `FightSetup.FIGURE_H` and `FIGURE_TURN`, `FightResultCard.RESULT_BADGE` and its card,
`NewCareerScreen.PREVIEW_FRAME`). See them all at once: `godot --path . --rendering-driver opengl3 --script
res://tools/portrait_preview.gd -- --out=res://build/portraits`. Tests: `tests/ui/test_fighter_portrait.gd` and the
screens' own tests. Presentation only: fights and careers are unchanged (no golden re-pin).

### 6.12 The world pages (D432)

The second piece of D430. *His division*, *Promotions*, *Rankings* and *History* on the hub were long text in a pop-up
(D352, D354, D355, D358). Now they're one full-screen page with four tabs (`ui/world_screen.gd`, `WorldScreen`): each hub
button opens it on its own tab, the tabs switch between them, and *Back to the hub* or Esc closes it. Kyle picked
"Full-screen with tabs" and "Colour and badge" on the D430 cards, and my pick on all seven D432 cards about how each tab
looks (one promotion at a time, sort and filter, a man's card at the side, the belt timeline, badge shape by size, gold and
crimson fixed with the regionals rolled, badges only on the world pages for now).

- **His division** is a table of every man in it this week and him, one row each: name and nickname, age, where he's
  from, his level, his promotion and rank (*C* for a champion, with a belt by his name), record, style, grade, and how it
  went if you've fought him. Click a column's title to sort by it (best grade first to start; the same column again turns
  it round). Filters over it: Everyone, Pros, Amateurs, Ranked, Fought him. His row is picked out in green and stays in
  whatever the filter. A former champion's name is gold; each promotion's name is in its colour.
- **Rankings** shows one promotion at a time, picked from a row of its badges, opening on his own promotion (his home
  promotion until he's signed). Over the table: where he stands, then the champion with a belt (click him for his card).
  The table is #, the last move (▲ up, ▼ down, NEW, – none), name, record, where he's from and *former champion* tags;
  beside it the moves after its last card and why.
- **Promotions** is a card each, biggest first, edged in its colour with its badge: its name and kind (and whether it's
  yours or your hometown's), city, venue and seats, pay, how many men and how many at his weight, its champion at his
  weight, its next three cards as small posters in its colour (*HIS FIGHT* on his), the hometown legend on the home one,
  and its last card's results at his weight.
- **History** shows one promotion's belt at his weight at a time (the same badge row): every reign as a bar across the
  years, newest at the top, its length how long he held it, the defences on it and how it ended after it (yours green, the
  current one running to today with a white cap); click a row for his card. The hometown legend is over it, and the
  legends are a wall of cards under it, each with the belts he held once each ("ACL middleweight, 3 reigns, 5 defences").
- **A man's card.** Click a man anywhere and his card opens at the side (`ui/man_card.gd`, `ManCard`): his head-and-chest
  portrait (D431), name and nickname, his promotion's badge, record, level and age (retired and when), where he's from,
  his rank or belt or former belt, style, height and grade, how it went if you fought him, what you've scouted on him (the
  camp's scouting report, D401) and his last five fights in the world's results. Close or Esc shuts it.

**The badges (drawn in code, `ui/promotion_badge.gd`, `PromotionBadge`).** A promotion's initials on a shape that says how
big it is: the world organisation a belt plate, the international one a shield, a regional promotion a round badge. The
world organisation is always gold and the international one always crimson; each regional promotion gets its own colour
from a set of eight, shuffled by the world's seed, so it's the same all career and differs between careers. For now they
show only on the world pages; the hub gets them when it's rebuilt round the next fight (D430's next piece).

**To change it:** the tabs, filters and columns (`TABS`, `FILTERS`, `DIVISION_COLUMNS`, `RANK_COLUMNS`), his row's colour
(`HIM_ROW`), the table's look (`ROW_PAD`, `FONT_SIZE`, `_tree`) and the badge and belt sizes at the top of
`ui/world_screen.gd`; the badge colours and shapes (`WORLD_GOLD`, `INTERNATIONAL_CRIMSON`, `REGIONAL_COLOURS`,
`shape_of`) in `ui/promotion_badge.gd`; the timeline's rows and spacing (`ROW_HEIGHT`, `NAME_WIDTH`, `AXIS_HEIGHT`,
`BAR_HEIGHT`) in `ui/belt_timeline.gd`; the man's card (`WIDTH`, `PORTRAIT_SIZE`, `LAST_FIGHTS`) in `ui/man_card.gd`. The
old text pages (`CareerHub.division_text`, `rankings_text`, `promotions_text`, `history_text`) stay for the tests and the
30-year check. Tests: `tests/ui/test_world_screen.gd`. Presentation only: fights and careers are unchanged (no golden
re-pin).

### 6.13 The hub, rebuilt round the next fight (D433)

The third piece of D430. The hub had four columns of the same weight (his card, his stats, This week, his fights): the
offers, the choice that matters, started under the division's news and were cut off, and a booked fight was a line of
text. Now the next fight is the middle of the screen (`ui/career_hub.gd`; my picks on the seven D433 cards, built while
they're open):

- **The tab bar** under his name: *Hub*, then *His division*, *Rankings*, *Promotions* and *History* (each opens the world
  pages on its tab, D432) and the *Coach's Notebook* at the far end. The hub stays the tab that's down.
- **Left, his card** with *About* (his head and chest, D431, and his card's words) and *Stats* (every stat as a bar and a
  grade) on tabs, so the next fight has the room.
- **The middle, the next fight.** Each offer is a poster (`ui/fight_poster.gd`, `FightPoster`), side by side: along the
  top the card's name and fight night's date in its promotion's colour with its badge (an amateur or local card in grey);
  ribbons for what matters (*Coach's pick*, title fight, eliminator, call-up, tryout, tournament, how hard, *last week to
  answer*); both men face to face, him on the left in red and the other man on the right in blue, each with his name and
  record; *Take the fight* and *Turn it down*; then the offer's whole scouting card. Once he's booked, the poster stays up
  counting down (*5 WEEKS* to fight night, the date, where his camp is, the rules) over *Go to camp*. Under it, what the
  week holds (hurt, suspended, school, savings, the ladder, what the last week did), then the week's buttons, which stay
  put: the week plan, *Run this week* and *Advance* side by side (the plan hidden once he's booked), *Ask for a step up*,
  the debut division and *Turn pro*, and *Save and go to the title*.
- **Right, the news and his fights.** *Around the division* (the news that used to sit under This week, D353) and *His
  fights*, newest first, each line with its promotion's badge (D432) when it has one.
- **The calendar** along the bottom: each coming week with an icon for each thing in it, drawn in code
  (`ui/calendar_icon.gd`, `CalendarIcon`): crossed gloves for fight night (its week edged red), a red cross for hurt, a
  green one for healed, a tick for cleared to fight, a candle for a birthday, a book for school, a sun for the summer
  holidays, an envelope for offers, a coin for the gym shifts, a low battery for worn down.

A poster is kept while its offer stays up (each has two portraits to build) and made new for a new one.

**To change it:** the columns' widths (`FIGHTER_CARD_WIDTH`, `SIDE_WIDTH`) and the badge by a line (`LINE_BADGE`) at the
top of `ui/career_hub.gd`; a poster's width, faces and ribbon colours (`WIDTH`, `FACE`, `AMATEUR`, `PICK`, `TITLE`, `STEP`,
`URGENT`) in `ui/fight_poster.gd`; the icons' size, colours and drawings (`SIZE`, `COLOURS`, `_draw`) in
`ui/calendar_icon.gd`. The hub's words are unchanged (`offer_text`, `week_text`, `news_text` and `news_items`,
`fights_text` and `fight_lines`). Tests: `tests/ui/test_hub_rebuild.gd` and `tests/ui/test_career_screens.gd`.
Presentation only: fights and careers are unchanged (no golden re-pin).

### 6.14 The front door (D434)

The fourth piece of D430: the screens a new player sees first, before his first week. They were dark pages of text
and lists. Now (my picks on the eight D434 cards, built while they're open):

- **The title over a real fight** (`game/title_backdrop.gd`, `TitleBackdrop`). Two men picked at random from the roster
  (never the tests' own `check_` fighters) fight a simmed fight in the cage behind the menu: both corners the AI's,
  at normal speed with the fight screen's own slow-downs on big shots, no names over their heads and no range tag
  (`ArenaView.backdrop`), the referee in with them, the camera slid left so they sit to the right of the menu, and
  silent. When it ends the finish is held, and a few seconds later a new pair walks in. It runs only while the title is
  up: any other screen stops it and clears the cage, and a real fight takes the cage over. Headless runs (the tests,
  the smoke run) leave it off unless a test asks (`backdrop_in_headless` in `game/main.gd`).
- **The menu down the left** (`ui/title_screen.gd`): CHIN CHECK, Lampsmoke Games and the buttons in a dark strip that
  fades out over the fight.
- **New career on one page** (`ui/new_career_screen.gd`): you and him on the left as before; in the middle his full
  figure (D431) under a spotlight, changing as his look is picked, with his name and nickname, stance and hometown under
  him; on the right where he comes from, the 12 backgrounds as tiles each with a picture drawn in code
  (`ui/background_icon.gd`, `BackgroundIcon`: a glove, a plaster, a football, a barn, a belt, a gi, a clock, Thai pads,
  a brick wall, a running track, a gate, a wrestling mat), the picked one edged in its colour, and what it means under
  them. With *Play his childhood* ticked the tiles are dimmed, as the list was.
- **His childhood** (`ui/childhood_screen.gd`): him at that age beside each scene's card, shorter and slighter at 8
  and 12 (`AGE_FRAMES`), nearly grown at 15, no beard before 15; on *Who he became*, him as his career will start.
- **Where you coach** (`ui/gym_screen.gd`): each gym a card topped in its kind's colour with its picture (the gym kinds
  borrow the nearest background's, the MMA gym a cage) and its name and kind; the owner's head and chest (a man from
  his hometown's country, his look rolled from his name) beside his name and words; what it trains as chips, green for
  better and red for worse with the share (*Wrestling +25%*), and the culture's (*Fewer skipped sessions*, *More
  injuries*, *Sparring +20%*); the kind and culture in a line each; the fee big; *Coach here*.
- **The walk-in**: him standing in a lit doorway beside the words, as his career will make him (his background's
  height and his childhood's changes, `GymScreen.his_profile`), the owner's face by his line under them.
- **Load career** (`ui/load_screen.gd`): each slot with his head and chest at the top, his record with his division,
  and the belt he holds in gold. The save's summary carries what it needs (`division`, `belt`, `portrait`; `docs/09`
  career@1); a career saved before D434 shows without them until it's saved again.

**To change it:** the title fight's speed, the wait before the next pair, the camera's slide and who's left out
(`RATE`, `NEXT_AFTER`, `CAMERA_SHIFT`, `LEFT_OUT_PREFIX`) in `game/title_backdrop.gd`; the strip's width, darkness, solid
share and the menu's edge (`STRIP_WIDTH`, `STRIP_ALPHA`, `STRIP_SOLID`, `MENU_LEFT`) in `ui/title_screen.gd`; the stage's
width and colour and the tiles' grid (`STAGE_WIDTH`, `STAGE`, `TILE_COLUMNS`, `TILE_SIZE`) in `ui/new_career_screen.gd`;
the pictures and their colours (`_draw`, `COLOURS`, `ALIASES`) in `ui/background_icon.gd`; the boy's frame at each age
and the portrait's size (`AGE_FRAMES`, `PORTRAIT_SIZE`) in `ui/childhood_screen.gd`; the cards' width, the owner's face,
his frame and the doorway (`CARD_WIDTH`, `OWNER_FACE`, `OWNER_FRAME`, `DOORWAY`) in `ui/gym_screen.gd`; the slot's face
(`FACE`) in `ui/load_screen.gd`. Tests: `tests/ui/test_front_door.gd` and `tests/ui/test_career_screens.gd`.
Presentation only: fights and careers are unchanged (no golden re-pin).

### 6.15 One look off the fight (D435)

The fifth piece of D430: the screens off the fight each had their own flat dark page and Godot's grey buttons, and they
snapped from one to the next. Kyle's picks on the four D435 cards (all four recommendations):

- **Every screen off the fight** shares the look: the setup, the title's menu, new career, his childhood, the gyms,
  load, the hub, the world pages, the camp and its fight night card, and the result.
- **The empty cage, lights low, behind them** (`ArenaView.hall_drift`): leaving any screen clears the cage, and with no
  fight in it the camera drifts slowly round the empty cage, pulled back to take in the seats. The screens' backing is
  see-through (`OffCage.HALL`) so the hall shows dimmed behind them. A page laid over another screen (the world pages
  over the hub, the fight night card over the camp) stays solid (`OffCage.OVER`), so the screen under it doesn't read
  through. The title keeps its own fight (§6.14), and the result keeps the fight that just ended behind it.
- **Dark buttons, a red edge on hover** (`ui/off_cage.gd`, `OffCage.style_button` and `OffCage.theme()`): every button
  dark with rounded corners, edged in red-corner red when the mouse is on it or the keyboard is on it, short labels in
  the display font; the main action on each screen stays solid red (`CampPlanner.style_fight_button`). Tabs and other
  toggles (the hub's tabs, the world pages' tabs and filters, the promotions strip) are lit a shade and underlined in red
  when they're the one picked. The pickers keep their low height so the pages still fit, and tick boxes keep their own
  look. Each screen carries the theme (`game/main.gd`), so a button no screen styled itself gets the look too.
- **A quick fade** (`_fade_up` in `game/main.gd`): when one screen changes to the next, the old one fades out into the
  dark over a fifth of a second (a picture of its last frame, so the game has already moved on underneath) and the new
  one comes up out of the dark over the same again. Headless (the tests) only the second half runs.
- **Small fixes**: the camp's stat names were cut short (*Submission defens*); the name column now widens to its
  longest name (`StatBars.name_width`).

**To change it:** the backing's darkness and the solid page's colour (`HALL`, `OVER`), the buttons' colours, the red
edge, the toggle's light and underline, which labels get the display font and its size (`BUTTON`, `BUTTON_HOVER`,
`BUTTON_PRESSED`, `EDGE`, `BUTTON_ON`, `ON_LINE`, `DISPLAY_UP_TO`, `DISPLAY_SIZE`) and the fade's length
(`FADE_SECONDS`) in `ui/off_cage.gd`; how fast the hall turns and how far back the camera stands (`HALL_TURN_SPEED`,
`HALL_ZOOM`) in `game/arena_view.gd`; the camp's own backing (`BACKGROUND`) in `ui/camp_planner.gd`. Tests:
`tests/ui/test_one_look.gd`. Presentation only: fights and careers are unchanged (no golden re-pin).

### 6.16 The result as a moment (D436)

The sixth and last piece of D430: a fight ended and the full-screen sheet of numbers came straight up. Now (Kyle's picks
on the four D436 cards, all four recommendations):

- **The verdict first, over the cage** (`ui/verdict_banner.gd`, `VerdictBanner`): when the finish has been held and,
  with *Walk-out and corners* on, his hand raised, the HUD goes and a dark band across the lower third of the cage reads
  the verdict out like the announcer: how and when, then the winner's name big in his corner's colour. A key or a click
  shows it all at once and another goes on to the sheet; left alone it goes on a few seconds after the last line.
  The sheet (§6.9) then comes up as before. A simmed fight (D305) still goes straight to the sheet, and so do headless
  runs unless a test asks (`verdict_in_headless` in `game/main.gd`).
- **The finish again, slowly** (`game/finish_replay.gd`, `FinishReplay`): after a KO, TKO or tap the last few seconds
  play again in slow motion behind the verdict, closer and from another angle (`ArenaView.view_turn`, `view_zoom`),
  with REPLAY in the corner and its own sounds, held a moment at the end and played again, on and on behind the sheet
  until you leave it. It's the real fight played again, not a recording: a fresh fight from the same seed, the same two
  men made fresh and every command the fight took (your calls, his rules, the other corner's calls, the towel), as a
  saved fight replays (docs/04 §2.2). It never starts before the last bell, so a finish early in a round only replays
  that round. If it ever ended differently it wouldn't be shown again (`exact`).
- **A decision read out one judge at a time**: "After 3 rounds, to the judges' scorecards", then each judge's score in
  turn in the colour of the man he gave it to, then the winner with how it was decided. Whole-fight judging (PRIDE
  rules, D141) reads as a finish does: how, then the winner.
- **What it means, in a career** (`FightResultCard.meaning_rows`, `Career.standing()`): a fourth card on the result
  beside your corner and the judges: his record before and after, his place in his promotion's rankings (the new ones
  come out after the card, so it says so), a belt won, lost or kept, a call-up or being let go down the promotions, the
  purse and his savings, and the suspension and any Chin lost. These moved off the notes under the sheet; the notes keep
  the rest (simmed, a tournament's next round, a medal, a habit spotted).

**To change it:** the band's colour and place, the gap between the judges, how long it stays up and the sizes
(`BAND`, `BAND_TOP`, `BAND_BOTTOM`, `READ_GAP`, `STAY_FOR`, `NAME_SIZE`, `LINE_SIZE`, `REPLAY_SIZE`) in
`ui/verdict_banner.gd`; how far back the replay starts, its speed, the hold before it plays again and the camera's turn
and closeness (`SECONDS`, `RATE`, `HOLD_AFTER`, `VIEW_TURN`, `VIEW_ZOOM`) in `game/finish_replay.gd`; the panel's rows
in `FightResultCard.meaning_rows` (`ui/result_card.gd`). Tests: `tests/ui/test_result_moment.gd`. Presentation only:
fights and careers are unchanged (no golden re-pin).
