class_name FighterSculpt
extends RefCounted
## Authored low-poly contours for the temporary fighters (docs/13, character refinement).
## Meshes are built once. Animation and all fight rules remain in their existing layers.

## Rings: height, half width, front depth, back depth. Front is -Z.
static func contour(profile: Array[Vector4], sides: int = 12, offsets: Array[Vector2] = [], deform: Callable = Callable()) -> ArrayMesh:
	var rings: Array[PackedVector3Array] = []
	for r in profile.size():
		var ring := PackedVector3Array()
		var p: Vector4 = profile[r]
		for n in sides:
			var angle: float = TAU * n / sides
			var depth: float = p.z if cos(angle) >= 0.0 else p.w
			var point := Vector3(sin(angle) * p.y, p.x, -cos(angle) * depth)
			if not offsets.is_empty():
				point += Vector3(offsets[r].x, 0, offsets[r].y)
			if deform.is_valid():
				point = deform.call(point)
			ring.append(point)
		rings.append(ring)
	if profile[0].x > profile[-1].x:
		rings.reverse()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in range(rings.size() - 1):
		for n in sides:
			var next: int = (n + 1) % sides
			var a: Vector3 = rings[r][n]
			var b: Vector3 = rings[r][next]
			var c: Vector3 = rings[r + 1][n]
			var d: Vector3 = rings[r + 1][next]
			if (r + n) % 2 == 0:
				FightMesh._triangle(surface, a, c, b)
				FightMesh._triangle(surface, b, c, d)
			else:
				FightMesh._triangle(surface, a, c, d)
				FightMesh._triangle(surface, a, d, b)
	for end in 2:
		var ring: PackedVector3Array = rings[0 if end == 0 else -1]
		var center := Vector3.ZERO
		for point in ring:
			center += point / sides
		for n in sides:
			var next: int = (n + 1) % sides
			FightMesh._triangle(surface, center, ring[n if end == 0 else next], ring[next if end == 0 else n])
	return surface.commit()


static func torso(stocky: bool) -> ArrayMesh:
	var profile: Array[Vector4] = [
		Vector4(-0.31, 0.17, 0.105, 0.10), Vector4(-0.23, 0.165, 0.115, 0.115),
		Vector4(-0.15, 0.17, 0.127, 0.12), Vector4(-0.07, 0.19, 0.14, 0.13),
		Vector4(0.015, 0.235, 0.147, 0.145), Vector4(0.09, 0.265, 0.177, 0.155),
		Vector4(0.17, 0.282, 0.175, 0.15), Vector4(0.235, 0.275, 0.14, 0.135),
		Vector4(0.285, 0.17, 0.103, 0.11), Vector4(0.335, 0.086, 0.077, 0.085)
	]
	return contour(profile, 16, [], func(p: Vector3) -> Vector3:
		# Sternum, pectoral lobes and the abdominal midline are in the surface, not stuck-on blocks.
		if p.z < 0:
			var front: float = clampf(-p.z / 0.12, 0, 1)
			var pec: float = exp(-pow((absf(p.x) - 0.125) / 0.085, 2.0) - pow((p.y - 0.13) / 0.085, 2.0))
			var midline: float = exp(-pow(p.x / 0.028, 2.0))
			p.z -= front * (pec * 0.027 - midline * 0.009)
			if p.y < 0.015 and p.y > -0.24:
				p.z -= front * 0.009 * sin((p.y + 0.24) * 42.0)
		else:
			p.z += 0.014 * exp(-pow((absf(p.x) - 0.1) / 0.07, 2.0))
		p.x *= 1.08 if stocky else 0.98
		p.z *= 1.10 if stocky else 1.0
		return p)


static func head(stocky: bool) -> ArrayMesh:
	return contour([
		Vector4(-0.15, 0.053, 0.085, 0.06), Vector4(-0.115, 0.091, 0.112, 0.085),
		Vector4(-0.065, 0.111, 0.124, 0.113), Vector4(-0.015, 0.128, 0.129, 0.132),
		Vector4(0.035, 0.123, 0.116, 0.136), Vector4(0.075, 0.125, 0.128, 0.132),
		Vector4(0.125, 0.114, 0.122, 0.118), Vector4(0.17, 0.088, 0.091, 0.09),
		Vector4(0.19, 0.035, 0.039, 0.04)
	], 16, [], func(p: Vector3) -> Vector3:
		if stocky and p.y < 0.02:
			p.x *= 1.09  # A squarer jaw on the heavier frame.
		return p)


