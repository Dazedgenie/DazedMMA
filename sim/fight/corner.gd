class_name Corner
extends RefCounted
## A corner that makes calls on its own: the opponent's AI corner (D68) and the
## balance harness's coaching bots (#18, D12). It watches the fight from the cage
## like a coach, picks a call, and shouts it a coach's reaction time later as a
## live_call command, so the call goes through the fighter's whole pipeline
## (voice, delay, compliance, LiveCalls) and the fight replays from its command
## log without the corner. Its own choices draw from its own seeded RNG, never
## the fight's, so a fight with a corner that never calls is the fight without one.
##
## Styles:
##   none   never calls
##   ideal  the "good coaching" bot (D12): a good player who sees every moment, calls the
##          right thing 0.3 s later, and never calls on a spent voice
##   ai     the opponent's corner (D68): the same calls, slower, and it misses some moments
##   spam   calls something every 1.5 s, whatever is happening
##   mash   the key masher (D257): one call (`mash:takedown`), again as soon as it's done and
##          wherever it can be heard, never on a spent voice
##
## What it calls (ideal and ai), all from data where it can be:
##   - the opponent starts a move one of this fighter's read calls is for (a kick):
##     Takedown! at once, so the call lands while the leg is up
##   - the opponent's scouted tell is set off (their jab blocked: a kick is coming): the read
##     call for that move (Catch the kick!), so the fighter is primed before the kick
##   - this fighter rocked: Survive!; the opponent rocked: Pressure! (Ground and pound! on top,
##     Get up! underneath)
##   - this fighter ends up on top: Ground and pound! (D121), once: not again for a pass (D130)
##   - a submission locks in (D126): Finish it! for the attacker, Defend the sub! for the defender
## and since D257, moments for the calls it used to leave out (MOMENTS; docs/01 §22.10). A plain ideal
## or AI corner uses DEFAULT_MOMENTS, the ones that won fights; the rest cost wins and wait to be tried again:
##   - fire_back: the opponent's strike follows on into a combination: Fire back!, primed for the rest
##     (not for a fighter who shoots: a fired Fire back! holds his own leads, his shots, for 10 s)
##   - defend_the_shot: the opponent shoots: Defend the shot!, kept up while he keeps shooting
##   - feint: this fighter's shot is stuffed: Feint!, so the next one is set up
##   - get_up: the man on top is rocked: Get up!
##   - pass: the man underneath covers up (D270): Pass!
##   - go_for_the_finish: on top in side control, mount or on the back with a hold he knows
##     there: Go for the finish! (D200)
##   - collar_tie: the clinch starts and he knows the collar tie (D129), against a man who doesn't
##     shoot: Collar tie!
##   - cut_the_cage: the opponent circles away and this fighter is the one coming forward:
##     Cut the cage! (D231)
##   - circle_out: this fighter, an outside fighter, is near the fence and being cut off: Circle out!
##   - follow_down: the opponent is knocked down and this fighter is a grappler: Takedown! (D142)
##   - keep_pressing: he isn't an outside fighter (Range 0 or more), he's winning the exchanges on the
##     feet (PRESSING_LEAD more damage in the last PRESSING_TICKS) and no other focus is on: Pressure!
## A focus call never replaces a more urgent one still running (Survive!, Pressure!, Ground and
## pound!, the struggle calls), and no moment is called again while its last call is still on.

const NONE := "none"
const IDEAL := "ideal"
const AI := "ai"
const SPAM := "spam"
const MASH := "mash"
const STYLES: Array[String] = [NONE, IDEAL, AI, SPAM, MASH]
## The moments the ideal and AI corners have called since D257. A style written `ideal:fire_back+pass`
## (the harness's --corners) uses only these of them, `ideal:` none, to weigh each one on its own.
const MOMENTS: Array[String] = ["fire_back", "defend_the_shot", "feint", "get_up", "pass",
	"go_for_the_finish", "collar_tie", "cut_the_cage", "circle_out", "follow_down", "keep_pressing"]
## The moments a plain `ideal` or `ai` corner uses: the ones that won fights when tried one by one
## (docs/01 §22.10). The others cost wins at these moments and stay for the harness to try again.
const DEFAULT_MOMENTS: Array[String] = ["fire_back", "get_up", "collar_tie", "cut_the_cage", "follow_down", "keep_pressing"]
## keep_pressing: Pressure! when this fighter has landed this much more damage than he's taken over
## the last PRESSING_TICKS standing, and no other focus is on.
const PRESSING_LEAD: float = 10.0
const PRESSING_TICKS: int = 200
## Focus calls a new focus mustn't replace while they're on (the corner's own count of them).
const URGENT: Array[String] = ["survive", "pressure", "ground_and_pound", "finish_it", "defend_the_sub"]
## Where Go for the finish! is called on top (D257): the positions with holds from on top.
const FINISH_FROM: Array[String] = ["side_control", "mount", "back_control"]
## Why a stuffed shot stopped, for the Feint! moment (FightEvent.GRAPPLE_STOPPED).
const STUFFED: Array[String] = ["defended", "sprawled on", "stopped"]

