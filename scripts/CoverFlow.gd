class_name CoverFlow
extends Control

@onready var viewport_container = $ViewportContainer
@onready var viewport_3d = $ViewportContainer/SubViewport
@onready var camera_3d = $ViewportContainer/SubViewport/Camera3D
@onready var game_title_label = $GameTitleLabel
@onready var game_state_label = $GameTitleLabel/GameStateLabel
@onready var keyboard_control = $Keyboard
@onready var gamepad_control = $Gamepad
@onready var a_button = $Gamepad/Instruction/Zapusk/Play
@onready var dpad_button = $Gamepad/Instruction/Navigation/Navigation
@onready var start_button = $Gamepad/Add/Start
@onready var controller_icon = $Gamepad/Controller/Icon
@onready var game_info_node = $GameInfo
@onready var game_info_logo = $GameInfo/Panel/GameLogo
@onready var game_fallback_label = $GameInfo/Panel/GameName
@onready var game_time_label = $GameInfo/Panel/Time

var games: Array[GameLoader.GameData] = []
var game_covers: Array[GameCover3D] = []
var current_index: int = 0
var running_games := {} # title -> {"pid": int}
var logo_cache: Dictionary = {}
var failed_api_games: Array[String] = [] # Список игр, для которых API не дал нужного результата

@export var cover_spacing: float = 6.0
@export var side_angle_y: float = 35.0
@export var side_angle_x: float = 0.0
@export var side_offset: float = 2.0

var notification
var notification_icon = load("res://logo.png")

const GamepadTypeClass = preload("res://scripts/GamepadType.gd")
var gamepadtype = GamepadTypeClass.new()

const GameTimeTrackerClass = preload("res://scripts/GameTimeTracker.gd")
var time_tracker: GameTimeTracker

const SteamAPIClass = preload("res://scripts/SteamAPI.gd")
var steam_api: SteamAPI
@export var steam_api_key: String = ""

var first_update: bool = true
var current_input_method = "keyboard"
var last_device_id: int = -1

func _ready():
	find_notification()
	time_tracker = GameTimeTrackerClass.get_instance()
	
	# Steam API (оставляем только инициализацию)
	steam_api = SteamAPIClass.new()
	steam_api.setup_http_request(self)
	steam_api.logo_found.connect(func(game_data): get_game_logo(game_data))
	steam_api.description_found.connect(func(game_data): get_game_description(game_data))
	
	load_games()
	setup_keyboard_ui()
	
	for device_id in Input.get_connected_joypads():
		update_controller_icon(device_id)
		
	await get_tree().process_frame
	setup_coverflow()
	await get_tree().process_frame
	update_display()
	
func find_notification():
	var main_scene = get_tree().get_first_node_in_group("main_scene")
	if main_scene and main_scene.has_method("get_notification"):
		notification = main_scene.get_notification()
	else:
		var parent = get_parent()
		while parent:
			if parent.get("notification"):
				notification = parent.notification
				break
			parent = parent.get_parent()

func load_games():
	games = GameLoader.load_all_games()
	cleanup_unused_covers()

func cleanup_unused_covers():
	"""Обновленная очистка с учетом логотипов"""
	var covers_dir = "user://covers/"
	if not DirAccess.dir_exists_absolute(covers_dir):
		return
	
	var used_covers = {}
	
	# Добавляем обычные обложки
	for game in games:
		if game.get("front") != "":
			used_covers[game.front] = true
		if game.get("back") != "":
			used_covers[game.back] = true
		if game.get("spine") != "":
			used_covers[game.spine] = true
		
		# Добавляем логотипы
		var safe_title = sanitize_filename(game.title)
		var logo_filename = safe_title + "_logo.png"
		used_covers["user://covers/" + logo_filename] = true
	
	var dir = DirAccess.open(covers_dir)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not file_name.begins_with("."):
			var full_path = covers_dir + file_name
			if not used_covers.has(full_path):
				print("Удаляем неиспользуемый файл: ", full_path)
				dir.remove(file_name)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	

func setup_keyboard_ui():
	keyboard_control.visible = true
	gamepad_control.visible = false

func setup_gamepad_ui():
	keyboard_control.visible = false
	gamepad_control.visible = true

