class_name CoverFlow
extends Control

@onready var viewport_container = $ViewportContainer
@onready var viewport_3d = $ViewportContainer/SubViewport
@onready var camera_3d = $ViewportContainer/SubViewport/Camera3D
@onready var animationplayer = $GameInfo/AnimationPlayer
@onready var file_dialog = $GameInfo/FileDialog

@onready var game_title_label = $GameTitleLabel
@onready var game_state_label = $GameTitleLabel/GameStateLabel

@onready var keyboard_control = $Keyboard
@onready var gamepad_control = $Gamepad
@onready var a_button = $Gamepad/Instruction/Zapusk/Play
@onready var dpad_button = $Gamepad/Instruction/Navigation/Navigation
@onready var start_button = $Gamepad/Add/Start
@onready var controller_icon = $Gamepad/Controller/Icon

@onready var game_info_node = $GameInfo
@onready var game_info_node_canvas = $GameInfo/CanvasLayer
@onready var game_info_logo = $GameInfo/CanvasLayer/Panel/GameLogo
@onready var game_fallback_label = $GameInfo/CanvasLayer/Panel/GameName
@onready var game_time_label = $GameInfo/CanvasLayer/Panel/Time
@onready var game_date_label = $GameInfo/CanvasLayer/Panel/Date

@onready var editgame_icon = $GameInfo/CanvasLayer/Panel/Edit/KeyIcon
@onready var editgame_gamepad_icon = $GameInfo/CanvasLayer/Panel/Edit/GamepadIcon
@onready var editgame_line = $GameInfo/CanvasLayer/Panel/LineEdit
@onready var editgame_label = $GameInfo/CanvasLayer/Panel/Edit
@onready var editgame_executable = $GameInfo/CanvasLayer/Panel/Executable
@onready var editgame_front = $GameInfo/CanvasLayer/Panel/Front
@onready var editgame_back = $GameInfo/CanvasLayer/Panel/Back
@onready var editgame_spine = $GameInfo/CanvasLayer/Panel/Spine
@onready var editgame_delete = $GameInfo/CanvasLayer/Panel/Delete
@onready var editgame_executable_icon = $GameInfo/CanvasLayer/Panel/Executable/TextureRect
@onready var editgame_front_icon = $GameInfo/CanvasLayer/Panel/Front/TextureRect
@onready var editgame_back_icon = $GameInfo/CanvasLayer/Panel/Back/TextureRect
@onready var editgame_spine_icon = $GameInfo/CanvasLayer/Panel/Spine/TextureRect

@onready var loading_icon = $Loading

var games: Array[GameLoader.GameData] = []
var game_covers: Array[GameCover3D] = []
var current_index: int = 0
var running_games := {} # title -> {"pid": int}
var logo_cache: Dictionary = {}
var failed_api_games: Array[String] = [] # Список игр, для которых API не дал нужного результата
var updated_game_data: Dictionary = {}

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

var GameAddScript = load("res://scripts/GameAdd.gd")
var game_manager = GameAddScript.new()
var current_button: String = ""

var first_update: bool = true
var current_input_method = "keyboard"
var last_device_id: int = -1

var missing_logo_queue := []
var processing_request := ""

var edit_mode = false
var delete_mode = false
var editing = false
var edit_cooldown = 0.5

func _ready():
	loading_icon.visible = true
	
	find_notification()
	time_tracker = GameTimeTrackerClass.get_instance()
	
	# Steam API (оставляем только инициализацию)
	steam_api = SteamAPIClass.new()
	steam_api.setup_http_request(self)
	steam_api.logo_found.connect(func(game_data): get_game_logo(game_data))
	steam_api.game_not_found.connect(_on_logo_not_found)
	
	file_dialog.file_selected.connect(func(path): _on_file_selected(path))
	editgame_executable.pressed.connect(func(): _on_fs_pressed())
	editgame_front.pressed.connect(func(): _on_front_pressed())
	editgame_back.pressed.connect(func(): _on_back_pressed())
	editgame_spine.pressed.connect(func(): _on_spine_pressed())
	editgame_delete.pressed.connect(func(): _on_delete_pressed())
	
	load_games()
	setup_keyboard_ui()
	
	await get_tree().process_frame
	preload_logos()
	
	for device_id in Input.get_connected_joypads():
		update_controller_icon(device_id)
		
	await get_tree().process_frame
	setup_coverflow()
	await get_tree().process_frame
	update_display()
	
	time_tracker.cleanup_game_time(games)
	
	loading_icon.visible = false
	
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
	editgame_icon.visible = true
	editgame_gamepad_icon.visible = false
	
