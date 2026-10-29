# 08 — Amateur vs Pro Rules & the Teen Amateur Stage

> Related decisions: D20, D35, D83. Status: **v1 spec**.
> Based loosely on real amateur MMA rule sets, kept simple and fictional (no real federation is named).

---

## 1. Ruleset comparison

| Rule | Teen amateur (16–17) | Adult amateur (18+) | Pro |
|---|---|---|---|
| Rounds | 3 × 2 min | 3 × 3 min | 3 × 5 min; 5 × 5 min for main events/titles |
| Protective gear | Headgear, shin guards, 8 oz gloves | Shin guards, 6 oz gloves | 4 oz gloves, none else |
| Elbows | ✗ | ✗ | ✓ |
| Strikes to the head on the ground | ✗ (body only) | ✗ | ✓ (ground-and-pound) |
| Knees to the head | ✗ | Standing only, in the clinch | Standing only (no knees to a grounded opponent) |
| Heel hooks / neck cranks / slams | ✗ | ✗ heel hooks, ✗ slams | ✓ (except spiking) |
| Standing 8-count / ref stoppage | Ref stops early (safety bias) | Ref stops early | Ref personality (D20) |
| Judging | 10-point must, more weight on technique | 10-point must | 10-point must, judge personalities |
| Pay | None (entry fee); medals / trophies | None or travel money | Purse + win bonus |
| Weigh-ins | Same day, no big cuts | Same day | Day before (allows weight cuts, D23) |

**Simulation impact:** each rule is a flag in a `Ruleset` data file the fight engine reads (illegal actions removed from the AI
and the call bar; protective gear multiplies damage and cut chances). Same engine, different data. In the engine now (D120,
D121, `01` §24): elbows are illegal and ground strikes go to the body under both amateur rulesets, and `early_stoppage_bias`
(adult 0.3, teen 0.5) makes the referee stop it sooner: at 15% / 25% health instead of 0, and one unanswered shot sooner.
The heel hook (D132, `01` §30) is illegal under both amateur rulesets through `heel_hooks`; the ankle lock and kneebar are allowed.

### 1.1 PRIDE rules (D141, `01` §33)
A fourth ruleset, for fun and for the PRIDE fans (Kyle, 2026-10-29: "pride never die"). Pro and amateur fights stay on unified
rules. `data/rulesets/pride.json`:

| Rule | PRIDE |
|---|---|
| Rounds | A 10-minute first round, then two of 5 minutes (`round_lengths`) |
| Elbows | ✗ (PRIDE banned elbows to the head) |
| Knees to the head | Standing and on the ground (`knees_to_head_grounded`) |
| Soccer kicks and stomps | ✓ on a knocked-down opponent (`soccer_kicks`, `stomps`) |
| Heel hooks / slams | ✓ |
| Judging | The whole fight, not round by round: the effort to finish first, then control, then aggression (`judging: whole_fight`). No 10-9s and almost no draws |
| Gloves, weigh-ins, pay | 4 oz, the day before, a purse |

## 2. Teen amateur stage (D83)

- **Ages ~16–18.** You fight on local and regional amateur cards (4–10 fights in total).
- **School/family balance**: the weekly planner has fewer slots (school days). Life events involve parents, school, friends.
- **Amateur record & medals** feed pro hype at debut (a strong amateur record → better first pro contract).
- **Tournament format** (optional events): a one-day bracket of 2–3 short fights, with damage carrying over between them. Great for stories and minigame variety.
- **Turning pro**: possible from 18. The game recommends it based on record + skills, but the timing is your choice
  (too early = risky, too late = lost prime years).
- **Weight class emerges (D35)**: amateur weigh-ins use walk-around weight. The pro division is chosen when you turn pro.

## 3. Pro variants
- **Short notice**: no full camp, so readiness penalties apply.
- **Catchweight**: the agreed weight sits between divisions.
- **Title fights**: 5 rounds, championship pay.
- **Foreign bouts** (D74): local rule variants (e.g. a Muay Thai bout in Bangkok uses kickboxing rules: no takedowns, clinch knees allowed, scoring on kicks/knees).
