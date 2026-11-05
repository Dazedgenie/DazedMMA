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
##   rooms    (D442) mats, a bag area, a ring, a cage, weights, recovery, video and changing rooms
##            (data/enums/gym_rooms), each at a level 1–3 inside the place's floor space: each level makes its kind of
##            session learn faster, a few sessions need one (hard sparring a ring or cage, Shark tank the cage, film
##            study the video room), the recovery room clears fatigue and heals, the video room finds habits. You build
##            them one at a time with the gym's money, the room shut until it's done; each level you build brings a member.
##   coaches  (D443) the specialists you hire for a weekly wage (Staff, `coaches` and `looking`)
##   money    the gym's own bank (Career.gym_money), apart from his savings. On the first Monday of every month its
##            members pay their dues (the kind's `fee`) and the rent goes out (month()); the gym takes PURSE_CUT of
##            every purse he's paid (Kyle: "Members plus a cut of purses"). Members drift towards a number that grows
##            with his wins, up to what the place holds.
##
## A gym is plain data on the career ({kind, culture, place, name, owner_name, owner, dues, members, members_start,
## rent, rooms, levels_start, spent, building, spots, coaches, looking, looking_at}), so it saves as it is. `owner_name`
## and `owner` are the man you take the place over from. Pure and seeded:
## the same career seed offers the same three places.

const DEFAULT_DIR := "res://data/gyms/"
const CULTURES_PATH := "res://data/enums/gym_cultures.json"
const PLACES_PATH := "res://data/enums/gym_places.json"
const ROOMS_PATH := "res://data/enums/gym_rooms.json"
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
## Rooms (D442): what each level costs ($: Kyle's pick), the top level, the weeks a level takes (its level, one more
## for a big room of BIG_ROOM floor squares or more, never more than BUILD_WEEKS_MAX), tearing one down (a week, a
## quarter of what it cost back: Kyle's pick) and the members each level you build brings in (Kyle's pick).
const ROOM_COSTS: Array[int] = [300, 1000, 2500]
const ROOM_LEVELS: int = 3
const BIG_ROOM: int = 2
const BUILD_WEEKS_MAX: int = 4
const TEAR_DOWN_WEEKS: int = 1
const TEAR_DOWN_BACK: float = 0.25
const MEMBERS_PER_ROOM_LEVEL: int = 1

static var _kinds: Dictionary = {}  # id → gym@1
static var _kind_ids: Array = []
static var _cultures: Dictionary = {}
static var _places: Dictionary = {}
static var _rooms: Dictionary = {}


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
			"rooms": starting_rooms(id, where), "spent": {}, "building": {},
		})
		out[-1].levels_start = levels(out[-1])
	return out


## The rent on a place whose first `members` pay `dues` a month: RENT_SHARE of it, to the nearest $10.
static func rent_for(members: int, dues: int) -> int:
	return roundi(members * dues * RENT_SHARE / 10.0) * 10


## A gym saved before D441 (his fee at someone else's gym) made yours: a unit, its fee now what a member pays. A copy;
## a gym that's already yours comes back as it is.
static func made_yours(gym: Dictionary) -> Dictionary:
	var out: Dictionary = gym.duplicate(true)
	if out.is_empty():
		return out
	if out.has("place"):
		return with_rooms(out)
	var dues: int = int(out.get("fee", 50))
	out.erase("fee")
	out.place = OLD_SAVE_PLACE
	out.dues = dues
	out.members = OLD_SAVE_MEMBERS
	out.members_start = OLD_SAVE_MEMBERS
	out.rent = rent_for(OLD_SAVE_MEMBERS, dues)
	return with_rooms(out)


## A gym saved before D442 given its kind's starting rooms (the gym itself, changed; one that has rooms as it is).
static func with_rooms(gym: Dictionary) -> Dictionary:
	if not gym.is_empty() and not gym.has("rooms"):
		gym.rooms = starting_rooms(String(gym.get("kind", "")), String(gym.get("place", "")))
		gym.spent = {}
		gym.building = {}
	if not gym.is_empty() and not gym.has("levels_start"):
		gym.levels_start = levels(gym)
	return gym


## Every room's level added up.
static func levels(gym: Dictionary) -> int:
	var out: int = 0
	for id: Variant in gym.get("rooms", {}):
		out += int(gym.rooms[id])
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