func setup_gamepad_ui():
	keyboard_control.visible = false
	gamepad_control.visible = true
	editgame_icon.visible = false
	editgame_gamepad_icon.visible = true

func update_controller_icon(device_id: int):
	var joy_name = Input.get_joy_name(device_id).to_lower()
	var controller_type = gamepadtype.detect_controller_type(joy_name)
	
	match controller_type:
		gamepadtype.ControllerType.XBOX:
			controller_icon.texture = load(gamepadtype.ICON_XBOX_CONTROLLER)
			a_button.texture = load(gamepadtype.ICON_XBOX_A)
			dpad_button.texture = load(gamepadtype.ICON_XBOX_DPAD)
			start_button.texture = load(gamepadtype.ICON_XBOX_START)
			editgame_gamepad_icon.texture = load(gamepadtype.ICON_XBOX_BACK) 
		gamepadtype.ControllerType.PLAYSTATION:
			controller_icon.texture = load(gamepadtype.ICON_PS_CONTROLLER)
			a_button.texture = load(gamepadtype.ICON_PS_A)
			dpad_button.texture = load(gamepadtype.ICON_PS_DPAD)
			start_button.texture = load(gamepadtype.ICON_PS_START)
			editgame_gamepad_icon.texture = load(gamepadtype.ICON_PS_BACK)
		_:
			controller_icon.texture = load(gamepadtype.ICON_GENERIC_CONTROLLER)
			a_button.texture = load(gamepadtype.ICON_GENERIC_A)
			dpad_button.texture = load(gamepadtype.ICON_GENERIC_DPAD)
			start_button.texture = load(gamepadtype.ICON_GENERIC_START)
			editgame_gamepad_icon.texture = load(gamepadtype.ICON_GENERIC_BACK)

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
		game_title_label.text = tr("CF_NOGAMES_TIP")
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
		elif not edit_mode:
			_on_up_pressed()
		_trigger_vibration(1.0, 0.0, 0.1)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("down_pad"):
		if side_panel.side_panel_shown:
			side_panel.side_panel_move_focus(1)
		elif not edit_mode:
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
			game_info_node_canvas.visible = false
		else:
			side_panel.hide_panel()
			if not games.is_empty():
				await get_tree().create_timer(0.15).timeout
				game_info_node_canvas.visible = true
	elif event.is_action_pressed("edit_key"):
		if edit_mode and not editing:
			exit_editmode()
		else:
			if not games.is_empty() and not editing:
				enter_editmode()

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
		show_notification(tr("NTF_ALREADYSTARTED").format({"title": title}))
		return
	
	# Анимация
	#if current_index < game_covers.size():
		#var cover = game_covers[current_index]
		#cover.start_fast_spin_move_animation()
		#await get_tree().create_timer(1.0).timeout
		#cover.stop_fast_spin_move_animation()
	
	await get_tree().create_timer(1.0).timeout
	
	var exe_path = game.get("executable")
	if exe_path.is_empty():
		show_notification(tr("NTF_NOEXECSPECIFIED"))
		return
	
	# Проверяем существование файла
	if not FileAccess.file_exists(exe_path):
		show_notification(tr("NTF_NOEXECFOUND"))
		return
	
	# Запускаем игру
	var pid = _execute_game(exe_path)
	if pid > 0:
		_start_monitoring(title, pid)
		show_notification(tr("NTF_GAMESTARTED").format({"title": title}))
	else:
		show_notification(tr("NTF_STARTFAILED"))

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
					show_notification(tr("NTF_WINENOTFOUND"))
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
		show_notification(tr("NTF_STOPSUCCESS").format({"title": title}))
		game_state_label.visible = false

