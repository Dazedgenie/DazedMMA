class_name LocalVenue
extends Node3D
## A small, lived-in amateur venue. All decoration is deterministic and presentation-only.
## Static props are batched by mesh/material to keep the crowd affordable on Compatibility.

const RED := Color("#a83c3d")
const BLUE := Color("#37688e")
const HEIGHT: float = 1.9
## The camera-side fence (D281): a panel fades in, see-through, while a fighter is within NEAR_FENCE_WITHIN
## metres of it, up to NEAR_FENCE_ALPHA, over about 1 / NEAR_FENCE_SPEED seconds.
const NEAR_FENCE_WITHIN: float = 1.2
const NEAR_FENCE_ALPHA: float = 0.7
const NEAR_FENCE_SPEED: float = 4.0
## The camera-side panels: {node, material, normal (Vector2, out of the cage), fade}.
var near_panels: Array[Dictionary] = []
var _batches: Dictionary = {}
var _cube := BoxMesh.new()
var _cylinder := CylinderMesh.new()
var _head: ArrayMesh
var _materials: Dictionary = {}


func _ready() -> void:
	_cube.size = Vector3.ONE
	_cylinder.top_radius = 1.0
	_cylinder.bottom_radius = 1.0
	_cylinder.height = 1.0
	_cylinder.radial_segments = 8
	_head = FightMesh.loft([Vector3(-0.13, 0.07, 0.08), Vector3(-0.07, 0.11, 0.1), Vector3(0.08, 0.11, 0.1), Vector3(0.14, 0.06, 0.06)])
	_cage()
	_room()
	_ringside()
	_lighting()
	_flush_batches()


func _mat(hex: String) -> StandardMaterial3D:
	if not _materials.has(hex):
		_materials[hex] = FighterFigure._material(Color(hex))
	return _materials[hex]


func _piece(mesh: Mesh, material: Material, at: Vector3, size: Vector3, angle: float = 0.0) -> void:
	var key: String = "%d/%d" % [mesh.get_instance_id(), material.get_instance_id()]
	if not _batches.has(key):
		_batches[key] = {"mesh": mesh, "material": material, "transforms": []}
	_batches[key].transforms.append(Transform3D(Basis(Vector3.UP, angle).scaled_local(size), at))


func _box(at: Vector3, size: Vector3, hex: String, angle: float = 0.0) -> void:
	_piece(_cube, _mat(hex), at, size, angle)


func _rod(at: Vector3, radius: float, height: float, hex: String) -> void:
	_piece(_cylinder, _mat(hex), at, Vector3(radius, height, radius))


func _flush_batches() -> void:
	for group: Dictionary in _batches.values():
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = group.mesh
		batch.instance_count = group.transforms.size()
		for i in batch.instance_count:
			batch.set_instance_transform(i, group.transforms[i])
		var node := MultiMeshInstance3D.new()
		node.multimesh = batch
		node.material_override = group.material
		add_child(node)
	_batches.clear()


