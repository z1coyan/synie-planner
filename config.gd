class_name Config
extends RefCounted

## 全局尺寸、颜色、吸附参数统一入口。

const GRID := 0.5
const GRID_MAJOR := 5.0
const CLEARANCE := 0.05

## 嵌入余量（米）：允许相交的构件（墙/柱/地板）在相交方向多伸出 EMBED，
## 使相交面互相穿过、埋入对方体内，而非精确共面——从根源消除 z-fighting 闪烁。
## 0.02m 在建筑尺度下不可见，且与柱截面预设、墙厚步进均不重合，保证永不共面。
const EMBED := 0.02

## 磁吸阈值（米）：柱子吸附墙中心线，使墙柱互相嵌入、消除接缝
const SNAP_TO_WALL := 0.3
## 地板/墙体端点吸附角点（墙/柱/地板）的阈值；墙对柱吸附柱角内缩半墙厚位置
const SNAP_TO_CORNER := 0.35

## 无限地面：巨型碰撞盒顶部对齐 1F 标高，等效无限建造区
const GROUND_EXTENT := 20000.0

const WALL_THICKNESS_DEFAULT := 0.2
const WALL_THICKNESS_MIN := 0.1
const WALL_THICKNESS_MAX := 1.0
const WALL_THICKNESS_STEP := 0.05
const WALL_HEIGHT := 5.0

const COLUMN_WIDTH := 0.4
const COLUMN_DEPTH := 0.4
const COLUMN_HEIGHT := 5.0
## 柱子截面预设（米），E 键循环切换
const COLUMN_SIZES := [0.4, 0.6, 0.8, 1.0]

## 默认设备尺寸：冲网机完整 footprint（柜体 2.0×2.2×0.8 m，另加右侧控制台与 +Z 前伸臂）。
## 细节以 PunchMeshMachineParams.FOOTPRINT 为准。
const DEVICE_SIZE := Vector3(2.42, 2.2, 1.5)

const EYE_HEIGHT := 1.6
const WALK_SPEED := 5.0
const FLY_SPEED := 10.0
const TOP_DOWN_SPEED := 20.0
const TOP_DOWN_START := 60.0
const TOP_DOWN_MIN := 6.0
const TOP_DOWN_MAX := 200.0
const MOUSE_SENS := 0.002

## 白模配色纪律：建筑/设备一律灰白（明度 0.75~0.95），
## 仅允许橙色（选中/悬停高亮）与青色（物流路径）两个强调色。

const COLOR_GROUND := Color(0.42, 0.34, 0.24, 1.0)
const COLOR_GRID_MINOR := Color(0.72, 0.73, 0.75, 1.0)
const COLOR_GRID_MAJOR := Color(0.28, 0.30, 0.22, 0.70)
const COLOR_AXIS := Color(0.52, 0.53, 0.55, 1.0)
const COLOR_WALL := Color(0.89, 0.90, 0.91, 1.0)
const COLOR_COLUMN := Color(0.80, 0.81, 0.83, 1.0)
const COLOR_DEVICE := Color(0.78, 0.79, 0.81, 1.0)
const COLOR_ACCENT := Color(0.96, 0.60, 0.15, 1.0)      # 橙色：选中/悬停高亮
const COLOR_PATH := Color(0.20, 0.78, 0.85, 1.0)       # 青色：物流路径
const COLOR_OK := Color(0.96, 0.60, 0.15, 0.35)
const COLOR_BAD := Color(0.35, 0.36, 0.38, 0.45)

const FLOOR_THICKNESS := 0.3
const FLOOR_TOP_OFFSET := 0.3

## 默认地板色：偏混凝土灰（非纯白盒白）
const COLOR_FLOOR := Color(0.60, 0.61, 0.63, 1.0)
## 混凝土：冷灰，略深于旧白模地板
const COLOR_FLOOR_CONCRETE := Color(0.58, 0.59, 0.62, 1.0)
## 泥土：贴近地面泥土棕
const COLOR_FLOOR_DIRT := Color(0.40, 0.30, 0.20, 1.0)
const COLOR_FLOOR_GRID := Color(0.32, 0.34, 0.24, 0.50)

## 柱/墙/地板共用材质 id
const MATERIAL_IDS := ["dirt", "concrete"]
const DEFAULT_MATERIAL := "concrete"

static func normalize_material(material_id: String) -> String:
	if material_id == "dirt":
		return "dirt"
	return DEFAULT_MATERIAL

static func material_label(material_id: String) -> String:
	return "泥土" if normalize_material(material_id) == "dirt" else "混凝土"

static func material_color(material_id: String) -> Color:
	if normalize_material(material_id) == "dirt":
		return COLOR_FLOOR_DIRT
	return COLOR_FLOOR_CONCRETE
