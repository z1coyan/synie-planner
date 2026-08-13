class_name SaveSystem
extends Node

## 本地存档：JSON 写入 user://saves/，负责世界序列化与玩家位姿。

signal world_reset

const SAVE_DIR := "user://saves/"
const SAVE_VERSION := 1

var world: WorldStore
var player: Player

func setup(w: WorldStore, p: Player) -> void:
	world = w
	player = p
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_dir()

func is_dirty() -> bool:
	return world != null and world.dirty

func default_save_name() -> String:
	var d := Time.get_datetime_dict_from_system()
	return "存档_%04d%02d%02d_%02d%02d" % [
		int(d["year"]), int(d["month"]), int(d["day"]),
		int(d["hour"]), int(d["minute"]),
	]

func list_saves() -> Array:
	_ensure_dir()
	var out: Array = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var fn := dir.get_next()
	while fn != "":
		if not dir.current_is_dir() and fn.ends_with(".json"):
			var path := SAVE_DIR + fn
			out.append({
				"name": fn.get_basename(),
				"file": fn,
				"path": path,
				"mtime": FileAccess.get_modified_time(path),
			})
		fn = dir.get_next()
	dir.list_dir_end()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["mtime"]) > int(b["mtime"]))
	return out

## 成功返回空字符串，失败返回中文错误。
func save_game(raw_name: String) -> String:
	if world == null:
		return "世界未就绪"
	_ensure_dir()
	var save_name := _safe_name(raw_name)
	var path := SAVE_DIR + save_name + ".json"
	var data := {
		"version": SAVE_VERSION,
		"name": save_name,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"player": _serialize_player(),
		"objects": world.serialize_placed(),
		"labels_visible": world.labels_visible,
	}
	var json := JSON.stringify(data, "\t")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "无法写入存档"
	f.store_string(json)
	f.close()
	world.dirty = false
	return ""

func load_game(path: String) -> String:
	if world == null:
		return "世界未就绪"
	if not FileAccess.file_exists(path):
		return "存档不存在"
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return "无法读取存档"
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return "存档格式无效"
	var data: Dictionary = parsed
	var objs: Array = data.get("objects", [])
	world.restore_placed(objs)
	if data.has("labels_visible"):
		var want: bool = bool(data["labels_visible"])
		if world.labels_visible != want:
			world.toggle_labels()
	_apply_player(data.get("player", {}))
	world.dirty = false
	world_reset.emit()
	return ""

func new_world() -> void:
	if world != null:
		world.clear_placed()
		world.dirty = false
	_reset_player()
	world_reset.emit()

func _serialize_player() -> Dictionary:
	if player == null or not is_instance_valid(player):
		return {}
	var rec := {
		"position": [player.global_position.x, player.global_position.y, player.global_position.z],
	}
	var rig: CameraController = player.camera_rig
	if rig != null:
		rec["yaw"] = rig.yaw
		rec["pitch"] = rig.pitch
		rec["flying"] = rig.flying
	return rec

func _apply_player(data: Dictionary) -> void:
	if player == null or not is_instance_valid(player):
		return
	var pos: Variant = data.get("position", [0.0, Config.FLOOR_TOP_OFFSET + 0.04, 10.0])
	if pos is Array and pos.size() >= 3:
		player.global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	else:
		player.global_position = Vector3(0.0, Config.FLOOR_TOP_OFFSET + 0.04, 10.0)
	player.velocity = Vector3.ZERO
	var rig: CameraController = player.camera_rig
	if rig != null:
		rig.yaw = float(data.get("yaw", 0.0))
		rig.pitch = float(data.get("pitch", 0.0))
		rig.flying = bool(data.get("flying", false))

func _reset_player() -> void:
	_apply_player({})

func _ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))

func _safe_name(raw: String) -> String:
	var s := raw.strip_edges()
	if s == "":
		s = default_save_name()
	var bad := "/\\:*?\"<>|"
	var out := ""
	for i in s.length():
		var ch := s.substr(i, 1)
		if bad.find(ch) >= 0:
			out += "_"
		else:
			out += ch
	if out.strip_edges() == "":
		return default_save_name()
	return out
