class_name Lads
extends RefCounted
## The gym's other fighters (docs/03 §14.4, D444; phase 4's sparring partners, D407): real men from the world (D352)
## who train at your gym, the amateurs and young pros of his town first, then his country. They keep fighting on the
## world's cards, so their records grow. On the gym (`gym.lads`, a snapshot of each: id, name, style, born, avg, record,
## since), so they save with it; the world's own man is the truth and the snapshot is refreshed each month.
##
##   how many   one a MEMBERS_PER_LAD members, at least MIN_LADS and at most MAX_LADS (room()). Each month, while there's
##              room, one walks in at WALK_IN_CHANCE; each lad leaves at LEAVE_CHANCE (and a man who retires goes)
##   sparring   a session with a partner (data/sessions `partner`: sparring, rolling, wrestling and clinch drills, Shark
##              tank) learns faster with a better partner: his best lad's average stat against his own, up to
##              PARTNER_UP more at PARTNER_SPREAD points better, down to PARTNER_DOWN less with only weaker ones or none
##   offers     a gym-mate is never offered against him (Matchmaker.pick_man); a man who's left (`gym.former`) can be,
##              and the offer says he used to train with you
##
## Pure and seeded: the same month always brings the same walk-in.

const MEMBERS_PER_LAD: int = 8
const MIN_LADS: int = 2
const MAX_LADS: int = 8
const WALK_IN_CHANCE: float = 0.35
const LEAVE_CHANCE: float = 0.05
## Sparring with a partner: up to PARTNER_UP more XP when his best lad is PARTNER_SPREAD points of average stat better,
## down to PARTNER_DOWN less when he's that much worse (or there's nobody).
const PARTNER_UP: float = 0.15
const PARTNER_DOWN: float = 0.10
const PARTNER_SPREAD: float = 10.0
## The ages a lad can be when he walks in, and the world's levels (World.LEVELS) he can be from.
const AGES: Array[float] = [15.0, 30.0]
const TIERS: Array[String] = ["amateur", "local", "regional"]
## The news: a lad walked in or left (`{ kind, name }`).
const WALKED_IN := "lad_in"
const LEFT := "lad_left"


## The gym's lads, in the order they came ([] for none, or a gym saved before D444).
static func lads(gym: Dictionary) -> Array:
	return gym.get("lads", []) if gym.get("lads") is Array else []


## Whether this world man trains at your gym: one of its lads, or signed to your stable (Stable, D445).
static func at_gym(gym: Dictionary, id: String) -> bool:
	for lad: Dictionary in lads(gym):
		if String(lad.get("id", "")) == id:
			return true
	return Stable.in_stable(gym, id)


## Whether he used to train at your gym.
static func used_to(gym: Dictionary, id: String) -> bool:
	return id in (gym.get("former", []) as Array) if gym.get("former") is Array else false


## How many lads the gym has room for: one a MEMBERS_PER_LAD members, MIN_LADS to MAX_LADS.
static func room(gym: Dictionary) -> int:
	return clampi(int(gym.get("members", 0)) / MEMBERS_PER_LAD, MIN_LADS, MAX_LADS)


## A lad's snapshot from the world's man.
static func snapshot(w: World, m: Dictionary, since: int) -> Dictionary:
	return { "id": String(m.get("id", "")), "name": String(m.get("name", "")), "style": String(m.get("style", "")),
		"born": float(m.get("born", 0.0)), "avg": snappedf(w.average(m), 0.1), "record": World.record_text(m),
		"pro": bool(m.get("pro", false)), "country": String(m.get("country", "")), "since": since }


## The world's men who could walk in: still fighting, AGES old, an amateur or a local or regional pro, from his country
## (anywhere when he has none), not at the gym and never left it. His town's men first, then by id, so it's the same
## every time.
static func candidates(w: World, gym: Dictionary, week: int, names: NameLibrary = null) -> Array:
	var lib: NameLibrary = names if names != null else NameLibrary.shared()
	var town: Array = []
	var rest: Array = []
	var ids: Array = w.men.keys()
	ids.sort()
	for id: String in ids:
		var m: Dictionary = w.men[id]
		if not World.active(m) or at_gym(gym, id) or used_to(gym, id) or not String(m.get("tier", "")) in TIERS:
			continue
		var age: float = World.age_of(m, week)
		if age < AGES[0] or age > AGES[1]:
			continue
		if w.country_id != "" and lib.country_id_of(String(m.get("country", ""))) != w.country_id:
			continue
		(town if w.hometown != "" and String(m.get("hometown", "")) == w.hometown else rest).append(m)
	return town + rest