func _cage() -> void:
	var radius: float = Octagon.APOTHEM / cos(PI / 8.0)
	var apron: MeshInstance3D = FightMesh.instance(self, ArenaView._octagon_slab(radius + 0.65, 0.55), _mat("#151c24"), Vector3(0, -0.3, 0))
	apron.rotation.y = PI / 8.0
	var canvas := ShaderMaterial.new()
	canvas.shader = load("res://game/shaders/canvas.gdshader")
	var floor_node: MeshInstance3D = FightMesh.instance(self, ArenaView._octagon_slab(radius, 0.06), canvas, Vector3(0, -0.03, 0))
	floor_node.rotation.y = PI / 8.0
	# Actual octagonal paint, slightly inside the fence.
	for k in 8:
		var a: Vector2 = Vector2.from_angle(PI / 8.0 + k * PI / 4.0) * (radius - 0.38)
		var b: Vector2 = Vector2.from_angle(PI / 8.0 + (k + 1) * PI / 4.0) * (radius - 0.38)
		var middle: Vector2 = (a + b) / 2.0
		_box(Vector3(middle.x, 0.005, middle.y), Vector3(a.distance_to(b), 0.006, 0.055), "#5e6264", -(b - a).angle())
	_canvas_text("CHIN CHECK", Vector3(0, 0.012, -0.35), 0.011, 115, Color("#555a5a"))
	_canvas_text("LOCAL FIGHT SERIES", Vector3(0, 0.013, 0.48), 0.008, 48, Color("#777b79"))
	_canvas_text("LAMPSMOKE", Vector3(-2.65, 0.012, -0.2), 0.006, 52, Color("#626865"), PI / 2.0)
	_canvas_text("FIGHT CLUB", Vector3(2.65, 0.012, -0.2), 0.006, 52, Color("#626865"), -PI / 2.0)
	var mesh_material := ShaderMaterial.new()
	mesh_material.shader = load("res://game/shaders/chain_link.gdshader")
	var camera_side := Vector2(ArenaView.CAMERA_FROM.x, ArenaView.CAMERA_FROM.z).normalized()
	for k in 8:
		var a: Vector2 = Vector2.from_angle(PI / 8.0 + k * PI / 4.0) * radius
		var b: Vector2 = Vector2.from_angle(PI / 8.0 + (k + 1) * PI / 4.0) * radius
		var middle: Vector2 = (a + b) / 2.0
		var angle: float = -(b - a).angle()
		var near_side: bool = middle.normalized().dot(camera_side) > 0.05
		var length: float = a.distance_to(b)
		# Camera-side panels are cut down to an ankle-high rail, keeping fence grappling visible.
		_box(Vector3(middle.x, 0.07, middle.y), Vector3(length, 0.1, 0.09), "#20252c", angle)
		if near_side:
			_near_panel(middle, length, angle)
			continue
		var panel := QuadMesh.new()
		panel.size = Vector2(length, HEIGHT)
		var wire: MeshInstance3D = FightMesh.instance(self, panel, mesh_material, Vector3(middle.x, HEIGHT / 2.0, middle.y))
		wire.rotation.y = angle
		wire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_box(Vector3(middle.x, HEIGHT, middle.y), Vector3(length, 0.13, 0.13), "#20252c", angle)
		var pad_hex: String = "#a83c3d" if k == 3 else ("#37688e" if k == 5 else "#252e39")
		_box(Vector3(a.x, HEIGHT / 2.0, a.y), Vector3(0.22, HEIGHT + 0.12, 0.22), pad_hex, angle)
		var label: Label3D = _sign("CHIN\nCHECK", Vector3(a.x, 1.25, a.y) + Vector3(-a.x, 0, -a.y).normalized() * 0.14, 0.0026, 48, Color("#d6d4ca"))
		label.rotation.y = atan2(-a.x, -a.y)
	# A small stair unit at the visible entrance.
	for step in 3:
		_box(Vector3(4.2 + step * 0.32, -0.48 - step * 0.12, 3.3), Vector3(0.45, 0.14, 1.1), "#343d45")


func _near_panel(middle: Vector2, length: float, angle: float) -> void:
	var material := ShaderMaterial.new()
	material.shader = load("res://game/shaders/chain_link_fade.gdshader")
	material.set_shader_parameter("fade", 0.0)
	var panel := QuadMesh.new()
	panel.size = Vector2(length, HEIGHT)
	var wire: MeshInstance3D = FightMesh.instance(self, panel, material, Vector3(middle.x, HEIGHT / 2.0, middle.y))
	wire.rotation.y = angle
	wire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wire.visible = false
	near_panels.append({ "node": wire, "material": material, "normal": middle.normalized(), "fade": 0.0 })


