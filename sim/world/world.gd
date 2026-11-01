class_name World
extends RefCounted
## The world's fighters (docs/03 §12.2, D352): about PER_DIVISION named men in each of the six divisions (D351), made
## once when a career needs them and kept in its save. Kyle (2026-11-01) picked a pyramid of levels ("A pyramid": most
## of them amateurs and local pros, a few world class), local men at home and the hotbeds at the top ("Home locally,
## hotbeds at top"), the local lads he meets as an amateur among them ("Yes, amateurs in the roster"), rematches after a
## while ("Rematches after a while") and a list of his division on the hub ("A division list on the hub").
##
## A man is kept small: his name and where he's from, his style, the seed and quality level StyleLibrary.generate makes
## his fighter from, his age at the career's week 0, his body (height, reach and grown weight, Weight), his record and
## when he last fought the career's fighter. profile() makes his whole fighter@1 profile when it's needed. His division
## is whatever his weight makes at his age (Weight.division_for), so a growing lad moves up as the weeks go by.
##
## Until the world's weeks (D353) nobody else fights: his record is a stand-in for the years before the career
## (D358 replaces it with a played history), and it only changes when he fights the career's fighter.
##
## Pure and seeded (D100): the same career seed and home make the same men.

const VERSION: int = 1
## Men in each division when the world's made.
const PER_DIVISION: int = 100
## The pyramid (Kyle, 2026-11-01: "A pyramid"), each level's share of a division's men and what goes with it:
## `count` men a division, `pro`, `ages` [youngest, oldest] at the start, `avg` [lowest, highest] average stat (a pro's;
## an amateur's comes from his age: AMATEUR_AVG_*), `home` the share of them from the career's country (the rest from
## anywhere, the hotbeds the most), `win` [lowest, highest] share of his fights he's won, `per_year` fights a year,
## `nickname` the share of them with a nickname (most men haven't one; the best have earned one).
const LEVELS: Array[Dictionary] = [
	{ "id": "amateur", "name": "Amateur", "count": 25, "pro": false, "ages": [14, 22], "home": 1.0, "win": [0.35, 0.75], "per_year": 3.0, "nickname": 0.2 },
	{ "id": "local", "name": "Local pro", "count": 20, "pro": true, "ages": [20, 31], "avg": [38, 50], "home": 0.75, "win": [0.35, 0.65], "per_year": 2.5, "nickname": 0.35 },
	{ "id": "regional", "name": "Regional pro", "count": 30, "pro": true, "ages": [21, 33], "avg": [46, 58], "home": 0.45, "win": [0.5, 0.75], "per_year": 2.5, "nickname": 0.45 },
	{ "id": "national", "name": "National-level pro", "count": 18, "pro": true, "ages": [23, 34], "avg": [55, 67], "home": 0.25, "win": [0.65, 0.85], "per_year": 2.5, "nickname": 0.6 },
	{ "id": "world", "name": "World-class pro", "count": 7, "pro": true, "ages": [25, 35], "avg": [64, 80], "home": 0.1, "win": [0.78, 0.95], "per_year": 2.5, "nickname": 0.75 },
]
## An amateur's average stat: AMATEUR_AVG_AT_16 at 16, AMATEUR_AVG_PER_YEAR more for every year older (less younger),
## give or take AMATEUR_AVG_SPREAD, held inside AMATEUR_AVG_RANGE.
const AMATEUR_AVG_AT_16: float = 28.0
const AMATEUR_AVG_PER_YEAR: float = 2.5
const AMATEUR_AVG_SPREAD: float = 6.0
const AMATEUR_AVG_RANGE: Array[float] = [18.0, 50.0]
## Amateurs' ages lean young: the share of the way from youngest to oldest is a roll to this power.
const AMATEUR_AGE_SKEW: float = 1.5
## Of the career's own country's amateurs, this share are from his hometown.
const HOMETOWN_SHARE: float = 0.5
## A style his country is known for (names@1 `styles`) is this many times as likely.
const HOME_STYLE_WEIGHT: float = 2.5
## Amateurs start at 16; a pro turned pro at PRO_FROM_AGE, give or take PRO_FROM_SPREAD.
const AMATEUR_FROM_AGE: int = 16
const PRO_FROM_AGE: int = 21
const PRO_FROM_SPREAD: int = 2
## A fight in his past that was a draw.
const DRAW_CHANCE: float = 0.02
## Rematches (Kyle, 2026-11-01: "Rematches after a while"): a man he's fought isn't offered again for this many weeks,
## or CLOSE_REMATCH_WEEKS after a close fight (a draw, or a split or majority decision).
const REMATCH_WEEKS: int = 52
const CLOSE_REMATCH_WEEKS: int = 16
## Tries at a name nobody else in the world has.
const NAME_TRIES: int = 6

