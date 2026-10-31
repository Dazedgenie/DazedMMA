# tools/ — developer scripts

The rendered visual reviews require a graphics display (Godot 4.7.2). `visual_preview.gd` captures
the real fight screen in standing, striking, kicking, clinch, ground and fence poses; `--720p`
checks the smaller desktop window. `character_preview.gd` captures the actual fighter models
from the front, three-quarter and back under neutral lighting. Neither writes a saved fight.

    godot --script res://tools/visual_preview.gd -- --out=res://build/visual --720p
    godot --script res://tools/character_preview.gd -- --out=res://build/characters

Headless runners and utilities. `run_sim.gd` runs one placeholder fight (a kicker against a boxer) with no scene tree
and prints a summary; `--fights=N` runs N seeds and counts how they ended:

    godot --headless --script res://tools/run_sim.gd -- --seed=123
    godot --headless --script res://tools/run_sim.gd -- --fights=200

`balance.gd` is the balance harness (#18): many seeded fights for one or more pairs from `data/fighters/`, written to
`build/balance/balance.csv` (one line per fight) and `build/balance/summary.txt`, with the balance targets (D96, D97,
`docs/12` §4) marked MET, MISSED or INFO. It plays the fights in one Godot process per CPU core (`--jobs=N` for N,
`--jobs=1` for one; the CSV and summary are the same either way, D123, `docs/01` §2.3). 100 fights per pair takes about
1.5 minutes on one core, so well under a minute on four:

    godot --headless --script res://tools/balance.gd -- --fights=200 --pairs=kicker:boxer,check_red:check_blue
    godot --headless --script res://tools/balance.gd -- --seed=500 --ruleset=amateur_adult --out=build/amateur

Coaching bots (D12, `docs/01` §22.7): `--corners` runs every pair again with a bot in a corner, `--coach` says whose
(`red`, `blue`, or `both`, the default, one after the other). `none` is the engine on its own, `ideal` a good coach,
`spam` a random call every 1.5 s, `ai` the opponent's AI corner (D68). The summary then checks good coaching is worth
+10–20% wins and spam less than nothing, pooled over both corners. Wrestler vs Kicker, about 25 minutes:

    godot --headless --script res://tools/balance.gd -- --fights=100 --pairs=wrestler:kicker,kicker:wrestler --corners=none,ideal,spam,ai --coach=both

Drilled rules (#17, `docs/01` §23): `--rules=wrestler:catch_kick_and_shoot@80` runs every pair once more with those
fighters' rules (`fighter:rule@drilled`, comma-separated; a fighter's rules fill slots 1 and 2 in order) and reports what
they did to that fighter's wins, next to the same fights without rules.

The CSV columns are listed in `sim/balance/fight_summary.gd` (`FightSummary.COLUMNS`). The movement columns (D107,
`docs/01` §20.2) are shares of standing time: `fence_*` near the fence or pinned, `pinned_*` pinned, `centre_*` nearer the
centre than the opponent, and `chase` one fighter stepping back while the other steps in. `corner_red`/`corner_blue` name the bot in each corner
and `calls_red`/`calls_blue` count the calls it made; `rules_red`/`rules_blue` name each fighter's drilled rules and
`fired_red`/`fired_blue` count how often they fired.

Each run also writes `run.json`: the arguments, the commit, a hash of `data/`, the Godot version, the time taken and the
computer time a simulated tick took (D250, `docs/01` §2.4). The summary gives win shares and the coaching and rule changes
with 95% ranges, and the `chosen_*` columns count who chose each fighter's moves (own AI, call, rule, command).

`balance_compare.gd` compares two harness runs fight by fight, matched by pairing and seed (D250): how many fights played
out differently, win shares, draws and finishes before and after, and the change with its 95% range. Run both on the same
seeds:

    godot --headless --script res://tools/balance_compare.gd -- --before=build/before/balance.csv --after=build/balance/balance.csv --columns=shots_red

`mirror_check.gd` checks a fight has no corner built in (D252, `docs/01` §2.5): it plays `--red` vs `--blue` on `--seed`,
and the same two in the other corners with blue stepping first on the first tick (the two then take turns, D253), and prints
the tick where the two stop mirroring each other. The harness's `--blue-first` plays a whole run that way.

    godot --headless --script res://tools/mirror_check.gd -- --red=kicker --blue=boxer --seed=1

`playtest_report.gd` adds up the playtest's saved fights (#20, D118, `docs/playtests/README.md` §3): one CSV line per fight
(`game/playtest_report.gd`, `PlaytestReport.COLUMNS`) and a summary per playtest fight and per speed, with every fight
re-run from its file to check it replays:

    godot --headless --script res://tools/playtest_report.gd -- --dir=/path/to/all/fights --out=build/playtest

`camp.gd` runs a training camp on a fighter (#54, D125, `docs/02` §3.5): `--plan` is a `data/week_plans/` id for every
week, `--taper=N` swaps the last N weeks for the taper plan (default 1), and `--age`/`--potential` stand in for a fighter
file that doesn't give them. It prints each week (sessions done, skipped and missed hurt, peak and Sunday fatigue, biggest
gains), the injuries, the stats that moved with their grades, the style pushes and the fight-night fatigue. With
`--fights=N` it also plays N fights against `--opponent` (default the Kicker) as the fighter was and as the camp left them:

    godot --headless --script res://tools/camp.gd -- --fighter=wrestler --plan=wrestler --weeks=8 --fights=100
    godot --headless --script res://tools/camp.gd -- --fighter=kicker --plan=all_out --weeks=8 --taper=0 --seed=4

`career_curve.gd` runs a fighter through years of camps and prints their stat groups by age, the climb to the prime and
the decline after it (D136, `docs/02` §3.8), and writes `build/career/curve.csv`. `--start` sets every stat (0 keeps the
fighter file's), `--fights` is fights a year, `--camp` the weeks of each camp (the last is a taper fight week), `--plans`
the week plans a camp rotates through, and `--between=off` rests the weeks between camps instead of training them:

    godot --headless --script res://tools/career_curve.gd -- --fighter=wrestler --start=45 --age=18 --to=38 --potential=90
    godot --headless --script res://tools/career_curve.gd -- --between=off --plans=striker,balanced,speed,power --fighter=boxer

`golden.gd` plays the golden fights (#35, D122, `docs/01` §2.2), the four fights pinned in
`tests/golden/golden_fights.json`, and says which ones changed and how. With `--update` it pins the new results: do that
only when a change is meant to change fights, commit the file and say why in the PR.

    godot --headless --script res://tools/golden.gd
    godot --headless --script res://tools/golden.gd -- --update

`strike_sounds.gd` writes every strike's sounds (D190, `docs/06` §6.8) to `build/strike_sounds/` as WAV files: one per
strike (connected, missed, blocked with a pause between) and `all_strikes.wav` with every strike in turn. `--only` picks
some:

    godot --headless --script res://tools/strike_sounds.gd
    godot --headless --script res://tools/strike_sounds.gd -- --only=jab,leg_kick
