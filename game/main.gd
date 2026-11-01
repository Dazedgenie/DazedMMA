extends Node3D
## The fight prototype's screen (#19, docs/10 §1, docs/06): pick a fight, then coach
## the red corner through three rounds in the grey-box view (ArenaView) with HUD v0
## (FightHud), the speed controls (FightDriver) and the hotkeys of docs/06 §3. Blue's
## corner is the AI corner (D68). The bell holds the fight between rounds so the
## drilled rules can be changed; the result screen (FightResultCard, D173) offers a rematch.
##
## For the playtest (#20, D118): a playtest fight opens on its tip card and limits the
## call bar to its calls; every fight is saved as a FightRecord in user://fights/ for the
## write-up; `-- --self-check` runs the self-check fight and quits (the export check in CI).
##
## "Training camp first" on the setup opens the camp planner (CampPlanner, D133); its Fight!
## starts the same fight with the fighter as the camp left them (settings.red_profile).
##
## Strike sounds (StrikeSounds, D190) play during the fight at the setup's Sound volume; M mutes them.
##
## The game opens on the title screen (TitleScreen, D302): Continue, New career, Load career, Quick fight (the setup
## above, with the Playtest fights) and Quit. A career (Career, saved by CareerSaves, D301) is made on the new-career
## screen and lives on the career hub (CareerHub), which saves every week.

## Smallest window the UI still fits in (the game opens windowed and resizable).
const MIN_WINDOW_SIZE := Vector2i(960, 540)
const TITLE := "title"
const NEW_CAREER := "new_career"
const CHILDHOOD := "childhood"
const GYM := "gym"
const LOAD := "load"
const CAREER := "career"
const SETUP := "setup"
const FIGHT := "fight"
const ROUND_BREAK := "round_break"
const OVER := "over"

var arena: ArenaView
var hud: FightHud
var setup: FightSetup
var planner: CampPlanner
## The result screen (D173), over the fight when it's over.
var result: FightResultCard
var overlay: DebugOverlay
var sounds: StrikeSounds
var driver: FightDriver
var state: String = TITLE
## The title screen and the career's screens (D302).
var title: TitleScreen
var new_career: NewCareerScreen
## His childhood scenes (D312), between the new-career screen and the hub.
var childhood: ChildhoodScreen
## Your gym and the walk-in (D313), the last step before the hub.
var gym_screen: GymScreen
var load_screen: LoadScreen
var hub: CareerHub
## The career being played (null on Quick fight) and its save slot.
var career: Career
var career_slot: int = -1
## Where careers are saved (tests use their own folder).
var save_dir: String = CareerSaves.DIR
var settings: Dictionary = {}
## Where finished fights are saved ("" = don't save).
var record_dir: String = FightRecord.DIR
## The last fight's saved record ("" when it wasn't saved).
var last_record_path: String = ""

## A new career on its way through his childhood and the gym: the choices so far and its seed.
var _pending_choices: Dictionary = {}
var _pending_seed: int = 0
var _actions: ActionLibrary
var _roster: FighterLibrary
var _console: DebugConsole
var _break_rules: RuleSlots
## The gameplan pickers on the between-rounds panel (D320).
var _break_plan: GameplanPicker


