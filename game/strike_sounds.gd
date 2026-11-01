class_name StrikeSounds
extends Node
## The fight's strike sounds (D190, docs/06 §6.8): every strike has one sound of its own in three
## versions, connected, missed and blocked, made in code from three layers (no audio files):
## - the swish: the limb moving through the air (a sweep of filtered noise; kicks are longer and lower);
## - the thump: the weight landing (a low sine that drops in pitch; deeper for kicks and knees);
## - the snap: the skin and the glove (a short burst of bright noise; sharpest for elbows and leg kicks).
## All three versions use the same swish and the same thump pitch, so a jab always sounds like a jab:
## connected is all three layers; missed is a longer, louder swish on its own; blocked is the swish
## with the thump and snap muffled (on the guard, the forearms or a checked shin).
##
## What counts as which (from the fight's events, outcome_for): a landed strike is connected, unless it
## landed through a fighter covering up (covered, D180), which is blocked; a checked kick is blocked; a
## slipped punch is missed (a slip is a whoosh past his head, SLIP_OUTCOME); any other miss is missed.
## A landed shot gets louder and deeper the more damage it does (play_settings), and every sound plays
## at a slightly random pitch so repeats don't sound the same.
##
## To change a strike's sound, edit its line in RECIPES (the keys are explained there); new strikes need a
## line too (tests/game/test_strike_sounds.gd checks every strike in data/actions/ has one). How loud the
## versions are against each other: OUTCOME_DB; how much damage changes a hit: LIGHT_DAMAGE/HEAVY_DAMAGE.

## A sound was played (or would have been, when muted or at volume 0: `heard` is false then).
signal played(action_id: String, outcome: String, heard: bool)

const CONNECTED := "connected"
const MISSED := "missed"
const BLOCKED := "blocked"
const OUTCOMES: Array[String] = [CONNECTED, MISSED, BLOCKED]

## How a slipped punch sounds (D190: Kyle's pick on the slip card).
const SLIP_OUTCOME := MISSED

const RATE: int = 22050
## Each sound's length in seconds (the tail fades to silence well before).
const SECONDS: float = 0.5
## Sounds playing at once before the oldest is cut off.
const VOICES: int = 8

