extends SceneTree
## Measures final-body limb segments against the other torso in canonical ground/clinch holds.
## This is a capsule diagnostic, not a claim of complete mesh collision detection.
## godot --headless --path . --script res://tools/contact_audit.gd -- --out=res://build/contact-audit.json

var _out: String = "res://build/contact-audit.json"
var _stills: bool = false
var _action: String = ""
var _who: int = 0
var _motion: bool = false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg == "--stills":
			_stills = true
		elif arg.begins_with("--action="):
			_action = arg.trim_prefix("--action=")
		elif arg.begins_with("--who="):
			_who = int(arg.trim_prefix("--who="))
		elif arg == "--motion":
			_motion = true
			_stills = true
	_audit.call_deferred()


func _audit() -> void:
	var actions: ActionLibrary = ActionLibrary.load_dir()
	var roster: FighterLibrary = FighterLibrary.load_dir()
	var report: Array[Dictionary] = []
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out.get_base_dir()))
	var main: Node3D
	if _stills:
		root.size = Vector2i(1280, 720)
		main = load("res://game/main.tscn").instantiate()
		root.add_child(main)
	for where: String in ["full_guard", "half_guard", "side_control", "mount", "back_control", "crucifix", "clinch"]:
		if _action != "" and not actions.get_action(_action).positions.has(where):
			continue
		var sim := FightSim.new(3, roster.make_pair("wrestler", "bjj"), actions)
		var roles: Array[String] = [PositionLibrary.TOP, PositionLibrary.BOTTOM]
		var grips: Array[int] = [FightSim.NO_GRIP, FightSim.NO_GRIP]
		if where == "clinch":
			roles = [PositionLibrary.NEUTRAL, PositionLibrary.NEUTRAL]
			grips = [0, 0]
		sim.situation.set_to(sim.positions.get_position(where), roles)
		sim.set_grips(grips)
		for i in 2:
			sim.fighters[i].clear_action()
			sim.fighters[i].pos = Vector2(-0.4 if i == 0 else 0.4, 0)
		var view: ArenaView
		if _stills:
			main.start_fight({"red": "wrestler", "blue": "bjj", "seed": 3, "sound_volume": 0.0, "easy": true})
			main.set_process(false)
			main.hud.visible = false
			main.hud.set_process(false)
			view = main.arena
		else:
			view = ArenaView.new()
			root.add_child(view)
		view.set_process(false)
		view.watch(FightDriver.new(sim))
		for frame in 60:
			view._process(1.0 / 30.0)
		if _action != "":
			sim.fighters[_who].action_id = _action
			sim.fighters[_who].phase = "active"
			sim.fighters[_who].phase_ticks_left = 1
			for frame in 60:
				view._process(1.0 / 30.0)
		var failures: Array[Dictionary] = []
		for i in 2:
			var body: SkinnedBody = view.figures[i].body
			var trunk: Array[Vector3] = view.figures[1 - i].body.trunk()
			for limb: Array in SkinnedBody.LIMBS:
				for segment in 2:
					var a: Vector3 = body._world_at(limb[segment])
					var b: Vector3 = body._world_at(limb[segment + 1])
					var near: PackedVector3Array = Geometry3D.get_closest_points_between_segments(a, b, trunk[0], trunk[1])
					var clearance: float = near[0].distance_to(near[1])
					if clearance < FighterRig.TRUNK_RADIUS - 0.005:
						failures.append({"fighter": i, "segment": str(limb[segment]) + "-" + str(limb[segment + 1]), "clearance": clearance,
							"root": str(body._world_at(limb[0])), "bend": str(body._world_at(limb[1])), "tip": str(body._world_at(limb[2])), "trunk": str(trunk)})
		report.append({"position": where, "crossings": failures})
		print(where, ": ", failures.size(), " segment crossings")
		if _stills:
			for figure: FighterFigure in view.figures:
				figure.hide_overhead()
			view._tag.visible = false
			var focus: Vector3 = (view.figures[0].body.hips_at() + view.figures[1].body.hips_at()) / 2.0 + Vector3.UP * 0.3
			for side in 2:
				if _motion and side > 0 and _action != "":
					sim.fighters[_who].action_id = _action
					sim.fighters[_who].phase = "active"
					sim.fighters[_who].phase_ticks_left = 1
					for frame in 60:
						view._process(1.0 / 60.0)
					for figure: FighterFigure in view.figures:
						figure.hide_overhead()
					view._tag.visible = false
				view.camera.fov = 42.0
				view.camera.global_position = focus + (Vector3(2.4, 1.7, 2.8) if side == 0 else Vector3(-2.4, 1.7, 2.8))
				view.camera.look_at(focus)
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(_out.get_basename() + "-%s-%d.png" % [where, side])
				if _motion and _action != "":
					await _capture_motion(view, where, side)
		else:
			view.free()
	var file: FileAccess = FileAccess.open(_out, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	quit()


## One-times fight speed, sampled at 20 fps from a 60 Hz view update, including the full return to the hold.
func _capture_motion(view: ArenaView, where: String, side: int) -> void:
	var folder: String = _out.get_basename() + "-%s-%d-motion" % [where, side]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var sim: FightSim = view.driver.sim
	var fighter: FighterState = sim.fighters[_who]
	view.driver.normal_rate = 1.0
	fighter.clear_action()
	view.driver._budget = 0.0
	for frame in 60:
		view._process(1.0 / 60.0)
	var focus: Vector3 = (view.figures[0].body.hips_at() + view.figures[1].body.hips_at()) / 2.0 + Vector3.UP * 0.3
	view.camera.global_position = focus + (Vector3(2.4, 1.7, 2.8) if side == 0 else Vector3(-2.4, 1.7, 2.8))
	view.camera.look_at(focus)
	var camera_pose: Transform3D = view.camera.global_transform
	var index: int = 0
	for phase: String in ["telegraph", "windup", "active", "recovery", "idle"]:
		var ticks: int = 5 if phase == "idle" else sim.phase_ticks(fighter, _action, phase)
		for tick in ticks:
			fighter.action_id = _action
			fighter.phase = phase
			fighter.phase_ticks_left = ticks - tick
			if phase == "idle":
				fighter.clear_action()
			for frame in 6:
				view.driver._budget = float(frame) / 6.0
				view._process(1.0 / 60.0)
				view.camera.global_transform = camera_pose
				view.camera.fov = 42.0
				for figure: FighterFigure in view.figures:
					figure.hide_overhead()
				view._tag.visible = false
				if frame % 3 == 0:
					await process_frame
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_jpg("%s/frame-%03d.jpg" % [folder, index], 0.92)
					index += 1
	view.driver._budget = 0.0