func show_notification(message: String):
	if notification:
		notification.show_notification(message, notification_icon)

func show_game_info(game_title: String):
	game_info_node_canvas.visible = true
	var game_time = time_tracker.get_game_time(game_title)
	if game_time:
		var game_time_format = game_time.get_formatted_total_time()
		var game_date_format = game_time.get_formatted_last_played()
		game_time_label.visible = true
		game_time_label.text = tr("CF_GT_TIME_TIP") + game_time_format
		game_date_label.text = tr("CF_GT_DATE_TIP") + game_date_format
	else:
		game_time_label.text = tr("CF_GT_NOTIME_TIP")
		game_date_label.text = tr("CF_GT_NODATE_TIP")

	# Загружаем логотип только из памяти/диска, не обращаемся к API
	load_logo_with_fallback(game_title)

func load_logo_with_fallback(game_title: String):
	"""Загрузка логотипа с проверкой: сначала память, потом диск, иначе текст"""
	if logo_cache.has(game_title):
		var cached = logo_cache[game_title]
		if cached.has("is_fallback") and cached.is_fallback:
			show_fallback_text(game_title)
		else:
			game_info_logo.texture = cached.texture
			game_info_logo.visible = true
			game_fallback_label.visible = false
		return

	# Проверяем диск (и загружаем в память)
	var cached_logo = load_logo_from_cache(game_title)
	if cached_logo != null:
		logo_cache[game_title] = {"texture": cached_logo, "is_fallback": false}
		game_info_logo.texture = cached_logo
		game_info_logo.visible = true
		game_fallback_label.visible = false
		return

	# Ничего нет — показываем текст (и не делаем новых запросов)
	show_fallback_text(game_title)

func show_fallback_text(game_title: String):
	game_fallback_label.text = game_title
	game_fallback_label.visible = true
	game_info_logo.visible = false

# --- Предзагрузка кэша и постановка в очередь отсутствующих логотипов ---
func preload_logos():
	"""Загружаем с диска в память все доступные логотипы и собираем очередь для оставшихся."""
	# 1) Пополняем logo_cache из файлового кэша
	for g in games:
		var title = g.title
		if logo_cache.has(title):
			continue
		var cached_logo = load_logo_from_cache(title)
		if cached_logo != null:
			logo_cache[title] = {"texture": cached_logo, "is_fallback": false}

	# 2) Формируем очередь запросов к API
	missing_logo_queue.clear()
	for g in games:
		var title = g.title
		if logo_cache.has(title):
			continue
		if failed_api_games.has(title):
			continue
		missing_logo_queue.append(title)

	# 3) Запускаем обработку
	request_next_logo()

func request_next_logo():
	"""Посылает следующий запрос к API, если нет текущего обрабатываемого."""
	if processing_request != "" or missing_logo_queue.is_empty():
		return
	processing_request = missing_logo_queue.pop_front()
	steam_api.search_game_logo_only(processing_request)


func request_logo_from_api(game_title: String):
	if logo_cache.has(game_title) or failed_api_games.has(game_title):
		return
	if not missing_logo_queue.has(game_title):
		missing_logo_queue.append(game_title)
	request_next_logo()


# --- Обработка ответа API ---
func get_game_logo(game_data):
	var requested_title = processing_request
	processing_request = ""

	if requested_title == "":
		requested_title = games[current_index].title if current_index >= 0 and current_index < games.size() else ""
		print("get_game_logo: нет связывающего запроса, пробуем текущую игру: ", requested_title)

	print("=== Обработка логотипа (API) ===")
	print("Запрошено для: '", requested_title, "'")
	print("API название: '", game_data.name, "'")

	var names_match = false
	if requested_title != "":
		names_match = are_names_similar(game_data.name, requested_title)
	else:
		names_match = game_data.logo_texture != null

	if names_match and game_data.logo_texture != null:
		logo_cache[requested_title] = {"texture": game_data.logo_texture, "is_fallback": false}
		_save_logo_to_disk_async_once(requested_title, game_data.logo_texture)
		print("✓ API нашёл логотип: ", requested_title)
	else:
		if requested_title != "":
			failed_api_games.append(requested_title)
			logo_cache[requested_title] = {"is_fallback": true}
		print("✗ API не нашёл логотип: ", requested_title, " (найден: ", game_data.name, ")")

	print("===============================")
	request_next_logo()


