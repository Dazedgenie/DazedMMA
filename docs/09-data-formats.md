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
| `data/enums/` | `enum@1` | Fixed vocabularies: `flags` (state flags, `docs/01` §5), `stats` (attributes, `docs/02` §2), `gifts` and `flaws` (`docs/11` §4.3), `nicknames` (what *Roll* picks from on the new-career screen, D302), `coach_backgrounds` (who the head coach was before him: id → `{name, about}`, D311), `gym_cultures` (a gym's culture: id → `{name, about, skips, injury, sparring_xp}`, the shares it changes those by, D313) |
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
| `data/styles/` | `style@1` | Opponent style sheets: the recipe the world makes opponents of one style from, and the style's scouting card (D160, `docs/03` §7.1) |
| `data/backgrounds/` | `background@1` | Where a career's fighter comes from: the 12 backgrounds of `docs/02` §1.2 and the 16-year-old each makes (D302, `docs/03` §10.2) |
| `data/names/` | `names@1` | One country each: its cities (hometowns) and common first and last names, for new careers and generated fighters (D302, D57) |
| `data/gyms/` | `gym@1` | The five kinds of gym you can coach at: what each trains better and worse, its fee, names and owners (D313, `docs/03` §11.3) |
| `data/vignettes/` | `vignette@1` | His childhood scenes: one scene at age 8, 12 or 15, with three choices that make him who he is at 16 (D312, `docs/03` §11.2) |
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
| `opportunities` | `[{opponent_flag \| own_flag, success_bonus, required?, ai_takes?, target?, damage_multiplier?, stops?}]` | Bonus when the *opponent* carries that flag; `required: true` = only possible then (catch-kick). `own_flag` instead: when the user carries it (get up with your back on the fence, +0.15; a negative bonus makes it harder); a required `own_flag` is only `HELD_ON_FENCE` (the spin-off and turning him, only from there, D220), `UNDERHOOK` (turning him needs one, D261) or `OVERHOOK` (stripping needs one of his underhooks on you, D261). For strikes, when the opening is there: `target` sends it there instead (a knee into a shot goes to the head), `damage_multiplier` scales it, `stops: true` stops the opponent's move (`docs/01` §21.2). `ai_takes: true` (on a required opening, D128): the fighter AI takes it on its own when it reads it (the foot sweep on a lean); without it a move that needs an opening is only thrown on a call or a drilled rule (the catch-kick, D103) |
| `strike` / `takedown` / `defense` / `clinch` / `ground` | object | Category-specific: `{target, base_damage, push_m?, downed?, through_cover?, hands_down_ms?}` · `{base_success, partial_within?, throw?, landing_damage?}` · `{against_categories?, against_strikes?, base_success}` or `{head_share}` · `{base_success, partial_within?}` · `{base_success, partial_within?}`. `partial_within` (a chance, optional): a roll that misses the odds by less than this half works, and goes where the position's `partial` transition says (a scramble; half guard for a guard pass, D130). `ties_up_ms` (a `clinch` move's, optional, D129): when it works the fight stays put and the opponent's posture is broken for this long (`POSTURE_BROKEN`): the collar tie in the clinch (his head pulled down for knees, `01` §27). (The tie-up from the bottom used it too, D121, until D263 made it a ground grip held until he postures up.) Winning one also frees the winner's own posture. `drives_m` (a `clinch` move's, optional, D220, `01` §39): when it works the fight stays in the clinch and the opponent is walked straight back, 1.5 m a second, until his back is on the fence or this many metres are used up (the drive to the fence, 4). `turns` (a `clinch` move's, optional, D220): `true` when it works by turning the two round, so the other man's back is on the fence (the spin-off and turning him); if the clinch position has a transition for it, the fight then goes there (the spin-off comes away, to standing). `grip` (a `clinch` move's, optional, D261, `01` §40.3): `"inside"` swims an arm inside for an underhook (the pummel: on the side where the other man has the inside if he has one, else a free side), `"strip"` takes one of his underhooks off (that side back to hand fighting); the fight stays in the clinch. On a `ground` move (D263, `01` §40.11), the fight stays where it is: `"collar"` ties his head from underneath (the tie-up: `POSTURE_BROKEN`, no ground strikes), `"wrist"` holds one of his wrists (`WRIST_HELD`; both, `WRISTS_HELD`: no ground strikes), `"posture"` frees him from one (the collar tie first, then a wrist), `"half_inside"` takes the half-guard underhook (`UNDERHOOK`) from either side; (D264, `01` §40.12) `"frame"` sets a frame from underneath side control or mount (`FRAMED`), `"flatten"` takes it away from on top, `"two_on_one"` puts both hands on the choking arm with his back taken (`TWO_ON_ONE`), `"strip_hands"` takes them off. A ground grip he can't take now (one he has, nothing to strip, no frame to flatten) makes the move impossible (`missing`). `throw` (a takedown's, optional, D128, `01` §26): `true` for a throw or a trip, which a sprawl can't stop. `landing_damage` (a takedown's, optional): body damage when it lands, × (0.5 + Strength / 100), none where slams are banned (the hip throw, 8). `through_cover` (a strike's, optional, D270, `01` §41): the share of its head damage that gets through a cover-up instead of the cover-up's `head_share`, when that is less (the hammerfist, 0.8). `hands_down_ms` (a ground strike's, optional, D270): when it lands to the body his hands come down (`HANDS_LOW`) for this long (ms, a multiple of 100; the body punch and the knee from side control, 1000). `push_m` (metres, optional): a landed strike shoves the opponent back that far (the teep, 0.5). `downed` (a strike's or a ground move's, optional, D141, D142): `true` for a move at a knocked-down opponent (the soccer kick, the stomp; following him down to the ground); only these reach him while he's down, and each must be a standing move with `DOWN` as a required opening. Where a landed takedown takes the fight is in the position files. A `submission` move (D126, `01` §25) has `{base_success, partial_within?, start_danger, escape_to}`: `base_success` is the lock-in's base odds; `start_danger` (0–100) where the struggle's danger meter starts, before the stats' edge; `escape_to` where the defender goes on getting out: `back` (where it was locked from) or `scramble`; `ai_without_opening` (optional, D130) `true` when the fighter AI goes for it without waiting for an opening (the rear-naked choke: being on the back is the opening), or a list of the hold's positions where it does (the leg locks in a `scramble`, D132); `leg_lock` (optional, D132, `01` §30) `true` for a leg lock (counted in the harness, posed lying back); `step` (optional, D132) how far each beat of the struggle moves the danger, instead of the usual 20 (the heel hook's 30). A `movement` move (the stance shift) has none: it only takes time and stamina, and can be a tell. A `feint` move (D131, `01` §29) has `{base_success, bites_ms}`: the odds the opponent bites, rolled as its active phase starts, and how long he then carries `BIT_ON_FEINT` (ms, a multiple of 100). A takedown with nothing setting it up carries `BLIND_SHOT` (`01` §29.2), so its own penalty and the sprawl's bonus are ordinary opportunities (`own_flag`, `opponent_flag`). A `defense` move (D180, `01` §38) names what it stops: `against_categories` (moves of a category: the sprawl against takedowns) or `against_strikes` (strikes by id: the check against the leg and calf kicks, the slip against the jab, cross and overhand), rolled on `base_success` once if it's in its active phase as the move arrives; `hidden_by` (a strike defence's, optional, 0 or more): the striker's skill above 50 counts again at this weight (the check's 0.5: a good kicker hides his kicks); or it's a cover-up, `{head_share}`: while its `COVERED` flag is on, that share of head damage gets through (0.5), and nothing is rolled |
| `requires_technique` | id or null | Needs this technique learned (`docs/02` §2.1) |

### position@2 (example: `standing.json`)
`name`, `phase` (`standing`/`clinch`/`ground`), `roles` (`neutral`, `top`/`bottom`, or `attacker`/`defender` in a submission), and per role:
`stamina_drain_per_s`, `control_score` (judging; since D130 a better position on top also scores the rise in it, `01` §28.3), `strike_damage_multiplier`.
`top_label` (optional, D130): how the feed and the screen say who's in the `top` role, if not "on top" (back control: "has the back").

`transitions`: how the fight leaves this position (`docs/01` §4.1). Each entry is
`{action, from_role, result?, to, roles: {actor, opponent}}`: when the fighter in `from_role` lands `action` here, the fight moves to
position `to`, with the actor and the opponent in those roles. `result` is `success` (the default), `partial`: where the move
goes when it only half works (`partial_within`, a scramble), or `failed`: where it goes when it doesn't work at all, for a move
that costs a position when it misses (a guillotine pulls the attacker onto their back, D126; a leg lock from underneath lets the top fighter into side control, D132), or `pressed`: where a shot at a man with his back on the fence goes when it half works and the shooter stays on him (the double leg into the clinch on the fence, D220, `01` §39). A submission's `success` takes the
fight to the `submission` position (roles `attacker` and `defender`), where the struggle runs (`01` §25). Example from `standing.json`:
`{ "action": "double_leg", "from_role": "neutral", "to": "full_guard", "roles": { "actor": "top", "opponent": "bottom" } }`.
An action with no entry doesn't move the fight. The validator checks that the action exists and can be used here, `from_role`
is one of this position's roles (and one the action allows), `to` exists and has both roles, and no action/role/result is listed twice.
Loaded by `PositionLibrary` (`sim/fight/position_library.gd`).

Versions: position@2 added `transitions`; action@2 moved a takedown's `on_success` into them (no saved data needed migrating).

### call@2 (examples: `takedown.json` attempt, `pressure.json` focus, `catch_the_kick.json` read)
`name` (as shouted, "Takedown!"), `kind` (`now`/`read`), `tier` (`intent`/`technique`), `parent` (intent call it unlocks under),
`hotkey` (a digit 0–9, a capital letter the fight screen doesn't already use (Q, E, F, P, T and M are taken: Cut the cage! is "R", D230), or null; two calls may share a digit only if their `positions` never overlap, e.g. 1 for Pressure! standing and Ground and pound! in full guard, D121), `voice_cost`, `positions` (where it can be acted on), `roles` (optional:
`neutral`/`top`/`bottom`), `actions`, `requires_technique` (an action id the fighter must know, or null), `then` (optional, an attempt's: action ids
tried straight after the first move is over, the first that would work; *Feint!* feints, then shoots or ties up off it, D131, `docs/01` §29.3a).
A now call is one of two kinds (`docs/01` §22.2):
- an **attempt**: `actions` lists the moves to try, in order (the first that would work right now is used), and no `focus`;
- a **focus**: `actions` is empty and `focus: {duration_ms, leanings, weights, read_bonus, sprawl_bonus, cover_bonus, struggle, struggle_stamina, hunt, cut}` says how the fighter
  fights for that long: `leanings` adds points to Pace/Range/Base/Risk (−100 to 100), `weights` multiplies the AI's weight for
  an action id or category (0–10), `read_bonus` adds to the chance to read the opponent's moves of a category (0–1),
  `sprawl_bonus` to the chance to sprawl on a shot (0–1), `cover_bonus` to a rocked fighter's chance to cover up (0–1: Survive!'s 1 makes him, D180), `struggle` to their side's chance to win each beat of a submission (0–0.5: Finish it! for the attacker, Defend the sub! for the defender, D126) `struggle_stamina` the extra stamina each beat costs them, and `hunt: {rate}` sends the fighter on top after a hold for that long (*Go for the finish!*, D200, `docs/01` §25.7): `rate` is his chance a free tick (above 0, up to 1) to go for it or for a position that has one; only for a call with `roles: ["top"]`. `cut` (0–1, *Cut the cage!*, D230) has them cut the cage off at least that hard, from anywhere in the cage, without circling (`01` §20.5). All optional except `duration_ms`.

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
of these), `phase` (`action_phase` events), `defended` (`strike_missed` events: `true` = the opponent stopped it, a check or a slip included (D180), not "out of
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
| `condition` (optional) | `{tank: 0–1, hurt: {head/body/legs: 0–1}, call_delay?}` | How a camp sends them in (D135, `docs/02` §3.7): the share of the gas tank they have all fight, and how hurt an area already is. `call_delay` is the share of the usual delay his corner's calls take to reach him: 0.75 with a Tactician head coach (D311), left out = 1. Written by the camp planner, never in `data/fighters/`; left out = fresh |
| `combos` (optional) | data/combos ids | The combinations this fighter has drilled (D133, `docs/01` §31). Every move in them must be one the fighter knows. Left out = none: their strikes chain one at a time as before |
| `tells` | `[{trigger, action, chance, within_ms}]` | Habits an opponent can scout: after `trigger`, `chance` to throw `action` within `within_ms` (`docs/01` §7, D11). The AI follows them (`docs/01` §20). A tell on the fighter's own move starting is a set-up: the Wrestler's `own_stance_shift` → `double_leg` |

Without a `template`, every field above must be present. A fight is saved and replayed as seed + fighter ids + ruleset +
command log (`FightSim.record()` / `FightSim.from_record()`).

### style@1 (examples: `brawler.json`, `counter_striker.json`)
An opponent style (D160, `docs/03` §7.1). Loaded by `StyleLibrary` (`sim/world/style_library.gd`), whose `generate(style, seed, level, roster)`
makes a complete fighter@1 profile from it: the same style, seed and level always give the same fighter.

| Field | Type | Meaning |
|---|---|---|
| `name` | string | The style's name, as scouting shows it ("Counter-striker") |
| `fighter` | fighter id | The **signature fighter**: the style done well at an average level. Opponents start from this profile. It must not use a `template` |
| `roots` | strings | Backgrounds and trips this style comes from (`docs/02` §1.2, §6); display text for now |
| `southpaw_chance` | 0–1 | The chance an opponent of this style fights southpaw |
| `variation` | `{stats, style, tendencies, personality, height_cm}` | How far an opponent may differ from the signature fighter: each stat ± `stats` points (at most 20), each style leaning ± `style` (at most 40), each move preference × (1 ± `tendencies`) (at most 0.5), each personality axis ± `personality`, height ± `height_cm` (reach keeps the signature fighter's reach-to-height gap, ± 3 cm) |
| `scouting` | `{summary, strengths, weaknesses, tell, how_to_beat}` | The scouting card: one line on how they fight, lists of strengths and weaknesses, the tell in words (`null` if the signature fighter has no tell; the validator checks they agree), and how to beat them |

What `generate` keeps from the signature fighter: moves, combinations, tells, gifts, flaws and build. The quality `level`
(−30 to +30) is added to every one of the 23 stats, so it changes how good they are, not how they fight. A generated profile
carries two extra fields, `style_id` and `level`. Add it to the fight's `FighterLibrary` (`add()`) before the fight, so a replay finds it.

### background@1 (examples: `wrestling_family.json`, `street_kid.json`)
Where a new career's fighter comes from (D302, `docs/03` §10.2, `docs/02` §1.2). Loaded by `BackgroundLibrary`
(`sim/world/background_library.gd`), whose `make_fighter(background, seed, roster, choices)` makes a 16-year-old's complete
fighter@1 profile from it: the same background, seed and choices always make the same fighter.

| Field | Type | Meaning |
|---|---|---|
| `name`, `about` | strings | The background's name and a line on his childhood, as the new-career screen shows them |
| `fighter` | fighter id | Whose moves, combinations, habits and tells he grows up with (no `template`). His stats aren't used |
| `strengths`, `weaknesses` | stat ids | Start `STRENGTH_BONUS` higher or `WEAKNESS_PENALTY` lower than the rest (a stat is in one list at most) |
| `style` | `{pace, range, base, risk}` | Where his style leanings start (−100 to 100), ± 10 at random |
| `frame` | `{height_cm: [low, high], build}` | His height range (reach follows, −2 to +6 cm) and build (`lean`, `average`, `stocky`) |
| `personality` | `{ego?, discipline?, coachable?, loyal?}` | The background's lean on each axis (missing = 0), ± 30 at random |
| `gift_weights`, `flaw_weights` | `{gift or flaw id: weight}` | How much likelier each is than the others (weight 1 when not named) |
| `hook` | string | The story hook (`docs/02` §1.2), on the screen and his card |
| `money` | number | What he starts the career with |

### gym@1 (examples: `boxing_gym.json`, `mma_gym.json`)
A kind of gym (D313, `docs/03` §11.3). Loaded by `Gym` (`sim/world/gym.gd`), whose `offers(city, country_id, background,
seed)` rolls the three gyms a new career offers.

| Field | Type | Meaning |
|---|---|---|
| `name`, `about` | strings | The kind's name and a line on what it's like, as the gym card shows them |
| `xp` | `{session kind: share}` | Each kind of session's XP × this (0.5–1.5; `striking`, `wrestling`, `grappling`, `sparring`, `conditioning`, `mind`, `recovery`; missing = 1) |
| `fee` | `[low, high]` | Its monthly fee in dollars, rolled in that range |
| `names` | strings | Names for a gym of this kind; `{city}` is his hometown and `{surname}` the owner's surname |
| `owners` | strings | A line about the owner, one picked per gym |
| `backgrounds` | background ids | The backgrounds it suits: the first gym on offer is a kind that suits his (every background must have one) |

### vignette@1 (examples: `age8_flyer.json`, `age15_trip.json`)
One childhood scene (D312, `docs/03` §11.2). Loaded by `Childhood` (`sim/world/childhood.gd`), which draws one scene per age
for a career and turns the choices into his background and changes to his fighter.

| Field | Type | Meaning |
|---|---|---|
| `title`, `text` | strings | The scene's name and what's happening, as the card shows them |
| `age` | 8, 12 or 15 | Which age's pool it's in (`Childhood.AGES`) |
| `choices` | 3 objects | What he can do: each `{id, text, outcome, backgrounds, stats?, personality?, height?, person?, money?}` |

A choice: `text` is the button, `outcome` the line after it. `backgrounds` is `{background id: weight}` (1–5; the scenes use 3):
the most weight over his three choices is his background. `stats` nudges stats (−10 to 10 points), `personality` nudges axes
(−30 to 30), `height` is −1, 0 or 1 (`HEIGHT_PER_LEAN` cm, reach with it), `money` adds dollars. `person` is `{role, about,
family?, named?}`: someone who goes on his card; `family` gives them his surname, `named: false` leaves them called by the role
alone. Every background must be reachable from every age's scenes (the validator checks).

### names@1 (examples: `england.json`, `brazil.json`)
A country (D302, D57): `country` (its name), `cities` (the hometowns offered, in order), `first` and `last` (common names).
Loaded by `NameLibrary` (`sim/world/name_library.gd`); a rolled person's name comes from his hometown's country.

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
| `kind` | `striking` · `wrestling` · `grappling` · `sparring` · `conditioning` · `mind` · `recovery` | What kind of training it is: the planner colours its tile by it (D170, `docs/02` §3.10) |
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
| `career_only` (optional) | bool | Put in by the career, never planned: the camp planner doesn't offer it (the gym shift, D313) |

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

### career@1 (saved by the game, not in `data/`)
One career (D301, `docs/03` §10.1): a slot's file in the player's `user://saves/` folder (`slot_0.json` … `slot_2.json`,
each with a `.backup.json` of the save before it). Written by `CareerSaves` (`game/career_saves.gd`) from `Career.to_dict()`
(`sim/world/career.gd`). Numbers come back from JSON as floats; `Career.from_dict()` makes whole numbers whole again.

| Field | Meaning |
|---|---|
| `schema`, `version` | `"career"` and the format's version (1). A newer version than the game knows is refused; older ones go through `Career.migrate()` |
| `seed`, `dice` | The career's seed and where its dice are, as text (64-bit numbers don't survive a JSON number) |
| `coach` | `{name, background?, specialty?}`: the head coach, the player. `background` is a `data/enums/coach_backgrounds` id and `specialty` one of `striking`, `wrestling`, `bjj`, `motivator`, `tactician` (D311, `docs/03` §11.1); a career saved before D311 has neither and loads with none |
| `fighter` | The fighter@1 profile he started with (id `career_fighter`); what changes with training is in `trainee`. A career made on the new-career screen adds `background`, `age` and `potential` (D302) |
| `about` | `nickname`, `hometown`, `country`, `background`: shown on screens, not used by fights |
| `gym` | Your gym, where he trains (D313, `docs/03` §11.3): `{kind (a data/gyms id), culture (a gym_cultures id), name, owner_name, owner, fee}`. Optional: `{}` (or missing) for a career before D313 |
| `gym_owed` | Dollars of gym fee he couldn't pay, worked off in Saturday shifts (D313; optional, 0 when missing) |
| `childhood` | His childhood scenes (D312, `docs/03` §11.2): `{picks: [{scene, choice}], second (the runner-up background), people: [{role, name, about, age}]}`. Optional: `{}` (or missing) when his background was picked from the list or the career predates D312 |
| `trainee` | `TrainingCamp.snapshot()`: `stats` (with fractions), `style`, `fatigue`, `injured_days`, `injury_area`, `age_years`, `potential`, `camp_gains` (this camp's, for the soft cap) and `dice` |
| `calendar` | `first_monday` (days since 1 Jan 1970 of week 0's Monday) and `week` (weeks since) |
| `suspended_days`, `money`, `pro`, `week_plan`, `worn_last_week` | Days of medical suspension left; money; turned pro; the data/week_plans id run between fights; whether training wore him down last week, so *Advance* stops only on the first such week (D303; optional, false when missing) |
| `next_offers_week` | The first week the next set of fight offers can come in (D304; optional, next week when missing) |
| `fights` | One entry per fight, oldest first: `result` (`win`, `loss`, `draw`, `no_contest`), `opponent` (an id in `opponents`), `week`, `pro`, and what the fight screen adds (`method`, `round`, `time`, `ruleset`, `purse`, `seed`, `simmed`, and the aftermath: `suspension_days`, `suspension_why`, `chin_lost`, D305) |
| `opponents` | `{id: fighter@1 profile}` for everyone he's fought or is booked to fight |
| `booked`, `offers` | The offers on the table (D304, `docs/03` §10.4): each `{id, profile (the opponent, fighter@1, with `age`), about {nickname, hometown, country}, style (a style sheet id), difficulty (`easier`, `even`, `harder`), week (fight week), expires (its last open week), ruleset, pro, purse ({show, win} in dollars, or {} for an amateur)}`. `booked` is the offer taken, without `profile` (that goes into `opponents`), plus `opponent` (his id), `camp_weeks`, and `fight_week_report` once fight week has run ({} when not booked) |
| `summary` | What the load screen shows without loading the career: `name`, `nickname`, `coach`, `coach_specialty`, `hometown`, `country`, `background`, `age`, `date`, `week`, `pro`, `amateur_record`, `pro_record` |
| `saved_at`, `saved_unix`, `game` | Added by `CareerSaves`: when (UTC, and Unix seconds for *Continue*), and the game name and Godot version |

## 4. What the validator checks
Valid JSON with a known schema · id matches file name and folder · required fields present with the right types ·
action timings are whole ticks · values come from the allowed lists · every reference (positions, actions, calls, triggers,
flags, stats, sessions, gameplans) points to something that exists · a session's shares add up to 1 · a week plan has 6 days
of 2 sessions · a background builds on a real fighter with real stats, gifts and flaws · a country has cities and names · a childhood
scene has three choices leaning toward real backgrounds, and every background can come out of every age · a gym trains real
session kinds and every background has a gym that suits him.

## 5. Not yet defined (comes with the issue that needs it)
Technique proficiency and the `techniques` link to `requires_technique` (D6), state/threshold trigger fields (#16), techniques and promotions (Alpha).
