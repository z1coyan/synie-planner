class_name Config
extends RefCounted

## 全局尺寸、颜色、吸附参数统一入口。

const GRID := 0.5
const GRID_EXTENT := 200.0
const GRID_MAJOR := 5.0
const CLEARANCE := 0.05

const WALL_THICKNESS_DEFAULT := 0.2
const WALL_THICKNESS_MIN := 0.1
const WALL_THICKNESS_MAX := 1.0
const WALL_THICKNESS_STEP := 0.05
const WALL_HEIGHT := 5.0

const COLUMN_WIDTH := 0.4
const COLUMN_DEPTH := 0.4
const COLUMN_HEIGHT := 5.0

const DEVICE_SIZE := Vector3(2.0, 1.5, 1.0)

const EYE_HEIGHT := 1.6
const WALK_SPEED := 5.0
const FLY_SPEED := 10.0
const TOP_DOWN_SPEED := 20.0
const TOP_DOWN_START := 60.0
const TOP_DOWN_MIN := 6.0
const TOP_DOWN_MAX := 200.0
const MOUSE_SENS := 0.002

const COLOR_GROUND := Color(0.16, 0.17, 0.18, 1.0)
const COLOR_GRID_MINOR := Color(0.28, 0.30, 0.32, 1.0)
const COLOR_GRID_MAJOR := Color(0.42, 0.45, 0.48, 1.0)
const COLOR_AXIS := Color(0.85, 0.30, 0.30, 1.0)
const COLOR_WALL := Color(0.78, 0.76, 0.68, 1.0)
const COLOR_COLUMN := Color(0.45, 0.45, 0.52, 1.0)
const COLOR_DEVICE := Color(0.35, 0.65, 0.95, 1.0)
const COLOR_OK := Color(0.15, 0.95, 0.30, 0.35)
const COLOR_BAD := Color(0.95, 0.20, 0.20, 0.35)
