extends Control

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if get_tree().paused:
			_hide_and_unpause()
		else:
			_show_and_pause()

func _show_and_pause() -> void:
	get_tree().paused = true
	if get_parent() != null:
		get_parent().show()
	show()

func _hide_and_unpause() -> void:
	hide()
	if get_parent() != null:
		get_parent().hide()
	get_tree().paused = false
