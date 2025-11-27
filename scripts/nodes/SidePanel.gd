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
@onready var home_button = side_panel_instance.get_node("VBoxContainer/Home")
@onready var gameadd_button = side_panel_instance.get_node("VBoxContainer/GameAdd")
@onready var settings_button = side_panel_instance.get_node("VBoxContainer/Settings")

func _ready():
	side_panel_init()
	home_button.pressed.connect(func(): side_panel_change_scene(home_button))
	gameadd_button.pressed.connect(func(): side_panel_change_scene(gameadd_button))
	settings_button.pressed.connect(func(): side_panel_change_scene(settings_button))

func show_panel():
	if side_panel_moving or side_panel_shown or side_panel_buttons.is_empty():
		return
	
	var main_scene = get_tree().get_first_node_in_group("main_scene")
	var current_scene = main_scene.get_current_scene()
	
	dark_node.visible = true
	dark_node.mouse_filter = Control.MOUSE_FILTER_STOP
	side_panel.visible = true
	if side_panel_animation.has_animation("show_panel"):
		side_panel_animation.play("show_panel")
		side_panel_moving = true
		await side_panel_animation.animation_finished
		side_panel_moving = false
		side_panel_shown = true
		if current_scene.name == "CoverFlow":
			side_panel_current_index = 0
		elif current_scene.name == "GameAdd":
			side_panel_current_index = 1
		elif current_scene.name == "Settings":
			side_panel_current_index = 2
		
		# ПРИНУДИТЕЛЬНО устанавливаем фокус на первую кнопку
		if side_panel_buttons.size() > 0:
			# Сначала включаем focus_mode для текущей кнопки
			side_panel_buttons[side_panel_current_index].focus_mode = Control.FOCUS_ALL
			# Затем устанавливаем фокус
			side_panel_buttons[side_panel_current_index].grab_focus()
			
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
		dark_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		side_panel.visible = false
		side_panel_shown = false
		side_panel_current_index = 0
		
func side_panel_init():
	if side_panel_instance:
		side_panel.position = Vector2(-365, 136.5)
		
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
	if gameadd_btn and gameadd_btn is Button:
		side_panel_buttons.append(gameadd_btn)
		# ОТКЛЮЧАЕМ автофокус
		gameadd_btn.focus_mode = Control.FOCUS_NONE
	if settings_btn and settings_btn is Button:
		side_panel_buttons.append(settings_btn)
		# ОТКЛЮЧАЕМ автофокус
		settings_btn.focus_mode = Control.FOCUS_NONE
	
	
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

func side_panel_change_scene(button: Button = null):
	var button_name := ""
	var main_scene = get_tree().get_first_node_in_group("main_scene")
	var current_scene = main_scene.get_current_scene()

	if button != null:
		# Если пришла кнопка с UI (мышь), берём её имя
		button_name = button.name
	else:
		# Иначе берём текущую по индексу (геймпад/клава)
		if side_panel_current_index < side_panel_buttons.size():
			button_name = side_panel_buttons[side_panel_current_index].name
		else:
			return # на всякий

	match button_name:
		"Home":
			if current_scene.name != "CoverFlow":
				await hide_panel()
				main_scene.load_scene("res://scenes/CoverFlow.tscn")
			else:
				hide_panel()
		"GameAdd":
			if current_scene.name != "GameAdd":
				await hide_panel()
				main_scene.load_scene("res://scenes/GameAdd.tscn")
			else:
				hide_panel()
		"Settings":
			if current_scene.name != "Settings":
				await hide_panel()
				main_scene.load_scene("res://scenes/Settings.tscn")
			else:
				hide_panel()
