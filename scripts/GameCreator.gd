extends Control
@onready var game_name = $Panel/Name
@onready var front = $Panel/Front
@onready var back = $Panel/Back
@onready var spine = $Panel/Spine
@onready var executable = $Panel/Executable
@onready var done_button = $Panel/Done
@onready var option_button = $Panel/OptionButton
@onready var download_button = $Panel/DownloadCovers  # Кнопка для скачивания

var file_dialog: FileDialog
var executable_dialog: FileDialog
var current_button: String = ""
var coverflow_scene: PackedScene

@export var game_data = {
	"title": "",
	"front": "",
	"back": "",
	"spine": "",
	"executable": "",
	"box_type": "xbox"
}

func _ready():
	print("GameCreator готов, блядь")
	
	# Создаем файловый диалог для изображений
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.add_filter("*.png", "PNG Images")
	file_dialog.add_filter("*.jpg", "JPEG Images") 
	file_dialog.add_filter("*.jpeg", "JPEG Images")
	file_dialog.add_filter("*.bmp", "BMP Images")
	file_dialog.add_filter("*.webp", "WebP Images")
	file_dialog.file_selected.connect(_on_file_selected)
	add_child(file_dialog)
	
	# Создаем файловый диалог для исполняемых файлов
	executable_dialog = FileDialog.new()
	executable_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	executable_dialog.access = FileDialog.ACCESS_FILESYSTEM
	
	# Добавляем фильтры в зависимости от ОС
	if OS.get_name() == "Windows":
		executable_dialog.add_filter("*.exe", "Windows Executable")
		executable_dialog.add_filter("*.bat", "Batch Files")
		executable_dialog.add_filter("*.cmd", "Command Files")
	elif OS.get_name() == "Linux":
		executable_dialog.add_filter("*.sh", "Shell Scripts")
		executable_dialog.add_filter("*.exe", "Windows Executable (Wine)")
		executable_dialog.add_filter("*.x86_64", "x86 64 Bit Executable")
		executable_dialog.add_filter("*", "All Files")
	elif OS.get_name() == "macOS":
		executable_dialog.add_filter("*.app", "macOS Applications")
		executable_dialog.add_filter("*.sh", "Shell Scripts")
		executable_dialog.add_filter("*", "All Files")
	else:
		executable_dialog.add_filter("*", "All Files")
	
	executable_dialog.file_selected.connect(_on_executable_selected)
	add_child(executable_dialog)
	
	# Создаем папку covers если её нет
	ensure_covers_directory()
	
	# Загружаем сцену coverflow
	coverflow_scene = preload("res://scenes/CoverFlow.tscn")
	
	option_button.add_item("Xbox 360", 0)
	option_button.add_item("PC/Steam", 1)
	option_button.item_selected.connect(_on_option_button_item_selected)

func ensure_covers_directory():
	"""Создает папку covers если её нет"""
	var covers_path = get_covers_directory()
	if not DirAccess.dir_exists_absolute(covers_path):
		var result = DirAccess.open("user://").make_dir_recursive(covers_path.get_file())
		if result == OK:
			print("Папка covers создана: ", covers_path)
		else:
			print("Ошибка создания папки covers: ", result)

func get_covers_directory() -> String:
	"""Возвращает путь к папке covers"""
	return "user://covers/"

func get_steamboxcover_path() -> String:
	"""Возвращает путь к программе steamboxcover с улучшенной отладкой"""
	var exe_path = OS.get_executable_path()
	var exe_dir = exe_path.get_base_dir()
	
	print("Исполняемый файл Godot: ", exe_path)
	print("Директория исполняемого файла: ", exe_dir)
	
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
	
	print("Основной путь: ", steamboxcover_path)
	print("Альтернативный путь: ", alt_path)
	
	# Если основной путь не существует, пробуем альтернативный
	if not FileAccess.file_exists(steamboxcover_path) and FileAccess.file_exists(alt_path):
		print("Используем альтернативный путь")
		return alt_path
	
	return steamboxcover_path