func _on_logo_not_found():
	"""Обработка случая когда API не нашёл игру"""
	var requested_title = processing_request
	processing_request = ""
	
	if requested_title != "":
		print("✗ API не нашёл игру: ", requested_title)
		failed_api_games.append(requested_title)
		logo_cache[requested_title] = {"is_fallback": true}
	
	# Продолжаем обработку очереди
	request_next_logo()

# --- Кэширование ---
func save_logo_to_cache(game_title: String, texture: ImageTexture):
	if texture == null:
		return
	logo_cache[game_title] = {"texture": texture, "is_fallback": false}
	_save_logo_to_disk_async_once(game_title, texture)


func _save_logo_to_disk_async_once(game_title: String, texture: ImageTexture):
	if texture == null:
		return

	var safe_title = sanitize_filename(game_title)
	var file_path = "user://covers/" + safe_title + "_logo.png"

	if FileAccess.file_exists(file_path):
		return

	var covers_dir = "user://covers/"
	if not DirAccess.dir_exists_absolute(covers_dir):
		DirAccess.open("user://").make_dir_recursive("covers")

	var image = texture.get_image()
	if image == null:
		return

	await get_tree().process_frame
	var err = image.save_png(file_path)
	if err == OK:
		print("Логотип сохранён: ", file_path)
	else:
		print("Ошибка сохранения: ", err)


func load_logo_from_cache(game_title: String) -> ImageTexture:
	var safe_title = sanitize_filename(game_title)
	var file_path = "user://covers/" + safe_title + "_logo.png"

	if not FileAccess.file_exists(file_path):
		return null

	var image = Image.new()
	var error = image.load(file_path)
	if error != OK:
		print("Ошибка загрузки логотипа: ", error)
		return null

	var texture = ImageTexture.new()
	texture.set_image(image)
	print("Загружен логотип: ", file_path)
	return texture


func sanitize_filename(filename: String) -> String:
	var invalid_chars := ["<", ">", ":", "\"", "/", "\\", "|", "?", "*"]
	var safe := filename
	for c in invalid_chars:
		safe = safe.replace(c, "_")
	safe = safe.strip_edges()
	# убираем конечную точку(ы)
	while safe.ends_with("."):
		safe = safe.substr(0, safe.length() - 1)
	# ограничение длины
	if safe.length() > 200:
		safe = safe.substr(0, 200)
	return safe

func normalize_game_name(name: String) -> String:
	if name.is_empty():
		return ""
	var s := name.to_lower().strip_edges()
	# набор спецсимволов, которые превращаем в пробелы
	var special := ["'", ":", "-", "_", ".", ",", "!", "?", "&", "+", "(", ")", "[", "]", "{", "}", "™", "®", "©", "/","\\","–","—"]
	for ch in special:
		if s.find(ch) != -1:
			s = s.replace(ch, " ")
	# заменить множественные пробелы одним
	while s.find("  ") != -1:
		s = s.replace("  ", " ")
	s = s.strip_edges()
	# простая замена римских цифр (только если отделены пробелом или в конце/начале)
	var roman_map := {" ii":" 2", " iii":" 3", " iv":" 4", " v":" 5", " vi":" 6", " vii":" 7", " viii":" 8", " ix":" 9", " x":" 10"}
	for r in roman_map.keys():
		if s.find(r) != -1:
			s = s.replace(r, roman_map[r])
	# удаляем ведущие/хвостовые пробелы ещё раз на всякий
	return s.strip_edges()

