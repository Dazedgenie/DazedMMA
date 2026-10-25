# 01 — Fight Engine & Coaching

> The heart of the game. Related decisions: D1, D5, D6, D9–D12, D20, D27–D33.
> Status: **design draft**. Numbers are starting points for the prototype, not final balance.

---

## 1. Goals

1. A call made at the right moment **visibly wins exchanges**. A call made at the wrong moment
   **visibly loses them**.
2. The player can always answer **"why did that work / fail?"** from what was on screen.
3. Fighters behave like *themselves*. A wrestler with a big ego and a striker with a calm
   counter style should feel different even with no calls at all.
4. The simulation runs **headless and deterministically** (seeded) so we can balance it with thousands of
   auto-fights.

---

## 2. Time model

| Concept | Value (draft) | Notes |
|---|---|---|
| Fight time per round | 5:00 | Standard MMA |
| Real time per round | ~2:30 | Time scale **2×** (D9) |
| Simulation tick | **100 ms of fight time** | 10 ticks per fight-second, 20 ticks per real second at 2× |
| Slow-mo | 0.5× real (= 1× fight time) | Costs nothing. Accessibility setting: unlimited |
| Active pause | Optional setting | Calls can be queued while paused; opponent AI is frozen too, so it's fair |

The simulation never reads frame time. Presentation interpolates between ticks. That keeps the simulation
deterministic and lets it run headless at 1000× for balance tests.

### 2.1 Speed budget and how it's checked (D105)

A fight must simulate at least **1000× faster than fight time**: a 3 × 5:00 fight in under 900 ms, the 60-second self-check
fight in under 60 ms. Two checks enforce it:

| Check | Where | Budget |
|---|---|---|
| Full fight | `tests/sim/fight/test_fight_sim.gd`, `test_a_full_fight_runs_over_1000x_faster_than_fight_time` | 900 ms |
| Self-check fight ("Runs over 1000x faster than fight time") | `game/sim_check.gd`: the debug console's **Run test fight**, also run in CI by `tests/game/test_sim_check.gd` (5 seeds) | 60 ms (`ROUND_SECONDS`) |

**The rule (D105):** a timed fight that comes in over budget is simulated again, up to 3 runs in all, and the fastest run
counts. A fight under budget on its first run is timed once. GitHub's shared test machines vary about 1.6× in speed and
sometimes stall for a moment: on 2026-10-25 the same code ran the full fight in 967 ms on one machine and 380 ms on another.
A sim that is really too slow is slow on every run, so it still fails. To change the number of runs, edit `TIMING_TRIES` in
`game/sim_check.gd` and the `3` in the full-fight test; keep them the same.

**Where the time goes** (profile of a full fight, 2026-10-25, about 0.6 s here): the AI's feet (`preferred_distance`) and
choice (`choose`) each tick, `FighterState.effective_stat` (2–4 µs a call, about 30,000 calls a fight), walking (`_move`) and
the cage checks. Speed-ups made with #14 (PR #40), about 20%, none of which changed a single fight:

- `effective_stat`, `tired`, `hurt`, `max_stamina` and `regen_tick` read `stats` directly, and head hurt is worked out once
  per `effective_stat` call (`is_panicking()` is the same test).
- `Octagon.keep_inside` and `Octagon.proximity`, and the AI's fence check (`_fence_behind`), skip the eight fence-panel
  checks for points well inside the cage (`Octagon.CLEAR_INSIDE`, `CLEAR_OF_NEAR`, `FighterAI.CLEAR_OF_FENCE`).
- The sim works out the fighters' distance once per step and once per space update.
- `FightView.band()`, `step()`, `distance()` and `roll()` read the sim reference directly.
- The AI looks up all four style leanings once a second (`LEAN_EVERY`), and walking pace, the footwork contest and the
  range plan are cached too (`FightSim.FEET_EVERY`, `FighterAI.PLAN_EVERY`).

**Speed work must not change fights.** Run the same fights (same seeds and fighters) before and after, and compare a hash of
each fight's event list (`JSON.stringify(sim.events_as_dicts()).md5_text()`). If any hash differs, the change altered
behaviour: re-run the balance harness and treat it as a design change.

---

## 3. Spatial model (D2, D33)

- The **octagon** is a 2D polygon (the isometric view is only for display). Fighters have positions
  and facing in cage space.
- **Distance bands:** Out of range → Long (kicks) → Mid (punches) → Pocket (hooks/uppercuts, knees) → Clinch.
- **Cage proximity:** Centre / Near cage / Pinned. This affects:
  - takedown odds (easier to finish against the cage, but cage-walking lets the defender get up),
  - escape odds (circling out is harder when cut off),
  - strike options (fence grab = foul, D20).
- **Cutting off the cage (D107):** a pressure fighter steps sideways to stay between the opponent and the middle of the
  cage, so the opponent's way out along the fence shuts. It only bites once the opponent is near the fence (in open space
  there's no way out to shut), and how much of it gets done is a Footwork contest. This replaces the earlier idea of a
  "space" value that drops while you're pressed without circling: the space is now the fighters' real positions. Built as
  §20.2.

---

## 4. Position state machine (MMA phases)

```
STANDING ──(clinch entry)──► CLINCH (open / cage / plum / body lock)
   ▲  │                         │  ▲
   │  └──(takedown / trip)──────┼──┼──► GROUND
   │                            │  │    ├─ Full guard (top/bottom)
   └──────(stand-up / break)────┴──┘    ├─ Half guard
                                        ├─ Butterfly / open guard
                                        ├─ Side control
                                        ├─ Mount
                                        ├─ Back mount / back control (seated)
                                        ├─ North-south
                                        ├─ Turtle / front headlock
                                        └─ SCRAMBLE (transitional, contested)
```

