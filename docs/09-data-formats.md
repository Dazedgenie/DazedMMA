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
| `data/enums/` | `enum@1` | Fixed vocabularies: `flags` (state flags, `docs/01` §5), `stats` (attributes, `docs/02` §2) |
| `data/actions/` | `action@1` | Everything a fighter can do: strikes, takedowns, defenses, ground moves |
| `data/positions/` | `position@1` | Standing, clinch and ground positions (`docs/01` §4) |
| `data/calls/` | `call@1` | Coach calls: now/read, intent/technique (`docs/01` §6) |
| `data/triggers/` | `trigger@1` | Building blocks for read calls and drilled rules ("opponent starts a kick") |
| `data/rules/` | `rule@1` | Drilled-rule presets: trigger → action (`docs/01` §6.0) |
| `data/rulesets/` | `ruleset@1` | Amateur/pro rules (`docs/08`) |

## 3. Schemas

### action@1 (example: `data/actions/body_kick.json`)
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
| `strike` / `takedown` / `defense` | object | Category-specific: `{target, base_damage}` · `{base_success, on_success: {position, role}}` · `{against_categories, base_success}` |
| `requires_technique` | id or null | Needs this technique learned (`docs/02` §2.1) |

### position@1 (example: `full_guard.json`)
`name`, `phase` (`standing`/`clinch`/`ground`), `roles` (`neutral` or `top`/`bottom`), and per role:
`stamina_drain_per_s`, `control_score` (judging), `strike_damage_multiplier`.

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

## 4. What the validator checks
Valid JSON with a known schema · id matches file name and folder · required fields present with the right types ·
action timings are whole ticks · values come from the allowed lists · every reference (positions, actions, calls, triggers,
flags, stats) points to something that exists.

## 5. Not yet defined (comes with the issue that needs it)
Fighter profiles and tendencies/tells (#14), state/threshold trigger fields (#16), backgrounds/vignettes, techniques, promotions and names (Alpha).
