class_name Scouting
extends RefCounted
## What you know of the man you're fighting (D401, docs/03 §13.1). Pure logic and seeded.
##
## **His grades.** An offer shows each attribute group's grade as a range (Striking B–A) until he's scouted: the range
## is SPREAD points wide when you know nothing of him, narrowing to his one true grade as you get to know him, with the
## truth somewhere inside (not always the middle). How well you know him (0–1): his fights on film (FILM_PER_FIGHT a
## fight on his record, up to FILM_MAX), having fought him before (MET), and what film study in this camp has added.
##
## **His habits.** A man's tells (fighter@1 `tells`, D11) are found one at a time: each film study session done in a
## camp has a chance to find one he hasn't shown you yet, better with a high Fight IQ, more of his fights on film, and a
## Tactician for a head coach. In a career fight only found habits get the tell cue (D51); one you haven't found is
## still in his fighting, and seeing it go off SPOT_FIRES times in a fight (Watch) counts as finding it, for the rest of
## the fight and for good. Quick fight cues every tell, as before.
##
## The career keeps it as `scouting`: man id → { known (what film study has added, 0–1), tells (found tells' keys) }.

## A grade range this many points wide when you know nothing of him, narrowing to nothing when you know him fully.
const SPREAD: float = 16.0
## How far off the middle of the range the truth may sit, as a share of half the range.
const OFFSET: float = 0.6
## What his fights on film tell you: this much a fight on his record, at most FILM_MAX.
const FILM_PER_FIGHT: float = 0.03
const FILM_MAX: float = 0.45
## Having fought him before.
const MET: float = 0.5
## A film study session done in camp adds this much at Fight IQ 50, ±STUDY_IQ of it at Fight IQ 100 or 0.
const STUDY_GAIN: float = 0.2
const STUDY_IQ: float = 0.5
## The chance a film study session finds one of his habits: FIND_BASE, + FIND_PER_IQ × Fight IQ / 100,
## + FIND_PER_FIGHT a fight of his on film (at most FIND_FILM_MAX), + FIND_TACTICIAN with a Tactician head coach,
## + the video room's `finds` a level (Gym.finds_bonus, D442).
const FIND_BASE: float = 0.25
const FIND_PER_IQ: float = 0.3
const FIND_PER_FIGHT: float = 0.01
const FIND_FILM_MAX: float = 0.15
const FIND_TACTICIAN: float = 0.15
## Seeing an unfound habit go off this many times in a fight finds it.
const SPOT_FIRES: int = 3
## The session that studies him.
const FILM_STUDY := "film_study"
## How each trigger reads in a habit ("when his jab is blocked, he throws a body kick").
const TRIGGER_TEXT := {
	"own_jab_blocked": "when his jab is blocked",
	"opp_strike_misses": "when he makes you miss",
	"own_stance_shift": "when he shifts his stance",
	"opp_kick_starts": "when you start a kick",
	"opp_shot_starts": "when you shoot",
}

static var _actions: ActionLibrary


## A tell's key: its trigger and its move ("own_jab_blocked>body_kick").
static func key(tell: Dictionary) -> String:
	return "%s>%s" % [String(tell.get("trigger", "")), String(tell.get("action", ""))]


## How many fights he has on film: his world record, or the record his offer came with.
static func fights_on_film(c: Career, id: String) -> int:
	var m: Dictionary = c.world().man(id) if c != null else {}
	if not m.is_empty():
		var r: Dictionary = m.get("record", {})
		return int(r.get("win", 0)) + int(r.get("loss", 0)) + int(r.get("draw", 0))
	return 0


## Whether the career's fighter has fought him before.
static func met(c: Career, id: String) -> bool:
	for f: Dictionary in c.fights:
		if String(f.get("opponent", "")) == id:
			return true
	return false


## How well you know him, 0–1: his fights on film, having fought him, and film study.
static func knowledge(c: Career, id: String) -> float:
	var k: float = minf(FILM_MAX, FILM_PER_FIGHT * fights_on_film(c, id))
	if met(c, id):
		k += MET
	k += float(c.scouting.get(id, {}).get("known", 0.0))
	return clampf(k, 0.0, 1.0)


