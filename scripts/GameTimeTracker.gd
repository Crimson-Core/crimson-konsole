class_name GameTimeTracker
extends RefCounted

# Структура для хранения данных о времени игры
class GameTimeData:
	var game_title: String = ""
	var total_time: float = 0.0  # Общее время в секундах
	var sessions: Array = []     # Массив сессий игры
	var last_played: String = "" # Дата последней игры
	
	func _init(title: String = ""):
		game_title = title
		last_played = Time.get_datetime_string_from_system()
	
	func add_session(duration: float):
		var session = {
			"date": Time.get_datetime_string_from_system(),
			"duration": duration
		}
		sessions.append(session)
		total_time += duration
		last_played = Time.get_datetime_string_from_system()
	
	func get_formatted_total_time() -> String:
		return format_time(total_time)
	
	func get_formatted_session_time(session_index: int) -> String:
		if session_index >= 0 and session_index < sessions.size():
			return format_time(sessions[session_index]["duration"])
		return "0:00"
	
	static func format_time(seconds: float) -> String:
		var hours = int(seconds) / 3600
		var minutes = (int(seconds) % 3600) / 60
		var secs = int(seconds) % 60
		
		if hours > 0:
			return "%d:%02d:%02d" % [hours, minutes, secs]
		else:
			return "%d:%02d" % [minutes, secs]

# Синглтон для отслеживания времени
static var instance: GameTimeTracker = null
var tracked_games: Dictionary = {}
var current_game: String = ""
var current_pid: int = 0
var start_time: float = 0.0
var check_timer: Timer = null

static func get_instance() -> GameTimeTracker:
	if instance == null:
		instance = GameTimeTracker.new()
	return instance

# Инициализация трекера
func _init():
	load_game_times()
	setup_timer()

# Настройка таймера для проверки процессов
func setup_timer():
	# Создаем таймер для проверки процессов каждые 5 секунд
	check_timer = Timer.new()
	check_timer.wait_time = 5.0
	check_timer.timeout.connect(_check_game_process)
	check_timer.autostart = true
	
	# Добавляем к корневому узлу
	if Engine.get_main_loop():
		var scene_tree = Engine.get_main_loop() as SceneTree
		if scene_tree and scene_tree.current_scene:
			scene_tree.current_scene.add_child(check_timer)

# Начать отслеживание игры
func start_tracking(game_title: String, pid: int):
	print("Начинаем отслеживание игры: ", game_title, " PID: ", pid)
	
	# Останавливаем предыдущее отслеживание если есть
	if current_game != "":
		stop_tracking()
	
	current_game = game_title
	current_pid = pid
	start_time = Time.get_unix_time_from_system()  # ИСПРАВЛЕНО
	
	# Создаем запись для игры если её нет
	if not tracked_games.has(game_title):
		tracked_games[game_title] = GameTimeData.new(game_title)
	
	print("Отслеживание начато для: ", game_title)

# Остановить отслеживание
func stop_tracking():
	if current_game == "":
		return
	
	var end_time = Time.get_unix_time_from_system()  # ИСПРАВЛЕНО
	var session_duration = end_time - start_time
	
	print("Остановка отслеживания для: ", current_game)
	print("Время сессии: ", GameTimeData.format_time(session_duration))
	
	# Добавляем сессию только если она длилась больше 30 секунд
	if session_duration > 30:
		if tracked_games.has(current_game):
			tracked_games[current_game].add_session(session_duration)
			save_game_times()
			print("Сессия записана для: ", current_game)
	
	current_game = ""
	current_pid = 0
	start_time = 0.0

# Проверка процесса игры
func _check_game_process():
	if current_pid == 0 or current_game == "":
		return
	
	var is_running = is_process_running(current_pid)
	if not is_running:
		print("Процесс игры завершен: ", current_game)
		stop_tracking()

