class_name SeaModel
extends MeshInstance3D
# The sea: a gentle swell cut into flat facets, like everything else aboard, running past both ships,
# with a band of foam where it meets each hull. It only ever moves in the shader; height_at() is the
# same sum of WAVES on the CPU, and the shader's waves() is written from them.

const LEVEL := -0.8
const SIZE := 300.0   # metres a side: past the haze in every direction
const FACET := 2.0    # metres
const FOAM := 0.45    # metres out from the hull
const MAX_POINTS := 64   # per hull outline
# Each wave: direction (x, z) times wavenumber, speed, height, phase. The heights add up to SWELL.
const WAVES := [Vector4(0.55, 0.25, 1.1, 0.07), Vector4(-0.3, 0.7, 0.9, 0.05), Vector4(1.1, -0.6, 1.7, 0.03)]
const PHASES := [0.0, 1.3, 2.1]
const SWELL := 0.15

const SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform vec3 water : source_color;
uniform float time;
uniform float swell;
uniform vec2 ours[64];
uniform int ours_count;
uniform vec4 ours_box;     // min xz, max xz
uniform vec2 theirs[64];
uniform int theirs_count;
uniform vec4 theirs_box;
uniform float foam_width;

varying vec3 world;
varying float crest;

float waves(vec2 p, float t) {
	return %s;
}

%s
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = waves(world.xz, time) * swell;
	VERTEX.y += h;
	crest = h / %s;
}

void fragment() {
	NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));   // flat facets
	float d = min(edge_ours(world.xz), edge_theirs(world.xz));
	float lap = foam_width * (0.75 + 0.25 * sin(time * 1.4 + world.x * 0.9 + world.z * 0.6));
	float flecks = step(0.25, sin(world.x * 2.3 + time) * sin(world.z * 2.9 - time * 0.7));
	float foam = max(step(d, lap) * 0.4, step(d, lap * 1.8) * flecks * 0.25);   // a wash, then broken flecks
	vec3 sea = mix(water, water * 1.35 + 0.03, clamp(crest, 0.0, 1.0));
	ALBEDO = mix(sea, vec3(0.85, 0.9, 0.92), foam);
	ROUGHNESS = mix(0.35, 0.9, foam);
	SPECULAR = 0.4;
}
"""

# How far p is from a hull's edge, if it's anywhere near; outside the box it's far enough. One copy per
# hull reads its uniforms in place: passed as a function argument, each 64-point outline was copied for
# every pixel of sea, and that cost more than the rest of the frame put together.
const EDGE := """float edge_{hull}(vec2 p) {
	if ({hull}_count == 0 || any(lessThan(p, {hull}_box.xy - foam_width)) || any(greaterThan(p, {hull}_box.zw + foam_width))) {
		return 1e3;
	}
	float d = 1e3;
	for (int i = 0; i < {hull}_count; i++) {
		vec2 a = {hull}[i];
		vec2 ab = {hull}[(i + 1) %% {hull}_count] - a;
		d = min(d, length(p - a - ab * clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0)));
	}
	return d;
}
"""

var _material := ShaderMaterial.new()
var _color := Color.BLACK
var _swell := 0.0
var _time := 0.0
var _lines: Array[PackedVector2Array] = []

func _init() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(SIZE, SIZE)
	plane.subdivide_width = int(SIZE / FACET) - 1
	plane.subdivide_depth = int(SIZE / FACET) - 1
	mesh = plane
	position.y = LEVEL
	var shader := Shader.new()
	var sum := PackedStringArray()
	for i in WAVES.size():
		var w: Vector4 = WAVES[i]
		sum.append("%f * sin(dot(p, vec2(%f, %f)) - %f * t + %f)" % [w.w, w.x, w.y, w.z, PHASES[i]])
	var edges := (EDGE.format({hull = "ours"}) + "\n" + EDGE.format({hull = "theirs"})).replace("%%", "%")
	shader.code = SHADER % [" + ".join(sum), edges, SWELL]
	_material.shader = shader
	_material.set_shader_parameter("foam_width", FOAM)
	material_override = _material

func set_color(color: Color) -> void:
	_color = color
	_material.set_shader_parameter("water", color)

func color() -> Color:
	return _color

# The swell fades in with the tilt by `amount`, so the sea lies flat while the view lines up with the 2D.
func sway(amount: float) -> void:
	_swell = amount
	_time = Time.get_ticks_msec() / 1000.0
	_material.set_shader_parameter("swell", _swell)
	_material.set_shader_parameter("time", _time)

# How far above LEVEL the sea is at (x, z) right now.
func height_at(p: Vector2) -> float:
	var h := 0.0
	for i in WAVES.size():
		var w: Vector4 = WAVES[i]
		h += w.w * sin(p.dot(Vector2(w.x, w.y)) - w.z * _time + PHASES[i])
	return h * _swell

# Foam round each hull, given its edge at the waterline in world (x, z): ours first, then theirs.
func foam_round(ours: PackedVector2Array, theirs: PackedVector2Array) -> void:
	_lines = [ours, theirs]
	_send("ours", ours)
	_send("theirs", theirs)

func foam_lines() -> Array[PackedVector2Array]:
	return _lines

func _send(which: String, outline: PackedVector2Array) -> void:
	assert(outline.size() <= MAX_POINTS, "the shader holds %d points per hull" % MAX_POINTS)
	var box := Rect2(outline[0], Vector2.ZERO) if outline.size() > 0 else Rect2()
	for p in outline:
		box = box.expand(p)
	_material.set_shader_parameter(which, outline)
	_material.set_shader_parameter(which + "_count", outline.size())
	_material.set_shader_parameter(which + "_box", Vector4(box.position.x, box.position.y, box.end.x, box.end.y))
