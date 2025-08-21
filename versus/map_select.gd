extends Node2D

@onready var btn_level_1: Button = $"Level1/Button"

func _ready() -> void:
	if btn_level_1:
		btn_level_1.pressed.connect(_on_level_1_pressed)

func _on_level_1_pressed() -> void:
	get_tree().change_scene_to_file("res://versus/vs_map_1.tscn")


