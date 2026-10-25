# tools/ — developer scripts

Headless runners and utilities. `run_sim.gd` runs one placeholder fight (a kicker against a boxer) with no scene tree
and prints a summary; `--fights=N` runs N seeds and counts how they ended:

    godot --headless --script res://tools/run_sim.gd -- --seed=123
    godot --headless --script res://tools/run_sim.gd -- --fights=200

`balance.gd` is the balance harness (#18): many seeded fights for one or more pairs from `data/fighters/`, written to
`build/balance/balance.csv` (one line per fight) and `build/balance/summary.txt`, with the balance targets (D96, D97,
`docs/12` §4) marked MET, MISSED or INFO. 100 fights per pair takes about a minute:

    godot --headless --script res://tools/balance.gd -- --fights=200 --pairs=kicker:boxer,check_red:check_blue
    godot --headless --script res://tools/balance.gd -- --seed=500 --ruleset=amateur_adult --out=build/amateur

Coaching bots (D12, `docs/01` §22.7): `--corners` runs every pair again with a bot in a corner, `--coach` says whose
(`red`, `blue`, or `both`, the default, one after the other). `none` is the engine on its own, `ideal` a good coach,
`spam` a random call every 1.5 s, `ai` the opponent's AI corner (D68). The summary then checks good coaching is worth
+10–20% wins and spam less than nothing, pooled over both corners. Wrestler vs Kicker, about 25 minutes:

    godot --headless --script res://tools/balance.gd -- --fights=100 --pairs=wrestler:kicker,kicker:wrestler --corners=none,ideal,spam,ai --coach=both

The CSV columns are listed in `sim/balance/fight_summary.gd` (`FightSummary.COLUMNS`). The movement columns (D107,
`docs/01` §20.2) are shares of standing time: `fence_*` near the fence or pinned, `pinned_*` pinned, `centre_*` nearer the
centre than the opponent, and `chase` one fighter stepping back while the other steps in. `corner_red`/`corner_blue` name the bot in each corner
and `calls_red`/`calls_blue` count the calls it made.
