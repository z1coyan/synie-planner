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
var library_panel: LibraryPanel
var ground_body: StaticBody3D

func _ready() -> void:
	_build_environment()
	ground_body = _build_ground()

	world = WorldStore.new()
	world.name = "WorldStore"
	add_child(world)
	var content := Node3D.new()
	content.name = "Content"
	add_child(content)
	world.setup(content, ground_body)

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

	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.setup()

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
	_update_floor_hud()

func _on_show_all_changed(value: bool) -> void:
	_update_floor_hud()

func _update_floor_hud() -> void:
	hud.set_floor_text("楼层: %dF   显示: %s" % [floors.current_floor + 1, "全部" if floors.show_all else "单层"])

func _build_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.35, 0.5, 0.7)
	sky_mat.sky_horizon_color = Color(0.6, 0.68, 0.75)
	sky_mat.ground_horizon_color = Color(0.45, 0.45, 0.45)
	sky_mat.ground_bottom_color = Color(0.2, 0.2, 0.2)
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.shadow_enabled = true
	sun.light_energy = 1.2
	add_child(sun)

func _build_ground() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = 2
	body.collision_mask = 0

	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(Config.GRID_EXTENT * 2.0, Config.GRID_EXTENT * 2.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Config.COLOR_GROUND
	mat.roughness = 1.0
	pm.material = mat
	mi.mesh = pm
	mi.rotation_degrees.x = -90.0
	body.add_child(mi)

	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(Config.GRID_EXTENT * 2.0, 0.5, Config.GRID_EXTENT * 2.0)
	cs.shape = bs
	cs.position.y = -0.25
	body.add_child(cs)

	add_child(body)
	_build_grid()
	return body

func _build_grid() -> void:
	var minor := _line_mat(Config.COLOR_GRID_MINOR)
	var major := _line_mat(Config.COLOR_GRID_MAJOR)
	var ext := Config.GRID_EXTENT
	var step := Config.GRID
	var mstep := Config.GRID_MAJOR
	var im := ImmediateMesh.new()

	im.surface_begin(Mesh.PRIMITIVE_LINES, minor)
	_build_minor_lines(im, ext, step, mstep)
	im.surface_end()
	im.surface_begin(Mesh.PRIMITIVE_LINES, major)
	_build_major_lines(im, ext, step, mstep)
	im.surface_end()

	var mi := MeshInstance3D.new()
	mi.name = "Grid"
	mi.mesh = im
	mi.position.y = 0.002
	add_child(mi)

func _build_minor_lines(im: ImmediateMesh, ext: float, step: float, mstep: float) -> void:
	var x := -ext
	while x <= ext + 0.001:
		if absf(fmod(x, mstep)) > 0.001:
			im.surface_add_vertex(Vector3(x, 0.0, -ext))
			im.surface_add_vertex(Vector3(x, 0.0, ext))
		x += step
	var z := -ext
	while z <= ext + 0.001:
		if absf(fmod(z, mstep)) > 0.001:
			im.surface_add_vertex(Vector3(-ext, 0.0, z))
			im.surface_add_vertex(Vector3(ext, 0.0, z))
		z += step

func _build_major_lines(im: ImmediateMesh, ext: float, step: float, mstep: float) -> void:
	var x := -ext
	while x <= ext + 0.001:
		if absf(fmod(x, mstep)) <= 0.001:
			im.surface_add_vertex(Vector3(x, 0.0, -ext))
			im.surface_add_vertex(Vector3(x, 0.0, ext))
		x += step
	var z := -ext
	while z <= ext + 0.001:
		if absf(fmod(z, mstep)) <= 0.001:
			im.surface_add_vertex(Vector3(-ext, 0.0, z))
			im.surface_add_vertex(Vector3(ext, 0.0, z))
		z += step

func _line_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	return m

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if library_panel.is_open():
			return
		match event.keycode:
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
	wall_tool.set_active(t == "wall")
	opening_tool.set_active(t == "opening")
	builder.set_tool("column" if t == "column" else "device" if t == "device" else "none")
	if t == "none":
		hud.set_status("无工具（Tab 视角切换，1 墙 2 柱 3 设备 4 开洞，5-8 楼层）")
