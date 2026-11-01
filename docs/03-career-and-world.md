# 03 — Career, World & Life

> Related decisions: D7, D16–D19, D21, D22, D25, D35, D41–D45, D55–D57, D160, D300–D316, D350–D359. Status: **design draft**; §7.1 and §10.1–§10.5 and §11 are built; §12 (D350–D359) is planned.

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
| **Pressure wrestler** (new) | `pressure_wrestler` | Wrestling family, Dagestan | Relentless pace (Pace +80, Cardio 75), chained double legs and feints to set them up; tell: shoots behind a blocked jab |
| **Karate point fighter** (new) | `karate` | Karate/TKD | Far outside (Range −80, Footwork 75), feints, straight punches and head kicks; often southpaw (35%); tell: head kick after a blocked jab |
| **Leg-kick specialist** (new) | `leg_kicker` | Dutch kickboxing, Amsterdam, Muay Thai | Walks forward chopping the legs (leg kick ×2, calf kick ×1.0 since D255, the new 1-2-leg kick combination); tell: calf kick after a blocked jab |
| **Dirty boxer** (new) | `dirty_boxer` | Boxing gym kid, street kid | Grabs the clinch (clinch entry ×3, Range +80) and works short uppercuts and hooks; tell: grabs the clinch after a blocked jab |
| **Ground-and-pound wrestler** (new) | `gnp_wrestler` | Wrestling family, farm kid | Takedowns to hit, not to submit: Top control 70, ground punches and elbows ×2, no submissions of his own; tell: shoots behind a blocked jab |

Every sheet uses the same variation for now: stats ±6, leanings ±12, move preferences ±20%, personality ±30, height ±4 cm.
Check that a sheet's opponents fight in style with `tools/style_sheets.gd -- --fights=30` (prints the scouting cards, then
a table of win rate against the other styles' signature fighters, finishes, output, shots, submissions, clinch and ground time).
Kyle picked "recipe + scouting card" and all 15 styles (the first 10 plus five extras) on 2026-10-29. Run with all 15
(2026-10-29, 30 opponents a style at level 0, each against the other 14 signature fighters in turn; reported, no pass marks):

| Style | Wins | By KO/TKO | By sub | Strikes a minute | Shots a fight | Subs tried | Clinch | Ground |
|---|---|---|---|---|---|---|---|---|
| Range kicker | 47% | 3% | 0% | 9.8 | 0 | 1.1 | 1% | 15% |
| Pressure boxer | 37% | 30% | 0% | 10.5 | 0 | 0.3 | 8% | 19% |
| Wrestle-boxer | 60% | 10% | 10% | 6.3 | 33.7 | 1.4 | 4% | 51% |
| Submission grappler | 53% | 0% | 37% | 6.8 | 10.3 | 2.4 | 4% | 46% |
| Judo thrower | 50% | 7% | 17% | 6.4 | 41.6 | 1.9 | 6% | 43% |
| Sambo leg-locker | 57% | 7% | 27% | 6.4 | 38.1 | 2.4 | 5% | 49% |
| Muay Thai clinch fighter | 60% | 50% | 3% | 9.9 | 0 | 0.4 | 17% | 22% |
| Counter-striker | 57% | 13% | 0% | 11.7 | 0 | 0.3 | 2% | 14% |
| Sprawl-and-brawl | 63% | 50% | 3% | 11.6 | 0 | 0.5 | 9% | 13% |
| Brawler | 50% | 47% | 0% | 8.6 | 0 | 0.3 | 6% | 23% |
| Pressure wrestler | 47% | 17% | 3% | 8.3 | 33.1 | 0.6 | 4% | 57% |
| Karate point fighter | 57% | 23% | 0% | 9.8 | 0 | 0.1 | 0% | 11% |
| Leg-kick specialist | 40% | 17% | 3% | 14.0 | 0 | 0.4 | 7% | 20% |
| Dirty boxer | 40% | 30% | 3% | 9.9 | 0 | 0.5 | 25% | 23% |
| Ground-and-pound wrestler | 50% | 37% | 0% | 5.8 | 24.5 | 0.1 | 3% | 54% |

Every style wins between 37% and 63%, and each wins its own way: the strikers by KO, the grapplers by submission, the
wrestlers on top (51–57% of the fight on the ground), the Dirty boxer and Muay Thai fighter in the clinch (17–25%). The
Leg-kick specialist first won 33%; Kyle asked for at least 36% (2026-10-29), so his Striking defense and Footwork went from 50
to 55: 40% over 30 fights and 40% over 90. To watch: the Counter-striker throws about as much as the other strikers
(counters and tells, not leads).

**Reworking the Leg-kick specialist (D255, 2026-10-31).** Kyle asked how he does against the field before deciding whether
to change how he fights. In a round robin of all 15 signature fighters (40 fights a pairing, pro rules, no calls) he won 48%
against an average of 50% (8th of 15). He beat outside fighters and grapplers (Kicker 90%, Karate 72%, Sambo and Wrestler 70%)
and lost to the men who walk forward (Muay Thai 10%, Dirty boxer 18%, Sprawl-and-brawl 28%, Counter-striker 32%). He threw
and landed the most strikes and did 20 times the field's leg damage, but took the most head damage, was stopped by KO/TKO in
31% of his fights (field 18%) and spent 241 s a fight shut in on the fence (field 37 s).

- *Tried and dropped: getting him off the fence.* Kyle first picked "Both": circle and burst off the fence like an outside
  fighter, and plant and punish the walk-in (teep, knee, low kicks) when he can't get out. Built as two fighter tendencies,
  it cut his time shut in from 241 s to 52 s but dropped him from 48% to 22%; bursting and reversing alone 42%; punishing
  alone 46%. Planted on the fence he gets +0.4 to meet a man coming in (D234), which is his best way of fighting. None of
  it shipped.
- *What actually beat him* (head damage he took, 12 fights a pairing): against the Dirty boxer, 44% while held on the
  fence in the clinch; against Muay Thai, 45% from knees with his posture broken; against the Counter-striker, 68% from
  counters, a third of it while throwing the calf kick; against the Brawler and Sprawl-and-brawl, 34% and 43% from counters.
