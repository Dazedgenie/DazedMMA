# 10 — Phase 1 Fight Prototype Spec (draft)

> **One question this prototype answers:** *Does calling the takedown during the kick feel right?*
> Everything not needed to answer that is out of scope. Status: **draft, not approved for coding**.

---

## 1. Scope

### In
- Headless `FightSim` (tick-based, seeded) per `01-fight-engine.md` §2–§8 (simplified).
- **Positions:** Standing (distance bands + cage proximity), Cage clinch, Ground: Full guard top/bottom, Side control, Mount, Scramble.
- **Actions (~15):** jab, cross, hook, leg kick, body kick, head kick, teep, knee, double leg, single leg, catch-kick single,
  sprawl, clinch entry, clinch break, ground-and-pound, guard pass, get up, sweep.
- **Calls (9):** Pressure, Circle out, Work the range, Takedown, Clinch, Defend the shot, Get up, Survive, Stay safe,
  plus **one read call: "Catch the kick!"**
- **Voice meter**, call delay, compliance (ego/trust), the visible processing ring.
- **2 fighters with authored tendencies + 1 tell each**:
  - Opponent A, "Kicker": throws a right body kick after their jab is blocked (~70%).
  - Opponent B, "Wrestler": telegraphs a level change with a stance shift before shooting.
- **Damage & stamina** (head/body/legs, simple). KO/TKO and decision (simple 10-point scoring). 3 rounds.
- **Isometric grey-box view**: capsules on a polygon cage, action labels, flags shown as icons, slow-mo toggle, event text feed.
- **Debug overlay** + **balance harness** (headless N-fight CSV).

### Out (later phases)
Submissions struggle, corner/cutman, officials personalities, fouls, commentary personalities, career, training, art.

---

## 2. Success criteria (playtest)

1. **Feel**: in a blind playtest, at least 4 of 5 testers can explain *why* a successful catch-kick takedown worked.
2. **Learnability**: by fight 3 against "Kicker", testers land at least 2 well-timed takedowns per fight.
3. **Impact**: harness numbers show good coaching (scripted "ideal caller" bot) beats no coaching by
   **+10–20% win rate** in even matchups, and spam-calling (bot) does *worse* than no coaching.
4. **Punishment readability**: testers can explain why a bad takedown failed (sprawl, knee, guillotine risk flagged).
5. **Fun**: testers want to play another fight (subjective, but it's the real test).

---

## 3. Deliverables

| # | Deliverable | Notes |
|---|---|---|
| 1 | Godot 4 project skeleton, folder structure, GUT tests, CI | `sim/`, `game/`, `ui/`, `data/`, `tests/` |
| 2 | Data format for actions/positions/calls | JSON or `.tres`; decided at task start |
| 3 | `FightSim` core + unit tests | Deterministic replay test from seed + command log |
| 4 | Fighter AI (utility) + tendency/tell rules | |
| 5 | Call processor + voice meter | |
| 6 | Balance harness | CSV + summary printout |
| 7 | Grey-box isometric view + slow-mo + call buttons/hotkeys | |
| 8 | Playtest build + playtest checklist | |

---

## 4. Milestone breakdown (~6–8 weeks at 20 h/week)

1. **Week 1:** Godot learning + project skeleton + CI + first sim test (two fighters trade jabs headless).
2. **Weeks 2–3:** Standing game: distance, cage, action phases, flags, damage, stamina. Harness v1.
3. **Week 4:** Clinch + takedowns (incl. catch-kick) + sprawl + simple ground.
4. **Week 5:** Calls, delay, voice, compliance, read call. "Ideal caller" and "spam caller" bots.
5. **Week 6:** Grey-box view, slow-mo, feed, debug overlay.
6. **Weeks 7–8:** Tuning + playtests (you plus 2–4 friends) + write-up → go / adjust / rethink.

---

## 5. Open questions before approval
- S1. Should we confirm the **now call vs read call** split (F1) before building it?
- S2. Are you OK with this prototype having **no real art** at all?
- S3. Who are your playtesters? (Friends, Discord, a modding community?)