## Ticks from seeing a moment to the call leaving the coach's mouth.
const IDEAL_REACTION: int = 3
const AI_REACTION: int = 5
## Share of moments the AI corner notices (its coaching level, D15, later).
const AI_NOTICE: float = 0.5
## The spam bot calls every this many ticks, picking any call at random.
const SPAM_EVERY: int = 15
## The ideal and AI corners don't call with less voice than this (it would be garbled).
const SAVE_VOICE: float = LiveCalls.GARBLED_BELOW

var style: String
## The style with its moments or mashed call, as written (`ideal:fire_back`, `mash:takedown`): the harness's label.
var label: String
## The D257 moments this corner uses (all of them unless the label says otherwise).
var moments: Dictionary = {}
var reaction: int = IDEAL_REACTION
var notice: float = 1.0
var only: Array = []
var _calls: CallLibrary
var _triggers: TriggerLibrary
var _rng := RandomNumberGenerator.new()
## Calls decided on and waiting for the coach's reaction time: [{at, call_id}], in order.
var _queue: Array[Dictionary] = []
## Worked out once a fight: read call id → the opponent's moves it's for; the opponent's
## tells as {trigger, action}; the call ids this fighter can act on.
var _ready: bool = false
var _reads: Dictionary = {}
var _tells: Array[Dictionary] = []
var _usable: Dictionary = {}
## This fighter was on top before the last change of position (a pass keeps them there, D130).
var _was_top: bool = false
## Call id → the tick its last call stops being on (its focus, read or attempt, D257): not again before.
var _on_until: Dictionary = {}
## The focus the corner last called and when it ends: a new one doesn't replace an urgent one.
var _focus_id: String = ""
var _focus_until: int = -1
## Whether this fighter shoots: knows a takedown that isn't everyone's (D257 follow_down).
var _grappler: bool = false
## Whether the opponent shoots (D257 defend_the_shot is only worth a voice against a shooter).
var _opponent_shoots: bool = false
## The strikes landed standing lately, for keep_pressing: [{tick, dealt (true: by this fighter), damage}].
var _recent: Array[Dictionary] = []


func _init(p_style: String = NONE, p_seed: int = 0, p_calls: CallLibrary = null, p_triggers: TriggerLibrary = null) -> void:
	assert(valid(p_style), "unknown corner style '%s'" % p_style)
	label = p_style
	style = p_style.get_slice(":", 0)
	_rng.seed = p_seed
	_calls = p_calls if p_calls != null else CallLibrary.shared()
	_triggers = p_triggers if p_triggers != null else TriggerLibrary.shared()
	if style == AI:
		reaction = AI_REACTION
		notice = AI_NOTICE
	var picked: PackedStringArray = DEFAULT_MOMENTS if not p_style.contains(":") else p_style.get_slice(":", 1).split("+", false)
	for id: String in picked:
		moments[id] = true
	if style == MASH:
		only = [p_style.get_slice(":", 1)]


## Whether `text` names a corner: a style, `ideal:`/`ai:` with some of MOMENTS joined by +, or `mash:` and a call id.
static func valid(text: String, p_calls: CallLibrary = null) -> bool:
	var base: String = text.get_slice(":", 0)
	if base not in STYLES:
		return false
	if not text.contains(":"):
		return base != MASH
	var rest: String = text.get_slice(":", 1)
	if base == MASH:
		return (p_calls if p_calls != null else CallLibrary.shared()).has(rest)
	if base != IDEAL and base != AI:
		return false
	for id: String in rest.split("+", false):
		if id not in MOMENTS:
			return false
	return true


## The call ids to shout this tick (FightSim submits them as live_call commands).
func due(view: FightView, voice: float) -> Array[String]:
	var out: Array[String] = []
	if style == NONE:
		return out
	_prepare(view)
	if style == SPAM:
		if view.now > 0 and view.now % SPAM_EVERY == 0:
			var ids: Array = _calls.ids() if only.is_empty() else only
			out.append(ids[_rng.randi_range(0, ids.size() - 1)])
		return out
	if style == MASH:
		var id: String = only[0]
		if _usable.has(id) and view.now >= int(_on_until.get(id, 0)) and _heard_here(view, _calls.get_call(id)) \
				and voice >= SAVE_VOICE + float(_calls.get_call(id).voice_cost):
			_on_until[id] = view.now + _hold(_calls.get_call(id))
			out.append(id)
		return out
	_watch(view)
	while not _queue.is_empty() and _queue[0].at <= view.now:
		var id: String = _queue.pop_front().call_id
		var call: Dictionary = _calls.get_call(id)
		if voice >= SAVE_VOICE + float(call.voice_cost) or voice >= LiveCalls.VOICE_MAX:
			out.append(id)
			voice -= float(call.voice_cost)
			if call.has("focus"):
				_focus_id = id
				_focus_until = view.now + int(call.focus.duration_ms) / FightClock.TICK_MS
	return out


