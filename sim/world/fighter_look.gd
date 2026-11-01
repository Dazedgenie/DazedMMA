class_name FighterLook
extends RefCounted
## Fighters who look different (docs/13, D364): what a fighter looks like, as plain data the fight screen draws. A
## look is { skin, hair, hair_style, beard }:
##   skin        0 to SKIN_TONES.size() - 1, light to dark (SKIN_TONES)
##   hair        a colour in HAIR_COLOURS
##   hair_style  "short" (the body's own hair), "buzzed" or "shaved" (HAIR_STYLES)
##   beard       "none", "stubble" or "beard" (BEARDS)
## The shorts stay his corner's colour (Kyle, 2026-11-01: "Corner colours, as now"), so red against blue always reads.
## Kyle (2026-11-01) picked "You pick for your own fighter": the career's own fighter has the look picked on the
## new-career screen (career@1 `about.look`); everyone else's comes from where he's from (names@1 `looks`: how often
## each skin tone and hair colour turns up in that country), fixed for that man by his id.
##
## A fighter@1 profile may carry `look` (a whole or part look; what's missing is rolled) and `home` (a names@1 country
## id the rest is rolled for). Pure: no nodes; the colours are text ("#rrggbb").

## Skin tones, light to dark: the colour each tone's skin comes out at in the light (sRGB).
const SKIN_TONES: Array[String] = ["#e2ad88", "#d09a73", "#bb8660", "#a06d48", "#805235", "#5f3b25", "#42271a"]
## Hair colours (sRGB).
const HAIR_COLOURS := {
	"black": "#1a1613", "dark_brown": "#38281d", "brown": "#5e412b", "light_brown": "#8a6646",
	"blonde": "#c09a62", "red": "#8c4626", "grey": "#8e8b87",
}
## How often each hair style and beard turns up (anywhere).
const HAIR_STYLES := { "short": 0.45, "buzzed": 0.3, "shaved": 0.25 }
const BEARDS := { "none": 0.45, "stubble": 0.35, "beard": 0.2 }
## How much of the beard's zone darkens toward his hair colour for each beard.
const BEARD_SHADE := { "none": 0.0, "stubble": 0.4, "beard": 0.95 }
## A man this dark (SKIN_TONES index) or darker has black or dark brown hair whatever his country's mix.
const DARK_HAIR_FROM: int = 4
## With no country (a test fighter with no `home`): every tone and hair colour this often.
const ANYWHERE_SKIN: Array[float] = [2.0, 3.0, 2.0, 1.5, 1.5, 1.5, 1.0]
const ANYWHERE_HAIR := { "black": 3.0, "dark_brown": 3.0, "brown": 2.0, "light_brown": 1.0, "blonde": 0.7, "red": 0.3 }


## His look: the profile's own `look`, with anything missing rolled for where he's from (`home`, a names@1 country
## id) on dice fixed by his id (and name), so the same man looks the same in every fight.
static func for_profile(profile: Dictionary, names: NameLibrary = null) -> Dictionary:
	var given: Dictionary = profile.get("look", {}) if profile.get("look") is Dictionary else {}
	var key: String = "%s|%s" % [String(profile.get("id", "")), String(profile.get("name", ""))]
	return roll(hash([key, "look"]), String(profile.get("home", "")), given, names)


## A look rolled on `look_seed` for a man from country `home` ("" for anywhere), keeping whatever `given` has.
static func roll(look_seed: int, home: String, given: Dictionary = {}, names: NameLibrary = null) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = look_seed
	var mix: Dictionary = {}
	if home != "":
		mix = (names if names != null else NameLibrary.shared()).looks(home)
	var skin_weights: Array = mix.get("skin", ANYWHERE_SKIN)
	var out := {}
	out.skin = clampi(int(given.skin), 0, SKIN_TONES.size() - 1) if given.has("skin") else _pick_index(rng, skin_weights)
	var hair_weights: Dictionary = mix.get("hair", ANYWHERE_HAIR)
	if int(out.skin) >= DARK_HAIR_FROM:
		hair_weights = { "black": 4.0, "dark_brown": 1.0 }
	var hair: String = _pick(rng, hair_weights)
	out.hair = String(given.hair) if HAIR_COLOURS.has(String(given.get("hair", ""))) else hair
	var style: String = _pick(rng, HAIR_STYLES)
	out.hair_style = String(given.hair_style) if HAIR_STYLES.has(String(given.get("hair_style", ""))) else style
	var beard: String = _pick(rng, BEARDS)
	out.beard = String(given.beard) if BEARDS.has(String(given.get("beard", ""))) else beard
	return out


