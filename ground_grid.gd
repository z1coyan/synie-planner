class_name GroundGrid
extends Node3D

## 局部放置网格：仅在放置工具激活且有有效瞄准时，显示在物体脚点下的世界坐标贴片。
## 边缘圆形淡出，世界 X/Z 轴略加强。不再铺满全场景。

const DEFAULT_PATCH := 6.5
const MIN_PATCH := 4.0
const MAX_PATCH := 12.0
const Y_LIFT := 0.002

var _mesh: MeshInstance3D
var _mat: ShaderMaterial
var _plane: PlaneMesh
var _size := DEFAULT_PATCH

func setup() -> void:
	_mat = _make_grid_material()
	_plane = PlaneMesh.new()
	_plane.size = Vector2(DEFAULT_PATCH, DEFAULT_PATCH)
	_mesh = MeshInstance3D.new()
	_mesh.name = "GridPatch"
	_mesh.mesh = _plane
	_mesh.material_override = _mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.position.y = Config.FLOOR_TOP_OFFSET + Y_LIFT
	_mesh.visible = false
	add_child(_mesh)

func set_patch_visible(v: bool) -> void:
	if _mesh == null:
		return
	_mesh.visible = v

func is_patch_visible() -> bool:
	return _mesh != null and _mesh.visible

func set_origin(world_xz: Vector3) -> void:
	if _mesh == null:
		return
	_mesh.position.x = world_xz.x
	_mesh.position.z = world_xz.z

func set_patch_size(meters: float) -> void:
	if _plane == null or _mat == null:
		return
	var s := clampf(meters, MIN_PATCH, MAX_PATCH)
	if is_equal_approx(s, _size):
		return
	_size = s
	_plane.size = Vector2(s, s)
	_mat.set_shader_parameter("patch_size", s)

func _make_grid_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _grid_shader()
	# 浅尘土色线条，压在深色泥土上才看得见；逻辑格距仍用 Config.GRID
	mat.set_shader_parameter("minor_color", Color(0.86, 0.78, 0.56, 0.42))
	mat.set_shader_parameter("major_color", Color(0.95, 0.90, 0.70, 0.78))
	mat.set_shader_parameter("axis_color", Color(0.98, 0.96, 0.88, 0.95))
	mat.set_shader_parameter("minor_cell", Config.GRID)
	mat.set_shader_parameter("major_cell", Config.GRID_MAJOR)
	mat.set_shader_parameter("patch_size", DEFAULT_PATCH)
	return mat

static var _grid_shader_res: Shader

static func _grid_shader() -> Shader:
	if _grid_shader_res == null:
		var s := Shader.new()
		s.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;

uniform vec4 minor_color : source_color = vec4(0.32, 0.34, 0.24, 0.50);
uniform vec4 major_color : source_color = vec4(0.28, 0.30, 0.22, 0.70);
uniform vec4 axis_color : source_color = vec4(0.52, 0.53, 0.55, 1.0);
uniform float minor_cell = 0.5;
uniform float major_cell = 5.0;
uniform float patch_size = 6.5;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float grid_line(vec2 g, float cell) {
	vec2 gr = g / cell;
	vec2 fw = max(fwidth(gr), vec2(1e-5));
	// 约 1.4px 半宽 + smoothstep，线条更稳、边缘抗锯齿
	vec2 a = abs(fract(gr - 0.5) - 0.5) / (fw * 1.4);
	float lx = 1.0 - smoothstep(0.0, 1.0, a.x);
	float ly = 1.0 - smoothstep(0.0, 1.0, a.y);
	return max(lx, ly);
}

float axis_line(vec2 g) {
	vec2 fw = max(fwidth(g), vec2(1e-5));
	float ax = 1.0 - smoothstep(0.0, 1.0, abs(g.x) / (fw.x * 2.2));
	float az = 1.0 - smoothstep(0.0, 1.0, abs(g.y) / (fw.y * 2.2));
	return max(ax, az);
}

void fragment() {
	vec2 g = v_world.xz;
	float minor = grid_line(g, minor_cell);
	float major = grid_line(g, major_cell);
	float axis = axis_line(g);

	vec3 col = minor_color.rgb;
	float a = minor * minor_color.a * 0.85;
	if (major > 0.05) {
		col = mix(col, major_color.rgb, clamp(major, 0.0, 1.0));
		a = max(a, major * major_color.a);
	}
	if (axis > 0.05) {
		col = mix(col, axis_color.rgb, clamp(axis, 0.0, 1.0));
		a = max(a, axis * 0.92);
	}

	// 圆形边缘淡出，避免硬方块
	float d = length(UV - vec2(0.5)) / 0.5;
	a *= 1.0 - smoothstep(0.48, 0.98, d);
	a = clamp(a, 0.0, 1.0);

	ALBEDO = col;
	ALPHA = a;
}
"""
		_grid_shader_res = s
	return _grid_shader_res
