# 09 — Data Formats

> Issue #10. Status: **v1**. Validated automatically by `tests/data/test_data_files.gd`, so CI fails on bad content.

## 1. Decision: JSON, one file per item

| Option | For | Against |
|---|---|---|
| **JSON** ✅ | Plain text with readable diffs in PRs; easy for AI to write and review; editable in any editor; Python tools (balance reports) can read it; loads in the headless sim with no editor | No editor inspector; types are checked by our tests, not by Godot |
| Godot `.tres` resources | Inspector editing, typed fields | Noisy diffs, harder for AI to write correctly, ties content to Godot internals |

Rules:
- **One file per item** (`data/actions/body_kick.json`), so changes and merges stay small.
- `id` = file name = how other files refer to it. ids are `snake_case`; enum values (flags) are `UPPER_SNAKE`.
- Every file has `"schema": "<type>@<version>"`. When a format changes, bump the version and migrate old files (save files follow the same idea).
- **Units:** time in **milliseconds of fight time**, always a multiple of 100 (one tick, `FightClock.TICK_MS`). Probabilities `0.0–1.0`. Stats `0–100`.
- **Exports:** `*.json` is in the export preset's *non-resource files* filter (`include_filter="data/*.json"` in `export_presets.cfg`), or data wouldn't ship in builds; CI self-checks the exported game (D118).

## 2. Folder map

| Folder | Schema | What it is |
|---|---|---|
| `data/enums/` | `enum@1` | Fixed vocabularies: `flags` (state flags, `docs/01` §5), `stats` (attributes, `docs/02` §2), `gifts` and `flaws` (`docs/11` §4.3) |
| `data/actions/` | `action@2` | Everything a fighter can do: strikes, takedowns, defenses, ground moves |
| `data/positions/` | `position@2` | Standing, clinch and ground positions (`docs/01` §4) |
| `data/calls/` | `call@2` | Coach calls: now/read, intent/technique (`docs/01` §6, §22) |
| `data/gameplans/` | `gameplan@1` | Gameplan presets: Pressure, Counter, Range, Wrestle-heavy, Conserve (`docs/01` §6.0, §22.4) |
| `data/triggers/` | `trigger@1` | Building blocks for read calls and drilled rules ("opponent starts a kick") |
| `data/rules/` | `rule@2` | Drilled-rule presets: trigger → action (`docs/01` §6.0) |
| `data/rulesets/` | `ruleset@1` | Amateur/pro rules (`docs/08`) |
| `data/fighters/` | `fighter@1` | Fighter profiles: authored fighters, archetype templates and (later) generated fighters (D94) |
| `data/playtest/` | `playtest@1` | The playtest's fights in order (D118, `docs/playtests/`) |
| `data/sessions/` | `session@1` | Training sessions: drills, sparring, conditioning, rest (`docs/02` §3.5, D125) |
| `data/week_plans/` | `week_plan@1` | Week plans: a session in each of the 12 slots of a training week (`docs/02` §3.5) |
| `data/combos/` | `combo@1` | Combinations: a named run of strikes a fighter has drilled, the 1-2, a jab into a low kick (D133, `docs/01` §31) |

## 3. Schemas