# Одно-строчный Levenshtein (экономия памяти O(min(n,m)))
func calculate_similarity(a: String, b: String) -> float:
	if a == b:
		return 1.0
	if a.is_empty() or b.is_empty():
		return 0.0
	# делаем так, чтобы b была более короткой строкой (чтобы row был короче)
	if a.length() < b.length():
		var tmp := a; a = b; b = tmp
	var len_a := a.length()
	var len_b := b.length()
	# prev_row хранит расстояния для предыдущей позиции в a
	var prev_row := []
	for j in range(len_b + 1):
		prev_row.append(j)
	for i in range(1, len_a + 1):
		var cur_row := []
		cur_row.append(i)
		var ai := a[i - 1]
		for j in range(1, len_b + 1):
			var cost := 0 if ai == b[j - 1] else 1
			var ins = cur_row[j - 1] + 1
			var delet = prev_row[j] + 1
			var subs = prev_row[j - 1] + cost
			cur_row.append(min(ins, delet, subs))
		prev_row = cur_row
	var distance = prev_row[len_b]
	var max_len = max(len_a, len_b)
	return 1.0 - float(distance) / float(max_len)

func extract_keywords(name: String) -> Array:
	var norm := normalize_game_name(name)
	if norm.is_empty():
		return []
	var words := norm.split(" ")
	var stop := {"the":true, "a":true, "an":true, "and":true, "or":true, "of":true, "in":true, "on":true, "at":true, "to":true, "for":true, "with":true, "by":true}
	var res := []
	for w in words:
		if w.length() > 2 and not stop.has(w):
			res.append(w)
	return res

# Быстрая проверка аббревиатуры (например "ow" vs "overwatch")
func short_abbrev_match(single: String, multi_words: Array) -> bool:
	var abbrev := ""
	for w in multi_words:
		if w.length() > 0:
			abbrev += w[0]
	return abbrev == single

func check_keyword_match(name1: String, name2: String) -> float:
	var k1 := extract_keywords(name1)
	var k2 := extract_keywords(name2)
	if k1.is_empty() or k2.is_empty():
		return 0.0
	# уникальные ключи
	var all := {}
	for w in k1:
		all[w] = true
	for w in k2:
		all[w] = true
	var total := all.size()
	# прямые совпадения + частичные (префикс) + близкие (similarity)
	var matches := 0.0
	for w1 in k1:
		var found := false
		for w2 in k2:
			if w1 == w2:
				matches += 1.0
				found = true
				break
			# если длинные — допускаем частичное совпадение
			if w1.length() > 4 and w2.length() > 4:
				if w1.begins_with(w2) or w2.begins_with(w1):
					matches += 0.7
					found = true
					break
				elif calculate_similarity(w1, w2) > 0.82:
					matches += 0.5
					found = true
					break
		# не найдено — продолжаем
	return float(matches) / float(total)

func are_names_similar(api_name: String, local_name: String) -> bool:
	var norm_api := normalize_game_name(api_name)
	var norm_local := normalize_game_name(local_name)
	print("Сравниваем: '", norm_api, "' с '", norm_local, "'")
	# полное совпадение
	if norm_api == norm_local:
		print("Точное совпадение")
		return true
	# близость строк
	var sim := calculate_similarity(norm_api, norm_local)
	print("Схожесть строк: ", sim)
	if sim >= 0.86:
		print("Высокая схожесть")
		return true
	# совпадение ключевых слов
	var kmatch := check_keyword_match(api_name, local_name)
	print("Ключевые слова: ", kmatch)
	if kmatch >= 0.72:
		print("Хорошее совпадение ключевых слов")
		return true
	# если короткие названия — проверяем вхождение
	if norm_api.length() <= 15 and norm_local.length() <= 15:
		if norm_api.find(norm_local) != -1 or norm_local.find(norm_api) != -1:
			var length_ratio := float(min(norm_api.length(), norm_local.length())) / float(max(norm_api.length(), norm_local.length()))
			if length_ratio > 0.6:
				print("Название содержится в другом")
				return true
	# проверка аббревиатур: API 1 слово vs локал >1 слова и наоборот
	var api_words := norm_api.split(" ")
	var local_words := norm_local.split(" ")
	if api_words.size() == 1 and local_words.size() > 1:
		if short_abbrev_match(api_words[0], local_words):
			print("API название — аббревиатура локального")
			return true
	if local_words.size() == 1 and api_words.size() > 1:
		if short_abbrev_match(local_words[0], api_words):
			print("Локальное — аббревиатура API")
			return true
	print("Не совпадают")
	return false

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
		"executable": editgame_executable_icon.texture = load(icon_path)
		"front": editgame_front_icon.texture = load(icon_path)
		"back": editgame_back_icon.texture = load(icon_path)
		"spine": editgame_spine_icon.texture = load(icon_path)
		
	if not FileAccess.file_exists(path):
		notification.show_notification(tr("NTF_FILENOTFOUND"), notification_icon)
		return
	
	updated_game_data[current_button] = path

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
	
