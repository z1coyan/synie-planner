extends Node3D

var world: WorldStore
var camera_rig: CameraController
var builder: Builder
var wall_tool: WallTool
var floor_tile_tool: FloorTileTool
var hud: Hud
var menu: PauseMenu
var ground_grid: GroundGrid
var ground_terrain: GroundTerrain
var library: ElementLibrary
var delete_tool: DeleteTool
var select_tool: SelectTool
var library_panel: LibraryPanel
var hotbar: Hotbar
var param_bar: ParamBar
var material_panel: MaterialPanel
var tool_params_panel: ToolParamsPanel

var current_tool := "none"

func _ready() -> void:
	_build_environment()

	world = WorldStore.new()
	world.name = "WorldStore"
	add_child(world)
	var content := Node3D.new()
	content.name = "Content"
	add_child(content)
	world.setup(content, _build_ground())

	ground_terrain = GroundTerrain.new()
	ground_terrain.name = "GroundTerrain"
	add_child(ground_terrain)
	ground_terrain.setup()

	ground_grid = GroundGrid.new()
	ground_grid.name = "GroundGrid"
	add_child(ground_grid)
	ground_grid.setup()

	library = ElementLibrary.new()
	library.setup()
	_spawn_punch_mesh_preview()

	camera_rig = CameraController.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	camera_rig.setup()
	ground_terrain.set_camera(camera_rig)
	ground_grid.set_camera(camera_rig)

	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.setup()

	hotbar = Hotbar.new()
	hotbar.name = "Hotbar"
	add_child(hotbar)
	hotbar.setup()

	param_bar = ParamBar.new()
	param_bar.name = "ParamBar"
	add_child(param_bar)
	param_bar.setup()
	param_bar.action_requested.connect(_on_param_action)

	material_panel = MaterialPanel.new()
	material_panel.name = "MaterialPanel"
	add_child(material_panel)
	material_panel.setup(camera_rig)
	material_panel.confirmed.connect(_on_material_confirmed)
	material_panel.cancelled.connect(_on_material_cancelled)

	tool_params_panel = ToolParamsPanel.new()
	tool_params_panel.name = "ToolParamsPanel"
	add_child(tool_params_panel)
	tool_params_panel.setup(camera_rig)
	tool_params_panel.confirmed.connect(_on_tool_params_confirmed)
	tool_params_panel.cancelled.connect(_on_tool_params_cancelled)

	builder = Builder.new()
	builder.name = "Builder"
	add_child(builder)
	builder.setup(world, camera_rig, hud, library, self)
	builder.exit_requested.connect(_on_tool_exit)

	wall_tool = WallTool.new()
	wall_tool.name = "WallTool"
	add_child(wall_tool)
	wall_tool.setup(world, camera_rig, hud, self)
	wall_tool.exit_requested.connect(_on_tool_exit)

	floor_tile_tool = FloorTileTool.new()
	floor_tile_tool.name = "FloorTileTool"
	add_child(floor_tile_tool)
	floor_tile_tool.setup(world, camera_rig, hud, self)
	floor_tile_tool.exit_requested.connect(_on_tool_exit)

	delete_tool = DeleteTool.new()
	delete_tool.name = "DeleteTool"
	add_child(delete_tool)
	delete_tool.setup(world, camera_rig, hud)
	delete_tool.exit_requested.connect(_on_tool_exit)

	select_tool = SelectTool.new()
	select_tool.name = "SelectTool"
	add_child(select_tool)
	select_tool.setup(world, camera_rig, hud, hotbar, self)

	library_panel = LibraryPanel.new()
	library_panel.name = "LibraryPanel"
	add_child(library_panel)
	library_panel.setup(library, builder, camera_rig, hud)
	library_panel.device_selected.connect(_on_device_selected)

	menu = PauseMenu.new()
	menu.name = "PauseMenu"
	add_child(menu)
	menu.setup(camera_rig)

	_set_tool("none")

func is_material_dialog_open() -> bool:
	return material_panel != null and material_panel.is_open()

func is_any_dialog_open() -> bool:
	return (material_panel != null and material_panel.is_open()) \
			or (tool_params_panel != null and tool_params_panel.is_open())

func sync_param_bar() -> void:
	if is_any_dialog_open():
		return
	if current_tool == "column":
		param_bar.show_context("placement", "column", builder.material_id, false)
	elif current_tool == "wall":
		param_bar.show_context("placement", "wall", wall_tool.material_id, false)
	elif current_tool == "floor_tile":
		param_bar.show_context("placement", "floor_tile", floor_tile_tool.material_id, false)
	elif current_tool == "none" and select_tool != null and select_tool.wants_param_bar():
		select_tool.sync_param_bar(param_bar)
	else:
		param_bar.hide_bar()

func _on_param_action(action_id: String) -> void:
	if not param_bar.is_visible_bar():
		return
	if is_any_dialog_open():
		return
	match action_id:
		"params":
			_open_tool_params()
		"array":
			if param_bar.get_context() == "selection":
				select_tool.begin_array_from_param()
		"material":
			material_panel.show_dialog(param_bar.get_material())
			hud.set_status("选择材质后确认（Esc/取消保持原材质）")