var seed_value: int = 0
var country_id: String = ""
var hometown: String = ""
## Every man by id, in the order they were made.
var men: Dictionary = {}
## The next number for a newcomer's id, by division.
var next_number: Dictionary = {}
## The last week the world's fights were played (WorldWeeks, D353), and the results of the last RESULTS_WEEKS weeks.
var played: int = -1
var results: Array = []

var _styles: StyleLibrary
var _names: NameLibrary
var _roster: FighterLibrary
var _signature_avg: Dictionary = {}
var _names_used: Dictionary = {}


func _init(p_styles: StyleLibrary = null, p_names: NameLibrary = null, p_roster: FighterLibrary = null) -> void:
	_styles = p_styles if p_styles != null else StyleLibrary.shared()
	_names = p_names if p_names != null else NameLibrary.shared()
	_roster = p_roster if p_roster != null else FighterLibrary.load_dir()


## A new world: PER_DIVISION men in every division, the levels as LEVELS has them, home being the career's country and
## hometown. `week` is the career's week now: the men are their ages now, whenever the world's made (a career saved
## before D352 makes its world when it loads).
static func make(world_seed: int, home_country_id: String, home_town: String, week: int = 0, p_styles: StyleLibrary = null,
		p_names: NameLibrary = null, p_roster: FighterLibrary = null) -> World:
	var w := World.new(p_styles, p_names, p_roster)
	w.seed_value = world_seed
	w.country_id = home_country_id
	w.hometown = home_town
	w.played = week - 1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, "world"])
	for division_id: String in Weight.ids():
		for level: Dictionary in LEVELS:
			for i in int(level.count):
				w._make_man(rng, division_id, level, week)
	return w


## His age in years at this week.
static func age_of(man: Dictionary, week: int) -> float:
	return float(man.get("born", 0.0)) + float(week) / Career.WEEKS_PER_YEAR


## The division he fights at this week: a pro's own (picked when he turned pro, D353), an amateur's what his weight
## makes at his age.
static func division_of(man: Dictionary, week: int) -> String:
	if String(man.get("division", "")) != "":
		return String(man.division)
	return Weight.division_for(Weight.walk_kg(man.get("frame", {}), age_of(man, week)))


## Whether he's still fighting (not retired, D353).
static func active(man: Dictionary) -> bool:
	return int(man.get("retired", -1)) < 0


## His average stat: his style's signature fighter's, moved by his level (StyleLibrary.generate; `lv`, the level to a
## fraction as the weeks change it, D353).
func average(man: Dictionary) -> float:
	return signature_average(String(man.get("style", ""))) + float(man.get("lv", man.get("level", 0)))


## A style's signature fighter's average stat.
func signature_average(style_id: String) -> float:
	if not _signature_avg.has(style_id):
		var sig: Dictionary = _roster.profile(String(_styles.get_style(style_id).fighter)).get("stats", {})
		_signature_avg[style_id] = Matchmaker.average_stat(sig)
	return float(_signature_avg[style_id])


func man(id: String) -> Dictionary:
	return men.get(id, {})


