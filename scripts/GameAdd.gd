extends Control

@onready var file_dialog = $FileDialog
@onready var panel = $Panel
@onready var executable_icon = $Panel/Executable/TextureRect

# Данные о игре
@export var game_data = {
	"title": "", # Название
	"front": "", # Путь к передней обложке
	"back": "", # Путь к задней обложке
	"spine": "", # Путь к боковой обложке
	"executable": "", # Путь к исполняемому файлу игры
	"box_type": "xbox" # Тип модели коробки
}

var covers_path = "user://covers"

# Ввод
var current_input_method = "keyboard"
var last_device_id: int

# Уведомления
const NotificationLogicClass = preload("res://scripts/NotificationLogic.gd")
var notification = NotificationLogicClass.new()
var notification_icon = load("res://logo.png")

func _ready():
	add_child(notification)

func ensure_covers_directory():
	"""Создает папку covers если её нет"""
	if not DirAccess.dir_exists_absolute(covers_path):
		var result = DirAccess.open("user://").make_dir_recursive(covers_path.get_file())
		if result == OK:
			print("Папка covers создана: ", covers_path)
		else:
			print("Ошибка создания папки covers: ", result)

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

func _on_fs_pressed() -> void:
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
		file_dialog.add_filter("*", "All Files")
	file_dialog.popup()

func _on_file_selected(path):
	executable_icon.texture = load("res://assets/icons/check.png")

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
