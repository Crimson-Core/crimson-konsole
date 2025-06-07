@tool
extends PanelContainer

###########################
## SETTINGS
###########################

@export var auto_show:bool = true
@export var animate:bool = true

@export_file var custom_layout_file
@export var set_tool_tip := true
@export_group("Style")
@export var separation:Vector2i = Vector2i(0,0)
var style_background:StyleBoxFlat = null
@export var background:StyleBoxFlat = null:
	set(new_val):
		style_background = new_val
		background = new_val
	get:
		return style_background
var style_normal:StyleBoxFlat = null
@export var normal:StyleBoxFlat = null:
	set(new_val):
		style_normal = new_val
		normal = new_val
	get:
		return style_normal
var style_hover:StyleBoxFlat = null
@export var hover:StyleBoxFlat = null:
	set(new_val):
		style_hover = new_val
		hover = new_val
	get:
		return style_hover
var style_pressed:StyleBoxFlat = null
@export var pressed:StyleBoxFlat = null:
	set(new_val):
		style_pressed = new_val
		pressed = new_val
	get:
		return style_pressed
var style_special_keys:StyleBoxFlat = null
@export var special_keys:StyleBoxFlat = null:
	set(new_val):
		style_special_keys = new_val
		special_keys = new_val
	get:
		return style_special_keys

# КОНТРОЛЛЕР
@export_group("Controller")
@export var enable_controller:bool = true
@export var controller_focus_color:Color = Color(0.2, 0.5, 1.0, 0.8)
@export var up_pad:String = "up_pad"
@export var down_pad:String = "down_pad"
@export var left_pad:String = "left_pad"
@export var right_pad:String = "right_pad"
@export var accept_pad:String = "accept_pad"
@export var back_pad:String = "back_pad"

@export_group("Font")
@export var font:FontFile
@export var font_size:int = 20
@export var font_color_normal:Color = Color(1,1,1)
@export var font_color_hover:Color = Color(1,1,1)
@export var font_color_pressed:Color = Color(1,1,1)

###########################
## SIGNALS
###########################

signal layout_changed

###########################
## CONTROLLER VARIABLES
###########################

var current_focused_key = null
var focused_key_index = Vector2i(0, 0)
var keyboard_grid = []
var original_key_styles = {}
var controller_input_enabled = false # Флаг для активации управления контроллером

###########################
## PANEL 
###########################

func _enter_tree():
	if not get_tree().get_root().size_changed.is_connected(size_changed):
		get_tree().get_root().size_changed.connect(size_changed)
	_init_keyboard()

func _input(event):
	_update_auto_display_on_input(event)
	
	# Обрабатываем контроллер только если клавиатура видима И включено управление контроллером
	if enable_controller and visible and controller_input_enabled:
		_handle_controller_input(event)

func size_changed():
	if auto_show and visible:
		_hide_keyboard()

###########################
## CONTROLLER LOGIC
###########################

func _handle_controller_input(event):
	# Обрабатываем только события джойстика
	if not (event is InputEventJoypadButton):
		return
	
	if not event.pressed and event is InputEventJoypadButton:
		return
	
	var action_handled = false
	
	# Проверяем нажатие кнопок через Input.is_action_just_pressed
	if Input.is_action_just_pressed(up_pad):
		_navigate_up()
		action_handled = true
	elif Input.is_action_just_pressed(down_pad):
		_navigate_down()
		action_handled = true
	elif Input.is_action_just_pressed(left_pad):
		_navigate_left()
		action_handled = true
	elif Input.is_action_just_pressed(right_pad):
		_navigate_right()
		action_handled = true
	elif Input.is_action_just_pressed(accept_pad):
		_activate_focused_key()
		action_handled = true
	elif Input.is_action_just_pressed(back_pad):
		_hide_keyboard()
		action_handled = true
	
	# Поглощаем событие контроллера, чтобы оно не дошло до других элементов
	if action_handled:
		get_viewport().set_input_as_handled()