## A grade as scouted: [low, high] grade letters for a true value, `known` 0–1, the same every time for the same seed.
static func grade_range(value: float, known: float, scout_seed: int) -> Array[String]:
	var half: float = SPREAD * 0.5 * (1.0 - clampf(known, 0.0, 1.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = scout_seed
	var centre: float = value + rng.randf_range(-OFFSET, OFFSET) * half
	return [TrainingCamp.grade(clampf(centre - half, 0.0, 100.0)), TrainingCamp.grade(clampf(centre + half, 0.0, 100.0))]


## "B" when the range is one grade, else "B–A" (low first).
static func range_text(grades: Array[String]) -> String:
	return grades[0] if grades[0] == grades[1] else "%s–%s" % [grades[0], grades[1]]


## His grades by attribute group as scouted, e.g. "Striking B–A · Wrestling C · Grappling D–C · Physical C".
## `groups` maps stat id → group name; `known` 0–1 (1 shows the true grades).
static func grades_text(stats: Dictionary, groups: Dictionary, group_names: Array[String], known: float, scout_seed: int) -> String:
	var bits: Array[String] = []
	for group in group_names:
		var total: float = 0.0
		var n: int = 0
		for id: String in groups:
			if String(groups[id]) == group:
				total += float(stats.get(id, FighterState.DEFAULT_STAT))
				n += 1
		if n > 0:
			bits.append("%s %s" % [group, range_text(grade_range(total / n, known, hash([scout_seed, group])))])
	return " · ".join(bits)


## The seed his scouted ranges come from in a career: the same man always scouts the same.
static func seed_for(c: Career, id: String) -> int:
	return hash([c.career_seed, id, "scouting"])


## The keys of the habits of his you've found.
static func found(c: Career, id: String) -> Array[String]:
	var out: Array[String] = []
	for k: Variant in c.scouting.get(id, {}).get("tells", []):
		out.append(String(k))
	return out


## His habits you haven't found yet.
static func unfound(c: Career, profile: Dictionary) -> Array[Dictionary]:
	var have: Array[String] = found(c, String(profile.get("id", "")))
	var out: Array[Dictionary] = []
	for t: Variant in profile.get("tells", []):
		if t is Dictionary and not have.has(key(t)):
			out.append(t)
	return out


## The chance one film study session finds a habit of his.
static func find_chance(c: Career, id: String) -> float:
	var chance: float = FIND_BASE + FIND_PER_IQ * c.trainee.stat("fight_iq") / 100.0
	chance += minf(FIND_FILM_MAX, FIND_PER_FIGHT * fights_on_film(c, id))
	if c.coach_specialty == Coach.TACTICIAN:
		chance += FIND_TACTICIAN
	chance += Gym.finds_bonus(c.gym)
	return clampf(chance, 0.0, 1.0)


## What `sessions` film study sessions in a camp week found out about the booked man: knowledge added, and a roll a
## session to find a habit he hasn't shown you. Returns the habits found (fighter@1 tells). Seeded by the week.
static func study(c: Career, profile: Dictionary, sessions: int) -> Array[Dictionary]:
	var id: String = String(profile.get("id", ""))
	var out: Array[Dictionary] = []
	if id == "" or sessions <= 0:
		return out
	var entry: Dictionary = c.scouting.get(id, { "known": 0.0, "tells": [] })
	var gain: float = study_gain(c)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([c.career_seed, c.week, id, "film"])
	for n in sessions:
		entry.known = minf(1.0, float(entry.get("known", 0.0)) + gain)
		c.scouting[id] = entry
		var left: Array[Dictionary] = unfound(c, profile)
		if not left.is_empty() and rng.randf() < find_chance(c, id):
			var t: Dictionary = left[rng.randi_range(0, left.size() - 1)]
			(entry.tells as Array).append(key(t))
			out.append(t)
	c.scouting[id] = entry
	return out


## What a film study session adds to how well you know him (STUDY_GAIN, more with a high Fight IQ).
static func study_gain(c: Career) -> float:
	return STUDY_GAIN * (1.0 + STUDY_IQ * (c.trainee.stat("fight_iq") - 50.0) / 50.0)


## `sessions` film study sessions that only add to how well you know him (no roll for a habit: the film study minigame
## found one for sure, D410).
static func study_known(c: Career, id: String, sessions: int) -> void:
	if id == "" or sessions <= 0:
		return
	var entry: Dictionary = c.scouting.get(id, { "known": 0.0, "tells": [] })
	entry.known = minf(1.0, float(entry.get("known", 0.0)) + study_gain(c) * sessions)
	c.scouting[id] = entry


## Habits spotted in a fight (Watch.spotted) count as found for good.
static func learn(c: Career, id: String, keys: Array) -> void:
	if id == "" or keys.is_empty():
		return
	var entry: Dictionary = c.scouting.get(id, { "known": 0.0, "tells": [] })
	for k: Variant in keys:
		if not (entry.tells as Array).has(String(k)):
			(entry.tells as Array).append(String(k))
	c.scouting[id] = entry


## A habit in words: "When his jab is blocked, he throws a body kick (7 times in 10, within 1.5 s)".
static func tell_text(tell: Dictionary) -> String:
	if _actions == null:
		_actions = ActionLibrary.load_dir()
	var trigger: String = String(tell.get("trigger", ""))
	var when: String = String(TRIGGER_TEXT.get(trigger, trigger.replace("_", " ")))
	var action: String = String(tell.get("action", ""))
	var move: String = String(_actions.get_action(action).get("name", action)).to_lower() if _actions.has(action) else action.replace("_", " ")
	var article: String = "an" if move.substr(0, 1) in ["a", "e", "i", "o", "u"] else "a"
	return "%s, he throws %s %s (%d times in 10, within %.1f s)" % [when.substr(0, 1).to_upper() + when.substr(1), article,
		move, roundi(float(tell.get("chance", 0.0)) * 10.0), float(tell.get("within_ms", 1000)) / 1000.0]


## The camp screen's scouting box: how well you know him, his grades as scouted, the habits found, and what film study
## might still find.
static func report_text(c: Career, profile: Dictionary, groups: Dictionary, group_names: Array[String]) -> String:
	var id: String = String(profile.get("id", ""))
	var k: float = knowledge(c, id)
	var lines: Array[String] = []
	var film: int = fights_on_film(c, id)
	lines.append("Known: %d%% · %d fight%s on film%s" % [roundi(k * 100.0), film, "" if film == 1 else "s",
		" · you've fought him" if met(c, id) else ""])
	lines.append(grades_text(profile.get("stats", {}), groups, group_names, k, seed_for(c, id)))
	var have: Array[String] = found(c, id)
	for t: Variant in profile.get("tells", []):
		if t is Dictionary and have.has(key(t)):
			lines.append("[color=#ffe066]Habit:[/color] %s" % tell_text(t))
			var answers: Array[String] = []
			for rule_id: String in RuleDrilling.available(c):
				if RuleDrilling.answers(rule_id, t):
					answers.append(RuleDrilling.rule_name(rule_id))
			if not answers.is_empty():
				lines.append("  [color=#8a8f98]Drill to beat it:[/color] %s" % ", ".join(answers))  # D403
	var left: int = unfound(c, profile).size()
	if have.is_empty() and left == 0:
		lines.append("[color=#8a8f98]Film study hasn't turned up a habit of his.[/color]" if float(c.scouting.get(id, {}).get("known", 0.0)) > 0.0
			else "[color=#8a8f98]Film study can find his habits and sharpen his grades.[/color]")
	elif left > 0:
		lines.append("[color=#8a8f98]Film study can find more: %d%% a session.[/color]" % roundi(find_chance(c, id) * 100.0))
	else:
		lines.append("[color=#8a8f98]You've found all his habits.[/color]")
	return "\n".join(lines)


## Counts his habits going off in a fight (presentation: the arena feeds it the fight's events), so one you hadn't found
## gets cued once you've seen it SPOT_FIRES times. `known` is the found keys; a null Watch cues everything.
class Watch:
	extends RefCounted
	var known: Array[String] = []
	## Habits found in this fight (keys), in the order they were spotted.
	var spotted: Array[String] = []
	var _fires: Dictionary = {}  # key → times seen
	var _waiting: Dictionary = {}  # key → the last tick its move can follow by

	func _init(known_keys: Array = []) -> void:
		for k: Variant in known_keys:
			known.append(String(k))

	## Whether the habit gets the cue.
	func cues(tell: Dictionary) -> bool:
		return known.has(Scouting.key(tell))

	## His habit's trigger went off at `tick`: its move may follow within its window.
	func set_off(tell: Dictionary, tick: int) -> void:
		_waiting[Scouting.key(tell)] = tick + int(tell.get("within_ms", 1000)) / FightClock.TICK_MS

	## He started `action` at `tick`: a waiting habit with that move went off. Returns the key if that found it.
	func started(action: String, tick: int) -> String:
		for k: String in _waiting.keys():
			if not k.ends_with(">" + action) or tick > int(_waiting[k]):
				continue
			_waiting.erase(k)
			_fires[k] = int(_fires.get(k, 0)) + 1
			if not known.has(k) and int(_fires[k]) >= Scouting.SPOT_FIRES:
				known.append(k)
				spotted.append(k)
				return k
		return ""

	## How many times a habit has gone off this fight.
	func fires(k: String) -> int:
		return int(_fires.get(k, 0))