## The men fighting at this division this week (not retired), in the order they were made.
func in_division(division_id: String, week: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m: Dictionary in men.values():
		if active(m) and division_of(m, week) == division_id:
			out.append(m)
	return out


## His whole fighter@1 profile this week: his style's fighter at his level (StyleLibrary.generate), his name, age and
## body.
func profile(id: String, week: int) -> Dictionary:
	var m: Dictionary = man(id)
	if m.is_empty():
		return {}
	var p: Dictionary = _styles.generate(String(m.style), int(m.seed), int(m.level), _roster, id, String(m.name))
	p.age = int(floor(age_of(m, week)))
	for key: String in ["height_cm", "reach_cm", "adult_kg"]:
		if m.frame.has(key):
			p.frame[key] = m.frame[key]
	for key: String in ["height_cm", "reach_cm"]:
		p.frame[key] = int(p.frame[key])
	p.home = _names.country_id_of(String(m.get("country", "")))  # His look comes from where he's from (D364).
	return p


## Where he's from and what he's called: { nickname, hometown, country, record (as written, "7-2-0") }.
static func about(m: Dictionary) -> Dictionary:
	return { "nickname": String(m.get("nickname", "")), "hometown": String(m.get("hometown", "")),
		"country": String(m.get("country", "")), "record": record_text(m) }


## "7-2-0": his wins, losses and draws.
static func record_text(m: Dictionary) -> String:
	var r: Dictionary = m.get("record", {})
	return "%d-%d-%d" % [int(r.get("win", 0)), int(r.get("loss", 0)), int(r.get("draw", 0))]


## His level's name ("Regional"), or "Amateur".
static func level_name(m: Dictionary) -> String:
	for level: Dictionary in LEVELS:
		if String(level.id) == String(m.get("tier", "")):
			return String(level.name)
	return ""


## Whether he can be offered to the career's fighter this week (rematches, Kyle: "Rematches after a while"): never
## fought, or REMATCH_WEEKS since, or CLOSE_REMATCH_WEEKS after a close fight.
static func can_rematch(m: Dictionary, week: int) -> bool:
	var met: int = int(m.get("met_week", -1))
	if met < 0:
		return true
	return week - met >= (CLOSE_REMATCH_WEEKS if bool(m.get("met_close", false)) else REMATCH_WEEKS)


## A fight with the career's fighter is over: onto the man's record and his last fights (`result` is the career
## fighter's: a win for him is a loss for the man; `method` as the fight screen gives it), he's due another fight in a
## while (WorldWeeks.note_fight), and he can't be offered again for a while (can_rematch). `close` for a draw or a
## split or majority decision.
func record_fight(id: String, result: String, week: int, close: bool, method: String = "") -> void:
	var m: Dictionary = man(id)
	if m.is_empty():
		return
	var theirs: String = { "win": "loss", "loss": "win" }.get(result, result)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, id, week, "his fight"])
	WorldWeeks.note_fight(m, Career.FIGHTER_ID, theirs, method if method != "" else "decision", week, rng)
	m.met_week = week
	m.met_close = close


## Whether a fight's ending makes it a close one (a rematch comes sooner): a draw, or a split or majority decision.
static func is_close(result: String, method: String) -> bool:
	var m: String = method.to_lower()
	return result == "draw" or m.begins_with("split") or m.begins_with("majority")


## A new man joins the world (when nobody in it fits an offer): `pro` or an amateur, of this style, about this average
## stat, this age now, fighting in this division. Returns his id.
func add_newcomer(rng: RandomNumberGenerator, division_id: String, pro: bool, style_id: String, avg: float, age_now: float, week: int) -> String:
	var level: Dictionary = LEVELS[0]
	if pro:
		level = LEVELS[1]
		for l: Dictionary in LEVELS.slice(1):
			if avg >= float(l.avg[0]):
				level = l
	var m: Dictionary = _make_man(rng, division_id, level, week, { "style": style_id, "avg": avg, "age": age_now })
	return String(m.id)


