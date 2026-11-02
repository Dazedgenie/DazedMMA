class_name BodyMarks
extends RefCounted
## What a fight has done to one man's body, for drawing it (D375-D378; docs/13 "Damage on the body"): cuts over his
## eyebrows opened by what hit him (elbows most), the blood trickling from them and onto the other man's gloves, each
## eye swelling as he's hit on that side, his ribs and each leg marked by the damage the fight gives them, and sweat and
## a flush as he tires. Presentation only: it reads the fight and the strikes that land, and never changes either.

## A head strike that lands clean can open a cut over the eye on the side it lands, once his head is hurt this much,
## at this chance by the strike (scaled by how hard it landed and how hurt his head is), one cut a side.
const CUT_FROM_HURT: float = 0.12
const CUT_CHANCE := {
	"elbow": 0.11, "ground_elbow": 0.11,
	"knee": 0.03, "ground_knee": 0.03, "head_kick": 0.03, "soccer_kick": 0.03, "stomp": 0.03,
	"overhand": 0.016, "hook": 0.013, "cross": 0.011, "uppercut": 0.008, "short_hook": 0.013, "short_uppercut": 0.008,
	"posture_bomb": 0.016, "ground_punch": 0.01, "hammerfist": 0.013, "jab": 0.004,
}
## A strike's chance is scaled by its damage over this (as FighterFigure.HIT_FULL_DAMAGE), within these limits.
const CUT_FULL_DAMAGE: float = 18.0
const CUT_SCALE_LIMITS := Vector2(0.5, 1.6)
## The trickle (0 none to 1 its full length): where a fresh cut starts, how much a shot on that side adds, how fast
## it runs on its own (a second), how far it runs on its own (more with a more hurt head), and what's left after the
## cutman works on it between rounds.
const BLEED_START: float = 0.25
const BLEED_PER_HIT: float = 0.12
const BLEED_RATE: float = 0.012
const BLEED_DRIFT_TO := Vector2(0.35, 0.8)
const BLEED_AFTER_CORNER: float = 0.3
## Blood onto the gloves of the man who hits a bleeding cut (0 to 1), a shot.
const GLOVE_BLOOD_PER_HIT: float = 0.18
## Where his head hits land: a hook, an overhand, an elbow or a kick lands on the side it came from; a straight or an
## upright shot puts this share there and the rest on the other side.
const STRAIGHT_SHARE: float = 0.65
const STRAIGHTS: Array[String] = ["jab", "cross", "uppercut", "short_uppercut", "ground_punch", "hammerfist",
	"posture_bomb", "knee", "ground_knee", "soccer_kick", "stomp"]
## An eye swells (0 to 1) as his head is hurt, on the side he's been hit: from this much head damage, full at this.
const SWELL_FROM: float = 0.12
const SWELL_FULL: float = 0.6
## His ribs and each leg are marked by how hurt they are: from, full.
const BODY_MARK := Vector2(0.06, 0.6)
const LEG_MARK := Vector2(0.06, 0.6)
## How tired he looks (0 to 1): his tank below half counts (as FighterState.TIRED_BELOW), empty is 1, followed over
## this many seconds as it comes on and this many as he gets his wind back, so a burst doesn't flash him red.
const STRAIN_FROM: float = 0.5
const STRAIN_RISE_SECONDS: float = 20.0
const STRAIN_FALL_SECONDS: float = 45.0
## Sweat (0 to 1): a little from the work of each minute fought, up to a cap, plus this much at full strain; it comes
## on over this many seconds and dries off over this many.
const SWEAT_PER_MINUTE: float = 0.04
const SWEAT_WORK_MAX: float = 0.35
const SWEAT_TIRED: float = 0.65
const SWEAT_RISE_SECONDS: float = 20.0
const SWEAT_DRY_SECONDS: float = 180.0
## The flush on his face and chest: from this much strain, full at this.
const FLUSH := Vector2(0.15, 0.75)

## [left, right] (his own sides): head damage landed on each, whether a cut is open there, its trickle (0 to 1).
var head_hits: Array[float] = [0.0, 0.0]
var cut: Array[bool] = [false, false]
var bleed: Array[float] = [0.0, 0.0]
## Blood on his gloves from hitting a bleeding man.
var glove_blood: float = 0.0
## Shown on the body: the eyes' swelling, ribs, legs, sweat and flush (all 0 to 1), from update().
var swell: Array[float] = [0.0, 0.0]
var body: float = 0.0
var legs: Array[float] = [0.0, 0.0]
var sweat: float = 0.0
var flush: float = 0.0
## How tired he looks, followed slowly (0 to 1).
var strain: float = 0.0
var _rng := RandomNumberGenerator.new()


