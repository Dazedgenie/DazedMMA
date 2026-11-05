class_name Staff
extends RefCounted
## The coaches you hire at your gym (docs/03 §14.3, D443). You stay his head coach (D311); these are specialists on a
## weekly wage, kept on the gym (`gym.coaches`), so they save with it. Each has a role, a level 1–3 and a personality:
##
##   role         (data/enums/coach_roles) a striking, wrestling, BJJ or strength coach makes his attribute group's
##                stats (data/enums/stats) learn `xp` × his level faster, from any session; a nutritionist makes the
##                weight cut cost `cut` × his level less (its gas tank, its Chin and the chance of missing weight)
##   level        what he did as a fighter: a man who held a belt 3, a national or world-class pro 2, the rest 1. A
##                career coach's is rolled at CAREER_LEVEL_ODDS. His wage a week is WAGES by level, and each level
##                brings MEMBERS_PER_LEVEL more members to the gym (Gym.members_target)
##   personality  (data/enums/coach_personalities) hard (`xp` more in his group, injuries × `injury`), patient
##                (injuries × `injury`) or fiery (skips × `skips`)
##
## Who's looking for work (`gym.looking`) changes on the first of every month: LOOKING men, mostly the world's retired
## fighters from his country (a fighter's style says which role he coaches), and CAREER_COACHES coaches who never
## fought. One coach a role. Wages are paid each Monday from the gym's money; a coach the gym can't pay keeps coaching
## UNPAID_WEEKS weeks and walks out on the next one. Pure and seeded: the same month always brings the same men.

const ROLES_PATH := "res://data/enums/coach_roles.json"
const PERSONALITIES_PATH := "res://data/enums/coach_personalities.json"

## A week's wage ($) at levels 1, 2 and 3.
const WAGES: Array[int] = [15, 40, 90]
const LEVELS: int = 3
## Members the gym's heading for, more for each coach's level (as a room's level does, D442).
const MEMBERS_PER_LEVEL: int = 1
## Weeks running a coach goes unpaid and still coaches; unpaid one more and he's gone.
const UNPAID_WEEKS: int = 2
## How many are looking for work each month, and how many of them are career coaches (the rest are retired fighters
## while there are enough of them).
const LOOKING: Array[int] = [3, 5]
const CAREER_COACHES: Array[int] = [1, 2]
## A career coach's level: the odds of 1, 2 and 3.
const CAREER_LEVEL_ODDS: Array[float] = [0.6, 0.3, 0.1]
## Retired fighters older than this don't come looking.
const OLDEST: float = 66.0
## A career coach's age.
const CAREER_AGES: Array[int] = [30, 60]
## Tiers (World.LEVELS) whose retired men coach at level 2.
const LEVEL_TWO_TIERS: Array[String] = ["national", "world"]

static var _roles: Dictionary = {}
static var _personalities: Dictionary = {}


## The roles: id → { name, about, group?, xp?, cut?, styles, career }, in the file's order.
static func roles() -> Dictionary:
	if _roles.is_empty():
		_roles = _load(ROLES_PATH)
	return _roles


static func role(id: String) -> Dictionary:
	return roles().get(id, {})


## A role's name in a sentence: "striking coach", "BJJ coach", "nutritionist".
static func role_words(id: String) -> String:
	var name: String = String(role(id).get("name", "coach"))
	var first: String = name.get_slice(" ", 0)
	return name if first == first.to_upper() else name.left(1).to_lower() + name.substr(1)


## The personalities: id → { name, about, xp?, injury?, skips? }.
static func personalities() -> Dictionary:
	if _personalities.is_empty():
		_personalities = _load(PERSONALITIES_PATH)
	return _personalities


static func personality(id: String) -> Dictionary:
	return personalities().get(id, {})