## Fades in the camera-side fence where a fighter (drawn at `spots`) is against it, and out again (D281).
func show_near_fence(spots: Array[Vector2], delta: float) -> void:
	for panel: Dictionary in near_panels:
		var normal: Vector2 = panel.normal
		var want: float = 0.0
		for p: Vector2 in spots:
			var facing_it: bool = p.length() < 0.5 or p.normalized().dot(normal) > cos(PI / 8.0 + 0.2)
			if facing_it and Octagon.APOTHEM - p.dot(normal) < NEAR_FENCE_WITHIN + Octagon.BODY_MARGIN:
				want = NEAR_FENCE_ALPHA
		panel.fade = move_toward(float(panel.fade), want, delta * NEAR_FENCE_SPEED * NEAR_FENCE_ALPHA)
		(panel.material as ShaderMaterial).set_shader_parameter("fade", panel.fade)
		(panel.node as MeshInstance3D).visible = float(panel.fade) > 0.01


func _room() -> void:
	_box(Vector3(0, -0.72, 0), Vector3(36, 0.2, 32), "#202833")
	_box(Vector3(0, 3.5, -11.5), Vector3(32, 8.5, 0.2), "#28303a")
	_box(Vector3(-12, 3.5, 0), Vector3(0.2, 8.5, 24), "#30343a")
	# Wall seams and painted lower wall give the room scale without texture noise.
	_box(Vector3(0, 0.25, -11.35), Vector3(32, 1.8, 0.1), "#1d242d")
	for x in range(-12, 16, 4):
		_box(Vector3(x, 3.3, -11.2), Vector3(0.22, 8, 0.3), "#171e27")
		_box(Vector3(x, 6.2, -10), Vector3(0.18, 0.22, 2), "#161e27")
	_banner("LOCAL FIGHT NIGHT", Vector3(-2, 3.4, -11.05), Vector2(6.8, 1.35), "#151e29", "#d8d4c6")
	_banner("RIVERTON\nFIGHT GEAR", Vector3(6, 2.8, -11.05), Vector2(3.5, 1.65), "#703435", "#ddd1bb")
	_banner("HARD WORK.\nREAL PEOPLE.", Vector3(-8.3, 2.9, -11.05), Vector2(3.2, 2.0), "#b9b3a4", "#333536")
	# Dim practical fixtures outside the cage.
	for x: float in [-8.0, 0.0, 8.0]:
		_rod(Vector3(x, 5.2, -8.4), 0.02, 2.0, "#171c24")
		_rod(Vector3(x, 4.25, -8.4), 0.32, 0.15, "#171c24")
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(x, 3.9, -8.4)
		lamp.light_color = Color("#f2c18c")
		lamp.light_energy = 1.25
		lamp.omni_range = 4.5
		add_child(lamp)


func _ringside() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 83021
	# Two modest banks of folding chairs. Never touch the simulation's random source.
	for row in 3:
		for seat in 13:
			var at := Vector3(-7.3 + seat * 1.12, -0.61, -6.4 - row * 1.15)
			_chair(at, 0.0)
			if rng.randf() > 0.14:
				_spectator(at, rng)
	for row in 2:
		for seat in 7:
			var at := Vector3(-7.2 - row * 1.1, -0.61, -3.7 + seat * 1.05)
			_chair(at, PI / 2.0)
			if rng.randf() > 0.2:
				_spectator(at, rng, PI / 2.0)
	# Judges' table and score sheets outside the back fence.
	_box(Vector3(0, 0.15, -5.9), Vector3(2.5, 0.1, 0.7), "#4e4640")
	for x: float in [-1.0, 1.0]:
		_box(Vector3(x, -0.2, -5.9), Vector3(0.06, 0.7, 0.06), "#121b24")
	for x: float in [-0.7, 0.5]:
		_box(Vector3(x, 0.21, -5.85), Vector3(0.35, 0.008, 0.26), "#b8b8b0")
		_rod(Vector3(x + 0.35, 0.31, -6.0), 0.035, 0.22, "#668b9c")
	for at: Vector3 in [Vector3(-4.9, -0.55, 0), Vector3(1.2, -0.55, -5.3)]:
		_rod(at + Vector3(0, 0.46, 0), 0.23, 0.09, "#4c5660")
		for dx: float in [-0.13, 0.13]:
			for dz: float in [-0.13, 0.13]:
				_box(at + Vector3(dx, 0.2, dz), Vector3(0.035, 0.45, 0.035), "#242c36")
		_rod(at + Vector3(0.5, 0.17, 0.2), 0.17, 0.34, "#68717a")
		_box(at + Vector3(0, 0.53, 0), Vector3(0.34, 0.045, 0.24), "#b4b6b0")


