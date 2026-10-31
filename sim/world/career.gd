class_name Career
extends RefCounted
## One fighter's career (docs/03 §10.1, D301): who he is and who coaches him, the date, his fights, how he is between
## fights, his money, the fight he's booked for and the men he's met. One Career is one save file (CareerSaves in
## game/career_saves.gd writes it; the format is docs/09 career@1).
##
## Pure logic and seeded like the rest of sim/ (D100): the same seed and the same choices always play out the same,
## and a career saved and loaded carries on exactly as if it had never stopped, because its dice are saved with it.
## The career's dice are apart from each fight's (A11): a fight takes its seed from next_seed() and replays from that.
##
## His stats, style, fatigue, injuries and age live in `trainee`, the TrainingCamp he trains in for his whole career:
## weeks between fights go through run_week(), and a camp's weeks go through the planner on the same trainee.
##
## Usage: Career.create(profile, seed, { "coach": "Sam", "nickname": "The Hammer" }), then run_week() each week,
## add_fight() after each fight, and to_dict() / Career.from_dict() to save and load.

const SCHEMA := "career"
## The save format's version. A change to what to_dict() writes raises it and adds a step to migrate().
const VERSION: int = 1
## The fighter's id in fights and saved fight records.
const FIGHTER_ID := "career_fighter"
## A new career's week 0 starts on this Monday: [year, month, day].
const START_DATE: Array[int] = [2027, 1, 4]
## The week plan for weeks between fights until the player picks another (data/week_plans, docs/02 §3.8).
const BETWEEN_PLAN := "between_fights"
const DAYS_PER_WEEK: int = 7
const WEEKDAYS: Array[String] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
const MONTHS: Array[String] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
## What a fight can end as for him, as add_fight() takes it.
const RESULTS: Array[String] = ["win", "loss", "draw", "no_contest"]
## What `about` holds besides the fighter file: shown on screens, not used by fights.
const ABOUT_KEYS: Array[String] = ["nickname", "hometown", "country", "background"]
## Advance (docs/03 §10.3, D303) runs weeks until something happens, or this many at most.
const ADVANCE_MAX_WEEKS: int = 8
## How many weeks the hub's calendar shows, this one first.
const CALENDAR_WEEKS: int = 8
## What can happen in a week (events[].kind in run_week()'s report and calendar()'s weeks).
const HURT := "hurt"
const HEALED := "healed"
const CLEARED := "cleared"
const BIRTHDAY := "birthday"
const FIGHT_NIGHT := "fight_night"
## How many weeks a year has for a birthday: TrainingCamp ages him 1/52 of a year a week (docs/02 §3.8).
const WEEKS_PER_YEAR: float = 52.0

## Why the last from_dict() or migrate() failed ("" when it didn't).
static var load_error: String = ""

var career_seed: int = 0
## The head coach: the player (D15).
var coach_name: String = ""
## The fighter@1 profile he started with: name, frame, stance, personality, gifts, flaws and moves. What changes
## with training (stats, style, age, condition) is in `trainee`; profile() puts the two together.
var fighter: Dictionary = {}
## nickname, hometown, country, background (ABOUT_KEYS).
var about: Dictionary = {}
var trainee: TrainingCamp
## The day (days since 1 Jan 1970) of the Monday that starts week 0, and the week it is now.
var first_monday: int = 0
var week: int = 0
## Days until a medical suspension lets him fight again (0 = none).
var suspended_days: int = 0
var money: int = 0
## Turned pro: his fights count on the pro record from then on.
var pro: bool = false
## Every fight he's had, oldest first (add_fight()).
var fights: Array = []
## Everyone he's fought or is booked to fight: id → fighter@1 profile, so a rematch is the same man.
var opponents: Dictionary = {}
## The next fight ({} when none) and the offers on the table. Their contents come with fight offers (D304).
var booked: Dictionary = {}
var offers: Array = []
## The week plan run between fights: a data/week_plans id.
var week_plan: String = BETWEEN_PLAN

var _dice := RandomNumberGenerator.new()
var _library: TrainingLibrary


## A new career for this fighter (a fighter@1 profile) on week 0. `extra` may give `coach` (the player's name) and
## ABOUT_KEYS.
static func create(profile_in: Dictionary, new_seed: int, extra: Dictionary = {}, library: TrainingLibrary = null) -> Career:
	var c := Career.new()
	c._library = library if library != null else TrainingLibrary.shared()
	c.career_seed = new_seed
	c._dice.seed = new_seed
	c.fighter = profile_in.duplicate(true)
	c.fighter.id = FIGHTER_ID
	c.fighter.erase("condition")
	c.coach_name = String(extra.get("coach", ""))
	for key in ABOUT_KEYS:
		c.about[key] = String(extra.get(key, ""))
	c.first_monday = days_from_civil(START_DATE[0], START_DATE[1], START_DATE[2])
	c.trainee = TrainingCamp.new(c.fighter, c._dice.randi(), c._library)
	return c


