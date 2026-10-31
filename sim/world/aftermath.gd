class_name Aftermath
extends RefCounted
## What a fight does to him afterwards (docs/03 §10.5, D305): the medical suspension, and the Chin a knockout takes
## for good. Kyle (2026-10-31): "Sounds good for now".
##
## Pure: the same fight always gives the same aftermath.

## Losing by knockout: this many days out, and this much Chin gone for good.
const KO_DAYS: int = 60
const KO_CHIN: float = 1.0
## Losing by TKO (the referee, the doctor or the towel).
const TKO_DAYS: int = 30
const TKO_CHIN: float = 0.5
## A hard fight, won or lost: knocked down, or finishing it this hurt to the head or the body (FighterState.hurt).
const HARD_DAYS: int = 21
const HARD_HEAD: float = 0.5
const HARD_BODY: float = 0.6
## Any other fight.
const OTHER_DAYS: int = 7
## How a fight's method reads on his record (main.gd's method_text).
const KO := "KO"
const TKO := "TKO"


## Whether it was a hard fight for him: knocked down, or this hurt at the end.
static func is_hard(head_hurt: float, body_hurt: float, knockdowns: int) -> bool:
	return knockdowns > 0 or head_hurt >= HARD_HEAD or body_hurt >= HARD_BODY


## The aftermath of a fight: { days (the suspension), chin (Chin lost), why ("a KO loss", "a hard fight", "") }.
## `result` is win, loss, draw or no_contest; `method` as his record writes it ("KO", "TKO", "Submission", …).
static func of(result: String, method: String, hard: bool) -> Dictionary:
	if result == "loss" and method == KO:
		return { "days": KO_DAYS, "chin": KO_CHIN, "why": "a KO loss" }
	if result == "loss" and method == TKO:
		return { "days": TKO_DAYS, "chin": TKO_CHIN, "why": "a TKO loss" }
	if hard:
		return { "days": HARD_DAYS, "chin": 0.0, "why": "a hard fight" }
	return { "days": OTHER_DAYS, "chin": 0.0, "why": "" }
