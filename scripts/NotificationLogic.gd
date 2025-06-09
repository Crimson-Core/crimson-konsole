class_name NotificationLogic
extends Node

const NOTIFICATION_SCENE_PATH = "res://scenes/notification.tscn"
var is_showing_notification := false
var notification_queue := []

func show_notification(message: String, texture: Texture2D) -> void:
	# Добавляем уведомление в очередь
	notification_queue.append({"message": message, "texture": texture})
	
	# Если уведомление не показывается, начинаем обработку очереди
	if not is_showing_notification:
		_process_notification_queue()

func _process_notification_queue() -> void:
	if notification_queue.is_empty() or is_showing_notification:
		return
	
	is_showing_notification = true
	
	# Берём первое уведомление из очереди
	var notification_data = notification_queue.pop_front()
	var message = notification_data.message
	var texture = notification_data.texture
	
	var notification_scene = load(NOTIFICATION_SCENE_PATH) as PackedScene
	if notification_scene:
		var notification_node = notification_scene.instantiate()
		add_child(notification_node)
		
		notification_node.position = Vector2(1487.0, 150.0)
		
		var notification_text = notification_node.get_node_or_null("Text")
		var notification_icon = notification_node.get_node_or_null("Icon")
		var anim_player = notification_node.get_node_or_null("AnimationPlayer")
		
		if anim_player and anim_player.has_animation("notification_animation"):
			notification_node.visible = true
			anim_player.play("notification_animation")
			
			await get_tree().create_timer(0.4).timeout
			if notification_text:
				notification_text.visible = true
				notification_text.text = message
			if notification_icon:
				notification_icon.visible = true
				notification_icon.texture = texture
			
			await get_tree().create_timer(3.0).timeout
			
			if anim_player.has_animation("notification_animation_rev"):
				anim_player.play("notification_animation_rev")
				
				await get_tree().create_timer(0.2).timeout
				if notification_text:
					notification_text.visible = false
					notification_text.text = ""
				if notification_icon:
					notification_icon.visible = false
					notification_icon.texture = null
				
				await get_tree().create_timer(0.2).timeout
				notification_node.visible = false
				notification_node.queue_free()
				
			else:
				print("хуйня, нет notification_animation_rev")
		else:
			print("хуйня, нет AnimationPlayer или notification_animation")
	else:
		print("Хуйня, не смог загрузить сцену уведомления")
	
	is_showing_notification = false
	
	# Обрабатываем следующее уведомление в очереди, если есть
	if not notification_queue.is_empty():
		_process_notification_queue()
