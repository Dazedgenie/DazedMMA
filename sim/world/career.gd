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
## Training wore him down this week: his fatigue went past TrainingCamp.FATIGUE_FREE, where he starts learning less
## (docs/02 §3.5). Sunday's rest brings him back by Monday, so it's the week's peak that counts. Counted the first
## week it happens, not every week after on the same hard plan, so Advance stops once (Kyle, 2026-10-31).
const WORN_DOWN := "worn_down"
## Fight offers came in (D304): { kind, count }.
const OFFERS := "offers"
## He couldn't pay the gym fee in full, so the owner gave him Saturday shifts to work it off (D313): { kind, owed }.
const GYM_SHIFTS := "gym_shifts"
## School (D314, School): the summer holidays start (every session is his until September), school starts again, and
## he's left school for good (LEAVES_AT): { kind }.
const SCHOOL_OUT := "school_out"
const BACK_TO_SCHOOL := "back_to_school"
const LEFT_SCHOOL := "left_school"
## Days from fight night (Saturday) to the Monday after it.
const FIGHT_TO_MONDAY: int = 2
## How many weeks a year has for a birthday: TrainingCamp ages him 1/52 of a year a week (docs/02 §3.8).
const WEEKS_PER_YEAR: float = 52.0

## Why the last from_dict() or migrate() failed ("" when it didn't).
static var load_error: String = ""

var career_seed: int = 0
## The head coach: the player (D15), with a background and a specialty (Coach, D311). A career saved before D311 has
## neither ("").
var coach_name: String = ""
var coach_background: String = ""
var coach_specialty: String = ""
## The fighter@1 profile he started with: name, frame, stance, personality, gifts, flaws and moves. What changes
## with training (stats, style, age, condition) is in `trainee`; profile() puts the two together.
var fighter: Dictionary = {}
## nickname, hometown, country, background (ABOUT_KEYS).
var about: Dictionary = {}
## His childhood (Childhood, D312): { picks: [{scene, choice}], second: the runner-up background, people: [{role, name,
## about, age}] }. {} when the player picked his background from the list instead (or the career predates D312).
var childhood: Dictionary = {}
## Your gym, where he trains (Gym, D313): { kind, culture, name, owner_name, owner, fee }. {} for a career before D313 (no
## gym: training as before, no fee).
var gym: Dictionary = {}
## What he owes the gym (D313): a fee he couldn't pay in full. He works it off in Saturday shifts (Gym.with_shifts).
var gym_owed: int = 0
var trainee: TrainingCamp
## The day (days since 1 Jan 1970) of the Monday that starts week 0, and the week it is now.
var first_monday: int = 0
var week: int = 0
## Whether training wore him down last week (WORN_DOWN): a week like it after this one isn't news.
var worn_last_week: bool = false
## Days until a medical suspension lets him fight again (0 = none).
var suspended_days: int = 0
var money: int = 0
## Turned pro: his fights count on the pro record from then on.
var pro: bool = false
## Every fight he's had, oldest first (add_fight()).
var fights: Array = []
## Everyone he's fought or is booked to fight: id → fighter@1 profile, so a rematch is the same man.
var opponents: Dictionary = {}
## The offers on the table (Matchmaker.make_offer's, D304) and the fight he took ({} when none): an offer without its
## `profile` (that's in `opponents`), with `opponent` (the opponent's id) and `camp_weeks` (the camp it left him).
var booked: Dictionary = {}
var offers: Array = []
## The first week the next set of offers can come in (they wait while he's booked, hurt or suspended).
var next_offers_week: int = 1
## The week plan run between fights: a data/week_plans id.
var week_plan: String = BETWEEN_PLAN
## The first week a one-day tournament (Tournament, D315) can be offered: one of the next set of offers is a
## tournament from this week on, while he's amateur.
var next_tournament_week: int = Tournament.FIRST_WEEK
## His tournament medals, oldest first: { medal (Tournament.GOLD, SILVER or BRONZE), name, week, size }.
var medals: Array = []

var _dice := RandomNumberGenerator.new()
var _library: TrainingLibrary
var _matchmaker: Matchmaker