func _ready() -> void:
	if "--self-check" in OS.get_cmdline_user_args():
		_self_check.call_deferred()
		return
	get_window().min_size = MIN_WINDOW_SIZE
	DisplayFont.add_symbols_fallback()
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()
	arena = ArenaView.new()
	add_child(arena)
	sounds = StrikeSounds.new()
	add_child(sounds)
	sounds.build_in_background()
	arena.fence_slammed.connect(sounds.play_rattle)  # The fence rattles (D287).
	arena.takedown_landed.connect(sounds.play_thud)  # A takedown thuds onto the canvas (D288).
	var ui: CanvasLayer = $UI
	hud = FightHud.new()
	hud.visible = false
	hud.call_pressed.connect(make_call)
	hud.control_pressed.connect(_on_control)
	ui.add_child(hud)
	overlay = DebugOverlay.new()
	ui.add_child(overlay)
	setup = FightSetup.new(_roster, _actions)
	setup.start_pressed.connect(start_fight)
	setup.camp_pressed.connect(open_camp)
	setup.menu_pressed.connect(show_title)
	setup.visible = false
	ui.add_child(setup)
	title = TitleScreen.new()
	title.continue_pressed.connect(load_career)
	title.new_career_pressed.connect(open_new_career)
	title.load_pressed.connect(open_load)
	title.quick_fight_pressed.connect(quick_fight)
	title.quit_pressed.connect(func() -> void: get_tree().quit())
	ui.add_child(title)
	new_career = NewCareerScreen.new()
	new_career.visible = false
	new_career.start_pressed.connect(start_career)
	new_career.back_pressed.connect(show_title)
	ui.add_child(new_career)
	childhood = ChildhoodScreen.new()
	childhood.visible = false
	childhood.finished.connect(_childhood_done)
	childhood.back_pressed.connect(open_new_career.bind(false))
	ui.add_child(childhood)
	gym_screen = GymScreen.new()
	gym_screen.visible = false
	gym_screen.finished.connect(_gym_done)
	gym_screen.back_pressed.connect(open_new_career.bind(false))
	ui.add_child(gym_screen)
	load_screen = LoadScreen.new()
	load_screen.visible = false
	load_screen.load_pressed.connect(load_career)
	load_screen.back_pressed.connect(show_title)
	ui.add_child(load_screen)
	hub = CareerHub.new()
	hub.visible = false
	hub.week_pressed.connect(run_career_week)
	hub.advance_pressed.connect(advance_career)
	hub.title_pressed.connect(_hub_to_title)
	hub.accept_pressed.connect(accept_offer)
	hub.decline_pressed.connect(decline_offer)
	hub.turn_pro_pressed.connect(turn_pro)
	hub.camp_pressed.connect(open_career_camp)
	ui.add_child(hub)
	result = FightResultCard.new()
	result.visible = false
	ui.add_child(result)
	ui.move_child($UI/Version, -1)  # Over the full-screen setup.
	_console = $UI/DebugConsole
	ui.move_child(_console, -1)
	$UI/Version.text = "%s · fight prototype · Godot %s" % [
		ProjectSettings.get_setting("application/config/name"),
		Engine.get_version_info().string,
	]
	show_title()


## The title screen (D302), with Continue pointing at the career saved last.
func show_title() -> void:
	_hide_screens()
	title.save_dir = save_dir
	title.refresh()
	title.visible = true
	state = TITLE
	title.focus_first()


## Quick fight: the fight setup and the Playtest fights, as before careers (D302).
func quick_fight() -> void:
	_hide_screens()
	career = null
	setup.visible = true
	state = SETUP
	setup.focus_start()


## The new-career screen, rolled afresh (`reroll`), or as it was when coming back from his childhood.
func open_new_career(reroll: bool = true) -> void:
	_hide_screens()
	new_career.slot_free = CareerSaves.free_slot(save_dir) >= 0
	if reroll:
		new_career.roll(randi())
	new_career.visible = true
	state = NEW_CAREER
	new_career.focus_start()


## Starts a career from the new-career screen's choices in the first free slot, saves it and opens the hub. First come
## his childhood scenes (D312, with Play his childhood ticked), then your gym and the walk-in (D313), each adding to the
## choices; the whole new career uses one seed.
func start_career(choices: Dictionary) -> void:
	if CareerSaves.free_slot(save_dir) < 0:
		return
	_pending_choices = choices.duplicate(true)
	_pending_seed = randi()
	_next_new_career_step()


func _next_new_career_step() -> void:
	if bool(_pending_choices.get("play_childhood", false)) and not _pending_choices.has("childhood"):
		open_childhood(_pending_choices, _pending_seed)
	elif not _pending_choices.has("gym"):
		open_gym(_pending_choices, _pending_seed)
	else:
		_start_career(_pending_choices, _pending_seed)


## His childhood scenes (D312) for these new-career choices, drawn from the seed the career will start with.
func open_childhood(choices: Dictionary, career_seed: int) -> void:
	_hide_screens()
	_pending_choices = choices
	_pending_seed = career_seed
	childhood.begin(career_seed, choices, _roster)
	childhood.visible = true
	state = CHILDHOOD


func _childhood_done(picks: Array) -> void:
	_pending_choices.childhood = picks
	var kid: Childhood = Childhood.shared()
	var background: String = String(kid.tally(picks).background)
	if background != "":
		_pending_choices.background = background  # What Career.start will make of it, for the gyms and the walk-in.
	_pending_choices.people = kid.people(picks, String(_pending_choices.get("name", "")),
		String(_pending_choices.get("country_id", "")), _pending_seed)
	_next_new_career_step()


