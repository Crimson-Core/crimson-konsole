extends Panel

@onready var time_label = $Label
@onready var timer = $Timer

func _ready():
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_on_timer_timeout)
	_on_timer_timeout()

func _on_timer_timeout():
	var time = Time.get_datetime_dict_from_system()
	var locale = TranslationServer.get_locale()
	
	var time_str = ""
	var date_str = ""
	
	# Форматирование времени в зависимости от локали
	if locale.begins_with("en"):
		# 12-часовой формат для английского
		var hour_12 = time.hour % 12
		if hour_12 == 0:
			hour_12 = 12
		var am_pm = "AM" if time.hour < 12 else "PM"
		time_str = "%d:%02d %s" % [hour_12, time.minute, am_pm]
	else:
		# 24-часовой формат для русского и японского
		time_str = "%02d:%02d" % [time.hour, time.minute]
	
	# Получаем локализованный день недели
	var weekday_key = "WEEKDAY_" + str(time.weekday)
	var weekday = tr(weekday_key)
	
	# Форматирование даты в зависимости от локали
	if locale.begins_with("en"):
		# Месяц/день для английского
		date_str = "%s %02d/%02d" % [weekday, time.month, time.day]
	else:
		# День.месяц для русского и японского
		date_str = "%s %02d.%02d" % [weekday, time.day, time.month]
	
	time_label.text = time_str + "\n" + date_str