## Every strike's sound. Keys:
## - thump: the pitch of the landing in Hz (lower = heavier: punches 95–150, kicks and knees 55–95);
## - decay: how long the thump rings in seconds (longer = meatier);
## - snap: how loud the slap/crack is (0–1); bright: how sharp it is (0 dull thud, 1 crack);
## - swish: how long the limb's whoosh is in seconds (longer for wide or long strikes);
## - tone: how high the whoosh sits (0 low and heavy, 1 thin and fast);
## - gain: the whole sound's loudness (1 = normal).
const RECIPES := {
	"jab": { "thump": 150.0, "decay": 0.05, "snap": 0.75, "bright": 0.80, "swish": 0.12, "tone": 0.85, "gain": 0.80 },
	"cross": { "thump": 125.0, "decay": 0.07, "snap": 0.85, "bright": 0.70, "swish": 0.16, "tone": 0.70, "gain": 0.95 },
	"hook": { "thump": 115.0, "decay": 0.08, "snap": 0.85, "bright": 0.60, "swish": 0.20, "tone": 0.55, "gain": 1.00 },
	"uppercut": { "thump": 120.0, "decay": 0.07, "snap": 0.75, "bright": 0.65, "swish": 0.18, "tone": 0.75, "gain": 0.95 },
	"overhand": { "thump": 100.0, "decay": 0.10, "snap": 0.90, "bright": 0.55, "swish": 0.24, "tone": 0.50, "gain": 1.05 },
	"body_hook": { "thump": 80.0, "decay": 0.11, "snap": 0.40, "bright": 0.30, "swish": 0.20, "tone": 0.50, "gain": 1.00 },
	"short_hook": { "thump": 125.0, "decay": 0.06, "snap": 0.70, "bright": 0.60, "swish": 0.10, "tone": 0.60, "gain": 0.85 },
	"short_uppercut": { "thump": 130.0, "decay": 0.06, "snap": 0.70, "bright": 0.65, "swish": 0.10, "tone": 0.70, "gain": 0.85 },
	"ground_punch": { "thump": 105.0, "decay": 0.07, "snap": 0.55, "bright": 0.50, "swish": 0.10, "tone": 0.55, "gain": 0.85 },
	"elbow": { "thump": 140.0, "decay": 0.05, "snap": 1.00, "bright": 0.95, "swish": 0.14, "tone": 0.85, "gain": 1.00 },
	"hammerfist": { "thump": 95.0, "decay": 0.08, "snap": 0.35, "bright": 0.25, "swish": 0.08, "tone": 0.50, "gain": 0.80 },
	"ground_body_punch": { "thump": 78.0, "decay": 0.11, "snap": 0.40, "bright": 0.30, "swish": 0.10, "tone": 0.50, "gain": 0.95 },
	"posture_bomb": { "thump": 92.0, "decay": 0.12, "snap": 0.90, "bright": 0.55, "swish": 0.28, "tone": 0.40, "gain": 1.15 },
	"ground_elbow": { "thump": 130.0, "decay": 0.05, "snap": 0.95, "bright": 0.90, "swish": 0.12, "tone": 0.80, "gain": 0.95 },
	"knee": { "thump": 70.0, "decay": 0.10, "snap": 0.45, "bright": 0.35, "swish": 0.18, "tone": 0.45, "gain": 1.05 },
	"ground_knee": { "thump": 75.0, "decay": 0.10, "snap": 0.50, "bright": 0.40, "swish": 0.16, "tone": 0.45, "gain": 1.05 },
	"teep": { "thump": 65.0, "decay": 0.12, "snap": 0.35, "bright": 0.25, "swish": 0.20, "tone": 0.40, "gain": 0.90 },
	"leg_kick": { "thump": 85.0, "decay": 0.09, "snap": 1.00, "bright": 0.75, "swish": 0.30, "tone": 0.35, "gain": 1.05 },
	"calf_kick": { "thump": 95.0, "decay": 0.07, "snap": 0.90, "bright": 0.80, "swish": 0.26, "tone": 0.40, "gain": 0.95 },
	"body_kick": { "thump": 65.0, "decay": 0.12, "snap": 0.90, "bright": 0.55, "swish": 0.32, "tone": 0.30, "gain": 1.10 },
	"head_kick": { "thump": 80.0, "decay": 0.11, "snap": 1.00, "bright": 0.70, "swish": 0.36, "tone": 0.30, "gain": 1.15 },
	"soccer_kick": { "thump": 70.0, "decay": 0.10, "snap": 0.75, "bright": 0.50, "swish": 0.30, "tone": 0.30, "gain": 1.10 },
	"stomp": { "thump": 55.0, "decay": 0.14, "snap": 0.40, "bright": 0.30, "swish": 0.20, "tone": 0.25, "gain": 1.05 },
	"up_kick": { "thump": 72.0, "decay": 0.11, "snap": 0.70, "bright": 0.45, "swish": 0.26, "tone": 0.30, "gain": 1.00 },
}

## Each version's loudness against connected, in dB.
const OUTCOME_DB := { CONNECTED: 0.0, MISSED: -4.0, BLOCKED: -3.0 }
## A landed shot's damage that sounds lightest and heaviest (dealt damage, not the strike's base damage).
const LIGHT_DAMAGE: float = 2.0
const HEAVY_DAMAGE: float = 14.0
## How much quieter (dB) and higher (pitch scale) the lightest shot is than the heaviest.
const LIGHT_DB: float = -7.0
const LIGHT_PITCH: float = 1.08
const HEAVY_PITCH: float = 0.92
## Random pitch on every sound, ± this share.
const PITCH_JITTER: float = 0.04
## Overall loudness, in dB (the setup's Sound slider sets the bus, this sets the mix under it).
const BASE_DB: float = -6.0

## The player's volume, 0–1 (the setup's Sound slider, D190). 0 is silent.
var volume: float = 1.0
## Muted with M during a fight.
var muted: bool = false

