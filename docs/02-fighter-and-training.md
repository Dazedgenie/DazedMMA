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
could be built while the Phase 1 playtest runs. The planner screen is §3.6 (D134); the minigames and save/load come later.

**Try it:** `godot --headless --script res://tools/camp.gd -- --fighter=wrestler --plan=wrestler --weeks=8 --fights=100`
prints each week, the injuries, the stats that moved (with grades), the style pushes and how fresh the fighter is for the
fight, then plays 100 fights against the Kicker before and after the camp. CI prints two camps in every run's summary
("Camp snapshot"). Options: `tools/README.md`.

**A week** is Monday to Saturday, a morning and an evening slot each (12 slots; Sunday is always off). That is the "~10–12
sessions" of §3.1 with two slots a day, not three. A week plan (`data/week_plans/`, `docs/09` week_plan@1) fills every slot
with a session, and may name an **instruction**: a gameplan (`data/gameplans/`) whose style leanings every session pushes a
little. The presets: Balanced, Striker, Push the pace (Striker with the Pressure instruction), Wrestler (with Wrestle-heavy),
All out (12 hard sessions, no rest: the overtraining example) and Taper (fight week), plus the focus weeks of §3.6 (Speed,
Cardio, Power, Jiu-jitsu and Defense focus, D134). Each says in one line (`about`) what it's for.

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
| Sprints & plyometrics (D134) | Speed 60%, Strength 20%, Cardio 20% | 10 | 12 | 0.15% | |
| Roadwork | Cardio 70%, Recovery 30% | 10 | 10 | 0.05% | |
| Film study | Fight IQ | 8 | 2 | | |
| Meditation | Composure 60%, Heart 40% | 8 | −4 | | |
| Light sparring | Striking defense 25%, Composure 20%, Boxing 15%, Footwork 15%, Fight IQ 15%, Kicking 10% | 12 | 10 | 0.15% | |
| Hard sparring | Composure 30%, Heart 20%, Striking defense 20%, Fight IQ 20%, Durability 10% | 20 | 18 | 0.6% | Risk +0.05; Chin −0.05 |
| Recovery (stretching, ice, massage) | | | −15 | | |
| Rest | | | −20 | | |
| Rehab (physio, easy technique) (D135) | | | −8 | | heals a day faster |

**Points from XP** (§3.3, D13). Each session's XP is split by its shares, and one point of an attribute costs
**4 × e^(attribute / 25)** XP: about 13 at 30, 30 at 50 and 66 at 70, so every 25 points costs e (≈2.7) times as much
(it was 10 × until D136 sped camps up so a top prospect reaches the top level by 28–29, §3.8). The
XP is then multiplied by:
- **Session quality**: 1.0 when it auto-resolves; a session played as a minigame scores 0.8 (bad) to 1.5 (great). Auto is
  the baseline, never a gate (A5), and about two thirds of a great session (D14).
- **Age**: × 1.2 up to 23, × 1.0 to 29, × 0.8 to 33, × 0.6 after. The body's stats (the ones that age, §3.8) have their own
  curve: × 1.2 up to 23, × 1.0 to 27, × 0.6 to 30, × 0.3 to 34, × 0.1 after.
- **Coachable** (`11` §4.1): × (1 + Coachable / 400), so × 1.25 at +100 and × 0.75 at Stubborn −100. **Fast learner** × 1.15.
- **Fatigue**: full up to 40, then down in a line to × 0.5 at 100.
- **Variety**: × 1.1 for the whole week when its plan trains attributes from at least 3 of the 5 groups (§2).

Then two brakes. **Potential** (`11` §2.3; `potential` in the fighter file, 75 if it has none): from 10 points under it,
a point costs × e^(points past that / 8) more, so × 3.5 at the potential itself and × 12 ten points past it. Freak athlete
raises the ceiling for Speed and Strength by 10, Heavy hands for Power. **The soft cap per camp**: once an attribute has
gained 3 points in one camp, the rest of that camp's points for it count half.