### action@2 (example: `data/actions/body_kick.json`)
| Field | Type | Meaning |
|---|---|---|
| `name` | string | Display name |
| `category` | `strike` · `takedown` · `defense` · `movement` · `clinch` · `ground` · `submission` · `feint` | |
| `positions` | position ids | Where it can be used |
| `roles` (optional) | `neutral` · `top` · `bottom` (· `attacker` · `defender` in a submission, D126) | Which roles may use it there (get up: `bottom` or `neutral`, so the fighter on top can't). Left out = any role. A move that moves the fight (a takedown, clinch, ground move or submission, but not a tie-up) also needs a transition for that role in the position's file, so one move can work from different roles in different positions: the armbar lists `bottom` and `top`, and works from the bottom of full guard and the top of mount (D130) |
| `basic` (optional) | bool | `true` = every fighter knows it, whatever their `techniques` (sprawl, clinch entry and break, get up, scramble; the soccer kick and stomp, D141) |
| `ranges` | `long` · `mid` · `pocket` · `clinch` | Distance bands it works from |
| `phases_ms` | `{telegraph, windup, active, recovery}` | Commitment model timings (`docs/01` §5) |
| `stamina_cost` | number | Stamina spent |
| `flags_self` | `[{flag, from, to}]` | Flags the *user* carries during those phases (`ONE_LEG` from windup to recovery) |
| `stats` | `{offense: [stat], defense: [stat]}` | Attributes that decide the contest |
| `opportunities` | `[{opponent_flag \| own_flag, success_bonus, required?, ai_takes?, target?, damage_multiplier?, stops?}]` | Bonus when the *opponent* carries that flag; `required: true` = only possible then (catch-kick). `own_flag` instead: when the user carries it (get up with your back on the fence, +0.15; a negative bonus makes it harder). For strikes, when the opening is there: `target` sends it there instead (a knee into a shot goes to the head), `damage_multiplier` scales it, `stops: true` stops the opponent's move (`docs/01` §21.2). `ai_takes: true` (on a required opening, D128): the fighter AI takes it on its own when it reads it (the foot sweep on a lean); without it a move that needs an opening is only thrown on a call or a drilled rule (the catch-kick, D103) |
| `strike` / `takedown` / `defense` / `clinch` / `ground` | object | Category-specific: `{target, base_damage, push_m?, downed?}` · `{base_success, partial_within?, throw?, landing_damage?}` · `{against_categories, base_success}` · `{base_success, partial_within?}` · `{base_success, partial_within?}`. `partial_within` (a chance, optional): a roll that misses the odds by less than this half works, and goes where the position's `partial` transition says (a scramble; half guard for a guard pass, D130). `ties_up_ms` (a `ground` or `clinch` move's, optional, D121, D129): when it works the fight stays put and the opponent's posture is broken for this long (`POSTURE_BROKEN`): as the tie-up from the bottom of full guard (no ground strikes), or the collar tie in the clinch (his head pulled down for knees, `01` §27). Winning one also frees the winner's own posture. `throw` (a takedown's, optional, D128, `01` §26): `true` for a throw or a trip, which a sprawl can't stop. `landing_damage` (a takedown's, optional): body damage when it lands, × (0.5 + Strength / 100), none where slams are banned (the hip throw, 8). `push_m` (metres, optional): a landed strike shoves the opponent back that far (the teep, 0.5). `downed` (a strike's, optional, D141): `true` for a strike at a knocked-down opponent (the soccer kick, the stomp); only these land on him while he's down, and each must be a standing move with `DOWN` as a required opening. Where a landed takedown takes the fight is in the position files. A `submission` move (D126, `01` §25) has `{base_success, partial_within?, start_danger, escape_to}`: `base_success` is the lock-in's base odds; `start_danger` (0–100) where the struggle's danger meter starts, before the stats' edge; `escape_to` where the defender goes on getting out: `back` (where it was locked from) or `scramble`; `ai_without_opening` (optional, D130) `true` when the fighter AI goes for it without waiting for an opening (the rear-naked choke: being on the back is the opening), or a list of the hold's positions where it does (the leg locks in a `scramble`, D132); `leg_lock` (optional, D132, `01` §30) `true` for a leg lock (counted in the harness, posed lying back); `step` (optional, D132) how far each beat of the struggle moves the danger, instead of the usual 20 (the heel hook's 30). A `movement` move (the stance shift) has none: it only takes time and stamina, and can be a tell. A `feint` move (D131, `01` §29) has `{base_success, bites_ms}`: the odds the opponent bites, rolled as its active phase starts, and how long he then carries `BIT_ON_FEINT` (ms, a multiple of 100). A takedown with nothing setting it up carries `BLIND_SHOT` (`01` §29.2), so its own penalty and the sprawl's bonus are ordinary opportunities (`own_flag`, `opponent_flag`) |
| `requires_technique` | id or null | Needs this technique learned (`docs/02` §2.1) |

