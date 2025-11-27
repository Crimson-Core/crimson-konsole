class_name GameCover3D
extends Node3D

# Типы коробок
enum BoxType {
	XBOX,
	PC
}

var game_data: GameLoader.GameData
@export var is_selected: bool = false
@export var box_type: BoxType = BoxType.XBOX
var original_scale: Vector3
var target_position: Vector3
var target_rotation: Vector3
var target_scale: Vector3
@export var model_scale_multiplier: float = 3.0 

var is_spinning: bool = false
var spin_speed: float = 60.0
var spin_duration: float = 6.0
var spin_timer: float = 0.0
var base_rotation_y: float = 0.0

# Новый параметры анимации
var is_fast_spinning: bool = false
var fast_spin_speed: float = 0.0  # Один оборот за секунду
var fast_spin_duration: float = 0.5  # Вся анимация за 1 секунду
var fast_spin_timer: float = 0.0
var fast_spin_start_position: Vector3
var fast_spin_target_position: Vector3
var fast_spin_start_rotation_y: float
var fast_spin_end_rotation_y: float
var is_animation_finished: bool = false

var is_returning: bool = false
var return_timer: float = 0.0
var return_duration: float = 0.9
var return_start_position: Vector3
var return_end_position: Vector3
var return_start_rotation_y: float
var return_end_rotation_y: float

var move_distance_x: float = 1.0

var mesh_instance: MeshInstance3D
var model_node: Node3D

var front_material: StandardMaterial3D
var back_material: StandardMaterial3D  
var spine_material: StandardMaterial3D

func _ready():
	original_scale = scale
	target_position = position
	target_rotation = rotation_degrees
	target_scale = scale
	
	load_model()

func set_box_type(type: BoxType):
	box_type = type
	if model_node:
		model_node.queue_free()
		model_node = null
		mesh_instance = null
	load_model()

func load_model():
	var model_path: String
	match box_type:
		BoxType.XBOX:
			model_path = "res://models/game_case.glb"
		BoxType.PC:
			model_path = "res://models/game_case_pc.glb"
		_:
			model_path = "res://models/game_case.glb"
			
	var model_scene = load(model_path)
	if model_scene:
		model_node = model_scene.instantiate()
		model_node.scale = Vector3.ONE * model_scale_multiplier
		add_child(model_node)
		mesh_instance = find_mesh_instance(model_node)
		if mesh_instance:
			pass
		else:
			print("MeshInstance3D не найден, создаем fallback")
			create_fallback_mesh()
	else:
		print("Модель не загружена (", model_path, "), создаем fallback")
		create_fallback_mesh()
	setup_materials()

func find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var result = find_mesh_instance(child)
		if result:
			return result
	return null

func create_fallback_mesh():
	mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	match box_type:
		BoxType.XBOX:
			box_mesh.size = Vector3(2, 3, 0.3) * model_scale_multiplier
		BoxType.PC:
			box_mesh.size = Vector3(2.5, 2.5, 0.4) * model_scale_multiplier
	mesh_instance.mesh = box_mesh
	add_child(mesh_instance)

func setup_materials():
	front_material = StandardMaterial3D.new()
	back_material = StandardMaterial3D.new()
	spine_material = StandardMaterial3D.new()
	for material in [front_material, back_material, spine_material]:
		material.albedo_color = Color.WHITE
		material.metallic = 0.1
		material.roughness = 0.7
		#material.specular = 0.5
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	front_material.albedo_color = Color(0.2, 0.4, 0.8)
	back_material.albedo_color = Color(0.8, 0.2, 0.2)
	spine_material.albedo_color = Color(0.2, 0.8, 0.2)
	if game_data:
		load_textures()
	else:
		apply_materials_to_mesh()

func set_game_data(data: GameLoader.GameData):
	game_data = data
	match game_data.box_type.to_lower():
		"xbox":
			set_box_type(BoxType.XBOX)
		"pc":
			set_box_type(BoxType.PC)
		_:
			set_box_type(BoxType.XBOX)
	if mesh_instance:
		load_textures()

func load_textures():
	if not game_data or not mesh_instance:
		print("Нет данных игры или mesh_instance")
		return
	if game_data.front != "" and FileAccess.file_exists(game_data.front):
		var front_texture = GameLoader.load_texture_from_path(game_data.front)
		if front_texture:
			front_material.albedo_texture = front_texture
			front_material.albedo_color = Color.WHITE
	if game_data.back != "" and FileAccess.file_exists(game_data.back):
		var back_texture = GameLoader.load_texture_from_path(game_data.back)
		if back_texture:
			back_material.albedo_texture = back_texture
			back_material.albedo_color = Color.WHITE
	if game_data.spine != "" and FileAccess.file_exists(game_data.spine):
		var spine_texture = GameLoader.load_texture_from_path(game_data.spine)
		if spine_texture:
			spine_material.albedo_texture = spine_texture
			spine_material.albedo_color = Color.WHITE
	apply_materials_to_mesh()

