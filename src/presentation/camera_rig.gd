class_name CameraRig
extends Node3D
## Ortho izometrik kamera rig'i (CLAUDE.md §16.1).
## Rig döner; kamera lokal sabit. Q/E = 90° adım rotasyon (tween), tekerlek = zoom.

const PITCH_DEG := -35.0
const BASE_YAW_DEG := 45.0
const CAM_DISTANCE := 18.0
const ROTATE_TIME := 0.35
const ZOOM_MIN := 6.0
const ZOOM_MAX := 16.0
const ZOOM_STEP := 1.0

var camera: Camera3D
var _target_yaw := BASE_YAW_DEG
var _tween: Tween

func _ready() -> void:
	rotation_degrees.y = BASE_YAW_DEG
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 9.0
	var pitch := deg_to_rad(-PITCH_DEG)
	camera.position = Vector3(0, CAM_DISTANCE * sin(pitch), CAM_DISTANCE * cos(pitch))
	camera.rotation_degrees.x = PITCH_DEG
	camera.near = 0.05
	camera.far = 100.0
	camera.current = true
	add_child(camera)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q: _rotate_step(90.0)
			KEY_E: _rotate_step(-90.0)
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP: _zoom(-ZOOM_STEP)
			MOUSE_BUTTON_WHEEL_DOWN: _zoom(ZOOM_STEP)

func _rotate_step(delta_deg: float) -> void:
	_target_yaw += delta_deg
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, "rotation_degrees:y", _target_yaw, ROTATE_TIME)

func _zoom(delta: float) -> void:
	camera.size = clampf(camera.size + delta, ZOOM_MIN, ZOOM_MAX)
