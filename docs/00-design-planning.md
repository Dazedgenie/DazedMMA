# Chin Check — Design Planning (v1)

> Status: **v1: design signed off for Phase 0 wrap-up.** Working title **Chin Check** (D81); the repo stays `DazedMMA`.
> Decisions D1–D84 are binding unless revisited on purpose. Anything still marked **[ASSUMPTION]**
> in older sections has been superseded by the decisions log and the per-system docs.

Inspiration: *Boxing School* (Steam app 939990). It's a management/coaching sim where you shape a
boxer between fights and influence bouts from the corner. Chin Check takes that loop to MMA, with
**one created fighter followed through a full career**.

---

## 0. Decisions log

| # | Decision | Answer | Implications |
|---|---|---|---|
| D1 | Fight pacing (Q3.1) | **Real-time with slow-mo / active pause** | The simulation must support time scaling, and pausing has to be fair (the opponent AI doesn't act while paused). Calls can be queued while paused. |
| D2 | Art / camera (Q2.1–2.2) | **Isometric view** *(now low-poly 3D with an isometric camera: see D80)* | Cage position and octagon geometry are visible, which makes cage-cutting and pinning real mechanics. Tells need to read clearly from above (silhouette + UI cue). |
| D3 | Project goal (Q1.2–1.3) | **All three: hobby + learning + eventual Steam release** | Build in milestones that are each worth finishing, and keep code quality good enough for public release. Docs should explain the *why* (learning value). |
| D4 | Engine (Q8.1) | **Godot 4** | GDScript to start (C# optional later). The simulation core is plain scripts with no node dependencies, so it can run headless for balance tests. |
| D5 | Call compliance (Q3.4–3.5) | **Visible reaction delay + rare ignores** | Delay = f(Fight IQ, Coach Trust, fatigue, damage, crowd). Ignore chance = f(ego, trust, panic). Show the delay so the player can learn to anticipate it. |
| D6 | Call types (Q3.2–3.3) | **Broad intents at first → specific moves unlock** | Call tree: intent ("Takedown!") → technique ("Catch kick → single leg"). Learning techniques in training adds calls, so training feeds directly into fight-night options. |
| D7 | Tone (Q1.5) | **Grounded but warm** | Realistic MMA. Injuries, losses and money trouble exist, but with heart and humour. No grimdark spirals. |
| D8 | Background (Q4.2) | **Series of childhood vignettes** | 3–4 lifepath scenes (~age 8 / 13 / 17 / 19) that build stats, traits and relationships, with persistent characters introduced there. |
| D9 | Round length (Q3.16) | **~2.5 real minutes per 5-min round** (time scale ≈ 2×) | A 3-round fight ≈ 9–10 min with corners; a 5-round title fight ≈ 15 min. Pacing has to stay interesting, so we need lulls, feints and resets. Slow-mo is still available, and fight skip is required (Q3.17). |
| D10 | Submissions (Q3.13) | **Coach-driven struggle** | When a sub is locked in, play switches to a short sequence of struggle calls (hand-fight, posture, turn in, stack, tap?). Stats set the base odds and good calls swing them. The same system works on offence (finishing calls). |
| D11 | Tells (Q3.8) | **Real behaviour patterns + scouting reveals** | Every fighter has authored or generated habits (e.g. "drops right hand after double jab", "overcommits body kick when behind"). Unscouted habits are still in the sim and can be spotted by eye. Film study adds on-screen cues. |
| D12 | Randomness (Q7.1) | **~80% for the clearly better fighter** | Upsets and lucky punches exist. Good coaching should be worth about +10–20% win probability against an even opponent. The balance harness tests against this target. |
| D13 | Progression (Q5.3) | **XP with diminishing returns + technique unlocks** | Training fatigue and soft caps per camp. Techniques come from coaches/gyms plus skill thresholds, and each one adds a fight call (links to D6). |
| D14 | Auto-train (Q5.6) | **Skippable with reduced gains (~60–70% of an average result)** | Every minigame needs a "simulated score" path. |
| D15 | Player role (Q6.9) | **Named head coach** | A coach character with their own progression (coaching level → clearer, faster calls), a relationship/trust stat with the fighter, and a hook for a future next-generation coaching mode. |
| D16 | Career length (Q6.1) | **~20–30 hours, ~25–35 pro fights** | About 1 fight every ~45 min of play including camp. Fits about 3 fights/year over a ~10-year pro career. |
| D17 | Divisions (Q4.4) | **Men's divisions only at launch** | Women's divisions are a post-launch roadmap item. Keep the data model gender-agnostic so adding them later doesn't need a rewrite. |
| D18 | Career structure (Q6.4) | **Tiered ladder with competing major leagues** (refined by D41: 2 pro orgs) | Amateur → regional → national → 2–3 fictional majors. Contracts, free agency, and promotions competing for fighters. |
| D19 | Injuries (Q6.7) | **Real but recoverable** | Medical suspensions, camp injuries and occasional lasting dents. Chin and durability wear accumulates slowly over a career. |
| D20 | Fight-night extras | **Ref/judge personalities, fouls + deductions, cutman minigame, commentary feed: all in** | Phased in: commentary + cutman by Alpha, ref/judge personalities + fouls by Beta. |
| D21 | Life sim depth (Q6.5–6.6) | **Medium** | Weekly budget, purses/sponsors, choice-based press conferences and callouts, 4–6 persistent relationships with light story events. |
| D22 | Rivals (Q6.11) | **Generated only (systemic)** | No handcrafted story rival. Rivalries form from world events (losses, callouts, shared opponents, close decisions). Needs a solid grudge/relationship model in the world sim. |
| D23 | Weight cut | **Fight-week mini-system** | Planning minigame: cut aggressiveness ↔ size advantage vs cardio and chin penalties. Missing weight = fine + reputation hit. |
| D24 | Stat display (Q7.3) | **Letter grades + descriptive tags** | Internally 0–100, shown as grades (F → A+) plus tags like "Iron chin" or "Elite wrestler". Debug overlay shows the raw numbers. |
| D25 | Session design (Q1.9) | **Replayability + "30 minutes or 3 hours"** | Natural save points every week, a fast "advance week", fight skip and auto-train. Each career must feel different: seeded variety, emergent world, different backgrounds. |
| D26 | Reference game #2 | **Corner King: Boxing Tycoon** (Steam 4259990) | Borrow: emergent stories (grudges, media, poaching), weekly drag-and-drop training plans, fatigue ("enter the ring broken"), trainers with personalities. Avoid: it's gym-tycoon (many fighters); we stay single-fighter. |
| D27 | Starting calls (Q3.2) | Pressure, Circle out, Work the range, Takedown, Clinch, Defend the shot, Get up, Survive, **plus Stay safe** | Each one is an "intent" that branches into unlockable techniques (D6). |
| D28 | Call spam (Q3.7) | **Voice meter** | Each call costs voice and voice regenerates. Low voice → longer delay, lower compliance, and trust drains if you keep spamming. |
| D29 | Bad timing (Q3.6) | **Punished hard** | Shooting into a knee → flash KO risk. Shooting into a front headlock → guillotine/D'arce risk. Mistimed calls must *visibly* explain the punishment. |
| D30 | Between rounds (Q3.10) | **Cutman minigame + coaching options that shape the next round** | The 60 s corner is a time budget: cutman work, ice/water, 1–2 tactical instructions (they buff or bias the next round), motivation. |
| D31 | Towel / safety (Q3.11) | **Throw in the towel + "Stay safe" call** | Towel = TKO loss but protects long-term health (chin wear, injuries) and the relationship. |
| D32 | Habits from calls (Q3.9) | **Only if they fit the fighter's personality** | Adaptive/coachable fighters absorb your call patterns into their AI. Stubborn fighters resist. |
| D33 | Cage (Q3.12) | **Fully strategic** | Pinning, cage-walking, wall-and-stall, cutting off the cage, and cage position affecting takedown/escape odds. |
| D34 | Backgrounds (Q4.1) | All 10 listed **plus Track star (cardio)** and **Bullied underdog** | 12 background flavours delivered through vignettes (D8). |
| D35 | Weight class (Q4.5) | **Emerges over time** | Frame/height come from vignettes + growth. Walk-around weight changes with training and lifestyle. The division is picked at amateur debut and can change later (D44). |
| D36 | Personality (Q4.8) | **Hybrid** (recommended, user open) | Vignette choices set the initial traits, with a small random roll for variety. Traits then drift with career events (big wins → ego up, etc.). |
| D37 | Career start (Q4.7) | **Walking into a gym** | The first playable moment after the vignettes is the gym walk-in. Amateur fights follow. |
| D38 | Minigames (Q5.2) | **All 10 approved**, about **1 minute each** | Mitt rhythm, heavy-bag power, Thai pads, wrestling chain, sprawl reflex, rolling puzzle, roadwork pacing, film study, hard sparring, meditation, plus the weight-cut system (D23). |
| D39 | Training partners (Q5.7) | **Persistent; can turn pro** | They feed the generated rivalry system (D22): a former partner can become a rival. |
| D40 | Gyms & coaches (Q5.5) | **Major strategic layer** | Switching gyms and hiring specialists, each with personality, specialties, cost and a technique catalogue. |
| D41 | World size (Q6.3) | **At least 100 fighters across amateur/regional/pro** (*per division? see open Q*) | A few regional promotions + **2 pro organisations** (refines D18). |
| D42 | Fight business (Q6.12) | **All in:** short-notice offers, catchweights, interim belts, eliminators | — |
| D43 | Bad outcomes (Q6.8) | **Warm but punishing** | Cuts from the roster, going broke, career-ending injuries are possible. Bad things can always happen. |
| D44 | Weight moves (Q6.x) | **Can move up/down mid-career** | — |
| D45 | Ironman (Q6.10) | **Yes, optional ironman mode** | Single autosave and no reloading. |
| D46 | Team & capacity (Q1.3–1.4) | **About 20 hrs/week**; background in GTA V modding + web design/coding | GDScript (Python-like) is a good fit. Plan milestones in 4–8 week chunks. |
| D47 | Production approach (Q8.6) | **AI-assisted for most code and art** | Requires a strong style guide, a repeatable art pipeline, tests and docs so AI output stays consistent. See `04-tech-and-production.md`. |
| D48 | First playable (vertical slice) | **Create fighter → 1 camp → 3 fights** | Comes after the Phase 1 fight prototype. |
| D49 | Call kinds (F1) | **Now calls + read calls** both in | Now = pure timing; read = primed reaction with an attention cost. |
| D50 | Active pause (F2) | **Easy difficulty only** | Normal/Hard: slow-mo only. |
| D51 | Tell display (F3) | **On-screen cue once a habit is scouted** | E.g. a small icon/glow on the telegraph. Unscouted habits are behaviour only. Head coach *Reading* skill improves cue timing. |
| D52 | Perfect-call flourish (F4) | **Yes** | Brief slow-mo + sound + feed line when a call lands inside a counter window. |
| D53 | Auto slow-mo (F5) | **Yes** | Triggers: fighter rocked, sub locked in, knockdown, scramble. Can be turned off in settings. |
| D54 | Input (F6) | **Keyboard + mouse only at launch** | Hotkeys 1–9 + clickable call wheel/bar. Controller later. |
| D55 | World size (W1) | **~100 fighters per division** | With D56: about 600 simulated fighters. |
| D56 | Divisions (W2) | **6 men's divisions** | Bantam, Feather, Light, Welter, Middle, Light Heavy. Heavyweight post-launch. |
| D57 | Places & promotions (W3) | **Real-world places, fictional promotions, generated at game start** | Each new career generates the regional promotions + 2 pro orgs (names, HQ city, style, pay scale). Adds replayability (D25). |
| D58 | Manager (W6) | **Head coach does it by default; optional agent** | Hiring an agent auto-handles negotiation for a % cut, for players who don't want that layer. |
| D59 | Code ownership (P1) | **You direct; AI writes the code** | Docs, tests and playtests are how you keep control (see `04`). No learning tasks in milestones. |
| D60 | Art approach (P2) | ~~3D → 2D sprite sheets~~ **superseded by D80** | Blender is available. Free/cheap tools to add: see `04` §3. |
| D61 | Prototype art (S2) | **None: mechanics first** | Art direction starts only after the prototype passes. |
| D62 | Playtesters (S3) | **Friends + a small Discord** | Needs a shareable build (Windows export) + a feedback form. |
| D63 | Head coach (T2) | **Customisable** | Name, look, background, plus a starting coaching specialty. |
| D64 | Training trips (T4) | **Yes: "Bangkok ready"** | Travel camps (Thailand, Dagestan, Brazil, Netherlands...) with unique coaches, techniques and minigame variants. |
| D65 | Family & life → training (T3) | **Yes** | Life events affect fatigue, motivation and focus (new baby, sick parent, breakup, wedding). |
| D66 | Tell visibility tie-in | Head coach **Reading** stat + film study | Better reading = cue appears earlier in the telegraph. |
| D67 | Stacked read calls (F7) | **Yes: up to 2 at once** | Two active reads = a bigger attention cost (slower defense against everything else). |
| D68 | Opponent corner (F8) | **The AI corner makes calls and you can hear them** | Shown as a speech bubble/feed line. Lets you counter ("they're telling him to shoot → Watch the shot!"). The AI corner has its own voice meter and coaching level. |
| D69 | Difficulty (F9) | **Both: opponent AI and player assistance** | Uses the 3-dimension split (combat challenge / realism / assistance), see `05` A4. |
| D70 | Played sessions (T1) | **The player picks which sessions to play** | The game can highlight "key sessions" as a hint. |
| D71 | Coach specialty (T5) | **Yes** | Striking / Wrestling / BJJ / Motivator / Tactician. Each gives a different early bonus and coach skill-tree start. |
| D72 | Titles (W4) | **Everything: defences, vacating, double champ, superfights, GOAT legacy** | A **GOAT score** (titles, defences, opponent quality, finishes, longevity) compared against the generated all-time list. |
| D73 | Fight card (W5) | **Watch the whole card eventually** | Results list first (Alpha). Watching other fights (same fight renderer) by Beta. |
| D74 | Foreign fights (W7) | **Yes** | Fights abroad during training trips (e.g. a Muay Thai or MMA bout in Bangkok). |
| D75 | GitHub tracking (P3) | **Yes: issues + milestones after sign-off** | |
| D76 | Budget (P5) | **No budget for now: free tools only** | Gameplay first. Art assets come near the end. |
| D77 | Title | **Open**: shortlist in `05` §7 | "DazedMMA" stays as the repo/working name. |
| D78 | Reference game #3 | **Glass Jaw** | Take: the excitement of watching the card, simple between-round adjustments. Leave: shared online world. |
| D79 | Foundation doc merge | **Adopted A1–A16 from the user's Foundation v1.0** | See `05-review-and-reconciliation.md`. |
| D80 | Presentation (C1) | **Real-time low-poly 3D, isometric (orthographic) camera** | Camera zooms in for clinch/ground. Blender for models/rig, Mixamo-style animations. No sprite baking. Replaces D60. |
| D81 | Title | **Chin Check** (working title) | Check Steam/trademark before the store page. |
| D82 | Coaching layers (C2) | **4 layers: Gameplan → Drilled rules → Live calls → Corner** | Drilled rules: 2–3 trigger→action slots, reliability from camp drilling + Fight IQ. Advanced conditions unlock later. See `01` §6.0. |
| D83 | Career start (C3) | **Vignettes at ~8 / ~12 / ~15 → gym walk-in at ~16 → teen amateur → pro at 18+** | Amateur ruleset in `08-amateur-rules.md`. |
| D84 | Launch model | **Open**: full release vs Early Access | Decide at the vertical-slice checkpoint, when scope/cost is known. |

### Per-system design docs
- [`01-fight-engine.md`](01-fight-engine.md): simulation, positions, coaching calls, tells, corner, scoring
- [`02-fighter-and-training.md`](02-fighter-and-training.md): creation, vignettes, attributes, minigames, camps, gyms
- [`03-career-and-world.md`](03-career-and-world.md): promotions, world sim, contracts, life, rivals, injuries
- [`04-tech-and-production.md`](04-tech-and-production.md): Godot architecture, AI-assisted workflow, art pipeline, milestones
- [`05-review-and-reconciliation.md`](05-review-and-reconciliation.md): review pass + merge with the Foundation v1.0 doc, conflicts C1–C3, title ideas
- [`06-fight-hud.md`](06-fight-hud.md): fight screen layout, HUD elements, input map
- [`07-onboarding.md`](07-onboarding.md): tutorial plan (the first amateur fights teach the corner)
- [`08-amateur-rules.md`](08-amateur-rules.md): amateur vs pro rulesets, the teen amateur stage
- [`09-data-formats.md`](09-data-formats.md): JSON content formats + what the validator checks
- [`10-prototype-spec.md`](10-prototype-spec.md): Phase 1 fight prototype, the "kick → takedown" test
- [`11-attributes-and-traits.md`](11-attributes-and-traits.md): **proposal**: attribute list, how stats enter a fight, trait layers (incl. style from training habits)

---

## 1. Vision statement (draft)

> *You built this fighter from a kid in a rough neighbourhood (or a wrestling household, or a
> karate dojo...). You chose how they trained, who they trusted, and which fights they took.
> On fight night you're in their corner, and the call you make at the right moment wins the fight.*

### Design pillars
1. **The corner matters.** Coaching calls change the fight in a way you can see. Good timing is
   rewarded, bad timing is punished, and you can read why from what happens on screen.
2. **Prove the coaching loop first.** Don't build the whole sport before the corner feels good (scope guardrail, Foundation doc).
3. **A career with a story.** Background, rivalries, injuries, camps, contracts and aging all add
   up to one fighter's story that no other player gets.
4. **Training is play, not a menu.** Fighters improve through short, skill-based minigames, plus
   longer-term choices like camps, coaches and lifestyle.
5. **MMA is three games in one.** Striking, wrestling/clinch and grappling each have their own
   decisions, and the fight moves between them.
6. **Readable simulation.** Every outcome comes from systems the player can learn: stats,
   tendencies, fatigue, damage and timing. Hidden dice-roll results are kept to a minimum.

---

## 2. Core loop (draft)

```
 ┌──────────────────────────────────────────────────────────────────┐
 │  CAREER HUB (week-by-week calendar)                              │
 │   ├─ Accept / negotiate fight offer                              │
 │   ├─ Fight camp (N weeks)                                         │
 │   │    ├─ Training minigames  → attribute XP / technique unlocks │
 │   │    ├─ Sparring (risk: injury, reward: fight IQ / tells)      │
 │   │    ├─ Scouting the opponent (reveal tendencies / tells)      │
 │   │    ├─ Weight cut management                                   │
 │   │    └─ Life events (money, relationships, media, temptation)  │
 │   ├─ FIGHT NIGHT                                                  │
 │   │    ├─ Gameplan set-up (pre-fight strategy sliders)           │
 │   │    ├─ Live rounds with real-time corner calls                │
 │   │    └─ Between-round corner (cutman, adjustments, motivation) │
 │   └─ Aftermath: medical suspension, rankings, money, hype, offers│
 └──────────────────────────────────────────────────────────────────┘
```

---

## 3. Fight engine: the core design problem

This is the part that makes or breaks the game, so it gets planned first and prototyped first.

### 3.1 Proposed model: tick-based simulation with commitment windows [ASSUMPTION]
- The fight runs on a fixed simulation tick (e.g. 10 ticks/sec), separate from rendering.
- Every action (jab, leg kick, shot, sprawl, guard pass...) has phases:
  **telegraph → wind-up → active → recovery**.
- During **wind-up and recovery** a fighter is *committed*. Their balance, guard and options are
  reduced. This creates **counter windows**.
- Example: an opponent throws a body kick and spends ~0.6 s on one leg. A takedown started inside
  that window gets a big success bonus (catch-kick single leg). The same shot against a fighter in
  a balanced stance is likely to be sprawled on.

### 3.2 How coaching plugs in *(superseded: see `01-fight-engine.md` §6 and `05` C2)*
Three layers of influence:

| Layer | When | Example | Effect |
|---|---|---|---|
| **Gameplan** | Pre-fight | "Pressure, attack legs, wrestle late" | Biases the AI's action weights all fight |
| **Live calls** | During round | "SHOOT!", "Check the kick!", "Circle left!", "Clinch!" | Short-term override / priority boost, subject to delay and how receptive the fighter is |
| **Corner** | Between rounds | Fix cuts, ice, "he drops his left after the jab" | Resets/adjusts state, motivation, tactical reveal |

**Live calls aren't instant.** Several things decide whether and when the fighter acts on a call:
- *Reaction delay*, which depends on Fight IQ, Coach Trust, crowd noise and how hurt or tired the
  fighter is.
- *Compliance*: a fighter with a big ego or low trust might ignore you.
- *Feasibility*: you can't "shoot" from the bottom of mount.

The player's skill is **anticipation**: read the opponent's tells and call the move *slightly
before* the window opens, allowing for your fighter's delay.

### 3.3 Fight positions (MMA state machine) [ASSUMPTION]
- **Standing**: distance (long / mid / pocket), stance (orthodox/southpaw), cage position (centre / near cage / pinned).
- **Clinch**: open-space clinch, cage clinch (control / being controlled), Thai plum, body lock.
- **Ground**: full guard, half guard, butterfly, side control, mount, back mount, north-south, turtle, scramble, plus top/bottom versions of each.
- **Transitions**: takedowns, sprawls, sweeps, guard passes, stand-ups, reversals.
- **Finishes**: KO, TKO (ref stoppage), submission (with an escape minigame or contest), doctor stoppage, decision (10-point must scoring).

### 3.4 Fighter state during a fight
- Stamina (short-term gas tank) and cardio (how fast it comes back).
- Damage by location: head, body and legs, each with its own effects (head → chin and composure, body → stamina, legs → movement and stance).
- Cuts and swelling (vision penalty, doctor-check risk).
- Composure/morale (panic, momentum, "the bear is awake").
- Knockdown / rocked state.

---

## 4. Feature list (master backlog, draft)

**Legend:** VS = Vertical Slice, A = Alpha, B = Beta, 1.0 = launch, Post = after launch

### 4.1 Character creation
- [VS] Name, nickname, nationality, weight class, stance
- [VS] Childhood **background** with starting stat modifiers and story hooks (see Q-section)
- [A] Appearance editor (scope depends on the art style)
- [A] Personality traits (ego, discipline, aggression, loyalty, party animal...)
- [B] Family / relationships that persist through the career
- [Post] Starting from different points (late bloomer, ex-boxer converting, Olympic wrestler)

### 4.2 Attributes and skills
- [VS] Core physicals: Strength, Speed, Cardio, Chin, Durability, Recovery
- [VS] Striking: Boxing, Kicking, Clinch striking, Defense, Footwork
- [VS] Grappling: Takedowns, Takedown defense, Top control, Guard/bottom game, Submissions, Submission defense, Scrambles
- [VS] Mental: Fight IQ, Composure, Heart, Coachability
- [A] **Technique unlocks**: specific moves (spinning back kick, D'arce, calf kick, Imanari roll...)
- [A] Fighter **tendencies** that come from how you play (if you call a lot of jab-cross, the fighter starts doing it on their own)
- [B] Aging curves, peak window and decline; injuries that never fully heal

### 4.3 Training and minigames
- [VS] 2–3 minigames as a proof of concept (e.g. mitt work rhythm game, wrestling chain timing, cardio pacing)
- [A] Full set of minigames, one for each skill family (see the Q list for ideas)
- [A] Sparring sessions: auto-simulated or short playable fights; risk/reward
- [A] Gyms and coaches: move gyms, hire specialists, gym culture/traits
- [B] Overtraining, burnout, the injury system
- [B] "Auto-train" for players who want to skip minigames (with a smaller reward)

### 4.4 Fight night
- [VS] Fight engine with standing, clinch and ground phases (simplified)
- [VS] Live coach calls (6–10 core calls)
- [VS] Between-round corner screen
- [VS] Judging and stoppages
- [A] Opponent tells and scouting integration
- [A] Full call set, plus calls that unlock as the fighter learns techniques
- [A] Commentary text feed / play-by-play
- [B] Crowd and venue atmosphere affecting call delay
- [B] Replays of key moments; fight stats (sig strikes, TD %, control time)

### 4.5 Career and world
- [VS] Linear series of 3–5 fights against generated opponents
- [A] Simulated world: other fighters fight each other, rankings move, champions change
- [A] Promotions tiered from amateur → regional → national → major leagues
- [A] Contracts: fight purses, win bonuses, exclusivity, multi-fight deals
- [A] Weight classes and moving up or down
- [B] Rivalries, trash talk, press conferences (choice-driven dialogue)
- [B] Hype / popularity / sponsorships
- [B] Finances: gym fees, coaches, medical bills, lifestyle
- [B] Retirement and legacy / Hall of Fame
- [Post] Legacy mode (become a coach for the next generation; ties directly back to the Boxing School influence)

### 4.6 Meta / tech
- [VS] Save/load
- [A] Settings, accessibility (colour-blind, slower fight speed, pause-to-call)
- [B] Localisation pipeline
- [B] Steam achievements, cloud saves (if targeting Steam)
- [Post] Mod support (custom fighters/promotions)

---

## 5. Development phases (summary; the source of truth with estimates is `04-tech-and-production.md` §6)

| Phase | Goal | Exit criteria |
|---|---|---|
| **0. Pre-production** (now) | Answer the questions, lock scope, pick engine/art direction | Signed-off GDD, Vertical Slice scope, tech choice |
| **1. Fight engine prototype** | Grey-box, text or simple shapes. Prove that "calling the takedown during the kick" feels good | Blind playtest: testers can explain *why* a call worked |
| **2. Vertical Slice** | Create a fighter → 1 camp with 2–3 minigames → 3 fights → career screen | Full loop playable start to finish; fun to replay |
| **3. Alpha** | All major systems in, content incomplete | Full career playable to a title shot |
| **4. Content / Beta** | Content, balance, polish, world sim | Every planned feature in; balance passes; save compatibility |
| **5. Launch (1.0)** | Release, marketing, store page | Shippable build |
| **6. Post-launch** | Legacy/coach mode, mods, more promotions | — |

Why the fight engine comes first: if coaching calls don't *feel* good, the training and career
layers won't save the game. A headless simulation (no graphics) also lets us run thousands of
fights to balance stats.

---

## 6. Technical considerations (to be decided)
- Engine options: **Godot 4** (free, 2D/3D, GDScript/C#), **Unity**, **Unreal**, a web stack (TypeScript + canvas/Phaser/PixiJS), or **Python** for the headless prototype.
- **Simulation and presentation stay separate**, so the engine can run headless for balance tests and AI tuning.
- Data-driven content (moves, backgrounds, opponents, promotions) in JSON/YAML/Resource files.
- Seeded RNG, so fights can be replayed and debugged.
- Automated balance harness: simulate N fights between stat profiles → win rates and finish types.

---

## 7. Open questions (the big list)

> **Mostly answered.** See the decisions log (§0). Kept for reference and numbering.

Answer these in any order, short answers are fine, and "not sure, you recommend" is a valid
answer. They're numbered so we can refer to them later (e.g. "Q3.4: yes").

### Q1. Vision and audience
1. What's the **platform target**: PC (Steam), mobile, web, consoles, or several?
2. Is this a **hobby / learning project**, a **portfolio piece**, or a **commercial release**?
3. Who's building it: just you, you + me, or a team? What are your programming and art skills?
4. What's the **time budget** (hours/week) and a rough target for a first playable?
5. Tone: **gritty realistic** (Fight Night / *Warrior*), **light and charming** (Boxing School / Punch Club), or **arcade/over-the-top**?
6. How deep should the sim go: "anyone can pick it up" or "MMA nerds argue about guard-pass percentages"?
7. Is there a story arc with a fixed ending (like *Punch Club*), or is it fully sandbox?
8. Which games besides Boxing School should we take from? (Punch Club, Football Manager, EA UFC career, Fight Night Champion, Wrestling Empire, MMA Manager 2...) What do you love or hate about each?
9. What did you specifically **love** about Boxing School? What frustrated you?
10. Licensed realism (real organisations/fighters) is almost certainly out, so are you happy with fictional promotions that are clear parodies (e.g. "UFF", "Bellatrix")?

### Q2. Art and presentation
1. **2D or 3D**? Pixel art, hand-drawn, low-poly 3D, or stylised 3D?
2. What camera angle for fights: side-on (classic 2D fighter), isometric, top-down, or a 3D broadcast camera?
3. Should the fight be **fully animated**, **semi-abstract** (stick figures / animated sprites + text), or **text-sim with visual indicators** (like Football Manager's 2D match engine)?
4. How important is it to *see* the counter window? (e.g. a visual "tell" flash, slow-mo on perfect calls, a UI timing ring)
5. UI style: gritty gym posters, clean sports broadcast, or comic book?
6. Do you want commentary (text, voice, or none)?
7. Music direction?

### Q3. Coaching and fight feel (most important section)
1. **Real-time, pausable, or turn-based?** Options:
   (a) fully real-time, call buttons/hotkeys;
   (b) real-time with optional slow-mo/active pause;
   (c) the fight runs in "beats" (every few seconds you pick a call);
   (d) hybrid: real-time, but big moments trigger a quick-time decision.
2. How many calls should be available at once? A small fixed set (6–8) or a big context-sensitive set that changes by position?
3. Should calls be **specific moves** ("double leg!"), **intents** ("get it to the ground!"), or **both** (intent by default, specific after you unlock them)?
4. Should the fighter **ignore calls** sometimes (ego, low trust, panicking)? Or is that too frustrating?
5. Is there a **reaction delay** between call and action? If yes, should the player be able to see the delay (e.g. a meter showing your fighter's "processing" state)?
6. What happens when a call is badly timed? (e.g. shooting into a knee: big penalty, flash KO risk?)
7. Should there be a limit on calls ("your voice": spamming calls lowers effectiveness or annoys the fighter)?
8. Opponent tells: should they be **learnable patterns** (the same opponent always drops his hand after a double jab), **revealed by scouting**, or both?
9. Should your fighter develop **habits from your calls** over a career (the AI learns your style)?
10. Between rounds: what tools do you want? (cutman minigame, motivational speech choice, tactical adjustment, ice/water/Vaseline, "you're down two rounds, you need a finish")
11. Can the player *throw in the towel* / tell the fighter to stay safe?
12. Should the **cage position** matter strategically (pinning, cage-walking, wall-and-stall)?
13. **Submissions**: a minigame (struggle/escape), purely stat-driven, or coach-driven ("get your hand free! Roll!")?
14. Should **referees** and **judges** have personalities (early stopper, takedown-loving judge)?
15. Are **fouls** in scope (eye pokes, groin shots, point deductions, illegal knees)?
16. How long is a fight in real time? Compressed (a 5-min round ≈ 60–90 s) or full length?
17. Can the player **sim/skip** a fight they're confident in?

### Q4. Fighter creation and background
1. Pick or veto background ideas:
   - **Street kid**: chin and heart bonus, low discipline, starts with brawling
   - **Wrestling family**: strong takedowns, cardio; poor striking
   - **Traditional martial arts** (karate/TKD): kicks and footwork; poor grappling
   - **Jiu-jitsu prodigy**: subs and guard; poor striking/TDs
   - **Farm/labour kid**: strength, durability; low technique
   - **Muay Thai camp abroad**: clinch, kicks, toughness
   - **Former college athlete / football**: athleticism, explosiveness; raw skills
   - **Sambo / judo household**: throws, leg locks
   - **Boxing gym kid**: hands, defense
   - **Privileged / late starter**: money and time, lower toughness
2. Is the childhood **one choice**, or a **series of choices/vignettes** (age 8, age 13, age 17) that build the fighter?
3. Should background affect **story/relationships** too (a rival from the old neighbourhood, a mentor, a family member who needs money)?
4. Can the player pick **gender**? Women's divisions?
5. Do we pick a **weight class** at creation, or does it emerge from body growth/training?
6. How customisable are looks? (Depends on the art style in Q2.)
7. Do we start at **amateur level**, from a gym walk-in, or in the regional pros?
8. Personality traits: chosen, rolled, or developed through choices?

### Q5. Training and minigames
1. How long should one minigame take? (30 s? 2 min?)
2. Rate these minigame ideas (love / ok / no):
   - **Mitt work**: rhythm game, the coach calls combos and you hit them on beat → Boxing
   - **Heavy bag power**: timing meter → Power
   - **Kick shield / Thai pads**: aim and timing → Kicking
   - **Wrestling chain drill**: a sequence of directional inputs under time pressure → Takedowns
   - **Sprawl drill**: react to shots (reflex) → Takedown defense
   - **Rolling / positional sparring**: a puzzle-like grappling board (pick transitions, Tetris/chess feel) → Grappling/Subs
   - **Roadwork / sprints**: pace management (too fast = gas out) → Cardio
   - **Strength circuit**: button mash vs form meter → Strength
   - **Film study**: spot the opponent's tell in a short clip → Fight IQ / reveal tells
   - **Hard sparring**: a short playable fight with injury risk → Composure, big XP
   - **Meditation / visualisation**: focus minigame → Composure
   - **Weight cut**: resource management across fight week
3. Should minigame performance give **XP**, or should it give **stat caps / technique unlocks**?
4. Should there be **diminishing returns** / a fatigue system so you can't grind one stat?
5. Should the **gym's equipment/coaches** limit what you can train?
6. Do you want an **auto-train/skip** option for minigames?
7. Should **sparring partners** be persistent characters (training buddies who also become pro fighters)?

### Q6. Career and world
1. How long is a full career in **real playtime**: 10 hours? 40? endless?
2. How many fights per in-game year (realistic is 2–4)?
3. How big is the simulated world: dozens or hundreds of generated fighters?
4. Multiple promotions with tiers, or one promotion from amateur to the big league?
5. **Contracts and money**: how deep? (Managers, negotiation minigame, sponsors, PPV points)
6. **Hype/media**: press conferences, social media, callouts, trash talk choices?
7. **Injuries**: realistic and career-altering (ACL, orbital fracture), or kept light?
8. Can the career **end badly** (CTE-style decline, bankruptcy, losing streak cut)? How dark do we go?
9. Is the **player a coach-character** with their own progression (coaching level, better call delay), or an invisible "you"?
10. **Permadeath/ironman** mode?
11. Should rival fighters have **persistent personalities and grudges**?
12. Real-world style events: short-notice replacement offers, catchweight bouts, title eliminators, interim belts?
13. After retirement: **coach mode / next generation** (Boxing School style)? Should this be the sequel hook or in 1.0?

### Q7. Systems and balance
1. How much **randomness** is OK? Should a superior fighter win 95% or 75% of the time?
2. Should **"lucky punch" KOs** exist?
3. Stats visible as numbers (0–100), letter grades, or hidden behind descriptions ("elite wrestler")?
4. Should difficulty settings exist? What do they change (opponent AI, call delay, tell visibility)?
5. Do we want a **fight-stat screen** after each fight (FightMetric-style)?

### Q8. Tech and process
1. Do you have an **engine preference** or prior experience (Godot, Unity, Unreal, web)?
2. What languages are you comfortable with?
3. OK with prototyping the fight engine **headless/text-first** before any art?
4. Source control/branching: work on feature branches + PRs into main?
5. Do you want design docs split by system (fight engine, training, career...) as we go?
6. Will you be making art yourself, buying asset packs, commissioning, or using AI-generated placeholder art?
7. Monetisation (if commercial): premium one-time purchase? DLC?

---

## 8. Next steps
1. You answer the questions (all at once or section by section).
2. I update this doc to **v1**: decisions recorded, assumptions resolved, and the backlog re-scoped.
3. Split into per-system design docs: `01-fight-engine.md`, `02-coaching.md`, `03-training.md`, `04-career.md`, `05-tech.md`.
4. Define the **Phase 1 fight prototype** in detail (moves, timings, calls, and the "kick → takedown" test case).
5. Only then: code.
