class_name RuleDrilling
extends RefCounted
## Drilling rules in camp (docs/03 §13.2, D402): the two rules he takes into a career fight (docs/01 §23), picked in the
## camp planner, and how sharp each one is from the Drill rule sessions he did.
##
##   slots     Career.rule_slots: the rule in slot 1 and slot 2 ("" empty). A Drill rule N session drills slot N's rule
##   a drill   each Drill rule session done takes a rule's drilled share most of the way up: 1 − (1 − d) × e^(−reps/SCALE),
##             reps 1 a session (less when he's worn out, as every session). About 6 sessions from nothing takes it to 80%
##   fading    a week he doesn't drill a rule it loses FADE_PER_WEEK points, never below KEEPS of his best with it
##   the fight his two rules go in at their drilled share; a rule whose move he hasn't learned stays out
##
## Every rule he's drilled is remembered (Career.drills: rule id → { drilled 0–100, best, week }), so swapping a slot
## keeps what the old rule had. Pure and seeded: nothing here rolls dice. Every number is a first guess.

## Reps for 1 − 1/e of the way to 100% (about 6 sessions to 80% from nothing).
const SCALE: float = 3.73
## Points a rule loses a week he doesn't drill it, down to KEEPS × his best with it.
const FADE_PER_WEEK: float = 2.0
const KEEPS: float = 0.5
## The session field naming the slot it drills (docs/09 session@1).
const FIELD := "drills_rule"

static var _actions: ActionLibrary


## The slot (1 or 2) a session drills, or 0.
static func slot_of(session: Dictionary) -> int:
	return int(session.get(FIELD, 0))


## How well drilled rule `rule_id` is (0–100).
static func drilled(c: Career, rule_id: String) -> float:
	return float(c.drills.get(rule_id, {}).get("drilled", 0.0))


## Drilled after `reps` more reps from `from` (0–100).
static func after_reps(from: float, reps: float) -> float:
	return 100.0 * (1.0 - (1.0 - clampf(from, 0.0, 100.0) / 100.0) * exp(-maxf(reps, 0.0) / SCALE))


## Drills `rule_id` by `reps` this week. Returns [before, after].
static func drill(c: Career, rule_id: String, reps: float) -> Array[float]:
	var before: float = drilled(c, rule_id)
	var now: float = after_reps(before, reps)
	var entry: Dictionary = c.drills.get(rule_id, {})
	c.drills[rule_id] = { "drilled": now, "best": maxf(now, float(entry.get("best", 0.0))), "week": c.week }
	return [before, now]


## A week's Drill rule sessions (the report's slots done): each drills its slot's rule. Keeps what moved on the report as
## `drilled` (rule id → [before, after]) and returns it. A session for an empty slot drills nothing.
static func drill_week(c: Career, report: Dictionary, library: TrainingLibrary) -> Dictionary:
	var reps: Dictionary = {}
	for slot: Dictionary in report.get("slots", []):
		if String(slot.get("result", "")) != TrainingCamp.DONE:
			continue
		var n: int = slot_of(library.session(String(slot.session)))
		if n < 1 or n > c.rule_slots.size() or String(c.rule_slots[n - 1]) == "":
			continue
		var id: String = c.rule_slots[n - 1]
		reps[id] = float(reps.get(id, 0.0)) + TrainingCamp.fatigue_factor_at(float(slot.get("fatigue_before", 0.0)))
	var moved: Dictionary = {}
	for id: String in reps:
		moved[id] = drill(c, id, reps[id])
	report.drilled = moved
	return moved


## The week turns (Career.end_week): every rule he didn't drill the week that's ending goes a little rusty.
static func fade_week(c: Career) -> void:
	for id: String in c.drills:
		var e: Dictionary = c.drills[id]
		if int(e.get("week", -1)) >= c.week:
			continue
		var floor_at: float = KEEPS * float(e.get("best", 0.0))
		e.drilled = maxf(minf(float(e.drilled), floor_at), float(e.drilled) - FADE_PER_WEEK)


## Every rule (data/rules) he could take into a fight: its move is one he knows. Sorted by name.
static func available(c: Career) -> Array[String]:
	var out: Array[String] = []
	for id: String in RuleLibrary.shared().ids():
		if knows(c, id):
			out.append(id)
	out.sort_custom(func(a: String, b: String) -> bool: return rule_name(a) < rule_name(b))
	return out


