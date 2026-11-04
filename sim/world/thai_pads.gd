class_name ThaiPads
extends RefCounted
## The Thai pads minigame (docs/03 §13.7, D413): aim and timing. The pad holder sets a pad where he wants a strike (a pad
## high by his head for a head kick, flat in front of his face for an elbow, on his ribs for a body kick, both pads at his
## belly for a knee, the thigh pad for a low kick) and the player throws the matching strike before he drops it. Now and
## then he kicks back and the player checks it. Quicker is better: a strike in the first part of the pad's time is
## perfect, a later one good. From Kicking COMBO_FROM he flashes two or three pads in a row. It plays a Thai pads
## session; how well it went is the session's quality (TrainingCamp.PLAYED_MIN–PLAYED_MAX).
##
## Pure logic and seeded: the round is a list of pads in seconds from the start, and `press(key, at)` judges a strike
## at a time. The screen (ui/thai_pads_screen.gd) feeds it real key presses; tests feed it exact ones.

const HEAD_KICK := "head_kick"
const ELBOW := "elbow"
const BODY_KICK := "body_kick"
const KNEE := "knee"
const LOW_KICK := "low_kick"
const CHECK := "check"
## The strikes he holds pads for, top to bottom (keys 1–5 on the screen), and the check for his kick back.
const STRIKES: Array[String] = [HEAD_KICK, ELBOW, BODY_KICK, KNEE, LOW_KICK]
const NAMES := {
	"head_kick": "head kick", "elbow": "elbow", "body_kick": "body kick", "knee": "knee", "low_kick": "low kick",
	"check": "check",
}

## About a minute (D38), after a short count-in.
const ROUND_SECONDS: float = 60.0
const COUNT_IN: float = 1.5
## How long a pad stays up: OPEN_SLOW seconds at Kicking LEVEL_LOW down to OPEN_FAST at LEVEL_HIGH; and the gap before
## the next pad (or combination) goes up, GAP_SLOW to GAP_FAST.
const OPEN_SLOW: float = 1.2
const OPEN_FAST: float = 0.65
const GAP_SLOW: float = 1.1
const GAP_FAST: float = 0.5
const LEVEL_LOW: float = 20.0
const LEVEL_HIGH: float = 90.0
## A strike in this first share of a pad's time is perfect; after it, good until the pad drops.
const PERFECT_SHARE: float = 0.45
## Combinations: from Kicking COMBO_FROM a set of pads is two in a row COMBO_CHANCE of the time, and from TRIPLE_FROM a
## two may be three (TRIPLE_CHANCE). Each pad in a combination is up for COMBO_SHARE of a single pad's time, and the
## next goes up as it drops.
const COMBO_FROM: float = 60.0
const TRIPLE_FROM: float = 80.0
const COMBO_CHANCE: float = 0.5
const TRIPLE_CHANCE: float = 0.5
const COMBO_SHARE: float = 0.75
## He kicks back (a check wanted) this share of single pads.
const CHECK_CHANCE: float = 0.15
## Tired legs: from fatigue TIRED_FROM a pad's time shrinks in a line to × TIRED_FLOOR at 100 (as mitt work's windows).
const TIRED_FROM: float = 40.0
const TIRED_FLOOR: float = 0.6
## Accuracy: a perfect strike counts 1, a good one GOOD_CREDIT; each stray strike (no pad up) takes STRAY_COST off.
const GOOD_CREDIT: float = 0.6
const STRAY_COST: float = 0.25

const PERFECT := "perfect"
const GOOD := "good"
const MISS := "miss"

var kicking: float
var fatigue: float
## How long a single pad stays up, and the gap after a set, for this man this session.
var open: float
var gap: float
## Each pad: { t: when it goes up, until: when he drops it, key: a STRIKES id or CHECK, combo: index of its set,
## result: "" until judged }.
var pads: Array[Dictionary] = []
## Each set: { t, first: its first pad's index, count }.
var sets: Array[Dictionary] = []
var counts := { PERFECT: 0, GOOD: 0, MISS: 0, "stray": 0 }


