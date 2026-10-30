# Chin Check — notes for AI coding sessions

- Design docs in `docs/` are the source of truth (decisions log: `docs/00-design-planning.md` §0).
  Every change should trace to a doc section or GitHub issue. If code and docs disagree, flag it.
- Engine: **Godot 4.7** (`project.godot`). Typed GDScript (`var x: int`, `:=`), tabs for indentation.
- Layers: `sim/` is pure logic with no Node/scene-tree use (see `sim/README.md`); `game/` and `ui/` are presentation.
- Content lives in `data/` as JSON, one file per item (`docs/09-data-formats.md`). New fields or types: update the doc and `tests/data/test_data_files.gd` together.
- The user directs and doesn't read code: PR descriptions must be plain language (what changed, how to try it, what to look for).

## Commands
- Run tests (GUT 9.7, vendored in `addons/gut`): `mkdir -p build && godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json`
  Tests live in `tests/` (mirror `sim/` paths), extend `GutTest`, and are named as plain sentences (`test_round_ends_exactly_on_its_last_tick`).
  CI (`.github/workflows/tests.yml`) runs them on every PR and posts a readable table in the run summary.
- Run the headless sim: `godot --headless --script res://tools/run_sim.gd`
- Run the balance harness: `godot --headless --script res://tools/balance.gd -- --fights=100 --pairs=kicker:boxer` (CSV + summary in `build/balance/`). It uses every CPU core (`--jobs=N` to change; same results either way): `docs/01-fight-engine.md` §2.3 (D123).
- How sure a balance number is (95% ranges, coaching compared seed by seed, `run.json`, the speed line, who chose the moves) and comparing two runs with `tools/balance_compare.gd`: `docs/01-fight-engine.md` §2.4 (D250). The AI improvement plan and Kyle's answers: §20.4 (D251).
- How fighters move round the cage (holding the centre, cutting off, getting off the fence) and the numbers to tune it: `docs/01-fight-engine.md` §20.2 (D107).
- Cutting the cage (the Cage cutting stat against Footwork, aiming at the exit not the man, the diagonal step, reversing and countering when cut off, herding feints, the *Cut the cage!* call on key R, the Shark tank session, the numbers to tune it): `docs/01-fight-engine.md` §20.5 (D230–D232).
- How long each fighter circled and cut off the cage, reported after every fight (what counts, the numbers to change it): `docs/01-fight-engine.md` §20.3 (D119).
- Smoke-run the main scene: `godot --headless --quit-after 30`
- The fight screen (setup, grey-box 3D view, HUD v0, speed controls, hotkeys, F3 debug overlay), what's not in v0 yet and what to edit: `docs/06-fight-hud.md` §6 (D117).
- The body damage figure on the top bar (head, body and legs green → red, the readout, hit flash and rocked pulse; it replaced the health bar) and the numbers to change it: `docs/06-fight-hud.md` §6.2 and §6.6 (D150).
- Playtest kit (the Windows download from Actions → Playtest build, the Playtest fights in `data/playtest/`, saved fights and `tools/playtest_report.gd`, the host script, feedback form and write-up template): `docs/playtests/README.md` (D118). No testers: `docs/playtests/solo-checklist.md` (D127). Self-check an export: `ChinCheck.x86_64 --headless -- --self-check`.
- Re-run the playtest write-up's balance numbers without Godot installed: Actions → Playtest numbers → Run workflow (`.github/workflows/playtest-numbers.yml`, D124); what each part is and where its numbers go: `docs/playtests/README.md` §4.
- Clinch, takedowns and the ground (how a shot resolves, sprawls, knees into shots, getting up, judges' grappling points, the AI tied up): `docs/01-fight-engine.md` §21 (D108).
- How live coaching calls work (voice, delay, compliance, attempts/focus/reads) and where their numbers live: `docs/01-fight-engine.md` §22 (D111, D112).
- Coaching bots and the AI corner (who calls what, the harness's `--corners`/`--coach`, the D12 coaching checks), what a call costs, and strikers' answers to grappling: `docs/01-fight-engine.md` §22.5–22.9 and §21.8 (D113–D115).
- Health, the referee's stoppages and ground and pound (the health bar, what stops a fight, ground punches, elbows and tie-ups, the "Ground and pound!" call, the numbers to tune finishes): `docs/01-fight-engine.md` §24 (D120, D121).
- Submissions (the guillotine, triangle and armbar, how a hold locks in, the struggle's danger meter, Finish it! / Defend the sub!, the AI's openings, the numbers to tune them): `docs/01-fight-engine.md` §25 (D126).
- Throws and the guard game (the outside trip, hip throw and foot sweep, why a sprawl can't stop them, the guard pull and the sweep, the Judoka and BJJ test fighters, the numbers to tune them): `docs/01-fight-engine.md` §26 (D128).
- Clinch knees and the collar tie (the plum: how long it holds, knees to the head from it, getting out, the *Collar tie!* call on key 5, the Muay Thai test fighter, the numbers to tune them): `docs/01-fight-engine.md` §27 (D129).
- Ground positions (half guard, side control, mount and the back: passes, escapes, taking the back, the rear-naked choke and arm-triangle, the *Pass!* call on key 4, the judges' points for a better position, the numbers to tune them): `docs/01-fight-engine.md` §28 (D130).
- Feints and blind shots (the feint and the bite, what makes a takedown blind and what it costs, grapplers setting their shots up, the *Feint!* call on key 7, the numbers to tune them): `docs/01-fight-engine.md` §29 (D131).
- Leg locks and the Sambo fighter (the ankle lock, kneebar and heel hook, what a miss costs, the heel hook's amateur ban, the AI's openings, the Sambo test fighter, the numbers to tune them): `docs/01-fight-engine.md` §30 (D132).
- Striker combinations and *Fire back!* (the fighters' combinations in `data/combos/`, why they flow and change levels, a combination he has seen before, what breaks one, the *Fire back!* read call on key E, the numbers to tune them): `docs/01-fight-engine.md` §31 (D133).
- More strikes (the uppercut, overhand, hook to the body, calf kick, elbow and the short uppercut and hook in the clinch: what each punishes and leaves open, who throws them, why the Boxer never looks for the clinch, the numbers to tune them): `docs/01-fight-engine.md` §32 (D140).
- PRIDE rules (the 10-minute first round, soccer kicks and stomps on a downed fighter, knees on the ground, the whole-fight judges: effort to finish, then control, then aggression; the *Rules* picker on the setup, the numbers to tune them): `docs/01-fight-engine.md` §33 (D141).
- Following a knockdown down to the ground (the *Follow him down* move, where it lands, who follows up, *Takedown!* on key 4 doing it, the numbers to tune it): `docs/01-fight-engine.md` §34 (D142).
- Liver shots (how a body shot finds the liver, the freeze and the fold, getting up winded, how often, the numbers to tune them): `docs/01-fight-engine.md` §35 (D143).
- A leg giving out (the two legs tracked apart, low kicks on the front leg, switching stance, the buckle and the limp, the numbers to tune them): `docs/01-fight-engine.md` §36 (D144).
- Flash knockdowns (one big shot dropping a fresh man, and what the four rocked-and-dropped changes did to fights together): `docs/01-fight-engine.md` §37 (D145).
- Striking defence (checking a low kick, slipping a straight punch, covering up: who has which, when they have to be up, what a checked kick does to the kicker, the counter off the slip, covering up when rocked and on *Survive!*, the numbers to tune them): `docs/01-fight-engine.md` §38 (D180).
- *Go for the finish!* (key 2 on top: a 10 s hunt for a hold, passing to get to one, one hold a call; what it does to fights, the numbers to tune it): `docs/01-fight-engine.md` §25.7 (D200).
- The browser build and the name (the *Web* export preset with threads off, the Playtest build's `ChinCheck-web` download, the symbols fallback font, publishing it to GitHub Pages, Chin Check by Lampsmoke Games): `docs/04-tech-and-production.md` §2.4 (D240, D241).
- Strike sounds (each strike's connected, missed and blocked sound made in code, which version a check, slip or cover-up plays, the Sound slider and M to mute, `tools/strike_sounds.gd` to hear them as WAV files, the numbers to tune them): `docs/06-fight-hud.md` §6.8 (D190).
- How the ground positions look (the bodies laid out per position in the 3D view, the top-down position diagram on the HUD, the fighters' face, shorts, gloves and feet, the numbers and drawings to change them): `docs/06-fight-hud.md` §6.10 (D210, D211).
- The cage clinch (driving him to the fence, being held there, spinning off and turning him, a shot on the fence pressing him there, who leans in with the `fence_drive` tendency, the numbers to tune it): `docs/01-fight-engine.md` §39 (D220).
- Drilled rules (two slots, reliability, cooldown, opponents adapting, the presets, `--rules` in the harness): `docs/01-fight-engine.md` §23 (D116).
- Speed budget (1000× fight time), the timing checks and how to speed things up without changing fights: `docs/01-fight-engine.md` §2.1 (D105).
- Golden fights: four pinned fights that fail a test whenever a change alters a fight. If the change is meant to, re-pin with `godot --headless --script res://tools/golden.gd -- --update`, commit `tests/golden/golden_fights.json` and say why in the PR: `docs/01-fight-engine.md` §2.2 (D122).
- Training camp (the week planner's sessions and plans, how XP turns into points, fatigue, camp injuries, style pushes, `tools/camp.gd`): `docs/02-fighter-and-training.md` §3.5 (D125).
- The camp planner screen (*Training camp first* on the fight setup: focus weeks, slot-by-slot weeks, the forecast, taking the trained fighter into the fight): `docs/02-fighter-and-training.md` §3.6 (D134).
- Fight night (camp fatigue shrinks the gas tank, a healing injury starts the fight hurt, light sessions and rehab while hurt, the doctor, pulling out, fighting hurt making it worse): `docs/02-fighter-and-training.md` §3.7 (D135).
- Ageing and the prime (the body slows from 30 while skills keep growing, the body's learning curve, training between camps, scouted potential, `tools/career_curve.gd`): `docs/02-fighter-and-training.md` §3.8 (D136).
- The camp week HUD (the planner's look: the weeks counting down to the fight, the condition card, session tiles coloured by kind and the session list, the fatigue line, the stat bars, the display font, what to edit): `docs/02-fighter-and-training.md` §3.10 (D170).
- The fight setup as a tale of the tape (any two fighters with ◀ ▶, frames and headline stats face to face, the opponent scouted as grades, scouting cards, keys to the fight, the options under it): `docs/06-fight-hud.md` §6.7 (D172).
- The result screen (the verdict and when, both figures as they finished, the fight sheet, the judges' cards round by round, your corner's letter grade and its numbers): `docs/06-fight-hud.md` §6.9 (D173).
- The fight night card (the full-screen card after the camp: gas tank, fatigue, injury, the doctor's stamp, what the camp added, Fight! or Pull out; the display font on the fight screen): `docs/02-fighter-and-training.md` §3.11 (D171).
- Mitt work, the first minigame (the coach's calls in boxing's numbers, keys 1–6 and ← ↓, timing windows, how it scores the session, ticking Play in the planner, the numbers to tune it): `docs/02-fighter-and-training.md` §3.9 (D137).
- Opponent style sheets (the 15 styles, how opponents are generated from them, scouting cards, `tools/style_sheets.gd`): `docs/03-career-and-world.md` §7.1 (D160).
- Import/refresh the project cache: `godot --headless --import`
