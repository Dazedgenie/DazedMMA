# 03 — Career, World & Life

> Related decisions: D7, D16–D19, D21, D22, D25, D35, D41–D45, D55–D57, D160, D300–D316, D350–D359, D400–D419, D440–D459. Status: **design draft**; §7.1 and §10.1–§10.5, §11 and §12 (D350–D359) are built; §13 (phase 4) is being built (§13.1 and §13.2 so far).

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
| **Volume striker** (D495, 2026-11-05) | `volume_striker` | Boxing gym kid, street kid | A busy southpaw who walks you down to the fence and never stops punching (Pace +80, Cardio 80, Chin 72, Power 45): jab, cross, hooks, the rear-hand body hook, and a hand on your head on the fence to dig to the body (the head post, `01` §47); tell: body hook after a blocked jab |

Every sheet uses the same variation for now: stats ±6, leanings ±12, move preferences ±20%, personality ±30, height ±4 cm.
Check that a sheet's opponents fight in style with `tools/style_sheets.gd -- --fights=30` (prints the scouting cards, then
a table of win rate against the other styles' signature fighters, finishes, output, shots, submissions, clinch and ground time).
Kyle picked "recipe + scouting card" and all 15 styles (the first 10 plus five extras) on 2026-10-29; the Volume striker made 16 on 2026-11-05 (D495). Run with all 15
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

*Its look was rebuilt in D434 (`06` §6.14): the title over a real fight with the menu down the left, the new-career page with him in the middle and the backgrounds as tiles, and the load slots with his face. What's on each screen is as below; §6.14 is how it looks.*

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
**His look** (D365, Kyle: "You pick for your own fighter"; `docs/13` §Fighters who look different): under Stance, seven
skin-tone swatches and drop-downs for his hair colour, hair (short, buzzed or shaved) and beard. *Roll everything* rolls them
for his hometown's country. He's drawn with it in every fight; the world's men get theirs from where they're from.
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

*Its look was rebuilt round the next fight in D433 (`06` §6.13): the same parts, laid out with his card on the left (About
and Stats on tabs), the offers as posters or the booked fight counting down in the middle, the news and his fights on
the right, a tab bar along the top and icons on the calendar. The list below is what's on it; §6.13 is where.*

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

**Who's offered.** Each offer is a new man made from one of the 16 style sheets (`StyleLibrary.generate`, §7.1), a
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
carries on, the fight week ends and the career saves. The result screen says what it did to his record and his money (since
D436 on its own *What it means* card with his rank, a belt, a promotion move and the suspension: `docs/06` §6.16), and
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

**Not yet:** a doctor's check that can lengthen a suspension (named injuries from a fight are built: §13.10, D406), and the AI corner coaching a simmed fight for him (D113).

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

*Since D434 (`06` §6.14): him at that age beside each scene.*

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

*Since D434 (`06` §6.14): each gym a card with its owner's face and what it trains as chips, and him in a lit doorway at the walk-in.*

*Since D441 (§14.1): the gym is yours. The three gyms are three run-down places you could open, the owner is the man you take it over from, the gym has its own money from members' dues and 15% of his purses, and his monthly fee and the Saturday shifts are gone. What follows is how it worked before that, apart from the kinds and cultures, which still work as written.*

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
each other, with promotions, rankings and belts to climb. The plan and its 10 questions are in the phase 3 plan doc (https://claude.ai/artifact/EgqAcbosfRoFa46UCERW5i); Kyle
answered all ten on 2026-11-01, taking my pick on eight. He also picked all 6 divisions at about 100 men, local men at home and the
hotbeds at the top, each organisation's own top 15, about 3 fights a year (champions 2), and grounded, plausible promotion names. Nine pieces, in this order (D350), each playable when it lands:

| Piece | Decision | Status |
|---|---|---|
| Weight divisions: a walk-around weight, growing into his natural division by about 21, moved one up or down at his pro debut if you like (Kyle, 2026-11-01: "Grows into it, move at debut"; refines D35) | D351 | Built (§12.1) |
| The world's fighters: about 100 named men a division, from local amateurs to world class; offers come from them, and the local lads he meets as an amateur are real men who can turn pro alongside him (Kyle, 2026-11-01: "Yes, amateurs in the roster") | D352 | Built (§12.2) |
| The world's weeks: the other men fight about 3 times a year, age, retire, and new prospects join each January | D353 | Built (§12.3) |
| Promotions and their cards: 3 or 4 regional pro promotions and 2 international organisations, made up each career (D57) | D354 | Built (§12.4) |
| Rankings: each organisation's top 15, updated weekly, each move with its reason (A10) | D355 | Built (§12.5) |
| Titles: belts, 5-round title fights, defences, vacating | D356 | Built (§12.6) |
| Climbing the ladder: call-ups to the bigger promotion, title eliminators, and asking for a step up from the hub at a risk of a tougher fight or a no (Kyle, 2026-11-01: "Call-ups plus asking for it"); fight-by-fight deals until phase 5 | D357 | Built (§12.7) |
| A history before day one: the world played 10 years before his career starts, so there are long records and some retired legends (Kyle, 2026-11-01: "10 years") | D358 | Built (§12.8) |
| The 30-year check: a tool and a test that the world stays healthy (A10) | D359 | Built (§12.9) |

**The world's other fights** are decided by a quick result model, not the fight engine (Kyle, 2026-11-01: "A quick result model"; this changes A9's middle tier). The
engine takes about 0.6 s a fight (94 µs a tick, 2026-11-01), so 600 men fighting 3 times a year would cost about 9 minutes a
career year. The model takes each man's level, the style matchup edge from the balance harness (every style against every
style, saved as data), and small nudges for age, form, damage and ring rust; how a fight ends and in which round come from
what the harness saw for that pair of styles. A tool rebuilds the matchup data when fights change, and a test checks the
model's win shares sit inside the harness's 95% ranges. His own fights stay on the engine.

### 12.1 Weight divisions (D351)

Every fighter now has a weight and a division (Kyle, 2026-11-01: "Grows into it, move at debut"; refines D35). The six
men's divisions (D56) are data, `data/divisions/` (docs/09 division@1): Bantamweight 61.2 kg (135 lb), Featherweight 65.8 kg
(145 lb), Lightweight 70.3 kg (155 lb), Welterweight 77.1 kg (170 lb), Middleweight 83.9 kg (185 lb) and Light heavyweight
93.0 kg (205 lb). Heavyweight comes after launch.

- **His grown weight.** What he'll walk around at once he's filled out at 21 comes from his height and build (a body-mass
  index of 23.5 lean, 25 average or 26.5 stocky at 70 kg, rising 0.06 for every kg over), give or take 4% of his own, rolled
  once when the career starts and kept as the fighter's `frame.adult_kg`. A 175 cm average build is about 78 kg.
- **Growing into it.** At 16 he walks around at 88% of it, rising evenly to all of it at 21.
- **His division** is the lightest whose limit he can make with a normal cut, 12% of what he walks around at (the cut itself,
  and what a bigger one costs, is phase 4). His *natural* division is the one his grown weight makes. Over the heaviest, he's
  a light heavyweight.
- **As an amateur** he fights at whatever division his weight makes that year, so a growing lad moves up a division or two.
- **At his pro debut** you pick his division beside *Turn pro*: his natural one (picked to start with), one lighter (a bigger
  cut) or one heavier, and he stays there (the career's `division`). A pro saved before D351 gets his natural division.
- **His opponents** are made to fit his division: each walks around somewhere in the division's band, with a grown weight to
  match his age and a height (±3 cm) that goes with that weight and his style's build; his reach keeps his ape index.
- **On screen.** The hub's fighter card says what he walks around at, the division he fights at (with its limit in kg and
  lb), and while he's growing the division he's growing into. Who he became says his weight at 16 and the division he'll
  grow into. Each offer says the opponent's weight and "A lightweight bout". The tale of the tape has a WEIGHT row in a
  career fight. Weights are in kg, with the divisions' limits in kg and lb as well.

Fights don't read weight, so no fight changes (no golden re-pin); generated opponents' heights now follow their weight.

**To change it:** the divisions in `data/divisions/`; the numbers at the top of `sim/world/weight.gd` (`BUILD_BMI`,
`BMI_PER_KG`, `PERSONAL_SPREAD`, `GROWN_AT`, `SHARE_AT_16`, `CUT`, `FIT_BAND`, `FIT_HEIGHT_SPREAD_CM`); the choice at the debut
in `Career.turn_pro` and `CareerHub` (`_pro_division`, `weight_text`); opponents in `Matchmaker.make_offer`. Tests:
`tests/sim/world/test_weight.gd`, `tests/ui/test_career_screens.gd`, `tests/data/test_data_files.gd`. Then update this
section and D351.

### 12.2 The world's fighters (D352)

