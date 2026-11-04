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
## The world's history plays this many weeks a frame on the new-career wait (D358).
const HISTORY_SLICE: int = 13
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
## A moment before the bell or walking out of the corners (D390, D391): the fight is held while it plays.
const MOMENT := "moment"

## The verdict over the cage has been read out (or skipped) and the sheet can come up (D436).
signal verdict_read

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
## Tip cards and the Coach's Notebook (D316), over every screen.
var tips: TipCard
## The world pages (D432): his division, the rankings, the promotions and the history, full-screen over the hub.
var world_page: WorldScreen
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
## This fight shows the moments before, between and after the rounds (D390-D394; the setup's "Walk-out and corners"
## option): the bodies and the referee are drawn and it isn't headless (or a test asked, moments_in_headless).
var _moments: bool = false
var moments_in_headless: bool = false
## The fight behind the title screen (D434): not in headless runs unless a test asks (backdrop_in_headless).
var backdrop: TitleBackdrop
var backdrop_in_headless: bool = false
## The fade between screens off the fight (D435): the next screen comes up out of the dark.
var _veil: ColorRect
var _snap: TextureRect
## The verdict read out over the cage before the result's sheet, and the finish again behind it (D436). Headless runs
## (the tests) go straight to the sheet unless a test asks.
var verdict: VerdictBanner
var replay: FinishReplay
var verdict_in_headless: bool = false
## The career fight's "what it means" rows for the result (D436), made as the fight goes onto his record.
var _meaning: Array = []
var _fade: Tween
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
	backdrop = TitleBackdrop.new(_roster, _actions)
	sounds = StrikeSounds.new()
	add_child(sounds)
	sounds.build_in_background()
	# The fence rattles (D287) and a takedown thuds onto the canvas (D288); the title's fight is silent (D434).
	arena.fence_slammed.connect(func(strength: float) -> void:
		if not backdrop.running():
			sounds.play_rattle(strength))
	arena.tell_spotted.connect(_on_tell_spotted)
	arena.takedown_landed.connect(func(strength: float) -> void:
		if not backdrop.running():
			sounds.play_thud(strength))
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
	hub.notebook_pressed.connect(open_notebook)
	hub.division_pressed.connect(open_division)
	hub.promotions_pressed.connect(open_promotions)
	hub.rankings_pressed.connect(open_rankings)
	hub.ask_pressed.connect(ask_step_up)
	hub.history_pressed.connect(open_history)
	ui.add_child(hub)
	result = FightResultCard.new()
	result.visible = false
	ui.add_child(result)
	verdict = VerdictBanner.new()
	verdict.finished.connect(func() -> void: verdict_read.emit())
	ui.add_child(verdict)
	world_page = WorldScreen.new()
	ui.add_child(world_page)
	_veil = ColorRect.new()
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.color = Color(OffCage.HALL, 0.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_veil)  # Over the screens, under the tips and the console: the fade between screens (D435).
	_snap = TextureRect.new()
	_snap.set_anchors_preset(Control.PRESET_FULL_RECT)
	_snap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_snap.stretch_mode = TextureRect.STRETCH_SCALE
	_snap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_snap.visible = false
	ui.add_child(_snap)  # The old screen as it last looked, fading out over the veil.
	tips = TipCard.new()
	ui.add_child(tips)
	for screen: Control in [setup, title, new_career, childhood, gym_screen, load_screen, hub, result, world_page, tips]:
		screen.theme = OffCage.theme()  # One look off the fight (D435): the buttons no screen styled itself.
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
	$UI/Version.visible = true
	state = TITLE
	if DisplayServer.get_name() != "headless" or backdrop_in_headless:
		backdrop.start(arena)  # A real fight behind the menu (D434).
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
	if career.history_pending():
		await _write_history()
	save_career()
	show_hub()


## The world's history (D358; Kyle, 2026-11-02: "A short wait with a progress line"): a new career's world played for
## Career.history_years years before his first week, HISTORY_SLICE weeks a frame, with the year counting up.
func _write_history() -> void:
	_hide_screens()
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.09)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var label := Label.new()
	DisplayFont.apply(label, 34)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
	$UI.add_child(panel)
	var done: float = 0.0
	while done < 1.0:
		done = career.play_history(HISTORY_SLICE)
		var year: int = int(career.date(0, int(done * float(career.week))).year)
		label.text = "WRITING %d YEARS OF HISTORY\n%d" % [Career.history_years, year]
		await get_tree().process_frame
	panel.queue_free()


