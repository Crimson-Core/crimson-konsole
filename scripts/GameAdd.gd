extends Control

@onready var file_dialog = $FileDialog
@onready var panel = $Panel
@onready var executable_icon = $Panel/Executable/TextureRect
@onready var front_icon = $Panel/Front/TextureRect
@onready var back_icon = $Panel/Back/TextureRect
@onready var spine_icon = $Panel/Spine/TextureRect
@onready var download_icon = $Panel/Download/TextureRect
@onready var game_name = $Panel/LineEdit
@onready var download_button = $Panel/Download
@onready var option_button = $Panel/OptionButton

# Данные о игре
@export var game_data = {
	"title": "", # Название
	"front": "", # Путь к передней обложке
	"back": "", # Путь к задней обложке
	"spine": "", # Путь к боковой обложке
	"executable": "", # Путь к исполняемому файлу игры
	"box_type": "xbox" # Тип модели коробки
}

var covers_path = "user://covers/"

# Ввод
var current_input_method = "keyboard"
var last_device_id: int
var current_button: String = ""

# Уведомления
const NotificationLogicClass = preload("res://scripts/NotificationLogic.gd")
var notification = NotificationLogicClass.new()
var notification_icon = load("res://logo.png")

func _ready():
	add_child(notification)
	
	ensure_covers_directory()
	
	option_button.add_item("Xbox 360", 0)
	option_button.add_item("PC/Steam", 1)
	option_button.item_selected.connect(_on_option_button_item_selected)

func ensure_covers_directory():
	"""Создает папку covers если её нет"""
	if not DirAccess.dir_exists_absolute(covers_path):
		var result = DirAccess.open("user://").make_dir_recursive(covers_path.get_file())
		if result == OK:
			print("Папка covers создана: ", covers_path)
		else:
			print("Ошибка создания папки covers: ", result)

func save_game_data() -> bool:
	var title = game_data["title"].strip_edges()
	if title == "":
		return false
	
	# Создаем безопасное имя файла
	var file_name = title.replace(" ", "_").replace("/", "_").replace("\\", "_")
	var invalid_chars = ["<", ">", ":", "\"", "|", "?", "*"]
	for char in invalid_chars:
		file_name = file_name.replace(char, "_")
	
	var file_path = "user://games/" + file_name + ".json"
	
	# Создаем директорию если её нет
	if not DirAccess.dir_exists_absolute("user://games/"):
		var result = DirAccess.open("user://").make_dir("games")
		if result != OK:
			print("Ошибка создания директории games: ", result)
			return false
	
	# Сохраняем файл
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(game_data)
		file.store_string(json_string)
		file.close()
		print("Игра сохранена в: ", file_path)
		return true
	else:
		print("Ошибка создания файла: ", file_path)
		return false

func get_steamboxcover_path() -> String:
	"""Возвращает путь к программе steamboxcover с улучшенной отладкой"""
	var exe_path = OS.get_executable_path()
	var exe_dir = exe_path.get_base_dir()
	
	var steamboxcover_path: String
	if OS.get_name() == "Windows":
		steamboxcover_path = exe_dir + "/steamboxcover.exe"
	else:
		steamboxcover_path = exe_dir + "/steamboxcover"
	
	# Проверяем также в текущей рабочей директории
	var current_dir = OS.get_environment("PWD")
	if current_dir == "":
		current_dir = exe_dir
	
	var alt_path: String
	if OS.get_name() == "Windows":
		alt_path = current_dir + "/steamboxcover.exe"
	else:
		alt_path = current_dir + "/steamboxcover"
	
	# Если основной путь не существует, пробуем альтернативный
	if not FileAccess.file_exists(steamboxcover_path) and FileAccess.file_exists(alt_path):
		return alt_path
	
	return steamboxcover_path

func get_spine_template_path() -> String:
	"""Возвращает путь к шаблону spine"""
	var exe_path = OS.get_executable_path()
	var exe_dir = exe_path.get_base_dir()
	return exe_dir + "/steam_spine.png"

func find_covers_for_game(game_title: String) -> Dictionary:
	"""Ищет обложки для указанной игры в папке covers"""
	var found = {}
	
	var dir = DirAccess.open(covers_path)
	if not dir:
		print("Не удалось открыть папку covers: ", covers_path)
		return found
	
	print("Ищем обложки для игры: ", game_title, " в папке: ", covers_path)
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		# Проверяем точное совпадение с названием игры
		if file_name.begins_with(game_title):
			var full_path = covers_path + file_name
			var lower_filename = file_name.to_lower()
			
			
			# Определяем тип обложки по окончанию имени файла
			if lower_filename.ends_with("_back.png") or lower_filename.ends_with("_back.jpg"):
				found["back"] = full_path
			elif lower_filename.ends_with("_spine.png") or lower_filename.ends_with("_spine.jpg"):
				found["spine"] = full_path  
			elif (lower_filename.ends_with(".png") or lower_filename.ends_with(".jpg")) and not lower_filename.contains("_"):
				# Это передняя обложка (без суффикса)
				found["front"] = full_path
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return found

func apply_found_covers(covers: Dictionary):
	"""Применяет найденные обложки к game_data"""
	var icon_path: String = "res://assets/icons/check.png"
	for cover_type in covers:
		var path = covers[cover_type]
		game_data[cover_type] = path
		
		match cover_type:
			"front": front_icon.texture = load(icon_path)
			"back": back_icon.texture = load(icon_path)
			"spine": spine_icon.texture = load(icon_path)

func _on_fs_pressed() -> void:
	current_button = "executable"
	_file_dialog()