## Makes one man of this level in this division and adds him. `fixed` may give his `style`, `avg` and `age` instead of
## rolling them.
func _make_man(rng: RandomNumberGenerator, division_id: String, level: Dictionary, week: int, fixed: Dictionary = {}) -> Dictionary:
	var pro: bool = bool(level.pro)
	var age: float
	if fixed.has("age"):
		age = float(fixed.age)
	elif pro:
		age = rng.randf_range(float(level.ages[0]), float(level.ages[1]) + 0.99)
	else:
		age = lerpf(float(level.ages[0]), float(level.ages[1]) + 0.99, pow(rng.randf(), AMATEUR_AGE_SKEW))
	var from_id: String = country_id
	if rng.randf() >= float(level.home) or not _names.countries().has(country_id):
		from_id = _hotbed(rng)
	var town: String = hometown if from_id == country_id and not pro and rng.randf() < HOMETOWN_SHARE else ""
	var person: Dictionary = _names.roll_in(rng, from_id, town)
	for i in NAME_TRIES:
		if not _name_taken(String(person.name)):
			break
		person.name = _names.random_name(rng, from_id)
	if rng.randf() >= float(level.get("nickname", 1.0)):
		person.nickname = ""
	var style_id: String = String(fixed.get("style", ""))
	if style_id == "" or not _styles.has(style_id):
		style_id = _style_for(rng, from_id)
	var avg: float
	if fixed.has("avg"):
		avg = float(fixed.avg)
	elif pro:
		avg = rng.randf_range(float(level.avg[0]), float(level.avg[1]))
	else:
		avg = clampf(AMATEUR_AVG_AT_16 + AMATEUR_AVG_PER_YEAR * (age - 16.0) + rng.randf_range(-AMATEUR_AVG_SPREAD, AMATEUR_AVG_SPREAD),
			AMATEUR_AVG_RANGE[0], AMATEUR_AVG_RANGE[1])
	var shift: int = clampi(roundi(avg - average({ "style": style_id, "level": 0 })), -StyleLibrary.MAX_LEVEL, StyleLibrary.MAX_LEVEL)
	var sig: Dictionary = _roster.profile(String(_styles.get_style(style_id).fighter))
	var body: Dictionary = { "frame": (sig.get("frame", {}) as Dictionary).duplicate(true) }
	Weight.fit(body, division_id, age, rng)
	var number: int = int(next_number.get(division_id, 1))
	next_number[division_id] = number + 1
	var m: Dictionary = {
		"id": "%s_%03d" % [division_id, number], "name": String(person.name), "nickname": String(person.nickname),
		"hometown": String(person.hometown), "country": String(person.country),
		"style": style_id, "seed": rng.randi(), "level": shift, "tier": String(level.id), "pro": pro,
		"born": snappedf(age - float(week) / Career.WEEKS_PER_YEAR, 0.01),
		"frame": { "height_cm": int(body.frame.height_cm), "reach_cm": int(body.frame.reach_cm), "adult_kg": float(body.frame.adult_kg) },
		"record": _past_record(rng, level, age), "met_week": -1, "met_close": false,
		"division": division_id if pro else "",
	}
	WorldWeeks.set_up(self, m, rng, week)
	men[String(m.id)] = m
	_names_used[String(m.name)] = true
	return m


## A stand-in record for his years before the career (D358's history replaces it): about `per_year` fights a year since
## he started (16 for an amateur, PRO_FROM_AGE for a pro), won at his level's rate.
func _past_record(rng: RandomNumberGenerator, level: Dictionary, age: float) -> Dictionary:
	var from: float = float(AMATEUR_FROM_AGE) if not bool(level.pro) else float(PRO_FROM_AGE + rng.randi_range(-PRO_FROM_SPREAD, PRO_FROM_SPREAD))
	var years: float = maxf(0.0, age - from)
	var fights: int = roundi(years * float(level.per_year) * rng.randf_range(0.6, 1.2))
	if bool(level.pro):
		fights = maxi(fights, 1)
	var share: float = rng.randf_range(float(level.win[0]), float(level.win[1]))
	var out := { "win": 0, "loss": 0, "draw": 0 }
	for i in fights:
		if rng.randf() < DRAW_CHANCE:
			out.draw += 1
		elif rng.randf() < share:
			out.win += 1
		else:
			out.loss += 1
	return out