### position@2 (example: `standing.json`)
`name`, `phase` (`standing`/`clinch`/`ground`), `roles` (`neutral`, `top`/`bottom`, or `attacker`/`defender` in a submission), and per role:
`stamina_drain_per_s`, `control_score` (judging; since D130 a better position on top also scores the rise in it, `01` §28.3), `strike_damage_multiplier`.
`top_label` (optional, D130): how the feed and the screen say who's in the `top` role, if not "on top" (back control: "has the back").

`transitions`: how the fight leaves this position (`docs/01` §4.1). Each entry is
`{action, from_role, result?, to, roles: {actor, opponent}}`: when the fighter in `from_role` lands `action` here, the fight moves to
position `to`, with the actor and the opponent in those roles. `result` is `success` (the default), `partial`: where the move
goes when it only half works (`partial_within`, a scramble), or `failed`: where it goes when it doesn't work at all, for a move
that costs a position when it misses (a guillotine pulls the attacker onto their back, D126; a leg lock from underneath lets the top fighter into side control, D132). A submission's `success` takes the
fight to the `submission` position (roles `attacker` and `defender`), where the struggle runs (`01` §25). Example from `standing.json`:
`{ "action": "double_leg", "from_role": "neutral", "to": "full_guard", "roles": { "actor": "top", "opponent": "bottom" } }`.
An action with no entry doesn't move the fight. The validator checks that the action exists and can be used here, `from_role`
is one of this position's roles (and one the action allows), `to` exists and has both roles, and no action/role/result is listed twice.
Loaded by `PositionLibrary` (`sim/fight/position_library.gd`).

Versions: position@2 added `transitions`; action@2 moved a takedown's `on_success` into them (no saved data needed migrating).

### call@2 (examples: `takedown.json` attempt, `pressure.json` focus, `catch_the_kick.json` read)
`name` (as shouted, "Takedown!"), `kind` (`now`/`read`), `tier` (`intent`/`technique`), `parent` (intent call it unlocks under),
`hotkey` (a digit 0–9, or null; two calls may share a digit only if their `positions` never overlap, e.g. 1 for Pressure! standing and Ground and pound! in full guard, D121), `voice_cost`, `positions` (where it can be acted on), `roles` (optional:
`neutral`/`top`/`bottom`), `actions`, `requires_technique` (an action id the fighter must know, or null), `then` (optional, an attempt's: action ids
tried straight after the first move is over, the first that would work; *Feint!* feints, then shoots or ties up off it, D131, `docs/01` §29.3a).
A now call is one of two kinds (`docs/01` §22.2):
- an **attempt**: `actions` lists the moves to try, in order (the first that would work right now is used), and no `focus`;
- a **focus**: `actions` is empty and `focus: {duration_ms, leanings, weights, read_bonus, sprawl_bonus, struggle, struggle_stamina}` says how the fighter
  fights for that long: `leanings` adds points to Pace/Range/Base/Risk (−100 to 100), `weights` multiplies the AI's weight for
  an action id or category (0–10), `read_bonus` adds to the chance to read the opponent's moves of a category (0–1),
  `sprawl_bonus` to the chance to sprawl on a shot (0–1), `struggle` to their side's chance to win each beat of a submission (0–0.5: Finish it! for the attacker, Defend the sub! for the defender, D126) and `struggle_stamina` the extra stamina each beat costs them. All optional except `duration_ms`.

A read call has `actions` (what the fighter reacts with) and `read: {trigger, duration_ms, attention_cost}`: primed for
`duration_ms`, it reacts to the trigger once; while primed, Striking and Takedown defense drop by `attention_cost` (0–0.5).
A read call with `combo: true` (*Fire back!*, D133, `docs/01` §31.4) reacts with the fighter's first combination (their
profile's `combos`, in order) whose first move works from there, thrown as a whole; its `actions` are single strikes it falls
back on for a fighter with no combination that works.
Loaded by `CallLibrary` (`sim/fight/call_library.gd`). call@2 replaced call@1's `priority_boost` with the attempt/focus split
(an accepted call claims the choice outright, `docs/01` §19); the two call@1 files were migrated.