func _init(kicking_in: float, fatigue_in: float, round_seed: int) -> void:
	kicking = kicking_in
	fatigue = fatigue_in
	var level: float = clampf((kicking - LEVEL_LOW) / (LEVEL_HIGH - LEVEL_LOW), 0.0, 1.0)
	var tired: float = 1.0 - (1.0 - TIRED_FLOOR) * clampf((fatigue - TIRED_FROM) / (100.0 - TIRED_FROM), 0.0, 1.0)
	open = lerpf(OPEN_SLOW, OPEN_FAST, level) * tired
	gap = lerpf(GAP_SLOW, GAP_FAST, level)
	_build(round_seed)


## How many pads a set can hold at this Kicking.
func most_in_a_set() -> int:
	return 3 if kicking >= TRIPLE_FROM else (2 if kicking >= COMBO_FROM else 1)


func _build(round_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = round_seed
	var at: float = COUNT_IN
	while at < COUNT_IN + ROUND_SECONDS:
		var count: int = 1
		if most_in_a_set() >= 2 and rng.randf() < COMBO_CHANCE:
			count = 2
			if most_in_a_set() >= 3 and rng.randf() < TRIPLE_CHANCE:
				count = 3
		var each: float = open if count == 1 else open * COMBO_SHARE
		sets.append({ "t": at, "first": pads.size(), "count": count })
		var last: String = ""
		for i in count:
			var key: String = CHECK if count == 1 and rng.randf() < CHECK_CHANCE else STRIKES[rng.randi_range(0, STRIKES.size() - 1)]
			if key == last:  # Never the same pad twice in a row in a set: he moves it.
				key = STRIKES[(STRIKES.find(key) + 1 + rng.randi_range(0, STRIKES.size() - 2)) % STRIKES.size()]
			last = key
			pads.append({ "t": at, "until": at + each, "key": key, "combo": sets.size() - 1, "result": "" })
			at += each
		at += gap


## When the round is over: as the last pad drops.
func length() -> float:
	return float(pads[-1].until) if not pads.is_empty() else 0.0


func is_over(at: float) -> bool:
	return at >= length()


## The pad up at `at`, or {} between them.
func pad_at(at: float) -> Dictionary:
	for p in pads:
		if at >= float(p.t) and at < float(p.until):
			return p
		if float(p.t) > at:
			break
	return {}


## Judges a strike (a STRIKES id or CHECK) at `at` seconds against the pad up then. The right strike is perfect in the
## first PERFECT_SHARE of the pad's time and good after; the wrong one misses that pad. No pad up (or one already hit)
## is a stray strike. Returns { result: perfect/good/miss/stray, pad: index or −1 }.
func press(key: String, at: float) -> Dictionary:
	miss_late(at)
	var index: int = -1
	for i in pads.size():
		if at >= float(pads[i].t) and at < float(pads[i].until):
			index = i
			break
	if index < 0 or pads[index].result != "":
		counts.stray += 1
		return { "result": "stray", "pad": -1 }
	var pad: Dictionary = pads[index]
	var share: float = (at - float(pad.t)) / (float(pad.until) - float(pad.t))
	var result: String = MISS if pad.key != key else (PERFECT if share <= PERFECT_SHARE else GOOD)
	pad.result = result
	counts[result] += 1
	return { "result": result, "pad": index }


## Every pad dropped before `at` without a strike is a miss. Returns how many it marked.
func miss_late(at: float) -> int:
	var marked: int = 0
	for pad in pads:
		if pad.result == "" and float(pad.until) <= at:
			pad.result = MISS
			counts[MISS] += 1
			marked += 1
	return marked


## 0–1: perfect strikes count 1, good ones GOOD_CREDIT, stray strikes take STRAY_COST off, over every pad.
func accuracy() -> float:
	if pads.is_empty():
		return 0.0
	var credit: float = counts[PERFECT] + GOOD_CREDIT * counts[GOOD] - STRAY_COST * counts.stray
	return clampf(credit / pads.size(), 0.0, 1.0)


## The session's quality: TrainingCamp.PLAYED_MIN with nothing hit up to PLAYED_MAX for a perfect round.
func quality() -> float:
	return lerpf(TrainingCamp.PLAYED_MIN, TrainingCamp.PLAYED_MAX, accuracy())
