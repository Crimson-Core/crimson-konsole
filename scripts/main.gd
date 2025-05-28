extends Node3D

#func _ready():
#	var anim_player = $AnimationPlayer
#	anim_player.play("box_rotate")
#	var animation: Animation = anim_player.get_animation("box_rotate")
#	animation.loop_mode = Animation.LOOP_LINEAR

func _ready():
	var anim_player = $AnimationPlayer
	var box_container = $BoxContainer  # Замени на путь к твоему BoxContainer
	anim_player.play("box_rotate")
	var animation: Animation = anim_player.get_animation("box_rotate")
	animation.loop_mode = Animation.LOOP_LINEAR

	for child in box_container.get_children():
		# Копируем анимацию для каждого дочернего узла
		var track_index = anim_player.get_animation("box_rotate").add_track(Animation.TYPE_VALUE)
		anim_player.get_animation("box_rotate").track_set_path(track_index, "%s:rotation_degrees" % child.get_path())
		# Дублируем ключевые кадры вращения (нужно адаптировать под твои значения)
		anim_player.get_animation("box_rotate").track_insert_key(track_index, 0.0, Vector3(0, 0, 0))
		anim_player.get_animation("box_rotate").track_insert_key(track_index, 5.0, Vector3(0, 360, 0))
