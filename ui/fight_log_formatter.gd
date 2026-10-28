class_name FightLogFormatter
extends RefCounted
## Turns FightEvents into readable console lines (BBCode) for the debug console.
## Presentation only: reads events and the sim's fighters/actions, never changes them.

const FIGHTER_COLOURS: Array[String] = ["#ff6b6b", "#5fa8ff"]
const PASS_COLOUR := "#6bd66b"
const FAIL_COLOUR := "#ff5555"
const DIM_COLOUR := "#8a8f98"
## Stats the debug summary shows when condition has moved them (docs/11 §3.2).
const RANGE_NAMES := { "out": "out of range", "long": "long (kicking range)", "mid": "mid (punching range)", "pocket": "in the pocket" }
const CAGE_NAMES := { "centre": "is back in open space", "near": "is near the fence", "pinned": "is PINNED against the cage" }
const RESULT_NAMES := { "ko": "KO", "tko": "TKO", "submission": "submission" }
## How the referee's stoppages read (FIGHT_ENDED `why`, D120).
const STOP_REASONS := {
	"health": "the referee stops it: nothing left",
	"unanswered": "the referee stops it: taking shots and not answering",
	"knockdowns": "the referee stops it: three knockdowns in a round",
}
const CALL_OUTCOMES := {
	"accepted": "takes", "ignored": "[b]IGNORES[/b]", "infeasible": "can't do", "fired": "goes on the read of",
	"missed": "misses with the read of", "expired": "is done with", "replaced": "drops",
}
const RULE_OUTCOMES := {
	"set": "drilled", "fired": "goes on the", "cooling": "holds the", "slow": "is too slow for the",
	"outranked": "skips the", "not_eligible": "can't use the", "missed": "misses with the",
}
const CONDITION_STATS: Array[String] = ["boxing", "kicking", "power", "speed", "striking_defense", "footwork", "takedowns", "takedown_defense", "fight_iq"]


## Phase changes are noisy; the console hides them unless "phase details" is on.
static func is_detail(event: FightEvent) -> bool:
	if event.type == FightEvent.ACTION_ENDED:
		return true
	return event.type == FightEvent.ACTION_PHASE and event.data.phase != "telegraph"


## Fight time since the start of the event's round, e.g. "R1 0:03.4".
static func time_label(event: FightEvent, round_seconds: int) -> String:
	var ticks_per_round: int = round_seconds * FightClock.TICKS_PER_SECOND
	var in_round: int = event.tick - (event.round_number - 1) * ticks_per_round
	var seconds: int = in_round / FightClock.TICKS_PER_SECOND
	var tenths: int = in_round % FightClock.TICKS_PER_SECOND
	return "R%d %d:%02d.%d" % [event.round_number, seconds / 60, seconds % 60, tenths]


static func line(event: FightEvent, sim: FightSim) -> String:
	var stamp: String = "[color=%s]%s  t%d[/color]  " % [DIM_COLOUR, time_label(event, sim.clock.round_seconds), event.tick]
	return stamp + _describe(event, sim)


## The event in words (BBCode) without the time stamp: the fight screen's feed adds its own clock.
static func describe(event: FightEvent, sim: FightSim) -> String:
	return _describe(event, sim)


