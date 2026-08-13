class_name GroundTerrain
extends Node3D

## 压实泥土地面：跟随相机的巨大平面 + 世界坐标多层噪声着色器（无外部纹理）。
## 干土/潮土/细石子与稀疏草斑，法线来自高度导数。建筑白模不变。

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
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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

float fbm(vec2 p, int octaves) {
	float v = 0.0;
	float a = 0.5;
	mat2 m = mat2(vec2(0.80, -0.60), vec2(0.60, 0.80));
	for (int i = 0; i < octaves; i++) {
		v += a * value_noise(p);
		p = m * p * 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 xz = v_world.xz;

	vec2 warp = vec2(
		fbm(xz * 0.055 + vec2(11.2, 4.7), 3),
		fbm(xz * 0.055 + vec2(31.9, 19.4), 3)
	);
	vec2 w = xz + (warp - 0.5) * 4.2;

	float macro = fbm(w * 0.022, 4);
	float mid = fbm(w * 0.09 + vec2(17.0, 9.0), 4);
	float fine = fbm(w * 0.62 + vec2(3.3, 28.1), 3);
	float grit = value_noise(xz * 5.4 + vec2(macro * 3.0, mid * 1.5));
	float grain = value_noise(xz * 14.0 + vec2(19.0, 7.0));

	vec3 dry = vec3(0.28, 0.20, 0.12);
	vec3 packed = vec3(0.15, 0.10, 0.06);
	vec3 damp = vec3(0.08, 0.06, 0.04);
	float dry_m = clamp(mid * 0.65 + grit * 0.35, 0.0, 1.0);
	vec3 dirt = mix(packed, dry, dry_m);
	float damp_m = smoothstep(0.52, 0.80, macro);
	dirt = mix(dirt, damp, damp_m * 0.70);

	float pebble_m = smoothstep(0.78, 0.94, value_noise(xz * 15.0 + vec2(8.1, 2.4))) * (0.40 + 0.60 * fine);
	vec3 pebble = vec3(0.26, 0.22, 0.16);
	dirt = mix(dirt, pebble, pebble_m * 0.85);

	float patch = smoothstep(0.60, 0.80, macro + mid * 0.10);
	float fleck = smoothstep(0.76, 0.93, value_noise(xz * 19.0 + vec2(4.2, 13.7)));
	float blade = smoothstep(0.66, 0.94, value_noise(vec2(xz.x * 28.0, xz.y * 8.0) + warp * 2.0));
	float grass_m = patch * max(fleck * 0.88, blade * 0.70);
	vec3 grass_a = vec3(0.10, 0.18, 0.06);
	vec3 grass_b = vec3(0.16, 0.20, 0.07);
	vec3 grass = mix(grass_a, grass_b, grit);
	vec3 col = mix(dirt, grass, grass_m);

	float h = macro * 0.40 + mid * 0.30 + fine * 0.18 + grit * 0.12;
	col *= 0.62 + 0.58 * h;
	col *= 0.78 + 0.36 * grit;
	col *= 0.86 + 0.24 * grain;
	col *= 1.0 - smoothstep(0.90, 0.99, value_noise(xz * 31.0 + 5.5)) * 0.28;

	ALBEDO = col;
	METALLIC = 0.0;
	ROUGHNESS = mix(0.95, 0.68, pebble_m) - fine * 0.05 + damp_m * 0.05;
	ROUGHNESS = clamp(ROUGHNESS, 0.62, 0.98);

	float relief = (h - 0.5) * 0.32 + (grain - 0.5) * 0.10;
	vec3 n_world = normalize(vec3(-dFdx(relief), 1.0, -dFdy(relief)));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
}
"""
		_terrain_shader_res = s
	return _terrain_shader_res
