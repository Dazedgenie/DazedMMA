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

---

## 3. Spatial model (D2, D33)

- The **octagon** is a 2D polygon (the isometric view is only for display). Fighters have positions
  and facing in cage space.
- **Distance bands:** Out of range → Long (kicks) → Mid (punches) → Pocket (hooks/uppercuts, knees) → Clinch.
- **Cage proximity:** Centre / Near cage / Pinned. This affects:
  - takedown odds (easier to finish against the cage, but cage-walking lets the defender get up),
  - escape odds (circling out is harder when cut off),
  - strike options (fence grab = foul, D20).
- **Cutting off the cage:** a pressure fighter's lateral movement mirrors the opponent's to shrink
  the space. Mechanically this is a "space" value that drops while you're under pressure without circling.

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
constants in `sim/fight/octagon.gd`, `sim/fight/fight_sim.gd`, `sim/fight/placeholder_ai.gd` and `sim/fight/judging.gd`. Stat effects are in `11` §3.5.

| Piece | Rule |
|---|---|
| Cage | Regular octagon, 4.5 m from the centre to each panel (30 ft across). Fighters start 3.5 m apart and go back to their corners each round |
| Distance bands | Out > 3.0 m · Long 2.2–3.0 · Mid 1.5–2.2 · Pocket < 1.5. Standing fighters can't get closer than 0.9 m until the clinch exists (#15) |
| Reach | A strike only lands from the bands in its data. The AI only starts moves that reach; a commanded or interrupted move that no longer reaches *falls short* ("out of range") |
| Movement | Walk at 0.8 + 1.2 × (Footwork + Speed)/200 m/s toward the distance where your moves work, shifted by the Range (±0.5 m) and Pace (±0.3 m) leanings. Committed fighters don't move |
| Cage | Near = within 1.5 m of the fence; pinned = within 0.5 m with the opponent in mid range or closer (`BACK_TO_CAGE`). Backing up near the fence turns into circling toward open space; the presser mirrors to cut it off. Who wins the sideways battle is a Footwork contest |
| Flags | From action phases (data `flags_self`), plus `BACK_TO_CAGE` when pinned and `HANDS_LOW` below a quarter tank or while rocked |
| Counters | Hitting a fighter in wind-up or recovery: +10% to land and ×1.3 damage |
| Damage | Base damage × (0.5 + Power/100), at least 1 |
| Rocked | Head shots only. Shock = damage × (1 + head hurt) / (6 + 0.12 × Chin). Rock chance = (shock − 0.6) × 0.5, up to 60%: a jab never rocks a fresh fighter, a clean hook or head kick can. Rocked lasts 4 s × (1.5 − Recovery/100): Speed, Striking defense, Fight IQ −30% more, hands drop, they back off and mostly cover up, and the opponent swarms (more with a Wild Risk leaning) |
| Knockdown | Rocked again while rocked. Down for 2 s (nobody hits a downed fighter until the ground game exists), then up and rocked |
| KO / TKO | KO roll on each knockdown: 15% + (shock − 1) × 50%, 5–80%, × (1.5 − Heart/100). TKO on a third knockdown in a round, or a rock with the head fully hurt |
| Judges | Three judges, 10-point must. A round's points = damage landed (head ×1, body ×0.8, legs ×0.6) + 8 per rock + 20 per knockdown; each judge sees each fighter's points ±15%. Within 5% = 10-10 (too generous: D97 wants 10-10 rounds very rare and draws under 2%); 10-8 for two more knockdowns or out-landing 3 to 1 in a busy round. Decision: unanimous / split / majority / draw |
| Events | `range_changed`, `cage_changed` (announced once held for 0.5 s), `rocked`, `knockdown`, `got_up`, `recovered`; strikes carry `counter`, the `odds` breakdown (§19) and, when they fall short, a `reason` |

Not yet: leg damage giving out, liver shots, cuts, aggression and cage control on the cards, judge personalities and fouls (D20),
and anything clinch or ground (#15). Fatigue never shows with the current costs (D96, `12` §4).

## 19. Decision layer in the engine (#33)
How §6.0 and §7 plug into the code (`12` §3 item 2). The fight loop (`sim/fight/fight_sim.gd`) owns time, movement and
resolution. What a free fighter starts each tick comes from their **decision layer** (`sim/fight/decision_layer.gd`), which reads
the fight through a read-only **view** and walks one priority stack. The first layer that claims the choice wins:

| Priority | Layer | Today |
|---|---|---|
| 1 | **Command** | An action queued from outside (tests, bots, the debug console). Always obeyed if possible |
| 2 | **Live call** | A `live_call` command waits out the call delay in fight time (base 0.6 s = 6 ticks, D92), then a compliance check (always complies until #16 adds the roll, D5) and a feasibility check (legal, possible from this position). Every outcome is logged as `call_answered`: accepted, ignored or infeasible, with the reason (A16) |
| 3 | **Drilled rule** | Slot reserved; rules arrive with #17 |
| 4 | **Fighter AI** | The placeholder AI (`sim/fight/placeholder_ai.gd`) until #14. Gameplans only multiply its weights per action or category, so the fighter never silently replaces the gameplan (§16 A2) |

- **Reaction time** (D93) is one number on the fighter, shared by read calls, rules and the AI: 3 − 0.02 × Speed ticks
  (3 at Speed 0, 2 at 50, 1 at 100), stretched by fatigue up to +30%, at least 1 tick.
- **Odds breakdown** (A16): every rolled strike event carries `odds` = base, the stat gap on effective stats, and each bonus by
  name (`counter`, the opponent's flag such as `ONE_LEG`), plus `clamped` when the 5–95% cap cut it. The debug console prints it:
  *"Jab LANDS (head, 3 damage) 65% (base 50 · stats +5 · counter +10)"*. Takedowns get the same breakdown when they resolve (#15).
- **Rulesets** (`08`): the fight takes a ruleset (pro by default) for rounds, round length, damage scaling from gear and which
  actions are legal. Banned actions are refused as commands and calls and never picked by the AI. Today only `takedowns` maps to
  actions; elbows, knees to a grounded opponent, ground strikes to the head and slams map as those actions arrive (#15).
