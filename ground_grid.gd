class_name GroundGrid
extends Node3D

## 地面描图网格：跟随相机的巨大平面 + 世界坐标网格着色器，随距离淡出。
## 网格贴在地面标高（Config.FLOOR_TOP_OFFSET）上，作为建造基准参考。

var camera_cc: CameraController

const GRID_PLANE_SIZE := 1000.0
const GRID_FADE_START := 100.0
const GRID_FADE_END := 320.0

var _grid: MeshInstance3D

func setup() -> void:
	var mat := _make_grid_material()
	_grid = MeshInstance3D.new()
	_grid.name = "GroundGrid"
	var plane := PlaneMesh.new()
	plane.size = Vector2(GRID_PLANE_SIZE, GRID_PLANE_SIZE)
	_grid.mesh = plane
	_grid.material_override = mat
	_grid.position.y = Config.FLOOR_TOP_OFFSET + 0.002
	add_child(_grid)

## 无限网格：跟随相机 XZ 平移。
func _process(_delta: float) -> void:
	if camera_cc == null:
		return
	var c := camera_cc.global_position
	_grid.position.x = c.x
	_grid.position.z = c.z

func set_camera(cc: CameraController) -> void:
	camera_cc = cc

func _make_grid_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _grid_shader()
	mat.set_shader_parameter("minor_color", Config.COLOR_FLOOR_GRID)
	mat.set_shader_parameter("major_color", Config.COLOR_GRID_MAJOR)
	mat.set_shader_parameter("minor_cell", Config.GRID)
	mat.set_shader_parameter("major_cell", Config.GRID_MAJOR)
	mat.set_shader_parameter("fade_start", GRID_FADE_START)
	mat.set_shader_parameter("fade_end", GRID_FADE_END)
	return mat

static var _grid_shader_res: Shader

static func _grid_shader() -> Shader:
	if _grid_shader_res == null:
		var s := Shader.new()
		s.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

uniform vec4 minor_color : source_color = vec4(0.66, 0.67, 0.69, 0.5);
uniform vec4 major_color : source_color = vec4(0.60, 0.61, 0.63, 1.0);
uniform float minor_cell = 0.5;
uniform float major_cell = 5.0;
uniform float fade_start = 100.0;
uniform float fade_end = 320.0;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float grid_line(vec2 g, float cell) {
	vec2 gr = g / cell;
	vec2 fw = max(fwidth(gr), vec2(1e-5));
	vec2 a = abs(fract(gr - 0.5) - 0.5) / fw;
	return max(1.0 - a.x, 1.0 - a.y);
}

void fragment() {
	vec2 g = v_world.xz;
	float minor = grid_line(g, minor_cell);
	float major = grid_line(g, major_cell);
	float a = clamp(max(minor, major), 0.0, 1.0);
	vec3 col = mix(minor_color.rgb, major_color.rgb, step(0.5, major));
	float d = length(g);
	a *= 1.0 - smoothstep(fade_start, fade_end, d);
	ALBEDO = col;
	ALPHA = a;
}
"""
		_grid_shader_res = s
	return _grid_shader_res
