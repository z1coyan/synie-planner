class_name ModalManager
extends Node

## 弹窗集中管理器：统一登记所有带 is_open() 方法的弹窗节点（材质 / 工具参数 / 元素库 / 阵列面板），
## any_open() 供工具基类与宿主（main.gd）判断"是否有弹窗打开"，
## 取代原先在 main.gd 中逐个点名 material_panel / tool_params_panel / library_panel / select_tool 的硬编码逻辑。

var _modals: Array[Node] = []

## 登记弹窗节点：必须提供 is_open() 方法（has_method 校验），否则忽略。
func register(m: Node) -> void:
	if m == null:
		return
	if not m.has_method("is_open"):
		push_warning("ModalManager.register：节点 %s 缺少 is_open() 方法，未登记" % m.name)
		return
	_modals.append(m)

## 任一登记的弹窗处于打开状态即返回 true；is_instance_valid 防护，已释放节点自动跳过。
func any_open() -> bool:
	for m in _modals:
		if is_instance_valid(m) and bool(m.call("is_open")):
			return true
	return false
