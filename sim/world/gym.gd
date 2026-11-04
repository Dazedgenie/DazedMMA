class_name Gym
extends RefCounted
## Your gym (docs/03 §11.3 and §14.1, D313, D441): the place you open in his hometown, and where he walks in at 16. You
## own it (Kyle, 2026-11-04: "Yes, a small run-down place"). A new career offers three run-down places (offers()): a
## lock-up garage, a unit on the estate and an old hall (data/enums/gym_places), each one of the five kinds in
## data/gyms/ (docs/09 gym@1) with a culture from data/enums/gym_cultures and a name. The one you pick changes his
## training and is your business:
##
##   kind     each session kind's XP × the kind's `xp` (a boxing gym's striking 1.2, its grappling 0.7; missing = 1)
##   culture  skips × `skips` (a family gym 0.75, a party gym 1.5), injury odds × `injury` and sparring XP × `sparring_xp`
##            (hard sparring 1.5 and 1.2)
##   money    the gym's own bank (Career.gym_money), apart from his savings. On the first Monday of every month its
##            members pay their dues (the kind's `fee`) and the rent goes out (month()); the gym takes PURSE_CUT of
##            every purse he's paid (Kyle: "Members plus a cut of purses"). Members drift towards a number that grows
##            with his wins, up to what the place holds.
##
## A gym is plain data on the career ({kind, culture, place, name, owner_name, owner, dues, members, members_start,
## rent}), so it saves as it is. `owner_name` and `owner` are the man you take the place over from. Pure and seeded:
## the same career seed offers the same three places.

const DEFAULT_DIR := "res://data/gyms/"
const CULTURES_PATH := "res://data/enums/gym_cultures.json"
const PLACES_PATH := "res://data/enums/gym_places.json"
## How many places a new career offers, one of each in data/enums/gym_places. The first is always a kind that suits
## where he comes from (a kind whose `backgrounds` has his).
const OFFERS: int = 3
## The gym's money (D441): what you put in to open it ($), the share of every purse it takes, the rent as a share of
## what its first members pay (rounded to $10: tight, Kyle's pick on the first year), each of his wins bringing this
## many more members in (up to the place's `cap`), and the chance one drifts off in a month.
const START_MONEY: int = 500
const PURSE_CUT: float = 0.15
const RENT_SHARE: float = 0.85
const MEMBERS_PER_WIN: int = 2
const LEAVE_CHANCE: float = 0.25
## An old save's gym (before D441, when he paid a fee at someone else's): it becomes yours, as a unit with this many
## members.
const OLD_SAVE_PLACE := "unit"
const OLD_SAVE_MEMBERS: int = 16

static var _kinds: Dictionary = {}  # id → gym@1
static var _kind_ids: Array = []
static var _cultures: Dictionary = {}
static var _places: Dictionary = {}


static func kinds() -> Dictionary:
	if _kinds.is_empty():
		var files: PackedStringArray = DirAccess.get_files_at(DEFAULT_DIR)
		files.sort()
		for file in files:
			if file.ends_with(".json"):
				var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DEFAULT_DIR.path_join(file)))
				if parsed is Dictionary:
					_kinds[String(parsed.id)] = parsed
					_kind_ids.append(String(parsed.id))
	return _kinds


## The kinds' ids, sorted.
static func kind_ids() -> Array:
	kinds()
	return _kind_ids.duplicate()


static func kind(id: String) -> Dictionary:
	return kinds().get(id, {})


## The cultures: id → { name, about, skips, injury, sparring_xp }, in the file's order.
static func cultures() -> Dictionary:
	if _cultures.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CULTURES_PATH))
		if data is Dictionary:
			_cultures = data.get("values", {})
	return _cultures


static func culture(id: String) -> Dictionary:
	return cultures().get(id, {})


## The places you can open in: id → { name, about, members: [low, high], cap }, in the file's order.
static func places() -> Dictionary:
	if _places.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLACES_PATH))
		if data is Dictionary:
			_places = data.get("values", {})
	return _places


