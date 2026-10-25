# 10 — Phase 1 Fight Prototype Spec (draft)

> **One question this prototype answers:** *Does calling the takedown during the kick feel right?*
> Everything not needed to answer that is out of scope. Status: **v1: approved in principle; final go after the Phase 0 wrap-up tasks**.

---

## 1. Scope

### In
- Headless `FightSim` (tick-based, seeded) per `01-fight-engine.md` §2–§8 (simplified).
- **Positions:** Standing (distance bands + cage proximity), Cage clinch, Ground: Full guard top/bottom, Scramble. *Side control and Mount moved to after the playtest (D98).*
- **Actions (~15):** jab, cross, hook, leg kick, body kick, head kick, teep, knee, double leg, single leg, catch-kick single,
  sprawl, clinch entry, clinch break, get up, sweep. *Ground-and-pound and guard pass after the playtest (D98).*
- **Calls (9):** Pressure, Circle out, Work the range, Takedown, Clinch, Defend the shot, Get up, Survive, Stay safe,
  plus **one read call: "Catch the kick!"**
- **Voice meter**, call delay, compliance (ego/trust), the visible processing ring.
- **Drilled rules (D82)**: 2 slots, simple trigger → action, with a reliability slider standing in for camp drilling. Includes cooldown and opponent adaptation.
- **2 fighters with authored tendencies + 1 tell each**:
  - Opponent A, "Kicker": throws a right body kick after their jab is blocked (~70%).
  - Opponent B, "Wrestler": telegraphs a level change with a stance shift before shooting.
- **Damage & stamina** (head/body/legs, simple). KO/TKO and decision (simple 10-point scoring). 3 rounds.
- **Isometric grey-box view (3D, D80)**: capsule fighters on a low-poly octagon, orthographic camera with clinch/ground zoom, action labels, flags shown as icons, slow-mo toggle, event text feed.
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

Merged acceptance tests from the Foundation doc (A13):

| Test | Pass when |
|---|---|
| Timing | A well-timed call/rule exploits a real opening without guaranteeing success |
| Tactical value | Over many seeds, correct timing beats poor timing by a clear margin |
| Fairness | Skilled opponents can defend, and the log explains why |
| Slow motion | Slow-mo gives decision time without changing the simulation result |
| Rules (if C2 adopted) | Rules fire only when eligible; conflicts resolve by priority, predictably |
| Autonomy | With no calls, fighters still fight competently and in character |
| Readability | Testers can name range, position, current action and the opening |
| Reproducibility | Same seed + same commands → identical fight |

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
| 7 | Grey-box isometric view + slow-mo + call buttons/hotkeys | Built in #19 (D117): `06` §6 |
| 8 | Playtest build + playtest checklist | Built in #20 (D118): the Windows download, the playtest fights, saved fights and the report, and the script, form and write-up template in `docs/playtests/` |

---

## 4. Milestone breakdown (~6–8 weeks at 20 h/week)

1. **Week 1:** Godot learning + project skeleton + CI + first sim test (two fighters trade jabs headless).
2. **Weeks 2–3:** Standing game: distance, cage, action phases, flags, damage, stamina. Harness v1.
3. **Week 4:** Clinch + takedowns (incl. catch-kick) + sprawl + simple ground (trimmed per D98). The balance harness v1 comes before the AI (D95).
4. **Week 5:** Calls, delay, voice, compliance, read call. "Ideal caller" and "spam caller" bots.
5. **Week 6:** Grey-box view, slow-mo, feed, debug overlay.
6. **Weeks 7–8:** Tuning + playtests (you plus 2–4 friends) + write-up → go / adjust / rethink.

---

## 5. Additions from decisions D49–D54
- **Read call "Catch the kick!"** and all now calls are in scope (D49).
- **Scouted-tell cue**: a toggle in the prototype to compare cue on vs off (D51).
- **Perfect-call flourish** (D52) and **auto slow-mo** on rocked/knockdown (D53).
- **Active pause** behind an "Easy" toggle (D50).
- **Keyboard + mouse**: hotkeys 1–9 + clickable call bar (D54).
- **Speed control first** (D91): the playtest compares 1× and 2× fight speed before D9's 2× is confirmed.
- **Playtest build**: Windows export + a feedback form for friends and the Discord (D62). How to run one: `docs/playtests/README.md` (D118).

## 6. Approval checklist
- [x] S1: now/read call split confirmed (D49)
- [x] S2: no art; mechanics first (D61)
- [x] S3: playtesters: friends + small Discord (D62)
- [ ] Final sign-off from you → Phase 0 wrap-up → coding begins