func update_controller_icon(device_id: int):
	var joy_name = Input.get_joy_name(device_id).to_lower()
	var controller_type = gamepadtype.detect_controller_type(joy_name)
	
	match controller_type:
		gamepadtype.ControllerType.XBOX:
			controller_icon.texture = load(gamepadtype.ICON_XBOX_CONTROLLER)
			a_button.texture = load(gamepadtype.ICON_XBOX_A)
			dpad_button.texture = load(gamepadtype.ICON_XBOX_DPAD)
			start_button.texture = load(gamepadtype.ICON_XBOX_START)
		gamepadtype.ControllerType.PLAYSTATION:
			controller_icon.texture = load(gamepadtype.ICON_PS_CONTROLLER)
			a_button.texture = load(gamepadtype.ICON_PS_A)
			dpad_button.texture = load(gamepadtype.ICON_PS_DPAD)
			start_button.texture = load(gamepadtype.ICON_PS_START)
		_:
			controller_icon.texture = load(gamepadtype.ICON_GENERIC_CONTROLLER)
			a_button.texture = load(gamepadtype.ICON_GENERIC_A)
			dpad_button.texture = load(gamepadtype.ICON_GENERIC_DPAD)
			start_button.texture = load(gamepadtype.ICON_GENERIC_START)

func setup_coverflow():
	for cover in game_covers:
		if is_instance_valid(cover):
			cover.queue_free()
	game_covers.clear()
	
	await get_tree().process_frame
	
	if games.is_empty():
		return
	
	for i in range(games.size()):
		var cover_instance: GameCover3D = GameCover3D.new()
		cover_instance.set_game_data(games[i])
		viewport_3d.add_child(cover_instance)
		game_covers.append(cover_instance)

func update_display():
	if games.is_empty():
		game_title_label.text = "Нет игр"
		return
	
	game_title_label.text = games[current_index].title
	
	for i in range(game_covers.size()):
		var cover = game_covers[i]
		if not is_instance_valid(cover):
			continue
			
		var offset = i - current_index
		var pos = Vector3()
		var rot = Vector3()
		var scl = Vector3.ONE
		
		if offset == 0:
			pos = Vector3(0, 0, 0)
			rot = Vector3(-side_angle_x, side_angle_y, 0)
			scl = Vector3(1.2, 1.2, 1.2)
			cover.set_selected(true)
			game_state_label.visible = running_games.has(games[i].title)
			show_game_info(games[current_index].title)
		else:
			var abs_offset = abs(offset)
			pos = Vector3(offset * abs_offset, offset * cover_spacing, abs_offset * 1.5)
			rot = Vector3(-side_angle_x, side_angle_y, 0)
			scl = Vector3(0.8, 0.8, 0.8)
			cover.set_selected(false)
		
		if not cover.is_animation_finished:
			if first_update:
				cover.position = pos
				cover.rotation_degrees = rot
				cover.scale = scl
			cover.set_target_transform(pos, rot, scl)
	
	first_update = false
	
func _on_up_pressed():
	if games.size() <= 1:
		return
	
	current_index += 1
	if current_index >= games.size():
		current_index = games.size() - 1
	
	update_display()

func _on_down_pressed():
	if games.size() <= 1:
		return
	
	current_index -= 1
	if current_index < 0:
		current_index = 0
	
	update_display()

func _input(event):
	var main_scene = get_tree().get_first_node_in_group("main_scene")
	var side_panel = main_scene.get_side_panel()
	
	if event is InputEventKey or event is InputEventMouseButton:
		if current_input_method != "keyboard":
			current_input_method = "keyboard"
			setup_keyboard_ui()
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if current_input_method != "gamepad":
			current_input_method = "gamepad"
			setup_gamepad_ui()
		var device_id = event.device
		last_device_id = device_id
		update_controller_icon(device_id)

	if event.is_action_pressed("ui_up") or event.is_action_pressed("up_pad"):
		if side_panel.side_panel_shown:
			side_panel.side_panel_move_focus(-1)
		else:
			_on_up_pressed()
		_trigger_vibration(1.0, 0.0, 0.1)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("down_pad"):
		if side_panel.side_panel_shown:
			side_panel.side_panel_move_focus(1)
		else:
			_on_down_pressed()
		_trigger_vibration(1.0, 0.0, 0.1)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("accept_pad"):
		if side_panel.side_panel_shown:
			side_panel.side_panel_change_scene()
		else:
			launch_game()
	elif event.is_action_pressed("menu_key") or event.is_action_pressed("menu_pad"):
		if not side_panel.side_panel_shown:
			side_panel.show_panel()
		else:
			side_panel.hide_panel()
	elif event.is_action_pressed("skip_key"):
		get_main_scene().load_scene("res://scenes/game_add.tscn")