## A new career for this fighter (a fighter@1 profile) on week 0. `extra` may give `coach` (the player's name),
## `coach_background` and `coach_specialty` (Coach, D311), `gym` (one of Gym.offers(), D313) and ABOUT_KEYS.
static func create(profile_in: Dictionary, new_seed: int, extra: Dictionary = {}, library: TrainingLibrary = null) -> Career:
	var c := Career.new()
	c._library = library if library != null else TrainingLibrary.shared()
	c.career_seed = new_seed
	c._dice.seed = new_seed
	c.fighter = profile_in.duplicate(true)
	c.fighter.id = FIGHTER_ID
	c.fighter.erase("condition")
	c.coach_name = String(extra.get("coach", ""))
	c.coach_background = String(extra.get("coach_background", ""))
	c.coach_specialty = String(extra.get("coach_specialty", ""))
	for key in ABOUT_KEYS:
		c.about[key] = String(extra.get(key, ""))
	c.first_monday = days_from_civil(START_DATE[0], START_DATE[1], START_DATE[2])
	c.trainee = TrainingCamp.new(c.fighter, c._dice.randi(), c._library)
	c.trainee.coach_specialty = c.coach_specialty
	if extra.get("gym") is Dictionary:
		c.gym = (extra.gym as Dictionary).duplicate(true)
	c.trainee.gym = c.gym
	c._school_week()
	return c


## A new career from the new-career screen (docs/03 §10.2, D302): a 16-year-old made from his background
## (BackgroundLibrary.make_fighter) and the player's `choices`: coach, name, nickname, hometown, country, background (an
## id in data/backgrounds) and stance. He starts with his background's money.
##
## With `childhood` (the picks from his childhood scenes, [{scene, choice}]: Childhood, D312, §11.2) his background is
## the one those choices add up to instead of `background`, and the choices change him on top (Childhood.apply), add
## to his money and bring in people (named from `country_id`). `new_seed` must be the seed the scenes were drawn with.
static func start(choices: Dictionary, new_seed: int, roster: FighterLibrary, backgrounds: BackgroundLibrary = null,
		library: TrainingLibrary = null, scenes: Childhood = null) -> Career:
	var bgs: BackgroundLibrary = backgrounds if backgrounds != null else BackgroundLibrary.shared()
	var picks: Array = choices.get("childhood", [])
	var kid: Childhood = null
	var tally: Dictionary = {}
	if not picks.is_empty():
		kid = scenes if scenes != null else Childhood.shared()
		tally = kid.tally(picks)
	var extra: Dictionary = choices.duplicate(true)
	if String(tally.get("background", "")) != "" and bgs.has(String(tally.background)):
		extra.background = String(tally.background)
	var background: String = String(extra.get("background", ""))
	var profile_in: Dictionary = bgs.make_fighter(background, new_seed, roster, extra)
	if not tally.is_empty():
		profile_in = kid.apply(profile_in, picks, bgs)
	var c: Career = create(profile_in, new_seed, extra, library)
	c.money = int(bgs.get_background(background).get("money", 0))
	if not tally.is_empty():
		c.money += kid.money(picks)
		c.childhood = {
			"picks": picks.duplicate(true), "second": String(tally.second),
			"people": kid.people(picks, String(profile_in.get("name", "")), String(choices.get("country_id", "")), new_seed),
		}
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
	var before := { "injured_days": trainee.injured_days, "suspended_days": suspended_days, "age": age(),
		"at_school": School.at_school(self), "holiday": School.on_holiday(self) }
	var worked: int = 0
	if gym_owed > 0:
		plan_data = Gym.with_shifts(plan_data)  # Saturday at the gym, working off what he owes.
		worked = mini(gym_owed, Gym.shift_week_pay())
	var report: Dictionary = trainee.run_plan(plan_data, played)
	gym_owed -= worked
	report.gym_worked = worked
	var owed_before: int = gym_owed
	report.gym_fee = end_week()
	report.week = week - 1
	report.events = _events_since(before)
	if owed_before == 0 and gym_owed > 0:
		report.events.append({ "kind": GYM_SHIFTS, "owed": gym_owed })
	var worn: bool = float(report.get("fatigue_peak", 0.0)) >= TrainingCamp.FATIGUE_FREE
	if worn and not worn_last_week:
		report.events.append({ "kind": WORN_DOWN })
	worn_last_week = worn
	_check_offers(report.events)
	return report


