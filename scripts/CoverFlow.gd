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

var games: Array[GameLoader.GameData] = []
var game_covers: Array[GameCover3D] = []
var current_index: int = 0
var running_games := {}

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

var game_cover_scene: PackedScene
var first_update: bool = true
var current_input_method = "keyboard"
var last_device_id: int = -1

func _ready():
	# Инициализация
	find_notification()
	time_tracker = GameTimeTrackerClass.get_instance()
	
	# Инициализация Steam API
	steam_api = SteamAPIClass.new(steam_api_key)
	steam_api.setup_http_request(self)
	
	# Подключение сигналов Steam API
	steam_api.steam_launch_success.connect(_on_steam_launch_success)
	steam_api.steam_launch_failed.connect(_on_steam_launch_failed)
	
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
	var covers_dir = "user://covers/"
	if not DirAccess.dir_exists_absolute(covers_dir):
		return
	
	var used_covers = {}
	for game in games:
		if game.get("front") != "":
			used_covers[game.front] = true
		if game.get("back") != "":
			used_covers[game.back] = true
		if game.get("spine") != "":
			used_covers[game.spine] = true
	
	var dir = DirAccess.open(covers_dir)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not file_name.begins_with("."):
			var full_path = covers_dir + file_name
			if not used_covers.has(full_path):
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
		var cover_instance: GameCover3D
		
		if game_cover_scene:
			cover_instance = game_cover_scene.instantiate()
		else:
			cover_instance = GameCover3D.new()
		
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
			launch_current_game()
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
	if last_device_id < 0 or current_input_method == "keyboard":
		return
	else:
		Input.start_joy_vibration(last_device_id, weak_strength, strong_strength, duration_sec)

