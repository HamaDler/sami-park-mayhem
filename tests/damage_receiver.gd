extends StaticBody3D
var damage_received: float=0
func receive_hit(damage: float, _point: Vector3, _normal: Vector3) -> void:damage_received+=damage