## Weeks on the career's week plan until something happens (docs/03 §10.3, D303): he's hurt, he's healed, his
## suspension ends, training wears him down, a birthday, an offer comes in (D304), or ADVANCE_MAX_WEEKS go by.
## Nothing runs while he's booked for a fight: the camp runs that (D304). Returns each week's report, oldest first.
func advance(max_weeks: int = ADVANCE_MAX_WEEKS) -> Array[Dictionary]:
	var reports: Array[Dictionary] = []
	if not booked.is_empty():
		return reports
	for i in max_weeks:
		var report: Dictionary = run_week()
		reports.append(report)
		if not (report.events as Array).is_empty():
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
	for i in range(1, weeks):  # School (D314): the week before each change, as run_week() reports it.
		if not School.at_school(self, week + i - 1):
			break
		if not School.at_school(self, week + i):
			_add_ahead(ahead, i - 1, { "kind": LEFT_SCHOOL })
		elif School.on_holiday(self, week + i) != School.on_holiday(self, week + i - 1):
			_add_ahead(ahead, i - 1, { "kind": SCHOOL_OUT if School.on_holiday(self, week + i) else BACK_TO_SCHOOL })
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
	if bool(before.get("at_school", false)):
		if not School.at_school(self):
			out.append({ "kind": LEFT_SCHOOL })
		elif School.on_holiday(self) and not bool(before.holiday):
			out.append({ "kind": SCHOOL_OUT })
		elif bool(before.holiday) and not School.on_holiday(self):
			out.append({ "kind": BACK_TO_SCHOOL })
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
		WORN_DOWN:
			return "Worn down from training"
		OFFERS:
			return "%d fight offers" % int(event.get("count", 0))
		BIRTHDAY:
			return "Turns %d" % int(event.get("age", 0))
		FIGHT_NIGHT:
			return "Fight night"
		GYM_SHIFTS:
			return "Short on the gym fee: working Saturdays at the gym ($%d)" % int(event.get("owed", 0))
		SCHOOL_OUT:
			return "School's out for the summer: every session is his until September"
		BACK_TO_SCHOOL:
			return "Back to school: weekday mornings are at school again"
		LEFT_SCHOOL:
			return "Done with school: every session is his now"
	return String(event.kind)


## A new week's offers (D304): the ones past their last week go, and a new set comes in if he's free and it's time.
## Called by run_week(); camp weeks don't get offers (he's booked).
func _check_offers(events: Array) -> void:
	offers = offers.filter(func(o: Dictionary) -> bool: return int(o.get("expires", -1)) >= week)
	if not offers.is_empty() or not booked.is_empty() or trainee.injured_days > 0 or suspended_days > 0 or week < next_offers_week:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = ("offers:%d:%d" % [career_seed, week]).hash()
	offers = matchmaker().make_offers(self, rng)
	if not pro and week >= next_tournament_week and not offers.is_empty():
		# Every few months one of the offers is a one-day tournament instead (D315).
		offers[-1] = matchmaker().make_tournament(self, rng, 0, offers.size() - 1)
		next_tournament_week = week + rng.randi_range(Tournament.GAP_MIN, Tournament.GAP_MAX)
	next_offers_week = week + Matchmaker.OPEN_WEEKS + rng.randi_range(Matchmaker.GAP_MIN, Matchmaker.GAP_MAX)
	events.append({ "kind": OFFERS, "count": offers.size() })


## Who makes his offers: the shipped data's unless set (tests set their own).
func matchmaker() -> Matchmaker:
	if _matchmaker == null:
		_matchmaker = Matchmaker.shared()
	return _matchmaker


func set_matchmaker(m: Matchmaker) -> void:
	_matchmaker = m


func offer(id: String) -> Dictionary:
	for o: Dictionary in offers:
		if String(o.id) == id:
			return o
	return {}


