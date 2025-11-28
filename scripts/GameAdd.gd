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
	"id": "", # Уникальный идентификатор игры
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

func generate_unique_id() -> String:
	"""Генерирует уникальный идентификатор для игры"""
	var timestamp = Time.get_unix_time_from_system()
	var random_part = randi() % 999999
	return "game_%d_%06d" % [timestamp, random_part]

func save_game_data() -> bool:
	var title = game_data["title"].strip_edges()
	if title == "":
		return false
	
	# Генерируем ID если его нет
	if game_data["id"] == "":
		game_data["id"] = generate_unique_id()
	
	var file_path = "user://games/" + game_data["id"] + ".json"
	
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

func reset_form():
	"""Очищает всю форму после успешного сохранения"""
	# Очищаем game_data
	game_data = {
		"id": "",
		"title": "",
		"front": "",
		"back": "",
		"spine": "",
		"executable": "",
		"box_type": "xbox"
	}
	
	# Очищаем поле ввода
	game_name.text = ""
	
	var plus_icon = load("res://assets/kenney_input-prompts_1.4/Nintendo Switch 2/Default/switch_button_plus.png")
	var download_icon_path = load("res://assets/icons/download.png")
	executable_icon.texture = plus_icon
	front_icon.texture = plus_icon
	back_icon.texture = plus_icon
	spine_icon.texture = plus_icon
	download_icon.texture = download_icon_path
	
	# Сбрасываем выбор типа коробки
	option_button.select(0)
	
	# Разблокируем кнопку загрузки если была заблокирована
	download_button.disabled = false
	download_button.text = tr("GA_COVERS_BT")
	
	print("Форма очищена")

func load_game_by_id(game_id: String) -> Dictionary:
	"""
	Загружает данные игры по её ID
	
	Возвращает: Словарь с данными игры или пустой словарь при ошибке
	"""
	var file_path = "user://games/" + game_id + ".json"
	
	if not FileAccess.file_exists(file_path):
		print("Игра с ID не найдена: ", game_id)
		return {}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("Ошибка открытия файла: ", file_path)
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		print("Ошибка парсинга JSON: ", file_path)
		return {}
	
	return json.data

func find_game_id_by_title(game_title: String) -> String:
	"""
	Находит ID игры по её названию
	
	Возвращает: ID игры или пустую строку если не найдена
	"""
	var dir = DirAccess.open("user://games/")
	if not dir:
		print("Не удалось открыть папку games")
		return ""
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".json"):
			var file_path = "user://games/" + file_name
			var file = FileAccess.open(file_path, FileAccess.READ)
			
			if file:
				var json_string = file.get_as_text()
				file.close()
				
				var json = JSON.new()
				if json.parse(json_string) == OK:
					var data = json.data
					if data.has("title") and data["title"] == game_title:
						dir.list_dir_end()
						return data["id"]
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return ""

func update_game_data_by_id(game_id: String, updated_data: Dictionary) -> bool:
	"""
	Обновляет информацию о игре по её ID
	
	Параметры:
	- game_id: Уникальный идентификатор игры
	- updated_data: Словарь с обновляемыми данными
	
	Возвращает: true при успешном обновлении, false при ошибке
	"""
	var file_path = "user://games/" + game_id + ".json"
	
	# Проверяем существование файла
	if not FileAccess.file_exists(file_path):
		print("Игра с ID не найдена: ", game_id)
		#notification.show_notification(tr("NTF_GAMENOTFOUND"), notification_icon)
		return false
	
	# Загружаем существующие данные
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("Ошибка открытия файла: ", file_path)
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		print("Ошибка парсинга JSON: ", file_path)
		return false
	
	var existing_data = json.data
	
	# Обновляем только предоставленные поля (кроме ID)
	for key in updated_data.keys():
		if key == "id":
			print("Предупреждение: изменение ID запрещено")
			continue
		if key in existing_data:
			existing_data[key] = updated_data[key]
		else:
			print("Предупреждение: неизвестное поле '", key, "'")
	
	# Сохраняем обновленные данные
	file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		print("Ошибка записи файла: ", file_path)
		return false
	
	var updated_json_string = JSON.stringify(existing_data)
	file.store_string(updated_json_string)
	file.close()
	
	print("Игра обновлена: ", game_id)
	return true

func update_game_data_by_title(game_title: String, updated_data: Dictionary) -> bool:
	"""
	Обновляет информацию о игре по её названию
	
	Параметры:
	- game_title: Название игры для поиска
	- updated_data: Словарь с обновляемыми данными
	
	Возвращает: true при успешном обновлении, false при ошибке
	"""
	var game_id = find_game_id_by_title(game_title)
	if game_id == "":
		print("Игра не найдена по названию: ", game_title)
		return false
	
	return update_game_data_by_id(game_id, updated_data)

