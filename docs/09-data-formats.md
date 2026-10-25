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

## 3. Schemas

### action@2 (example: `data/actions/body_kick.json`)
| Field | Type | Meaning |
|---|---|---|
| `name` | string | Display name |
| `category` | `strike` · `takedown` · `defense` · `movement` · `clinch` · `ground` · `submission` | |
| `positions` | position ids | Where it can be used |
| `roles` (optional) | `neutral` · `top` · `bottom` | Which roles may use it there (get up: `bottom` or `neutral`, so the fighter on top can't). Left out = any role |
| `basic` (optional) | bool | `true` = every fighter knows it, whatever their `techniques` (sprawl, clinch entry and break, get up, scramble) |
| `ranges` | `long` · `mid` · `pocket` · `clinch` | Distance bands it works from |
| `phases_ms` | `{telegraph, windup, active, recovery}` | Commitment model timings (`docs/01` §5) |
| `stamina_cost` | number | Stamina spent |
| `flags_self` | `[{flag, from, to}]` | Flags the *user* carries during those phases (`ONE_LEG` from windup to recovery) |
| `stats` | `{offense: [stat], defense: [stat]}` | Attributes that decide the contest |
| `opportunities` | `[{opponent_flag \| own_flag, success_bonus, required?, target?, damage_multiplier?, stops?}]` | Bonus when the *opponent* carries that flag; `required: true` = only possible then (catch-kick). `own_flag` instead: when the user carries it (get up with your back on the fence, +0.15; a negative bonus makes it harder). For strikes, when the opening is there: `target` sends it there instead (a knee into a shot goes to the head), `damage_multiplier` scales it, `stops: true` stops the opponent's move (`docs/01` §21.2) |
| `strike` / `takedown` / `defense` / `clinch` / `ground` | object | Category-specific: `{target, base_damage, push_m?}` · `{base_success, partial_within?}` · `{against_categories, base_success}` · `{base_success, partial_within?}` · `{base_success, partial_within?}`. `partial_within` (a chance, optional): a roll that misses the odds by less than this half works, and goes where the position's `partial` transition says (a scramble). `push_m` (metres, optional): a landed strike shoves the opponent back that far (the teep, 0.5). Where a landed takedown takes the fight is in the position files. A `movement` move (the stance shift) has none: it only takes time and stamina, and can be a tell |
| `requires_technique` | id or null | Needs this technique learned (`docs/02` §2.1) |

### position@2 (example: `standing.json`)
`name`, `phase` (`standing`/`clinch`/`ground`), `roles` (`neutral` or `top`/`bottom`), and per role:
`stamina_drain_per_s`, `control_score` (judging), `strike_damage_multiplier`.

`transitions`: how the fight leaves this position (`docs/01` §4.1). Each entry is
`{action, from_role, result?, to, roles: {actor, opponent}}`: when the fighter in `from_role` lands `action` here, the fight moves to
position `to`, with the actor and the opponent in those roles. `result` is `success` (the default) or `partial`: where the move
goes when it only half works (`partial_within`, a scramble). Example from `standing.json`:
`{ "action": "double_leg", "from_role": "neutral", "to": "full_guard", "roles": { "actor": "top", "opponent": "bottom" } }`.
An action with no entry doesn't move the fight. The validator checks that the action exists and can be used here, `from_role`
is one of this position's roles (and one the action allows), `to` exists and has both roles, and no action/role/result is listed twice.
Loaded by `PositionLibrary` (`sim/fight/position_library.gd`).

Versions: position@2 added `transitions`; action@2 moved a takedown's `on_success` into them (no saved data needed migrating).

### call@2 (examples: `takedown.json` attempt, `pressure.json` focus, `catch_the_kick.json` read)
`name` (as shouted, "Takedown!"), `kind` (`now`/`read`), `tier` (`intent`/`technique`), `parent` (intent call it unlocks under),
`hotkey` (a digit 0–9, each used once, or null), `voice_cost`, `positions` (where it can be acted on), `roles` (optional:
`neutral`/`top`/`bottom`), `actions`, `requires_technique` (an action id the fighter must know, or null).
A now call is one of two kinds (`docs/01` §22.2):
- an **attempt**: `actions` lists the moves to try, in order (the first that would work right now is used), and no `focus`;
- a **focus**: `actions` is empty and `focus: {duration_ms, leanings, weights, read_bonus, sprawl_bonus}` says how the fighter
  fights for that long: `leanings` adds points to Pace/Range/Base/Risk (−100 to 100), `weights` multiplies the AI's weight for
  an action id or category (0–10), `read_bonus` adds to the chance to read the opponent's moves of a category (0–1),
  `sprawl_bonus` to the chance to sprawl on a shot (0–1). All optional except `duration_ms`.

A read call has `actions` (what the fighter reacts with) and `read: {trigger, duration_ms, attention_cost}`: primed for
`duration_ms`, it reacts to the trigger once; while primed, Striking and Takedown defense drop by `attention_cost` (0–0.5).
Loaded by `CallLibrary` (`sim/fight/call_library.gd`). call@2 replaced call@1's `priority_boost` with the attempt/focus split
(an accepted call claims the choice outright, `docs/01` §19); the two call@1 files were migrated.

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

### ruleset@1 (examples: `pro`, `amateur_adult`, `amateur_teen`)
`name`, `rounds`, `title_rounds`, `round_seconds`, `glove_oz`, `gear`, `allows` (exactly: `elbows`, `head_strikes_on_ground`,
`knees_to_head_standing`, `knees_to_head_grounded`, `heel_hooks`, `slams`, `takedowns`), `damage_multiplier`, `cut_multiplier`,
`early_stoppage_bias`, `weigh_in` (`same_day`/`day_before`), `paid`.

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

### fight_record@1 (saved by the game, not in `data/`)
What a fight on the fight screen leaves behind, one file per fight in the player's `user://fights/` folder (on Windows
`%APPDATA%\Godot\app_userdata\Chin Check\fights`). Built by `FightRecord` (`game/fight_record.gd`); added up by
`tools/playtest_report.gd` (`docs/playtests/README.md` §3).

| Field | Meaning |
|---|---|
| `saved_at`, `game` | When, and the game name and Godot version |
| `settings` | The setup it was played with: `label`, `step` (playtest id or ""), `tester`, `normal_rate` (1 or 2), `easy`, `tell_cues`, `auto_slow`, `flourishes` |
| `player` | The player's corner (0 = red) |
| `result`, `won`, `rounds_played` | The `FIGHT_ENDED` event's data (`winner`, `result`, `stopped_by`, cards), and whether the player won |
| `stats` | The player's coaching: `calls_made`, `calls_ignored`, `calls_by_id`, `perfect_calls`, takedowns that worked split by who chose them (`takedowns_by_call`, `takedowns_by_rule`, `takedowns_own`), `catch_kicks_landed`, `rules_fired` |
| `fighters` | Each fighter's id, name, strikes and takedowns landed and tried, damage |
| `replay` | `FightSim.record()` plus `ticks`: the fight replays from it to the same ending |

## 4. What the validator checks
Valid JSON with a known schema · id matches file name and folder · required fields present with the right types ·
action timings are whole ticks · values come from the allowed lists · every reference (positions, actions, calls, triggers,
flags, stats) points to something that exists.

## 5. Not yet defined (comes with the issue that needs it)
Technique proficiency and the `techniques` link to `requires_technique` (D6), state/threshold trigger fields (#16), backgrounds/vignettes, techniques, promotions and names (Alpha).