# Проверить, запущен ли процесс (УЛУЧШЕННАЯ кроссплатформенная версия)
func is_process_running(pid: int) -> bool:
	var os_name = OS.get_name()
	var output = []
	var result = false
	
	match os_name:
		"Windows":
			# Используем tasklist для проверки процесса
			var exit_code = OS.execute("tasklist", ["/FI", "PID eq " + str(pid), "/NH"], output, true, true)
			if exit_code == 0 and output.size() > 0:
				var output_text = ""
				for line in output:
					output_text += line
				# Проверяем, что PID действительно найден в выводе
				result = output_text.contains(str(pid)) and not output_text.contains("INFO: No tasks")
			else:
				# Альтернативный метод для Windows - через PowerShell
				var ps_exit_code = OS.execute("powershell", 
					["-Command", "Get-Process -Id " + str(pid) + " -ErrorAction SilentlyContinue"], 
					output, true, true)
				result = ps_exit_code == 0
		
		"Linux", "FreeBSD", "NetBSD", "OpenBSD":
			# Проверяем через /proc (самый надежный способ для Linux)
			result = DirAccess.dir_exists_absolute("/proc/" + str(pid))
			
			# Если /proc недоступен, используем ps
			if not result:
				var exit_code = OS.execute("ps", ["-p", str(pid)], output, true, true)
				result = exit_code == 0 and output.size() > 1
		
		"macOS":
			# Используем ps для проверки процесса на macOS
			var exit_code = OS.execute("ps", ["-p", str(pid)], output, true, true)
			result = exit_code == 0 and output.size() > 1
		
		_:
			# Для неизвестных платформ пробуем универсальный подход
			print("Неизвестная платформа: ", os_name, " - используем универсальный метод")
			var exit_code = OS.execute("ps", ["-p", str(pid)], output, true, true)
			if exit_code != 0:
				# Если ps не работает, пробуем через kill -0 (Unix-like системы)
				exit_code = OS.execute("kill", ["-0", str(pid)], output, true, true)
				result = exit_code == 0
			else:
				result = output.size() > 1
	
	return result

# Загрузить сохраненное время игр
func load_game_times():
	var file_path = "user://game_times.json"
	
	if not FileAccess.file_exists(file_path):
		print("Файл времени игр не найден, создаем новый")
		return
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("Не удалось открыть файл времени игр")
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	if json_string.is_empty():
		return
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		print("Ошибка парсинга JSON времени игр: ", json.error_string)
		return
	
	var data = json.get_data()
	if not data is Dictionary:
		return
	
	# Загружаем данные времени
	for game_title in data.keys():
		var game_data = data[game_title]
		var time_data = GameTimeData.new(game_title)
		
		if game_data.has("total_time"):
			time_data.total_time = game_data["total_time"]
		if game_data.has("sessions"):
			time_data.sessions = game_data["sessions"]
		if game_data.has("last_played"):
			time_data.last_played = game_data["last_played"]
		
		tracked_games[game_title] = time_data
	
	print("Загружено времени для ", tracked_games.size(), " игр")

# Сохранить время игр
func save_game_times():
	var file_path = "user://game_times.json"
	var data = {}
	
	# Конвертируем в Dictionary для сохранения
	for game_title in tracked_games.keys():
		var time_data = tracked_games[game_title]
		data[game_title] = {
			"total_time": time_data.total_time,
			"sessions": time_data.sessions,
			"last_played": time_data.last_played
		}
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(data, "\t")
		file.store_string(json_string)
		file.close()
		print("Время игр сохранено")
	else:
		print("Ошибка сохранения времени игр")

# Получить время игры
func get_game_time(game_title: String) -> GameTimeData:
	if tracked_games.has(game_title):
		return tracked_games[game_title]
	return null

# Получить все игры с временем
func get_all_game_times() -> Dictionary:
	return tracked_games

# Получить топ игр по времени
func get_top_games_by_time(limit: int = 10) -> Array:
	var games_array = []
	
	for game_title in tracked_games.keys():
		var time_data = tracked_games[game_title]
		games_array.append({
			"title": game_title,
			"time": time_data.total_time,
			"formatted_time": time_data.get_formatted_total_time(),
			"last_played": time_data.last_played
		})
	
	# Сортируем по времени (убывание)
	games_array.sort_custom(func(a, b): return a.time > b.time)
	
	# Возвращаем топ
	if limit > 0 and games_array.size() > limit:
		return games_array.slice(0, limit)
	
	return games_array

# Очистить данные о времени для игры
func clear_game_time(game_title: String):
	if tracked_games.has(game_title):
		tracked_games.erase(game_title)
		save_game_times()
		print("Время игры очищено для: ", game_title)

# Очистить все данные о времени
func clear_all_times():
	tracked_games.clear()
	save_game_times()
	print("Все данные о времени очищены")