func delete_game_by_id(game_id: String) -> bool:
	var file_path = "user://games/" + game_id + ".json"

	# Проверяем существование файла
	if not FileAccess.file_exists(file_path):
		print("Игра с таким ID не найдена: ", game_id)
		return false

	# Пытаемся удалить файл
	var err := DirAccess.remove_absolute(file_path)
	if err != OK:
		print("Ошибка удаления файла: ", err)
		return false

	print("Игра удалена: ", game_id)
	return true

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

func normalize_filename_for_comparison(filename: String) -> Dictionary:
	"""
	Нормализует имя файла для сравнения и возвращает словарь с нормализованным именем и типом обложки.
	Возвращает: {"name": нормализованное_имя, "type": "front|back|spine|unknown"}
	"""
	var normalized = filename
	
	# Убираем расширение
	if normalized.ends_with(".png") or normalized.ends_with(".jpg") or normalized.ends_with(".jpeg") or normalized.ends_with(".bmp") or normalized.ends_with(".webp"):
		normalized = normalized.get_basename()
	
	# Определяем и убираем суффикс типа обложки
	var cover_type = "front"  # по умолчанию - передняя обложка
	if normalized.to_lower().ends_with("_back"):
		cover_type = "back"
		normalized = normalized.substr(0, normalized.length() - 5)  # убираем "_back"
	elif normalized.to_lower().ends_with("_spine"):
		cover_type = "spine"
		normalized = normalized.substr(0, normalized.length() - 6)  # убираем "_spine"
	
	# Сохраняем оригинальное имя до очистки для разных вариантов
	var original_normalized = normalized
	
	# Убираем лишние символы, которые могут мешать сравнению
	normalized = normalized.replace(";", " ").replace(":", " ").replace("!", " ").replace("?", " ").replace(",", " ").replace("-", " ").replace("_", " ")
	normalized = normalized.strip_edges()
	
	# Приводим к нижнему регистру для сравнения
	normalized = normalized.to_lower()
	
	# Также создаём вариант без пробелов (для сравнения с именами, где пробелы были удалены)
	var normalized_no_spaces = normalized.replace(" ", "")
	
	return {"name": normalized, "name_no_spaces": normalized_no_spaces, "original": original_normalized.to_lower(), "type": cover_type}

func find_covers_for_game(game_title: String) -> Dictionary:
	"""
	Ищет обложки для указанной игры в папке covers, используя нормализованное сравнение имён файлов
	"""
	var found = {}
	
	var dir = DirAccess.open(covers_path)
	if not dir:
		print("Не удалось открыть папку covers: ", covers_path)
		return found
	
	print("Ищем обложки для игры: ", game_title, " в папке: ", covers_path)
	
	# Используем санитизацию как в steamboxcover
	var sanitized_game_title = sanitize_filename_for_steamboxcover(game_title)
	print("Санитизированный заголовок игры для поиска: ", sanitized_game_title)
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".png") or file_name.ends_with(".jpg") or file_name.ends_with(".jpeg") or file_name.ends_with(".bmp") or file_name.ends_with(".webp"):
			var original_basename = file_name.get_basename()
			var lower_filename = original_basename.to_lower()
			
			# Определяем тип обложки
			var cover_type = "front"
			if lower_filename.ends_with("_back"):
				cover_type = "back"
			elif lower_filename.ends_with("_spine"):
				cover_type = "spine"
			elif lower_filename.ends_with("_logo"):
				# Пропускаем логотипы
				file_name = dir.get_next()
				continue
			# Если это не один из известных суффиксов, это front
			
			# Санитизируем имя файла (без суффикса)
			var filename_without_suffix = original_basename
			if cover_type == "back":
				filename_without_suffix = original_basename.substr(0, original_basename.length() - 5)  # "_back"
			elif cover_type == "spine":
				filename_without_suffix = original_basename.substr(0, original_basename.length() - 6)  # "_spine"
			
			var sanitized_filename = sanitize_filename_for_steamboxcover(filename_without_suffix)
			
			print("Сравниваем: '", sanitized_filename, "' (тип: ", cover_type, ") с '", sanitized_game_title, "'")
			
			if sanitized_filename == sanitized_game_title:
				# Совпадение найдено
				found[cover_type] = covers_path + file_name
				print("Найдена ", cover_type, " обложка: ", file_name)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	print("Найдено обложек: ", found.size())
	for key in found:
		print("  ", key, ": ", found[key])
	
	return found
	