## Takes an offer (D304): he's booked for it, the other offers go, the opponent joins `opponents` and the camp starts
## (TrainingCamp.start_camp: its gains count afresh). Returns false when there's no such offer or he's booked already.
func accept(id: String) -> bool:
	var o: Dictionary = offer(id)
	if o.is_empty() or not booked.is_empty():
		return false
	booked = o.duplicate(true)
	booked.erase("profile")
	booked.opponent = String(o.profile.id)
	booked.camp_weeks = int(o.week) - week + 1
	add_opponent(o.profile)
	if o.get("tournament") is Dictionary:
		# A tournament (D315): every man he'd meet is known now, one a round; the first is booked.opponent.
		var men: Array = [{ "id": String(o.profile.id), "about": o.get("about", {}), "style": String(o.get("style", "")) }]
		for m: Dictionary in o.tournament.get("rest", []):
			add_opponent(m.profile)
			men.append({ "id": String(m.profile.id), "about": m.get("about", {}), "style": String(m.get("style", "")) })
		booked.tournament = { "size": int(o.tournament.size), "stage": 0, "men": men, "carry": {}, "suspension": 0 }
	offers.clear()
	trainee.start_camp()
	return true


## Turns an offer down: it goes, and nothing else happens (no penalty in phase 1, D304).
func decline(id: String) -> void:
	offers = offers.filter(func(o: Dictionary) -> bool: return String(o.id) != id)


## Turns pro (D304, the hub's button when Matchmaker.can_turn_pro): his fights count on the pro record from now, the
## amateur offers on the table go and pro offers come next week.
func turn_pro() -> bool:
	if not Matchmaker.can_turn_pro(self):
		return false
	pro = true
	offers.clear()
	next_offers_week = week + 1
	return true


## The weeks of camp left before the booked fight, this one included (0 when not booked).
func camp_weeks_left() -> int:
	return int(booked.week) - week + 1 if not booked.is_empty() else 0


## The booked opponent's profile and name ("" when not booked).
func booked_opponent() -> Dictionary:
	return opponents.get(String(booked.get("opponent", "")), {})


## The booked fight is over (D304): onto his record, his purse paid, the fight week done. `entry` is as add_fight()
## takes it, without `opponent` (the booked one), and `hard` (Aftermath.is_hard) when it was a hard fight for him.
## Then the aftermath (D305, Aftermath.of): a medical suspension counted from fight night, and the Chin a knockout
## takes for good; the fight's entry keeps them (`suspension_days`, `suspension_why`, `chin_lost`). Returns what he was paid.
##
## In a tournament (D315) `entry` may also give `tank` (the gas tank he went in with) and `hurt` (his damage at the end,
## area → 0–1): a win before the final keeps him booked for the next round, carrying that (Tournament.carry_over),
## and the week isn't over; a loss, a draw or the final ends his day with any medal (`medals`, and the fight's
## entry's `medal`). The suspension is the day's worst, from the end of it.
func finish_fight(entry: Dictionary) -> int:
	var e: Dictionary = entry.duplicate(true)
	var hard: bool = bool(e.get("hard", false))
	e.erase("hard")
	var tank_in: float = float(e.get("tank", 1.0))
	var hurt_out: Dictionary = e.get("hurt", {}) if e.get("hurt") is Dictionary else {}
	e.erase("tank")
	e.erase("hurt")
	e.opponent = String(booked.get("opponent", ""))
	e.ruleset = String(booked.get("ruleset", ""))
	if booked.get("card") is Dictionary and not (booked.card as Dictionary).is_empty():
		e.card = (booked.card as Dictionary).duplicate()  # The local card it was on (D314).
	var purse: Dictionary = booked.get("purse", {})
	var paid: int = int(purse.get("show", 0)) + (int(purse.get("win", 0)) if String(e.result) == "win" else 0)
	if paid > 0:
		e.purse = paid
	var after: Dictionary = Aftermath.of(String(e.result), String(e.get("method", "")), hard)
	e.suspension_days = int(after.days)
	e.chin_lost = float(after.chin)
	e.suspension_why = String(after.why)
	var t: Dictionary = booked.get("tournament", {}) if booked.get("tournament") is Dictionary else {}
	var days: int = int(after.days)
	if not t.is_empty():
		var stage: int = int(t.stage)
		var won: bool = String(e.result) == "win"
		e.tournament = { "name": tournament_name(), "size": int(t.size), "stage": stage }
		if won and stage < Tournament.rounds(int(t.size)) - 1:
			add_fight(e)
			money += paid
			trainee.stats["chin"] = maxf(0.0, trainee.stat("chin") - float(after.chin))
			t.stage = stage + 1
			t.carry = Tournament.carry_over(tank_in, hurt_out)
			if days > int(t.get("suspension", 0)):
				t.suspension = days  # The day's worst so far, given when his day's over.
				t.suspension_why = String(after.why)
			var next: Dictionary = t.men[stage + 1]
			booked.opponent = String(next.id)
			booked.about = next.get("about", {})
			booked.style = String(next.get("style", ""))
			return paid  # Through to the next round: the same day, so the week isn't over.
		if int(t.get("suspension", 0)) > days:
			days = int(t.suspension)
			e.suspension_days = days
			e.suspension_why = "%s earlier in the day" % String(t.get("suspension_why", "a hard fight"))
		e.medal = Tournament.medal(int(t.size), stage, won)
		if String(e.medal) != "":
			medals.append({ "medal": String(e.medal), "name": tournament_name(), "week": week, "size": int(t.size) })
		for id: String in _unmet().slice(1):
			opponents.erase(id)  # The men after this round he never met.
	add_fight(e)
	money += paid
	trainee.stats["chin"] = maxf(0.0, trainee.stat("chin") - float(after.chin))
	_after_booking()
	# The suspension runs from fight night (Saturday): by Monday two of its days are gone.
	suspended_days = maxi(suspended_days, days - FIGHT_TO_MONDAY)
	return paid


