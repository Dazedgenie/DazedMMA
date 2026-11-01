class_name WorldWeeks
extends RefCounted
## The world's weeks (docs/03 §12.3, D353): every week the world's men (World, D352) who are due a fight are matched
## with a man of their division and kind near their level and fight on Saturday, decided by the quick result model
## (ResultModel, D350). They get better while they're young and slow down from 31, wins build them up and knockouts
## wear them down, the best amateurs turn pro, men
## retire, new pros join each month and new lads each January, so every division keeps about World.PER_DIVISION men.
##
## Kyle's D353 picks are in the decisions log (D353).
##
## Pure and seeded (D100): the world's seed and the week make the same fights.

## About 3 fights a year (Kyle, 2026-11-01: "3 a year, champions 2"): after a fight he's due again in GAP_WEEKS weeks,
## give or take GAP_SPREAD; a man nobody fits waits a week and is matched more loosely (MATCH_WIDEN a week waited).
const GAP_WEEKS: int = 15
const GAP_SPREAD: int = 5
## A match is two due men of the same division and kind (amateur or pro; teenagers with teenagers) whose average stats
## are within MATCH_GAP (+ MATCH_WIDEN a week the first has waited), who haven't met in REMATCH_WEEKS.
const MATCH_GAP: float = 5.0
const MATCH_WIDEN: float = 1.0
## Hurt: a man knocked out sits out KO_OUT_WEEKS more weeks than the gap; one stopped another way SUB_OUT_WEEKS.
const KO_OUT_WEEKS: int = 8
const SUB_OUT_WEEKS: int = 2
## Form and rust (logit nudges to the result model): FORM_PER_RESULT for each of his last FORM_FIGHTS fights won (taken
## off for each lost), RUST after RUST_WEEKS without a fight.
const FORM_PER_RESULT: float = 0.08
const FORM_FIGHTS: int = 3
const RUST: float = 0.2
const RUST_WEEKS: int = 52
## Getting better and worse (like his own fighter, D136): a year's growth is GROWTH (by age) of the way from where he is
## to his potential, applied a week at a time; from DECLINE_AT his average falls DECLINE a year, DECLINE_LATE from
## DECLINE_LATE_AT.
const GROWTH: Array = [[18.0, 0.35], [21.0, 0.3], [25.0, 0.2], [28.0, 0.1], [30.0, 0.0]]
const DECLINE_AT: float = 31.0
const DECLINE: float = 0.6
const DECLINE_LATE_AT: float = 34.0
const DECLINE_LATE: float = 1.5
## A man's potential: his average now plus, for every year under PEAK_AGE, between HEADROOM[0] and HEADROOM[1] points
## (leaning low: HEADROOM_SKEW), held at POTENTIAL_MAX.
const PEAK_AGE: float = 28.0
const HEADROOM: Array[float] = [0.3, 3.6]
const HEADROOM_SKEW: float = 1.8
const POTENTIAL_MAX: float = 84.0
## What a fight does to him for good (Kyle, 2026-11-01: "Wins and losses change them too"): a win adds WIN_GAIN to
## his average stat and his potential (confidence and rounds in the bank); being knocked out takes KO_WEAR off both
## (the wear a knockout leaves), more for every knockout loss in his last fights (KO_WEAR_MORE each). Other losses
## leave him as he was.
const WIN_GAIN: float = 0.4
const KO_WEAR: float = 0.8
const KO_WEAR_MORE: float = 0.4
## Turning pro: an amateur from PRO_FROM with PRO_AFTER fights, a PRO_WIN_SHARE winning record and PRO_READY average
## turns pro within about PRO_WEEKS weeks; at PRO_LATE he turns pro if he's PRO_LATE_READY, else gives it up.
const PRO_FROM: float = 18.0
const PRO_AFTER: int = 4
const PRO_WIN_SHARE: float = 0.55
const PRO_READY: float = 38.0
const PRO_WEEKS: float = 26.0
const PRO_LATE: float = 23.0
const PRO_LATE_READY: float = 34.0
## Retiring only when he's too old (Kyle, 2026-11-01: "Only when they're too old"): nobody retires before RETIRE_FROM.
## From then a pro's yearly chance is TOO_OLD for every point his average stat has fallen from his best past
## FALLEN_FREE, plus BAD_RUN when he's lost BAD_RUN_LOSSES of his last BAD_RUN_FIGHTS and KO_RUN after KO_RUN_KOS
## knockout losses in them (a man still winning keeps going); at RETIRE_BY he's done. An amateur only gives it up at
## PRO_LATE (above).
const RETIRE_FROM: float = 32.0
const FALLEN_FREE: float = 1.0
const TOO_OLD: float = 0.1
const BAD_RUN_FIGHTS: int = 4
const BAD_RUN_LOSSES: int = 3
const BAD_RUN: float = 0.4
const KO_RUN_KOS: int = 2
const KO_RUN: float = 0.25
const RETIRE_BY: float = 45.0
## Each January every division is topped up to each level's count (World.LEVELS): amateurs as NEW_AMATEUR_AGES lads
## from home, pros as men new to the division.
const NEW_AMATEUR_AGES: Array[float] = [14.0, 16.0]
## A man's last fights kept (form, rust and the list), and the weeks of results kept for the hub.
const HISTORY: int = 6
const RESULTS_WEEKS: int = 8
## What a retired man no longer needs.
const RETIRED_DROPS: Array[String] = ["frame", "seed", "potential", "lv", "history", "next_week", "out_until", "met_close", "best"]