## Every fight event, as this fighter's corner sees it.
func on_event(view: FightView, event: FightEvent) -> void:
	if style == NONE or style == SPAM or style == MASH:
		return
	_prepare(view)
	var me: int = view.index
	match event.type:
		FightEvent.ROCKED:
			if event.actor == me:
				_decide(event.tick, "survive")
			elif view.is_standing():
				_decide(event.tick, "pressure")
			elif view.my_role() == PositionLibrary.TOP:
				_decide(event.tick, "ground_and_pound")
			else:
				_moment(view, event.tick, "get_up")
		FightEvent.POSITION_CHANGED:
			var was_top: bool = _was_top
			_was_top = event.data.roles[me] == PositionLibrary.TOP
			if _was_top and not was_top:
				_decide(event.tick, "ground_and_pound")
			elif event.data.roles[me] == PositionLibrary.ATTACKER:
				_decide(event.tick, "finish_it")
			elif event.data.roles[me] == PositionLibrary.DEFENDER:
				_decide(event.tick, "defend_the_sub")
			var at: String = str(event.data.get("position", ""))
			if _was_top and at in FINISH_FROM and _knows_hold(view, at):
				_moment(view, event.tick, "go_for_the_finish")
			elif at == PositionLibrary.CLINCH and not _opponent_shoots:
				_moment(view, event.tick, "collar_tie")
		FightEvent.ROUND_ENDED:
			_was_top = false  # Every round starts standing.
			_focus_until = -1
			_recent.clear()
		FightEvent.ACTION_PHASE:
			if event.actor != me:
				if event.data.phase == "telegraph":
					for read_id: String in _reads:
						if _reads[read_id].has(event.data.action_id):
							_decide(event.tick, "takedown")
				var category: String = str(view.actions.get_action(event.data.action_id).get("category", "")) \
					if view.actions.has(event.data.action_id) else ""
				if category == FighterAI.STRIKE and event.data.phase == "telegraph" and int(event.data.get("step", 0)) == 1 \
						and view.is_standing() and not _grappler:
					_moment(view, event.tick, "fire_back")
				elif category == "takedown" and event.data.phase in ["telegraph", "windup"] and _opponent_shoots:
					_moment(view, event.tick, "defend_the_shot")
				elif event.data.action_id == FightSim.GROUND_COVER and event.data.phase == "windup" \
						and view.my_role() == PositionLibrary.TOP and view.position() != "back_control":
					_moment(view, event.tick, "pass")
		FightEvent.GRAPPLE_STOPPED:
			if event.actor == me and str(event.data.get("reason", "")) in STUFFED and view.actions.has(event.data.action_id) \
					and view.actions.get_action(event.data.action_id).get("category", "") == "takedown":
				_moment(view, event.tick, "feint")
		FightEvent.STRIKE_LANDED:
			if moments.has("keep_pressing") and view.is_standing():
				_recent.append({ "tick": event.tick, "dealt": event.actor == me, "damage": float(event.data.get("damage", 0.0)) })
		FightEvent.KNOCKDOWN:
			if event.actor != me and _grappler:
				_moment(view, event.tick, "follow_down", "takedown")
	for tell: Dictionary in _tells:
		if _triggers.matches(tell.trigger, event, 1 - me):
			for read_id: String in _reads:
				if _reads[read_id].has(tell.action):
					_decide(event.tick, read_id)


## The moments read off the fight as it stands, not from one event (D257): who's circling, who's cutting.
func _watch(view: FightView) -> void:
	if not view.is_standing() or view.me.style == null or view.opponent.style == null:
		return
	var my_range: float = view.me.style.value(StyleLeanings.RANGE)
	if moments.has("cut_the_cage") and view.opponent_circling() and not view.cutting() \
			and my_range > view.opponent.style.value(StyleLeanings.RANGE):
		_moment(view, view.now, "cut_the_cage")
	if moments.has("keep_pressing") and not _recent.is_empty() and my_range >= 0.0:
		while not _recent.is_empty() and _recent[0].tick < view.now - PRESSING_TICKS:
			_recent.pop_front()
		var lead: float = 0.0
		for hit: Dictionary in _recent:
			lead += hit.damage if hit.dealt else -hit.damage
		if lead >= PRESSING_LEAD and (_focus_until < view.now or _focus_id == "pressure"):
			_moment(view, view.now, "keep_pressing", "pressure")
	if moments.has("circle_out") and my_range < 0.0 and view.opponent_cutting() \
			and view.my_cage_proximity() != Octagon.CAGE_CENTRE:
		_moment(view, view.now, "circle_out")


