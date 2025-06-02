extends Control

@onready var viewport_3d = $ViewportContainer/SubViewport
@onready var camera_3d = $ViewportContainer/SubViewport/Camera3D
@onready var game_title_label = $GameTitleLabel
@onready var keyboard_control = $Keyboard
@onready var left_button = $Keyboard/LeftButton
@onready var right_button = $Keyboard/RightButton
@onready var gamepad_control = $Gamepad
# Иконки для геймпадов
@onready var a_button = $Gamepad/Instruction/Zapusk/Play
@onready var dpad_button = $Gamepad/Instruction/Navigation/Navigation
@onready var start_button = $Gamepad/Add/Start
@onready var controller_icon = $Gamepad/Controller/Icon

# Массив игр и 3D объектов
var games: Array[GameLoader.GameData] = []
var game_covers: Array[GameCover3D] = []
var current_index: int = 0

# Настройки coverflow (подкорректированы для больших коробок)
@export var cover_spacing: float = 8.0
@export var side_angle: float = 60.0
@export var side_offset: float = 3.0

const GamepadType = preload("res://scripts/GamepadType.gd")
var gamepadtype = GamepadType.new()

# Шаблон сценки GameCover
var game_cover_scene: PackedScene

# Флаг для проверки первого обновления
var first_update: bool = true

var current_input_method = "keyboard" # по дефолту клава

func _ready():
	print("CoverFlow готов к работе")
	
	load_games()
	setup_ui()
	setup_keyboard_ui()
	
	for device_id in Input.get_connected_joypads():
		update_controller_icon(device_id)
		
	# Ждем один кадр перед настройкой coverflow
	await get_tree().process_frame
	setup_coverflow()
	# Ждем еще один кадр перед первым обновлением
	await get_tree().process_frame
	update_display()

func load_games():
	print("Загрузка игр...")
	games = GameLoader.load_all_games()
	print("Загружено игр: ", games.size())
	
	cleanup_unused_covers()
	
	if games.is_empty():
		print("Игр не найдено, коробки не будут созданы")
	else:
		for i in range(games.size()):
			print("Игра ", i, ": ", games[i].title)

func cleanup_unused_covers():
	"""Удаляет неиспользуемые обложки из папки covers"""
	var covers_dir = "user://covers/"
	
	if not DirAccess.dir_exists_absolute(covers_dir):
		return
	
	# Собираем все используемые пути к обложкам
	var used_covers = {}
	for game in games:
		if game.get("front") != "":
			used_covers[game.front] = true
		if game.get("back") != "":
			used_covers[game.back] = true
		if game.get("spine") != "":
			used_covers[game.spine] = true
	
	# Сканируем папку covers и удаляем неиспользуемые файлы
	var dir = DirAccess.open(covers_dir)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not file_name.begins_with("."):  # Пропускаем скрытые файлы
			var full_path = covers_dir + file_name
			
			# Если файл не используется ни одной игрой - удаляем
			if not used_covers.has(full_path):
				print("Удаляем неиспользуемую обложку: ", full_path)
				dir.remove(file_name)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func setup_ui():
	left_button.pressed.connect(_on_left_pressed)
	right_button.pressed.connect(_on_right_pressed)
	
	# Скрываем кнопки если игр мало
	if games.size() <= 1:
		left_button.visible = false
		right_button.visible = false
		
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
	print("Настройка coverflow...")
	
	# Очищаем предыдущие коробки
	for cover in game_covers:
		if is_instance_valid(cover):
			cover.queue_free()
	game_covers.clear()
	
	# Ждем один кадр для очистки
	await get_tree().process_frame
	
	if games.is_empty():
		print("Игр нет, коробки не создаются")
		return
	
	# Создаем 3D объекты для каждой игры
	for i in range(games.size()):
		var cover_instance: GameCover3D
		
		if game_cover_scene:
			# Используем сцену если она есть
			cover_instance = game_cover_scene.instantiate()
		else:
			# Создаем экземпляр класса напрямую
			cover_instance = GameCover3D.new()
		
		# Устанавливаем данные игры
		cover_instance.set_game_data(games[i])
		
		# Добавляем в viewport
		viewport_3d.add_child(cover_instance)
		game_covers.append(cover_instance)
		
		print("Создана обложка для: ", games[i].title)
	
	print("Создано обложек: ", game_covers.size())