- *Kyle's pick: fix the clinch and the counters.* The counters: his calf kick weight goes from 1.6 to 1.0, so he leads
  with it less on its own and throws it more off the jab (his tell and his combinations). Over 100 fights a pairing
  (seed 1001) the signature fighter goes from 51% to 58% (±4); Counter-striker 43 → 55%, Boxer 38 → 55%, Judoka 51 → 66%,
  GnP wrestler 41 → 56%; his leg damage falls from 214 to 160 a fight (still 15 times the field's). Opponents generated
  from his sheet move less (`tools/style_sheets.gd -- --fights=700`: 45 → 47%, inside the dice), likely because his
  leanings ±12 put some of them below Range 0, where they fight as outside fighters. The calf kick weight is in
  `data/fighters/leg_kicker.json` (`tendencies.actions.calf_kick`).
- *The clinch stays his weakness (D256, Kyle: "Keep it as his weakness").* With the grips in (D261, D262) he wins 55%
  against the field (100 fights a pairing, seed 1001) but only 20% against Muay Thai and 23% against the Dirty boxer:
  his clinch breaks fail about 9 times in 10 and his spin-offs about 6 in 10. None of the fixes tried helped much (100
  fights each against the two): Clinch control 65 gave 26% and 27%; knees ×1.5 made it worse (5%, 9%), both together too
  (13%, 7%); fighting from range, Range −30 or −60, much worse (4–7%). Most of the head damage they do lands standing, as
  they counter him walking in, not in the clinch. So his scouting card now says it ("Falls apart against a clinch
  fighter, worst of all on the fence", and tie him up in how to beat him), and the player can use it. The fighters who
  beat Muay Thai and the Dirty boxer keep their distance with better footwork: Karate 88% and 100%, the Counter-striker
  78% and 72% (40 fights a pairing, before the grips).

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

## 10. The career (D300–D305)

Kyle (2026-10-31): "lets get a thread up for working on the portions of the game outside of fighting". Everything built
outside the cage so far (the camp, fight night, ageing, mitt work, the style sheets, the tale of the tape and the result
screen) hung off one fight picked on the setup screen, and nothing carried on after it. The plan puts the rest of the game
outside the fights in six phases: **1** the career spine, **2** the front door (the head coach, the childhood scenes, the gym
walk-in, the teen amateur stage and the story as the tutorial, which finishes the vertical slice, D48), **3** a world to climb
(divisions, named fighters, promotions, rankings, titles), **4** a deeper camp (scouting, rule drilling, the weight cut, gyms
and coaches, more minigames), **5** the business and the story (money, contracts, hype, press conferences, rivals, life
events, trips) and **6** how a career ends (retirement, legacy, ironman). Kyle picked the career spine first (D300).

Phase 1 joins what's built into a career that goes on from fight to fight and saves:

| Piece | Decision | Status |
|---|---|---|
| The career and its save file | D301 | Built (§10.1) |
| The title screen and a new career | D302 | Built (§10.2) |
| The career hub and the calendar | D303 | Built (§10.3) |
| Fight offers and matchmaking | D304 | Built (§10.4) |
| The aftermath, and skipping a fight | D305 | Built (§10.5) |

### 10.1 The career and its save file (D301)

One career is one `Career` (`sim/world/career.gd`), pure logic and seeded like the fight (D100), and one save file.

**What a career holds.** The head coach's name (the player, D15); the fighter as he started (his fighter@1 profile: name,
frame, stance, personality, gifts, flaws and moves) and his nickname, hometown, country and background; the date; his record
and a line for every fight; how many days of a medical suspension are left; his money; whether he's turned pro; everyone he's
fought or is booked to fight (their whole profiles, so a rematch is the same man); the booked fight and the offers on the
table (filled in by D304); and the week plan he runs between fights (*Between fights* to start with, `docs/02` §3.8).

**Training for life.** His stats (with their fractions), style, fatigue, injuries and age live in one `TrainingCamp` that he
trains in for the whole career (`trainee`): a week between fights is `run_week()`, and a camp's weeks will go through the
planner on the same trainee, so nothing is lost between camps. `TrainingCamp.snapshot()` and `restore()` carry all of it,
the dice included, into the save.

**The calendar.** A career starts on Monday 4 January 2027 (week 0) and moves a week at a time; `date_text()` gives
"Mon 4 Jan 2027". Each week between fights he trains on his plan, heals, gets a week older (52 weeks is a birthday) and a
suspension runs down 7 days. The date is worked out with plain arithmetic, not the computer's clock (sim/ never reads it).

**The record.** `add_fight()` takes a finished fight (a result of win, loss, draw or no contest, the opponent, and how
and when it ended) and dates it this week. Amateur and pro fights are counted apart: `record_text()` gives "5-1-0", with
"1 NC" after it for no contests.

**Its own dice.** The career rolls its own dice, apart from each fight's (A11): a fight takes a seed from `next_seed()`
and replays from that alone. The same career seed and the same choices always play out the same, and a career saved and
loaded carries on exactly as if it had never stopped, because the dice are saved with it. Seeds and dice are saved as text,
since a 64-bit number doesn't survive being a JSON number.

**Saves** (`game/career_saves.gd`, `docs/04` §11, A11, R8). Three slots (`CareerSaves.SLOTS`), each a JSON file in the
player's `user://saves/` folder (on Windows `%APPDATA%\Godot\app_userdata\Chin Check\saves`). A save is written to a
temporary file, read back to check it, and only then takes the slot's place; the save it replaces is kept as the slot's
backup. If the main file is missing or damaged, loading uses the backup (a week back, not lost) and says so. *Continue*
will load the slot saved last (`latest()`). In the browser build the saves live in the browser's storage for the page, so
clearing the site's data clears them.

**A save that survives updates.** The file says it's a career save and which version of the format it is
(`Career.VERSION`, now 1; `docs/09` career@1). A change to what a career saves raises the version and adds a step to
`Career.migrate()` that brings older saves up to date, with a test. A save from a newer version of the game than the one
reading it is refused with that reason, never half-read.

**Not yet:** autosaving before each fight (with offers, D304) and ironman mode (one save, no going back, D45; phase 6).
The title screen and the slots on screen came with D302 (§10.2); the hub saves every week.

**What to change:** the start date (`START_DATE`), the week plan between fights (`BETWEEN_PLAN`) and the save format
(`VERSION`, `migrate()`) in `sim/world/career.gd`; the number of slots (`SLOTS`) and where they go (`DIR`) in
`game/career_saves.gd`. Tests: `tests/sim/world/test_career.gd`, `tests/game/test_career_saves.gd` and the snapshot in
`tests/sim/world/test_training_camp.gd`. Fights don't change (no golden re-pin). Then update this section and D301.

### 10.2 The title screen and a new career (D302)

**The title screen** (`ui/title_screen.gd`) is the first thing the game shows, in the corner-board look of the screens off
the cage (D170): CHIN CHECK in the display font, Lampsmoke Games under it (D242), then:

- **Continue**: the career saved last, with his name, age and the date under the button. Greyed out until there's a career.
- **New career**: the new-career screen.
- **Load career** (`ui/load_screen.gd`): the three slots side by side, each with the fighter's name and nickname, age, the
  career's date, his record, his coach and when it was saved (and a warning when only the backup could be read). Load, and
  Delete, which asks once more before it deletes.
- **Quick fight**: the fight setup and the Playtest fights, exactly as before (it has a *Main menu* button now, and Esc goes
  back to the title too).
- **Quit** (not in the browser build, which can't close its own tab).

**A new career** (`ui/new_career_screen.gd`) asks your name (you're his coach, D15), then his name, nickname, hometown, stance
and where he comes from: one of the 12 backgrounds of `docs/02` §1.2 (Q4 in the plan: picked from a list until phase 2's
childhood scenes picked it instead: now they do, unless you untick *Play his childhood*, §11.2). The screen opens already rolled, so *Start career* works straight away; *Roll everything*
rolls again. Hometowns are real cities in 12 countries (`data/names/`), and a rolled name comes from his hometown's country.
Each background shows what it's strong and weak at, the style he'll grow into, the money he starts with (in dollars, Kyle's
call) and its story hook.
*Start career* takes the first free slot and saves at once; with all three in use it asks you to delete one first.

**The fighter a background makes** (`BackgroundLibrary.make_fighter`, `sim/world/background_library.gd`, from
`data/backgrounds/`, `docs/09` background@1). He's 16 (Q3). Every stat rolls 20 to 35, his background's strengths 12 higher and
its weaknesses 8 lower (never under 5), so a wrestling family's son starts with takedowns around 40 and boxing around 20. His
style leans his background's way (± 10), his personality is his own (± 30 around the background's lean), his height is in
its range and his build its build. Potential is 60 plus two dice of 1 to 16 (62 to 92, most often near 77), hidden behind the
scouted range (D136). He rolls 0 to 2 gifts (45%, 40%, 15%) and a flaw 35% of the time (D90), more likely the ones his
background favours (a street kid's Granite chin, a football player's Freak athlete and Slow healer). Bleeder and Hard cut stay
off his card until they show (D90). His moves, combinations and habits are his background fighter's (data/fighters: the
Wrestler for a wrestling family, the Boxer for the boxing gym kid), only worse. The same background, seed and choices always
make the same fighter. Kyle (2026-10-31) was happy with that starting level.

**The career hub, first version** (`ui/career_hub.gd`; D303 filled it in, §10.3): the top bar (his name and nickname, age, records,
coach, the date and the week), his card (background, hometown, stance, height and reach, the gifts and flaws he knows of,
his scouted potential, the background's hook), every stat as a bar and a grade, and *This week*: any injury or suspension,
the week plan, his savings, *Run this week* (a week between fights, then an autosave) and *Save and go to the title*.

**Not yet:** offers and fights from the hub (D304), the calendar and the rest of the hub (D303), and the head coach's look
(his background and specialty came in §11.1, the childhood scenes in §11.2).

**What to change:** a background's strengths, weaknesses, leanings, frame, gift and flaw odds, money and hook in its file in
`data/backgrounds/`; how high or low a new fighter starts, potential and the gift and flaw odds (`STAT_LOW`, `STAT_HIGH`,
`STRENGTH_BONUS`, `WEAKNESS_PENALTY`, `POTENTIAL_BASE`, `POTENTIAL_DIE`, `GIFT_COUNT_ODDS`, `FLAW_CHANCE`) in
`sim/world/background_library.gd`; the cities and names in `data/names/`, nicknames in `data/enums/nicknames.json`; the
southpaw chance of a roll (`SOUTHPAW_CHANCE`) in `ui/new_career_screen.gd`. Tests: `tests/sim/world/test_background_library.gd`,
`tests/sim/world/test_name_library.gd`, `tests/ui/test_career_screens.gd` and the career tests in `tests/game/test_main_scene.gd`.
Fights don't change (no golden re-pin). Then update this section and D302.

### 10.3 The career hub and the calendar (D303)

The hub (`ui/career_hub.gd`) is the screen a career comes back to between fights (Q6 in the plan: one default plan, Run
this week or Advance).

- **Top bar:** his name and nickname, age, amateur record (and pro once he's turned pro), his coach, the date and the week.
- **The fighter:** the body figure showing any injury (as fight night would see it), how he feels (fresh, a little tired,
  worn down; hurt and for how long), his background, hometown, stance, height, reach and build, the style he's leaning
  toward (the D88 hints past ±30, and any named style traits), the gifts and flaws he knows of, his scouted potential and
  his background's hook. Then every stat as a bar and a grade, in its group.
- **This week:** what's next (offers waiting and a booked fight come with D304; hurt for N days; suspended for N days;
  otherwise free to fight), his week plan between fights (a picker of every week plan; *Between fights* to start,
  `docs/02` §3.8), his savings, and:
  - **Run this week**: one week on his plan, then an autosave.
  - **Advance until something happens**: weeks on his plan until he's hurt in training, healed, cleared to fight, worn
    down from training, has a birthday or an offer comes in, at most 8 weeks (`Career.ADVANCE_MAX_WEEKS`), then an
    autosave. *Worn down* (Kyle, 2026-10-31) means his fatigue went past 40 during the week (`TrainingCamp.FATIGUE_FREE`,
    where he starts learning less, `02` §3.5); Sunday's rest has him fresh again by Monday, so it's the week's peak that
    counts. It stops the first week a plan wears him down, not every week after on the same plan, so a player who means
    to train hard can press Advance again and it keeps going. To stop every worn week instead, drop the
    `worn_last_week` check in `Career.run_week()`. While he's booked for
    a fight neither button runs: the camp runs those weeks (D304).
  - Under them, what the last run did: the biggest gains over the weeks and anything that happened, with its week.
- **His fights:** newest first, the result (W, L, D, NC), who, how and in which round, the date (the Saturday of the
  week it was fought) and amateur or pro.
- **The calendar:** the coming 8 weeks (`Career.CALENDAR_WEEKS`), this one first, each with what will happen in it if
  nothing changes: an injury healed, a suspension over, his birthday, fight night (`Career.calendar()`).

**Fitting the screen (D340):** the hub is one screen and the page itself doesn't scroll (Kyle, 2026-11-01, found it
running off the bottom). The long parts scroll inside their own cards instead, with the mouse wheel or by dragging the
bar: the fighter card's text, his stats, this week's news together with the offers under it, and his fights. The
headings, the week plan, the buttons (Run this week, Advance, Go to camp, Turn pro, Save and go to the title) and the
calendar stay put, so however long his record or last week's report gets, they're always on screen. Each refresh puts
the scrolling parts back at the top.

Each week's report from `Career.run_week()` now says what happened in it (`events`: hurt, healed, cleared, birthday,
fight night) and which week it was.

