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
- **Exports:** add `*.json` to the export preset's *non-resource files* filter, or data won't ship in builds (needed from the first playtest build, #20).

## 2. Folder map

| Folder | Schema | What it is |
|---|---|---|
| `data/enums/` | `enum@1` | Fixed vocabularies: `flags` (state flags, `docs/01` §5), `stats` (attributes, `docs/02` §2), `gifts` and `flaws` (`docs/11` §4.3) |
| `data/actions/` | `action@2` | Everything a fighter can do: strikes, takedowns, defenses, ground moves |
| `data/positions/` | `position@2` | Standing, clinch and ground positions (`docs/01` §4) |
| `data/calls/` | `call@1` | Coach calls: now/read, intent/technique (`docs/01` §6) |
| `data/triggers/` | `trigger@1` | Building blocks for read calls and drilled rules ("opponent starts a kick") |
| `data/rules/` | `rule@1` | Drilled-rule presets: trigger → action (`docs/01` §6.0) |
| `data/rulesets/` | `ruleset@1` | Amateur/pro rules (`docs/08`) |
| `data/fighters/` | `fighter@1` | Fighter profiles: authored fighters, archetype templates and (later) generated fighters (D94) |

## 3. Schemas

### action@2 (example: `data/actions/body_kick.json`)
| Field | Type | Meaning |
|---|---|---|
| `name` | string | Display name |
| `category` | `strike` · `takedown` · `defense` · `movement` · `clinch` · `ground` · `submission` | |
| `positions` | position ids | Where it can be used |
| `ranges` | `long` · `mid` · `pocket` · `clinch` | Distance bands it works from |
| `phases_ms` | `{telegraph, windup, active, recovery}` | Commitment model timings (`docs/01` §5) |
| `stamina_cost` | number | Stamina spent |
| `flags_self` | `[{flag, from, to}]` | Flags the *user* carries during those phases (`ONE_LEG` from windup to recovery) |
| `stats` | `{offense: [stat], defense: [stat]}` | Attributes that decide the contest |
| `opportunities` | `[{opponent_flag, success_bonus, required?}]` | Bonus when the *opponent* carries that flag; `required: true` = only possible then (catch-kick) |
| `strike` / `takedown` / `defense` | object | Category-specific: `{target, base_damage}` · `{base_success}` · `{against_categories, base_success}`. Where a landed takedown takes the fight is in the position files |
| `requires_technique` | id or null | Needs this technique learned (`docs/02` §2.1) |

### position@2 (example: `standing.json`)
`name`, `phase` (`standing`/`clinch`/`ground`), `roles` (`neutral` or `top`/`bottom`), and per role:
`stamina_drain_per_s`, `control_score` (judging), `strike_damage_multiplier`.

`transitions`: how the fight leaves this position (`docs/01` §4.1). Each entry is
`{action, from_role, to, roles: {actor, opponent}}`: when the fighter in `from_role` lands `action` here, the fight moves to
position `to`, with the actor and the opponent in those roles. Example from `standing.json`:
`{ "action": "double_leg", "from_role": "neutral", "to": "full_guard", "roles": { "actor": "top", "opponent": "bottom" } }`.
An action with no entry doesn't move the fight. The validator checks that the action exists and can be used here, `from_role`
is one of this position's roles, `to` exists and has both roles, and no action/role pair is listed twice.
Loaded by `PositionLibrary` (`sim/fight/position_library.gd`).

Versions: position@2 added `transitions`; action@2 moved a takedown's `on_success` into them (no saved data needed migrating).

### call@1 (examples: `takedown.json` now/intent, `catch_the_kick.json` read/technique)
`name`, `kind` (`now`/`read`), `tier` (`intent`/`technique`), `parent` (intent call it unlocks under), `hotkey` (1–9 or null),
`voice_cost`, `positions`, `actions` (what the fighter may attempt), `priority_boost` (now calls),
`read: {trigger, duration_ms, attention_cost}` (read calls), `requires_technique`.

### trigger@1 (example: `opp_kick_starts.json`)
`name`, `type` (`event`/`state`/`threshold`), `event` (for event triggers, e.g. `action_phase`),
`match` (e.g. `{actor: "opponent", action_ids: ["body_kick"], phase: "telegraph"}`). State/threshold match fields get defined in #16.

### rule@1 (example: `catch_kick_and_shoot.json`)
`name`, `trigger` (trigger id), `action` (action id), `priority`, `cooldown_ms`. Reliability comes from camp drilling at runtime, not data.

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
| `tendencies` | `{work_rate, actions: {action id: weight}}` | `work_rate`: chance per idle tick to start something (0–1). `actions`: how much they favour a move (1.0 = normal, 0–10), `docs/01` §7 |
| `tells` | `[{trigger, action, chance, within_ms}]` | Habits an opponent can scout: after `trigger`, `chance` to throw `action` within `within_ms` (`docs/01` §7, D11). Read by the AI from #14 |

Without a `template`, every field above must be present. A fight is saved and replayed as seed + fighter ids + ruleset +
command log (`FightSim.record()` / `FightSim.from_record()`).

## 4. What the validator checks
Valid JSON with a known schema · id matches file name and folder · required fields present with the right types ·
action timings are whole ticks · values come from the allowed lists · every reference (positions, actions, calls, triggers,
flags, stats) points to something that exists.

## 5. Not yet defined (comes with the issue that needs it)
How the AI reads tells (#14), technique proficiency and the `techniques` link to `requires_technique` (D6), state/threshold trigger fields (#16), backgrounds/vignettes, techniques, promotions and names (Alpha).
