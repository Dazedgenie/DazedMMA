class_name Promotions
extends RefCounted
## The world's promotions (docs/03 §12.4, D354): 3 or 4 regional pro promotions in his country and 2 international
## organisations, made up for each career from data/world/promotions.json (docs/09 promotions@1) and kept in the world
## (World.promotions). Each has a name, a home city, a venue, a pay scale and a card every few weeks. Every pro of the
## world is signed to one (his `promotion`), and pros only fight on their promotion's cards (WorldWeeks.play_week).
##
## Who's where (by level): in each division the best MAJOR_MEN pros fight for the world organisation (rank 0), the
## next SECOND_MEN for the international one (rank 1) and the rest for the regional promotions (rank 2). Men move as it
## goes (call-ups and cuts): CALL_UP_WINS wins in a row since his last move and he's called up a rank; CUT_LOSSES
## losses in a row and he's let go a rank down.
##
## Pure and seeded (D100): the world's seed makes the same promotions.

const PATH := "res://data/world/promotions.json"
## The pros of each division in each organisation when they're placed by level.
const MAJOR_MEN: int = 18
const SECOND_MEN: int = 20
## The ranks: 0 the world organisation, 1 the international one, 2 a regional promotion.
const MAJOR: int = 0
const SECOND: int = 1
const REGIONAL: int = 2
## Call-ups and cuts (Kyle, 2026-11-01: see D354): wins or losses in a row since he last moved.
const CALL_UP_WINS: int = 3
const CUT_LOSSES: int = 3
## A call-up only comes while the organisation has room in his division: fewer than its count (MAJOR_MEN or
## SECOND_MEN) plus CALL_UP_ROOM.
const CALL_UP_ROOM: int = 2
## A card's number: its first card is numbered from these (a promotion that's been going a while), plus one a card.
const FIRST_NUMBER_REGIONAL: Array[int] = [3, 40]
const FIRST_NUMBER_ORGANISATION: Array[int] = [60, 240]
## How many tries to make a name that isn't taken or real.
const NAME_TRIES: int = 30

static var _data: Dictionary = {}


## The shipped promotions data, loaded once.
static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_data = parsed
	return _data


## The world's promotions, made once from its seed: the two organisations first (rank 0, then 1), then 3 or 4
## regional ones, the first in his hometown. Each: { id, name, short, kind, rank, city, country, venue, capacity,
## every (weeks between cards), first_week (its first card's week, at or after `week`), first_number, show, win }.
static func make(w: World, week: int, d: Dictionary = {}) -> Array:
	var src: Dictionary = d if not d.is_empty() else data()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([w.seed_value, "promotions"])
	var out: Array = []
	var used: Dictionary = {}
	for org: Dictionary in src.get("organisations", []):
		var country: String = w._hotbed(rng)
		var cities: Array = w._names.cities(country)
		var name: String = ""
		for i in NAME_TRIES:
			name = "%s %s" % [_pick(rng, src.get("first", ["Apex"])), _pick(rng, src.get("second", ["Combat League"]))]
			if not _taken(name, used, src):
				break
		used[name] = true
		var every: int = int(org.get("every_weeks", 4))
		out.append({
			"id": "org_%d" % int(org.rank), "name": name, "short": short_name(name), "kind": String(org.get("kind", "")),
			"rank": int(org.rank), "city": String(_pick(rng, cities)) if not cities.is_empty() else "", "country": country,
			"venue": String(_pick(rng, src.get("organisation_venues", ["Arena"]))),
			"capacity": _round_to(rng.randi_range(int(org.capacity[0]), int(org.capacity[1])), 500),
			"every": every, "first_week": week + rng.randi_range(0, every - 1),
			"first_number": rng.randi_range(FIRST_NUMBER_ORGANISATION[0], FIRST_NUMBER_ORGANISATION[1]),
			"show": int(org.show), "win": int(org.win),
		})
	var reg: Dictionary = src.get("regional", {})
	var count: int = rng.randi_range(int(reg.get("count", [3, 4])[0]), int(reg.get("count", [3, 4])[1]))
	var home_cities: Array = w._names.cities(w.country_id).filter(func(x: Variant) -> bool: return String(x) != w.hometown)
	home_cities.sort()
	_shuffle(home_cities, rng)
	var regions: Array = (reg.get("regions", ["Northern"]) as Array).duplicate()
	_shuffle(regions, rng)
	for i in count:
		var city: String = w.hometown if i == 0 or home_cities.is_empty() else String(home_cities[(i - 1) % home_cities.size()])
		var name: String = ""
		for t in NAME_TRIES:
			var pattern: String = String(_pick(rng, reg.get("names", ["{city} Fight League"])))
			name = pattern.format({ "city": city, "region": String(regions[(i + t) % regions.size()]) })
			if not _taken(name, used, src):
				break
		used[name] = true
		var every: int = rng.randi_range(int(reg.get("every_weeks", [6, 8])[0]), int(reg.get("every_weeks", [6, 8])[1]))
		out.append({
			"id": "reg_%d" % i, "name": name, "short": short_name(name), "kind": "Regional promotion", "rank": REGIONAL,
			"city": city, "country": w.country_id, "venue": String(_pick(rng, reg.get("venues", ["Arena"]))),
			"capacity": _round_to(rng.randi_range(int(reg.capacity[0]), int(reg.capacity[1])), 100),
			"every": every, "first_week": week + rng.randi_range(0, every - 1),
			"first_number": rng.randi_range(FIRST_NUMBER_REGIONAL[0], FIRST_NUMBER_REGIONAL[1]),
			"show": _round_to(rng.randi_range(int(reg.show[0]), int(reg.show[1])), 50),
			"win": _round_to(rng.randi_range(int(reg.win[0]), int(reg.win[1])), 50),
		})
	return out


