# ui/ — interface

HUD, menus, minigame UI and themes (docs/06-fight-hud.md). Presentation only: no game rules here.

- `debug_console.gd`: developer console in the main scene (toggle with the ` key). "Run test fight" runs `game/sim_check.gd` and prints pass/fail; "Live fight" plays a fight at 2x and prints every event. Lines are formatted by `fight_log_formatter.gd`.
