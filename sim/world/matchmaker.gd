class_name Matchmaker
extends RefCounted
## Fight offers for a career (docs/03 §10.4, D304). While he's free (not booked, hurt or suspended), a set of
## OFFERS_MIN–OFFERS_MAX offers comes in every few weeks and stays open OPEN_WEEKS weeks. Each is one of the world's
## men in his division (World, D352: pick_man), a bit easier, about even or a bit harder than him, on a date
## CAMP_WEEKS_MIN–CAMP_WEEKS_MAX weeks away (the camp's length), under the rules his age and record call for, for a
## purse once he's pro.
##
## Pure and seeded (D100): the same dice make the same offers.

## How many offers come at once.
const OFFERS_MIN: int = 2
const OFFERS_MAX: int = 3
## Weeks an offer stays open: this week and the next.
const OPEN_WEEKS: int = 2
## Weeks after a set of offers closes (or after a fight) before the next set comes.
const GAP_MIN: int = 1
const GAP_MAX: int = 3
## The camp an offer leaves him, if he takes it the week it comes in: the fight is on that many weeks' last Saturday.
## Taken in its last open week, the camp is a week shorter, so never less than CAMP_WEEKS_MIN.
const CAMP_WEEKS_MIN: int = 4
const CAMP_WEEKS_MAX: int = 8
## How much better or worse than him each kind of offer is, in points on every stat (StyleLibrary's quality level).
const DIFFICULTY_LEVELS := { "easier": -5, "even": 0, "harder": 5 }
const DIFFICULTIES: Array[String] = ["easier", "even", "harder"]
## Each offer's level is off its kind's by up to this much either way.
const LEVEL_SPREAD: int = 2
## The rules (data/rulesets): teen amateur under ADULT_AGE, adult amateur from it, pro once he turns pro.
const TEEN_RULES := "amateur_teen"
const ADULT_RULES := "amateur_adult"
const PRO_RULES := "pro"
const ADULT_AGE: int = 18
## Turning pro (a button on the hub): from PRO_AGE, after PRO_AFTER_FIGHTS amateur fights.
const PRO_AGE: int = 18
const PRO_AFTER_FIGHTS: int = 4
## A pro purse in dollars: paid to show, and as much again for a win. Both rise by PURSE_STEP for every pro win.
const PURSE_SHOW: int = 1000
const PURSE_WIN: int = 1000
const PURSE_STEP: int = 250
## An adult opponent's age: his give or take this much (never under ADULT_AGE or over OLDEST).
const AGE_YOUNGER: int = 3
const AGE_OLDER: int = 4
const OLDEST: int = 40
## Picking the world's man for an offer (pick_man, D352): points of average stat a year he's outside that age gap
## counts as; any man within PICK_WITHIN of the offer's level may be picked, else the closest within NEWCOMER_PAST,
## else a new man joins the world.
const AGE_PENALTY: float = 1.0
const PICK_WITHIN: float = 2.5
const NEWCOMER_PAST: float = 4.0
## Local amateur cards (docs/03 §11.4, D314): where the names and venues come from (docs/09 cards@1).
const CARDS_PATH := "res://data/cards/local.json"
## A card's number in its series: 1 + up to SERIES_START (seeded by the career and the series) + one every `every_weeks`.
const SERIES_START: int = 9
## Turning pro (docs/08 §2, D314): the hub's word on it from PRO_AGE. Wise when he has won at least PRO_WIN_SHARE of his
## decided amateur fights and his stats average PRO_READY_AVG (a C: a top prospect is 45 at 18, docs/02 §3.8); and from
## PRO_LATE_AGE, waiting longer costs him prime years.
const PRO_WIN_SHARE: float = 0.6
const PRO_READY_AVG: float = 38.0
const PRO_LATE_AGE: int = 22
## The hub's word on turning pro.
const PRO_NOT_YET := "not_yet"
const PRO_WISE := "wise"
const PRO_RISKY := "risky"
const PRO_LATE := "late"

static var _cards: Dictionary = {}

static var _shared: Matchmaker