func open_load() -> void:
	_hide_screens()
	load_screen.save_dir = save_dir
	load_screen.refresh()
	load_screen.visible = true
	$UI/Version.visible = true
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
	var places: Array[String] = ["hub"]
	if not career.offers.is_empty():
		places.append("offers")
	if career.offers.any(func(o: Dictionary) -> bool: return o.get("tournament") is Dictionary):
		places.append("tournament")
	if career.suspended_days > 0:
		places.append("suspended")
	if career.gym_money < 0:
		places.append("gym_behind")
	show_career_tips(places)


## The tips due at these places (Tutorial.due, D316) on a card each, waiting for Got it; marked seen and saved.
func show_career_tips(places: Array) -> void:
	if career == null:
		return
	var due: Array[Dictionary] = []
	for where: Variant in places:
		for t: Dictionary in Tutorial.due(career, String(where)):
			career.see_tip(String(t.id))
			due.append(t)
	if not due.is_empty():
		save_career()
		tips.show_tips(due)


## The Coach's Notebook (D316): every tip he's seen.
func open_notebook() -> void:
	if career != null:
		tips.show_notebook(Tutorial.notebook(career))


## His division (D352): the men in it this week, as a table on the world pages (D432).
func open_division() -> void:
	_open_world(WorldScreen.DIVISION)


## The world's promotions (D354): a card each on the world pages.
func open_promotions() -> void:
	_open_world(WorldScreen.PROMOTIONS)


## The rankings (D355): each promotion's table in his division and its last moves.
func open_rankings() -> void:
	_open_world(WorldScreen.RANKINGS)


## The history page (D358): each belt's champions in his division and the legends.
func open_history() -> void:
	_open_world(WorldScreen.HISTORY)


## The world pages (D432) on this tab, over the hub. A career saved before D352–D355 makes its world, promotions and
## rankings as they're first read, so it's saved after.
func _open_world(tab: String) -> void:
	if career == null:
		return
	world_page.show_world(career, tab)
	$UI.move_child(world_page, -1)
	$UI.move_child(_console, -1)
	save_career()


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


## Ask for a step up (D357): the answer shows on This week, and a yes's tryout with the offers.
func ask_step_up() -> void:
	if career != null and not career.ask_step_up().is_empty():
		save_career()
		show_hub()


func turn_pro() -> void:
	if career != null and career.turn_pro(hub.pro_division()):
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
	# The gameplan opens with his third fight (D316).
	planner.night_card.gameplan.visible = Tutorial.plan_open(Tutorial.lesson(career))
	planner.theme = OffCage.theme()
	$UI.add_child(planner)
	_veil_on_top()  # The camp fades up too (D435).
	$UI.move_child(_console, -1)
	$UI.move_child(tips, -1)
	state = CAREER
	planner.focus_run()
	show_career_tips(["fight_night"] if planner.done() else ["camp", "mitt_work"])


func _career_camp_week(report: Dictionary) -> void:
	career.scout_week(report)  # Film study on the man he's fighting (D401).
	career.drill_week(report)  # The Drill rule sessions sharpen his two rules (D402).
	if bool(report.get("fight_week", false)):
		career.booked.fight_week_report = report.duplicate(true)  # Fight night waits for the fight, even over a reload.
		save_career()
		show_career_tips(["fight_night"])
		return
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
	var s: Dictionary = _career_settings(profile, true)
	s.sim = true
	s.sound_volume = 0.0
	save_career()
	start_fight(s)
	while not driver.sim.is_over():
		driver.step()


