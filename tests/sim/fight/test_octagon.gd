extends GutTest
## Octagon: the cage as a 2D shape, distance bands and cage proximity (docs/01-fight-engine.md §3).


func test_distance_bands_run_from_out_of_range_to_the_pocket() -> void:
	assert_eq(Octagon.band(3.5), Octagon.BAND_OUT)
	assert_eq(Octagon.band(2.6), Octagon.BAND_LONG)
	assert_eq(Octagon.band(1.85), Octagon.BAND_MID)
	assert_eq(Octagon.band(1.2), Octagon.BAND_POCKET)


func test_the_fence_is_4_5_metres_from_the_centre_on_every_panel() -> void:
	assert_almost_eq(Octagon.distance_to_fence(Vector2.ZERO), 4.5, 0.0001)
	for k in 8:
		assert_almost_eq(Octagon.distance_to_fence(Octagon.normal(k) * 4.0), 0.5, 0.0001)


func test_fighters_are_kept_inside_the_cage() -> void:
	var p: Vector2 = Octagon.keep_inside(Vector2(9.0, 0.0))
	assert_almost_eq(p.x, Octagon.APOTHEM - Octagon.BODY_MARGIN, 0.0001)
	var corner: Vector2 = Octagon.keep_inside(Vector2(7.0, 7.0))
	assert_gte(Octagon.distance_to_fence(corner), Octagon.BODY_MARGIN - 0.0001)


func test_pinned_means_at_the_fence_with_the_opponent_close() -> void:
	var at_fence := Vector2(4.1, 0.0)
	assert_eq(Octagon.proximity(at_fence, 1.2), Octagon.CAGE_PINNED)
	assert_eq(Octagon.proximity(at_fence, 3.0), Octagon.CAGE_NEAR, "nobody pressing")
	assert_eq(Octagon.proximity(Vector2(3.0, 0.0), 1.2), Octagon.CAGE_NEAR)
	assert_eq(Octagon.proximity(Vector2.ZERO, 1.2), Octagon.CAGE_CENTRE)
