class_name FilmStudy
extends RefCounted
## The film study minigame (docs/03 §13.4, D410): a minute of the man's tape, sped up, in which you press Space each time
## you think his habit just went off, then name the habit from three. It plays a Film study session; how well it went is
## the session's quality (TrainingCamp.PLAYED_MIN–PLAYED_MAX), and naming his habit right finds it for sure (in a
## career, Career.scout_week). With no habit of his left to find, or no booked man, the tape is a man of a style and the
## session trains Fight IQ only.
##
## Pure logic and seeded. The tape is a whole fight of his against a stand-in, played here without drawing it; the clip
## is the CLIP_SECONDS stretch of it where his habit goes off most. The screen (ui/film_study_screen.gd) plays the same
## fight from the same seed up to `start` and shows the clip; `press(at)` judges a press at a fight time (ticks).

## The clip: this many seconds of fight time, shown at SPEED (a minute on screen, D38).
const CLIP_SECONDS: float = 180.0
const SPEED: float = 3.0
## A press counts for a fire of his habit from WINDOW_BEFORE seconds before its move starts to WINDOW_AFTER after (fight
## time), ± WINDOW_PER_IQ of it at Fight IQ 100 or 0.
const WINDOW_BEFORE: float = 0.3
const WINDOW_AFTER: float = 1.5
const WINDOW_PER_IQ: float = 0.3
## Each press with no fire of any of his habits near it takes this much off.
const STRAY_COST: float = 0.25
## The score: MARK_SHARE from the marks (fires caught, less strays), the rest from naming the habit right.
const MARK_SHARE: float = 0.6
## Choices to name it from (his habit and two others from the styles' habits).
const CHOICES: int = 3
## A clip needs his habit to go off at least this often; up to TRIES fights are played to find one.
const MIN_FIRES: int = 2
const TRIES: int = 4
## Who he's filmed against: the stand-in that sets his habit off most is picked from these (data/fighters).
const STAND_INS: Array[String] = ["boxer", "kicker", "counter_striker"]

## His profile (fighter@1) and the habit the clip is about (a fighter@1 tell).
var him: Dictionary
var habit: Dictionary
## Whether naming it finds it (a habit of his you haven't found): false for a sample man, or nothing left to find.
var finds: bool
var fight_iq: float
## The fight the tape is: its seed and the stand-in (a data/fighters id), him red.
var fight_seed: int
var stand_in: String
## The clip in fight ticks, and the ticks his habit's move started in it.
var start: int = 0
var end: int = 0
var fires: Array[int] = []
## Every fire of any of his habits in the clip (presses near them aren't strays).
var any_fires: Array[int] = []
## The three habits to name it from (tells), his among them, in a seeded order.
var choices: Array[Dictionary] = []

var _caught: Dictionary = {}  # fire tick → true
var _strays: int = 0
var _named: int = -1


## `profile` is his fighter@1 profile; `target` the habit of his the clip is about ({} = his first); `finds` whether
## naming it finds it.
func _init(profile: Dictionary, target: Dictionary, finds_it: bool, iq: float, tape_seed: int,
		roster: FighterLibrary = null, actions: ActionLibrary = null) -> void:
	him = profile
	finds = finds_it
	fight_iq = iq
	var tells: Array = profile.get("tells", []) if profile.get("tells") is Array else []
	habit = target if not target.is_empty() else (tells[0] if not tells.is_empty() else {})
	if roster == null:
		roster = FighterLibrary.load_dir()
	if actions == null:
		actions = ActionLibrary.load_dir()
	_film(roster, actions, tape_seed)
	_make_choices(tape_seed)


## The man the tape is of when there's no habit of his to find: a man of `style_id` (the booked man's style, or one
## picked by the seed), made by StyleLibrary as the world makes men.
static func sample_man(style_id: String, tape_seed: int, roster: FighterLibrary = null) -> Dictionary:
	var styles: StyleLibrary = StyleLibrary.shared()
	var with_habits: Array = styles.ids().filter(func(id: String) -> bool: return not (styles.get_style(id).get("habits", []) as Array).is_empty())
	with_habits.sort()
	if not styles.has(style_id) or (styles.get_style(style_id).get("habits", []) as Array).is_empty():
		style_id = String(with_habits[posmod(tape_seed, with_habits.size())])
	return styles.generate(style_id, tape_seed, 0, roster if roster != null else FighterLibrary.load_dir(), "", "")


