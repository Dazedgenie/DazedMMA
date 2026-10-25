# Playtests

> Related decisions: D62 (friends + small Discord), D91 (compare 1× and 2×), D118 (the playtest kit). Issue #20.
> The playtest answers the prototype's one question (`10` §1): *does calling the takedown during the kick feel right?*

This folder holds everything for running a playtest and writing it up:

| File | What it is | Who uses it |
|---|---|---|
| [`script.md`](script.md) | The host's script: setup, the four fights in order, what to watch for, what to say and not say | Host |
| [`feedback-form.md`](feedback-form.md) | The questions for each tester after the fights, each tied to a test in `10` §2 | Tester (the host reads them out or pastes them into a form) |
| [`write-up-template.md`](write-up-template.md) | The write-up shell: every acceptance test from `10` §2 with where its answer comes from, and the go / adjust / rethink decision | Host, after the session |
| [`tester-readme.txt`](tester-readme.txt) | The read-me that ships inside the download (how to start, the keys, sending the saved fights back) | Tester |

A finished write-up goes here too, as `YYYY-MM-DD-<name>.md` (for example `2026-11-08-first-playtest.md`), and its decision
goes into the decisions log (`00` §0) as its own row.

## 1. Getting the build

Every push to `main` (and every pull request) runs the **Playtest build** workflow (`.github/workflows/playtest-build.yml`).
It exports the game for Windows, checks a Linux export of the same project starts and fights a self-check fight (so the
`data/` files made it into the build), and uploads the Windows build.

1. On GitHub, open **Actions → Playtest build** and click the newest green run on `main`.
2. Under **Artifacts**, download `ChinCheck-windows-<commit>`. It's a zip with `ChinCheck.exe` (about 110 MB, everything inside
   it) and `README.txt` (the tester read-me).
3. Send that zip to the testers as it is. Downloads are kept for 30 days; re-run the workflow (**Run workflow**) to make a fresh one.

To build it yourself instead: install Godot 4.7.2 with its export templates, then
`godot --headless --export-release "Windows Desktop" build/export/windows/ChinCheck.exe` (presets in `export_presets.cfg`).

## 2. Running a session

Follow [`script.md`](script.md). In short: each tester plays four fights (fight 1, fight 2 at one speed, fight 2 again at
the other speed, fight 3), thinks out loud, then answers the feedback form. Half the testers start fight 2 at 2× and half at
1× (D91). About 30–40 minutes a tester. Aim for 4–5 testers (`10` §2 test 1 is "4 of 5").

The game saves every fight on its own, one JSON file per fight (`fight_record@1`, `09` §3). Collect each tester's files at
the end (the result screen's **Open saved fights** button opens the folder).

## 3. Adding up the saved fights

Put every tester's files in one folder (the tester's name is inside each file, so they don't need renaming) and run:

```
godot --headless --script res://tools/playtest_report.gd -- --dir=/path/to/all/fights --out=build/playtest
```

It writes `build/playtest/playtest.csv` (one line per fight) and `build/playtest/summary.txt` (per fight and per speed:
fights, wins, well-timed takedowns a fight, perfect calls a fight, and how many fights had 2 or more well-timed takedowns),
and checks every fight replays to the same result from its file (`10` §2 "Reproducibility").

A **well-timed takedown** is one that worked and that the player chose, by a call or a drilled rule (not one the Wrestler
went for on his own). A **perfect call** is the flourish (D52): a called move that worked as a counter, such as the catch off
"Catch the kick!".

## 4. Writing it up

Copy [`write-up-template.md`](write-up-template.md) to `YYYY-MM-DD-<name>.md`, fill in every row, and pick **go**, **adjust**
or **rethink** with the reasons. Then add the decision row to `00` §0 and close or update issue #20.

## 5. Changing the playtest

| To change | Edit |
|---|---|
| The fights (matchup, which calls are open, drilled rules, tell cue, the tip) | `data/playtest/*.json` (`playtest@1`, `09` §3); `order` sets the order |
| What the game saves after a fight | `game/fight_record.gd` (`KEPT_SETTINGS`, `coaching_stats`) |
| The report's columns, groups and the "2+ well-timed takedowns" line | `game/playtest_report.gd` (`COLUMNS`, `LEARNED_TAKEDOWNS`) |
| What ships in the build | `export_presets.cfg` (`include_filter`, `exclude_filter`) |
| The download (name, how long it's kept) | `.github/workflows/playtest-build.yml` |
| The script, form or write-up | The files in this folder |

Tests: `tests/game/test_playtest.gd` (steps, settings, records, the report), `tests/game/test_main_scene.gd` (a playtest
fight from setup to saved record), `tests/data/test_data_files.gd` (the `playtest@1` files).
