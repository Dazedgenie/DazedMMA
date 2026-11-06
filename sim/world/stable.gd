class_name Stable
extends RefCounted
## Your stable (docs/03 §14.5, D445): the world's men (D352) you've signed to fight out of your gym, beside the lad you
## raised. The first of D445's three pieces: who you can sign, how many, what you set for their training, the gym's cut
## of their purses, and leaving when they're unhappy. Their fights are still the world's (WorldWeeks); their offers and
## playing their fights come next, then their planner. On the gym (`gym.stable`, each a Lads.snapshot plus his `focus`,
## `unhappy` months and `why`), so they save with it; `gym.asked` keeps who said no and when.
##
##   places      one a PER_MEMBERS members, MIN_PLACES to MAX_PLACES, counting the lad you raised (places())
##   signing     the gym's lads, and up to PROSPECTS of his country's amateurs and local or regional pros AGES old (his
##               town's first); each says yes at yes_chance(): YES_BASE, YES_PER_TIER less a level up, YES_PER_LEVEL
##               more for every room and coach level at the gym, YES_LAD more for a lad who already trains there. A man
##               who says no can't be asked again for ASK_AGAIN_WEEKS
##   training    a focus you set once (data/enums/stable_focus.json): each week he grows BOOST more than the world's
##               men do on their own (WorldWeeks.change_a_week's growth), × the gym's rooms and coaches for his focus,
##               and the extra goes into his focus's stats (the world man's `gains`)
##   purses      a pro fight pays him his promotion's purse; the gym takes Gym.PURSE_CUT of it
##   leaving     each month he's unhappy if he's lost LOSSES_IN_A_ROW in a row, gone IDLE_WEEKS without a fight, or the gym
##               is behind on the rent; you're warned the first month, and after UNHAPPY_MONTHS in a row he leaves
##               (`gym.former`, so he can be offered against your lad)
##
## Pure and seeded: the career rolls the dice.

const FOCUS_PATH := "res://data/enums/stable_focus.json"
const PER_MEMBERS: int = 10
const MIN_PLACES: int = 2
const MAX_PLACES: int = 8
const PROSPECTS: int = 10
const AGES: Array[float] = [16.0, 30.0]
const TIERS: Array[String] = ["amateur", "local", "regional"]
const YES_BASE: float = 0.7
const YES_PER_TIER: float = 0.25
const YES_PER_LEVEL: float = 0.03
const YES_LAD: float = 0.2
const YES_RANGE: Array[float] = [0.05, 0.95]
const ASK_AGAIN_WEEKS: int = 13
const BOOST: float = 0.5
const LOSSES_IN_A_ROW: int = 3
const IDLE_WEEKS: int = 26
const UNHAPPY_MONTHS: int = 2
const DEFAULT_FOCUS := "all_round"
## Their fights (D445's second piece): booked LEAD_WEEKS ahead (a pro on his promotion's next card from then) against
## the world's man nearest his level within MATCH_GAP (WorldWeeks.pair_gap); turning one down makes him wait
## TURN_DOWN_WEEKS before the next is booked.
const LEAD_WEEKS: int = 3
const MATCH_GAP: float = 10.0
const TURN_DOWN_WEEKS: int = 4
const CARD_SEARCH_WEEKS: int = 12
## The news (`{ kind, name, … }`).
const SIGNED := "stable_signed"
const FOUGHT := "stable_fought"
const UNHAPPY := "stable_unhappy"
const LEFT := "stable_left"
const BOOKED := "stable_booked"
const FIGHT_NIGHT := "stable_fight_night"

static var _focuses: Dictionary = {}
static var _groups: Dictionary = {}


## The focuses: id → { name, about, group? (a stats group; none for all-round), kind (the session kind whose room
## counts) }, in the file's order.
static func focuses() -> Dictionary:
	if _focuses.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FOCUS_PATH))
		_focuses = parsed.get("values", {}) if parsed is Dictionary else {}
	return _focuses


static func focus(id: String) -> Dictionary:
	return focuses().get(id, focuses().get(DEFAULT_FOCUS, {}))


## The stats a focus trains: its group's, or every stat for all-round.
static func focus_stats(id: String) -> Array:
	if _groups.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/enums/stats.json"))
		_groups = parsed.get("values", {}) if parsed is Dictionary else {}
	var group: String = String(focus(id).get("group", ""))
	var out: Array = []
	for stat: String in StyleLibrary.stat_ids():
		if group == "" or String(_groups.get(stat, "")) == group:
			out.append(stat)
	return out