Every position defines its **available actions**, its **available calls**, its stamina drain, how much
control it scores for the judges, and its striking damage multipliers.

### 4.1 The model in the engine (#34, `12` §3 item 4)
- **One shared situation.** Positions are relational (one fighter is on top), so the fight holds a single **situation** both
  fighters read (`sim/fight/situation.gd`): the phase (standing / clinch / ground), the named position (`standing`,
  `full_guard`, …) and each fighter's **role** in it (`neutral` standing, `top` / `bottom` on the ground; clinch positions name
  their own roles). Fighters no longer carry their own position. Every round starts standing.
- **Transitions are data.** Each position file lists how the fight leaves it: *this action, landed by the fighter in this role,
  takes the fight to that position with these roles* (`09` position@2). Today: a landed double leg or catch-kick single from
  standing → full guard, shooter on top. The code only applies what the data says (`FightSim.apply_transition`); resolution
  calls it when a takedown, clinch entry or get-up succeeds (#15). Adding a position is a content change, not a code change.
- **The cage carries through.** Where the fight is in the cage stays with the fighters' own spots. Tying up or taking someone
  down happens on the spot where the opponent stood, so a takedown on the fence stays on the fence, the bottom fighter keeps
  `BACK_TO_CAGE` (wall-walking), and getting up separates the fighters right there, a standing gap apart.
- While tied up (clinch or ground) nobody walks, and the range reads `clinch` whatever the distance.
- **Still to come with #15:** actions say which roles may use them (so only the bottom fighter can get up), clinch entry,
  get up and scramble as actions, and removing the standing minimum gap (`Octagon.MIN_GAP`) once the clinch exists. Each
  position's stamina drain, control score and damage multipliers are in the data but not yet applied.

### 4.2 Playtest scope (D98)
The Phase 1 playtest ships a trimmed ground game (#15):

| In the playtest | After the playtest |
|---|---|
| Clinch (one clinch position), double leg, catch-kick single, sprawl, full guard top/bottom, get up, scramble | Half guard, side control, mount, back, north-south, turtle, guard passing, sweeps, ground-and-pound, submissions (§9) |

---

## 5. Actions: the commitment model (the core idea)

Every action has four phases:

| Phase | Meaning | Vulnerability |
|---|---|---|
| **Telegraph** | Readable pre-movement (weight shift, dipped shoulder, hand drop). Length depends on technique skill; elite fighters telegraph less | Low |
| **Wind-up** | Committed; can't cancel cheaply | **Counter window opens** |
| **Active** | The strike/shot lands or gets defended | Depends |
| **Recovery** | Rebalancing. Off-balance flags apply (e.g. *on one leg*, *head off-centre*, *hands low*) | **Counter window** |

Each phase can set **state flags** that counters look for:

| Flag | Set by | Exploited by |
|---|---|---|
| `ONE_LEG` | Body/head kick, teep, knee | Catch-kick single leg, sweep, counter cross |
| `HANDS_LOW` | Lazy jab return, shot attempt, fatigue | Overhand, head kick, knee |
| `HEAD_LOW` | Level change, shot | Knee, guillotine, front headlock, uppercut |
| `LEANING` | Overcommitted hook/overhand | Counter hook, trip, level change |
| `BACK_TO_CAGE` | Pinned position | Double leg against the cage, knees in the clinch |
| `POSTURE_BROKEN` | Clinch control, being pulled into guard | Subs from the bottom, sweeps |

### 5.1 The example the whole game is built around: kick → takedown
- Opponent throws a **body kick**: telegraph 0.3 s, wind-up 0.3 s, active 0.2 s, recovery 0.4 s
  (fight time). `ONE_LEG` is set from wind-up through recovery, about **0.9 s of fight time ≈ 0.45 s real time** (all timings are whole 100 ms ticks; source: `data/actions/body_kick.json`).
- A takedown that *starts* while `ONE_LEG` is active gets a large bonus (e.g. +35% success) and turns into a
  **catch-kick single leg**.
- The same shot against a balanced opponent with good TDD is likely to get sprawled on (D29), and shooting
  into a knee (`HEAD_LOW` against a knee in active frames) risks a **flash KO**.

Even counting the fighter's reaction delay (§6.2), a 0.45 s real-time window is too short for pure reaction. Players
hit it in two ways:
1. **Anticipation**: the player knows (from tells/scouting) *when* the kick is coming and calls just before it.
2. **Read calls**: see §6.1. These are the core skill, and they make "perfect timing" achievable without twitch reflexes.

---

## 6. Coaching

### 6.0 The four coaching layers (D82)

| Layer | When set | What it does |
|---|---|---|
| 1. **Gameplan** | Pre-fight (adjustable in the corner) | Strategic preset (Pressure / Counter / Range / Wrestle-heavy / Conserve) that biases the AI's action weights |
| 2. **Drilled rules** | Pre-fight / between rounds; must be **drilled in camp** | 2–3 slots of *trigger → action* ("Opponent body kick → catch-kick single"). Fire automatically with the fighter's own reaction time |
| 3. **Live calls** | During the round | Now calls + read calls (§6.1), with delay, compliance and the voice meter |
| 4. **Corner** | Between rounds | Recovery, cutman, adjustments, motivation (§10) |

**Drilled rules in detail:**
- A rule = **trigger** (an opponent event like *body kick telegraph*, *level change*, *back to cage*; or a state like
  *opponent stamina < 30%*) + **action** (a technique the fighter knows) + **priority**.
- **Reliability (0–100%)** = how many reps it got in camp (the "Rule drilling" session in the middle-camp phase) ×
  Fight IQ × technique proficiency. Each fire also gets fatigue/damage penalties.
- A rule fires only if it's eligible (range, position, stamina, not committed) and passes the reliability roll. Otherwise
  the log says why (*"Catch-kick rule: too tired to fire"*).
- **Cooldown** after each fire, so rules can't be farmed. Opponents with high Fight IQ **adapt** to a rule that fires
  repeatedly: they telegraph less or bait it (counter-play, risk R4).
- **Slots:** 2 at the start, a 3rd from the coach's *Tactician* skill / experience. Advanced conditions
  (AND filters, stamina thresholds, fallbacks) are a later unlock (Foundation doc "advanced rule builder").
- Rules and read calls work together: a rule is the **pre-planned** answer, and a read call is the **improvised** one.

### 6.1 Two kinds of live call (D49)

| Kind | Example | Behaviour |
|---|---|---|
| **Now call** | "SHOOT!", "Clinch!", "Get up!" | The fighter attempts the action as soon as they've processed the call. Pure timing. |
| **Read call** (primed) | "Catch the kick!", "Counter the jab!", "Watch the shot!" | The fighter stays primed for N seconds. If the trigger happens, they react with *their own* reaction time, which is much faster than call delay. Priming has a cost: e.g. watching for kicks makes them slightly slower to defend punches. |

Read calls reward **knowing the opponent** (tells, scouting). Now calls reward **timing**. The best
players combine them: prime the read, then follow up with a now call.

### 6.2 Call processing pipeline

```
Player presses call
   └─► Voice check (D28): costs voice; low voice = garbled call
        └─► Delay = base 0.6 s of fight time (6 ticks, D92)
                    × (1 - FightIQ bonus)
                    × (1 - CoachTrust bonus)
                    × (1 + fatigue + damage + crowd noise penalties)
                    × (coach level bonus, D15)
             └─► Compliance roll (D5): ego, trust, panic, personality conflicts
                  ├─ Ignored  → fighter shakes head / visible "nah" indicator
                  └─ Accepted → becomes high-priority intent for the AI
                         └─► Feasibility check (position, stamina, distance)
                              └─► Action executes with modifiers from timing, flags, skills
```

**Visible to the player:** a small "processing" ring above the fighter fills over the delay, and the
voice meter. Ignored calls get a clear animation and a text feed line.

### 6.3 Voice meter (D28)
- Maximum 100. A call costs 15–30 (big calls cost more). Regenerates about 8/s of fight time.
- Below 30, calls are *garbled*: +50% delay and −20% compliance.
- Spamming the same call within 3 s also drains **Coach Trust** a little.
- Crowd noise (venue size, hometown, big moment) increases delay, not voice cost.

### 6.4 Call catalogue (start, D27)

| Intent (starts unlocked) | Unlocks into (via techniques, D6/D13) |
|---|---|
| **Pressure** | Cut the cage, Body work, Walk him to the fence |
| **Circle out** | Pivot off the cage, Angle out, Lateral stick-and-move |
| **Work the range** | Jab to the body, Calf kicks, Teep the advance |
| **Takedown** | Double leg, Single leg, *Catch-kick single*, Trip from clinch, Body-lock throw |
| **Clinch** | Collar tie, Thai plum knees, Underhooks against the cage |
| **Defend the shot** | Sprawl, Guillotine on the shot, Whizzer |
| **Get up** | Wall-walk, Technical stand-up, Hip escape to guard |
| **Survive** | Tie up, Hold on, Cover up |
| **Stay safe** (D31) | Coast mode: lower output, high defense, no risks |
| *Ground (context)* | Pass guard, Ground-and-pound, Posture up, Sweep, Hunt the sub (Kimura, RNC, Arm-triangle...) |

Context-sensitivity: only calls that are possible in the current position appear prominently, and the rest are dimmed.

### 6.5 Habits from calls (D32)
- Track how often the player calls an intent in a given situation (e.g. "Takedown after opponent kicks").
- A fighter with **Adaptive** or **Coachable** traits gradually adds a small AI weight toward that response, up to a cap.
- **Stubborn** fighters don't absorb habits. **Ego** fighters absorb only calls that *worked*.

---

## 7. Fighter AI (without calls)

A **utility AI**: each tick the fighter scores the available actions:

`score = base_tendency × gameplan_bias × situation_modifiers × stamina_factor × personality × habits`

- **Tendencies** are part of the fighter data (e.g. jab 0.8, leg kick 0.6, shot 0.2).
- **Tells** (D11) are *patterns written into tendencies*: conditional rules such as
  "after a blocked double jab → 70% throw a right body kick within 1.5 s" or
  "when down on the scorecards → shoot more often, with a longer telegraph".
- Calls temporarily override or boost scores for one intent.

In the engine: §20.

---

## 8. Damage, stamina, state

| Resource | Effect |
|---|---|
| **Stamina** (short-term) | Every action costs stamina. Low stamina → longer telegraphs, slower recovery, bigger flags (hands drop) |
| **Cardio** (attribute) | Regen rate; how deep the tank is across rounds |
| **Head damage** | Chin threshold. Rocked state (wobbly; huge counter vulnerability), knockdowns, KO |
| **Body damage** | Drains max stamina; liver-shot fold possible |
| **Leg damage** | Slower movement, stance switch forced, eventually the leg gives out |
| **Cuts/swelling** | Vision penalty on one side (more tells missed, punches from that side land more), doctor-check risk |
| **Composure/Momentum** | Panic → more ignored calls, wild swings. Momentum → more accuracy and willingness |

Lucky punches (D12) come from: a clean counter on a rocked/`LEANING` fighter + a chin roll. They're rare,
but happen often enough that an underdog always has a chance.

---

## 9. Submissions: coach-driven struggle (D10)

1. A sub attempt starts from position + flags (e.g. back mount + `HANDS_LOW` from fatigue → RNC).
2. **Lock-in phase**: the defender's stats contest the attacker's. If it locks, play moves to the **struggle sequence**.
3. The struggle is 3–5 beats (~1–2 s real time each, auto slow-mo). Each beat shows the **danger meter** and
   2–4 coach calls: e.g. *Hand-fight! / Tuck the chin! / Turn into him! / Stack! / Tap!*
4. Each beat has a *correct* response determined by the hold's stage (each sub type has a script) plus the
   fighter's skills. The right call drops danger; the wrong call raises it; no call = fighter's own AI choice.
5. Danger hits 100 → tap (or a "go to sleep" stoppage). Escape → reversal or scramble.
6. **On offence** it's mirrored: "Get the hooks in! Flatten him! Switch to the arm-triangle!"

---

## 10. Between rounds: the corner (D30)

- A **60-second real-time budget** (the clock is visible). Each action uses time:
  - **Cutman minigame** (D20): ~15–25 s. Pressure + Vaseline/adrenaline on a cut. Success lowers bleeding and doctor risk.
  - **Ice / enswell** on swelling: ~10 s
  - **Water / breathing**: recovers stamina; skipping it costs cardio
  - **Tactical instruction** (pick up to 2): gives a next-round bias, e.g. "He drops his hand after the jab" (reveals a tell
    and adds a read-call bonus), "Go to the body", "Take him down early", "Win this round: you're down"
  - **Motivation** (pick 1 tone): Calm / Fire up / Tough love. The effect depends on personality and trust
- **Throw in the towel** (D31): available any time, and at the corner as a dedicated button with a confirmation.

---

## 11. Officials, fouls, scoring (D20)

- **Judges**: 10-point must system. Each round is scored on effective striking/grappling > aggression > cage control.
  Judges have personality weights (e.g. *loves takedowns*, *volume-striking fan*, *damage-first*). The player can
  learn their reputations over a career.
- **Referees**: stoppage threshold (early vs late), stand-up impatience, foul strictness.
- **Fouls**: eye poke, groin strike, illegal knee to a grounded opponent, fence grab, strike to the back of the head.
  Fouls come from personality (dirty/reckless), fatigue and position. Outcomes: warning → point deduction → DQ,
  plus a pause for the fouled fighter's recovery.
- **Doctor checks** for cuts and swelling between rounds or after a ref pause.

---

## 12. Commentary feed (D20)

- Template-based play-by-play driven by simulation events (`KICK_CAUGHT`, `TAKEDOWN_SUCCESS`, `ROCKED`...).
- Two commentator personalities (play-by-play + colour), with spikes for big moments.
- Also a teaching tool: *"He's been dropping that left after every jab, and his corner has spotted it!"*

---

## 13. Fight end and stats

- Finishes: KO, TKO (ref), TKO (doctor), TKO (corner/towel), Submission, Decision (unanimous / split / majority), Draw,
  DQ, No contest (accidental foul).
- Post-fight stats (FightMetric style): significant strikes by target, takedowns landed/attempted, control time,
  sub attempts, knockdowns, **call success rate** and **perfect-timing calls**.

---

## 14. Resolved questions
- F1 → **D49**: now calls + read calls are both in.
- F2 → **D50**: active pause on Easy difficulty only.
- F3 → **D51/D66**: scouted tells show an on-screen cue. The head coach's *Reading* stat makes it appear earlier.
- F4 → **D52**: perfect-call flourish (slow-mo + sound + feed line).
- F5 → **D53**: auto slow-mo on big moments (can be switched off in settings).
- F6 → **D54**: keyboard + mouse at launch (hotkeys 1–9 + clickable call bar). Controller later.

## 15. Resolved (round 2)
- F7 → **D67**: up to 2 read calls stacked, with a bigger attention cost.
- F8 → **D68**: the opponent's corner calls are audible/visible, so you can counter-call.
- F9 → **D69**: difficulty affects both opponent AI and assistance.

## 16. Merged from the Foundation doc (see `05`)
- **Speed controls (A3):** Normal (2× fight time) / Fast (4×, quiet moments) / Tactical slow-mo (test 0.15–0.5×). The simulation clock slows, not only the animation.
- **Autonomy principles (A2):** the fighter never silently replaces the gameplan, never attempts impossible actions,
  never switches instantly between incompatible actions, and always defends against immediate danger.
- **Difficulty dimensions (A4):** *Combat challenge* (opponent AI quality, adaptation) · *Simulation realism*
  (stamina/injury/weight-cut strictness) · *Coaching assistance* (cues, auto slow-mo, pause on Easy, explanation detail).
  Same core rules on every difficulty.
- **Explanations in the event log (A16):** every call/rule logs why it fired, was ignored, suppressed, or fell back.
- **Drilled rules (proposal C2, pending):** see `05` §4.

## 17. Gaps to spec before sign-off
- **Fight HUD layout** (round/clock, both fighters' condition, position/range, active plan/rules/reads, voice meter, call bar, feed).
- **Onboarding**: the first amateur fights double as a tutorial that introduces calls one at a time.
- **Amateur ruleset**: 3×3 min rounds, shin guards, no elbows / no strikes to a grounded head (with C3).

## 18. Standing game v1 in the engine (#13)
What `sim/` does today for §3, §5, §8 and §11. Every number is a first guess for the balance harness (#18); they are named
constants in `sim/fight/octagon.gd`, `sim/fight/fight_sim.gd`, `sim/fight/fighter_ai.gd` (§20) and `sim/fight/judging.gd`. Stat effects are in `11` §3.5.

| Piece | Rule |
|---|---|
| Cage | Regular octagon, 4.5 m from the centre to each panel (30 ft across). Fighters start 3.5 m apart and go back to their corners each round |
| Distance bands | Out > 3.0 m · Long 2.2–3.0 · Mid 1.5–2.2 · Pocket < 1.5. Standing fighters can't get closer than 0.9 m until the clinch exists (#15) |
| Reach | A strike only lands from the bands in its data. The AI only starts moves that reach; a commanded or interrupted move that no longer reaches *falls short* ("out of range") |
| Movement | Walk at 0.8 + 1.2 × (Footwork + Speed)/200 m/s toward the distance the fighter's range plan wants (§20). Committed fighters don't move. Walking costs stamina (D96): 0.6 a second at full pace × (share of full pace)², so walking in is cheap and running all night isn't. A clean shot stops the feet for 1 tick + 1 per 4 damage; a landed teep shoves the opponent 0.5 m back (`push_m`) |
| Cage | Near = within 1.5 m of the fence; pinned = within 0.5 m with the opponent in mid range or closer (`BACK_TO_CAGE`). The fence stops the part of a step that goes into it and the rest slides along it, so backing straight into the fence gets a fighter nowhere (D107). A presser aims where a moving opponent is going: how far ahead is the presser's share of a Footwork contest. Chasing someone who's getting away and cutting the cage off both depend on Footwork too (§20.2), so good feet get out and bad feet get trapped |
| Flags | From action phases (data `flags_self`), plus `BACK_TO_CAGE` when pinned and `HANDS_LOW` below a quarter tank or while rocked |
| Counters | Hitting a fighter in wind-up or recovery: +10% to land and ×1.3 damage |
| Damage | Base damage × (0.5 + Power/100), at least 1 |
| Rocked | Head shots only. Shock = damage × (1 + head hurt) / (6 + 0.12 × Chin). Rock chance = (shock − 0.6) × 0.5, up to 60%: a jab never rocks a fresh fighter, a clean hook or head kick can. Rocked lasts 4 s × (1.5 − Recovery/100): Speed, Striking defense, Fight IQ −30% more, hands drop, they back off and mostly cover up, and the opponent swarms (more with a Wild Risk leaning) |
| Knockdown | Rocked again while rocked. Down for 2 s (nobody hits a downed fighter until the ground game exists), then up and rocked |
| KO / TKO | KO roll on each knockdown: 15% + (shock − 1) × 50%, 5–80%, × (1.5 − Heart/100). TKO on a third knockdown in a round, or a rock with the head fully hurt |
| Judges | Three judges, 10-point must. A round's points = damage landed (head ×1, body ×0.8, legs ×0.6) + 8 per rock + 20 per knockdown; each judge sees each fighter's points ±15%. Within 5%, the round goes to the busier fighter (aggression: strikes and takedowns started plus metres walked forward, each judge seeing it ±15%), then to whoever held the other on the fence longer (cage control); only a round where nothing separates them is 10-10 (D97). 10-8 for two more knockdowns or out-landing 3 to 1 in a busy round. Decision: unanimous / split / majority / draw |
| Events | `range_changed`, `cage_changed` (announced once held for 0.5 s), `rocked`, `knockdown`, `got_up`, `recovered`; strikes carry `counter`, the `odds` breakdown (§19) and, when they fall short, a `reason` |

Not yet: leg damage giving out, liver shots, cuts, judge personalities and fouls (D20), and anything clinch or ground (#15).

## 19. Decision layer in the engine (#33)
How §6.0 and §7 plug into the code (`12` §3 item 2). The fight loop (`sim/fight/fight_sim.gd`) owns time, movement and
resolution. What a free fighter starts each tick comes from their **decision layer** (`sim/fight/decision_layer.gd`), which reads
the fight through a read-only **view** and walks one priority stack. The first layer that claims the choice wins:

| Priority | Layer | Today |
|---|---|---|
| 1 | **Command** | An action queued from outside (tests, bots, the debug console). Always obeyed if possible |
| 2 | **Live call** | A `live_call` command waits out the call delay in fight time (base 0.6 s = 6 ticks, D92), then a compliance check (always complies until #16 adds the roll, D5) and a feasibility check (legal, possible from this position). Every outcome is logged as `call_answered`: accepted, ignored or infeasible, with the reason (A16) |
| 3 | **Drilled rule** | Slot reserved; rules arrive with #17 |
| 4 | **Fighter AI** | The fighter AI (`sim/fight/fighter_ai.gd`, §20). Gameplans only multiply its weights per action or category and shift its style leanings, so the fighter never silently replaces the gameplan (§16 A2) |

- **Reaction time** (D93) is one number on the fighter, shared by read calls, rules and the AI: 3 − 0.02 × Speed ticks
  (3 at Speed 0, 2 at 50, 1 at 100), stretched by fatigue up to +30%, at least 1 tick.
- **Odds breakdown** (A16): every rolled strike event carries `odds` = base, the stat gap on effective stats, and each bonus by
  name (`counter`, the opponent's flag such as `ONE_LEG`), plus `clamped` when the 5–95% cap cut it. The debug console prints it:
  *"Jab LANDS (head, 3 damage) 65% (base 50 · stats +5 · counter +10)"*. Takedowns get the same breakdown when they resolve (#15).
- **Rulesets** (`08`): the fight takes a ruleset (pro by default) for rounds, round length, damage scaling from gear and which
  actions are legal. Banned actions are refused as commands and calls and never picked by the AI. Today only `takedowns` maps to
  actions; elbows, knees to a grounded opponent, ground strikes to the head and slams map as those actions arrive (#15).

## 20. Fighter AI in the engine (#14)
What a fighter does when nobody is calling (`sim/fight/fighter_ai.gd`), the bottom of the §19 stack. It sees the fight only
through the read-only view and the fight's events, so it knows what a fighter in the cage could know, one reaction time late
(D93). The aim is §7: believable, varied and true to style with no calls at all. Every number is a named constant and a first
guess for the balance harness; stat effects are in `11` §3.5.

| Piece | Rule |
|---|---|
| Each free tick | In order: (1) danger first (A2): a rocked fighter covers up and gets out; a shot it read gets sprawled on (60% + 30% × Takedown defense). (2) Follow through: a tell, or the next strike of a combination. (3) An opening it read in time. (4) Meeting an opponent who walks in. (5) Now and then, a lead |
| Reads | A move registers one reaction time after the fighter first sees it start. Read chance = (0.15 + 0.5 × Fight IQ/100) × a telegraph factor (a 2-tick telegraph is normal, each tick longer or shorter ±20%, 0.5–1.5×); half when rocked. A read gets used 75% of the time, ±20% for Pace (patient fighters take more). Fighters step in turn each tick, so a move that starts after your step is first seen next tick (fair to both corners) |
| Counters and openings | A counter is timed to land in the opponent's wind-up or recovery (+10%, ×1.3 damage, §18); an opening is timed to land while the opponent's flag is up (`ONE_LEG` during a kick, `LEANING` after a hook). Outside fighters may step back instead: up to 60% at Range −100, plus 30% × head hurt for anyone |
| Catch-kicks | Never on their own (D103): a move that needs an opening (`required`) gets no weight from the AI. Only a call or a drilled rule throws it |
| Leads | Per tick: work rate (0.015, about one lead every 7 s) × (1 + Pace/200); × (1.5 + Risk/200) against a rocked opponent; × 0.35 while resetting or crowded; × 0.6 while still walking in; fading below half a tank; × 1.25 in the last 15 s of a round and when behind going into the final round. Never more than 4× the work rate |
| Picking a move | Only moves that will still reach as they land. Weight = tendency × style (Base +100: takedowns ×2, strikes ×½; −100 never shoots) × gameplan × commitment × stamina × what's working × (odds now / plain odds)², picked by weighted chance that is sharper with Fight IQ (weights to the power 1 + IQ/100) |
| Commitment | Strike weight × (ticks / 5)^−aversion, aversion = (0.5 − 0.4 × Risk/100) × danger/0.5: safe fighters throw quick shots, wild ones throw big ones, and everyone throws big ones more freely where the opponent can't punish them |
| What's working | Each move's landing record moves its weight by up to ±40% at Fight IQ 50, ±80% at 100 |
| Combinations | After a strike, another at (0.15 + 0.45 × the move's technique stat/100) × (1 + Pace/200), up to 3 more. Outside fighters then often reset: step out 0.6 m for 1–2 s (up to 70% at Range −100) |
| Range plan | Every 2 s, per band: my threat − caution × theirs, over my best threat (threat = the best move's expected damage per second from there, plus a quarter of the rest); caution = 0.8 − 0.3 × (Pace + Risk)/100. Range ±0.35 and Pace ±0.15 tilt it toward the pocket or long range; the band it holds gets +0.1 so it doesn't flicker. It never plans to stand where none of its own moves reach |
| Feet | Stand in the planned band (Range +100 0.25 m closer, Pace +100 another 0.15 m). Walking into the opponent's weapons while they're free, stalk: half pace (± a quarter for Pace, a tenth faster when losing on their own reckoning), scaled by the opponent's share of the threat there; full speed while the opponent is committed to a move. Pressed by an opponent who can't do much from where they stand, they hold their ground; once the opponent is in range of their own weapons, they give ground back to their spot (D107). Outside fighters circle when giving ground (0.8 of their pace at Range −100, 0.25 when not), and pivot back toward the middle when they're further out than the opponent. Backing up with the fence within 1.5 m behind them, they back up less (none at the fence), and outside fighters circle out off it. Pressing, they cut the cage off. The details of all of this are in §20.2. A fighter with nothing that reaches from anywhere holds their ground |
| Crowded | Closer than planned in a band where the opponent out-guns them (the Kicker caught in the pocket): getting out comes first, so leads × 0.35 and combinations × 0.5 |
| Meeting the advance | When the opponent walks in faster than 0.4 m/s: one roll per advance at (0.2 + 0.5 for an outside fighter) × (0.5 + Fight IQ/100) to land a strike as they arrive |
| Hurt | Rocked: cover up, get out and circle away; reads halved, leads × 0.3. Opponent rocked: swarm from the band of the best head shot, head shots weighted up by (0.5 + 0.5 × Risk/100) × (head hurt + 1) |
| Tells and set-ups | From the profile's `tells` (`09`): when the trigger's event happens, follow with the action within the window, at the given chance. The Kicker: jab blocked → body kick, 70% within 1.5 s. A set-up is a tell set off by the fighter's own move: the Wrestler shifts his stance (a 0.2 s telegraph, the tell to watch for) and shoots a double-leg within 1 s, 90% |
| Why | Every move the fighter starts says why (`why` on the telegraph event: leads, combination, counters the jab, opening: ONE_LEG, meets him coming in, swarms, tell: jab blocked); the fight log prints it |

Balance on 2026-10-25 before the movement work (harness, 100 fights a pairing): the Kicker beats the Boxer 46% of the time, 44% with the corners swapped
(the #14 exit test is within 60/40); one draw in 500 fights and no 10-10 cards (D97); in Kicker vs Boxer someone ends up under half
a tank in 82% of fights (D96). Mirror matches come out even (Kicker 53/47, Boxer 49/51). The Wrestler is tested but stays out of
the targets until #15 (D104).

After the movement work (D107, §20.2), same harness: the Kicker beats the Boxer 53% of the time, 48% with the corners swapped;
one draw in 500 fights and no 10-10 cards; someone under half a tank in 87–94% of Kicker vs Boxer fights. Mirrors: Boxer 53/47,
Kicker 41/59 on seeds 1–100 and 46/54 on seeds 101–200. The two Kickers are identical, so that's most likely seed noise
(100 fights swing about ±10%), but blue was ahead both times: if it holds over more fights, look for a corner bias in the feet.

To watch in the playtest: the Kicker is near the fence for a bit over half the fight (it was nearly all of it) and almost never
pinned, but the Boxer still holds the centre (nearer it 98% of the time) and the Kicker mostly circles round him at range; the
Boxer's hook is rare because the Kicker seldom stays in the pocket when it would land; the Kicker works harder for it (lowest
stamina about 30% of the tank, was 37%); and two Boxers stand in the pocket and trade until one is stopped (every Boxer mirror
ends inside the distance), which is as much the damage numbers (§18) as the AI. Since D107 they do it on the fence more often
(near it 36% of the time, was 26%): a fighter who doesn't lean outside plants on the fence and fights instead of circling off.

Speed: the AI made a full fight about 1.65× slower; the speed-ups in §2.1 won back about 20%; D107's footwork costs about 4%
back. The speed budget and the timing checks are in §2.1 (D105).

### 20.1 Watching the AI move: the top-down cage view (temporary, D106)
A debug-only map of the cage seen from straight above, to judge by eye how the AI uses range, the fence and circling before
the grey-box fight view (#19) exists. It lives in `ui/cage_map.gd` and is switched on and off with the **Cage view** box in the
debug console (the ` key); it follows **Live fight** and hides with the console. It only reads the fight, so a watched fight
plays out exactly as an unwatched one (tested in `tests/ui/test_cage_map.gd`).

| On the map | What it shows |
|---|---|
| Octagon | The fence (`Octagon.APOTHEM`, 4.5 m to each panel); two faint lines inside it mark where "near the fence" (1.5 m) and "pinned" (0.5 m) start, measured from a fighter's body |
| Dots | Each fighter (red, blue) at body width; a white halo when pinned, a purple one when rocked, dimmed when down |
| White point | The way the fighter faces. The engine has no separate facing yet (§3 says fighters have one): both always face each other, so this points at the opponent |
| Arrow | Where the fighter is heading: their last 0.5 s of movement, drawn as 1 s at that pace |
| Trail | The path of the last 4 s; it restarts when the fighters go back to their corners for a new round |
| Ring | The distance each fighter is walking toward (their range plan, §20 "Feet"), drawn around the opponent in the walker's colour |
| Line between them | Coloured by range: grey out, green long, yellow mid, orange pocket |
| Text above | Per fighter: wanted distance, how much they're circling (0–100%), how hard they're cutting the cage off (0–100%, §20.2), pace in m/s, near the fence or pinned, and the move they're in. Then the clock, the distance and the range |

To change it: trail length, arrow length and the pace window are constants at the top of `ui/cage_map.gd` (`TRAIL_TICKS`,
`ARROW_SECONDS`, `SPEED_WINDOW`); its size and place on screen are `CAGE_VIEW_WIDTH` and the offsets in `ui/debug_console.gd`.
The sim gives it three read-only numbers, `FightSim.last_wanted_distance()`, `last_circling()` and `last_cutting()`. To remove
it once #19 is in: delete `ui/cage_map.gd`, its test and the **Cage view** lines in `ui/debug_console.gd`, those three
`FightSim` functions (and the `_wants`, `_circling` and `_cutting` arrays only they read), and this section; mark D106 as
replaced.

### 20.2 Moving round the cage (D107)
Until D107 each fighter had one idea about movement: walk to the distance the range plan wants. The Kicker wants long range
and the Boxer the pocket, so the Boxer walked forward, the Kicker walked back until the fence stopped him, and then slid
along it at full pace. Watched in the cage view (§20.1), the Kicker just circled away and the Boxer just chased. The harness
said the same: the Kicker was near the fence 97% of the fight and pinned 45%, the Boxer was nearer the centre 99% of the time,
and one of them was chasing the other 80% of the time. Fighters now also care where they are in the cage.

Each tick a free standing fighter makes one footwork plan, a `FeetPlan` (`sim/fight/feet_plan.gd`): how far apart they want
to be, how much to circle and which way, and how hard to cut the cage off. `FighterAI.plan_feet` fills it and
`FightSim._move` carries it out.

| Behaviour | What the fighter does | To change it |
|---|---|---|
| Holding the centre | Pressed (the opponent is closer than they want), a fighter holds their ground while the opponent can do little from there: the opponent's share of the threat at this distance (the range plan, §20) is under 15%. Once it isn't, they give ground all the way back to their spot, then hold again. Stepping back from a strike and resetting after a combination work as before | `HOLD_DANGER` 0.15 in `sim/fight/fighter_ai.gd` |
| Back toward the centre | An outside fighter (Range below 0) who is further from the middle than the opponent circles round the opponent toward it while giving ground or while the opponent is busy throwing, and pivots instead of backing off. Both grow with how much further out they are (all of it from 1 m further out) and with how far outside they lean (all of it at Range −100) | `CENTRE_PULL` 1.0, `CENTRE_PULL_OVER` 1.0 m and `PIVOT` 1.0 in `fighter_ai.gd` |
| Off the fence | With the fence within 1.5 m behind them, everyone backs up less (not at all at the fence), so a pressure fighter who gets backed up plants and fights. Outside fighters also circle out: all they can for 1.5 s, toward the side nearer the middle (a coin flip when neither side is clearly more open), the moment the opponent commits to a move, or else on a chance of 50% × how far outside they lean, each tick | `FENCE_SENSE` 1.5 m, `ESCAPE_TICKS` 15 and `ESCAPE_RATE` 0.5 in `fighter_ai.gd` |
| Changing direction | In open space (the fence more than 0.8 m away), circling fighters think again every 3 s and switch direction 40% of the time, so they don't circle the same way all fight. Closer to the fence they circle toward the middle | `SWITCH_EVERY` 30 ticks, `SWITCH_CHANCE` 0.4 and `SWITCH_FENCE` 0.8 m in `fighter_ai.gd` |
| Cutting off the cage | Pressing or holding (not while giving ground, rocked, or swarming a hurt opponent), a fighter steps sideways toward the spot between the opponent and the middle, as far from the opponent as now. How hard: 0.6 at Range 0, ±0.4 at Range ±100. It fades in as the opponent goes from 3 m to 4 m out from the middle, because it's the fence that traps: in open space there's no way out to shut. The sideways step is × the presser's Footwork contest share | `CUT_BASE` 0.6 and `CUT_PER_RANGE` 0.4 in `fighter_ai.gd`; `CUT_FROM` 3.0 m and `CUT_FULL` 4.0 m in `sim/fight/fight_sim.gd` |
| Chasing | Walking in on someone whose last step was away, a fighter keeps up only by their footwork edge = (2 × Footwork contest share)², at most 1. Even feet get all of the chase; the Boxer's 50 against the Kicker's 70 (a 30% share) gets about a third | `FightSim.footwork_edge()` in `fight_sim.gd` |
| The fence | The fence stops the part of a step that goes into it, and the rest slides along it. Before D107 a fighter who walked into the fence slid along it at full pace, so backing straight up turned into a sprint along the fence. Walking costs stamina for the distance actually covered | `FightSim._move()` in `fight_sim.gd` |

The harness reports movement for every pair (the **Feet** line: time near the fence and pinned, who was nearer the centre,
how much of the fight was a chase) and two INFO lines for the whole run (`04` §2.3). Before and after D107, 100 fights a
pairing:

| | Before | After |
|---|---|---|
| Kicker vs Boxer: Kicker wins (Kicker red / Kicker blue) | 46% / 44% | 53% / 48% |
| Kicker near the fence (pinned) | 97% (45%) | 59% (1%) |
| Boxer near the fence (pinned) | 85% (12%) | 1% (0%) |
| Nearer the centre: Kicker / Boxer | 1% / 99% | 2% / 98% |
| One chasing the other | 80% | 36% |
| Kicker mirror: near the fence, chasing | 31%, 10% | 33%, 9% |
| Boxer mirror: near the fence (pinned), chasing | 26% (1%), 10% | 36% (9%), 10% |

The harness had a bug that this work found: the 60/40 check counted wins by corner, so a pair run both ways round
(`kicker:boxer,boxer:kicker`) always looked about 50/50, even when one fighter won 95% of the time. It now counts wins by
fighter, whichever corner they were in (`BalanceReport.fighter_win_share`). The earlier numbers in §20 come from the per-pair
lines, so they stand; the check itself said 50.5% before D107, when the real favourite (the Boxer) won 54.5%.

Tested in `tests/sim/fight/test_fighter_ai.gd` (holds ground out of reach, circles out off the fence when the opponent commits,
steps across to cut off, changes direction), `tests/sim/fight/test_standing_game.gd` (better footwork gets off the fence
sooner, the footwork edge) and `tests/sim/balance/` (the movement numbers, the by-fighter check). After changing any of the
numbers above, run the harness with both corners and the mirrors
(`--pairs=kicker:boxer,boxer:kicker,kicker:kicker,boxer:boxer`), read the **Feet** lines next to the wins, and watch a few
fights in the cage view, which shows how hard each fighter is cutting off.

Tuning notes, so nobody walks the same dead ends: cutting off in open space, or at full strength whatever the Footwork,
left the Kicker winning 2–20% of fights against the Boxer, and slowing the chaser with no cut at all had him winning about
73%. The cut only near the fence and × the presser's share, plus the squared footwork edge on chases, is what landed near
50%.