## Made once for the whole game (shared by every StrikeSounds): action id -> { outcome: AudioStreamWAV }.
static var _sounds := {}
static var _build_task: int = -1
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _sim: FightSim
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


func _exit_tree() -> void:
	_finish_build()


## Starts playing a fight's strike sounds (null stops).
func watch(sim: FightSim) -> void:
	if _sim != null and _sim.event_emitted.is_connected(_on_event):
		_sim.event_emitted.disconnect(_on_event)
	_sim = sim
	if _sim != null:
		_sim.event_emitted.connect(_on_event)


## Makes every strike's three versions on another thread (about half a second, done once when the game
## opens), so the setup screen doesn't wait for it. A sound asked for before they're ready waits for them.
static func build_in_background() -> void:
	if _sounds.is_empty() and _build_task < 0:
		_build_task = WorkerThreadPool.add_task(_build_into.bind(_sounds), false, "Strike sounds")


## Makes every strike's three versions now.
static func build_all() -> void:
	_finish_build()
	if _sounds.is_empty():
		_build_into(_sounds)


static func _build_into(into: Dictionary) -> void:
	for id: String in RECIPES:
		var versions := {}
		for outcome in OUTCOMES:
			versions[outcome] = to_wav(render(RECIPES[id], outcome, id.hash()))
		into[id] = versions


static func _finish_build() -> void:
	if _build_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_build_task)
		_build_task = -1


## The stream for a strike's version (builds them if needed). Null for a strike with no recipe.
static func stream(action_id: String, outcome: String) -> AudioStreamWAV:
	build_all()
	return _sounds.get(action_id, {}).get(outcome)


## Plays a strike's version. `damage` < 0: not a landed shot (no loudness from damage).
func play(action_id: String, outcome: String, damage: int = -1) -> void:
	var wav: AudioStreamWAV = stream(action_id, outcome)
	if wav == null:
		return
	var heard: bool = not muted and volume > 0.0
	played.emit(action_id, outcome, heard)
	if not heard:
		return
	var how: Dictionary = play_settings(action_id, outcome, damage)
	var player: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = wav
	player.volume_db = how.db + linear_to_db(volume)
	player.pitch_scale = how.pitch * (1.0 + _rng.randf_range(-PITCH_JITTER, PITCH_JITTER))
	if player.is_inside_tree():
		player.play()


func _on_event(event: FightEvent) -> void:
	var outcome: String = outcome_for(event)
	if outcome != "":
		play(String(event.data.action_id), outcome, int(event.data.get("damage", -1)) if outcome == CONNECTED else -1)


## Which version a fight event plays ("" = none): see the class notes.
static func outcome_for(event: FightEvent) -> String:
	if not RECIPES.has(String(event.data.get("action_id", ""))):
		return ""
	match event.type:
		FightEvent.STRIKE_LANDED:
			return BLOCKED if bool(event.data.get("covered", false)) else CONNECTED
		FightEvent.STRIKE_MISSED:
			if event.data.get("reason", "") == "defended":
				return SLIP_OUTCOME if event.data.get("by_action", "") == "slip" else BLOCKED
			return MISSED
	return ""


## How loud (dB) and at what pitch a version plays, before the random jitter and the player's volume.
static func play_settings(action_id: String, outcome: String, damage: int = -1) -> Dictionary:
	var db: float = BASE_DB + float(OUTCOME_DB[outcome]) + linear_to_db(float(RECIPES[action_id].gain))
	var pitch: float = 1.0
	if outcome == CONNECTED and damage >= 0:
		var heavy: float = clampf(inverse_lerp(LIGHT_DAMAGE, HEAVY_DAMAGE, float(damage)), 0.0, 1.0)
		db += lerpf(LIGHT_DB, 0.0, heavy)
		pitch = lerpf(LIGHT_PITCH, HEAVY_PITCH, heavy)
	return { "db": db, "pitch": pitch }


