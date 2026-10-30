extends GutTest
## Neither corner has an edge built into the engine (D252, docs/01 §2.5): the only difference
## between red and blue is that red steps first each tick. Two fighters on a seed, and the same
## two in the other corners with blue stepping first, are the same fight mirrored through the
## cage's centre (MirrorCheck).
##
## If one of these fails after a change, run tools/mirror_check.gd on it to see the tick the
## fights part. Something that goes by fighter index (0 = red) instead of step order is a corner
## edge; a fighter squeezed into one of the cage's corners can also part them by a hair
## (Octagon.keep_inside pushes off the panels in a fixed order), which is no corner's edge: pick
## another seed then.

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


func _parts_at(red: String, blue: String, fight_seed: int) -> int:
	var usual: FightSim = FightSummary.setup(fight_seed, _roster, _actions, red, blue, 1, 120)
	var swapped: FightSim = FightSummary.setup(fight_seed, _roster, _actions, blue, red, 1, 120)
	swapped.step_order = [1, 0]
	return MirrorCheck.first_difference(usual, swapped)


func test_a_boxer_mirror_plays_the_same_from_either_corner() -> void:
	for fight_seed in [1, 2, 3]:
		assert_eq(_parts_at("boxer", "boxer", fight_seed), -1, "seed %d" % fight_seed)


func test_a_wrestler_mirror_plays_the_same_from_either_corner_through_takedowns() -> void:
	for fight_seed in [1, 3, 7]:
		assert_eq(_parts_at("wrestler", "wrestler", fight_seed), -1, "seed %d" % fight_seed)


func test_a_kicker_against_a_boxer_plays_the_same_from_either_corner() -> void:
	for fight_seed in [2, 3]:
		assert_eq(_parts_at("kicker", "boxer", fight_seed), -1, "seed %d" % fight_seed)


func test_a_grappler_against_a_striker_plays_the_same_from_either_corner() -> void:
	assert_eq(_parts_at("bjj", "kicker", 4), -1)
	assert_eq(_parts_at("judoka", "boxer", 2), -1)


func test_the_mirror_check_spots_fights_that_part() -> void:
	var usual: FightSim = FightSummary.setup(1, _roster, _actions, "boxer", "boxer", 1, 120)
	var other_seed: FightSim = FightSummary.setup(2, _roster, _actions, "boxer", "boxer", 1, 120)
	other_seed.step_order = [1, 0]
	assert_gt(MirrorCheck.first_difference(usual, other_seed), -1, "two different fights")
