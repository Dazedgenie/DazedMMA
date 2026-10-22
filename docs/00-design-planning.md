# DazedMMA — Design Planning (Draft v0)

> Status: **pre-production / planning**. No code until the open questions below are answered
> and the Vertical Slice scope is locked. Everything marked **[ASSUMPTION]** is a placeholder
> guess for discussion and can be overturned.

Inspiration: *Boxing School* (Steam app 939990). It's a management/coaching sim where you shape a
boxer between fights and influence bouts from the corner. DazedMMA takes that loop to MMA, with
**one created fighter followed through a full career**.

---

## 0. Decisions log

| # | Decision | Answer | Implications |
|---|---|---|---|
| D1 | Fight pacing (Q3.1) | **Real-time with slow-mo / active pause** | The simulation must support time scaling, and pausing has to be fair (the opponent AI doesn't act while paused). Calls can be queued while paused. |
| D2 | Art / camera (Q2.1–2.2) | **Isometric / top-down 2D** | Cage position and octagon geometry are visible, which makes cage-cutting and pinning real mechanics. Tells need to read clearly from above (silhouette + UI cue). |
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
| D18 | Career structure (Q6.4) | **Tiered ladder with competing major leagues** | Amateur → regional → national → 2–3 fictional majors. Contracts, free agency, and promotions competing for fighters. |
| D19 | Injuries (Q6.7) | **Real but recoverable** | Medical suspensions, camp injuries and occasional lasting dents. Chin and durability wear accumulates slowly over a career. |
| D20 | Fight-night extras | **Ref/judge personalities, fouls + deductions, cutman minigame, commentary feed: all in** | Phased in: commentary + cutman by Alpha, ref/judge personalities + fouls by Beta. |
| D21 | Life sim depth (Q6.5–6.6) | **Medium** | Weekly budget, purses/sponsors, choice-based press conferences and callouts, 4–6 persistent relationships with light story events. |
| D22 | Rivals (Q6.11) | **Generated only (systemic)** | No handcrafted story rival. Rivalries form from world events (losses, callouts, shared opponents, close decisions). Needs a solid grudge/relationship model in the world sim. |
| D23 | Weight cut | **Fight-week mini-system** | Planning minigame: cut aggressiveness ↔ size advantage vs cardio and chin penalties. Missing weight = fine + reputation hit. |
| D24 | Stat display (Q7.3) | **Letter grades + descriptive tags** | Internally 0–100, shown as grades (F → A+) plus tags like "Iron chin" or "Elite wrestler". Debug overlay shows the raw numbers. |

---

## 1. Vision statement (draft)

> *You built this fighter from a kid in a rough neighbourhood (or a wrestling household, or a
> karate dojo...). You chose how they trained, who they trusted, and which fights they took.
> On fight night you're in their corner, and the call you make at the right moment wins the fight.*

### Design pillars
1. **The corner matters.** Coaching calls change the fight in a way you can see. Good timing is
   rewarded, bad timing is punished, and you can read why from what happens on screen.
2. **A career with a story.** Background, rivalries, injuries, camps, contracts and aging all add
   up to one fighter's story that no other player gets.
3. **Training is play, not a menu.** Fighters improve through short, skill-based minigames, plus
   longer-term choices like camps, coaches and lifestyle.
4. **MMA is three games in one.** Striking, wrestling/clinch and grappling each have their own
   decisions, and the fight moves between them.
5. **Readable simulation.** Every outcome comes from systems the player can learn: stats,
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

### 3.2 How coaching plugs in [ASSUMPTION, needs your input]
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

## 5. Development phases (draft roadmap)

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