## One version of a strike's sound as samples (-1–1) at RATE. The same recipe and seed give the same sound.
static func render(recipe: Dictionary, outcome: String, sound_seed: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = sound_seed
	var count: int = int(RATE * SECONDS)
	var out := PackedFloat32Array()
	out.resize(count)
	var dt: float = 1.0 / RATE

	# The swish: noise through a band that rises and falls with the limb's speed. Connected and blocked
	# cut it short at the impact (it starts just before, so the hit lands a few hundredths in); a miss
	# lets it run its whole length and a little louder, as the limb carries on past.
	var swish_len: float = float(recipe.swish)
	var tone: float = float(recipe.tone)
	var hit_at: float = 0.035  # Where the impact sits in a connected or blocked sound.
	var swish_peak: float = hit_at if outcome != MISSED else swish_len * 0.45
	var swish_end: float = hit_at + 0.03 if outcome != MISSED else swish_len * 1.4
	var swish_gain: float = 0.35 if outcome != MISSED else 0.75
	var low_hz: float = lerpf(250.0, 1400.0, tone)
	var high_hz: float = lerpf(900.0, 4200.0, tone)
	var lp_a: float = 0.0
	var lp_b: float = 0.0
	var lp_slow: float = 0.0
	# The thump and snap.
	var thump_hz: float = float(recipe.thump)
	var decay: float = float(recipe.decay)
	var snap: float = float(recipe.snap)
	var bright: float = float(recipe.bright)
	var thump_gain: float = 1.0
	var snap_gain: float = 0.6 * snap
	var muffle: float = 0.0  # 0 = open, 1 = everything above a low rumble cut away.
	if outcome == BLOCKED:
		thump_gain = 0.55
		snap_gain = 0.35 * snap
		muffle = 0.75
		decay *= 0.7
	elif outcome == MISSED:
		thump_gain = 0.0
		snap_gain = 0.0
	var snap_decay: float = lerpf(0.035, 0.012, bright)
	var snap_lp: float = 0.0
	var snap_cut: float = 1.0 - exp(-TAU * lerpf(lerpf(900.0, 5000.0, bright), 500.0, muffle) * dt)
	var phase: float = 0.0
	var out_lp: float = 0.0
	var out_cut: float = 1.0 - exp(-TAU * lerpf(9000.0, 1600.0, muffle) * dt)
	var peak: float = 0.0
	for n in count:
		var t: float = n * dt
		var sample: float = 0.0
		# Swish.
		if t < swish_end:
			var env: float = t / swish_peak if t < swish_peak else 1.0 - (t - swish_peak) / (swish_end - swish_peak)
			env = env * env
			var centre: float = lerpf(low_hz, high_hz, env)
			var cut: float = 1.0 - exp(-TAU * centre * 1.4 * dt)
			lp_a += cut * (rng.randf_range(-1.0, 1.0) - lp_a)
			lp_b += cut * (lp_a - lp_b)
			lp_slow += (1.0 - exp(-TAU * centre * 0.5 * dt)) * (lp_b - lp_slow)
			sample += (lp_b - lp_slow) * env * swish_gain * 3.0
		# Thump and snap, from the impact on.
		if thump_gain > 0.0 and t >= hit_at:
			var since: float = t - hit_at
			var hz: float = thump_hz * (1.0 + 1.2 * exp(-since / 0.012))
			phase += TAU * hz * dt
			sample += sin(phase) * exp(-since / decay) * thump_gain * minf(1.0, since / 0.002)
			snap_lp += snap_cut * (rng.randf_range(-1.0, 1.0) - snap_lp)
			sample += snap_lp * exp(-since / snap_decay) * snap_gain * (1.5 + bright)
		out_lp += out_cut * (sample - out_lp)
		out[n] = out_lp
		peak = maxf(peak, absf(out_lp))
	# Every sound is scaled to the same peak; loudness comes from play_settings.
	if peak > 0.0:
		var scale: float = 0.9 / peak
		for n in count:
			out[n] *= scale
	return out


static func to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for n in samples.size():
		data.encode_s16(n * 2, int(clampf(samples[n], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	return wav
