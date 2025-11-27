extends Control
@onready var scene_container = $SceneContainer
const NotificationLogicClass = preload("res://scripts/NotificationLogic.gd")
const SidePanelClass = preload("res://scripts/nodes/SidePanel.gd")
var notification_node = NotificationLogicClass.new()
var side_panel = SidePanelClass.new()
var notification_icon = load("res://logo.png")

func _ready():
	# Добавляем главную сцену в группу для поиска
	add_to_group("main_scene")
	
	# ВАЖНО: Ждем, пока @onready переменные инициализируются
	await get_tree().process_frame
	
	# Добавляем компоненты
	add_child(notification_node)
	add_child(side_panel)
	add_child(side_panel.side_panel_instance)
	
	# Загружаем начальную сцену
	load_scene("res://scenes/CoverFlow.tscn")
	
	var selected_language = SettingsManager.get_setting("language", "en")
	TranslationServer.set_locale(selected_language)
	

# Метод для получения уведомлений дочерними сценами
func get_notification():
	return notification_node

# Метод для получения side_panel дочерними сценами
func get_side_panel():
	return side_panel

# Метод для показа панели (можно вызывать из дочерних сцен)
func show_side_panel():
	side_panel.show_panel()

# Метод для скрытия панели (можно вызывать из дочерних сцен)
func hide_side_panel():
	side_panel.hide_panel()

# Функция для получения текущей сцены из scene_container
func get_current_scene() -> Node:
	if not scene_container:
		print("Ошибка: scene_container не найден")
		return null
	
	var children = scene_container.get_children()
	if children.size() == 0:
		print("scene_container пустой")
		return null
	
	# Возвращаем первый дочерний узел (текущую сцену)
	return children[0]

# Альтернативная функция, если может быть несколько сцен
func get_all_scenes() -> Array[Node]:
	if not scene_container:
		return []
	return scene_container.get_children()

# Функция для проверки, загружена ли конкретная сцена (по имени класса или имени узла)
func is_scene_loaded(scene_name: String) -> bool:
	var current_scene = get_current_scene()
	if not current_scene:
		return false
	
	# Проверяем по имени узла
	if current_scene.name == scene_name:
		return true
	
	# Проверяем по имени класса скрипта
	if current_scene.get_script() and current_scene.get_script().get_global_name() == scene_name:
		return true
	
	return false

func load_scene(path: String) -> void:
	var scene = load(path).instantiate()
	
	# Правильно очищаем контейнер
	for child in scene_container.get_children():
		child.queue_free()
	
	# Ждем один кадр для корректного удаления
	await get_tree().process_frame
	
	scene_container.add_child(scene)

func _input(event):
	if event.is_action_pressed("lang_change"):
		var current_locale = TranslationServer.get_locale()
		
		match current_locale:
			"en":
				TranslationServer.set_locale("ja")
			"ja":
				TranslationServer.set_locale("ru")
			_: 
				TranslationServer.set_locale("en")