static func hair(cropped: bool) -> ArrayMesh:
	return contour([
		Vector4(0.065, 0.127, 0.132, 0.139), Vector4(0.13, 0.122, 0.127, 0.124),
		Vector4(0.177, 0.092, 0.096, 0.096), Vector4(0.205, 0.038, 0.04, 0.045)
	], 16, [], func(p: Vector3) -> Vector3:
		if p.y < 0.07:
			p.y += 0.035 if p.z < -0.08 else (-0.08 if p.z > 0.04 else -0.025)
		elif not cropped:
			# A swept, asymmetric top; keeps broad designed planes rather than noisy spikes.
			p.y += 0.035 * clampf((0.12 - p.z) / 0.2, 0, 1)
			p.x += 0.008 * clampf((p.y - 0.17) / 0.07, 0, 1)
		p.x *= 1.045
		p.z *= 1.045
		return p)


static func ellipsoid(radius: Vector3, sides: int = 10) -> ArrayMesh:
	var profile: Array[Vector4] = []
	for r in 7:
		var angle: float = PI * r / 6.0
		var ring_radius: float = maxf(sin(angle), 0.06)
		profile.append(Vector4(-cos(angle) * radius.y, ring_radius * radius.x, ring_radius * radius.z, ring_radius * radius.z))
	return contour(profile, sides)


static func nose() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector3] = [
		Vector3(-0.015, 0.055, 0.008), Vector3(0.015, 0.055, 0.008),
		Vector3(0, -0.012, -0.044), Vector3(-0.026, -0.032, -0.006),
		Vector3(0.026, -0.032, -0.006), Vector3(0, -0.037, -0.025)
	]
	for tri: Vector3i in [Vector3i(0, 1, 2), Vector3i(0, 2, 3), Vector3i(2, 1, 4), Vector3i(3, 2, 5), Vector3i(2, 4, 5)]:
		FightMesh._triangle(surface, points[tri.x], points[tri.y], points[tri.z])
	return surface.commit()


static func beard(full: bool) -> ArrayMesh:
	# Only the jaw's front arc, leaving the nape and ears uncovered.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for n in 8:
		var angle_a: float = lerpf(-PI * 0.47, PI * 0.47, n / 8.0)
		var angle_b: float = lerpf(-PI * 0.47, PI * 0.47, (n + 1) / 8.0)
		var a := Vector3(sin(angle_a) * (0.143 if full else 0.132), -0.07 + absf(sin(angle_a)) * 0.075, -cos(angle_a) * 0.131)
		var b := Vector3(sin(angle_b) * (0.143 if full else 0.132), -0.07 + absf(sin(angle_b)) * 0.075, -cos(angle_b) * 0.131)
		var c := Vector3(sin(angle_a) * (0.105 if full else 0.094), -0.145 + absf(sin(angle_a)) * 0.025, -cos(angle_a) * 0.097)
		var d := Vector3(sin(angle_b) * (0.105 if full else 0.094), -0.145 + absf(sin(angle_b)) * 0.025, -cos(angle_b) * 0.097)
		if full:
			c.y -= 0.018
			d.y -= 0.018
		FightMesh._triangle(surface, a, b, c)
		FightMesh._triangle(surface, b, d, c)
	return surface.commit()


static func leg(stocky: bool) -> ArrayMesh:
	# Skin begins beneath the shorts; covered upper-thigh geometry would poke through on kicks.
	return contour([
		Vector4(-0.23, 0.125, 0.127, 0.13),
		Vector4(-0.29, 0.112, 0.118, 0.12), Vector4(-0.405, 0.076, 0.084, 0.074),
		Vector4(-0.46, 0.075, 0.085, 0.075), Vector4(-0.53, 0.09, 0.077, 0.11),
		Vector4(-0.63, 0.089, 0.063, 0.105), Vector4(-0.77, 0.055, 0.048, 0.065),
		Vector4(-0.9, 0.044, 0.043, 0.047)
	], 12, [], func(p: Vector3) -> Vector3:
		p.z -= 0.025 * exp(-pow((p.y + 0.43) / 0.13, 2.0))
		p.x *= 1.09 if stocky else 1.0
		return p)


static func foot() -> ArrayMesh:
	return contour([
		Vector4(-0.032, 0.063, 0.133, 0.065), Vector4(-0.012, 0.07, 0.14, 0.07),
		Vector4(0.024, 0.063, 0.123, 0.065), Vector4(0.065, 0.047, 0.05, 0.048),
		Vector4(0.1, 0.042, 0.041, 0.043)
	], 12)
