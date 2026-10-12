class_name DrivingSettings
extends Resource
@export_group("Engine")
@export var max_speed: float = 55.555556
@export var reverse_speed: float = 4.2
@export var acceleration: float = 11.0
@export var top_speed_acceleration: float = 4.0
@export var throttle_response: float = 3.5
@export var brake_deceleration: float = 21.0
@export var coast_deceleration: float = 0.8
@export var aerodynamic_drag: float = 0.0015
@export var grass_speed: float = 11.111111
@export var grass_deceleration: float = 24.0
@export_group("Handling")
@export var steering_angle: float = 0.52
@export var wheelbase: float = 1.85
@export var high_speed_steering_ratio: float = 0.3
@export var steering_reduction_start: float = 8.0
@export var max_yaw_rate: float = 1.25
@export var road_traction: float = 12.0
@export var grass_traction: float = 5.0
@export_group("Handbrake drift")
@export var drift_min_speed: float = 8.333333
@export var drift_traction: float = 1.5
@export var drift_brake_deceleration: float = 2.8
@export var drift_yaw_boost: float = 0.45
@export var drift_max_yaw_rate: float = 1.8
@export var max_drift_angle: float = 1.1
@export var drift_engage_rate: float = 4.0
@export var drift_release_rate: float = 2.0
@export var drift_kick_duration: float = 0.35

@export_group("Rollover")
@export var rollover_min_speed: float = 38.888889
@export var rollover_brake_min_speed: float = 33.333333
@export var rollover_lateral_acceleration: float = 38.0
@export var rollover_brake_multiplier: float = 1.35
@export var rollover_risk_gain: float = 2.5
@export var rollover_risk_release: float = 3.0
@export var rollover_launch_speed: float = 3.6
@export var rollover_spin_speed: float = 4.6