## A country for a man from abroad: any, the hotbeds the most (names@1 `hotbed`).
func _hotbed(rng: RandomNumberGenerator) -> String:
	var ids: Array = _names.countries()
	var total: float = 0.0
	for id: String in ids:
		total += _names.hotbed(id)
	var roll: float = rng.randf() * total
	for id: String in ids:
		roll -= _names.hotbed(id)
		if roll < 0.0:
			return id
	return String(ids.back())


## A style for a man from this country: any, the ones it's known for (names@1 `styles`) HOME_STYLE_WEIGHT times as often.
func _style_for(rng: RandomNumberGenerator, from_id: String) -> String:
	var ids: Array = _styles.ids().duplicate()
	ids.sort()
	var home: Array = _names.home_styles(from_id)
	var weights: Array[float] = []
	var total: float = 0.0
	for id: String in ids:
		var w: float = HOME_STYLE_WEIGHT if id in home else 1.0
		weights.append(w)
		total += w
	var roll: float = rng.randf() * total
	for i in ids.size():
		roll -= weights[i]
		if roll < 0.0:
			return String(ids[i])
	return String(ids.back())


func _name_taken(full_name: String) -> bool:
	return _names_used.has(full_name)


## The world as plain data for the career's save (docs/09 career@1 `world`).
func to_dict() -> Dictionary:
	return { "version": VERSION, "seed": str(seed_value), "country_id": country_id, "hometown": hometown,
		"men": men.values().map(func(m: Dictionary) -> Dictionary: return m.duplicate(true)), "next_number": next_number.duplicate(),
		"played": played, "results": results.duplicate(true) }


## A world back from to_dict() (after a trip through JSON, so whole numbers may come back as floats).
static func from_dict(data: Dictionary, p_styles: StyleLibrary = null, p_names: NameLibrary = null, p_roster: FighterLibrary = null) -> World:
	var w := World.new(p_styles, p_names, p_roster)
	w.seed_value = String(data.get("seed", "0")).to_int()
	w.country_id = String(data.get("country_id", ""))
	w.hometown = String(data.get("hometown", ""))
	for raw: Variant in data.get("men", []):
		if not raw is Dictionary:
			continue
		var m: Dictionary = (raw as Dictionary).duplicate(true)
		if m.has("seed"):
			m.seed = int(m.seed)
		m.level = int(m.get("level", 0))
		m.met_week = int(m.get("met_week", -1))
		for key: String in ["next_week", "out_until", "retired"]:
			if m.has(key):
				m[key] = int(m[key])
		for entry: Variant in m.get("history", []):
			if entry is Array and not (entry as Array).is_empty():
				entry[0] = int(entry[0])
		for key: String in ["win", "loss", "draw"]:
			m.record[key] = int(m.get("record", {}).get(key, 0))
			if m.get("amateur_record") is Dictionary:
				m.amateur_record[key] = int(m.amateur_record.get(key, 0))
		for key: String in ["joined", "turned_pro"]:
			if m.has(key):
				m[key] = int(m[key])
		if m.get("frame") is Dictionary:
			for key: String in ["height_cm", "reach_cm"]:
				m.frame[key] = int(m.frame.get(key, 0))
		w.men[String(m.id)] = m
		w._names_used[String(m.name)] = true
	for key: Variant in data.get("next_number", {}):
		w.next_number[String(key)] = int(data.next_number[key])
	w.played = int(data.get("played", -1))
	w.results = (data.get("results", []) as Array).duplicate(true) if data.get("results") is Array else []
	for r: Variant in w.results:
		if r is Dictionary:
			for key: String in ["week", "round"]:
				if r.has(key):
					r[key] = int(r[key])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([w.seed_value, "set up"])
	for m: Dictionary in w.men.values():
		if active(m):
			WorldWeeks.set_up(w, m, rng, maxi(0, w.played + 1))  # A world saved before D353: what the weeks need.
	return w
