extends RigidBody2D

enum ANIMAL_STATE { READY, DRAG, RELEASE }
var _state: ANIMAL_STATE = ANIMAL_STATE.READY

const DRAG_LIM_MAX: Vector2 = Vector2(0, 60)
const DRAG_LIM_MIN: Vector2 = Vector2(-60, 0)
const IMPULSE_MULT: float = 20.0
const IMPULSE_MAX: float = 1200.0

var _start: Vector2 = Vector2.ZERO
var _drag_start: Vector2 = Vector2.ZERO
var _dragged_vector: Vector2 = Vector2.ZERO
var _last_dragged_vector: Vector2 = Vector2.ZERO
var _arrow_scale_x: float = 0.0
var _last_collision_count: int = 0
var _reentry: bool = false

@onready var debug_label = $DebugLabel
@onready var stretch_sound = $StretchSound
@onready var launch_sound = $LaunchSound
@onready var kick_sound = $KickSound
@onready var arrow = $Arrow
@onready var timer = $Timer


# Called when the node enters the scene tree for the first time.
func _ready():
	_arrow_scale_x = arrow.scale.x
	arrow.hide()
	_start = position


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	update(delta)
	debug_label.text = "%s\n" % ANIMAL_STATE.keys()[_state]
	debug_label.text += "%.1f,%.1f" % [_dragged_vector.x, _dragged_vector.y]

func get_impulse() -> Vector2:
	return _dragged_vector * -1 * IMPULSE_MULT

func set_drag() -> void:
	_drag_start = get_global_mouse_position()
	arrow.show()

func set_release() -> void:
	arrow.hide()
	freeze = false
	apply_central_impulse(get_impulse())
	launch_sound.play()
	SignalManager.on_attempt_made.emit()

func set_new_state(new_state: ANIMAL_STATE) -> void:
	_state = new_state
	if _state == ANIMAL_STATE.RELEASE:
		set_release()
	elif _state == ANIMAL_STATE.DRAG:
		set_drag()
	elif _state == ANIMAL_STATE.READY:
		pass

func detect_release() -> bool:
	if _state == ANIMAL_STATE.DRAG:
		if Input.is_action_just_released("drag"):
			set_new_state(ANIMAL_STATE.RELEASE)
			return true
	return false

func scale_arrow() -> void:
	var imp_len = get_impulse().length()
	var perc = imp_len / IMPULSE_MAX
	arrow.scale.x = (_arrow_scale_x * perc) + _arrow_scale_x
	arrow.rotation = (_start - position).angle()

func play_stretch_sound() -> void:
	if(_last_dragged_vector - _dragged_vector).length() > 0:
		if not stretch_sound.playing:
			stretch_sound.play()

func get_dragged_vector(gmp: Vector2) -> Vector2:
	return gmp - _drag_start

func drag_in_limits() -> void:
	_last_dragged_vector = _dragged_vector
	_dragged_vector.x = clampf(_dragged_vector.x, DRAG_LIM_MIN.x, DRAG_LIM_MAX.x)
	_dragged_vector.y = clampf(_dragged_vector.y, DRAG_LIM_MIN.y, DRAG_LIM_MAX.y)
	position = _start + _dragged_vector

func update_drag() -> void:
	
	if detect_release():
		return
	
	var gmp = get_global_mouse_position()
	_dragged_vector = get_dragged_vector(gmp)
	play_stretch_sound()
	drag_in_limits()
	scale_arrow()

func play_collision() -> void:
	if (_last_collision_count == 0 and \
		get_contact_count() > 0 and \
		not kick_sound.playing):
		kick_sound.play()
	_last_collision_count = get_contact_count()
		

func update_flight() -> void:
	play_collision()

func update(delta: float) -> void:
	match _state:
		ANIMAL_STATE.DRAG:
			update_drag()
		ANIMAL_STATE.RELEASE:
			update_flight()

func die() -> void:
	SignalManager.on_animal_died.emit()
	queue_free()

func _on_screen_exited():
	_reentry = false
	timer.start()

func _on_screen_entered():
	_reentry = true


func _on_input_event(viewport, event, shape_idx):
	if _state == ANIMAL_STATE.READY and event.is_action_pressed("drag"):
		set_new_state(ANIMAL_STATE.DRAG)


func _on_sleeping_state_changed():
	if sleeping:
		var cb = get_colliding_bodies()
		if cb.size() > 0:
			cb[0].die()
		call_deferred("die")




func _on_timer_timeout():
	if not _reentry:
		die()
