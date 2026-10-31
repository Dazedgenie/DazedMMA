class_name Coach
extends RefCounted
## The head coach: you (D15, D63, D71; docs/03 §11.1, D311). A name, a background (data/enums/coach_backgrounds: who
## you were before him, for flavour) and a starting specialty that does something small but real:
##
##   Striking, Wrestling, BJJ  his Striking, Wrestling or Grappling stats learn × GROUP_XP from any session
##   Motivator                 training tires him × MOTIVATOR_FATIGUE, and a party animal skips × MOTIVATOR_SKIPS as often
##   Tactician                 your calls reach him × TACTICIAN_DELAY as slowly (0.6 s → 0.45 s for a fresh fighter)
##
## Pure: TrainingCamp reads the specialty (coach_specialty) for training and puts the call delay in the fight
## profile's `condition` (call_delay), so a fight replays from its profiles the same way.

const STRIKING := "striking"
const WRESTLING := "wrestling"
const BJJ := "bjj"
const MOTIVATOR := "motivator"
const TACTICIAN := "tactician"
## The specialties in the order the new-career screen lists them, each with its name and what it does.
const SPECIALTIES := {
	STRIKING: { "name": "Striking", "does": "His striking stats learn 15% faster." },
	WRESTLING: { "name": "Wrestling", "does": "His wrestling stats learn 15% faster." },
	BJJ: { "name": "BJJ", "does": "His grappling stats learn 15% faster." },
	MOTIVATOR: { "name": "Motivator", "does": "Training tires him 10% less, and he skips half as many sessions." },
	TACTICIAN: { "name": "Tactician", "does": "Your calls reach him a quarter sooner." },
}
## Which attribute group (data/enums/stats) each of the three skill specialties speeds up.
const SPECIALTY_GROUPS := { STRIKING: "Striking", WRESTLING: "Wrestling", BJJ: "Grappling" }
const GROUP_XP: float = 1.15
const MOTIVATOR_FATIGUE: float = 0.9
const MOTIVATOR_SKIPS: float = 0.5
const TACTICIAN_DELAY: float = 0.75

const BACKGROUNDS_PATH := "res://data/enums/coach_backgrounds.json"

static var _backgrounds: Dictionary = {}


static func specialty_ids() -> Array:
	return SPECIALTIES.keys()


static func specialty_name(id: String) -> String:
	return String(SPECIALTIES.get(id, {}).get("name", ""))


static func specialty_does(id: String) -> String:
	return String(SPECIALTIES.get(id, {}).get("does", ""))


## Training XP × this for a stat in this attribute group (1 when the specialty isn't that group's).
static func xp_share(specialty: String, group: String) -> float:
	return GROUP_XP if group != "" and String(SPECIALTY_GROUPS.get(specialty, "")) == group else 1.0


## A session's fatigue × this.
static func fatigue_share(specialty: String) -> float:
	return MOTIVATOR_FATIGUE if specialty == MOTIVATOR else 1.0


## The chance a party animal skips a session × this.
static func skip_share(specialty: String) -> float:
	return MOTIVATOR_SKIPS if specialty == MOTIVATOR else 1.0


## Live calls' delay × this (FighterState.call_delay, from the profile's condition).
static func call_delay(specialty: String) -> float:
	return TACTICIAN_DELAY if specialty == TACTICIAN else 1.0


## The coach backgrounds: id → { name, about }, in the file's order.
static func backgrounds() -> Dictionary:
	if _backgrounds.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(BACKGROUNDS_PATH))
		if data is Dictionary:
			_backgrounds = data.get("values", {})
	return _backgrounds


static func background_name(id: String) -> String:
	return String(backgrounds().get(id, {}).get("name", ""))


static func background_about(id: String) -> String:
	return String(backgrounds().get(id, {}).get("about", ""))
