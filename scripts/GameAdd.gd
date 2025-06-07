extends Control

@onready var file_dialog = $FileDialog
@onready var panel = $Panel
@onready var executable_icon = $Panel/Executable/TextureRect

# Ввод
var current_input_method = "keyboard"
var last_device_id: int

# Уведомления
const NotificationLogicClass = preload("res://scripts/NotificationLogic.gd")
var notification = NotificationLogicClass.new()
var notification_icon = load("res://logo.png")

# Боковая панель
#const SidePanelClass = preload("res://scripts/nodes/SidePanel.gd")
#var side_panel = SidePanelClass.new()

func _ready():
	add_child(notification)
	
	#add_child(side_panel)
	#add_child(side_panel.side_panel_instance)

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
