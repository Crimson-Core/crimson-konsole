# SteamAPI.gd - Упрощенный класс для поиска игр в Steam
class_name SteamAPI
extends RefCounted

var http_request: HTTPRequest
var current_callback: Callable

# Разделяем сигналы для логотипа и описания
signal logo_found(game_data: Dictionary)
signal description_found(game_data: Dictionary)
signal game_not_found()

var steamgriddb_api_key: String = "ac6407f383cb7696689026c4576a7758"

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
	"""Обработка загруженного изображения (основной источник: steamstatic)."""
	request_node.queue_free() # Удаляем временный HTTP запрос
	
	var logo_texture: ImageTexture = null
	
	if response_code == 200 and body.size() > 0:
		var image = Image.new()
		var error = image.load_png_from_buffer(body)
		
		if error == OK:
			logo_texture = ImageTexture.new()
			logo_texture.set_image(image)
			print("Логотип загружен успешно (steamstatic).")
		else:
			print("Ошибка загрузки изображения: ", error)
	else:
		print("Не удалось загрузить логотип с steamstatic (response_code: ", response_code, ")")
	
	# Если логотип не получен — пробуем резервный поиск через SteamGridDB
	if logo_texture == null:
		# Попробуем резервный путь
		_fallback_steamgriddb_logo(app_id, basic_info, description)
		return
	
	# Формируем данные для логотипа и эмитим
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


# --- Новые методы для работы со SteamGridDB ---
func _fallback_steamgriddb_logo(app_id: int, basic_info: Dictionary, description: String):
	"""Резервный поиск логотипа через SteamGridDB API."""
	if steamgriddb_api_key == "":
		print("SteamGridDB API key не установлен — пропускаем резервный поиск.")
		# Отправляем пустой результат, чтобы не зависать
		var logo_data = {
			"name": basic_info.get("name", ""),
			"app_id": app_id,
			"logo_texture": null,
			"description": description
		}
		logo_found.emit(logo_data)
		if current_callback.is_valid():
			current_callback.call(logo_data)
		return
	
	# Сначала пытаемся получить steamgriddb game id по Steam AppID
	var url = "https://www.steamgriddb.com/api/v2/games/steam/" + str(app_id)
	var req = HTTPRequest.new()
	http_request.get_parent().add_child(req)
	req.request_completed.connect(func(result:int, response_code:int, headers:PackedStringArray, body:PackedByteArray):
		_on_steamgriddb_game_completed(result, response_code, headers, body, app_id, basic_info, description, req)
	)
	var headers = [
		"User-Agent: GodotSteamAPI/1.0",
		"Authorization: Bearer " + steamgriddb_api_key
	]
	req.request(url, headers)

func _on_steamgriddb_game_completed(result:int, response_code:int, headers:PackedStringArray, body:PackedByteArray, app_id:int, basic_info:Dictionary, description:String, request_node:HTTPRequest):
	request_node.queue_free()
	
	if response_code != 200:
		print("SteamGridDB: не удалось получить game по steam id, code=", response_code)
		# Отправляем пустой логотип (чтобы не висеть)
		var logo_data_fail = {
			"name": basic_info.get("name", ""),
			"app_id": app_id,
			"logo_texture": null,
			"description": description
		}
		logo_found.emit(logo_data_fail)
		if current_callback.is_valid():
			current_callback.call(logo_data_fail)
		return
	
	var json_text = body.get_string_from_utf8()
	var json = JSON.new()
	if json.parse(json_text) != OK:
		print("SteamGridDB: ошибка парсинга JSON для game by steam id")
		var logo_data_fail2 = {
			"name": basic_info.get("name", ""),
			"app_id": app_id,
			"logo_texture": null,
			"description": description
		}
		logo_found.emit(logo_data_fail2)
		if current_callback.is_valid():
			current_callback.call(logo_data_fail2)
		return
	
	var root = json.data
	# В API v2 ответ обычно в поле "data"
	var sg_game_id = null
	if root.has("data") and typeof(root.data) == TYPE_DICTIONARY:
		# Попробуем достать internal id (может называться "id")
		sg_game_id = root.data.get("id", null)
	elif root.has("id"):
		sg_game_id = root.get("id", null)
	
	if sg_game_id == null:
		print("SteamGridDB: не найден internal game id")
		var logo_data_nf = {
			"name": basic_info.get("name", ""),
			"app_id": app_id,
			"logo_texture": null,
			"description": description
		}
		logo_found.emit(logo_data_nf)
		if current_callback.is_valid():
			current_callback.call(logo_data_nf)
		return
	
	# Теперь запрашиваем grids для этой игры
	var grids_url = "https://www.steamgriddb.com/api/v2/grids/game/" + str(sg_game_id)
	var grids_req = HTTPRequest.new()
	http_request.get_parent().add_child(grids_req)
	grids_req.request_completed.connect(func(result:int, response_code:int, headers:PackedStringArray, body:PackedByteArray):
		_on_steamgriddb_grids_completed(result, response_code, headers, body, app_id, basic_info, description, grids_req)
	)
	var headers2 = [
		"User-Agent: GodotSteamAPI/1.0",
		"Authorization: Bearer " + steamgriddb_api_key
	]
	grids_req.request(grids_url, headers2)

