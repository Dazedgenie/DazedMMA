class_name Tutorial
extends RefCounted
## The story as the tutorial (docs/07, docs/03 §11.6, D316). A new career teaches the game in its first three amateur
## fights, one idea a fight, and with a tip card the first time each part of the game shows (data/tips, docs/09 tip@1).
## Kyle (2026-11-01) picked the three ways it works:
##
## - Only fight things are held back ("Fight things only"): the hub, the camp and mitt work are open from the start,
##   each with its tip. In a fight, lesson 1 opens FIRST_CALLS (Pressure!, Circle out!, Takedown! and the calls that
##   share their keys on top and in a hold), lesson 2 adds Catch the kick! and the tell cue, and from lesson 3 every call,
##   his drilled rules and the gameplan are open.
## - Each of his first three sets of offers has a lesson fight, the *Coach's pick* ("One lesson fight per offer set"):
##   an easier man, then a kicker, then a man about his level (LESSONS). The other offers are rolled as usual, and the
##   lessons go by how many fights he's had, whoever he takes.
## - A tip card waits for *Got it* ("A card that waits for Got it"); in a fight the clock holds behind it.
##
## *I know the game* on the new-career screen turns it all off (Career.tutorial false): every call from his first fight
## and no tips, with every tip in the Coach's Notebook. Careers saved before D316 load with it off.
##
## Pure: it reads the career's fights and the tips' data.

## How many lesson fights there are.
const LESSON_FIGHTS: int = 3
## The calls open in lesson 1: the three to learn and the ones sharing their keys in other positions (as in the first
## Playtest fight, docs/07 §3).
const FIRST_CALLS: Array[String] = ["pressure", "circle_out", "takedown", "ground_and_pound", "go_for_the_finish",
	"finish_it", "defend_the_sub"]
## What lesson 2 adds: the read call (Q) the game is built around.
const SECOND_CALLS: Array[String] = ["catch_the_kick"]
## The lesson fights in his first three sets of offers: the kind of man (Matchmaker difficulty, and a style sheet or
## "" for any).
const LESSONS: Array[Dictionary] = [
	{ "difficulty": "easier", "style": "" },
	{ "difficulty": "even", "style": "kicker" },
	{ "difficulty": "even", "style": "" },
]
## Styles lesson 1 and 3 don't roll, so the kicker is fight 2's.
const KICKER_STYLES: Array[String] = ["kicker", "leg_kicker"]
## Where tips show (tip@1 `where`).
const PLACES: Array[String] = ["hub", "offers", "tournament", "camp", "mitt_work", "fight_night", "fight",
	"round_break", "loss", "suspended", "gym_shifts"]
const TIPS_DIR := "res://data/tips/"

static var _tips: Array[Dictionary] = []


## The lesson his next fight is (1 to LESSON_FIGHTS), or 0 once he's had them or the tutorial's off.
static func lesson(c: Career) -> int:
	if not c.tutorial or c.fights.size() >= LESSON_FIGHTS:
		return 0
	return c.fights.size() + 1


## The calls open in a lesson fight, or [] for every call (lesson 0 or from lesson 3).
static func calls(lesson_number: int) -> Array[String]:
	var out: Array[String] = []
	if lesson_number == 1 or lesson_number == 2:
		out.append_array(FIRST_CALLS)
		if lesson_number == 2:
			out.append_array(SECOND_CALLS)
	return out


## Whether the tell cue (the flash before a strike he can read) is on: from lesson 2.
static func tell_cue(lesson_number: int) -> bool:
	return lesson_number != 1


## Whether drilled rules and the gameplan are open: from lesson 3 (and with no lessons).
static func plan_open(lesson_number: int) -> bool:
	return lesson_number == 0 or lesson_number >= LESSON_FIGHTS


## Every tip (data/tips), in `order`.
static func tips() -> Array[Dictionary]:
	if _tips.is_empty():
		for file: String in DirAccess.get_files_at(TIPS_DIR):
			if not file.ends_with(".json"):
				continue
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TIPS_DIR + file))
			if parsed is Dictionary:
				_tips.append(parsed)
		_tips.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("order", 0)) < int(b.get("order", 0)))
	return _tips


static func tip(id: String) -> Dictionary:
	for t: Dictionary in tips():
		if String(t.id) == id:
			return t
	return {}


## The tips due at `where` that he hasn't seen ({} each when the tutorial's off). A tip with a `lesson` shows only
## before that lesson fight. Doesn't mark them: Career.see_tip does.
static func due(c: Career, where: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not c.tutorial:
		return out
	for t: Dictionary in tips():
		if String(t.get("where", "")) != where or String(t.id) in c.tips_seen:
			continue
		if t.has("lesson") and int(t.lesson) != lesson(c):
			continue
		out.append(t)
	return out


## The Coach's Notebook: every tip he's seen, in order (every tip when the tutorial's off: you know the game).
static func notebook(c: Career) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t: Dictionary in tips():
		if not c.tutorial or String(t.id) in c.tips_seen:
			out.append(t)
	return out