## In a tournament's later rounds (D315) he goes in as the last fight left him (Career.tournament_condition), not as the
## camp did, and fighting hurt was the first round's worry (its injury roll is done).
## The tutorial (D316): a lesson fight opens only its calls, the tell cue from lesson 2, rules and the gameplan from
## lesson 3, and starts on its tip card (not when simmed: nobody's watching).
func _career_settings(profile: Dictionary, simmed: bool = false) -> Dictionary:
	var opponent: Dictionary = career.booked_opponent().duplicate(true)
	# His own camp (D404): the plan his corner rolled, a rule against your favourite move, and how fresh he is.
	var their_camp: Dictionary = OpponentCamp.of(career)
	if float(their_camp.get("tank", 1.0)) < 1.0:
		opponent.condition = { "tank": float(their_camp.tank) }
	var camp: Dictionary = planner.summary() if planner != null else {}
	if career.tournament_stage() > 0:
		profile = career.round_profile()
		camp = {}
	# The weigh-in (D405): what each man's cut cost him, and the bigger man's Strength on the night.
	var weighed: Dictionary = WeightCut.of(career)
	if not weighed.is_empty():
		profile = profile.duplicate(true)
		WeightCut.apply(profile, weighed.him, float(weighed.edge))
		WeightCut.apply(opponent, weighed.opp, float(weighed.opp_edge))
	_roster.add(opponent)
	var s: Dictionary = {
		"career": true,
		"label": "%s vs %s" % [career.fighter_name(), String(opponent.get("name", ""))],
		"red": String(profile.id), "red_profile": profile, "blue": String(opponent.id),
		"ruleset": String(career.booked.get("ruleset", Ruleset.DEFAULT_ID)),
		"title": String(career.booked.get("title", "")) != "",
		"seed": career.next_seed(), "normal_rate": 2.0, "auto_slow": true, "flourishes": true, "tell_cues": true,
		"sound_volume": float(setup.settings().get("sound_volume", 1.0)), "easy": false,
		"rules": RuleDrilling.fight_rules(career),  # His two rules, as well drilled as camp left them (D402).
		"moments": bool(setup.settings().get("moments", true)),  # The setup's "Walk-out and corners" (D394).
		# Only his habits you've found get the tell cue (D401); one seen going off often enough in the fight joins them.
		"known_tells": Scouting.found(career, String(opponent.id)),
		# Tonight's plan from the fight night card; a tournament's later rounds keep the last round's (D320).
		"gameplan": planner.night_card.gameplan.picked() if planner != null else Dictionary(settings.get("gameplan", {})),
		"camp": camp,
		"their_camp": their_camp,
		"weigh_in": WeightCut.record(weighed),
	}
	var lesson: int = Tutorial.lesson(career)
	if lesson > 0:
		s.lesson = lesson
		s.calls = Tutorial.calls(lesson)
		s.tell_cues = Tutorial.tell_cue(lesson)
		if not Tutorial.plan_open(lesson):
			s.gameplan = {}
			s.rules = []
	if not simmed:
		for t: Dictionary in Tutorial.due(career, "fight"):
			career.see_tip(String(t.id))
			s.tip = String(t.text)
			s.tip_title = String(t.title)
	return s