## The men you've signed, in the order they signed ([] for none).
static func fighters(gym: Dictionary) -> Array:
	return gym.get("stable", []) if gym.get("stable") is Array else []


static func in_stable(gym: Dictionary, id: String) -> bool:
	return not entry(gym, id).is_empty()


static func entry(gym: Dictionary, id: String) -> Dictionary:
	for f: Dictionary in fighters(gym):
		if String(f.get("id", "")) == id:
			return f
	return {}


## How many fighters the gym can run, the lad you raised among them: one a PER_MEMBERS members, MIN_PLACES to MAX_PLACES.
static func places(gym: Dictionary) -> int:
	return clampi(int(gym.get("members", 0)) / PER_MEMBERS, MIN_PLACES, MAX_PLACES)


## Places left for a signing (the lad you raised takes one).
static func free_places(gym: Dictionary) -> int:
	return maxi(0, places(gym) - 1 - fighters(gym).size())


## The men you could sign this week: the gym's lads who could, then up to PROSPECTS of his country's amateurs and local
## or regional pros AGES old, his town's first and then the best. Each is the world's man.
static func prospects(w: World, gym: Dictionary, week: int, names: NameLibrary = null) -> Array:
	var out: Array = []
	for lad: Dictionary in Lads.lads(gym):
		var m: Dictionary = w.man(String(lad.get("id", "")))
		if not m.is_empty() and World.active(m):
			out.append(m)
	var lib: NameLibrary = names if names != null else NameLibrary.shared()
	var town: Array = []
	var rest: Array = []
	for m: Dictionary in w.men.values():
		var id: String = String(m.get("id", ""))
		if not World.active(m) or Lads.at_gym(gym, id) or Lads.used_to(gym, id) or not String(m.get("tier", "")) in TIERS:
			continue
		var age: float = World.age_of(m, week)
		if age < AGES[0] or age > AGES[1]:
			continue
		if w.country_id != "" and lib.country_id_of(String(m.get("country", ""))) != w.country_id:
			continue
		(town if w.hometown != "" and String(m.get("hometown", "")) == w.hometown else rest).append(m)
	var best_first := func(a: Dictionary, b: Dictionary) -> bool:
		var aa: float = w.average(a)
		var ab: float = w.average(b)
		return aa > ab if aa != ab else String(a.id) < String(b.id)
	town.sort_custom(best_first)
	rest.sort_custom(best_first)
	out.append_array((town + rest).slice(0, PROSPECTS))
	return out


## How many levels of rooms and coaches the gym has: what a man weighs up before he signs.
static func gym_levels(gym: Dictionary) -> int:
	return Gym.levels(gym) + Staff.levels(gym)


## The chance he says yes (YES_RANGE): YES_BASE, less YES_PER_TIER for each level above amateur (TIERS), more
## YES_PER_LEVEL for every room and coach level, more YES_LAD when he already trains at your gym.
static func yes_chance(gym: Dictionary, m: Dictionary) -> float:
	var tier: int = maxi(0, TIERS.find(String(m.get("tier", "amateur"))))
	var out: float = YES_BASE - YES_PER_TIER * tier + YES_PER_LEVEL * gym_levels(gym)
	if Lads.at_gym(gym, String(m.get("id", ""))):
		out += YES_LAD
	return clampf(out, YES_RANGE[0], YES_RANGE[1])


## Why you can't ask him now ("" when you can).
static func cant_sign(gym: Dictionary, m: Dictionary, week: int) -> String:
	var id: String = String(m.get("id", ""))
	if in_stable(gym, id):
		return "He's in your stable"
	if not World.active(m):
		return "He's retired"
	if free_places(gym) <= 0:
		return "No place: one fighter per %d members" % PER_MEMBERS
	var asked: Dictionary = gym.get("asked", {}) if gym.get("asked") is Dictionary else {}
	if asked.has(id) and week - int(asked[id]) < ASK_AGAIN_WEEKS:
		var left: int = ASK_AGAIN_WEEKS - (week - int(asked[id]))
		return "He said no: ask again in %d week%s" % [left, "" if left == 1 else "s"]
	return ""


