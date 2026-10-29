# 03 — Career, World & Life

> Related decisions: D7, D16–D19, D21, D22, D25, D41–D45. Status: **design draft**.

---

## 1. Career shape

| Stage | Typical age | Fights | Notes |
|---|---|---|---|
| Gym walk-in / teen amateur (D83) | 16–19 | 4–10 amateur | Amateur rules (`08`), local/regional amateur cards; pro debut possible at 18+ |
| Regional pro | 18–25 | 6–12 | A few regional promotions; build record and hype |
| Pro org (tier 2) | 23–28 | 5–10 | The smaller of the 2 pro orgs |
| Pro org (tier 1) | 25–33 | 8–15 | Rankings, title fights, PPV |
| Decline / retirement | 33+ | — | Aging, chin wear, legacy decisions |

Target: **~20–30 hours of play, ~25–35 pro fights** (D16). One fight is roughly every 45 min of play.

### 1.1 Calendar
- The game advances **week by week**. Every week ends at a natural save point (D25).
- Fight offers arrive based on hype, rank, and promotion needs.
- "Advance until next event" fast-forward for quick sessions.

---

## 2. World simulation (D41)

- **Simulated fighters:** at least **100** across amateur/regional/pro. *(Open: per division or in total? See W1.)*
- **Promotions**: 3–4 regional promotions + **2 pro organisations** (D41) that compete for talent (D18).
  - Each promotion has a personality: matchmaking style, pay scale, contract tactics, its own ranking table.
- Every fighter has stats, traits, tendencies/tells, a record, hype and a career arc (rising, prime, declining, retired).
- Each week the other fights are **simulated headless** with the same fight engine (fast mode). Records, rankings and champions change.
- **New prospects** are generated each year, and older fighters retire. The world keeps going.

### 2.1 Generated rivalries (D22, D39)
A grudge score between any two fighters, raised by:
- Losing a close/controversial decision to them
- Callouts and trash talk (press conference choices)
- Fouls in a fight between them
- Shared-gym history (former training partners, D39)
- A fight cancelled/declined

Above a threshold → **rival**. Rivals get commentary lines, press conference scenes, bigger purses, and rematch offers.
Trilogies are possible.

---

## 3. Contracts & money (D21, D42)

- **Contracts**: number of fights, show/win purse, exclusivity, champion clause, release clause.
- **Negotiation**: a simple offer/counter screen. Hype and record are your leverage. The other org's interest can be used as leverage.
- **Fight offers**: regular, **short notice** (big hype/money, less camp), **catchweight**, **title eliminator**, **interim title**.
- **Money**: weekly budget: rent, gym fees, coaches, medical bills, travel camps, lifestyle.
- **Sponsors**: unlock with hype; conditions apply (win streak, social media activity).
- **Being cut**: losing streaks or bad behaviour can get you released (D43).
- **Poaching** (Corner King, D26): the other org can try to sign you; rival gyms can try to poach your coaches.

---

## 4. Hype, media, life (D21)

- **Hype** (popularity) and **Reputation** (respect) are separate stats.
- **Press conferences**: choice-based dialogue (Respectful / Confident / Trash talk / Silent). Affects hype, grudge,
  the opponent's composure, and your fighter's ego.
- **Callouts** after wins.
- **Relationships** (4–6 persistent characters): family member, mentor, best friend/training partner, partner,
  manager (later). Each has a relationship meter and light story events that can affect motivation, money and focus.
- **Life events** (warm but punishing, D43): family emergencies, a party invite the week before a fight,
  a car accident, a big sponsor offer that needs time, a new baby.

---

## 5. Injuries & health (D19)

- **Camp injuries** (from fatigue, hard sparring, bad luck) → pull out of fight or fight hurt (hidden penalty, risky).
- **Fight injuries** → **medical suspension** (days/weeks), sometimes surgery.
- **Lasting dents**: e.g. bad knee (−TD explosiveness), repeated orbital fractures.
- **Chin wear**: every KO/TKO and heavy head damage reduces Chin permanently by a small amount. Hard sparring wears it too.
- **Throwing in the towel** (D31) protects long-term health and the relationship.
- **Career-ending injuries** are possible but rare (D43).

---

## 6. End of career & meta

- **Retirement**: chosen, forced (health), or circumstantial (cut + no offers).
- **Legacy screen**: record, titles, best wins, rivalries, Hall of Fame score.
- **Ironman mode** (D45): one autosave, no reloading.
- **Next generation / coach mode**: post-launch (D15 hook). Your coach character carries over.
- **Replayability** (D25): different background vignettes, seeded world generation, random life events, different promotions.

---

## 7. Promotion generation (D57)

At the start of every new career:
1. Pick the **home region** from the fighter's hometown (real places).
2. Generate **3–4 regional promotions** near it: name, HQ city, venue sizes, matchmaking style, pay scale, reputation.
3. Generate **2 pro organisations** (international): name, branding colours, HQ, ranking style, contract tactics, PPV model.
4. Fill each of the 6 divisions (D56) with **~100 fighters** (D55), spread across amateur/regional/pro tiers, with backgrounds and nationalities
   weighted toward real-world MMA hotbeds.
5. Simulate a short **history** (e.g. 3–5 years of past results) so champions, records and rivalries already exist on day one.

Name generators need some care: promotion names should sound plausible without copying real brands.