## A career fight is over (D304): onto his record (Career.finish_fight), any injury fighting hurt made worse, saved.
## Returns the lines for the result screen.
## Habits of his the player saw going off often enough to find them (D401) are found for good: a line each for the
## result. Not in a simmed fight (nobody was watching).
func _spotted_notes(sim: FightSim) -> Array[String]:
	var out: Array[String] = []
	if arena.tell_watch == null or bool(settings.get("sim", false)) or arena.tell_watch.spotted.is_empty():
		return out
	Scouting.learn(career, String(career.booked.get("opponent", "")), arena.tell_watch.spotted)
	for t: Dictionary in sim.fighters[1 - driver.player].tells:
		if arena.tell_watch.spotted.has(Scouting.key(t)):
			out.append("[color=#ffe066]You found a habit of his:[/color] %s." % Scouting.tell_text(t))
	return out


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
		career.trainee.injury = String(injury.get("injury", ""))
	var me: FighterState = sim.fighters[driver.player]
	var condition: Variant = settings.get("red_profile", {}).get("condition", {})
	var tank_in: float = float(condition.get("tank", 1.0)) if condition is Dictionary else 1.0
	var before: Dictionary = career.standing()
	career.finish_fight({ "result": result, "method": method_text(String(ended.get("result", ""))),
		"round": sim.clock.current_round, "seed": sim.fight_seed, "simmed": bool(settings.get("sim", false)),
		"hard": Aftermath.is_hard(me.hurt("head"), me.hurt("body"), me.knockdowns),
		"tank": tank_in, "hurt": { "head": me.hurt("head"), "body": me.hurt("body"), "legs": me.hurt("legs") },
		"moves": OpponentCamp.moves_of(sim, driver.player),  # What he threw, for the next man's camp (D404).
		"punches": Injuries.punches_landed(sim, driver.player) })  # For his hand (D406).
	save_career()
	var lines: Array[String] = []
	if bool(settings.get("sim", false)):
		lines.append("Simmed: the fighters' own AI fought it.")
	if int(career.fights[-1].get("fine", 0)) > 0:
		lines.append("[color=#ff8787]He missed weight: $%d of his purse went to the other man.[/color]" % int(career.fights[-1].fine))
	elif int(career.fights[-1].get("fine_got", 0)) > 0:
		lines.append("[color=#69db7c]The other man missed weight: $%d of his purse came to you.[/color]" % int(career.fights[-1].fine_got))
	if career.fights[-1].get("injury") is Dictionary:
		lines.append("[color=#ff8787]%s[/color]" % Injuries.fight_text(career.fights[-1].injury))
	# What it did to his career goes on its own panel (D436): record, rank, belt, promotion, purse, suspension.
	var through: String = tournament_text(career)
	_meaning = FightResultCard.meaning_rows(before, career.standing(), career.fights[-1],
		"" if through != "" else aftermath_text(career.fights[-1]))
	if through != "":
		lines.append(through)
		return lines  # The suspension comes at the end of his day.
	var medal: String = String(career.fights[-1].get("medal", ""))
	if medal != "":
		lines.append("[color=#ffd43b]%s medal, %s.[/color]" % [medal.capitalize(), String(career.fights[-1].tournament.name)])
	elif career.fights[-1].get("tournament") is Dictionary:
		lines.append("Out of the %s in the %s." % [String(career.fights[-1].tournament.name),
			Tournament.stage_name(int(career.fights[-1].tournament.size), int(career.fights[-1].tournament.stage)).to_lower()])
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
	for screen: Control in [title, new_career, childhood, gym_screen, load_screen, hub, world_page, setup, result, hud]:
		screen.visible = false
	if hud.dialog_open():
		hud.hide_dialog()
	if driver != null:
		driver.held = true
	backdrop.stop(arena)
	_stop_replay()
	arena.watch(null)  # The empty hall behind the screens off the fight, the camera drifting round it (D435).
	arena.hall_drift = true
	_fade_up()
	$UI/Version.visible = false  # Only the title and load screens show it: elsewhere it sat on buttons (D431).


## The change of screen (D435, Kyle's pick "A quick fade"): the old screen fades out into the dark over
## OffCage.FADE_SECONDS (a picture of its last frame, so the game has already moved on underneath) and the new one
## comes up out of it over the same again. With no picture to take (headless) only the second half runs.
func _fade_up() -> void:
	if _veil == null:
		return
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_snap.visible = false
	_veil.color = Color(OffCage.HALL, 1.0)
	_fade = create_tween()
	if DisplayServer.get_name() != "headless":
		var shot: Image = get_viewport().get_texture().get_image()
		if shot != null and not shot.is_empty():
			_snap.texture = ImageTexture.create_from_image(shot)
			_snap.modulate.a = 1.0
			_snap.visible = true
			_fade.tween_property(_snap, "modulate:a", 0.0, OffCage.FADE_SECONDS)
			_fade.tween_callback(func() -> void: _snap.visible = false)
	_fade.tween_property(_veil, "color:a", 0.0, OffCage.FADE_SECONDS)


