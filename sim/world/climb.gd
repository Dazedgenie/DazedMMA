class_name Climb
extends RefCounted
## Climbing the ladder (docs/03 §12.7, D357): the career's fighter moving up the promotions, from the regional cards to
## the international organisation to the world one. Kyle (2026-11-02) picked: called up like everyone else, three wins
## in a row since his last move or a title defence ("Like everyone: 3 wins or a defence"); the call-up as an offer he can
## turn down ("An offer he can turn down"); asking for a step up from the hub, a yes being a tryout fight on the bigger
## promotion's card ("A tryout fight on their card"), more likely the higher he's ranked, with 3 months between asks
## ("By his rank, 3 months between asks"); let go a rank after three losses in a row ("Let go after 3 losses in a row");
## and his place on the ladder as a line on his card with the ask on This week ("A line on his card, ask on This week").
## Title eliminators (Kyle: "#3 v #4, winner next in line") are in Titles.
##
## His place is in World.him: `rung` (a promotion rank: Promotions.REGIONAL until he's called up, then SECOND, then
## MAJOR), `run` (wins in a row since his last move, or minus the losses in a row; a draw ends either), `moved` (the
## week of his last move), `fights` (his pro card fights so far), `offered` (his `fights` when a call-up was last
## offered: one call-up offer a fight), `asked` (the week he last asked for a step up) and `answer` ({ week, yes, to }:
## the last answer). On the regional rung his fights are on the regional cards (Matchmaker.pro_cards, D354); on a
## bigger rung, on that organisation's cards against its men.
##
## Pure (D100): the same career makes the same answers.

## Called up after CALL_UP_WINS wins in a row since his last move, or as a champion after Titles.CALL_UP_DEFENCES
## defences; let go a rank after LET_GO_LOSSES losses in a row (the world's men's numbers, Promotions).
const CALL_UP_WINS: int = Promotions.CALL_UP_WINS
const LET_GO_LOSSES: int = Promotions.CUT_LOSSES
## Asking for a step up: ASK_WAIT_WEEKS between asks; a yes as likely as ASK_YES says for his rank in his promotion
## ([up to this rank, chance], a champion counting as #1), ASK_YES_UNRANKED when he isn't ranked.
const ASK_WAIT_WEEKS: int = 13
const ASK_YES: Array = [[3, 0.7], [10, 0.3]]
const ASK_YES_UNRANKED: float = 0.1
## The kinds of step-up offer (Matchmaker.step_up_offer): a call-up (taking it signs him) and a tryout (winning it does).
const CALL_UP := "call_up"
const TRYOUT := "tryout"


## The rank of promotion he fights for: Promotions.REGIONAL, SECOND or MAJOR.
static func rung(w: World) -> int:
	return int(w.him.get("rung", Promotions.REGIONAL))


## The organisation of a rank ({} for the regional rung: those are several).
static func organisation(w: World, rank: int) -> Dictionary:
	if rank >= Promotions.REGIONAL:
		return {}
	for p: Dictionary in w.promotions:
		if int(p.rank) == rank:
			return p
	return {}


## The promotion a step up from where he is ({} at the top).
static func up(w: World) -> Dictionary:
	return organisation(w, rung(w) - 1) if rung(w) > Promotions.MAJOR else {}


## The promotions his offers come from: the regional ones until he's called up, then his organisation.
static func promotion_ids(w: World) -> Array:
	var p: Dictionary = organisation(w, rung(w))
	if not p.is_empty():
		return [String(p.id)]
	return Promotions.regionals(w).map(func(x: Dictionary) -> String: return String(x.id))


## Whether a call-up is due him: below the top, three wins in a row since his last move or a champion who's defended,
## and not offered one since his last fight.
static func call_up_due(w: World) -> bool:
	if up(w).is_empty() or int(w.him.get("fights", 0)) <= int(w.him.get("offered", -1)):
		return false
	var belt: String = Titles.held_by(w, Career.FIGHTER_ID)
	if belt != "" and int(Titles.belt(w, belt).get("defences", 0)) >= Titles.CALL_UP_DEFENCES:
		return true
	return int(w.him.get("run", 0)) >= CALL_UP_WINS


## A call-up's been offered: the next one waits for his next fight.
static func offered(w: World) -> void:
	w.him.offered = int(w.him.get("fights", 0))


## After one of his pro fights on a card (Career.finish_fight): his run, then the move it makes. `step` is the booked
## offer's (Matchmaker.step_up_offer's) step, "" for an ordinary fight. A tryout won signs him; three losses in a row
## above the regional rung and he's let go. Returns the move ("up", "down" or "").
static func after_fight(w: World, result: String, step: String, week: int) -> String:
	w.him.fights = int(w.him.get("fights", 0)) + 1
	var run: int = int(w.him.get("run", 0))
	match result:
		"win":
			run = maxi(run, 0) + 1
		"loss":
			run = mini(run, 0) - 1
		_:
			run = 0
	w.him.run = run
	if step == TRYOUT and result == "win":
		sign_up(w, week, TRYOUT)
		return "up"
	if run <= -LET_GO_LOSSES and rung(w) < Promotions.REGIONAL:
		let_go(w, week)
		return "down"
	return ""


## He signs with the promotion a step up (a call-up taken, or a tryout won): his fights are theirs from now, a belt he
## holds goes vacant, and it's news.
static func sign_up(w: World, week: int, how: String) -> void:
	var to: Dictionary = up(w)
	if to.is_empty():
		return
	var from: String = String(w.him.get("promotion", ""))
	var belt: String = Titles.held_by(w, Career.FIGHTER_ID)
	if belt != "":
		Titles.vacate(w, belt, week, "called up")
	w.him.rung = int(to.rank)
	w.him.promotion = String(to.id)
	w.him.run = 0
	w.him.moved = week
	w.results.append({ "kind": "moved", "week": week, "id": Career.FIGHTER_ID, "division": String(w.him.get("division", "")),
		"from": from, "to": String(to.id), "up": true, "how": how })
	w.rank_cache = {}