## Offers him a place: `roll` (0–1) under yes_chance signs him (off the lads, with `focus`) and returns "", else he says
## no (remembered in `gym.asked`) and it returns why. `gym` changes in place.
static func offer(w: World, gym: Dictionary, m: Dictionary, week: int, roll: float, focus_id: String = DEFAULT_FOCUS) -> String:
	var why: String = cant_sign(gym, m, week)
	if why != "":
		return why
	var id: String = String(m.get("id", ""))
	if roll >= yes_chance(gym, m):
		if not gym.get("asked") is Dictionary:
			gym.asked = {}
		gym.asked[id] = week
		return "%s said no. Better rooms and coaches make a yes likelier." % String(m.get("name", "He"))
	if not gym.get("stable") is Array:
		gym.stable = []
	gym.lads = Lads.lads(gym).filter(func(l: Dictionary) -> bool: return String(l.get("id", "")) != id)
	var e: Dictionary = Lads.snapshot(w, m, week)
	e.focus = focus_id if focuses().has(focus_id) else DEFAULT_FOCUS
	e.unhappy = 0
	e.why = ""
	(gym.stable as Array).append(e)
	return ""


## Lets him go: off the stable and onto `gym.former`. The entry, or {} when he wasn't signed.
static func release(gym: Dictionary, id: String) -> Dictionary:
	var e: Dictionary = entry(gym, id)
	if e.is_empty():
		return {}
	gym.stable = fighters(gym).filter(func(f: Dictionary) -> bool: return String(f.get("id", "")) != id)
	if not gym.get("former") is Array:
		gym.former = []
	if not id in gym.former:
		(gym.former as Array).append(id)
	return e


static func set_focus(gym: Dictionary, id: String, focus_id: String) -> bool:
	var e: Dictionary = entry(gym, id)
	if e.is_empty() or not focuses().has(focus_id):
		return false
	e.focus = focus_id
	return true


# --- What the gym does for them --------------------------------------------------------------------------------------

## His growth × this on top of the world's: 1 + BOOST × the gym's XP share for his focus (its kind's and rooms', and
## the coaches' for its group).
static func boost(gym: Dictionary, focus_id: String) -> float:
	var f: Dictionary = focus(focus_id)
	var share: float = Gym.xp_share(gym, String(f.get("kind", "sparring"))) * Staff.xp_share(gym, String(f.get("group", "")))
	return BOOST * share