func _navigate_up():
	if keyboard_grid.is_empty():
		return

	var new_row = focused_key_index.x - 1
	if new_row < 0:
		new_row = keyboard_grid.size() - 1  # Переходим в конец
	
	var new_col = min(focused_key_index.y, keyboard_grid[new_row].size() - 1)
	_set_focused_key(Vector2i(new_row, new_col))

func _navigate_down():
	if keyboard_grid.is_empty():
		return
	
	var new_row = focused_key_index.x + 1
	if new_row >= keyboard_grid.size():
		new_row = 0  # Переходим в начало
	
	var new_col = min(focused_key_index.y, keyboard_grid[new_row].size() - 1)
	_set_focused_key(Vector2i(new_row, new_col))

func _navigate_left():
	if keyboard_grid.is_empty():
		return
	
	var current_row = keyboard_grid[focused_key_index.x]
	var new_col = focused_key_index.y - 1
	if new_col < 0:
		new_col = current_row.size() - 1  # Переходим в конец строки
	
	_set_focused_key(Vector2i(focused_key_index.x, new_col))

func _navigate_right():
	if keyboard_grid.is_empty():
		return
	
	var current_row = keyboard_grid[focused_key_index.x]
	var new_col = focused_key_index.y + 1
	if new_col >= current_row.size():
		new_col = 0  # Переходим в начало строки
	
	_set_focused_key(Vector2i(focused_key_index.x, new_col))

func _set_focused_key(new_index: Vector2i):
	# Убираем фокус с предыдущей кнопки
	if current_focused_key != null:
		_remove_focus_style(current_focused_key)
	
	# Устанавливаем фокус на новую кнопку
	focused_key_index = new_index
	if focused_key_index.x < keyboard_grid.size() and focused_key_index.y < keyboard_grid[focused_key_index.x].size():
		current_focused_key = keyboard_grid[focused_key_index.x][focused_key_index.y]
		_apply_focus_style(current_focused_key)

func _apply_focus_style(key):
	if key == null:
		return
	
	# Сохраняем оригинальный стиль
	if not original_key_styles.has(key):
		var original_style = key.get_theme_stylebox("normal")
		if original_style != null:
			original_key_styles[key] = original_style
		else:
			# Создаем базовый стиль, если его нет
			var base_style = StyleBoxFlat.new()
			base_style.bg_color = Color(0.3, 0.3, 0.3)
			original_key_styles[key] = base_style
	
	# Создаем новый стиль с подсветкой
	var focused_style = StyleBoxFlat.new()
	var original = original_key_styles[key]
	
	if original is StyleBoxFlat:
		focused_style.bg_color = original.bg_color
		focused_style.border_width_left = 3
		focused_style.border_width_right = 3
		focused_style.border_width_top = 3
		focused_style.border_width_bottom = 3
		focused_style.border_color = controller_focus_color
		focused_style.corner_radius_top_left = original.corner_radius_top_left
		focused_style.corner_radius_top_right = original.corner_radius_top_right
		focused_style.corner_radius_bottom_left = original.corner_radius_bottom_left
		focused_style.corner_radius_bottom_right = original.corner_radius_bottom_right
	else:
		focused_style.bg_color = Color(0.3, 0.3, 0.3)
		focused_style.border_width_left = 3
		focused_style.border_width_right = 3
		focused_style.border_width_top = 3
		focused_style.border_width_bottom = 3
		focused_style.border_color = controller_focus_color
	
	key.add_theme_stylebox_override("normal", focused_style)

func _remove_focus_style(key):
	if key == null:
		return
	
	# Восстанавливаем оригинальный стиль
	if original_key_styles.has(key):
		key.add_theme_stylebox_override("normal", original_key_styles[key])

func _activate_focused_key():
	if current_focused_key != null:
		# Получаем данные ключа
		var key_data = current_focused_key.get_meta("key_data", {})
		
		# Эмулируем нажатие кнопки
		current_focused_key.pressed.emit()
		
		# Немного задержки для визуального эффекта
		await get_tree().create_timer(0.1).timeout
		current_focused_key.released.emit()

