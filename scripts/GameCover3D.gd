class_name GameCover3D
extends Node3D

# Типы коробок, блядь
enum BoxType {
	XBOX,
	PC
}

var game_data: GameLoader.GameData
@export var is_selected: bool = false
@export var box_type: BoxType = BoxType.XBOX  # По умолчанию Xbox, хуле
var original_scale: Vector3
var target_position: Vector3
var target_rotation: Vector3
var target_scale: Vector3

# Увеличиваем базовый масштаб модели
@export var model_scale_multiplier: float = 3.0 

# Параметры анимации вращения
var is_spinning: bool = false
var spin_speed: float = 60.0  # градусов в секунду (медленное вращение)
var spin_duration: float = 6.0  # 6 секунд для полного оборота
var spin_timer: float = 0.0
var base_rotation_y: float = 0.0

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
	"""Устанавливает тип коробки и перезагружает модель"""
	box_type = type
	print("Меняем тип коробки на: ", "Xbox" if type == BoxType.XBOX else "PC")
	
	# Удаляем старую модель если есть
	if model_node:
		model_node.queue_free()
		model_node = null
		mesh_instance = null
	
	# Загружаем новую модель
	load_model()

func load_model():
	var model_path: String
	match box_type:
		BoxType.XBOX:
			model_path = "res://models/game_case.glb"
		BoxType.PC:
			model_path = "res://models/game_case_pc.glb"
		_:
			model_path = "res://models/game_case.glb"  # Fallback на Xbox
	
	print("Загружаем модель: ", model_path)
	
	var model_scene = load(model_path)
	if model_scene:
		model_node = model_scene.instantiate()
		# Увеличиваем базовый размер модели
		model_node.scale = Vector3.ONE * model_scale_multiplier
		add_child(model_node)
		
		# Найдем MeshInstance3D в загруженной модели
		mesh_instance = find_mesh_instance(model_node)
		
		if mesh_instance:
			print("MeshInstance3D найден, поверхностей: ", mesh_instance.mesh.get_surface_count())
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
	
	# Разные размеры для разных типов коробок
	match box_type:
		BoxType.XBOX:
			box_mesh.size = Vector3(2, 3, 0.3) * model_scale_multiplier
		BoxType.PC:
			# PC коробки обычно квадратные или почти квадратные
			box_mesh.size = Vector3(2.5, 2.5, 0.4) * model_scale_multiplier
	
	mesh_instance.mesh = box_mesh
	add_child(mesh_instance)

func setup_materials():
	# Создаем материалы
	front_material = StandardMaterial3D.new()
	back_material = StandardMaterial3D.new()
	spine_material = StandardMaterial3D.new()
	
	# Настройка базовых свойств материалов
	for material in [front_material, back_material, spine_material]:
		material.albedo_color = Color.WHITE
		material.metallic = 0.1
		material.roughness = 0.7
		material.specular = 0.5
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	# Устанавливаем разные цвета по умолчанию для лучшего различения
	front_material.albedo_color = Color(0.2, 0.4, 0.8)  # Синий
	back_material.albedo_color = Color(0.8, 0.2, 0.2)   # Красный
	spine_material.albedo_color = Color(0.2, 0.8, 0.2)  # Зеленый
	
	# Если у нас есть игровые данные, загружаем текстуры
	if game_data:
		load_textures()
	else:
		apply_materials_to_mesh()

func set_game_data(data: GameLoader.GameData):
	game_data = data
	print("установлены данные игры: ", game_data.title)
	print("пути: front=", game_data.front, ", back=", game_data.back, ", spine=", game_data.spine, ", box_type=", game_data.box_type)
	
	# синхронизируем тип коробки из game_data
	match game_data.box_type.to_lower():
		"xbox":
			set_box_type(BoxType.XBOX)
		"pc":
			set_box_type(BoxType.PC)
		_:
			print("неизвестный тип коробки: ", game_data.box_type, ", fallback на Xbox")
			set_box_type(BoxType.XBOX)
	
	# загружаем текстуры после установки модели
	if mesh_instance:
		load_textures()