static func _describe(event: FightEvent, sim: FightSim) -> String:
	var who: String = _fighter(event.actor, sim)
	match event.type:
		FightEvent.ACTION_PHASE:
			if event.data.phase == "telegraph":
				var why: String = String(event.data.get("why", ""))
				var reason: String = "  [color=%s](%s)[/color]" % [DIM_COLOUR, why] if why != "" else ""
				return "%s starts a %s%s" % [who, _action_name(event.data.action_id, sim), reason]
			return "[color=%s]%s %s → %s[/color]" % [DIM_COLOUR, who, _action_name(event.data.action_id, sim), event.data.phase]
		FightEvent.ACTION_ENDED:
			return "[color=%s]%s %s finished[/color]" % [DIM_COLOUR, who, _action_name(event.data.action_id, sim)]
		FightEvent.STRIKE_LANDED:
			var counter: String = "counter " if event.data.get("counter", false) else ""
			var into: String = " into the %s" % _action_name(event.data.into, sim).to_lower() if event.data.has("into") else ""
			return "%s's %s%s [b]LANDS[/b]%s (%s, %d damage)%s" % [who, counter, _action_name(event.data.action_id, sim), into, event.data.target, event.data.damage, _odds(event)]
		FightEvent.GRAPPLE_WON:
			if event.data.result == "tied_up" and event.data.action_id == FightSim.COLLAR_TIE:
				return "%s gets the [b]COLLAR TIE[/b]: his head is pulled down for the knees%s" % [who, _odds(event)]
			if event.data.result == "tied_up":
				return "%s [b]TIES HIM UP[/b] from the bottom: no ground strikes for a few seconds%s" % [who, _odds(event)]
			if event.data.result == PositionLibrary.PARTIAL:
				return "%s's %s [b]half works[/b]: they scramble%s" % [who, _action_name(event.data.action_id, sim), _odds(event)]
			if event.data.has("landing_damage"):
				return "%s's %s [b]WORKS[/b]: slammed down (%d damage)%s" % [who, _action_name(event.data.action_id, sim), event.data.landing_damage, _odds(event)]
			return "%s's %s [b]WORKS[/b]%s" % [who, _action_name(event.data.action_id, sim), _odds(event)]
		FightEvent.GRAPPLE_STOPPED:
			return "%s's %s %s" % [who, _action_name(event.data.action_id, sim), _stopped(event, sim)]
		FightEvent.SPRAWLED:
			if event.data.worked:
				return "%s [b]SPRAWLS[/b] on it%s" % [who, _odds(event)]
			return "%s's sprawl doesn't hold%s" % [who, _odds(event)]
		FightEvent.STRIKE_MISSED:
			if event.data.has("reason"):
				return "%s's %s misses (%s)" % [who, _action_name(event.data.action_id, sim), event.data.reason]
			return "%s's %s misses%s" % [who, _action_name(event.data.action_id, sim), _odds(event)]
		FightEvent.RANGE_CHANGED:
			return "[color=%s]Range: %s[/color]" % [DIM_COLOUR, RANGE_NAMES.get(event.data.band, event.data.band)]
		FightEvent.POSITION_CHANGED:
			if event.data.get("escaped", false):
				return "[b]%s is out of the %s → %s[/b]%s" % [who, _action_name(event.data.action_id, sim).to_lower(), _position_name(event.data.position, sim), _roles(event, sim)]
			if event.data.action_id == "":
				return "[b]They come apart → %s[/b]" % _position_name(event.data.position, sim)
			return "[b]%s's %s → %s[/b]%s" % [who, _action_name(event.data.action_id, sim), _position_name(event.data.position, sim), _roles(event, sim)]
		FightEvent.SUBMISSION_LOCKED:
			return "[b]%s LOCKS IN the %s![/b] danger %d" % [who, _action_name(event.data.action_id, sim).to_lower(), event.data.danger]
		FightEvent.SUBMISSION_BEAT:
			var way: String = "squeezes" if event.data.gained else "loses ground"
			return "%s %s on the %s: danger [b]%d[/b]  [color=%s](%d%% to win the beat)[/color]" % [
				who, way, _action_name(event.data.action_id, sim).to_lower(), event.data.danger, DIM_COLOUR, roundi(float(event.data.chance) * 100.0)]
		FightEvent.SUBMISSION_ESCAPED:
			return "[b]%s ESCAPES the %s[/b] (danger %d after %d s)" % [who, _action_name(event.data.action_id, sim).to_lower(), event.data.danger, event.data.beats]
		FightEvent.CAGE_CHANGED:
			return "[color=%s]%s %s[/color]" % [DIM_COLOUR, who, CAGE_NAMES.get(event.data.proximity, event.data.proximity)]
		FightEvent.ROCKED:
			if event.data.get("again", false):
				return "[b]%s is ROCKED again underneath![/b]" % who
			return "[b]%s is ROCKED![/b]" % who
		FightEvent.KNOCKDOWN:
			return "[b]%s goes DOWN![/b]" % who
		FightEvent.GOT_UP:
			return "%s beats the count and gets back up" % who
		FightEvent.RECOVERED:
			return "[color=%s]%s has shaken it off[/color]" % [DIM_COLOUR, who]
		FightEvent.CALL_HEARD:
			var extra: String = ""
			if event.data.garbled:
				extra += " · [b]garbled[/b]"
			if event.data.spam:
				extra += " · spam: trust %d" % event.data.trust
			return "%s's corner: [b]%s[/b]  [color=%s](voice %d left · acts in %.1f s%s)[/color]" % [
				who, _call_name(event.data.call_id, sim), DIM_COLOUR, event.data.voice, event.data.delay / float(FightClock.TICKS_PER_SECOND), extra]
		FightEvent.CALL_ANSWERED:
			var outcome: String = CALL_OUTCOMES.get(event.data.outcome, event.data.outcome)
			var id: String = event.data.get("call_id", event.data.get("action_id", ""))
			var move: String = ""
			if event.data.has("call_id") and event.data.has("action_id") and event.data.action_id != id:
				move = ": %s" % _action_name(event.data.action_id, sim)
			var colour: String = FAIL_COLOUR if event.data.outcome == "ignored" else DIM_COLOUR
			return "[color=%s]%s %s the %s call%s (%s)[/color]" % [colour, who, outcome, _call_name(id, sim), move, event.data.reason]
		FightEvent.RULE_ANSWERED:
			var rule_name: String = RuleLibrary.shared().get_rule(event.data.rule_id).name if RuleLibrary.shared().has(event.data.rule_id) else event.data.rule_id
			var colour: String = PASS_COLOUR if event.data.outcome == "fired" else DIM_COLOUR
			var rule_move: String = ": %s" % _action_name(event.data.action_id, sim) if event.data.has("action_id") else ""
			return "[color=%s]%s %s rule \"%s\"%s (%s)[/color]" % [colour, who, RULE_OUTCOMES.get(event.data.outcome, event.data.outcome), rule_name, rule_move, event.data.reason]
		FightEvent.COMMAND_REJECTED:
			return "[color=%s]Command refused for %s: %s[/color]" % [FAIL_COLOUR, who, event.data.reason]
		FightEvent.ROUND_ENDED:
			return "[b]── End of round %d ──[/b]  judges: %s" % [event.round_number, _cards(event.data.get("cards", []))]
		FightEvent.FIGHT_ENDED:
			return "[b]── %s ──[/b]" % result_text(event, sim)
	return "%s %s %s" % [who, event.type, JSON.stringify(event.data)]