## A new career from the new-career screen (docs/03 §10.2, D302): a 16-year-old made from his background
## (BackgroundLibrary.make_fighter) and the player's `choices`: coach, name, nickname, hometown, country, background (an
## id in data/backgrounds) and stance. He starts with his background's money.
static func start(choices: Dictionary, new_seed: int, roster: FighterLibrary, backgrounds: BackgroundLibrary = null, library: TrainingLibrary = null) -> Career:
	var bgs: BackgroundLibrary = backgrounds if backgrounds != null else BackgroundLibrary.shared()
	var background: String = String(choices.background)
	var profile_in: Dictionary = bgs.make_fighter(background, new_seed, roster, choices)
	var c: Career = create(profile_in, new_seed, choices, library)
	c.money = int(bgs.get_background(background).get("money", 0))
	return c


## The fighter@1 profile as he is now, for a fight or the planner (fights read his stats to the nearest point).
func profile() -> Dictionary:
	var out: Dictionary = trainee.profile()
	out.id = FIGHTER_ID
	return out


func fighter_name() -> String:
	return String(fighter.get("name", ""))


## His age in whole years.
func age() -> int:
	return trainee.age


## A week between fights on `plan` (a data/week_plans id or a week_plan@1 Dictionary; the career's `week_plan` when
## left out): he trains, rests, heals and gets a week older, and a suspension runs down. `played` is the minigame
## scores, as TrainingCamp.run_plan takes them. Returns run_plan's report of the week.
func run_week(plan: Variant = null, played: Dictionary = {}) -> Dictionary:
	var plan_data: Dictionary
	if plan is Dictionary:
		plan_data = plan
	else:
		plan_data = _library.plan(week_plan if plan == null else String(plan))
	var before := { "injured_days": trainee.injured_days, "suspended_days": suspended_days, "age": age() }
	var report: Dictionary = trainee.run_plan(plan_data, played)
	end_week()
	report.week = week - 1
	report.events = _events_since(before)
	return report


## Weeks on the career's week plan until something happens (docs/03 §10.3, D303): he's hurt, he's healed, his
## suspension ends, a birthday, an offer comes in (D304), or ADVANCE_MAX_WEEKS go by. Nothing runs while he's booked
## for a fight: the camp runs that (D304). Returns each week's report, oldest first.
func advance(max_weeks: int = ADVANCE_MAX_WEEKS) -> Array[Dictionary]:
	var reports: Array[Dictionary] = []
	if not booked.is_empty():
		return reports
	for i in max_weeks:
		var report: Dictionary = run_week()
		reports.append(report)
		if not (report.events as Array).is_empty() or not offers.is_empty():
			break
	return reports


## The calendar from this week on (docs/03 §10.3, D303): `weeks` weeks, each { week, date ("Mon 11 Jan"), events },
## with what will happen during it if nothing changes: the injury healed, the suspension over, a birthday, fight night.
func calendar(weeks: int = CALENDAR_WEEKS) -> Array[Dictionary]:
	var ahead: Dictionary = {}  # weeks from now → events
	if trainee.injured_days > 0:
		_add_ahead(ahead, ceili(trainee.injured_days / float(DAYS_PER_WEEK)) - 1, { "kind": HEALED, "area": trainee.injury_area })
	if suspended_days > 0:
		_add_ahead(ahead, ceili(suspended_days / float(DAYS_PER_WEEK)) - 1, { "kind": CLEARED })
	var to_birthday: int = ceili((age() + 1 - trainee.age_years) * WEEKS_PER_YEAR - 0.001) - 1
	_add_ahead(ahead, to_birthday, { "kind": BIRTHDAY, "age": age() + 1 })
	if not booked.is_empty() and booked.has("week"):
		_add_ahead(ahead, int(booked.week) - week, { "kind": FIGHT_NIGHT, "opponent": String(booked.get("opponent", "")) })
	var out: Array[Dictionary] = []
	for i in weeks:
		out.append({ "week": week + i, "date": short_date(week + i), "events": ahead.get(i, []) })
	return out


static func _add_ahead(ahead: Dictionary, weeks_from_now: int, event: Dictionary) -> void:
	if weeks_from_now < 0:
		return
	if not ahead.has(weeks_from_now):
		ahead[weeks_from_now] = []
	ahead[weeks_from_now].append(event)