### 7.1 Opponent style sheets (D160)
The ~600 world fighters are made from **style sheets** (`data/styles/`, `09` style@1). Each sheet names a hand-built
**signature fighter** in `data/fighters/` and says how far opponents of that style may differ from it. A generated opponent
keeps the style's moves, combinations and tell, so scouting a style works on every fighter of it; their stats, style
leanings, move preferences, personality, height and stance differ a little, and a **quality level** (−30 to +30 on every stat)
sets how good they are. Each sheet also carries a **scouting card**: how they fight, strengths, weaknesses, the tell and how
to beat them.

| Style | Signature fighter | Roots | Fights by |
|---|---|---|---|
| Range kicker | `kicker` | Karate/TKD, Dutch kickboxing | Teeps and kicks from range; tell: body kick after a blocked jab |
| Pressure boxer | `boxer` | Boxing gym kid, street kid | Walking you down to trade combinations in the pocket |
| Wrestle-boxer | `wrestler` | Wrestling family, Dagestan | Jab and overhand to get close, then the double leg; tell: stance shift before the shot |
| Submission grappler | `bjj` | Jiu-jitsu prodigy, Rio | Clinch or guard pull, then submissions from anywhere |
| Judo thrower | `judoka` | Judo/sambo household | Clinch, trips and throws, then the back |
| Sambo leg-locker | `sambo` | Judo/sambo household, Dagestan | Takedowns and throws, leg locks in scrambles |
| Muay Thai clinch fighter | `muay_thai` | Muay Thai camp, Bangkok | Collar tie, knees and elbows |
| **Counter-striker** (new) | `counter_striker` | Boxing gym kid, karate, late starter | Waits for you to lead, then counters (Pace −70, Risk −30); tell: a counter right hand after you miss |
| **Sprawl-and-brawl** (new) | `sprawl_brawl` | Boxing gym kid, street kid, college football | Stuffs takedowns (TDD 75, Base −70) and keeps it standing; tell: body hook after a blocked jab |
| **Brawler** (new) | `brawler` | Street kid, farm kid | Hooks and overhands, hunting the knockout (Pace +70, Risk +70, Power 70, Heavy hands); tell: overhand after a blocked jab |

Every sheet uses the same variation for now: stats ±6, leanings ±12, move preferences ±20%, personality ±30, height ±4 cm.
Check that a sheet's opponents fight in style with `tools/style_sheets.gd -- --fights=30` (prints the scouting cards, then
a table of win rate against the other styles' signature fighters, finishes, output, shots, submissions, clinch and ground time).
First run (2026-10-29, 30 opponents a style at level 0; reported, no pass marks):

| Style | Wins | By KO/TKO | By sub | Strikes a minute | Shots a fight | Subs tried | Clinch | Ground |
|---|---|---|---|---|---|---|---|---|
| Range kicker | 53% | 7% | 0% | 10.2 | 0 | 1.0 | 1% | 10% |
| Pressure boxer | 43% | 30% | 0% | 11.8 | 0 | 0 | 6% | 18% |
| Wrestle-boxer | 33% | 13% | 0% | 6.1 | 25.7 | 0.8 | 3% | 52% |
| Submission grappler | 43% | 0% | 23% | 6.8 | 9.1 | 2.5 | 3% | 40% |
| Judo thrower | 43% | 0% | 10% | 6.6 | 41.4 | 2.3 | 6% | 43% |
| Sambo leg-locker | 33% | 0% | 17% | 6.2 | 35.3 | 1.9 | 5% | 41% |
| Muay Thai clinch fighter | 50% | 40% | 0% | 9.9 | 0 | 0.2 | 12% | 19% |
| Counter-striker | 47% | 13% | 0% | 10.6 | 0 | 0.2 | 1% | 15% |
| Sprawl-and-brawl | 50% | 47% | 0% | 11.6 | 0 | 0.5 | 7% | 14% |
| Brawler | 60% | 47% | 0% | 11.0 | 0 | 0.1 | 4% | 21% |

Each style wins its own way. To watch: the Counter-striker still throws about as much as the strikers (most of it counters
and tells, not leads), and the wrestling styles win least against this field.

Not yet: names and nationalities for generated fighters, picking a style mix per division and region, and showing the
scouting card on screen (it comes with scouting, D51).

## 8. Resolved & open questions
- W1 → **D55**: ~100 fighters **per division**.
- W2 → **D56**: 6 men's divisions at launch.
- W3 → **D57**: real places, fictional promotions generated per career.
- W6 → **D58**: the head coach acts as manager by default; an optional hired agent auto-negotiates for a cut.
- W4 → **D72**: full title layer (defences, vacating, double champ, superfights) + GOAT legacy score.
- W5 → **D73**: results list first, then watching the whole card.
- W7 → **D74**: foreign fights during trips.

## 9. Merged from the Foundation doc (see `05`)
- **World-sim tiers (A9):** *Player* (full sim) · *Important competitors* (top 15 of each division + rivals +
  your opponents: full headless fight sim) · *Wider world* (statistical result model). Keeps ~600 fighters cheap.
- **Rankings (A10):** recent results, opponent quality, activity, title status. Ranking moves get a one-line
  explanation ("+3: beat #7 by KO").
- **Long-run validation (A10):** automated 30-year world sims check that champions turn over, divisions stay
  full, and records/ages look plausible.
- **Conditional consequences (A7):** a loss's effect scales with expectation (ranking gap, performance, finish type).
- **Retirement (A8):** forced retirement is rare, foreshadowed (doctor warnings, declining camp results) and explained, with a
  career epilogue + legacy/GOAT screen.
