# 11 — Attributes & Traits (proposal)

> Kyle asked to settle the stat and trait system before more engine work, because it decides how simulated fights play out.
> Related: D13, D24, D32, D36, `02` §1.3 and §2, `01` §6.5, §7, §8. Status: **v1: decided** (D85–D90, 2026-10-23). `02` §1.3/§2 and `data/enums/stats.json` follow this doc.

---

## 0. Where we are today

- `02` §2 lists **26 attributes** (all in `data/enums/stats.json`) plus hidden ones. `02` §1.3 lists **6 personality axes** (D36).
- The engine uses stats in exactly one place so far: **strike hit chance** = 50% + (attacker's offense stats − defender's
  defense stats) / 100, clamped to 5–95% (`sim/fight/contest.gd`). A jab uses Boxing + Speed against Striking defense.
  Takedown stats are written in the data but not resolved yet (#15). Any stat a fighter doesn't have counts as 50.
- So almost everything is still open, which makes this the right time to decide.

Problems found while reading:
1. **Duplicates:** *Coachability* and *Composure* are both an attribute (`02` §2) and a personality axis (`02` §1.3).
   *Aggressive ↔ Patient* is a personality axis but is really fighting style.
2. **Stats without a clear job:** Explosiveness vs Speed, and Ground-and-pound vs Top control + Power, overlap.
3. **Nothing turns training habits into personality.** D32 turns repeated *calls* into small AI habits, and D36 lets
   traits drift from *career events*, but "always pushing the pace in training makes them aggressive" isn't covered.

## 1. Principles

1. **Every stat has one main job in the fight engine** that fits in a sentence. If we can't name it, the stat doesn't exist.
2. **Attributes are what the fighter can do** (trained with XP). **Traits are who the fighter is** (shaped by choices
   and habits). No number lives in both.
3. **Stats tilt the odds and never guarantee** (keep the 5–95% clamp). A well-timed call should be worth about as much as a
   ~15-point stat gap, so coaching matters (`10` §2: good coaching = +10–20% win rate).
4. **Condition beats paper.** A tired, hurt fighter fights below their numbers, and the debug overlay shows by how much.

---

## 2. Attributes

### 2.1 How many?

| Option | Count | Good | Bad |
|---|---|---|---|
| A. Keep the current list | 26 | Already in docs and data | Overlaps (see §0), more to train, balance and explain |
| **B. Trim the overlaps (recommended)** | **23** | Every stat has its own job; still deep enough for a sim fan | Small doc/data update |
| C. Lean | ~14 | Very readable | Loses archetypes (e.g. a great guard player with weak top game) |

### 2.2 Recommended list (option B)

| Group | Attribute | Main job in the fight | Also affects |
|---|---|---|---|
| Physical | **Strength** | Wins clinch and grappling contests (control, escapes, finishing takedowns) | Small damage bonus; walk-around weight |
| | **Speed** *(absorbs Explosiveness)* | Shortens telegraph and wind-up on every action; faster reactions for read calls and drilled rules | Burst on shots; hit chance on fast strikes |
| | **Cardio** | Size of the stamina tank and how fast it refills during a round | How much the tank shrinks round to round |
| | **Recovery** | Stamina recovered between rounds (head and leg damage don't come back, D99); how fast "rocked" wears off | Healing between fights; training fatigue |
| | **Durability** | Resists body and leg damage | Injury risk in training |
| | **Chin** | How much head damage before rocked / knockdown / KO | Wears down over a career (KO losses and wars chip it) |
| Striking | **Boxing** | Punch accuracy and combo flow | |
| | **Kicking** | Kick accuracy; shorter kick telegraph (harder to catch) | |
| | **Clinch striking** | Knees and elbows in the clinch and against `HEAD_LOW` | |
| | **Power** | Damage per strike; KO chance on clean shots | Ground-and-pound damage |
| | **Striking defense** | The defense side of every strike (slip, block, parry) | |
| | **Footwork** | Winning the range: getting to your distance, circling off the cage, cutting it off | Escape odds when pinned |
| Wrestling | **Takedowns** | Shot, trip and throw success | |
| | **Takedown defense** | Sprawl and stuff odds; getting up off the cage | |
| | **Clinch control** | Winning clinch position, pinning to the cage, breaking free | |
| | **Scrambles** | Winning `SCRAMBLE` and getting back up | |
| Grappling | **Top control** *(absorbs Ground-and-pound)* | Holding and advancing top positions, passing guard | Ground-and-pound accuracy (damage = Power) |
| | **Guard** | Sweeps, sub threats and staying safe off the back | |
| | **Submissions** | Lock-in odds and starting danger in the struggle (`01` §9) | |
| | **Submission defense** | Defending the lock-in and the struggle beats | |
| Mental | **Fight IQ** | Shorter call delay (`01` §6.2); drilled-rule reliability; the AI picks better actions | Adapting to repeated patterns |
| | **Composure** | Panic threshold: how much damage and bad moments before calls get ignored and swings get wild | Momentum swings |
| | **Heart** | Surviving rocked states; late-round output when hurt; comeback chance | |

Moved out: **Coachability** becomes a personality axis only (§5.1). **Explosiveness** folds into Speed. **Ground-and-pound** is Top control + Power.

### 2.3 Body and hidden values (set at creation, not trained)

| Value | What it does |
|---|---|
| **Frame**: height, reach, build | Reach lengthens strike range; build sets natural weight (D35) and nudges Strength/Speed ceilings |
| **Stance**: orthodox / southpaw / switch | Southpaw angle bonus against orthodox; switch stance unlocks later |
| **Potential** | Overall ceiling; where training XP slows down (`02` §3.3) |
| **Max chin** | The cap that Chin wears down from |
| **Aging curve** | When the peak window starts and how fast decline comes |
| **Injury proneness** | Training and fight injury risk |

### 2.4 Scale

Internally 0–100, shown as letter grades with tags (D24). Rough benchmarks for tuning:

| Range | Grade | Who looks like this |
|---|---|---|
| 0–19 | F | Never trained it |
| 20–34 | D | A 16-year-old walking into the gym (best background stats up to ~45) |
| 35–49 | C | Solid amateur |
| 50–64 | B | Regional pro |
| 65–79 | A− / A | Big-promotion pro |
| 80–89 | A+ | Elite in that skill |
| 90+ | A+ (tagged) | Best in the world at it; rare |

---

## 3. How attributes enter a fight

### 3.1 One contest formula for everything
Every contested moment (strike, takedown, sprawl, clinch fight, sub lock-in, scramble) uses the formula the jab already uses:

`chance = action base + (attack stats − defense stats) / 100 + situation bonuses (flags, cage, opportunities)`, clamped to 5–95%.

*Example:* a jab from Boxing 70 / Speed 60 (average 65) into Striking defense 50: 50% + 15% = **65%**.

| Option | Good | Bad |
|---|---|---|
| **Linear, as today (recommended for the prototype)** | Easy to read in the debug overlay and the event log | Big gaps hit the clamp quickly |
| S-curve | Gaps in the middle matter most; extremes flatten | Harder to explain "why did that work?" |

Revisit with harness data from the balance tool.

### 3.2 Effective stats: condition matters
A fighter fights at their stats × their condition. Draft rules:
- **Stamina** under 50%: physical and technique stats drop gradually, up to −30% at empty. Cardio decides how fast you
  get there, not how bad it is.
- **Head damage / rocked**: Speed, Striking defense and Fight IQ drop.
- **Leg damage**: Footwork, Speed and Kicking drop.
- **Panic** (Composure broken): Fight IQ and defense drop; Power and output go up (wild swings).

The debug overlay shows it as e.g. *Boxing 70 → 52 (tired, hurt)*.

### 3.3 Attributes change timing, not just odds
Speed shortens telegraph and wind-up by up to ±20% (whole ticks). Kicking shortens kick telegraphs. A shorter telegraph
is harder for the opposing coach to read, so skill shows up in exactly the thing the prototype is testing.

### 3.4 What the prototype needs now
The standing + takedown prototype only needs about 17: Strength, Speed, Cardio, Durability, Chin, Boxing, Kicking, Power,
Striking defense, Footwork, Takedowns, Takedown defense, Clinch control, Top control, Guard, Fight IQ, Composure.
The rest stay at the default 50 until their systems exist.

### 3.5 In the engine now (first-guess numbers)
What `sim/` does today. Every number is a first guess for the balance harness (#18) to tune; they live as named constants
in `sim/fight/fighter_state.gd`, `sim/fight/fight_sim.gd` and `sim/fight/contest.gd`.

| Piece | Rule |
|---|---|
| Contest formula (§3.1) | `Contest.chance`, used for every strike. `FightSim.odds()` gives takedowns and sprawls their odds the same way (base from data, opportunity bonuses from the opponent's flags, 0 if a `required` opportunity is missing); applying a takedown's result waits for #15 |
| Stamina tank | 60 + 0.8 × Cardio points (Cardio 50 = 100). Refills 0.6 + 1.2 × Cardio/100 per second. Every move costs its `stamina_cost` when it starts |
| Corner | Wins back 30% + Recovery/2 % of the missing stamina (Recovery 50 = 55%). Rocked ends; damage stays (D99) |
| Tired | Below half a tank, physical and technique stats fall linearly to −30% at empty. Cardio, Recovery, Durability, Chin and the mental stats don't |
| Hurt | "Fully hurt" = 10 × (Chin + 50) head damage, 10 × (Durability + 50) body or leg damage. Head: Speed, Striking defense, Fight IQ up to −30%. Legs: Footwork, Speed, Kicking up to −30%. Body: stamina tank up to −30% |
| Panic | When head hurt reaches 40% + Composure/2 % (Composure 50 = 65%): Fight IQ and the defense stats −20%, Power +15%, 20% busier |
| Timing (§3.3) | Speed 100 → telegraph and wind-up −20%, Speed 0 → +20% (kick telegraphs use the average of Speed and Kicking). Tired stretches them up to another +30% (`01` §8). Whole ticks, never below one |
| Style leanings (§4.2) | Four leanings with the ±30 hint, ±60 trait and ±40 fade lines. The fighter AI (`01` §20) reads them: Pace (+100 = 1.5× as many leads, −100 = half; patient fighters take more of the openings they read and stalk slower), Base (+100 doubles takedowns and halves strikes, −100 never shoots), Range (where in the range plan they like to stand, how much they circle, step back from strikes and reset) and Risk (safe fighters throw quick shots, wild ones big ones and swarm a rocked opponent harder) |
| Fight IQ in the AI | Reads: (0.15 + 0.5 × Fight IQ/100) of moves, before the telegraph factor. Picks: weights to the power 1 + Fight IQ/100, so sharp fighters pick their best option more often. What's working: up to ±40% at 50, ±80% at 100. Meeting an advance: × (0.5 + Fight IQ/100) |
| Footwork in the AI | Movement is a Footwork contest (`01` §18, §20.2, D107). A presser aims ahead of a moving opponent by the presser's share. Chasing someone who's getting away, a fighter keeps up by their footwork edge = (2 × share)², at most 1: even feet get all of the chase, 50 against 70 (a 30% share) about a third. Cutting the cage off near the fence gets the presser's share of the sideways step. Good feet get out, bad feet get trapped |
| Technique in the AI | Combinations: another strike at (0.15 + 0.45 × the move's technique stat/100) × (1 + Pace/200), so Boxing chains punches and Kicking chains kicks |
| Debug | The console summary shows stamina, panic and worn-down stats as *Boxing 70 → 49 (tired)*, plus style hints and traits; strike lines show the odds they were rolled at |

Not yet: what named style traits actually do in a fight, and pushing leanings from training, gameplans and calls (those systems
don't exist yet). Rocked and knockdowns landed with #13; the corner clears rocked and panic but not damage (D99).

---

## 4. Traits: random or earned? Both, in three layers

| Layer | What it is | Set by | Changes |
|---|---|---|---|
| **1. Personality** | How they think off the mat: how they treat you, money, discipline | Vignettes + a small random roll (D36) | Slowly, from career events and how you treat them |
| **2. Fighting style** | How they fight when nobody's calling | Training habits + gameplans + calls you make | Steadily, from what you *do* (Kyle's "push the pace" idea) |
| **3. Gifts & flaws** | Things they're born with | Rolled at creation, weighted by frame and background | Almost never |

### 4.1 Personality (4 axes, each −100 to +100)

| Axis | Gameplay effect |
|---|---|
| Ego ↔ Humble | Call compliance; Ego fighters only learn habits from calls that worked |
| Discipline ↔ Party animal | Camp consistency, weight-cut success, life-event risks |
| Coachable ↔ Stubborn | Training XP multiplier; **how fast style (§4.2) and habits (D32) change** |
| Loyal ↔ Mercenary | Poaching offers, gym switches, money disputes |

Changes from `02` §1.3: *Aggressive ↔ Patient* moves to fighting style (§4.2). *Composed ↔ Fragile* is dropped because the
Composure attribute already does that job; "Fragile" and "Ice in the veins" live on as a flaw and a gift (§4.3).

### 4.2 Fighting style: leanings that grow into traits

Four style **leanings**, each a hidden number from −100 to +100:

| Leaning | − end | + end | Pushed by (examples) |
|---|---|---|---|
| **Pace** | Patient | Aggressive | + "Push the pace" sparring, Pressure gameplan and calls · − Counter gameplan, Circle out, Stay safe |
| **Range** | Outside | Inside | + pocket boxing and clinch drills, Clinch calls · − range drills, Work the range calls |
| **Base** | Striker | Grappler | + wrestling/BJJ sessions, Takedown calls · − striking sessions, Get up calls |
| **Risk** | Safe | Wild | + going for finishes, subs off the back, spinning stuff · − Stay safe, coasting with a lead |

How a leaning moves:
- **Training:** each session's instruction gives a small push. "Push the pace" in every slot for a week ≈ +3.
- **Fights:** the gameplan and each accepted call push it. A Pressure fight with ~20 accepted Pressure calls ≈ +5 to +8.
- **Results:** a style that wins pushes harder than one that loses (the fighter believes in it).
- **Personality:** Coachable speeds it up, Stubborn slows it down; Ego only counts wins.
- **Age:** young fighters change fast; around 30 a style "sets" and moves much more slowly.

With those numbers, going from neutral to a named trait takes roughly **4–6 months of game time, or 3–4 fights**.

Every point of leaning nudges the AI's tendencies a little (`01` §7), so the change is gradual. Crossing **±60** earns a
**named trait** with an upside and a downside:

| Leaning | Trait at −60 | Trait at +60 |
|---|---|---|
| Pace | **Patient counter-puncher**: better counters, fewer wasted strikes · slow starter, loses close rounds on activity | **Natural aggressor**: higher output, better cage cutting, Pressure calls never ignored · burns more stamina, ignores Circle out / Stay safe more often, walks into counters |
| Range | **Range fighter**: bonus at long range, harder to catch kicks · weaker when pinned | **Phone-booth fighter**: bonus in pocket and clinch · eats more kicks on the way in |
| Base | **Sprawl-and-brawl**: TDD and get-ups bonus · reluctant to shoot | **Wrestle-first**: shoots more, chains attempts · telegraphs the level change more |
| Risk | **Fundamentalist**: fewer openings, fewer fouls · rarely finishes | **Finisher**: more KO/sub chances when the opponent's hurt · leaves openings, more foul risk |

Losing a trait: it fades only if the leaning falls back below **±40** (so it doesn't flicker on and off).
A fighter has at most one trait per leaning, so at most four style traits.

D32 habits stay as they are. Habits are narrow ("takedown after the opponent kicks"), style is broad. The same calls feed both.

### 4.3 Gifts and flaws (rolled at creation)

Each fighter rolls **0–2 gifts and 0–1 flaw**, weighted by frame and background. Some show at creation, and some are
**discovered** the first time they matter (you learn your fighter is a Bleeder after their first cut).

| Gifts | Flaws |
|---|---|
| Granite chin (higher Max chin) | Glass jaw (lower Max chin) |
| Heavy hands (higher Power ceiling, bonus KO chance) | Bleeder (cuts open more easily) *discovered* |
| Freak athlete (higher Speed and Strength ceilings) | Brittle hands (hand injuries from power shots) |
| Ice in the veins (Composure drops slower) | Fragile (Composure breaks faster) |
| Fast learner (training XP bonus) | Slow healer (longer injury layoffs) |
| Natural southpaw / Long limbs | Hard cut (weight cuts are riskier) *discovered* |

---

## 5. Decisions (Kyle, 2026-10-23)

| # | Question | Answer |
|---|---|---|
| D85 | Stat count | **Trim to 23** (§2.2). Explosiveness → Speed, Ground-and-pound → Top control + Power, Coachability → personality |
| D86 | Trait model | **Three layers**: personality / fighting style / gifts & flaws (§4) |
| D87 | Moves | **Yes**: Aggressive ↔ Patient becomes the Pace leaning; Composed ↔ Fragile axis dropped (Composure attribute + Fragile flaw / Ice in the veins gift) |
| D88 | Style leaning visibility | **Fuzzy hint** ("leaning aggressive") once past ±30; exact numbers only in the debug overlay |
| D89 | Losing style traits | **Yes**, below ±40 (buffer from the ±60 earn line), much slower after ~30 |
| D90 | Gifts & flaws visibility | **Mixed**: some shown at creation, some hidden until discovered |

## 6. Follow-up work
- Done with D85–D90: `00` decisions, `02` §1.3/§2, `data/enums/stats.json`, and the Double leg and Sprawl actions (Explosiveness → Speed).
- Done with #32: attributes, frame, stance, personality, style leanings and gifts/flaws are in the fighter profile format (`09` fighter@1).
- Engine: effective stats, the shared contest formula, timing and style leanings are in (§3.5). Still to come: takedown results (#15), rocked/knockdowns (#13), style trait effects, and leaning pushes from training and calls.