## Keeps the fade over a screen added after the others (the camp).
func _veil_on_top() -> void:
	$UI.move_child(_veil, -1)
	$UI.move_child(_snap, -1)


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
	var rules: Ruleset = Ruleset.load_id(String(settings.get("ruleset", Ruleset.DEFAULT_ID)))
	if bool(settings.get("title", false)):
		rules.rounds = rules.title_rounds  # A title fight (D356): 5 rounds.
	var sim := FightSim.new(fight_seed, _roster.make_pair(red, settings.blue), _actions, rules)
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
	var their_camp: Dictionary = settings.get("their_camp", {}) if settings.get("their_camp") is Dictionary else {}
	var their_plan: Dictionary = StyleLibrary.gameplan_of(sim.fighters[1].profile)
	if their_camp.get("plan") is Dictionary and not (their_camp.plan as Dictionary).is_empty():
		their_plan = their_camp.plan  # The plan his corner rolled for this fight (D404).
	if not their_plan.is_empty():
		sim.submit(FightCommand.set_gameplan(0, 1, their_plan))  # His corner's plan (D324).
	if String(their_camp.get("rule", "")) != "":
		sim.submit(FightCommand.set_rule(0, 1, 1, String(their_camp.rule), float(their_camp.drilled)))  # His rule against you (D404).
	driver.round_over.connect(_on_round_over)
	driver.fight_over.connect(_on_fight_over)
	backdrop.stop(arena)  # The title's fight gives the cage up (D434; the tools start a fight from the title).
	_stop_replay()
	arena.tell_cues = bool(settings.get("tell_cues", true))
	arena.tell_watch = Scouting.Watch.new(settings.known_tells) if settings.get("known_tells") is Array else null
	arena.watch(driver)
	arena.hud_names_holds = true  # The danger meter names the hold (D466).
	_moments = bool(settings.get("moments", false)) and arena.can_play_moments() \
		and (DisplayServer.get_name() != "headless" or moments_in_headless)
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
		hud.show_dialog(String(settings.get("tip_title", settings.get("label", ""))), String(settings.tip), [["Fight!", _start_after_tip]])
	else:
		_first_bell()


func _start_after_tip() -> void:
	hud.hide_dialog()
	_first_bell()


## The first round starts: after the referee has called them to the centre to touch gloves (D390), if it's shown.
func _first_bell() -> void:
	if _moments:
		state = MOMENT
		driver.held = true
		var sim: FightSim = driver.sim
		arena.play_moment(Ceremony.INTRO)
		await arena.ceremony.moment_done
		if driver == null or driver.sim != sim or state != MOMENT:
			return
		state = FIGHT
	driver.held = false
	hud.show_banner("Round 1")


func _process(delta: float) -> void:
	if driver != null and state == FIGHT:
		driver.advance(delta)
	elif state == TITLE and backdrop.running():
		backdrop.advance(arena, delta)
	elif replay != null and replay.running():
		var was: FightDriver = replay.driver
		replay.advance(arena, delta)
		if replay.driver != was:
			sounds.watch(replay.driver.sim)  # Each time it plays again, its own sounds.


## True when `event` is a key or click that skips the moment playing (D394; not F3, the debug overlay).
func _skips_moment(event: InputEvent) -> bool:
	if driver == null or not arena.moment_playing():
		return false
	if event is InputEventKey:
		return event.pressed and not event.echo and (event as InputEventKey).keycode != KEY_F3
	return event is InputEventMouseButton and event.pressed


## The player's corner makes a call (call bar, keys 1–9 and Q/E). Calls go in while paused.
func make_call(id: String) -> void:
	if driver == null or state != FIGHT or not driver.sim.calls.has(id) or not hud.is_allowed(id):
		return
	var why: String = FightHud.call_problem(driver.sim, driver.player, driver.sim.calls.get_call(id))
	if why != "":
		hud.feed.add_line(FightFeed.NOTE, "[color=#8a8f98]Can't call \"%s\" now: %s[/color]" % [driver.sim.calls.get_call(id).name, why])
		return
	driver.make_call(id)


