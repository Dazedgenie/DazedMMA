# Chin Check — Design Planning (v1)

> Status: **v1: design signed off for Phase 0 wrap-up.** Working title **Chin Check** (D81); the repo stays `DazedMMA`.
> Decisions D1–D125 are binding unless revisited on purpose. Anything still marked **[ASSUMPTION]**
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
| D36 | Personality (Q4.8) | **Hybrid** (refined by D86/D87) | Vignette choices set the initial traits, with a small random roll for variety. Traits then drift with career events (big wins → ego up, etc.). |
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
| D85 | Attribute count | **23 attributes**, each with one job in the fight engine | Explosiveness → Speed, Ground-and-pound → Top control + Power, Coachability → personality only. See `11` §2. |
| D86 | Trait model | **Three layers: personality / fighting style / gifts & flaws** | Style leanings (Pace, Range, Base, Risk) move with training, gameplans and calls, and earn named traits at ±60. Refines D36. See `11` §4. |
| D87 | Personality axes | **4 axes**: Ego, Discipline, Coachable, Loyal | Aggressive ↔ Patient becomes the Pace leaning; Composed ↔ Fragile dropped (the Composure attribute covers it). |
| D88 | Style visibility | **Fuzzy hint** once a leaning passes ±30 | e.g. "leaning aggressive". Raw numbers in the debug overlay only. |
| D89 | Losing style traits | **Yes** | Trait fades below ±40; style changes much more slowly after ~30. |
| D90 | Gifts & flaws | **0–2 gifts, 0–1 flaw rolled at creation; some hidden until discovered** | e.g. Bleeder shows after the first cut. See `11` §4.3. |
| D91 | Prototype fight speed | **Build the speed control first; playtest at 1× and 2×** | D9's 2× stays the target, but the catch-kick window is only ~0.45 s real time at 2×. The playtest decides. See `12` §4. |
| D92 | Call delay unit | **Fight time** | The 0.6 s base delay in `01` §6.2 is 6 ticks of fight time, so the simulation stays speed-independent. |
| D93 | Reaction time inside a primed read or drilled rule | **2 ticks at Speed 50, 1 at Speed 100, 3 at Speed 0, stretched by fatigue** | One derived number in `FighterState`, shared by read calls (#16), drilled rules (#17) and the AI (#14). |
| D94 | Fighter data format | **One `fighter` schema for authored profiles and generated fighters** | Authored opponents (tells) and the ~600 generated fighters use the same file, with an optional archetype template field. See `09`, `12` §3. |
| D95 | Harness before AI | **A minimal balance harness (#18) lands before the fighter AI (#14)** | The AI is tuned against numbers, not by eye. Coaching bots join when calls exist (#16). |
| D96 | Fatigue | **Earned, not automatic** | A fighter who pushed the pace, had it pushed on them, or took heavy body damage ends round 3 at ~30–50% of the tank. A slow tit-for-tat fight can leave both fresh. Movement costs stamina. Harness target, see `12` §4. |
| D97 | Even rounds | **10-10 rounds are very rare; draws under 2%** | Judges pick a winner unless nothing happened. Tightens `01` §18. |
| D98 | Ground scope for the playtest | **Trimmed**: clinch, takedowns, sprawl, full guard top/bottom, get up, scramble | Side control, mount, guard passing and ground-and-pound come after the Phase 1 playtest. Refines `10` §1 and #15. Ground-and-pound came in early with D121 (2026-10-26). |
| D99 | Between rounds | **Rocked and panic clear in the corner; stamina recovers (Recovery); head and leg damage do not** | Replaces the "damage recovered between rounds" wording in `11` §2.2. |
| D100 | World and career simulation | **Pure, in `sim/world/`** | Same rules as the fight engine (no scene tree, seeded), so 30-year world sims can run in CI (R6). The game layer only schedules it. |
| D101 | Renderer | **Compatibility** | Switch before the grey-box view (#19). Smooth on most machines first, looks second. |
| D102 | Pre-coding review | **Filed as `12-pre-coding-review.md`; priority items tracked as GitHub issues** | Structure work lands before #14–#17. |
| D103 | Catch-kicks | **Only when called or drilled** | The fighter AI never throws a move that needs an opening (`required`) on its own, so the kick → takedown call in the playtest only works if the coach makes it (`01` §20, #14). |
| D104 | The Wrestler | **In the data now, parked until #15** | Profile, stance-shift tell and the AI's set-up logic land with #14; he stays out of the showcase and the balance targets until takedowns resolve (#15). |
| D105 | Speed checks | **An over-budget timed fight is run again, up to 3 runs; the fastest counts. On CI the budgets get a 1.5× slow-machine margin (added with #19, Kyle's pick 2026-10-26)** | GitHub's shared test machines vary about 1.6× in speed and sometimes stall, which failed the 1000× checks on code that had just got faster. A sim that is really too slow still fails every run. The margin came after the checks failed four times on slow machines (two runs of PR #47 at 60–66 ms, with the same balance fights taking 120 s against 76 s on a green run); a 50% slower sim still fails, and local runs and the in-game check stay at 1000×. Details, and where to change it: `01` §2.1. |
| D106 | Judging the AI's movement | ~~**A temporary top-down cage view in the debug console, until the grey-box fight view (#19)**~~ **Replaced by D117**: the 3D view shows the fighters, and the F3 debug overlay shows the numbers and the cage lines | The isometric arena is still empty, so range, cage pressure and circling can only be read from the log. The view is debug-only (the console's **Cage view** box), reads the fight without changing it, and gets deleted once #19 shows the same. Details: `01` §20.1. |
| D107 | How fighters move round the cage | **Hold the centre, give ground only to real danger, cut the cage off near the fence, and circle out off it either way; Footwork decides chases and cuts** | Kyle saw the Kicker just circle away and the Boxer just chase (the Kicker spent 97% of the fight near the fence). Fighters now hold their ground until the opponent can actually hit them, pivot back toward the middle when they're the one further out, plant on the fence and slip out when the opponent commits, and change circling direction now and then; a presser steps across to stay between the opponent and the middle once the opponent is near the fence. The worse mover gets less of a chase or a cut done (Footwork edge), and walking into the fence no longer turns backing up into a sprint along it. Replaces the "space" idea in `01` §3. Details, numbers and what to edit: `01` §20.2. |
| D108 | The ground before ground-and-pound | ~~**The fighter on top holds and scores control; the fighter underneath works to get up**~~ **Replaced by D121** (the top fighter grounds and pounds; control still scores, at 0.15 a second) | No ground strikes until after the playtest (D98), so full guard is about position: judges score a takedown (10 points) and every second on top (0.3 × the position's control score), the bottom fighter tries to get up (easier with their back on the fence) and a stint usually lasts 10–30 s. Takedowns resolve on contact and a roll at the end of the drive, so sprawls and knees can punish a shot in between (D29). Details and what to edit: `01` §21. |
| D109 | The Wrestler's balance target | **Report only, no pass mark until after the playtest** | The harness prints Wrestler vs Kicker and Wrestler vs Boxer win shares as INFO lines (D104); Kicker vs Boxer within 60/40 stays the only win check. Targets get set from the playtest. `01` §21.7. |
| D110 | When a round is 10-8 | **Out-landing 4 to 1 in a busy round (or two more knockdowns), not 3 to 1** | Strikers who stuffed every shot in a round were getting 10-8 over a Wrestler who landed little, then losing the other two 10-9: 28-28 draws pushed draws to 2.0% (D97 wants under 2%). At 4 to 1, draws 0.5% with fights unchanged. `Judging.DOMINANT_SHARE` 0.25; `01` §18 Judges, §21.7. Since D120 an out-landing 10-8 also needs a rock or knockdown in the round. |
| D111 | How live calls work | **Three kinds: attempts (one try, stepping in for up to 2 s), focus calls (15 s, like a short gameplan) and read calls (primed 6 s, fire once)** | Takedown!, Clinch! and Get up! are one move; Pressure!, Circle out!, Work the range!, Defend the shot!, Survive! and Stay safe! change how the fighter fights for 15 s of fight time and calling again keeps it going; Catch the kick! reacts to the kick with the fighter's own reaction time. A Takedown! call that lands while the leg is up becomes the catch-kick single. Voice, delay, compliance and trust as `01` §6.2–6.3 with the numbers in `01` §22. |
| D112 | Who the player coaches in the playtest | **The Wrestler, taught the catch-kick single** | He already shoots and is about even with the Kicker without calls, so the harness can measure what coaching adds (D12). Knowing the catch changes nothing on its own (D103): only calls and drilled rules throw it. `01` §22.3. |
| D113 | Corners that call on their own (D12, D68) | **A `Corner` in each corner: none, ideal (a good coach, 0.3 s), the AI corner (0.5 s, notices half the moments) and spam (a random call every 1.5 s)** | Its calls go through the fighter's whole call pipeline as commands, so fights replay without it. The AI corner calls for blue on the fight screen (D117). The harness runs every pair with each bot in red's corner and then blue's, and checks good coaching at +10–20% wins and spam below none, pooled over both corners (one corner alone swung ±6% on the same fights). `01` §22.7. |
| D114 | Strikers' answers to grappling (Kyle: "Fix it in this PR", "Opponent wises up to repeats") | **Strikes into a clinch entry or the first step of a shot stop it (`COMING_IN`); Footwork helps break the clinch; fighters read the third shot in a minute better than the first; a fighter whose move keeps getting caught throws it less; the catch-kick is harder** | With good calls the Wrestler beat the Kicker 77–80% because the Kicker had no answer to extra grappling. The Wrestler grapples more on his own to stay even without calls (takedowns and the clinch count when he plans his range; double-leg tendency 1.2). `01` §21.8. |
| D115 | What a call costs | **Calls pick the moment, they don't add work: a called takedown or clinch entry spends the fighter's own tries of that kind for 45 s; every call heard costs half a second of attention; a call needs the voice it costs; garbled calls are mostly ignored and cost trust** | Random calls every 1.5 s won 84–87% before; now spam does 8–36% worse than no calls in every pairing but Boxer vs Kicker (even). Good coaching of the Wrestler against the Kicker: +13% (D12). D5 holds: at the starting trust with a clear voice, ignores stay rare. `01` §22.5. |
| D116 | How drilled rules work (#17, D82) | **Two slots set before a round; slot 1 goes first (the slot is the priority); reliability = drilled × Fight IQ × tired × hurt × how wise the opponent is; a cooldown per rule; opponents disguise a move a rule keeps catching (10% per fire at Fight IQ 100, at most half)** | The data's `priority` field went (rule@2): a player orders rules by the slot they put them in. Rules come in as `set_rule` commands so fights replay; no voice, no attention cost, and live calls still outrank them. Measured: the catch rule is about even against the Kicker (he stops body kicking and goes high), the sprawl rule costs the Kicker wins (it tires him). `01` §23. |
| D117 | The fight screen (#19) | **The main scene is the playable fight: a setup screen, the grey-box isometric cage, HUD v0 and the speed controls; the player is the red corner, the AI corner calls for blue. Speed only changes how many ticks a second are played, never what a tick does** | Normal 2× (1× can be picked for the D91 comparison), Fast 4×, slow-mo half of Normal; auto slow-mo for 1.5 s when a fighter is rocked or dropped or a scramble starts (D53); the perfect-call flourish (D52) is a move the player's call started that works as a counter (the catch off a called takedown), with 1.2 s of slow-mo and a feed line; pause on Easy only (D50); the bell holds the fight so the drilled rules can be changed. A full fight played with random speed changes and pauses gives the same events as the same fight run headless (A13). The towel is a `throw_towel` command (a TKO loss, D31) so it replays. The renderer is now Compatibility (D101). The temporary cage view is gone (D106). What's in v0, what isn't yet, and what to edit: `06` §6. |
| D118 | The playtest kit (#20, D62, D91) | **Every push to `main` builds a Windows download (GitHub Actions → Playtest build); the game has a Playtest list that sets up three fights in the onboarding order (`07` §3) and saves every fight as a file with its replay and coaching numbers; a report tool adds testers' files up for a write-up that answers every test in `10` §2 and ends in go / adjust / rethink** | The fights: the Wrestler with three calls against the Boxer, then against the Kicker with Catch the kick! and the tell cue, then with a drilled catch rule and every call. Each tester plays fight 2 at both 2× and 1×, half starting at each, for D91. A well-timed takedown is one that worked and that the player's call or rule chose. The export also fixes #35's export preset (data/ ships inside the build; a self-check fight on the exported game proves it in CI). Script, form, write-up template and what to edit: `docs/playtests/`. |
| D119 | Reporting how long each fighter circled and cut off the cage | **After every fight, each fighter's time circling and cutting off the cage, as fight time (m:ss) and a share of the fight: in the debug console's result, the headless sim and the balance harness (a Circling line per pair and four CSV columns). Circling = a step with at least 40% of it going round the opponent; cutting off = pressing or holding with the cut working (the opponent more than 3 m from the middle)** | Kyle asked to see it when fights end. It only counts what the feet already do (D107), so fights come out exactly as before (160 harness fights, every number the same). The 40% leaves out the Kicker's everyday drift sideways (0.15 of a step). The numbers to change are in `01` §20.3. |
| D120 | Health and the referee (Kyle, 2026-10-26: "kind of pointless with no health system"; picked "about 30% of fights end early, like real MMA") | **Each fighter has a health bar: the head damage they can still take (1 − head hurt, 10 × (Chin + 50) of head damage is all of it). The referee stops it (TKO) when health runs out, when a rocked fighter takes 2 more clean head shots without answering, or when a fighter underneath takes 2 + 14 × health clean head shots in a row without answering (landing anything, tying up, or getting out answers). A 10-8 for out-landing now also needs a rock or knockdown in the round; takedowns score 6 (was 10), control 0.15 a second (was 0.3)** | Damage was tracked but only 3% of fights ended early. Now about a third do (26% striker vs striker, 18% Wrestler vs Kicker, 57% Wrestler vs Boxer). Amateur referees step in sooner (`early_stoppage_bias`: health line 15% adult, one shot fewer). Judging changes keep draws under 2% now that ground strikes score. The HUD shows health, body and legs as bars. See `01` §24, `06` §6. |
| D121 | Ground and pound (Kyle, 2026-10-26: "no ground and pound atleast") | **The fighter on top of full guard throws ground punches (everyone) and elbows (a technique; the Wrestler has it; banned under amateur rules, where ground strikes also go to the body only). Accuracy is Top control + Boxing (punch) or Power (elbow) against Guard; full guard top strikes at × 0.8 damage. Underneath: tie up (Guard + Strength vs Top control) to break the posture for 3 s, or get up, both +bonus while the top fighter postures up to strike. Rocked again on the ground is the KO roll, not a knockdown. A "Ground and pound!" focus call (key 1, shared with Pressure!, which is standing only); the AI corner calls it when its fighter lands on top** | Replaces "the top fighter holds" (D108) and lifts D98's "ground-and-pound after the playtest". The Wrestler wins 60–64% against the Kicker and 49–55% against the Boxer (was 48–51% and 40–59%), still report only (D109); good coaching adds +18% and +11% (D12 met). See `01` §24. |
| D122 | Golden fights (#35, `12` §3 item 9, risk R9 in `04`) | **Four whole fights are pinned in `tests/golden/golden_fights.json`: Kicker vs Boxer with no corners, Wrestler vs Kicker coached with the catch-kick rule, Wrestler vs Boxer with the sprawl rule and the AI corner, and the check fighters under amateur rules. Each pins the winner, how and when it ended, events, knockdowns, strikes, takedowns, calls, rules fired and a hash of the whole event list. Any change that alters one of them fails a test until it is re-pinned with `tools/golden.gd -- --update`, and the PR says why. The test also replays each fight from its saved seed and command log** | A balance number, the AI, a corner or a rule changing fights silently is the cheapest drift to catch: now it shows up in the PR as a deliberate update with the old and new numbers side by side. Four fights, not three, so calls, drilled rules, takedowns, a KO/TKO, a decision and a non-pro ruleset are all covered (a test checks they still are). Adds about 6 s to the test run. The export preset and the Compatibility renderer, the rest of #35, are D118 (#20) and D101 (#19). See `01` §2.2. |
| D123 | Faster balance harness runs (#35, `12` §3 item 12: "measure first") | **The harness plays its fights in one Godot process per CPU core (`--jobs=N` to choose, `--jobs=1` for one), each playing every Nth fight, and puts the rows back in order, so the CSV and summary are the same whatever N is. No quiet mode** | Measured 2026-10-26 on a 4-core machine: not keeping the event list made fights under 2% faster (within noise), so a quiet mode isn't worth its code. Threads inside one Godot process only reached 1.6× on 4 cores, even with their own copies of the data; separate processes reached 3.9×. A 35-fight run went from 31 s to 10 s, with the CSV and summary byte for byte the same as before. Rows come back from the other processes in a binary file so every number is exact. See `01` §2.3. |
| D124 | Re-running the playtest's balance numbers (#20, D118) | **A manual GitHub Actions workflow, Actions → Playtest numbers, runs the four harness runs the write-up needs on any branch or commit (no calls with every pairing and the mirrors; the coaching bots on Wrestler vs Kicker and vs Boxer; a second seed set for Wrestler vs Kicker; Playtest 3's drilled rule), 100 fights a pairing and corner, side by side in about 15 minutes, with each summary on the run's page and the CSVs as downloads. It also runs on a pull request that changes the workflow. The write-up template's harness rows were refilled from its first run (2026-10-26)** | The template's numbers predated health and ground and pound, and nobody should need Godot installed to refresh them before a playtest. The refresh: good coaching of the Wrestler is worth +15% against the Kicker (+19.5 and +11 on two seed sets) and +10% against the Boxer (D12 met), but spam now only just loses (−5% and −2.5%, was −10%); the Kicker wins about 18% against a well-coached Wrestler (was 39%); Playtest 1 (Wrestler vs Boxer) ends early 57% of the time without calls and 71% with good coaching. The kit's feedback form gained questions on stoppages and ground and pound (F18–F20) and the write-up a §2b for them. See `playtests/README.md` §4. |
| D125 | The training camp, first piece of the vertical slice (#54; Kyle, 2026-10-27: "start on the next step until we get play test results") | **Training runs in the sim (`sim/world/TrainingCamp`): a week is 6 days × 2 slots with Sunday off, filled from a week plan of sessions (`data/sessions/`, `data/week_plans/`). Sessions auto-resolve at quality 1.0 (a played minigame scores 0.8–1.5); a point costs 10 × e^(stat / 25) XP, slowed near the fighter's potential (new optional `potential` and `age` in fighter@1) and halved past 3 points per stat per camp (fights read the nearest whole point, so a camp's fractions count once they round up); age, Coachable, Fast learner, fatigue and variety scale the XP. Sessions add fatigue, nights keep 60% and Sunday 40%; tired fighters learn less and get hurt more; party animals skip sessions; sessions and the week's instruction (a gameplan) push style leanings; hard sparring wears the Chin. `tools/camp.gd` runs a camp and can fight before vs after** | Picked because it sits outside the fight engine, so the playtest shouldn't reshape it. Fatigue and injuries don't reach fights yet, and the minigames, rule drilling (A6), planner screen and save/load come later. Fights don't change (no golden re-pin). Numbers and what to edit: `02` §3.5. |
| D126 | Submissions, added before the playtest scope said (D98; Kyle, 2026-10-27: "can we add in submissions?", picked the simple struggle on a decision card) | **Three holds from the positions the game has: a guillotine (everyone, on a head left low by a shot; a miss pulls the attacker onto their back), a triangle and an armbar (techniques, from the bottom of full guard, on a broken or postured-up top fighter). A hold locks in like any grapple, then moves the fight to a new `submission` position where a danger meter (start 40 ± the stats' edge) goes 20 up or down each second of fight time on the hold's stats, until a tap at 100 (a submission win) or an escape at 0 or after 5 beats. One call a corner: Finish it! (+15% a beat) and Defend the sub! (−15%), on keys 1 and 6. The AI only goes for a hold on its opening and waits 45 s between tries. The lock scores 4 with the judges and a hold past 80 counts as impact for a 10-8. CI prints the re-pinned golden fights when fights change, for sessions without Godot. The per-beat call menu of D10 and the holds that need other positions come later** | `01` §25, §9, §4.2, §2.2; `06` §6.2; `09` |
| D127 | Playing the playtest solo (#20, D118; Kyle, 2026-10-28: "I dont really have testers atm", then "both" to a solo checklist and throws) | **With no testers, Kyle plays the playtest build himself from a one-page checklist (`playtests/solo-checklist.md`): the three Playtest fights in order (fight 2 at 2× then 1×), what to check in each, ten questions in place of the feedback form, then the saved fights and answers go into the project chat and Claude writes a short solo write-up from the files (no Godot needed; the replay check is left to the tests). A solo run decides carry on or adjust, never go, and its speed pick sets normal speed until testers say otherwise. The playtest fights also open Finish it! and Defend the sub! (D126) from fight 1** | The designer can't be a blind tester: tests 1 and 4 (`10` §2, testers explain why a catch worked or a takedown failed) wait for real testers, and the full kit (script, form, write-up template) stays for them. Everything else a playtest catches (broken, confusing, too fast, unfair, dull, wanting another fight) one player can find. The sub calls were missing from fights 1 and 2's call bars, so a hold locked there (the Kicker's triangle and armbar, a guillotine on a shot) had no answer; they share keys 1 and 6 and light up only in a hold, so the first fight still has three keys to learn (`07` §3). See `playtests/solo-checklist.md`. |
| D128 | Throws, so judo and BJJ fighters become possible (Kyle, 2026-10-28: "both", to throws and the solo playtest checklist) | **Three throws, all takedowns a sprawl can't stop: an outside trip and a hip throw from the clinch (the trip +15% on the fence, the hip throw −10% there, a slam of 8 × (0.5 + Strength / 100) body damage where slams are allowed, `LEANING` after a miss) and a foot sweep on a lean (a hook), which the AI takes when it reads one, unlike the catch (D103). A guard pull (clinch → bottom of full guard, no points either side) and a sweep from the bottom (scored like a takedown). All land in full guard: no side control yet (D98). Two new test fighters, a Judoka and a BJJ fighter, reported with no pass mark (as D109). The *Takedown!* call lists the throws** | `01` §26, §21; `06` §6; `09` |
| D129 | Clinch knees and collar ties for Muay Thai (Kyle, 2026-10-28: "Add some clinch knees and collar ties for muay thai") | **A collar tie (a technique) inside the one clinch position, not a new position: it breaks the opponent's posture for 4 s (the tie-up timer, D121). While it's on the holder's knees are +15%, go to the head (body under teen rules) and do ×1.2; the one tied up breaks at −10%, knees at −15%, and gets out by winning a tie of his own (−15%), breaking, or waiting it out. The AI works twice as often while a tie is on and wants out when tied. A *Collar tie!* call shares key 5 with *Clinch!* (in the clinch, only for a fighter who knows it). A Muay Thai test fighter, reported with no pass mark (as D109, D128)** | The plum is the Muay Thai clinch's whole point and the clinch had nothing to fight over but knees to the body and takedowns. A grip with a timer reuses tested machinery and keeps D98's one clinch position; whether the plum needs its own position (holder and held, control points) is for the playtest. Nobody else knows the move, so other fights don't change. See `01` §27. |
| D130 | More positions on the ground for wrestling, BJJ, judo and sambo (Kyle, 2026-10-28: "Let's work on some positions on the ground I feel like that opens up the most for wrestling BJJ and judo and sambo as well") | **Four positions from `01` §4's diagram: half guard, side control, mount and back control, with the moves between them. On top: a guard pass (full guard → side control, half working → half guard), taking the mount, taking the back (a technique). Underneath: recovering guard, the bridge from mount (a reversal), escaping the back, each showing an opening as he turns (`ESCAPING`). Holds: the rear-naked choke from the back (everyone), the arm-triangle from side control and mount (a technique), the armbar from mount. Ground strikes from every top spot, ×1.3 from mount, ×0.7 from the back. The judges score 6 points per point of control gained on top. The hip throw lands in side control. A *Pass!* call on key 4 (shared with *Takedown!*); *Get up!* calls the way out from wherever. A move that moves the fight only works where its position file says where it goes for that role** | The ground was one guard and a scramble (D98's trim), so a grappler's only reward on top was punching from guard, and subs only came from the bottom. The first of three scopes put to Kyle; half guard and side control alone, or this plus leg locks and a Sambo fighter, were the others (leg locks build on it). Grapplers get a little stronger against strikers (reported, no pass mark, as D109); Kicker vs Boxer doesn't change. See `01` §28. |
| D131 | Feints, and blind shots punished (Kyle, 2026-10-28: "to fix the wrestling vs striking issue let's start working in feints. Grapplers should be punished for not feinting or for shooting blind takedowns") | **A feint that every fighter knows: on its own roll (Fight IQ and Speed against Fight IQ) the opponent bites, hands up and weight back for a second (`BIT_ON_FEINT`): a shot or clinch entry then gets +10%, his sprawl −10%, and he reads moves half as well. Feinting again within 30 s bites 10% less each time. A takedown from standing with nothing setting it up is a blind shot (`BLIND_SHOT`): none of the shooter's strikes or feints in the last 0.5 s, no opening to shoot into (a counter into his wind-up or recovery, `LEANING`, a bite; the fence doesn't count), not a catch and not a throw. A blind shot is −20%, read +30%, sprawled on +20%, stuck 0.5 s longer under a sprawl and costs 5 more stamina when it's stuffed. The double leg's base drops from 45% to 35%: a shot works as before only off a bite. The fighter AI feints before a shot that would be blind on a chance of 10% + 60% × Fight IQ / 100, then shoots off it; strikers never feint on their own. Clinch entries aren't blind shots. A *Feint!* call (key 7 standing, 20 voice) feints, then shoots off it straight away (or ties up, for a fighter with no takedown), so a called set-up is never blind** | Grapplers beat strikers 72–78% after D130, mostly by shooting whenever they liked. Kyle picked the second of three scopes (the feint alone; **this plus a *Feint!* call**; the blind-shot penalty with no feint move). One call, not *Feint!* then *Takedown!*: a second call lands 0.6 s later, after the bite. Called every 10 s it takes the Wrestler from 29 to 40 wins of 60 against the Boxer, where *Takedown!* every 10 s drops him to 5 (blind shots). Blind clinch entries were tried and taken out: they cost the Muay Thai fighter 17 points against the Boxer, a striker fight. Wrestler vs Boxer 75% → 60%, vs Kicker 77% → 72% (the rest is shots timed into his kicks, which are set up); striker fights unchanged. See `01` §29. |
| D132 | Leg locks and a Sambo fighter (Kyle, 2026-10-29: "alright lets start on that", the third ground scope from D130) | **Three leg locks, each a hold with the D126 struggle: the ankle lock (from underneath in full or half guard, or a scramble), the kneebar (from on top of half guard, or a scramble) and the heel hook (as the ankle lock, but its danger moves 30 a beat, not 20, and it's banned under both amateur rulesets through the ruleset's `heel_hooks` flag). They need a leg, not a neck: a leg lock that misses costs the position (from underneath, he walks past the legs into side control and scores the pass; from on top or a scramble, the attacker ends up on the bottom of full guard and the other scores a reversal). Getting out of one ends in a scramble. The AI goes for one underneath only when the top fighter postures up, on top only as the one underneath escapes, and in a scramble at any time. A Sambo test fighter (throws, a double leg, the ankle lock and kneebar; sport sambo bans the heel hook) and the BJJ fighter learns the ankle lock and heel hook** | Kyle's D130 card offered leg locks and a Sambo fighter as the scope after the four positions. Leg locks are the gamble a grappler takes from anywhere, so the miss has to cost something, or the AI would dive for feet every scramble. The heel hook uses the `heel_hooks` rule `08` has had since the start. Reported, no pass mark (D109): the Sambo fighter wins about half his fights with the strikers, three in four with the Wrestler, one in four with the BJJ fighter; leg locks end 10–15% of his fights. Striker and Wrestler fights don't change. See `01` §30. |
| D133 | Striker combinations (Kyle, 2026-10-29: "after that I want to work on strikers combinations", then picked the *Fire back!* scope on a decision card) | **Strikers have drilled combinations, one file each in `data/combos/` and listed in a fighter's `combos` (the Boxer's 1-2, 1-2-3, 1-1-2 and 2-3; the Kicker's jab or teep into a kick; the Muay Thai fighter's 1-2 into a body kick or a knee). Each move after the first flows out of the last (its telegraph 0.1 s shorter), one that changes levels is +20% to land, and one the opponent has seen before is −5% a time (up to −15%) and easier to read. A clean shot, the next move not reaching, being rocked or the fight leaving the feet breaks it. The AI's chaining chance is unchanged: when its next strike starts one of its combinations, that's what it throws, one chained move at a time. A *Fire back!* read call on E: primed for 3 s, when the opponent's strike is defended the fighter answers with their first combination that reaches, thrown whole; it costs 30 voice, −25% defense while primed, and 10 s of no leads of their own after it fires** | Combinations should reward drilling and timing, not just throw more. The first draft ran every combination to its end and the Boxer beat the Kicker 65% (the #14 exit test is 60/40); one chained move at a time keeps him at about 58%. Kicks after kicks fell short half the time, so the Kicker's combinations start with a jab or a teep (all but the body kick into a high kick, which stayed in his profile by mistake and was in every number measured; docs corrected with D140). *Fire back!* spammed took the Boxer to 86% in a first draft; with its limits it's worth about +6 called well and costs about 9 against a sharp puncher. See `01` §31. |
| D134 | The camp planner screen (Kyle, 2026-10-29: "Let's start working on the training camp side of things as well since that doesn't effect the actual fight", picked the planner first on a decision card; "Ideally, you would have some defaults, you know, focus on speed, focus on this, focus on that. But I'd also want one where you can select it yourself") | **A planner screen for the camp (`ui/camp_planner.gd`), opened from the fight setup's *Training camp first*: set the camp's length (1–8 weeks, 6 by default) and the fighter's age and potential, fill each week from a week plan or slot by slot (12 dropdowns and an instruction; any change makes a Custom week), see a forecast of the week before running it (`TrainingCamp.forecast`: the week on a copy that rolls no dice, with the chance of an injury), run it a week at a time or to the end, then *Fight!* with the trained fighter (`<id>_camp`, kept whole in the fight's record so it replays). Five focus weeks (Speed, Cardio, Power, Jiu-jitsu, Defense) and a *Sprints & plyometrics* session (Speed 60%) join the presets; every week plan gets a one-line `about`** | Makes the camp something Kyle can play and judge (D125 only had `tools/camp.gd`), and it's what phases, gyms and minigames plug into later. Dropdowns, not §3.1's drag and drop, and no minigames: those come with the art. Fatigue and injuries still don't reach the fight: fight-night condition is next (Kyle: they "should absolutely carry into the fight", and a badly hurt fighter pulls out or is pulled out), then ageing and the prime (a perfect 18-year-old peaks around 28–29). Fights don't change. See `02` §3.6. |
| D140 | More strikes (Kyle, 2026-10-29: "alright lets start expanding on that now", then picked "Core set plus clinch dirty boxing" on the scope card). D134–D139 are the training camp thread's | **Seven new strikes, each a data file: the uppercut (pocket; +25% and ×1.4 into a lowered head, stopping the shot; drops the rear hand), the overhand (mid and pocket; +20% over dropped hands; leaves him leaning), the hook to the body (pocket; +15% into a kick or knee), the calf kick (mid and pocket; quicker than the leg kick, to the legs, catchable), the elbow (pocket and clinch; +15% on a head pulled down; banned in amateur rules), and the short uppercut and short hook inside the clinch (dirty boxing). The Boxer gets the uppercut, overhand, hook to the body and both clinch punches, with a clinch-entry tendency of 0 so he fights in the clinch but never looks for it; the Kicker the calf kick; the Muay Thai fighter the elbow (0.5) and a clinch-entry tendency of 3.25 (was 2.5); the Wrestler the overhand. Four new combinations** | Each new strike punishes an opening the engine already had, so the AI needs no new code. Two profile numbers answer what the range plan does on its own: a fighter with any clinch strike goes looking for the clinch (the Boxer walked into the Wrestler's shots, 71%), and the Muay Thai fighter flips from walking the Boxer down to being walked down on small changes (37% until his clinch entry went up). Reported, no pass marks (D109); the #14 exit test still passes. See `01` §32. Soccer kicks, stomps and knees on the ground come next, under a PRIDE ruleset (Kyle's pick, 2026-10-29). |
| D141 | PRIDE rules (Kyle, 2026-10-29: "also we will be adding soccer kicks to downed opponents and knees to grounded opponents", "pride never die", then picked "A new PRIDE ruleset" and "Whole-fight judging, PRIDE style" on decision cards) | **A fourth ruleset, `data/rulesets/pride.json`, picked on the fight setup's *Rules*: a 10-minute first round then two of 5 (`round_lengths`), no elbows, knees to the head standing and on the ground, soccer kicks and stomps on a knocked-down fighter (the new `DOWN` flag; only `strike.downed` moves land on him, everyone knows them, and the AI follows a knockdown up at 30% a free tick), and the whole fight judged instead of rounds (`judging: whole_fight`): each judge gives it to whoever did more to finish it, then (within 10%) whoever controlled it, then whoever pushed it. A knee on the ground from side control (Wrestler, Judoka) goes to the head under PRIDE and the body elsewhere. Pro and amateur rules stay unified rules** | Kyle wants PRIDE's violence without changing the main game. A kick on a downed man is no second knockdown, but it can end the fight. Harness: PRIDE draws 0%, 76% of fights finished (pro 61%), half inside the first round; the Boxer beats the Kicker 65% (pro 54%), and finish-first judging takes the Judoka from 62% to 51% against the Boxer. Pro fights change only through the ground knee (to the body), within about the noise. See `01` §33, `08` §1.1. |
| D150 | The body damage figure instead of the health bar (Kyle, 2026-10-29: "Lets look into chaning the health bar into a visual body representation that reflects current damage levels"; three mockups shown, the heat-map figure recommended). D141–D149 are the strikes thread's | **The top bar's health bar and small body and leg bars are replaced by a little fighter figure per fighter: head, body and both legs each run smoothly from green (fresh) through yellow (half gone) to red (finished) by that area's hurt, with a readout beside it (HEAD 65%, BODY 94%, LEGS 100%: what's left of each, in the same colour) and ROCKED under it while they are. The head is still health (D120): at 0 the referee stops it. Both legs show the one legs area until the engine tracks them apart. A part flashes white for 0.35 s when a clean shot lands on it, and a rocked head pulses. Stamina stays a thin bar underneath. Both fighters show exact numbers (scouting, D24, can hide them later). Presentation only: fights are unchanged** | The health bar only showed the head; body and leg damage sat in two thin bars nobody read. One figure shows where a fighter is hurt at a glance, which is what a corner needs to make a call (go to the body, attack the legs, *Survive*). See `06` §6.2 and §6.6, `ui/body_damage_figure.gd` |

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
- [`11-attributes-and-traits.md`](11-attributes-and-traits.md): attribute list, how stats enter a fight, trait layers (incl. style from training habits)
- [`12-pre-coding-review.md`](12-pre-coding-review.md): structural review before heavy coding (2026-10-24), baseline numbers, D91–D102
- [`playtests/`](playtests/README.md): how to run a playtest (script, feedback form, write-up template, the solo checklist) and the write-ups (D118, D127)

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
- [VS] Core physicals: Strength, Speed, Cardio, Chin, Durability, Recovery (full list: `11` §2.2, D85)
- [VS] Striking: Boxing, Kicking, Clinch striking, Defense, Footwork
- [VS] Grappling: Takedowns, Takedown defense, Top control, Guard/bottom game, Submissions, Submission defense, Scrambles
- [VS] Mental: Fight IQ, Composure, Heart
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