func _on_delete_pressed() -> void:
	var game = games[current_index]
	var title = game.title
	var game_id = game_manager.find_game_id_by_title(title)
	
	delete_mode = true
	
	game_manager.delete_game_by_id(game_id)
	
	exit_editmode()

func enter_editmode():
	var game = games[current_index]
	var title = game.title
	var cover = game_covers[current_index]
	edit_mode = true
	
	editgame_line.visible = true
	editgame_line.text = title
	editgame_label.text = tr("CF_GE_STOP")
	editgame_executable.visible = true
	editgame_front.visible = true
	editgame_back.visible = true
	editgame_spine.visible = true
	editgame_delete.visible = true
	
	game_info_logo.visible = false
	game_fallback_label.visible = false
	game_time_label.visible = false
	game_date_label.visible = false
	
	if current_index < game_covers.size():
		cover.start_fast_spin_move_animation()
		move_viewport_container(500, 0.4)
		game_info_node.set_notify_transform(true)
		animationplayer.play("GameEdit")
		game_info_node.queue_redraw()
		await get_tree().create_timer(0.3).timeout

func exit_editmode():
	var game = games[current_index]
	var title = game.title
	var cover = game_covers[current_index]
	var game_id = game_manager.find_game_id_by_title(title)
	var plus_icon = load("res://assets/kenney_input-prompts_1.4/Nintendo Switch 2/Default/switch_button_plus.png")
	
	var new_title = editgame_line.text
	
	updated_game_data["title"] = new_title 
	
	if not delete_mode:
		game_manager.update_game_data_by_id(game_id, updated_game_data)
		notification.show_notification(tr("NTF_GAMEUPDATESUCCESS"), notification_icon)
	else:
		notification.show_notification(tr("NTF_GAMEDELETESUCCESS"), notification_icon)
	
	updated_game_data = {}
	
	game_info_logo.visible = true
	game_fallback_label.visible = true
	game_time_label.visible = true
	game_date_label.visible = true
	
	editgame_line.visible = false
	editgame_label.text = tr("CF_GE_EDIT")
	editgame_executable.visible = false
	editgame_front.visible = false
	editgame_back.visible = false
	editgame_spine.visible = false
	editgame_delete.visible = false
	
	editgame_executable_icon.texture = plus_icon
	editgame_front_icon.texture = plus_icon
	editgame_back_icon.texture = plus_icon
	editgame_spine_icon.texture = plus_icon
	
	show_game_info(title)

	if current_index < game_covers.size():
		editing = true
		cover.stop_fast_spin_move_animation()
		move_viewport_container(-500, 0.4)
		animationplayer.play("GameEdit_Back")
		await get_tree().create_timer(0.3).timeout
	
	await get_tree().create_timer(0.4).timeout
	refresh_games()
	
	if games.is_empty():
		game_info_node_canvas.visible = false
		
	edit_mode = false
	
	var t := get_tree().create_timer(edit_cooldown)
	t.timeout.connect(_reset_edit)

func _reset_edit():
	editing = false
	
func _exit_tree():
	logo_cache.clear()
	failed_api_games.clear()

func refresh_games():
	load_games()
	if current_index >= games.size():
		current_index = max(0, games.size() - 1)
	await get_tree().process_frame
	setup_coverflow()
	await get_tree().process_frame
	update_display()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			set_process_input(false)
		NOTIFICATION_WM_WINDOW_FOCUS_IN:
			set_process_input(true)