func get_main_scene():
	var current = get_parent()
	while current:
		if current.has_method("load_scene"):
			return current
		current = current.get_parent()
	
	get_tree().change_scene_to_file("res://scenes/game_add.tscn")
	return null

func _trigger_vibration(weak_strength: float, strong_strength: float, duration_sec: float) -> void:
	if last_device_id >= 0 and current_input_method == "gamepad":
		Input.start_joy_vibration(last_device_id, weak_strength, strong_strength, duration_sec)

func move_viewport_container(x: int, time: float):
	var tween := create_tween()
	tween.tween_property(viewport_container, "position:x", x, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

# ПРОСТАЯ ФУНКЦИЯ ЗАПУСКА ИГРЫ
func launch_game():
	if games.is_empty():
		return
	
	var game = games[current_index]
	var title = game.title
	
	# Проверяем, не запущена ли уже
	if running_games.has(title):
		show_notification("Игра \"" + title + "\" уже запущена.")
		return
	
	# Анимация
	if current_index < game_covers.size():
		var cover = game_covers[current_index]
		if is_instance_valid(cover) and cover.has_method("stop_fast_spin_move_animation"):
			cover.stop_fast_spin_move_animation()
		move_viewport_container(-465, 0.9)
	
	await get_tree().create_timer(1.0).timeout
	
	var exe_path = game.get("executable")
	if exe_path.is_empty():
		show_notification("У игры не указан исполняемый файл!")
		return
	
	# Проверяем существование файла
	if not FileAccess.file_exists(exe_path):
		show_notification("Исполняемый файл не найден!")
		return
	
	# Запускаем игру
	var pid = _execute_game(exe_path)
	if pid > 0:
		_start_monitoring(title, pid)
		show_notification("Игра \"" + title + "\" запущена!")
	else:
		show_notification("Не удалось запустить игру!")

func _execute_game(exe_path: String) -> int:
	var working_dir = exe_path.get_base_dir()
	var os_name = OS.get_name()
	
	match os_name:
		"Windows":
			return OS.create_process("cmd", ["/c", "cd /d \"" + working_dir + "\" && \"" + exe_path + "\""])
		
		"Linux":
			OS.execute("chmod", ["+x", exe_path])
			
			if exe_path.get_extension().to_lower() == "exe":
				# Windows exe в Linux
				if OS.execute("which", ["umu-run"]) == 0:
					return OS.create_process("umu-run", [exe_path])
				elif OS.execute("which", ["wine"]) == 0:
					return OS.create_process("wine", [exe_path])
				else:
					show_notification("Для .exe нужен wine/umu-launcher!")
					return -1
			
			# Для нативных Linux игр - создаем команду с установкой LD_LIBRARY_PATH
			var lib_paths = []
			var potential_lib_dirs = ["lib", "libs", "../lib", "lib64", "lib32"]
			
			for dir in potential_lib_dirs:
				var full_path = working_dir + "/" + dir
				if DirAccess.dir_exists_absolute(full_path):
					lib_paths.append(full_path)
			
			lib_paths.append(working_dir)  # Сама директория игры
			
			var ld_library_path = ":".join(lib_paths)
			var command = "cd \"" + working_dir + "\" && LD_LIBRARY_PATH=\"" + ld_library_path + ":$LD_LIBRARY_PATH\" ./" + exe_path.get_file()
			
			return OS.create_process("sh", ["-c", command])
		
		"macOS":
			if exe_path.get_extension().to_lower() == "app":
				return OS.create_process("open", [exe_path])
			else:
				OS.execute("chmod", ["+x", exe_path])
				return OS.create_process("sh", ["-c", "cd \"" + working_dir + "\" && ./" + exe_path.get_file()])
		_:	
			return -1

# МОНИТОРИНГ ПРОЦЕССОВ
func _start_monitoring(title: String, pid: int):
	running_games[title] = {"pid": pid}
	time_tracker.start_tracking(title, pid)
	update_display()
	_monitor_game(title)

func _monitor_game(title: String):
	var game_info = running_games[title]
	
	await get_tree().create_timer(3.0).timeout
	
	while running_games.has(title):
		if not OS.is_process_running(game_info.pid):
			_stop_game(title)
			break
		
		await get_tree().create_timer(5.0).timeout

func _stop_game(title: String):
	if running_games.has(title):
		var game_info = running_games[title]
		time_tracker.stop_tracking(game_info.pid)
		running_games.erase(title)
		update_display()
		show_notification("Игра \"" + title + "\" завершена.")
		game_state_label.visible = false

func show_notification(message: String):
	if notification:
		notification.show_notification(message, notification_icon)

func show_game_info(game_title: String):
	var game_time = time_tracker.get_game_time(game_title)
	if game_time:
		var game_time_format = game_time.get_formatted_total_time()
		game_time_label.visible = true
		game_time_label.text = "ВЫ ИГРАЛИ: " + game_time_format
	else:
		game_time_label.text = "ВЫ ИГРАЛИ: 0 мин."
	
	# Загружаем логотип независимо от API
	load_logo_with_fallback(game_title)

func load_logo_with_fallback(game_title: String):
	"""Загрузка логотипа с проверкой всех источников"""
	
	# Проверяем, была ли игра уже помечена как проблемная для API
	if failed_api_games.has(game_title):
		show_fallback_text(game_title)
		return
	
	# 1. Проверяем кэш в памяти
	if logo_cache.has(game_title):
		var cached_data = logo_cache[game_title]
		if cached_data.has("is_fallback") and cached_data.is_fallback:
			show_fallback_text(game_title)
		else:
			game_info_logo.texture = cached_data.texture
			game_info_logo.visible = true
			game_fallback_label.visible = false
		return
	
	# 2. Проверяем кэш на диске
	var cached_logo = load_logo_from_cache(game_title)
	if cached_logo != null:
		game_info_logo.texture = cached_logo
		game_info_logo.visible = true
		game_fallback_label.visible = false
		logo_cache[game_title] = {"texture": cached_logo, "is_fallback": false}
		return
	
	# 3. Если нигде нет - загружаем из Steam API
	request_logo_from_api(game_title)

func show_fallback_text(game_title: String):
	"""Показать текстовое название вместо логотипа"""
	game_fallback_label.text = game_title
	game_fallback_label.visible = true
	game_info_logo.visible = false

func request_logo_from_api(game_title: String):
	"""Запрос только логотипа из Steam API"""
	steam_api.search_game_logo_only(game_title)

# Разделяем обработку логотипа и описания
func get_game_logo(game_data):
	"""Обработка только логотипа из API с улучшенной проверкой соответствия названий"""
	var current_game_title = games[current_index].title
	
	print("=== Проверка логотипа ===")
	print("Локальное название: '", current_game_title, "'")
	print("API название: '", game_data.name, "'")
	
	# Используем улучшенный алгоритм сравнения
	var names_match = are_names_similar(game_data.name, current_game_title)
	
	if names_match and game_data.logo_texture != null:
		# Названия совпадают - показываем логотип
		game_info_logo.texture = game_data.logo_texture
		game_info_logo.visible = true
		game_fallback_label.visible = false
		save_logo_to_cache(current_game_title, game_data.logo_texture)
		print("✓ API нашел подходящий логотип для: ", current_game_title)
	else:
		# Названия не совпадают или нет логотипа - показываем текст и помечаем игру как проблемную
		show_fallback_text(current_game_title)
		failed_api_games.append(current_game_title)
		# Сохраняем в кэш информацию о том, что для этой игры нужно показывать текст
		logo_cache[current_game_title] = {"is_fallback": true}
		print("✗ API не нашел подходящий логотип для: ", current_game_title, " (найден: ", game_data.name, ")")
	
	print("=========================")
	

func get_game_description(game_data):
	"""Обработка только описания из API (если потребуется)"""
	var game_description = game_data.description
	# Здесь можно добавить обработку описания если нужно

func save_logo_to_cache(game_title: String, texture: ImageTexture):
	"""Сохранение логотипа в кэш"""
	if texture == null:
		return
	
	# Сохраняем в память
	logo_cache[game_title] = {"texture": texture, "is_fallback": false}
	
	# Сохраняем на диск асинхронно
	_save_logo_to_disk_async(game_title, texture)
	
func _save_logo_to_disk_async(game_title: String, texture: ImageTexture):
	"""Асинхронное сохранение на диск"""
	
	# Создаем директорию если её нет
	var covers_dir = "user://covers/"
	if not DirAccess.dir_exists_absolute(covers_dir):
		DirAccess.open("user://").make_dir_recursive("covers")
	
	# Получаем изображение из текстуры
	var image = texture.get_image()
	if image == null:
		return
	
	# Безопасное имя файла
	var safe_title = sanitize_filename(game_title)
	var file_path = covers_dir + safe_title + "_logo.png"
	
	# Сохраняем асинхронно в следующем кадре
	await get_tree().process_frame
	image.save_png(file_path)
	print("Логотип сохранен: ", file_path)
	
func load_logo_from_cache(game_title: String) -> ImageTexture:
	"""Загрузка логотипа из кэша на диске"""
	
	var safe_title = sanitize_filename(game_title)
	var file_path = "user://covers/" + safe_title + "_logo.png"
	
	if not FileAccess.file_exists(file_path):
		return null
	
	var image = Image.new()
	var error = image.load(file_path)
	
	if error != OK:
		print("Ошибка загрузки кэшированного логотипа: ", error)
		return null
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	
	print("Загружен кэшированный логотип: ", file_path)
	return texture

func sanitize_filename(filename: String) -> String:
	"""Очистка имени файла от недопустимых символов"""
	var safe_name = filename
	
	# Заменяем недопустимые символы
	var invalid_chars = ["<", ">", ":", "\"", "/", "\\", "|", "?", "*"]
	for char in invalid_chars:
		safe_name = safe_name.replace(char, "_")
	
	# Убираем точки в конце и пробелы
	safe_name = safe_name.strip_edges()
	if safe_name.ends_with("."):
		safe_name = safe_name.substr(0, safe_name.length() - 1)
	
	# Ограничиваем длину
	if safe_name.length() > 200:
		safe_name = safe_name.substr(0, 200)
	
	return safe_name

func normalize_game_name(name: String) -> String:
	"""Нормализация названия игры для сравнения"""
	var normalized = name.to_lower().strip_edges()
	
	# Удаляем специальные символы и заменяем их пробелами
	var special_chars = ["'", "'", ":", "-", "_", ".", ",", "!", "?", "&", "+", "(", ")", "[", "]", "{", "}", "™", "®", "©"]
	for char in special_chars:
		normalized = normalized.replace(char, " ")
	
	# Заменяем множественные пробелы одним
	while normalized.contains("  "):
		normalized = normalized.replace("  ", " ")
	
	# Убираем пробелы в начале и конце
	normalized = normalized.strip_edges()
	
	# Заменяем римские цифры арабскими (базовые случаи)
	var roman_to_arabic = {
		" ii": " 2", " iii": " 3", " iv": " 4", " v": " 5", 
		" vi": " 6", " vii": " 7", " viii": " 8", " ix": " 9", " x": " 10"
	}
	
	for roman in roman_to_arabic:
		normalized = normalized.replace(roman, roman_to_arabic[roman])
	
	return normalized

func calculate_similarity(str1: String, str2: String) -> float:
	"""Вычисление схожести строк (упрощенный алгоритм Левенштейна)"""
	if str1 == str2:
		return 1.0
	
	if str1.is_empty() or str2.is_empty():
		return 0.0
	
	var len1 = str1.length()
	var len2 = str2.length()
	
	# Создаем матрицу расстояний
	var matrix = []
	for i in range(len1 + 1):
		matrix.append([])
		for j in range(len2 + 1):
			matrix[i].append(0)
	
	# Инициализируем первую строку и столбец
	for i in range(len1 + 1):
		matrix[i][0] = i
	for j in range(len2 + 1):
		matrix[0][j] = j
	
	# Заполняем матрицу
	for i in range(1, len1 + 1):
		for j in range(1, len2 + 1):
			var cost = 0 if str1[i-1] == str2[j-1] else 1
			matrix[i][j] = min(
				matrix[i-1][j] + 1,      # удаление
				matrix[i][j-1] + 1,      # вставка
				matrix[i-1][j-1] + cost  # замена
			)
	
	var max_len = max(len1, len2)
	var distance = matrix[len1][len2]
	
	return 1.0 - (float(distance) / float(max_len))

func extract_keywords(name: String) -> Array:
	"""Извлечение ключевых слов из названия"""
	var normalized = normalize_game_name(name)
	var words = normalized.split(" ")
	var keywords = []
	
	# Исключаем общие слова
	var common_words = ["the", "a", "an", "and", "or", "of", "in", "on", "at", "to", "for", "with", "by"]
	
	for word in words:
		if word.length() > 2 and not common_words.has(word):
			keywords.append(word)
	
	return keywords

func check_keyword_match(name1: String, name2: String) -> float:
	"""Проверка совпадения ключевых слов"""
	var keywords1 = extract_keywords(name1)
	var keywords2 = extract_keywords(name2)
	
	if keywords1.is_empty() or keywords2.is_empty():
		return 0.0
	
	var matches = 0
	var total_unique_keywords = 0
	var all_keywords = {}
	
	# Собираем все уникальные ключевые слова
	for word in keywords1:
		all_keywords[word] = true
	for word in keywords2:
		all_keywords[word] = true
	
	total_unique_keywords = all_keywords.size()
	
	# Считаем совпадения
	for word1 in keywords1:
		for word2 in keywords2:
			if word1 == word2:
				matches += 1
				break
			# Проверяем частичное совпадение для длинных слов
			elif word1.length() > 4 and word2.length() > 4:
				if word1.begins_with(word2) or word2.begins_with(word1):
					matches += 0.7
					break
				elif calculate_similarity(word1, word2) > 0.8:
					matches += 0.5
					break
	
	return float(matches) / float(total_unique_keywords)

func are_names_similar(api_name: String, local_name: String) -> bool:
	"""Улучшенная проверка схожести названий игр"""
	
	# Нормализуем названия
	var norm_api = normalize_game_name(api_name)
	var norm_local = normalize_game_name(local_name)
	
	print("Сравниваем: '", norm_api, "' с '", norm_local, "'")
	
	# 1. Точное совпадение после нормализации
	if norm_api == norm_local:
		print("Точное совпадение после нормализации")
		return true
	
	# 2. Проверяем схожесть строк
	var similarity = calculate_similarity(norm_api, norm_local)
	print("Схожесть строк: ", similarity)
	
	if similarity > 0.85:
		print("Высокая схожесть строк")
		return true
	
	# 3. Проверяем совпадение ключевых слов
	var keyword_match = check_keyword_match(api_name, local_name)
	print("Совпадение ключевых слов: ", keyword_match)
	
	if keyword_match > 0.7:
		print("Хорошее совпадение ключевых слов")
		return true
	
	# 4. Проверяем, содержится ли одно название в другом (для коротких названий)
	if norm_api.length() <= 15 and norm_local.length() <= 15:
		if norm_api.contains(norm_local) or norm_local.contains(norm_api):
			var length_ratio = float(min(norm_api.length(), norm_local.length())) / float(max(norm_api.length(), norm_local.length()))
			if length_ratio > 0.6:
				print("Одно название содержится в другом")
				return true
	
	# 5. Специальные случаи для аббревиатур и сокращений
	var api_words = norm_api.split(" ")
	var local_words = norm_local.split(" ")
	
	# Проверяем, может ли одно быть аббревиатурой другого
	if api_words.size() == 1 and local_words.size() > 1:
		var abbrev = ""
		for word in local_words:
			if word.length() > 0:
				abbrev += word[0]
		if abbrev == norm_api:
			print("API название - аббревиатура локального")
			return true
	
	if local_words.size() == 1 and api_words.size() > 1:
		var abbrev = ""
		for word in api_words:
			if word.length() > 0:
				abbrev += word[0]
		if abbrev == norm_local:
			print("Локальное название - аббревиатура API")
			return true
	
	print("Названия не совпадают")
	return false
	
func _exit_tree():
	logo_cache.clear()
	failed_api_games.clear()

func refresh_games():
	load_games()
	if current_index >= games.size():
		current_index = max(0, games.size() - 1)
	setup_coverflow()
	update_display()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			set_process_input(false)
		NOTIFICATION_WM_WINDOW_FOCUS_IN:
			set_process_input(true)
