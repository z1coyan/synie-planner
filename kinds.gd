class_name Kinds
extends RefCounted

## 物体类型集中定义：所有工具/仓库共用的 kind 常量表与查询函数，
## 避免各文件各自维护一份重复列表。

## 全部合法物体类型（含开洞类）。
const VALID_KINDS := ["wall", "column", "device", "floor_tile", "stair", "door", "window", "floor_hole"]
## 支持材质的物体类型。
const MATERIAL_KINDS := ["floor_tile", "column", "wall", "stair"]
## 可交互（点选/选中）的物体类型。
const INTERACT_KINDS := ["wall", "column", "device", "floor_tile", "stair"]
## 可删除的物体类型（与 INTERACT_KINDS 同内容）。
const DELETABLE_KINDS := ["wall", "column", "device", "floor_tile", "stair"]
## 提供参数面板的物体类型。
const PARAM_KINDS := ["column", "wall", "floor_tile", "stair", "door", "window", "floor_hole"]
## 放置工具对应的物体类型。
const PLACEMENT_KINDS := ["column", "wall", "floor_tile", "stair", "device", "door", "window", "floor_hole"]
## 物体类型的中文显示名。
const KIND_NAMES := {
	"wall": "墙体", "column": "柱子", "device": "设备", "floor_tile": "地板",
	"stair": "楼梯", "door": "门洞", "window": "窗洞", "floor_hole": "地洞",
}

## 取物体类型的中文名，未知类型返回 "物体"。
static func label(kind: String) -> String:
	return KIND_NAMES.get(kind, "物体")

## 该类型是否支持材质。
static func has_material(kind: String) -> bool:
	return MATERIAL_KINDS.has(kind)

## 该类型是否属于放置工具。
static func is_placement(kind: String) -> bool:
	return PLACEMENT_KINDS.has(kind)
