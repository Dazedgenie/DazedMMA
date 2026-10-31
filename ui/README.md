# ui/ — interface

HUD, menus, minigame UI and themes (docs/06-fight-hud.md). Presentation only: no game rules here.

- `fight_hud.gd`: HUD v0 for the fight screen (docs/06 §6): top bar, plan panel, opponent corner bubble, feed, voice meter, call bar, and the dialog in the middle (bell, result, menu, towel).
- `fight_feed.gd`: the feed with its All / Key moments / Explanations filter. `voice_meter.gd`: the voice bar with the garbled zone.
- `title_screen.gd`: the title screen the game opens on (docs/03 §10.2, D302): Continue, New career, Load career, Quick fight, Quit. `new_career_screen.gd`: a new career (your name, his name, nickname, hometown, stance, background; Roll). `load_screen.gd`: the three save slots. `career_hub.gd`: the career hub between fights (docs/03 §10.3, D303): his card and stats, This week (the plan, Run this week, Advance), his fights and the calendar.
- `fight_setup.gd`: the screen before a fight (Quick fight on the title), as a tale of the tape (docs/06 §6.7, D172): any two fighters with ◀ ▶, their scouting cards and the keys to the fight, then the options (speed, difficulty, cue toggles, rules, seed). `tale_of_the_tape.gd`: the tape in its middle (frames and headline stats face to face, the opponent's scouted). `rule_slots.gd`: the two rule slots and the Drilled slider, used there and between rounds.
- `camp_planner.gd`: the training camp planner (docs/02 §3.6, D134; laid out as the camp week HUD, §3.10, D170), from the setup's "Training camp first": plan each week, see its forecast, run the camp, then fight with the trained fighter.
- The camp week HUD's parts (docs/02 §3.10, D170): `session_tile.gd` (a slot's tile, coloured by the session's kind), `fatigue_line.gd` (the week's fatigue under the tiles), `stat_bars.gd` (the stats as bars), `camp_countdown.gd` (the weeks counting down to the fight). `display_font.gd`: the display font for headings and big numbers (`fonts/`, SIL Open Font License).
- `result_card.gd`: the result screen (docs/06 §6.9, D173): the verdict, both figures, the fight sheet, the judges' cards and your corner's grade.
- `fight_night_card.gd`: the fight night card (docs/02 §3.11, D171), opened over the planner when the camp is over.
- `mitt_work_screen.gd`: the mitt work minigame (docs/02 §3.9, D137), opened by the planner for each Boxing drills session ticked to Play; the judging is `sim/world/mitt_work.gd`.
- `debug_overlay.gd`: F3 on the fight screen, the raw numbers behind what's on screen.
- `debug_console.gd`: developer console (toggle with the ` key). "Run test fight" runs `game/sim_check.gd` and prints pass/fail; the fight on screen is logged here with every odds breakdown. Lines are formatted by `fight_log_formatter.gd`.
