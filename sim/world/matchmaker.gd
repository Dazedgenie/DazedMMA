class_name Matchmaker
extends RefCounted
## Fight offers for a career (docs/03 §10.4, D304). While he's free (not booked, hurt or suspended), a set of
## OFFERS_MIN–OFFERS_MAX offers comes in every few weeks and stays open OPEN_WEEKS weeks. Each is a new man made from
## one of the 15 style sheets (StyleLibrary.generate, D160) with a name and hometown (NameLibrary), set a bit easier,
## about even or a bit harder than him, on a date CAMP_WEEKS_MIN–CAMP_WEEKS_MAX weeks away (the camp's length), under
## the rules his age and record call for, for a purse once he's pro.
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


## A set of offers for this career this week: OFFERS_MIN–OFFERS_MAX, each a different style. Two offers are one about
## even and one easier or harder; three are one of each.
func make_offers(c: Career, rng: RandomNumberGenerator) -> Array:
	var count: int = rng.randi_range(OFFERS_MIN, OFFERS_MAX)
	var kinds: Array[String] = DIFFICULTIES.duplicate()
	if count < kinds.size():
		kinds = ["even", "easier" if rng.randf() < 0.5 else "harder"]
		kinds.sort_custom(func(a: String, b: String) -> bool: return DIFFICULTIES.find(a) < DIFFICULTIES.find(b))
	var style_ids: Array = styles.ids().duplicate()
	style_ids.sort()
	var out: Array = []
	for i in count:
		var style_id: String = String(style_ids.pop_at(rng.randi_range(0, style_ids.size() - 1)))
		out.append(make_offer(c, style_id, kinds[i], rng, i))
	return out


## One offer: { id, profile (the opponent, fighter@1), about (nickname, hometown, country), style, difficulty,
## week (fight night is that week's Saturday), expires (the last week it's open), ruleset, pro, purse ({show, win} or {}) }.
func make_offer(c: Career, style_id: String, difficulty: String, rng: RandomNumberGenerator, index: int = 0) -> Dictionary:
	var person: Dictionary = names.roll(rng)
	var id: String = "opp_w%d_%d" % [c.week, index]
	var level: int = level_against(c.profile().stats, style_id) + int(DIFFICULTY_LEVELS.get(difficulty, 0)) \
		+ rng.randi_range(-LEVEL_SPREAD, LEVEL_SPREAD)
	var p: Dictionary = styles.generate(style_id, rng.randi(), level, roster, id, String(person.name))
	p.age = opponent_age(c.age(), rng)
	var camp: int = rng.randi_range(CAMP_WEEKS_MIN + OPEN_WEEKS - 1, CAMP_WEEKS_MAX)
	return {
		"id": id, "profile": p,
		"about": { "nickname": String(person.nickname), "hometown": String(person.hometown), "country": String(person.country) },
		"style": style_id, "difficulty": difficulty,
		"week": c.week + camp - 1, "expires": c.week + OPEN_WEEKS - 1,
		"ruleset": rules_for(c), "pro": c.pro, "purse": purse_for(c),
	}


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


static func amateur_fights(c: Career) -> int:
	return c.fights.filter(func(f: Dictionary) -> bool: return not bool(f.get("pro", false))).size()
