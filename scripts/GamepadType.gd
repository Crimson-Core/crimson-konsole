class_name GamepadType
extends Node
enum ControllerType { XBOX, PLAYSTATION, GENERIC }

const ICON_XBOX_CONTROLLER = "res://assets/kenney_input-prompts_1.4/Xbox Series/Double/controller_xboxseries.png"
const ICON_PS_CONTROLLER = "res://assets/kenney_input-prompts_1.4/PlayStation Series/Default/controller_playstation4.png"
const ICON_GENERIC_CONTROLLER = "res://assets/kenney_input-prompts_1.4/Flairs/Double/controller_generic.png"

const ICON_XBOX_A = "res://assets/kenney_input-prompts_1.4/Xbox Series/Default/xbox_button_color_a.png"
const ICON_PS_A = "res://assets/kenney_input-prompts_1.4/PlayStation Series/Default/playstation_button_color_cross.png"
const ICON_GENERIC_A = "res://assets/kenney_input-prompts_1.4/Steam Deck/Vector/steamdeck_button_a.svg"

const ICON_XBOX_B = "res://assets/kenney_input-prompts_1.4/Xbox Series/Double/xbox_button_color_b.png"
const ICON_PS_B = "res://assets/kenney_input-prompts_1.4/PlayStation Series/Double/playstation_button_color_circle.png"
const ICON_GENERIC_B = "res://assets/kenney_input-prompts_1.4/Nintendo Gamecube/Default/gamecube_button_b.png"

const ICON_XBOX_START = "res://assets/kenney_input-prompts_1.4/Xbox Series/Double/xbox_button_menu_black.png"
const ICON_PS_START = "res://assets/kenney_input-prompts_1.4/PlayStation Series/Double/playstation4_button_options_outline.png"
const ICON_GENERIC_START = "res://assets/kenney_input-prompts_1.4/Xbox Series/Double/xbox_button_start_outline.png"

const ICON_XBOX_DPAD = "res://assets/kenney_input-prompts_1.4/Xbox Series/Double/xbox_dpad_vertical.png"
const ICON_PS_DPAD = "res://assets/kenney_input-prompts_1.4/PlayStation Series/Double/playstation_dpad_vertical.png"
const ICON_GENERIC_DPAD = "res://assets/kenney_input-prompts_1.4/Steam Deck/Double/steamdeck_dpad_vertical.png"

func detect_controller_type(joy_name: String) -> ControllerType:
	if "xbox" in joy_name or "xinput" in joy_name:
		return ControllerType.XBOX
	elif "sony" in joy_name or "dualshock" in joy_name or "dualsense" in joy_name or "ps" in joy_name:
		return ControllerType.PLAYSTATION
	else:
		return ControllerType.GENERIC