## "Northern Cage Championship" → "NCC" ("of", "in" and "the" left out).
static func short_name(name: String) -> String:
	var out: String = ""
	for word: String in name.split(" ", false):
		if word.to_lower() in ["of", "in", "the"]:
			continue
		out += word.substr(0, 1).to_upper()
	return out


## Every pro of the world signed by level (see the top): in each division, best first.
static func place_all(w: World, week: int) -> void:
	for division_id: String in Weight.ids():
		var pros: Array = w.in_division(division_id, week).filter(func(m: Dictionary) -> bool: return bool(m.pro))
		pros.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return w.average(a) > w.average(b) if w.average(a) != w.average(b) else String(a.id) < String(b.id))
		for i in pros.size():
			var rank: int = MAJOR if i < MAJOR_MEN else (SECOND if i < MAJOR_MEN + SECOND_MEN else REGIONAL)
			sign_to(w, pros[i], rank)


## A new pro (a man joining the world, or an amateur turning pro) signed where his level puts him among his division's
## pros; an amateur turning pro always starts regional.
static func place(w: World, m: Dictionary, week: int, start_regional: bool = false) -> void:
	if w.promotions.is_empty() or not bool(m.get("pro", false)):
		return
	if start_regional:
		sign_to(w, m, REGIONAL)
		return
	var better: int = 0
	for o: Dictionary in w.in_division(World.division_of(m, week), week):
		if bool(o.pro) and String(o.id) != String(m.id) and w.average(o) > w.average(m):
			better += 1
	sign_to(w, m, MAJOR if better < MAJOR_MEN else (SECOND if better < MAJOR_MEN + SECOND_MEN else REGIONAL))


## Signs him to a promotion of this rank: of the regional ones, the one with fewest men in his division (his hometown's
## first among those, then by his id).
static func sign_to(w: World, m: Dictionary, rank: int) -> void:
	var options: Array = w.promotions.filter(func(p: Dictionary) -> bool: return int(p.rank) == rank)
	if options.is_empty():
		return
	var pick: Dictionary = options[absi(String(m.id).hash()) % options.size()]
	if options.size() > 1:
		var counts: Dictionary = {}
		var division: String = World.division_of(m, maxi(0, w.played))
		for o: Dictionary in w.men.values():
			if World.active(o) and String(o.get("division", "")) == division and String(o.id) != String(m.id):
				counts[String(o.get("promotion", ""))] = int(counts.get(String(o.get("promotion", "")), 0)) + 1
		var fewest: int = 1 << 30
		for p: Dictionary in options:
			fewest = mini(fewest, int(counts.get(String(p.id), 0)))
		var least: Array = options.filter(func(p: Dictionary) -> bool: return int(counts.get(String(p.id), 0)) == fewest)
		pick = least[absi(String(m.id).hash()) % least.size()]
		for p: Dictionary in least:
			if String(p.city) == String(m.get("hometown", "")):
				pick = p
	m.promotion = String(pick.id)


## The promotion with this id ({} for none).
static func by_id(w: World, id: String) -> Dictionary:
	for p: Dictionary in w.promotions:
		if String(p.id) == id:
			return p
	return {}


## His promotion ({} for an amateur, or a man not signed).
static func of(w: World, m: Dictionary) -> Dictionary:
	return by_id(w, String(m.get("promotion", "")))


## His home promotion: the regional one in his hometown (the first regional one when none is).
static func home(w: World) -> Dictionary:
	var regs: Array = regionals(w)
	for p: Dictionary in regs:
		if String(p.city) == w.hometown:
			return p
	return regs[0] if not regs.is_empty() else {}


## The regional promotions.
static func regionals(w: World) -> Array:
	return w.promotions.filter(func(p: Dictionary) -> bool: return int(p.rank) == REGIONAL)


## Whether the promotion runs a card this week (on its Saturday).
static func has_card(p: Dictionary, week: int) -> bool:
	var since: int = week - int(p.first_week)
	return since >= 0 and since % maxi(1, int(p.every)) == 0