func _build_keyboard_grid():
	keyboard_grid.clear()
	
	if current_layout == null:
		print("Нет активной раскладки для построения сетки")
		return
	
	# Получаем контейнер с раскладкой
	var layout_container = current_layout
	if layout_container.get_child_count() == 0:
		print("Нет дочерних элементов в раскладке")
		return
	
	var base_vbox = layout_container.get_child(0)
	if not base_vbox is VBoxContainer:
		print("Первый дочерний элемент не VBoxContainer")
		return
	
	# Строим сетку по строкам
	for i in range(base_vbox.get_child_count()):
		var hbox = base_vbox.get_child(i)
		if hbox is HBoxContainer:
			var row = []
			for j in range(hbox.get_child_count()):
				var key = hbox.get_child(j)
				# Проверяем, что это кнопка клавиатуры
				if key.has_method("released") and key.has_method("pressed"):
					row.append(key)
			if not row.is_empty():
				keyboard_grid.append(row)
	
	print("Построена сетка клавиатуры: ", keyboard_grid.size(), " строк")
	
	# Устанавливаем фокус на первую кнопку
	if not keyboard_grid.is_empty() and not keyboard_grid[0].is_empty():
		_set_focused_key(Vector2i(0, 0))

###########################
## INIT
###########################
var KeyboardButton
var KeyListHandler

var layouts = []
var keys = []
var capslock_keys = []
var uppercase = false

var tween_position
var tween_speed = .2

var hide_position = Vector2()

func _init_keyboard():
	if custom_layout_file == null:
		var default_layout = preload("default_layout.gd").new()
		_create_keyboard(default_layout.data)
	else:
		_create_keyboard(_load_json(custom_layout_file))

	# init positioning without animation
	var tmp_anim = animate
	animate = false
	if visible:
		_hide_keyboard()
	elif visible:
		_show_keyboard()
	animate = tmp_anim

###########################
## HIDE/SHOW
###########################

var focus_object = null

func show():
	_show_keyboard()

func hide():
	_hide_keyboard()

var released = true
func _update_auto_display_on_input(event):
	if auto_show == false:
		return

	if event is InputEventMouseButton:
		released = !released
		if released == false:
			return

		var focus_object = get_viewport().gui_get_focus_owner()
		if focus_object != null:
			var click_on_input = Rect2(focus_object.global_position, focus_object.size).has_point(get_global_mouse_position())
			var click_on_keyboard = Rect2(global_position, size).has_point(get_global_mouse_position())

			if click_on_input:
				if is_keyboard_focus_object(focus_object):
					_show_keyboard()
			elif click_on_keyboard:
				_show_keyboard()
			else:
				_hide_keyboard()

	if event is InputEventKey:
		var focus_object = get_viewport().gui_get_focus_owner()
		if focus_object != null:
			if event.keycode == KEY_ENTER:
				if is_keyboard_focus_object_complete_on_enter(focus_object):
					focus_object.release_focus()
					_hide_keyboard()

func _hide_keyboard(key_data=null):
	controller_input_enabled = false  # Отключаем управление контроллером
	
	# Убираем фокус при скрытии
	if current_focused_key != null:
		_remove_focus_style(current_focused_key)
		current_focused_key = null
	
	if animate:
		var new_y_pos = get_viewport().get_visible_rect().size.y + 10
		animate_position(Vector2(position.x, new_y_pos), true)
	else:
		change_visibility(false)

func _show_keyboard(key_data=null):
	change_visibility(true)
	
	if animate:
		var new_y_pos = get_viewport().get_visible_rect().size.y - size.y
		animate_position(Vector2(position.x, new_y_pos))
	
	# Включаем управление контроллером и строим сетку
	if enable_controller:
		controller_input_enabled = true
		# Даем немного времени на отрисовку, потом строим сетку
		await get_tree().process_frame
		_build_keyboard_grid()

func animate_position(new_position, trigger_visibility:bool=false):
	var tween = get_tree().create_tween()
	if trigger_visibility:
		tween.finished.connect(change_visibility.bind(!visible))
	tween.tween_property(
		self,"position",
		Vector2(new_position),
		tween_speed
	).set_trans(Tween.TRANS_SINE)

