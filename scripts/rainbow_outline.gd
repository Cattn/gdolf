extends Label

@export var speed: float = 0.5
@export var saturation: float = 0.85
@export var value: float = 1.0
@export var alpha: float = 1.0

var hue: float = 0.0

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	hue = fmod(hue + delta * speed, 1.0)
	add_theme_color_override("font_outline_color", Color.from_hsv(hue, saturation, value, alpha))


