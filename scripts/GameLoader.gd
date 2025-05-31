class_name GameLoader
extends RefCounted

# Структура данных игры
class GameData:
	var title: String = ""
	var front: String = ""
	var back: String = ""
	var spine: String = ""
	var executable: String = ""
	var box_type: String = "xbox"  # По умолчанию Xbox, можно "xbox" или "pc"
	
	func _init(data: Dictionary = {}):
		if data.has("title"):
			title = data["title"]
		if data.has("front"):
			front = data["front"]
		if data.has("back"):
			back = data["back"]
		if data.has("spine"):
			spine = data["spine"]
		if data.has("executable"):
			executable = data["executable"]
		if data.has("box_type"):
			box_type = data["box_type"]
		else:
			box_type = "xbox"  # Fallback на Xbox если не указано

# Загрузить все игры из директории
static func load_all_games() -> Array[GameData]:
	var games: Array[GameData] = []
	var games_dir = "user://games/"
	
	print("Поиск игр в директории: ", games_dir)
	
	if not DirAccess.dir_exists_absolute(games_dir):
		print("Директория games не найдена, создаем...")
		DirAccess.open("user://").make_dir("games")
		return games
	
	var dir = DirAccess.open(games_dir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".json"):
				print("Найден файл игры: ", file_name)
				var game_data = load_game_data(games_dir + file_name)
				if game_data:
					games.append(game_data)
					print("Игра загружена: ", game_data.title, " (тип коробки: ", game_data.box_type, ")")
			file_name = dir.get_next()
		
		dir.list_dir_end()
	else:
		print("Не удалось открыть директорию: ", games_dir)
	
	print("Всего загружено игр: ", games.size())
	return games

# Загрузить данные конкретной игры
static func load_game_data(file_path: String) -> GameData:
	print("Загрузка данных игры из: ", file_path)
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("Не удалось открыть файл: ", file_path)
		return null
	
	var json_string = file.get_as_text()
	file.close()
	
	if json_string.is_empty():
		print("Пустой файл: ", file_path)
		return null
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		print("Ошибка парсинга JSON в файле ", file_path, ": ", json.error_string)
		return null
	
	var data = json.get_data()
	if not data is Dictionary:
		print("Неверный формат данных в файле: ", file_path)
		return null
	
	var game_data = GameData.new(data)
	print("Данные игры загружены: ", game_data.title)
	print("  Передняя: ", game_data.front)
	print("  Задняя: ", game_data.back)
	print("  Корешок: ", game_data.spine)
	print("  Тип коробки: ", game_data.box_type)
	
	return game_data

# Загрузить текстуру из пути
static func load_texture_from_path(path: String) -> Texture2D:
	if path == "":
		print("Пустой путь к текстуре")
		return null
	
	print("Попытка загрузки текстуры: ", path)
	
	if not FileAccess.file_exists(path):
		print("Файл текстуры не существует: ", path)
		return null
	
	var image = Image.new()
	var error = image.load(path)
	
	if error != OK:
		print("Ошибка загрузки изображения ", path, ": ", error)
		return null
	
	print("Изображение загружено, размер: ", image.get_width(), "x", image.get_height())
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	
	print("Текстура создана успешно")
	return texture

# Проверить существование файла текстуры
static func texture_file_exists(path: String) -> bool:
	if path == "":
		return false
	return FileAccess.file_exists(path)

# Получить информацию о текстуре
static func get_texture_info(path: String) -> Dictionary:
	var info = {}
	info["exists"] = texture_file_exists(path)
	info["path"] = path
	
	if info["exists"]:
		var image = Image.new()
		var error = image.load(path)
		if error == OK:
			info["width"] = image.get_width()
			info["height"] = image.get_height()
			info["format"] = image.get_format()
		else:
			info["error"] = "Не удалось загрузить изображение"
	
	return info
