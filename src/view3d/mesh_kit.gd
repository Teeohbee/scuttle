class_name MeshKit
# Low-poly building blocks, from scuttle-3d. Every helper appends flat-shaded triangles in one
# colour to a SurfaceTool, so a model is a list of calls and one commit().
#
#   var st := MeshKit.begin()
#   MeshKit.box(st, Vector3(0, 0.5, 0), Vector3(1, 1, 1), Color.SADDLE_BROWN)
#   mesh_instance.mesh = MeshKit.commit(st)

static var _material: StandardMaterial3D

static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
		_material.roughness = 0.85
	return _material

static func begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st

static func commit(st: SurfaceTool) -> ArrayMesh:
	var mesh := st.commit()
	if mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, material())
	return mesh

# One flat triangle; winding is counter-clockwise seen from outside.
static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	st.set_color(color)
	st.set_normal(n)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(b)

static func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	tri(st, a, b, c, color)
	tri(st, a, c, d, color)

# Box centred on `centre`, optionally turned by `basis`.
static func box(st: SurfaceTool, centre: Vector3, size: Vector3, color: Color, basis := Basis.IDENTITY) -> void:
	var h := size * 0.5
	var p := func(x: float, y: float, z: float) -> Vector3:
		return centre + basis * Vector3(x * h.x, y * h.y, z * h.z)
	quad(st, p.call(-1, 1, -1), p.call(-1, 1, 1), p.call(1, 1, 1), p.call(1, 1, -1), color)      # top
	quad(st, p.call(-1, -1, 1), p.call(-1, -1, -1), p.call(1, -1, -1), p.call(1, -1, 1), color)  # bottom
	quad(st, p.call(-1, -1, 1), p.call(1, -1, 1), p.call(1, 1, 1), p.call(-1, 1, 1), color)      # +z
	quad(st, p.call(1, -1, -1), p.call(-1, -1, -1), p.call(-1, 1, -1), p.call(1, 1, -1), color)  # -z
	quad(st, p.call(1, -1, 1), p.call(1, -1, -1), p.call(1, 1, -1), p.call(1, 1, 1), color)      # +x
	quad(st, p.call(-1, -1, -1), p.call(-1, -1, 1), p.call(-1, 1, 1), p.call(-1, 1, -1), color)  # -x

# A thin square-section bar from a to b: rigging, rails.
static func strut(st: SurfaceTool, a: Vector3, b: Vector3, thickness: float, color: Color) -> void:
	var along := b - a
	var basis := Basis(Quaternion(Vector3.UP, along.normalized()))
	box(st, (a + b) / 2.0, Vector3(thickness, along.length(), thickness), color, basis)

# Revolve a profile of (radius, height) points about +Y. Flat faces, `sides`
# segments; caps are closed when the profile ends off-axis, unless `caps` is false.
static func lathe(st: SurfaceTool, base: Vector3, profile: PackedVector2Array, sides: int, color: Color, basis := Basis.IDENTITY, colors: PackedColorArray = PackedColorArray(), caps := true) -> void:
	for s in sides:
		var a0 := TAU * s / sides
		var a1 := TAU * (s + 1) / sides
		for i in profile.size() - 1:
			var c := colors[i] if i < colors.size() else color
			var r0 := profile[i]
			var r1 := profile[i + 1]
			var p00 := base + basis * Vector3(cos(a0) * r0.x, r0.y, sin(a0) * r0.x)
			var p01 := base + basis * Vector3(cos(a1) * r0.x, r0.y, sin(a1) * r0.x)
			var p10 := base + basis * Vector3(cos(a0) * r1.x, r1.y, sin(a0) * r1.x)
			var p11 := base + basis * Vector3(cos(a1) * r1.x, r1.y, sin(a1) * r1.x)
			quad(st, p00, p10, p11, p01, c)
		if not caps:
			continue
		var first := profile[0]
		var last := profile[profile.size() - 1]
		if first.x > 0.0:
			var centre := base + basis * Vector3(0, first.y, 0)
			tri(st, centre, base + basis * Vector3(cos(a0) * first.x, first.y, sin(a0) * first.x),
				base + basis * Vector3(cos(a1) * first.x, first.y, sin(a1) * first.x), colors[0] if colors.size() > 0 else color)
		if last.x > 0.0:
			var centre := base + basis * Vector3(0, last.y, 0)
			tri(st, centre, base + basis * Vector3(cos(a1) * last.x, last.y, sin(a1) * last.x),
				base + basis * Vector3(cos(a0) * last.x, last.y, sin(a0) * last.x), colors[colors.size() - 1] if colors.size() > 0 else color)

static func cylinder(st: SurfaceTool, base: Vector3, radius: float, height: float, sides: int, color: Color, basis := Basis.IDENTITY) -> void:
	lathe(st, base, PackedVector2Array([Vector2(radius, 0), Vector2(radius, height)]), sides, color, basis)

# A ring lying flat round +Y: a lathe of a small circle.
static func torus(st: SurfaceTool, centre: Vector3, radius: float, thickness: float, color: Color, basis := Basis.IDENTITY, sides := 12) -> void:
	var profile := PackedVector2Array()
	for i in 7:
		var a := TAU * i / 6
		profile.append(Vector2(radius + cos(a) * thickness, sin(a) * thickness))
	lathe(st, centre, profile, sides, color, basis, PackedColorArray(), false)

# A chunky low-poly ball: a lathe with few rings.
static func ball(st: SurfaceTool, centre: Vector3, radius: float, color: Color, rings := 4, sides := 7) -> void:
	var profile := PackedVector2Array()
	for i in rings + 1:
		var a := PI * i / rings - PI * 0.5
		profile.append(Vector2(cos(a) * radius, sin(a) * radius))
	lathe(st, centre, profile, sides, color)

# A squashed ball: `size` is its radius along each axis.
static func blob(st: SurfaceTool, centre: Vector3, size: Vector3, color: Color, basis := Basis.IDENTITY, rings := 6, sides := 10) -> void:
	var profile := PackedVector2Array()
	for i in rings + 1:
		var a := PI * i / rings - PI * 0.5
		profile.append(Vector2(cos(a), sin(a)))
	lathe(st, centre, profile, sides, color, basis * Basis.from_scale(size))

# A barrel/keg: bulging staves with darker hoops. `basis` lays it down.
static func barrel(st: SurfaceTool, base: Vector3, radius: float, height: float, wood: Color, hoop: Color, sides := 8, basis := Basis.IDENTITY) -> void:
	var r := radius
	var h := height
	var profile := PackedVector2Array([
		Vector2(r * 0.82, 0), Vector2(r * 0.86, h * 0.1), Vector2(r * 0.86, h * 0.16),
		Vector2(r, h * 0.5), Vector2(r * 0.86, h * 0.84), Vector2(r * 0.86, h * 0.9), Vector2(r * 0.82, h),
	])
	var colors := PackedColorArray([hoop, wood, wood, wood, wood, hoop])
	lathe(st, base, profile, sides, wood, basis, colors)
