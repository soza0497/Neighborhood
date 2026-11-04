class_name IslandTestEntry
extends RefCounted
## Entrada ESCONDIDA a la demo de la isla (Isla 1A), en Menú → Info.
##
## Detrás de un interruptor «Herramientas de prueba» (apagado por defecto, se guarda en
## la partida como `settings.dev_tools`): al prenderlo aparece el botón «Prueba de isla».
## Así la demo viaja en el APK sin cambiar la escena principal ni molestar a nadie.
## El botón guarda la partida y abre la demo; el botón «Volver» de la demo vuelve al login.

const SCENE := "res://scenes/island/island_demo.tscn"
const SETTING := "dev_tools"


## Agrega el interruptor y el botón a la lista `rows`, desde la posición `anchor`.
## Devuelve la posición siguiente (para seguir insertando).
static func add_to(rows: VBoxContainer, anchor: int, tree: SceneTree) -> int:
	var enabled := bool(GameState.settings.get(SETTING, false))
	var toggle := CheckButton.new()
	toggle.text = "Herramientas de prueba"
	toggle.add_theme_font_size_override("font_size", 20)
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.button_pressed = enabled
	var button := Button.new()
	button.text = "Prueba de isla (rendimiento)"
	button.add_theme_font_size_override("font_size", 20)
	button.focus_mode = Control.FOCUS_NONE
	button.visible = enabled
	toggle.toggled.connect(func(on: bool) -> void:
		GameState.settings[SETTING] = on
		button.visible = on)
	button.pressed.connect(func() -> void:
		SaveSystem.save_game()
		tree.change_scene_to_file(SCENE))
	rows.add_child(toggle)
	rows.move_child(toggle, anchor)
	rows.add_child(button)
	rows.move_child(button, anchor + 1)
	return anchor + 2