### combo@1 (examples: `one_two.json`, `jab_leg_kick.json`, `one_two_body_kick.json`)
`name` (as the feed says it, "1-2-3"), `moves` (two or more action ids, each a strike thrown standing, in order). A fighter
throws the ones in their profile's `combos` (D133, `docs/01` §31). Loaded by `ComboLibrary` (`sim/fight/combo_library.gd`).

### gameplan@1 (example: `pressure.json`)
`name`, `leanings` (points added to Pace/Range/Base/Risk for the fight, −100 to 100), `weights` (action id or category →
multiplier, 0–10). Loaded by `Gameplan.load_id` (`sim/fight/gameplan.gd`).

### trigger@1 (examples: `opp_kick_starts.json`, `own_jab_blocked.json`)
`name`, `type` (`event`/`state`/`threshold`), `event` (for event triggers: a fight event type such as `action_phase`,
`strike_landed`, `strike_missed`, `rocked`, `range_changed`), `match` (e.g. `{actor: "opponent", action_ids: ["body_kick"], phase: "telegraph"}`).
An event trigger matches one event as one fighter sees it; every `match` field is optional and all must hold:
`actor` (`self` = the fighter whose tell, call or rule it is, `opponent` = the other one), `action_ids` (the event's action is one
of these), `phase` (`action_phase` events), `defended` (`strike_missed` events: `true` = the opponent stopped it, not "out of
range"). Loaded by `TriggerLibrary` (`sim/fight/trigger_library.gd`). State/threshold match fields get defined in #16.

### rule@2 (examples: `catch_kick_and_shoot.json`, `sprawl_on_the_shot.json`)
`name`, `trigger` (trigger id), `action` (action id), `cooldown_ms`. Which rule goes first is the slot it's put in (slot 1 before
slot 2), and how well it's drilled is set with it (the `set_rule` command), not in the data (D116, `docs/01` §23). rule@1 had a
`priority` field; the slot replaced it.

### ruleset@1 (examples: `pro`, `amateur_adult`, `amateur_teen`, `pride`)
`name`, `rounds`, `title_rounds`, `round_seconds`, `glove_oz`, `gear`, `allows` (exactly: `elbows`, `head_strikes_on_ground`,
`knees_to_head_standing`, `knees_to_head_grounded`, `heel_hooks`, `slams`, `takedowns`, `soccer_kicks`, `stomps`), `damage_multiplier`, `cut_multiplier`,
`early_stoppage_bias`, `weigh_in` (`same_day`/`day_before`), `paid`.
Optional (D141, `01` §33): `round_lengths`, one length in whole seconds per round when they differ (PRIDE: `[600, 300, 300]`;
left out = every round is `round_seconds`); `judging`, `"rounds"` (10-point must cards, the default) or `"whole_fight"` (one
verdict on the whole fight: the effort to finish, then control, then aggression). `knees_to_head_grounded` sends a knee on the
ground (`ground_knee`) to the head; without it, to the body. `soccer_kicks` and `stomps` allow the moves whose ids start with
those words.

### fighter@1 (examples: `kicker.json`, `boxer.json`; `check_blue.json` uses a template)
One format for every fighter (D94): the showcase pair, the debug-console check fighters, and later archetypes and the ~600
generated world fighters. Loaded by `FighterLibrary` (`sim/fight/fighter_library.gd`); `FighterState.from_profile()` builds the fight state.