func apply_materials_to_mesh():
	if not mesh_instance or not mesh_instance.mesh:
		print("Нет mesh_instance или mesh")
		return
	var surface_count = mesh_instance.mesh.get_surface_count()
	for i in range(surface_count):
		var material: StandardMaterial3D
		match i:
			0: material = front_material
			1: material = spine_material
			2: material = back_material
		mesh_instance.set_surface_override_material(i, material)

func set_selected(selected: bool):
	is_selected = selected

func start_spin_animation():
	if is_spinning:
		return
	is_spinning = true
	spin_timer = 0.0
	base_rotation_y = target_rotation.y

func stop_spin_animation():
	if not is_spinning:
		return
	is_spinning = false
	spin_timer = 0.0
	target_rotation.y = base_rotation_y

func start_fast_spin_move_animation():
	if is_fast_spinning:
		return
	is_fast_spinning = true
	fast_spin_timer = 0.0
	is_animation_finished = false
	#fast_spin_start_position = position
	#fast_spin_target_position = fast_spin_start_position + Vector3(move_distance_x, 0, 0)
	fast_spin_start_rotation_y = rotation_degrees.y
	fast_spin_end_rotation_y = fast_spin_start_rotation_y + 470.0 # один оборот

func stop_fast_spin_move_animation():
	if not is_fast_spinning and not is_animation_finished:
		return
	is_fast_spinning = false
	is_animation_finished = false

	# Начинаем возвратную анимацию
	#is_returning = true
	#return_timer = 0.0
	#return_start_position = position
	#return_end_position = fast_spin_start_position
	#return_start_rotation_y = rotation_degrees.y
	#return_end_rotation_y = fast_spin_start_rotation_y

#func _process_return_animation(delta):
	#if not is_returning:
		#return
	#return_timer += delta
	#var progress = clamp(return_timer / return_duration, 0, 1)
	#var eased_progress = ease_in_out(progress)
	#position = return_start_position.lerp(return_end_position, eased_progress)
	#rotation_degrees.y = lerp(return_start_rotation_y, return_end_rotation_y, eased_progress)
	#var scale_factor = 1.0 + sin((1.0 - progress) * PI) * 0.1
	#scale = original_scale * scale_factor
	#if progress >= 1.0:
		#is_returning = false
		#is_animation_finished = false
		#position = return_end_position
		#rotation_degrees.y = return_end_rotation_y
		#scale = original_scale

func _process_fast_spin_animation(delta):
	if not is_fast_spinning:
		return
	fast_spin_timer += delta
	var progress = clamp(fast_spin_timer / fast_spin_duration, 0, 1)
	var eased_progress = ease_in_out(progress)
	rotation_degrees.y = lerp(fast_spin_start_rotation_y, fast_spin_end_rotation_y, eased_progress)
	position = fast_spin_start_position.lerp(fast_spin_target_position, eased_progress)
	#var scale_factor = 1.0 + sin(progress * PI) * 0.1
	#scale = original_scale * scale_factor
	if progress >= 1.0:
		is_fast_spinning = false
		fast_spin_timer = 0.0
		position = fast_spin_target_position
		rotation_degrees.y = fast_spin_end_rotation_y
		is_animation_finished = true

func ease_in_out(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)

func set_target_transform(pos: Vector3, rot: Vector3, scl: Vector3):
	target_position = pos
	target_scale = scl
	if not is_spinning and not is_animation_finished:
		target_rotation = rot
		base_rotation_y = rot.y
	else:
		base_rotation_y = rotation_degrees.y

func _process(delta):
	if is_fast_spinning:
		_process_fast_spin_animation(delta)
		return
	#if is_returning:
		#_process_return_animation(delta)
		#return
	if is_spinning:
		spin_timer += delta
		var spin_progress = spin_timer / spin_duration
		var current_spin_angle = spin_progress * 360.0
		target_rotation.y = base_rotation_y + current_spin_angle
		if spin_timer >= spin_duration:
			stop_spin_animation()
	if not is_animation_finished:
		position = position.lerp(target_position, delta * 5.0)
		rotation_degrees = rotation_degrees.lerp(target_rotation, delta * 5.0)
		scale = scale.lerp(target_scale, delta * 5.0)