The men he meets are now the world's men, not made for one offer and gone. Kyle (2026-11-01) picked a pyramid of levels
("A pyramid"), rematches after a while ("Rematches after a while") and a list of his division on the hub ("A division list
on the hub"), and earlier the local lads among them ("Yes, amateurs in the roster") and local men at home with the hotbeds
at the top ("Home locally, hotbeds at top").

- **About 100 men a division**, 600 in all, made the first time the career needs them from its seed and his home, and
  kept in the save (a career saved before D352 makes its world when it next needs it). The same career makes the same men.
- **The pyramid**, in each division: 25 amateurs, 20 local pros, 30 regional pros, 18 national-level pros and 7
  world-class pros, times the division's size since D359 (§12.9: lightweight 1.25, light heavyweight 0.75), and each man
  is fitted to his division by his grown weight. A pro's average stat is 38–50 local, 46–58 regional, 55–67 national-level and 64–80 world class; an
  amateur's comes from his age, about 28 at 16 and 2.5 more a year (give or take 6). Amateurs are 14 to 22 and lean
  young; pros are 20 to 35, the best a little older.
- **Where they're from.** Every amateur is from his country, half of them his hometown. Of the pros, 75% of the local
  ones are from his country, 45% of the regional ones, 25% of the national-level ones and 10% of the world-class ones;
  the rest come from anywhere, the hotbeds most. Each country (`data/names`, names@1) has a `hotbed` weight (the United
  States 5, Brazil and Russia 4, the rest 2) and the `styles` it's known for, two and a half times as common there
  (Brazil's jiu-jitsu and Muay Thai, Russia's sambo and wrestlers, the Netherlands' kickers).
- **Each man** is a style, his own seed and a level (StyleLibrary.generate), a name nobody else in the world has, an age, a
  body made to fit his division (Weight.fit) and a record. Most haven't a nickname: a fifth of amateurs, rising to three
  quarters of the world-class men. His division is whatever his weight makes at his age, so a growing lad moves up.
- **Records** are a stand-in until the world's history (D358): about 3 fights a year since 16 for an amateur and 2.5 a
  year since about 21 for a pro, won at his level's rate (35–65% for a local pro up to 78–95% world class).
- **His offers are these men.** Each offer looks in his division for a man of his kind (an amateur while he is one, a pro
  once he's pro; 16 or 17 while he's a teenager), as good as the offer says (his average stat, 5 less for an easier
  fight and 5 more for a harder one, give or take 2), not in another offer and of a style none of them has. A year he's
  outside 3 younger to 4 older counts as a point off. Any man within 2.5 points can be picked; else the closest within
  4; else a new man joins the world (a newcomer, at the level the offer needs). Lessons and tournaments pick the same way.
  The offer shows his record.
- **His fights go on their records**, the other way round, and he can't be offered again for a year, or 16 weeks after
  a close fight (a draw, or a split or majority decision).
- **His division** is a button on the hub's top bar: the men in his division this week, the ones he can be offered
  first (amateurs while he's one), best first by the scouts' grade, each with his age, hometown, level, record, style
  and how it went if he's fought him. A man he's fought in the last 26 weeks stays on it even when one of them has grown
  into the next division since ("now welterweight"; D359, `CareerHub.MET_LATELY_WEEKS`).

From D353 the men fight each other too, get better and older, turn pro and retire (§12.3). Fights don't change (no
golden re-pin).

**To change it:** the pyramid, ages, levels, home shares, records and nicknames in `World.LEVELS` and the numbers at the
top of `sim/world/world.gd` (`PER_DIVISION`, `AMATEUR_AVG_*`, `HOMETOWN_SHARE`, `HOME_STYLE_WEIGHT`, `REMATCH_WEEKS`,
`CLOSE_REMATCH_WEEKS`); each country's `hotbed` and `styles` in `data/names/`; how a man is picked for an offer in
`Matchmaker.pick_man` (`AGE_PENALTY`, `PICK_WITHIN`, `NEWCOMER_PAST`); the list in `CareerHub.division_text` and its page
in `game/main.gd` (`open_division`, `DIVISION_WIDTH`). Tests: `tests/sim/world/test_world.gd`,
`tests/ui/test_career_screens.gd`, `tests/game/test_main_scene.gd`, `tests/data/test_data_files.gd`. Then update this
section and D352.

### 12.3 The world's weeks (D353)

The world's men now live between his fights. Every Saturday the men who are due a fight fight each other, decided by the
quick result model (D350); they get better while they're young and slower when they're old, wins build them up and
knockouts wear them down, the good amateurs turn pro, men retire when they're too old and new ones join. Kyle
(2026-11-01) picked "Wins and losses change them too", "When they're ready, 18 to 23", "Only when they're too old" and
"Results in his division on the hub".

- **The weeks catch up when the career needs the world.** The world remembers the last Saturday it played (`played`);
  each time the hub, an offer or a fight needs the world, it plays every Saturday up to last week's. A world saved before
  D353 starts from the week it's loaded. The man booked to fight him, and the men in his offers (and a tournament's later
  rounds), don't take other fights.
- **About 3 fights a year** (Kyle's earlier pick, "3 a year, champions 2"; champions come with titles, D356). After a fight
  a man is due again in 15 weeks, give or take 5 (17 until D354, when pros started waiting for their promotion's
  next card); 8 more after being knocked out, 2 more after being submitted. Each
  week, in each division, the due men are paired with a man of the same kind (amateurs with amateurs, teenagers with
  teenagers, pros with pros) whose average stat is within 5, one more for every week the first has waited, and whom he
  hasn't met in a year. Nobody fights before 16.
- **Who wins** is the result model: the logistic of the styles' edge at an even level, plus `per_point` for every point
  of average stat he's better, plus his form (0.08 for each of his last 3 fights won, taken off for each lost) and rust
  (0.2 off after a year out). How it ends and which round come from what the engine did for those two styles (the
  winner's style's wins and the loser's style's losses by each method, averaged). Results go on both records.
- **The matchup table** is data, `data/world/matchups.json` (docs/09 matchups@1), made by `tools/matchups.gd`: every pair
  of the 16 styles (120 pairs since the Volume striker, D495; his 15 were played on their own with `--only=volume_striker` and merged in) plays 60 fights on the engine at an average stat of 55 give or take 6, the two up to 8
  apart, red and blue corners taking turns, on every core. It fits each pair's edge (pulled a little toward even) and the
  worth of a point together, and a test plays the most lopsided pair again and checks the model's share sits inside the
  engine's 95% range. Rebuild it whenever fights change (`godot --headless --script res://tools/matchups.gd --
  --fights=60`, about 17 minutes on 4 cores).
- **Getting better and older** (like his own fighter, D136). Each man has a potential, made once: his average now plus
  0.3 to 3.6 points (leaning low) for every year he's under 28, at most 84. Each year he closes 35% of the way to it
  under 18, 30% to 21, 20% to 25 and 10% to 28, and nothing more at 28 and 29; from 31 he loses 0.6 points a year, and
  1.5 from 34. A pro's level (local, regional, national-level, world class) follows his average stat.
- **Wins and losses change them too** (Kyle's pick). Every win adds 0.4 to his average stat and his potential for good
  (confidence and rounds in the bank). Being knocked out takes 0.8 off both, and 0.4 more for every other knockout loss
  in his last 4 fights. A decision or submission loss leaves him as he was. His last 3 results also nudge his next fight
  (form, above).
- **Turning pro.** An amateur turns pro within about half a year once he's 18, has had 4 fights, has won 55% of them
  and averages 38. At 23 he turns pro if he averages 34, or gives it up. A pro keeps his amateur record beside his pro one
  (which starts at 0-0-0), starts as a local pro, and his division is fixed from then on, like the career's fighter's.
- **Retiring only when they're too old** (Kyle's pick). Nobody retires before 32. From then a pro's chance of retiring
  in a year is 10% for every point his average stat has fallen from his best (the first point free), plus 40% when he's
  lost 3 of his last 4 and 25% after 2 knockout losses in them; at 45 he's done. So a man still at his best and winning
  keeps going into his 40s (a 10-year run had a 41-year-old world-class man at 38-2-2), and most go at 33 to 37. An
  amateur only gives it up at 23 (above). A retired man keeps his name, style, level and records (for the world's
  history, D358) and loses the rest; each January, retired amateurs who never turned pro and never fought him are let go.
- **New men.** The first week of every month each division's regional, national-level and world-class pros are topped
  back up to the pyramid's counts (§12.2) with men new to the division, and its local pros too while it has fewer pros
  in all than the pyramid's (the amateurs turning pro fill the bottom); each January its amateurs too, with lads of 14
  to 16 from home. With nobody retiring young, a division settles at about 110 men.
- **On the hub** (Kyle's pick, results in his division): under *This week*, AROUND THE <DIVISION> gives up to 4 lines from the
  weeks just run in his division: the men he's fought first ("who you beat", "who beat you"), then upsets (the winner
  had under 35% beforehand), first-round finishes, the best men (averaging 58 or more) and men of his kind. Men he's
  fought turning pro or retiring are news too. His division's list shows each man's record as it now stands.
- **The save** keeps the last 8 weeks of results and, on each man, his level to a fraction, potential, when he's next
  due, his last 6 fights, and when he turned pro or retired (docs/09 career@1 `world`). After 10 years it's about 610 KB.

**How healthy it is** (10 years from a fresh career on the shipped table, 2026-11-01): about 2.6 fights a man a year;
15 to 30 men turn pro and 35 to 90 retire a year (more as the first men age); 650 to 680 active men, 100 to 112 in the
lightweights, the pyramid's levels within a few men of their counts except about 8 extra local pros a division; the
best man averages 83 to 85; retired pros' median age 34, the oldest 42; a year takes about 0.4 s. The 30-year check
(D359, §12.9) watches it for 30 years.

**What the table says about the styles** (60 fights a pair, a point of average stat worth 0.32 on the logit, 0.4%
draws, 44% knockouts, 15% submissions, 41% decisions; the model inside the engine's 95% range for all 105 pairs): some
matchups are lopsided at an even level. The Karate point fighter beats the Dirty boxer about 97% of the time (an edge
of 3.6), and the Sprawl-and-brawl beats the Pressure wrestler, the Leg-kick specialist the Range kicker, the Karate point
fighter the Sambo leg-locker and the Counter-striker the Submission grappler about 92%. That's the engine's balance, which the world copies; a balance pass
on the styles would show up here when the table is rebuilt.

His own fights stay on the engine, so no fight changes (no golden re-pin).

**To change it:** the numbers at the top of `sim/world/world_weeks.gd` (`GAP_WEEKS`, `GAP_SPREAD`, `MATCH_GAP`,
`MATCH_WIDEN`, `KO_OUT_WEEKS`, `SUB_OUT_WEEKS`, `FORM_PER_RESULT`, `RUST`, `GROWTH`, `DECLINE*`, `HEADROOM`,
`POTENTIAL_MAX`, `WIN_GAIN`, `KO_WEAR*`, `PRO_*`, `RETIRE_FROM`, `FALLEN_FREE`, `TOO_OLD`, `BAD_RUN*`, `KO_RUN*`,
`RETIRE_BY`, `NEW_AMATEUR_AGES`, `HISTORY`,
`RESULTS_WEEKS`); the result model in `sim/world/result_model.gd` (`EDGE_PRIOR`, `METHOD_PRIOR`) and its table by
re-running `tools/matchups.gd`; when the world catches up in `Career.world`; the hub's lines in `CareerHub.news_text`
(`NEWS_MAX`, `UPSET_CHANCE`, `NEWS_BEST`). Tests: `tests/sim/world/test_world_weeks.gd`, `tests/data/test_data_files.gd`.
Then update this section and D353.

### 12.4 Promotions and their cards (D354)

Every career now has its own promotions, and the world's pros fight on their cards. Kyle (2026-11-01) picked "By
level", "Call-ups and cuts as they happen", "Regional ~every 7 weeks, bigger more", "Mostly home, sometimes others"
and "A Promotions button on the hub". The local amateur shows (§11.4) stay as they are.

- **Six or so promotions a career**, made once from the world's seed (data/world/promotions.json, docs/09
  promotions@1) and kept in the save. A career saved before D354 gets them, and its pros signed, when it's loaded.
  - *A world organisation* (rank 0): a card every 2 weeks, 12,000 to 20,000 seats, $12,000 to show and $12,000 to win,
    its home in a hotbed country, its cards round the hotbeds' cities.
  - *An international organisation* (rank 1): a card every 4 weeks, 4,000 to 9,000 seats, $4,000 and $4,000.
  - *3 or 4 regional promotions* in his country, the first in his hometown, each in another of its cities: a card every
    6 to 8 weeks, 800 to 4,000 seats, $750 to $1,500 to show and to win, 70% of cards at home.
  - *Names* are grounded and made up (Kyle's earlier pick): an organisation is a first word and a second ("Sovereign
    Fighting Championship", "Crown Fighting Alliance"); a regional one a pattern with its city or a word ("Iron MMA
    League", "Newcastle Combat Series", "Battle in Birmingham"). Each has a short name from its initials (SFC) and its
    cards are numbered on from where a promotion that's been going a while would be (SFC 84). A list of real
    promotions' names is never used.
- **Who's where: by level.** In each division the best 18 pros fight for the world organisation, the next 20 for the
  international one and the rest for the regional ones, each regional man to the one with fewest men in his division
  (his hometown's first). A new pro joins where his level puts him; an amateur turning pro starts regional.
- **Pros fight on their promotion's cards.** A pro due a fight waits for his promotion's next card and meets a man of
  his promotion and division there (amateurs still fight any Saturday). Each result says the card (NCC 14). About 2.5
  fights a man a year.
- **Call-ups and cuts as they happen.** Three wins in a row since he last moved and he's called up a rank, while the
  organisation has room in his division (fewer than its 18 or 20, plus 2); three losses in a row and he's let go a
  rank down. A move is news.
- **His pro offers** are on a regional promotion's card, fight by fight (until he's called up, §12.7), at its pay plus
  $250 more for each pro win: three in four on his home promotion's next card at least 5 weeks away (a camp can be up
  to a card's gap longer than usual), the rest on another regional promotion's card 5 to 8 weeks away. His opponent is
  any regional pro of his division (or a newcomer, who signs where the card is). Each offer says the card ("On Iron
  MMA League 41 · the Indoor Arena, Liverpool") and its pay.
- **On the hub.** A *Promotions* button on the top bar opens a page: each promotion, biggest first, with what it is,
  its home city, venue and seats, its pay, how many men it has (and in his division), a card every so many weeks,
  its next two cards (his own fight marked), and its last card's results in his division. *His division* shows each
  pro's promotion. The news says the card a result was on, and when a man is called up or let go (men he's fought
  first, and call-ups to the world organisation).

**How healthy it is** (10 years from a fresh career, 2026-11-01): about 2.5 fights a man a year; 50 to 100 call-ups and
40 to 60 cuts a year; after 10 years about 19 men a division in the world organisation, 22 in the international one and
about 12 in each regional one, their average stats in that order (about 63, 56 and 47 to 51 at lightweight); a year
takes about 0.65 s.

**To change it:** the promotions' names, sizes, pay and how often they run cards in `data/world/promotions.json`; who
goes where and the call-ups in `sim/world/promotions.gd` (`MAJOR_MEN`, `SECOND_MEN`, `CALL_UP_WINS`, `CUT_LOSSES`,
`CALL_UP_ROOM`, `FIRST_NUMBER_*`); the gap between fights in `WorldWeeks.GAP_WEEKS`; his offers in `Matchmaker`
(`pro_cards`, `HOME_OFFER_SHARE`, `purse_for`); the page in `CareerHub.promotions_text` and `game/main.gd`
(`open_promotions`). Tests: `tests/sim/world/test_promotions.gd`, `tests/sim/world/test_matchmaker.gd`,
`tests/data/test_data_files.gd`. Then update this section and D354.

### 12.5 Rankings (D355)

Every promotion now ranks its men in each division. Kyle (2026-11-01) picked "All of them", "Points from recent results",
"Slide after 6 months, out at 12", "Ranked men fight near their rank" and "Rankings page, numbers everywhere" (my pick on all
five). This is A10's explainable rankings (§9).

- **Every promotion's own tables.** The two organisations rank a top 15 in each division and each regional promotion a top
  10 (as far as its men go). The tables are worked out each Saturday after the world's fights: a promotion's afresh on
  its card weeks, and between cards only the men who've gone (retired, moved, a year out) come off, the men below move up
  and the next best fills the end.
- **Points from recent results.** Each pro fight gets points when it happens, kept with the man:
  - a win 10, plus up to 12 for beating a ranked man (all 12 for the table's #1, less down the table), times 1.3 for a
    knockout or submission;
  - a draw 4;
  - a loss 5 off, less for losing to a ranked man (1.5 off for losing to the #1), times 1.3 for being finished.

  His score is those points fading to nothing over 2 years. Points won in a smaller promotion count 0.4 in the next one
  up (0.16 two up), so a man called up starts low in the bigger table and climbs by beating its men. The best score is #1.
- **Out of action.** After 6 months without a fight his score shrinks 2% a week; after a year he's off the table until
  he fights again.
- **Day one** (until D358's 10-year history): each table is filled by level, the best man given 24 points as one recent
  win, the worst 4.
- **Ranked men fight near their rank.** When the world's men are matched (§12.3), two unranked men still go by level, but
  a ranked man goes by places in his table (2 points of average stat a place, an unranked man counting as just under
  the end), so the top 5 fight each other and #1 meets #2. About nine in ten fights between ranked men are within 3 places.
- **Every move has a reason.** Each table's last moves are kept ("Up 4 to #3, Obinna Eze: beat #6 Ryan Baker on the
  cards"; "Out (was #15), Dmitry Khamzatov: pushed out on others' results"; "out of action 7 months"; "called up to the
  Ascent Combat League"; "retired").
- **Him.** A pro fight of his on a promotion's card goes onto his points (the man he fought gets his too), and he's in
  that promotion's tables, in his division, from that Saturday.
- **On the hub.** A *Rankings* button on the top bar opens a page: his place (or that he isn't ranked yet), then each
  promotion's table in his division, biggest first (him picked out), and its last moves with their reasons (the
  shuffles on others' results counted, not listed). His card on the hub says where he's ranked. *His division* shows
  "#3 ACL"; offers say where the man is ranked; the news puts the numbers by names ("#2 Felipe Nunes beat #4 Bas
  Dekker"), says when a table has a new #1 and says every move of his.

**How healthy it is** (10 years from a fresh career, 2026-11-01): about 590 world fights a year have a ranked man in
them, and nearly nine in ten fights between two ranked men are within 3 places; most tables are full (25 to 36 of the 36,
the rest regional promotions short of 10 men in a division); the world organisation has a new #1 about 3 times a year in
each division (titles, D356, will steady the top); its top men are better on average than the men further down; a
year still takes about 0.75 s and fights a man a year stay about 2.5.

**To change it:** the points, fading, sliding and table lengths in `sim/world/rankings.gd` (`TOP_ORGANISATION`,
`TOP_REGIONAL`, `WIN_POINTS`, `RANKED_BONUS`, `DRAW_POINTS`, `LOSS_POINTS`, `LOSS_TO_RANKED_SHARE`, `FINISH_SHARE`,
`FADE_WEEKS`, `LOWER_SHARE`, `SLIDE_WEEKS`, `SLIDE_PER_WEEK`, `OUT_WEEKS`, `SEED_*`); matching by rank in `WorldWeeks`
(`pair_gap`, `PLACE_GAP`); the page and the numbers by names in `CareerHub` (`rankings_text`, `move_text`,
`his_rank_text`, `opponent_rank_text`, `_ranked_news`, `NEWS_TOP_RANK`) and `game/main.gd` (`open_rankings`). Tests:
`tests/sim/world/test_rankings.gd`. Then update this section and D355.

### 12.6 Titles (D356)

Every promotion now has a belt in each division. Kyle (2026-11-02) picked "Every promotion", "Best ranked man who's free",
"Stripped after a year out", "After one defence", "5 rounds, every title fight" and "At #1 or #2 in his promotion" (my
pick on all six).

- **A belt in every promotion's division.** The champion sits above the rankings (they're #1 to #15, or #1 to #10,
  below him). On day one (until D358's history) each promotion's best man in each division holds its belt, won a few
  months to a year and a half before, with up to 3 defences.
- **Title fights** are on the promotion's cards, 5 rounds (the pro rules' title rounds; the world's on the quick result
  model's 5-round spread), before the card's other fights:
  - a champion defends once 22 weeks have gone since his last title fight and he's fit, against the best ranked man of
    the table's top 5 who's due a fight, free (not booked to fight him) and hasn't met him lately: about twice a year;
  - a vacant belt goes to the two best such men;
  - a draw keeps the belt where it is.
  Beating the champion scores in the rankings as beating a #1. A champion only fights for his belt, and isn't called up
  or let go by the usual three-in-a-row.
- **Losing a belt without losing.** It goes vacant when the champion retires, leaves the promotion or division, or goes
  a year (52 weeks) without a title fight (stripped); and a regional or international champion who's defended it twice (once
  until D359, §12.9) is called up a rank (while there's room) and leaves it vacant. Each belt keeps its last 8 reigns.
- **His title fights.** Ranked #1 or #2 in the promotion of his last pro fight, when its champion is due to defend (or
  the belt's vacant), the first of his offers is the title fight: on the promotion's first card far enough off for a camp,
  against the champion (or the best other ranked man for a vacant belt), 5 rounds, paying double. Win it and he's the
  champion; as champion his only offer is his defence when it's due (22 weeks on), against the best ranked man who's
  free. A year without a defence strips him too. His call-up after two defences and the title eliminators: §12.7.
- **On the hub.** The rankings page puts each table's champion above it (since when, defences; vacant when it is), his
  card says when he's champion, *His division* says "champion, ACL", offers say when the man is a champion and a title
  fight says so ("Title shot: the IML lightweight title, 5 rounds, double pay"), his fights list marks title fights, and
  the news says title fights ("… to win the SFC lightweight title"), belts gone vacant and his own title won.

**How healthy it is** (10 years from a fresh career, 2026-11-02): about 90 title fights a year over the 36 belts (2.5 a
belt); about 48 new champions a year, about 28 belts left by champions called up and one or two by retirements, none
stripped; at most 2 belts vacant at once; the world organisation's lightweight reigns ran from 5 months to 2.5 years
with up to 5 defences; a year still takes about 0.75 s.

**To change it:** in `sim/world/titles.gd` (`DEFENCE_WEEKS`, `STRIP_WEEKS`, `CHALLENGER_FROM`, `CHALLENGER_DUE`,
`CALL_UP_DEFENCES`, `ROUNDS`, `TITLE_PAY`, `OFFER_FROM`, `PAST_KEPT`, `SEED_*`); title rounds in `data/rulesets/pro.json`
(`title_rounds`) and `game/main.gd` (`start_fight`); his offers in `Matchmaker.title_offer` (`TITLE_EVEN`); the hub in
`CareerHub` (`champion_line`, `his_rank_text`, `offer_text`, `_title_news`). Tests: `tests/sim/world/test_titles.gd`.
Then update this section and D356.

### 12.7 Climbing the ladder (D357)

He climbs the promotions now, from the regional cards to the international organisation to the world one. Kyle
(2026-11-02) picked "Like everyone: 3 wins or a defence", "An offer he can turn down", "A tryout fight on their card",
"By his rank, 3 months between asks", "Let go after 3 losses in a row", "#3 v #4, winner next in line" and "A line on
his card, ask on This week" (my pick on all seven).

- **Where he is.** He starts on the regional cards (D354's offers, mostly at home). Once he's signed by an
  organisation his offers are on its cards, against its men, at its pay; the world organisation is the top.
- **Called up like everyone else.** Three wins in a row since his last move, or two title defences as a champion (one until D359), and the
  promotion a step up offers to sign him: one of his offers is a *Call-up* on their card, against one of their men about
  his level. Take it and he's theirs from that moment (a belt he holds goes vacant); turn it down, or let it go, and he
  stays, asked again after his next fight if he still qualifies.
- **Asking for a step up.** *Ask the ACL for a step up* on This week. A yes is about 70% in his promotion's top 3 (a
  champion counts as #1), 30% in its top 10, 10% further down or unranked. A yes is a *Tryout* offer on their card against
  one of their men a bit better than him: win it and they sign him, lose it and he's back where he was with the loss on
  his record. A no means waiting 3 months to ask again. The answer shows on This week, and the date he can ask again.
- **Let go.** Three losses in a row in an organisation and he's let go a rank (the international organisation lets him
  go to his home promotion).
- **Title eliminators.** Between a champion's title fights, from 8 weeks after the last one and while nobody's next in
  line, the two best men of the table's #3 to #6 who are due and free fight a 3-round eliminator on the card. The winner
  is next in line: he sits out the other fights and gets the next title shot before anyone ranked higher (the champion's
  defence waits for him while he's hurt or booked), for up to 26 weeks, and no longer once he's left. Ranked #3 to #5,
  with a champion and nobody next, he's offered an eliminator against the best other free man of #3 to #6; win it and
  his title shot comes when the champion's next due, whatever his rank. A man next in line goes before his #1 or #2 shot.
- **On the hub.** His card has a *Ladder* line ("Regional (IML) · 2 of 3 wins in a row to a call-up to the ACL", "a
  call-up to the ACL after a title defence", "the top of the ladder", and how many losses in a row from being let go),
  and his rank says when he's next in line. Offers say *Call-up*, *Tryout* or *Title eliminator*; his fights list marks
  tryouts, eliminators, "signed up" and "let go"; the news says when he's signed or let go and when an eliminator's
  winner is next in line.
- **Fixed with it:** a man booked to fight him (or in his offers) no longer retires or turns pro before fight night,
  which could break the fight's result going onto his record.

**How healthy it is** (10 years from a fresh career, 2026-11-02): about 67 eliminators a year over the 36 belts, and
the winner got the next title shot 3 times in 4; about 84 title fights a year; a year takes about 0.85 s. A stand-in
career winning 85% of his fights (fewer against bigger promotions) reached the international organisation in about a
year and the world one in about 2; winning 70% took 1 to 7 years to the international one and 2.5 to 9 to the world one.

**To change it:** in `sim/world/climb.gd` (`CALL_UP_WINS`, `LET_GO_LOSSES`, `ASK_WAIT_WEEKS`, `ASK_YES`,
`ASK_YES_UNRANKED`); the eliminators in `sim/world/titles.gd` (`ELIMINATOR_FROM`, `ELIMINATOR_TO`, `HIS_ELIMINATOR_TO`,
`ELIMINATOR_AFTER`, `ELIMINATOR_ROUNDS`, `NEXT_WAIT`); his offers in `Matchmaker` (`step_up_offer`, `eliminator_offer`,
`pro_cards`, `title_offer`); the hub in `CareerHub` (`fighter_card_text`, `offer_text`, the Ask button, `news_text`) and
`game/main.gd` (`ask_step_up`). Tests: `tests/sim/world/test_climb.gd`. Then update this section and D357.

### 12.8 A history before day one (D358)

A new career's world has 10 years behind it. Kyle (2026-11-02) picked "A short wait with a progress line", "Records,
reigns and a History page", "World champions and long reigns", "Yes, everywhere by name" and "Yes, named on the hub" (my
pick on all five).

- **The wait.** Once, when a new career starts (after the gym), the world is made at the start of a calendar 10 years
  before his first week and played up to it: "WRITING 10 YEARS OF HISTORY" with the year counting up, about 8 seconds on
  a PC (longer in the browser). His first week is still Monday 4 January 2027; the top bar's week counts from his start.
  A loaded career never plays it again, and a career saved before D358 carries on without one.
- **What it leaves.** Men with long records (the busiest about 50 pro fights), retired men kept with their records,
  rankings built from real results, and every belt reign kept for good: who, when won and lost, how many defences and
  how it ended.
- **Legends:** anyone who's held the world organisation's belt, or defended any belt 3 times in one reign, retired or
  still fighting, ranked by their reigns (a world organisation reign counts 3 times, the international one 1.5), about 40
  after 10 years.
- **Former champions marked everywhere by name.** A man who's held a belt and doesn't now is "former IML champion" (his
  biggest one) on offers, the rankings, *His division* and the news.
- **His hometown's legend.** Of the men who've held his home promotion's belts, one from his hometown if any is, else
  from his country, the one whose reigns there count for most: named on the Promotions page under his home promotion and
  on This week while he's a pro with no pro fights yet ("The IML's best ever: …").
- **The History page** (*History* on the top bar): his hometown's legend; every promotion's champions in his division,
  biggest promotion first and newest first ("2019–2022 Lewis Ward (England) · 4 defences · lost it"); and the top 20
  legends in every division with their belts.

**How healthy it is** (a fresh career, 2026-11-02): 10 years take about 8 s; about 680 active men and 480 retired ones
kept; a save about 830 KB; about 40 legends; about 140 of the active men are former champions. A dominant world champion could
run up 20 defences over the 10 years until the 30-year check (§12.9) made title fights closer and the best men fade.

**To change it:** how many years in `Career.HISTORY_YEARS` (tests and tools set `Career.history_years`; the test run's
pre-run hook `tests/pre_run.gd` sets 0), the wait in `game/main.gd` (`_write_history`, `HISTORY_SLICE`); legends and the
hometown legend in `sim/world/history.gd` (`LEGEND_DEFENCES`, `LEGENDS_SHOWN`, `legacy`, `home_legend`); the page in
`CareerHub` (`history_text`, `home_legend_text`, `_reign_line`). Tests: `tests/sim/world/test_history.gd`. Then update
this section and D358.

### 12.9 The 30-year check (D359)

A test on every PR plays a new career's world for 30 years, with a stand-in of his own fighting through them, and fails
when the world drifts out of bounds (A10's long-run validation). Kyle (2026-11-02) picked "About one a decade, any
division", "Both a little", "Notable ones and the last 5 years", "A test on every PR", "Yes, a stand-in career too" and
"Most at lightweight and welter" (my pick on all six).

**What the first 30-year runs found** (before this, 2026-11-02): about 670 active men and steady ages and records, but
world champions often 7 to 15 points better than their #1 contender, so reigns of 20 to 30 defences (a 42-year-old with
22); every retired man kept for good (the save 1.3 MB and a year about 1 s by year 30); and light heavyweight oddly big,
because a lad was fitted to his division at the weight he is now and grew out of it upward. What changed:

- **Closer title fights.** In the world's title fights the gap between the two men's averages counts 40%
  (`Titles.SQUEEZE` 0.4): a champion 10 points better wins about 78% rather than 96%. A puncher's chance. His own title
  fights are on the engine and don't change.
- **The best men fade faster after 34.** From 34 a man falls 1.5 a year as before, plus 0.15 a year for every point he
  averages over 72 (`WorldWeeks.TOP_DECLINE`, `TOP_DECLINE_FROM`): an 84 at 35 falls 3.3 a year.
- **The champion's edge.** Those two alone left world champions too easy to beat: half lost their first defence and
  they averaged about 1.5 defences. Kyle (2026-11-02): "We should tune for champs averaging 2-4 defenses I think with the
  chance at less and more possible". So in a defence the champion gets an edge on the odds (`Titles.CHAMPION_EDGE` 1.1,
  the man who's been five rounds before and knows the belt): against an even man he wins about 75%.
- Together, over four seeds with the stand-in: world organisation champions average 2.5 to 3.6 defences (the median 1
  or 2: about a third still lose the first one), 5 to 7 reigns of 10 or more defences in 30 years across every belt, the
  longest 15 to 25.
- **The smaller belts' champions defend twice before a call-up.** Regional and international champions were called up
  after one defence (D356), so they averaged under 1. Kyle (2026-11-02) picked "Called up after 2 defences"
  (`Titles.CALL_UP_DEFENCES` 2; his own call-up as a champion too, §12.7).
- **Retired men remembered when notable.** Each January a retired pro who never fought him and never held a belt is
  forgotten 5 years after he retires (`WorldWeeks.FORGET_PROS_WEEKS`); champions (so every legend) and men he fought are
  kept for good. The save is about 1.1 MB after 30 years with his own career in it, a year about 0.8 s.
- **Divisions biggest in the middle.** Each division's file has a `size` (bantamweight 0.85, featherweight 0.95,
  lightweight 1.25, welterweight 1.2, middleweight 1, light heavyweight 0.75) the pyramid's counts are multiplied by, and
  a lad is fitted to his division by his grown weight, so he grows into it. Pros settle at about 100 at lightweight and
  welterweight, 75 to 85 at bantam, feather and middle, and about 60 at light heavyweight (teenagers still walk lighter,
  so the bantamweight list has the most amateurs in it).

**The check** (`sim/world/world_check.gd`, `WorldCheck`): a career started without the 10-year history (so the world is
30 years old at the end), played a year at a time; every 5 years it measures the world: active men 550 to 800, pros in
each division 45 to 140, the best man averaging 72 to 90, at most a quarter of belts vacant, no active pro over 46, no
record over 80 fights, retired pros' median age 30 to 39; and at the end: world organisation champions averaging 2 to 4
defences, at most 12 reigns of 10+ defences and none over 28, every world organisation belt with 4 champions or more, the save under 1.5 MB. **The stand-in** takes his offers as
they come (a step up, a title shot or an eliminator first), turns pro as soon as he can, asks for a step up now and then,
wins 65% of his fights by decision, and his camps are weeks on his plan. After 30 years the test loads his save, runs a
week and opens every hub page. On seed 3 he had about 150 fights and was 40, about 25 s in all.

**Run it by hand** for more seeds, or after changing the world's numbers:

    godot --headless --script res://tools/world_check.gd -- --seeds=3,7,11 [--years=30] [--world-only]

It prints each seed's 5-year lines and anything out of bounds, and exits 1 if any seed is.

**To change it:** the bounds and the stand-in in `WorldCheck` (`ACTIVE`, `PROS_IN_A_DIVISION`, `LONG_REIGNS_MAX`,
`MOST_DEFENCES`, `WORLD_DEFENCES`, `STAND_IN_WINS`, …); title fights in `Titles.SQUEEZE` and `Titles.CHAMPION_EDGE`; fading in `WorldWeeks.TOP_DECLINE` and
`TOP_DECLINE_FROM`; forgetting in `WorldWeeks.FORGET_PROS_WEEKS` (`let_go`); division sizes in `data/divisions/*.json`
`size` (`Weight.size_of`, `World.count_in`). Tests: `tests/sim/world/test_world_check.gd`. Then update this section and
D359.

---

## 13. A deeper camp (D400–D419)

Phase 4 of the plan (§10, D300). Kyle (2026-11-02): "Merge and start the next phase". Until now the camp barely knew who
he was fighting: an offer showed the opponent's grades exactly, a career fight cued every one of his tells, and career
fights started with no drilled rules. Phase 4 makes every camp about the man he's fighting: scout him, drill the rule that
beats his habit, cut the weight and see it pay off on the night. The plan and its 16 questions are in the phase 4 plan doc
(https://claude.ai/artifact/1nBbfwVWue3ZCFZGb2amh3). The pieces, in this order (D400; Kyle, 2026-11-02, picked "Scouting and film
study" first, my pick):

| Piece | Decision | Status |
|---|---|---|
| Scouting and film study: grades as a range until he's scouted, film study finding his habits, only found habits cued, each man's own habits from his style | D401 | Built (§13.1) |
| Drilling rules in camp: a session that drills one of his two rule slots, the slots in career fights, the camp's early, middle and taper weeks marked | D402 | Built (§13.2) |
| More rules to drill: eight answers to the styles' habits, the answer marked when you've found his habit | D403 | Built (§13.3) |
| The opponent's camp: a plan against your style, sometimes a rule against your favourite move, his own cut (his cut moves to D405) | D404 | Built (§13.8) |
| The weight cut and the weigh-in: how hard he cuts in fight week, missing weight (Kyle, 2026-11-02: "One pick now, planner later": light, normal, hard or extreme now, D23's five-day planner later as a minigame) | D405 | Built (§13.9) |
| Named injuries, and hiding one from the doctor | D406 | Built (§13.10) |
| Sparring partners: named men at his gym from the world's local men | D407 | Moved to the gym-owner plan (§14, D444; Kyle, 2026-11-04: "Fold them into this plan") |
| Coaches: assistants for a weekly fee, the head coach's levels | D408 | Moved to the gym-owner plan (§14, D443 and D447) |
| Changing gyms: his hometown and the nearest city | D409 | Moved to the gym-owner plan (§14, D448: expanding and moving your own gym) |
| Minigames, one a PR: film study, heavy bag, sprawl reflex, Thai pads first (Kyle, 2026-11-03: "Minigames first", next after D403, before the opponent's camp) | D410 on | Film study built (§13.4, D410); sprawl reflex built (§13.5, D411); heavy bag built (§13.6, D412); Thai pads built (§13.7, D413): all four built |
| Your corner naming the habits you found at each round break (Kyle's ask after D401) | D419 | Built (§13.1) |

### 13.1 Scouting and film study (D401)

What you know of the man you're fighting is what you've found out (D11, D51, D66). Kyle (2026-11-02) picked "Grades as a
range", "Film study sessions find them" and "Found after 3 fires" and "1 to 2 habits from his style" (my picks on all four).

- **How well you know him** (0–100%): 3% for each fight on his record (his fights on film, at most 45%), 50% if he's fought
  him before, and what film study in this camp has added. The camp screen shows it.
- **His grades as scouted.** An offer's *Scouted* line (and the camp screen's) shows each group's grade as a range, 16
  points wide when you know nothing of him (*Striking B–A*), narrowing to his one true grade as you get to know him. The truth
  is always inside it but not always in the middle, and the same man always scouts the same.
- **Film study** (the session, `data/sessions/film_study.json`) studies the booked man when it's done in his camp: each one
  adds 20% to how well you know him at Fight IQ 50 (10% at 0, 30% at 100), and has a chance of finding one of his habits he
  hasn't shown you: 25%, + 30% × Fight IQ / 100, + 1% for each of his fights on film (at most 15%), + 15% with a Tactician
  for a head coach (until the coach's own Reading, D408). Between fights it trains Fight IQ only, as before. The camp log
  says what it found (*Film study found his habit: when his jab is blocked, he throws a body kick (7 times in 10, within 1.5
  s)*) and the camp screen's **Scouting** box lists them.
- **Only found habits get the tell cue** in a career fight (D51). One you haven't found is still in his fighting, and once
  you've seen it go off three times in the fight (its move inside its window after its trigger) it's found: the feed says
  *You've got his habit*, it's cued for the rest of the fight, the result lists it, and it stays found for a rematch. Not in a
  simmed fight: nobody was watching. Quick fight cues every tell, as before.
- **His own habits.** Each style sheet now lists two or three habits (style@1 `habits`, `docs/09`): a man made from it keeps
  the signature fighter's tell (the kicker's body kick off a blocked jab) and, half the time, one more from the list; the five
  styles whose signature fighter has none (the Boxer, BJJ, Judoka, Muay Thai, Sambo) get one or two. So two kickers can have
  different habits, and every opponent has something to find. This changes how career opponents fight a little (the AI
  follows its habits); quick fights, the harness and the golden fights use the authored fighters and don't change. On
  `tools/style_sheets.gd --fights=12` (12 men of each style against the field, 2026-11-02) every style still fights in
  style: strikes a minute, shots, submissions and time in the clinch and on the ground within a little of before, and win
  shares moving inside what 12 fights can tell apart. The Sambo fighter's first list (two double legs) took him from 31 to 43
  shots a fight, so his second habit off a miss is a leg kick (35 shots, about as before, on 20 fights).

- **Your corner talks about them** (D419; Kyle, 2026-11-02: "in the fight coaches should mention in the corner the tell
  that was picked up", then picked "At each round break", my pick). At every round break of a career fight, the coach on the stool names each habit you've found, in camp
  or in the fight so far, and how often he's done it: *Your corner: When his jab is blocked, he throws a body kick. He's done
  it 3 times so far: make him pay.* (or *He hasn't shown it yet, but be ready.*). It's the first thing on the break's card.
  Quick fights cue every tell and the corner says nothing of them, as before. (`corner_habit_lines` in `game/main.gd`.)

Saved on the career as `scouting` (`docs/09` career@1; optional, so a career saved before D401 loads knowing nothing of
anyone). A man who was already in the career's opponents keeps the habits he was made with.

**Not yet:** a scout's report you pay for, the head coach's Reading making the cue come earlier (D66, with the coach levels,
D408), and the film study minigame (spot the tell, D410; built, §13.4). The opponent studying you is built (§13.8, D404).

**What to change:** the numbers at the top of `sim/world/scouting.gd` (`SPREAD`, `OFFSET`, `FILM_PER_FIGHT`, `FILM_MAX`,
`MET`, `STUDY_GAIN`, `STUDY_IQ`, `FIND_BASE`, `FIND_PER_IQ`, `FIND_PER_FIGHT`, `FIND_FILM_MAX`, `FIND_TACTICIAN`,
`SPOT_FIRES`) and how each trigger reads in a habit (`TRIGGER_TEXT`); each style's `habits` in `data/styles/`, and how many a
man rolls (`StyleLibrary.HABIT_EXTRA_CHANCE`, `HABITS_MAX`). Tested in `tests/sim/world/test_scouting.gd`,
`tests/sim/world/test_style_library.gd` and `tests/game/test_main_scene.gd`.

### 13.2 Drilling rules in camp (D402)

The two drilled rules (`docs/01` §23, D82, D116) come into the career: you pick them in the camp, drill them in sessions,
and he takes them into the fight as sharp as camp left them. Kyle (2026-11-02) picked "Drill a rule sessions", "Fades
slowly, keeps half", "Marked, nothing locked", "Fresh, and in place of his read" and "In the camp planner" (my picks on all
five).

- **His two rules** are picked in a career camp's new **Rules** box (two pickers). Only rules whose move he knows are offered:
  everyone can sprawl, only a man from the Wrestling family background knows the catch. One rule can't sit in both slots.
  The box shows how well drilled each one is. The career keeps them for the next camp (`rule_slots`).
- **Drill rule 1** and **Drill rule 2** are two new sessions (`data/sessions/drill_rule_1.json`, `_2`; session@1
  `drills_rule`), only offered in a career's planner (a quick camp has no rules to drill). Each one done takes that slot's
  rule most of the way up: drilled = 1 − (1 − drilled) × e^(−reps / 3.73), one rep a session (less when he's worn out, as
  every session's gains). About six sessions take a rule from nothing to 80%, and each one after adds less. They train a
  little Fight IQ and Speed too and cost 6 fatigue. The camp log says what moved (*Drilled When he shoots → sprawl: 0% → 24%*).
  A session for an empty slot drills nothing. Weeks between fights drill too, if you put them in the week's plan.
- **Going rusty.** Every rule he's drilled is remembered, so swapping one out keeps what it had. A week he doesn't drill one,
  it loses 2 points, but never drops below half of his best with it: drilled to 80% and left for a year, it's at 40% when he
  comes back to it.
- **In the fight** his two rules go in at their drilled share (a rule never drilled goes in at 0% and never fires). At the
  round break you can swap between rules, each at its own drilled share; there's no slider in a career. Lesson fights 1 and 2
  of the tutorial (§11.6) have no rules, as before.
- **Rules worth having.** Before this, a drilled sprawl cost the man who had it wins (`docs/01` §23.3). Two changes to the
  rules themselves (`docs/01` §23.5) fixed that before they went into the career: a rule sits out while he's gassed (under 30%
  of his tank), and a sprawl rule stands in for his own read of a shot instead of doubling it.
- **The camp's three parts** (A6) are marked above the week: *Early camp* for its first third (build him up), *Middle camp*
  (get ready for this man: film study, sparring and drilling), and the *Taper* in fight week (keep it light: the less tired he
  is, the fuller his tank, as before). Only marked, with a tip each: nothing is locked and nothing extra is paid for following
  them.

Saved on the career as `rules` (`docs/09` career@1; optional, so a career saved before D402 loads with no rules).

**Not yet:** a drilling minigame and a third slot with a coach (D408). The opponent drilling a rule against you is built
(§13.8, D404).

**What to change:** `SCALE`, `FADE_PER_WEEK` and `KEEPS` at the top of `sim/world/rule_drilling.gd`; the sessions in
`data/sessions/drill_rule_*.json`; the camp's parts and their tips in `Career.camp_phase()` and `CAMP_PHASE_TIPS`
(`sim/world/career.gd`); when a rule sits out and how it stands in for his read in `sim/fight/drilled_rules.gd`
(`FRESH_ABOVE`, `STAND_IN_FOR_READ`, `docs/01` §23.5). Tested in `tests/sim/world/test_rule_drilling.gd`,
`tests/sim/fight/test_drilled_rules.gd`, `tests/data/test_data_files.gd` and `tests/game/test_main_scene.gd`.

### 13.3 More rules to drill (D403)

Before this a career fighter had two rules to pick from: the sprawl, and the catch if he came from wrestling. Now there's an
answer to every kind of habit a style has (§7.1). Kyle (2026-11-03) picked "Eight, one for every habit", "Only moves he
knows", "Mark the answer" and "At least break even" (my picks), then "Keep all eight in careers".

| Rule | Answers the habit | Who knows the move |
|---|---|---|
| When he leg kicks → check it | Leg kicks and calf kicks (the Kicker, Leg kicker, Muay Thai, Sambo and Counter-striker) | Everyone |
| When he throws a straight → slip | The cross (the BJJ fighter, Judoka, Boxer and Karate fighter) | Fighters who learned the slip |
| When he hooks → roll it | The hook (the Boxer, Brawler, Dirty boxer, Counter-striker and Sprawl-and-brawler) | Fighters who learned the shoulder roll |
| When he kicks high → lean back | The head kick (the Kicker) | Fighters who learned the lean back |
| When he kicks high → hands up | The head kick | Everyone |
| When he shoots → knee him | The double leg (the wrestlers and Sambo) | Everyone with the knee |
| When I block his jab → fire the cross | Anything he throws when his jab is blocked (most styles' first habit) | Everyone |
| When I'm blocked → hands up | Anything he throws when your strike misses (most styles' second habit) | Everyone |

- **Only the moves he knows** (as D402): the Rules box offers a rule when he knows its move, so a street kid can check, put
  his hands up, knee, sprawl and fire the cross, and a boxing gym kid can also roll.
- **The answer is marked.** Once you've found one of the booked man's habits (film study, or seen three times in a fight,
  §13.1), every rule he knows that answers it is starred in the Rules box's pickers (*★ When he leg kicks → check it (answers
  his habit)*), the box says *Answers his habit: …*, and the scouting report puts *Drill to beat it: …* under the habit.
  Nothing is picked for you.
- **Worth having.** Each rule was played in a matchup against a man with its habit, drilled to 80% (`docs/01` §23.6): the
  check, slip, roll and jab counter break even or better, the knee wins the Kicker 13% more fights against the Wrestler, and
  the lean back and the two hands-up rules cost 2 to 4%. They're kept as the weaker picks; the fix belongs in the lean back
  and the high guard themselves.

**Not yet:** an answer of its own to a body kick, a body hook or an overhand (the overhand comes over a roll and no defence stops a body shot yet), rules that fire on a position or a grip.
The opponent drilling one of these against your favourite move is built (§13.8, D404).

**What to change:** a rule's trigger, move and cooldown in `data/rules/`; what sets a trigger off in `data/triggers/`;
which rule answers which habit in `RuleDrilling.answers()` (`sim/world/rule_drilling.gd`); how a defence rule is timed and
whether it lifts his own read in `sim/fight/drilled_rules.gd` (`LIFT_GUARD_ON_READ`, `docs/01` §23.6). Tested in
`tests/sim/world/test_rule_drilling.gd` and `tests/sim/fight/test_drilled_rules.gd`.

### 13.4 Film study, the minigame (D410)

The first of phase 4's minigames (§13 table; Kyle, 2026-11-03, picked "Minigames first" and "Film study" to lead them).
A Film study session ticked to **Play** in the camp planner (up to three played sessions a week, as mitt work, `docs/02`
§3.9) opens a minute of the man's tape before the week runs. Kyle picked "His fights in the 3D view", "Mark it, then name
it", "The habit for sure, plus Fight IQ" and "Study a man of his style" (my picks on all four).

- **The tape** is a whole fight of his, played without drawing it, against a stand-in (the Boxer, Kicker or
  Counter-striker, whichever sets his habit off most): the 3 minutes of fight time where his habit goes off most (at least
  twice, a new fight tried up to four times), shown in the fight screen's 3D view at 3× (a minute on screen, D38) with no
  tell cues. Before the tape starts it's the same fight from the same seed, played up to the clip.
- **Marking.** Press **Space** each time you think his habit just went off: a move he throws straight after the same
  moment (his jab blocked, you making him miss). A press from 0.3 s before his habit's move starts to 1.5 s after counts
  (fight time, ± 30% at Fight IQ 100 or 0); a press near one of his other habits costs nothing; any other press is a
  stray.
- **Naming.** When the tape runs out, pick his habit from three (keys 1–3): his, and two from the other styles' habits
  that aren't his, in words without their numbers (*When his jab is blocked, he throws a body kick*).
- **The score**: 60% the marks (fires caught, less a quarter of a fire a stray), 40% naming it right. It's the session's
  quality, ×0.8 for nothing to ×1.5 for every fire and the name, on what the session trains (Fight IQ), as mitt work's
  is on Boxing drills. **Skip it** lets the session auto-resolve (×1.0), as before.
- **Finding it.** In a career, naming the booked man's habit right finds it for sure (`Career.scout_week`), instead of
  the session's roll (§13.1), and the session still adds to how well you know him. Played but named wrong, or not played,
  it rolls as before. The habit on the tape is one you haven't found, and not one another played session found that week.
- **Nothing to find.** With no booked man (a quick camp), or all his habits found, the tape is a man of his style (any
  style with habits, in a quick camp), made the way the world makes men: Fight IQ only.

**Not yet:** a tape of his real past fights (the world's fights are quick results, not fights), the opponent's habits
shown as film to a corner, and the other minigames (sprawl reflex built next, §13.5; heavy bag, §13.6; Thai pads, §13.7).

**What to change:** the clip, speed, windows and score in the constants at the top of `sim/world/film_study.gd`
(`CLIP_SECONDS`, `SPEED`, `WINDOW_BEFORE`, `WINDOW_AFTER`, `WINDOW_PER_IQ`, `STRAY_COST`, `MARK_SHARE`, `CHOICES`,
`MIN_FIRES`, `TRIES`, `STAND_INS`); the screen in `ui/film_study_screen.gd`; which sessions can be played in
`CampPlanner.PLAYABLE`. To see it: `godot --path . --script res://tools/film_preview.gd -- --style=kicker` (with
`--write-movie` to save frames). Tested in `tests/sim/world/test_film_study.gd`, `tests/ui/test_camp_planner.gd` and
`tests/game/test_main_scene.gd`.

### 13.5 Sprawl reflex, the minigame (D411)

The second phase 4 minigame (Kyle, 2026-11-03, picked "Sprawl reflex" next, my pick: a reaction game, unlike mitt work's
rhythm). A Sprawl drills session ticked to **Play** in the camp planner opens a minute of a drill before the week runs: your
fighter and a wrestling partner (the Wrestler from `data/fighters/`) in the fight screen's 3D view, the partner shooting
double legs at you, and **Space** to sprawl. Kyle then picked "3D view, him and a partner",
"Feints, some shot off the feint", "He's taken down, then reset" and "Pace, feints and speed by TD defence" (my picks on all
four).

- **The engine is the referee.** It's the real fight engine, so the timing is the fights' own (`docs/01` §21.2): a sprawl
  works when its active phase meets the shot's drive. Pressed from his first step in until the drive's last moment, about
  0.9 s of fight time, it's in time; but a sprawl takes 0.7 s to finish and get back up from, and he can't start another
  until it's over. The drill runs with `FightSim.drill`: a sprawl in time always stuffs the shot and a shot not sprawled on
  always lands, so only the timing counts, never a roll. No move names, range tag or referee in the view: reading his level
  change is the drill.
- **The partner** stands at mid range and, after a short gap, does one of: a shot; a feint (a pump of the shot); or a feint
  and the shot straight off it. Sprawl on the feint and the real shot comes while you're still getting back up.
- **A shot that gets through** takes you down: a moment on the mat, then both are stood back up and the drill goes on (it
  counts against you).
- **Harder as he gets better**, by his Takedown defence from 20 to 90 (as mitt work by Boxing): the gap between reps from
  2.4 s to 1.2 s (± 0.4 s), feints from 20% to 50% of reps (half of them with the shot off the feint), and the drill from 1×
  to 1.3× (fight seconds per real second). From fatigue 40 it runs faster again, up to 1.2× more at 100: tired reflexes. It
  always lasts a minute on screen.
- **The score**: shots stuffed, less a quarter of a shot for each sprawl that met nothing (a bite on the feint, or just
  jumpy), over the shots that reached him. It's the session's quality, ×0.8 for nothing up to ×1.5 for every shot, on what
  Sprawl drills train (Takedown defence, Scrambles, Speed). **Skip it** lets the session auto-resolve (×1.0), as before.

**Not yet:** knees into the shot (D182) as a second key, a gym partner from the world's men (D407), and the drill in a
gym's own look (a mat, not the cage).

**What to change:** the pace, feints, speed and score in the constants at the top of `sim/world/sprawl_reflex.gd`
(`PARTNER`, `ROUND_SECONDS`, `GAP_SLOW`, `GAP_FAST`, `GAP_JITTER`, `FEINTS_LOW`, `FEINTS_HIGH`, `FEINT_SHOT_SHARE`,
`SPEED_LOW`, `SPEED_HIGH`, `TIRED_FROM`, `TIRED_SPEED`, `LEVEL_LOW`, `LEVEL_HIGH`, `SETTLE_SECONDS`, `DOWN_SECONDS`,
`STRAY_COST`, `FEINT_BITE_TICKS`); the sprawl's and the double leg's timings in `data/actions/`; the screen in
`ui/sprawl_reflex_screen.gd`; which sessions can be played in `CampPlanner.PLAYABLE`. To see it:
`godot --path . --script res://tools/sprawl_preview.gd -- --level=50 --sprawl` (with `--write-movie` to save frames).
Tested in `tests/sim/world/test_sprawl_reflex.gd` and `tests/ui/test_camp_planner.gd`.

### 13.6 Heavy bag, the minigame (D412)

The third phase 4 minigame (Kyle, 2026-11-03, picked "Heavy bag" next, my pick: strikers get a session to play, after a
mind drill and a wrestling drill). It's `docs/02` §3.2's power timing with chaining. A Heavy bag session ticked to **Play**
in the camp planner opens a minute on the bag before the week runs. Kyle's three cards (2026-11-03, all my picks): "2D drawn
bag and meter", "Load, release, meet the swing", "Quicker meter, smaller green".

- **The screen**: the bag drawn swinging on its chain, his glove, and a power meter beside it (green at the top, good
  below it, weak under that), like mitt work's drawn mitts. A thud on every shot that lands, a whoosh on one that finds
  nothing (made in code).
- **A shot**: hold **Space** to load it. The meter climbs to the top and back down, over and over, while it's held; let
  go with it in the green. The green is a full shot, the band below it good (worth 0.6), lower weak (0.15).
- **The swing**: the bag swings away and back to him 1.4 s after a shot lands, however hard it was hit (a pendulum's
  pace). Let go within 0.15 s of it coming back and the shot **meets** it: it counts in full and the chain grows. Let go
  after it's back and the shot lands but misses the swing (× 0.6) and the chain ends. Let go while it's still swinging
  away and the shot finds nothing: a whiff, a quarter of a shot off, and the chain ends. A ring over the meter fills as
  the bag swings in and turns green as it meets you. The first shot meets a still bag.
- **The skill**: start loading while the bag is still swinging away, so the meter tops out just as it comes back.
- **The score**: what the shots were worth, less the whiffs, over a perfect round's shots (one each swing, 42). It's
  the session's quality, ×0.8 for nothing up to ×1.5 for a perfect round, on what Heavy bag trains (Power 50%, Boxing
  30%, Strength 20%). **Skip it** lets the session auto-resolve (×1.0), as before.
- **Harder as he gets better**, by his Power from 20 to 90 (as mitt work by Boxing): the meter tops out in 1.0 s down to
  0.6 s, and the green shrinks from 20% of the meter to 10%. **Tired arms:** from fatigue 40 at that point of the week the
  green shrinks in a line to 60% of itself at fatigue 100, as mitt work's windows do.

**Not yet:** kicks and knees on the bag (Thai pads will have them), the bag in a gym's own look, and a 3D view of his
fighter on it.

**What to change:** the round, the swing, the meter and the score in the constants at the top of
`sim/world/heavy_bag.gd` (`ROUND_SECONDS`, `SWING_SECONDS`, `MEET_WINDOW`, `LOAD_SLOW`, `LOAD_FAST`, `GREEN_WIDE`,
`GREEN_NARROW`, `GOOD_BAND`, `LEVEL_LOW`, `LEVEL_HIGH`, `TIRED_FROM`, `TIRED_FLOOR`, `MISSED_SWING`, `GOOD_CREDIT`,
`WEAK_CREDIT`, `WHIFF_COST`); the drawing, colours and sounds in `ui/heavy_bag_screen.gd`; which sessions can be played in
`CampPlanner.PLAYABLE`. To see it: `godot --path . --script res://tools/bag_preview.gd -- --power=50` (with
`--write-movie` to save frames). Tested in `tests/sim/world/test_heavy_bag.gd` and `tests/ui/test_camp_planner.gd`.
Fights don't change.

### 13.7 Thai pads, the minigame (D413)

The fourth phase 4 minigame and the last of the four (Kyle, 2026-11-03, picked "Thai pads minigame" next, my pick: the
kicking styles were the only strikers without a session to play). It's `docs/02` §3.2's aim and timing, the pad holder
feeding kicks, knees and elbows. A Thai pads session ticked to **Play** in the camp planner opens a minute on the pads
before the week runs. Kyle's three cards (2026-11-03, all my picks): "Read the pads, throw the strike", "2D drawn pad
holder", "Quicker pads, then combinations".

- **The screen**: the pad holder drawn facing him, like the heavy bag, his pads held at his chest between strikes. A
  smack on every strike that lands, a whoosh on one that doesn't (made in code).
- **Reading the pads**: he sets a pad where he wants a strike and you throw it before he drops it. Pad high beside his
  head: **1** head kick. Pad flat in front of his face: **2** elbow. Pad on his ribs: **3** body kick. Both pads at his
  belly: **4** knee. The thigh pad on his lead leg: **5** low kick. Now and then (15% of single pads) his rear leg comes
  up as he kicks back: **Space** checks it. Each key is drawn faintly beside its pad's place.
- **Timing**: a ring round the pad runs down until he drops it. A strike while it's gold (the first 45% of the pad's
  time) is perfect, a later one good (worth 0.6). The wrong strike misses that pad, and a pad he drops unhit is missed
  ("Too slow"). A strike with no pad up, or at one already hit, finds nothing and takes a quarter of a strike off.
- **The score**: perfect strikes, plus good ones at 0.6, less the strikes at nothing, over every pad he held. It's the
  session's quality, ×0.8 for nothing up to ×1.5 for a perfect round, on what Thai pads trains (Kicking 50%, Clinch
  striking 30%, Power 20%). **Skip it** lets the session auto-resolve (×1.0), as before.
- **Harder as he gets better**, by his Kicking from 20 to 90 (as mitt work by Boxing): a pad stays up 1.2 s down to
  0.65 s, and the next one comes after 1.1 s down to 0.5 s. **Combinations:** from Kicking 60 half the sets are two pads
  in a row, and from 80 half of those are three; each pad in a combination is up for three quarters of a single pad's
  time and the next goes up as it drops, never the same pad twice running. **Tired legs:** from fatigue 40 at that
  point of the week a pad's time shrinks in a line to 60% of itself at fatigue 100, as mitt work's windows do.

**Not yet:** fake-outs (a pad shown and pulled), the plum and knees from it, teeps, harder pads at a Muay Thai gym or a
camp abroad (`docs/02` §6, Bangkok), and a 3D view of him and the holder.

**What to change:** the round, the pads' times, the combinations and the score in the constants at the top of
`sim/world/thai_pads.gd` (`ROUND_SECONDS`, `COUNT_IN`, `OPEN_SLOW`, `OPEN_FAST`, `GAP_SLOW`, `GAP_FAST`, `LEVEL_LOW`,
`LEVEL_HIGH`, `PERFECT_SHARE`, `COMBO_FROM`, `TRIPLE_FROM`, `COMBO_CHANCE`, `TRIPLE_CHANCE`, `COMBO_SHARE`, `CHECK_CHANCE`,
`TIRED_FROM`, `TIRED_FLOOR`, `GOOD_CREDIT`, `STRAY_COST`); the drawing, keys, colours and sounds in
`ui/thai_pads_screen.gd`; which sessions can be played in `CampPlanner.PLAYABLE`. To see it:
`godot --path . --script res://tools/pads_preview.gd -- --kicking=70` (with `--write-movie` to save frames). Tested in
`tests/sim/world/test_thai_pads.gd` and `tests/ui/test_camp_planner.gd`. Fights don't change.

### 13.8 The opponent's camp (D404)

Phase 4's fourth piece (Kyle, 2026-11-03, picked "Opponent's camp (D404)" next, my pick). Until now the man he was booked
against walked in the same whoever he was fighting: his style sheet's one plan, no rules, a full tank. Now he has a camp
of his own. Kyle's four cards (2026-11-03):

- **His plan: one of a few, rolled** (Kyle's pick; I'd suggested a plan picked against your style). Every style sheet
  lists two or three plans that suit it (style@1 `gameplan` and `gameplans`, `docs/09`), and his corner rolls one for the
  fight. The scouting report still shows the style's usual plan; which one he's really bringing you learn on fight night,
  or earlier if you know him well (below). This replaces D324's "his corner sticks to one plan".

  | Style | His plans |
  |---|---|
  | Pressure boxer | Pressure · Head · standing; Counter · Head · standing; Pressure · Body · standing |
  | Brawler | Pressure · Head; Pressure · Body; Head · standing |
  | Counter-striker | Counter · Head · standing; Range · Head · standing; Counter · Legs · standing |
  | Dirty boxer | Pressure · Body · clinch; Pressure · Head · clinch; Pressure · Body · standing |
  | Karate point fighter | Range · Head · standing; Counter · Head · standing; Range · Body · standing |
  | Range kicker | Legs; Body; Range · Head · standing |
  | Leg-kick specialist | Legs; Range · Legs · standing; Counter · Legs |
  | Muay Thai clinch fighter | Body · clinch; Legs · clinch; Pressure · Body |
  | Sprawl-and-brawl | Head · standing; Counter · Head · standing; Pressure · Body · standing |
  | Pressure wrestler | Pressure · take him down; Pressure · clinch; Conserve · take him down |
  | Ground-and-pound wrestler | Pressure · take him down; clinch; Pressure · Head · take him down |
  | Wrestle-boxer | Take him down; Pressure · take him down; clinch |
  | Judo thrower | Clinch; take him down; Counter · clinch |
  | Submission grappler | Take him down; Counter · take him down; clinch |
  | Sambo leg-locker | Take him down; Legs · take him down; clinch |

- **A rule against your favourite move, more often higher up** (my pick). Your favourite move is the one you threw most
  in your last 3 fights that a rule can answer (each fight's `moves` on your record, counted from every move you started).
  A third of amateur opponents drill a rule against it, half of pros, and every title fight's. He drills one he knows (a
  rule whose move is in his techniques), 50 to 80%, in his first rule slot, and it works exactly as yours do (`docs/01`
  §23). Throw a lot of leg kicks and a pro will often come in checking them; jab a lot and he may have drilled the slip.
  Before your first fight he has no film of you, and some moves no rule answers yet (the uppercut, for one), so he
  drills nothing.
- **Seen on fight night, or early if scouted** (my pick). The fight night card has a *His camp* line under the gameplan:
  *His plan: Pressure · Body. He's drilled When he leg kicks → check it (64%) for your leg kick. He overtrained: 90% of his
  gas tank.* In fight week the camp's scouting box shows the same lines when you know him 60% or better (§13.1), so you
  can still drill your own rules or change your plan for it.
- **Usually fresh, sometimes not** (my pick). A quarter of opponents overtrained or cut badly and start with 85 to 95% of
  their gas tank (the same `condition` your own camp gives you, `docs/09` fighter@1); the rest come in fresh. His own
  weight cut, and seeing it at the weigh-in, is built: §13.9 (D405).

Not in a one-day tournament (nobody prepared for one man) or the tutorial's lesson fights before the gameplan opens
(§11.6). It's worked out from the career's seed, the man and the week of the booking, so the same booking always gives
the same camp and nothing new is saved but each fight's `moves` (optional: a career saved before D404 has no moves on its
old fights, so its next man has no film of you).

**Not yet:** a plan picked to beat your style (Kyle chose the roll), the world's men drilling
rules against each other, a rule against your favourite takedown or submission (rules answer strikes and shots only), and
the hub telling you what your favourite move is before a camp.

**What to change:** each style's plans in `data/styles/*.json` (`gameplan` and `gameplans`); the chances, drill range,
fights counted, the tired share and tank range and how well you must know him to see it early in the constants at the top of
`sim/world/opponent_camp.gd` (`RULE_CHANCE_AMATEUR`, `RULE_CHANCE_PRO`, `RULE_CHANCE_TITLE`, `DRILLED_MIN`, `DRILLED_MAX`,
`MOVES_FIGHTS`, `TIRED_CHANCE`, `TANK_LOW`, `TANK_HIGH`, `SCOUTED_EARLY`); which rule answers which move in
`RuleDrilling.answers()`. Tested in `tests/sim/world/test_opponent_camp.gd`, `tests/data/test_data_files.gd` and
`tests/game/test_main_scene.gd`. Fights against the booked man change: his plan, his rule and his tank.

### 13.9 The weight cut and the weigh-in (D405)

Phase 4's fifth piece (Kyle, 2026-11-04, picked "Weight cut and weigh-in (D405)" next, my pick). Until now a pro made his
division's limit without it costing or winning him anything. Now he cuts weight, and so does the other man. As Kyle
picked on 2026-11-02 ("One pick now, planner later"), it's one choice for now: light, normal, hard or extreme. D23's
five-day planner can come later as a minigame. Kyle's four cards (2026-11-04, all my picks): "Heavier on the night: Strength", "Gas tank and Chin, worse harder",
"Fined, the fight goes ahead", "Pick in camp, a weigh-in card".

- **The cut.** A pro weighs in the day before (`docs/08`), so in fight week he sheds water to make the limit and puts
  most of it back by fight night. What he walks around at over the limit has to come off. Each level sets how much of
  that comes off as water in fight week; the rest is dieted off in camp.

  | Level | Water he sheds | Gas tank cost | Chin cost | Chance he misses weight |
  |---|---|---|---|---|
  | Light | up to 3% of his weight | none | none | none |
  | Normal (to start with) | up to 6% | 3% | none | 2% |
  | Hard | up to 9% | 8% | 3 | 6% |
  | Extreme | up to 12% | 15% | 8 | 15% |

  He gets 90% of the water back by fight night, so a harder cut makes him heavier on the night. A man with less to lose
  than the level's share sheds only what he has, and pays that share of the cost. A man already under the limit has
  nothing to cut: no cost and no miss. The Hard cut flaw (`docs/11`) makes a miss half as likely again. Amateurs weigh in on
  the day at what they walk around at (`docs/08`), so amateur fights and tournaments have no cut.
- **What it wins: the bigger man on the night** (my pick). Whoever is heavier on fight night gets +1 Strength for each
  whole kg he outweighs the other man, up to +6. Strength drives damage and the clinch.
- **What it costs: gas tank and Chin, worse the harder** (my pick). The costs are in the table. The tank cost multiplies
  what the camp left him (the fight night card's gas tank shows both), and the Chin is lost for that fight only.
- **Missing weight: fined, and the fight goes ahead** (my pick). A man who misses is over the limit by 0.3 to 1.5 kg. 20%
  of his purse goes to the other man; when it's the other man who misses, you get 20% of your show money from him. It
  goes on the fight's record, and in a title fight the man who missed can't win the belt. A champion who misses is
  stripped at the scale, so only the other man can win it.
- **The other man cuts too.** His corner picks light 15% of the time, normal 50%, hard 25% and extreme 10%. It's rolled
  on the booking, so your own pick never changes his.
- **Where you see it: picked in camp, then a weigh-in card** (my pick). A *Weight cut* box in the camp planner, under
  the rules, picks the level. Its line says what he walks around at, the limit, the water he'll shed, about what he'll
  weigh on fight night, what it costs and the chance he misses. The pick is fixed once the camp is over. When the last
  week has run, *The weigh-in* card comes before the fight night card. It shows both men on the scale (kg and lb), MADE
  WEIGHT or MISSED WEIGHT, each man's cut and what it cost him, what each will weigh on the night, who's the bigger man,
  and any fine. *On to fight night* goes on. The fight night card then has a *Weigh-in* line, and its gas tank includes
  the cut.

Saved on the booking as `cut`, and on the fight's record as `weigh_in`, `fine` and `fine_got` (`docs/09` career@1; all
optional, so a career saved before D405 loads on a normal cut). Pure and seeded on the booking: the same booking and
pick always give the same weigh-in.

**Not yet:** D23's five-day planner (water loading, sodium, sauna, food) as a minigame, the other man refusing the fight
when you miss, reputation for missing weight, catchweights, moving divisions after a bad cut, and the world's men cutting
in their own fights.

**What to change:** the levels, water, regain, costs, miss chances, size edge, fine and the other man's odds in the
constants at the top of `sim/world/weight_cut.gd` (`WATER`, `REGAIN`, `TANK_COST`, `CHIN_COST`, `MISS_CHANCE`,
`HARD_CUT_MISS`, `MISS_BY`, `STRENGTH_PER_KG`, `STRENGTH_MAX`, `FINE`, `OPP_LEVEL_ODDS`, `DEFAULT`). The weigh-in card's
look is in `ui/weigh_in_card.gd`, and the camp's box in `ui/camp_planner.gd` (`set_cut`). Tested in
`tests/sim/world/test_weight_cut.gd` and `tests/game/test_main_scene.gd`. Fights change for the two men's cuts: tank,
Chin and Strength.

### 13.10 Named injuries, and hiding one (D406)

Phase 4's sixth piece (Kyle, 2026-11-04, picked "Named injuries (D406)" next, my pick). Until now an injury was only
where it was (head, body or legs) and how many days it had left: 2 to 10 days from a camp session, and fights never hurt
him beyond the medical suspension. Now every injury has a name, and fights can cause one. Kyle's four cards (2026-11-04,
all my picks): "Each hurts its own thing", "Yes, by what happened", "Hide it, he may be found out", "Rarely, a small dent".

- **Each hurts its own thing** (my pick). Twelve injuries, one file each in `data/injuries/` (`docs/09` injury@1). Each
  has where it is, how long it takes to heal, and what it takes off his stats until it has:

  | Injury | Where | Days to heal | Until it heals | From camp | From a fight | Lasting dent |
  |---|---|---|---|---|---|---|
  | Cut over the eye | head | 3–10 | nothing | sparring | head | – |
  | Broken nose | head | 14–28 | Cardio −3 | sparring | head | – |
  | Orbital fracture | head | 35–70 | Striking defense −6 | – | head (rare) | 25%: Striking defense −2 to −3 |
  | Bruised ribs | body | 3–8 | nothing | sparring, wrestling, grappling, striking | body | – |
  | Cracked rib | body | 14–35 | Cardio −5 | sparring, wrestling, grappling (rare) | body | – |
  | Back strain | body | 3–10 | Takedowns −5, Strength −3 | conditioning, wrestling, grappling | – | – |
  | Sprained ankle | legs | 4–14 | Footwork −6, Kicking −3 | conditioning, striking, wrestling | – | – |
  | Bruised shin | legs | 2–7 | Kicking −4 | striking, sparring | legs | – |
  | Sprained knee | legs | 14–35 | Footwork −5, Takedowns −5 | wrestling, grappling, conditioning (rare) | legs | 15%: Footwork −2 to −3 |
  | Torn knee ligament | legs | 90–180 | Footwork −10, Takedowns −10, Kicking −6 | wrestling, grappling (very rare) | legs (very rare) | 60%: Footwork −2 to −4 |
  | Sprained wrist | hands | 4–12 | Power −4, Boxing −3 | striking | – | – |
  | Broken hand | hands | 28–56 | Power −8, Boxing −5 | striking, sparring (rare) | punches | 20%: Power −2 to −4 |

  In camp, a session that hurts him (the same chance as before, D135) picks one of the injuries its kind of training can
  cause, by each one's weight, so a cut over the eye comes from sparring and a sprained ankle from roadwork. Slow healer
  still makes every one take half as long again. A head, body or leg injury still starts the fight hurt there (3% a day
  left, now never more than 50%). A hand injury doesn't: it only cuts his stats. The cuts count in the fight (the camp's
  `fight_profile`).
- **Fights injure him by what happened** (my pick). After a career fight, each area he finished hurt in has a 35% ×
  how hurt chance (a man who finished 60% hurt in the legs: 21%) of one of that area's fight injuries. His hand has a
  0.15% chance for every punch he landed (100 landed: about 15%), twice that with the Brittle hands flaw. When more than
  one happens, the longest counts. Its days run from fight night alongside his medical suspension, so whichever is longer
  keeps him out. It goes on the fight's record as `injury` and on the result screen ("Hurt in the fight: Broken hand, 40
  days to heal (Power −8, Boxing −5 until then)."). In a tournament it's rolled when his day is over.
- **Hide it, he may be found out** (my pick). On a career's fight night, when the doctor won't clear him (more than 7
  days still to heal), the fight night card has **Hide it from the doctor**. The doctor finds out 15% + 2.5% a day still
  to heal of the time (8 days: 35%; 20 days: 65%; never more than 90%). Found out, the stamp says CAUGHT HIDING IT and
  the fight is off, as if he'd not been cleared. If not, the stamp says CLEARED (HIDING IT): he fights hurt, and fighting
  on it is twice as likely to make it worse. It's seeded on the booking, so trying again gives the same answer.
- **Rarely, a small dent** (my pick). The worst injuries (orbital fracture, sprained knee, torn knee ligament, broken hand)
  sometimes take 2 to 4 points off one stat for good when they happen. No injury ends a career yet.
- **Where you see it.** The injury's name everywhere it showed where he was hurt: the planner's condition card, forecast
  and fight night summary, the fight night card (with what it cuts until it heals), the hub's card and This week, and the
  calendar's Hurt line.

Saved as `trainee.injury` (the injury's id), on the camp week's injury report as `injury` (and `dent`), on the fight's
record as `injury` `{id, days, dent?}`, and on the booking as `hid` (`docs/09` career@1; all optional, so an injury saved
before D406 loads unnamed and shows as "Leg injury"). Pure and seeded.

**Not yet:** career-ending injuries (D43), surgery and its choices, a doctor's check that lengthens a suspension, the
world's men getting injured and pulling out, an injury he carries into the fight changing how the AI fights (it only
changes his stats), and a reputation for hiding injuries.

**What to change:** the injuries themselves (names, days, effects, which sessions and fights cause them, their weights
and lasting dents) in `data/injuries/`. The fight chances and hiding in the constants at the top of
`sim/world/injuries.gd` (`FIGHT_CHANCE`, `HAND_PER_PUNCH`, `BRITTLE_HANDS`, `PUNCHES`, `HIDE_BASE`, `HIDE_PER_DAY`,
`HIDE_MAX`, `HIDDEN_WORSEN`); how hurt a healing injury starts him in `sim/world/training_camp.gd` (`HURT_PER_DAY`,
`HURT_MAX`). Where they're rolled: `TrainingCamp._run_slot` (camp) and `Career._fight_injury` (fights). Hiding is in
`ui/camp_planner.gd` (`hide_injury`) and the card in `ui/fight_night_card.gd`. Tested in
`tests/sim/world/test_injuries.gd`, `tests/ui/test_career_screens.gd` and `tests/data/test_data_files.gd`. Fights don't
change outside a career (no golden re-pin).

## 14. You own the gym (D440–D459)

Kyle (2026-11-04): "currently we are playing the middle with if we are the fighter or the coach. I think we need to really
focus on the fact we are the coach/gym owner." You own a small run-down gym from day one and grow it; the lad you raised
from 8 stays the main story, with a small stable of other fighters round him; when he retires the gym carries on. This
supersedes D26's "we stay single-fighter". The plan, its twenty questions and Kyle's answers (all my picks) are in the plan
doc (https://claude.ai/artifact/BrEV5jejZtpFWMJiT9HuYC). The pieces, in this order (D440):

| Piece | Decision | Status |
|---|---|---|
| You own the gym, and its money: three run-down places to open, the gym's own money from members' dues and 15% of his purses, rent; his fee and shifts gone | D441 | Built (§14.1) |
| Rooms and upgrades: mats, bag area, ring, cage, weights, recovery, video and changing rooms at three levels inside the building's floor space, 1 to 4 weeks to build with the room shut; faster training and a few sessions opened; the gym page as a drawn floor plan | D442 | Built (§14.2) |
| Hiring coaches: specialists for a weekly wage by level, mostly the world's retired fighters | D443 | Built (§14.3) |
| The gym's other fighters: named lads training there as sparring partners, walk-ins as it grows (was D407) | D444 | Built (§14.4) |
| Recruiting and the stable: signing the world's men, 2 fighters at first and up to 8, plans set once, each fight played or simmed, men who leave when unhappy | D445, D450 | Signing and training built (§14.5); their fights, played or simmed, built (§14.6, D450); their camps with the planner and minigames built (§14.7, D451) |
| The gym's name: members, who'll sign, which coaches come, news | D446 | Planned |
| Your own levels as head coach (was D408) | D447 | Planned |
| Expanding and moving: the unit next door, a bigger building (was D409) | D448 | Planned |
| When he retires: the gym carries on | D449 | Planned |

### 14.1 You own the gym, and its money (D441)

Kyle (2026-11-04) picked "Yes, a small run-down place", "Members plus a cut of purses", "Pick 1 of 3 run-down places",
"15%" and "Tight: members just cover rent", my picks.

**Where you open your gym** (`ui/gym_screen.gd`) is still the last step of a new career, with three cards side by side
(`Gym.offers`): three different kinds, the first suiting where he comes from, each a different run-down place
(`data/enums/gym_places.json`):

| Place | What it is | Members at first | Most it holds |
|---|---|---|---|
| A lock-up garage | One bulb, a roll-up door, a mat and two bags | 10–14 | 20 |
| A unit on the estate | An old print shop: mats, bags, a corner for weights | 14–18 | 35 |
| An old hall | A gym that's closing, sold as it stands | 20–26 | 50 |

Each card has the gym's name, the place, its kind and culture (they train as before, §11.3), the man you take it over from
(his face and a line, where the owner used to be) and its month: members × dues, the rent, and what's left big (*+$80 a
month*). *Open it here* picks it. At the walk-in the sign's paint is still wet: "this place is yours, and from today so is
he."

**The gym's money** (`Career.gym_money`, `sim/world/gym.gd`) is apart from his savings:

- **$500** to start (`START_MONEY`): what you put in.
- On the **first Monday of each month** (`Gym.month`) the members pay their **dues** (a member pays the kind's `fee`: a
  wrestling club $25–45, an MMA gym $70–110) and the **rent** goes out. The rent is 85% of what its first members pay, to
  the nearest $10 (`RENT_SHARE`), so the first year is tight: a garage of 12 at $40 is $480 in and $410 rent.
- **Members** then move one towards a number (two when they're five or more off): its first members plus **2 for each of
  his wins** (`MEMBERS_PER_WIN`), never more than the place holds. One may drift off in a month (25%, `LEAVE_CHANCE`), so
  with no wins it slowly empties. The drift rolls on its own dice, so nothing else in the career changes.
- The gym takes **15% of every purse** he's paid (`PURSE_CUT`): a $2,000 win pays the gym $300 and him $1,700. The
  fight's entry keeps it (`gym_cut`) and the result says so (*Purse $2000 (savings $1700, the gym's 15%: $300)*).
- Below $0 it's **behind on the rent**: news (*Advance* stops on it, the money shows red, a tip explains it). Nothing else
  happens yet; going under is for later (D43).

His **monthly fee and the Saturday gym shifts are gone**: it's your gym. His savings are only his purses and his background's
money now.

**The hub** says *Trains at your gym, …* on his card, and in *This week* "Your gym: $620 · A unit on the estate · 16
members at $40 a month · rent $540 · +$100 a month" above *His savings*. *Last week* says the gym's month when one turned
("The gym's month: dues $640, rent $540 (+$100), 16 members (+1).").

**Old saves.** A career saved before D441 (when he paid a fee at someone else's gym) loads with that gym as yours: a unit
with 16 members, its fee now what a member pays, and $500 (`Gym.made_yours`). What he owed is forgotten. A career from
before D313 still has no gym. Fights don't change (no golden re-pin).

**What to change:** the places in `data/enums/gym_places.json`; what members pay in each kind's `fee` in `data/gyms/`; the
money numbers at the top of `sim/world/gym.gd` (`START_MONEY`, `PURSE_CUT`, `RENT_SHARE`, `MEMBERS_PER_WIN`,
`LEAVE_CHANCE`, `OLD_SAVE_PLACE`, `OLD_SAVE_MEMBERS`) and the month in `Gym.month`; where the career turns it in
`sim/world/career.gd` (`end_week`, `_pay`, `GYM_BEHIND`); the cards and the walk-in in `ui/gym_screen.gd` (`gym_text`,
`money_text`, `place_line`, `walk_in_text`); the hub in `ui/career_hub.gd` (`gym_text`, `month_text`); the result's purse
row in `ui/result_card.gd`; the tip in `data/tips/gym_behind.json`. Tests: `tests/sim/world/test_gym.gd`,
`tests/ui/test_career_screens.gd`, `tests/data/test_data_files.gd`. Then update this section and D441.

### 14.2 Rooms and upgrades (D442)

Kyle (2026-11-04) picked "Faster learning, a few open sessions", "3 levels each, floor space limits", "1 to 4 weeks, room
shut", "A drawn floor plan from above", then "Only three need a room", "$300, $1,000, $2,500", "Yes, 1 more member a
level", "Its kind's rooms at level 1" and "Yes, a quarter back", all my picks.

**The rooms** (`data/enums/gym_rooms.json`, `sim/world/gym.gd`). Each is built at level 1 to 3 and takes 1 or 2 squares of
the place's floor (`floor` in `data/enums/gym_places.json`: a garage 4, a unit 6, the old hall 9, so even the hall can't
hold all eight, 11 squares; expanding is D448):

| Room | Squares | Each level | Needed for |
|---|---|---|---|
| Mats | 2 | Grappling and wrestling sessions +8% XP | |
| Bag and pad area | 1 | Striking sessions +8% | |
| Ring | 2 | Sparring +8%, sparring injuries 10% less likely | Hard sparring (or the cage) |
| Cage | 2 | Clinch work and Shark tank +10% | Shark tank, hard sparring (or the ring) |
| Weights room | 1 | Conditioning +6%, S&C a further +4% | |
| Recovery room | 1 | 5% less fatigue kept each night, injuries heal a day more each Sunday | |
| Video room | 1 | Film study +8%, 5% likelier to find one of his habits (§13.1) | Film study |
| Changing rooms | 1 | Room for 5 more members | |

A room's share adds to the gym kind's (§11.3): XP × kind × (1 + level × share). A full gym adds at most +24% to a kind
(clinch work, from the mats and the cage, +54%); a test holds it there.

**Sessions that need a room** (data/sessions `needs`, `instead`): hard sparring needs a ring or a cage, Shark tank the cage,
film study the video room. Without it the session's stand-in runs in its slot (light sparring, boxing drills, meditation):
a week plan's slots swap as the week runs (`TrainingCamp.with_rooms`), and in the camp planner they're greyed out with
"needs the video room" and a slot set to one takes the stand-in. A camp with no gym (the fight setup's) has everything.

**What a gym opens with.** Its kind's `rooms` (data/gyms) at level 1, then the place's (the old hall's tired ring), each
that still fits: a boxing gym or Muay Thai camp has bags and a ring, an MMA gym mats, bags and a cage (no cage in a garage),
a wrestling club mats and weights, a BJJ academy mats.

**Building.** On the gym's page click a room to upgrade it, or pick one to build from the list. A level costs **$300,
$1,000 or $2,500** (`ROOM_COSTS`) from the gym's money, straight away. It takes its level in weeks, one more for a 2-square
room, at most 4 (`build_weeks`: bags 1, a new ring 2, the cage to level 3 4), and the room is **shut** meanwhile (its
sessions stand in, its effects stop). One job at a time. When it's done it's news (*New in the gym: the video room*, *The
ring is level 2 now*; Advance stops on it) and the calendar shows the week. **Each level you build brings one more
member**: the members drift towards one more (§14.1), the rooms it opened with not counted. **Tearing a room down** takes a
week, frees its floor and gives a quarter of what you spent on it back now.

**The gym's page** (`ui/gym_page.gd`, `ui/floor_plan.gd`), from the hub's *Your gym* tab: the place drawn from above, its
squares inside the walls with the door at the bottom, each room drawn on its squares (blue mat tiles, red bags, a ring with
its ropes, the cage's octagon, bars and plates, an ice bath, a screen and sofa, lockers) with its name and three level
pips, a room being worked on striped yellow with its weeks to go, free squares dashed. A room stays on the squares it
was built on (`Gym.spots`); only when a new 2-square room can't fit round the others are they all laid out again. Along the top the gym's money and
month. Down the side the room you clicked: what it does at its level and the next, the next level's cost and weeks,
*Build level 2 · $1000* and *Tear it down · $75 back*; with nothing picked, every room you could build with its squares,
cost, weeks and what it does, each with *Build it* or why not. A tip the first time. The hub's *This week* says what's
being built.

**Old saves.** A gym from before D442 gets its kind's starting rooms. Fights don't change (no golden re-pin).

**What to change:** the rooms in `data/enums/gym_rooms.json` (`size`, the shares in `kinds` and `sessions` a level,
`injury`, `night`, `heals`, `finds`, `cap`); each place's `floor` and `rooms` in `data/enums/gym_places.json`; each kind's
`rooms` in `data/gyms/`; a session's `needs` and `instead` in `data/sessions/`; the costs and weeks at the top of
`sim/world/gym.gd` (`ROOM_COSTS`, `ROOM_LEVELS`, `BIG_ROOM`, `BUILD_WEEKS_MAX`, `TEAR_DOWN_WEEKS`, `TEAR_DOWN_BACK`,
`MEMBERS_PER_ROOM_LEVEL`); where training uses them in `sim/world/training_camp.gd` (`with_rooms`, the XP and the night)
and `sim/world/scouting.gd` (`find_chance`); building in `sim/world/career.gd` (`build_room`, `tear_down_room`, `end_week`,
`ROOM_DONE`); the page in `ui/gym_page.gd` and the drawing in `ui/floor_plan.gd`; the planner's list in
`ui/camp_planner.gd` (`at_gym`); the tip in `data/tips/gym_page.json`. Tests: `tests/sim/world/test_gym_rooms.gd`,
`tests/ui/test_gym_page.gd`, `tests/data/test_data_files.gd`. Then update this section and D442.

### 14.3 Hiring coaches (D443)

Kyle (2026-11-04) picked "Retired world fighters, plus others" and "A weekly wage by his level" on the plan, then on this
piece "Four trainers and a nutritionist", "5% a level, up to 15%", "$15, $40, $90 a week", "3 to 5 a month, mostly
ex-fighters", "Two weeks unpaid, then he leaves" and "Yes, three with a small twist", my picks. You stay his head coach (§11.1, your specialty unchanged). The coaches are the
specialists you pay, on the gym (`Staff`, `sim/world/staff.gd`; `gym.coaches`), so they save with it.

**The roles** (`data/enums/coach_roles.json`), one coach a role:

| Role | What he does a level | Who he was |
|---|---|---|
| Striking coach | Striking stats learn 5% faster | A retired boxer, brawler, counter-striker, dirty boxer, karate man, kicker, leg-kicker, Muay Thai man or sprawl-and-brawler |
| Wrestling coach | Wrestling stats learn 5% faster | A retired wrestler (any of the three wrestling styles) |
| BJJ coach | Grappling stats learn 5% faster | A retired BJJ man, judoka or Sambo man |
| Strength coach | Physical stats learn 5% faster | A career coach (never fought) |
| Nutritionist | The weight cut costs 20% less: its gas tank, its Chin and the chance of missing weight (§13.9) | A career coach |

A coach's stats are his attribute group's (`data/enums/stats`), from any session, on top of the gym's kind, its rooms and
your specialty. **His level** is what he did: a man who held a belt is level 3, a national or world-class pro level 2, the
rest level 1; a career coach's is rolled (60% level 1, 30% level 2, 10% level 3). **His personality**
(`data/enums/coach_personalities.json`): *Hard* (5% more in his group, injuries in training 15% likelier), *Patient*
(injuries 15% less likely) or *Fiery* (a party animal skips 30% fewer sessions).

**Wages:** **$15, $40 or $90 a week** by level (`WAGES`), from the gym's money every Monday after the month's dues are in.
A coach the gym can't pay that Monday coaches on unpaid (news each week: *Couldn't pay Joe Hart, your striking coach, this
week*); after **2 weeks unpaid** he walks out on the third (*Joe Hart has walked out: 3 weeks without pay*). A week paid
clears it; missed wages aren't owed. **Each coach's level brings a member** (the members drift towards one more a level,
as a room's does, §14.2). Letting a coach go costs nothing.

**Who's looking for work** (`Career.coaches_looking`, `Staff.looking`) changes on the first of every month: 3 to 5 men,
one or two career coaches and the rest the world's retired fighters from his country (§12.3, the 10 years of history
included), his style deciding his role, none already on your staff. A former champion says so (*Former BFL champion,
13-8-1*); a career coach has a line from his role's `career` (*Ran the weights room at a rugby club*). The list is made the
first time it's looked at in a month and kept on the gym (`looking`, `looking_at`).

**The gym's page** has two tabs, *Rooms* (§14.2) and *Coaches* (`ui/coaches_view.gd`): your coaches down the left, one
row a role, each with his face (drawn from his name, as the old owner is), name and age, role, level, personality and
wage, who he was, what he does, a warning when he's unpaid and *Let him go*; down the side the men looking for work, each
with *Hire him · $40 a week* or *You have one*. The money line adds the week's wages, and the hub's gym line names them
(*Coaching with you: Reece Wright (striking) and Ann Lee (nutritionist) · $105 a week in wages*).

**Not yet:** coaches teaching moves (D40's catalogue), a cutman (cuts don't change fights yet, D375), coaches in your
corner on fight night, poaching (D26), coaches getting better, and the gym's name deciding who comes (D446). The coaches
are drawn in fight shorts, like the old owner, until people off the fight screen get clothes.

**Old saves.** A gym from before D443 has no coaches. Fights outside a career don't change (no golden re-pin).

**What to change:** the roles (`group`, `xp`, `cut`, `styles`, `career`) in `data/enums/coach_roles.json`; the
personalities (`xp`, `injury`, `skips`) in `data/enums/coach_personalities.json`; the wages, levels, members, unpaid weeks
and who comes looking at the top of `sim/world/staff.gd` (`WAGES`, `MEMBERS_PER_LEVEL`, `UNPAID_WEEKS`, `LOOKING`,
`CAREER_COACHES`, `CAREER_LEVEL_ODDS`, `OLDEST`, `LEVEL_TWO_TIERS`); where they act in `sim/world/training_camp.gd`
(`learning`), `sim/world/gym.gd` (`skip_share`, `injury_share`, `members_target`) and `sim/world/weight_cut.gd` (`side`'s
`ease`); the wages in `sim/world/career.gd` (`end_week`, `COACH_UNPAID`, `COACH_LEFT`, `coaches_looking`, `hire_coach`,
`let_go_coach`); the tab in `ui/coaches_view.gd` and `ui/gym_page.gd`, the hub's line in `ui/career_hub.gd`
(`coaches_line`). Tests: `tests/sim/world/test_staff.gd`, `tests/ui/test_gym_page.gd`, `tests/data/test_data_files.gd`.
Then update this section and D443.

### 14.4 The gym's other fighters (D444)

Kyle (2026-11-05) said "you can start now", then picked "Real local men from the world", "Better partners, faster
sparring", "2 to start, 1 more per 8 members", "Never while they share a gym", "Sometimes, and come back as rivals" and
"A Fighters tab on the gym page", my picks. These are phase 4's sparring partners (D407). The lads
are **real men from the world** (§12.2), not made-up partners: they keep fighting on the world's cards and their records
grow. They're on the gym (`Lads`, `sim/world/lads.gd`; `gym.lads`, a snapshot of each: id, name, style, born, average
stat, record, pro, country, the week he came), so they save with it; the world's own man is the truth and the snapshot is
refreshed each month.

**Who walks in** (`Lads.candidates`): a man still fighting, **15 to 30**, an amateur or a local or regional pro, from
his country, not at the gym and never left it; **his town's men first**, then the rest by id, one of the first dozen
picked. The first time the gym is looked at (a new career, or an old save) **two** walk in.

**How many:** the gym has **room for one lad for every 8 members, 2 to 8** (`room`). On the first of each month every lad's
snapshot is refreshed; a man who's retired goes (*Jake Moss has retired and left the gym*); each lad **leaves at 5%**
(*Jake Moss has left the gym to train somewhere else*); then, while there's room, **one walks in at 35%** (*Jake Moss
walked in to train at Hill's Gym*). The news goes on the hub and the calendar; *Advance* runs on past it
(`Career.JUST_NEWS`). Seeded: the same month brings the same men.

**What they do for him.** A session with a partner (`partner: true` in `data/sessions/`: hard and light sparring, rolling,
wrestling drills, clinch work, the sprawl drill, Shark tank) **learns faster with a better partner**: his best lad's
average stat against his own, **up to 15% more at 10 points better, down to 10% less** when they're all that much worse
or there's nobody (`partner_share`), on top of the gym, its rooms and coaches. So a lad who outgrows his gym trains
slower until better men walk in, and a growing gym (more members) has room for more.

**Fights.** A gym-mate is **never offered against him** (`Matchmaker.pick_man`); a man who's left (`gym.former`) can be,
and the offer says *He used to train at Hill's Gym*.

**The gym's page** has a third tab, *Fighters* (`ui/lads_view.gd`): him first (*your lad*, his record and average stat),
then each lad with his face, name and age, style, record, how he compares (*Well ahead of him*, *Better than him*,
*About even*, *Still learning*, *Well behind him*) and how long he's trained there; down the side the best partner and
what he does to the partner sessions now, the room the members make, and the men who used to train there. The hub's gym
line adds *2 other lads train here · best sparring partner: Jake Moss (about even)*.

**Not yet:** training them yourself (D445's third piece; signing them to your stable is §14.5), sparring a named lad in a session, lads getting
hurt in sparring, and the gym's name deciding who comes (D446).

**Old saves.** A gym from before D444 trains as before until it's next played, when its first two lads walk in. Fights
outside a career don't change (no golden re-pin); a career's partner sessions do.

**What to change:** the numbers at the top of `sim/world/lads.gd` (`MEMBERS_PER_LAD`, `MIN_LADS`, `MAX_LADS`,
`WALK_IN_CHANCE`, `LEAVE_CHANCE`, `PARTNER_UP`, `PARTNER_DOWN`, `PARTNER_SPREAD`, `AGES`, `TIERS`); which sessions have a
partner (`partner` in `data/sessions/`); where it acts in `sim/world/training_camp.gd` (`_run_slot`), `sim/world/career.gd`
(`end_week`, `gym_lads`, `LAD_IN`, `LAD_LEFT`) and `sim/world/matchmaker.gd` (`pick_man`, `_offer`); the tab in
`ui/lads_view.gd` and `ui/gym_page.gd`, the hub's line in `ui/career_hub.gd` (`gym_text`, `best_partner_text`). Tests:
`tests/sim/world/test_lads.gd`, `tests/ui/test_gym_page.gd`, `tests/data/test_data_files.gd`. Then update this section
and D444.

### 14.5 Your stable (D445)

Kyle (2026-11-05) said "You can start", then picked "Three pieces, signing first", "Gym lads and local men", "A chance by
what your gym offers", "One place per 10 members", "A focus, like striking or wrestling" and "Losing, waiting, or a broke
gym", my picks. D445 comes in three pieces: **signing men and their training** (this one), then **their offers and fight
nights** (each played or simmed), then **opening their planner and the minigames**. The men you sign stay **the world's
men** (§12.2): the world plays their fights on its cards (§12.3), and the stable is on the gym (`Stable`,
`sim/world/stable.gd`; `gym.stable`, each a lad's snapshot plus his focus and how he feels), so it saves with it.

**Places.** The gym runs **one fighter for every 10 members, 2 to 8, his own lad among them** (`places`): a new unit's
16 members make room for him and one more, a busy unit 3, a full hall 5; 8 waits for a bigger building (D448).

**Who you can sign** (`prospects`, the gym page's *Stable* tab): the gym's lads first (§14.4), then up to **10** of his
country's amateurs and local or regional pros aged **16 to 30**, his town's first and then the best. Offering a man a
place (*Offer him a place*) rolls **his chance of saying yes** (`yes_chance`): **70% for an amateur, 25 points less a
level up** (45% for a local pro, 20% for a regional one), **3 points more for every room and coach level** at the gym,
**20 more for a lad who already trains there**, kept between 5% and 95%. A man who says no **won't be asked again for 13
weeks** (`gym.asked`). The roll comes from the career's seed, the man and the week, so asking again the same week can't
change it. A man who signs comes off the lads; he's still at the gym, so he's never offered against your lad.

**Training.** Each man has **a focus you set once** (`data/enums/stable_focus.json`): *All-round*, *Striking*,
*Wrestling*, *Grappling* or *Fitness*. Each week he grows **about half as much again** as he would on his own (the
world's growth for his age and potential, `WorldWeeks.growth_a_week`), × the gym's rooms for his focus's kind of session
and its coach for his focus's stats (`boost`), and the extra goes into **his focus's stats** (the world man's `gains`), so
a striking focus makes him a better striker as well as better on average. All-round spreads it over every stat. A
22-year-old regional pro on *Striking* at a new unit adds about 1.5 to his average stat in a year on top of his own 3 or
4, about 5 points in each striking stat. A man going backwards with age loses nothing extra.

**Money.** A pro fight pays him his promotion's purse (as the career's purses are, §12.4); **the gym takes 15%**
(`Gym.PURSE_CUT`), straight into its money. The hub says *Harry Wright beat Tom Reid by knockout · the gym's cut $1350*.
Amateurs aren't paid. Since D450 the world doesn't make your stable's fights at all: your gym books them (§14.6), and
never two of your stable against each other. A champion's or the next man in line's title fights are still the
world's.

**Leaving.** On the first of each month (`month`) each man's snapshot is refreshed and a man who's retired goes. A man is
**unhappy** when he's **lost 3 in a row**, gone **26 weeks without a fight**, or the gym's **behind on the rent**. The first
month you're warned (*Harry Wright is unhappy (3 losses in a row): put it right or he'll leave next month*, which stops
*Advance*); a happy month clears it, and **a second unhappy month in a row and he leaves** (`gym.former`, so he can be
offered against your lad). *Let him go* does the same at once.

**On screen.** The gym page's fourth tab, *Stable* (`ui/stable_view.gd`): down the left *YOUR STABLE* and how many places
are used, him first, then each signed man with his face, name and age, style, record, average stat, his focus and how
much faster the gym makes him learn, *Happy here* or why he's unhappy, a focus picker and *Let him go*; down the side
*SIGN A FIGHTER*, each prospect with his face, what he is, his chance of saying yes and *Offer him a place* (or why you
can't). The *Fighters* tab lists your stable after him, and your stable spars with him like the lads (§14.4). The hub's
gym line adds *Your stable: Harry Wright · 2 of 3 places*. Signings and fights are news on the hub and the calendar and
*Advance* runs on past them (`Career.JUST_NEWS`); a warning or a man leaving stops it.

**Not yet:** a week planner between fights (their fights are §14.6, their camps §14.7), the gym's name drawing better men (D446), and signing national or world-class men.

**Old saves.** A gym from before D445 has an empty stable. Fights outside a career don't change (no golden re-pin), and a
career without a stable plays as before.

**What to change:** the numbers at the top of `sim/world/stable.gd` (`PER_MEMBERS`, `MIN_PLACES`, `MAX_PLACES`,
`PROSPECTS`, `AGES`, `TIERS`, `YES_BASE`, `YES_PER_TIER`, `YES_PER_LEVEL`, `YES_LAD`, `YES_RANGE`, `ASK_AGAIN_WEEKS`,
`BOOST`, `LOSSES_IN_A_ROW`, `IDLE_WEEKS`, `UNHAPPY_MONTHS`); the focuses in `data/enums/stable_focus.json`; where it acts
in `sim/world/world_weeks.gd` (`_age_a_week`, `play_week`), `sim/world/world.gd` (`average`, `gained`, `profile`) and
`sim/world/career.gd` (`world`, `end_week`, `stable_prospects`, `sign_fighter`, `release_fighter`, `set_stable_focus`,
`STABLE_SIGNED`, `STABLE_FOUGHT`, `STABLE_UNHAPPY`, `STABLE_LEFT`); the tab in `ui/stable_view.gd` and `ui/gym_page.gd`,
the hub's line in `ui/career_hub.gd` (`stable_line`). Tests: `tests/sim/world/test_stable.gd`,
`tests/ui/test_gym_page.gd`, `tests/data/test_data_files.gd`. Then update this section and D445.

### 14.6 Your stable's fights (D450)

Kyle (2026-11-06) said "You can start now" for D445's second piece, and answered its five cards (below). **Offers come
in for each man, and you pick one**, like your lad's offers; **you play or sim each fight**, from the hub or from your
lad's camp. The world doesn't make their fights any more (`WorldWeeks.play_week` leaves your stable out).

**Offers.** A man due a fight (the world's `next_week`, not hurt) gets **up to 3 offers** (`OFFERS`, `Stable.make_offers`,
run each Monday from `Career.end_week`), each for a fight **3 weeks ahead** (`LEAD_WEEKS`): a pro on his promotion's next
card from then (*NCC 14*), an amateur that Saturday. The men are the world's whose average stat is within `MATCH_GAP`
(10 points) of **his** (`Stable.find_opponents`), in his division, pro against pro on the same promotion, amateur
against amateur of his age group (under or over 18), not at your gym, not hurt, not a champion or the man next in line,
not met lately and not booked to fight your lad or in his offers. Of those he's offered, as your lad is, the men nearest
**a bit easier, about even and a bit harder** than him (5 points either side, Matchmaker's `DIFFICULTY_LEVELS`;
`Stable.pick_opponents`), each marked by how they compare (*Much harder* past 6 points, *A bit harder* past 3, *About
even*; `Stable.difficulty`) and with **his chance of winning** (the quick result model, `ResultModel.win_chance`). A man
whose promotion is well above him only gets harder fights, and the chance says so. The news says *3 fight offers for Harry Wright: pick one on the hub*,
which **stops Advance**. The hub's middle shows *OFFERS FOR YOUR STABLE*: each man, then each offer (*vs Tom Reid (5-2-0)
· About even · NCC 14, Sat 14 Mar · Professional MMA · 54% he wins*) with **Take it** (he's booked, his other offers go) and **Turn it
down** (that one goes, the rest stay). The Stable tab says *3 fight offers waiting: pick one on the hub*. Offers are open
**2 weeks** (`OFFER_WEEKS`, `offers_until`) and then go; the next set can come a week after that (`OFFERS_GAP`,
`wait_until`). The men in a man's offers are held back from the world's pairings and from your lad's offers while
they're on the table (`Stable.busy`).

**Booked.** A taken offer is his booked fight: on the calendar (purple gloves) and the *Stable* tab (*Next: Tom Reid,
Sat 14 Mar · NCC 14*). **Turn the fight down** (on the Stable tab, or in fight week) frees the other man, and no offers
come for **4 weeks** (`TURN_DOWN_WEEKS`). A booked man isn't unhappy for waiting; a man whose offers you keep leaving
can be (six months without a fight, §14.5).

**Fight night.** The Monday of the week of his fight, the news says *Fight night for Harry Wright: Tom Reid this
Saturday. Play it or sim it from the hub*, which **stops Advance**. The hub's middle shows *YOUR STABLE FIGHTS THIS
SATURDAY* with each man's fight (the two men and their records, the card, the rules) and three buttons:

- **Play it**: the fight screen with **you in his corner**, every call as for your lad, the two men as they are (or as his
  camp leaves him, §14.7), under the booking's rules. No habit cues: you haven't scouted the other man.
- **Sim it**: the same fight run at once by the fighters' own AI, straight to the result, as *Sim the fight* (D305).
- **Turn it down**.

Either way the result goes **onto the world** (`Stable.settle`, `WorldWeeks.record`, split out of `WorldWeeks.fight`):
both men's records, histories, form, rankings and promotions, as the world's own fights do, the gym's 15% of a pro purse,
and the news (*Harry Wright beat Tom Reid by knockout · the gym's cut $1350*). It isn't on your lad's record.

**In your lad's camp.** The camp planner has the same box above its buttons (`CampPlanner.stable_box`): the week's
offers with Take it and Turn it down, and the week's fights with Play it, Sim it and Turn it down. A fight played or
simmed from the camp ends on *Back to the camp*. *Run every week left* stops on a week with new offers or a fight night
for your stable, as Advance does on the hub.

**Left alone.** A fight nobody opened by the end of its week (running the week anyway, on the hub or in the camp) is
decided by **the world's quick result** (`Stable.quick`: ResultModel, with form and rust) when the week ends, onto the
world the same way.

**The cards** (Kyle's answers, 2026-11-06): how their fights are made: **offers to pick from, like his** (Kyle's pick;
mine was booked for them with a Turn it down); what Play means: **the fight screen, you in his corner** (my pick); what
Sim does: **the full engine at once** (my pick); a fight you don't open: **Advance stops, and running the week anyway is
the quick result** (my pick); while your lad's in camp: **play or sim them from the camp** (Kyle's pick; mine was the
quick result).

**Not yet:** their title fights offered and played (still the
world's), and a stable man's injuries beyond the world's time out after a knockout.

**Old saves.** A stable saved before D450 has no offers; each man's first come the next Monday he's due a fight.

**What to change:** the numbers at the top of `sim/world/stable.gd` (`OFFERS`, `OFFER_WEEKS`, `OFFERS_GAP`,
`LEAD_WEEKS`, `MATCH_GAP`, `TURN_DOWN_WEEKS`, `CARD_SEARCH_WEEKS`); where it acts in `sim/world/stable.gd`
(`make_offers`, `find_opponents`, `pick_opponents`, `difficulty`, `take`, `decline`, `turn_down`, `settle`, `quick`),
`sim/world/world_weeks.gd` (`record`, `play_week` leaving your stable out), `sim/world/matchmaker.gd` (`pick_man` leaving
your stable's men out), `sim/world/career.gd` (`_stable_fights`, `stable_fight`, `finish_stable_fight`,
`take_stable_offer`, `decline_stable_offer`, `turn_down_stable_fight`, `calendar`, `STABLE_OFFERS`,
`STABLE_FIGHT_NIGHT`) and `game/main.gd` (`play_stable_fight`, `sim_stable_fight`, `take_stable_offer`,
`_finish_stable_fight`, `_back_to_career_camp`); the box in `ui/stable_fights_box.gd` (on the hub, `ui/career_hub.gd`,
and in the camp, `ui/camp_planner.gd`), the Stable tab's line in `ui/stable_view.gd`. Tests:
`tests/sim/world/test_stable_fights.gd`, `tests/ui/test_gym_page.gd`, `tests/game/test_main_scene.gd`. Then update this
section and D450.

### 14.7 Your stable's camps (D451)

Kyle (2026-11-06) said "Start now" for D445's third piece: their planner and minigames. **A stable man booked for a fight
gets a camp you can open**, the same planner as your lad's, run **a week at a time with the calendar**, ending on his
fight night card. Kyle picked my recommendation on all five cards (below).

**Opening it.** On the *Stable* tab a booked man has **Plan his camp** next to his fight. It opens the camp planner on a
camp made from the world man as he is (`Career.stable_camp`, a `TrainingCamp` from his world profile with your gym's
rooms and your specialty), counting down the weeks to his fight (*Week 1 of 4*). Every session, preset and minigame
works as in your lad's camp (Mitt work, Film study, Sprawl drills, Heavy bag, Thai pads; film study on a man of the
other man's style). The weeks picker, *Reset* and *Run every week left* are hidden; the back button is *Back to your
stable*. Once opened his **focus stops training him** while the camp does (`Stable.trained` leaves him out) and the
button reads *His camp this week*, *His fight week* or, when the week's run, *This week's camp is run*. The tab's line
adds *his camp: 4 weeks to go, fatigue 3*.

**A week at a time.** *Run week N* runs this week and goes back to the Stable tab; the next week opens on Monday (the
planner says *This week's run: back on Monday*). What the week did **stays on the world man** (his stats' `gains`,
`Stable.add_gains`), so his record, rankings and the quick result all see it, and the camp's fatigue and any injury are
saved on his stable entry. A week you don't run **runs on the plan you left** on his planner (the *Balanced* preset if
you never set one, `Stable.CAMP_PLAN`) when the week ends, so an opened camp never stalls Advance.

**Fight night.** Fight week runs as the last week and ends on **his fight night card**: his gas tank from the camp's
fatigue, any injury and the doctor, then *Fight!* (the fight screen, you in his corner), *Sim it* or *Pull out of the
fight* (turned down). Play it and Sim it on the hub or in your lad's camp still work: fight week runs on his plan first
if you haven't run it, and he fights **as his camp leaves him** (`TrainingCamp.fight_profile`, his condition and any
injury). If the doctor won't clear him, **the fight's off**: the news says *Jake Moss's fight with Tom Reid is off: the
doctor won't clear him after his camp*, the fight is turned down, and the injury keeps him out (the world man's
`out_until`) until it heals. A hurt man left alone isn't put in the fight either.

**After.** The fight (or turning it down) ends the camp: back on his focus, and any injury from it keeps him out the
weeks it has left (`Stable.end_camp`).

**A camp you don't open.** Nothing changes: his focus trains him and the fight is as in §14.6, fresh.

**The cards** (Kyle's answers, 2026-11-06, all my picks): what opening a man gives: **a camp for his booked fight**;
an unopened camp: **his focus trains him, as now**; what carries into his fight: **gains, fatigue and injuries**; how
much of your lad's camp: **sessions and minigames now** (scouting, drilled rules and the weight cut later); what it
costs your lad: **nothing, you plan both**.

**Not yet:** scouting and film study on the other man, drilled rules and the weight cut for a stable man's camp; a
planner for his weeks between fights; their title fights (still the world's).

**Old saves.** A stable saved before D451 has no camps; *Plan his camp* opens one for a booked man the next time you
look.

**What to change:** `CAMP_PLAN` at the top of `sim/world/stable.gd`; where it acts in `sim/world/stable.gd` (`camp_of`,
`can_camp`, `camp_weeks_left`, `add_gains`, `end_camp`, `trained`, `settle`, `turn_down`, `month`), `sim/world/career.gd`
(`stable_camp`, `_camp_for`, `stable_camp_week`, `set_stable_camp_plan`, `stable_camp_ran`, `stable_cleared`,
`_catch_up_stable_camp`, `_call_off_stable_fight`, `stable_fight`, `_stable_fights`, `STABLE_CALLED_OFF`) and
`game/main.gd` (`open_stable_camp`, `_stable_camp_week`, `_stable_camp_back`); the planner's stable mode in
`ui/camp_planner.gd` (`use_stable`, `use_plan`, `waiting_for_monday`), the button in `ui/stable_view.gd` (`camp_label`).
Tests: `tests/sim/world/test_stable_camp.gd`, `tests/game/test_main_scene.gd`. Then update this section and D451.

