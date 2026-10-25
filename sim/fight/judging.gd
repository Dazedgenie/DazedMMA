class_name Judging
extends RefCounted
## Simple 10-point must scoring with three judges (docs/01-fight-engine.md §11,
## issue #13). A round goes to whoever did more effective striking: damage landed
## (head counts most), plus big moments (rocking or dropping the opponent). When
## that's even, the judges look at aggression, then cage control, and only call it
## 10-10 when nothing separates the fighters (D97).
## Each judge sees the round slightly differently, so close fights can be split.
## Grappling counts in the same points (#15): a takedown (ending up on top) and every
## second held in a position that scores control (full guard top, docs/01 §21).
## Judge personalities come with D20.

const JUDGES: int = 3
## Points per point of damage landed on each target.
const TARGET_WEIGHTS := { "head": 1.0, "body": 0.8, "legs": 0.6 }
const ROCKED_POINTS: float = 8.0
const KNOCKDOWN_POINTS: float = 20.0
## Grappling (#15): a takedown, and per second × the position's control score for the role
## (full guard: top 1.0, bottom 0.2, data/positions).
const TAKEDOWN_POINTS: float = 10.0
const CONTROL_POINTS_PER_S: float = 0.3
## How differently judges see the same round: each fighter's points ×(1 ± up to 15%).
const JUDGE_NOISE: float = 0.15
## Effective striking this close (within 5%) is even: aggression decides, then cage control.
const EVEN_WITHIN: float = 0.05
## Aggression: attacks thrown, plus this much per metre walked toward the opponent.
const AGGRESSION_PER_METRE: float = 1.0
## 10-8: two more knockdowns, or out-landed over 3 to 1 in a busy round.
const DOMINANT_KNOCKDOWNS: int = 2
const DOMINANT_SHARE: float = 0.35
const DOMINANT_MIN_POINTS: float = 60.0

const UNANIMOUS := "unanimous decision"
const SPLIT := "split decision"
const MAJORITY := "majority decision"
const DRAW := "draw"


## One judge's card for one round, e.g. [10, 9]. `tie_breaks` are what the judge
## looks at, in order, when effective striking is even: [[aggression red, blue],
## [cage control red, blue]].
static func round_card(points: Array[float], knockdowns: Array[int], tie_breaks: Array = []) -> Array[int]:
	var best: float = maxf(points[0], points[1])
	var w: int = -1
	if best > 0.0 and absf(points[0] - points[1]) > EVEN_WITHIN * best:
		w = 0 if points[0] > points[1] else 1
	else:
		for pair: Array in tie_breaks:
			if pair[0] != pair[1]:
				w = 0 if pair[0] > pair[1] else 1
				break
	if w < 0:
		return [10, 10]
	var l: int = 1 - w
	var dominant: bool = knockdowns[w] - knockdowns[l] >= DOMINANT_KNOCKDOWNS \
		or (points[w] >= DOMINANT_MIN_POINTS and points[l] < DOMINANT_SHARE * points[w])
	var card: Array[int] = [0, 0]
	card[w] = 10
	card[l] = 8 if dominant else 9
	return card


## The verdict from each judge's totals ([[29, 28], [28, 29], [29, 28]]):
## {result, winner (fighter index, or -1 for a draw)}.
static func decision(totals: Array) -> Dictionary:
	var wins: Array[int] = [0, 0]
	for t: Array in totals:
		if t[0] > t[1]:
			wins[0] += 1
		elif t[1] > t[0]:
			wins[1] += 1
	var draws: int = totals.size() - wins[0] - wins[1]
	for w in 2:
		var l: int = 1 - w
		if wins[w] == totals.size():
			return { "result": UNANIMOUS, "winner": w }
		if wins[w] >= 2 and wins[l] == 1:
			return { "result": SPLIT, "winner": w }
		if wins[w] >= 2 and draws >= 1:
			return { "result": MAJORITY, "winner": w }
	return { "result": DRAW, "winner": -1 }