## A D257 moment: its call, unless this corner leaves the moment out, the call is still on from last
## time, or it's a focus that would cut short a more urgent one. A moment it doesn't notice (the AI
## corner) is gone all the same: it isn't looked at again until the call would have ended.
func _moment(view: FightView, tick: int, moment: String, call_id: String = "") -> void:
	var id: String = moment if call_id == "" else call_id
	if not moments.has(moment) or not _usable.has(id) or tick < int(_on_until.get(id, 0)):
		return
	var call: Dictionary = _calls.get_call(id)
	if not _heard_here(view, call):
		return
	if call.has("focus") and _focus_id in URGENT and tick < _focus_until and _focus_id != id \
			and not (id == "go_for_the_finish" and _focus_id == "ground_and_pound"):
		return
	_on_until[id] = tick + reaction + _hold(call)
	_decide(tick, id)


## Queues a call for the coach's reaction time from now, if it's one this fighter can act on
## and the corner notices the moment.
func _decide(tick: int, call_id: String) -> void:
	if not _usable.has(call_id) or (not only.is_empty() and not only.has(call_id)):
		return
	if notice < 1.0 and _rng.randf() >= notice:
		return
	_queue.append({ "at": tick + reaction, "call_id": call_id })


## How long a call is on once it's taken: its focus or read, an attempt's 2 s; never under the
## 3 s that makes the same call again spam (LiveCalls.SPAM_TICKS).
static func _hold(call: Dictionary) -> int:
	var ms: int = 0
	if call.has("focus"):
		ms = int(call.focus.duration_ms)
	elif call.has("read"):
		ms = int(call.read.duration_ms)
	var ticks: int = ms / FightClock.TICK_MS if ms > 0 else LiveCalls.ATTEMPT_TICKS
	return maxi(ticks, LiveCalls.SPAM_TICKS + 1)


## Whether the call can be taken where the fight is now: its positions and roles.
static func _heard_here(view: FightView, call: Dictionary) -> bool:
	if not call.get("positions", []).has(view.position()):
		return false
	return not call.has("roles") or call.roles.has(view.my_role())


## Whether this fighter knows a submission he can go for from on top in this position.
func _knows_hold(view: FightView, at: String) -> bool:
	for id: String in view.me.repertoire:
		if not view.actions.has(id):
			continue
		var action: Dictionary = view.actions.get_action(id)
		if action.get("category", "") == "submission" and action.get("positions", []).has(at) \
				and action.get("roles", []).has(PositionLibrary.TOP):
			return true
	for id: String in view.actions.ids():
		var action: Dictionary = view.actions.get_action(id)
		if action.get("basic", false) and action.get("category", "") == "submission" \
				and action.get("positions", []).has(at) and action.get("roles", []).has(PositionLibrary.TOP):
			return true
	return false


func _prepare(view: FightView) -> void:
	if _ready:
		return
	_ready = true
	for id: String in _calls.ids():
		var call: Dictionary = _calls.get_call(id)
		var technique: Variant = call.get("requires_technique")
		if technique != null and not view.me.repertoire.has(technique):
			continue
		var knows: bool = call.get("actions", []).is_empty()
		for action_id: String in call.get("actions", []):
			if view.actions.has(action_id):
				var action: Dictionary = view.actions.get_action(action_id)
				knows = knows or action.get("basic", false) or view.me.repertoire.has(action_id)
		if not knows:
			continue
		_usable[id] = true
		if LiveCalls.shape(call) == LiveCalls.READ:
			var trigger: Dictionary = _triggers.get_trigger(call.read.trigger)
			_reads[id] = trigger.get("match", {}).get("action_ids", [])
	_grappler = _shoots(view, view.me)
	_opponent_shoots = _shoots(view, view.opponent)
	for t: Dictionary in view.opponent.tells:
		if _triggers.has(t.trigger):
			_tells.append({ "trigger": t.trigger, "action": t.action })


## Whether a fighter knows a takedown of his own (not just following a downed man down).
static func _shoots(view: FightView, fighter: FighterState) -> bool:
	for id: String in fighter.repertoire:
		if view.actions.has(id) and view.actions.get_action(id).get("category", "") == "takedown" \
				and not view.actions.get_action(id).get("basic", false):
			return true
	return false