## What the weeks need on a man that doesn't have it yet (one made before D353, or new): his potential, his level to a
## fraction, when he's next due, and his fights so far.
static func set_up(w: World, m: Dictionary, rng: RandomNumberGenerator, week: int) -> void:
	if not m.has("lv"):
		m.lv = float(m.get("level", 0))
	if not m.has("best"):
		m.best = snappedf(w.average(m), 0.1)
	if not m.has("potential"):
		var age: float = World.age_of(m, week)
		var per_year: float = lerpf(HEADROOM[0], HEADROOM[1], pow(rng.randf(), HEADROOM_SKEW))
		m.potential = snappedf(minf(POTENTIAL_MAX, w.average(m) + maxf(0.0, PEAK_AGE - age) * per_year), 0.1)
	if not m.has("next_week"):
		m.next_week = week + rng.randi_range(0, GAP_WEEKS + GAP_SPREAD)
	if not m.has("out_until"):
		m.out_until = -1
	if not m.has("retired"):
		m.retired = -1
	if not m.has("history"):
		m.history = []
	if bool(m.get("pro", false)) and String(m.get("division", "")) == "":
		m.division = World.division_of(m, week)


## Plays the world's weeks up to and including `to_week` (each week's Saturday). `busy` holds men who can't take
## another fight (booked to fight the career's fighter, or in his offers). `date_of` gives a week's Monday as
## { year, month, day } (Career.date). Returns what happened, oldest first.
static func advance(w: World, to_week: int, busy: Dictionary, date_of: Callable) -> Array:
	var out: Array = []
	while w.played < to_week:
		var week: int = w.played + 1
		var month: int = int(date_of.call(week).month)
		if month != int(date_of.call(week - 1).month):
			if month == 1:
				let_go(w, week)
			new_men(w, week, month == 1)
		out.append_array(play_week(w, week, busy))
		w.played = week
	var keep_from: int = w.played - RESULTS_WEEKS + 1
	w.results = w.results.filter(func(r: Dictionary) -> bool: return int(r.week) >= keep_from)
	return out