## Your gym and the walk-in (D313): three gyms in his hometown, then the morning he walks in.
func open_gym(choices: Dictionary, career_seed: int) -> void:
	_hide_screens()
	_pending_choices = choices
	_pending_seed = career_seed
	gym_screen.begin(choices, career_seed)
	gym_screen.visible = true
	state = GYM


func _gym_done(gym: Dictionary) -> void:
	_pending_choices.gym = gym
	_next_new_career_step()


func _start_career(choices: Dictionary, career_seed: int) -> void:
	var slot: int = CareerSaves.free_slot(save_dir)
	if slot < 0:
		return
	career = Career.start(choices, career_seed, _roster)
	career_slot = slot
	save_career()
	show_hub()


func open_load() -> void:
	_hide_screens()
	load_screen.save_dir = save_dir
	load_screen.refresh()
	load_screen.visible = true
	state = LOAD
	load_screen.focus_first()


## Loads the career in a slot (Continue, or Load on the load screen) and opens the hub. A slot that won't load leaves
## the load screen up.
func load_career(slot: int) -> void:
	var loaded: Career = CareerSaves.load_slot(slot, save_dir)
	if loaded == null:
		open_load()
		return
	career = loaded
	career_slot = slot
	show_hub()


## The career hub (D303). `reports`: what the last Run this week or Advance did.
func show_hub(reports: Array = []) -> void:
	_hide_screens()
	hub.show_career(career, reports)
	hub.visible = true
	state = CAREER
	hub.focus_first()


## Run this week on the hub: a week between fights, then an autosave (docs/03 §10.1).
func run_career_week() -> void:
	if career == null:
		return
	var report: Dictionary = career.run_week()
	save_career()
	show_hub([report])


## Advance on the hub: weeks until something happens (Career.advance, D303), then an autosave.
func advance_career() -> void:
	if career == null:
		return
	var reports: Array[Dictionary] = career.advance()
	save_career()
	show_hub(reports)


## Take the fight on an offer (D304): he's booked, the camp starts, saved.
func accept_offer(offer_id: String) -> void:
	if career != null and career.accept(offer_id):
		save_career()
		show_hub()


func decline_offer(offer_id: String) -> void:
	if career != null:
		career.decline(offer_id)
		save_career()
		show_hub()


func turn_pro() -> void:
	if career != null and career.turn_pro():
		save_career()
		show_hub()


## The booked fight's camp (D304): the planner on the career's own fighter, for the weeks left. Each week run moves the
## calendar on and saves, all but fight week, which ends with the fight.
func open_career_camp() -> void:
	if career == null or career.booked.is_empty():
		return
	_hide_screens()
	planner = CampPlanner.new(career.profile(), career.career_seed + career.week)
	planner.use_career(career)
	planner.week_ran.connect(_career_camp_week)
	planner.fight_pressed.connect(_career_fight)
	planner.sim_pressed.connect(sim_career_fight)
	planner.back_pressed.connect(_career_camp_back)
	$UI.add_child(planner)
	$UI.move_child(_console, -1)
	state = CAREER
	planner.focus_run()


func _career_camp_week(report: Dictionary) -> void:
	if bool(report.get("fight_week", false)):
		career.booked.fight_week_report = report.duplicate(true)  # Fight night waits for the fight, even over a reload.
	else:
		career.end_week()
	save_career()


## Back to the hub from the camp. On fight night with the fight off (pulled out, or the doctor said no), the fight's
## cancelled and the week's over.
func _career_camp_back() -> void:
	if planner != null and planner.done() and not planner.can_fight():
		if career.tournament_stage() > 0:
			career.withdraw()  # Between a tournament's rounds: out, with any medal for the round he'd have fought (D315).
		else:
			career.cancel_fight()
		save_career()
	show_hub()


## Fight! from a career's camp: the booked man, under the booked rules, with a seed from the career's dice, saved first.
func _career_fight(profile: Dictionary) -> void:
	var s: Dictionary = _career_settings(profile)
	save_career()
	start_fight(s)


## Sim the fight (D305): the same fight, played out at once with no sound, straight to the result. The fighters' own AI
## fights it (the AI corner calls nothing for him: the player isn't watching).
func sim_career_fight(profile: Dictionary) -> void:
	var s: Dictionary = _career_settings(profile)
	s.sim = true
	s.sound_volume = 0.0
	save_career()
	start_fight(s)
	while not driver.sim.is_over():
		driver.step()