## The clip's length in real seconds on screen.
func length() -> float:
	return float(end - start) / FightClock.TICKS_PER_SECOND / SPEED


## The press window either side of a fire, in ticks: [before, after].
func window() -> Array[int]:
	var iq: float = 1.0 + WINDOW_PER_IQ * (fight_iq - 50.0) / 50.0
	return [roundi(WINDOW_BEFORE * iq * FightClock.TICKS_PER_SECOND), roundi(WINDOW_AFTER * iq * FightClock.TICKS_PER_SECOND)]


## A press at fight tick `at`: {result: "hit" (a fire of his habit caught), "near" (one of his other habits, no cost),
## "stray"}.
func press(at: int) -> Dictionary:
	var w: Array[int] = window()
	for f: int in fires:
		if not _caught.has(f) and at >= f - w[0] and at <= f + w[1]:
			_caught[f] = true
			return { "result": "hit", "fire": f }
	for f: int in any_fires:
		if at >= f - w[0] and at <= f + w[1]:
			return { "result": "near", "fire": f }
	_strays += 1
	return { "result": "stray" }


## Fires of his habit caught so far, and strays.
func caught() -> int:
	return _caught.size()


func strays() -> int:
	return _strays


## Names the habit as choice `index` (0 to CHOICES − 1). True when it's his.
func name_it(index: int) -> bool:
	_named = index
	return named_right()


func named_right() -> bool:
	return _named >= 0 and _named < choices.size() and Scouting.key(choices[_named]) == Scouting.key(habit)


## The marks' part of the score, 0–1: fires caught, less STRAY_COST a stray.
func mark_score() -> float:
	if fires.is_empty():
		return 0.0
	return clampf((float(caught()) - STRAY_COST * _strays) / fires.size(), 0.0, 1.0)


## The whole score, 0–1.
func score() -> float:
	return MARK_SHARE * mark_score() + (1.0 - MARK_SHARE) * (1.0 if named_right() else 0.0)


## The session's quality: TrainingCamp.PLAYED_MIN for nothing up to PLAYED_MAX for every fire caught and the habit named.
func quality() -> float:
	return lerpf(TrainingCamp.PLAYED_MIN, TrainingCamp.PLAYED_MAX, score())


## The habit it found (its key), or "" (named wrong, or nothing to find).
func found_key() -> String:
	return Scouting.key(habit) if finds and named_right() else ""


## Plays his fights without drawing them until one has a clip with his habit in it MIN_FIRES times: tries each
## stand-in in turn on a new seed, and keeps the best.
func _film(roster: FighterLibrary, actions: ActionLibrary, tape_seed: int) -> void:
	var best: Dictionary = {}
	for n in TRIES:
		var who: String = STAND_INS[posmod(tape_seed + n, STAND_INS.size())]
		if not roster.has(who):
			continue
		var s: int = hash([tape_seed, n, "film"])
		var tape: Dictionary = _watch(roster, actions, s, who)
		if best.is_empty() or (tape.fires as Array).size() > (best.fires as Array).size():
			best = tape
		if (best.fires as Array).size() >= MIN_FIRES:
			break
	fight_seed = int(best.get("seed", tape_seed))
	stand_in = String(best.get("stand_in", STAND_INS[0]))
	start = int(best.get("start", 0))
	end = int(best.get("end", roundi(CLIP_SECONDS * FightClock.TICKS_PER_SECOND)))
	fires.assign(best.get("fires", []))
	any_fires.assign(best.get("any", []))


## The fight that the tape is (FightSim with this seed, him red against `who`), as the screen plays it.
func make_sim(roster: FighterLibrary = null, actions: ActionLibrary = null) -> FightSim:
	return _sim(roster if roster != null else FighterLibrary.load_dir(), actions if actions != null else ActionLibrary.load_dir(),
		fight_seed, stand_in)


