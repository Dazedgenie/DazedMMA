class_name Titles
extends RefCounted
## The titles (docs/03 §12.6, D356): a belt for every promotion in every division, its champion out of the rankings
## above #1, 5-round title fights on the promotion's cards, defences about twice a year, vacant belts and champions
## moving up. Kyle (2026-11-02) picked a belt in every promotion ("Every promotion"), the best ranked man who's free as
## challenger ("Best ranked man who's free"), a belt stripped after a year without a defence ("Stripped after a year
## out"), a champion called up after one defence ("After one defence"), 5 rounds for every title fight ("5 rounds, every
## title fight") and his title fight offered once he's #1 or #2 ("At #1 or #2 in his promotion").
##
## Each belt (World.titles, by the rankings' key "org_0:lightweight"): { champion (an id, the career's fighter's
## Career.FIGHTER_ID, or "" vacant), won (the week he won it), defences, last (the week of his last title fight),
## past ([[id, won, lost, defences, how it ended]], the last PAST_KEPT reigns) }.
##
## On a promotion's card week (WorldWeeks.play_week, before the other fights):
## - a champion who's retired, left the promotion or the division, or gone STRIP_WEEKS without a title fight loses the
##   belt;
## - a champion whose last title fight was DEFENCE_WEEKS ago or more, and who's fit, defends it against the best ranked
##   man of the table's top CHALLENGER_FROM who's due a fight and free;
## - a vacant belt goes to the two best ranked such men;
## - a regional or international champion who's defended CALL_UP_DEFENCES times is called up a rank, while there's
##   room, and his belt goes vacant.
## A draw keeps the belt with the champion.
##
## Pure (D100): the same world makes the same champions.

## The weeks between a champion's title fights at least (about two a year, D353's "champions 2").
const DEFENCE_WEEKS: int = 22
## A champion with no title fight in STRIP_WEEKS (a year) is stripped.
const STRIP_WEEKS: int = 52
## The challengers: the top CHALLENGER_FROM of the table, due a fight within CHALLENGER_DUE weeks.
const CHALLENGER_FROM: int = 5
const CHALLENGER_DUE: int = 4
## A regional or international champion is called up after this many defences (Kyle: "After one defence").
const CALL_UP_DEFENCES: int = 1
## Title fights are 5 rounds (the pro ruleset's title_rounds) and pay TITLE_PAY times a card's pay.
const ROUNDS: int = 5
const TITLE_PAY: int = 2
## His title fight offer (D356): once he's in his promotion's top OFFER_FROM and the belt's due on the line.
const OFFER_FROM: int = 2
## Reigns kept in a belt's `past`.
const PAST_KEPT: int = 8
## Day one: the best man of each promotion's division holds the belt, won SEED_WON weeks ago, with up to SEED_DEFENCES
## defences, his last title fight SEED_LAST weeks ago.
const SEED_WON: Array[int] = [8, 80]
const SEED_DEFENCES: int = 3
const SEED_LAST: Array[int] = [2, 20]


## A belt ({} when there's none: a promotion or division that isn't the world's).
static func belt(w: World, k: String) -> Dictionary:
	return w.titles.get(k, {})


## The champion of a table ("" vacant).
static func champion(w: World, promotion_id: String, division: String) -> String:
	return String(belt(w, Rankings.key(promotion_id, division)).get("champion", ""))


## The key of the belt he holds ("" for none).
static func held_by(w: World, id: String) -> String:
	if id == "":
		return ""
	if w.champion_cache.is_empty() and not w.titles.is_empty():
		for k: String in w.titles:
			var c: String = String(w.titles[k].get("champion", ""))
			if c != "":
				w.champion_cache[c] = k
	return String(w.champion_cache.get(id, ""))


## "the IML lightweight title".
static func title_name(w: World, k: String) -> String:
	var p: Dictionary = Promotions.by_id(w, k.get_slice(":", 0))
	return "the %s %s title" % [String(p.get("short", "")), Weight.name_of(k.get_slice(":", 1)).to_lower()]


