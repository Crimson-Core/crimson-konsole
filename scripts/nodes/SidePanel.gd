class_name SidePanel
extends Node

var side_panel_moving = false
var side_panel_shown = false
var side_panel_buttons: Array[Button] = []
var side_panel_current_index: int = 0

# Загружаем сцену side_panel
var side_panel_scene = preload("res://scenes/side_panel.tscn")
var side_panel_instance = side_panel_scene.instantiate()

@onready var side_panel = side_panel_instance
@onready var dark_node = side_panel_instance.get_node("Dark")
@onready var side_panel_animation = side_panel_instance.get_node("AnimationPlayer")
@onready var side_panel_container = side_panel_instance.get_node("VBoxContainer")
@onready var side_panel_button_hover = side_panel_instance.get_node("VBoxContainer/Home/Hover")

func _ready():
	side_panel_init()

func show_panel():
	if side_panel_moving or side_panel_shown or side_panel_buttons.is_empty():
		return
	
	dark_node.visible = true
	side_panel.visible = true
	if side_panel_animation.has_animation("show_panel"):
		side_panel_animation.play("show_panel")
		side_panel_moving = true
		await side_panel_animation.animation_finished
		side_panel_moving = false
		side_panel_shown = true
		side_panel_current_index = 0
		
		# ПРИНУДИТЕЛЬНО устанавливаем фокус на первую кнопку
		if side_panel_buttons.size() > 0:
			# Сначала включаем focus_mode для текущей кнопки
			side_panel_buttons[side_panel_current_index].focus_mode = Control.FOCUS_ALL
			# Затем устанавливаем фокус
			side_panel_buttons[side_panel_current_index].grab_focus()
			print("Принудительно установлен фокус на: ", side_panel_buttons[side_panel_current_index].name)
			
func hide_panel():
	if side_panel_moving or not side_panel_shown:
		return
	
	# Очищаем фокусы перед скрытием панели
	for button in side_panel_buttons:
		button.focus_mode = Control.FOCUS_NONE
		
	if side_panel_animation.has_animation("hide_panel"):
		side_panel_animation.play("hide_panel")
		side_panel_moving = true
		await side_panel_animation.animation_finished
		side_panel_moving = false
		dark_node.visible = false
		side_panel.visible = false
		side_panel_shown = false
		side_panel_current_index = 0
		
func side_panel_init():
	side_panel_buttons.clear()
	
	var vbox_container = side_panel_container
	if not vbox_container:
		print("Ошибка: VBoxContainer не найден")
		return
	
	# Собираем кнопки принудительно в правильном порядке
	var home_btn = vbox_container.get_node_or_null("Home")
	var gameadd_btn = vbox_container.get_node_or_null("GameAdd") 
	var settings_btn = vbox_container.get_node_or_null("Settings")
	
	if home_btn and home_btn is Button:
		side_panel_buttons.append(home_btn)
		# ОТКЛЮЧАЕМ автофокус
		home_btn.focus_mode = Control.FOCUS_NONE
		print("Добавлена кнопка Home")
	if gameadd_btn and gameadd_btn is Button:
		side_panel_buttons.append(gameadd_btn)
		# ОТКЛЮЧАЕМ автофокус
		gameadd_btn.focus_mode = Control.FOCUS_NONE
		print("Добавлена кнопка GameAdd")
	if settings_btn and settings_btn is Button:
		side_panel_buttons.append(settings_btn)
		# ОТКЛЮЧАЕМ автофокус
		settings_btn.focus_mode = Control.FOCUS_NONE
		print("Добавлена кнопка Settings")
	
	print("=== ИТОГО: порядок кнопок ===")
	for i in range(side_panel_buttons.size()):
		print("Индекс ", i, ": ", side_panel_buttons[i].name)
	
	side_panel_current_index = 0
	
	
func side_panel_move_focus(direction: int):
	if side_panel_buttons.is_empty():
		return
	
	# Отключаем фокус у текущей кнопки
	if side_panel_current_index < side_panel_buttons.size():
		side_panel_buttons[side_panel_current_index].focus_mode = Control.FOCUS_NONE
	
	# Вычисляем новый индекс
	side_panel_current_index += direction
	
	# Циклическая навигация
	if side_panel_current_index < 0:
		side_panel_current_index = side_panel_buttons.size() - 1
	elif side_panel_current_index >= side_panel_buttons.size():
		side_panel_current_index = 0
	
	# Включаем фокус только у новой кнопки и устанавливаем его
	if side_panel_current_index < side_panel_buttons.size():
		side_panel_buttons[side_panel_current_index].focus_mode = Control.FOCUS_ALL
		side_panel_buttons[side_panel_current_index].grab_focus()
		print("Фокус на кнопке: ", side_panel_buttons[side_panel_current_index].name)


func side_panel_change_scene():
	if side_panel_buttons.is_empty() or side_panel_current_index >= side_panel_buttons.size():
		return
	
	var current_button = side_panel_buttons[side_panel_current_index]
	var current_scene = get_tree().current_scene
	
	match current_button.name:
		"Home":
			hide_panel()
		"GameAdd":
			if current_scene.name == "CoverFlow":
				get_tree().change_scene_to_file("res://scenes/GameAdd.tscn")
		"Settings":
			# Тут потом настройки
			hide_panel()
