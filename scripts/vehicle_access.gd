extends Node3D
@export var display_name: String="GOLF CART"
@export var interaction_distance: float=3.6
var occupant: Node=null
@onready var vehicle: CharacterBody3D=get_parent()
func _ready() -> void:add_to_group("vehicles")
func set_occupied(person: Node) -> void:
    occupant=person
    vehicle.set_control_enabled(person!=null)
func available() -> bool:return occupant==null and not vehicle.rolling and vehicle.health>0
func exit_candidates() -> Array[Vector3]:
    var result: Array[Vector3]=[]
    for marker in [$ExitLeft,$ExitRight,$ExitRear]:result.append(marker.global_position)
    return result