## In a tournament's later rounds (D315) he goes in as the last fight left him (Career.tournament_condition), not as the
## camp did, and fighting hurt was the first round's worry (its injury roll is done).
func _career_settings(profile: Dictionary) -> Dictionary:
	var opponent: Dictionary = career.booked_opponent()
	_roster.add(opponent)
	var camp: Dictionary = planner.summary() if planner != null else {}
	if career.tournament_stage() > 0:
		profile = career.round_profile()
		camp = {}
	return {
		"career": true,
		"label": "%s vs %s" % [career.fighter_name(), String(opponent.get("name", ""))],
		"red": String(profile.id), "red_profile": profile, "blue": String(opponent.id),
		"ruleset": String(career.booked.get("ruleset", Ruleset.DEFAULT_ID)),
		"seed": career.next_seed(), "normal_rate": 2.0, "auto_slow": true, "flourishes": true, "tell_cues": true,
		"sound_volume": float(setup.settings().get("sound_volume", 1.0)), "easy": false, "rules": [],
		# Tonight's plan from the fight night card; a tournament's later rounds keep the last round's (D320).
		"gameplan": planner.night_card.gameplan.picked() if planner != null else Dictionary(settings.get("gameplan", {})),
		"camp": camp,
	}


## A career fight is over (D304): onto his record (Career.finish_fight), any injury fighting hurt made worse, saved.
## Returns the lines for the result screen.
func _finish_career_fight(sim: FightSim, record: Dictionary, injury: Dictionary) -> Array[String]:
	var ended: Dictionary = record.get("result", {})
	var winner: int = int(ended.get("winner", -1))
	var result: String = "draw"
	if winner == driver.player:
		result = "win"
	elif winner >= 0:
		result = "loss"
	if not injury.is_empty():
		career.trainee.injured_days = int(injury.days_out)
		career.trainee.injury_area = String(injury.area)
	var me: FighterState = sim.fighters[driver.player]
	var condition: Variant = settings.get("red_profile", {}).get("condition", {})
	var tank_in: float = float(condition.get("tank", 1.0)) if condition is Dictionary else 1.0
	var paid: int = career.finish_fight({ "result": result, "method": method_text(String(ended.get("result", ""))),
		"round": sim.clock.current_round, "seed": sim.fight_seed, "simmed": bool(settings.get("sim", false)),
		"hard": Aftermath.is_hard(me.hurt("head"), me.hurt("body"), me.knockdowns),
		"tank": tank_in, "hurt": { "head": me.hurt("head"), "body": me.hurt("body"), "legs": me.hurt("legs") } })
	save_career()
	var lines: Array[String] = []
	if bool(settings.get("sim", false)):
		lines.append("Simmed: the fighters' own AI fought it.")
	lines.append("%s: %s on his %s record, now %s." % [career.fighter_name(), result.to_upper(), "pro" if career.pro else "amateur",
		career.record_text(career.pro)])
	if paid > 0:
		lines.append("Paid $%d. Savings: $%d." % [paid, career.money])
	var through: String = tournament_text(career)
	if through != "":
		lines.append(through)
		return lines  # The suspension comes at the end of his day.
	var medal: String = String(career.fights[-1].get("medal", ""))
	if medal != "":
		lines.append("[color=#ffd43b]%s medal, %s.[/color]" % [medal.capitalize(), String(career.fights[-1].tournament.name)])
	elif career.fights[-1].get("tournament") is Dictionary:
		lines.append("Out of the %s in the %s." % [String(career.fights[-1].tournament.name),
			Tournament.stage_name(int(career.fights[-1].tournament.size), int(career.fights[-1].tournament.stage)).to_lower()])
	lines.append(aftermath_text(career.fights[-1]))
	return lines


## Between a tournament's rounds (D315): who's next and how he goes in. "" when he isn't between rounds.
static func tournament_text(c: Career) -> String:
	if c.tournament_stage() <= 0:
		return ""
	var t: Dictionary = c.booked.tournament
	var carried: Dictionary = c.tournament_condition()
	var hurt: Array[String] = []
	for area: String in carried.get("hurt", {}):
		if float(carried.hurt[area]) >= 0.05:
			hurt.append("%s %d%%" % [area, roundi(float(carried.hurt[area]) * 100.0)])
	return "[color=#69db7c]Through to the %s[/color] against %s, later today. He goes in with %d%% of his gas tank%s." % [
		Tournament.stage_name(int(t.size), int(t.stage)).to_lower(), String(c.booked_opponent().get("name", "")),
		roundi(float(carried.get("tank", 1.0)) * 100.0), (", still hurt: " + ", ".join(hurt)) if not hurt.is_empty() else ""]