var styles: StyleLibrary
var names: NameLibrary
var roster: FighterLibrary


func _init(p_styles: StyleLibrary = null, p_names: NameLibrary = null, p_roster: FighterLibrary = null) -> void:
	styles = p_styles if p_styles != null else StyleLibrary.shared()
	names = p_names if p_names != null else NameLibrary.shared()
	roster = p_roster if p_roster != null else FighterLibrary.load_dir()


## One matchmaker on the shipped data, loaded once.
static func shared() -> Matchmaker:
	if _shared == null:
		_shared = Matchmaker.new()
	return _shared


## A set of offers for this career this week: OFFERS_MIN–OFFERS_MAX, each a different man of a different style. Two
## offers are one about even and one easier or harder; three are one of each.
func make_offers(c: Career, rng: RandomNumberGenerator) -> Array:
	var count: int = rng.randi_range(OFFERS_MIN, OFFERS_MAX)
	var kinds: Array[String] = DIFFICULTIES.duplicate()
	if count < kinds.size():
		kinds = ["even", "easier" if rng.randf() < 0.5 else "harder"]
		kinds.sort_custom(func(a: String, b: String) -> bool: return DIFFICULTIES.find(a) < DIFFICULTIES.find(b))
	var out: Array = []
	for i in count:
		out.append(make_offer(c, "", kinds[i], rng, i, out))
	return out


## One offer: { id, profile (the opponent, fighter@1: a man of the world, World.profile), about (nickname, hometown,
## country, record), style, difficulty, division (D351), week (fight night is that week's Saturday), expires (the last
## week it's open), ruleset, pro, purse ({show, win} or {}), card }.
##
## The man (D352) is one of the world's men in his division this week (World), an amateur while he is one and a pro
## once he's pro, a teenager while he's one, as good as the offer's kind (pick_man), and of `style_id` (any style none
## of the offers in `taken` has when ""). Nobody he's fought lately (World.can_rematch) or in `taken`. When nobody in
## the world fits, a new man joins it (World.add_newcomer).
func make_offer(c: Career, style_id: String, difficulty: String, rng: RandomNumberGenerator, index: int = 0, taken: Array = []) -> Dictionary:
	var country_id: String = names.country_id_of(String(c.about.get("country", "")))
	var target: float = average_stat(c.profile().get("stats", {})) + float(DIFFICULTY_LEVELS.get(difficulty, 0)) \
		+ float(rng.randi_range(-LEVEL_SPREAD, LEVEL_SPREAD))
	var division: String = c.division_now()
	var w: World = c.world()
	var id: String = pick_man(c, w, division, target, style_id, taken, rng)
	if id == "":
		var used: Array = taken.map(func(o: Dictionary) -> String: return String(o.get("style", "")))
		var style_ids: Array = styles.ids().filter(func(x: Variant) -> bool: return not String(x) in used)
		style_ids.sort()
		var new_style: String = style_id if style_id != "" else String(style_ids[rng.randi_range(0, style_ids.size() - 1)])
		id = w.add_newcomer(rng, division, c.pro, new_style, target, newcomer_age(c, rng), c.week)
	var m: Dictionary = w.man(id)
	var p: Dictionary = w.profile(id, c.week)
	var camp: int = rng.randi_range(CAMP_WEEKS_MIN + OPEN_WEEKS - 1, CAMP_WEEKS_MAX)
	return {
		"id": "offer_w%d_%d" % [c.week, index], "profile": p, "about": World.about(m),
		"style": String(m.style), "difficulty": difficulty, "division": division,
		"week": c.week + camp - 1, "expires": c.week + OPEN_WEEKS - 1,
		"ruleset": rules_for(c), "pro": c.pro, "purse": purse_for(c),
		"card": {} if c.pro else local_card(c, rng, country_id),
	}


