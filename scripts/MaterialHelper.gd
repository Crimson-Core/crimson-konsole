class_name MaterialHelper
extends RefCounted

# Создает материал с текстурой для коробки игры
static func create_game_material(texture: Texture2D) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	
	if texture:
		material.albedo_texture = texture
	
	material.albedo_color = Color.WHITE
	material.metallic = 0.1
	material.roughness = 0.7
	material.specular = 0.5
	
	# Настройка для лучшего вида коробок
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.flags_unshaded = false
	material.flags_vertex_lighting = false
	
	return material

# Создает материал с цветом по умолчанию
static func create_default_material(color: Color = Color.GRAY) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	
	material.albedo_color = color
	material.metallic = 0.0
	material.roughness = 0.8
	material.specular = 0.3
	
	return material

# Применяет материалы к MeshInstance3D в зависимости от количества поверхностей
static func apply_materials_to_game_box(mesh_instance: MeshInstance3D, 
										front_texture: Texture2D = null,
										back_texture: Texture2D = null, 
										spine_texture: Texture2D = null):
	
	var surface_count = mesh_instance.get_surface_override_material_count()
	
	# Создаем материалы
	var front_mat = create_game_material(front_texture)
	var back_mat = create_game_material(back_texture) 
	var spine_mat = create_game_material(spine_texture)
	var default_mat = create_default_material(Color.WHITE)
	
	# Применяем материалы в зависимости от модели
	match surface_count:
		0:
			# Если нет поверхностей, устанавливаем общий материал
			mesh_instance.material_override = front_mat
		1:
			# Одна поверхность - используем переднюю обложку
			mesh_instance.set_surface_override_material(0, front_mat)
		2:
			# Две поверхности - передняя и задняя
			mesh_instance.set_surface_override_material(0, front_mat)
			mesh_instance.set_surface_override_material(1, back_mat)
		3:
			# Три поверхности - передняя, задняя и корешок
			mesh_instance.set_surface_override_material(0, front_mat)
			mesh_instance.set_surface_override_material(1, back_mat)
			mesh_instance.set_surface_override_material(2, spine_mat)
		_:
			# Больше поверхностей - назначаем по порядку
			mesh_instance.set_surface_override_material(0, front_mat)
			mesh_instance.set_surface_override_material(1, back_mat)
			mesh_instance.set_surface_override_material(2, spine_mat)
			
			# Остальные поверхности получают материал по умолчанию
			for i in range(3, surface_count):
				mesh_instance.set_surface_override_material(i, default_mat)

# Создает анимированный эффект свечения для выбранной игры
static func create_glow_effect(material: StandardMaterial3D, intensity: float = 1.5):
	material.emission_enabled = true
	material.emission_energy = intensity
	material.emission = Color(0.2, 0.2, 0.8, 1.0)

# Убирает эффект свечения
static func remove_glow_effect(material: StandardMaterial3D):
	material.emission_enabled = false
	material.emission_energy = 0.0