class_name GameTimeTracker
extends RefCounted

# Структура данных о времени игры — остается без изменений
class GameTimeData:
	var game_title: String = ""
	var total_time: float = 0.0
	var sessions: Array = []
	var last_played: String = ""
	
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

# === SINGLETON-ЧАСТЬ ===

static var instance: GameTimeTracker = null
static func get_instance() -> GameTimeTracker:
	if instance == null:
		instance = GameTimeTracker.new()
	return instance

var tracked_games: Dictionary = {}
var active_games: Dictionary = {}  # {pid: {"title": game_title, "start_time": float}}
var check_timer: Timer = null

func _init():
	load_game_times()
	setup_timer()

func setup_timer():
	check_timer = Timer.new()
	check_timer.wait_time = 5.0
	check_timer.timeout.connect(_check_game_processes)
	check_timer.autostart = true

	if Engine.get_main_loop():
		var scene_tree = Engine.get_main_loop() as SceneTree
		if scene_tree and scene_tree.current_scene:
			scene_tree.current_scene.add_child(check_timer)

# Начать отслеживание одной игры
func start_tracking(game_title: String, pid: int):
	print("Начинаем отслеживание игры: ", game_title, " PID: ", pid)
	if active_games.has(pid):
		print("Игра уже отслеживается: ", game_title)
		return
	
	active_games[pid] = {
		"title": game_title,
		"start_time": Time.get_unix_time_from_system()
	}
	
	if not tracked_games.has(game_title):
		tracked_games[game_title] = GameTimeData.new(game_title)

# Остановить отслеживание одной игры
func stop_tracking(pid: int):
	if not active_games.has(pid):
		return
	
	var game_title = active_games[pid]["title"]
	var start_time = active_games[pid]["start_time"]
	var end_time = Time.get_unix_time_from_system()
	var duration = end_time - start_time
	
	print("Останавливаем отслеживание: ", game_title, " (PID: ", pid, ")")
	print("Продолжительность сессии: ", GameTimeData.format_time(duration))
	
	if duration > 30:
		if tracked_games.has(game_title):
			tracked_games[game_title].add_session(duration)
			save_game_times()
			print("Сессия записана для: ", game_title)
	
	active_games.erase(pid)

# Проверка всех процессов игр
func _check_game_processes():
	var finished_pids = []
	
	for pid in active_games.keys():
		if not is_process_running(pid):
			finished_pids.append(pid)
	
	for pid in finished_pids:
		stop_tracking(pid)

# Проверка процесса (тот же метод, не изменился)
func is_process_running(pid: int) -> bool:
	var os_name = OS.get_name()
	var output = []
	var result = false
	
	match os_name:
		"Windows":
			var exit_code = OS.execute("tasklist", ["/FI", "PID eq " + str(pid), "/NH"], output, true, true)
			if exit_code == 0 and output.size() > 0:
				var output_text = ""
				for line in output:
					output_text += line
				result = output_text.contains(str(pid)) and not output_text.contains("INFO: No tasks")
			else:
				var ps_exit_code = OS.execute("powershell", ["-Command", "Get-Process -Id " + str(pid) + " -ErrorAction SilentlyContinue"], output, true, true)
				result = ps_exit_code == 0
		
		"Linux", "FreeBSD", "NetBSD", "OpenBSD":
			result = DirAccess.dir_exists_absolute("/proc/" + str(pid))
			if not result:
				var exit_code = OS.execute("ps", ["-p", str(pid)], output, true, true)
				result = exit_code == 0 and output.size() > 1
		
		"macOS":
			var exit_code = OS.execute("ps", ["-p", str(pid)], output, true, true)
			result = exit_code == 0 and output.size() > 1
		
		_:
			var exit_code = OS.execute("ps", ["-p", str(pid)], output, true, true)
			if exit_code != 0:
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
