class_name FightMesh
extends RefCounted
## Small, flat-shaded meshes shared by the local-fight-night presentation (docs/13).

## Each ring is (height, half width, half depth). Separate triangle normals keep broad facets.
static func loft(rings: Array[Vector3], sides: int = 8) -> ArrayMesh:
	if rings[0].x > rings[-1].x:
		rings = rings.duplicate()
		rings.reverse()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in range(rings.size() - 1):
		for n in sides:
			var a: Vector3 = _point(rings[r], n, sides)
			var b: Vector3 = _point(rings[r], (n + 1) % sides, sides)
			var c: Vector3 = _point(rings[r + 1], n, sides)
			var d: Vector3 = _point(rings[r + 1], (n + 1) % sides, sides)
			_triangle(surface, a, c, b)
			_triangle(surface, b, c, d)
	for n in sides:
		_triangle(surface, Vector3(0, rings[0].x, 0), _point(rings[0], n, sides), _point(rings[0], (n + 1) % sides, sides))
		_triangle(surface, Vector3(0, rings[-1].x, 0), _point(rings[-1], (n + 1) % sides, sides), _point(rings[-1], n, sides))
	return surface.commit()


static func _point(ring: Vector3, n: int, sides: int) -> Vector3:
	var angle: float = TAU * float(n) / sides + PI / sides
	return Vector3(cos(angle) * ring.y, ring.x, sin(angle) * ring.z)


static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal: Vector3 = (b - a).cross(c - a).normalized()
	for point: Vector3 in [a, c, b]:
		surface.set_normal(normal)
		surface.add_vertex(point)


static func instance(parent: Node3D, mesh: Mesh, material: Material, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	parent.add_child(node)
	return node


static func box(parent: Node3D, size: Vector3, material: Material, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return instance(parent, mesh, material, at)
