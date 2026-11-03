class_name HeavyBag
extends RefCounted
## The heavy bag minigame (docs/03 §13.6, D412): power timing with chaining. Hold Space to load a shot (the meter climbs
## to the top and back down, over and over, while it's held) and let go with it in the green at the top. The bag swings
## away and comes back on its chain at the same pace however hard it was hit; meet it as it comes back to you and the shot
## counts in full and the chain grows. Let go while it's still swinging away and the shot finds nothing. It plays a Heavy
## bag session; how well it went is the session's quality (TrainingCamp.PLAYED_MIN–PLAYED_MAX).
##
## Pure logic with nothing random: times are seconds from the start, `hold(at)` and `release(at)` are the
## key going down and up. The screen (ui/heavy_bag_screen.gd) feeds it real key presses; tests feed it exact ones.

## About a minute (D38).
const ROUND_SECONDS: float = 60.0
## The bag's swing: away and back to him this long after a shot lands, whatever the shot.
const SWING_SECONDS: float = 1.4
## A shot let go within this long either side of the bag coming back meets it.
const MEET_WINDOW: float = 0.15
## The meter: from empty to the top in LOAD_SLOW seconds at Power LEVEL_LOW, LOAD_FAST at LEVEL_HIGH.
const LOAD_SLOW: float = 1.0
const LOAD_FAST: float = 0.6
## The green at the top of the meter: GREEN_WIDE of it at Power LEVEL_LOW, GREEN_NARROW at LEVEL_HIGH; GOOD_BAND more
## below it is a good shot, and anything lower is weak.
const GREEN_WIDE: float = 0.2
const GREEN_NARROW: float = 0.1
const GOOD_BAND: float = 0.2
const LEVEL_LOW: float = 20.0
const LEVEL_HIGH: float = 90.0
## Tired arms: from fatigue TIRED_FROM the green shrinks in a line to × TIRED_FLOOR at 100 (as mitt work's windows).
const TIRED_FROM: float = 40.0
const TIRED_FLOOR: float = 0.6
## What a shot is worth (0–1): green and meeting the bag 1, green without meeting it MISSED_SWING, a good shot GOOD_CREDIT
## (× MISSED_SWING without meeting it), a weak one WEAK_CREDIT. The first shot, at a still bag, meets it.
const MISSED_SWING: float = 0.6
const GOOD_CREDIT: float = 0.6
const WEAK_CREDIT: float = 0.15
## A shot that finds nothing (the bag still swinging away) takes this off.
const WHIFF_COST: float = 0.25

const GREEN := "green"
const GOOD := "good"
const WEAK := "weak"
const WHIFF := "whiff"

var power: float
var fatigue: float
var load_seconds: float
var green: float
## Every shot let go: { t, load, result: GREEN/GOOD/WEAK/WHIFF, met: bool, score }.
var shots: Array[Dictionary] = []
var counts := { GREEN: 0, GOOD: 0, WEAK: 0, WHIFF: 0 }
## Shots in a row that met the bag, and the longest run.
var chain: int = 0
var best_chain: int = 0

var _held_at: float = -1.0
var _landed_at: float = -1000.0  # When the last shot landed (the bag's swing starts then).
var _landed_power: float = 0.0


func _init(power_in: float, fatigue_in: float) -> void:
	power = power_in
	fatigue = fatigue_in
	var t: float = clampf((power - LEVEL_LOW) / (LEVEL_HIGH - LEVEL_LOW), 0.0, 1.0)
	load_seconds = lerpf(LOAD_SLOW, LOAD_FAST, t)
	green = lerpf(GREEN_WIDE, GREEN_NARROW, t) * (1.0 - (1.0 - TIRED_FLOOR) * clampf((fatigue - TIRED_FROM) / (100.0 - TIRED_FROM), 0.0, 1.0))


func is_over(at: float) -> bool:
	return at >= ROUND_SECONDS


func holding() -> bool:
	return _held_at >= 0.0


## The key goes down at `at`: he starts loading a shot.
func hold(at: float) -> void:
	if holding() or is_over(at):
		return
	_held_at = at


## The meter at `at` (0–1): climbing to the top over load_seconds and back down, over and over, while it's held.
func load_at(at: float) -> float:
	if not holding():
		return 0.0
	return pingpong((at - _held_at) / load_seconds, 1.0)


## The key comes up at `at`: the shot. Returns its entry in `shots`, or {} when nothing was held.
func release(at: float) -> Dictionary:
	if not holding():
		return {}
	var load: float = load_at(at)
	_held_at = -1.0
	var shot := { "t": at, "load": load, "met": false, "score": 0.0 }
	if bag_away(at):
		shot.result = WHIFF
		chain = 0
	else:
		shot.result = GREEN if load >= 1.0 - green else (GOOD if load >= 1.0 - green - GOOD_BAND else WEAK)
		shot.met = meets(at)
		var worth: float = { GREEN: 1.0, GOOD: GOOD_CREDIT, WEAK: WEAK_CREDIT }[shot.result]
		shot.score = worth if shot.met or shot.result == WEAK else worth * MISSED_SWING
		chain = chain + 1 if shot.met and shot.result != WEAK else 0
		best_chain = maxi(best_chain, chain)
		_landed_at = at
		_landed_power = load
	counts[shot.result] += 1
	shots.append(shot)
	return shot


## When the bag comes back to him from the last shot.
func back_at() -> float:
	return _landed_at + SWING_SECONDS


## True while the bag is still swinging away from the last shot, out of reach.
func bag_away(at: float) -> bool:
	return at > _landed_at and at < back_at() - MEET_WINDOW


## True when a shot at `at` meets the bag as it comes back (or it's the first shot, at a still bag).
func meets(at: float) -> bool:
	return shots.filter(func(s: Dictionary) -> bool: return s.result != WHIFF).is_empty() or absf(at - back_at()) <= MEET_WINDOW


## How far out the bag is at `at`, for drawing: 0 hanging at rest in front of him, up to about the last shot's load
## at the top of its swing; past its return it swings through a little and settles.
func bag_at(at: float) -> float:
	var since: float = at - _landed_at
	if since < 0.0 or _landed_at < -999.0:
		return 0.0
	var swing: float = sin(PI * since / SWING_SECONDS)
	if since <= SWING_SECONDS:
		return (0.35 + 0.65 * _landed_power) * swing
	return (0.35 + 0.65 * _landed_power) * 0.25 * swing * exp(-(since - SWING_SECONDS) * 2.0)


## Shots a perfect round lands: one each swing.
func expected_shots() -> int:
	return floori(ROUND_SECONDS / SWING_SECONDS)


## 0–1: what the shots were worth, less WHIFF_COST a whiff, over a perfect round's shots.
func accuracy() -> float:
	var total: float = 0.0
	for s in shots:
		total += float(s.score)
	return clampf((total - WHIFF_COST * counts[WHIFF]) / expected_shots(), 0.0, 1.0)


## The session's quality: TrainingCamp.PLAYED_MIN with nothing landed up to PLAYED_MAX for a perfect round.
func quality() -> float:
	return lerpf(TrainingCamp.PLAYED_MIN, TrainingCamp.PLAYED_MAX, accuracy())