**Not yet:** opening any week in the planner to plan it slot by slot, and the stats' tags (D24). Offers on the hub and a
booked fight's camp are §10.4.

**What to change:** how many weeks Advance runs at most (`ADVANCE_MAX_WEEKS`) and the calendar shows (`CALENDAR_WEEKS`)
in `sim/world/career.gd`; how many fights the list shows (`FIGHTS_SHOWN`), the colours and which parts scroll (`_scroll()`
in `_init()`, D340) in `ui/career_hub.gd`. Tests:
`tests/sim/world/test_career.gd`, `tests/ui/test_career_screens.gd`, `tests/game/test_main_scene.gd`. Fights don't change
(no golden re-pin). Then update this section and D303.

### 10.4 Fight offers, the camp and the fight (D304)

A career now goes from fight to fight. Kyle said start (2026-10-31); the numbers are the picks put to him, built while he
answered, and Kyle confirmed them: "Fight numbers seemed fine to me" (2026-10-31).

**When offers come.** While he's free (not booked, not hurt, not suspended), a set of 2–3 offers comes in every few weeks
(`Matchmaker.OFFERS_MIN`, `OFFERS_MAX`): the first after his first week, then 1–3 weeks after a set closes
(`GAP_MIN`, `GAP_MAX`) and 1–3 weeks after a fight. Each set stays open this week and next (`OPEN_WEEKS`), then goes. A new
set is an event (*N fight offers*), so *Advance* stops for it; offers already on the table don't stop it.