## How many members the gym is heading towards with `wins` wins behind him: its first members, MEMBERS_PER_WIN a
## win, one for each room level built and each coach's level (Staff, D443), never more than the place holds.
static func members_target(gym: Dictionary, wins: int) -> int:
	return clampi(int(gym.get("members_start", gym.get("members", 0))) + MEMBERS_PER_WIN * wins
		+ MEMBERS_PER_ROOM_LEVEL * (levels(gym) - int(gym.get("levels_start", levels(gym))))
		+ Staff.MEMBERS_PER_LEVEL * Staff.levels(gym), 0, cap(gym))


## The most members the gym holds: its place's `cap`, and each changing rooms level's `cap` more (D442).
static func cap(gym: Dictionary) -> int:
	return int(place(String(gym.get("place", ""))).get("cap", 999)) + int(_sum(gym, "cap"))


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


## Session XP × this for a session of this kind (data/sessions `kind`) at this gym (1 with no gym): the gym's kind,
## its culture's sparring and its rooms (room_share, D442) when the session's `id` is given.
static func xp_share(gym: Dictionary, session_kind: String, session_id: String = "") -> float:
	if gym.is_empty():
		return 1.0
	var out: float = float(kind(String(gym.get("kind", ""))).get("xp", {}).get(session_kind, 1.0))
	if session_kind == "sparring":
		out *= float(culture(String(gym.get("culture", ""))).get("sparring_xp", 1.0))
	return out * room_share(gym, session_kind, session_id)


## The chance a party animal skips × this: the culture's, and a fiery coach's (Staff, D443).
static func skip_share(gym: Dictionary) -> float:
	return float(culture(String(gym.get("culture", ""))).get("skips", 1.0)) * Staff.skip_share(gym) if not gym.is_empty() else 1.0


## A session's injury odds × this: the culture's, and less for each level of a room that makes its kind safer (the
## ring's sparring, D442), and the coaches' personalities (Staff, D443).
static func injury_share(gym: Dictionary, session_kind: String = "") -> float:
	if gym.is_empty():
		return 1.0
	var safer: float = 0.0
	for id: String in rooms():
		safer += working_level(gym, id) * float(room(id).get("injury", {}).get(session_kind, 0.0))
	return float(culture(String(gym.get("culture", ""))).get("injury", 1.0)) * maxf(0.0, 1.0 - safer) * Staff.injury_share(gym)


# --- Rooms (D442) ---------------------------------------------------------------------------------------------------

## The rooms you can build: id → { name, about, size (floor squares), kinds?, sessions?, injury?, night?, heals?,
## finds?, cap? }, in the file's order (data/enums/gym_rooms, docs/09).
static func rooms() -> Dictionary:
	if _rooms.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOMS_PATH))
		if data is Dictionary:
			_rooms = data.get("values", {})
	return _rooms


static func room(id: String) -> Dictionary:
	return rooms().get(id, {})


## The rooms a new gym of this kind opens with in this place, each at level 1: the kind's `rooms` then the place's,
## each that still fits on its floor.
static func starting_rooms(kind_id: String, place_id: String) -> Dictionary:
	var out: Dictionary = {}
	var used: int = 0
	var floor: int = int(place(place_id).get("floor", 0))
	for id: Variant in kind(kind_id).get("rooms", []) + place(place_id).get("rooms", []):
		var size: int = int(room(String(id)).get("size", 0))
		if out.has(String(id)) or size <= 0 or used + size > floor:
			continue
		out[String(id)] = 1
		used += size
	return out


## Columns for a floor of this many squares (rows follow): the floor plan's grid.
const GRID_COLUMNS := { 4: 2, 6: 3, 9: 3 }


static func grid_of(floor_squares: int) -> Vector2i:
	var cols: int = int(GRID_COLUMNS.get(floor_squares, maxi(1, ceili(sqrt(float(floor_squares))))))
	return Vector2i(cols, maxi(1, ceili(float(floor_squares) / cols)))