func apply_found_covers(covers: Dictionary):
	"""
	Применяет найденные обложки к game_data
	"""
	var icon_path: String = "res://assets/icons/check.png"
	
	# Обновляем game_data
	for cover_type in covers:
		var path = covers[cover_type]
		game_data[cover_type] = path
		
		# Обновляем соответствующую иконку
		match cover_type:
			"front": 
				front_icon.texture = load(icon_path)
				print("Применена передняя обложка: ", path)
			"back": 
				back_icon.texture = load(icon_path)
				print("Применена задняя обложка: ", path)
			"spine": 
				spine_icon.texture = load(icon_path)
				print("Применена боковая обложка: ", path)

	# Если не все обложки найдены, оставляем плюсы для недостающих
	if not covers.has("front"):
		var plus_icon = load("res://assets/kenney_input-prompts_1.4/Nintendo Switch 2/Default/switch_button_plus.png")
		front_icon.texture = plus_icon
		print("Не найдена передняя обложка, оставлена иконка плюса")
	
	if not covers.has("back"):
		var plus_icon = load("res://assets/kenney_input-prompts_1.4/Nintendo Switch 2/Default/switch_button_plus.png")
		back_icon.texture = plus_icon
		print("Не найдена задняя обложка, оставлена иконка плюса")
	
	if not covers.has("spine"):
		var plus_icon = load("res://assets/kenney_input-prompts_1.4/Nintendo Switch 2/Default/switch_button_plus.png")
		spine_icon.texture = plus_icon
		print("Не найдена боковая обложка, оставлена иконка плюса")
		
func sanitize_filename_for_steamboxcover(filename: String) -> String:
	"""
	Санитизирует имя файла так же, как это делает steamboxcover.
	"""
	var safe := filename
	
	# Удаляем или заменяем символы, которые могут быть проблемными для имён файлов
	var invalid_chars := ["<", ">", ":", "\"", "/", "\\", "|", "?", "*", ";", "!", ".", "'", "`", "~"]
	
	for c in invalid_chars:
		safe = safe.replace(c, " ")
	
	# Заменяем множественные пробелы на один
	while safe.contains("  "):
		safe = safe.replace("  ", " ")
	
	# Убираем начальные и конечные пробелы
	safe = safe.strip_edges()
	
	# Убираем точки в конце
	while safe.ends_with("."):
		safe = safe.substr(0, safe.length() - 1)
	
	# Ограничение длины
	if safe.length() > 200:
		safe = safe.substr(0, 200)
	
	# Убираем все пробелы, чтобы получить имя как в steamboxcover
	var no_spaces = safe.replace(" ", "")
	
	return no_spaces

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
		notification.show_notification(tr("NTF_TYPEGAMENAME"), notification_icon)
		return
	
	var steamboxcover_path = get_steamboxcover_path()
	var spine_template_path = get_spine_template_path()
	
	if not FileAccess.file_exists(steamboxcover_path):
		notification.show_notification(tr("NTF_SBCNOTFOUND"), notification_icon)
		return
		
	var args = []
	args.append("--game")
	args.append(title)
	args.append("--output_dir")
	args.append(ProjectSettings.globalize_path(covers_path))
	args.append("-k")
	args.append("ac6407f383cb7696689026c4576a7758")
	
	if spine_template_path != "":
		args.append("--spine_template")
		args.append(ProjectSettings.globalize_path(spine_template_path))
		
	download_button.text = tr("GA_DOWNCOVERS_BT")
	download_button.disabled = true
	
	await get_tree().create_timer(0.1).timeout
	
	var output = []
	var result = OS.execute(steamboxcover_path, args, output, true, false)
	
	download_button.text = tr("GA_COVERS_BT")
	download_button.disabled = false
	download_icon.texture = load("res://assets/icons/check.png")
	
	if result != OK:
		notification.show_notification(tr("NTF_COVERDOWNFAILED"), notification_icon)
		
	if result == OK:
		notification.show_notification(tr("NTF_COVERDOWNSUCCESS"), notification_icon)
		
		var found_covers = find_covers_for_game(title)
		if found_covers.size() > 0:
			apply_found_covers(found_covers)

func _on_done_pressed() -> void:
	if game_name.text.strip_edges() == "":
		notification.show_notification(tr("NTF_TYPEGAMENAME"), notification_icon)
		return
		
	game_data["title"] = game_name.text.strip_edges()
	
	if save_game_data():
		notification.show_notification(tr("NTF_GAMESAVESUCCESS"), notification_icon)
		
		# Ждём немного чтобы пользователь увидел уведомление
		await get_tree().create_timer(1.0).timeout
		
		# Очищаем форму
		reset_form()
	else:
		notification.show_notification(tr("NTF_GAMESAVEFAILED"), notification_icon)

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
		notification.show_notification(tr("NTF_FILENOTFOUND"), notification_icon)
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
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if current_input_method != "gamepad":
			current_input_method = "gamepad"
		var device_id = event.device
		last_device_id = device_id
	
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
