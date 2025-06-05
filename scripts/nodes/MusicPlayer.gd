extends Node

@export var background_tracks: Array[String] = [
	"res://assets/music/sanctuary01.ogg",
	"res://assets/music/sanctuary02.ogg",
	"res://assets/music/sanctuary03.ogg",
	"res://assets/music/sanctuary04.ogg",
	"res://assets/music/sanctuary05.ogg",
	"res://assets/music/sanctuary06.ogg",
	"res://assets/music/sanctuary07.ogg",
	"res://assets/music/sanctuary08.ogg",
	"res://assets/music/sanctuary09.ogg",
	"res://assets/music/sanctuary10.ogg",
	"res://assets/music/sanctuary11.ogg",
	"res://assets/music/sanctuary12.ogg",
]

@export var target_volume: float = -20.0
@export var fade_in_duration: float = 5.0
@export var fade_pause_duration: float = 1.0  # Длительность фейда для паузы и возобновления

var sanctuary_cover = load("res://assets/music/cover.jpg")

var shuffled_playlist: Array[String] = []
var current_track_index: int = 0
var audio_player: AudioStreamPlayer
var tween: Tween

const NotificationLogicClass = preload("res://scripts/NotificationLogic.gd")
var notification = NotificationLogicClass.new()

func _ready():
	print("Инициализация музыки")
	add_child(notification)
	if not audio_player:
		audio_player = AudioStreamPlayer.new()
		add_child(audio_player)
		audio_player.finished.connect(_on_audio_stream_player_finished)
	
	await get_tree().process_frame
	start_music()

func start_music():
	if background_tracks.size() == 0:
		print("хуйня, нет треков для воспроизведения!")
		return
	
	shuffled_playlist = background_tracks.duplicate()
	shuffled_playlist.shuffle()
	current_track_index = 0
	play_current_track()
	print("музыка пошла, треков: ", shuffled_playlist.size())

func play_current_track():
	if shuffled_playlist.size() == 0 or current_track_index >= shuffled_playlist.size():
		print("плейлист пуст или треки кончились, начинаем заново")
		shuffled_playlist = background_tracks.duplicate()
		shuffled_playlist.shuffle()
		current_track_index = 0
	
	var track_path = shuffled_playlist[current_track_index]
	
	if not ResourceLoader.exists(track_path):
		print("файл не найден: ", track_path)
		next_track()
		return
	
	var audio_stream = load(track_path)
	if audio_stream == null:
		print("не удалось загрузить трек: ", track_path)
		next_track()
		return
	
	audio_player.volume_db = -50.0
	audio_player.stream = audio_stream
	audio_player.play()
	
	start_fade_in()
	print("♪ играет: ", track_path.get_file())
	var raw_name = track_path.get_file().get_basename()
	var pretty_name = raw_name.replace("_", " ").capitalize()
	var notification_text = "СЕЙЧАС ИГРАЕТ:\n" + pretty_name
	notification.show_notification(notification_text, sanctuary_cover)

func start_fade_in():
	if tween:
		tween.kill()
	
	tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(set_audio_volume, -50.0, target_volume, fade_in_duration)
	tween.tween_callback(on_fade_in_complete)

func set_audio_volume(volume: float):
	if audio_player:
		audio_player.volume_db = volume
	else:
		print("audio_player не инициализирован, хз что делать")

func on_fade_in_complete():
	print("появление звука завершено")

func next_track():
	current_track_index += 1
	if current_track_index >= shuffled_playlist.size():
		shuffled_playlist.shuffle()
		current_track_index = 0
		print("плейлист кончился, мешаем заново")
	play_current_track()

func _on_audio_stream_player_finished():
	print("трек закончился, переключаем")
	next_track()

func stop_music():
	if audio_player:
		if tween:
			tween.kill()
		audio_player.stop()
		print("музыка стоп")

func pause_music():
	if audio_player and not audio_player.stream_paused:
		if tween:
			tween.kill()
		tween = create_tween()
		tween.set_ease(Tween.EASE_IN)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_method(set_audio_volume, audio_player.volume_db, -50.0, fade_pause_duration)
		tween.tween_callback(func(): 
			audio_player.stream_paused = true
			print("музыка на паузе после фейда")
		)

func resume_music():
	if audio_player and audio_player.stream_paused:
		audio_player.stream_paused = false
		if tween:
			tween.kill()
		tween = create_tween()
		tween.set_ease(Tween.EASE_IN)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_method(set_audio_volume, audio_player.volume_db, target_volume, fade_pause_duration)
		tween.tween_callback(func(): 
			print("музыка снова играет после фейда")
		)

func set_volume(volume_db: float):
	target_volume = volume_db
	if audio_player and (not tween or not tween.is_valid()):
		audio_player.volume_db = volume_db
		print("!!!!!!! ГРОМКОСТЬ УСТАНОВЛЕНА: ", volume_db)

func set_fade_in_duration(duration: float):
	fade_in_duration = duration
	print("длительность фейда: ", duration)

func skip_track():
	if tween:
		tween.kill()
	print("скипаем трек")
	next_track()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			pause_music()
		NOTIFICATION_WM_WINDOW_FOCUS_IN:
			resume_music()
