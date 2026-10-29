class_name MittWork
extends RefCounted
## The mitt work minigame (docs/02 §3.9, D137): a rhythm game where the coach calls a
## combination in boxing's numbers ("1-2-3!") and the player hits it on the beat, slipping
## and rolling when the coach swings the mitt back. It plays a Boxing drills session; how
## well it went is the session's quality (TrainingCamp.PLAYED_MIN–PLAYED_MAX).
##
## Pure logic and seeded: the round is a list of notes in seconds from the start, and
## `press(key, at)` judges a key press at a time. The screen (ui/mitt_work_screen.gd) feeds it
## real key presses; tests feed it exact ones.

## The keys: boxing's numbers for the punches, plus the two defences.
const PUNCHES: Array[String] = ["1", "2", "3", "4", "5", "6"]
const SLIP := "slip"
const ROLL := "roll"
const KEY_NAMES := {
	"1": "jab", "2": "cross", "3": "lead hook", "4": "rear hook", "5": "lead uppercut", "6": "rear uppercut",
	"slip": "slip", "roll": "roll",
}

## The coach's calls by level (Boxing): each tier adds its combinations to the ones before.
const TIERS: Array = [
	[0.0, ["1", "1-2", "1-1-2", "2-3"]],
	[40.0, ["1-2-3", "1-2-slip", "3-2", "1-6", "roll-3"]],
	[60.0, ["1-2-3-2", "1-2-slip-2", "1-6-3-2", "5-2-3", "roll-3-2"]],
	[80.0, ["1-2-3-roll-3-2", "1-1-2-3-2", "2-3-2-slip-2", "6-3-2-roll-4", "1-2-5-2-3"]],
]
## The newest tier's calls come up this much more often than older ones.
const NEW_TIER_WEIGHT: float = 2.0

## Tempo: TEMPO_MIN beats a minute at Boxing LEVEL_LOW, rising to TEMPO_MAX at LEVEL_HIGH.
const TEMPO_MIN: float = 84.0
const TEMPO_MAX: float = 132.0
const LEVEL_LOW: float = 20.0
const LEVEL_HIGH: float = 90.0
## A round is about a minute (D38): calls keep coming until this many seconds of hitting.
const ROUND_SECONDS: float = 60.0
## Beats of count-in before the first call, the call itself, and the rest after each combination.
const COUNT_IN_BEATS: int = 4
const CALL_BEATS: int = 1
const REST_BEATS: int = 2

## Timing windows either side of the beat, in seconds.
const PERFECT_WINDOW: float = 0.06
const GOOD_WINDOW: float = 0.14
## Tired hands: from fatigue TIRED_FROM the windows shrink in a line to × TIRED_FLOOR at 100
## (the same 40 where the camp starts learning less, docs/02 §3.5).
const TIRED_FROM: float = 40.0
const TIRED_FLOOR: float = 0.6

## Accuracy: a perfect hit counts 1, a good one GOOD_CREDIT; each stray press (nothing there to hit) takes STRAY_COST off.
const GOOD_CREDIT: float = 0.6
const STRAY_COST: float = 0.25

const PERFECT := "perfect"
const GOOD := "good"
const MISS := "miss"

var boxing: float
var fatigue: float
var tempo: float  # beats a minute
var beat: float  # seconds a beat
var window_scale: float
## Each note: { t: seconds, key, combo: index into calls, result: "" until judged }.
var notes: Array[Dictionary] = []
## Each call: { t: when the coach shouts it, text: "1-2-3", first: its first note's index, count }.
var calls: Array[Dictionary] = []
var counts := { PERFECT: 0, GOOD: 0, MISS: 0, "stray": 0 }


func _init(boxing_in: float, fatigue_in: float, round_seed: int) -> void:
	boxing = boxing_in
	fatigue = fatigue_in
	tempo = lerpf(TEMPO_MIN, TEMPO_MAX, clampf((boxing - LEVEL_LOW) / (LEVEL_HIGH - LEVEL_LOW), 0.0, 1.0))
	beat = 60.0 / tempo
	window_scale = 1.0 - (1.0 - TIRED_FLOOR) * clampf((fatigue - TIRED_FROM) / (100.0 - TIRED_FROM), 0.0, 1.0)
	_build(round_seed)


