# SteamAPI.gd - Класс для работы со Steam API
class_name SteamAPI
extends RefCounted

# Steam API ключ (можно получить здесь: https://steamcommunity.com/dev/apikey)
var api_key: String = ""
var http_request: HTTPRequest
var current_callback: Callable

signal game_found(app_id: int, game_data: Dictionary)
signal game_not_found()
signal steam_launch_success(app_id: int)
signal steam_launch_failed(error: String)

func _init(steam_api_key: String = ""):
	api_key = steam_api_key

func setup_http_request(parent_node: Node):
	"""Настройка HTTP запросов"""
	http_request = HTTPRequest.new()
	parent_node.add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

func search_game_by_name(game_name: String, callback: Callable = Callable()):
	"""Поиск игры по названию через Steam Store API"""
	if not http_request:
		print("HTTPRequest не настроен! Вызовите setup_http_request() сначала")
		return
	
	current_callback = callback
	
	var search_url = "https://store.steampowered.com/api/storesearch/"
	var query_params = "?term=" + game_name.uri_encode() + "&l=english&cc=US"
	var full_url = search_url + query_params
	
	print("Ищем игру: ", game_name)
	print("URL: ", full_url)
	
	var headers = ["User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"]
	http_request.request(full_url, headers)

func get_game_details(app_id: int, callback: Callable = Callable()):
	"""Получение детальной информации об игре"""
	if not http_request:
		print("HTTPRequest не настроен!")
		return
	
	current_callback = callback
	
	var details_url = "https://store.steampowered.com/api/appdetails/"
	var query_params = "?appids=" + str(app_id) + "&l=english"
	var full_url = details_url + query_params
	
	print("Получаем детали игры с ID: ", app_id)
	
	var headers = ["User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"]
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
	
	# Обработка результатов поиска
	if data.has("items") and data.items.size() > 0:
		var first_game = data.items[0]
		var app_id = first_game.id
		print("Найдена игра с ID: ", app_id)
		
		var game_data = {
			"app_id": app_id,
			"name": first_game.get("name", ""),
			"type": first_game.get("type", ""),
			"price": first_game.get("price", {})
		}
		
		game_found.emit(app_id, game_data)
		if current_callback.is_valid():
			current_callback.call(game_data)
	
	# Обработка деталей игры
	elif data.has(str(data.keys()[0])) if data.keys().size() > 0 else false:
		var app_id_str = str(data.keys()[0])
		var app_data = data[app_id_str]
		
		if app_data.has("success") and app_data.success and app_data.has("data"):
			var game_info = app_data.data
			var processed_data = {
				"app_id": int(app_id_str),
				"name": game_info.get("name", ""),
				"description": game_info.get("short_description", ""),
				"developers": game_info.get("developers", []),
				"publishers": game_info.get("publishers", []),
				"release_date": game_info.get("release_date", {}),
				"categories": game_info.get("categories", []),
				"genres": game_info.get("genres", []),
				"screenshots": game_info.get("screenshots", []),
				"header_image": game_info.get("header_image", ""),
				"background": game_info.get("background", ""),
				"background_raw": game_info.get("background_raw", "")
			}
			
			print("Получены детали игры: ", processed_data.name)
			if current_callback.is_valid():
				current_callback.call(processed_data)
		else:
			print("Игра не найдена или недоступна")
			game_not_found.emit()
			if current_callback.is_valid():
				current_callback.call(null)
	else:
		print("Игра не найдена")
		game_not_found.emit()
		if current_callback.is_valid():
			current_callback.call(null)