## `seed_from` makes the cuts the same every time a fight's seed is watched (his corner mixed in).
func _init(seed_from: int = 0) -> void:
	_rng.seed = hash([seed_from, "body marks"])


## The side of his head (0 left, 1 right) a shot lands on when thrown with the thrower's hand or foot on `thrower_side`
## (0 the thrower's left, 1 his right): facing each other, a left hand lands on the right side of the face.
static func side_hit(thrower_side: int) -> int:
	return 1 - thrower_side


## A strike `action` landed on him on `side` (0 his left, 1 his right) for `damage`, `covered` or clean, with his head
## `head_hurt` (0-1). Returns true when it opened a cut.
func landed(action: String, target: String, damage: float, covered: bool, side: int, head_hurt: float) -> bool:
	if target != "head":
		return false
	var share: float = STRAIGHT_SHARE if action in STRAIGHTS else 1.0
	head_hits[side] += damage * share
	head_hits[1 - side] += damage * (1.0 - share)
	if covered:
		return false
	if cut[side]:
		bleed[side] = minf(1.0, bleed[side] + BLEED_PER_HIT)
		return false
	if head_hurt < CUT_FROM_HURT or not CUT_CHANCE.has(action):
		return false
	var scale: float = clampf(damage / CUT_FULL_DAMAGE, CUT_SCALE_LIMITS.x, CUT_SCALE_LIMITS.y)
	var chance: float = float(CUT_CHANCE[action]) * scale * (0.5 + head_hurt)
	if _rng.randf() >= chance:
		return false
	cut[side] = true
	bleed[side] = maxf(bleed[side], BLEED_START)
	return true


## Whether a shot landing on `side` now would get blood on the gloves that threw it.
func bleeding(side: int) -> bool:
	return cut[side] and bleed[side] > 0.0


## He hit a bleeding cut: some of it on his gloves.
func blooded() -> void:
	glove_blood = minf(1.0, glove_blood + GLOVE_BLOOD_PER_HIT)


## The corner worked on his cuts between rounds.
func cornered() -> void:
	for i in 2:
		bleed[i] *= BLEED_AFTER_CORNER


## Brings the marks up to date with the man `f` after `seconds` of fight time, `minutes` into the fight.
func update(f: FighterState, seconds: float, minutes: float) -> void:
	var head_hurt: float = f.hurt("head")
	var total: float = maxf(head_hits[0] + head_hits[1], 0.001)
	for i in 2:
		var on_side: float = clampf(head_hits[i] / total * 1.6, 0.0, 1.0) if head_hits[0] + head_hits[1] > 0.0 else 0.5
		swell[i] = clampf((head_hurt * on_side - SWELL_FROM) / (SWELL_FULL - SWELL_FROM), 0.0, 1.0)
		if cut[i]:
			var drift: float = lerpf(BLEED_DRIFT_TO.x, BLEED_DRIFT_TO.y, head_hurt)
			if bleed[i] < drift:
				bleed[i] = minf(drift, bleed[i] + BLEED_RATE * seconds)
		legs[i] = _ramp(f.leg_hurt(i), LEG_MARK)
	body = _ramp(f.hurt("body"), BODY_MARK)
	var tired: float = _ramp(1.0 - clampf(f.stamina_fraction(), 0.0, 1.0), Vector2(STRAIN_FROM, 1.0))
	strain = _follow(strain, tired, seconds, STRAIN_RISE_SECONDS, STRAIN_FALL_SECONDS)
	var wet: float = clampf(minf(minutes * SWEAT_PER_MINUTE, SWEAT_WORK_MAX) + strain * SWEAT_TIRED, 0.0, 1.0)
	sweat = _follow(sweat, wet, seconds, SWEAT_RISE_SECONDS, SWEAT_DRY_SECONDS)
	flush = _ramp(strain, FLUSH)


## `now` moved toward `to` over `seconds`, at a pace of `rise` seconds going up and `fall` coming down.
static func _follow(now: float, to: float, seconds: float, rise: float, fall: float) -> float:
	var pace: float = rise if to > now else fall
	return lerpf(now, to, clampf(seconds / pace, 0.0, 1.0))


static func _ramp(value: float, from_to: Vector2) -> float:
	return clampf((value - from_to.x) / (from_to.y - from_to.x), 0.0, 1.0)
