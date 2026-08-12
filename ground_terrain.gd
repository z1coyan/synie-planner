class_name GroundTerrain
extends Node3D

## 泥土/草地地面：跟随相机的巨大平面 + 世界坐标噪声着色器（无纹理）。
## 置于网格下方（FLOOR_TOP_OFFSET + 0.001），建筑白模不变。

var camera_cc: CameraController

const TERRAIN_PLANE_SIZE := 1000.0

var _mesh: MeshInstance3D

func setup() -> void:
	var mat := _make_terrain_material()
	_mesh = MeshInstance3D.new()
	_mesh.name = "TerrainMesh"
	var plane := PlaneMesh.new()
	plane.size = Vector2(TERRAIN_PLANE_SIZE, TERRAIN_PLANE_SIZE)
	_mesh.mesh = plane
	_mesh.material_override = mat
	_mesh.position.y = Config.FLOOR_TOP_OFFSET + 0.001
	add_child(_mesh)

## 无限地面：跟随相机 XZ 平移。
func _process(_delta: float) -> void:
	if camera_cc == null or _mesh == null:
		return
	var c := camera_cc.global_position
	_mesh.position.x = c.x
	_mesh.position.z = c.z

func set_camera(cc: CameraController) -> void:
	camera_cc = cc

func _make_terrain_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _terrain_shader()
	return mat

static var _terrain_shader_res: Shader

static func _terrain_shader() -> Shader:
	if _terrain_shader_res == null:
		var s := Shader.new()
		s.code = """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// 低成本哈希噪声（纯 shader，无外部纹理）
float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 m = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));
	for (int i = 0; i < 4; i++) {
		v += a * value_noise(p);
		p = m * p * 2.02;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 xz = v_world.xz;

	// 大尺度草斑 + 中尺度泥土变化 + 细粒度
	float macro = fbm(xz * 0.035);
	float mid = fbm(xz * 0.12 + vec2(17.0, 9.0));
	float fine = value_noise(xz * 1.7);

	// 泥土棕
	vec3 dirt_a = vec3(0.42, 0.32, 0.22);
	vec3 dirt_b = vec3(0.34, 0.26, 0.18);
	vec3 dirt = mix(dirt_a, dirt_b, mid);

	// 草地绿（偏橄榄，俯视/FP 都可读）
	vec3 grass_a = vec3(0.28, 0.40, 0.20);
	vec3 grass_b = vec3(0.22, 0.34, 0.16);
	vec3 grass = mix(grass_a, grass_b, fine);

	// 软斑块：macro 控制草覆盖，边缘用 smoothstep
	float grass_mask = smoothstep(0.38, 0.62, macro + (mid - 0.5) * 0.15);
	vec3 col = mix(dirt, grass, grass_mask);

	// 细微明度抖动，避免塑料感
	col *= 0.92 + 0.16 * fine;

	ALBEDO = col;
	ROUGHNESS = 0.90;
	METALLIC = 0.0;
}
"""
		_terrain_shader_res = s
	return _terrain_shader_res
