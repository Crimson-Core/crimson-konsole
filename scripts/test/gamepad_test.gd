extends Node

# Ссылки на ноды UI (например, TextureRect для иконки кнопки A)
@onready var button_a_icon = $TextureRect_ButtonA

# Путь к текстурам иконок
const ICON_XBOX_A = "res://assets/kenney_input-prompts_1.4/Xbox Series/Default/xbox_button_color_a.png"
const ICON_PS_A = "res://assets/kenney_input-prompts_1.4/PlayStation Series/Default/playstation_button_color_cross.png"
const ICON_GENERIC_A = "res://assets/kenney_input-prompts_1.4/Steam Deck/Vector/steamdeck_button_a.svg"

# Перечисление типов геймпадов
enum ControllerType { XBOX, PLAYSTATION, GENERIC }

func _ready():
	# Проверяем все подключённые геймпады
	for device_id in Input.get_connected_joypads():
		update_controller_icon(device_id)

func _input(event):
	# Обрабатываем нажатие кнопки A
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A and event.pressed:
		var device_id = event.device
		update_controller_icon(device_id)

func update_controller_icon(device_id: int):
	var joy_name = Input.get_joy_name(device_id).to_lower()
	var controller_type = detect_controller_type(joy_name)
	print(joy_name)
	
	# Меняем иконку в зависимости от типа
	match controller_type:
		ControllerType.XBOX:
			button_a_icon.texture = load(ICON_XBOX_A)
		ControllerType.PLAYSTATION:
			button_a_icon.texture = load(ICON_PS_A)
		_:
			button_a_icon.texture = load(ICON_GENERIC_A)

func detect_controller_type(joy_name: String) -> ControllerType:
	if "xbox" in joy_name or "xinput" in joy_name:
		return ControllerType.XBOX
	elif "sony" in joy_name or "dualshock" in joy_name or "dualsense" in joy_name or "ps" in joy_name:
		return ControllerType.PLAYSTATION
	else:
		return ControllerType.GENERIC