func _on_front_pressed() -> void:
	current_button = "front"
	_file_dialog()

func _on_back_pressed() -> void:
	current_button = "back"
	_file_dialog()

func _on_spine_pressed() -> void:
	current_button = "spine"
	_file_dialog()

func _on_download_pressed() -> void:
	var title = game_name.text.strip_edges()
	if title == "":
			notification.show_notification("Введите название игры!", notification_icon)
			return
	
	var steamboxcover_path = get_steamboxcover_path()
	var spine_template_path = get_spine_template_path()
	
	if not FileAccess.file_exists(steamboxcover_path):
		notification.show_notification("Программа steamboxcover не найдена!", notification_icon)
		return
		
	var args = []
	args.append("--game")
	args.append(title)
	args.append("--output_dir")
	args.append(ProjectSettings.globalize_path(covers_path))
	
	if spine_template_path != "":
		args.append("--spine_template")
		args.append(ProjectSettings.globalize_path(spine_template_path))
		
	download_button.text = "Downloading\nСovers..."
	download_button.disabled = true
	
	await get_tree().create_timer(0.1).timeout
	
	var output = []
	var result = OS.execute(steamboxcover_path, args, output, true, false)
	
	download_button.text = "Download\nCovers"
	download_button.disabled = false
	download_icon.texture = load("res://assets/icons/check.png")
	
	if result != OK:
		notification.show_notification("Скачивание обложек провалилось!", notification_icon)
		
	if result == OK:
		notification.show_notification("Обложки загружены успешно!", notification_icon)
		
		var found_covers = find_covers_for_game(title)
		if found_covers.size() > 0:
			apply_found_covers(found_covers)

func _on_done_pressed() -> void:
	if game_name.text.strip_edges() == "":
		notification.show_notification("Введите название игры!", notification_icon)
		return
		
	game_data["title"] = game_name.text.strip_edges()
	
	if save_game_data():
		notification.show_notification("Игра сохранена успешно!", notification_icon)
		
		await get_tree().create_timer(1.5).timeout
		var main_scene = get_tree().get_first_node_in_group("main_scene")
		main_scene.load_scene("res://scenes/CoverFlow.tscn")
	else:
		notification.show_notification("Ошибка при сохранении игры!", notification_icon)

func _file_dialog():
	file_dialog.clear_filters()
	if current_button == "executable":
		if OS.get_name() == "Windows":
			file_dialog.add_filter("*.exe", "Windows Executable")
			file_dialog.add_filter("*.bat", "Batch Files")
			file_dialog.add_filter("*.cmd", "Command Files")
		elif OS.get_name() == "Linux":
			file_dialog.add_filter("*.sh", "Shell Scripts")
			file_dialog.add_filter("*.exe", "Windows Executable (Wine)")
			file_dialog.add_filter("*.x86_64", "x86 64 Bit Executable")
			file_dialog.add_filter("*", "All Files")
		elif OS.get_name() == "macOS":
			file_dialog.add_filter("*.app", "macOS Applications")
			file_dialog.add_filter("*.sh", "Shell Scripts")
			file_dialog.add_filter("*", "All Files")
	else:
		file_dialog.add_filter("*.png", "PNG Images")
		file_dialog.add_filter("*.jpg", "JPEG Images") 
		file_dialog.add_filter("*.jpeg", "JPEG Images")
		file_dialog.add_filter("*.bmp", "BMP Images")
		file_dialog.add_filter("*.webp", "WebP Images")
		
	file_dialog.popup()

func _on_file_selected(path):
	var icon_path: String = "res://assets/icons/check.png"
	match current_button:
		"executable": executable_icon.texture = load(icon_path)
		"front": front_icon.texture = load(icon_path)
		"back": back_icon.texture = load(icon_path)
		"spine": spine_icon.texture = load(icon_path)
		
	if not FileAccess.file_exists(path):
		notification.show_notification("Файл не найден!", notification_icon)
		return
	
	game_data[current_button] = path

func _on_option_button_item_selected(index):
	match index:
		0:
			game_data["box_type"] = "xbox"
		1:
			game_data["box_type"] = "pc"

func _input(event):
	var main_scene = get_tree().get_first_node_in_group("main_scene")
	var side_panel = main_scene.get_side_panel()

	if event is InputEventKey or event is InputEventMouseButton:
		if current_input_method != "keyboard":
			current_input_method = "keyboard"
			#setup_keyboard_ui()
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if current_input_method != "gamepad":
			current_input_method = "gamepad"
			#setup_gamepad_ui()
		var device_id = event.device
		last_device_id = device_id
		#update_controller_icon(device_id)
	
	if event.is_action_pressed("ui_up") or event.is_action_pressed("up_pad"):
		if side_panel.side_panel_shown:
			side_panel.side_panel_move_focus(-1)
			_trigger_vibration(1.0, 0.0, 0.1)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("down_pad"):
		if side_panel.side_panel_shown:
			side_panel.side_panel_move_focus(1)
			_trigger_vibration(1.0, 0.0, 0.1)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("accept_pad"):
		if side_panel.side_panel_shown:
			side_panel.side_panel_change_scene()
	elif event.is_action_pressed("menu_key") or event.is_action_pressed("menu_pad"):
		if not side_panel.side_panel_shown:
			side_panel.show_panel()
		else:
			side_panel.hide_panel()
			
func _trigger_vibration(weak_strength: float, strong_strength: float, duration_sec: float) -> void:
	if last_device_id < 0 or current_input_method == "keyboard":
		return
	else:
		Input.start_joy_vibration(last_device_id, weak_strength, strong_strength, duration_sec)
