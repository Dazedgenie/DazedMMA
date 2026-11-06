class_name GymRepute
extends RefCounted
## Your gym's name (docs/03 §14.8, D446): one number, 0 to MAX, for how well known the gym is, shown as a word
## (LEVEL_NAMES: Unknown, Known in town, Known in the region, Known nationally, World famous) and a bar to the next.
##
## What makes it, added up (`parts`):
##   fights      every fight your lad and your stable have had for the gym: a win WIN_AMATEUR as an amateur, WIN_PRO
##               times his promotion's PROMOTION_SHARE as a pro (a finish FINISH_SHARE more, a title fight won
##               TITLE_WIN more), a pro loss LOSS_PRO times it off. Each fades by half every HALF_LIFE_WEEKS.
##   standing    the men fighting for the gym now: RANKED for each ranked man, CHAMPION for each belt, times his
##               promotion's PROMOTION_SHARE.
##   facilities  PER_ROOM_LEVEL for every room level built since it opened, PER_COACH_LEVEL for every coach's level.
##   trouble     MAN_LEFT off for a man who left you unhappy, COACH_WALKED for a coach who walked out unpaid,
##               BEHIND_ON_RENT for each month the gym starts behind on the rent; fading as fights do.
## Your stable's fights and the trouble are kept as marks on the gym (`repute_marks`); his own fights are read from his
## record, so a career saved before D446 has a name from day one.
##
## What it does: members (Gym.members_target: MEMBERS_PER_POINT for each point of fights, standing and trouble), the
## chance a man signs (Stable.yes_chance) and who'll sign (national pros from Known nationally, world-class from World
## famous, Stable.prospects), which coaches will come (level 2 from Known in town, level 3 from Known in the region,
## Staff.cant_hire), lads walking in (Lads.month), and news when it moves a level.
##
## The career works it out (Career.refresh_repute) and keeps it on the gym as `repute` ({ score, parts, level }), so
## the gym's own code reads it with score() and level() without the world. Pure: no Node use.

## The levels: the score each starts at, and its words.
const LEVELS: Array[float] = [0.0, 10.0, 30.0, 55.0, 80.0]
const LEVEL_NAMES: Array[String] = ["Unknown", "Known in town", "Known in the region", "Known nationally", "World famous"]
const TOWN: int = 1
const REGION: int = 2
const NATIONAL: int = 3
const WORLD: int = 4
const MAX: float = 100.0
## Fights: points for a win as an amateur and as a pro, a finish's share more, a title fight won, a pro loss.
const WIN_AMATEUR: float = 1.0
const WIN_PRO: float = 2.0
const FINISH_SHARE: float = 0.5
const TITLE_WIN: float = 6.0
const LOSS_PRO: float = 0.5
## A pro's points by his promotion's rank (Promotions: 0 the world organisation, 1 the international one, 2 regional).
const PROMOTION_SHARE: Array[float] = [3.0, 2.0, 1.0]
## Marks and his fights count half after this many weeks, a quarter after twice it.
const HALF_LIFE_WEEKS: float = 104.0
## Standing: each ranked man, each belt.
const RANKED: float = 3.0
const CHAMPION: float = 8.0
## Facilities: each room level built since it opened, each coach's level.
const PER_ROOM_LEVEL: float = 0.5
const PER_COACH_LEVEL: float = 1.0
## Trouble.
const MAN_LEFT: float = 6.0
const COACH_WALKED: float = 6.0
const BEHIND_ON_RENT: float = 4.0
## Members: how many each point of fights, standing and trouble brings (Gym.members_target).
const MEMBERS_PER_POINT: float = 1.5
## The marks kept: older ones count for next to nothing.
const MARKS_KEPT: int = 200

## News when the name moves a level: { kind, level (its index), up (bool) }.
const MOVED := "gym_name"


## The gym's name as last worked out (0 to MAX).
static func score(gym: Dictionary) -> float:
	return float(gym.get("repute", {}).get("score", 0.0)) if gym.get("repute") is Dictionary else 0.0


## Its level (index into LEVELS) as last worked out.
static func level(gym: Dictionary) -> int:
	return level_of(score(gym))


## The level a score is at.
static func level_of(points: float) -> int:
	var out: int = 0
	for i in LEVELS.size():
		if points >= LEVELS[i]:
			out = i
	return out


## "Known in the region".
static func level_name(i: int) -> String:
	return LEVEL_NAMES[clampi(i, 0, LEVEL_NAMES.size() - 1)]


## The share of the way from this level to the next (1.0 at the top).
static func to_next(points: float) -> float:
	var i: int = level_of(points)
	if i >= LEVELS.size() - 1:
		return 1.0
	return clampf((points - LEVELS[i]) / (LEVELS[i + 1] - LEVELS[i]), 0.0, 1.0)


## The part of the name that brings members: fights, standing and trouble, not the rooms and coaches (they bring their
## own members, Gym.members_target).
static func fame(gym: Dictionary) -> float:
	var parts: Dictionary = gym.get("repute", {}).get("parts", {}) if gym.get("repute") is Dictionary else {}
	return maxf(0.0, float(parts.get("fights", 0.0)) + float(parts.get("standing", 0.0)) + float(parts.get("trouble", 0.0)))


## How much a mark or fight from `then` counts at `week`.
static func fade(then: int, week: int) -> float:
	return pow(0.5, maxf(0.0, float(week - then)) / HALF_LIFE_WEEKS)