func change_visibility(value):
	if value:
		super.show()
	else:
		_set_caps_lock(false)
		# Убираем фокус при скрытии
		if current_focused_key != null:
			_remove_focus_style(current_focused_key)
			current_focused_key = null
		super.hide()
	visibility_changed.emit()

###########################
##  KEY LAYOUT
###########################

var prev_prev_layout = null
var previous_layout = null
var current_layout = null

func set_active_layout_by_name(name):
	for layout in layouts:
		if layout.get_meta("layout_name") == str(name):
			_show_layout(layout)
		else:
			_hide_layout(layout)

func _show_layout(layout):
	layout.show()
	current_layout = layout
	# Перестраиваем сетку при смене раскладки
	if enable_controller and visible and controller_input_enabled:
		await get_tree().process_frame
		_build_keyboard_grid()

func _hide_layout(layout):
	layout.hide()

func _switch_layout(key_data):
	prev_prev_layout = previous_layout
	previous_layout = current_layout
	layout_changed.emit(key_data.get("layout-name"))

	for layout in layouts:
		_hide_layout(layout)

	if key_data.get("layout-name") == "PREVIOUS-LAYOUT":
		if prev_prev_layout != null:
			_show_layout(prev_prev_layout)
			return

	for layout in layouts:
		if layout.get_meta("layout_name") == key_data.get("layout-name"):
			_show_layout(layout)
			return

	_set_caps_lock(false)

###########################
## KEY EVENTS
###########################

func _set_caps_lock(value: bool):
	uppercase = value
	for key in capslock_keys:
		if value:
			if key.get_draw_mode() != BaseButton.DRAW_PRESSED:
				key.button_pressed = !key.button_pressed
		else:
			if key.get_draw_mode() == BaseButton.DRAW_PRESSED:
				key.button_pressed = !key.button_pressed

	for key in keys:
		key.change_uppercase(value)

func _trigger_uppercase(key_data):
	uppercase = !uppercase
	_set_caps_lock(uppercase)

func _key_released(key_data):
	if key_data.has("output"):
		var key_value = key_data.get("output")

		###########################
		## DISPATCH InputEvent 
		###########################

		var input_event_key = InputEventKey.new()
		input_event_key.shift_pressed = uppercase
		input_event_key.alt_pressed = false
		input_event_key.meta_pressed = false
		input_event_key.ctrl_pressed = false
		input_event_key.pressed = true

		var key = KeyListHandler.get_key_from_string(key_value)
		if !uppercase && KeyListHandler.has_lowercase(key_value):
			key +=32

		input_event_key.keycode = key
		input_event_key.unicode = key

		Input.parse_input_event(input_event_key)

		###########################
		## DISABLE CAPSLOCK AFTER 
		###########################
		_set_caps_lock(false)

###########################
## CONSTRUCT KEYBOARD
###########################

func _set_key_style(style_name:String, key: Control, style:StyleBoxFlat):
	if style != null:
		key.add_theme_stylebox_override(style_name, style)

