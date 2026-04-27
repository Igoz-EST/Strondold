extends Node

var _main: Node3D


func setup(main: Node3D) -> void:
	_main = main


func _unhandled_input(event: InputEvent) -> void:
	var layer := get_parent() as CanvasLayer
	if layer == null or not layer.visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		if _main != null and _main.has_method(&"close_pause_menu"):
			_main.call(&"close_pause_menu")
		get_viewport().set_input_as_handled()