## Day one's champions (and a world saved before D356's): in each promotion's division, the best signed man.
static func seed(w: World, week: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([w.seed_value, "titles"])
	w.titles = {}
	for p: Dictionary in w.promotions:
		for division_id: String in Weight.ids():
			var men: Array = Rankings._men_of(w, String(p.id), division_id)
			men.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return w.average(a) > w.average(b) if w.average(a) != w.average(b) else String(a.id) < String(b.id))
			var k: String = Rankings.key(String(p.id), division_id)
			if men.is_empty():
				w.titles[k] = { "champion": "", "won": week, "defences": 0, "last": week, "past": [] }
				continue
			var won: int = week - rng.randi_range(SEED_WON[0], SEED_WON[1])
			w.titles[k] = { "champion": String(men[0].id), "won": won, "defences": rng.randi_range(0, SEED_DEFENCES),
				"last": maxi(won, week - rng.randi_range(SEED_LAST[0], SEED_LAST[1])), "past": [] }
	w.champion_cache = {}


## This card week's title business for every promotion with a card (see the top). Returns the title fights' results.
static func play_week(w: World, week: int, busy: Dictionary, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for p: Dictionary in w.promotions:
		if not Promotions.has_card(p, week):
			continue
		for division_id: String in Weight.ids():
			var k: String = Rankings.key(String(p.id), division_id)
			var b: Dictionary = w.titles.get_or_add(k, { "champion": "", "won": week, "defences": 0, "last": week, "past": [] })
			_check(w, k, b, week)
			var champ_id: String = String(b.champion)
			if champ_id == Career.FIGHTER_ID or busy.has(champ_id):
				continue  # His own belt is defended through his offers; a man booked to fight him waits.
			if champ_id != "":
				if week - int(b.last) < DEFENCE_WEEKS:
					continue
				var champ: Dictionary = w.man(champ_id)
				if int(champ.get("out_until", -1)) > week:
					continue
				var picks: Array = challengers(w, k, week, busy, champ_id)
				if picks.is_empty():
					continue
				out.append(title_fight(w, k, champ, picks[0], week, rng))
			else:
				var picks: Array = challengers(w, k, week, busy, "")
				if picks.size() < 2:
					continue
				out.append(title_fight(w, k, picks[0], picks[1], week, rng))
	return out


## The men of a table's top CHALLENGER_FROM who can fight for its belt this week, best first: active, fit, due a fight
## within CHALLENGER_DUE weeks, not booked to fight him, not the career's fighter (his are offers) and, with `against`,
## not met lately.
static func challengers(w: World, k: String, week: int, busy: Dictionary, against: String) -> Array:
	var out: Array = []
	var ids: Array = w.rankings.get(k, [])
	for i in mini(CHALLENGER_FROM, ids.size()):
		var id: String = String(ids[i])
		if id == Career.FIGHTER_ID or busy.has(id):
			continue
		var m: Dictionary = w.man(id)
		if m.is_empty() or not World.active(m) or int(m.get("out_until", -1)) > week or int(m.get("next_week", 0)) > week + CHALLENGER_DUE:
			continue
		if against != "" and WorldWeeks._met_lately(m, against, week):
			continue
		if out.size() == 1 and against == "" and WorldWeeks._met_lately(m, String(out[0].id), week):
			continue
		out.append(m)
	return out


## A title fight between two of the world's men: 5 rounds on the quick result model, onto both records, rankings points
## and the belt (`a` is the champion when there is one). Returns the fight's result with `title` (the belt's key).
static func title_fight(w: World, k: String, a: Dictionary, b: Dictionary, week: int, rng: RandomNumberGenerator) -> Dictionary:
	var r: Dictionary = WorldWeeks.fight(w, a, b, week, rng, ROUNDS)
	r.title = k
	var b_: Dictionary = w.titles[k]
	var holder: String = String(b_.champion)
	var winner: String = String(r.a) if String(r.winner) == "a" else (String(r.b) if String(r.winner) == "b" else "")
	if holder != "" and (winner == holder or winner == ""):
		b_.defences = int(b_.defences) + 1
		b_.last = week
		r.title_how = "defended"
	else:
		if winner == "":
			r.title_how = "drawn"  # A vacant belt stays vacant on a draw.
		else:
			crown(w, k, winner, week, "lost" if holder != "" else "")
			r.title_how = "won"
	return r


## He's the new champion: the old one's reign goes into `past` with how it ended.
static func crown(w: World, k: String, id: String, week: int, how: String) -> void:
	var b: Dictionary = w.titles[k]
	_end_reign(b, week, how)
	b.champion = id
	b.won = week
	b.last = week
	b.defences = 0
	w.champion_cache = {}


## The belt goes vacant (`why`: retired, left, stripped, called up), logged as a "title" result.
static func vacate(w: World, k: String, week: int, why: String) -> void:
	var b: Dictionary = w.titles[k]
	var id: String = String(b.champion)
	if id == "":
		return
	_end_reign(b, week, why)
	b.champion = ""
	b.defences = 0
	b.last = week
	w.champion_cache = {}
	w.results.append({ "kind": "title", "week": week, "id": id, "division": k.get_slice(":", 1), "promotion": k.get_slice(":", 0),
		"how": why })


## After one of his title fights (a title defence or shot): the belt with whoever won. `title` is the belt's key,
## `result` his (win, loss, draw), `opponent` the man.
static func his_title_fight(w: World, k: String, opponent: String, result: String, week: int) -> void:
	if not w.titles.has(k):
		return
	var b: Dictionary = w.titles[k]
	var holder: String = String(b.champion)
	if result == "draw" or (result == "win" and holder == Career.FIGHTER_ID) or (result == "loss" and holder == opponent):
		if holder != "":
			b.defences = int(b.defences) + 1
			b.last = week
		return
	crown(w, k, Career.FIGHTER_ID if result == "win" else opponent, week, "lost" if holder != "" else "")
	w.results.append({ "kind": "title", "week": week, "id": Career.FIGHTER_ID if result == "win" else opponent,
		"division": k.get_slice(":", 1), "promotion": k.get_slice(":", 0), "how": "won", "from": holder })


## A champion who's gone, left or not fought for the belt in STRIP_WEEKS loses it; one who's defended it
## CALL_UP_DEFENCES times in a promotion below the world organisation is called up.
static func _check(w: World, k: String, b: Dictionary, week: int) -> void:
	var id: String = String(b.champion)
	if id == "":
		return
	var pid: String = k.get_slice(":", 0)
	if id == Career.FIGHTER_ID:
		if String(w.him.get("promotion", "")) != pid:
			vacate(w, k, week, "left")
		elif week - int(b.last) >= STRIP_WEEKS:
			vacate(w, k, week, "stripped")
		return
	var m: Dictionary = w.man(id)
	if m.is_empty() or not World.active(m):
		vacate(w, k, week, "retired")
		return
	if String(m.get("promotion", "")) != pid or String(m.get("division", "")) != k.get_slice(":", 1):
		vacate(w, k, week, "left")
		return
	if week - int(b.last) >= STRIP_WEEKS:
		vacate(w, k, week, "stripped")
		return
	var rank: int = int(Promotions.by_id(w, pid).get("rank", Promotions.MAJOR))
	if rank > Promotions.MAJOR and int(b.defences) >= CALL_UP_DEFENCES and Promotions.has_room(w, rank - 1, String(m.division)):
		vacate(w, k, week, "called up")
		Promotions.sign_to(w, m, rank - 1)
		m.moved = week
		w.results.append({ "kind": "moved", "week": week, "id": id, "division": String(m.division), "from": pid,
			"to": String(m.promotion), "up": true })


static func _end_reign(b: Dictionary, week: int, how: String) -> void:
	if String(b.get("champion", "")) == "":
		return
	var past: Array = b.get_or_add("past", [])
	past.append([String(b.champion), int(b.won), week, int(b.defences), how])
	while past.size() > PAST_KEPT:
		past.pop_front()