static func _load(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var data: Variant = JSON.parse_string(file.get_as_text())
	return (data as Dictionary).get("values", {}) if data is Dictionary else {}


# --- Who's on staff ---------------------------------------------------------------------------------------------------

## The gym's coaches, in the order you hired them ([] for a gym saved before D443).
static func coaches(gym: Dictionary) -> Array:
	return gym.get("coaches", []) if gym.get("coaches") is Array else []


## The coach in this role ({} for none).
static func in_role(gym: Dictionary, role_id: String) -> Dictionary:
	for c: Dictionary in coaches(gym):
		if String(c.get("role", "")) == role_id:
			return c
	return {}


static func wage(coach: Dictionary) -> int:
	return WAGES[clampi(int(coach.get("level", 1)), 1, LEVELS) - 1]


## Every coach's wage added up: what the gym pays a week.
static func wages(gym: Dictionary) -> int:
	var out: int = 0
	for c: Dictionary in coaches(gym):
		out += wage(c)
	return out


## Every coach's level added up (members, Gym.members_target).
static func levels(gym: Dictionary) -> int:
	var out: int = 0
	for c: Dictionary in coaches(gym):
		out += int(c.get("level", 1))
	return out


## Why you can't hire him ("" when you can): a coach in that role already, or he's not looking any more.
static func cant_hire(gym: Dictionary, coach: Dictionary) -> String:
	var there: Dictionary = in_role(gym, String(coach.get("role", "")))
	if not there.is_empty():
		return "%s is your %s: let him go first" % [String(there.get("name", "")), role_words(String(coach.get("role", "")))]
	return ""


## Hires the man at `index` of the looking list: off the list, onto the staff from `week`. "" when he's hired, else why
## not.
static func hire(gym: Dictionary, index: int, week: int) -> String:
	var looking: Array = gym.get("looking", [])
	if index < 0 or index >= looking.size():
		return "He's not looking for work now"
	var coach: Dictionary = (looking[index] as Dictionary).duplicate(true)
	var why: String = cant_hire(gym, coach)
	if why != "":
		return why
	looking.remove_at(index)
	coach.since = week
	coach.unpaid = 0
	if not gym.get("coaches") is Array:
		gym.coaches = []
	(gym.coaches as Array).append(coach)
	return ""


## Lets the coach in this role go (no notice to pay). Returns him ({} when there was nobody).
static func let_go(gym: Dictionary, role_id: String) -> Dictionary:
	var list: Array = coaches(gym)
	for i in list.size():
		if String((list[i] as Dictionary).get("role", "")) == role_id:
			var gone: Dictionary = list[i]
			list.remove_at(i)
			return gone
	return {}


## Monday's wages from the gym's `money`, coach by coach in the order you hired them, while there's money to pay each in
## full. A coach paid is owed nothing; one who can't be paid has a week more `unpaid`, and is gone after UNPAID_WEEKS.
## `gym` changes in place. Returns { paid ($), unpaid: [coach], left: [coach] }.
static func pay_week(gym: Dictionary, money: int) -> Dictionary:
	var paid: int = 0
	var unpaid: Array = []
	var left: Array = []
	var keep: Array = []
	for c: Dictionary in coaches(gym):
		var w: int = wage(c)
		if money - paid >= w:
			paid += w
			c.unpaid = 0
			keep.append(c)
			continue
		c.unpaid = int(c.get("unpaid", 0)) + 1
		if int(c.unpaid) > UNPAID_WEEKS:
			left.append(c)
		else:
			unpaid.append(c)
			keep.append(c)
	if gym.has("coaches"):
		gym.coaches = keep
	return { "paid": paid, "unpaid": unpaid, "left": left }


# --- What they do -----------------------------------------------------------------------------------------------------

## Training XP × this for a stat in this attribute group (data/enums/stats): each coach of that group, 1 + `xp` × his
## level, and a hard one's `xp` more.
static func xp_share(gym: Dictionary, group: String) -> float:
	var out: float = 1.0
	if group == "":
		return out
	for c: Dictionary in coaches(gym):
		var r: Dictionary = role(String(c.get("role", "")))
		if String(r.get("group", "")) != group:
			continue
		out *= 1.0 + float(r.get("xp", 0.0)) * int(c.get("level", 1)) + float(personality(String(c.get("personality", ""))).get("xp", 0.0))
	return out


## A session's injury odds × this: each coach's personality's `injury`.
static func injury_share(gym: Dictionary) -> float:
	return _product(gym, "injury")


## The chance he skips × this: each coach's personality's `skips`.
static func skip_share(gym: Dictionary) -> float:
	return _product(gym, "skips")


## The weight cut's costs × this (WeightCut.side `ease`): 1 − `cut` × the nutritionist's level.
static func cut_share(gym: Dictionary) -> float:
	var out: float = 1.0
	for c: Dictionary in coaches(gym):
		out *= maxf(0.0, 1.0 - float(role(String(c.get("role", ""))).get("cut", 0.0)) * int(c.get("level", 1)))
	return out


static func _product(gym: Dictionary, field: String) -> float:
	var out: float = 1.0
	for c: Dictionary in coaches(gym):
		out *= float(personality(String(c.get("personality", ""))).get(field, 1.0))
	return out


## What he does at his level, for the gym page: ["Striking stats learn 10% faster", "15% fewer injuries in training",
## "2 more members"].
static func does_lines(coach: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var r: Dictionary = role(String(coach.get("role", "")))
	var p: Dictionary = personality(String(coach.get("personality", "")))
	var lv: int = int(coach.get("level", 1))
	if r.has("group"):
		var pct: int = roundi((float(r.get("xp", 0.0)) * lv + float(p.get("xp", 0.0))) * 100.0)
		out.append("%s stats learn %d%% faster" % [String(r.group), pct])
	if r.has("cut"):
		out.append("The weight cut costs %d%% less" % roundi(minf(1.0, float(r.cut) * lv) * 100.0))
	if p.has("injury"):
		var injury: float = float(p.injury)
		out.append("%d%% %s injuries in training" % [roundi(absf(injury - 1.0) * 100.0), "more" if injury > 1.0 else "fewer"])
	if p.has("skips"):
		out.append("%d%% fewer sessions skipped" % roundi((1.0 - float(p.skips)) * 100.0))
	out.append("%d more member%s" % [lv * MEMBERS_PER_LEVEL, "" if lv * MEMBERS_PER_LEVEL == 1 else "s"])
	return out


## "Striking coach · level 2 · Hard · $40 a week".
static func title_line(coach: Dictionary) -> String:
	return "%s · level %d · %s · $%d a week" % [String(role(String(coach.get("role", ""))).get("name", "")), int(coach.get("level", 1)),
		String(personality(String(coach.get("personality", ""))).get("name", "")), wage(coach)]


# --- Who's looking for work -------------------------------------------------------------------------------------------

## A month's number from a date ({ year, month }): the looking list changes when it does.
static func month_key(date: Dictionary) -> int:
	return int(date.get("year", 0)) * 12 + int(date.get("month", 1))


## Who's looking for work this month at this gym: LOOKING men, CAREER_COACHES of them career coaches and the rest the
## world's retired fighters from his country (career coaches stand in when there aren't enough), none already on your
## staff. Each is { id, name, role, level, personality, country_id, age, line, from (the world man's id, or "") }.
static func looking(w: World, gym: Dictionary, career_seed: int, key: int, week: int, names: NameLibrary = null) -> Array:
	var lib: NameLibrary = names if names != null else NameLibrary.shared()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([career_seed, key, "coaches looking"])
	var count: int = rng.randi_range(LOOKING[0], LOOKING[1])
	var career: int = mini(count, rng.randi_range(CAREER_COACHES[0], CAREER_COACHES[1]))
	var taken: Dictionary = {}
	for c: Dictionary in coaches(gym):
		taken[String(c.get("id", ""))] = true
	var out: Array = []
	var pool: Array = _retired_pool(w, lib, week, taken)
	for i in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	for m: Dictionary in pool:
		if out.size() >= count - career:
			break
		out.append(from_fighter(w, m, week, rng))
	var country: String = w.country_id if w != null else ""
	var n: int = 0
	while out.size() < count:
		var made: Dictionary = career_coach(rng, country, key, n, lib)
		n += 1
		if not taken.has(String(made.id)):
			out.append(made)
	return out


## The retired fighters who could come looking: from his country (anywhere when he has none), young enough, whose style coaches a role, not on your
## staff. In id order, so the shuffle is the same every time.
static func _retired_pool(w: World, lib: NameLibrary, week: int, taken: Dictionary) -> Array:
	var out: Array = []
	if w == null:
		return out
	var ids: Array = w.men.keys()
	ids.sort()
	for id: String in ids:
		var m: Dictionary = w.men[id]
		if World.active(m) or taken.has(id) or role_for_style(String(m.get("style", ""))) == "":
			continue
		if w.country_id != "" and lib.country_id_of(String(m.get("country", ""))) != w.country_id:
			continue
		if World.age_of(m, week) > OLDEST:
			continue
		out.append(m)
	return out


## The role a fighter of this style coaches ("" for none).
static func role_for_style(style_id: String) -> String:
	for id: String in roles():
		if style_id in role(id).get("styles", []):
			return id
	return ""


## A coach made from a retired world fighter: his style's role, a level from what he did, a personality rolled.
static func from_fighter(w: World, m: Dictionary, week: int, rng: RandomNumberGenerator) -> Dictionary:
	var id: String = String(m.get("id", ""))
	var lv: int = 1
	var line: String = "Retired %s, %s" % [World.level_name(m).to_lower(), World.record_text(m)]
	var tag: String = History.former_tag(w, id) if w != null else ""
	if tag != "":
		lv = 3
		line = "%s, %s" % [tag.left(1).to_upper() + tag.substr(1), World.record_text(m)]
	elif String(m.get("tier", "")) in LEVEL_TWO_TIERS:
		lv = 2
	return { "id": id, "name": String(m.get("name", "")), "role": role_for_style(String(m.get("style", ""))), "level": lv,
		"personality": _personality_roll(rng), "country_id": w.country_id if w != null else "",
		"age": floori(World.age_of(m, week)), "line": line, "from": id }


## A coach who never fought: any role, a level rolled at CAREER_LEVEL_ODDS, a line from his role's `career`.
static func career_coach(rng: RandomNumberGenerator, country_id: String, key: int, n: int, lib: NameLibrary) -> Dictionary:
	var ids: Array = roles().keys()
	var role_id: String = String(ids[rng.randi_range(0, ids.size() - 1)]) if not ids.is_empty() else ""
	var roll: float = rng.randf()
	var lv: int = 1
	var at: float = 0.0
	for i in CAREER_LEVEL_ODDS.size():
		at += CAREER_LEVEL_ODDS[i]
		if roll < at:
			lv = i + 1
			break
	var lines: Array = role(role_id).get("career", [""])
	return { "id": "coach_%d_%d" % [key, n], "name": lib.random_name(rng, country_id), "role": role_id, "level": lv,
		"personality": _personality_roll(rng), "country_id": country_id, "age": rng.randi_range(CAREER_AGES[0], CAREER_AGES[1]),
		"line": String(lines[rng.randi_range(0, lines.size() - 1)]) if not lines.is_empty() else "", "from": "" }


static func _personality_roll(rng: RandomNumberGenerator) -> String:
	var ids: Array = personalities().keys()
	return String(ids[rng.randi_range(0, ids.size() - 1)]) if not ids.is_empty() else ""