## What changed this week, against how things were before it.
func _events_since(before: Dictionary) -> Array:
	var out: Array = []
	if int(before.injured_days) == 0 and trainee.injured_days > 0:
		out.append({ "kind": HURT, "area": trainee.injury_area, "days": trainee.injured_days })
	elif int(before.injured_days) > 0 and trainee.injured_days == 0:
		out.append({ "kind": HEALED })
	if int(before.suspended_days) > 0 and suspended_days == 0:
		out.append({ "kind": CLEARED })
	if age() > int(before.age):
		out.append({ "kind": BIRTHDAY, "age": age() })
	if not booked.is_empty() and int(booked.get("week", -1)) == week:
		out.append({ "kind": FIGHT_NIGHT, "opponent": String(booked.get("opponent", "")) })
	return out


## What an event says, for the hub: "Healed", "Turned 17" …
static func event_text(event: Dictionary) -> String:
	match String(event.kind):
		HURT:
			return "Hurt in training (%s, %d days)" % [event.get("area", ""), int(event.get("days", 0))]
		HEALED:
			return "Healed"
		CLEARED:
			return "Cleared to fight"
		BIRTHDAY:
			return "Turns %d" % int(event.get("age", 0))
		FIGHT_NIGHT:
			return "Fight night"
	return String(event.kind)


## Moves the calendar on to next Monday. run_week() calls it; a camp week run on `trainee` by the planner calls it too.
func end_week() -> void:
	week += 1
	suspended_days = maxi(0, suspended_days - DAYS_PER_WEEK)


## Dice for something outside the career's own dice, such as a fight: the same career always hands out the same seeds.
func next_seed() -> int:
	return _dice.randi()


## The date of a day this week (0 = Monday … 6 = Sunday), or of week `of_week`: { year, month, day, weekday }.
func date(day_of_week: int = 0, of_week: int = -1) -> Dictionary:
	var w: int = week if of_week < 0 else of_week
	var ymd: Array[int] = civil_from_days(first_monday + w * DAYS_PER_WEEK + day_of_week)
	return { "year": ymd[0], "month": ymd[1], "day": ymd[2], "weekday": WEEKDAYS[day_of_week] }


## "Mon 4 Jan 2027" (this week, or week `of_week`).
func date_text(day_of_week: int = 0, of_week: int = -1) -> String:
	var d: Dictionary = date(day_of_week, of_week)
	return "%s %d %s %d" % [d.weekday, d.day, MONTHS[d.month - 1], d.year]


## "Mon 11 Jan": a week's Monday without the year, for the calendar.
func short_date(of_week: int, day_of_week: int = 0) -> String:
	var d: Dictionary = date(day_of_week, of_week)
	return "%s %d %s" % [d.weekday, d.day, MONTHS[d.month - 1]]


## Someone he's fought or is booked to fight (a fighter@1 profile with its own id).
func add_opponent(profile_in: Dictionary) -> void:
	opponents[String(profile_in.id)] = profile_in.duplicate(true)


## A finished fight, onto his record. `entry` needs `result` (one of RESULTS) and `opponent` (an id in `opponents`);
## everything else is kept as given (docs/09 career@1: method, round, time, ruleset, purse). It's dated this week,
## and counts as pro if he's pro now unless `entry` says.
func add_fight(entry: Dictionary) -> void:
	assert(String(entry.get("result", "")) in RESULTS, "a fight's result is one of %s" % [RESULTS])
	var e: Dictionary = entry.duplicate(true)
	e.week = week
	e.pro = bool(e.get("pro", pro))
	fights.append(e)


## His wins, losses, draws and no contests, pro or amateur: { win, loss, draw, no_contest }.
func record(pro_fights: bool) -> Dictionary:
	var out := { "win": 0, "loss": 0, "draw": 0, "no_contest": 0 }
	for e: Dictionary in fights:
		if bool(e.get("pro", false)) == pro_fights:
			out[String(e.result)] += 1
	return out


## The record as it's written: wins-losses-draws, "5-1-0", with no contests after it when there are any ("5-1-0, 1 NC").
func record_text(pro_fights: bool) -> String:
	var r: Dictionary = record(pro_fights)
	var text: String = "%d-%d-%d" % [r.win, r.loss, r.draw]
	if r.no_contest > 0:
		text += ", %d NC" % r.no_contest
	return text


## What the load screen shows for this career.
func summary() -> Dictionary:
	return {
		"name": fighter_name(), "nickname": String(about.get("nickname", "")), "coach": coach_name,
		"hometown": String(about.get("hometown", "")), "country": String(about.get("country", "")),
		"background": String(about.get("background", "")),
		"age": age(), "date": date_text(), "week": week, "pro": pro,
		"amateur_record": record_text(false), "pro_record": record_text(true),
	}