## What the world needs to train the stable each week (World.trained): id → { stats (the focus's), boost }.
static func trained(gym: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for e: Dictionary in fighters(gym):
		var focus_id: String = String(e.get("focus", DEFAULT_FOCUS))
		out[String(e.get("id", ""))] = { "stats": focus_stats(focus_id), "boost": boost(gym, focus_id) }
	return out


## A week's extra growth for a signed man (`growth`: his own week's growth, WorldWeeks), put into his focus's stats so
## his average rises by `growth` × boost (the world man's `gains`, stat id → points).
static func train_week(m: Dictionary, growth: float, training: Dictionary) -> void:
	var extra: float = maxf(0.0, growth) * float(training.get("boost", 0.0))
	var stats: Array = training.get("stats", [])
	if extra <= 0.0 or stats.is_empty():
		return
	if not m.get("gains") is Dictionary:
		m.gains = {}
	var each: float = extra * float(StyleLibrary.stat_ids().size()) / float(stats.size())
	for stat: String in stats:
		m.gains[stat] = snappedf(float(m.gains.get(stat, 0.0)) + each, 0.0001)


## A pro fight's purse for him (Matchmaker's: his promotion's show, as much again for a win, both up PURSE_STEP a pro
## win); 0 for an amateur.
static func purse(w: World, m: Dictionary, won: bool) -> int:
	if not bool(m.get("pro", false)):
		return 0
	var p: Dictionary = Promotions.of(w, m)
	var wins: int = int(m.get("record", {}).get("win", 0))
	var show: int = int(p.get("show", Matchmaker.PURSE_SHOW)) + Matchmaker.PURSE_STEP * wins
	var win: int = int(p.get("win", Matchmaker.PURSE_WIN)) + Matchmaker.PURSE_STEP * wins
	return show + (win if won else 0)


## The world's fights (WorldWeeks results) for your stable: the gym's cut of each pro purse, and the news. Returns
## { cut (dollars), news: [{ kind FOUGHT, name, opponent, result (win, loss or draw), method, cut }] }.
static func after_fights(w: World, gym: Dictionary, results: Array) -> Dictionary:
	var out := { "cut": 0, "news": [] }
	for r: Dictionary in results:
		if String(r.get("kind", "")) != "fight":
			continue
		for side: String in ["a", "b"]:
			var id: String = String(r.get(side, ""))
			if not in_stable(gym, id):
				continue
			var m: Dictionary = w.man(id)
			var other: Dictionary = w.man(String(r.get("b" if side == "a" else "a", "")))
			var winner: String = String(r.get("winner", ""))
			var result: String = "draw" if winner == "" or winner == "draw" else ("win" if winner == side or winner == id else "loss")
			var cut: int = Gym.purse_cut(purse(w, m, result == "win"))
			out.cut = int(out.cut) + cut
			(out.news as Array).append({ "kind": FOUGHT, "name": String(m.get("name", "")), "opponent": String(other.get("name", "")),
				"result": result, "method": String(r.get("method", "")), "cut": cut })
	return out


# --- Their fights (D445's second piece) -------------------------------------------------------------------------------

## The men your stable's bookings hold back from the world's own pairings: each booked man and his opponent.
static func busy(gym: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for e: Dictionary in fighters(gym):
		var b: Dictionary = booking(e)
		if not b.is_empty():
			out[String(e.get("id", ""))] = true
			out[String(b.get("opponent", ""))] = true
	return out


## A man's booked fight: { opponent (a world man's id), week, card ("NCC 14" or ""), promotion, ruleset }, or {}.
static func booking(e: Dictionary) -> Dictionary:
	return e.booked if e.get("booked") is Dictionary else {}


## The bookings whose fight night is `week`: [{ id, entry, booking }], in the stable's order.
static func due(gym: Dictionary, week: int) -> Array:
	var out: Array = []
	for e: Dictionary in fighters(gym):
		var b: Dictionary = booking(e)
		if not b.is_empty() and int(b.get("week", -1)) == week:
			out.append({ "id": String(e.get("id", "")), "entry": e, "booking": b })
	return out


## The rules his fight is under: pro, or amateur by his age on the night (Matchmaker's).
static func ruleset_for(m: Dictionary, week: int) -> String:
	if bool(m.get("pro", false)):
		return Matchmaker.PRO_RULES
	return Matchmaker.TEEN_RULES if World.age_of(m, week) < float(Matchmaker.ADULT_AGE) else Matchmaker.ADULT_RULES


## Books a fight for each man who's due one by LEAD_WEEKS from `week` and hasn't one (not a champion or the man next
## in line: their fights are the belt's, Titles). `held` is men who can't be booked (the career's own opponents and
## offers). Returns the news: [{ kind BOOKED, name, opponent, week, card }].
static func book(w: World, gym: Dictionary, week: int, held: Dictionary = {}) -> Array:
	var news: Array = []
	var taken: Dictionary = held.duplicate()
	taken.merge(busy(gym))
	for e: Dictionary in fighters(gym):
		var id: String = String(e.get("id", ""))
		var m: Dictionary = w.man(id)
		if not booking(e).is_empty() or m.is_empty() or not World.active(m):
			continue
		if Titles.held_by(w, id) != "" or Titles.waiting(w).has(id):
			continue
		var on: int = maxi(week + LEAD_WEEKS, maxi(int(m.get("out_until", 0)), int(e.get("wait_until", 0))))
		if int(m.get("next_week", 0)) > week + LEAD_WEEKS or on > week + LEAD_WEEKS:
			continue
		var p: Dictionary = Promotions.of(w, m)
		if bool(m.get("pro", false)) and not p.is_empty():
			var found: bool = false
			for i in CARD_SEARCH_WEEKS:
				if Promotions.has_card(p, on + i):
					on += i
					found = true
					break
			if not found:
				continue
		var opp: Dictionary = find_opponent(w, gym, m, on, taken)
		if opp.is_empty():
			continue
		taken[String(opp.id)] = true
		e.booked = { "opponent": String(opp.id), "opponent_name": String(opp.get("name", "")), "week": on, "card": String(Promotions.card(w, p, on).short) if not p.is_empty() else "",
			"promotion": String(p.get("id", "")), "ruleset": ruleset_for(m, on) }
		news.append({ "kind": BOOKED, "name": String(m.get("name", "")), "opponent": String(opp.get("name", "")), "week": on,
			"card": String(e.booked.card) })
	return news


## The world's man nearest `m`'s level who could fight him on `on`: same division, pro with pro on his promotion,
## amateur with amateur of his age group (under or over 18), not at your gym, not a champion or next in line, not
## hurt, not met lately, not `taken`, due a fight by then; within MATCH_GAP. {} when there's nobody.
static func find_opponent(w: World, gym: Dictionary, m: Dictionary, on: int, taken: Dictionary = {}) -> Dictionary:
	var division: String = World.division_of(m, on)
	var teen: bool = World.age_of(m, on) < float(Matchmaker.ADULT_AGE)
	var best: Dictionary = {}
	var best_gap: float = MATCH_GAP
	var ids: Array = w.men.keys()
	ids.sort()
	for oid: String in ids:
		var o: Dictionary = w.men[oid]
		if oid == String(m.get("id", "")) or taken.has(oid) or not World.active(o) or Lads.at_gym(gym, oid):
			continue
		if bool(o.get("pro", false)) != bool(m.get("pro", false)) or World.division_of(o, on) != division:
			continue
		if bool(m.get("pro", false)) and String(o.get("promotion", "")) != String(m.get("promotion", "")):
			continue
		if not bool(m.get("pro", false)) and (World.age_of(o, on) < float(Matchmaker.ADULT_AGE)) != teen:
			continue
		if World.age_of(o, on) < float(BackgroundLibrary.START_AGE):
			continue
		if int(o.get("out_until", 0)) > on or int(o.get("next_week", 0)) > on or WorldWeeks._met_lately(m, oid, on):
			continue
		if Titles.held_by(w, oid) != "" or Titles.waiting(w).has(oid):
			continue
		var gap: float = WorldWeeks.pair_gap(w, m, o)
		if gap < best_gap:
			best_gap = gap
			best = o
	return best


## Turns his booked fight down: the other man's free again, and he isn't booked again for TURN_DOWN_WEEKS. False when
## he has nothing booked.
static func turn_down(gym: Dictionary, id: String, week: int) -> bool:
	var e: Dictionary = entry(gym, id)
	if booking(e).is_empty():
		return false
	e.booked = {}
	e.wait_until = week + TURN_DOWN_WEEKS
	return true


## His booked fight's result onto the world (played or simmed on the fight screen, or the quick result for one left
## alone): `result` his (win, loss or draw), `method` (ko, submission, decision, draw, or the fight screen's words),
## `round`. The booking's gone, the result's in the world's results, and the gym's cut and the news as after_fights.
## Returns { result (WorldWeeks.record's), cut, news } ({} when he had nothing booked).
static func settle(w: World, gym: Dictionary, id: String, result: String, method: String, round: int, seed_value: int) -> Dictionary:
	var e: Dictionary = entry(gym, id)
	var b: Dictionary = booking(e)
	if b.is_empty():
		return {}
	var m: Dictionary = w.man(id)
	var o: Dictionary = w.man(String(b.opponent))
	e.booked = {}
	if m.is_empty() or o.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var winner: String = { "win": "a", "loss": "b" }.get(result, "draw")
	var r: Dictionary = WorldWeeks.record(w, m, o, int(b.week), { "winner": winner, "method": WorldWeeks._method(method), "round": round },
		ResultModel.win_chance(String(m.style), w.average(m), String(o.style), w.average(o)), rng)
	w.results.append(r)
	Promotions.after_fight(w, m, int(b.week))
	Promotions.after_fight(w, o, int(b.week))
	var paid: Dictionary = after_fights(w, gym, [r])
	return { "result": r, "cut": int(paid.cut), "news": paid.news }


## A booked fight nobody opened by the end of its week (or one in his camp): the world's quick result decides it
## (WorldWeeks' model). Returns settle()'s, or {} when it isn't due by `week`.
static func quick(w: World, gym: Dictionary, id: String, week: int, seed_value: int) -> Dictionary:
	var e: Dictionary = entry(gym, id)
	var b: Dictionary = booking(e)
	if b.is_empty() or int(b.week) > week:
		return {}
	var m: Dictionary = w.man(id)
	var o: Dictionary = w.man(String(b.opponent))
	if m.is_empty() or o.is_empty() or not World.active(m) or not World.active(o):
		e.booked = {}  # One of them has gone: the fight's off.
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var r: Dictionary = ResultModel.decide(String(m.style), w.average(m), String(o.style), w.average(o), rng, 3,
		WorldWeeks.nudge_for(m, int(b.week)) - WorldWeeks.nudge_for(o, int(b.week)))
	var result: String = { "a": "win", "b": "loss" }.get(String(r.winner), "draw")
	return settle(w, gym, id, result, String(r.method), int(r.round), seed_value)


# --- Happiness ---------------------------------------------------------------------------------------------------------

## Why he's unhappy now ([] when he isn't): a losing run, waiting for a fight, the gym behind on the rent.
static func unhappy_reasons(m: Dictionary, e: Dictionary, week: int, gym_money: int) -> Array[String]:
	var out: Array[String] = []
	var history: Array = m.get("history", [])
	if history.size() >= LOSSES_IN_A_ROW and history.slice(-LOSSES_IN_A_ROW).all(func(h: Array) -> bool: return String(h[2]) == "l"):
		out.append("%d losses in a row" % LOSSES_IN_A_ROW)
	var last: int = int(history[-1][0]) if not history.is_empty() else -1
	if week - maxi(last, int(e.get("since", week))) >= IDLE_WEEKS and booking(e).is_empty():
		out.append("six months without a fight")
	if gym_money < 0:
		out.append("the gym's behind on the rent")
	return out


## The stable's month (D445): snapshots refreshed, a man who's retired gone, and each one happy or not; a man unhappy
## UNHAPPY_MONTHS in a row leaves. `gym` changes in place. Returns the news, oldest first:
## [{ kind (UNHAPPY or LEFT), name, why, retired? }].
static func month(w: World, gym: Dictionary, week: int, gym_money: int) -> Array:
	var news: Array = []
	var keep: Array = []
	for e: Dictionary in fighters(gym):
		var id: String = String(e.get("id", ""))
		var m: Dictionary = w.man(id)
		if m.is_empty() or not World.active(m):
			_to_former(gym, id)
			news.append({ "kind": LEFT, "name": String(e.get("name", "")), "why": "retired", "retired": true })
			continue
		var fresh: Dictionary = Lads.snapshot(w, m, int(e.get("since", week)))
		fresh.focus = String(e.get("focus", DEFAULT_FOCUS))
		for key: String in ["booked", "wait_until"]:  # His booked fight and any wait after turning one down.
			if e.has(key):
				fresh[key] = e[key]
		var why: Array[String] = unhappy_reasons(m, e, week, gym_money)
		fresh.unhappy = int(e.get("unhappy", 0)) + 1 if not why.is_empty() else 0
		fresh.why = ", ".join(PackedStringArray(why))
		if int(fresh.unhappy) >= UNHAPPY_MONTHS:
			_to_former(gym, id)
			news.append({ "kind": LEFT, "name": String(fresh.name), "why": String(fresh.why) })
			continue
		if int(fresh.unhappy) > 0:
			news.append({ "kind": UNHAPPY, "name": String(fresh.name), "why": String(fresh.why) })
		keep.append(fresh)
	gym.stable = keep
	return news


static func _to_former(gym: Dictionary, id: String) -> void:
	if not gym.get("former") is Array:
		gym.former = []
	if not id in gym.former:
		(gym.former as Array).append(id)


## The news's words.
static func news_text(event: Dictionary) -> String:
	var name: String = String(event.get("name", ""))
	match String(event.get("kind", "")):
		SIGNED:
			return "%s signed to fight out of your gym" % name
		BOOKED:
			return "%s is booked to fight %s%s" % [name, String(event.get("opponent", "")),
				" on %s" % String(event.card) if String(event.get("card", "")) != "" else ""]
		FIGHT_NIGHT:
			return "Fight night for %s: %s this Saturday. Play it or sim it from the hub" % [name, String(event.get("opponent", ""))]
		FOUGHT:
			var how: String = String({ "ko": "knockout", "submission": "submission", "decision": "decision" }.get(String(event.get("method", "")), ""))
			var line: String = "%s %s %s%s" % [name, {"win": "beat", "loss": "lost to", "draw": "drew with"}.get(String(event.get("result", "")), "fought"),
				String(event.get("opponent", "")), " by %s" % how if how != "" and String(event.get("result", "")) != "draw" else ""]
			if int(event.get("cut", 0)) > 0:
				line += " · the gym's cut $%d" % int(event.cut)
			return line
		UNHAPPY:
			return "%s is unhappy (%s): put it right or he'll leave next month" % [name, String(event.get("why", ""))]
		LEFT:
			if bool(event.get("retired", false)):
				return "%s has retired and left your stable" % name
			return "%s has left your stable (%s)" % [name, String(event.get("why", ""))]
	return name
