class_name PlacementToolBase
extends Node3D

## 放置工具基类：统一持有世界 / 相机 / HUD / 宿主引用、激活状态与材质 id，
## 并提供全息材质、端点标记、预览根节点等公共辅助函数。
## 放置类工具（柱子 / 墙体 / 地板 / 楼梯 / 门洞 / 窗洞 / 地洞 / 交互）都继承本类，
## 由各自 setup() 注入引用；refresh_material_hud / refresh_param_hud 供子类按需覆盖。

signal exit_requested

var world: WorldStore
var camera_rig: CameraController
var hud: Hud
var host: Node  # Main：材质对话框 / 参数栏协调
var modal: ModalManager  # 弹窗集中管理器（可为 null；优先于 host 回查）

var active := false
var material_id := Config.DEFAULT_MATERIAL

## 全息材质：半透明自发光，base 为底色（透明度通道单独处理）。
func _holo_mat(base: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = base
	m.emission_enabled = true
	var e := base
	e.a = 1.0
	m.emission = e
	return m

## 注入弹窗集中管理器（main 构造工具后调用；未注入时 _dialog_open 回退 host 回查）。
func set_modal(m: ModalManager) -> void:
	modal = m

## 材质 / 参数 / 阵列等弹窗是否打开：优先查询 ModalManager；
## 未注入时回退 host.is_any_dialog_open()（host 未注入或无该方法时视为未打开）。
func _dialog_open() -> bool:
	if modal != null and modal.any_open():
		return true
	return host != null and host.has_method("is_any_dialog_open") and host.is_any_dialog_open()

## 端点 / 落点标记：0.2m 立方体，自发光，默认隐藏，挂在本工具节点下。
func _make_marker(color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.2, 0.2, 0.2)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	bm.material = m
	mi.mesh = bm
	mi.visible = false
	add_child(mi)
	return mi

## 预览根节点：创建并挂到本工具下，默认隐藏，子类自行填充内容。
func _make_preview_root(name: String) -> Node3D:
	var root := Node3D.new()
	root.name = name
	root.visible = false
	add_child(root)
	return root

## 材质变更后的 HUD 刷新（子类按需覆盖）。
func refresh_material_hud() -> void:
	pass

## 参数变更后的 HUD 刷新：默认沿用材质刷新（柱/墙/地板/楼梯共用），
## 开洞类工具在子类中覆盖为各自的 HUD 刷新。
func refresh_param_hud() -> void:
	refresh_material_hud()

func get_material_id() -> String:
	return material_id

func set_material_id(m: String) -> void:
	material_id = m
