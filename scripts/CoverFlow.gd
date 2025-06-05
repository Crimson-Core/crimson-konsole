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
#@onready var dark_node = $Dark
#@onready var side_panel = $SidePanel
#@onready var side_panel_animation = $SidePanel/AnimationPlayer
#@onready var side_panel_container = $SidePanel/VBoxContainer
#@onready var side_panel_button_hover = $SidePanel/VBoxContainer/Home/Hover

var games: Array[GameLoader.GameData] = []
var game_covers: Array[GameCover3D] = []
var current_index: int = 0

@export var cover_spacing: float = 6.0
@export var side_angle_y: float = 35.0
@export var side_angle_x: float = 0.0
@export var side_offset: float = 2.0

const NotificationLogicClass = preload("res://scripts/NotificationLogic.gd")
var notification = NotificationLogicClass.new()
var notification_icon = load("res://logo.png")

const SidePanelClass = preload("res://scripts/nodes/SidePanel.gd")
var side_panel = SidePanelClass.new()

const GamepadTypeClass = preload("res://scripts/GamepadType.gd")
var gamepadtype = GamepadTypeClass.new()

const GameTimeTrackerClass = preload("res://scripts/GameTimeTracker.gd")
var time_tracker: GameTimeTracker

var game_cover_scene: PackedScene
var first_update: bool = true
var current_input_method = "keyboard"
var last_device_id: int = -1

func _ready():
	add_child(notification)
	add_child(side_panel)
	
	time_tracker = GameTimeTrackerClass.get_instance()
	
	load_games()
	setup_keyboard_ui()
	
	for device_id in Input.get_connected_joypads():
		update_controller_icon(device_id)
		
	await get_tree().process_frame
	setup_coverflow()
	await get_tree().process_frame
	update_display()
	
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
	#elif event.is_action_pressed("skip_key"):
		#musicplayer.next_track()

func _trigger_vibration(weak_strength: float, strong_strength: float, duration_sec: float) -> void:
	if last_device_id < 0:
		return
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
	
	var pid = OS.create_process(command, arguments, false)
	
	if pid > 0:
		var current_game = games[current_index]
		time_tracker.start_tracking(current_game.title, pid)
		print("Игра запущена с PID: ", pid, " - начинаем отслеживание времени")
		
		#musicplayer.pause_music()
		
		# Запускаем асинхронный мониторинг процесса
		monitor_process(pid, current_game.title)
		
		return true
	else:
		print("Ошибка запуска игры, PID: ", pid)
		return false

func monitor_process(pid: int, game_title: String):
	while OS.is_process_running(pid):
		await get_tree().create_timer(1.0).timeout
	time_tracker.stop_tracking()
	#musicplayer.resume_music()
	print("Игра ", game_title, " с PID: ", pid, " завершена, трекинг остановлен")

func is_wine_available() -> bool:
	var output = []
	var exit_code = OS.execute("which", ["umu-run"], output)
	return exit_code == 0 and output.size() > 0

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			#if musicplayer:
				#musicplayer.pause_music()
			set_process_input(false)
		NOTIFICATION_WM_WINDOW_FOCUS_IN:
			#if musicplayer and not OS.is_process_running(time_tracker.current_pid):
				#musicplayer.resume_music()
			set_process_input(true)

func refresh_games():
	load_games()
	if current_index >= games.size():
		current_index = max(0, games.size() - 1)
	setup_coverflow()
	update_display()