## Which floor squares each room built (or being built new) takes: id → Array of Vector2i, a 2-square room on two
## squares side by side or one above the other. A room stays where it was put (the gym's `spots`); a new one goes on
## free squares, and only if it can't fit round the others are they all laid out again. Keeps `spots` up to date.
static func spots(gym: Dictionary) -> Dictionary:
	var floor_squares: int = floor_size(gym)
	var grid: Vector2i = grid_of(floor_squares)
	var ids: Array[String] = []
	for id: String in rooms():
		if level(gym, id) > 0 or String(gym.get("building", {}).get("room", "")) == id:
			ids.append(id)
	var out: Dictionary = {}
	var taken: Dictionary = {}
	var saved: Dictionary = gym.get("spots", {}) if gym.get("spots") is Dictionary else {}
	var placing: Array[String] = []
	for id: String in ids:
		var cells: Array = []
		for xy: Variant in saved.get(id, []):
			cells.append(Vector2i(int(xy[0]), int(xy[1])))
		if cells.size() == int(room(id).get("size", 1)) and cells.all(func(c: Vector2i) -> bool: return not taken.has(c) and _on_floor(c, grid, floor_squares)):
			out[id] = cells
			for c: Vector2i in cells:
				taken[c] = true
		else:
			placing.append(id)
	if not _place(_big_first(placing), 0, grid, floor_squares, taken, out):
		out.clear()
		taken.clear()
		if not _place(_big_first(ids), 0, grid, floor_squares, taken, out):
			var n: int = 0  # Can't lay them out neatly: one square at a time, in order.
			for id: String in ids:
				var cells: Array = []
				for i in int(room(id).get("size", 1)):
					cells.append(Vector2i(n % grid.x, n / grid.x))
					n += 1
				out[id] = cells
	if not gym.is_empty():
		var keep: Dictionary = {}
		for id: String in out:
			keep[id] = (out[id] as Array).map(func(c: Vector2i) -> Array: return [c.x, c.y])
		gym.spots = keep
	return out


static func _big_first(ids: Array[String]) -> Array[String]:
	var out: Array[String] = ids.duplicate()
	out.sort_custom(func(a: String, b: String) -> bool:
		var sa: int = int(room(a).get("size", 1))
		var sb: int = int(room(b).get("size", 1))
		return sa > sb or (sa == sb and rooms().keys().find(a) < rooms().keys().find(b)))
	return out


static func _on_floor(c: Vector2i, grid: Vector2i, floor_squares: int) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < grid.x and c.y * grid.x + c.x < floor_squares


static func _place(ids: Array[String], i: int, grid: Vector2i, floor_squares: int, taken: Dictionary, out: Dictionary) -> bool:
	if i >= ids.size():
		return true
	var size: int = int(room(ids[i]).get("size", 1))
	for n in floor_squares:
		var at := Vector2i(n % grid.x, n / grid.x)
		if taken.has(at):
			continue
		var shapes: Array = [[at]] if size <= 1 else [[at, at + Vector2i(1, 0)], [at, at + Vector2i(0, 1)]]
		for shape: Array in shapes:
			if not shape.all(func(c: Vector2i) -> bool: return not taken.has(c) and _on_floor(c, grid, floor_squares)):
				continue
			for c: Vector2i in shape:
				taken[c] = true
			out[ids[i]] = shape
			if _place(ids, i + 1, grid, floor_squares, taken, out):
				return true
			for c: Vector2i in shape:
				taken.erase(c)
			out.erase(ids[i])
	return false


## A room's level (0 = not built).
static func level(gym: Dictionary, id: String) -> int:
	return int(gym.get("rooms", {}).get(id, 0))


## A room's level as it trains now: 0 while it's shut for building (D442).
static func working_level(gym: Dictionary, id: String) -> int:
	return 0 if String(gym.get("building", {}).get("room", "")) == id else level(gym, id)


## The floor squares the place has, and the ones its rooms (and a new room being built) take.
static func floor_size(gym: Dictionary) -> int:
	return int(place(String(gym.get("place", ""))).get("floor", 0))


static func floor_used(gym: Dictionary) -> int:
	var used: int = 0
	for id: String in rooms():
		if level(gym, id) > 0 or String(gym.get("building", {}).get("room", "")) == id:
			used += int(room(id).get("size", 0))
	return used


