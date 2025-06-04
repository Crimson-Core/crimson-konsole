class_name CoverFlow
extends Control

@onready var viewport_container = $ViewportContainer
@onready var viewport_3d = $ViewportContainer/SubViewport
@onready var camera_3d = $ViewportContainer/SubViewport/Camera3D
@onready var game_title_label = $GameTitleLabel
@onready var keyboard_control = $Keyboard
@onready var gamepad_control = $Gamepad
@onready var a_button = $Gamepad/Instruction/Zapusk/Play
@onready var dpad_button = $Gamepad/Instruction/Navigation/Navigation
@onready var start_button = $Gamepad/Add/Start
@onready var controller_icon = $Gamepad/Controller/Icon

var games: Array[GameLoader.GameData] = []
var game_covers: Array[GameCover3D] = []
var current_index: int = 0

@export var cover_spacing: float = 6.0  # Уменьшено для вертикального расположения
@export var side_angle_y: float = 35.0  # Поворот по Y для показа боковой обложки
@export var side_angle_x: float = 0.0   # Небольшой наклон по X
@export var side_offset: float = 2.0

const NotificationLogicClass = preload("res://scripts/NotificationLogic.gd")
var notification = NotificationLogicClass.new()
var notification_icon = load("res://logo.png")

const GamepadTypeClass = preload("res://scripts/GamepadType.gd")
var gamepadtype = GamepadTypeClass.new()

const MusicPlayerClass = preload("res://scripts/nodes/MusicPlayer.gd")
var musicplayer = MusicPlayerClass.new()

const GameTimeTrackerClass = preload("res://scripts/GameTimeTracker.gd")
var time_tracker: GameTimeTracker

var game_cover_scene: PackedScene
var first_update: bool = true
var current_input_method = "keyboard"

func _ready():
	musicplayer.set_volume(-20.0)
	add_child(notification)
	
	time_tracker = GameTimeTrackerClass.get_instance()
	
	load_games()
	setup_keyboard_ui()
	
	for device_id in Input.get_connected_joypads():
		update_controller_icon(device_id)
		
	await get_tree().process_frame
	setup_coverflow()
	await get_tree().process_frame
	update_display()

# Загружает список игр и очищает неиспользуемые обложки
func load_games():
	games = GameLoader.load_all_games()
	cleanup_unused_covers()

# Удаляет неиспользуемые файлы обложек из папки covers
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

# Обновляет иконки контроллера в зависимости от типа геймпада
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

# Создает 3D обложки для всех игр в системе coverflow
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

# Обновляет позиции и анимации всех обложек для вертикального coverflow
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
			# Центральная обложка - слегка повернута для показа боковой стороны
			pos = Vector3(0, 0, 0)
			rot = Vector3(-side_angle_x, side_angle_y, 0)
			scl = Vector3(1.2, 1.2, 1.2)
			cover.set_selected(true)
		else:
			# Боковые обложки расположены вертикально
			var abs_offset = abs(offset)
			
			# Вертикальное расположение (по оси Y)
			pos = Vector3(offset * abs_offset, offset * cover_spacing, abs_offset * 1.5)
			# Фиксированный поворот для всех обложек
			rot = Vector3(-side_angle_x, side_angle_y, 0)
			scl = Vector3(0.8, 0.8, 0.8)
			cover.set_selected(false)
		
		# Устанавливаем target только если анимация не завершена
		if not cover.is_animation_finished:
			if first_update:
				cover.position = pos
				cover.rotation_degrees = rot
				cover.scale = scl
			cover.set_target_transform(pos, rot, scl)
	
	first_update = false

# Обновленные функции для вертикального движения
func _on_up_pressed():
	if games.size() <= 1:
		return
	
	current_index += 1
	if current_index >= games.size():
		current_index = 0
	
	update_display()

func _on_down_pressed():
	if games.size() <= 1:
		return
	
	current_index -= 1
	if current_index < 0:
		current_index = games.size() - 1
	
	update_display()

# Обработка ввода с клавиатуры и геймпада
func _input(event):
	if event is InputEventKey or event is InputEventMouseButton:
		if current_input_method != "keyboard":
			current_input_method = "keyboard"
			setup_keyboard_ui()
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if current_input_method != "gamepad":
			current_input_method = "gamepad"
			setup_gamepad_ui()
		var device_id = event.device
		update_controller_icon(device_id)

	# Изменено на вертикальное управление
	if event.is_action_pressed("ui_up") or event.is_action_pressed("up_pad"):
		_on_up_pressed()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("down_pad"):
		_on_down_pressed()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("accept_pad"):
		launch_current_game()
	elif event.is_action_pressed("menu_pad"):
		add_game()
	elif event.is_action_pressed("view_key") or event.is_action_pressed("view_pad"):
		game_info()
	elif event.is_action_pressed("skip_key"):
		musicplayer.next_track()

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

