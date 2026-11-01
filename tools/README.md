# tools/ — developer scripts

The rendered visual reviews require a graphics display (Godot 4.7.2). `visual_preview.gd` captures
the real fight screen in standing, striking, kicking, clinch, ground and fence poses; `--720p`
checks the smaller desktop window. `character_preview.gd` captures the actual fighter models
from the front, three-quarter and back under neutral lighting. Neither writes a saved fight.
`motion_preview.gd` captures a real seeded Boxer–Kicker fight at 1× speed, with the HUD hidden,
as 960×540 PNG frames at 24 fps. It also leaves saved fights untouched. Use a fresh output folder
when changing the duration so old trailing frames do not enter the encoded video. `--red=`, `--blue=` and `--seed=`
record another fight (the Muay Thai fighter against the Wrestler on seed 35013 spends most of a minute in the clinch).
`--from=` plays the fight's first seconds without saving frames, to get to a moment quickly (D288: the Judoka against
the Wrestler on seed 35000 from 11.5 s throws him with a hip throw).

    godot --script res://tools/visual_preview.gd -- --out=res://build/visual --720p
    godot --script res://tools/character_preview.gd -- --out=res://build/characters
    godot --script res://tools/motion_preview.gd -- --out=res://build/motion --seconds=12
    ffmpeg -framerate 24 -i build/motion/frame-%04d.png -c:v libx264 -pix_fmt yuv420p build/motion.mp4

`strike_preview.gd` arranges every covered strike landing, blocked, slipped or checked, missing and thrown out of
range, side on to the camera, at 24 frames a fight second (D281, `docs/13`). Since D360 each one shows its tell in
the telegraph and travels out over its wind-up, and the kicks chamber first; slow a clip down to study one. For the
camera turning to see them side-on (D361) and the stances by style (D362), record a real fight with
`motion_preview.gd` (the Boxer against the Kicker for 20 s, or `--red=wrestler --blue=muay_thai` for two stances):

    godot --script res://tools/strike_preview.gd -- --out=res://build/strikes

`grapple_preview.gd` arranges the clinch grips (hand fighting, an underhook, the body lock), each grip and clinch move,
ground and pound, covering up and turning away, the sweeps, passes and throws, and every submission going on and held,
side on to the camera, at 24 frames a fight second (D282, `docs/13`). `--only=` takes move or position ids:

    godot --script res://tools/grapple_preview.gd -- --out=res://build/grapples --only=pummel,armbar

`rig_preview.gd` shows the rig prototype (D283, `docs/13`): two code skeletons posed against each other in the clinch,
the double leg, the full guard, the sprawl and getting up, blended from one to the next, with today's figures first for
the clinch and the guard. `--stills` writes one picture per pose; `--angle=` turns the camera; `--body` puts Kyle's
skinned Tripo body (`game/bodies/tripo_fighter.glb`, D284; the fight screen draws it too, D285) on the rigs;
`--clinch` writes the clinch poses built from grips instead (D286, `clinch-<name>.png`), the fence's too (D287: the
drive, spinning off, turning him, breaking); `--takedowns` writes the clinch takedowns from the clinch to the canvas
(D288, `takedown-<move>-<n>.png`, with the scramble and the sprawl); `--ground` writes the ground positions with their
grips (D289, `ground-<name>.png`) and a sweep rolling them over in steps (`ground-sweep-<n>.png`):

    godot --script res://tools/rig_preview.gd -- --out=res://build/rig --stills
    godot --script res://tools/rig_preview.gd -- --out=res://build/clinch --clinch --body
    godot --script res://tools/rig_preview.gd -- --out=res://build/takedowns --takedowns --body
    godot --script res://tools/rig_preview.gd -- --out=res://build/ground --ground --body

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
`spam` a random call every 1.5 s, `ai` the opponent's AI corner (D68), `mash:pressure` one call repeated as soon as it's
over (D257). `ideal:fire_back+pass` is the good coach with only those of its D257 moments (`ideal:` the corner from before
D257; the moments are `Corner.MOMENTS`). The summary then checks good coaching is worth +10–20% wins and spam less than
nothing, pooled over both corners, and each pairing's **Calls** line says what each call did (heard, taken, won the
exchange it was called for; `docs/01` §22.10). Wrestler vs Kicker, about 25 minutes:

    godot --headless --script res://tools/balance.gd -- --fights=100 --pairs=wrestler:kicker,kicker:wrestler --corners=none,ideal,spam,ai --coach=both

Drilled rules (#17, `docs/01` §23): `--rules=wrestler:catch_kick_and_shoot@80` runs every pair once more with those
fighters' rules (`fighter:rule@drilled`, comma-separated; a fighter's rules fill slots 1 and 2 in order) and reports what
they did to that fighter's wins, next to the same fights without rules.

The CSV columns are listed in `sim/balance/fight_summary.gd` (`FightSummary.COLUMNS`). The movement columns (D107,
`docs/01` §20.2) are shares of standing time: `fence_*` near the fence or pinned, `pinned_*` pinned, `centre_*` nearer the
centre than the opponent, and `chase` one fighter stepping back while the other steps in. `corner_red`/`corner_blue` name the bot in each corner
and `calls_red`/`calls_blue` count the calls it made, `call_outcomes_red`/`_blue` what each did (D257); `rules_red`/`rules_blue` name each fighter's drilled rules and
`fired_red`/`fired_blue` count how often they fired.

Each run also writes `run.json`: the arguments, the commit, a hash of `data/`, the Godot version, the time taken and the
computer time a simulated tick took (D250, `docs/01` §2.4). The summary gives win shares and the coaching and rule changes
with 95% ranges, and the `chosen_*` columns count who chose each fighter's moves (own AI, call, rule, command), and the `ai_*`
columns which part of his own AI did (defence, counter, combination, set-up, lead, cage, tied up, downed; D254).

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
strike (connected, missed, blocked with a pause between), `all_strikes.wav` with every strike in turn, and
`fence_rattle.wav` with the fence's rattle when a man is slammed into it (D287) and `takedown_thud.wav` with a
takedown's landing (D288). `--only` picks
some:

    godot --headless --script res://tools/strike_sounds.gd
    godot --headless --script res://tools/strike_sounds.gd -- --only=jab,leg_kick

`matchups.gd` builds the style matchup table the world's other fights are rolled from (D353, `docs/03` §12.3): every
style against every other on the fight engine (`--fights=` a pair, 60 by default in the shipped table, about 25 minutes
on 4 cores), fitted into each pair's edge at an even level and the worth of a point of average stat, with how each
style's wins and losses end and in which round. It writes `data/world/matchups.json` and prints how many pairs the
model gets inside the engine's 95% range. Rebuild it when fights change.

    godot --headless --script res://tools/matchups.gd -- --fights=60