## The aftermath line for the result screen: the suspension and why, and any Chin lost.
static func aftermath_text(fight: Dictionary) -> String:
	var days: int = int(fight.get("suspension_days", 0))
	var lost: float = float(fight.get("chin_lost", 0.0))
	var out: String = "Medical suspension: %d days" % days
	var why: String = String(fight.get("suspension_why", ""))
	if why != "":
		out += " (%s)" % why
	out += "."
	if lost > 0.0:
		out += " [color=#ff8787]He loses %s Chin for good.[/color]" % ("%.1f" % lost).trim_suffix(".0")
	return out


## How a fight ended, as his fights list says it: "KO", "TKO", "Submission", "Unanimous decision"…
static func method_text(result: String) -> String:
	if result == FightSim.RESULT_KO or result == FightSim.RESULT_TKO:
		return result.to_upper()
	if result == FightSim.RESULT_SUB:
		return "Submission"
	return result.substr(0, 1).to_upper() + result.substr(1)


## A tournament's next round (D315): the next man, straight away, carrying the last fight (simmed again if the last
## one was).
func next_tournament_fight() -> void:
	if career == null or career.tournament_stage() <= 0:
		return
	result.visible = false
	if bool(settings.get("sim", false)):
		sim_career_fight(career.round_profile())
	else:
		_career_fight(career.round_profile())


## Pulls him out of the tournament between rounds (D315, Career.withdraw): the medal for the round he'd have fought,
## then the hub.
func withdraw_from_tournament() -> void:
	if career != null:
		career.withdraw()
		save_career()
	_career_after_fight()


func _career_after_fight() -> void:
	hud.visible = false
	result.visible = false
	show_hub()


## Saves the career in its slot. Returns false when it couldn't (the hub keeps going; the last save stays).
func save_career() -> bool:
	return career != null and career_slot >= 0 and CareerSaves.save(career, career_slot, save_dir)


func _hub_to_title() -> void:
	save_career()
	show_title()


func _hide_screens() -> void:
	_close_camp()
	for screen: Control in [title, new_career, childhood, gym_screen, load_screen, hub, setup, result, hud]:
		screen.visible = false
	if hud.dialog_open():
		hud.hide_dialog()
	if driver != null:
		driver.held = true
	$UI/Version.visible = true


## Starts a fight with these settings (FightSetup.settings()). With `red_profile` (a fighter@1
## profile, from the camp planner) the red corner is that fighter instead of `red`'s data file.
func start_fight(p_settings: Dictionary) -> void:
	settings = p_settings
	var fight_seed: int = int(settings.get("seed", -1))
	if fight_seed < 0:
		fight_seed = randi()
	var red: String = settings.red
	if settings.get("red_profile") is Dictionary:
		_roster.add(settings.red_profile)
		red = String(settings.red_profile.id)
	var sim := FightSim.new(fight_seed, _roster.make_pair(red, settings.blue), _actions, Ruleset.load_id(String(settings.get("ruleset", Ruleset.DEFAULT_ID))))
	sim.corners[1] = Corner.new(Corner.AI, fight_seed)
	driver = FightDriver.new(sim, 0)
	driver.normal_rate = float(settings.get("normal_rate", 2.0))
	driver.auto_slow = bool(settings.get("auto_slow", true))
	driver.flourishes = bool(settings.get("flourishes", true))
	for entry: Array in settings.get("rules", []):
		if String(entry[1]) != "":
			driver.set_rule(int(entry[0]), String(entry[1]), float(entry[2]))
	var plan: Dictionary = settings.get("gameplan", {})
	if Gameplan.check(plan) == "" and Gameplan.describe(plan) != Gameplan.OWN_GAME:
		driver.set_gameplan(plan)
	var their_plan: Dictionary = StyleLibrary.gameplan_of(sim.fighters[1].profile)
	if not their_plan.is_empty():
		sim.submit(FightCommand.set_gameplan(0, 1, their_plan))  # His corner's plan (D324).
	driver.round_over.connect(_on_round_over)
	driver.fight_over.connect(_on_fight_over)
	arena.tell_cues = bool(settings.get("tell_cues", true))
	arena.watch(driver)
	sounds.volume = float(settings.get("sound_volume", 1.0))
	sounds.watch(sim)
	hud.pause_allowed = bool(settings.get("easy", false))
	hud.allowed_calls = Array(settings.get("calls", []))
	hud.watch(driver)
	hud.visible = true
	$UI/Version.visible = false  # The call bar's second row sits where it is.
	overlay.driver = driver
	_console.watch(sim, "%s, seed %d" % [settings.get("label", ""), fight_seed])
	for screen: Control in [title, new_career, load_screen, hub, setup, result]:
		screen.visible = false  # Whatever started the fight (the tools start one from the title screen).
	_close_camp()
	state = FIGHT
	last_record_path = ""
	if String(settings.get("tip", "")) != "":
		driver.held = true
		hud.show_dialog(String(settings.get("label", "")), String(settings.tip), [["Fight!", _start_after_tip]])
	else:
		hud.show_banner("Round 1")