func _sim(roster: FighterLibrary, actions: ActionLibrary, s: int, who: String) -> FightSim:
	var pair: Array[FighterState] = [FighterState.from_profile(him), roster.make(who)]
	return FightSim.new(s, pair, actions)


## One fight of his: when each of his habits went off, and the clip where `habit` went off most.
func _watch(roster: FighterLibrary, actions: ActionLibrary, s: int, who: String) -> Dictionary:
	var sim: FightSim = _sim(roster, actions, s, who)
	sim.run_to_end()
	var triggers: TriggerLibrary = TriggerLibrary.shared()
	var tells: Array = him.get("tells", []) if him.get("tells") is Array else []
	var waiting: Dictionary = {}  # key → last tick its move can follow by
	var mine: Array[int] = []
	var any: Array[int] = []
	var round_end: Dictionary = {}  # tick a round ended → true
	for e: FightEvent in sim.events:
		if e.type == FightEvent.ROUND_ENDED:
			round_end[e.tick] = true
		for t: Variant in tells:
			if t is Dictionary and triggers.has(String(t.trigger)) and triggers.matches(String(t.trigger), e, 0):
				waiting[Scouting.key(t)] = e.tick + int(t.get("within_ms", 1000)) / FightClock.TICK_MS
		if e.actor != 0 or e.type != FightEvent.ACTION_PHASE or String(e.data.get("phase", "")) != "telegraph" \
				or not String(e.data.get("why", "")).begins_with("tell"):
			continue
		for t: Variant in tells:
			var k: String = Scouting.key(t)
			if waiting.has(k) and String(e.data.get("action_id", "")) == String(t.action) and e.tick <= int(waiting[k]):
				waiting.erase(k)
				any.append(e.tick)
				if k == Scouting.key(habit):
					mine.append(e.tick)
				break
	# The clip: CLIP_SECONDS from a fire of his habit (a little before it), not over a round's end, with the most fires.
	var span: int = roundi(CLIP_SECONDS * FightClock.TICKS_PER_SECOND)
	var lead: int = 5 * FightClock.TICKS_PER_SECOND
	var last: int = sim.now
	var best_start: int = 0
	var best: Array[int] = []
	for f: int in mine:
		var from: int = maxi(0, f - lead)
		var to: int = mini(from + span, last)
		for r: int in round_end:
			if r > from and r < to:
				to = r
		var inside: Array[int] = mine.filter(func(x: int) -> bool: return x >= from and x <= to)
		if inside.size() > best.size():
			best = inside
			best_start = from
	var clip_end: int = mini(best_start + span, last)
	for r: int in round_end:
		if r > best_start and r < clip_end:
			clip_end = r
	return { "seed": s, "stand_in": who, "start": best_start, "end": clip_end, "fires": best,
		"any": any.filter(func(x: int) -> bool: return x >= best_start and x <= clip_end) }


## His habit and two others (from the styles' habits, not his), in a seeded order.
func _make_choices(tape_seed: int) -> void:
	choices = []
	if habit.is_empty():
		return
	var his: Array[String] = []
	for t: Variant in him.get("tells", []):
		if t is Dictionary:
			his.append(Scouting.key(t))
	var pool: Array[Dictionary] = []
	var seen: Dictionary = {}
	var styles: StyleLibrary = StyleLibrary.shared()
	var ids: Array = styles.ids()
	ids.sort()
	for id: String in ids:
		for t: Variant in styles.get_style(id).get("habits", []):
			if t is Dictionary and not his.has(Scouting.key(t)) and not seen.has(Scouting.key(t)):
				seen[Scouting.key(t)] = true
				pool.append(t)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([tape_seed, "choices"])
	choices.append(habit)
	while choices.size() < CHOICES and not pool.is_empty():
		choices.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	for i in range(choices.size() - 1, 0, -1):  # Shuffle.
		var j: int = rng.randi_range(0, i)
		var tmp: Dictionary = choices[i]
		choices[i] = choices[j]
		choices[j] = tmp