func get_spine_template_path() -> String:
	"""Возвращает путь к шаблону spine"""
	var exe_path = OS.get_executable_path()
	var exe_dir = exe_path.get_base_dir()
	return exe_dir + "/steam_spine.png"

func _on_download_covers_pressed():
	"""Запускает загрузку обложек через steamboxcover"""
	var title = game_name.text.strip_edges()
	if title == "":
		show_notification("Введите название игры!")
		return
	
	var steamboxcover_path = get_steamboxcover_path()
	var spine_template_path = get_spine_template_path()
	var covers_dir = get_covers_directory()
	
	# Логируем все пути для отладки
	print("=== ОТЛАДКА ЗАПУСКА STEAMBOXCOVER ===")
	print("Путь к steamboxcover: ", steamboxcover_path)
	print("Существует ли файл: ", FileAccess.file_exists(steamboxcover_path))
	print("Путь к spine template: ", spine_template_path)
	print("Папка covers: ", covers_dir)
	print("Глобальный путь covers: ", ProjectSettings.globalize_path(covers_dir))
	
	# Проверяем существование программы
	if not FileAccess.file_exists(steamboxcover_path):
		show_notification("Программа steamboxcover не найдена!")
		print("ОШИБКА: Ожидался путь: ", steamboxcover_path)
		return
	
	# Проверяем права на выполнение (для Linux/Mac)
	if OS.get_name() != "Windows":
		var test_output = []
		var test_result = OS.execute("ls", ["-la", steamboxcover_path], test_output, true)
		print("Права доступа к файлу: ", test_output)
	
	# Проверяем шаблон spine (не критично если нет)
	if not FileAccess.file_exists(spine_template_path):
		print("ВНИМАНИЕ: Шаблон spine не найден: ", spine_template_path)
		spine_template_path = ""
	
	# Формируем команду
	var args = []
	args.append("--game")
	args.append(title)
	args.append("--output_dir")
	args.append(ProjectSettings.globalize_path(covers_dir))
	
	if spine_template_path != "":
		args.append("--spine_template")
		args.append(ProjectSettings.globalize_path(spine_template_path))
	
	print("Полная команда: ", steamboxcover_path, " ", args)
	
	# Временно блокируем кнопку
	download_button.text = "Загрузка..."
	download_button.disabled = true
	
	# Синхронный запуск - работает отлично!
	var output = []
	print("Запуск синхронного процесса...")
	var result = OS.execute(steamboxcover_path, args, output, true, false)
	
	print("Код результата: ", result)
	print("Вывод программы: ", output)
	
	# Восстанавливаем кнопку
	download_button.text = "Скачать обложки"
	download_button.disabled = false
	
	if result != OK:
		print("ОШИБКА: Синхронный запуск провалился с кодом: ", result)
		
		# Пробуем запуск через командную строку системы
		print("Пробуем альтернативный способ запуска...")
		var alt_result = try_alternative_execution(steamboxcover_path, args)
		if not alt_result:
			show_notification("Все способы запуска провалились!")
			return
	
	# Если всё прошло успешно
	if result == OK:
		show_notification("Обложки загружены успешно!")
		
		# Ищем и применяем созданные обложки
		var found_covers = find_covers_for_game(title)
		if found_covers.size() > 0:
			print("Найдены и применяются обложки: ", found_covers)
			apply_found_covers(found_covers)
		else:
			print("Хм, обложки не найдены, хотя программа отработала...")
			# Попробуем найти по безопасному имени
			found_covers = find_covers_for_game(make_safe_filename(title))
			if found_covers.size() > 0:
				print("Найдены обложки по безопасному имени: ", found_covers)
				apply_found_covers(found_covers)
	else:
		show_notification("Ошибка запуска загрузки обложек!")
		print("ОШИБКА: Синхронный запуск провалился с кодом: ", result)

