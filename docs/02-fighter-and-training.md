# 02 — Fighter Creation, Attributes & Training

> Related decisions: D8, D13, D14, D23, D24, D34–D40, D125. Status: **design draft**; §3.5 is built.

---

## 1. Creation flow

```
Name / nickname / nationality / hometown
   └─► Childhood vignettes (D8/D83): ages ~8, ~12, ~15
        └─► Age ~16: "the gym walk-in" (D37/D83) → first gym choice
             └─► Teen amateur stage (`08-amateur-rules.md`) → pro debut possible at 18+
             └─► Starting attributes, traits, frame, relationships are set
                  └─► Amateur career begins
```

### 1.1 Vignettes
Each vignette is a short illustrated scene with **2–4 choices**. A choice affects:
- attribute modifiers (small: ±2–6 each),
- traits (D36): adds or strengthens one,
- **frame** (height, reach, build: feeds natural weight, D35),
- relationships (introduces persistent characters: a parent, a mentor, a friend who might become a training partner),
- **starting money** and gym access.

### 1.2 Background flavours (D34)

| Background | Strengths | Weaknesses | Story hook |
|---|---|---|---|
| Street kid | Chin, Heart, brawling | Discipline, defense | Old crew pulls you back |
| Wrestling family | Takedowns, Cardio, Top control | Striking | A parent's expectations |
| Traditional martial arts (karate/TKD) | Kicks, Footwork, distance | Grappling, clinch | An old sensei's pride |
| Jiu-jitsu prodigy | Subs, Guard | Striking, TDs | Competition rivals from the mats |
| Farm / labour kid | Strength, Durability | Technique, Speed | Family needs money |
| Muay Thai camp abroad | Clinch, Kicks, toughness | Wrestling | A Thai trainer contact |
| College football athlete | Speed (burst), Strength | Raw skills, cardio | Injury history |
| Judo / sambo household | Throws, leg locks | Boxing | Olympic dreams that didn't happen |
| Boxing gym kid | Hands, head movement | Kicks, ground | Old boxing coach feels betrayed |
| Late starter / privileged | Money, time, Fight IQ | Toughness, chin | Proving yourself |
| **Track star** | Cardio, Speed, footwork | Strength, power | Former coach and scholarship |
| **Bullied underdog** | Heart, composure growth, Coachable trait | Low starting stats | A bully from school shows up in the world |

Backgrounds aren't picked from a list. They **emerge** from vignette choices (a scene at age 8 might be "a
wrestling tournament with dad" vs "a karate class at the community centre" vs "getting jumped after school").

### 1.3 Traits (D36, D86–D90)
Three layers, detailed in `11-attributes-and-traits.md` §4:
1. **Personality**: vignettes set it, plus a small random roll; it drifts with career events.
2. **Fighting style**: four leanings (Pace, Range, Base, Risk) pushed by training, gameplans and calls; named traits at ±60.
3. **Gifts & flaws**: rolled at creation; some hidden until discovered.

| Personality axis | Gameplay effect |
|---|---|
| Ego ↔ Humble | Compliance with calls; habit absorption (only successful calls) |
| Discipline ↔ Party animal | Camp consistency, weight-cut success, life-event risks |
| Coachable/Adaptive ↔ Stubborn | Habit absorption (D32); training XP multiplier; how fast style changes |
| Loyal ↔ Mercenary | Reaction to poaching offers, switching gyms, money disputes |

---

## 2. Attributes (internally 0–100, shown as grades + tags, D24, D85)

What each attribute does in a fight: `11` §2.2.

| Group | Attributes |
|---|---|
| Physical | Strength, Speed, Cardio, Recovery, Durability, **Chin** (wears down over a career) |
| Striking | Boxing, Kicking, Clinch striking, Striking defense, Footwork, Power |
| Wrestling | Takedowns, Takedown defense, Clinch control, Scrambles |
| Grappling | Top control, Guard/bottom game, Submissions, Submission defense |
| Mental | Fight IQ, Composure, Heart |
| Hidden / derived | Frame, stance, potential ceiling, max chin, aging curve, injury proneness, **natural weight** |

**Example tags:** "Iron chin", "Elite wrestler", "Dangerous off the back", "Gasses late", "Calf-kick specialist", "Glass jaw".
Tags appear when an attribute crosses a threshold or is shown in fights.