## Whether he knows rule `rule_id`'s move (a basic move, or one of his techniques with its technique).
static func knows(c: Career, rule_id: String) -> bool:
	if not RuleLibrary.shared().has(rule_id):
		return false
	if _actions == null:
		_actions = ActionLibrary.load_dir()
	var move: String = String(RuleLibrary.shared().get_rule(rule_id).action)
	if not _actions.has(move):
		return false
	var action: Dictionary = _actions.get_action(move)
	var techniques: Array = c.profile().get("techniques", [])
	var technique: Variant = action.get("requires_technique")
	return (technique == null or technique in techniques) and (bool(action.get("basic", false)) or move in techniques)


## Whether rule `rule_id` answers his habit `tell` (fighter@1 tells, D403): its trigger is his habit's move starting (a
## check for his leg kick), or the same moment his habit goes off on, seen from this side (his jab blocked, when the
## habit is "when his jab is blocked").
static func answers(rule_id: String, tell: Dictionary) -> bool:
	if not RuleLibrary.shared().has(rule_id):
		return false
	var triggers: TriggerLibrary = TriggerLibrary.shared()
	var mine: String = String(RuleLibrary.shared().get_rule(rule_id).trigger)
	var his: String = String(tell.get("trigger", ""))
	if not triggers.has(mine):
		return false
	var t: Dictionary = triggers.get_trigger(mine)
	var m: Dictionary = t.get("match", {})
	if t.get("event", "") == FightEvent.ACTION_PHASE and m.get("actor", "") == "opponent" \
			and (m.get("action_ids", []) as Array).has(String(tell.get("action", ""))):
		return true
	if not triggers.has(his):
		return false
	var h: Dictionary = triggers.get_trigger(his)
	var hm: Dictionary = (h.get("match", {}) as Dictionary).duplicate()
	if h.get("event", "") != t.get("event", "") or not hm.has("actor"):
		return false
	hm.actor = "opponent" if hm.actor == "self" else "self"  # His "self" is my "opponent".
	return hm == m


## The rules he knows that answer any habit of the booked man's you've found (D403), for the Rules box's marks.
static func answers_found(c: Career) -> Array[String]:
	var out: Array[String] = []
	var him: Dictionary = c.booked_opponent()
	var found: Array[String] = Scouting.found(c, String(him.get("id", "")))
	for tell: Variant in him.get("tells", []):
		if not tell is Dictionary or not found.has(Scouting.key(tell)):
			continue
		for id: String in available(c):
			if answers(id, tell) and not out.has(id):
				out.append(id)
	return out


static func rule_name(rule_id: String) -> String:
	return String(RuleLibrary.shared().get_rule(rule_id).name) if RuleLibrary.shared().has(rule_id) else rule_id


## Puts `rule_id` in `slot` (1 or 2; "" empties it). False when he doesn't know it, or the slot's wrong. The same rule
## in the other slot leaves it.
static func set_slot(c: Career, slot: int, rule_id: String) -> bool:
	if slot < 1 or slot > c.rule_slots.size() or (rule_id != "" and not knows(c, rule_id)):
		return false
	for i in c.rule_slots.size():
		if c.rule_slots[i] == rule_id:
			c.rule_slots[i] = ""
	c.rule_slots[slot - 1] = rule_id
	return true


## The fight's rules (main.gd's settings `rules`): [[slot, rule id, drilled 0–100]] for each slot with a rule he knows.
static func fight_rules(c: Career) -> Array:
	var out: Array = []
	for i in c.rule_slots.size():
		var id: String = c.rule_slots[i]
		if id != "" and knows(c, id):
			out.append([i + 1, id, snappedf(drilled(c, id), 0.1)])
	return out


## The planner's Rules box: each slot's rule and how well drilled, then what to do.
static func slots_text(c: Career) -> String:
	var lines: Array[String] = []
	for i in c.rule_slots.size():
		var id: String = c.rule_slots[i]
		if id == "":
			lines.append("Rule %d: none" % (i + 1))
		else:
			lines.append("Rule %d: %s, drilled %d%%" % [i + 1, rule_name(id), roundi(drilled(c, id))])
	var marked: Array[String] = answers_found(c)
	if not marked.is_empty():
		lines.append("Answers his habit: %s." % ", ".join(marked.map(func(id: String) -> String: return rule_name(id))))
	lines.append("A Drill rule session sharpens that slot's rule. Rules go rusty slowly when he stops drilling them.")
	return "\n".join(lines)
