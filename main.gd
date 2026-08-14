extends Node3D

var world: WorldStore
var player: Player
var camera_rig: CameraController
var builder: Builder
var wall_tool: WallTool
var floor_tile_tool: FloorTileTool
var stair_tool: StairTool
var door_tool: OpeningTool
var window_tool: OpeningTool
var floor_opening_tool: FloorOpeningTool
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
var save_system: SaveSystem
var modal: ModalManager  # 弹窗集中管理器：统一登记各弹窗面板
var _render: EnvironmentSystem  # 光照/天空/后期渲染系统

var current_tool := "none"

## 放置工具注册表：{id, kind, tool}，按数字键顺序注册。
## device 复用 builder 的 column 项；delete/none 不注册（各自单独管理）。
var _registry: Array[Dictionary] = []

func _ready() -> void:
	_render = EnvironmentSystem.new()
	_render.name = "EnvironmentSystem"
	add_child(_render)
	_render.setup()

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

	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.setup(self)
	camera_rig = player.camera_rig
	ground_terrain.set_camera(camera_rig)
	process_physics_priority = 20

	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.setup()
	player.hud = hud

	hotbar = Hotbar.new()
	hotbar.name = "Hotbar"
	add_child(hotbar)
	hotbar.setup()

	param_bar = ParamBar.new()
	param_bar.name = "ParamBar"
	add_child(param_bar)
	param_bar.setup()
	param_bar.action_requested.connect(_on_param_action)

	modal = ModalManager.new()
	modal.name = "ModalManager"
	add_child(modal)

	material_panel = MaterialPanel.new()
	material_panel.name = "MaterialPanel"
	add_child(material_panel)
	material_panel.setup(camera_rig)
	material_panel.confirmed.connect(_on_material_confirmed)
	material_panel.cancelled.connect(_on_material_cancelled)
	modal.register(material_panel)

	tool_params_panel = ToolParamsPanel.new()
	tool_params_panel.name = "ToolParamsPanel"
	add_child(tool_params_panel)
	tool_params_panel.setup(camera_rig)
	tool_params_panel.confirmed.connect(_on_tool_params_confirmed)
	tool_params_panel.cancelled.connect(_on_tool_params_cancelled)
	modal.register(tool_params_panel)

	builder = Builder.new()
	builder.name = "Builder"
	add_child(builder)
	builder.setup(world, camera_rig, hud, library, self)
	builder.set_modal(modal)
	builder.exit_requested.connect(_on_tool_exit)

	wall_tool = WallTool.new()
	wall_tool.name = "WallTool"
	add_child(wall_tool)
	wall_tool.setup(world, camera_rig, hud, self)
	wall_tool.set_modal(modal)
	wall_tool.exit_requested.connect(_on_tool_exit)

	floor_tile_tool = FloorTileTool.new()
	floor_tile_tool.name = "FloorTileTool"
	add_child(floor_tile_tool)
	floor_tile_tool.setup(world, camera_rig, hud, self)
	floor_tile_tool.set_modal(modal)
	floor_tile_tool.exit_requested.connect(_on_tool_exit)

	stair_tool = StairTool.new()
	stair_tool.name = "StairTool"
	add_child(stair_tool)
	stair_tool.setup(world, camera_rig, hud, self)
	stair_tool.set_modal(modal)
	stair_tool.exit_requested.connect(_on_tool_exit)

	door_tool = OpeningTool.new()
	door_tool.name = "DoorTool"
	add_child(door_tool)
	door_tool.setup(world, camera_rig, hud, self, "door")
	door_tool.set_modal(modal)
	door_tool.exit_requested.connect(_on_tool_exit)

	window_tool = OpeningTool.new()
	window_tool.name = "WindowTool"
	add_child(window_tool)
	window_tool.setup(world, camera_rig, hud, self, "window")
	window_tool.set_modal(modal)
	window_tool.exit_requested.connect(_on_tool_exit)

	floor_opening_tool = FloorOpeningTool.new()
	floor_opening_tool.name = "FloorOpeningTool"
	add_child(floor_opening_tool)
	floor_opening_tool.setup(world, camera_rig, hud, self)
	floor_opening_tool.set_modal(modal)
	floor_opening_tool.exit_requested.connect(_on_tool_exit)

	delete_tool = DeleteTool.new()
	delete_tool.name = "DeleteTool"
	add_child(delete_tool)
	delete_tool.setup(world, camera_rig, hud)
	delete_tool.exit_requested.connect(_on_tool_exit)

	select_tool = SelectTool.new()
	select_tool.name = "SelectTool"
	add_child(select_tool)
	select_tool.setup(world, camera_rig, hud, hotbar, self, modal)

	library_panel = LibraryPanel.new()
	library_panel.name = "LibraryPanel"
	add_child(library_panel)
	library_panel.setup(library, builder, camera_rig, hud)
	library_panel.device_selected.connect(_on_device_selected)
	modal.register(library_panel)

	save_system = SaveSystem.new()
	save_system.name = "SaveSystem"
	add_child(save_system)
	save_system.setup(world, player, library)
	save_system.world_reset.connect(_on_world_reset)

	menu = PauseMenu.new()
	menu.name = "PauseMenu"
	add_child(menu)
	menu.setup(camera_rig, save_system)

	_build_registry()
	_set_tool("none")