func _start_after_tip() -> void:
	hud.hide_dialog()
	driver.held = false
	hud.show_banner("Round 1")


func _process(delta: float) -> void:
	if driver != null and state == FIGHT:
		driver.advance(delta)


## The player's corner makes a call (call bar, keys 1–9 and Q/E). Calls go in while paused.
func make_call(id: String) -> void:
	if driver == null or state != FIGHT or not driver.sim.calls.has(id) or not hud.is_allowed(id):
		return
	var why: String = FightHud.call_problem(driver.sim, driver.player, driver.sim.calls.get_call(id))
	if why != "":
		hud.feed.add_line(FightFeed.EXPLANATION, "[color=#8a8f98]Can't call \"%s\" now: %s[/color]" % [driver.sim.calls.get_call(id).name, why])
		return
	driver.make_call(id)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: Key = event.keycode
	if key == KEY_F3:
		overlay.visible = not overlay.visible
		arena.debug_marks = overlay.visible
		get_viewport().set_input_as_handled()
		return
	if key == KEY_ESCAPE and state in [CHILDHOOD, GYM]:
		open_new_career(false)
		get_viewport().set_input_as_handled()
		return
	if key == KEY_ESCAPE and state in [SETUP, NEW_CAREER, LOAD]:
		show_title()
		get_viewport().set_input_as_handled()
		return
	if state != FIGHT or hud.dialog_open():
		if key == KEY_ESCAPE and hud.dialog_title() == "Paused":
			_close_menu()
			get_viewport().set_input_as_handled()
		return
	var handled: bool = true
	match key:
		KEY_SPACE:
			driver.toggle_slow()
		KEY_F:
			driver.toggle_fast()
		KEY_P:
			_on_control("pause")
		KEY_T:
			_on_control("towel")
		KEY_M:
			sounds.muted = not sounds.muted
			hud.feed.add_line(FightFeed.EXPLANATION, "[color=#8a8f98]Sound %s (M)[/color]" % ("off" if sounds.muted else "on"))
		KEY_ESCAPE:
			_open_menu()
		KEY_Q:
			make_call(hud.read_call(0))
		KEY_E:
			make_call(hud.read_call(1))
		KEY_R, KEY_H:
			# Calls on a letter key (Cut the cage! on R, D230; Hand fight! on H, D265).
			handled = false
			var letter: String = OS.get_keycode_string(key)
			for id in driver.sim.calls.ids():
				if driver.sim.calls.get_call(id).get("hotkey") == letter and hud.is_allowed(id):
					make_call(id)
					handled = true
					break
		_:
			handled = false
			if key >= KEY_0 and key <= KEY_9:
				# Calls can share a key when they're for different positions (1: Pressure!
				# standing, Ground and pound! on top, D121): make the one that works from here.
				var on_key: Array[String] = []
				for id in driver.sim.calls.ids():
					var hotkey: Variant = driver.sim.calls.get_call(id).get("hotkey")
					if hotkey != null and not hotkey is String and int(hotkey) == key - KEY_0 and hud.is_allowed(id):
						on_key.append(id)
				for id in on_key:
					if FightHud.call_problem(driver.sim, driver.player, driver.sim.calls.get_call(id)) == "" or id == on_key[-1]:
						make_call(id)
						handled = true
						break
	if handled:
		get_viewport().set_input_as_handled()


