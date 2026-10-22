class_name ChaseCameraSettings
extends Resource
@export var min_distance: float = 2.8
@export var max_distance: float = 18.0
@export var default_distance: float = 7.0
@export var scroll_step: float = .8
@export var field_of_view: float = 62.0
@export var follow_height: float = 1.25
# First person on foot and from the driver's seat. Off restores the old chase camera.
@export var first_person: bool = true
@export var eye_height: float = 1.6
@export var driver_look_yaw_limit: float = 2.2