## A fight's points for the gym: `result` (win, loss or draw), `method` (ko, submission, decision, …), `pro`, his
## promotion's rank (Promotions.MAJOR … REGIONAL, -1 for none) and whether it was a title fight.
static func fight_points(result: String, method: String, pro: bool, promotion_rank: int, title: bool = false) -> float:
	if not pro:
		return WIN_AMATEUR if result == "win" else 0.0
	var share: float = PROMOTION_SHARE[clampi(promotion_rank, 0, PROMOTION_SHARE.size() - 1)] if promotion_rank >= 0 else 1.0
	if result == "win":
		var out: float = WIN_PRO * share
		if WorldWeeks._method(method) in ["ko", "submission"]:
			out *= 1.0 + FINISH_SHARE
		return out + (TITLE_WIN * share if title else 0.0)
	if result == "loss":
		return -LOSS_PRO * share
	return 0.0


## Puts a mark on the gym (a stable man's fight, or trouble): `points` from `week`, with what it was.
static func mark(gym: Dictionary, week: int, points: float, why: String) -> void:
	if gym.is_empty() or absf(points) < 0.0001:
		return
	if not gym.get("repute_marks") is Array:
		gym.repute_marks = []
	(gym.repute_marks as Array).append({ "week": week, "points": snappedf(points, 0.01), "why": why })
	while (gym.repute_marks as Array).size() > MARKS_KEPT:
		(gym.repute_marks as Array).pop_front()


## The gym's marks added up at `week`, faded: { fights, trouble }.
static func marks_at(gym: Dictionary, week: int) -> Dictionary:
	var out := { "fights": 0.0, "trouble": 0.0 }
	for m: Dictionary in gym.get("repute_marks", []):
		var p: float = float(m.get("points", 0.0)) * fade(int(m.get("week", week)), week)
		out["trouble" if String(m.get("why", "")) in ["left", "walked", "rent"] else "fights"] += p
	return out


## Rooms and coaches: { facilities }.
static func facilities(gym: Dictionary) -> float:
	var rooms: int = maxi(0, Gym.levels(gym) - int(gym.get("levels_start", Gym.levels(gym))))
	return PER_ROOM_LEVEL * rooms + PER_COACH_LEVEL * Staff.levels(gym)


## Works the name out and keeps it on the gym (`repute`: { score, parts }). `his_fights` is the score of his own fights
## (Career's), `standing` the ranked men and belts now. Returns the score.
static func work_out(gym: Dictionary, week: int, his_fights: float, standing: float) -> float:
	var marks: Dictionary = marks_at(gym, week)
	var parts := { "fights": snappedf(his_fights + float(marks.fights), 0.01), "standing": snappedf(standing, 0.01),
		"facilities": snappedf(facilities(gym), 0.01), "trouble": snappedf(float(marks.trouble), 0.01) }
	var total: float = clampf(float(parts.fights) + float(parts.standing) + float(parts.facilities) + float(parts.trouble), 0.0, MAX)
	gym.repute = { "score": snappedf(total, 0.01), "parts": parts }
	return total


## The gym page's line: "Known in town · 14 of 30 to Known in the region".
static func line(gym: Dictionary) -> String:
	var s: float = score(gym)
	var i: int = level_of(s)
	if i >= LEVELS.size() - 1:
		return "%s · %d" % [level_name(i), roundi(s)]
	return "%s · %d of %d to %s" % [level_name(i), roundi(s), roundi(LEVELS[i + 1]), level_name(i + 1)]


## What it's made of, in words: "fights 9 · ranked men and belts 3 · rooms and coaches 5 · trouble −2".
static func parts_line(gym: Dictionary) -> String:
	var parts: Dictionary = gym.get("repute", {}).get("parts", {}) if gym.get("repute") is Dictionary else {}
	var bits: Array[String] = []
	for k: String in ["fights", "standing", "facilities", "trouble"]:
		var v: float = float(parts.get(k, 0.0))
		if absf(v) < 0.5:
			continue
		var words: String = { "fights": "fights", "standing": "ranked men and belts", "facilities": "rooms and coaches",
			"trouble": "trouble" }[k]
		bits.append("%s %s%d" % [words, "−" if v < 0.0 else "", absi(roundi(v))])
	return " · ".join(PackedStringArray(bits)) if not bits.is_empty() else "no fights for the gym yet"


## The news's words.
static func news_text(event: Dictionary, gym_name: String = "") -> String:
	var who: String = gym_name if gym_name != "" else "Your gym"
	var i: int = int(event.get("level", 0))
	if bool(event.get("up", true)):
		return "%s is %s now: %s" % [who, level_name(i).to_lower(), what_opens(i)]
	return "%s's name is slipping: %s now" % [who, level_name(i).to_lower()]


## What a level opens, for the news.
static func what_opens(i: int) -> String:
	match i:
		TOWN:
			return "more members, and level 2 coaches will come"
		REGION:
			return "level 3 coaches will come"
		NATIONAL:
			return "national-level pros will sign"
		WORLD:
			return "world-class men will sign"
	return "more members"


## The least level a coach of `coach_level` comes for (Staff.cant_hire): level 1 anywhere, 2 from Known in town, 3 from
## Known in the region.
static func coach_needs(coach_level: int) -> int:
	return clampi(coach_level - 1, 0, REGION)


## The least level a man of `tier` signs for (Stable.prospects): national from Known nationally, world from World
## famous, the rest anywhere.
static func tier_needs(tier: String) -> int:
	return { "national": NATIONAL, "world": WORLD }.get(tier, 0)