## One week: the men change a week's worth, some turn pro or retire, and the men due a fight fight. Returns what
## happened: the fights, and men turning pro or retiring (`kind` "fight", "pro" or "retired").
static func play_week(w: World, week: int, busy: Dictionary) -> Array:
	var first: int = w.results.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([w.seed_value, "week", week])
	for m: Dictionary in w.men.values():
		if World.active(m):
			_age_a_week(w, m, week, rng)
	var pools: Dictionary = {}
	for m: Dictionary in w.men.values():
		if not World.active(m) or busy.has(String(m.id)) or int(m.next_week) > week or int(m.out_until) > week:
			continue
		var age: float = World.age_of(m, week)
		if age < float(BackgroundLibrary.START_AGE):
			continue
		var pool: String = "am:teen" if age < 18.0 else "am:adult"
		if bool(m.pro):
			var p: Dictionary = Promotions.of(w, m)
			if not p.is_empty() and not Promotions.has_card(p, week):
				continue  # A pro fights on his promotion's cards (D354).
			pool = "pro:" + String(m.get("promotion", ""))
		var key: String = "%s:%s" % [World.division_of(m, week), pool]
		pools.get_or_add(key, []).append(m)
	var keys: Array = pools.keys()
	keys.sort()
	for key: String in keys:
		var due: Array = pools[key]
		due.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.id) < String(b.id))
		_shuffle(due, rng)
		var taken: Dictionary = {}
		for m: Dictionary in due:
			if taken.has(String(m.id)):
				continue
			var waited: int = week - int(m.next_week)
			var best: Dictionary = {}
			var best_gap: float = MATCH_GAP + MATCH_WIDEN * float(waited)
			for o: Dictionary in due:
				if String(o.id) == String(m.id) or taken.has(String(o.id)) or _met_lately(m, String(o.id), week):
					continue
				var gap: float = absf(w.average(m) - w.average(o))
				if gap <= best_gap:
					best_gap = gap
					best = o
			if best.is_empty():
				continue
			taken[String(m.id)] = true
			taken[String(best.id)] = true
			w.results.append(fight(w, m, best, week, rng))
			Promotions.after_fight(w, m, week)
			Promotions.after_fight(w, best, week)
	return w.results.slice(first)


## Two of the world's men fight (ResultModel.decide, with form and rust): onto both records and histories, and they're
## due again in about GAP_WEEKS (longer when hurt). Returns the result: { week, division, a, b, winner ("a", "b" or
## "draw"), method, round, chance (a's chance beforehand), pro }.
static func fight(w: World, a: Dictionary, b: Dictionary, week: int, rng: RandomNumberGenerator) -> Dictionary:
	var nudge: float = nudge_for(a, week) - nudge_for(b, week)
	var chance: float = ResultModel.win_chance(String(a.style), w.average(a), String(b.style), w.average(b), nudge)
	var r: Dictionary = ResultModel.decide(String(a.style), w.average(a), String(b.style), w.average(b), rng, 3, nudge)
	var result_a: String = { "a": "win", "b": "loss" }.get(String(r.winner), "draw")
	var result_b: String = { "a": "loss", "b": "win" }.get(String(r.winner), "draw")
	note_fight(a, String(b.id), result_a, String(r.method), week, rng)
	note_fight(b, String(a.id), result_b, String(r.method), week, rng)
	var out: Dictionary = { "kind": "fight", "week": week, "division": World.division_of(a, week), "a": String(a.id), "b": String(b.id),
		"winner": String(r.winner), "method": String(r.method), "round": int(r.round), "chance": snappedf(chance, 0.01), "pro": bool(a.pro) }
	var p: Dictionary = Promotions.of(w, a)
	if bool(a.pro) and not p.is_empty():
		out.card = String(Promotions.card(w, p, week).short)
		out.promotion = String(p.id)
	return out


## A fight onto a man's record and history (his `result`: win, loss or draw; `method`: ko, submission, decision or
## draw, or the fight screen's words), and when he's due again: GAP_WEEKS give or take, KO_OUT_WEEKS more after a
## knockout loss.
static func note_fight(m: Dictionary, opponent_id: String, result: String, method: String, week: int, rng: RandomNumberGenerator) -> void:
	if result in ["win", "loss", "draw"]:
		m.record[result] = int(m.record.get(result, 0)) + 1
	var how: String = _method(method)
	var change: float = form_change(m, result, how)
	if change != 0.0 and m.has("lv"):
		m.lv = snappedf(float(m.lv) + change, 0.001)
		m.level = roundi(float(m.lv))
		if m.has("potential"):
			m.potential = snappedf(minf(POTENTIAL_MAX, float(m.potential) + change), 0.1)
	(m.history as Array).append([week, opponent_id, result.substr(0, 1), how])
	while (m.history as Array).size() > HISTORY:
		(m.history as Array).pop_front()
	var out: int = 0
	if result == "loss" and how == "ko":
		out = KO_OUT_WEEKS
	elif result == "loss" and how == "submission":
		out = SUB_OUT_WEEKS
	m.next_week = week + GAP_WEEKS + rng.randi_range(-GAP_SPREAD, GAP_SPREAD) + out
	m.out_until = week + out