### 2.1 Techniques (D6, D13)
- These are specific moves that unlock calls and AI actions (e.g. *Catch-kick single*, *D'arce*, *Calf kick*, *Spinning back fist*).
- Unlock sources: skill threshold + a coach who teaches it, or a background, or a sparring discovery.
- Each technique has a **proficiency** level (Learning → Competent → Signature). Signature moves get their own tag and commentary lines.

### 2.2 Weight & frame (D35)
- Frame (height/reach/build) is set by about age 17. Walk-around weight comes from frame + strength training + lifestyle.
- The division is chosen at amateur debut. The game recommends one but doesn't force it. You can move later (D44).
- Weight cut (D23): see §4.

---

## 3. Training

### 3.1 The weekly planner (borrowed from Corner King, D26)
- Each week has **~10–12 session slots** (morning/afternoon/evening × 6 days, with Sunday rest).
- Drag sessions into slots: technique drill, strength & conditioning, sparring, film study, recovery, rest.
- Each week you **play 1–3 sessions** as minigames (your choice). The rest auto-resolve using your averages.
  Played sessions give more XP, and auto-resolved ones give ~60–70% (D14).
- **Fatigue**: every session adds fatigue, and rest removes it. Overtraining → injury risk, worse minigame performance,
  and you "enter the ring broken".

### 3.2 Minigames (D38), about 1 minute each

| Minigame | Mechanic | Trains |
|---|---|---|
| **Mitt work** | Rhythm game: the coach calls combos and you hit them on the beat | Boxing, Speed |
| **Heavy bag** | Power-timing meter with combo chaining | Power, Strength |
| **Thai pads** | Aim + timing; the pad holder feeds kicks/knees/elbows | Kicking, Clinch striking |
| **Wrestling chain** | Directional input sequences under time pressure (shot → finish → chain) | Takedowns, Scrambles |
| **Sprawl reflex** | React to incoming shots with feints mixed in | Takedown defense, Speed |
| **Rolling puzzle** | Turn-based positional puzzle: pick transitions, chess-like | Top control, Guard, Submissions |
| **Roadwork** | Pace management: stay in the target zone; going too fast gasses you out | Cardio, Recovery |
| **Film study** | Watch a short sim clip and spot the tell | Fight IQ; reveals opponent tells (D11) |
| **Hard sparring** | Short playable fight using the real fight engine. Injury risk, big XP | Composure, everything; habit forming |
| **Meditation** | Focus/breathing: keep a marker centred against distractions | Composure, Heart |

Design rules for every minigame:
- Its score must also be **simulatable** (for auto-train).
- Difficulty scales with the fighter's level, so it stays interesting at A grades.
- A visual + audio identity per gym (a boxing gym feels different from a Thai camp).

### 3.3 Diminishing returns (D13)
- Each attribute has a **soft cap per camp**: XP beyond it is reduced.
- Higher attributes need more XP. Potential ceiling + age limit growth.
- Variety bonus: training different skills in a week gives a small XP bonus, to discourage grinding one stat.

### 3.4 Sparring & training partners (D39)
- Gyms have a roster of persistent partners with their own stats and careers.
- Partners can turn pro, get signed by your organisation, and become rivals (D22).
- Hard sparring with a better partner = more XP + more injury risk.

### 3.5 The camp in the sim (D125, #54)

The first working piece of training, as pure logic in `sim/world/` (D100): `TrainingCamp` (`sim/world/training_camp.gd`)
runs week plans of sessions and turns them into attribute points, fatigue, style pushes, chin wear and camp injuries. It is
seeded, so the same fighter, plans and seed always train the same way. Nothing here touches the fight engine, which is why it
could be built while the Phase 1 playtest runs. The planner screen, the minigames and save/load come later.

**Try it:** `godot --headless --script res://tools/camp.gd -- --fighter=wrestler --plan=wrestler --weeks=8 --fights=100`
prints each week, the injuries, the stats that moved (with grades), the style pushes and how fresh the fighter is for the
fight, then plays 100 fights against the Kicker before and after the camp. CI prints two camps in every run's summary
("Camp snapshot"). Options: `tools/README.md`.

**A week** is Monday to Saturday, a morning and an evening slot each (12 slots; Sunday is always off). That is the "~10–12
sessions" of §3.1 with two slots a day, not three. A week plan (`data/week_plans/`, `docs/09` week_plan@1) fills every slot
with a session, and may name an **instruction**: a gameplan (`data/gameplans/`) whose style leanings every session pushes a
little. The presets: Balanced, Striker, Push the pace (Striker with the Pressure instruction), Wrestler (with Wrestle-heavy),
All out (12 hard sessions, no rest: the overtraining example) and Taper (fight week).

**Sessions** (`data/sessions/`, `docs/09` session@1) say what they train (shares of their XP per attribute), their XP, the
fatigue they add (or take away), their injury risk, any style push, any chin wear and the minigame that will play them:

| Session | Trains | XP | Fatigue | Injury risk | Style push |
|---|---|---|---|---|---|
| Boxing drills (mitt work) | Boxing 50%, Footwork 25%, Striking defense 25% | 10 | 8 | 0.1% | Base −0.1 |
| Heavy bag | Power 50%, Boxing 30%, Strength 20% | 10 | 10 | 0.1% | Base −0.1 |
| Thai pads | Kicking 50%, Clinch striking 30%, Power 20% | 10 | 10 | 0.1% | Base −0.1 |
| Wrestling drills (wrestling chain) | Takedowns 50%, Scrambles 30%, Clinch control 20% | 10 | 12 | 0.15% | Base +0.1 |
| Sprawl drills (sprawl reflex) | Takedown defense 60%, Scrambles 20%, Speed 20% | 10 | 10 | 0.1% | Base −0.05 |
| Clinch work | Clinch control 50%, Clinch striking 30%, Strength 20% | 10 | 10 | 0.1% | Range +0.1 |
| Rolling (rolling puzzle) | Top control 30%, Guard 30%, Submissions 20%, Submission defense 20% | 10 | 10 | 0.1% | Base +0.1 |
| Strength & conditioning | Strength 50%, Speed 25%, Durability 25% | 10 | 12 | 0.1% | |
| Roadwork | Cardio 70%, Recovery 30% | 10 | 10 | 0.05% | |
| Film study | Fight IQ | 8 | 2 | | |
| Meditation | Composure 60%, Heart 40% | 8 | −4 | | |
| Light sparring | Striking defense 25%, Composure 20%, Boxing 15%, Footwork 15%, Fight IQ 15%, Kicking 10% | 12 | 10 | 0.15% | |
| Hard sparring | Composure 30%, Heart 20%, Striking defense 20%, Fight IQ 20%, Durability 10% | 20 | 18 | 0.6% | Risk +0.05; Chin −0.05 |
| Recovery (stretching, ice, massage) | | | −15 | | |
| Rest | | | −20 | | |

**Points from XP** (§3.3, D13). Each session's XP is split by its shares, and one point of an attribute costs
**10 × e^(attribute / 25)** XP: about 33 at 30, 74 at 50 and 164 at 70, so every 25 points costs e (≈2.7) times as much. The
XP is then multiplied by:
- **Session quality**: 1.0 when it auto-resolves; a session played as a minigame scores 0.8 (bad) to 1.5 (great). Auto is
  the baseline, never a gate (A5), and about two thirds of a great session (D14).
- **Age**: × 1.2 up to 23, × 1.0 to 29, × 0.8 to 33, × 0.6 after.
- **Coachable** (`11` §4.1): × (1 + Coachable / 400), so × 1.25 at +100 and × 0.75 at Stubborn −100. **Fast learner** × 1.15.
- **Fatigue**: full up to 40, then down in a line to × 0.5 at 100.
- **Variety**: × 1.1 for the whole week when its plan trains attributes from at least 3 of the 5 groups (§2).

Then two brakes. **Potential** (`11` §2.3; `potential` in the fighter file, 75 if it has none): from 10 points under it,
a point costs × e^(points past that / 8) more, so × 3.5 at the potential itself and × 12 ten points past it. Freak athlete
raises the ceiling for Speed and Strength by 10, Heavy hands for Power. **The soft cap per camp**: once an attribute has
gained 3 points in one camp, the rest of that camp's points for it count half.

What that comes to: a 17-year-old with 30 in their wrestling stats gains about 3–4 Takedowns in an 8-week wrestling camp;
the Wrestler (70 Takedowns, 25 years old, potential 75) about 1. Fights read whole points (`FighterState` rounds down), so
the camp keeps fractions and a gain shows in fights once it crosses a whole number.

**Fatigue** (0–100, §3.1). A session adds its fatigue × (1.25 − Recovery / 200), so × 1 at Recovery 50; rest and recovery
take theirs off. Every night keeps 60% of the fatigue and Sunday keeps 40% of what's left. A Balanced week peaks around 50;
All out peaks around 65 and the fighter learns about a tenth less. A Taper week brings the fighter in fresh.

**Camp injuries** (`03` §5). Each session rolls its injury risk × (1 + (fatigue / 30)²) × (1.5 − Durability / 100): at
fatigue 60 that is 5 times the fresh risk. An injury keeps the fighter out 2–10 days (Slow healer × 1.5), and every slot
until then becomes rest. About a quarter of sensible 8-week camps have one minor knock; All out gets one in about two camps
in three. **Party animals skip sessions**: a chance of −Discipline / 400 a session (25% at −100); a disciplined fighter
never does. A skipped session gives nothing and costs nothing.

**Style** (`11` §4.2). Each session's style push and the week's instruction (the gameplan's leanings / 160 a session, so a
week of Push the pace is about +3 Pace) move the fighter's leanings through `StyleLeanings`, which earns and fades the named
traits. Pushes are × (1 + Coachable / 200), and × 0.4 from age 30 (a style sets). **Hard sparring wears the Chin** 0.05 a
session (`03` §5); nothing trains it back up.

**Not yet** (they change how fights feel, so they wait for the playtest): fatigue and injuries carried into the fight
("enter the ring broken"), the minigames (`played` scores are already taken), rule drilling in the middle of a camp (A6), camp
phases, the planner screen, scouting and the weight cut, and saving a career (`04` §11).

**What to change:** every number above is a named constant at the top of `sim/world/training_camp.gd` (`XP_PER_POINT`,
`XP_CURVE`, `CEILING_SOFT`, `CEILING_SCALE`, `AGE_LEARNING`, `CAMP_SOFT_CAP`, `NIGHT_KEEPS`, `SUNDAY_KEEPS`, `FATIGUE_FREE`,
`INJURY_FATIGUE`, `SKIP_PER_PARTY_POINT`, `INSTRUCTION_DIVISOR` …); sessions and plans are their JSON files. Fights don't
change, so the golden fights don't need re-pinning. Check a change with `tools/camp.gd` and
`tests/sim/world/test_training_camp.gd`, then update this section and D125.

---

## 4. Fight camp & fight week

- **Camp** = the weeks between accepting a fight and fight night (usually 4–8; short notice = 1–2).
- **Scouting**: pay or assign film study to reveal opponent tendencies and tells.
- **Gameplan**: set during camp; affects which drills give bonus XP ("prep the takedown defense").
- **Fight week / weight cut (D23)**: a 5-day planning mini-system:
  - Choose water loading, sodium, sauna sessions, and food per day.
  - Hidden risk: too aggressive → you make weight but start the fight with stamina/chin penalties. Too soft → miss weight.
  - Missing weight: fine (% of purse), reputation loss, and the opponent might refuse the fight.
  - Rehydration after weigh-ins gives a size advantage in the fight.

---

## 5. Gyms & coaches (D40)

- **Gyms** have a specialty mix, equipment level, partner roster, culture (family vibe, hard-sparring, party gym)
  and monthly fees.
- **Coaches** (specialists: striking, wrestling, BJJ, S&C, nutritionist, cutman) have personalities, technique catalogues,
  and a relationship with your fighter *and* with you (the head coach).
- Switching gyms has costs: relationships, a short adaptation period, and possibly drama with the old gym.
- Your head coach (D15) levels up in: *Clarity* (call delay), *Reading* (spotting tells), *Corner work* (cutman/time
  budget), *Motivation*, and *Network* (better gyms/coaches/offers).

---

## 6. Training trips (D64: "Bangkok ready")

| Destination | Specialty | Unique techniques / minigame variants | Trade-offs |
|---|---|---|---|
| Bangkok, Thailand | Muay Thai | Thai plum, elbows, teep; harder Thai pads | Cost, heat fatigue, time away from family |
| Dagestan, Russia | Wrestling / sambo | Chain wrestling, mat returns; brutal wrestling chain | Very high fatigue, injury risk |
| Rio de Janeiro, Brazil | BJJ | Advanced guard and back takes; rolling puzzle "black belt" tier | Weaker striking work |
| Amsterdam, Netherlands | Dutch kickboxing | Low kicks, punch-kick combos | — |
| US altitude camp | Strength & conditioning | Cardio ceiling boost | Expensive |

- A trip takes 2–6 weeks, costs money, and needs an invitation or contact (from your network, background or a coach).
- Trips create **story moments** and possible persistent contacts (a Thai trainer who'll corner you later).

## 7. Resolved & open questions
- T2 → **D63**: the head coach is customisable (name, look, background, starting specialty).
- T3 → **D65**: family/life events affect fatigue, motivation and focus.
- T4 → **D64**: training trips are in (see §6).
- T1 → **D70**: the player picks which sessions to play (with "key session" hints).
- T5 → **D71**: head coach starting specialty: Striking / Wrestling / BJJ / Motivator / Tactician.

## 8. Merged from the Foundation doc (see `05`)
- **Minigames are bonuses, not gates (A5):** every planned session gives baseline progress. Playing it as a minigame
  raises *session quality* (bad play still ≥ baseline × 0.8; great play up to ~1.5×). Same balance as D14, friendlier framing.
- **Camp phases (A6):** *Early* (development, S&C) → *Middle* (matchup drills, sparring, **rule drilling**: each session adds reps to one drilled rule (D82), raising its reliability) →
  *Late* (taper, recovery, weight cut) → *Post-fight* (medical, review, return to training).
