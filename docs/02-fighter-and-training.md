# 02 — Fighter Creation, Attributes & Training

> Related decisions: D8, D13, D14, D23, D24, D34–D40. Status: **design draft**.

---

## 1. Creation flow

```
Name / nickname / nationality / hometown
   └─► Childhood vignettes (D8): ages ~8, ~13, ~17
        └─► Age ~19: "the gym walk-in" (D37) → first gym choice
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
| College football athlete | Explosiveness, Strength | Raw skills, cardio | Injury history |
| Judo / sambo household | Throws, leg locks | Boxing | Olympic dreams that didn't happen |
| Boxing gym kid | Hands, head movement | Kicks, ground | Old boxing coach feels betrayed |
| Late starter / privileged | Money, time, Fight IQ | Toughness, chin | Proving yourself |
| **Track star** | Cardio, Speed, footwork | Strength, power | Former coach and scholarship |
| **Bullied underdog** | Heart, composure growth, Coachability | Low starting stats | A bully from school shows up in the world |

Backgrounds aren't picked from a list. They **emerge** from vignette choices (a scene at age 8 might be "a
wrestling tournament with dad" vs "a karate class at the community centre" vs "getting jumped after school").

### 1.3 Personality traits (D36)
Hybrid: vignettes set the starting traits plus a small random roll, and traits drift during the career.

| Trait axis | Gameplay effect |
|---|---|
| Ego ↔ Humble | Compliance with calls; habit absorption (only successful calls) |
| Discipline ↔ Party animal | Camp consistency, weight-cut success, life-event risks |
| Aggressive ↔ Patient | AI tendencies, foul risk |
| Coachable/Adaptive ↔ Stubborn | Habit absorption (D32); training XP multiplier |
| Loyal ↔ Mercenary | Reaction to poaching offers, switching gyms, money disputes |
| Composed ↔ Fragile | Panic thresholds; between-round motivation effect |

---

## 2. Attributes (internally 0–100, shown as grades + tags, D24)

| Group | Attributes |
|---|---|
| Physical | Strength, Speed, Explosiveness, Cardio, Recovery, Durability, **Chin** (wears down over a career) |
| Striking | Boxing, Kicking, Clinch striking, Striking defense, Footwork, Power |
| Wrestling | Takedowns, Takedown defense, Clinch control, Scrambles |
| Grappling | Top control, Guard/bottom game, Submissions, Submission defense, Ground-and-pound |
| Mental | Fight IQ, Composure, Heart, Coachability |
| Hidden / derived | Potential ceiling, aging curve, injury proneness, **natural weight** |

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
| **Sprawl reflex** | React to incoming shots with feints mixed in | Takedown defense, Explosiveness |
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
- **Camp phases (A6):** *Early* (development, S&C) → *Middle* (matchup drills, sparring, **drilling rules**, C2) →
  *Late* (taper, recovery, weight cut) → *Post-fight* (medical, review, return to training).