**Who's offered.** Each offer is a new man made from one of the 15 style sheets (`StyleLibrary.generate`, §7.1), a
different style each, with a name, nickname and hometown from `data/names` (`NameLibrary`). His quality level is set from
the career fighter's: his average stat less the style's signature fighter's (`Matchmaker.level_against`), then −5 for *a
bit easier*, 0 for *about even* or +5 for *a bit harder* (`DIFFICULTY_LEVELS`), give or take 2 (`LEVEL_SPREAD`). Two offers
are one about even and one easier or harder; three are one of each. A teenager meets 16- and 17-year-olds; a man meets men
3 younger to 4 older.

**The rules and the money.** Under 18, teen amateur rules (`amateur_teen`); from 18, adult amateur (`amateur_adult`); once
he turns pro, pro rules. Amateurs aren't paid. A pro fight pays $1,000 to show and $1,000 more to win, both $250 more for
every pro win he has (`PURSE_SHOW`, `PURSE_WIN`, `PURSE_STEP`). **Turn pro** shows on the hub from 18 with 4 amateur fights
(`PRO_AGE`, `PRO_AFTER_FIGHTS`); the amateur offers on the table go and pro offers come the week after.

**The date.** Taken the week it comes in, an offer leaves a camp of 5–8 weeks (`CAMP_WEEKS_MIN` + 1 to `CAMP_WEEKS_MAX`);
taken in its second week, a week less, so never under 4. Fight night is the last week's Saturday (D135).

**On the hub.** Each offer is a card under *This week*: his name and nickname, the style and how he compares (a bit easier,
about even, a bit harder), hometown, age, height and stance, the style's scouting line, grades for Striking, Wrestling,
Grappling and Physical, the date, the camp's length, the rules and the purse, and *Last week to answer* when it is. **Take
the fight** books it (the other offers go, the camp starts: `TrainingCamp.start_camp`); **Turn it down** takes only that
one off, with no penalty for now. Booked, *Run this week* and *Advance* give way to **Go to camp: N weeks to fight night**,
and the calendar shows fight night.

