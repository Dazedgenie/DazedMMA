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
##
## What it calls (ideal and ai), all from data where it can be:
##   - the opponent starts a move one of this fighter's read calls is for (a kick):
##     Takedown! at once, so the call lands while the leg is up
##   - the opponent's scouted tell is set off (their jab blocked: a kick is coming): the read
##     call for that move (Catch the kick!), so the fighter is primed before the kick
##   - this fighter rocked: Survive!; the opponent rocked: Pressure!
##   - this fighter ends up on top: Ground and pound! (D121)
## It doesn't call Get up!: the fighter works to get up on their own, and a called try
## adds a tired try more than it helps. Nor Defend the shot! on the Wrestler's
## stance shift: the shot comes within a second, before the call can land, and the fighter
## already reads repeated shots better on their own (FighterAI.WISE_READ).

const NONE := "none"
const IDEAL := "ideal"
const AI := "ai"
const SPAM := "spam"
const STYLES: Array[String] = [NONE, IDEAL, AI, SPAM]

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


func _init(p_style: String = NONE, p_seed: int = 0, p_calls: CallLibrary = null, p_triggers: TriggerLibrary = null) -> void:
	assert(p_style in STYLES, "unknown corner style '%s'" % p_style)
	style = p_style
	_rng.seed = p_seed
	_calls = p_calls if p_calls != null else CallLibrary.shared()
	_triggers = p_triggers if p_triggers != null else TriggerLibrary.shared()
	if style == AI:
		reaction = AI_REACTION
		notice = AI_NOTICE


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
	while not _queue.is_empty() and _queue[0].at <= view.now:
		var id: String = _queue.pop_front().call_id
		if voice >= SAVE_VOICE + float(_calls.get_call(id).voice_cost) or voice >= LiveCalls.VOICE_MAX:
			out.append(id)
			voice -= float(_calls.get_call(id).voice_cost)
	return out


## Every fight event, as this fighter's corner sees it.
func on_event(view: FightView, event: FightEvent) -> void:
	if style == NONE or style == SPAM:
		return
	_prepare(view)
	var me: int = view.index
	match event.type:
		FightEvent.ROCKED:
			if event.actor == me:
				_decide(event.tick, "survive")
			else:
				_decide(event.tick, "ground_and_pound" if view.my_role() == PositionLibrary.TOP else "pressure")
		FightEvent.POSITION_CHANGED:
			if event.data.roles[me] == PositionLibrary.TOP:
				_decide(event.tick, "ground_and_pound")
		FightEvent.ACTION_PHASE:
			if event.data.phase == "telegraph" and event.actor != me:
				for read_id: String in _reads:
					if _reads[read_id].has(event.data.action_id):
						_decide(event.tick, "takedown")
	for tell: Dictionary in _tells:
		if _triggers.matches(tell.trigger, event, 1 - me):
			for read_id: String in _reads:
				if _reads[read_id].has(tell.action):
					_decide(event.tick, read_id)


## Queues a call for the coach's reaction time from now, if it's one this fighter can act on
## and the corner notices the moment.
func _decide(tick: int, call_id: String) -> void:
	if not _usable.has(call_id) or (not only.is_empty() and not only.has(call_id)):
		return
	if notice < 1.0 and _rng.randf() >= notice:
		return
	_queue.append({ "at": tick + reaction, "call_id": call_id })


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
	for t: Dictionary in view.opponent.tells:
		if _triggers.has(t.trigger):
			_tells.append({ "trigger": t.trigger, "action": t.action })