| Field | Type | Meaning |
|---|---|---|
| `name` | string | Display name (required) |
| `template` | fighter id or null | Fill in anything this file leaves out from that fighter. `frame`, `stats`, `personality`, `style` and `tendencies` merge key by key; other fields replace. One level only (a template has no template) |
| `frame` | `{height_cm, reach_cm, build}` | Body (`docs/11` §2.3). `build`: `lean` · `average` · `stocky` |
| `stance` | `orthodox` · `southpaw` · `switch` | |
| `stats` | `{stat: 0–100}` | Attributes from `enums/stats`; unlisted stats are 50 |
| `personality` | `{ego, discipline, coachable, loyal}` −100–100 | `docs/11` §4.1: + is Ego / Disciplined / Coachable / Loyal, − is Humble / Party animal / Stubborn / Mercenary |
| `style` | `{pace, range, base, risk}` −100–100 | Style leanings (`docs/11` §4.2); ±60 earns the named trait |
| `gifts` / `flaws` | ids from `enums/gifts` / `enums/flaws` | `docs/11` §4.3 |
| `techniques` | action ids | The moves this fighter knows and the AI picks from |
| `tendencies` | `{work_rate, actions: {action id: weight}}` | `work_rate`: the chance per free tick to lead with something (0–1; 0.015 ≈ one lead every 7 s, with combinations, counters and meeting advances on top; `docs/01` §20). `actions`: how much they favour a move (1.0 = normal, 0–10), `docs/01` §7 |
| `age` | whole years, 14–45 (optional) | Training learns faster when young and styles set from 30 (`docs/02` §3.5); 25 if left out |
| `potential` | 0–100 (optional) | Where training slows right down (`docs/11` §2.3, `docs/02` §3.5); 75 if left out. Hidden in the game: scouts see a 14-point range around it (D136, `docs/02` §3.8) |
| `condition` (optional) | `{tank: 0–1, hurt: {head/body/legs: 0–1}}` | How a camp sends them in (D135, `docs/02` §3.7): the share of the gas tank they have all fight, and how hurt an area already is. Written by the camp planner, never in `data/fighters/`; left out = fresh |
| `combos` (optional) | data/combos ids | The combinations this fighter has drilled (D133, `docs/01` §31). Every move in them must be one the fighter knows. Left out = none: their strikes chain one at a time as before |
| `tells` | `[{trigger, action, chance, within_ms}]` | Habits an opponent can scout: after `trigger`, `chance` to throw `action` within `within_ms` (`docs/01` §7, D11). The AI follows them (`docs/01` §20). A tell on the fighter's own move starting is a set-up: the Wrestler's `own_stance_shift` → `double_leg` |

Without a `template`, every field above must be present. A fight is saved and replayed as seed + fighter ids + ruleset +
command log (`FightSim.record()` / `FightSim.from_record()`).

### playtest@1 (examples: `fight_1_first_calls.json`, `fight_2_catch_the_kick.json`)
One fight of the playtest (D118), picked from the setup screen's **Playtest** list. Loaded by `Playtest` (`game/playtest.gd`).

| Field | Type | Meaning |
|---|---|---|
| `name` | string | As the Playtest list and the result screen's "Next" button show it |
| `order` | number | Where it comes in the playtest (1 first) |
| `red` / `blue` | fighter ids | The matchup; the player is red |
| `calls` | call ids | The calls on the call bar; empty means every call |
| `rules` | `[[rule id, drilled 0–100], …]` | Drilled rules already in the slots, slot 1 first (at most 2) |
| `tell_cue` | bool | Show the scouted-tell cue (D51) |
| `tip` | string | The tip card before the fight (`07` §2: two sentences at most) |

### session@1 (examples: `boxing_drill.json`, `hard_sparring.json`, `rest.json`)
One kind of training session (`docs/02` §3.5, D125). Loaded by `TrainingLibrary` (`sim/world/training_library.gd`); `TrainingCamp` runs it.

