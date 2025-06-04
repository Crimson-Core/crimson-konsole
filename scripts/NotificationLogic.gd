class_name NotificationLogic
extends Node

const NOTIFICATION_SCENE_PATH = "res://scenes/notification.tscn"

var is_showing_notification := false

func show_notification(message: String, texture: Texture2D) -> void:
	if is_showing_notification:
		print("Уведомление уже показывается. Ждём...")
		return

	is_showing_notification = true
	
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
				
				print("обратная анимация пошла")
			else:
				print("хуйня, нет notification_animation_rev")
		else:
			print("хуйня, нет AnimationPlayer или notification_animation")
	else:
		print("Хуйня, не смог загрузить сцену уведомления")

	is_showing_notification = false
