extends Control
@onready var game_name = $Panel/Name
@onready var front = $Panel/Front
@onready var back = $Panel/Back
@onready var spine = $Panel/Spine
@onready var executable = $Panel/Executable  # Новая кнопка для выбора файла запуска
@onready var done_button = $Panel/Done
@onready var option_button = $Panel/OptionButton

var file_dialog: FileDialog
var executable_dialog: FileDialog  # Отдельный диалог для исполняемых файлов
var current_button: String = ""
var coverflow_scene: PackedScene

@export var game_data = {
	"title": "",
	"front": "",
	"back": "",
	"spine": "",
	"executable": "",  # Путь к исполняемому файлу
	"box_type": "xbox"
}

func _ready():
	print("GameCreator готов")
	
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
		executable_dialog.add_filter("*", "All Files")
	elif OS.get_name() == "macOS":
		executable_dialog.add_filter("*.app", "macOS Applications")
		executable_dialog.add_filter("*.sh", "Shell Scripts")
		executable_dialog.add_filter("*", "All Files")
	else:
		executable_dialog.add_filter("*", "All Files")
	
	executable_dialog.file_selected.connect(_on_executable_selected)
	add_child(executable_dialog)
	
	# Загружаем сцену coverflow
	coverflow_scene = preload("res://scenes/CoverFlow.tscn")
	
	option_button.add_item("Xbox 360", 0)
	option_button.add_item("PC/Steam", 1)
	option_button.item_selected.connect(_on_option_button_item_selected)
	
	# Подключаем кнопки
#	if done_button:
#		done_button.pressed.connect(_on_done_pressed)
#	if executable:
#		executable.pressed.connect(_on_executable_pressed)
	
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
			return extension in ["sh", "exe"] or extension == ""  # Пустое расширение для исполняемых файлов
		"macOS":
			return extension in ["app", "sh"] or extension == ""
		_:
			return true  # Для неизвестных ОС разрешаем все

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
