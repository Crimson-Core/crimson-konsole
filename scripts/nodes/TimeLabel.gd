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
	time_label.text = "%02d:%02d" % [time.hour, time.minute]