func _open_tool_params() -> void:
	var ctx := param_bar.get_context()
	var kind := param_bar.get_kind()
	var dims: Dictionary = {}
	if ctx == "placement":
		match kind:
			"column":
				dims = builder.get_placement_dims()
			"wall":
				dims = wall_tool.get_placement_dims()
			"floor_tile":
				dims = floor_tile_tool.get_placement_dims()
	elif ctx == "selection":
		dims = select_tool.get_selected_logical_dims()
	else:
		return
	if dims.is_empty():
		return
	tool_params_panel.show_dialog(kind, dims)
	hud.set_status("编辑工具参数后确认（Esc/取消不改）")

func _on_tool_params_confirmed() -> void:
	if tool_params_panel == null:
		return
	var dims := tool_params_panel.get_values()
	var kind := tool_params_panel.get_kind()
	var ctx := param_bar.get_context()
	tool_params_panel.hide_dialog()
	if ctx == "placement":
		match kind:
			"column":
				builder.apply_placement_dims(dims)
			"wall":
				wall_tool.apply_placement_dims(dims)
			"floor_tile":
				floor_tile_tool.apply_placement_dims(dims)
		hud.set_status("已更新放置参数（F1 可再改）")
	elif ctx == "selection":
		select_tool.apply_selected_dims(dims)
		hud.set_status("已更新选中物体尺寸")
	sync_param_bar()

func _on_tool_params_cancelled() -> void:
	if tool_params_panel != null:
		tool_params_panel.hide_dialog()
	sync_param_bar()
	if current_tool == "none":
		select_tool.refresh_status_after_material()
	elif current_tool == "column":
		builder.refresh_material_hud()
	elif current_tool == "wall":
		wall_tool.refresh_material_hud()
	elif current_tool == "floor_tile":
		floor_tile_tool.refresh_material_hud()

func _on_material_confirmed() -> void:
	if material_panel == null:
		return
	var mat := material_panel.get_material()
	material_panel.hide_dialog()
	var ctx := param_bar.get_context()
	var kind := param_bar.get_kind()
	if ctx == "placement":
		match kind:
			"column":
				builder.material_id = mat
				builder.refresh_material_hud()
			"wall":
				wall_tool.material_id = mat
				wall_tool.refresh_material_hud()
			"floor_tile":
				floor_tile_tool.material_id = mat
				floor_tile_tool.refresh_material_hud()
		param_bar.set_material(mat)
		hud.set_status("材质：%s（F3 可再改）" % Config.material_label(mat))
	elif ctx == "selection":
		select_tool.apply_selected_material(mat)
		param_bar.set_material(mat)
		hud.set_status("已改材质：%s" % Config.material_label(mat))
	sync_param_bar()

func _on_material_cancelled() -> void:
	if material_panel != null:
		material_panel.hide_dialog()
	sync_param_bar()
	if current_tool == "column":
		builder.refresh_material_hud()
	elif current_tool == "wall":
		wall_tool.refresh_material_hud()
	elif current_tool == "floor_tile":
		floor_tile_tool.refresh_material_hud()
	elif current_tool == "none":
		select_tool.refresh_status_after_material()

func _on_tool_exit() -> void:
	_set_tool("none")

func _on_device_selected() -> void:
	_set_tool("device")

## 无限地面：巨型静碰撞盒，顶面与地面标高对齐，作为无限建造基准面。
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
	sky_mat.ground_horizon_color = Color(0.48, 0.46, 0.34)
	sky_mat.ground_bottom_color = Color(0.28, 0.24, 0.18)
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
	env.fog_light_color = Color(0.62, 0.60, 0.48)
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
		if is_any_dialog_open():
			return
		match event.keycode:
			KEY_0, KEY_1:
				_set_tool("none")
				get_viewport().set_input_as_handled()
			KEY_2:
				_set_tool("column")
				get_viewport().set_input_as_handled()
			KEY_3:
				_set_tool("wall")
				get_viewport().set_input_as_handled()
			KEY_4:
				_set_tool("floor_tile")
				get_viewport().set_input_as_handled()
			KEY_X:
				_set_tool("delete")
				get_viewport().set_input_as_handled()
			KEY_B:
				library_panel.toggle()
				get_viewport().set_input_as_handled()
			KEY_T:
				world.toggle_labels()
				hud.set_status("设备标签：%s" % ("开" if world.labels_visible else "关"))
				get_viewport().set_input_as_handled()

## 样机预览：在原点附近放一台冲网机，便于对照 1.7 m 视角看真实 2.2 m 柜体。
func _spawn_punch_mesh_preview() -> void:
	var fp := PunchMeshMachineParams.FOOTPRINT
	var cx := Vector3(3.5, Config.FLOOR_TOP_OFFSET + fp.y * 0.5, 4.0)
	var sample := world.place_box(
		cx, fp, PunchMeshMachineParams.COLOR_BODY, "device", 0.0, 0,
		PunchMeshMachineParams.DISPLAY_NAME,
	)
	sample.set_meta("preview", true)
	var label: Label3D = sample.get_node_or_null("Label")
	if label != null:
		label.text = "冲网机（预览）"


func _set_tool(t: String) -> void:
	if is_any_dialog_open():
		if material_panel.is_open():
			material_panel.hide_dialog()
		if tool_params_panel.is_open():
			tool_params_panel.hide_dialog()
	current_tool = t
	wall_tool.set_active(t == "wall")
	floor_tile_tool.set_active(t == "floor_tile")
	delete_tool.set_active(t == "delete")
	select_tool.set_active(t == "none")
	builder.set_tool("column" if t == "column" else "device" if t == "device" else "none")
	hotbar.set_state(t)
	sync_param_bar()