func _on_control(which: String) -> void:
	if driver == null or state != FIGHT:
		return
	match which:
		"slow":
			driver.toggle_slow()
		"fast":
			driver.toggle_fast()
		"pause":
			if hud.pause_allowed:
				driver.paused = not driver.paused
		"towel":
			driver.held = true
			hud.show_dialog("Throw in the towel?", "%s loses by TKO. Only do it to save your fighter." % driver.sim.fighters[driver.player].name,
				[["Throw it in", func() -> void: driver.throw_towel()], ["Keep fighting", _close_menu]])


func _open_menu() -> void:
	driver.held = true
	if bool(settings.get("career", false)):
		hud.show_dialog("Paused", "The fight waits for you. (Esc goes back.) A career fight can't be restarted.", [["Resume", _close_menu]])
		return
	hud.show_dialog("Paused", "The fight waits for you. (Esc goes back.)",
		[["Resume", _close_menu], ["Restart fight", func() -> void: start_fight(settings)], ["Change setup", _back_to_setup]])


func _close_menu() -> void:
	hud.hide_dialog()
	if state == FIGHT:
		driver.held = false


func _on_round_over(event: FightEvent) -> void:
	state = ROUND_BREAK
	var sim: FightSim = driver.sim
	_break_rules = RuleSlots.new(sim.fighters[driver.player].profile, _actions)
	_break_rules.show_rules(_current_rules())
	_break_plan = GameplanPicker.new("Gameplan for the next round")
	_break_plan.show_plan(_current_plan())
	var extra := VBoxContainer.new()
	extra.add_child(_break_rules)
	extra.add_child(_break_plan)
	var next: int = event.round_number + 1  # The clock may not have moved on yet when the bell rings.
	hud.show_dialog("End of round %d" % event.round_number, round_summary(sim, event),
		[["Start round %d" % next, _start_next_round]], extra)


## The bell's text: each judge's card for the round, the totals and how both fighters are.
static func round_summary(sim: FightSim, event: FightEvent) -> String:
	var lines: Array[String] = []
	if not event.data.has("cards"):
		lines.append("No round scores under %s: the judges score the whole fight (the effort to finish, then control, then aggression)." % sim.ruleset.name)
		lines.append("So far: %s" % FightHud.judges_estimate(sim).trim_prefix("Judges: "))
	else:
		var cards: Array[String] = []
		for c: Array in event.data.cards:
			cards.append("%d-%d" % [c[0], c[1]])
		lines.append("Judges this round (%s – %s): %s" % [sim.fighters[0].name, sim.fighters[1].name, ", ".join(cards)])
		var totals: Array[String] = []
		for t: Array in sim.judge_totals:
			totals.append("%d-%d" % [t[0], t[1]])
		lines.append("So far: %s" % ", ".join(totals))
	for f in sim.fighters:
		lines.append("%s: stamina %d/%d, landed %d of %d, damage taken head %d · body %d · legs %d" % [f.name,
			roundi(f.stamina), roundi(f.max_stamina()), f.strikes_landed, f.strikes_thrown, f.damage.head, f.damage.body, f.damage.legs])
	lines.append("")
	lines.append("[color=#adb5bd]Change your drilled rules and gameplan for the next round if you like.[/color]")
	return "\n".join(lines)


func _start_next_round() -> void:
	var now: Array = _current_rules()
	for entry: Array in _break_rules.picked():
		var slot: int = int(entry[0]) - 1
		var same: bool = slot < now.size() and now[slot][1] == entry[1] and (entry[1] == "" or is_equal_approx(float(now[slot][2]), float(entry[2])))
		if not same:
			driver.set_rule(int(entry[0]), String(entry[1]), float(entry[2]))
	if _break_plan.picked() != _current_plan():
		driver.set_gameplan(_break_plan.picked())
	hud.hide_dialog()
	state = FIGHT
	driver.resume()
	hud.show_banner("Round %d" % driver.sim.clock.current_round)


## The player's gameplan as it stands: {approach, target, where} ("" = his own game).
func _current_plan() -> Dictionary:
	var plan: Gameplan = driver.sim.decisions[driver.player].gameplan
	var out: Dictionary = {}
	for part: String in Gameplan.PARTS:
		out[part] = "" if plan == null else String(plan.parts.get(part, ""))
	return out


## The player's rules as they stand: [[slot, rule id, drilled 0–100], …].
func _current_rules() -> Array:
	var out: Array = []
	var rules: DrilledRules = driver.sim.decisions[driver.player].rules
	for n in rules.slots.size():
		var entry: Dictionary = rules.slots[n]
		out.append([n + 1, "" if entry.is_empty() else String(entry.rule.id), 80.0 if entry.is_empty() else float(entry.drilled) * 100.0])
	return out


