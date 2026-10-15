extends Area3D
var zombie: CharacterBody3D
var headshot: bool=false
func receive_hit(damage: float, point: Vector3, _normal: Vector3) -> void:
    if is_instance_valid(zombie):zombie.manager.survival.damage_zombie(zombie,damage,headshot,"gun",point)