# Запускает выбранную игру с анимацией
func launch_current_game():
	if games.is_empty():
		return
	
	if current_index < game_covers.size():
		var current_cover = game_covers[current_index]
		if is_instance_valid(current_cover):
			current_cover.stop_fast_spin_move_animation()
			move_viewport_container(-465, 0.9)
	
	var current_game = games[current_index]
	
	if not current_game.get("executable") or current_game.executable == "":
		notification.show_notification("У игры не указан исполняемый файл!", notification_icon)
		return
	
	await get_tree().create_timer(1.0).timeout
	
	if launch_game_executable(current_game.executable):
		notification.show_notification("Игра \"" + current_game.title + "\" запущена!", notification_icon)

# Запускает исполняемый файл игры в зависимости от ОС
func launch_game_executable(executable_path: String) -> bool:
	if executable_path == "" or not FileAccess.file_exists(executable_path):
		notification.show_notification("Исполняемый файл не найден!", notification_icon)
		return false
	
	var extension = executable_path.get_extension().to_lower()
	var os_name = OS.get_name()
	var working_directory = executable_path.get_base_dir()
	
	var command: String = ""
	var arguments: PackedStringArray = []
	
	match os_name:
		"Windows":
			match extension:
				"exe":
					command = "cmd"
					arguments = ["/c", "cd /d \"" + working_directory + "\" && \"" + executable_path + "\""]
				"bat", "cmd":
					command = "cmd"
					arguments = ["/c", "cd /d \"" + working_directory + "\" && " + executable_path]
				_:
					notification.show_notification("Неподдерживаемый файл для Windows!", notification_icon)
					return false
		
		"Linux":
			match extension:
				"sh":
					OS.execute("chmod", ["+x", executable_path])
					command = "sh"
					arguments = ["-c", "cd \"" + working_directory + "\" && bash \"" + executable_path + "\""]
				"exe":
					if is_wine_available():
						command = "sh"
						arguments = ["-c", "cd \"" + working_directory + "\" && umu-run \"" + executable_path + "\""]
					else:
						notification.show_notification("Wine не установлен! Невозможно запустить .exe файлы", notification_icon)
						return false
				"":
					OS.execute("chmod", ["+x", executable_path])
					command = "sh"
					arguments = ["-c", "cd \"" + working_directory + "\" && ./" + executable_path.get_file()]
				"x86_64":
					OS.execute("chmod", ["+x", executable_path])
					command = "sh"
					arguments = ["-c", "cd \"" + working_directory + "\" && ./" + executable_path.get_file()]
				_:
					notification.show_notification("Неподдерживаемый файл для Linux!", notification_icon)
					return false
		
		"macOS":
			match extension:
				"app":
					command = "open"
					arguments = [executable_path]
				"sh":
					OS.execute("chmod", ["+x", executable_path])
					command = "sh"
					arguments = ["-c", "cd \"" + working_directory + "\" && bash \"" + executable_path + "\""]
				"":
					OS.execute("chmod", ["+x", executable_path])
					command = "sh"
					arguments = ["-c", "cd \"" + working_directory + "\" && ./" + executable_path.get_file()]
				_:
					notification.show_notification("Неподдерживаемый файл для macOS!", notification_icon)
					return false
		
		_:
			notification.show_notification("Неподдерживаемая операционная система!", notification_icon)
			return false
	
	# ИЗМЕНЕННАЯ ЧАСТЬ: Используем асинхронный запуск для получения PID
	var pid = OS.create_process(command, arguments, false)
	
	if pid > 0:
		# Начинаем отслеживание времени игры
		var current_game = games[current_index]
		time_tracker.start_tracking(current_game.title, pid)
		print("Игра запущена с PID: ", pid, " - начинаем отслеживание времени")
		return true
	else:
		print("Ошибка запуска игры, PID: ", pid)
		return false

func is_wine_available() -> bool:
	var output = []
	var exit_code = OS.execute("which", ["umu-run"], output)
	return exit_code == 0 and output.size() > 0

func add_game():
	get_tree().change_scene_to_file("res://scenes/game_add.tscn")

# Обновляет список игр после добавления новых
func refresh_games():
	load_games()
	if current_index >= games.size():
		current_index = max(0, games.size() - 1)
	setup_coverflow()
	update_display()
