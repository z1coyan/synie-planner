class_name ElementLibrary
extends RefCounted

## 元素库：参数化设备类型管理。用户填写名称与尺寸即可新增设备类型。
## 每个设备类型：{ name, size: Vector3(L,H,D), color, category }

var devices: Array = []
var current := 0

func setup() -> void:
	devices = [
		{"name": "注塑机", "size": Vector3(6.0, 3.0, 2.5), "color": Color(0.88, 0.89, 0.90), "category": "成型设备"},
		{"name": "空压机", "size": Vector3(3.0, 2.0, 2.0), "color": Color(0.80, 0.81, 0.83), "category": "动力设备"},
		{"name": "输送带", "size": Vector3(4.0, 1.2, 1.0), "color": Color(0.75, 0.76, 0.78), "category": "输送设备"},
		{"name": "机器人工位", "size": Vector3(2.0, 2.2, 2.0), "color": Color(0.84, 0.85, 0.86), "category": "自动化"},
	]
	current = 0

func current_device() -> Dictionary:
	if devices.is_empty():
		return {"name": "设备", "size": Vector3(2.0, 2.0, 2.0), "color": Color(0.78, 0.79, 0.81), "category": ""}
	return devices[current]

func count() -> int:
	return devices.size()

func get_device(i: int) -> Dictionary:
	return devices[clampi(i, 0, devices.size() - 1)]

func set_current(i: int) -> void:
	if i >= 0 and i < devices.size():
		current = i

func add_device(name: String, size: Vector3, color: Color, category: String) -> bool:
	var n := name.strip_edges()
	if n == "":
		return false
	if size.x < 0.5 or size.y < 0.5 or size.z < 0.5:
		return false
	devices.append({"name": n, "size": size, "color": color, "category": category.strip_edges()})
	current = devices.size() - 1
	return true

func remove_device(i: int) -> bool:
	if i < 0 or i >= devices.size():
		return false
	devices.remove_at(i)
	current = clampi(current, 0, devices.size() - 1)
	return true