func move_viewport_container(x: int, time: float):
	var tween := create_tween()
	tween.tween_property(viewport_container, "position:x", x, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

func game_info():
	if games.is_empty():
		return
	
	var current_game = games[current_index]
	
	if current_index < game_covers.size():
		var current_cover = game_covers[current_index]
		if is_instance_valid(current_cover):
			current_cover.start_fast_spin_move_animation()
			move_viewport_container(10, 0.9)

# УПРОЩЁННЫЙ ЗАПУСК ИГР ЧЕРЕЗ STEAM API
func launch_current_game():
	if games.is_empty():
		return
	
	var current_game = games[current_index]
	var title = current_game.title
	
	# Проверяем, не запущена ли уже игра
	if running_games.has(title):
		show_notification("Игра \"" + title + "\" уже запущена.")
		return
	
	# Анимация запуска
	if current_index < game_covers.size():
		var current_cover = game_covers[current_index]
		if is_instance_valid(current_cover):
			current_cover.stop_fast_spin_move_animation()
			move_viewport_container(-465, 0.9)
	
	await get_tree().create_timer(1.0).timeout
	
	# Определяем тип игры и запускаем
	var exe_path = current_game.get("executable")
	
	if is_steam_game(exe_path):
		launch_steam_game(current_game)
	else:
		launch_regular_game(current_game)

func is_steam_game(exe_path: String) -> bool:
	if exe_path == "":
		return false
	
	var lower_path = exe_path.to_lower()
	return exe_path.begins_with("steam://") or ("steam" in lower_path and "steamapps" in lower_path)

func launch_steam_game(game_data: GameLoader.GameData):
	var exe_path = game_data.get("executable")
	
	# Если это прямая ссылка Steam
	if exe_path.begins_with("steam://rungameid/"):
		var app_id = exe_path.split("/")[-1].to_int()
		steam_api.launch_steam_game(app_id)
	elif exe_path.begins_with("steam://"):
		# Другие Steam ссылки
		OS.shell_open(exe_path)
		handle_steam_launch_success(0, game_data.title)
	else:
		# Поиск по названию через Steam API
		steam_api.launch_steam_game_by_name(game_data.title)

func launch_regular_game(game_data: GameLoader.GameData):
	var exe_path = game_data.get("executable")
	
	if exe_path == "":
		show_notification("У игры не указан исполняемый файл!")
		return
	
	if not FileAccess.file_exists(exe_path):
		show_notification("Исполняемый файл не найден!")
		return
	
	var pid = launch_executable(exe_path)
	if pid > 0:
		handle_game_launch_success(pid, game_data.title)
	else:
		show_notification("Не удалось запустить игру!")

func launch_executable(exe_path: String) -> int:
	var working_dir = exe_path.get_base_dir()
	var os_name = OS.get_name()
	
	match os_name:
		"Windows":
			return OS.create_process("cmd", ["/c", "cd /d \"" + working_dir + "\" && \"" + exe_path + "\""], false)
		
		"Linux":
			OS.execute("chmod", ["+x", exe_path])
			
			# Обработка Windows исполняемых файлов
			if exe_path.get_extension().to_lower() == "exe":
				# Проверка наличия umu-run
				if OS.execute("which", ["umu-run"]) == OK:
					return OS.create_process("umu-run", [exe_path], false)
				
				# Проверка наличия wine
				if OS.execute("which", ["wine"]) == OK:
					return OS.create_process("wine", [exe_path], false)
				
				show_notification("Для запуска .exe нужен wine или umu-run!")
				return -1
			
			# Обычный запуск Linux-совместимых бинарников
			return OS.create_process("sh", ["-c", "cd \"" + working_dir + "\" && ./" + exe_path.get_file()], false)
		
		"macOS":
			if exe_path.get_extension().to_lower() == "app":
				return OS.create_process("open", [exe_path], false)
			else:
				OS.execute("chmod", ["+x", exe_path])
				return OS.create_process("sh", ["-c", "cd \"" + working_dir + "\" && ./" + exe_path.get_file()], false)
		
		_:
			return -1

# Обработчики сигналов Steam API
func _on_steam_launch_success(app_id: int):
	var current_game = games[current_index]
	handle_steam_launch_success(app_id, current_game.title)

func _on_steam_launch_failed(error: String):
	show_notification("Ошибка запуска Steam игры: " + error)

# Обработчики успешного запуска
func handle_steam_launch_success(app_id: int, title: String):
	running_games[title] = app_id
	time_tracker.start_tracking(title, app_id)
	update_display()
	show_notification("Игра \"" + title + "\" запущена через Steam!")
	
	# Простой мониторинг для Steam игр
	monitor_steam_game(title, app_id)

func handle_game_launch_success(pid: int, title: String):
	running_games[title] = pid
	time_tracker.start_tracking(title, pid)
	update_display()
	show_notification("Игра \"" + title + "\" запущена!")
	
	# Мониторинг обычных игр
	monitor_regular_game(title, pid)

# Упрощённый мониторинг
func monitor_steam_game(title: String, app_id: int):
	# Для Steam игр используем простую задержку
	await get_tree().create_timer(10.0).timeout
	
	while running_games.has(title):
		await get_tree().create_timer(5.0).timeout
		# Простая проверка - если прошло достаточно времени, считаем что игра может быть закрыта
		# В реальной реализации здесь должна быть проверка через Steam API или процессы

func monitor_regular_game(title: String, pid: int):
	while running_games.has(title):
		await get_tree().create_timer(3.0).timeout
		
		if not OS.is_process_running(pid):
			stop_game_tracking(title)
			break

func stop_game_tracking(title: String):
	if running_games.has(title):
		var pid_or_app_id = running_games[title]
		time_tracker.stop_tracking(pid_or_app_id)
		running_games.erase(title)
		update_display()
		show_notification("Игра \"" + title + "\" завершена.")
		print("Игра ", title, " завершена")
		game_state_label.visible = false

func show_notification(message: String):
	if notification:
		notification.show_notification(message, notification_icon)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			set_process_input(false)
		NOTIFICATION_WM_WINDOW_FOCUS_IN:
			set_process_input(true)

func refresh_games():
	load_games()
	if current_index >= games.size():
		current_index = max(0, games.size() - 1)
	setup_coverflow()
	update_display()