## Whether this gym has what a session needs (data/sessions `needs`: any one of those rooms, working). A camp with no
## gym, or a gym from before rooms, has everything.
static func can_use(gym: Dictionary, session: Dictionary) -> bool:
	var needs: Array = session.get("needs", [])
	if needs.is_empty() or gym.is_empty() or not gym.has("rooms"):
		return true
	return needs.any(func(id: Variant) -> bool: return working_level(gym, String(id)) > 0)


## The session he does in a slot planned with this one: itself, or its `instead` when the gym hasn't the room.
static func stand_in(gym: Dictionary, session: Dictionary) -> String:
	var id: String = String(session.get("id", ""))
	return id if can_use(gym, session) else String(session.get("instead", id))


## "Needs a ring or a cage" for a session this gym can't do ("" when it can).
static func needs_text(gym: Dictionary, session: Dictionary) -> String:
	if can_use(gym, session):
		return ""
	var names: Array = (session.get("needs", []) as Array).map(func(id: Variant) -> String: return String(room(String(id)).get("name", id)).to_lower())
	return "Needs the %s" % " or the ".join(PackedStringArray(names))


## XP × this from the rooms (D442): 1 + each working room's level × its share for the session's kind and for the
## session itself.
static func room_share(gym: Dictionary, session_kind: String, session_id: String = "") -> float:
	var out: float = 1.0
	for id: String in rooms():
		var lv: int = working_level(gym, id)
		if lv > 0:
			var r: Dictionary = room(id)
			out += lv * (float(r.get("kinds", {}).get(session_kind, 0.0)) + float(r.get("sessions", {}).get(session_id, 0.0)))
	return out


## The share of fatigue a night keeps × this (the recovery room's `night` less a level).
static func night_share(gym: Dictionary) -> float:
	return maxf(0.0, 1.0 - _sum(gym, "night"))


## Days more an injury heals each Sunday (the recovery room's `heals` a level).
static func extra_healing(gym: Dictionary) -> int:
	return int(_sum(gym, "heals"))


## Added to the chance a film study session finds one of his habits (the video room's `finds` a level).
static func finds_bonus(gym: Dictionary) -> float:
	return _sum(gym, "finds")


## Σ working level × a room's number field.
static func _sum(gym: Dictionary, field: String) -> float:
	var out: float = 0.0
	for id: String in rooms():
		out += working_level(gym, id) * float(room(id).get(field, 0.0))
	return out


## What the next level of a room costs ($; 0 at the top).
static func build_cost(gym: Dictionary, id: String) -> int:
	var next: int = level(gym, id) + 1
	return ROOM_COSTS[next - 1] if next <= ROOM_LEVELS else 0


## The weeks building a room to this level takes.
static func build_weeks(id: String, to_level: int) -> int:
	return clampi(to_level + (1 if int(room(id).get("size", 0)) >= BIG_ROOM else 0), 1, BUILD_WEEKS_MAX)


## Why the next level of a room can't be built with `money` ("" when it can).
static func cant_build(gym: Dictionary, id: String, money: int) -> String:
	if room(id).is_empty():
		return "No such room"
	var building: Dictionary = gym.get("building", {})
	if not building.is_empty():
		return "Already working on the %s" % String(room(String(building.room)).get("name", "")).to_lower()
	if level(gym, id) >= ROOM_LEVELS:
		return "At the top level"
	var size: int = int(room(id).get("size", 0))
	if level(gym, id) == 0 and floor_used(gym) + size > floor_size(gym):
		return "Not enough floor: it needs %d, %d free" % [size, floor_size(gym) - floor_used(gym)]
	if money < build_cost(gym, id):
		return "It costs $%d: the gym has $%d" % [build_cost(gym, id), money]
	return ""


## Starts the next level of a room, done after build_weeks: the gym changes; returns what it cost (the career pays).
static func start_build(gym: Dictionary, id: String, week: int) -> int:
	var cost: int = build_cost(gym, id)
	var to_level: int = level(gym, id) + 1
	gym.building = { "room": id, "level": to_level, "done": week + build_weeks(id, to_level) }
	spots(gym)  # Where it goes on the floor.
	if not gym.has("spent"):
		gym.spent = {}
	gym.spent[id] = int(gym.spent.get(id, 0)) + cost
	return cost


## What tearing a room down gives back ($): TEAR_DOWN_BACK of what was spent on it.
static func tear_down_back(gym: Dictionary, id: String) -> int:
	return roundi(int(gym.get("spent", {}).get(id, 0)) * TEAR_DOWN_BACK)