## The weeks of its cards from `from` to `to`, both included.
static func card_weeks(p: Dictionary, from: int, to: int) -> Array[int]:
	var out: Array[int] = []
	var every: int = maxi(1, int(p.every))
	var first: int = int(p.first_week)
	var k: int = maxi(0, ceili(float(from - first) / float(every)))
	var week: int = first + k * every
	while week <= to:
		if week >= from:
			out.append(week)
		week += every
	return out


## The card it runs this week: { name ("Northern Cage Championship 14"), short ("NCC 14"), venue, city, promotion }.
## A regional promotion is mostly at home (`home_city_share`), else in another city of his country; an organisation
## goes round the hotbeds, its home city as often as any.
static func card(w: World, p: Dictionary, week: int, d: Dictionary = {}) -> Dictionary:
	var src: Dictionary = d if not d.is_empty() else data()
	var k: int = (week - int(p.first_week)) / maxi(1, int(p.every))
	var number: int = int(p.first_number) + k
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([w.seed_value, String(p.id), number])
	var city: String = String(p.city)
	if int(p.rank) == REGIONAL:
		var others: Array = w._names.cities(String(p.country)).filter(func(x: Variant) -> bool: return String(x) != city)
		if rng.randf() >= float(src.get("regional", {}).get("home_city_share", 1.0)) and not others.is_empty():
			city = String(others[rng.randi_range(0, others.size() - 1)])
	elif rng.randf() >= 0.3:
		var country: String = w._hotbed(rng)
		var cities: Array = w._names.cities(country)
		if not cities.is_empty():
			city = String(cities[rng.randi_range(0, cities.size() - 1)])
	return { "name": "%s %d" % [String(p.name), number], "short": "%s %d" % [String(p.short), number],
		"venue": String(p.venue), "city": city, "promotion": String(p.id) }


## After a fight of his (a world fight or one against the career's fighter): called up after CALL_UP_WINS wins in a
## row since he last moved, let go a rank down after CUT_LOSSES losses in a row. Logs a "moved" result when he moves.
static func after_fight(w: World, m: Dictionary, week: int) -> void:
	if not bool(m.get("pro", false)) or String(m.get("promotion", "")) == "":
		return
	var p: Dictionary = of(w, m)
	if p.is_empty() or Titles.held_by(w, String(m.get("id", ""))) != "":
		return  # A champion moves on his belt's terms (Titles, D356).
	var since: int = int(m.get("moved", -1))
	var h: Array = (m.get("history", []) as Array).filter(func(x: Array) -> bool: return int(x[0]) > since)
	var rank: int = int(p.rank)
	var to_rank: int = rank
	if rank > MAJOR and _run(h, "w") >= CALL_UP_WINS and has_room(w, rank - 1, World.division_of(m, week)):
		to_rank = rank - 1
	elif rank < REGIONAL and _run(h, "l") >= CUT_LOSSES:
		to_rank = rank + 1
	if to_rank == rank:
		return
	sign_to(w, m, to_rank)
	m.moved = week
	w.results.append({ "kind": "moved", "week": week, "id": String(m.id), "division": World.division_of(m, week),
		"from": String(p.id), "to": String(m.promotion), "up": to_rank < rank })


## Whether an organisation of this rank has room for one more man in this division (see CALL_UP_ROOM).
static func has_room(w: World, rank: int, division: String) -> bool:
	if rank >= REGIONAL:
		return true
	var n: int = 0
	for o: Dictionary in w.men.values():
		if World.active(o) and String(o.get("division", "")) == division:
			var p: Dictionary = of(w, o)
			if not p.is_empty() and int(p.rank) == rank:
				n += 1
	return n < (MAJOR_MEN if rank == MAJOR else SECOND_MEN) + CALL_UP_ROOM


## What a fight on its card pays: { show, win } in dollars.
static func purse(p: Dictionary) -> Dictionary:
	return { "show": int(p.get("show", 0)), "win": int(p.get("win", 0)) }


## How many results in a row at the end of his history are `letter` (w, l).
static func _run(h: Array, letter: String) -> int:
	var n: int = 0
	for i in range(h.size() - 1, -1, -1):
		if String(h[i][2]) != letter:
			break
		n += 1
	return n


static func _taken(name: String, used: Dictionary, src: Dictionary) -> bool:
	if used.has(name):
		return true
	for real: Variant in src.get("real", []):
		if String(real).to_lower() == name.to_lower():
			return true
	return false


static func _pick(rng: RandomNumberGenerator, items: Array) -> Variant:
	return items[rng.randi_range(0, items.size() - 1)] if not items.is_empty() else ""


static func _round_to(x: int, step: int) -> int:
	return maxi(step, roundi(float(x) / float(step)) * step)


static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: Variant = items[i]
		items[i] = items[j]
		items[j] = t
