class_name FightLogFormatter
extends RefCounted
## Turns FightEvents into readable console lines (BBCode) for the debug console.
## Presentation only: reads events and the sim's fighters/actions, never changes them.

const FIGHTER_COLOURS: Array[String] = ["#ff6b6b", "#5fa8ff"]
const PASS_COLOUR := "#6bd66b"
const FAIL_COLOUR := "#ff5555"
const DIM_COLOUR := "#8a8f98"


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


static func _describe(event: FightEvent, sim: FightSim) -> String:
	var who: String = _fighter(event.actor, sim)
	match event.type:
		FightEvent.ACTION_PHASE:
			if event.data.phase == "telegraph":
				return "%s starts a %s" % [who, _action_name(event.data.action_id, sim)]
			return "[color=%s]%s %s → %s[/color]" % [DIM_COLOUR, who, _action_name(event.data.action_id, sim), event.data.phase]
		FightEvent.ACTION_ENDED:
			return "[color=%s]%s %s finished[/color]" % [DIM_COLOUR, who, _action_name(event.data.action_id, sim)]
		FightEvent.STRIKE_LANDED:
			return "%s's %s [b]LANDS[/b] (%s, %d damage)" % [who, _action_name(event.data.action_id, sim), event.data.target, event.data.damage]
		FightEvent.STRIKE_MISSED:
			return "%s's %s misses" % [who, _action_name(event.data.action_id, sim)]
		FightEvent.COMMAND_REJECTED:
			return "[color=%s]Command refused for %s: %s[/color]" % [FAIL_COLOUR, who, event.data.reason]
		FightEvent.ROUND_ENDED:
			return "[b]── End of round %d ──[/b]" % event.round_number
		FightEvent.FIGHT_ENDED:
			return "[b]── Fight over (%s) ──[/b]" % event.data.result
	return "%s %s %s" % [who, event.type, JSON.stringify(event.data)]


static func _fighter(index: int, sim: FightSim) -> String:
	if index < 0 or index >= sim.fighters.size():
		return "?" if index != FightEvent.NO_ACTOR else ""
	return "[color=%s]%s[/color]" % [FIGHTER_COLOURS[index], sim.fighters[index].name]


static func _action_name(id: String, sim: FightSim) -> String:
	return String(sim.actions.get_action(id).name) if sim.actions.has(id) else id