## The calls this fighter's level can get (every tier up to their Boxing), with their weights.
func pool() -> Dictionary:
	var out: Dictionary = {}
	var top: int = 0
	for i in TIERS.size():
		if boxing >= float(TIERS[i][0]):
			top = i
	for i in top + 1:
		for call: String in TIERS[i][1]:
			out[call] = NEW_TIER_WEIGHT if i == top and top > 0 else 1.0
	return out


func _build(round_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = round_seed
	var choices: Dictionary = pool()
	var names: Array = choices.keys()
	var weights := PackedFloat32Array(names.map(func(c: String) -> float: return choices[c]))
	var at: int = COUNT_IN_BEATS  # in beats
	while (at - COUNT_IN_BEATS) * beat < ROUND_SECONDS:
		var text: String = names[rng.rand_weighted(weights)]
		var keys: PackedStringArray = text.split("-")
		calls.append({ "t": at * beat, "text": text, "first": notes.size(), "count": keys.size() })
		at += CALL_BEATS
		for key in keys:
			notes.append({ "t": at * beat, "key": key, "combo": calls.size() - 1, "result": "" })
			at += 1
		at += REST_BEATS


func perfect_window() -> float:
	return PERFECT_WINDOW * window_scale


func good_window() -> float:
	return GOOD_WINDOW * window_scale


## When the round is over: a beat after the last note.
func length() -> float:
	return float(notes[-1].t) + beat if not notes.is_empty() else 0.0


## Judges a key press (a PUNCHES key, SLIP or ROLL) at `at` seconds: the nearest note not yet judged that's
## inside the good window. The right key scores perfect or good; the wrong one misses that note. Nothing there is
## a stray press. Returns { result: perfect/good/miss/stray, note: index or −1 }.
func press(key: String, at: float) -> Dictionary:
	miss_late(at)
	var best: int = -1
	for i in notes.size():
		if notes[i].result != "":
			continue
		var off: float = absf(float(notes[i].t) - at)
		if off <= good_window() and (best < 0 or off < absf(float(notes[best].t) - at)):
			best = i
		if float(notes[i].t) > at + good_window():
			break
	if best < 0:
		counts.stray += 1
		return { "result": "stray", "note": -1 }
	var off: float = absf(float(notes[best].t) - at)
	var result: String = MISS if notes[best].key != key else (PERFECT if off <= perfect_window() else GOOD)
	notes[best].result = result
	counts[result] += 1
	return { "result": result, "note": best }


## Every note whose window closed before `at` without a hit is a miss. Returns how many it marked.
func miss_late(at: float) -> int:
	var marked: int = 0
	for note in notes:
		if note.result == "" and float(note.t) + good_window() < at:
			note.result = MISS
			counts[MISS] += 1
			marked += 1
	return marked


## 0–1: perfect hits count 1, good ones GOOD_CREDIT, stray presses take STRAY_COST off.
func accuracy() -> float:
	if notes.is_empty():
		return 0.0
	var credit: float = counts[PERFECT] + GOOD_CREDIT * counts[GOOD] - STRAY_COST * counts.stray
	return clampf(credit / notes.size(), 0.0, 1.0)


## The session's quality from the accuracy: TrainingCamp.PLAYED_MIN with nothing hit up to PLAYED_MAX for a perfect round.
func quality() -> float:
	return lerpf(TrainingCamp.PLAYED_MIN, TrainingCamp.PLAYED_MAX, accuracy())


## The call being worked at `at` (from the coach's shout to its last note), or {} between them.
func call_at(at: float) -> Dictionary:
	for c in calls:
		var last: float = float(notes[int(c.first) + int(c.count) - 1].t)
		if at >= float(c.t) and at <= last + beat * 0.5:
			return c
	return {}