## What a result does to his average stat for good (before it goes on his history): WIN_GAIN for a win, KO_WEAR off
## (and KO_WEAR_MORE for each knockout loss already in his last BAD_RUN_FIGHTS) for being knocked out.
static func form_change(m: Dictionary, result: String, how: String) -> float:
	if result == "win":
		return WIN_GAIN
	if result != "loss" or how != "ko":
		return 0.0
	var h: Array = m.get("history", [])
	var earlier: int = h.slice(maxi(0, h.size() - BAD_RUN_FIGHTS)).filter(func(x: Array) -> bool: return String(x[2]) == "l" and String(x[3]) == "ko").size()
	return -(KO_WEAR + KO_WEAR_MORE * float(earlier))


## His form and rust as a nudge to the result model's logit: + for wins in his last FORM_FIGHTS, - for losses, -RUST
## after RUST_WEEKS out.
static func nudge_for(m: Dictionary, week: int) -> float:
	var h: Array = m.get("history", [])
	var n: float = 0.0
	for i in range(maxi(0, h.size() - FORM_FIGHTS), h.size()):
		n += FORM_PER_RESULT if String(h[i][2]) == "w" else (-FORM_PER_RESULT if String(h[i][2]) == "l" else 0.0)
	if not h.is_empty() and week - int(h[-1][0]) > RUST_WEEKS:
		n -= RUST
	return n


## The first week of a month: each division's regional, national-level and world-class pros topped back up to
## World.LEVELS' counts with men new to the division, and its local pros too while it has fewer pros in all than the
## pyramid's (amateurs turning pro fill the bottom, and men only retire when they're too old, D353); in January
## (`lads`) its amateurs too, with lads of NEW_AMATEUR_AGES from home.
static func new_men(w: World, week: int, lads: bool = true) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([w.seed_value, "new year", week])
	for division_id: String in Weight.ids():
		var counts: Dictionary = {}
		for m: Dictionary in w.in_division(division_id, week):
			var tier: String = String(m.get("tier", "amateur")) if not bool(m.pro) else tier_for(w.average(m))
			counts[tier] = int(counts.get(tier, 0)) + 1
		var pros_short: int = 0
		for level: Dictionary in World.LEVELS:
			if bool(level.pro):
				pros_short += int(level.count) - int(counts.get(String(level.id), 0))
			elif lads:
				for i in maxi(0, int(level.count) - int(counts.get(String(level.id), 0))):
					var lad: Dictionary = w._make_man(rng, division_id, level, week, { "age": rng.randf_range(NEW_AMATEUR_AGES[0], NEW_AMATEUR_AGES[1]) })
					lad.joined = week
		for level: Dictionary in World.LEVELS:
			if not bool(level.pro) or (String(level.id) == "local" and pros_short <= 0):
				continue
			for i in maxi(0, int(level.count) - int(counts.get(String(level.id), 0))):
				var m: Dictionary = w._make_man(rng, division_id, level, week, {})
				m.joined = week


## A pro's level by his average stat: World.LEVELS' pro levels, each from halfway between the level below's highest
## and its own lowest.
static func tier_for(avg: float) -> String:
	var out: String = "local"
	var below: float = -1.0
	for level: Dictionary in World.LEVELS:
		if not bool(level.pro):
			continue
		if below >= 0.0 and avg >= (below + float(level.avg[0])) / 2.0:
			out = String(level.id)
		below = float(level.avg[1])
	return out


## How much a week changes his average stat at this age: growing toward his potential while he's young (GROWTH), less
## each week from DECLINE_AT.
static func change_a_week(w: World, m: Dictionary, age: float) -> float:
	var rate: float = 0.0
	for step: Array in GROWTH:
		if age < float(step[0]):
			rate = float(step[1])
			break
	var change: float = maxf(0.0, float(m.get("potential", 0.0)) - w.average(m)) * rate / Career.WEEKS_PER_YEAR
	if age >= DECLINE_LATE_AT:
		change -= DECLINE_LATE / Career.WEEKS_PER_YEAR
	elif age >= DECLINE_AT:
		change -= DECLINE / Career.WEEKS_PER_YEAR
	return change


