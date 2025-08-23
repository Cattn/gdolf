extends RigidBody2D
const Find = preload("res://utilscripts/find.gd")

@onready var aiming_system = Find.find_aiming_system(self)
@onready var turn_manager: Node = Find.find_turn_manager(self)
@onready var _hit_sfx: AudioStreamPlayer2D = null
@export var max_hit_power: float = 3000.0
@export var min_hit_power: float = 600.0
@export var power_charge_time: float = 1.0 

var is_charging_power: bool = false
var power_start_time: float = 0.0
var current_power_level: float = 0.0
var recent_shot_frames: int = 0

const VELOCITY_THRESHOLD: float = 50.0
const ANGULAR_VELOCITY_THRESHOLD: float = 0.5
const GROUND_DAMPING: float = 0.02

func _ready() -> void:
	collision_mask |= collision_layer
	var existing: AudioStreamPlayer2D = get_node_or_null("HitSfx")
	if existing:
		_hit_sfx = existing
	else:
		_hit_sfx = AudioStreamPlayer2D.new()
		_hit_sfx.name = "HitSfx"
		_hit_sfx.stream = load("res://Ball/hit.wav")
		add_child(_hit_sfx)

func _process(_delta):
	if is_charging_power:
		var hold_duration = (Time.get_ticks_msec() / 1000.0) - power_start_time
		var power_ratio = min(hold_duration / power_charge_time, 1.0)
		current_power_level = power_ratio
		
		if aiming_system:
			aiming_system.queue_redraw()
	else:
		current_power_level = 0.0
	
	if recent_shot_frames > 0:
		recent_shot_frames -= 1
	
	if recent_shot_frames == 0 and is_on_ground() and linear_velocity.length() < 300.0 and abs(linear_velocity.y) < 50.0:
		linear_velocity *= (1.0 - GROUND_DAMPING)
		angular_velocity *= (1.0 - GROUND_DAMPING * 2.0)
		if linear_velocity.length() < VELOCITY_THRESHOLD and abs(angular_velocity) < ANGULAR_VELOCITY_THRESHOLD:
			linear_velocity = Vector2.ZERO
			angular_velocity = 0.0

func get_current_power() -> float:
	return current_power_level

func is_on_ground() -> bool:
	var params := PhysicsPointQueryParameters2D.new()
	params.position = global_position + Vector2(0, 30)
	params.collision_mask = 2
	params.exclude = [self]
	return get_world_2d().direct_space_state.intersect_point(params).size() > 0

func hit_ball():
	var hit_direction: Vector2 = Vector2.ZERO
	if aiming_system and aiming_system.has_method("get_aim_direction"):
		hit_direction = aiming_system.get_aim_direction()
	else:
		hit_direction = (get_global_mouse_position() - global_position).normalized()
	var shot_power_level: float = clamp(((Time.get_ticks_msec() / 1000.0) - power_start_time) / power_charge_time, 0.0, 1.0)
	if is_on_ground() and hit_direction.y > 0.7 and shot_power_level <= 0.6:
		var sign_x: float = 1.0 if hit_direction.x >= 0.0 else -1.0
		hit_direction.y = 0.7
		if abs(hit_direction.x) < 0.2:
			hit_direction.x = 0.2 * sign_x
		hit_direction = hit_direction.normalized()
	if hit_direction == Vector2.ZERO:
		hit_direction = Vector2.RIGHT
	var hold_duration: float = (Time.get_ticks_msec() / 1000.0) - power_start_time
	var power_level: float = clamp(hold_duration / power_charge_time, 0.0, 1.0)
	var power: float = lerp(min_hit_power, max_hit_power, power_level)
	var impulse: Vector2 = hit_direction * power
	apply_central_impulse(impulse)
	recent_shot_frames = 12
	if _hit_sfx:
		_hit_sfx.play()
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
