extends RigidBody2D
const Find = preload("res://utilscripts/find.gd")

@onready var aiming_system = Find.find_aiming_system(self)  # Reference to separate aiming node
@onready var turn_manager: Node = Find.find_turn_manager(self)
@export var max_hit_power: float = 3000.0
@export var min_hit_power: float = 600.0
@export var power_charge_time: float = 1.0 

var is_charging_power: bool = false
var power_start_time: float = 0.0
var current_power_level: float = 0.0

func _ready() -> void:
	collision_mask |= collision_layer

func _process(_delta):
	if is_charging_power:
		var hold_duration = (Time.get_ticks_msec() / 1000.0) - power_start_time
		var power_ratio = min(hold_duration / power_charge_time, 1.0)
		current_power_level = power_ratio
		
		if aiming_system:
			aiming_system.queue_redraw()
	else:
		current_power_level = 0.0

func get_current_power() -> float:
	return current_power_level

func hit_ball():
	if aiming_system and aiming_system.has_method("get_aim_direction"):
		var hit_direction = aiming_system.get_aim_direction()
		var power = lerp(min_hit_power, max_hit_power, current_power_level)
		var impulse = hit_direction * power
		apply_central_impulse(impulse)
		if turn_manager and turn_manager.has_method("notify_shot_fired"):
			turn_manager.notify_shot_fired()

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if turn_manager and turn_manager.has_method("can_start_shot"):
					if turn_manager.can_start_shot() and _is_active_ball():
						is_charging_power = true
						power_start_time = Time.get_ticks_msec() / 1000.0
				else:
					if _is_active_ball():
						is_charging_power = true
						power_start_time = Time.get_ticks_msec() / 1000.0
			else:
				if is_charging_power and _is_active_ball():
					hit_ball()
					is_charging_power = false

func _is_active_ball() -> bool:
	if is_in_group("ball"):
		return true
	var parent := get_parent()
	if not parent:
		return true
	var count := 0
	for child in parent.get_children():
		if child is RigidBody2D and child.get_script() == get_script():
			count += 1
	return count <= 1

