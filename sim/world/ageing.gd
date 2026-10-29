class_name Ageing
extends RefCounted
## Getting older and how far a fighter can go (docs/02 §3.8, D136): after the physical prime the body slows down
## while skills and Fight IQ can still grow. Kyle agreed (2026-10-29): physical stats start falling at 30, about 1% a
## year, then about 2% a year after 34; Speed, Cardio, Recovery and the Chin go first, Strength and Power later and
## slower (Durability goes with them here). Studies of master athletes find aerobic and anaerobic power fall 7–14% a
## decade. Pure logic: TrainingCamp ages its fighter a week at a time.

const WEEKS_PER_YEAR: float = 52.0

## [stat ids, from this age, % a year, from this age, % a year after]: the share of the stat lost each year.
const DECLINE: Array = [
	[["speed", "cardio", "recovery", "chin"], 30.0, 0.01, 34.0, 0.02],
	[["strength", "power", "durability"], 33.0, 0.005, 36.0, 0.01],
]

## Scouting a hidden potential (Kyle: yes, scouting shows a range): the range shown is this many
## points either side, and it sits off-centre by up to SCOUT_OFFSET so the true value isn't always the middle.
const SCOUT_HALF_WIDTH: float = 7.0
const SCOUT_OFFSET: float = 5.0


## Whether this stat gets older with the body (it's in DECLINE).
static func ages(stat_id: String) -> bool:
	for entry: Array in DECLINE:
		if stat_id in entry[0]:
			return true
	return false


## The share of this stat a fighter of this age loses in a year (0 before the decline starts).
static func yearly_decline(stat_id: String, age_years: float) -> float:
	for entry: Array in DECLINE:
		if stat_id in entry[0]:
			if age_years >= entry[3]:
				return entry[4]
			if age_years >= entry[1]:
				return entry[2]
			return 0.0
	return 0.0


## One week older: each declining stat loses its yearly share / 52 of what it is. Returns the points lost per stat.
static func age_a_week(stats: Dictionary, age_years: float) -> Dictionary:
	var lost: Dictionary = {}
	for entry: Array in DECLINE:
		for id: String in entry[0]:
			var share: float = yearly_decline(id, age_years) / WEEKS_PER_YEAR
			if share > 0.0 and stats.has(id):
				var points: float = float(stats[id]) * share
				stats[id] = float(stats[id]) - points
				lost[id] = points
	return lost


## What scouting says about a hidden potential: [low, high], 14 points wide, with the true value somewhere inside
## (not always the middle). Seeded, so the same fighter always scouts the same.
static func scouted_range(potential: float, scout_seed: int) -> Array[int]:
	var rng := RandomNumberGenerator.new()
	rng.seed = scout_seed
	var centre: float = potential + rng.randf_range(-SCOUT_OFFSET, SCOUT_OFFSET)
	return [clampi(roundi(centre - SCOUT_HALF_WIDTH), 0, 100), clampi(roundi(centre + SCOUT_HALF_WIDTH), 0, 100)]