## One fighter's condition for the debug console, e.g.
## "Red stamina 41/100 · Boxing 60 → 55 (tired) · Speed 55 → 44 (tired, hurt)".
static func condition_line(f: FighterState) -> String:
	var parts: Array[String] = ["%s stamina %d/%d" % [f.name, roundi(f.stamina), roundi(f.max_stamina())]]
	if f.is_rocked():
		parts.append("ROCKED")
	if f.is_panicking():
		parts.append("PANICKING")
	if f.knockdowns > 0:
		parts.append("knocked down %d×" % f.knockdowns)
	for id in CONDITION_STATS:
		if not f.condition_reasons(id).is_empty() and roundi(f.effective_stat(id)) != f.stat(id):
			parts.append(f.describe_stat(id))
	for leaning in StyleLeanings.LEANINGS:
		if f.style.hint(leaning) != "":
			parts.append(f.style.hint(leaning))
	for trait_id in f.style.traits():
		parts.append(StyleLeanings.TRAIT_NAMES[trait_id])
	return " · ".join(parts)


## How long fighter i spent circling and cutting off the cage (D119), e.g.
## "Kicker circled 7:12 (48% of the fight) · cut off the cage 0:00 (0%)".
static func movement_line(sim: FightSim, i: int) -> String:
	return "%s circled %s · cut off the cage %s" % [_fighter(i, sim), _fight_time(sim.circling_ticks[i], sim.now), _fight_time(sim.cutting_ticks[i], sim.now)]


## Ticks as m:ss of fight time and a share of `total` ticks, e.g. "7:12 (48% of the fight)".
static func _fight_time(ticks: int, total: int) -> String:
	var seconds: int = ticks / FightClock.TICKS_PER_SECOND
	var share: int = roundi(100.0 * ticks / total) if total > 0 else 0
	return "%d:%02d (%d%% of the fight)" % [seconds / 60, seconds % 60, share]