## A week older for one man: better or worse, maybe pro, maybe retired.
static func _age_a_week(w: World, m: Dictionary, week: int, rng: RandomNumberGenerator) -> void:
	var age: float = World.age_of(m, week)
	var change: float = change_a_week(w, m, age)
	m.lv = snappedf(clampf(float(m.lv) + change, -float(StyleLibrary.MAX_LEVEL), float(StyleLibrary.MAX_LEVEL)), 0.001)
	m.level = roundi(float(m.lv))
	m.best = maxf(float(m.get("best", 0.0)), snappedf(w.average(m), 0.1))
	if bool(m.pro):
		m.tier = tier_for(w.average(m))
		if rng.randf() < _weekly(retire_chance(w, m, age)):
			_retire(w, m, week)
		return
	var fights: int = int(m.record.win) + int(m.record.loss) + int(m.record.draw)
	var share: float = float(m.record.win) / maxf(1.0, float(int(m.record.win) + int(m.record.loss)))
	if age >= PRO_LATE:
		if w.average(m) >= PRO_LATE_READY:
			turn_pro(m, week)
			Promotions.place(w, m, week, true)
			w.results.append({ "kind": "pro", "week": week, "id": String(m.id), "division": String(m.division) })
		else:
			_retire(w, m, week)
		return
	if age >= PRO_FROM and fights >= PRO_AFTER and share >= PRO_WIN_SHARE and w.average(m) >= PRO_READY and rng.randf() < 1.0 / PRO_WEEKS:
		turn_pro(m, week)
		Promotions.place(w, m, week, true)
		w.results.append({ "kind": "pro", "week": week, "id": String(m.id), "division": String(m.division) })
		return


## An amateur turns pro: his amateur record is kept (`amateur_record`), his pro record starts, and his division is
## the one his weight makes now, kept from here.
static func turn_pro(m: Dictionary, week: int) -> void:
	m.amateur_record = (m.record as Dictionary).duplicate()
	m.record = { "win": 0, "loss": 0, "draw": 0 }
	m.division = World.division_of(m, week)
	m.pro = true
	m.tier = "local"
	m.turned_pro = week


## He retires: kept with his name, style, level and records (the world's history, D358), the rest let go.
static func _retire(w: World, m: Dictionary, week: int) -> void:
	w.results.append({ "kind": "retired", "week": week, "id": String(m.id), "division": World.division_of(m, week) })
	m.retired = week
	m.division = World.division_of(m, week)
	for key: String in RETIRED_DROPS:
		m.erase(key)


## Each January, the retired men nobody will look for again go for good: amateurs who never turned pro and never
## fought the career's fighter, retired before the results the hub still shows.
static func let_go(w: World, week: int) -> void:
	for id: String in w.men.keys():
		var m: Dictionary = w.men[id]
		if not World.active(m) and not bool(m.get("pro", false)) and int(m.get("met_week", -1)) < 0 \
				and int(m.retired) < week - RESULTS_WEEKS:
			w.men.erase(id)


## A pro's yearly chance of retiring at this age (see RETIRE_FROM).
static func retire_chance(w: World, m: Dictionary, age: float) -> float:
	if age < RETIRE_FROM:
		return 0.0
	if age >= RETIRE_BY:
		return 1.0
	var p: float = TOO_OLD * maxf(0.0, float(m.get("best", w.average(m))) - w.average(m) - FALLEN_FREE)
	var h: Array = m.get("history", [])
	var recent: Array = h.slice(maxi(0, h.size() - BAD_RUN_FIGHTS))
	var losses: int = recent.filter(func(x: Array) -> bool: return String(x[2]) == "l").size()
	var kos: int = recent.filter(func(x: Array) -> bool: return String(x[2]) == "l" and String(x[3]) == "ko").size()
	if losses >= BAD_RUN_LOSSES:
		p += BAD_RUN
	if kos >= KO_RUN_KOS:
		p += KO_RUN
	return clampf(p, 0.0, 1.0)


## A yearly chance as a weekly one.
static func _weekly(year: float) -> float:
	return 1.0 - pow(1.0 - clampf(year, 0.0, 0.999), 1.0 / Career.WEEKS_PER_YEAR)


static func _met_lately(m: Dictionary, other_id: String, week: int) -> bool:
	for h: Array in m.get("history", []):
		if String(h[1]) == other_id and week - int(h[0]) < World.REMATCH_WEEKS:
			return true
	return false


static func _method(method: String) -> String:
	var m: String = method.to_lower()
	if m == "ko" or m == "tko" or m.begins_with("ko") or m.begins_with("tko"):
		return "ko"
	if m.begins_with("sub"):
		return "submission"
	if m == "draw":
		return "draw"
	return "decision"


static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: Variant = items[i]
		items[i] = items[j]
		items[j] = t
