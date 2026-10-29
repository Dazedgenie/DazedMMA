# ui/ — interface

HUD, menus, minigame UI and themes (docs/06-fight-hud.md). Presentation only: no game rules here.

- `fight_hud.gd`: HUD v0 for the fight screen (docs/06 §6): top bar, plan panel, opponent corner bubble, feed, voice meter, call bar, and the dialog in the middle (bell, result, menu, towel).
- `fight_feed.gd`: the feed with its All / Key moments / Explanations filter. `voice_meter.gd`: the voice bar with the garbled zone.
- `fight_setup.gd`: the screen before a fight (matchup, speed, difficulty, cue toggles, rules, seed). `rule_slots.gd`: the two rule slots and the Drilled slider, used there and between rounds.
- `camp_planner.gd`: the training camp planner (docs/02 §3.6, D134), from the setup's "Training camp first": plan each week, see its forecast, run the camp, then fight with the trained fighter.
- `mitt_work_screen.gd`: the mitt work minigame (docs/02 §3.9, D137), opened by the planner for each Boxing drills session ticked to Play; the judging is `sim/world/mitt_work.gd`.
- `debug_overlay.gd`: F3 on the fight screen, the raw numbers behind what's on screen.
- `debug_console.gd`: developer console (toggle with the ` key). "Run test fight" runs `game/sim_check.gd` and prints pass/fail; the fight on screen is logged here with every odds breakdown. Lines are formatted by `fight_log_formatter.gd`.
