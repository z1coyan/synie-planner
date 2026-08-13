class_name PunchMeshMachineParams
extends RefCounted

## 精密高速冲网机（冲网机）参数：尺寸单位为米，Y 朝上。
## 柜体 2.0 × 2.2 × 0.8；控制台在 +X，前伸臂在 +Z。

const ID := "punch_mesh_machine"
const DISPLAY_NAME := "冲网机"
const CATEGORY := "冲网设备"
const FULL_NAME := "精密高速冲网机"
const BRAND := "星能机械"
const PHONE := "16633806660"

## 主柜体：宽 X × 高 Y × 深 Z
const CABINET := Vector3(2.0, 2.2, 0.8)
const CONSOLE := Vector3(0.40, 1.52, 0.50)
const CONSOLE_GAP := 0.02
## 白臂从柜体前脸再向前伸出的长度
const ARM_EXTENT := 0.70

## 放置/碰撞用完整 footprint（含控制台与前伸臂）
const FOOTPRINT := Vector3(
	CABINET.x + CONSOLE_GAP + CONSOLE.x,
	CABINET.y,
	CABINET.z + ARM_EXTENT,
)

const COLOR_BODY := Color(0.78, 0.79, 0.81)       # 与 Config.COLOR_DEVICE 一致
const COLOR_BODY_INNER := Color(0.72, 0.73, 0.75)
const COLOR_BLUE := Color(0.10, 0.40, 0.82)       # 电气蓝：铭牌 / 控制台框 / 减速机
const COLOR_YELLOW := Color(0.96, 0.78, 0.08)     # 安全黄：压紧梁 / 警示
const COLOR_DIE := Color(0.30, 0.31, 0.33)
const COLOR_SLOT := Color(0.12, 0.12, 0.13)
const COLOR_MOTOR := Color(0.16, 0.17, 0.19)
const COLOR_ARM := Color(0.93, 0.93, 0.94)
const COLOR_ESTOP := Color(0.86, 0.10, 0.10)
const COLOR_SCREEN := Color(0.08, 0.10, 0.12)
const COLOR_RAIL := Color(0.68, 0.70, 0.72)
const COLOR_CABLE := Color(0.07, 0.07, 0.08)
const COLOR_BOLT := Color(0.22, 0.23, 0.24)
const COLOR_DOOR := Color(0.82, 0.83, 0.85)
const COLOR_PHONE := Color(0.98, 0.86, 0.12)
const COLOR_WARN_RED := Color(0.78, 0.12, 0.10)