## 任一登记弹窗（材质 / 工具参数 / 元素库 / 阵列）打开即返回 true；方法保留，对外兼容。
func is_any_dialog_open() -> bool:
	return modal != null and modal.any_open()

func sync_param_bar() -> void:
	if is_any_dialog_open():
		return
	if current_tool == "none" and select_tool != null and select_tool.wants_param_bar():
		select_tool.sync_param_bar(param_bar)
		return
	# placement 分支：按注册表 id 匹配（device 无注册项 → 隐藏，与原行为一致）
	for entry in _registry:
		if String(entry["id"]) == current_tool:
			param_bar.show_context("placement", String(entry["kind"]), entry["tool"].get_material_id(), false)
			return
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
		var tool: Variant = _placement_tool_for(kind)
		if tool == null:
			return
		dims = tool.get_placement_dims()
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
		var tool: Variant = _placement_tool_for(kind)
		if tool != null:
			tool.apply_placement_dims(dims)
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
	else:
		# placement：统一走 refresh_param_hud（开洞类刷新 HUD；其余沿用材质刷新）
		var tool: Variant = _placement_tool_for(current_tool)
		if tool != null:
			tool.refresh_param_hud()

func _on_material_confirmed() -> void:
	if material_panel == null:
		return
	var mat := material_panel.get_material()
	material_panel.hide_dialog()
	var ctx := param_bar.get_context()
	var kind := param_bar.get_kind()
	if ctx == "placement":
		# 仅支持材质的类型写材质并刷新；开洞类跳过（set_material_id 忽略）
		if Kinds.has_material(kind):
			var tool: Variant = _placement_tool_for(kind)
			if tool != null:
				tool.set_material_id(mat)
				tool.refresh_material_hud()
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
	if current_tool == "none":
		select_tool.refresh_status_after_material()
	elif Kinds.has_material(current_tool):
		var tool: Variant = _placement_tool_for(current_tool)
		if tool != null:
			tool.refresh_material_hud()

func _on_world_reset() -> void:
	_set_tool("none")
	if hud != null:
		hud.set_status("场景已更新")

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
			KEY_5:
				_set_tool("stair")
				get_viewport().set_input_as_handled()
			KEY_6:
				_set_tool("door")
				get_viewport().set_input_as_handled()
			KEY_7:
				_set_tool("window")
				get_viewport().set_input_as_handled()
			KEY_8:
				_set_tool("floor_hole")
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

func _set_tool(t: String) -> void:
	if is_any_dialog_open():
		if material_panel.is_open():
			material_panel.hide_dialog()
		if tool_params_panel.is_open():
			tool_params_panel.hide_dialog()
	current_tool = t
	# 注册表驱动激活（builder 无 set_active，由下方 set_tool 单独控制）
	for entry in _registry:
		var tool_node: Node = entry["tool"]
		if tool_node.has_method("set_active"):
			tool_node.set_active(String(entry["id"]) == t)
	delete_tool.set_active(t == "delete")
	select_tool.set_active(t == "none")
	builder.set_tool("column" if t == "column" else "device" if t == "device" else "none")
	hotbar.set_state(t)
	sync_param_bar()
	if not Kinds.is_placement(t):
		ground_grid.set_patch_visible(false)

## 注册放置工具：id 为工具栏/按键标识，kind 为物体类型（当前两者一致）。
func _build_registry() -> void:
	_register_tool("column", "column", builder)
	_register_tool("wall", "wall", wall_tool)
	_register_tool("floor_tile", "floor_tile", floor_tile_tool)
	_register_tool("stair", "stair", stair_tool)
	_register_tool("door", "door", door_tool)
	_register_tool("window", "window", window_tool)
	_register_tool("floor_hole", "floor_hole", floor_opening_tool)

func _register_tool(id: String, kind: String, tool: Node) -> void:
	_registry.append({"id": id, "kind": kind, "tool": tool})

## 按注册 id 查工具；device 复用 builder 的 column 项。未注册返回 null。
func _tool_by_id(id: String) -> Variant:
	var target := "column" if id == "device" else id
	for entry in _registry:
		if String(entry["id"]) == target:
			return entry["tool"]
	return null

## 按物体类型查放置工具（device 复用 builder 的 column 项）。未注册返回 null。
func _placement_tool_for(kind: String) -> Variant:
	return _tool_by_id(kind)

## 放置工具激活且有有效瞄准时，把局部网格贴在物体脚点下；否则立刻隐藏。
func _physics_process(_delta: float) -> void:
	_sync_placement_grid()

func _sync_placement_grid() -> void:
	if ground_grid == null:
		return
	if is_any_dialog_open() or not Kinds.is_placement(current_tool):
		ground_grid.set_patch_visible(false)
		return
	var tool: Variant = _placement_tool_for(current_tool)
	if tool == null:
		ground_grid.set_patch_visible(false)
		return
	var origin: Variant = tool.get_grid_origin()
	if origin == null:
		ground_grid.set_patch_visible(false)
		return
	var extent := 6.5
	if tool.has_method("get_grid_extent"):
		extent = tool.get_grid_extent()
	var p: Vector3 = origin
	ground_grid.set_origin(p)
	ground_grid.set_patch_size(extent)
	ground_grid.set_patch_visible(true)