## The booked fight is off (pulled out, or the doctor wouldn't clear him, D135): the camp's wasted, the fight week's
## done and the man he'd have fought goes from `opponents`.
##
## In a tournament the men he hasn't met yet go. Pulling out between rounds (withdraw()) is the tournament's own way out.
func cancel_fight() -> void:
	for id: String in _unmet():
		opponents.erase(id)
	_after_booking()


## Pulls out of a tournament between rounds (D315: too hurt to go on): he's out at the round he'd have fought next,
## with the medal that round's loser gets (withdrawing from the final is silver, from a semi-final bronze). The men he
## didn't meet go from `opponents`. Returns the medal ("" for none), or "" with nothing done when not between rounds.
func withdraw() -> String:
	var t: Dictionary = booked.get("tournament", {}) if booked.get("tournament") is Dictionary else {}
	if t.is_empty() or int(t.stage) == 0:
		return ""
	var m: String = Tournament.medal(int(t.size), int(t.stage), false)
	if m != "":
		medals.append({ "medal": m, "name": tournament_name(), "week": week, "size": int(t.size) })
		fights[-1].medal = m
	fights[-1].withdrew = true
	var days: int = int(t.get("suspension", 0))
	if days > int(fights[-1].get("suspension_days", 0)):
		fights[-1].suspension_days = days
		fights[-1].suspension_why = "%s earlier in the day" % String(t.get("suspension_why", "a hard fight"))
	for id: String in _unmet():
		opponents.erase(id)
	_after_booking()
	suspended_days = maxi(suspended_days, days - FIGHT_TO_MONDAY)
	return m


## The booked tournament's round he fights next (0 for the first), or -1 when the booked fight isn't a tournament.
func tournament_stage() -> int:
	return int(booked.tournament.stage) if booked.get("tournament") is Dictionary else -1


## The booked tournament's name ("" when it isn't one).
func tournament_name() -> String:
	return String(booked.get("card", {}).get("name", "")) if booked.get("card") is Dictionary else ""


## What he carries into the tournament's next round (fighter@1 `condition`: { tank, hurt }), {} before the first.
func tournament_condition() -> Dictionary:
	if tournament_stage() <= 0:
		return {}
	return (booked.tournament.get("carry", {}) as Dictionary).duplicate(true)


## His profile for a tournament's next round: as he is, going in as the last fight left him (tournament_condition),
## and a Tactician's calls still reaching him sooner (D311).
func round_profile() -> Dictionary:
	var out: Dictionary = profile()
	out.condition = tournament_condition()
	if Coach.call_delay(coach_specialty) != 1.0:
		out.condition.call_delay = Coach.call_delay(coach_specialty)
	return out


## The booked men he hasn't fought: the booked opponent, and in a tournament the ones after him.
func _unmet() -> Array[String]:
	var out: Array[String] = []
	if booked.get("tournament") is Dictionary:
		for i in range(int(booked.tournament.stage), (booked.tournament.men as Array).size()):
			out.append(String(booked.tournament.men[i].id))
	elif String(booked.get("opponent", "")) != "":
		out.append(String(booked.opponent))
	return out