## The world's man for an offer (D352): of his division this week, an amateur or a pro as he is, 16 or 17 while he's
## under ADULT_AGE (18 or over once he isn't), not in `taken` (offers already made) or fought lately, of `style_id`
## (or of a style none of `taken` has). Each is scored by how far his average stat is off `target`, plus AGE_PENALTY a
## year he's outside AGE_YOUNGER–AGE_OLDER of the career's fighter; one of those within PICK_WITHIN, or the closest
## within NEWCOMER_PAST. "" when nobody is that close.
func pick_man(c: Career, w: World, division: String, target: float, style_id: String, taken: Array, rng: RandomNumberGenerator) -> String:
	var taken_ids: Array = taken.map(func(o: Dictionary) -> String: return String(o.get("profile", {}).get("id", "")))
	for o: Dictionary in taken:
		if o.get("tournament") is Dictionary:
			for r: Dictionary in o.tournament.get("rest", []):
				taken_ids.append(String(r.profile.id))
	var taken_styles: Array = taken.map(func(o: Dictionary) -> String: return String(o.get("style", "")))
	var his_age: float = c.trainee.age_years
	var teen: bool = c.age() < ADULT_AGE
	var close: Array[String] = []
	var best: String = ""
	var best_score: float = INF
	for m: Dictionary in w.in_division(division, c.week):
		if bool(m.pro) != c.pro or String(m.id) in taken_ids or not World.can_rematch(m, c.week):
			continue
		if (style_id != "" and String(m.style) != style_id) or (style_id == "" and String(m.style) in taken_styles):
			continue
		var age: float = World.age_of(m, c.week)
		if age < float(BackgroundLibrary.START_AGE) or (teen and age >= float(ADULT_AGE)) or (not teen and age < float(ADULT_AGE)):
			continue
		var score: float = absf(w.average(m) - target) \
			+ AGE_PENALTY * maxf(0.0, maxf(his_age - AGE_YOUNGER - age, age - his_age - AGE_OLDER))
		if score <= PICK_WITHIN:
			close.append(String(m.id))
		if score < best_score:
			best_score = score
			best = String(m.id)
	if not close.is_empty():
		return close[rng.randi_range(0, close.size() - 1)]
	return best if best_score <= NEWCOMER_PAST else ""


## A newcomer's age (World.add_newcomer): 16 or 17 for a teenager, else about his.
static func newcomer_age(c: Career, rng: RandomNumberGenerator) -> float:
	if c.age() < ADULT_AGE:
		return rng.randf_range(float(BackgroundLibrary.START_AGE), float(ADULT_AGE) - 0.3)
	return float(opponent_age(c.age(), rng)) + rng.randf_range(0.0, 0.9)


## A lesson fight (Tutorial.LESSONS, D316): an offer like make_offer's, taking the place of the first in a set, with
## `lesson` (1 to 3). The man is the lesson's kind: lesson 2 a kicker; lessons 1 and 3 any style but a kicker's and
## none another offer in the set has.
func make_lesson(c: Career, rng: RandomNumberGenerator, lesson_number: int, others: Array = []) -> Dictionary:
	var spec: Dictionary = Tutorial.LESSONS[clampi(lesson_number - 1, 0, Tutorial.LESSONS.size() - 1)]
	var style_id: String = String(spec.style)
	if style_id == "" or not styles.has(style_id):
		var taken: Array = others.slice(1).map(func(o: Dictionary) -> String: return String(o.get("style", "")))
		var pool: Array = styles.ids().filter(func(id: Variant) -> bool:
			return not String(id) in Tutorial.KICKER_STYLES and not String(id) in taken)
		pool.sort()
		style_id = String(pool[rng.randi_range(0, pool.size() - 1)])
	var out: Dictionary = make_offer(c, style_id, String(spec.difficulty), rng, 0, others.slice(1))
	out.lesson = lesson_number
	return out


## The shipped local cards (data/cards/local.json), loaded once.
static func local_cards() -> Dictionary:
	if _cards.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CARDS_PATH))
		if parsed is Dictionary:
			_cards = parsed
	return _cards


