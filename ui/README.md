# ui/ — interface

HUD, menus, minigame UI and themes (docs/06-fight-hud.md). Presentation only: no game rules here.

- `debug_console.gd`: developer console in the main scene (toggle with the ` key). "Run test fight" runs `game/sim_check.gd` and prints pass/fail; "Live fight" plays a fight at 2x and prints every event. Lines are formatted by `fight_log_formatter.gd`.
- `cage_map.gd`: TEMPORARY top-down view of the cage for judging how the AI moves (D106, docs/01 §20.1). The console's **Cage view** box shows it beside the log during a Live fight. Delete once the grey-box fight view (#19) exists.
