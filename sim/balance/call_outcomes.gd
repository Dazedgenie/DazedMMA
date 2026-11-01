class_name CallOutcomes
extends RefCounted
## What each call did (D257, Kyle's D251 answer): for every call a fighter's corner made, whether
## the fighter took it, and whether the move or the spell it was called for won the exchange.
## Worked out from a finished fight's events, so it reads any fight, the harness's or a saved one.
##
## The exchange each kind of call is for, and what winning it is:
##   a move (Takedown!, Clinch!, Get up!, Pass!, Collar tie!, Feint! and its shot): the move
##     started on the call works within ATTEMPT_WINDOW of taking it
##   a read (Catch the kick!), taken once he's primed: it goes off (only then is it counted) and
##     the move it fires works within READ_WINDOW; Fire back!: it goes off and he lands more than
##     he takes in the READ_WINDOW after
##   a spell of focus, over the focus's time:
##     Survive!: not knocked down or stopped
##     Defend the shot!: the opponent shoots and lands no takedown (no shot: not counted)
##     Finish it!: the tap; Defend the sub!: out of the hold; Go for the finish!: a hold locked in
##     Cut the cage!: the opponent pinned on the fence; Circle out!: back to the centre, not taken down
##     the rest (Pressure!, Ground and pound!, Work the range!, Stay safe!): he lands more than he
##     takes, or knocks him down or stops him (no strikes either way: not counted)
## A call that's ignored, can't be done or is missed is heard but not taken.

## Ticks a called move has to work in: the call's 2 s to find the range and the move itself.
const ATTEMPT_WINDOW: int = LiveCalls.ATTEMPT_TICKS + 20
## Ticks after a read goes off for the move it fired to work.
const READ_WINDOW: int = 20

const HEARD := 0
const TAKEN := 1
const JUDGED := 2
const WON := 3


## call id → [heard, taken, judged (an exchange came), won], for fighter `who` in this fight.
static func of(events: Array, who: int, actions: ActionLibrary, calls: CallLibrary = null) -> Dictionary:
	var library: CallLibrary = calls if calls != null else CallLibrary.shared()
	var out: Dictionary = {}
	var open: Array[Dictionary] = []
	for e: FightEvent in events:
		for x: Dictionary in open:
			if e.tick > x.until:
				_close(out, x)
		open = open.filter(func(x: Dictionary) -> bool: return not x.closed)
		if e.actor == who and e.type == FightEvent.CALL_HEARD:
			_count(out, e.data.call_id)[HEARD] += 1
		if e.actor == who and e.type == FightEvent.CALL_ANSWERED and library.has(e.data.call_id):
			var call: Dictionary = library.get_call(e.data.call_id)
			var shape: String = LiveCalls.shape(call)
			if e.data.outcome == LiveCalls.ACCEPTED:
				# Feint!'s shot is accepted again off the feint (D131): one call, one exchange.
				if open.any(func(x: Dictionary) -> bool: return x.id == call.id and x.test == "moves" and shape == LiveCalls.ATTEMPT):
					continue
				_count(out, call.id)[TAKEN] += 1
				if shape != LiveCalls.READ:
					open.append(_exchange(call, shape, e.tick))
			elif e.data.outcome == LiveCalls.FIRED:
				open.append(_exchange(call, shape, e.tick))
		for x: Dictionary in open:
			_watch(x, e, who, actions)
		open = open.filter(func(x: Dictionary) -> bool:
			if x.closed:
				_close(out, x)
			return not x.closed)
		if e.type == FightEvent.FIGHT_ENDED or e.type == FightEvent.ROUND_ENDED:
			for x: Dictionary in open:
				_close(out, x)
			open.clear()
	for x: Dictionary in open:
		_close(out, x)
	return out


## The outcomes as one CSV cell: "takedown:5/3/3/1;survive:2/2/2/2" (heard/taken/judged/won), by call id.
static func as_text(outcomes: Dictionary) -> String:
	var ids: Array = outcomes.keys()
	ids.sort()
	var parts: PackedStringArray = []
	for id: String in ids:
		var n: Array = outcomes[id]
		parts.append("%s:%d/%d/%d/%d" % [id, n[0], n[1], n[2], n[3]])
	return ";".join(parts)


## A CSV cell back into outcomes ("" or "0" is none).
static func from_text(text: String) -> Dictionary:
	var out: Dictionary = {}
	if text == "" or text == "0":
		return out
	for part: String in text.split(";", false):
		var n: PackedStringArray = part.get_slice(":", 1).split("/")
		out[part.get_slice(":", 0)] = [int(n[0]), int(n[1]), int(n[2]), int(n[3])]
	return out