static func place(id: String) -> Dictionary:
	return places().get(id, {})


## The three places a new career offers in his hometown (`city`, named from `country_id`), for his `background`:
## three different kinds, the first one that suits his background, and one of each place in a rolled order. Each
## { kind, culture, place, name, owner_name, owner, dues, members, members_start, rent }.
static func offers(city: String, country_id: String, background: String, career_seed: int, names: NameLibrary = null) -> Array:
	var lib: NameLibrary = names if names != null else NameLibrary.shared()
	var rng := RandomNumberGenerator.new()
	rng.seed = ("gyms:%d" % career_seed).hash()
	var pool: Array = kind_ids()
	var picked: Array = []
	var suits: Array = pool.filter(func(id: String) -> bool: return background in kind(id).get("backgrounds", []))
	if not suits.is_empty():
		picked.append(suits[rng.randi_range(0, suits.size() - 1)])
	while picked.size() < mini(OFFERS, pool.size()):
		var id: String = pool[rng.randi_range(0, pool.size() - 1)]
		if not id in picked:
			picked.append(id)
	var culture_ids: Array = cultures().keys()
	var place_ids: Array = places().keys()
	for i in range(place_ids.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Variant = place_ids[i]
		place_ids[i] = place_ids[j]
		place_ids[j] = swap
	var out: Array = []
	for n in picked.size():
		var id: String = picked[n]
		var k: Dictionary = kind(id)
		var owner_name: String = lib.random_name(rng, country_id)
		var surname: String = owner_name.get_slice(" ", owner_name.get_slice_count(" ") - 1)
		var pattern: String = String(_pick(rng, k.get("names", ["{city} Gym"])))
		var fee: Array = k.get("fee", [50, 50])
		var where: String = String(place_ids[n % place_ids.size()]) if not place_ids.is_empty() else ""
		var span: Array = place(where).get("members", [OLD_SAVE_MEMBERS, OLD_SAVE_MEMBERS])
		var dues: int = rng.randi_range(int(fee[0]), int(fee[1]))
		var members: int = rng.randi_range(int(span[0]), int(span[1]))
		out.append({
			"kind": id, "culture": String(_pick(rng, culture_ids)) if not culture_ids.is_empty() else "",
			"place": where, "name": pattern.format({ "city": city, "surname": surname }),
			"owner_name": owner_name, "owner": String(_pick(rng, k.get("owners", [""]))),
			"dues": dues, "members": members, "members_start": members, "rent": rent_for(members, dues),
		})
	return out


## The rent on a place whose first `members` pay `dues` a month: RENT_SHARE of it, to the nearest $10.
static func rent_for(members: int, dues: int) -> int:
	return roundi(members * dues * RENT_SHARE / 10.0) * 10


## A gym saved before D441 (his fee at someone else's gym) made yours: a unit, its fee now what a member pays. A copy;
## a gym that's already yours comes back as it is.
static func made_yours(gym: Dictionary) -> Dictionary:
	var out: Dictionary = gym.duplicate(true)
	if out.is_empty() or out.has("place"):
		return out
	var dues: int = int(out.get("fee", 50))
	out.erase("fee")
	out.place = OLD_SAVE_PLACE
	out.dues = dues
	out.members = OLD_SAVE_MEMBERS
	out.members_start = OLD_SAVE_MEMBERS
	out.rent = rent_for(OLD_SAVE_MEMBERS, dues)
	return out


## What the members pay in a month ($).
static func dues_in(gym: Dictionary) -> int:
	return int(gym.get("members", 0)) * int(gym.get("dues", 0))


## A month's dues less the rent ($, below 0 when the rent's more).
static func month_net(gym: Dictionary) -> int:
	return dues_in(gym) - int(gym.get("rent", 0))


## The gym's share of a purse ($).
static func purse_cut(paid: int) -> int:
	return roundi(maxi(0, paid) * PURSE_CUT)


## How many members the gym is heading towards with `wins` wins behind him: its first members and MEMBERS_PER_WIN a
## win, never more than the place holds.
static func members_target(gym: Dictionary, wins: int) -> int:
	var cap: int = int(place(String(gym.get("place", ""))).get("cap", 999))
	return clampi(int(gym.get("members_start", gym.get("members", 0))) + MEMBERS_PER_WIN * wins, 0, cap)


## The gym's month as it turns (D441), on the first Monday: the members pay their dues, the rent goes out, then the
## members move one towards members_target (two when they're five or more off) and one may drift away. `gym` changes
## in place; `dice` rolls the drift. Returns { dues, rent, net, members (after), joined (± change) }.
static func month(gym: Dictionary, wins: int, dice: RandomNumberGenerator) -> Dictionary:
	var paid: int = dues_in(gym)
	var rent: int = int(gym.get("rent", 0))
	var before: int = int(gym.get("members", 0))
	var target: int = members_target(gym, wins)
	var now: int = before
	if now < target:
		now += 2 if target - now >= 5 else 1
	elif now > target:
		now -= 1
	if now > 0 and dice.randf() < LEAVE_CHANCE:
		now -= 1
	gym.members = now
	return { "dues": paid, "rent": rent, "net": paid - rent, "members": now, "joined": now - before }


## "A unit on the estate · 16 members at $40 a month · rent $540".
static func money_line(gym: Dictionary) -> String:
	if gym.is_empty():
		return ""
	var bits: Array[String] = []
	var where: String = String(place(String(gym.get("place", ""))).get("name", ""))
	if where != "":
		bits.append(where)
	bits.append("%d members at $%d a month" % [int(gym.get("members", 0)), int(gym.get("dues", 0))])
	bits.append("rent $%d" % int(gym.get("rent", 0)))
	return " · ".join(bits)


## Session XP × this for a session of this kind (data/sessions `kind`) at this gym (1 with no gym).
static func xp_share(gym: Dictionary, session_kind: String) -> float:
	if gym.is_empty():
		return 1.0
	var out: float = float(kind(String(gym.get("kind", ""))).get("xp", {}).get(session_kind, 1.0))
	if session_kind == "sparring":
		out *= float(culture(String(gym.get("culture", ""))).get("sparring_xp", 1.0))
	return out


## The chance a party animal skips × this.
static func skip_share(gym: Dictionary) -> float:
	return float(culture(String(gym.get("culture", ""))).get("skips", 1.0)) if not gym.is_empty() else 1.0


## A session's injury odds × this.
static func injury_share(gym: Dictionary) -> float:
	return float(culture(String(gym.get("culture", ""))).get("injury", 1.0)) if not gym.is_empty() else 1.0


## "Boxing gym · Family gym".
static func kind_line(gym: Dictionary) -> String:
	var bits: Array[String] = []
	for name: String in [String(kind(String(gym.get("kind", ""))).get("name", "")), String(culture(String(gym.get("culture", ""))).get("name", ""))]:
		if name != "":
			bits.append(name)
	return " · ".join(bits)


## What the gym's kind trains better and worse: "Better at striking and sparring, worse at grappling and wrestling".
static func trains_line(gym: Dictionary) -> String:
	var xp: Dictionary = kind(String(gym.get("kind", ""))).get("xp", {})
	var better: Array = []
	var worse: Array = []
	for id: String in xp:
		if float(xp[id]) > 1.0:
			better.append(id)
		elif float(xp[id]) < 1.0:
			worse.append(id)
	var bits: Array[String] = []
	if not better.is_empty():
		bits.append("better at %s" % _and(better))
	if not worse.is_empty():
		bits.append("worse at %s" % _and(worse))
	if bits.is_empty():
		return "Trains everything the same."
	var out: String = ", ".join(bits)
	return out.left(1).to_upper() + out.substr(1) + "."


static func _and(items: Array) -> String:
	if items.size() == 1:
		return String(items[0])
	return "%s and %s" % [", ".join(items.slice(0, items.size() - 1)), String(items[-1])]


static func _pick(rng: RandomNumberGenerator, pool: Array) -> Variant:
	return pool[rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else ""