func _after_booking() -> void:
	booked = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = ("after:%d:%d" % [career_seed, week]).hash()
	next_offers_week = week + 1 + rng.randi_range(Matchmaker.GAP_MIN, Matchmaker.GAP_MAX)
	end_week()


## Moves the calendar on to next Monday. run_week() calls it; a camp week run on `trainee` by the planner calls it too.
## Returns the gym fee he paid as the week turned ($, 0 when none was due): his gym's `fee` comes out of his savings on
## the first Monday of each month (D313), as much of it as he has; the rest he owes (gym_owed) and works off.
func end_week() -> int:
	week += 1
	suspended_days = maxi(0, suspended_days - DAYS_PER_WEEK)
	_school_week()
	if gym.is_empty() or int(date(0, week).month) == int(date(0, week - 1).month):
		return 0
	var paid: int = mini(int(gym.get("fee", 0)), money)
	money -= paid
	gym_owed += int(gym.get("fee", 0)) - paid
	return paid


## Hands the new week's school slots (School.taken, D314) to his TrainingCamp, so the hub's weeks and a fight camp's
## both lose them.
func _school_week() -> void:
	trainee.taken = School.taken(self)


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
		"coach_specialty": coach_specialty,
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
		"coach": { "name": coach_name, "background": coach_background, "specialty": coach_specialty },
		"fighter": fighter.duplicate(true), "about": about.duplicate(true), "childhood": childhood.duplicate(true),
		"gym": gym.duplicate(true), "gym_owed": gym_owed,
		"trainee": trainee.snapshot(),
		"calendar": { "first_monday": first_monday, "week": week },
		"suspended_days": suspended_days, "money": money, "pro": pro, "week_plan": week_plan,
		"worn_last_week": worn_last_week, "next_offers_week": next_offers_week,
		"next_tournament_week": next_tournament_week, "medals": medals.duplicate(true),
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
	c.coach_background = String(d.get("coach", {}).get("background", ""))
	c.coach_specialty = String(d.get("coach", {}).get("specialty", ""))
	c.fighter = d.fighter.duplicate(true)
	for key in ABOUT_KEYS:
		c.about[key] = String(d.get("about", {}).get(key, ""))
	c.childhood = d.get("childhood", {}).duplicate(true) if d.get("childhood") is Dictionary else {}
	for person: Variant in c.childhood.get("people", []):
		if person is Dictionary:
			person.age = int(person.get("age", 0))
	c.first_monday = int(d.calendar.get("first_monday", 0))
	c.week = int(d.calendar.get("week", 0))
	c.suspended_days = int(d.get("suspended_days", 0))
	c.money = int(d.get("money", 0))
	c.pro = bool(d.get("pro", false))
	c.week_plan = String(d.get("week_plan", BETWEEN_PLAN))
	c.worn_last_week = bool(d.get("worn_last_week", false))
	c.next_offers_week = int(d.get("next_offers_week", c.week + 1))
	c.next_tournament_week = int(d.get("next_tournament_week", c.week + Tournament.FIRST_WEEK))
	c.medals = d.get("medals", []).duplicate(true) if d.get("medals") is Array else []
	for m: Variant in c.medals:
		if m is Dictionary:
			m.week = int(m.get("week", 0))
			m.size = int(m.get("size", 0))
	c.fights = d.get("fights", []).duplicate(true)
	c.opponents = d.get("opponents", {}).duplicate(true)
	c.booked = d.get("booked", {}).duplicate(true)
	if c.booked.get("tournament") is Dictionary:
		for key: String in ["size", "stage", "suspension"]:
			c.booked.tournament[key] = int(c.booked.tournament.get(key, 0))
	c.offers = d.get("offers", []).duplicate(true)
	c.gym = d.get("gym", {}).duplicate(true) if d.get("gym") is Dictionary else {}
	if c.gym.has("fee"):
		c.gym.fee = int(c.gym.fee)
	c.gym_owed = int(d.get("gym_owed", 0))
	c.trainee = TrainingCamp.new(c.fighter, 0, c._library)
	c.trainee.coach_specialty = c.coach_specialty
	c.trainee.gym = c.gym
	c.trainee.restore(d.trainee)
	c._school_week()
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
