class_name EnvironmentSystem
extends Node3D

## 光照与渲染系统（纯代码构建）：
## PhysicalSkyMaterial 物理天空（瑞利/米氏散射 + 太阳光晕）+ 暖色日光，
## ACES 色调映射、HDR 泛光、SSAO、深度雾（含大气透视）与轻微色彩分级。
## 白模建筑目标观感：暖阳斜照、柔和长影、干净蓝-暖渐变天空、阴影区带天空蓝反弹。
## 说明：PhysicalSkyMaterial 的太阳圆盘在本引擎版本下渲染很弱，靠米氏光晕 +
## 泛光提供太阳氛围；太阳方向与光照方向共用 Sun 节点朝向（光沿 -Z 行进）。

## —— 日光 ——
const SUN_ELEVATION := 46.0            # 仰角（度），越低影子越长越暖
const SUN_AZIMUTH := -38.0             # 方位角（度，绕 Y）
const SUN_COLOR := Color(1.0, 0.92, 0.80)
const SUN_ENERGY := 3.2                # 日光强度
const SUN_ANGULAR := 3.5               # 光源角直径（度），越大阴影越柔和
const SUN_SHADOW_MAX := 160.0          # 阴影覆盖距离（米）
const SUN_SHADOW_BLUR := 2.5

## —— 天空 ——
const SKY_ENERGY := 1.8                # 物理天空能量乘数（整体曝光平衡）
const SKY_TURBIDITY := 4.0             # 大气浑浊度：越高地平线越暖越"霾"
const SKY_RAYLEIGH := Color(0.30, 0.45, 1.0)
const SKY_MIE := Color(0.72, 0.75, 0.80)
const SKY_SUN_DISK := 3.5              # 太阳圆盘尺寸倍数
const SKY_GROUND := Color(0.30, 0.26, 0.20)   # 地平线以下地面色

## —— 环境后处理 ——
const AMBIENT_ENERGY := 0.5
const TONEMAP_EXPOSURE := 1.02
const GLOW_INTENSITY := 0.14
const GLOW_STRENGTH := 0.85
const GLOW_HDR_THRESHOLD := 1.15
const SSAO_INTENSITY := 2.1
const SSAO_RADIUS := 0.7
const SSAO_SHARPNESS := 0.9
const SSAO_LIGHT_AFFECT := 0.35
const FOG_COLOR := Color(0.72, 0.66, 0.54)
const FOG_BEGIN := 35.0
const FOG_END := 220.0
const FOG_SKY_AFFECT := 0.12
const FOG_AERIAL := 0.35               # 大气透视：远物向天空色靠拢
const ADJUST_SATURATION := 1.06
const ADJUST_CONTRAST := 1.03

func setup() -> void:
	_apply_antialiasing()
	_build_environment()

## Forward+：4x MSAA 3D + TAA（俯视正交由 CameraController 关闭 TAA 以免拖影）。
## 2x MSAA 2D 照顾 UI 文字/图标。运行时写 Viewport，编辑器 Play 立即生效。
func _apply_antialiasing() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	vp.msaa_3d = Viewport.MSAA_4X
	vp.msaa_2d = Viewport.MSAA_2X
	vp.use_taa = true
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_debanding = true

func _build_environment() -> void:
	var sky_mat := PhysicalSkyMaterial.new()
	sky_mat.rayleigh_color = SKY_RAYLEIGH
	sky_mat.mie_color = SKY_MIE
	sky_mat.turbidity = SKY_TURBIDITY
	sky_mat.sun_disk_scale = SKY_SUN_DISK
	sky_mat.ground_color = SKY_GROUND
	sky_mat.energy_multiplier = SKY_ENERGY
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = AMBIENT_ENERGY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = TONEMAP_EXPOSURE

	## HDR 泛光：仅高亮（太阳光晕/高光）轻微溢出，白模主体不糊
	env.glow_enabled = true
	env.glow_intensity = GLOW_INTENSITY
	env.glow_bloom = 0.0
	env.glow_strength = GLOW_STRENGTH
	env.glow_hdr_threshold = GLOW_HDR_THRESHOLD
	env.glow_hdr_scale = 1.3

	env.ssao_enabled = true
	env.ssao_intensity = SSAO_INTENSITY
	env.ssao_radius = SSAO_RADIUS
	env.ssao_sharpness = SSAO_SHARPNESS
	env.ssao_light_affect = SSAO_LIGHT_AFFECT

	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = FOG_COLOR
	env.fog_depth_begin = FOG_BEGIN
	env.fog_depth_end = FOG_END
	env.fog_depth_curve = 1.0
	env.fog_sky_affect = FOG_SKY_AFFECT
	env.fog_aerial_perspective = FOG_AERIAL

	env.adjustment_enabled = true
	env.adjustment_saturation = ADJUST_SATURATION
	env.adjustment_contrast = ADJUST_CONTRAST

	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)

	_build_sun()
	_build_vignette()

## 主光源：暖色日光。软阴影 = 角直径 + shadow_blur + 4 级级联。
## 注意：不添加第二盏 DirectionalLight3D——多盏方向光会争抢场景"太阳"定义，
## 阴影区冷色补光由 AMBIENT_SOURCE_SKY（采样天空蓝）+ SSAO light_affect 提供。
func _build_sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-SUN_ELEVATION, SUN_AZIMUTH, 0.0)
	sun.light_color = SUN_COLOR
	sun.light_energy = SUN_ENERGY
	sun.light_angular_distance = SUN_ANGULAR
	sun.shadow_enabled = true
	sun.shadow_blur = SUN_SHADOW_BLUR
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = SUN_SHADOW_MAX
	add_child(sun)

## 轻微暗角：白模氛围统一（Godot 4 已移除 Environment 的 vignette，改用全屏着色器）。
func _build_vignette() -> void:
	var vignette := Vignette.new()
	vignette.name = "Vignette"
	add_child(vignette)
	vignette.setup()