func update_display():
	if games.is_empty():
		print("Игр нет, очищаем отображение")
		game_title_label.text = "Нет игр"
		return
	
	print("Обновление отображения, текущий индекс: ", current_index)
	
	# Обновляем название игры
	game_title_label.text = games[current_index].title
	
	# Позиционируем все коробки
	for i in range(game_covers.size()):
		var cover = game_covers[i]
		if not is_instance_valid(cover):
			continue
			
		var offset = i - current_index
		
		var pos = Vector3()
		var rot = Vector3()
		var scl = Vector3.ONE
		
		if offset == 0:
			# Центральная (выбранная) коробка
			pos = Vector3(0, 0, 0)
			rot = Vector3(0, 0, 0)
			scl = Vector3(1.2, 1.2, 1.2)
			cover.set_selected(true)
			print("Центральная коробка: ", games[i].title)
		else:
			# Боковые коробки
			var side_multiplier = 1 if offset > 0 else -1
			var abs_offset = abs(offset)
			
			pos = Vector3(offset * cover_spacing, -0.5 * abs_offset, abs_offset * side_offset)
			rot = Vector3(0, -side_angle * side_multiplier, 0)
			scl = Vector3(0.8, 0.8, 0.8)
			cover.set_selected(false)
		
		# ВАЖНО: Принудительно устанавливаем позицию при первом обновлении
		if first_update:
			cover.position = pos
			cover.rotation_degrees = rot
			cover.scale = scl
		
		cover.set_target_transform(pos, rot, scl)
	
	# Сбрасываем флаг первого обновления
	first_update = false

func _on_left_pressed():
	if games.size() <= 1:
		return
	
	current_index -= 1
	if current_index < 0:
		current_index = games.size() - 1
	
	print("Переход влево, новый индекс: ", current_index)
	update_display()

func _on_right_pressed():
	if games.size() <= 1:
		return
	
	current_index += 1
	if current_index >= games.size():
		current_index = 0
	
	print("Переход вправо, новый индекс: ", current_index)
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
		update_controller_icon(device_id)

	if event.is_action_pressed("ui_left") or event.is_action_pressed("left_pad"):
		_on_left_pressed()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("right_pad"):
		_on_right_pressed()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("accept_pad"):
		launch_current_game()
	elif event.is_action_pressed("menu_pad"):
		add_game()

func launch_current_game():
	if games.is_empty():
		return
	
	var current_game = games[current_index]
	print("Запуск игры: ", current_game.title)
	
	# Проверяем наличие исполняемого файла
	if not current_game.get("executable") or current_game.executable == "":
		show_notification("У игры не указан исполняемый файл!")
		return
	
	# Запускаем анимацию вращения для текущей обложки
	if current_index < game_covers.size():
		var current_cover = game_covers[current_index]
		if is_instance_valid(current_cover):
			current_cover.start_spin_animation()
			print("Запущена анимация вращения для обложки")
	
	# Ждем немного для эффектности и запускаем игру
	await get_tree().create_timer(1.0).timeout
	
	if launch_game_executable(current_game.executable):
		print("Игра запущена успешно")
		show_notification("Игра \"" + current_game.title + "\" запущена!")
	else:
		print("Ошибка запуска игры")

func launch_game_executable(executable_path: String) -> bool:
	if executable_path == "" or not FileAccess.file_exists(executable_path):
		show_notification("Исполняемый файл не найден!")
		return false
	
	var extension = executable_path.get_extension().to_lower()
	var os_name = OS.get_name()
	var working_directory = executable_path.get_base_dir()
	
	print("Запуск игры: ", executable_path)
	print("ОС: ", os_name, ", Расширение: ", extension)
	print("Рабочая директория: ", working_directory)
	
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
					show_notification("Неподдерживаемый файл для Windows!")
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
						show_notification("Wine не установлен! Невозможно запустить .exe файлы")
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
					show_notification("Неподдерживаемый файл для Linux!")
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
					show_notification("Неподдерживаемый файл для macOS!")
					return false
		
		_:
			show_notification("Неподдерживаемая операционная система!")
			return false
	
	print("Команда: ", command)
	print("Аргументы: ", arguments)
	
	var pid = OS.create_process(command, arguments, false)
	if pid > 0:
		print("Игра запущена с PID: ", pid)
		return true
	else:
		print("Ошибка запуска процесса")
		return false

func is_wine_available() -> bool:
	# Проверяем наличие Wine в системе
	var output = []
	var exit_code = OS.execute("which", ["umu-run"], output)
	return exit_code == 0 and output.size() > 0

func show_notification(message: String):
	print("Уведомление: ", message)
	
	# Создаем диалог уведомления
	var notification = AcceptDialog.new()
	notification.dialog_text = message
	notification.title = "Информация"
	notification.size = Vector2i(400, 150)
	add_child(notification)
	notification.popup_centered()
	
	# Удаляем диалог через 2 секунды
	get_tree().create_timer(2.0).timeout.connect(func(): 
		if is_instance_valid(notification):
			notification.queue_free()
	)

func add_game():
	get_tree().change_scene_to_file("res://scenes/game_add.tscn")

# Функция для обновления списка игр (вызывается извне)
func refresh_games():
	print("Обновление списка игр...")
	load_games()
	if current_index >= games.size():
		current_index = max(0, games.size() - 1)
	setup_coverflow()
	update_display()