What that comes to: a teenager with 30 in their wrestling stats gains about 6 points of Takedowns in an 8-week wrestling
camp; the Wrestler at 19 with potential 80 (CI's camp snapshot) gains about 2 points in each main stat and about 4 Fight IQ
from the film study. The camp keeps fractions of a point; fights read each stat to the nearest whole point (`FighterState`), so
a gain shows in fights once it rounds up. Every fighter in `data/fighters/` has whole-number stats, so that changes no fight.

Each session that can hurt says where (`injury_area`, D135): sparring the head; boxing drills, the bag, wrestling, clinch
work, rolling and the weights the body; Thai pads, sprawls, roadwork and sprints the legs. Film study, meditation, rehab,
recovery and rest are **light** (`light`): they still go ahead while the fighter is hurt.

**Fatigue** (0–100, §3.1). A session adds its fatigue × (1.25 − Recovery / 200), so × 1 at Recovery 50; rest and recovery
take theirs off. Every night keeps 60% of the fatigue and Sunday keeps 40% of what's left. A Balanced or Wrestler week peaks around 53;
All out peaks around 65, where XP is × 0.8, and over 8 weeks it costs about 1.5 Chin from the hard sparring. A Taper week
brings the fighter in fresh.

**Camp injuries** (`03` §5). Each session rolls its injury risk × (1 + (fatigue / 30)²) × (1.5 − Durability / 100): at
fatigue 60 that is 5 times the fresh risk. An injury keeps the fighter out 2–10 days (Slow healer × 1.5), and until then every slot
becomes rest except the light sessions, which go ahead (Kyle: "you should also be able to train light", D135); each rehab
session heals a day on top. About a quarter of sensible 8-week camps have one minor knock; All out gets one in about two camps
in three. **Party animals skip sessions**: a chance of −Discipline / 400 a session (25% at −100); a disciplined fighter
never does. A skipped session gives nothing and costs nothing.

**Style** (`11` §4.2). Each session's style push and the week's instruction (the gameplan's strongest leaning moves 0.25 a
session and its others in proportion, so a week of Push the pace is about +3 Pace and +2 Range) move the fighter's leanings through `StyleLeanings`, which earns and fades the named
traits. Pushes are × (1 + Coachable / 200), and × 0.4 from age 30 (a style sets). **Hard sparring wears the Chin** 0.05 a
session (`03` §5); nothing trains it back up.

**Not yet:** the minigames other than mitt work (§3.9; `played` scores are already taken), rule drilling in the middle of a camp (A6), camp
phases, scouting and the weight cut, and saving a career (`04` §11).

**What to change:** every number above is a named constant at the top of `sim/world/training_camp.gd` (`XP_PER_POINT`,
`XP_CURVE`, `CEILING_SOFT`, `CEILING_SCALE`, `AGE_LEARNING`, `CAMP_SOFT_CAP`, `NIGHT_KEEPS`, `SUNDAY_KEEPS`, `FATIGUE_FREE`,
`INJURY_FATIGUE`, `SKIP_PER_PARTY_POINT`, `INSTRUCTION_PUSH` …); sessions and plans are their JSON files. Fights don't
change, so the golden fights don't need re-pinning (unless a fighter file gets fractional stats). Check a change with `tools/camp.gd` and
`tests/sim/world/test_training_camp.gd`, then update this section and D125.

### 3.6 The planner screen (D134)

The camp is now on screen. On the fight setup (`06` §6.1), **Training camp first** opens the planner for the red corner's
fighter (`ui/camp_planner.gd`); its **Fight!** button starts the same fight with the fighter as the camp left them. It is
the first look at §3.1's planner. It started plain (dropdowns); since D170 it is the camp week HUD of §3.10: tiles you
click, not drag and drop yet. The first minigame, mitt work, plays from it (§3.9).

**Try it:** run the game, pick a fight, press *Training camp first*, pick a focus week, change a slot or two, watch the
forecast, run the weeks, then *Fight!*.

**The camp.** Before week 1 you set its length (1–8 weeks, 6 by default: §4's 4–8, or 1–2 on short notice), and the
fighter's age and potential. The test fighters have neither in their files, so they start at 25 and 75 (`TrainingCamp`'s
defaults); the boxes are there to feel how a 19-year-old trains next to a 31-year-old. They lock once a week has run.

**A week** starts from a week plan in *Start from*, the "focus on speed, focus on this" defaults Kyle asked for: Balanced,
Striker, Push the pace, Wrestler, All out, Taper, and five focus weeks made for the planner:

| Focus week | Trains most (a fighter with flat stats) | Peak fatigue | Injury chance in the week |
|---|---|---|---|
| Speed focus | Speed, then Boxing and Takedown defense (three days of the new *Sprints & plyometrics*) | ~45 | ~2% |
| Cardio focus | Cardio, then Recovery (roadwork every day) | ~45 | ~3% |
| Power focus | Power, then Boxing and Strength (the heavy bag three times) | ~45 | ~2% |
| Jiu-jitsu focus | Top control and Guard, then Submissions and Submission defense (rolling five times) | ~37 | ~2% |
| Defense focus | Takedown defense (sprawls three times), then Fight IQ, Composure and Striking defense | ~42 | ~2% |

Every slot (Monday to Saturday, morning and evening) is a tile that opens a list of all the sessions (§3.10), and the *Instruction* picks a
gameplan to push the style with (§3.5). Change anything and the week becomes a *Custom week*: you can build one from
scratch the same way. The week stays on screen after it runs, so the next week starts from it.

**The forecast** (`TrainingCamp.forecast`) is what the week would do if nothing goes wrong: it runs the week on a copy of
the camp that rolls no dice (everyone turns up, nobody gets hurt) and shows the fatigue (start, peak, Sunday night), when
being tired starts costing XP, the chance of at least one injury that week, the sessions a party animal will probably skip,
whether the week gets the variety bonus, the Chin wear, the five biggest gains and the style pushes. A forecast never
changes the camp or its dice: the camp trains the same with or without one. The right-hand list has every stat with its
grade, what the camp has done to it so far and what this week adds.

**Running it.** *Run week N* runs the week on screen; *Run every week left like this one* runs it to the end of the camp.
The log says what each week did: sessions done, skipped and missed hurt, the fatigue peak, the biggest gains and any
injury. *Start the camp again* goes back to week 1 with the fighter as they came in.

**Into the fight.** *Fight!* (after the last week) starts the setup's fight with the trained fighter: id `<fighter>_camp`,
the stats as the camp left them (fights read the nearest whole point) and the new style. The fight's saved record keeps
the trained fighter whole and what the camp was (`09` fight_record@1), so it still replays. How tired or hurt the camp
sends them in is §3.7. Next: ageing and the prime (a perfect 18-year-old peaks around 28–29, physical stats fall off
after, skills and Fight IQ keep growing).

**What to change:** the camp length (`WEEKS_MIN`, `WEEKS_MAX`, `WEEKS_DEFAULT`) and the week it opens on (`START_PLAN`) at
the top of `ui/camp_planner.gd`; the focus weeks are `data/week_plans/` files (any new file shows up in *Start from*) and
the new session is `data/sessions/sprints.json`. Tests: `tests/ui/test_camp_planner.gd`, the forecast and focus weeks in
`tests/sim/world/test_training_camp.gd`, and the camp-to-fight path in `tests/game/test_main_scene.gd`. Fights don't
change (no golden re-pin). Then update this section and D134.

### 3.7 Fight night: the camp goes into the fight (D135)

What the camp leaves the fighter with reaches the fight (Kyle: fatigue and injuries "should absolutely carry into the fight.
If your fighter's sparring the day before and they get hurt, they should start the fight, you know, hurt a little bit").
`TrainingCamp.fight_night()` reads it after the last week, the planner shows it in place of the forecast, and
`TrainingCamp.fight_profile()` writes it into the fighter's profile as `condition` (`09` fighter@1), which
`FighterState.start_condition` applies when the fight starts.

**Fight week.** The camp's last week is fight week: the fight is on its Saturday evening, so that slot is the fight (the
planner greys it out) and Saturday morning is the last session, with no night's sleep or Sunday after it. So what happens
late in fight week counts: sparring hard on Friday comes into the fight tired, and a knock then is still healing.
(`run_plan`'s `fight_week`; `run_camp(plans, true)` and `tools/camp.gd` end the camp the same way.)

**A smaller gas tank.** Fight-night fatigue shrinks the tank for the whole fight: full up to fatigue 10, then 0.5% less a
point, so fatigue 30 leaves 90% of it and 60 leaves 75% (the numbers Kyle agreed), never under 50%. The fighter starts
with that smaller tank full, so they aren't tired at the bell; they just gas sooner. A Taper fight week brings fatigue
under 10; an All out one ends around 52 (79% of the tank), a Wrestler week around 42 (84%).

**Starting hurt.** An injury still healing on fight night starts the fight 3% hurt in its area for every day it still
needs (3 days → 9%), as the fight's own damage reads it (`11` §3.5): the head means a lower health bar and slower hands and
reads, the body a smaller tank, the legs slower feet and weaker kicks. Simple areas for now; named injuries (a hurt hand
that weakens punches, a knee) come later.

**Training light.** While hurt, the light sessions still go ahead (film study, meditation, rehab, recovery, rest) and the
rest become rest, so a hurt week isn't wasted. Rehab heals a day on top of the day each night heals, so a fighter hurt
late in camp can still get fit or less hurt for the fight.

**The doctor.** More than 7 days still to heal and the doctor won't clear the fighter: the fight is off. 7 or fewer and
it's the player's call: fight hurt, or pull out. Later there may be a way to try to hide an injury from the doctor.

**Pulling out** (on fight night, any time) calls the fight off. It costs no money; the penalty is the wasted camp (Kyle),
and later perhaps some reputation once there is reputation.

**Fighting hurt can make it worse:** a chance of 5% + 1% a day still to heal (3 days → 8%) that it gets worse, adding 7–28
days out after the fight. The result screen says whether the injury held up (`TrainingCamp.after_fight`, rolled from the
fight's seed so the same fight always says the same). With no career yet, those days out go nowhere; they're there for the
career calendar.

**Not yet:** the opponent's own camp (they always come in fresh for now; Kyle wants a hidden camp later, with scouting
hints), hiding an injury, named injuries, and reputation for pulling out.

**What to change:** `TANK_FREE_FATIGUE`, `TANK_PER_FATIGUE`, `TANK_FLOOR`, `HURT_PER_DAY`, `DOCTOR_MAX_DAYS`,
`WORSEN_BASE`, `WORSEN_PER_DAY`, `WORSEN_DAYS_MIN`, `WORSEN_DAYS_MAX` at the top of `sim/world/training_camp.gd`; where each
session hurts, whether it's light and rehab's `heals` in `data/sessions/`; what a hurt area does in the fight in
`sim/fight/fighter_state.gd` (`HURT_SCALE`, `HEAD_HURT_STATS`, `LEG_HURT_STATS`, `MAX_BODY_DRAIN`). Tests: fight night in
`tests/sim/world/test_training_camp.gd`, the starting condition in `tests/sim/fight/test_fighter_state.gd`, the planner's
fight night in `tests/ui/test_camp_planner.gd`, the result line in `tests/game/test_main_scene.gd`. A fighter without a
`condition` fights exactly as before (the golden fights don't change). Then update this section and D135.

### 3.8 Ageing and the prime (D136)

Fighters now get older a week at a time, and the body has a prime (Kyle: a perfect 18-year-old who trains right and wins
everything should peak "maybe 28, 29"; after it "a drop off after your physical decline", while "skills and fight IQ would
continue to increase"). It matches what fights show: in 8,332 UFC bouts (AgentMMA's win rate by age) fighters win 57.6% of the time at 24 or under,
52.2% at 28–30, 48.0% at 31–33 and 42.7% at 34–36, and master athletes lose about 7–14% of their aerobic and anaerobic power
a decade.

**Getting older** (`sim/world/ageing.gd`). Every week the camp runs makes the fighter a week older (`TrainingCamp.age_years`;
the fight gets the new age). From 30 the body slows (the numbers Kyle agreed):
- **Speed, Cardio, Recovery and Chin** lose 1% of what they are a year from 30, and 2% a year from 34.
- **Strength, Power and Durability** go later and slower: 0.5% a year from 33, 1% from 36.
- **Skills and the mental stats never age.** A 34-year-old still learns them (× 0.6, §3.5).

**The body stops answering training.** The stats that age have their own learning curve (§3.5): full to 27, then × 0.6 to
30, × 0.3 to 34 and × 0.1 after. So training builds the body until about 29, it holds at 30, and after that training only
slows the decline.

**Between camps** (Kyle: training between camps "should be optional for the player to decide"). Two new week plans for
the weeks between fights: *Between fights* (lighter work, more rest) and *Time off* (rest all week). Training between camps
is a bonus on top: a fighter who rests between camps still improves, just slower.

**Hidden potential.** A fighter's `potential` stays hidden; scouts see a range 14 points wide with the true number somewhere
inside it, not always the middle, and always the same for the same fighter (`Ageing.scouted_range`). The planner's title
shows it ("potential 78–92 (scouted)"); its *True potential* box is the real number, there for testing.

**The career curve** (`tools/career_curve.gd`). There's no career calendar yet, so this tool runs a fighter through years
of camps and prints their stat groups by age (also `build/career/curve.csv`). A top prospect (every stat 45 at 18,
potential 90, three 8-week camps a year with a taper, training between camps) comes out like this:

| Age | Physical | Striking | Wrestling | Grappling | Mental |
|---|---|---|---|---|---|
| 18 | 45 | 45 | 45 | 45 | 45 |
| 22 | 67 | 71 | 69 | 71 | 74 |
| 25 | 72 | 78 | 76 | 80 | 81 |
| 29 | 76 | 84 | 80 | 85 | 85 |
| 30 | 77 (the peak) | 84 | 81 | 86 | 86 |
| 34 | 75 | 87 | 83 | 88 | 88 |
| 38 | 71 | 87 | 84 | 90 | 90 |

Resting between camps instead leaves the same fighter about 8 points lower at 29. The skills keep creeping up into the
late 30s, but slowly and toward the potential, while the body falls away: the old fighter knows more but is slower and
gasses sooner.

    godot --headless --script res://tools/career_curve.gd -- --fighter=wrestler --start=45 --age=18 --to=38 --potential=90
    godot --headless --script res://tools/career_curve.gd -- --between=off --plans=striker,balanced,speed,power --fighter=boxer

**Not yet:** the career calendar itself (the tool stands in for it), a "skip a year" button, scouting that gets sharper
(better scouts or more fights watched narrow the range; Kyle: yes, later), gifts or flaws that move the
prime (a late bloomer, an early decline), damage over a career wearing the Chin faster, and retirement.

**What to change:** `DECLINE` (which stats age, from when, how fast) and the scouting width `SCOUT_HALF_WIDTH` and
`SCOUT_OFFSET` in `sim/world/ageing.gd`; `BODY_AGE_LEARNING` and `XP_PER_POINT` in `sim/world/training_camp.gd`; the
between-camp weeks in `data/week_plans/between_fights.json` and `time_off.json`. Check a change with
`tools/career_curve.gd` and `tests/sim/world/test_ageing.gd`, then update this section and D136. Fights don't change (the
golden fights don't need re-pinning).

### 3.9 Mitt work, the first minigame (D137)

Kyle picked mitt work as the first minigame. It's §3.2's rhythm game: the coach calls a combination and you hit it on
the beat. It plays a **Boxing drills** session, and how well it went is that session's quality (§3.5): every key hit
perfectly is × 1.5, nothing hit still × 0.8 (A5), and skipping it is the auto × 1.0. The logic is `sim/world/mitt_work.gd`
(`MittWork`, pure and seeded); the screen is `ui/mitt_work_screen.gd`.

**Try it:** in the planner pick *Striker* (Boxing drills on Monday and Friday mornings), tick **Play** beside one,
press *Run week 1*, then Space to start.

**Playing it.** Four beats of count-in, then the coach shouts a call in boxing's numbers and you hit it one key a beat,
starting the beat after the shout, as each note slides in to the hit line. Keys: **1** jab, **2** cross, **3** lead hook,
**4** rear hook, **5** lead uppercut, **6** rear uppercut (number pad too), **←** (or A) slip and **↓** (or S) roll when
the coach swings the mitt back. Two beats' rest, then the next call, for about a minute. The lead mitt lights up for odd
numbers and the rear for even ones; a click marks every beat and a smack every hit (both made in code: no audio files
yet).

**Judging.** Within 0.06 s of the beat is perfect, within 0.14 s good (worth 0.6); later or never is a miss, and the wrong
key misses that note. A press with nothing to hit is a stray and takes 0.25 off. Accuracy is that total over the notes, and
the quality runs in a line from 0.8 at 0% to 1.5 at 100%: hitting about 80% well is × 1.35.

**Harder as he gets better** (§3.2). The tempo runs from 84 beats a minute at Boxing 20 to 132 at Boxing 90, and the
calls get longer: from Boxing 40 three-punch calls and the first slip and roll, from 60 four, from 80 five or six with
defence in the middle. The newest calls come up twice as often. **Tired hands:** from fatigue 40 at that point of the week
(the forecast's fatigue before the session) the timing windows shrink in a line to 60% at fatigue 100.

**In the planner.** A *Play* box sits on every session's tile with a minigame built so far (only Boxing drills), up to 3 a
week (§3.1). *Run week* plays the ticked ones first, in order, then runs the week with their scores; the week's log says
"played Boxing drills × 1.35". *Run every week left* doesn't play them. If the fighter is hurt by then, the session
becomes rest and the round doesn't count, as any session would.

What it trains is the Boxing drills session's own split (Boxing 50%, Footwork 25%, Striking defense 25%), not §3.2's
"Boxing, Speed": the session data is the source.

**Not yet:** the other nine minigames, a gym's own look and sound (§3.2), playing a session during the week as it comes
round instead of before, and the onboarding's first week (`07`).

**What to change:** the calls (`TIERS`), the tempo (`TEMPO_MIN`, `TEMPO_MAX`, `LEVEL_LOW`, `LEVEL_HIGH`), the round
(`ROUND_SECONDS`, `COUNT_IN_BEATS`, `REST_BEATS`), the timing (`PERFECT_WINDOW`, `GOOD_WINDOW`, `TIRED_FROM`,
`TIRED_FLOOR`) and the scoring (`GOOD_CREDIT`, `STRAY_COST`) at the top of `sim/world/mitt_work.gd`; the keys, colours and
sounds in `ui/mitt_work_screen.gd`; how many a week (`PLAY_MAX`) and which minigames can be played (`PLAYABLE`) in
`ui/camp_planner.gd`. Tests: `tests/sim/world/test_mitt_work.gd`, `tests/ui/test_mitt_work_screen.gd` and the planner's
in `tests/ui/test_camp_planner.gd`. Fights don't change. Then update this section and D137.

### 3.10 The camp week HUD (D170)

Kyle (2026-10-29): "Why don't we start on some visual upgrades. Maybe a visual hud for the week and features outside of the
cage". Three looks were mocked up with a real forecast week; he picked **A, the corner board**: the fight screen's dark
panels and red corner carried over, so the whole game looks like one thing. The planner (§3.6) is its first screen; the
same look goes to fight night, then the fight setup as a tale of the tape, then the result screen (Kyle's order).

**Try it:** *Training camp first* on the fight setup, pick *Speed focus*, click a tile and pick another session, tick
*Play* on a Boxing drills tile, then run the weeks to fight night.

**The screen**, top to bottom:

- **Top bar.** The fighter's name and age (scouted potential under it), the camp as a row of weeks ending in **FIGHT**
  (`ui/camp_countdown.gd`): weeks run are filled with their week plan's name and a red dot if he got hurt that week
  (hover one for what it did), the week on screen is outlined in red, and FIGHT turns grey to OFF if he's pulled out or
  the doctor says no. On the right, the days to the fight from the Monday of the week on screen (the fight is the last
  week's Saturday evening, D135: 5 × 7 + 5 = 40 days in a 6-week camp), then *Fight week* and *Fight night*, with who
  it's against under it.
- **Condition card** (left). The body figure from the fight screen (D150) shows a healing injury where it is, as fight
  night would start him (D135), with how he feels (*Fresh, no injuries* or *Hurt (legs): 5 more days to heal*), his Chin
  and his gas tank. Three gauges: fatigue now, this week's peak and the chance of an injury this week, each green, yellow
  or red (fatigue: under 20, under 40, 40 and up, where he starts learning less; injury: under 3%, under 6%, more). Under
  them the camp's length, age and potential boxes (§3.6) and the camp so far, one entry a week.
- **The week** (middle). *Start from* and *Instruction* as before, then the week as tiles (`ui/session_tile.gd`): each
  session's name with a stripe in its kind's colour and the fatigue it leaves him at (or *out hurt* / *skipped* once a
  week has run). Clicking a tile opens every session grouped by kind, with what each does to fatigue. A tile that can be
  played has a *Play* box, and a ticked one is outlined in yellow. In fight week Saturday evening's tile is the fight.
  Under the tiles the week's fatigue as a line (`ui/fatigue_line.gd`) lined up with the day columns: where he starts,
  then after each session, with the dashed line at 40 where he learns less and the peak marked. Then the kinds' colours,
  and the forecast's notes (§3.6) as before. On fight night the tiles and line show how the last week went.
- **Stats** (right). Every stat as a bar 0–100 in its group (`ui/stat_bars.gd`): grey to where it started, green for
  what the camp added (red for a loss), a yellow tick where this week's forecast takes it, and the number, grade and
  camp change at the right. A gain under a point is a sliver on a 0–100 bar, so the green part is always at least a few
  pixels wide.

**Kinds of training.** Each session now says what kind it is (`kind` in `data/sessions`, `09` session@1), and the tile,
the session list and the legend colour it: striking red (Boxing drills, Heavy bag, Thai pads), wrestling blue
(Wrestling drills, Sprawl drills, Clinch work), grappling pink (Rolling), sparring orange (Light and Hard sparring),
conditioning green (Sprints, Strength & conditioning, Roadwork), mind purple (Film study, Meditation) and recovery teal
(Recovery, Rehab, Rest). Grappling wasn't in the mockup; it got its own colour so Rolling doesn't look like wrestling.

**The display font.** Kyle asked for one bold condensed font for headings and big numbers: **Barlow Condensed Bold**
(SIL Open Font License, `ui/fonts/`), set by `ui/display_font.gd`. On this screen it's the name, the days to the fight,
the week's heading, the card headings, the weeks along the top, the gauges' numbers, the stat numbers and *Fight!*.
Body text stays in Godot's default font. The other screens get it as each one gets its pass.

**Not yet:** drag and drop between slots, fight night as its own card (next), the fight setup's tale of the tape and the
result screen, the minigame screen in the same look, and sounds.

**What to change:** the layout and colours of the screen (`BACKGROUND`, `CARD`, `RED_CORNER`), the gauges' bands
(`FATIGUE_BANDS`, `INJURY_BANDS`, `INJURY_FULL`) and the fight's day (`FIGHT_DAY`) in `ui/camp_planner.gd`; the kinds'
colours and names (`KIND_COLOURS`, `KIND_NAMES`) and the tile's size in `ui/session_tile.gd`; a session's kind in its
`data/sessions` file (the kinds are `TrainingLibrary.KINDS`); the chart in `ui/fatigue_line.gd`, the bars in
`ui/stat_bars.gd`, the weeks along the top in `ui/camp_countdown.gd`, the font in `ui/display_font.gd`. Tests:
`tests/ui/test_camp_planner.gd`, `tests/ui/test_fatigue_line.gd`, and the kinds in `tests/data/test_data_files.gd`.
Presentation only: camps and fights don't change. Then update this section and D170.

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