func try_alternative_execution(program_path: String, arguments: Array) -> bool:
	"""Пробует альтернативные способы запуска программы"""
	var os_name = OS.get_name()
	
	match os_name:
		"Windows":
			# Пробуем через cmd
			var cmd_args = ["/c", program_path]
			cmd_args.append_array(arguments)
			var output = []
			var result = OS.execute("cmd", cmd_args, output, true, false)
			print("CMD запуск результат: ", result)
			print("CMD вывод: ", output)
			return result == OK
			
		"Linux", "macOS":
			# Пробуем через bash
			var bash_command = program_path + " " + " ".join(arguments)
			var output = []
			var result = OS.execute("bash", ["-c", bash_command], output, true, false)
			print("Bash запуск результат: ", result)
			print("Bash вывод: ", output)
			return result == OK
	
	return false

func find_covers_for_game(game_title: String) -> Dictionary:
	"""Ищет обложки для указанной игры в папке covers"""
	var covers_dir = get_covers_directory()
	var found = {}
	
	var dir = DirAccess.open(covers_dir)
	if not dir:
		print("Не удалось открыть папку covers: ", covers_dir)
		return found
	
	print("Ищем обложки для игры: ", game_title, " в папке: ", covers_dir)
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		print("Проверяем файл: ", file_name)
		
		# Проверяем точное совпадение с названием игры
		if file_name.begins_with(game_title):
			var full_path = covers_dir + file_name
			var lower_filename = file_name.to_lower()
			
			print("Найден подходящий файл: ", file_name)
			
			# Определяем тип обложки по окончанию имени файла
			if lower_filename.ends_with("_back.png") or lower_filename.ends_with("_back.jpg"):
				found["back"] = full_path
				print("Найдена задняя обложка: ", full_path)
			elif lower_filename.ends_with("_spine.png") or lower_filename.ends_with("_spine.jpg"):
				found["spine"] = full_path  
				print("Найдена боковая обложка: ", full_path)
			elif (lower_filename.ends_with(".png") or lower_filename.ends_with(".jpg")) and not lower_filename.contains("_"):
				# Это передняя обложка (без суффикса)
				found["front"] = full_path
				print("Найдена передняя обложка: ", full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	print("Итого найдено обложек: ", found.size())
	return found

func make_safe_filename(text: String) -> String:
	"""Создает безопасное имя файла из текста"""
	var safe = text.replace(" ", "_").replace("/", "_").replace("\\", "_")
	var invalid_chars = ["<", ">", ":", "\"", "|", "?", "*"]
	for char in invalid_chars:
		safe = safe.replace(char, "_")
	return safe

func apply_found_covers(covers: Dictionary):
	"""Применяет найденные обложки к game_data"""
	for cover_type in covers:
		var path = covers[cover_type]
		game_data[cover_type] = path
		
		# Обновляем UI кнопок
		match cover_type:
			"front":
				front.text = "Передняя ✓"
				front.modulate = Color.GREEN
			"back":
				back.text = "Задняя ✓" 
				back.modulate = Color.GREEN
			"spine":
				spine.text = "Боковая ✓"
				spine.modulate = Color.GREEN
		
		print("Обложка применена: ", cover_type, " -> ", path)

func _on_done_pressed():
	if game_name.text.strip_edges() == "":
		show_notification("Введите название игры!")
		return
	
	game_data["title"] = game_name.text.strip_edges()
	
	if save_game_data():
		show_notification("Игра сохранена успешно!")
		
		# Ждем немного и возвращаемся в главное меню
		await get_tree().create_timer(1.5).timeout
		get_tree().change_scene_to_packed(coverflow_scene)
	else:
		show_notification("Ошибка при сохранении игры!")
	
func _on_front_pressed():
	current_button = "front"
	open_file_dialog()
	
func _on_back_pressed():
	current_button = "back"
	open_file_dialog()
	
func _on_spine_pressed():
	current_button = "spine"
	open_file_dialog()

func _on_executable_pressed():
	open_executable_dialog()
	
func _on_option_button_item_selected(index):
	match index:
		0:
			game_data["box_type"] = "xbox"
		1:
			game_data["box_type"] = "pc"
	
func open_file_dialog():
	file_dialog.current_file = ""
	file_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	file_dialog.popup_centered(Vector2i(800, 600))

func open_executable_dialog():
	executable_dialog.current_file = ""
	executable_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	executable_dialog.popup_centered(Vector2i(800, 600))
	
func _on_file_selected(path: String):
	print("Выбран файл: ", path, " для ", current_button)
	
	# Проверяем существование файла
	if not FileAccess.file_exists(path):
		show_notification("Файл не найден!")
		return
	
	game_data[current_button] = path
	
	# Обновляем текст кнопки
	match current_button:
		"front":
			front.text = "Передняя ✓"
			front.modulate = Color.GREEN
		"back":
			back.text = "Задняя ✓"
			back.modulate = Color.GREEN
		"spine":
			spine.text = "Боковая ✓"
			spine.modulate = Color.GREEN
	
	print("Путь сохранен: ", game_data[current_button])

func _on_executable_selected(path: String):
	print("Выбран исполняемый файл: ", path)
	
	# Проверяем существование файла
	if not FileAccess.file_exists(path):
		show_notification("Файл не найден!")
		return
	
	# Проверяем поддерживаемость файла
	if not is_executable_supported(path):
		show_notification("Неподдерживаемый тип файла для текущей ОС!")
		return
	
	game_data["executable"] = path
	executable.text = "Исполняемый ✓"
	executable.modulate = Color.GREEN
	
	print("Исполняемый файл сохранен: ", path)

func is_executable_supported(path: String) -> bool:
	var extension = path.get_extension().to_lower()
	var os_name = OS.get_name()
	
	match os_name:
		"Windows":
			return extension in ["exe", "bat", "cmd"]
		"Linux":
			return extension in ["sh", "exe"] or extension == ""
		"macOS":
			return extension in ["app", "sh"] or extension == ""
		_:
			return true

func save_game_data() -> bool:
	var title = game_data["title"].strip_edges()
	if title == "":
		return false
	
	# Создаем безопасное имя файла
	var file_name = title.replace(" ", "_").replace("/", "_").replace("\\", "_")
	var invalid_chars = ["<", ">", ":", "\"", "|", "?", "*"]
	for char in invalid_chars:
		file_name = file_name.replace(char, "_")
	
	var file_path = "user://games/" + file_name + ".json"
	
	# Создаем директорию если её нет
	if not DirAccess.dir_exists_absolute("user://games/"):
		var result = DirAccess.open("user://").make_dir("games")
		if result != OK:
			print("Ошибка создания директории games: ", result)
			return false
	
	# Сохраняем файл
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(game_data)
		file.store_string(json_string)
		file.close()
		print("Игра сохранена в: ", file_path)
		return true
	else:
		print("Ошибка создания файла: ", file_path)
		return false

func save_temp_game_data(data: Dictionary) -> bool:
	var file_path = "user://temp_preview_game.json"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(data)
		file.store_string(json_string)
		file.close()
		print("Временные данные сохранены для предпросмотра")
		return true
	else:
		print("Ошибка сохранения временных данных")
		return false

func show_notification(message: String):
	print("Уведомление: ", message)
	
	# Создаем диалог уведомления
	var notification = AcceptDialog.new()
	notification.dialog_text = message
	notification.title = "Информация"
	notification.size = Vector2i(400, 150)
	add_child(notification)
	notification.popup_centered()
	
	# Удаляем диалог через 3 секунды
	get_tree().create_timer(3.0).timeout.connect(func(): 
		if is_instance_valid(notification):
			notification.queue_free()
	)

# Обработка нажатия Escape для возврата в главное меню
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_packed(coverflow_scene)