func _unhandled_input(event: InputEvent) -> void:
	if _skips_moment(event):
		arena.skip_moment()  # Any key or click skips a moment (D394).
		get_viewport().set_input_as_handled()
		return
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
			hud.feed.add_line(FightFeed.NOTE, "[color=#8a8f98]Sound %s (M)[/color]" % ("off" if sounds.muted else "on"))
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
	var next: int = event.round_number + 1  # The clock may not have moved on yet when the bell rings.
	# The break's side panel (D465): the round's card (the judges' chips, the two men as bars), then the pickers.
	var extra := VBoxContainer.new()
	extra.add_theme_constant_override("separation", 14)
	var card := RoundBreakCard.new()
	card.show_round(sim, event)
	extra.add_child(card)
	_break_rules = null
	_break_plan = null
	if Tutorial.plan_open(int(settings.get("lesson", 0))):
		extra.add_child(FightHud._heading("NEXT ROUND"))
		_break_rules = RuleSlots.new(sim.fighters[driver.player].profile, _actions)
		if bool(settings.get("career", false)) and career != null:
			_break_rules.use_drilled(_career_drilled())  # Only as sharp as camp left them (D402).
		_break_rules.show_rules(_current_rules())
		_break_plan = GameplanPicker.new("Gameplan")
		_break_plan.show_plan(_current_plan())
		extra.add_child(_break_plan)
		extra.add_child(_break_rules)
	# Before his third fight the break is just the cards (D316): rules and the gameplan open with lesson 3.
	var lines: Array[String] = corner_habit_lines(sim, arena.tell_watch if bool(settings.get("career", false)) else null)
	if bool(settings.get("career", false)) and career != null:
		for t: Dictionary in Tutorial.due(career, "round_break"):
			career.see_tip(String(t.id))
			lines.push_front("[color=#fcc419][b]Coach's tip: %s.[/b][/color] %s" % [String(t.title), String(t.text)])
	if _moments:
		arena.play_moment(Ceremony.CORNERS)  # To their stools (D391).
	hud.show_dialog("End of round %d" % event.round_number, "\n\n".join(lines),
		[["Start round %d" % next, _start_next_round]], extra, true)


## What your corner says on the stool about the opponent's habits (D419, Kyle 2026-11-02: "in the fight coaches should
## mention in the corner the tell that was picked up"): each habit of his you've found, in camp or in this fight, and how
## often he's done it so far. Empty outside a career (no scouting: every tell is cued anyway) or with nothing found.
static func corner_habit_lines(sim: FightSim, watch: Scouting.Watch) -> Array[String]:
	var out: Array[String] = []
	if watch == null:
		return out
	for tell: Dictionary in sim.fighters[1].tells:
		if not watch.cues(tell):
			continue
		var times: int = watch.fires(Scouting.key(tell))
		var so_far: String = "He hasn't shown it yet, but be ready." if times == 0 else ("He's done it once so far: make him pay."
			if times == 1 else "He's done it %d times so far: make him pay." % times)
		out.append("[color=#ffe066][b]Your corner:[/b][/color] %s. %s" % [Scouting.tell_text(tell).get_slice(" (", 0), so_far])
	return out


func _start_next_round() -> void:
	var now: Array = _current_rules()
	for entry: Array in (_break_rules.picked() if _break_rules != null else []):
		var slot: int = int(entry[0]) - 1
		var same: bool = slot < now.size() and now[slot][1] == entry[1] and (entry[1] == "" or is_equal_approx(float(now[slot][2]), float(entry[2])))
		if not same:
			driver.set_rule(int(entry[0]), String(entry[1]), float(entry[2]))
	if _break_plan != null and _break_plan.picked() != _current_plan():
		driver.set_gameplan(_break_plan.picked())
	hud.hide_dialog()
	if _moments:
		state = MOMENT
		var sim: FightSim = driver.sim
		arena.play_moment(Ceremony.OUT)  # Off the stools and out to their marks (D391).
		await arena.ceremony.moment_done
		if driver == null or driver.sim != sim or state != MOMENT:
			return
	state = FIGHT
	driver.resume()
	hud.show_banner("Round %d" % driver.sim.clock.current_round)


## A habit of his seen going off often enough to find it (D401): the feed says so, and it's cued from now on.
func _on_tell_spotted(tell: Dictionary) -> void:
	hud.feed.add_line(FightFeed.KEY_MOMENT, "[color=#ffe066][b]You've got his habit:[/b] %s.[/color]" % Scouting.tell_text(tell).to_lower())


## The player's gameplan as it stands: {approach, target, where} ("" = his own game).
func _current_plan() -> Dictionary:
	var plan: Gameplan = driver.sim.decisions[driver.player].gameplan
	var out: Dictionary = {}
	for part: String in Gameplan.PARTS:
		out[part] = "" if plan == null else String(plan.parts.get(part, ""))
	return out


