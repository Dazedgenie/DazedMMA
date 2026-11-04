extends SceneTree
## Close views of actual locked submissions, their tightening and their release (animation review).
## godot --path . --script res://tools/hold_preview.gd -- --only=armbar --out=res://build/holds

const CASES := [
	["armbar_guard", "armbar", "full_guard", 1], ["armbar_mount", "armbar", "mount", 0],
	["guillotine", "guillotine", "standing", 0], ["triangle", "triangle", "full_guard", 1],
	["rear_naked_choke", "rear_naked_choke", "back_control", 0],
	["arm_triangle", "arm_triangle", "side_control", 0],
	["ankle_lock", "ankle_lock", "full_guard", 1], ["kneebar", "kneebar", "half_guard", 0],
	["heel_hook", "heel_hook", "full_guard", 1],
]
var _out: String = "res://build/holds"
var _only: String = ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=")
	_capture.call_deferred()


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var main: Node3D = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	main.record_dir = ""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	for case: Array in CASES:
		if _only != "" and not String(case[0]).contains(_only):
			continue
		main.start_fight({"red": "bjj", "blue": "wrestler", "seed": 35003, "sound_volume": 0.0, "easy": true})
		main.set_process(false)
		main.arena.set_process(false)
		main.hud.visible = false
		main.hud.set_process(false)
		var view: ArenaView = main.arena
		var driver: FightDriver = main.driver
		driver.held = true
		var sim: FightSim = driver.sim
		if String(case[2]) != "standing":
			sim.situation.set_to(sim.positions.get_position(case[2]), [PositionLibrary.TOP, PositionLibrary.BOTTOM])
		for i in 2:
			sim.fighters[i].clear_action()
			sim.fighters[i].pos = Vector2(-0.4 if i == 0 else 0.4, 0)
		driver._snap()
		for frame in 30:
			view._process(1.0 / 30.0)
		if not sim._lock_in(int(case[3]), sim.actions.get_action(case[1])):
			push_error("Could not arrange hold: " + String(case[0]))
			continue
		for stage: String in ["loose", "tight", "released"]:
			if stage == "released":
				sim._finish(int(case[3]), FightSim.RESULT_SUB)
			else:
				sim._hold.danger = 20.0 if stage == "loose" else 95.0
			for frame in 120:
				view._process(1.0 / 30.0)
			var focus: Vector3 = (view.figures[0].body.hips_at() + view.figures[1].body.hips_at()) / 2.0 + Vector3.UP * 0.3
			for side in 2:
				view.camera.fov = 42.0
				view.camera.global_position = focus + (Vector3(2.4, 1.7, 2.8) if side == 0 else Vector3(-2.4, 1.7, 2.8))
				view.camera.look_at(focus)
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("%s/%s-%s-%d.png" % [_out, case[0], stage, side])
		print("Hold preview: ", case[0], " ", view._hold_pose.get("built", {}).get("tap", "none"))
	main.queue_free()
	await process_frame
	quit()
