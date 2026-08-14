extends SceneTree

## 渲染探针（开发工具，不参与游戏运行）：
## 窗口化跑主场景、程序化布景，多角度截图 + 打印 FPS，用于光照/渲染效果检查。
## 用法：
##   Godot --path . --script res://tests/render_probe.gd --resolution 1280x720 --log-file <log>
## 输出：res://tools/render_probe_out/shot_fp.png / shot_top.png / shot_hero.png
## 依赖：本机 GPU 与窗口能力（窗口被移到屏幕外，不打扰用户）。

var _frame := 0
var _main: Node3D
var _world: WorldStore
var _player: Node3D
var _rig: CameraController

func _initialize() -> void:
	if root is Window:
		var win := root as Window
		win.position = Vector2i(-5000, -5000)
		win.title = "synie render probe"
	var packed := load("res://main.tscn") as PackedScene
	if packed == null:
		printerr("render_probe: 无法加载 main.tscn")
		quit(1)
		return
	_main = packed.instantiate() as Node3D
	root.add_child(_main)

func _process(_delta: float) -> bool:
	_frame += 1
	match _frame:
		8:
			_build_diorama()
		16:
			_shot("shot_fp")
			_setup_top()
		26:
			_shot("shot_top")
			_setup_hero()
		36:
			_shot("shot_hero")
		48:
			print("PROBE_FPS=", Engine.get_frames_per_second())
			print("PROBE_DONE")
			quit(0)
	return false

## 程序化布景：地板 + 两堵墙（带门/窗洞）+ 柱 + 楼梯 + 设备。
func _build_diorama() -> void:
	_world = _main.get_node("WorldStore") as WorldStore
	_player = _main.get_node("Player") as Node3D
	_rig = _player.get_node("CameraRig") as CameraController
	# 地板（顶面 0.6）
	_world.place_box(Vector3(0.0, 0.44, 0.0), Vector3(14.0, 0.32, 11.0),
		Config.COLOR_FLOOR_CONCRETE, "floor_tile", 0.0, 0, "", "concrete")
	# 南墙（沿 X）
	var wall_a := _world.place_box(Vector3(0.0, 3.09, -5.5), Vector3(14.04, 5.02, 0.2),
		Config.COLOR_WALL, "wall", 0.0, 0, "", "concrete")
	# 西墙（沿 Z）
	_world.place_box(Vector3(-7.0, 3.09, 0.0), Vector3(11.04, 5.02, 0.2),
		Config.COLOR_WALL, "wall", PI * 0.5, 0, "", "concrete")
	# 门洞 / 窗洞
	_world.add_wall_opening(wall_a, "window", 1.6, 1.3, 0.9, 3.0)
	_world.add_wall_opening(wall_a, "window", 1.2, 1.2, 0.9, -1.2)
	_world.add_wall_opening(wall_a, "door", 1.0, 2.1, 0.0, -3.2)
	# 柱
	_world.place_box(Vector3(6.4, 3.10, -5.2), Vector3(0.44, 5.04, 0.44),
		Config.COLOR_COLUMN, "column", 0.0, 0, "", "concrete")
	_world.place_box(Vector3(-6.4, 3.10, 4.6), Vector3(0.44, 5.04, 0.44),
		Config.COLOR_COLUMN, "column", 0.0, 0, "", "concrete")
	# 楼梯（局部 -Z 上行）
	_world.place_stair(Vector3(-3.2, 3.1, 2.2), 1.4, 8.0, 5.0, 0.0, "concrete")
	# 设备
	_world.place_box(Vector3(4.2, 1.6, 2.6), Vector3(3.0, 2.0, 2.0),
		Config.COLOR_DEVICE, "device", 0.4, 0, "注塑机", "")
	_world.place_box(Vector3(5.2, 1.2, -2.2), Vector3(2.0, 1.2, 1.0),
		Config.COLOR_DEVICE, "device", 0.0, 0, "机器人工位", "")
	for o in _world.placed:
		print("PLACED kind=", o.get_meta("kind"), " pos=", o.global_position, " size=", o.get_meta("size"))
	print("PLACED_N=", _world.placed.size())
	_setup_fp()

## 视角 1：第一人称，从东南看向西北墙角（门窗洞 + 柱 + 楼梯入画）。
func _setup_fp() -> void:
	_rig.mode = "fp"
	_rig._apply_mode()
	_player.global_position = Vector3(1.0, 0.36, 3.0)
	_rig.yaw = 0.55
	_rig.pitch = -0.08

## 视角 2：俯视正交，看布局与阴影方向。
func _setup_top() -> void:
	_player.visible = false
	_rig.mode = "top"
	_rig.top_height = 20.0
	_rig._apply_mode()
	_player.global_position = Vector3(0.0, 0.36, 0.0)

## 视角 3：运行时正对太阳（读取 Sun 节点方向），暖光扫过墙转角、太阳光晕入画。
func _setup_hero() -> void:
	_player.visible = true
	_rig.mode = "fp"
	_rig._apply_mode()
	_player.global_position = Vector3(7.5, 0.36, -4.0)
	var sun := _main.get_node("EnvironmentSystem/Sun") as DirectionalLight3D
	var to_sun := sun.global_transform.basis.z
	var h := Vector2(to_sun.x, to_sun.z).length()
	_rig.yaw = atan2(-to_sun.x, -to_sun.z)
	_rig.pitch = atan2(to_sun.y, h) - 0.28  # 太阳略高于画面中心上方

func _shot(id: String) -> void:
	var out_dir := "res://tools/render_probe_out"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var img := (root as Window).get_texture().get_image()
	var path := out_dir + "/" + id + ".png"
	var err := img.save_png(path)
	print("PROBE_SHOT ", id, " err=", err)
