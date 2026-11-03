extends SceneTree
## Fighter portraits (D430, docs/06 §6.11): the test fighters as the screens outside the fight draw them, full body in
## one row and head and chest in the next, red corner and blue, with the hurt badge on the last two.
## Needs a graphics display:
##   godot --path . --rendering-driver opengl3 --script res://tools/portrait_preview.gd -- --out=res://build/portraits
## --men=boxer,wrestler,... picks the fighters (default: the first six).

var _out := "res://build/portraits"
var _men: Array[String] = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--men="):
			_men.assign(arg.trim_prefix("--men=").split(",", false))
	_review.call_deferred()


func _review() -> void:
	root.size = Vector2i(1920, 1080)
	var roster := FighterLibrary.load_dir()
	if _men.is_empty():
		var ids: Array = roster.ids()
		ids.sort()
		_men.assign(ids.slice(0, 6))
	var page := ColorRect.new()
	page.color = Color("#1b1f26")
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(page)
	var rows := VBoxContainer.new()
	rows.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.add_child(rows)
	for framing: String in [FighterPortrait.FULL, FighterPortrait.BUST]:
		var row := HBoxContainer.new()
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		rows.add_child(row)
		for i in _men.size():
			var portrait := FighterPortrait.new(framing, i % 2, 0.0)
			portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(portrait)
			portrait.show_fighter(roster.profile(_men[i]))
			if i >= _men.size() - 2:
				portrait.set_hurt({ "head": 0.5, "body": 0.2, "legs": 0.7 })
	for frame in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var path: String = _out.path_join("portraits.png")
	var error: Error = root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Portrait preview failed: %s (%s)" % [path, error])
		quit(1)
	print("Portrait preview: ", path)
	quit()
