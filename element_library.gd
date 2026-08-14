class_name ElementLibrary
extends RefCounted

## 元素库：参数化设备类型管理。用户填写名称与尺寸即可新增设备类型。
## 每个设备类型：{ name, size: Vector3(L,H,D), color, category }

## 默认设备：const 数组的元素是浅拷贝，复用前须对每个字典 duplicate。
const DEFAULT_DEVICES := [
	{"name": "注塑机", "size": Vector3(6.0, 3.0, 2.5), "color": Color(0.88, 0.89, 0.90), "category": "成型设备"},
	{"name": "空压机", "size": Vector3(3.0, 2.0, 2.0), "color": Color(0.80, 0.81, 0.83), "category": "动力设备"},
	{"name": "输送带", "size": Vector3(4.0, 1.2, 1.0), "color": Color(0.75, 0.76, 0.78), "category": "输送设备"},
	{"name": "机器人工位", "size": Vector3(2.0, 2.2, 2.0), "color": Color(0.84, 0.85, 0.86), "category": "自动化"},
]

var devices: Array = []
var current := 0

func setup() -> void:
	devices = _duplicate_defaults()
	current = 0

## 序列化为纯数据数组：{"name", "size": [x,y,z], "color": [r,g,b,a], "category"}。
func serialize() -> Array:
	var out: Array = []
	for d in devices:
		if not (d is Dictionary):
			continue
		var size: Vector3 = d.get("size", Vector3(2.0, 2.0, 2.0))
		var col: Color = d.get("color", Color(0.78, 0.79, 0.81))
		out.append({
			"name": String(d.get("name", "")),
			"size": [size.x, size.y, size.z],
			"color": [col.r, col.g, col.b, col.a],
			"category": String(d.get("category", "")),
		})
	return out

## 从存档数据恢复设备库：逐项校验（字典、name 非空、size ≥3 轴且每轴 ≥0.5、color 可选缺省），
## 非法项跳过；过滤后为空则恢复默认设备；成功后 devices 重建、current = 0。
func restore(arr: Array) -> void:
	var valid: Array = []
	for item in arr:
		if not (item is Dictionary):
			continue
		var d: Dictionary = item
		var name: Variant = d.get("name", "")
		if not (name is String) or (name as String).strip_edges() == "":
			continue
		var size: Variant = d.get("size", [])
		if not (size is Array) or size.size() < 3:
			continue
		var axes: Array[float] = []
		var size_ok := true
		for i in 3:
			var v: Variant = size[i]
			if v is int or v is float:
				axes.append(float(v))
			else:
				size_ok = false
				break
		if not size_ok or axes[0] < 0.5 or axes[1] < 0.5 or axes[2] < 0.5:
			continue
		var col := Color(0.78, 0.79, 0.81)
		var color: Variant = d.get("color")
		if color is Array and color.size() >= 3:
			col = Color(
				_to_axis(color[0], col.r),
				_to_axis(color[1], col.g),
				_to_axis(color[2], col.b),
				_to_axis(color[3] if color.size() >= 4 else null, col.a),
			)
		valid.append({
			"name": (name as String).strip_edges(),
			"size": Vector3(axes[0], axes[1], axes[2]),
			"color": col,
			"category": String(d.get("category", "")).strip_edges(),
		})
	if valid.is_empty():
		valid = _duplicate_defaults()
	devices = valid
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

static func _duplicate_defaults() -> Array:
	var out: Array = []
	for d in DEFAULT_DEVICES:
		out.append(d.duplicate())
	return out

static func _to_axis(v: Variant, def: float) -> float:
	if v is int or v is float:
		return float(v)
	return def