**The camp.** *Go to camp* opens the camp planner (`docs/02` §3.6) on the career's own fighter (`CampPlanner.use_career`):
its length is the weeks left to the fight, the camp can't be started again, and age and potential can't be set. Each week
run moves the calendar on and saves; *Back to the hub* leaves the camp where it is. Fight week waits for the fight, even over
a reload (the week's report is kept with the booking). On fight night the fight night card (`02` §3.11) says how he goes in;
pulling out, or the doctor not clearing him, calls the fight off when he goes back to the hub (`Career.cancel_fight`: the
camp's wasted, the week's over).

**The fight.** *Fight!* saves the career, then starts the fight against the booked man under the booked rules, with a seed
from the career's dice. A career fight can't be restarted from the pause menu. When it ends it goes on his record
(`Career.finish_fight`: result, how, the round, the rules, the purse), he's paid, an injury fighting hurt made worse (D135)
carries on, the fight week ends and the career saves. The result screen says what it did to his record and his money, and
*Back to the hub* goes home.

**Not yet:** short-notice offers, a rematch, an opponent's own record and camp, and reputation for turning fights down.

**What to change:** every number above is a constant at the top of `sim/world/matchmaker.gd`; when offers come and how a
fight is recorded are in `sim/world/career.gd` (`_check_offers`, `accept`, `finish_fight`); the offer cards in
`ui/career_hub.gd` (`offer_text`); the camp in `ui/camp_planner.gd` (`use_career`); the fight in `game/main.gd`
(`open_career_camp`, `_career_fight`, `_finish_career_fight`). Tests: `tests/sim/world/test_matchmaker.gd`,
`tests/ui/test_career_screens.gd`, `tests/game/test_main_scene.gd`. Fights themselves don't change (no golden re-pin).
Then update this section and D304.

### 10.5 The aftermath, and simming a fight (D305)

The last piece of the career spine. The picks put to Kyle; Kyle (2026-10-31): "Sounds good for now".

**The medical suspension.** After every fight the commission sits him out (`sim/world/aftermath.gd`): a KO loss 60 days and
1 point of Chin gone for good; a TKO loss (the referee, the doctor or the towel) 30 days and half a point of Chin; a hard
fight, won or lost, 21 days; any other fight 7 days. A hard fight is one where he was knocked down, or finished at least half
hurt to the head or 60% hurt to the body (`Aftermath.is_hard`, from `FighterState.hurt`). The suspension counts from fight
night, so by the Monday after two of its days are gone (`Career.FIGHT_TO_MONDAY`). While suspended no offers come (§10.4), the
hub says how long is left and the calendar shows the week he's cleared. Each fight's line on his record keeps its suspension,
why and the Chin lost. Chin already wears a little with hard sparring (`docs/02` §3.5); this is the knockout's own toll on
top, and it doesn't heal.

**Simming a fight.** The fight night card in a career has **Sim the fight** beside *Fight!*: the same fight (the booked man,
the rules, a seed from the career's dice, the camp's condition), played out at once with the sound off and no calls (the
fighters' own AI fights it), straight to the result screen, which says it was simmed. It counts exactly as a watched fight.

**Not yet:** damage that carries over as named injuries, a doctor's check that can lengthen a
suspension, and the AI corner coaching a simmed fight for him (D113).

**What to change:** the days and the Chin in `sim/world/aftermath.gd` (`KO_DAYS`, `KO_CHIN`, `TKO_DAYS`, `TKO_CHIN`,
`HARD_DAYS`, `HARD_HEAD`, `HARD_BODY`, `OTHER_DAYS`); where it's applied in `Career.finish_fight`; Sim the fight in
`ui/fight_night_card.gd` and `game/main.gd` (`sim_career_fight`); the result line in `game/main.gd` (`aftermath_text`). Tests:
`tests/sim/world/test_aftermath.gd`, `tests/game/test_main_scene.gd`. Fights don't change (no golden re-pin). Then update
this section and D305.


## 11. The front door (D310–D316)

Phase 2 of the plan (§10, D300): the first half hour of a new career, which is also the tutorial (`07`). Kyle (2026-10-31):
"Start now". The plan and its 14 questions are in the phase 2 plan doc (my picks are built until Kyle answers). Six pieces, in
this order (D310), each playable when it lands:

| Piece | Decision | Status |
|---|---|---|
| The head coach | D311 | Built (§11.1) |
| The childhood scenes at 8, 12 and 15, replacing the background list | D312 | Built (§11.2) |
| The gym walk-in at 16 | D313 | Built (§11.3) |
| School weeks and local cards | D314 | Built (§11.4) |
| The one-day tournament | D315 | Built (§11.5) |
| The story as the tutorial (the first three amateur fights, tip cards, the Coach's Notebook) | D316 | Built (§11.6) |

### 11.1 The head coach (D311)

You're his head coach (D15). A new career now asks three things about you (D63, D71): your name, who you were before him
(one of five coach backgrounds in `data/enums/coach_backgrounds.json`: former fighter, wrestling coach, boxing trainer, BJJ
black belt, PE teacher, each with a line about you) and your starting specialty, which does something small but real
(`sim/world/coach.gd`):

| Specialty | What it does |
|---|---|
| Striking | His Striking stats (`data/enums/stats`) learn 15% faster, from any session |
| Wrestling | His Wrestling stats learn 15% faster |
| BJJ | His Grappling stats learn 15% faster |
| Motivator | Training tires him 10% less, and a party animal skips half as many sessions |
| Tactician | Your calls reach him a quarter sooner (0.6 s → 0.45 s for a fresh fighter) |

The specialty lives on the career's `TrainingCamp` (`coach_specialty`), so it works between fights and in the camp alike. A
Tactician's call delay goes into the fight profile's `condition` (`call_delay`, `docs/09`), which `FighterState` reads, so a
fight still replays from its profiles. Fights without a career coach don't change (no golden re-pin). The hub's top bar says
who coaches him and the specialty ("coached by Sam Reed (Tactician)"), and his card says what it does. *Roll everything*
rolls a background and a specialty too. A career saved before D311 loads with a coach who has neither (the save stays
career@1: the new fields are optional).

Kyle's question on the plan was whether these numbers are right (Q8); they're my picks until he answers. The coach's own
levels (Clarity, Reading, Corner work, Motivation, Network, `02` §5) and the coach's look come later (phase 4, and with the
visual work).

**What to change:** the specialties' numbers and words in `sim/world/coach.gd` (`GROUP_XP`, `MOTIVATOR_FATIGUE`,
`MOTIVATOR_SKIPS`, `TACTICIAN_DELAY`, `SPECIALTIES`, `SPECIALTY_GROUPS`); the coach backgrounds in
`data/enums/coach_backgrounds.json`; where training reads them in `sim/world/training_camp.gd` (`learning`, `skip_chance`,
`_add_fatigue`, `fight_profile`); the call delay in `sim/fight/live_calls.gd` (`delay_ticks`); the screen in
`ui/new_career_screen.gd`, the hub in `ui/career_hub.gd` (`coach_text`, `fighter_card_text`). Tests:
`tests/sim/world/test_coach.gd`, `tests/sim/fight/test_live_calls.gd`, `tests/ui/test_career_screens.gd`,
`tests/data/test_data_files.gd`. Then update this section and D311.

### 11.2 His childhood (D312)

Before he's 16 he's a boy (D8, D83, `02` §1.1). A new career now plays three short scenes from his childhood, at about 8, 12
and 15, and what he chose in them makes him. *Play his childhood* on the new-career screen is ticked by default; *Start
career* becomes *Play his childhood* and opens the scenes (`ui/childhood_screen.gd`). Untick it to pick his background from
the list and start straight away, as before (plan Q2, Q4).

**The scenes** are text on a corner-board card (Q5), in `data/vignettes/` (`docs/09` vignette@1), four written for each age
(12 in all), so a career draws one per age from its seed (`Childhood.draw`) and two careers seldom grow up the same (Q3).
Each has three choices; pick one and a line says what came of it, then *Next*. Back goes to the new-career screen with what
you'd filled in kept; Esc does too.

| Age | The scenes |
|---|---|
| 8 | The flyer on the fridge, The walk home, Saturday mornings, The long summer |
| 12 | Tryouts, The older kids, Summer money, The test |
| 15 | The fight on TV, The party, The injury, The trip |

**What a choice does** (`sim/world/childhood.gd`):

- **Background.** Each choice leans 3 toward one of the 12 backgrounds (`data/backgrounds/`). The one with the most weight is
  his background; a tie goes to the one chosen later. So three different choices make him what he chose at 15, and two
  choices the same way make him that whatever the third was. Every background can come out of every age's scenes.
- **A bit of the runner-up.** The second background adds half a strength bonus (6 points) to its first two strengths (a
  mixed childhood feels mixed): "Street kid, with a bit of track star".
- **Stats and personality.** Each choice nudges two stats by 2 to 4 points and can nudge a personality axis by up to 15
  (on top of the background's own lean). Stats stay 5 to 100, personality −100 to 100.
- **His height.** A choice can lean his height (`height` −1 or +1: 4 cm, reach with it). None of the 12 scenes uses it yet.
- **People.** Some choices bring someone into his life: his dad who wrestled in college, the old trainer at the corner gym,
  the best friend he stood up for (Q13). Family share his surname, everyone's first name is from his country, and they go on
  his card on the hub ("Dad (Gary Hill): Wrestled in college and still talks about it."). A grandma goes by Grandma (the name
  lists are men's first names). They're only on his card for now; they come back in the story later (D316 and phase 3).
- **Money.** Summer jobs and the like add $150 to $400 to what his background starts him with.

After the third scene, **Who he became** shows his background and the flavour, the background's line and strengths, his
height and reach, the gifts and flaws that show, the people, the money he starts with and the hook, then *Start career*.
That's exactly the fighter the career starts with (`Career.start` with the scenes' picks and the same seed).

The career saves his childhood (`childhood`: the picks, the runner-up and the people, `docs/09` career@1; optional, so older
saves load with none). Fights don't change (no golden re-pin).

**Not yet:** a drawn header for each scene, gifts and flaws a choice can make likelier, and the people turning up again.

**What to change:** the scenes, their choices and what each does in `data/vignettes/` (a new file at age 8, 12 or 15 joins
that age's pool); the flavour, the height lean and the ages in `sim/world/childhood.gd` (`SECOND_SHARE`, `SECOND_STRENGTHS`,
`HEIGHT_PER_LEAN`, `AGES`); how a career starts from it in `sim/world/career.gd` (`start`); the screen in
`ui/childhood_screen.gd`, the toggle in `ui/new_career_screen.gd`, the flow in `game/main.gd` (`start_career`,
`open_childhood`), his card in `ui/career_hub.gd` (`fighter_card_text`). Tests: `tests/sim/world/test_childhood.gd`,
`tests/ui/test_career_screens.gd`, `tests/game/test_main_scene.gd`, `tests/data/test_data_files.gd`. Then update this
section and D312.

### 11.3 Your gym and the walk-in (D313)

You coach at a gym, and that's where he walks in at 16 (D37). Kyle (2026-11-01) picked **Yours** on the plan's card ("Whose
gym does he walk into at 16?"): you coach at a gym, picked from three in his hometown when he walks in, and the walk-in is
the scene where you meet him.

**Where you coach** (`ui/gym_screen.gd`) is the last step of a new career, after his childhood (§11.2) or straight after the
new-career screen when *Play his childhood* is unticked. It shows three gyms in his hometown side by side (`Gym.offers`):
three different kinds, and the first always suits where he comes from (a boxing gym for the boxing gym kid, a wrestling
club for the wrestling family's son). Each card has the gym's name, its kind and culture, what it trains better and worse,
the owner (named from his country, with a line about them) and the monthly fee. *Coach here* picks it.

**The walk-in** is that gym on the first Monday of January: the door bangs open, he walks in out of the cold, his
background's hook, whoever from his childhood sent him ("His dad, Gary Hill, told him to come here."), "I'm Danny Hill, I
want to fight," and the owner nodding at you from the office door. *Back* goes back to the three gyms; *Start career* starts
it. Back from the gyms (or Esc) goes to the new-career screen with what you'd filled in kept.

**What a gym does** (`sim/world/gym.gd`, `data/gyms/`, `docs/09` gym@1). Each of the five kinds changes the XP of each kind
of session (`data/sessions` `kind`; missing = no change):

| Kind | Session XP | Fee a month |
|---|---|---|
| BJJ academy | grappling ×1.25, mind ×1.1, striking ×0.75, wrestling ×0.9 | $60–90 |
| Boxing gym | striking ×1.2, sparring ×1.1, wrestling ×0.8, grappling ×0.7 | $35–55 |
| MMA gym | sparring ×1.1, mind ×1.05 | $70–110 |
| Muay Thai camp | striking ×1.2, conditioning ×1.1, wrestling ×0.8, grappling ×0.7 | $45–70 |
| Wrestling club | wrestling ×1.25, conditioning ×1.1, striking ×0.75, grappling ×0.9 | $25–45 |

Each gym also has one of three cultures (`data/enums/gym_cultures.json`): a **family gym** (a party animal skips a quarter
less), **hard sparring** (sparring XP ×1.2, injuries ×1.5) or a **party gym** (skips ×1.5). The fee comes out of his savings
on the first Monday of every month, as much of it as he has (never below $0).

**Working it off** (Kyle, 2026-11-01: "chances to work at the gym for his monthly pay"). What he can't pay he owes, and the
owner gives him shifts: from the next week his Saturday (both sessions) is a *Gym shift* (cleaning the mats, the front desk;
no XP, a little fatigue, done even when he's hurt) at $15 a shift, until it's paid. The week it starts is news (*Advance*
stops on it). Camp weeks don't have shifts: what he owes waits until the camp's over.

The hub says where he trains, the fee beside his savings, what he owes and that he's working Saturdays, and what he paid or
worked off in *Last week*.

The gym lives on the career (`gym`, `docs/09` career@1; optional, so a career saved before D313 loads with no gym, which
trains as before and pays nothing) and on its `TrainingCamp` (`gym`), so it counts between fights and in the camp alike.
Fights and the camp planner outside a career don't change (no golden re-pin).

**Not yet:** changing gyms, the gym's other fighters as sparring partners and rivals, shifts for money when he doesn't owe
anything, and a fee that grows with the gym (phase 4, `02` §5). Amateurs earn nothing yet, so most fighters end up working
Saturdays within a few months.

**What to change:** the kinds, their XP, fees, names, owners and the backgrounds they suit in `data/gyms/`; the cultures
in `data/enums/gym_cultures.json`; how many gyms are offered (`OFFERS`) and how they're rolled in `sim/world/gym.gd`; where
training reads them in `sim/world/training_camp.gd` (`_run_slot`, `skip_chance`, `injury_chance`); the fee in
`sim/world/career.gd` (`end_week`) and the shifts in `run_week`, their pay and day in `sim/world/gym.gd` (`SHIFT_PAY`,
`SHIFT_DAY`, `with_shifts`) and the shift itself in `data/sessions/gym_shift.json`; the screen and the walk-in's words in `ui/gym_screen.gd` (`gym_text`, `walk_in_text`);
the flow in `game/main.gd` (`start_career`, `open_gym`); the hub in `ui/career_hub.gd`. Tests: `tests/sim/world/test_gym.gd`,
`tests/ui/test_career_screens.gd`, `tests/game/test_main_scene.gd`, `tests/data/test_data_files.gd`. Then update this
section and D313.

### 11.4 School weeks and local cards (D314)

The teen amateur stage of `08` §2: school, local shows and the word on turning pro.

**School weeks.** Until his 18th birthday a week in term time isn't all his. School takes the five weekday mornings and
homework two evenings (Tuesday and Thursday), so he trains Monday, Wednesday and Friday evenings and Saturday: 5 of the 12
sessions (plan Q9; Kyle, 2026-11-01: "Mornings and two evenings"). In the summer holidays (a week whose Monday is in July
or August) every session is his, which is when a long camp pays most. The slots are taken whatever the plan says: the
hub's weeks and a fight camp both lose them, and the camp planner shows them as *School* and *Homework* tiles that can't
be changed or played (the `school` and `homework` sessions: no XP, no fatigue). That's too few sessions for even a week
all out to wear him down. The week school breaks up, the week it starts again and the week he leaves it for good are
news, so *Advance* stops on them, and the calendar shows them coming. The hub says what this week is: "School week:
weekday mornings at school and homework on Tuesday and Thursday evenings, so he trains 5 of the 12 sessions" or "Summer
holidays: every session this week is his". He leaves school on his 18th birthday (no exams or sixth-form years), and a
career saved before D314 gets its school weeks as it loads: they're worked out from the calendar and his age, so nothing
new goes in the save.

**Local cards.** Every amateur offer is on a named local show, "Leeds Fight Night 4 · the Sports Centre, Leeds": 60% in his
hometown, the rest in another city of his country, and the man he's offered is a local lad (from his country). A series
keeps its venue, and its number goes up one every 8 weeks, so the same show comes round again. The card is on the offer,
on the booked line (*Booked: vs Lee Kelly, Sat 27 Feb 2027 on Leeds Fight Night 4*), on the camp's countdown and on the
fight in his record. Pro offers aren't on cards yet (phase 3's promotions).

**The word on turning pro** (`08` §2: "the game recommends it based on record + skills"). From 18, while he's amateur,
the hub says one of:

| Word | When |
|---|---|
| Not yet | Fewer than 4 amateur fights: he can turn pro after N more |
| Risky | He's won under 60% of his decided amateur fights, or his stats average under 38 (a C; a top prospect is 45 at 18, `02` §3.8) |
| Wise | He's won 60% or more and his stats average 38 or more |
| Time to turn pro | As *wise*, from 22: every year he waits is a prime year gone |

It's advice only: *Turn pro* still works whenever `can_turn_pro` allows it (18, four amateur fights).

His amateur record was already on the hub's top line; medals come with the one-day tournament (D315, §11.5).

**Not yet:** exams, a part-time job, school events and parents having a say (phase 5's life events), holidays other than
the summer, and the advice changing his first pro contract (phase 3, `08` §2's "pro hype").

**What to change:** which slots school takes, the holidays and when he leaves in `sim/world/school.gd` (`MORNINGS`,
`EVENINGS`, `HOLIDAY_MONTHS`, `LEAVES_AT`) and the slots themselves in `data/sessions/school.json` and `homework.json`; how a week runs taken slots in
`sim/world/training_camp.gd` (`taken`, `with_taken`); the events in `sim/world/career.gd` (`SCHOOL_OUT`, `BACK_TO_SCHOOL`,
`LEFT_SCHOOL`, `_events_since`, `calendar`, `_school_week`). The cards' names, venues, home share and how often the number
goes up in `data/cards/local.json`, and how a card is made in `sim/world/matchmaker.gd` (`local_card`, `SERIES_START`); the
word on turning pro there too (`pro_advice`, `PRO_WIN_SHARE`, `PRO_READY_AVG`, `PRO_LATE_AGE`). The hub in
`ui/career_hub.gd` (`week_text`, `offer_text`, `fights_text`), the planner's tiles in `ui/camp_planner.gd`. Tests:
`tests/sim/world/test_school.gd`, `tests/sim/world/test_matchmaker.gd`, `tests/data/test_data_files.gd`. Fights don't change
(no golden re-pin). Then update this section and D314.

### 11.5 The one-day tournament (D315)

`08` §2's "a one-day bracket of 2–3 short fights, with damage carrying over between them" (plan Q10: a tournament every 3 to
4 months, 2 or 3 fights, damage carrying over, medals on his card).

**When.** While he's amateur, from his 12th week and then every 13 to 17 weeks, one offer in a set of offers is a
tournament instead of a single fight. Turn it down and the next one still comes 3 to 4 months later. Pros don't get them.

**Two sizes** (Kyle, 2026-11-01: "Either, depending on the event"). A local open is four men:
a semi-final and the final, named from `data/cards/open.json` (*Leeds Amateur Open 2027 · the Sports Centre, Leeds*; 70% in
his hometown). A regional championship is eight men: a quarter-final, a semi-final and the final, from
`data/cards/championship.json` (*Leeds Regional Championships 2027 · the Arena*; 40% at home, so more often away). Each is
half the time. A tournament is named by its year, not numbered like the local shows.

**The men.** The man he'd meet in each round is made when the offer comes, each a different style and each harder than the
last: an eight-man bracket goes easier, even, harder, and a four-man one even, harder. The later men have had fights of
their own that day, so they go in with less gas tank: 92% in the second round, 85% in the third. The offer's card shows the
first man (scouted as usual), how many men, how many fights and that the damage carries.

**The day.** The camp builds to fight night as for any fight. Each win takes him to the next round the same day: the result
screen says *Through to the final against Ryan Hart, later today. He goes in with 80% of his gas tank, still hurt: head 21%*
and offers *On to the final* or *Pull out*. He goes in with 70% of each area's damage from the last fight still on him and his
gas tank 10 points smaller for each fight he's had (never under the camp's floor, 50%). The first fight's camp injury is rolled
once, on the first fight. A simmed first fight sims the rest too. A loss or a draw puts him out (amateur tournaments need a
winner; a draw goes to the other man). The week ends when his day does. If the game's closed between rounds, the save
carries on from the next round: Go to camp goes straight to fight night, where *Fight!* takes him into the next round as
the last fight left him, and *Pull out* is pulling out of the tournament.

**Medals.** Gold for winning it, silver for losing the final (or pulling out before it), bronze for losing a semi-final he
won a quarter-final to reach (both of an eight-man bracket's semi-final losers get one, as in real amateur tournaments). A
four-man open's semi-final losers get nothing: otherwise every man in it would go home with a medal. Medals go on his card on
the hub (*Medals: gold, Leeds Amateur Open 2027*), and the fights list shows each fight's round and any medal. Every fight
of the day goes on his record.

**The suspension** is the day's worst, from the end of it: a hard semi-final he won still keeps him out 21 days after the
final.

**Not yet:** seeing the rest of the bracket (the other men's fights), weigh-ins and weight classes, a ruleset with shorter
tournament rounds, team scoring for his gym and a medal table on the hub.

**What to change:** the sizes, how often, the men's difficulty and tiredness, what carries and the medals in
`sim/world/tournament.gd` (`SIZES`, `BIG_CHANCE`, `FIRST_WEEK`, `GAP_MIN`, `GAP_MAX`, `DIFFICULTIES`, `OPPONENT_TANK`,
`CARRY_HURT`, `TANK_PER_FIGHT`, `medal`); the names, venues and home share in `data/cards/open.json` and
`championship.json` (docs/09 cards@1's `size`); how the offer's made in `sim/world/matchmaker.gd` (`make_tournament`); the day
in `sim/world/career.gd` (`_check_offers`, `accept`, `finish_fight`, `withdraw`, `round_profile`); the result screen's
buttons and lines in `game/main.gd` (`_finish_career_fight`, `tournament_text`, `next_tournament_fight`,
`withdraw_from_tournament`); the hub in `ui/career_hub.gd` (`offer_text`, `week_text`, `fights_text`, `medals_text`). Tests:
`tests/sim/world/test_tournament.gd`, `tests/game/test_main_scene.gd`, `tests/data/test_data_files.gd`. Fights don't change
(no golden re-pin). Then update this section and D315.

### 11.6 The story as the tutorial (D316)

`07`'s rule: the story is the tutorial, one idea at a time. Kyle (2026-11-01) answered the three questions that shape it:
"Fight things only", "One lesson fight per offer set" and "A card that waits for Got it".

**The three lesson fights.** A new career's first three fights are its lessons (`sim/world/tutorial.gd`), counted by fights
he's had, whoever they were against:

| Lesson | Calls open | Also |
|---|---|---|
| 1 | Pressure! (1), Circle out! (2), Takedown! (4), and on the same keys Ground and pound! and Go for the finish! on top, Finish it! and Defend the sub! in a hold (as the first Playtest fight, `07` §3) | No tell cue; the round break is just the cards |
| 2 | + Catch the kick! (Q) | The tell cue (his leg glows before a kick) |
| 3 | Every call | Drilled rules and the gameplan open, on the fight night card and at the round break |

Only fight things are held back: the hub, the camp, the week plans and mitt work are open from the start, each with a tip.

**The Coach's pick.** Each of his first three sets of offers has a lesson fight in first place, marked *Coach's pick* with
why: a man a bit easier than him to learn the calls on, then a kicker (the Catch the kick! fight), then a man about his
level. The other offers are rolled as usual, so he can take someone else; the lessons still go by fight count.

**Tip cards.** The first time each part of the game comes up a card of one or two sentences shows over it, and the screen
waits until *Got it*: his week on the hub, the first offers, a tournament offer, the camp and mitt work, fight night, each
lesson fight (its card opens the fight, the clock held, as the Playtest tips do), the first round break, his first loss,
his first suspension and the first time he works at the gym. A simmed fight skips its card (nobody's watching) and keeps it
for the next. Several due at once come one after another. The tips are in `data/tips/` (`09` tip@1), so their words can be
changed without code. Every tip he's seen goes in the **Coach's Notebook**, a button on the hub's top bar, to read again.

**I know the game**, a tick box under your specialty on the new-career screen, turns it all off: every call from his first
fight, no tips and no lesson fights, and every tip in the Notebook. A career saved before D316 loads with it off.

**Not yet:** a gentle review of a loss from the feed (`07` §2), film study and the first tell in training (step 6), the
corner screen's water and motivation (step 5), Easy's suggested call, a weight-cut and contracts lesson after fight 3
(phase 3), and tips for submissions, cuts and fouls the first time they happen in a fight.

**What to change:** which calls each lesson opens, the tell cue and when rules and the gameplan open in
`sim/world/tutorial.gd` (`FIRST_CALLS`, `SECOND_CALLS`, `tell_cue`, `plan_open`), the lesson fights there too (`LESSONS`,
`KICKER_STYLES`) and how they're made in `sim/world/matchmaker.gd` (`make_lesson`) and placed in `sim/world/career.gd`
(`_check_offers`); the tips' words, places and order in `data/tips/`, the places in `Tutorial.PLACES`, where they're shown
in `game/main.gd` (`show_hub`, `open_career_camp`, `_career_camp_week`, `_career_settings`, `_on_round_over`,
`_on_fight_over`, `show_career_tips`) and the card in `ui/tip_card.gd`; the Coach's pick's words in `ui/career_hub.gd`
(`LESSON_TEXT`); the tick box in `ui/new_career_screen.gd`. Tests: `tests/sim/world/test_tutorial.gd`,
`tests/game/test_main_scene.gd`, `tests/data/test_data_files.gd`. Fights don't change (no golden re-pin). Then update this
section and D316.

## 12. A world to climb (D350–D359)

Phase 3 of the plan (§10, D300). Kyle (2026-11-01): "We can start planning phase 3". Today every opponent is made for one
offer and nobody else fights; phase 3 fills six weight divisions (D56) with about 100 named men each (D55) who keep fighting
each other, with promotions, rankings and belts to climb. The plan and its 10 questions are in the phase 3 plan doc (https://claude.ai/artifact/EgqAcbosfRoFa46UCERW5i); my picks
are built until Kyle answers. Nine pieces, in this order (D350), each playable when it lands:

| Piece | Decision | Status |
|---|---|---|
| Weight divisions: a walk-around weight, growing into his natural division by about 21 | D351 | Planned |
| The world's fighters: about 100 named men a division, from local amateurs to world class; offers come from them | D352 | Planned |
| The world's weeks: the other men fight about 3 times a year, age, retire, and new prospects join each January | D353 | Planned |
| Promotions and their cards: 3 or 4 regional pro promotions and 2 international organisations, made up each career (D57) | D354 | Planned |
| Rankings: each organisation's top 15, updated weekly, each move with its reason (A10) | D355 | Planned |
| Titles: belts, 5-round title fights, defences, vacating | D356 | Planned |
| Climbing the ladder: call-ups to the bigger promotion, title eliminators; fight-by-fight deals until phase 5 | D357 | Planned |
| A history before day one: the world played 5 years before his career starts | D358 | Planned |
| The 30-year check: a tool and a test that the world stays healthy (A10) | D359 | Planned |

**The world's other fights** are decided by a quick result model, not the fight engine (Kyle, 2026-11-01: "A quick result model"; this changes A9's middle tier). The
engine takes about 0.6 s a fight (94 µs a tick, 2026-11-01), so 600 men fighting 3 times a year would cost about 9 minutes a
career year. The model takes each man's level, the style matchup edge from the balance harness (every style against every
style, saved as data), and small nudges for age, form, damage and ring rust; how a fight ends and in which round come from
what the harness saw for that pair of styles. A tool rebuilds the matchup data when fights change, and a test checks the
model's win shares sit inside the harness's 95% ranges. His own fights stay on the engine.
