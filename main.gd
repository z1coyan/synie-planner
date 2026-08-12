extends Node3D

var world: WorldStore
var camera_rig: CameraController
var builder: Builder
var wall_tool: WallTool
var hud: Hud
var menu: PauseMenu
var floors: FloorManager
var library: ElementLibrary
var opening_tool: OpeningTool
var delete_tool: DeleteTool
var library_panel: LibraryPanel
var hotbar: Hotbar

var current_tool := "column"

func _ready() -> void:
	_build_environment()

	world = WorldStore.new()
	world.name = "WorldStore"
	add_child(world)
	var content := Node3D.new()
	content.name = "Content"
	add_child(content)
	world.setup(content, _build_ground())

	floors = FloorManager.new()
	floors.name = "FloorManager"
	add_child(floors)
	floors.setup(world)

	library = ElementLibrary.new()
	library.setup()

	camera_rig = CameraController.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	camera_rig.setup()
	floors.set_camera(camera_rig)

	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.setup()

	hotbar = Hotbar.new()
	hotbar.name = "Hotbar"
	add_child(hotbar)
	hotbar.setup()

	builder = Builder.new()
	builder.name = "Builder"
	add_child(builder)
	builder.setup(world, camera_rig, hud, floors, library)

	wall_tool = WallTool.new()
	wall_tool.name = "WallTool"
	add_child(wall_tool)
	wall_tool.setup(world, camera_rig, hud, floors)

	opening_tool = OpeningTool.new()
	opening_tool.name = "OpeningTool"
	add_child(opening_tool)
	opening_tool.setup(world, camera_rig, hud, floors)

	delete_tool = DeleteTool.new()
	delete_tool.name = "DeleteTool"
	add_child(delete_tool)
	delete_tool.setup(world, camera_rig, hud)
	delete_tool.exit_requested.connect(_on_delete_exit)

	library_panel = LibraryPanel.new()
	library_panel.name = "LibraryPanel"
	add_child(library_panel)
	library_panel.setup(library, builder, camera_rig, hud)

	menu = PauseMenu.new()
	menu.name = "PauseMenu"
	add_child(menu)
	menu.setup(camera_rig)

	floors.floor_changed.connect(_on_floor_changed)
	floors.show_all_changed.connect(_on_show_all_changed)

	_set_tool("column")
	_update_floor_hud()

func _on_floor_changed(index: int) -> void:
	wall_tool.cancel()
	delete_tool.cancel()
	_update_floor_hud()

func _on_delete_exit() -> void:
	_set_tool("none")

func _on_show_all_changed(value: bool) -> void:
	_update_floor_hud()

func _update_floor_hud() -> void:
	hud.set_floor_text("楼层: %dF   显示: %s" % [floors.current_floor + 1, "全部" if floors.show_all else "单层"])
	hotbar.set_state(current_tool, floors.current_floor, floors.show_all)

## 无限地面：巨型静碰撞盒，顶面与 1F 标高对齐，作为无限建造基准面。
func _build_ground() -> StaticBody3D:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = 1
	ground.collision_mask = 0
	var shape := BoxShape3D.new()
	var thickness := 1.0
	shape.size = Vector3(Config.GROUND_EXTENT, thickness, Config.GROUND_EXTENT)
	ground.position.y = Config.FLOOR_TOP_OFFSET - thickness * 0.5
	var cs := CollisionShape3D.new()
	cs.name = "Collision"
	cs.shape = shape
	ground.add_child(cs)
	ground.set_meta("kind", "ground")
	ground.set_meta("size", shape.size)
	add_child(ground)
	return ground

func _build_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.72, 0.74, 0.77)
	sky_mat.sky_horizon_color = Color(0.92, 0.93, 0.94)
	sky_mat.ground_horizon_color = Color(0.88, 0.89, 0.90)
	sky_mat.ground_bottom_color = Color(0.70, 0.71, 0.73)
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.1
	env.glow_bloom = 0.0
	env.glow_strength = 0.8
	env.ssao_enabled = true
	env.ssao_intensity = 2.2
	env.ssao_radius = 0.5
	env.ssao_sharpness = 0.9
	env.ssao_light_affect = 0.3
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.85, 0.86, 0.87)
	env.fog_depth_begin = 40.0
	env.fog_depth_end = 260.0
	env.fog_depth_curve = 1.0
	env.fog_sky_affect = 0.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var vignette := Vignette.new()
	vignette.name = "Vignette"
	add_child(vignette)
	vignette.setup()

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_color = Color(1.0, 0.98, 0.93)
	sun.light_energy = 1.05
	sun.light_angular_distance = 4.0
	sun.shadow_enabled = true
	sun.shadow_blur = 2.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(sun)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if library_panel.is_open():
			return
		match event.keycode:
			KEY_0:
				_set_tool("none")
				get_viewport().set_input_as_handled()
			KEY_1:
				_set_tool("wall")
				get_viewport().set_input_as_handled()
			KEY_2:
				_set_tool("column")
				get_viewport().set_input_as_handled()
			KEY_3:
				_set_tool("device")
				get_viewport().set_input_as_handled()
			KEY_4:
				_set_tool("opening")
				get_viewport().set_input_as_handled()
			KEY_X:
				_set_tool("delete")
				get_viewport().set_input_as_handled()
			KEY_5:
				floors.set_floor(0)
				get_viewport().set_input_as_handled()
			KEY_6:
				floors.set_floor(1)
				get_viewport().set_input_as_handled()
			KEY_7:
				floors.set_floor(2)
				get_viewport().set_input_as_handled()
			KEY_8:
				floors.set_floor(3)
				get_viewport().set_input_as_handled()
			KEY_9:
				floors.toggle_show_all()
				get_viewport().set_input_as_handled()
			KEY_B:
				library_panel.toggle()
				get_viewport().set_input_as_handled()
			KEY_T:
				world.toggle_labels()
				hud.set_status("设备标签：%s" % ("开" if world.labels_visible else "关"))
				get_viewport().set_input_as_handled()

func _set_tool(t: String) -> void:
	current_tool = t
	wall_tool.set_active(t == "wall")
	opening_tool.set_active(t == "opening")
	delete_tool.set_active(t == "delete")
	builder.set_tool("column" if t == "column" else "device" if t == "device" else "none")
	hotbar.set_state(t, floors.current_floor, floors.show_all)
	if t == "none":
		hud.set_status("无工具（0-9 快捷栏选择工具与楼层）")
