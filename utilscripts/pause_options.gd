extends CanvasLayer
const GameManagerRef = preload("res://GameManager/GameManager.gd")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var continue_button := get_node_or_null("UI/Buttons/Continue")
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
	var exit_button := get_node_or_null("UI/Buttons/Exit")
	if exit_button:
		exit_button.pressed.connect(_on_exit_to_menu_pressed)

func _on_continue_pressed() -> void:
	get_tree().paused = false
	hide()

func _on_exit_to_menu_pressed() -> void:
	get_tree().paused = false
	GameManagerRef.reset_progress()
	get_tree().change_scene_to_file("res://main_menu.tscn")
