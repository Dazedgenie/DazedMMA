extends GutTest
## The final visible limbs, including a sprawl's extended feet, stay inside every cage panel.

func test_sprawls_and_takedowns_keep_visible_limbs_inside_panels_and_corners() -> void:
	var actions: ActionLibrary = ActionLibrary.load_dir()
	var roster: FighterLibrary = FighterLibrary.load_dir()
	for direction in 16:
		var angle: float = float(direction) * PI / 8.0
		for sprawl: bool in [true, false]:
			var sim := FightSim.new(3, roster.make_pair("wrestler", "judoka"), actions)
			sim.apply_transition(0, "clinch_entry")
			sim.set_grips([0, 1])
			var toward: Vector2 = Vector2.from_angle(angle)
			var closest_normal: float = 0.0
			for normal: Vector2 in Octagon.NORMALS:
				closest_normal = maxf(closest_normal, toward.dot(normal))
			var edge: float = Octagon.APOTHEM / closest_normal
			for i in 2:
				sim.fighters[i].clear_action()
				sim.fighters[i].pos = toward * (edge - (0.85 if i == 0 else 0.4))
			var initial: Array[Vector2] = [sim.fighters[0].pos, sim.fighters[1].pos]
			var view := ArenaView.new()
			add_child(view)
			view.watch(FightDriver.new(sim))
			for frame in 3:
				view._process(1.0)
			var fighter: FighterState = sim.fighters[0]
			fighter.action_id = "double_leg"
			fighter.phase = "active"
			fighter.phase_ticks_left = 1
			view._process(1.0 / 30.0)
			if sprawl:
				view._on_event(FightEvent.new(sim.now, 0, FightEvent.GRAPPLE_STOPPED, 0, {"action_id": "double_leg", "reason": "sprawled on"}))
				fighter.phase = "recovery"
				fighter.phase_ticks_left = 10
			else:
				view._on_event(FightEvent.new(sim.now, 0, FightEvent.GRAPPLE_WON, 0, {"action_id": "double_leg", "result": PositionLibrary.SUCCESS}))
				sim.apply_transition(0, "double_leg", PositionLibrary.SUCCESS)
				view.driver._snap()
			var worst: float = -INF
			var where: String = ""
			for frame in 45:
				view._process(1.0 / 30.0)
				for figure in view.figures:
					for bone: String in ["Head", "LeftHand", "RightHand", "LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase", "LeftForeArm", "RightForeArm", "LeftLeg", "RightLeg"]:
						var at: Vector3 = figure.body._world_at(bone)
						for normal: Vector2 in Octagon.NORMALS:
							var over: float = Vector2(at.x, at.z).dot(normal) - Octagon.APOTHEM
							if over > worst:
								worst = over
								where = "%s frame %d" % [bone, frame]
			assert_lt(worst, -0.025, "%s angle %.2f: %s clears the wire" % ["sprawl" if sprawl else "takedown", angle, where])
			if sprawl:
				assert_eq([sim.fighters[0].pos, sim.fighters[1].pos], initial, "keeping the bodies inside does not move the simulation")
			view.free()