## Fills an empty gym with its first MIN_LADS lads (his town's first). Returns the ones who came.
static func first_lads(w: World, gym: Dictionary, week: int, dice: RandomNumberGenerator) -> Array:
	var came: Array = []
	if gym.is_empty() or gym.has("lads"):
		return came
	gym.lads = []
	gym.former = []
	var pool: Array = candidates(w, gym, week)
	while came.size() < mini(MIN_LADS, room(gym)) and not pool.is_empty():
		var m: Dictionary = _pick(pool, dice)
		pool.erase(m)
		(gym.lads as Array).append(snapshot(w, m, week))
		came.append(gym.lads[-1])
	return came


## The gym's month for its lads (D444): their snapshots refreshed from the world, a man who's retired gone, each lad may
## leave, and one may walk in while there's room. `gym` changes in place. Returns the news, oldest first:
## [{ kind (WALKED_IN or LEFT), name, gym (its name), retired? }].
static func month(w: World, gym: Dictionary, week: int, dice: RandomNumberGenerator) -> Array:
	var news: Array = []
	if gym.is_empty():
		return news
	if not gym.has("lads"):
		first_lads(w, gym, week, dice)
		return news
	if not gym.get("former") is Array:
		gym.former = []
	var keep: Array = []
	for lad: Dictionary in lads(gym):
		var m: Dictionary = w.man(String(lad.get("id", "")))
		var leaves: bool = dice.randf() < LEAVE_CHANCE
		if m.is_empty() or not World.active(m) or leaves:
			(gym.former as Array).append(String(lad.id))
			news.append({ "kind": LEFT, "name": String(lad.get("name", "")), "retired": not m.is_empty() and not World.active(m),
				"gym": String(gym.get("name", "")) })
			continue
		var fresh: Dictionary = snapshot(w, m, int(lad.get("since", week)))
		keep.append(fresh)
	gym.lads = keep
	var walk_in: float = dice.randf()
	if keep.size() < room(gym) and walk_in < WALK_IN_CHANCE:
		var pool: Array = candidates(w, gym, week)
		if not pool.is_empty():
			var m: Dictionary = _pick(pool, dice)
			(gym.lads as Array).append(snapshot(w, m, week))
			news.append({ "kind": WALKED_IN, "name": String(m.get("name", "")), "gym": String(gym.get("name", "")) })
	return news


## One of the first dozen in the pool (his town's men come first).
static func _pick(pool: Array, dice: RandomNumberGenerator) -> Dictionary:
	return pool[dice.randi_range(0, mini(pool.size(), 12) - 1)]


# --- What they do -----------------------------------------------------------------------------------------------------

## The best partner's average stat (-1 with nobody): the lads' and your stable's (D445).
static func best_avg(gym: Dictionary) -> float:
	var best: float = -1.0
	for lad: Dictionary in lads(gym) + Stable.fighters(gym):
		best = maxf(best, float(lad.get("avg", 0.0)))
	return best


## Session XP × this for a session with a partner (`partner` in data/sessions) at your gym, his average stat `his`
## against his best lad's (1 with no gym, or a session without a partner).
static func partner_share(gym: Dictionary, his: float, session: Dictionary) -> float:
	if gym.is_empty() or not bool(session.get("partner", false)) or not gym.has("lads"):
		return 1.0
	var best: float = best_avg(gym)
	if best < 0.0:
		return 1.0 - PARTNER_DOWN
	var gap: float = clampf((best - his) / PARTNER_SPREAD, -1.0, 1.0)
	return 1.0 + gap * (PARTNER_UP if gap > 0.0 else PARTNER_DOWN)


## How a lad compares with him, in words: "Better than him", "About even", "Still learning".
static func compare_text(lad: Dictionary, his: float) -> String:
	var gap: float = float(lad.get("avg", 0.0)) - his
	if gap >= 3.0:
		return "Better than him" if gap < 8.0 else "Well ahead of him"
	if gap <= -3.0:
		return "Still learning" if gap > -8.0 else "Well behind him"
	return "About even"


## The news's words: "Jake Moss walked in to train at Hill's Gym", "Jake Moss has left the gym".
static func news_text(event: Dictionary, gym_name: String = "") -> String:
	if gym_name == "":
		gym_name = String(event.get("gym", ""))
	if String(event.get("kind", "")) == WALKED_IN:
		return "%s walked in to train at %s" % [String(event.get("name", "")), gym_name if gym_name != "" else "your gym"]
	if bool(event.get("retired", false)):
		return "%s has retired and left the gym" % String(event.get("name", ""))
	return "%s has left the gym to train somewhere else" % String(event.get("name", ""))