## Why a takedown, clinch or ground move didn't work (FightEvent.GRAPPLE_STOPPED), with
## its odds when it got that far, e.g. "is SPRAWLED ON, stuck with the head low 45% (base 35 · stats +10)".
static func _stopped(event: FightEvent, sim: FightSim) -> String:
	match event.data.reason:
		"defended":
			return "is [b]DEFENDED[/b]%s" % _odds(event)
		"sprawled on":
			return "is [b]SPRAWLED ON[/b], stuck with the head low · the shot was%s" % _odds(event)
		"stopped":
			return "is [b]STOPPED[/b] by the %s" % _action_name(event.data.get("by_action", ""), sim).to_lower()
		"nothing to catch":
			return "finds nothing to catch%s" % _odds(event)
	return "comes up short (%s)" % event.data.reason


## e.g. "Red wins by KO", "Blue wins by split decision (29-28, 28-29, 29-28)", "Draw (...)".
static func result_text(event: FightEvent, sim: FightSim) -> String:
	var result: String = event.data.result
	var how: String = RESULT_NAMES.get(result, result)
	if event.data.get("stopped_by", "") == FightSim.STOPPED_BY_TOWEL:
		how += " (the corner threw in the towel)"
	elif STOP_REASONS.has(event.data.get("why", "")):
		how += " (%s)" % STOP_REASONS[event.data.why]
	elif result == FightSim.RESULT_SUB and event.data.has("why"):
		how += " (%s)" % _action_name(event.data.why, sim).to_lower()
	var cards: String = " (%s)" % _cards(event.data.cards) if event.data.has("cards") else ""
	var winner: int = int(event.data.get("winner", -1))
	if winner < 0:
		return "%s%s" % [how.capitalize(), cards]
	return "%s wins by %s%s" % [_fighter(winner, sim), how, cards]


static func _cards(cards: Array) -> String:
	var out: Array[String] = []
	for c: Array in cards:
		out.append("%d-%d" % [c[0], c[1]])
	return ", ".join(out)


static func _odds(event: FightEvent) -> String:
	if not event.data.has("chance"):
		return ""
	var why: String = ""
	if event.data.has("odds"):
		why = " (%s)" % odds_reasons(event.data.odds)
	return " [color=%s]%d%%%s[/color]" % [DIM_COLOUR, roundi(event.data.chance * 100.0), why]


## Why the odds were what they were (OddsBreakdown.to_dict), e.g.
## "base 50 · stats +7 · counter +10 · ONE_LEG +35 · capped at 95".
static func odds_reasons(odds: Dictionary) -> String:
	var parts: Array[String] = ["base %d" % roundi(odds.base * 100.0), "stats %s" % _signed(odds.stat_gap)]
	for b: Dictionary in odds.bonuses:
		parts.append("%s %s" % [b.name, _signed(b.value)])
	if odds.has("missing"):
		parts.append("needs %s" % odds.missing)
	elif odds.get("clamped", false):
		parts.append("capped at %d" % roundi(odds.chance * 100.0))
	return " · ".join(parts)


static func _signed(fraction: float) -> String:
	var points: int = roundi(fraction * 100.0)
	return "+%d" % points if points >= 0 else "%d" % points


static func _fighter(index: int, sim: FightSim) -> String:
	if index < 0 or index >= sim.fighters.size():
		return "?" if index != FightEvent.NO_ACTOR else ""
	return "[color=%s]%s[/color]" % [FIGHTER_COLOURS[index], sim.fighters[index].name]


static func _position_name(id: String, sim: FightSim) -> String:
	return String(sim.positions.get_position(id).name) if sim.positions.has(id) else id


## " (Red on top)" when someone is on top, "" when both are neutral.
static func _roles(event: FightEvent, sim: FightSim) -> String:
	var roles: Array = event.data.get("roles", [])
	var top: int = roles.find("top")
	return " (%s on top)" % _fighter(top, sim) if top != -1 else ""


## A call's name from data/calls ("Takedown!"), or the move's for a bare call.
static func _call_name(id: String, sim: FightSim) -> String:
	return String(sim.calls.get_call(id).name) if sim.calls.has(id) else _action_name(id, sim)


static func _action_name(id: String, sim: FightSim) -> String:
	return String(sim.actions.get_action(id).name) if sim.actions.has(id) else id