func launch_steam_game(app_id: int) -> bool:
	"""Запуск игры через Steam протокол"""
	var steam_url = "steam://rungameid/" + str(app_id)
	
	print("Запускаем игру через Steam протокол: ", steam_url)
	
	var success = false
	var os_name = OS.get_name()
	
	match os_name:
		"Linux":
			# В Linux используем xdg-open
			var exit_code = OS.execute("xdg-open", [steam_url], [], false, true)
			success = (exit_code == OK)
		
		"Windows":
			# В Windows используем start команду через cmd
			var exit_code = OS.execute("cmd", ["/c", "start", steam_url], [], false, true)
			success = (exit_code == OK)
		
		"macOS":
			# В macOS используем open команду
			var exit_code = OS.execute("open", [steam_url], [], false, true)
			success = (exit_code == OK)
		
		_:
			# Для других систем пробуем универсальный подход
			var exit_code = OS.execute("xdg-open", [steam_url], [], false, true)
			success = (exit_code == OK)
	
	if success:
		print("Команда запуска игры выполнена успешно")
		steam_launch_success.emit(app_id)
		return true
	else:
		print("Не удалось запустить игру через Steam протокол")
		steam_launch_failed.emit("Ошибка выполнения команды запуска")
		return false

func launch_steam_game_by_name(game_name: String) -> void:
	"""Поиск и запуск игры по названию"""
	search_game_by_name(game_name, func(game_data):
		if game_data and game_data.has("app_id"):
			var app_id = game_data.app_id
			launch_steam_game(app_id)
		else:
			print("Игра '", game_name, "' не найдена")
			steam_launch_failed.emit("Игра не найдена")
	)

func open_steam_page(app_id: int) -> bool:
	"""Открытие страницы игры в Steam"""
	var steam_url = "steam://store/" + str(app_id)
	
	print("Открываем страницу игры в Steam: ", steam_url)
	
	var success = false
	var os_name = OS.get_name()
	
	match os_name:
		"Linux":
			var exit_code = OS.execute("xdg-open", [steam_url], [], false, true)
			success = (exit_code == OK)
		
		"Windows":
			var exit_code = OS.execute("cmd", ["/c", "start", steam_url], [], false, true)
			success = (exit_code == OK)
		
		"macOS":
			var exit_code = OS.execute("open", [steam_url], [], false, true)
			success = (exit_code == OK)
		
		_:
			var exit_code = OS.execute("xdg-open", [steam_url], [], false, true)
			success = (exit_code == OK)
	
	return success

func install_steam_game(app_id: int) -> bool:
	"""Открытие окна установки игры в Steam"""
	var steam_url = "steam://install/" + str(app_id)
	
	print("Открываем окно установки игры: ", steam_url)
	
	var success = false
	var os_name = OS.get_name()
	
	match os_name:
		"Linux":
			var exit_code = OS.execute("xdg-open", [steam_url], [], false, true)
			success = (exit_code == OK)
		
		"Windows":
			var exit_code = OS.execute("cmd", ["/c", "start", steam_url], [], false, true)
			success = (exit_code == OK)
		
		"macOS":
			var exit_code = OS.execute("open", [steam_url], [], false, true)
			success = (exit_code == OK)
		
		_:
			var exit_code = OS.execute("xdg-open", [steam_url], [], false, true)
			success = (exit_code == OK)
	
	return success

func get_steam_game_images(app_id: int) -> Dictionary:
	"""Получение ссылок на изображения игры"""
	var base_url = "https://cdn.akamai.steamstatic.com/steam/apps/" + str(app_id)
	
	return {
		"library_cover": base_url + "/library_600x900.jpg",
		"header": base_url + "/header.jpg",
		"logo": base_url + "/logo.png",
		"background": base_url + "/page_bg_raw.jpg",
		"capsule_sm": base_url + "/capsule_sm_120.jpg",
		"capsule_lg": base_url + "/capsule_616x353.jpg"
	}

# Функция для интеграции в существующий код CoverFlow
func integrate_with_coverflow(coverflow_node: Node, game_title: String) -> void:
	"""Интеграция со существующим кодом CoverFlow"""
	setup_http_request(coverflow_node)
	
	steam_launch_success.connect(func(app_id):
		if coverflow_node.has_method("handle_process_launch"):
			# Имитируем успешный запуск для системы трекинга времени
			var fake_pid = app_id  # Используем app_id как псевдо-PID
			coverflow_node.handle_process_launch(fake_pid, game_title)
	)
	
	# Запускаем поиск и запуск
	launch_steam_game_by_name(game_title)