## The local amateur card an offer is on (D314): { name, venue, city }, e.g. "Leeds Fight Night 4" at the Sports
## Centre in Leeds. Mostly in his hometown (`home_share`), otherwise another city in his country. A series keeps its
## venue, and its number goes up one every `every_weeks` weeks.
func local_card(c: Career, rng: RandomNumberGenerator, country_id: String, cards: Dictionary = {}) -> Dictionary:
	var data: Dictionary = cards if not cards.is_empty() else local_cards()
	var city: String = String(c.about.get("hometown", ""))
	var others: Array = names.cities(country_id).filter(func(x: Variant) -> bool: return String(x) != city)
	if (city == "" or rng.randf() >= float(data.get("home_share", 1.0))) and not others.is_empty():
		city = String(others[rng.randi_range(0, others.size() - 1)])
	var patterns: Array = data.get("names", ["{city} Fight Night"])
	var pattern: String = String(patterns[rng.randi_range(0, patterns.size() - 1)])
	var series: String = "%d:%s:%s" % [c.career_seed, pattern, city]
	var venues: Array = data.get("venues", ["Sports Centre"])
	var number: int = 1 + absi(series.hash()) % (SERIES_START + 1) + c.week / maxi(1, int(data.get("every_weeks", 8)))
	return {
		"name": "%s %d" % [pattern.format({ "city": city }).strip_edges(), number],
		"venue": String(venues[absi(("venue:" + series).hash()) % venues.size()]) if not venues.is_empty() else "",
		"city": city,
	}


## A one-day tournament offer (Tournament, D315): as make_offer's, its `profile` the man he'd meet in the first round,
## plus `tournament`: { size, rest (the men he'd meet in the later rounds, each { profile, about, style }, harder and
## more tired) }, and its `card` the tournament's name ("Leeds Amateur Open 2027") and venue. `size` 0 rolls the size
## (Tournament.BIG_CHANCE of the bigger one). `index` keeps its men's ids apart from the other offers'.
func make_tournament(c: Career, rng: RandomNumberGenerator, size: int = 0, index: int = 0, others: Array = []) -> Dictionary:
	if size <= 0:
		size = Tournament.SIZES[1] if rng.randf() < Tournament.BIG_CHANCE else Tournament.SIZES[0]
	var n: int = Tournament.rounds(size)
	var men: Array = []
	for stage in n:
		var difficulty: String = Tournament.DIFFICULTIES[mini(stage + Tournament.DIFFICULTIES.size() - n, Tournament.DIFFICULTIES.size() - 1)]
		var o: Dictionary = make_offer(c, "", difficulty, rng, index * 10 + stage, others + men)
		if stage > 0:
			o.profile.condition = { "tank": Tournament.OPPONENT_TANK[mini(stage, Tournament.OPPONENT_TANK.size() - 1)] }
		men.append(o)
	var out: Dictionary = men[0]
	var country_id: String = names.country_id_of(String(c.about.get("country", "")))
	out.id = "tournament_w%d" % c.week
	out.difficulty = "tournament"
	out.card = local_card(c, rng, country_id, Tournament.cards(size))
	var series_name: String = String(out.card.name)
	out.card.name = "%s %d" % [series_name.substr(0, series_name.rfind(" ")), int(c.date(5, int(out.week)).year)]  # Named by year.
	var rest: Array = []
	for i in range(1, men.size()):
		rest.append({ "profile": men[i].profile, "about": men[i].about, "style": men[i].style })
	out.tournament = { "size": size, "rest": rest }
	return out


## "Leeds Fight Night 4 · the Sports Centre, Leeds" ("" when the offer isn't on a card).
static func card_text(card: Dictionary) -> String:
	if String(card.get("name", "")) == "":
		return ""
	var where: String = ", ".join([String(card.get("venue", "")), String(card.get("city", ""))].filter(func(x: String) -> bool: return x != ""))
	return String(card.name) + (" · the %s" % where if where != "" else "")