## Why a room can't be torn down ("" when it can).
static func cant_tear_down(gym: Dictionary, id: String) -> String:
	if level(gym, id) == 0:
		return "Not built"
	if not gym.get("building", {}).is_empty():
		return "Already working on the %s" % String(room(String(gym.building.room)).get("name", "")).to_lower()
	return ""


## Starts tearing a room down (shut for TEAR_DOWN_WEEKS, then gone): the gym changes; returns the money back.
static func start_tear_down(gym: Dictionary, id: String, week: int) -> int:
	var back: int = tear_down_back(gym, id)
	gym.building = { "room": id, "level": 0, "done": week + TEAR_DOWN_WEEKS }
	return back


## The build (or tear-down) finishing by this week, if one is: the room takes its new level and the gym changes.
## Returns { room, level } ({} when none finished).
static func finish_build(gym: Dictionary, week: int) -> Dictionary:
	var building: Dictionary = gym.get("building", {})
	if building.is_empty() or week < int(building.get("done", 0)):
		return {}
	var id: String = String(building.room)
	var to_level: int = int(building.level)
	if not gym.has("rooms"):
		gym.rooms = {}
	if to_level > 0:
		gym.rooms[id] = to_level
	else:
		gym.rooms.erase(id)
		gym.get("spent", {}).erase(id)
	gym.building = {}
	spots(gym)
	return { "room": id, "level": to_level }


## "The mats are level 2 now." / "The ring is torn out."
static func built_text(done: Dictionary) -> String:
	var name: String = String(room(String(done.get("room", ""))).get("name", "room")).to_lower()
	var verb: String = "are" if name.ends_with("s") else "is"
	if int(done.get("level", 0)) == 0:
		return "The %s %s torn out" % [name, verb]
	if int(done.level) == 1:
		return "New in the gym: the %s" % name
	return "The %s %s level %d now" % [name, verb, int(done.level)]


## What a room does at a level, a line each: "Grappling and wrestling sessions learn 16% faster", "Sparring injuries
## 20% less likely" … (the sessions it opens are the page's to name).
static func effect_lines(id: String, lv: int) -> Array[String]:
	var r: Dictionary = room(id)
	var out: Array[String] = []
	var kinds: Array = r.get("kinds", {}).keys()
	if not kinds.is_empty():
		var share: float = float(r.kinds[kinds[0]])
		out.append("%s sessions learn %d%% faster" % [_first_up(_and(kinds)), roundi(share * lv * 100.0)])
	for session_id: String in r.get("sessions", {}):
		out.append("%s learns %d%% more" % [_first_up(session_id.replace("_", " ")), roundi(float(r.sessions[session_id]) * lv * 100.0)])
	for kind_id: String in r.get("injury", {}):
		out.append("%s injuries %d%% less likely" % [_first_up(kind_id), roundi(float(r.injury[kind_id]) * lv * 100.0)])
	if r.has("night"):
		out.append("%d%% less fatigue kept overnight" % roundi(float(r.night) * lv * 100.0))
	if r.has("heals"):
		out.append("Injuries heal %d day%s more each Sunday" % [int(r.heals) * lv, "" if int(r.heals) * lv == 1 else "s"])
	if r.has("finds"):
		out.append("Film study %d%% likelier to find a habit" % roundi(float(r.finds) * lv * 100.0))
	if r.has("cap"):
		out.append("Room for %d more members" % (int(r.cap) * lv))
	return out


## "Ring 2 · Mats 1 · Video room 1"
static func rooms_line(gym: Dictionary) -> String:
	var bits: Array[String] = []
	for id: String in rooms():
		if level(gym, id) > 0:
			bits.append("%s %d" % [String(room(id).name), level(gym, id)])
	return " · ".join(bits)


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


static func _first_up(text: String) -> String:
	return text.left(1).to_upper() + text.substr(1)


static func _and(items: Array) -> String:
	if items.size() == 1:
		return String(items[0])
	return "%s and %s" % [", ".join(items.slice(0, items.size() - 1)), String(items[-1])]


static func _pick(rng: RandomNumberGenerator, pool: Array) -> Variant:
	return pool[rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else ""
