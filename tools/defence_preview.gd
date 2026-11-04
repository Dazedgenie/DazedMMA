extends SceneTree
## Final fight-view defence contacts, from two angles. --out=res://build/defence
var _out := "res://build/defence"
var _motion: bool = false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg == "--motion":
			_motion = true
	_capture.call_deferred()

func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var main = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	for action: String in ["cross", "body_kick", "leg_kick"]:
		main.start_fight({"red": "kicker", "blue": "boxer", "seed": 3, "sound_volume": 0.0, "easy": true})
		main.set_process(false)
		main.hud.visible = false
		main.hud.set_process(false)
		var view: ArenaView = main.arena
		view.set_process(false)
		var sim: FightSim = view.driver.sim
		for fighter in sim.fighters:
			fighter.clear_action()
		for i in 2:
			sim.fighters[i].pos = Vector2(-0.9 if i == 0 else 0.9, 0)
		view.watch(FightDriver.new(sim))
		view.driver.normal_rate = 1.0
		for frame in 60:
			view._process(1.0 / 60.0)
		sim.fighters[0].action_id = action
		sim.fighters[1].action_id = "check_kick" if action == "leg_kick" else "cover_up"
		for fighter in sim.fighters:
			fighter.phase = "active"
			fighter.phase_ticks_left = 1
		view.figures[0].show_outcome(action, "checked" if action == "leg_kick" else "covered")
		for frame in 60:
			view._process(1.0 / 60.0)
		for figure in view.figures:
			figure.hide_overhead()
		view._tag.visible = false
		var focus: Vector3 = (view.figures[0].body.hips_at() + view.figures[1].body.hips_at()) / 2.0 + Vector3.UP * 0.25
		for side in 2:
			if side > 0 and _motion:
				sim.fighters[0].action_id = action
				sim.fighters[1].action_id = "check_kick" if action == "leg_kick" else "cover_up"
				for fighter in sim.fighters:
					fighter.phase = "active"
					fighter.phase_ticks_left = 1
				view.figures[0].show_outcome(action, "checked" if action == "leg_kick" else "covered")
				for frame in 60:
					view._process(1.0 / 60.0)
			view.camera.fov = 40.0
			view.camera.global_position = focus + (Vector3(1.6, 0.8, 3.5) if side == 0 else Vector3(-1.6, 0.8, 3.5))
			view.camera.look_at(focus)
			await process_frame
			await RenderingServer.frame_post_draw
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(_out.path_join("%s-%d.png" % [action, side]))
			if _motion:
				await _capture_motion(view, action, side)
	quit()


func _capture_motion(view: ArenaView, action: String, side: int) -> void:
	var folder: String = _out.path_join("%s-%d-motion" % [action, side])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var camera_pose: Transform3D = view.camera.global_transform
	var sim: FightSim = view.driver.sim
	for fighter in sim.fighters:
		fighter.clear_action()
	for frame in 60:
		view._process(1.0 / 60.0)
	var index: int = 0
	for phase: String in ["telegraph", "windup", "active", "recovery", "idle"]:
		var ticks: int = 8 if phase == "idle" else sim.phase_ticks(sim.fighters[0], action, phase)
		for tick in ticks:
			sim.now += 1
			sim.fighters[0].action_id = action
			sim.fighters[0].phase = phase
			sim.fighters[0].phase_ticks_left = ticks - tick
			sim.fighters[1].action_id = "check_kick" if action == "leg_kick" else "cover_up"
			sim.fighters[1].phase = "recovery" if phase == "recovery" else "active"
			sim.fighters[1].phase_ticks_left = 1
			if phase == "active":
				view.figures[0].show_outcome(action, "checked" if action == "leg_kick" else "covered")
			if phase == "idle":
				for fighter in sim.fighters:
					fighter.clear_action()
			for frame in 6:
				view.driver._budget = float(frame) / 6.0
				view._process(1.0 / 60.0)
				view.camera.global_transform = camera_pose
				view.camera.fov = 40.0
				for figure in view.figures:
					figure.hide_overhead()
				view._tag.visible = false
				if frame % 3 == 0:
					await process_frame
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_jpg(folder.path_join("frame-%03d.jpg" % index), 0.9)
					index += 1
