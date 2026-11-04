extends SceneTree
## Arranged sprawl/takedown beside the +X fence, using the real scene and final bodies (D422).
## godot --path . --script res://tools/cage_preview.gd -- --out=res://build/cage

var _out: String = "res://build/cage"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	_capture.call_deferred()


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var main: Node3D = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	main.record_dir = ""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	for sprawl: bool in [true, false]:
		main.start_fight({"red": "wrestler", "blue": "judoka", "seed": 35003, "sound_volume": 0.0, "easy": true})
		main.set_process(false)
		main.arena.set_process(false)
		main.hud.visible = false
		var driver: FightDriver = main.driver
		driver.held = true
		var sim: FightSim = driver.sim
		sim.apply_transition(0, "clinch_entry")
		sim.set_grips([0, 1])
		for i in 2:
			sim.fighters[i].clear_action()
			sim.fighters[i].pos = Vector2(3.65 if i == 0 else 4.1, 0.3)
		driver._snap()
		for frame in 24:
			main.arena._process(1.0 / 24.0)
			await process_frame
		var fighter: FighterState = sim.fighters[0]
		fighter.action_id = "double_leg"
		fighter.phase = "active"
		fighter.phase_ticks_left = 1
		main.arena._process(1.0 / 24.0)
		if sprawl:
			main.arena._on_event(FightEvent.new(sim.now, 0, FightEvent.GRAPPLE_STOPPED, 0, {"action_id": "double_leg", "reason": "sprawled on"}))
			fighter.phase = "recovery"
			fighter.phase_ticks_left = 10
		else:
			main.arena._on_event(FightEvent.new(sim.now, 0, FightEvent.GRAPPLE_WON, 0, {"action_id": "double_leg", "result": PositionLibrary.SUCCESS}))
			sim.apply_transition(0, "double_leg", PositionLibrary.SUCCESS)
			driver._snap()
		for frame in 40:
			main.arena._process(1.0 / 24.0)
			await process_frame
			await RenderingServer.frame_post_draw
			if frame in [0, 4, 8, 12, 20, 30, 39]:
				root.get_texture().get_image().save_png("%s/%s-%02d.png" % [_out, "sprawl" if sprawl else "takedown", frame])
	main.queue_free()
	await process_frame
	print("Cage preview saved to ", _out)
	quit()