func load_textures():
	if not game_data or not mesh_instance:
		print("Нет данных игры или mesh_instance")
		return
	
	print("Загрузка текстур для: ", game_data.title)
	
	# Загружаем переднюю обложку
	if game_data.front != "" and FileAccess.file_exists(game_data.front):
		var front_texture = GameLoader.load_texture_from_path(game_data.front)
		if front_texture:
			front_material.albedo_texture = front_texture
			front_material.albedo_color = Color.WHITE  # Сброс цвета для текстуры
			print("Передняя текстура загружена: ", game_data.front)
		else:
			print("Ошибка загрузки передней текстуры: ", game_data.front)
	else:
		print("Файл передней обложки не найден: ", game_data.front)
	
	# Загружаем заднюю обложку
	if game_data.back != "" and FileAccess.file_exists(game_data.back):
		var back_texture = GameLoader.load_texture_from_path(game_data.back)
		if back_texture:
			back_material.albedo_texture = back_texture
			back_material.albedo_color = Color.WHITE  # Сброс цвета для текстуры
			print("Задняя текстура загружена: ", game_data.back)
	else:
		print("Файл задней обложки не найден: ", game_data.back)
	
	# Загружаем корешок
	if game_data.spine != "" and FileAccess.file_exists(game_data.spine):
		var spine_texture = GameLoader.load_texture_from_path(game_data.spine)
		if spine_texture:
			spine_material.albedo_texture = spine_texture
			spine_material.albedo_color = Color.WHITE  # Сброс цвета для текстуры
			print("Текстура корешка загружена: ", game_data.spine)
	else:
		print("Файл корешка не найден: ", game_data.spine)
	
	apply_materials_to_mesh()

func apply_materials_to_mesh():
	if not mesh_instance or not mesh_instance.mesh:
		print("Нет mesh_instance или mesh")
		return
	
	var surface_count = mesh_instance.mesh.get_surface_count()
	print("Применение материалов, поверхностей: ", surface_count)
	
	# Применяем материалы к поверхностям
	for i in range(surface_count):
		var material: StandardMaterial3D
		match i:
			0: # Передняя часть
				material = front_material
			1: # Корешок
				material = spine_material
			2: # Задняя часть  
				material = back_material
		
		mesh_instance.set_surface_override_material(i, material)
		print("Материал ", i, " применен")

func set_selected(selected: bool):
	var was_selected = is_selected
	is_selected = selected
	
	# Запускаем анимацию вращения при выборе
	if selected and not was_selected:
		start_spin_animation()
	elif not selected and was_selected:
		stop_spin_animation()

func start_spin_animation():
	"""Запускает анимацию медленного вращения на 360 градусов"""
	if is_spinning:
		return
	
	is_spinning = true
	spin_timer = 0.0
	base_rotation_y = target_rotation.y
	print("Начинаем анимацию вращения для: ", game_data.title if game_data else "игра")

func stop_spin_animation():
	"""Останавливает анимацию вращения и возвращает к исходному углу"""
	if not is_spinning:
		return
		
	is_spinning = false
	spin_timer = 0.0
	# Возвращаем к базовому углу поворота
	target_rotation.y = base_rotation_y
	print("Остановка анимации вращения для: ", game_data.title if game_data else "игра")

func set_target_transform(pos: Vector3, rot: Vector3, scl: Vector3):
	target_position = pos
	target_scale = scl
	
	# Если не крутимся, устанавливаем целевой поворот как обычно
	if not is_spinning:
		target_rotation = rot
		base_rotation_y = rot.y
	else:
		# Если крутимся, обновляем только базовый угол
		base_rotation_y = rot.y

func _process(delta):
	# Обрабатываем анимацию вращения
	if is_spinning:
		spin_timer += delta
		
		# Вычисляем текущий угол поворота
		var spin_progress = spin_timer / spin_duration
		var current_spin_angle = spin_progress * 360.0
		
		# Устанавливаем поворот с учетом базового угла
		target_rotation.y = base_rotation_y + current_spin_angle
		
		# Останавливаем анимацию после полного оборота
		if spin_timer >= spin_duration:
			stop_spin_animation()
	
	# Плавно интерполируем к целевым значениям
	position = position.lerp(target_position, delta * 5.0)
	rotation_degrees = rotation_degrees.lerp(target_rotation, delta * 5.0)
	scale = scale.lerp(target_scale, delta * 5.0)