## Adds `more` into `total` (both as of()).
static func add(total: Dictionary, more: Dictionary) -> void:
	for id: String in more:
		var t: Array = total.get_or_add(id, [0, 0, 0, 0])
		for k in 4:
			t[k] += more[id][k]


static func _count(out: Dictionary, id: String) -> Array:
	return out.get_or_add(id, [0, 0, 0, 0])


## One exchange a taken call is for, open until it's decided or its window ends.
static func _exchange(call: Dictionary, shape: String, tick: int) -> Dictionary:
	var test: String = "moves"
	var window: int = ATTEMPT_WINDOW
	if shape == LiveCalls.READ:
		window = READ_WINDOW
		test = "strikes" if call.get("combo", false) else "moves"
	elif shape == LiveCalls.FOCUS:
		window = int(call.focus.duration_ms) / FightClock.TICK_MS
		test = call.id if call.id in ["survive", "defend_the_shot", "finish_it", "defend_the_sub",
			"go_for_the_finish", "cut_the_cage", "circle_out"] else "strikes"
	var moves: Array = call.get("actions", []).duplicate()
	moves.append_array(call.get("then", []))
	# Judged at once when the call itself is the exchange; otherwise once one comes.
	var judged: bool = test in ["moves", "survive", "finish_it", "defend_the_sub", "go_for_the_finish", "cut_the_cage", "circle_out"]
	return { "id": call.id, "test": test, "until": tick + window, "moves": moves, "judged": judged,
		"won": false, "lost": false, "closed": false, "dealt": 0.0, "taken": 0.0, "decisive": false }


## Reads one event into an open exchange; closes it once it's decided.
static func _watch(x: Dictionary, e: FightEvent, who: int, actions: ActionLibrary) -> void:
	var mine: bool = e.actor == who
	match x.test:
		"moves":
			if mine and e.type == FightEvent.GRAPPLE_WON and x.moves.has(e.data.action_id):
				_decide(x, true)
		"strikes":
			if e.type == FightEvent.STRIKE_LANDED:
				x.judged = true
				if mine:
					x.dealt += float(e.data.get("damage", 0.0))
				else:
					x.taken += float(e.data.get("damage", 0.0))
			elif e.type == FightEvent.KNOCKDOWN:
				x.judged = true
				_decide(x, not mine)
		"survive":
			if mine and e.type == FightEvent.KNOCKDOWN:
				_decide(x, false)
		"defend_the_shot":
			if not mine and e.type == FightEvent.ACTION_PHASE and _is_takedown(actions, e.data.action_id):
				x.judged = true
			elif not mine and e.type == FightEvent.GRAPPLE_WON and _is_takedown(actions, e.data.action_id):
				_decide(x, false)
		"defend_the_sub":
			if mine and e.type == FightEvent.SUBMISSION_ESCAPED:
				_decide(x, true)
		"go_for_the_finish":
			if mine and e.type == FightEvent.SUBMISSION_LOCKED:
				_decide(x, true)
		"cut_the_cage":
			if not mine and e.type == FightEvent.CAGE_CHANGED and e.data.proximity == Octagon.CAGE_PINNED:
				_decide(x, true)
		"circle_out":
			if mine and e.type == FightEvent.CAGE_CHANGED and e.data.proximity == Octagon.CAGE_CENTRE:
				_decide(x, true)
			elif not mine and e.type == FightEvent.GRAPPLE_WON and _is_takedown(actions, e.data.action_id):
				_decide(x, false)
	if e.type == FightEvent.FIGHT_ENDED:
		var winner: int = int(e.data.get("winner", -1))
		match x.test:
			"finish_it":
				_decide(x, winner == who and e.data.result == FightSim.RESULT_SUB)
			"survive", "strikes":
				if e.data.result in [FightSim.RESULT_KO, FightSim.RESULT_TKO, FightSim.RESULT_SUB] and winner >= 0:
					x.judged = true
					_decide(x, winner == who)


static func _decide(x: Dictionary, won: bool) -> void:
	if x.closed:
		return
	x.judged = true
	x.won = won
	x.decisive = true
	x.closed = true


## Counts a finished exchange: what it was judged as when it closed.
static func _close(out: Dictionary, x: Dictionary) -> void:
	if x.get("counted", false):
		return
	x.counted = true
	x.closed = true
	var won: bool = x.won
	if not x.decisive:
		match x.test:
			"strikes":
				won = x.dealt > x.taken
			"survive", "defend_the_shot":
				won = true  # He came through it.
			_:
				won = false
	if not x.judged:
		return
	var n: Array = _count(out, x.id)
	n[JUDGED] += 1
	if won:
		n[WON] += 1


static func _is_takedown(actions: ActionLibrary, action_id: String) -> bool:
	return actions.has(action_id) and actions.get_action(action_id).get("category", "") == "takedown"