## What's wrong with `look` ("" when nothing): every field there and known, or with `part`, the ones it has known and
## nothing else in it.
static func check(look: Dictionary, part: bool = false) -> String:
	for key: Variant in look:
		if not key in ["skin", "hair", "hair_style", "beard"]:
			return "'%s' isn't part of a look" % key
	if (look.has("skin") or not part) and (not (look.get("skin") is float or look.get("skin") is int)
			or int(look.skin) != float(look.skin) or int(look.skin) < 0 or int(look.skin) >= SKIN_TONES.size()):
		return "skin must be a whole number from 0 to %d" % (SKIN_TONES.size() - 1)
	for field: Array in [["hair", HAIR_COLOURS], ["hair_style", HAIR_STYLES], ["beard", BEARDS]]:
		if part and not look.has(field[0]):
			continue
		if not (field[1] as Dictionary).has(String(look.get(field[0], ""))):
			return "%s must be one of %s" % [field[0], ", ".join((field[1] as Dictionary).keys())]
	return ""


static func skin_colour(look: Dictionary) -> Color:
	return Color(SKIN_TONES[clampi(int(look.get("skin", 2)), 0, SKIN_TONES.size() - 1)])


static func hair_colour(look: Dictionary) -> Color:
	return Color(String(HAIR_COLOURS.get(String(look.get("hair", "")), HAIR_COLOURS.dark_brown)))


static func _pick(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var keys: Array = weights.keys()
	keys.sort()
	var total: float = 0.0
	for k: String in keys:
		total += float(weights[k])
	var at: float = rng.randf() * total
	for k: String in keys:
		at -= float(weights[k])
		if at < 0.0:
			return k
	return String(keys[-1])


static func _pick_index(rng: RandomNumberGenerator, weights: Array) -> int:
	var total: float = 0.0
	for w: Variant in weights:
		total += float(w)
	var at: float = rng.randf() * total
	for i in weights.size():
		at -= float(weights[i])
		if at < 0.0:
			return i
	return weights.size() - 1


## The figure as drawn stands this tall (cm); a man is drawn at his height over it (Kyle, 2026-11-01: "True to the
## numbers").
const DRAWN_HEIGHT_CM: float = 180.0
## How much thicker his trunk is drawn for each point of body-mass index (kg / m²) over DRAWN_BMI (thinner under it),
## between GIRTH_RANGE; his arms and legs take LIMB_GIRTH_SHARE of it.
const DRAWN_BMI: float = 25.0
const GIRTH_PER_BMI: float = 0.035
const GIRTH_RANGE: Array[float] = [0.88, 1.25]
const LIMB_GIRTH_SHARE: float = 0.8
## How long his arms are against his height: each arm takes half of his reach over his height (his ape index), on an
## arm (shoulder to wrist) this share of his height.
const ARM_SHARE_OF_HEIGHT: float = 0.33


## How big he's drawn from his frame (docs/09 fighter@1 `frame`): { height (the figure's scale), girth (his trunk's
## thickness), limbs (his arms' and legs' thickness), arm (his arms' length) }, each 1 for the figure as drawn.
static func sizes(profile: Dictionary) -> Dictionary:
	var frame: Dictionary = profile.get("frame", {}) if profile.get("frame") is Dictionary else {}
	var height_cm: float = float(frame.get("height_cm", DRAWN_HEIGHT_CM))
	var reach_cm: float = float(frame.get("reach_cm", height_cm))
	var kg: float = Weight.walk_kg(frame, float(profile.get("age", Weight.GROWN_AT)))
	var bmi: float = kg / pow(height_cm / 100.0, 2.0)
	var girth: float = clampf(1.0 + (bmi - DRAWN_BMI) * GIRTH_PER_BMI, GIRTH_RANGE[0], GIRTH_RANGE[1])
	return {
		"height": height_cm / DRAWN_HEIGHT_CM, "girth": girth, "limbs": 1.0 + (girth - 1.0) * LIMB_GIRTH_SHARE,
		"arm": 1.0 + (reach_cm - height_cm) / 2.0 / (ARM_SHARE_OF_HEIGHT * height_cm),
	}