func _chair(at: Vector3, angle: float) -> void:
	var basis := Basis(Vector3.UP, angle)
	_box(at + Vector3(0, 0.43, 0), Vector3(0.48, 0.06, 0.44), "#353f4a", angle)
	_box(at + basis * Vector3(0, 0.72, -0.2), Vector3(0.48, 0.32, 0.045), "#353f4a", angle)
	for x: float in [-0.19, 0.19]:
		for z: float in [-0.16, 0.16]:
			_box(at + basis * Vector3(x, 0.21, z), Vector3(0.025, 0.42, 0.025), "#49525a", angle)


func _spectator(at: Vector3, rng: RandomNumberGenerator, angle: float = 0.0) -> void:
	var basis := Basis(Vector3.UP, angle)
	var shirt: String = ["#3e4b58", "#51433c", "#27313b", "#6c6a61", "#50353c"][rng.randi_range(0, 4)]
	var skin: String = ["#b18467", "#855b43", "#614535", "#c19a7b"][rng.randi_range(0, 3)]
	_box(at + Vector3(0, 0.78, 0), Vector3(0.38, 0.53, 0.24), shirt, angle)
	_piece(_head, _mat(skin), at + basis * Vector3(0, 1.18, 0.015), Vector3.ONE, angle)
	for side: float in [-1.0, 1.0]:
		_box(at + basis * Vector3(side * 0.13, 0.45, 0.17), Vector3(0.16, 0.19, 0.4), "#252c34", angle)
		_box(at + basis * Vector3(side * 0.13, 0.23, 0.32), Vector3(0.13, 0.4, 0.15), "#252c34", angle)
		_box(at + basis * Vector3(side * 0.22, 0.71, 0.12), Vector3(0.12, 0.27, 0.14), shirt, angle)


func _sign(text: String, at: Vector3, pixel: float, font_size: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = DisplayFont.font()
	label.font_size = font_size
	label.pixel_size = pixel
	label.modulate = color
	label.outline_size = 0
	label.no_depth_test = false
	label.shaded = true
	label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	label.position = at
	add_child(label)
	return label


func _canvas_text(text: String, at: Vector3, pixel: float, font_size: int, color: Color, turn: float = 0.0) -> void:
	var label: Label3D = _sign(text, at, pixel, font_size, color)
	label.rotation = Vector3(-PI / 2.0, turn + PI / 4.0, 0)


func _banner(text: String, at: Vector3, size: Vector2, background: String, ink: String) -> void:
	_box(at, Vector3(size.x, size.y, 0.04), background)
	_sign(text, at + Vector3(0, 0, 0.035), 0.009, 64, Color(ink))


func _lighting() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#101720")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9aaec8")
	env.ambient_light_energy = 0.36
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)
	# One shadowed key: readable feet and broad low-poly planes without expensive screen effects.
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-62, -30, 0)
	key.light_color = Color("#fff0db")
	key.light_energy = 0.8
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 35
	add_child(key)
	for x: float in [-3.8, 3.8]:
		var light := SpotLight3D.new()
		light.position = Vector3(x, 6.0, -1.5)
		add_child(light)
		light.look_at(Vector3(x * 0.25, 0, 0))
		light.light_color = Color("#e0eaff")
		light.light_energy = 0.9
		light.spot_range = 11
		light.spot_angle = 43
		_box(Vector3(x, 6.15, -1.5), Vector3(0.85, 0.12, 0.4), "#151b24")
