# game/ — game layer and scenes

Godot scenes and nodes: the main scene, fight view, career hub, calendar, save/load.
Reads simulation state and events from `sim/` and sends player commands to it.

- `main.tscn` / `main.gd`: the fight prototype (#19, docs/06 §6): setup (or the camp planner first, D134) → three rounds with the bell in between → result. Hotkeys live here.
- `fight_driver.gd`: plays a FightSim in real time at the chosen speed (Normal, Fast, slow-mo, auto slow-mo, pause) without changing it.
- `arena_view.gd`: the grey-box octagon, the isometric camera and the range/position tag. `fighter_figure.gd`: one grey-box fighter acting out the move, with the delay ring, labels and the tell cue.
- `sim_check.gd`: the short self-check fight behind the debug console's "Run test fight" (and `-- --self-check` on an exported build).
- `playtest.gd`: the playtest's fights in order (`data/playtest/`, D118). `fight_record.gd`: the file each finished fight is saved as (`user://fights/`). `playtest_report.gd`: adds those files up for the write-up (`docs/playtests/`).
- `career_saves.gd`: the career save slots in `user://saves/` (D301, `docs/03` §10.1): safe writes, a backup per slot, the load screen's summary and *Continue*'s slot.
- `strike_sounds.gd`: every strike's connected, missed and blocked sound, made in code, and which one a fight event plays (D190, `docs/06` §6.8).
