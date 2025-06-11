# SteamAPI.gd - Упрощенный класс для поиска игр в Steam
class_name SteamAPI
extends RefCounted

var http_request: HTTPRequest
var current_callback: Callable

# Разделяем сигналы для логотипа и описания
signal logo_found(game_data: Dictionary)
signal description_found(game_data: Dictionary)
signal game_not_found()

func setup_http_request(parent_node: Node):
	"""Настройка HTTP запросов"""
	http_request = HTTPRequest.new()
	parent_node.add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

func search_game(game_name: String, callback: Callable = Callable()):
	"""Поиск игры по названию и получение логотипа с описанием (полный поиск)"""
	_search_game_internal(game_name, callback, true, true)

func search_game_logo_only(game_name: String, callback: Callable = Callable()):
	"""Поиск игры только для получения логотипа"""
	_search_game_internal(game_name, callback, true, false)

func search_game_description_only(game_name: String, callback: Callable = Callable()):
	"""Поиск игры только для получения описания"""
	_search_game_internal(game_name, callback, false, true)

func _search_game_internal(game_name: String, callback: Callable, need_logo: bool, need_description: bool):
	"""Внутренний метод поиска с возможностью выбора что загружать"""
	if not http_request:
		print("HTTPRequest не настроен! Вызовите setup_http_request() сначала")
		return
	
	current_callback = callback
	
	# Поиск с русской локализацией
	var search_url = "https://store.steampowered.com/api/storesearch/"
	var query_params = "?term=" + game_name.uri_encode() + "&l=russian&cc=RU"
	var full_url = search_url + query_params
	
	print("Ищем игру: ", game_name)
	
	var headers = ["User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"]
	
	# Сохраняем флаги что нужно загружать
	http_request.set_meta("need_logo", need_logo)
	http_request.set_meta("need_description", need_description)
	
	http_request.request(full_url, headers)

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	"""Обработка ответа от Steam API"""
	if response_code != 200:
		print("Ошибка HTTP запроса: ", response_code)
		game_not_found.emit()
		if current_callback.is_valid():
			current_callback.call(null)
		return
	
	var json_text = body.get_string_from_utf8()
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		print("Ошибка парсинга JSON")
		game_not_found.emit()
		if current_callback.is_valid():
			current_callback.call(null)
		return
	
	var data = json.data
	
	# Проверяем результаты поиска
	if data.has("items") and data.items.size() > 0:
		var first_game = data.items[0]
		var app_id = first_game.id
		
		# Получаем флаги что нужно загружать
		var need_logo = http_request.get_meta("need_logo", false)
		var need_description = http_request.get_meta("need_description", false)
		
		# Загружаем то что нужно
		if need_description:
			_get_game_description(app_id, first_game, need_logo)
		elif need_logo:
			_download_logo(app_id, first_game, "")
	else:
		print("Игра не найдена")
		game_not_found.emit()
		if current_callback.is_valid():
			current_callback.call(null)

func _get_game_description(app_id: int, basic_info: Dictionary, also_need_logo: bool = false):
	"""Получение описания игры"""
	var details_url = "https://store.steampowered.com/api/appdetails/"
	var query_params = "?appids=" + str(app_id) + "&l=russian"
	var full_url = details_url + query_params
	
	# Создаем новый HTTP запрос для деталей
	var detail_request = HTTPRequest.new()
	http_request.get_parent().add_child(detail_request)
	
	detail_request.request_completed.connect(func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
		_on_details_completed(result, response_code, headers, body, app_id, basic_info, detail_request, also_need_logo)
	)
	
	var headers = ["User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"]
	detail_request.request(full_url, headers)

func _on_details_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, app_id: int, basic_info: Dictionary, request_node: HTTPRequest, also_need_logo: bool):
	"""Обработка деталей игры"""
	request_node.queue_free() # Удаляем временный HTTP запрос
	
	var description = "Описание недоступно"
	
	if response_code == 200:
		var json_text = body.get_string_from_utf8()
		var json = JSON.new()
		if json.parse(json_text) == OK:
			var data = json.data
			var app_id_str = str(app_id)
			
			if data.has(app_id_str) and data[app_id_str].has("success") and data[app_id_str].success:
				var game_data = data[app_id_str].data
				description = game_data.get("short_description", "Описание недоступно")
	
	# Отправляем описание
	var description_data = {
		"name": basic_info.get("name", ""),
		"app_id": app_id,
		"description": description
	}
	
	description_found.emit(description_data)
	
	# Если нужен еще и логотип - загружаем его
	if also_need_logo:
		_download_logo(app_id, basic_info, description)

func _download_logo(app_id: int, basic_info: Dictionary, description: String = ""):
	"""Загрузка логотипа как текстуры"""
	var logo_url = "https://cdn.akamai.steamstatic.com/steam/apps/" + str(app_id) + "/logo.png"
	
	# Создаем HTTP запрос для загрузки изображения
	var image_request = HTTPRequest.new()
	http_request.get_parent().add_child(image_request)
	
	image_request.request_completed.connect(func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
		_on_image_downloaded(result, response_code, headers, body, app_id, basic_info, description, image_request)
	)
	
	print("Загружаем логотип...")
	var headers = ["User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"]
	image_request.request(logo_url, headers)

func _on_image_downloaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, app_id: int, basic_info: Dictionary, description: String, request_node: HTTPRequest):
	"""Обработка загруженного изображения"""
	request_node.queue_free() # Удаляем временный HTTP запрос
	
	var logo_texture: ImageTexture = null
	
	if response_code == 200 and body.size() > 0:
		# Создаем изображение из загруженных данных
		var image = Image.new()
		var error = image.load_png_from_buffer(body)
		
		if error == OK:
			# Создаем текстуру из изображения
			logo_texture = ImageTexture.new()
			logo_texture.set_image(image)
			print("Логотип загружен успешно")
		else:
			print("Ошибка загрузки изображения: ", error)
	else:
		print("Не удалось загрузить логотип")
	
	# Формируем данные для логотипа
	var logo_data = {
		"name": basic_info.get("name", ""),
		"app_id": app_id,
		"logo_texture": logo_texture,
		"description": description
	}
	
	print("Логотип найден для игры: ", logo_data.name)
	logo_found.emit(logo_data)
	if current_callback.is_valid():
		current_callback.call(logo_data)