| Field | Type | Meaning |
|---|---|---|
| `name` | string | As the planner and the camp report show it |
| `trains` | `{stat: share}` | Which attributes its XP goes to; shares add up to 1. Empty for rest and recovery |
| `xp` | number ≥ 0 | XP for a session at quality 1.0; 0 exactly when it trains nothing |
| `fatigue` | −100–100 | Fatigue it adds (× the Recovery factor); negative takes fatigue away (rest, recovery, meditation) |
| `injury_risk` | 0–0.05 | Chance of a camp injury per session when fresh (fatigue and Durability scale it) |
| `injury_area` | `head` · `body` · `legs`, or null | Where its injury is; a healing injury starts the fight hurt there (D135, `docs/02` §3.7). Needed when `injury_risk` > 0 |
| `light` | bool | Goes ahead while the fighter is hurt (film study, meditation, rehab, recovery, rest); the rest become rest (D135) |
| `heals` (optional) | days, 0–7 | Extra days of healing when done hurt (Rehab: 1). Only a light session heals |
| `leanings` | `{leaning: −1–1}` | Style push per session (`docs/11` §4.2) |
| `chin_wear` | 0–1 | Chin points lost per session (hard sparring) |
| `minigame` | minigame id or null | The minigame that will play it (D38; only `mitt_work` is built so far, D137): `mitt_work`, `heavy_bag`, `thai_pads`, `wrestling_chain`, `sprawl_reflex`, `rolling_puzzle`, `roadwork`, `film_study`, `hard_sparring`, `meditation` |

### week_plan@1 (examples: `balanced.json`, `wrestler.json`, `taper.json`)
A training week (`docs/02` §3.5). Loaded by `TrainingLibrary`.

| Field | Type | Meaning |
|---|---|---|
| `name` | string | As the planner and the camp report show it |
| `about` | string | One line on what the week is for, under the planner's *Start from* (D134) |
| `instruction` | gameplan id or null | A gameplan whose style leanings every session pushes a little (Pressure → "push the pace") |
| `days` | 6 × `[morning, evening]` session ids | Monday to Saturday; Sunday is always off |

### fight_record@1 (saved by the game, not in `data/`)
What a fight on the fight screen leaves behind, one file per fight in the player's `user://fights/` folder (on Windows
`%APPDATA%\Godot\app_userdata\Chin Check\fights`). Built by `FightRecord` (`game/fight_record.gd`); added up by
`tools/playtest_report.gd` (`docs/playtests/README.md` §3).

| Field | Meaning |
|---|---|
| `saved_at`, `game` | When, and the game name and Godot version |
| `settings` | The setup it was played with: `label`, `step` (playtest id or ""), `tester`, `normal_rate` (1 or 2), `easy`, `tell_cues`, `auto_slow`, `flourishes`, and after a camp (D134) `camp`: `weeks` (each week's plan id, `custom` for one changed by hand) and fight night (D135): `fatigue`, `tank`, `injury_area`, `injured_days`, `doctor`, `worsen_chance` |
| `player` | The player's corner (0 = red) |
| `result`, `won`, `rounds_played` | The `FIGHT_ENDED` event's data (`winner`, `result`, `stopped_by`, cards), and whether the player won |
| `stats` | The player's coaching: `calls_made`, `calls_ignored`, `calls_by_id`, `perfect_calls`, takedowns that worked split by who chose them (`takedowns_by_call`, `takedowns_by_rule`, `takedowns_own`), `catch_kicks_landed`, `rules_fired` |
| `fighters` | Each fighter's id, name, strikes and takedowns landed and tried, damage |
| `replay` | `FightSim.record()` plus `ticks`: the fight replays from it to the same ending |
| `profiles` | `{id: fighter@1 profile}` for any fighter not in `data/fighters/` (the camp planner's `<id>_camp`, D134); `PlaytestReport.replays` adds them to the roster before replaying. Empty otherwise |

## 4. What the validator checks
Valid JSON with a known schema · id matches file name and folder · required fields present with the right types ·
action timings are whole ticks · values come from the allowed lists · every reference (positions, actions, calls, triggers,
flags, stats, sessions, gameplans) points to something that exists · a session's shares add up to 1 · a week plan has 6 days
of 2 sessions.

## 5. Not yet defined (comes with the issue that needs it)
Technique proficiency and the `techniques` link to `requires_technique` (D6), state/threshold trigger fields (#16), backgrounds/vignettes, techniques, promotions and names (Alpha), the career save (`docs/04` §11).