func _create_keyboard(layout_data):
	if layout_data == null:
		print("ERROR. No layout file found")
		return

	KeyListHandler = preload("keylist.gd").new()
	KeyboardButton = preload("keyboard_button.gd")

	var ICON_DELETE = preload("icons/delete.png")
	var ICON_SHIFT = preload("icons/shift.png")
	var ICON_LEFT = preload("icons/left.png")
	var ICON_RIGHT = preload("icons/right.png")
	var ICON_HIDE = preload("icons/hide.png")
	var ICON_ENTER = preload("icons/enter.png")

	var data = layout_data

	if style_background != null:
		add_theme_stylebox_override('panel', style_background)

	var index = 0
	for layout in data.get("layouts"):

		var layout_container = PanelContainer.new()

		if style_background != null:
			layout_container.add_theme_stylebox_override('panel', style_background)

		# SHOW FIRST LAYOUT ON DEFAULT
		if index > 0:
			layout_container.hide()
		else:
			current_layout = layout_container

		var layout_name = layout.get("name")
		layout_container.set_meta("layout_name", layout_name)
		if set_tool_tip:
			layout_container.tooltip_text = layout_name
		layouts.push_back(layout_container)
		add_child(layout_container)

		var base_vbox = VBoxContainer.new()
		base_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
		base_vbox.size_flags_vertical = SIZE_EXPAND_FILL
		# theme override for spacing
		base_vbox.add_theme_constant_override("separation", separation.y)

		for row in layout.get("rows"):

			var key_row = HBoxContainer.new()
			key_row.size_flags_horizontal = SIZE_EXPAND_FILL
			key_row.size_flags_vertical = SIZE_EXPAND_FILL
			key_row.add_theme_constant_override("separation", separation.x)

			for key in row.get("keys"):
				var new_key = KeyboardButton.new(key)
				
				# Сохраняем данные ключа в метаданных
				new_key.set_meta("key_data", key)

				_set_key_style("normal",new_key, style_normal)
				_set_key_style("hover",new_key, style_hover)
				_set_key_style("pressed",new_key, style_pressed)

				new_key.set('theme_override_font_sizes/font_size', font_size)
				if font != null:
					new_key.set('theme_override_fonts/font', font)
				if font_color_normal != null:
					new_key.set('theme_override_colors/font_color', font_color_normal)
					new_key.set('theme_override_colors/font_hover_color', font_color_hover)
					new_key.set('theme_override_colors/font_pressed_color', font_color_pressed)
					new_key.set('theme_override_colors/font_disabled_color', font_color_normal)

				new_key.released.connect(_key_released)

				if key.has("type"):
					if key.get("type") == "switch-layout":
						new_key.released.connect(_switch_layout)
						_set_key_style("normal",new_key, style_special_keys)
					elif key.get("type") == "special":
						_set_key_style("normal",new_key, style_special_keys)
					elif key.get("type") == "special-shift":
						new_key.released.connect(_trigger_uppercase)
						new_key.toggle_mode = true
						capslock_keys.push_back(new_key)
						_set_key_style("normal",new_key, style_special_keys)
					elif key.get("type") == "special-hide-keyboard":
						new_key.released.connect(_hide_keyboard)
						_set_key_style("normal",new_key, style_special_keys)

				# SET ICONS
				if key.has("display-icon"):
					var icon_data = str(key.get("display-icon")).split(":")
					# PREDEFINED
					if str(icon_data[0])=="PREDEFINED":
						if str(icon_data[1])=="DELETE":
							new_key.set_icon(ICON_DELETE)
						elif str(icon_data[1])=="SHIFT":
							new_key.set_icon(ICON_SHIFT)
						elif str(icon_data[1])=="LEFT":
							new_key.set_icon(ICON_LEFT)
						elif str(icon_data[1])=="RIGHT":
							new_key.set_icon(ICON_RIGHT)
						elif str(icon_data[1])=="HIDE":
							new_key.set_icon(ICON_HIDE)
						elif str(icon_data[1])=="ENTER":
							new_key.set_icon(ICON_ENTER)
					# CUSTOM
					if str(icon_data[0])=="res":
						var texture = load(key.get("display-icon"))
						new_key.set_icon(texture)

					if font_color_normal != null:
						new_key.set_icon_color(font_color_normal)

				key_row.add_child(new_key)
				keys.push_back(new_key)

			base_vbox.add_child(key_row)

		layout_container.add_child(base_vbox)
		index+=1

###########################
## LOAD SETTINGS
###########################

func _load_json(file_path) -> Variant:
	var json = JSON.new()
	var json_string = _load_file(file_path)
	var error = json.parse(json_string)
	if error == OK:
		var data_received = json.data
		#        print(data_received)
		if typeof(data_received) == TYPE_DICTIONARY:
			return data_received
		else:
			return {"msg": "unexpected data => expected DICTIONARY"}
	else:
		print("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
		return {"msg":json.get_error_message()}

func _load_file(file_path):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("Error loading File. Error: ")

	var content = file.get_as_text()
	file.close()
	return content

###########################
## HELPER
###########################

func is_keyboard_focus_object_complete_on_enter(focus_object):
	if focus_object is LineEdit:
		return true
	return false

func is_keyboard_focus_object(focus_object):
	if focus_object is LineEdit or focus_object is TextEdit:
		return true
	return false