## Three losses in a row: he's let go a rank down (to his home promotion from the international organisation).
static func let_go(w: World, week: int) -> void:
	var from: String = String(w.him.get("promotion", ""))
	var r: int = rung(w) + 1
	var to: Dictionary = organisation(w, r) if r < Promotions.REGIONAL else Promotions.home(w)
	w.him.rung = r
	w.him.promotion = String(to.get("id", ""))
	w.him.run = 0
	w.him.moved = week
	w.results.append({ "kind": "moved", "week": week, "id": Career.FIGHTER_ID, "division": String(w.him.get("division", "")),
		"from": from, "to": String(to.get("id", "")), "up": false })
	w.rank_cache = {}


## Whether he can ask for a step up this week: a pro below the top, not booked, no step-up offer open, and
## ASK_WAIT_WEEKS since he last asked.
static func can_ask(c: Career) -> bool:
	if not c.pro or not c.booked.is_empty():
		return false
	var w: World = c.world()
	if up(w).is_empty() or c.week < next_ask_week(w):
		return false
	for o: Dictionary in c.offers:
		if String(o.get("step", "")) != "":
			return false
	return true


## The first week he can ask again.
static func next_ask_week(w: World) -> int:
	return int(w.him.get("asked", -ASK_WAIT_WEEKS)) + ASK_WAIT_WEEKS


## How likely a yes is (see ASK_YES): by his rank in his promotion's table, a champion counting as #1.
static func ask_chance(w: World) -> float:
	var r: int = 1 if Titles.held_by(w, Career.FIGHTER_ID) != "" else Rankings.rank_of(w, Career.FIGHTER_ID)
	if r <= 0:
		return ASK_YES_UNRANKED
	for step: Array in ASK_YES:
		if r <= int(step[0]):
			return float(step[1])
	return ASK_YES_UNRANKED


## He asks the promotion a step up for a fight (Career.ask_step_up): a yes is a tryout offer on its card, a no means
## waiting ASK_WAIT_WEEKS to ask again. Returns the answer ({ week, yes, to }, {} when he can't ask).
static func ask(c: Career, rng: RandomNumberGenerator) -> Dictionary:
	if not can_ask(c):
		return {}
	var w: World = c.world()
	var to: Dictionary = up(w)
	var yes: bool = rng.randf() < ask_chance(w)
	w.him.asked = c.week
	if yes:
		var o: Dictionary = c.matchmaker().step_up_offer(c, rng, TRYOUT, c.offers.size())
		if o.is_empty():
			yes = false  # Nobody of theirs to put him in with: a no for now.
		else:
			c.offers.append(o)
	w.him.answer = { "week": c.week, "yes": yes, "to": String(to.id) }
	return w.him.answer


## His place on the ladder, for his card: "Regional (IML) · 2 of 3 wins in a row to a call-up to the ACL".
static func ladder_text(c: Career) -> String:
	if not c.pro:
		return ""
	var w: World = c.world()
	var r: int = rung(w)
	var here: Dictionary = organisation(w, r)
	var where: String
	if here.is_empty():
		var p: Dictionary = Promotions.by_id(w, String(w.him.get("promotion", "")))
		if p.is_empty():
			p = Promotions.home(w)
		where = "Regional (%s)" % String(p.get("short", "")) if not p.is_empty() else "Regional"
	else:
		where = "%s (%s)" % ["World" if r == Promotions.MAJOR else "International", String(here.short)]
	var to: Dictionary = up(w)
	if to.is_empty():
		return where + " · the top of the ladder" + _let_go_note(w)
	var belt: String = Titles.held_by(w, Career.FIGHTER_ID)
	var next: String
	if belt != "":
		next = "a call-up to the %s after a title defence" % String(to.short)
	elif int(w.him.get("run", 0)) >= CALL_UP_WINS:
		next = "%d wins in a row: the %s want him" % [int(w.him.run), String(to.short)]
	else:
		next = "%d of %d wins in a row to a call-up to the %s" % [maxi(0, int(w.him.get("run", 0))), CALL_UP_WINS, String(to.short)]
	return "%s · %s%s" % [where, next, _let_go_note(w)]


static func _let_go_note(w: World) -> String:
	var run: int = int(w.him.get("run", 0))
	if rung(w) < Promotions.REGIONAL and run < 0:
		return " · %d loss%s in a row: %d and he's let go" % [-run, "" if run == -1 else "es", LET_GO_LOSSES]
	return ""


## The last answer to his ask, for This week, while it's news (the week he asked) or while he waits to ask again.
static func answer_text(c: Career) -> String:
	if not c.pro:
		return ""
	var w: World = c.world()
	var a: Dictionary = w.him.get("answer", {})
	var to: Dictionary = up(w)
	if not a.is_empty() and int(a.get("week", -1)) == c.week:
		var p: Dictionary = Promotions.by_id(w, String(a.get("to", "")))
		if bool(a.get("yes", false)):
			return "The %s said yes: a tryout on their card. Win it and they sign him (see the offers)." % String(p.get("short", ""))
		return "The %s said no, not yet. He can ask again from %s." % [String(p.get("short", "")),
			c.date_text(0, next_ask_week(w))]
	if not to.is_empty() and c.week < next_ask_week(w):
		return "He can ask the %s for a step up again from %s." % [String(to.short), c.date_text(0, next_ask_week(w))]
	return ""