## The whole career as plain data for a save file (docs/09 career@1). Seeds and dice are text: a 64-bit number
## doesn't survive a JSON number.
func to_dict() -> Dictionary:
	return {
		"schema": SCHEMA, "version": VERSION,
		"seed": str(career_seed), "dice": str(_dice.state),
		"coach": { "name": coach_name },
		"fighter": fighter.duplicate(true), "about": about.duplicate(true),
		"trainee": trainee.snapshot(),
		"calendar": { "first_monday": first_monday, "week": week },
		"suspended_days": suspended_days, "money": money, "pro": pro, "week_plan": week_plan,
		"fights": fights.duplicate(true), "opponents": opponents.duplicate(true),
		"booked": booked.duplicate(true), "offers": offers.duplicate(true),
		"summary": summary(),
	}


## A career back from to_dict() (after a trip through a JSON file, so whole numbers may come back as floats).
## null when the data isn't a career this game can read; load_error says why.
static func from_dict(data: Dictionary, library: TrainingLibrary = null) -> Career:
	var d: Dictionary = migrate(data)
	if d.is_empty():
		return null
	for key: String in ["fighter", "trainee", "calendar"]:
		if not d.get(key) is Dictionary:
			load_error = "the save has no %s" % key
			return null
	var c := Career.new()
	c._library = library if library != null else TrainingLibrary.shared()
	c.career_seed = String(d.get("seed", "0")).to_int()
	c._dice.seed = c.career_seed
	c._dice.state = String(d.get("dice", "0")).to_int()
	c.coach_name = String(d.get("coach", {}).get("name", ""))
	c.fighter = d.fighter.duplicate(true)
	for key in ABOUT_KEYS:
		c.about[key] = String(d.get("about", {}).get(key, ""))
	c.first_monday = int(d.calendar.get("first_monday", 0))
	c.week = int(d.calendar.get("week", 0))
	c.suspended_days = int(d.get("suspended_days", 0))
	c.money = int(d.get("money", 0))
	c.pro = bool(d.get("pro", false))
	c.week_plan = String(d.get("week_plan", BETWEEN_PLAN))
	c.fights = d.get("fights", []).duplicate(true)
	c.opponents = d.get("opponents", {}).duplicate(true)
	c.booked = d.get("booked", {}).duplicate(true)
	c.offers = d.get("offers", []).duplicate(true)
	c.trainee = TrainingCamp.new(c.fighter, 0, c._library)
	c.trainee.restore(d.trainee)
	return c


## A save from an older version of the game, brought up to this one a version at a time. {} when it isn't a career
## save, or was saved by a newer game than this one (load_error says which).
static func migrate(data: Dictionary) -> Dictionary:
	load_error = ""
	if String(data.get("schema", "")) != SCHEMA:
		load_error = "not a career save"
		return {}
	var version: int = int(data.get("version", 0))
	if version > VERSION:
		load_error = "saved by a newer version of the game (save version %d; this one reads up to %d)" % [version, VERSION]
		return {}
	if version < 1:
		load_error = "the save has no version"
		return {}
	var out: Dictionary = data.duplicate(true)
	# Each new version adds its step here, oldest first, e.g.:
	# if version == 1:
	#     out = _version_1_to_2(out)
	#     version = 2
	out.version = VERSION
	return out


## Days since 1 Jan 1970 for a date (proleptic Gregorian; Howard Hinnant's days_from_civil). Plain arithmetic, so the
## calendar needs no clock.
@warning_ignore("integer_division")
static func days_from_civil(year: int, month: int, day: int) -> int:
	var y: int = year - (1 if month <= 2 else 0)
	var era: int = (y if y >= 0 else y - 399) / 400
	var yoe: int = y - era * 400
	var doy: int = (153 * (month + (-3 if month > 2 else 9)) + 2) / 5 + day - 1
	var doe: int = yoe * 365 + yoe / 4 - yoe / 100 + doy
	return era * 146097 + doe - 719468


## [year, month, day] for days since 1 Jan 1970 (the other way round from days_from_civil).
@warning_ignore("integer_division")
static func civil_from_days(days: int) -> Array[int]:
	var z: int = days + 719468
	var era: int = (z if z >= 0 else z - 146096) / 146097
	var doe: int = z - era * 146097
	var yoe: int = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
	var doy: int = doe - (365 * yoe + yoe / 4 - yoe / 100)
	var mp: int = (5 * doy + 2) / 153
	var day: int = doy - (153 * mp + 2) / 5 + 1
	var month: int = mp + (3 if mp < 10 else -9)
	var out: Array[int] = [yoe + era * 400 + (1 if month <= 2 else 0), month, day]
	return out