func _on_fight_over(_event: FightEvent) -> void:
	state = OVER
	var sim: FightSim = driver.sim
	var record: Dictionary = FightRecord.build(sim, settings, driver.player)
	if record_dir != "":
		last_record_path = FightRecord.save(record, record_dir)
	var notes: Array[String] = []
	var injury: Dictionary = TrainingCamp.after_fight(settings.get("camp", {}), sim.fight_seed)
	if not injury.is_empty():
		notes.append(("[color=#ff8787]Fighting hurt made the %s injury worse: out %d days.[/color]" if injury.worse
			else "The %s injury held up: %d more days to heal.") % [injury.area, injury.days_out])
	if bool(settings.get("career", false)) and career != null:
		notes.append_array(_finish_career_fight(sim, record, injury))
		hud.hide_dialog()
		if career.tournament_stage() > 0:
			var stage: String = Tournament.stage_name(int(career.booked.tournament.size), career.tournament_stage())
			result.show_result(sim, driver.player, record.stats, notes,
				[["On to the %s" % stage.to_lower(), next_tournament_fight], ["Pull out", withdraw_from_tournament]])
		else:
			result.show_result(sim, driver.player, record.stats, notes, [["Back to the hub", _career_after_fight]])
		return
	notes.append("Seed %d (type it in the setup to replay this fight's start)" % sim.fight_seed)
	if last_record_path != "":
		notes.append("Saved for the playtest notes: %s" % ProjectSettings.globalize_path(last_record_path))
	var buttons: Array = []
	var next: Dictionary = Playtest.next_step(String(settings.get("step", ""))) if settings.get("step", "") != "" else {}
	if not next.is_empty():
		buttons.append(["Next: %s" % next.name, func() -> void: start_fight(Playtest.settings_for(next, settings))])
	buttons.append(["Fight again", func() -> void: start_fight(settings)])
	buttons.append(["Change setup", _back_to_setup])
	if last_record_path != "":
		buttons.append(["Open saved fights", func() -> void: OS.shell_open(ProjectSettings.globalize_path(record_dir))])
	hud.hide_dialog()
	result.show_result(sim, driver.player, record.stats, notes, buttons)


## `-- --self-check`: the self-check fight from the debug console, printed, then quit with
## 0 when it passed (CI runs it on the exported build to prove data/ shipped, #35).
func _self_check() -> void:
	var check: SimCheck = SimCheck.run(1)
	print("Self-check: %d moves, %d fighters, %d calls, %d playtest fights loaded" % [ActionLibrary.load_dir().ids().size(),
		FighterLibrary.load_dir().ids().size(), CallLibrary.load_dir().ids().size(), Playtest.steps().size()])
	for r in check.results:
		print("%s %s (%s)" % ["PASS" if r.passed else "FAIL", r.name, r.detail])
	get_tree().quit(0 if check.passed() and Playtest.steps().size() > 0 else 1)


## Opens the camp planner for these settings' red fighter (from the setup's "Training camp first").
func open_camp(p_settings: Dictionary) -> void:
	settings = p_settings
	_close_camp()
	planner = CampPlanner.new(_roster.profile(settings.red), randi())
	planner.opponent_name = String(_roster.profile(settings.blue).get("name", ""))
	planner.plan_start = settings.get("gameplan", {})
	planner.fight_pressed.connect(_fight_after_camp)
	planner.back_pressed.connect(_back_to_setup)
	$UI.add_child(planner)
	$UI.move_child(_console, -1)
	setup.visible = false
	planner.focus_run()


func _fight_after_camp(profile: Dictionary) -> void:
	var s: Dictionary = settings.duplicate(true)
	s.red_profile = profile
	s.camp = planner.summary()
	s.gameplan = planner.night_card.gameplan.picked()
	s.label = "%s after camp" % settings.get("label", "")
	start_fight(s)


func _close_camp() -> void:
	if planner != null:
		planner.queue_free()
		planner = null


func _back_to_setup() -> void:
	_close_camp()
	hud.hide_dialog()
	hud.visible = false
	result.visible = false
	state = SETUP
	if driver != null:
		driver.held = true
	setup.show_settings(settings)
	setup.visible = true
	$UI/Version.visible = true
	setup.focus_start()