## A career's drilled rules: rule id → drilled 0–100 (D402).
func _career_drilled() -> Dictionary:
	var out: Dictionary = {}
	for id: String in career.drills:
		out[id] = snappedf(RuleDrilling.drilled(career, id), 0.1)
	return out


## The player's rules as they stand: [[slot, rule id, drilled 0–100], …].
func _current_rules() -> Array:
	var out: Array = []
	var rules: DrilledRules = driver.sim.decisions[driver.player].rules
	for n in rules.slots.size():
		var entry: Dictionary = rules.slots[n]
		out.append([n + 1, "" if entry.is_empty() else String(entry.rule.id), 80.0 if entry.is_empty() else float(entry.drilled) * 100.0])
	return out


func _on_fight_over(event: FightEvent) -> void:
	state = OVER
	var sim: FightSim = driver.sim
	if arena.holds_finish(event.data) and DisplayServer.get_name() != "headless":
		await arena.finish_shown  # The finish held on the cage first (D374: the referee waves it off; D366 the tap).
		if driver == null or driver.sim != sim:
			return
	if _moments:
		# The winner celebrates after a finish, then the referee raises his hand (D392, D393).
		arena.play_moment(Ceremony.VERDICT, {"winner": int(event.data.get("winner", -1)),
			"finished": ArenaView.FINISHES.has(String(event.data.get("result", "")))})
		await arena.ceremony.moment_done
		if driver == null or driver.sim != sim:
			return
	if (DisplayServer.get_name() != "headless" or verdict_in_headless) and not bool(settings.get("sim", false)):
		_read_the_verdict(sim)  # Not a simmed fight: that goes straight to the result (D305).
		await verdict_read
		if driver == null or driver.sim != sim:
			return
	var record: Dictionary = FightRecord.build(sim, settings, driver.player)
	if record_dir != "":
		last_record_path = FightRecord.save(record, record_dir)
	var notes: Array[String] = []
	var injury: Dictionary = TrainingCamp.after_fight(settings.get("camp", {}), sim.fight_seed)
	if not injury.is_empty():
		notes.append(("[color=#ff8787]Fighting hurt made the %s injury worse: out %d days.[/color]" if injury.worse
			else "The %s injury held up: %d more days to heal.") % [injury.area, injury.days_out])
	if bool(settings.get("career", false)) and career != null:
		notes.append_array(_spotted_notes(sim))
		notes.append_array(_finish_career_fight(sim, record, injury))
		hud.hide_dialog()
		if career.tournament_stage() > 0:
			var stage: String = Tournament.stage_name(int(career.booked.tournament.size), career.tournament_stage())
			result.show_result(sim, driver.player, record.stats, notes,
				[["On to the %s" % stage.to_lower(), next_tournament_fight], ["Pull out", withdraw_from_tournament]])
		else:
			result.show_result(sim, driver.player, record.stats, notes, [["Back to the hub", _career_after_fight]])
		result.show_meaning(_meaning)
		if not career.fights.is_empty() and String(career.fights[-1].get("result", "")) == "loss":
			show_career_tips(["loss"])  # His first loss, while he's learning (D316).
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


## The verdict over the cage (D436): the HUD away, a finish playing again slowly behind it, the lines read out.
func _read_the_verdict(sim: FightSim) -> void:
	hud.visible = false
	_stop_replay()
	arena.backdrop = true  # No range tag or move names showing through the band.
	if FinishReplay.wanted(sim):
		var ids: Array[String] = [sim.fighters[0].id, sim.fighters[1].id]
		replay = FinishReplay.new(sim, func() -> Array[FighterState]: return _roster.make_pair(ids[0], ids[1]), _actions, driver.player)
		replay.start(arena)
		sounds.watch(replay.driver.sim)
	verdict.begin(sim, replay != null)


func _stop_replay() -> void:
	if replay != null:
		replay.stop(arena)
		replay = null
	if arena != null:
		arena.backdrop = false
	if verdict != null:
		verdict.visible = false


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
	planner.theme = OffCage.theme()
	$UI.add_child(planner)
	_veil_on_top()  # The camp fades up too (D435).
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
	setup.focus_start()