## The quality level (StyleLibrary.generate) that makes a man of this style about as good as him: his average stat
## less the style's signature fighter's. Clamped to StyleLibrary.MAX_LEVEL either way.
func level_against(his_stats: Dictionary, style_id: String) -> int:
	var signature: Dictionary = roster.profile(String(styles.get_style(style_id).fighter)).get("stats", {})
	var his: float = 0.0
	var theirs: float = 0.0
	var ids: Array = StyleLibrary.stat_ids()
	for id: String in ids:
		his += float(his_stats.get(id, FighterState.DEFAULT_STAT))
		theirs += float(signature.get(id, FighterState.DEFAULT_STAT))
	return clampi(roundi((his - theirs) / maxf(1.0, ids.size())), -StyleLibrary.MAX_LEVEL, StyleLibrary.MAX_LEVEL)


## A teenager meets teenagers (16 or 17); a man meets men about his age.
static func opponent_age(his_age: int, rng: RandomNumberGenerator) -> int:
	if his_age < ADULT_AGE:
		return rng.randi_range(BackgroundLibrary.START_AGE, ADULT_AGE - 1)
	return clampi(his_age + rng.randi_range(-AGE_YOUNGER, AGE_OLDER), ADULT_AGE, OLDEST)


## The rules his next fight is under (a data/rulesets id).
static func rules_for(c: Career) -> String:
	if c.pro:
		return PRO_RULES
	return TEEN_RULES if c.age() < ADULT_AGE else ADULT_RULES


## What a fight pays him: {} as an amateur, else { show, win } in dollars.
static func purse_for(c: Career) -> Dictionary:
	if not c.pro:
		return {}
	var wins: int = int(c.record(true).win)
	return { "show": PURSE_SHOW + PURSE_STEP * wins, "win": PURSE_WIN + PURSE_STEP * wins }


## Whether he can turn pro now: old enough, enough amateur fights, not pro already and not booked.
static func can_turn_pro(c: Career) -> bool:
	return not c.pro and c.booked.is_empty() and c.age() >= PRO_AGE and amateur_fights(c) >= PRO_AFTER_FIGHTS


## The hub's word on turning pro (docs/08 §2, D314), once he's PRO_AGE and still amateur: { word (PRO_NOT_YET,
## PRO_WISE, PRO_RISKY or PRO_LATE), text }. {} before then, or once he's pro. Advice only: the choice is yours.
static func pro_advice(c: Career) -> Dictionary:
	if c.pro or c.age() < PRO_AGE:
		return {}
	var fights: int = amateur_fights(c)
	if fights < PRO_AFTER_FIGHTS:
		var more: int = PRO_AFTER_FIGHTS - fights
		return { "word": PRO_NOT_YET, "text": "He can turn pro after %d more amateur fight%s." % [more, "" if more == 1 else "s"] }
	var r: Dictionary = c.record(false)
	var decided: int = int(r.win) + int(r.loss)
	var share: float = float(r.win) / decided if decided > 0 else 0.0
	var level: float = average_stat(c.profile().get("stats", {}))
	var grade: String = TrainingCamp.grade(level)
	var record: String = c.record_text(false)
	if share < PRO_WIN_SHARE:
		return { "word": PRO_RISKY, "text": "Turning pro looks risky: %s as an amateur. A few more wins first." % record }
	if level < PRO_READY_AVG:
		return { "word": PRO_RISKY, "text": "Turning pro looks risky: %s as an amateur, but his skills (%s) aren't at a pro's level yet." % [record, grade] }
	if c.age() >= PRO_LATE_AGE:
		return { "word": PRO_LATE, "text": "Time to turn pro: %s as an amateur at %d, and every year he waits is a prime year gone." % [record, c.age()] }
	return { "word": PRO_WISE, "text": "Turning pro looks wise: %s as an amateur, and his skills (%s) are ready for a pro debut." % [record, grade] }


## His average over every stat (data/enums/stats; a missing one counts FighterState.DEFAULT_STAT).
static func average_stat(stats: Dictionary) -> float:
	var ids: Array = StyleLibrary.stat_ids()
	var total: float = 0.0
	for id: String in ids:
		total += float(stats.get(id, FighterState.DEFAULT_STAT))
	return total / maxf(1.0, ids.size())


static func amateur_fights(c: Career) -> int:
	return c.fights.filter(func(f: Dictionary) -> bool: return not bool(f.get("pro", false))).size()