func _on_steamgriddb_grids_completed(result:int, response_code:int, headers:PackedStringArray, body:PackedByteArray, app_id:int, basic_info:Dictionary, description:String, request_node:HTTPRequest):
	request_node.queue_free()
	
	if response_code != 200:
		print("SteamGridDB: не удалось получить grids, code=", response_code)
		var logo_data_nf = {
			"name": basic_info.get("name", ""),
			"app_id": app_id,
			"logo_texture": null,
			"description": description
		}
		logo_found.emit(logo_data_nf)
		if current_callback.is_valid():
			current_callback.call(logo_data_nf)
		return
	
	var json_text = body.get_string_from_utf8()
	var json = JSON.new()
	if json.parse(json_text) != OK:
		print("SteamGridDB: ошибка парсинга JSON grids")
		var logo_data_nf2 = {
			"name": basic_info.get("name", ""),
			"app_id": app_id,
			"logo_texture": null,
			"description": description
		}
		logo_found.emit(logo_data_nf2)
		if current_callback.is_valid():
			current_callback.call(logo_data_nf2)
		return
	
	var root = json.data
	# Ожидаем что root.data -> массив элементов (каждый элемент содержит url / thumb / type)
	var chosen_url: String = ""
	if root.has("data") and typeof(root.data) == TYPE_ARRAY:
		for item in root.data:
			# Ищем элементы типа "logo" или горизонтальную "grid" (в зависимости от того, что доступно)
			var t = item.get("type", "").to_lower()
			# Популярные поля с URL: "url", "thumb", "image"
			var candidate_url = item.get("url", "") if item.has("url") else (item.get("thumb", "") if item.has("thumb") else item.get("image", ""))
			if candidate_url == "":
				continue
			# Предпочтение: logos, затем grids
			if t == "logo" or t.find("logo") != -1:
				chosen_url = candidate_url
				break
			if chosen_url == "":
				# временно сохраняем первый попавшийся
				chosen_url = candidate_url
	
	if chosen_url == "":
		print("SteamGridDB: не найден URL для изображения")
		var logo_data_nf3 = {
			"name": basic_info.get("name", ""),
			"app_id": app_id,
			"logo_texture": null,
			"description": description
		}
		logo_found.emit(logo_data_nf3)
		if current_callback.is_valid():
			current_callback.call(logo_data_nf3)
		return
	
	# Полный URL может быть относительным; если так — дополним доменом
	if chosen_url.begins_with("/"):
		chosen_url = "https://www.steamgriddb.com" + chosen_url
	
	# Скачиваем выбранный ресурс
	var img_req = HTTPRequest.new()
	http_request.get_parent().add_child(img_req)
	img_req.request_completed.connect(func(result:int, response_code:int, headers:PackedStringArray, body:PackedByteArray):
		_on_steamgriddb_image_downloaded(result, response_code, headers, body, app_id, basic_info, description, img_req)
	)
	# Для скачивания изображений SteamGridDB, header Authorization не обязателен, но не повредит
	var img_headers = [
		"User-Agent: GodotSteamAPI/1.0",
		"Authorization: Bearer " + steamgriddb_api_key
	]
	print("SteamGridDB: загружаем изображение: ", chosen_url)
	img_req.request(chosen_url, img_headers)


func _on_steamgriddb_image_downloaded(result:int, response_code:int, headers:PackedStringArray, body:PackedByteArray, app_id:int, basic_info:Dictionary, description:String, request_node:HTTPRequest):
	request_node.queue_free()
	
	var logo_texture: ImageTexture = null
	
	if response_code == 200 and body.size() > 0:
		var img = Image.new()
		# Попробуем PNG, если нет — попробуем load_jpg_from_buffer
		var err = img.load_png_from_buffer(body)
		if err != OK:
			err = img.load_jpg_from_buffer(body)
		
		if err == OK:
			logo_texture = ImageTexture.new()
			logo_texture.set_image(img)
			print("Логотип загружен успешно (SteamGridDB).")
		else:
			print("Ошибка загрузки изображения из SteamGridDB: ", err)
	else:
		print("Не удалось скачать изображение SteamGridDB, code=", response_code)
	
	var logo_data = {
		"name": basic_info.get("name", ""),
		"app_id": app_id,
		"logo_texture": logo_texture,
		"description": description
	}
	
	logo_found.emit(logo_data)
	if current_callback.is_valid():
		current_callback.call(logo_data)
